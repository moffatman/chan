import 'dart:async';

import 'package:chan/models/thread.dart';
import 'package:chan/services/captcha.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:mutex/mutex.dart';

typedef QueueEntryActionKey = (String imageboardKey, String board, ImageboardAction action);

sealed class QueueState<T> {
	const QueueState();
	bool get isIdle;
	bool get isSubmittable;
	bool get isFinished => isIdle && !isSubmittable;
	bool get _needsCaptcha => false;
	DateTime? get _submissionTime => null;
}

class QueueStateIdle<T> extends QueueState<T> {
	const QueueStateIdle();
	@override
	bool get isIdle => true;
	@override
	bool get isSubmittable => true;
}

class QueueStateNeedsCaptcha<T> extends QueueState<T> {
	final BuildContext? context;
	final VoidCallback? beforeModal;
	final VoidCallback? afterModal;
	const QueueStateNeedsCaptcha(this.context, {this.beforeModal, this.afterModal});
	@override
	bool get isIdle => false;
	@override
	bool get isSubmittable => false;
	@override
	bool get _needsCaptcha => true;
}

class QueueStateWaitingWithCaptcha<T> extends QueueState<T> {
	final CaptchaSolution captchaSolution;
	const QueueStateWaitingWithCaptcha(this.captchaSolution);
	@override
	bool get isIdle => false;
	@override
	bool get isSubmittable => false;
}

typedef WaitMetadata = ({DateTime until, VoidCallback skip});

class QueueStateSubmitting<T> extends QueueState<T> {
	final String? message;
	/// Can be called to skip current step (arbitrary delay?)
	final WaitMetadata? wait;
	final CancelToken? cancelToken;
	const QueueStateSubmitting({
		required this.message,
		this.wait,
		this.cancelToken
	});
	@override
	bool get isIdle => false;
	@override
	bool get isSubmittable => false;
	@override
	String toString() => 'QueueStateSubmitting(message: $message, wait: $wait, cancelToken: $cancelToken)';
}

class QueueStateFailed<T> extends QueueState<T> {
	final Object error;
	final StackTrace stackTrace;
	final CaptchaSolution? captchaSolution;
	const QueueStateFailed(this.error, this.stackTrace, {this.captchaSolution});
	@override
	bool get isIdle => true;
	@override
	bool get isSubmittable => true;
}

class QueueStateDone<T> extends QueueState<T> {
	final DateTime time;
	final CaptchaSolution captchaSolution;
	final T result;
	const QueueStateDone(this.time, this.result, this.captchaSolution);
	@override
	bool get isIdle => true;
	@override
	bool get isSubmittable => false;
	@override
	DateTime? get _submissionTime => time;
}

class QueueStateDeleted<T> extends QueueState<T> {
	const QueueStateDeleted();
	@override
	bool get isIdle => true;
	@override
	bool get isSubmittable => false;
}

sealed class QueueEntry<T> extends ChangeNotifier {
	final _lock = Mutex();
	final String imageboardKey;
	Imageboard get imageboard => ImageboardRegistry.instance.getImageboard(imageboardKey)!;
	ImageboardSite get site => imageboard.site;
	Future<T> _submitImpl(CaptchaSolution captchaSolution, CancelToken cancelToken);
	QueueState<T> _state;
	QueueState<T> get state => _state;
	bool get useLoginSystem;
	bool get isArchived;
	set _useLoginSystem(bool newUseLoginSystem);
	set useLoginSystem(bool newUseLoginSystem) {
		_useLoginSystem = newUseLoginSystem;
		notifyListeners();
	}

	@override
	String toString() => 'QueueEntry<$T>(state: $state)';

	QueueEntry({
		required this.imageboardKey,
		required QueueState<T> state
	}) : _state = state;

	String get _board;
	ImageboardAction get _action;
	Future<CaptchaRequest> _getCaptchaRequest();

	QueueEntryActionKey get _key => (imageboardKey, _board, site.getQueue(_action));
	OutboxQueue<T>? get queue => Outbox.instance.queues[_key] as OutboxQueue<T>?;
	DateTime? get allowedTime => queue?.allowedTime;
	Duration get _cooldown => site.getActionCooldown(_board, _action, !Settings.instance.isConnectedToWifi);
	ThreadIdentifier? get thread;

	void submit(BuildContext? context) async {
		_state = QueueStateNeedsCaptcha(context);
		notifyListeners();
		if (queue?.captchaAllowedTime.isAfter(DateTime.now()) == false) {
			// Grab the new captcha right away
			await _preSubmit();
		}
		notifyListeners();
		Future.microtask(Outbox.instance._process);
	}

	@mustCallSuper
	void delete() {
		final state = this.state;
		if (state is QueueStateSubmitting<T>) {
			state.cancelToken?.cancel();
		}
		_state = const QueueStateDeleted();
		notifyListeners();
		Future.microtask(Outbox.instance._process);
	}

	void undelete() {
		_state = const QueueStateIdle();
		notifyListeners();
		Future.microtask(Outbox.instance._process);
	}

	void cancel() {
		final state = this.state;
		if (state is QueueStateSubmitting<T>) {
			state.cancelToken?.cancel();
		}
		print('$this::cancel()');
		_state = const QueueStateIdle();
		notifyListeners();
		Future.microtask(Outbox.instance._process);
	}

	Future<void> _preSubmit() => _lock.protect(() async {
		final initialState = state;
		final QueueStateNeedsCaptcha<T>? initialNeedsCaptchaState;
		if (initialState is QueueStateNeedsCaptcha<T>) {
			initialNeedsCaptchaState = initialState;
			try {
				final savedFields = site.loginSystem?.getSavedLoginFields();
				if (useLoginSystem && savedFields != null) {
					try {
						await site.loginSystem?.login(_board, savedFields);
					}
					catch (e) {
						final context = initialState.context ?? ImageboardRegistry.instance.context;
						if (context != null && context.mounted) {
							showToast(
								context: context,
								icon: CupertinoIcons.exclamationmark_triangle,
								message: 'Failed to log in to ${site.loginSystem?.name}'
							);
						}
						print('Problem auto-logging-in to ${site.loginSystem?.name}: $e');
					}
				}
				else {
					await site.loginSystem?.clearLoginCookies(_board, false);
				}
				DateTime? tryAgainAt0;
				final request = await _getCaptchaRequest();
				final captcha = await solveCaptcha(
					context: (initialState.context?.mounted ?? false) ? initialState.context : null,
					beforeModal: initialState.beforeModal,
					afterModal: initialState.afterModal,
					site: site,
					request: request,
					onTryAgainAt: (x) => tryAgainAt0 = x,
					forceHeadless: switch (initialState.context?.mounted ?? false) {
						true => switch (Outbox.instance.headlessSolveFailed) {
								true => false, // Do not use headless solver
								false => null, // Try headless solver
						},
						false => true // Must use headless solver
					}
				);
				final tryAgainAt = tryAgainAt0;
				if (captcha != null) {
					_state = QueueStateWaitingWithCaptcha(captcha);
				}
				else if (tryAgainAt != null) {
					queue?.captchaAllowedTime = tryAgainAt;
					// Don't change state, just try again at that time
				}
				else {
					print('Idling following captcha == null');
					_state = const QueueStateIdle();
				}
			}
			on CooldownException catch (e) {
				print('Got cooldown in $this:_preSubmit() to try again in ${e.tryAgainAt.difference(DateTime.now())}');
				final context = initialState.context ?? ImageboardRegistry.instance.context;
				if (context != null && context.mounted) {
					showToast(
						context: context,
						message: 'Need to wait ${formatDuration(e.tryAgainAt.difference(DateTime.now()))} to get captcha',
						icon: CupertinoIcons.exclamationmark_shield
					);
				}
				queue?.captchaAllowedTime = e.tryAgainAt;
				// Don't change state, just try again at that time
			}
			on HeadlessSolveNotPossibleException {
				final context = initialState.context ?? ImageboardRegistry.instance.context;
				if (context != null && context.mounted) {
					showToast(
						context: context,
						message: 'Captcha needed',
						icon: CupertinoIcons.checkmark_shield,
						easyButton: ('Solve', () => submit(context))
					);
				}
				print('Idling after headless solve failed');
				_state = const QueueStateIdle();
			}
			catch (e, st) {
				print(e);
				print(st);
				_state = QueueStateFailed(e, st);
			}
			notifyListeners();
		}
		else {
			initialNeedsCaptchaState = null;
		}
		if (initialState is QueueStateWaitingWithCaptcha<T>) {
			final deadline = DateTime.now().add(const Duration(seconds: 5));
			final expiresAt = initialState.captchaSolution.expiresAt;
			if (expiresAt != null && expiresAt.isBefore(deadline)) {
				initialState.captchaSolution.dispose();
				_state = initialNeedsCaptchaState ?? const QueueStateNeedsCaptcha(null);
				notifyListeners();
			}
		}
	});

	Future<void> _submit() async {
		// _lock is not re-entrant...
		await _preSubmit();
		await _lock.protect(() async {
			final initialState = state;
			if (initialState is QueueStateWaitingWithCaptcha<T>) {
				final cancelToken = CancelToken();
				final captchaSolution = initialState.captchaSolution;
				try {
					final delay = site.getCaptchaUsableTime(captchaSolution).difference(DateTime.now());
					final skipCompleter = Completer<void>();
					_state = QueueStateSubmitting(
						message: 'Waiting to use captcha',
						wait: delay > const Duration(seconds: 3) ? (
							until: DateTime.now().add(delay),
							skip: skipCompleter.complete
						) : null,
						cancelToken: cancelToken
					);
					notifyListeners();
					await Future.any([Future.delayed(delay), skipCompleter.future, cancelToken.whenCancel]);
					if (cancelToken.isCancelled) {
						_state = const QueueStateIdle();
						notifyListeners();
						return;
					}
					_state = QueueStateSubmitting(
						message: 'Submitting',
						cancelToken: cancelToken
					);
					notifyListeners();
					final result = await _submitImpl(captchaSolution, cancelToken);
					_state = QueueStateDone(DateTime.now(), result, captchaSolution);
					notifyListeners();
				}
				on CooldownException catch (e) {
					print('got cd $e');
					_state = initialState; // Restore to wait with captcha
					final context = ImageboardRegistry.instance.context;
					if (context != null && context.mounted) {
						showToast(
							context: context,
							message: 'Need to wait ${formatDuration(e.tryAgainAt.difference(DateTime.now()))} to post',
							icon: CupertinoIcons.exclamationmark_shield
						);
					}
					queue?.allowedTime = e.tryAgainAt;
					notifyListeners();
				}
				catch (e, st) {
					print(e);
					print(st);
					if (_state is! QueueStateDeleted<T>) {
						// Don't revive due to exception from cancellation
						_state = QueueStateFailed(e, st, captchaSolution: captchaSolution);
						notifyListeners();
					}
				}
			}
		});
	}
}

class QueuedPost extends QueueEntry<PostReceipt> {
	final DraftPost post;
	@override
	bool get useLoginSystem => post.useLoginSystem ?? true;
	@override
	set _useLoginSystem(bool newUseLoginSystem) => post.useLoginSystem = newUseLoginSystem;

	@override
	Future<PostReceipt> _submitImpl(CaptchaSolution captchaSolution, CancelToken cancelToken) async {
		return await imageboard.submitPost(post, captchaSolution, cancelToken);
	}

	@override
	Future<CaptchaRequest> _getCaptchaRequest() => site.getCaptchaRequest(post.board, post.threadId);

	@override
	void delete() {
		super.delete();
		imageboard.persistence.browserState.outbox.remove(post);
		imageboard.persistence.didUpdateBrowserState();
	}

	@override
	String get _board => post.board;

	@override
	ImageboardAction get _action => post.action;

	@override
	ThreadIdentifier? get thread => post.thread;

	@override
	bool get isArchived {
		final thread = post.thread;
		if (thread == null) {
			// New thread -> no parent thread to check
			return false;
		}
		return imageboard.persistence.getThreadStateIfExists(thread)?.thread?.isArchived ?? false;
	}

	QueuedPost({
		required super.imageboardKey,
		required this.post,
		required super.state
	}) {
		imageboard.listenToReplyPosting(this);
	}
}

class QueuedReport extends QueueEntry<void> {
	final ChoiceReportMethod method;
	final ChoiceReportMethodChoice choice;
	@override
	bool _useLoginSystem;
	@override
	bool get useLoginSystem => _useLoginSystem;

	QueuedReport({
		required super.imageboardKey,
		required this.method,
		required this.choice,
		required bool useLoginSystem,
		required super.state
	}) : _useLoginSystem = useLoginSystem;

	@override
	Future<void> _submitImpl(CaptchaSolution captchaSolution, CancelToken cancelToken) async {
		await method.onSubmit(choice, captchaSolution);
		captchaSolution.dispose();
	}

	@override
	String get _board => method.post.board;

	@override
	ImageboardAction get _action => ImageboardAction.report;

	@override
	bool get isArchived {
		return imageboard.persistence.getThreadStateIfExists(method.post.thread)?.thread?.isArchived ?? false;
	}

	@override
	ThreadIdentifier? get thread => method.post.thread;

	@override
	Future<CaptchaRequest> _getCaptchaRequest() async => method.getCaptchaRequest();
}

class OutboxQueue<T> extends ChangeNotifier {
	final List<QueueEntry<T>> list = [];
	DateTime allowedTimeWifi = DateTime.now();
	DateTime allowedTimeCellular = DateTime.now();
	DateTime get allowedTime {
		if (Settings.instance.isConnectedToWifi) {
			return allowedTimeWifi;
		}
		else {
			return allowedTimeCellular;
		}
	}
	set allowedTime (DateTime newTime) {
		if (Settings.instance.isConnectedToWifi) {
			allowedTimeWifi = newTime;
		}
		else {
			allowedTimeCellular = newTime;
		}
		notifyListeners();
	}
	DateTime captchaAllowedTimeWifi = DateTime.now();
	DateTime captchaAllowedTimeCellular = DateTime.now();
	DateTime get captchaAllowedTime {
		if (Settings.instance.isConnectedToWifi) {
			return captchaAllowedTimeWifi;
		}
		else {
			return captchaAllowedTimeCellular;
		}
	}
	set captchaAllowedTime (DateTime newTime) {
		if (Settings.instance.isConnectedToWifi) {
			captchaAllowedTimeWifi = newTime;
		}
		else {
			captchaAllowedTimeCellular = newTime;
		}
		notifyListeners();
	}
}

class Outbox extends ChangeNotifier {
	static final _instance = Outbox._();
	static Outbox get instance => _instance;
	Outbox._() {
		_lastIsConnectedToWifi = Settings.instance.isConnectedToWifi;
		// No unsubscribing because Outbox never dies
		Settings.instance.addListener(_onSettingsUpdate);
	}

	final _lock = Mutex();
	final Map<QueueEntryActionKey, OutboxQueue> queues = {};
	bool headlessSolveFailed = false;
	bool? _lastIsConnectedToWifi;

	void _onSettingsUpdate() {
		if (_lastIsConnectedToWifi != Settings.instance.isConnectedToWifi) {
			_onConnectionChanged(Settings.instance.isConnectedToWifi);
			_lastIsConnectedToWifi = Settings.instance.isConnectedToWifi;
		}
	}

	void _onConnectionChanged(bool onWifi) {
		final toIdle = queues.values.expand((q) => q.list.where((e) => !e.state.isIdle));
		// Stop all submissions
		for (final e in toIdle) {
			e.cancel();
		}
		// Reset all timers
		for (final queue in queues.values) {
			queue.captchaAllowedTime = DateTime.now();
			queue.allowedTime = DateTime.now();
		}
		final context = ImageboardRegistry.instance.context;
		if (context != null && context.mounted && toIdle.isNotEmpty) {
			showToast(
				context: context,
				message: 'Network changed!',
				icon: CupertinoIcons.wifi_exclamationmark,
				easyButton: ('Resubmit', () {
					for (final e in toIdle) {
						e.submit(null);
					}
				})
			);
		}
	}

	void _onOutboxQueueUpdate() {
		// Some cooldown changed
		Future.microtask(_process);
	}

	Future<void> _process<T>([QueueEntry<T>? newEntry]) => _lock.protect(() async {
		print('Woken up!');
		if (newEntry != null) {
			final queue = queues.putIfAbsent(newEntry._key, () => OutboxQueue<T>()..addListener(_onOutboxQueueUpdate));
			queue.list.add(newEntry);
			if (queue.list.first.state.isIdle) {
				// List was idle, set the cooldown based on new entry type
				final submissionTimes = queue.list.tryMap((e) => e.state._submissionTime).toList();
				if (submissionTimes.isNotEmpty) {
					final newAllowedTime = submissionTimes.reduce((a, b) => a.isAfter(b) ? a : b).add(newEntry._cooldown);
					if (newAllowedTime.isAfter(queue.allowedTime)) {
						queue.allowedTime = newAllowedTime;
					}
				}
			}
		}
		final nextWakeups = <DateTime>[];
		for (final queue in queues.entries) {
			if (queue.value.list.isEmpty) {
				continue;
			}
			if (queue.value.list.every((e) => e.state.isIdle)) {
				continue;
			}
			// Put idle entries at the end
			mergeSort<QueueEntry>(queue.value.list, compare: (a, b) {
				final aIdle = a.state.isIdle;
				final bIdle = b.state.isIdle;
				if (aIdle == bIdle) {
					return 0;
				}
				else if (aIdle) {
					return 1;
				}
				else {
					return -1;
				}
			});
			if (queue.value.captchaAllowedTime.isAfter(DateTime.now()) && queue.value.list.first.state._needsCaptcha) {
				print('Can\'t fill first captcha yet');
				// Need captcha and not allowed yet, go to sleep
				nextWakeups.add(queue.value.captchaAllowedTime);
				continue;
			}
			print('Try filling first captcha');
			// Fill the captcha
			await queue.value.list.first._preSubmit();
			if (queue.value.captchaAllowedTime.isAfter(DateTime.now()) && queue.value.list.first.state._needsCaptcha) {
				print('Got cooldown filling first captcha');
				// Need captcha and not allowed yet, go to sleep
				nextWakeups.add(queue.value.captchaAllowedTime);
				continue;
			}
			if (queue.value.allowedTime.isAfter(DateTime.now())) {
				print('Can\'t submit yet');
				// Can't submit yet, go to sleep
				nextWakeups.add(queue.value.allowedTime);
				continue;
			}
			print('Try submitting first entry');
			// Submit the post
			await queue.value.list.first._submit();
			if (queue.value.list.length > 1 && !queue.value.list[1].state.isIdle) {
				queue.value.allowedTime = DateTime.now().add(queue.value.list[1]._cooldown);
				// Retrigger wakeup immediately to look at next post for captcha purposes
				nextWakeups.add(DateTime.now());
			}
			else {
				// Just use current queue subitem type. It could be corrected if a different subtype is submitted
				queue.value.allowedTime = DateTime.now().add(queue.value.list.first._cooldown);
				// Mainly to notifyListeners() and freshen up widgets that show timer 
				nextWakeups.add(queue.value.allowedTime);
			}
		}
		if (nextWakeups.isNotEmpty) {
			final time = nextWakeups.reduce((a, b) => a.isBefore(b) ? a : b);
			final delay = time.difference(DateTime.now());
			print('Will wake up again in $delay');
			Future.delayed(delay, _process);
		}
		else {
			print('Will not wake up again');
		}
		notifyListeners();
	});

	QueuedPost submitPost(String imageboardKey, DraftPost post, QueueState<PostReceipt> initialState) {
		final entry = QueuedPost(
			imageboardKey: imageboardKey,
			post: post,
			state: initialState
		);
		Future.microtask(() => _process(entry));
		return entry;
	}

	QueuedReport submitReport(BuildContext context, String imageboardKey, ChoiceReportMethod method, ChoiceReportMethodChoice choice, bool useLoginSystem) {
		final entry = QueuedReport(
			imageboardKey: imageboardKey,
			method: method,
			choice: choice,
			state: QueueStateNeedsCaptcha(context),
			useLoginSystem: useLoginSystem
		);
		Future.microtask(() => _process(entry));
		return entry;
	}

	int get submittableCount {
		int count = 0;
		for (final queue in queues.values) {
			for (final entry in queue.list) {
				if (entry.state.isSubmittable) {
					count++;
				}
			}
		}
		return count;
	}

	int get activeCount {
		int count = 0;
		for (final queue in queues.values) {
			for (final entry in queue.list) {
				if (!entry.state.isFinished) {
					count++;
				}
			}
		}
		return count;
	}

	Iterable<QueuedPost> queuedPostsFor(String imageboardKey, String board, int? threadId) sync* {
		for (final queue in queues.values) {
			for (final entry in queue.list) {
				if (entry is QueuedPost &&
				    entry.state is! QueueStateDone<PostReceipt> &&
						entry.imageboardKey == imageboardKey &&
						entry.post.board == board &&
						entry.post.threadId == threadId) {
					yield entry;
				}
			}
		}
	}
}
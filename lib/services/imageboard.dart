

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:chan/models/board.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/captcha.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/outbox.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/share.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/outbox.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mutex/mutex.dart';
import 'package:string_similarity/string_similarity.dart';

class ImageboardNotFoundException implements Exception {
	String board;
	ImageboardNotFoundException(this.board);
	@override
	String toString() => 'Imageboard not found: $board';
}

class Imageboard extends ChangeNotifier {
	dynamic siteData;
	ImageboardSite? _site;
	ImageboardSite get site => _site!;
	late final Persistence persistence;
	late final ThreadWatcher threadWatcher;
	late final Notifications notifications;
	String? setupErrorMessage;
	String? boardFetchErrorMessage;
	bool boardsLoading = false;
	bool initialized = false;
	bool _persistenceInitialized = false;
	bool _threadWatcherInitialized = false;
	bool _notificationsInitialized = false;
	final String key;
	bool get seemsOk => initialized && !(boardsLoading && persistence.boards.isEmpty) && setupErrorMessage == null && boardFetchErrorMessage == null;
	final ThreadWatcherController? threadWatcherController;

	Imageboard({
		required this.key,
		required this.siteData,
		this.threadWatcherController
	});
	
	void updateSiteData(dynamic siteData) {
		try {
			final newSite = makeSite(siteData);
			if (newSite != _site) {
				if (_site != null) {
					newSite.migrateFromPrevious(_site!);
					_site!.dispose();
				}
				_site = newSite;
				site.imageboard = this;
				site.initState();
				notifyListeners();
			}
		}
		catch (e, st) {
			Future.error(e, st); // Crashlytics
			setupErrorMessage = e.toStringDio();
			notifyListeners();
		}
	}

	Future<void> initialize({
		List<String> threadWatcherWatchForStickyOnBoards = const []
	}) async {
		try {
			_site = makeSite(siteData);
			persistence = Persistence(key);
			await persistence.initialize();
			site.imageboard = this;
			_persistenceInitialized = true;
			notifications = Notifications(
				persistence: persistence,
				site: site
			);
			notifications.initialize();
			_notificationsInitialized = true;
			threadWatcher = ThreadWatcher(
				imageboardKey: key,
				site: site,
				persistence: persistence,
				notifications: notifications,
				watchForStickyOnBoards: threadWatcherWatchForStickyOnBoards,
				controller: threadWatcherController ?? ImageboardRegistry.threadWatcherController
			);
			notifications.localWatcher = threadWatcher;
			_threadWatcherInitialized = true;
			if (persistence.boards.isEmpty) {
				await setupBoards();
			}
			site.initState();
			initialized = true;
			for (final draft in persistence.browserState.outbox) {
				final thread = draft.thread;
				if (thread != null) {
					// Load for [title], [isArchived]
					await persistence.getThreadStateIfExists(thread)?.ensureThreadLoaded();
				}
				Outbox.instance.submitPost(key, draft, const QueueStateIdle());
			}
		}
		catch (e, st) {
			setupErrorMessage = e.toStringDio();
			print('Error initializing $key');
			print(e);
			print(st);
		}
		notifyListeners();
	}

	Future<void> deleteAllData() async {
		await notifications.deleteAllNotificationsFromServer();
		await persistence.deleteAllData();
	}

	Future<void> setupBoards() async {
		try {
			boardsLoading = true;
			boardFetchErrorMessage = null;
			notifyListeners();
			final freshBoards = await site.getBoards(priority: RequestPriority.interactive);
			if (freshBoards.isEmpty) {
				throw('No boards found');
			}
			await persistence.storeBoards(freshBoards);
		}
		catch (error, st) {
			print('Error setting up boards for $key');
			print(error);
			print(st);
			boardFetchErrorMessage = error.toStringDio();
		}
		boardsLoading = false;
		notifyListeners();
	}

	Future<List<ImageboardBoard>> refreshBoards() async {
		final freshBoards = await site.getBoards(priority: RequestPriority.interactive);
		await persistence.storeBoards(freshBoards);
		return freshBoards;
	}

	void _maybeShowDubsToast(int id) {
		if (Settings.instance.highlightRepeatingDigitsInPostIds && site.explicitIds) {
			final digits = id.toString();
			int repeatingDigits = 1;
			for (; repeatingDigits < digits.length; repeatingDigits++) {
				if (digits[digits.length - 1 - repeatingDigits] != digits[digits.length - 1]) {
					break;
				}
			}
			if (repeatingDigits > 1) {
				showToast(
					context: ImageboardRegistry.instance.context!,
					icon: CupertinoIcons.hand_point_right,
					message: switch(repeatingDigits) {
						< 3 => 'Dubs GET!',
						3 => 'Trips GET!',
						4 => 'Quads GET!',
						5 => 'Quints GET!',
						6 => 'Sexts GET!',
						7 => 'Septs GET!',
						8 => 'Octs GET!',
						_ => 'Insane GET!!'
					}
				);
			}
		}
	}

	void _listenForSpamFilter(DraftPost submittedPost, PostReceipt receipt) async {
		final threadIdentifier =
			// Reply
			submittedPost.thread ??
			// Thread
			ThreadIdentifier(submittedPost.board, receipt.id);
		final start = DateTime.now();
		final postShowedUpCompleter = Completer<bool>();
		final listenable = persistence.listenForPersistentThreadStateChanges(threadIdentifier);
		Future.delayed(const Duration(seconds: 12), () {
			if (!postShowedUpCompleter.isCompleted) {
				threadWatcher.updateThread(threadIdentifier);
			}
		});
		void listener() {
			final threadState = persistence.getThreadStateIfExists(threadIdentifier);
			bool? found;
			for (final post in threadState?.thread?.posts_.reversed ?? <Post>[]) {
				if (post.id > receipt.id) {
					found = false;
				}
				else if (post.id == receipt.id) {
					final similarity = post.span.buildText().similarityTo(submittedPost.text);
					found = similarity > 0.65;
					break;
				}
				else {
					// post.id < receipt.id
					break;
				}
			}
			if (found != null) {
				// Post is certainly there or not
				postShowedUpCompleter.complete(found);
			}
			else if (DateTime.now().difference(start) > const Duration(seconds: 12)) {
				// On first update after 12 seconds, give up
				postShowedUpCompleter.complete(false);
			}
		}
		listenable.addListener(listener);
		final postShowedUp = await Future.any<bool>([
			postShowedUpCompleter.future,
			Future.delayed(const Duration(seconds: 20), () => false)
		]);
		listenable.removeListener(listener);
		if (postShowedUp) {
			receipt.spamFiltered = false;
			showToast(
				context: ImageboardRegistry.instance.context!,
				message: 'Post successful',
				icon: CupertinoIcons.smiley,
				hapticFeedback: false
			);
			_maybeShowDubsToast(receipt.id);
		}
		else {
			receipt.spamFiltered = true;
			persistence.didUpdateBrowserState();
			// Put it back in the Outbox, also don't remove it from persistence.outbox
			Outbox.instance.submitPost(key, submittedPost, const QueueStateIdle());
			showToast(
				context: ImageboardRegistry.instance.context!,
				message: '${submittedPost.threadId == null ? 'Thread' : 'Post'} spam-filtered',
				icon: CupertinoIcons.exclamationmark_shield,
				easyButton: ('More info', () => alertError(
					ImageboardRegistry.instance.context!,
					'Your ${submittedPost.threadId == null ? 'thread' : 'post'} seems to have been blocked by ${site.name}\'s anti-spam firewall.\nIt has been restored as a draft for you to try again.',
					barrierDismissible: true
				)),
				hapticFeedback: false
			);
		}
	}

	void listenToReplyPosting(QueuedPost post) {
		QueueState<PostReceipt>? lastState;
		void listener() async {
			final state = post.state;
			if (state == lastState) {
				// Sometimes notifyListeners() just used to internally rebuild
				return;
			}
			lastState = state;
			if (state is QueueStateDeleted<PostReceipt>) {
				// Don't remove listener, in case undeleted
				// Who cares about a leak....
				return;
			}
			if (state is QueueStateDone<PostReceipt>) {
				post.removeListener(listener);
				onSuccessfulCaptchaSubmitted(state.captchaSolution);
				print(state.result);
				mediumHapticFeedback();
				if (state.result.spamFiltered) {
					showToast(
						context: ImageboardRegistry.instance.context!,
						message: 'Spam-filter possible...',
						icon: CupertinoIcons.question_diamond,
						hapticFeedback: false
					);
					_listenForSpamFilter(post.post, state.result);
				}
				else {
					showToast(
						context: ImageboardRegistry.instance.context!,
						message: 'Post successful',
						icon: state.captchaSolution.autoSolved ? CupertinoIcons.checkmark_seal : CupertinoIcons.check_mark,
						hapticFeedback: false
					);
					_maybeShowDubsToast(state.result.id);
					if (state.captchaSolution.autoSolved && (Settings.instance.useCloudCaptchaSolver ?? false) && (Settings.instance.useHeadlessCloudCaptchaSolver == null)) {
						Settings.useHeadlessCloudCaptchaSolverSetting.value = await showAdaptiveDialog<bool>(
							context: ImageboardRegistry.instance.context!,
							barrierDismissible: true,
							builder: (context) => AdaptiveAlertDialog(
								title: const Text('Skip captcha confirmation?'),
								content: const Text('Cloud captcha solutions will be submitted directly without showing a popup and asking for confirmation.'),
								actions: [
									AdaptiveDialogAction(
										isDefaultAction: true,
										child: const Text('Skip confirmation'),
										onPressed: () {
											Navigator.of(context).pop(true);
										},
									),
									AdaptiveDialogAction(
										child: const Text('No'),
										onPressed: () {
											Navigator.of(context).pop(false);
										}
									)
								]
							)
						);
					}
				}
			}
			else if (state is QueueStateFailed<PostReceipt>) {
				final e = state.error;
				final bannedCaptchaRequest = post.site.getBannedCaptchaRequest(state.captchaSolution?.cloudflare ?? false);
				if (e is BannedException && bannedCaptchaRequest != null) {
					await showAdaptiveDialog(
						context: ImageboardRegistry.instance.context!,
						builder: (context) {
							return AdaptiveAlertDialog(
								title: const Text('Error'),
								content: Text(e.toStringDio()),
								actions: [
									AdaptiveDialogAction(
										child: const Text('See reason'),
										onPressed: () async {
											final solution = await solveCaptcha(
												context: context,
												site: post.site,
												request: bannedCaptchaRequest
											);
											if (solution != null) {
												final reason = await post.site.getBannedReason(solution);
												if (!context.mounted) return;
												alertError(context, reason);
											}
											solution?.dispose();
										}
									),
									AdaptiveDialogAction(
										child: const Text('Clear cookies'),
										onPressed: () {
											Persistence.clearCookies(fromWifi: null);
										}
									),
									AdaptiveDialogAction(
										child: const Text('OK'),
										onPressed: () {
											Navigator.of(context).pop();
										}
									)
								]
							);
						}
					);
				}
				else if (e is WebAuthenticationRequiredException) {
					alertError(ImageboardRegistry.instance.context!, 'Web authentication required\n\nMaking a post via the website is required to whitelist your IP for posting via Chance.', actions: {
						'Go to web': () => shareOne(
							context: ImageboardRegistry.instance.context!,
							text: post.site.getWebUrl(
								board: post.post.board,
								threadId: post.post.threadId
							),
							type: 'text',
							sharePositionOrigin: null
						)
					});
				}
				else {
					if (e.toStringDio().toLowerCase().contains('captcha')) {
						// Captcha didn't work. For now, let's disable the auto captcha solver
						Outbox.instance.headlessSolveFailed = true;
					}
					alertError(ImageboardRegistry.instance.context!, e.toStringDio(), actions: {
						'Open outbox': () => showOutboxModalForThread(
							context: ImageboardRegistry.instance.context!,
							imageboardKey: key,
							board: post.post.board,
							threadId: post.post.threadId,
							canPopWithDraft: false
						)
					});
				}
			}
		}
		post.addListener(listener);
		listener();
	}

	Future<PostReceipt> submitPost(DraftPost post, CaptchaSolution captchaSolution, dio.CancelToken cancelToken) async {
		final path = post.file;
		if (path != null && !File(path).existsSync()) {
			throw Exception('Selected file not found: $path');
		}
		persistence.browserState.outbox.add(post); // For restoration if app is closed
		runWhenIdle(const Duration(milliseconds: 500), persistence.didUpdateBrowserState);
		final receipt = await site.submitPost(post, captchaSolution, cancelToken);
		persistence.browserState.outbox.remove(post);
		runWhenIdle(const Duration(milliseconds: 500), persistence.didUpdateBrowserState);
		final thread = ThreadIdentifier(post.board, post.threadId ?? receipt.id);
		final persistentState = persistence.getThreadState(thread);
		persistentState.receipts = [...persistentState.receipts, receipt];
		persistentState.didUpdateYourPosts();
		final settings = Settings.instance;
		if (settings.watchThreadAutomaticallyWhenReplying) {
			notifications.subscribeToThread(
				thread: thread,
				lastSeenId: receipt.id,
				localYousOnly: (persistentState.threadWatch ?? settings.defaultThreadWatch)?.localYousOnly ?? post.threadId != null,
				pushYousOnly: (persistentState.threadWatch ?? settings.defaultThreadWatch)?.pushYousOnly ?? post.threadId != null,
				foregroundMuted: (persistentState.threadWatch ?? settings.defaultThreadWatch)?.foregroundMuted ?? false,
				push: (persistentState.threadWatch ?? settings.defaultThreadWatch)?.push ?? true,
				youIds: persistentState.freshYouIds()
			);
		}
		if (settings.saveThreadAutomaticallyWhenReplying) {
			persistentState.savedTime ??= DateTime.now();
		}
		await persistentState.save();
		return receipt;
	}

	@override
	void dispose() {
		super.dispose();
		if (_threadWatcherInitialized) {
			threadWatcher.dispose();
		}
		if (_persistenceInitialized) {
			persistence.dispose();
		}
		if (_notificationsInitialized) {
			notifications.dispose();
		}
	}

	ImageboardScoped<T> scope<T>(T item) => ImageboardScoped(
		imageboard: this,
		item: item
	);

	@override
	String toString() => 'Imageboard($key)';
}

const _devImageboardKey = 'devsite';

class ImageboardRegistry extends ChangeNotifier {
	static ImageboardRegistry? _instance;
	static ImageboardRegistry get instance {
		_instance ??= ImageboardRegistry._();
		return _instance!;
	}

	ImageboardRegistry._();
	
	String? setupError;
	String? setupStackTrace;
	final Map<String, Imageboard> _sites = {};
	int get count => _sites.length;
	Iterable<Imageboard> get imageboardsIncludingUninitialized => _sites.values;
	Iterable<Imageboard> get imageboards => _sites.values.where((s) => s.initialized);
	bool initialized = false;
	BuildContext? context;
	final _mutex = Mutex();
	static final threadWatcherController = ThreadWatcherController();
	Imageboard? dev;

	Future<void> initializeDev() async {
		dev?.dispose();
		final tmpDev = dev = Imageboard(
			key: _devImageboardKey,
			siteData: defaultSite,
			threadWatcherController: ThreadWatcherController(interval: const Duration(minutes: 10))
		);
		await tmpDev.initialize(
			threadWatcherWatchForStickyOnBoards: ['chance']
		);
		notifyListeners();
	}

	Future<void> handleSites({
		required Map<String, Map> sites,
		required Set<String> keys,
		required BuildContext context
	}) {
		return _mutex.protect(() async {
			context = context;
			setupError = null;
			try {
				final siteKeysToRemove = _sites.keys.toList();
				final initializations = <Future<void>>[];
				final microtasks = <Future<void> Function()>[];
				final yourSites = sites.entries.where((e) => keys.contains(e.key));
				if (yourSites.isEmpty) {
					throw Exception('No site data available for $keys');
				}
				for (final entry in yourSites) {
					siteKeysToRemove.remove(entry.key);
					if (_sites.containsKey(entry.key)) {
						// Site not changed
						_sites[entry.key]?.updateSiteData(entry.value);
					}
					else {
						_sites[entry.key] = Imageboard(
							siteData: entry.value,
							key: entry.key
						);
						initializations.add(_sites[entry.key]!.initialize());
					}
					// Only try to reauth on wifi
					microtasks.add(() async {
						if (!_sites[entry.key]!.initialized) {
							return;
						}
						final site = _sites[entry.key]!.site;
						final savedFields = site.loginSystem?.getSavedLoginFields();
						if (savedFields != null && Settings.instance.isConnectedToWifi) {
							try {
								await site.loginSystem!.login(null, savedFields);
								print('Auto-logged-in to ${site.loginSystem?.name}');
							}
							catch (e) {
								if (context.mounted) {
									showToast(
										context: context,
										icon: CupertinoIcons.exclamationmark_triangle,
										message: 'Failed to log in to ${site.loginSystem?.name}'
									);
								}
								print('Problem auto-logging-in to ${site.loginSystem?.name}: $e');
							}
						}
					});
				}
				await Future.wait(initializations);
				microtasks.forEach(Future.microtask);
				final initialTabsLength = Persistence.tabs.length;
				final initialTab = Persistence.tabs[Persistence.currentTabIndex];
				final initialTabIndex = Persistence.currentTabIndex;
				for (final key in siteKeysToRemove) {
					_sites[key]?.dispose();
					_sites.remove(key);
					Persistence.tabs.removeWhere((t) => t.imageboardKey == key);
				}
				if (Persistence.tabs.contains(initialTab)) {
					Persistence.currentTabIndex = Persistence.tabs.indexOf(initialTab);
				}
				else if (Persistence.tabs.isEmpty) {
					Persistence.tabs.add(PersistentBrowserTab());
					Persistence.currentTabIndex = 0;
				}
				else {
					Persistence.currentTabIndex = min(Persistence.tabs.length - 1, initialTabIndex);
				}
				await Future.wait(Persistence.tabs.map((tab) => tab.initialize()));
				if (initialTabsLength != Persistence.tabs.length) {
					Persistence.saveTabs();
				Persistence.globalTabMutator.value = Persistence.currentTabIndex;
				}
			}
			catch (e, st) {
				setupError = 'Fatal setup error\n${e.toStringDio()}';
				setupStackTrace = st.toStringDio();
				print(e);
				print(st);
			}
			initialized = true;
			notifyListeners();
		});
	}

	Imageboard? getImageboard(String? key) {
		if (key == null) {
			return null;
		}
		if (key == _devImageboardKey) {
			return dev;
		}
		if (_sites[key]?.initialized == true) {
			return _sites[key];
		}
		return null;
	}

	Imageboard? getImageboardUnsafe(String key) {
		if (key == _devImageboardKey) {
			return dev;
		}
		return _sites[key];
	}

	Future<void> retryFailedBoardSetup() async {
		final futures = <Future>[];
		for (final i in imageboards) {
			if (i.boardFetchErrorMessage != null) {
				futures.add(i.setupBoards());
			}
		}
		await Future.wait(futures);
	}

	Future<(Imageboard, BoardThreadOrPostIdentifier, bool)?> decodeUrl(String url) async {
		for (final imageboard in ImageboardRegistry.instance.imageboards) {
			BoardThreadOrPostIdentifier? dest = await imageboard.site.decodeUrl(url);
			bool usedArchive = false;
			for (final archive in imageboard.site.archives) {
				if (dest != null) {
					break;
				}
				dest = await archive.decodeUrl(url);
				usedArchive = true;
			}
			if (dest != null) {
				return (imageboard, dest, usedArchive);
			}
		}
		return null;
	}

	Future<void> clearAllPseudoCookies() async {
		for (final i in imageboards) {
			await i.site.clearPseudoCookies();
		}
	}
}

class ImageboardScoped<T> {
	final Imageboard imageboard;
	final T item;

	ImageboardScoped({
		required this.imageboard,
		required this.item
	});

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		(other is ImageboardScoped) &&
		(other.imageboard == imageboard) &&
		(other.item == item);
	@override
	int get hashCode => Object.hash(imageboard, item);

	@override
	String toString() => 'ImageboardScoped(${imageboard.key}, $item)';
}
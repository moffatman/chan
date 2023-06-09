import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chan/main.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/apple.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/version.dart';
import 'package:chan/widgets/cupertino_dialog.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_apns_only/flutter_apns_only.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:unifiedpush/unifiedpush.dart';

abstract class PushNotification {
	final PostIdentifier target;
	const PushNotification({
		required this.target
	});
	bool get isThread => target.threadId == target.postId;
}

class ThreadWatchNotification extends PushNotification {
	const ThreadWatchNotification({
		required super.target
	});
}

class BoardWatchNotification extends PushNotification {
	final String filter;

	const BoardWatchNotification({
		required super.target,
		required this.filter
	});
}

abstract class _NotificationsToken {
	Map<String, String> toMap();	
}

class _ApnsNotificationsToken implements _NotificationsToken {
	final String token;
	final bool isProduction;
	const _ApnsNotificationsToken(this.token, this.isProduction);

	@override
	Map<String, String> toMap() => {
		'type': isProduction ? 'apns-prod' : 'apns-sandbox',
		'token': token
	};
}

class _UnifiedPushNotificationsToken implements _NotificationsToken {
	final String endpoint;
	const _UnifiedPushNotificationsToken(this.endpoint);

	@override
	Map<String, String> toMap() => {
		'type': 'up',
		'endpoint': endpoint
	};
}

const _platform = MethodChannel('com.moffatman.chan/notifications');

Future<void> promptForPushNotificationsIfNeeded(BuildContext context) async {
	final settings = context.read<EffectiveSettings>();
	if (settings.usePushNotifications == null) {
		final choice = await showCupertinoDialog<bool>(
			context: context,
			builder: (context) => CupertinoAlertDialog2(
				title: const Text('Use push notifications?'),
				content: const Text('Notifications for (You)s will be sent while the app is closed.\nFor this to work, the thread IDs you want to be notified about will be sent to a notification server.'),
				actions: [
					CupertinoDialogAction2(
						child: const Text('No'),
						onPressed: () {
							Navigator.of(context).pop(false);
						}
					),
					CupertinoDialogAction2(
						child: const Text('Yes'),
						onPressed: () {
							Navigator.of(context).pop(true);
						}
					)
				]
			)
		);
		if (choice != null) {
			settings.usePushNotifications = choice;
		}
	}
}

Future<void> clearNotifications(Notifications notifications, Watch watch) async {
	await _platform.invokeMethod('clearNotificationsWithProperties', {
		'userId': notifications.id,
		'type': watch.type,
		if (watch is BoardWatch) ...{
			'board': watch.board
		}
		else if (watch is ThreadWatch) ...{
			'board': watch.board,
			'threadId': watch.threadId.toString()
		}
	});
}

Future<void> updateNotificationsBadgeCount() async {
	if (!Platform.isIOS) {
		return;
	}
	try {
		await _platform.invokeMethod('updateBadge');
	}
	catch (e, st) {
		print(e);
		print(st);
	}
}

const _notificationSettingsApiRoot = 'https://push.chance.surf';

class Notifications {
	static String? staticError;
	String? error;
	static final Map<String, Notifications> _children = {};
	final tapStream = BehaviorSubject<PostIdentifier>();
	final foregroundStream = BehaviorSubject<PushNotification>();
	final Persistence persistence;
	ThreadWatcher? localWatcher;
	final String siteType;
	final String siteData;
	String get id => persistence.browserState.notificationsId;
	Map<ThreadIdentifier, ThreadWatch> get threadWatches => persistence.browserState.threadWatches;
	List<BoardWatch> get boardWatches => persistence.browserState.boardWatches;
	static final Map<String, List<Map<String, dynamic>>> _unrecognizedByUserId = {};
	static ApnsPushConnectorOnly? _apnsConnector;
	static final List<Completer<String>> _unifiedPushNewEndpointCompleters = [];
	static final _client = Dio(BaseOptions(
		headers: {
			HttpHeaders.userAgentHeader: 'Chance/$kChanceVersion'
		}
	));

	Notifications({
		required ImageboardSite site,
		required this.persistence
	}) : siteType = site.siteType,
		siteData = site.siteData;

	@override
	String toString() => 'Notifications(siteType: $siteType, id: $id, tapStream: $tapStream)';

	static Future<void> _onMessage(Map messageData) async {
		final data = messageData.cast<String, String>();
		print('_onMessage');
		print(data);
		if (data.containsKey('threadId') && data.containsKey('userId')) {
			final child = _children[data['userId']];
			if (child == null) {
				print('Opened via message with unknown userId: $data');
				return;
			}
			PushNotification notification;
			if (data['type'] == 'thread') {
				notification = ThreadWatchNotification(
					target: PostIdentifier(data['board']!, int.parse(data['threadId']!), int.parse(data['postId']!))
				);
			}
			else if (data['type'] == 'board') {
				notification = BoardWatchNotification(
					target: PostIdentifier(data['board']!, int.parse(data['threadId']!), int.parse(data['postId']!)),
					filter: data['filter']!
				);
			}
			else {
				throw Exception('Unknown notification type ${data['type']}');
			}
			await child.localWatcher?.updateThread(notification.target.thread);
			if (child.getThreadWatch(notification.target.thread)?.foregroundMuted != true) {
				child.foregroundStream.add(notification);
			}
		}
	}

	@pragma('vm:entry-point')
	static void _onMessageOpenedApp(Map messageData) {
		final data = messageData.cast<String, String>();
		print('_onMessageOpenedApp');
		print(data);
		Future.delayed(const Duration(seconds: 1), updateNotificationsBadgeCount);
		final child = _children[data['userId']];
		if (child == null) {
			print('Opened via message with unknown userId: $data');
			_unrecognizedByUserId.update(data['userId']!, (list) => list..add(data), ifAbsent: () => [data]);
			return;
		}
		if (data['type'] == 'thread' || data['type'] == 'board') {
			child.tapStream.add(PostIdentifier(
				data['board']!,
				int.parse(data['threadId']!),
				int.parse(data['postId']!)
			));
		}
	}

	@pragma('vm:entry-point')
	static Future<void> onNewUnifiedPushEndpoint(String endpoint, String instance) async {
		Persistence.settings.lastUnifiedPushEndpoint = endpoint;
		for (final completer in _unifiedPushNewEndpointCompleters) {
			completer.complete(endpoint);
		}
		_unifiedPushNewEndpointCompleters.clear();
		await _reinitializeChildren();
	}

	@pragma('vm:entry-point')
	static Future<void> onUnifiedPushUnregistered(String instance) async {
		Persistence.settings.lastUnifiedPushEndpoint = null;
		_reinitializeChildren();
	}

	@pragma('vm:entry-point')
	static Future<void> onUnifiedPushMessage(Uint8List message, String instance) async {
		final data = json.decode(utf8.decode(message));
		if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
			_onMessage(data['data']);
		}
		else {
			FlutterLocalNotificationsPlugin().show(
				int.parse(data['data']['postId']),
				data['title'],
				data['body'],
				const NotificationDetails(
					android: AndroidNotificationDetails(
						'up', 'Unified Push',
						importance: Importance.high,
						priority: Priority.high
					)
				),
				payload: json.encode(data['data'])
			);
		}
	}

	@pragma('vm:entry-point')
	static Future<void> onAPNSLaunch(ApnsRemoteMessage message) async {
		_onMessageOpenedApp(message.payload['data']);
	}

	@pragma('vm:entry-point')
	static Future<void> onAPNSMessage(ApnsRemoteMessage message) async {
		_onMessage(message.payload['data']);
	}

	@pragma('vm:entry-point')
	static Future<void> onAPNSResume(ApnsRemoteMessage message) async {
		_onMessageOpenedApp(message.payload['data']);
	}

	@pragma('vm:entry-point')
	static Future<void> _onLocalNotificationTapped(NotificationResponse response) async {
		_onMessageOpenedApp(json.decode(response.payload!));
	}

	@pragma('vm:entry-point')
	static Future<void> _onBackgroundLocalNotificationTapped(NotificationResponse response) async {
		print('_onBackgroundLocalNotificationTapped(response: $response)');
	}

	static Future<String> _waitForNextUnifiedPushEndpoint() {
		final completer = Completer<String>();
		_unifiedPushNewEndpointCompleters.add(completer);
		return completer.future;
	}

	static Future<void> tryUnifiedPushDistributor(String distributor) async {
		final future = _waitForNextUnifiedPushEndpoint();
		await UnifiedPush.saveDistributor(distributor);
		await UnifiedPush.registerApp();
		await future.timeout(const Duration(milliseconds: 300), onTimeout: () async {
			await UnifiedPush.unregister();
			throw TimeoutException('Distributor did not provide an endpoint');
		});
	}

	static Future<void> registerUnifiedPush() async {
		if ((await UnifiedPush.getDistributor()).isNotEmpty) {
			return;
		}
		final distributors = await UnifiedPush.getDistributors();
		if (distributors.length == 1) {
			await UnifiedPush.saveDistributor(distributors.single);
			await UnifiedPush.registerApp();
		}
		for (final distributor in distributors) {
			try {
				await tryUnifiedPushDistributor(distributor);
				return;
			}
			on TimeoutException {
				print('UnifiedPush timed out waiting for $distributor endpoint');
			}
		}
	}

	static Future<void> initializeStatic() async {
		try {
			staticError = null;
			settings.filterListenable.addListener(_didUpdateFilter);
			if (Platform.isAndroid) {
				await FlutterLocalNotificationsPlugin().initialize(
					const InitializationSettings(
						android: AndroidInitializationSettings('@drawable/ic_stat_clover')
					),
					onDidReceiveNotificationResponse: _onLocalNotificationTapped,
					onDidReceiveBackgroundNotificationResponse: _onBackgroundLocalNotificationTapped
				);
				await UnifiedPush.initialize(
					onNewEndpoint: onNewUnifiedPushEndpoint,
					onUnregistered: onUnifiedPushUnregistered,
					onMessage: onUnifiedPushMessage
				);
				if (Persistence.settings.usePushNotifications ?? false) {
					if (Persistence.settings.lastUnifiedPushEndpoint == null) {
						// Force re-register of URL
						await UnifiedPush.unregister();
					}
					await registerUnifiedPush();
					if (Persistence.settings.lastUnifiedPushEndpoint == null) {
						try {
							await _waitForNextUnifiedPushEndpoint().timeout(const Duration(milliseconds: 300));
						}
						on TimeoutException {
							// Throw async to report to crashlytics
							Future.error(TimeoutException('Timed out waiting for initial UnifiedPush endpoint'));
						}
					}
				}
				final initial = await FlutterLocalNotificationsPlugin().getNotificationAppLaunchDetails();
				if (initial?.didNotificationLaunchApp ?? false) {
					_onMessageOpenedApp(json.decode(initial!.notificationResponse!.payload!));
				}
			}
			else if (Platform.isIOS || Platform.isMacOS) {
				_apnsConnector = ApnsPushConnectorOnly();
				_apnsConnector!.configureApns(
					onLaunch: onAPNSLaunch,
					onMessage: onAPNSMessage,
					onResume: onAPNSResume,
				);
				if (Persistence.settings.usePushNotifications == true) {
					await _apnsConnector!.requestNotificationPermissions();
				}
			}
		}
		catch (e, st) {
			print('Error initializing notifications: $e');
			print(st);
			staticError = e.toStringDio();
		}
	}

	static Future<void> didUpdateUsePushNotificationsSetting() async {
		if (Persistence.settings.usePushNotifications == true) {
			if (Platform.isIOS || Platform.isMacOS) {
				await _apnsConnector?.requestNotificationPermissions();
			}
			else if (Platform.isAndroid) {
				await registerUnifiedPush();
			}
		}
		else if (Persistence.settings.usePushNotifications == false) {
			if (Platform.isIOS || Platform.isMacOS) {
				await _apnsConnector?.unregister();
			}
			else if (Platform.isAndroid) {
				await UnifiedPush.unregister();
			}
		}
		await _reinitializeChildren();
	}

	static Future<void> _didUpdateFilter() async {
		if (Persistence.settings.usePushNotifications == true) {
			await _reinitializeChildren();
		}
	}

	static Future<void> _reinitializeChildren() async {
		await Future.wait(_children.values.map((c) => c.initialize()));
	}

	static Future<_NotificationsToken?> _getToken() async {
		if (Platform.isAndroid) {
			final endpoint = Persistence.settings.lastUnifiedPushEndpoint;
			if (endpoint != null) {
				return _UnifiedPushNotificationsToken(endpoint);
			}
		}
		else if (Platform.isIOS || Platform.isMacOS) {
			final token = _apnsConnector?.token.value;
			if (token != null) {
				return _ApnsNotificationsToken(token, !isDevelopmentBuild);
			}
		}
		return null;
	}

	String _calculateDigest() {
		final boards = [
			...threadWatches.values.where((w) => !w.zombie && w.push).map((w) => w.board),
			...boardWatches.map((w) => w.board)
		];
		boards.sort((a, b) => a.compareTo(b));
		return base64Encode(md5.convert(boards.join(',').codeUnits).bytes);
	}

	Future<void> deleteAllNotificationsFromServer() async {
		final response = await _client.patch('$_notificationSettingsApiRoot/user/$id', data: jsonEncode({
			'token2': (await _getToken())?.toMap(),
			'siteType': siteType,
			'siteData': siteData,
			'filters': ''
		}));
		final String digest = response.data['digest'];
		final emptyDigest = base64Encode(md5.convert(''.codeUnits).bytes);
		if (digest != emptyDigest) {
			print('Need to resync notifications $id');
			await _client.put('$_notificationSettingsApiRoot/user/$id', data: jsonEncode({
				'watches': []
			}));
		}
	}

	Future<void> initialize() async {
		_children[id] = this;
		try {
			if (Persistence.settings.usePushNotifications == true) {
				final response = await _client.patch('$_notificationSettingsApiRoot/user/$id', data: jsonEncode({
					'token2': (await _getToken())?.toMap(),
					'siteType': siteType,
					'siteData': siteData,
					'filters': settings.filterConfiguration
				}));
				final String digest = response.data['digest'];
				if (digest != _calculateDigest()) {
					print('Need to resync notifications $id');
					await _client.put('$_notificationSettingsApiRoot/user/$id', data: jsonEncode({
						'watches': [
							...threadWatches.values.where((w) => !w.zombie),
							...boardWatches
						].map((w) => w.toMap()).toList()
					}));
				}
			}
			else {
				await deleteAllNotificationsFromServer();
			}
			if (_unrecognizedByUserId.containsKey(id)) {
				_unrecognizedByUserId[id]?.forEach(_onMessageOpenedApp);
				_unrecognizedByUserId[id]?.clear();
			}
			error = null;
		}
		catch (e) {
			print('Error initializing notifications: $e');
			error = e.toStringDio();
		}
	}

	ThreadWatch? getThreadWatch(ThreadIdentifier thread) {
		return threadWatches[thread];
	}
	
	BoardWatch? getBoardWatch(String boardName) {
		return boardWatches.tryFirstWhere((w) => w.board == boardName);
	}

	void subscribeToThread({
		required ThreadIdentifier thread,
		required int lastSeenId,
		required bool localYousOnly,
		required bool pushYousOnly,
		required bool push,
		required List<int> youIds,
		bool foregroundMuted = false
	}) {
		final existingWatch = threadWatches[thread];
		if (existingWatch != null) {
			existingWatch.youIds = youIds;
			existingWatch.lastSeenId = lastSeenId;
			didUpdateWatch(existingWatch);
		}
		else {
			final watch = ThreadWatch(
				board: thread.board,
				threadId: thread.id,
				lastSeenId: lastSeenId,
				localYousOnly: localYousOnly,
				pushYousOnly: pushYousOnly,
				youIds: youIds,
				push: push,
				foregroundMuted: foregroundMuted
			);
			threadWatches[thread] = watch;
			if (Persistence.settings.usePushNotifications == true && watch.push) {
				_create(watch);
			}
			localWatcher?.onWatchUpdated(watch);
			persistence.didUpdateBrowserState();
		}
	}

void subscribeToBoard({
		required String boardName,
		required bool threadsOnly
	}) {
		final existingWatch = getBoardWatch(boardName);
		if (existingWatch != null) {
			existingWatch.threadsOnly = threadsOnly;
			didUpdateWatch(existingWatch);
		}
		else {
			final watch = BoardWatch(
				board: boardName,
				threadsOnly: threadsOnly
			);
			boardWatches.add(watch);
			if (Persistence.settings.usePushNotifications == true && watch.push) {
				_create(watch);
			}
			localWatcher?.onWatchUpdated(watch);
			persistence.didUpdateBrowserState();
		}
	}

	void unsubscribeFromThread(ThreadIdentifier thread) {
		final watch = getThreadWatch(thread);
		if (watch != null) {
			removeWatch(watch);
		}
	}

	void unsubscribeFromBoard(String boardName) {
		final watch = getBoardWatch(boardName);
		if (watch != null) {
			removeWatch(watch);
		}
	}

	void foregroundMuteThread(ThreadIdentifier thread) {
		final watch = getThreadWatch(thread);
		if (watch != null) {
			watch.foregroundMuted = true;
			localWatcher?.onWatchUpdated(watch);
			persistence.didUpdateBrowserState();
		}
	}

	void foregroundUnmuteThread(ThreadIdentifier thread) {
		final watch = getThreadWatch(thread);
		if (watch != null) {
			watch.foregroundMuted = false;
			localWatcher?.onWatchUpdated(watch);
			persistence.didUpdateBrowserState();
		}
	}

	void didUpdateWatch(Watch watch, {bool possiblyDisabledPush = false}) {
		if (Persistence.settings.usePushNotifications == true && watch.push) {
			_replace(watch);
		}
		else if (possiblyDisabledPush) {
			_delete(watch);
		}
		localWatcher?.onWatchUpdated(watch);
		persistence.didUpdateBrowserState();
	}

	void zombifyThreadWatch(ThreadWatch watch) {
		if (Persistence.settings.usePushNotifications == true && watch.push) {
			_delete(watch);
		}
		watch.zombie = true;
		localWatcher?.onWatchUpdated(watch);
		persistence.didUpdateBrowserState();
	}

	Future<void> removeWatch(Watch watch) async {
		if (Persistence.settings.usePushNotifications == true && watch.push) {
			_delete(watch);
		}
		if (watch is ThreadWatch) {
			threadWatches.remove(watch);
		}
		else if (watch is BoardWatch) {
			boardWatches.remove(watch);
		}
		localWatcher?.onWatchRemoved(watch);
		persistence.didUpdateBrowserState();
		await clearNotifications(this, watch);
		clearOverlayNotifications(this, watch);
		await updateNotificationsBadgeCount();
	}

	Future<void> updateLastKnownId(ThreadWatch watch, int lastKnownId, {bool foreground = false}) async {
		if (foreground && WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
			await clearNotifications(this, watch);
			clearOverlayNotifications(this, watch);
			await updateNotificationsBadgeCount();
		}
		final couldUpdate = watch.lastSeenId != lastKnownId;
		watch.lastSeenId = lastKnownId;
		if (couldUpdate && Persistence.settings.usePushNotifications == true && watch.push) {
			_update(watch);
		}
	}

	Future<void> _create(Watch watch) async {
		await _client.post(
			'$_notificationSettingsApiRoot/user/$id/watch',
			data: jsonEncode(watch.toMap())
		);
	}

	Future<void> _replace(Watch watch) async {
		if (watch.push) {
			await _client.put(
				'$_notificationSettingsApiRoot/user/$id/watch',
				data: jsonEncode(watch.toMap())
			);
		}
		else {
			await _delete(watch);
		}
	}

	Future<void> _update(Watch watch) async {
		await _client.patch(
			'$_notificationSettingsApiRoot/user/$id/watch',
			data: jsonEncode(watch.toMap())
		);
	}

	Future<void> _delete(Watch watch) async {
		await _client.delete(
			'$_notificationSettingsApiRoot/user/$id/watch',
			data: jsonEncode(watch.toMap())
		);
	}

	void dispose() {
		tapStream.close();
		foregroundStream.close();
	}
}
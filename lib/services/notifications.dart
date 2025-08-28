import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chan/main.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/apple.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/network_logging.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/version.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_apns_only/flutter_apns_only.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:unifiedpush/unifiedpush.dart';

sealed class PushNotification {
	final ThreadOrPostIdentifier target;
	const PushNotification({
		required this.target
	});
}

class ThreadWatchNotification extends PushNotification {
	const ThreadWatchNotification({
		required super.target
	});
}

class ThreadWatchPageNotification extends PushNotification {
	final int page;
	const ThreadWatchPageNotification({
		required super.target,
		required this.page
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

const kPushNotificationsHelp =
	'Notifications for (You)s will be sent while the app is closed.\n'
	'For this to work, the thread IDs you want to be notified about will be sent to a notification server.\n'
	'No personal data will be retained on the server.';

Future<void> promptForPushNotificationsIfNeeded(BuildContext context) async {
	final settings = Settings.instance;
	if (settings.usePushNotifications == null) {
		final choice = await showAdaptiveDialog<bool>(
			context: context,
			builder: (context) => AdaptiveAlertDialog(
				title: const Text('Use push notifications?'),
				content: const Text(kPushNotificationsHelp),
				actions: [
					AdaptiveDialogAction(
						child: const Text('No'),
						onPressed: () {
							Navigator.of(context).pop(false);
						}
					),
					AdaptiveDialogAction(
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
//const _notificationSettingsApiRoot = 'http://localhost:3001';
const _kProtocolVersion = 1;

class Notifications {
	static final Map<String, Notifications> _children = {};
	/// This must not be .broadcast(), we need the buffering feature as we add items early.
	final tapStream = StreamController<ThreadOrPostIdentifier>();
	final foregroundStream = StreamController<PushNotification>.broadcast();
	final Imageboard imageboard;
	Persistence get persistence => imageboard.persistence;
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
		},
		requestEncoder: (request, options) {
			if (!options.headers.containsValue(HttpHeaders.contentEncodingHeader)) {
				options.headers[HttpHeaders.contentEncodingHeader] = 'gzip';
				return gzip.encode(utf8.encode(request));
			}
			return utf8.encode(request);
		}
	));

	Notifications({
		required ImageboardSite site,
		required this.imageboard
	}) : siteType = site.siteType,
		siteData = site.siteData;

	@override
	String toString() => 'Notifications(siteType: $siteType, id: $id, tapStream: $tapStream)';

	/// iOS 18 has a known issue where foreground messages are received twice
	static final List<Map> _previousMessageDatas = [];
	static Future<void> _onMessage(Map messageData) async {
		final data = messageData.cast<String, String>();
		print('_onMessage');
		if (_previousMessageDatas.any((m) => mapEquals(messageData, m))) {
			print('Duplicate message!');
			return;
		}
		_previousMessageDatas.add(messageData);
		// Cleanup memory usage later
		Future.delayed(const Duration(minutes: 3), () => _previousMessageDatas.remove(messageData));
		print(data);
		if (data.containsKey('threadId') && data.containsKey('userId')) {
			final child = _children[data['userId']];
			if (child == null) {
				print('Opened via message with unknown userId: $data');
				return;
			}
			final PushNotification notification;
			final target = ThreadOrPostIdentifier(data['board']!, data['threadId']!.parseInt, data['postId']?.tryParseInt);
			if (data['type'] == 'thread') {
				final page = data['page']?.tryParseInt;
				if (page != null) {
					notification = ThreadWatchPageNotification(target: target, page: page);
				}
				else {
					notification = ThreadWatchNotification(target: target);
				}
			}
			else if (data['type'] == 'board') {
				notification = BoardWatchNotification(target: target, filter: data['filter']!);
			}
			else {
				throw Exception('Unknown notification type ${data['type']}');
			}
			if (switch (await child.persistence.getThreadStateIfExists(target.thread)?.getThread()) {
				// Update needed
				Thread t => target.postId != null && !t.posts_.any((p) => p.id == target.postId),
				null => true
			}) {
				await child.localWatcher?.updateThread(target.thread);
			}
			if (child.getThreadWatch(target.thread)?.foregroundMuted != true) {
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
		if (data['type'] == 'thread' || data['type'] == 'threadPage' || data['type'] == 'board') {
			child.tapStream.add(ThreadOrPostIdentifier(
				data['board']!,
				data['threadId']!.parseInt,
				data['postId']?.tryParseInt
			));
		}
	}

	@pragma('vm:entry-point')
	@pragma('vm:entry-point')
	static void onNewUnifiedPushEndpoint(PushEndpoint endpoint, String instance) {
	  _handleNewUnifiedPushEndpointAsync(endpoint.url, instance);
}

	static Future<void> _handleNewUnifiedPushEndpointAsync(String endpoint, String instance) async {
	  Persistence.settings.lastUnifiedPushEndpoint = endpoint;
		for (final completer in _unifiedPushNewEndpointCompleters) {
			completer.complete(endpoint);
		}
		_unifiedPushNewEndpointCompleters.clear();
		await _reinitializeChildren(allowDeleteAll: false);
	}

	@pragma('vm:entry-point')
	static Future<void> onUnifiedPushUnregistered(String instance) async {
		Persistence.settings.lastUnifiedPushEndpoint = null;
		_reinitializeChildren(allowDeleteAll: false);
	}

	static String _makeNotificationThreadId(Map<String, String> map) {
		return '${map['userId']}/${map['board']}/${map['threadId']}';
	}

	@pragma('vm:entry-point')
	static void onUnifiedPushMessage(PushMessage message, String instance) {
	  _handleUnifiedPushMessageAsync(message.content, instance);
}

	static Future<void> _handleUnifiedPushMessageAsync(Uint8List message, String instance) async {
		final notification = json.decode(utf8.decode(message)) as Map;
		final data = (notification['data'] as Map).cast<String, String>();
		if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
			_onMessage(data);
		}
		else {
			FlutterLocalNotificationsPlugin().show(
				data['postId']?.tryParseInt ?? data['threadId']!.parseInt,
				notification['title'] as String?,
				notification['body'] as String?,
				NotificationDetails(
					android: AndroidNotificationDetails(
						'up', 'Unified Push',
						importance: Importance.high,
						priority: Priority.high,
						groupKey: _makeNotificationThreadId(data)
					)
				),
				payload: json.encode(data)
			);
		}
	}

	@pragma('vm:entry-point')
	static Future<void> onAPNSLaunch(ApnsRemoteMessage message) async {
		_onMessageOpenedApp(message.payload['data'] as Map);
	}

	@pragma('vm:entry-point')
	static Future<void> onAPNSMessage(ApnsRemoteMessage message) async {
		_onMessage(message.payload['data'] as Map);
	}

	@pragma('vm:entry-point')
	static Future<void> onAPNSResume(ApnsRemoteMessage message) async {
		_onMessageOpenedApp(message.payload['data'] as Map);
	}

	@pragma('vm:entry-point')
	static Future<void> _onLocalNotificationTapped(NotificationResponse response) async {
		_onMessageOpenedApp(json.decode(response.payload!) as Map);
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
		await future.timeout(const Duration(seconds: 2), onTimeout: () async {
			await UnifiedPush.unregister();
			throw TimeoutException('Distributor did not provide an endpoint');
		});
	}

	static Future<void> registerUnifiedPush() async {
		if ((await UnifiedPush.getDistributor())?.isNotEmpty ?? false) {
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
			Settings.instance.addListener(_didUpdateSettings);
			_client.interceptors.add(LoggingInterceptor.instance);
			Settings.instance.filterListenable.addListener(_didUpdateFilter);
			if (Platform.isAndroid) {
				await FlutterLocalNotificationsPlugin().initialize(
					const InitializationSettings(
						android: AndroidInitializationSettings('@drawable/ic_stat_clover')
					),
					onDidReceiveNotificationResponse: _onLocalNotificationTapped,
					onDidReceiveBackgroundNotificationResponse: _onBackgroundLocalNotificationTapped
				);
				await FlutterLocalNotificationsPlugin().resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
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
					_onMessageOpenedApp(json.decode(initial!.notificationResponse!.payload!) as Map);
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
			ImageboardRegistry.instance.setNotificationError(null, (e, st));
		}
	}

	static bool? _lastUsePushNotifications;
	static Future<void> _didUpdateSettings() async {
		final usePushNotifications = Persistence.settings.usePushNotifications;
		if (usePushNotifications != _lastUsePushNotifications) {
			_lastUsePushNotifications = usePushNotifications;
			if (usePushNotifications == true) {
				if (Platform.isIOS || Platform.isMacOS) {
					await _apnsConnector?.requestNotificationPermissions();
				}
				else if (Platform.isAndroid) {
					await registerUnifiedPush();
					await FlutterLocalNotificationsPlugin().resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
				}
			}
			else if (usePushNotifications == false) {
				if (Platform.isIOS || Platform.isMacOS) {
					await _apnsConnector?.unregister();
				}
				else if (Platform.isAndroid) {
					await UnifiedPush.unregister();
				}
			}
			// For true -> false transition
			await _reinitializeChildren(allowDeleteAll: true);
		}
	}

	static Future<void> _didUpdateFilter() async {
		if (Persistence.settings.usePushNotifications == true) {
			await _reinitializeChildren(allowDeleteAll: true);
		}
	}

	static Future<void> _reinitializeChildren({required bool allowDeleteAll}) async {
		await Future.wait(_children.values.map((c) => c.initialize(allowDeleteAll: allowDeleteAll)));
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
		return base64Encode(md5.convert(utf8.encode(boards.join(','))).bytes);
	}

	Future<void> deleteAllNotificationsFromServer() async {
		final response = await _client.patch<Map>('$_notificationSettingsApiRoot/user/$id', data: jsonEncode({
			'token2': (await _getToken())?.toMap(),
			'siteType': siteType,
			'siteData': siteData,
			'filters': '',
			'hiddenImageMD5s': '',
			'protocolVersion': _kProtocolVersion
		}), options: Options(responseType: ResponseType.json));
		final digest = response.data!['digest'] as String;
		final emptyDigest = base64Encode(md5.convert(''.codeUnits).bytes);
		if (digest != emptyDigest) {
			print('Need to resync notifications $id');
			await _client.put('$_notificationSettingsApiRoot/user/$id', data: jsonEncode({
				'watches': []
			}));
		}
	}

	Future<void> initialize({required bool allowDeleteAll}) async {
		_children[id] = this;
		try {
			if (Persistence.settings.usePushNotifications == true) {
				final response = await _client.patch<Map>('$_notificationSettingsApiRoot/user/$id', data: jsonEncode({
					'token2': (await _getToken())?.toMap(),
					'siteType': siteType,
					'siteData': siteData,
					'filters': Settings.instance.filterConfiguration,
					'hiddenImageMD5s': Persistence.settings.hiddenImageMD5s.join('\n'),
					'protocolVersion': _kProtocolVersion
				}), options: Options(responseType: ResponseType.json));
				final digest = response.data!['digest'] as String;
				if (digest != _calculateDigest()) {
					print('Need to resync notifications $id ($digest -> ${_calculateDigest()})');
					await _client.put('$_notificationSettingsApiRoot/user/$id', data: jsonEncode({
						'watches': [
							...threadWatches.values.where((w) => !w.zombie),
							...boardWatches
						].map((w) => w.toMap(persistence)).toList()
					}));
				}
			}
			else if (allowDeleteAll) {
				await deleteAllNotificationsFromServer();
			}
			if (_unrecognizedByUserId.containsKey(id)) {
				_unrecognizedByUserId[id]?.forEach(_onMessageOpenedApp);
				_unrecognizedByUserId[id]?.clear();
			}
			ImageboardRegistry.instance.setNotificationError(imageboard, null);
		}
		catch (e, st) {
			print('Error initializing notifications: $e');
			ImageboardRegistry.instance.setNotificationError(imageboard, (e, st));
		}
	}

	ThreadWatch? getThreadWatch(ThreadIdentifier thread) {
		return threadWatches[thread];
	}
	
	BoardWatch? getBoardWatch(String boardName) {
		return boardWatches.tryFirstWhere((w) => w.board == boardName);
	}

	Future<void> insertWatch(ThreadWatch watch) async {
		final existingWatch = threadWatches[watch.threadIdentifier];
		if (existingWatch != null) {
			return;
		}
		threadWatches[watch.threadIdentifier] = watch;
		if (Persistence.settings.usePushNotifications == true && watch.push) {
			_create(watch);
		}
		localWatcher?.onWatchUpdated(watch);
		persistence.didUpdateBrowserState();
	}

	Future<void> subscribeToThread({
		required ThreadIdentifier thread,
		required int lastSeenId,
		required bool localYousOnly,
		required bool pushYousOnly,
		required bool push,
		required List<int> youIds,
		bool foregroundMuted = false,
		bool zombie = false,
		required bool notifyOnSecondLastPage,
		required bool notifyOnLastPage,
		required bool notifyOnDead
	}) async {
		final existingWatch = threadWatches[thread];
		if (existingWatch != null) {
			existingWatch.youIds = youIds;
			existingWatch.lastSeenId = lastSeenId;
			existingWatch.notifyOnSecondLastPage = notifyOnSecondLastPage;
			existingWatch.notifyOnLastPage = notifyOnLastPage;
			existingWatch.notifyOnDead = notifyOnDead;
			didUpdateWatch(existingWatch);
		}
		else {
			await insertWatch(ThreadWatch(
				board: thread.board,
				threadId: thread.id,
				lastSeenId: lastSeenId,
				localYousOnly: localYousOnly,
				pushYousOnly: pushYousOnly,
				youIds: youIds,
				push: push,
				foregroundMuted: foregroundMuted,
				zombie: zombie,
				watchTime: DateTime.now(),
				notifyOnSecondLastPage: notifyOnSecondLastPage,
				notifyOnLastPage: notifyOnLastPage,
				notifyOnDead: notifyOnDead
			));
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

	Future<void> unsubscribeFromThread(ThreadIdentifier thread) async {
		final watch = getThreadWatch(thread);
		if (watch != null) {
			await removeWatch(watch);
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

	void didUpdateWatch(Watch watch, {bool possiblyDisabledPush = false, bool updateBrowserState = true}) {
		if (Persistence.settings.usePushNotifications ?? false) {
			if (watch.push) {
				_replace(watch);
			}
			else if (possiblyDisabledPush) {
				_delete(watch);
			}
		}
		localWatcher?.onWatchUpdated(watch);
		if (updateBrowserState) {
			persistence.didUpdateBrowserState();
		}
	}

	Future<void> zombifyThreadWatch(ThreadWatch watch, bool deleted) async {
		if (Persistence.settings.usePushNotifications == true && watch.push) {
			final deletedFromServer = await _delete(watch);
			if (deletedFromServer && watch.notifyOnDead) {
				// We found out the thread was dead first, so show our own notification
				final payload = <String, String>{
					'userId': id,
					'board': watch.board,
					'threadId': watch.threadId.toString(),
					'page': deleted ? '-1' : '0',
					'type': 'thread'
				};
				if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
					// Show it in foreground
					_onMessage(payload);
				}
				else {
					FlutterLocalNotificationsPlugin().show(
						Object.hash(id, watch.board, watch.threadId),
						'Watched thread /${watch.board}/${watch.threadId} was ${deleted ? 'deleted' : 'archived'}',
						'',
						NotificationDetails(
							android: AndroidNotificationDetails(
								'up', 'Unified Push',
								importance: Importance.high,
								priority: Priority.high,
								groupKey: _makeNotificationThreadId(payload)
							),
							iOS: DarwinNotificationDetails(
								threadIdentifier: _makeNotificationThreadId(payload)
							)
						),
						payload: json.encode(payload)
					);
				}
			}
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
			threadWatches.remove(watch.threadIdentifier);
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
		if (lastKnownId > watch.lastSeenId) {
			watch.lastSeenId = lastKnownId;
			if (Persistence.settings.usePushNotifications == true && watch.push) {
				_update(watch);
			}
		}
	}

	Future<void> _create(Watch watch) async {
		await _client.post(
			'$_notificationSettingsApiRoot/user/$id/watch',
			data: jsonEncode(watch.toMap(persistence))
		);
	}

	Future<void> _replace(Watch watch) async {
		if (watch.push) {
			await _client.put(
				'$_notificationSettingsApiRoot/user/$id/watch',
				data: jsonEncode(watch.toMap(persistence))
			);
		}
		else {
			await _delete(watch);
		}
	}

	Future<void> _update(Watch watch) async {
		await _client.patch(
			'$_notificationSettingsApiRoot/user/$id/watch',
			data: jsonEncode(watch.toMap(persistence))
		);
	}

	Future<bool> _delete(Watch watch) async {
		final response = await _client.delete<Map>(
			'$_notificationSettingsApiRoot/user/$id/watch',
			data: jsonEncode(watch.toMap(persistence)),
			options: Options(
				responseType: ResponseType.json
			)
		);
		return response.data?['existed'] as bool? ?? false;
	}

	void dispose() {
		tapStream.close();
		foregroundStream.close();
	}
}
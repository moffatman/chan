import 'dart:convert';

import 'package:chan/main.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:chan/firebase_options.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

const _platform = MethodChannel('com.moffatman.chan/notifications');

Future<void> promptForPushNotificationsIfNeeded(BuildContext context) async {
	final settings = context.read<EffectiveSettings>();
	if (settings.usePushNotifications == null) {
		final choice = await showCupertinoDialog<bool>(
			context: context,
			builder: (context) => CupertinoAlertDialog(
				title: const Text('Use push notifications?'),
				content: const Text('Notifications for (You)s will be sent while the app is closed.\nFor this to work, the thread IDs you want to be notified about will be sent to a notification server.'),
				actions: [
					CupertinoDialogAction(
						child: const Text('No'),
						onPressed: () {
							Navigator.of(context).pop(false);
						}
					),
					CupertinoDialogAction(
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
		if (watch is NewThreadWatch) ...{
			'board': watch.board,
			'uniqueId': watch.uniqueId
		}
		else if (watch is ThreadWatch) ...{
			'board': watch.board,
			'threadId': watch.threadId.toString()
		}
	});
}

Future<void> handleBackgroundMessage(RemoteMessage message) async {
	print('handleBackgroundMessage');
	print(message.data);
}

const _notificationSettingsApiRoot = 'https://notifications.moffatman.com';

class Notifications {
	static final Map<String, Notifications> _children = {};
	final tapStream = BehaviorSubject<ThreadOrPostIdentifier>();
	final foregroundStream = BehaviorSubject<ThreadOrPostIdentifier>();
	final Persistence persistence;
	ThreadWatcher? localWatcher;
	final String siteType;
	final String siteData;
	String get id => persistence.browserState.notificationsId;
	List<ThreadWatch> get threadWatches => persistence.browserState.threadWatches;
	List<NewThreadWatch> get newThreadWatches => persistence.browserState.newThreadWatches;
	static final Map<String, List<RemoteMessage>> _unrecognizedByUserId = {};

	Notifications({
		required ImageboardSite site,
		required this.persistence
	}) : siteType = site.siteType,
		siteData = site.siteData;

	@override
	String toString() => 'Notifications(siteType: $siteType, id: $id, tapStream: $tapStream)';

	static void _onMessageOpenedApp(RemoteMessage message) {
		print('onMessageOpenedApp');
		print(message.data);
		if (message.data.containsKey('threadId') && message.data.containsKey('userId')) {
			if (!_children.containsKey(message.data['userId'])) {
				print('Opened via message with unknown userId: ${message.data}');
				_unrecognizedByUserId.update(message.data['userId'], (list) => list..add(message), ifAbsent: () => [message]);
			}
			_children[message.data['userId']]?.tapStream.add(ThreadOrPostIdentifier(
				message.data['board'],
				int.parse(message.data['threadId']),
				int.tryParse(message.data['postId'] ?? '')
			));
		}
	}

	static Future<void> initializeStatic() async {
		try {
			await Firebase.initializeApp(
				options: DefaultFirebaseOptions.currentPlatform,
			);
			FirebaseMessaging messaging = FirebaseMessaging.instance;
			//print('Token: ${await messaging.getToken()}');
			if (Persistence.settings.usePushNotifications == true) {
				await messaging.requestPermission();
			}
			final initialMessage = await messaging.getInitialMessage();
			if (initialMessage != null) {
				_onMessageOpenedApp(initialMessage);
			}
			FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
				print('onMessage');
				//print(message);
				print(message.data);
				if (message.data.containsKey('threadId') && message.data.containsKey('userId')) {
					if (!_children.containsKey(message.data['userId'])) {
						print('Opened via message with unknown userId: ${message.data}');
					}
					final identifier = ThreadOrPostIdentifier(
						message.data['board'],
						int.parse(message.data['threadId']),
						int.tryParse(message.data['postId'] ?? '')
					);
					await _children[message.data['userId']]?.localWatcher?.updateThread(identifier.threadIdentifier);
					_children[message.data['userId']]?.foregroundStream.add(identifier);
				}
			});
			FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);
			FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
		}
		catch (e) {
			print('Error initializing notifications: $e');
		}
	}

	static Future<void> didUpdateUsePushNotificationsSetting() async {
		if (Persistence.settings.usePushNotifications == true) {
			await FirebaseMessaging.instance.requestPermission();
		}
		await Future.wait(_children.values.map((c) => c.initialize()));
	}

	static Future<String?> getToken() {
		return FirebaseMessaging.instance.getToken();
	}

	String _calculateDigest() {
		final boards = [
			...threadWatches.where((w) => !w.zombie).map((w) => w.board),
			...newThreadWatches.map((w) => w.board)
		];
		boards.sort((a, b) => a.compareTo(b));
		return base64Encode(md5.convert(boards.join(',').codeUnits).bytes);
	}

	Future<void> deleteAllNotificationsFromServer() async {
		final response = await Dio().patch('$_notificationSettingsApiRoot/user/$id', data: jsonEncode({
			'token': await Notifications.getToken(),
			'siteType': siteType,
			'siteData': siteData
		}));
		final String digest = response.data['digest'];
		final emptyDigest = base64Encode(md5.convert(''.codeUnits).bytes);
		if (digest != emptyDigest) {
			print('Need to resync notifications $id');
			await Dio().put('$_notificationSettingsApiRoot/user/$id', data: jsonEncode({
				'watches': []
			}));
		}
	}

	Future<void> initialize() async {
		_children[id] = this;
		try {
			if (Persistence.settings.usePushNotifications == true) {
				final response = await Dio().patch('$_notificationSettingsApiRoot/user/$id', data: jsonEncode({
					'token': await Notifications.getToken(),
					'siteType': siteType,
					'siteData': siteData
				}));
				final String digest = response.data['digest'];
				if (digest != _calculateDigest()) {
					print('Need to resync notifications $id');
					await Dio().put('$_notificationSettingsApiRoot/user/$id', data: jsonEncode({
						'watches': [
							...threadWatches.where((w) => !w.zombie),
							...newThreadWatches
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
		}
		catch (e) {
			print('Error initializing notifications: $e');
		}
	}

	ThreadWatch? getThreadWatch(ThreadIdentifier thread) {
		return threadWatches.tryFirstWhere((w) => w.board == thread.board && w.threadId == thread.id);
	}

	void subscribeToThread({
		required ThreadIdentifier thread,
		required int lastSeenId,
		required bool localYousOnly,
		required bool pushYousOnly,
		required bool push,
		required List<int> youIds
	}) {
		final existingWatch = threadWatches.tryFirstWhere((w) => w.threadIdentifier == thread);
		if (existingWatch != null) {
			existingWatch.localYousOnly = localYousOnly;
			existingWatch.pushYousOnly = pushYousOnly;
			didUpdateThreadWatch(existingWatch);
		}
		else {
			final watch = ThreadWatch(
				board: thread.board,
				threadId: thread.id,
				lastSeenId: lastSeenId,
				localYousOnly: localYousOnly,
				pushYousOnly: pushYousOnly,
				youIds: youIds,
				push: push
			);
			threadWatches.add(watch);
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
			removeThreadWatch(watch);
		}
	}

	void didUpdateThreadWatch(ThreadWatch watch, {bool possiblyDisabledPush = false}) {
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

	void removeThreadWatch(ThreadWatch watch) {
		if (Persistence.settings.usePushNotifications == true && watch.push) {
			_delete(watch);
		}
		threadWatches.remove(watch);
		localWatcher?.onWatchRemoved(watch);
		persistence.didUpdateBrowserState();
	}

	List<NewThreadWatch> getNewThreadWatches(String board) {
		return newThreadWatches.where((w) => w.board == board).toList();
	}

	Future<void> updateLastKnownId(Watch watch, int lastKnownId, {bool foreground = false}) async {
		if (foreground && WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
			clearNotifications(this, watch);
			clearOverlayNotifications(this, watch);
		}
		final couldUpdate = watch.lastSeenId != lastKnownId;
		watch.lastSeenId = lastKnownId;
		if (couldUpdate && Persistence.settings.usePushNotifications == true && watch.push) {
			_update(watch);
		}
	}

	Future<void> _create(Watch watch) async {
		await Dio().post(
			'$_notificationSettingsApiRoot/user/$id/watch',
			data: jsonEncode(watch.toMap())
		);
	}

	Future<void> _replace(Watch watch) async {
		if (watch.push) {
			await Dio().put(
				'$_notificationSettingsApiRoot/user/$id/watch',
				data: jsonEncode(watch.toMap())
			);
		}
		else {
			await _delete(watch);
		}
	}

	Future<void> _update(Watch watch) async {
		await Dio().patch(
			'$_notificationSettingsApiRoot/user/$id/watch',
			data: jsonEncode(watch.toMap())
		);
	}

	Future<void> _delete(Watch watch) async {
		await Dio().delete(
			'$_notificationSettingsApiRoot/user/$id/watch',
			data: jsonEncode(watch.toMap())
		);
	}

	void dispose() {
		tapStream.close();
		foregroundStream.close();
	}
}
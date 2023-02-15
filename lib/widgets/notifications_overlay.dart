import 'dart:async';

import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class OverlayNotification {
	final Imageboard imageboard;
	final PushNotification notification;
	bool closed = false;
	AnimationController? autoCloseAnimation;

	OverlayNotification({
		required this.imageboard,
		required this.notification,
		required this.autoCloseAnimation
	});

	bool get isMuted => imageboard.notifications.getThreadWatch(notification.target.thread)?.foregroundMuted ?? false;

	@override
	String toString() => 'OverlayNotification(imageboard: $imageboard, notification: $notification)';
}

class NotificationsOverlay extends StatefulWidget {
	final Widget child;
	final bool onePane;
	final Duration fadeTime;
	final List<Imageboard> imageboards;

	const NotificationsOverlay({
		required this.child,
		required this.onePane,
		required this.imageboards,
		this.fadeTime = const Duration(seconds: 5),
		Key? key
	}) : super(key: key);

	@override
	createState() => NotificationsOverlayState();
}

class NotificationsOverlayState extends State<NotificationsOverlay> with TickerProviderStateMixin {
	final Map<Imageboard, StreamSubscription<PushNotification>> subscriptions = {};
	final List<OverlayNotification> shown = [];

	void _checkAutoclose() {
		if (shown.isEmpty) {
			return;
		}
		final n = shown.first;
		if (n.autoCloseAnimation!.isAnimating) {
			return;
		}
		if (!(n.imageboard.persistence.getThreadStateIfExists(n.notification.target.thread)?.freshYouIds().contains(n.notification.target.postId) ?? false)) {
			n.autoCloseAnimation!.forward().then((_) => closeNotification(n));
		}
	}

	void _newNotification(Imageboard imageboard, PushNotification notification) async {
		final autoCloseAnimation = AnimationController(
			vsync: this,
			duration: widget.fadeTime
		);
		final overlayNotification = OverlayNotification(
			imageboard: imageboard,
			notification: notification,
			autoCloseAnimation: autoCloseAnimation
		);
		shown.add(overlayNotification);
		setState(() {});
		await Future.delayed(const Duration(seconds: 1));
		_checkAutoclose();
	}

	Future<void> closeNotification(OverlayNotification notification) async {
		if (!shown.contains(notification)) {
			return;
		}
		notification.closed = true;
		setState(() {});
		await Future.delayed(const Duration(seconds: 1));
		notification.autoCloseAnimation?.dispose();
		notification.autoCloseAnimation = null;
		shown.remove(notification);
		setState(() {});
		_checkAutoclose();
	}

	Future<void> muteNotification(OverlayNotification notification) async {
		if (!shown.contains(notification)) {
			return;
		}
		notification.imageboard.notifications.foregroundMuteThread(notification.notification.target.thread);
		closeNotification(notification);
	}

	void _notificationTapped(OverlayNotification notification) {
		notification.imageboard.notifications.tapStream.add(notification.notification.target);
		closeNotification(notification);
	}

	@override
	void initState() {
		super.initState();
		subscriptions.addAll({
			for (final i in widget.imageboards) i: i.notifications.foregroundStream.listen((message) => _newNotification(i, message))
		});
	}

	@override
	void didUpdateWidget(NotificationsOverlay oldWidget) {
		super.didUpdateWidget(oldWidget);
		for (final i in widget.imageboards) {
			if (!subscriptions.containsKey(i)) {
				subscriptions[i] = i.notifications.foregroundStream.listen((message) => _newNotification(i, message));
			}
		}
		for (final i in oldWidget.imageboards) {
			if (!widget.imageboards.contains(i)) {
				subscriptions.remove(i)?.cancel();
			}
		}
	}

	@override
	Widget build(BuildContext context) {
		return Stack(
			children: [
				widget.child,
				if (widget.onePane) ...shown.reversed.map((notification) => Align(
					alignment: Alignment.topCenter,
					child: Padding(
						padding: EdgeInsets.only(top: 44 + MediaQuery.paddingOf(context).top),
						child: TopNotification(
							notification: notification,
							onTap: () => _notificationTapped(notification),
							onTapClose: () => closeNotification(notification),
							onTapMute: () => muteNotification(notification)
						)
					)
				))
				else Align(
					alignment: Alignment.topRight,
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.end,
						children: [
							const SizedBox(height: 50),
							...shown.map((notification) => CornerNotification(
								key: ValueKey(notification),
								notification: notification,
								onTap: () => _notificationTapped(notification),
								onTapClose: () => closeNotification(notification),
								onTapMute: () => muteNotification(notification)
							))
						]
					)
				)
			]
		);
	}

	@override
	void dispose() {
		super.dispose();
		for (final subscription in subscriptions.values) {
			subscription.cancel();
		}
	}
}

class NotificationContent extends StatelessWidget {
	final PushNotification notification;
	final BoxConstraints constraints;

	const NotificationContent({
		required this.notification,
		required this.constraints,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		final threadState = context.read<Persistence>().getThreadStateIfExists(notification.target.thread);
		final thread = threadState?.thread;
		Post? post;
		bool isYou = false;
		post = thread?.posts.tryFirstWhere((p) => p.id == notification.target.postId);
		if (threadState != null) {
			isYou = threadState.youIds.contains(notification.target.postId);
		}
		String title;
		if (notification is BoardWatchNotification) {
			title = 'New ${notification.isThread ? 'thread' : 'post'} matching "${(notification as BoardWatchNotification).filter}" on /${notification.target.board}/';
		}
		else if (post == null) {
			title = 'New post in /${notification.target.board}/${notification.target.threadId}';
		}
		else {
			title = 'New ${isYou ? 'reply' : 'post'} in /${notification.target.board}/${notification.target.threadId}';
		}
		return IgnorePointer(
			child: ChangeNotifierProvider<PostSpanZoneData>(
				create: (context) => PostSpanRootZoneData(
				site: context.read<ImageboardSite>(),
					thread: thread ?? Thread(
						board: notification.target.board,
						id: notification.target.threadId,
						isDeleted: false,
						isArchived: false,
						title: '',
						isSticky: false,
						replyCount: -1,
						imageCount: -1,
						time: DateTime.fromMicrosecondsSinceEpoch(0),
						posts_: [],
						attachments: []
					),
					threadState: context.read<Persistence>().getThreadStateIfExists(notification.target.thread),
					semanticRootIds: [-10]
				),
				builder: (context, _) => ConstrainedBox(
					constraints: constraints,
					child: Text.rich(
						TextSpan(
							children: [
								TextSpan(text: '$title       ', style: const TextStyle(
									fontWeight: FontWeight.bold
								)),
								if (post != null) ...[
									const TextSpan(text: '\n'),
									post.span.build(context, context.watch<PostSpanZoneData>(), context.watch<EffectiveSettings>(), PostSpanRenderOptions(
										shrinkWrap: true,
										avoidBuggyClippers: true
									))
								]
							]
						),
						overflow: TextOverflow.fade
					)
				)
			)
		);
	}
}

class TopNotification extends StatelessWidget {
	final OverlayNotification notification;
	final VoidCallback onTap;
	final VoidCallback onTapClose;
	final VoidCallback onTapMute;

	const TopNotification({
		required this.notification,
		required this.onTap,
		required this.onTapClose,
		required this.onTapMute,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return AnimatedOpacity(
			opacity: notification.closed ? 0 : 1.0,
			duration: const Duration(milliseconds: 300),
			curve: Curves.ease,
			child: IgnorePointer(
				ignoring: notification.closed,
				child: Container(
					color: CupertinoTheme.of(context).primaryColor,
					child: Row(
						crossAxisAlignment: CrossAxisAlignment.center,
						children: [
							Expanded(
								child: CupertinoButton.filled(
									borderRadius: BorderRadius.zero,
									alignment: Alignment.topLeft,
									onPressed: onTap,
									padding: const EdgeInsets.only(top: 16, right: 16, left: 16),
									child: ImageboardScope(
										imageboardKey: null, // it could be the dev board
										imageboard: notification.imageboard,
										child: NotificationContent(
											notification: notification.notification,
											constraints: const BoxConstraints(
												maxHeight: 80,
												minHeight: 80
											)
										)
									)
								)
							),
							if (notification is ThreadWatchNotification && !notification.isMuted) CupertinoButton.filled(
								padding: const EdgeInsets.all(16),
								borderRadius: BorderRadius.zero,
								alignment: Alignment.topCenter,
								onPressed: onTapMute,
								child: const Icon(CupertinoIcons.bell_slash)
							),
							CupertinoButton.filled(
								padding: const EdgeInsets.all(16),
								borderRadius: BorderRadius.zero,
								alignment: Alignment.topCenter,
								onPressed: onTapClose,
								child: Stack(
									alignment: Alignment.center,
									children: [
										const Icon(CupertinoIcons.xmark),
										IgnorePointer(
											child: AnimatedBuilder(
												animation: notification.autoCloseAnimation!,
												builder: (context, _) => CircularProgressIndicator(
													value: notification.autoCloseAnimation!.value,
													color: CupertinoTheme.of(context).scaffoldBackgroundColor
												)
											)
										)
									]
								)
							)
						]
					)
				)
			)
		);
	}
}

class CornerNotification extends StatelessWidget {
	final OverlayNotification notification;
	final VoidCallback onTap;
	final VoidCallback onTapClose;
	final VoidCallback onTapMute;

	const CornerNotification({
		required this.notification,
		required this.onTap,
		required this.onTapClose,
		required this.onTapMute,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return AnimatedSize(
			duration: const Duration(milliseconds: 500),
			curve: Curves.ease,
			child: notification.closed ? const SizedBox.shrink() : Padding(
				padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
				child: Stack(
					children: [
						Padding(
							padding: const EdgeInsets.all(8),
							child: CupertinoButton.filled(
								padding: const EdgeInsets.all(8),
								onPressed: onTap,
								child: ImageboardScope(
									imageboardKey: null, // it could be the dev board
									imageboard: notification.imageboard,
									child: NotificationContent(
										notification: notification.notification,
										constraints: const BoxConstraints(
											maxWidth: 300,
											maxHeight: 200
										)
									)
								)
							)
						),
						Positioned.fill(
							child: Align(
								alignment: Alignment.topRight,
								child: Row(
									mainAxisSize: MainAxisSize.min,
									children: [
										if (!notification.isMuted) ...[
											CupertinoButton(
												minSize: 0,
												padding: const EdgeInsets.all(8),
												borderRadius: BorderRadius.circular(100),
												color: CupertinoTheme.of(context).textTheme.actionTextStyle.color,
												onPressed: onTapMute,
												child: Icon(CupertinoIcons.bell_slash, size: 20, color: CupertinoTheme.of(context).primaryColor)
											),
											const SizedBox(width: 8),
										],
										CupertinoButton(
											minSize: 0,
											padding: EdgeInsets.zero,
											borderRadius: BorderRadius.circular(100),
											color: CupertinoTheme.of(context).textTheme.actionTextStyle.color,
											onPressed: onTapClose,
											child: Stack(
												alignment: Alignment.center,
												children: [
													Icon(CupertinoIcons.xmark, size: 17, color: CupertinoTheme.of(context).primaryColor),
													IgnorePointer(
														child: AnimatedBuilder(
															animation: notification.autoCloseAnimation!,
															builder: (context, _) => Transform.scale(
																scale: 0.8,
																child: CircularProgressIndicator(
																	value: notification.autoCloseAnimation!.value,
																	color: CupertinoTheme.of(context).primaryColor,
																	strokeWidth: 4,
																)
															)
														)
													)
												]
											)
										)
									]
								)
							)
						)
					]
				)
			)
		);
	}
}
import 'dart:async';

import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class OverlayNotification {
	final Notifications notifications;
	final ThreadOrPostIdentifier target;
	bool closed = false;
	final AnimationController autoCloseAnimation;

	OverlayNotification({
		required this.notifications,
		required this.target,
		required this.autoCloseAnimation
	});

	@override
	String toString() => 'OverlayNotification(notifications; $notifications, target: $target)';
}

class NotificationsOverlay extends StatefulWidget {
	final Widget child;
	final bool onePane;
	final Duration fadeTime;
	final List<Notifications> notifications;

	const NotificationsOverlay({
		required this.child,
		required this.onePane,
		required this.notifications,
		this.fadeTime = const Duration(seconds: 5),
		Key? key
	}) : super(key: key);

	@override
	createState() => NotificationsOverlayState();
}

class NotificationsOverlayState extends State<NotificationsOverlay> with TickerProviderStateMixin {
	final Map<Notifications, StreamSubscription<ThreadOrPostIdentifier>> subscriptions = {};
	final List<OverlayNotification> shown = [];

	void _checkAutoclose() {
		if (shown.isEmpty) {
			return;
		}
		final n = shown.first;
		if (n.autoCloseAnimation.isAnimating) {
			return;
		}
		if (!(n.notifications.persistence.getThreadStateIfExists(n.target.threadIdentifier)?.youIds.contains(n.target.postId) ?? false)) {
			n.autoCloseAnimation.forward().then((_) => closeNotification(n));
		}
	}

	void _newNotification(Notifications notifications, ThreadOrPostIdentifier target) async {
		final autoCloseAnimation = AnimationController(
			vsync: this,
			duration: widget.fadeTime
		);
		final notification = OverlayNotification(
			notifications: notifications,
			target: target,
			autoCloseAnimation: autoCloseAnimation
		);
		shown.add(notification);
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
		notification.autoCloseAnimation.dispose();
		shown.remove(notification);
		setState(() {});
		_checkAutoclose();
	}

	void _notificationTapped(OverlayNotification notification) {
		notification.notifications.tapStream.add(notification.target);
		closeNotification(notification);
	}

	@override
	void initState() {
		super.initState();
		subscriptions.addAll({
			for (final n in widget.notifications) n: n.foregroundStream.listen((message) => _newNotification(n, message))
		});
	}

	@override
	void didUpdateWidget(NotificationsOverlay oldWidget) {
		super.didUpdateWidget(oldWidget);
		for (final n in widget.notifications) {
			if (!subscriptions.containsKey(n)) {
				subscriptions[n] = n.foregroundStream.listen((message) => _newNotification(n, message));
			}
		}
		for (final n in oldWidget.notifications) {
			if (!widget.notifications.contains(n)) {
				subscriptions.remove(n)?.cancel();
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
						padding: EdgeInsets.only(top: 44 + MediaQuery.of(context).padding.top),
						child: TopNotification(
							notification: notification,
							onTap: () => _notificationTapped(notification),
							onTapClose: () => closeNotification(notification)
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
								onTapClose: () => closeNotification(notification)
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
	final ThreadOrPostIdentifier notification;
	final BoxConstraints constraints;

	const NotificationContent({
		required this.notification,
		required this.constraints,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		final threadState = context.read<Persistence>().getThreadStateIfExists(notification.threadIdentifier);
		final thread = threadState?.thread;
		Post? post;
		bool isYou = false;
		if (notification.postId != null) {
			post = thread?.posts.tryFirstWhere((p) => p.id == notification.postId);
		}
		if (threadState != null) {
			isYou = threadState.youIds.contains(notification.postId);
		}
		return IgnorePointer(
			child: ChangeNotifierProvider<PostSpanZoneData>(
				create: (context) => PostSpanRootZoneData(
				site: context.read<ImageboardSite>(),
					thread: thread ?? Thread(
						board: notification.board,
						id: notification.threadId,
						isDeleted: false,
						isArchived: false,
						title: '',
						isSticky: false,
						replyCount: -1,
						imageCount: -1,
						time: DateTime.fromMicrosecondsSinceEpoch(0),
						posts_: [],
					),
					threadState: context.read<Persistence>().getThreadStateIfExists(notification.threadIdentifier),
					semanticRootIds: [-10]
				),
				builder: (context, _) => ConstrainedBox(
					constraints: constraints,
					child: post == null ? Text('New post in /${notification.board}/${notification.threadId}       ', style: const TextStyle(
						fontWeight: FontWeight.bold
					)) : Text.rich(
						TextSpan(
							children: [
								TextSpan(text: 'New ${isYou ? 'reply' : 'post'} in /${notification.board}/${notification.threadId}       \n', style: const TextStyle(
									fontWeight: FontWeight.bold
								)),
								post.span.build(context, PostSpanRenderOptions(
									shrinkWrap: true,
									avoidBuggyClippers: true
								))
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

	const TopNotification({
		required this.notification,
		required this.onTap,
		required this.onTapClose,
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
									child: NotificationContent(
										notification: notification.target,
										constraints:const  BoxConstraints(
											maxHeight: 80,
											minHeight: 80
										)
									)
								)
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
												animation: notification.autoCloseAnimation,
												builder: (context, _) => CircularProgressIndicator(
													value: notification.autoCloseAnimation.value,
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

	const CornerNotification({
		required this.notification,
		required this.onTap,
		required this.onTapClose,
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
								child: NotificationContent(
									notification: notification.target,
									constraints: const BoxConstraints(
										maxWidth: 300,
										maxHeight: 200
									)
								)
							)
						),
						Positioned.fill(
							child: Align(
								alignment: Alignment.topRight,
								child: CupertinoButton(
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
													animation: notification.autoCloseAnimation,
													builder: (context, _) => Transform.scale(
														scale: 0.8,
														child: CircularProgressIndicator(
															value: notification.autoCloseAnimation.value,
															color: CupertinoTheme.of(context).primaryColor,
															strokeWidth: 4,
														)
													)
												)
											)
										]
									)
								)
							)
						)
					]
				)
			)
		);
	}
}
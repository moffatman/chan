import 'dart:async';

import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:flutter/cupertino.dart';
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

	void _newNotification(Notifications notifications, ThreadOrPostIdentifier target) {
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
		if (!(notifications.persistence.getThreadStateIfExists(target.threadIdentifier)?.youIds.contains(target.postId) ?? false)) {
			autoCloseAnimation.forward().then((_) => closeNotification(notification));
		}
		setState(() {});
	}

	Future<void> closeNotification(OverlayNotification notification) async {
		notification.closed = true;
		setState(() {});
		await Future.delayed(const Duration(seconds: 1));
		notification.autoCloseAnimation.dispose();
		shown.remove(notification);
		setState(() {});
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
						padding: const EdgeInsets.only(top: 64),
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
							...shown.reversed.map((notification) => CornerNotification(
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
					child: Text.rich(
						TextSpan(
							children: [
								TextSpan(text: 'New ${isYou ? 'reply' : 'post'} in /${notification.board}/${notification.threadId}\n', style: const TextStyle(
									fontWeight: FontWeight.bold
								)),
								if (post != null) post.span.build(context, PostSpanRenderOptions(
									shrinkWrap: true,
									avoidBuggyClippers: true
								))
								else TextSpan(text: '$notification')
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
									child: NotificationContent(
										notification: notification.target,
										constraints:const  BoxConstraints(
											maxHeight: 64,
											minHeight: 64
										)
									)
								)
							),
							CupertinoButton.filled(
								padding: const EdgeInsets.all(16),
								borderRadius: BorderRadius.zero,
								onPressed: onTapClose,
								child: const Icon(CupertinoIcons.xmark)
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
				padding: const EdgeInsets.all(8),
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
									padding: const EdgeInsets.all(4),
									borderRadius: BorderRadius.circular(100),
									color: CupertinoTheme.of(context).textTheme.actionTextStyle.color,
									onPressed: onTapClose,
									child: Icon(CupertinoIcons.xmark, size: 17, color: CupertinoTheme.of(context).primaryColor)
								)
							)
						)
					]
				)
			)
		);
	}
}
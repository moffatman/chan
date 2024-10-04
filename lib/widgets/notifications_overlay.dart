import 'dart:async';

import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/cupertino_inkwell.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/thread_row.dart';
import 'package:chan/widgets/util.dart';
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
		final n = widget.onePane ? shown.last : shown.first;
		if (n.autoCloseAnimation!.isAnimating) {
			return;
		}
		if (!(n.imageboard.persistence.getThreadStateIfExists(n.notification.target.thread)?.freshYouIds().contains(n.notification.target.postId) ?? false)) {
			n.autoCloseAnimation!.forward().then((_) => closeNotification(n));
		}
	}

	void _newNotification(Imageboard imageboard, PushNotification notification) async {
		final threadState = imageboard.persistence.getThreadStateIfExists(notification.target.thread);
		if (threadState?.youIds.contains(notification.target.postId) ?? false) {
			// Push server won race first, don't show this notification
			return;
		}
		await threadState?.ensureThreadLoaded();
		if (
			// This post is loaded locally
			threadState?.thread?.posts_.any((p) => p.id == notification.target.postId) == true &&
			// It's not in the set of unseen posts
			threadState?.unseenPostIds.data.contains(notification.target.postId) == false
		) {
			// We already saw this post locally
			return;
		}
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
		if (!widget.onePane) {
			// Allow time to collapse, shifting later notifications up
			await Future.delayed(const Duration(seconds: 1));
		}
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
			for (final i in widget.imageboards) i: i.notifications.foregroundStream.stream.listen((message) => _newNotification(i, message))
		});
	}

	@override
	void didUpdateWidget(NotificationsOverlay oldWidget) {
		super.didUpdateWidget(oldWidget);
		for (final i in widget.imageboards) {
			if (!subscriptions.containsKey(i)) {
				subscriptions[i] = i.notifications.foregroundStream.stream.listen((message) => _newNotification(i, message));
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
				if (widget.onePane) ...shown.indexed.map((notification) => Align(
					alignment: Alignment.topCenter,
					child: Padding(
						padding: EdgeInsets.only(top: 44 + MediaQuery.paddingOf(context).top + (24 * notification.$1)),
						child: CornerNotification(
							notification: notification.$2,
							onTap: () => _notificationTapped(notification.$2),
							onTapClose: () => closeNotification(notification.$2),
							onTapMute: () => muteNotification(notification.$2),
							maxWidth: double.infinity
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
								onTapMute: () => muteNotification(notification),
								maxWidth: 300
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
	final double topRightCornerInsetWidth;

	const NotificationContent({
		required this.notification,
		this.topRightCornerInsetWidth = 0,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		final notification = this.notification;
		final threadState = context.read<Persistence>().getThreadStateIfExists(notification.target.thread);
		final thread = threadState?.thread;
		Post? post;
		bool isYou = false;
		post = thread?.posts.tryFirstWhere((p) => p.id == notification.target.postId);
		if (threadState != null) {
			isYou = threadState.youIds.contains(notification.target.postId);
		}
		final String title;
		if (notification is BoardWatchNotification) {
			title = 'New ${notification.target.isThread ? 'thread' : 'post'} matching "${notification.filter}" on /${notification.target.board}/';
		}
		else if (notification is ThreadWatchPageNotification) {
			title = switch (notification.page) {
				> 0 => 'Thread /${notification.target.board}/${notification.target.threadId} reached page ${notification.page}',
				0 => 'Thread /${notification.target.board}/${notification.target.threadId} was archived',
				_ => 'Thread /${notification.target.board}/${notification.target.threadId} was deleted'
			};
		}
		else if (post == null) {
			title = 'New post in /${notification.target.board}/${notification.target.threadId}';
		}
		else {
			title = 'New ${isYou ? 'reply' : 'post'} in /${notification.target.board}/${notification.target.threadId}';
		}
		final child = Column(
			mainAxisSize: MainAxisSize.min,
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Row(
					mainAxisSize: MainAxisSize.min,
					children: [
						Flexible(
							child: Text(
								'$title       ',
								style: TextStyle(
									color: ChanceTheme.backgroundColorOf(context),
									fontWeight: FontWeight.bold,
									fontVariations: CommonFontVariations.bold
								)
							)
						),
						SizedBox(
							width: topRightCornerInsetWidth
						)
					]
				),
				if (post case Post p) ...[
					const SizedBox(height: 8),
					Flexible(
						child: SingleChildScrollView(
							primary: false,
							padding: const EdgeInsets.only(bottom: 8),
							child: ChangeNotifierProvider<PostSpanZoneData>(
								create: (context) => PostSpanRootZoneData(
									imageboard: context.read<Imageboard>(),
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
									semanticRootIds: [-10],
									style: PostSpanZoneStyle.linear
								),
								child: IgnorePointer(
									child: PostRow(
										post: p,
										shrinkWrap: true
									)
								)
							)
						)
					)
				]
				else if (thread case Thread t) ...[
					const SizedBox(height: 8),
					Flexible(
						child: SingleChildScrollView(
							primary: false,
							padding: const EdgeInsets.only(bottom: 8),
							child: IgnorePointer(
								child: ThreadRow(
									thread: t,
									isSelected: false
								)
							)
						)
					)
				]
			]
		);
		if (Settings.materialStyleSetting.watch(context)) {
			return Material(
				color: Colors.transparent,
				child: child
			);
		}
		return child;
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
					color: ChanceTheme.primaryColorOf(context),
					child: Row(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Expanded(
								child: CupertinoInkwell(
									alignment: Alignment.topLeft,
									onPressed: onTap,
									padding: const EdgeInsets.only(top: 16, right: 16, left: 16),
									child: ImageboardScope(
										imageboardKey: null, // it could be the dev board
										imageboard: notification.imageboard,
										child: ConstrainedBox(
											constraints: const BoxConstraints(
												maxHeight: 200,
												minHeight: 80
											),
											child: NotificationContent(
												notification: notification.notification,
											)
										)
									)
								)
							),
							Column(
								mainAxisSize: MainAxisSize.min,
								mainAxisAlignment: MainAxisAlignment.start,
								children: [
									AdaptiveFilledButton(
										padding: const EdgeInsets.all(16),
										borderRadius: BorderRadius.zero,
										alignment: Alignment.topCenter,
										onPressed: onTapClose,
										child: Stack(
											alignment: Alignment.center,
											children: [
												Icon(CupertinoIcons.xmark, color: ChanceTheme.backgroundColorOf(context)),
												IgnorePointer(
													child: AnimatedBuilder(
														animation: notification.autoCloseAnimation!,
														builder: (context, _) => CircularProgressIndicator(
															value: notification.autoCloseAnimation!.value,
															color: ChanceTheme.backgroundColorOf(context)
														)
													)
												)
											]
										)
									),
									if ((notification.notification is ThreadWatchNotification || notification.notification is ThreadWatchPageNotification) && !notification.isMuted) AdaptiveFilledButton(
										padding: const EdgeInsets.all(16),
										borderRadius: BorderRadius.zero,
										alignment: Alignment.topCenter,
										onPressed: onTapMute,
										child: Icon(CupertinoIcons.bell_slash, color: ChanceTheme.backgroundColorOf(context))
									)
								]
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
	final double maxWidth;

	const CornerNotification({
		required this.notification,
		required this.onTap,
		required this.onTapClose,
		required this.onTapMute,
		required this.maxWidth,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return TweenAnimationBuilder(
			tween: Tween<double>(begin: 0, end: notification.closed ? 0.0 : 1.0),
			duration: const Duration(milliseconds: 300),
			curve: Curves.ease,
			builder: (context, opacity, child) {
				return Opacity(
					opacity: opacity,
					child: child
				);
			},
			child: AnimatedSize(
				duration: const Duration(milliseconds: 500),
				curve: Curves.ease,
				child: notification.closed ? const SizedBox(width: double.infinity) : Padding(
					padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
					child: Stack(
						children: [
							Padding(
								padding: const EdgeInsets.all(8),
								child: CupertinoInkwell(
									padding: EdgeInsets.zero,
									onPressed: onTap,
									child: Container(
										padding: const EdgeInsets.all(8),
										decoration: BoxDecoration(
											color: ChanceTheme.primaryColorOf(context),
											borderRadius: BorderRadius.circular(8),
											border: Border.all(
												color: ChanceTheme.backgroundColorOf(context)
											)
										),
										child: ImageboardScope(
											imageboardKey: null, // it could be the dev board
											imageboard: notification.imageboard,
											child: ConstrainedBox(
												constraints: BoxConstraints(
													maxWidth: maxWidth,
													maxHeight: 200
												),
												child: NotificationContent(
													notification: notification.notification,
													topRightCornerInsetWidth: 50
												)
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
													color: ChanceTheme.secondaryColorOf(context),
													onPressed: onTapMute,
													child: Icon(CupertinoIcons.bell_slash, size: 20, color: ChanceTheme.primaryColorOf(context))
												),
												const SizedBox(width: 8),
											],
											CupertinoButton(
												minSize: 0,
												padding: EdgeInsets.zero,
												borderRadius: BorderRadius.circular(100),
												color: ChanceTheme.secondaryColorOf(context),
												onPressed: onTapClose,
												child: Stack(
													alignment: Alignment.center,
													children: [
														Icon(CupertinoIcons.xmark, size: 17, color: ChanceTheme.primaryColorOf(context)),
														IgnorePointer(
															child: AnimatedBuilder(
																animation: notification.autoCloseAnimation!,
																builder: (context, _) => Transform.scale(
																	scale: 0.8,
																	child: CircularProgressIndicator(
																		value: notification.autoCloseAnimation!.value,
																		color: ChanceTheme.primaryColorOf(context),
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
			)
		);
	}
}
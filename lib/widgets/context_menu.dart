import 'dart:async';
import 'dart:math';

import 'package:chan/services/imageboard.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/screen_size_hacks.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/cupertino_context_menu2.dart';
import 'package:chan/widgets/default_gesture_detector.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

class ContextMenuAction {
	final Widget child;
	final IconData trailingIcon;
	final FutureOr<void> Function() onPressed;
	final bool isDestructiveAction;
	final Key? key;
	ContextMenuAction({
		required this.child,
		required this.trailingIcon,
		required this.onPressed,
		this.isDestructiveAction = false,
		this.key
	});
}

enum ContextMenuHintMode {
	longPressEnabled,
	longPressDisabled,
	withinPreview
}

class ContextMenuHint {
	final _ContextMenuState _state;
	final ContextMenuHintMode mode;
	ContextMenuHint._(this._state, this.mode);
	void open({Rect? from}) => _state.show(from: from);
	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is ContextMenuHint &&
		other._state == _state &&
		other.mode == mode;
	@override
	int get hashCode => Object.hash(_state, mode);
}

class ContextMenu extends StatefulWidget {
	final List<ContextMenuAction> actions;
	final Widget child;
	final double? maxHeight;
	final Widget Function(BuildContext, Widget?)? previewBuilder;
	final Color? backgroundColor;
	final Rect Function(Rect)? trimStartRect;
	final bool enableLongPress;
	final SelectableRegionContextMenuBuilder Function(SelectedContent? Function())? contextMenuBuilderBuilder;

	const ContextMenu({
		required this.actions,
		required this.child,
		this.maxHeight,
		this.previewBuilder,
		this.backgroundColor,
		this.trimStartRect,
		this.enableLongPress = true,
		this.contextMenuBuilderBuilder,
		Key? key
	}) : super(key: key);

	@override
	createState() => _ContextMenuState();
}

class _ContextMenuState extends State<ContextMenu> {
	OverlayEntry? _overlayEntry;
	Offset? lastTap;
	final _cupertinoKey = GlobalKey<CupertinoContextMenuState2>(debugLabel: '_ContextMenuState._cupertinoKey');
	SelectedContent? _lastSelection;

	void _onLongPress({Rect? from}) async {
		final l = ((lastTap?.dx ?? 0) / Persistence.settings.interfaceScale) + 5;
		final t = ((lastTap?.dy ?? 0) / Persistence.settings.interfaceScale) + 5;
		final s = context.findAncestorWidgetOfExactType<MediaQuery>()!.data.size;
		mediumHapticFeedback();
		final action = await showMenu(
			useRootNavigator: true,
			items: widget.actions.map((action) => PopupMenuItem(
				value: action,
				key: action.key,
				child: Row(
					mainAxisAlignment: MainAxisAlignment.spaceBetween,
					children: [
						DefaultTextStyle.merge(
							style: action.isDestructiveAction ? const TextStyle(color: Colors.red) : const TextStyle(),
							child: action.child
						),
						Icon(action.trailingIcon, color: action.isDestructiveAction ? Colors.red : null)
					]
				)
			)).toList(),
			context: context,
			constraints: const BoxConstraints(maxHeight: 500),
			position: switch (from) {
				Rect rect => RelativeRect.fromRect(rect, Offset.zero & s),
				null => RelativeRect.fromLTRB(l, t, s.width - l, s.height - t)
			}
		);
		action?.onPressed();
	}

	Widget _buildMaterial() {
		assert((widget.previewBuilder == null) || (widget.backgroundColor == null), 'backgroundColor behind previewBuilder not supported');
		return widget.previewBuilder == null ? Material(
			color: widget.backgroundColor,
			child: InkWell(
				onTapDown: (d) {
					lastTap = d.globalPosition;
				},
				onTap: () {
					context.read<DefaultOnTapCallback?>()?.onTap?.call();
				},
				onLongPress: _onLongPress,
				child: widget.child
			)
		) : GestureDetector(
			onLongPressStart: widget.enableLongPress ? (d) {
				lastTap = d.globalPosition;
				_onLongPress();
			} : null,
			child: widget.child
		);
	}

	Widget _buildCupertino() {
		// Only rebuild when object changes identity
		final zone = context.watchIdentity<PostSpanZoneData?>();
		final imageboard = context.watchIdentity<Imageboard?>();
		final site = context.watch<ImageboardSite?>();
		final persistence = context.watchIdentity<Persistence?>();
		final threadWatcher = context.watchIdentity<ThreadWatcher?>();
		final notifications = context.watch<Notifications?>();
		// Need to be null-safe here. Because we could be building within export-image environment
		final navigator = Navigator.maybeOf(context, rootNavigator: true);
		final actions = widget.actions.map((action) => CupertinoContextMenuAction2(
			trailingIcon: action.trailingIcon,
			key: action.key,
			onPressed: () async {
				try {
					navigator?.pop();
					await action.onPressed();
				}
				catch (e, st) {
					print(e);
					print(st);
					if (context.mounted) {
						alertError(context, e, st);
					}
				}
			},
			isDestructiveAction: action.isDestructiveAction,
			child: action.child
		)).toList();
		final child = widget.backgroundColor == null ? widget.child : DecoratedBox(
			decoration: BoxDecoration(
				color: widget.backgroundColor
			),
			child: widget.child
		);
		Widget previewBuilder(BuildContext context) => MultiProvider(
			providers: [
				// At least one provider is required
				Provider<ContextMenuHint>.value(value: ContextMenuHint._(this, widget.enableLongPress ? ContextMenuHintMode.longPressEnabled : ContextMenuHintMode.withinPreview)),
				if (zone != null) ChangeNotifierProvider<PostSpanZoneData>.value(value: zone),
				if (imageboard != null) ChangeNotifierProvider<Imageboard>.value(value: imageboard),
				if (site != null) Provider<ImageboardSite>.value(value: site),
				if (persistence != null) ChangeNotifierProvider<Persistence>.value(value: persistence),
				if (threadWatcher != null) ChangeNotifierProvider<ThreadWatcher>.value(value: threadWatcher),
				if (notifications != null) Provider<Notifications>.value(value: notifications)
			],
			child: IgnorePointer(child: widget.previewBuilder?.call(context, null) ?? child)
		);
		return CupertinoContextMenu2(
			key: _cupertinoKey,
			actions: actions,
			previewBuilder: (context, animation, child) {
				final ctx = _cupertinoKey.currentContext;
				double? width;
				if ((ctx?.mounted ?? false)) {
					try {
						width = (ctx?.findRenderObject() as RenderBox?)?.size.width;
					}
					on Exception {
						// Ignore, probably _lifecycleState wrong
					}
					on AssertionError {
						// Ignore, probably _lifecycleState wrong
					}
				}
				final child = Builder(
					builder: previewBuilder
				);
				return FixedWidthLayoutBox(
					width: width ?? estimateWidth(context),
					child: widget.contextMenuBuilderBuilder == null ? child : SelectionArea(
						contextMenuBuilder: widget.contextMenuBuilderBuilder?.call(() => _lastSelection),
						onSelectionChanged: (selection) => _lastSelection = selection,
						child: SingleChildScrollView(
							child: child
						)
					)
				);
			},
			enableLongPress: widget.enableLongPress,
			trimStartRect: widget.trimStartRect,
			child: child
		);
	}

	void show({Rect? from}) {
		if (Settings.instance.materialStyle) {
			_onLongPress(from: from);
		}
		else {
			_cupertinoKey.currentState!.onLongPress(fast: true);
		}
	}

	@override
	Widget build(BuildContext context) {
		final iconSize = 24 * Settings.textScaleSetting.watch(context);
		final interfaceScale = Settings.interfaceScaleSetting.watch(context);
		final child = GestureDetector(
			onSecondaryTapUp: (event) {
				_overlayEntry = OverlayEntry(
					builder: (context) {
						return Stack(
							children: [
								Positioned.fill(
									child: GestureDetector(
										child: Container(color: Colors.transparent),
										onTap: () => _overlayEntry?.remove(),
										onSecondaryTap: () => _overlayEntry?.remove()
									)
								),
								CustomSingleChildLayout(
									delegate: _ContextMenuLayoutDelegate(
										rightClickPosition: event.globalPosition.scale(1 / interfaceScale, 1 / interfaceScale)
									),
									child: Container(
										decoration: BoxDecoration(
											border: Border.all(color: Colors.grey),
											borderRadius: const BorderRadius.all(Radius.circular(4)),
											color: ChanceTheme.backgroundColorOf(context)
										),
										margin: const EdgeInsets.only(bottom: 8, right: 8),
										child: IntrinsicWidth(
											child: Column(
												mainAxisSize: MainAxisSize.min,
												crossAxisAlignment: CrossAxisAlignment.start,
												children: widget.actions.map((action) {
													return CupertinoButton(
														key: action.key,
														padding: const EdgeInsets.all(16),
														onPressed: () async {
															_overlayEntry?.remove();
															try {
																await action.onPressed();
															}
															catch (e, st) {
																if (context.mounted) {
																	alertError(context, e, st);
																}
															}
														},
														child: Row(
															mainAxisSize: MainAxisSize.min,
															mainAxisAlignment: MainAxisAlignment.spaceBetween,
															children: [
																action.child,
																const Spacer(),
																const SizedBox(width: 8),
																Icon(action.trailingIcon, size: iconSize)
															]
														)
													);
												}).toList()
											)
										)
									)
								)
							]
						);
					}
				);
				Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
			},
			child: Provider.value(
				value: ContextMenuHint._(this, widget.enableLongPress ? ContextMenuHintMode.longPressEnabled : ContextMenuHintMode.longPressDisabled),
				child: ChanceTheme.materialOf(context) ? _buildMaterial() : _buildCupertino()
			)
		);
		if (widget.maxHeight != null) {
			return ConstrainedBox(
				constraints: BoxConstraints(
					maxHeight: widget.maxHeight!
				),
				child: child
			);
		}
		return child;
	}
}

class _ContextMenuLayoutDelegate extends SingleChildLayoutDelegate {
	final Offset rightClickPosition;

	const _ContextMenuLayoutDelegate({
		required this.rightClickPosition
	});

	@override
	BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
		return constraints;
	}

	@override
	Offset getPositionForChild(Size size, Size childSize) {
		final y = min(size.height - childSize.height, rightClickPosition.dy);
		if (rightClickPosition.dx > (size.width - childSize.width)) {
			// Put it to the left of mouse
			return Offset(rightClickPosition.dx - childSize.width, y);
		}
		return Offset(rightClickPosition.dx, y);
	}


	@override
	bool shouldRelayout(_ContextMenuLayoutDelegate oldDelegate) {
		return rightClickPosition != oldDelegate.rightClickPosition;
	}
}
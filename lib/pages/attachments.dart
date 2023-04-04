import 'dart:async';
import 'dart:math';

import 'package:chan/models/attachment.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/services/apple.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/attachment_viewer.dart';
import 'package:chan/widgets/cupertino_context_menu2.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mutex/mutex.dart';
import 'package:provider/provider.dart';

class AttachmentsPage extends StatefulWidget {
	final List<TaggedAttachment> attachments;
	final TaggedAttachment? initialAttachment;
	final ValueChanged<TaggedAttachment>? onChange;
	final PersistentThreadState? threadState;
	const AttachmentsPage({
		required this.attachments,
		this.initialAttachment,
		this.onChange,
		this.threadState,
		Key? key
	}) : super(key: key);

	@override
	createState() => _AttachmentsPageState();
}

class _AttachmentsPageState extends State<AttachmentsPage> {
	final Map<TaggedAttachment, AttachmentViewerController> _controllers = {};
	late final RefreshableListController<TaggedAttachment> _controller;
	TaggedAttachment? _lastPrimary;
	AttachmentViewerController? get _lastPrimaryController {
		if (_lastPrimary == null) {
			return null;
		}
		return _controllers[_lastPrimary!];
	}
	bool _showAdjustmentOverlay = false;
	double _lastScale = 1;
	final _listKey = GlobalKey();
	final _loadingLock = Mutex();
	final _loadingQueue = <AttachmentViewerController>[];
	TaggedAttachment? _lastMiddleVisibleItem;

	void _queueLoading(AttachmentViewerController controller) {
		_loadingQueue.add(controller);
		_loadingLock.protect(() async {
			if (_loadingQueue.isEmpty) {
				return;
			}
			// LIFO stack
			final item = _loadingQueue.removeLast();
			await Future.microtask(() => item.preloadFullAttachment());
		});
	}

	@override
	void initState() {
		super.initState();
		_controller = RefreshableListController();
		if (widget.initialAttachment != null) {
			Future.delayed(const Duration(milliseconds: 250), () {
				_controller.animateTo((a) => a.attachment.id == widget.initialAttachment?.attachment.id);
			});
		}
		Future.delayed(const Duration(seconds: 1), () {
			_controller.slowScrolls.addListener(_onSlowScroll);
		});
	}

	void _onSlowScroll() {
		final middleVisibleItem = _controller.middleVisibleItem;
		if (middleVisibleItem != null) {
			if (middleVisibleItem != _lastMiddleVisibleItem) {
				widget.onChange?.call(middleVisibleItem);
			}
			final maxColumnWidth = context.read<EffectiveSettings>().attachmentsPageMaxCrossAxisExtent;
			final screenWidth = (context.findRenderObject() as RenderBox?)?.paintBounds.width ?? double.infinity;
			final columnCount = max(1, screenWidth ~/ maxColumnWidth);
			if (columnCount == 1) {
				// This is one-column view
				if (middleVisibleItem != _lastMiddleVisibleItem) {
					if (_lastMiddleVisibleItem != null) {
						_getController(_lastMiddleVisibleItem!).isPrimary = false;
					}
					_getController(middleVisibleItem).isPrimary = true;
				}
			}
			_lastMiddleVisibleItem = middleVisibleItem;
		}
		if (_lastPrimary != null) {
			if (!_controller.isOnscreen(_lastPrimary!)) {
				_lastPrimaryController?.isPrimary = false;
			}
		}
	}

	AttachmentViewerController _getController(TaggedAttachment attachment) {
		return _controllers.putIfAbsent(attachment, () {
			final controller = AttachmentViewerController(
				context: context,
				attachment: attachment.attachment,
				site: context.read<ImageboardSite>(),
				isPrimary: false
			);
			if (context.watch<EffectiveSettings>().autoloadAttachments && !attachment.attachment.isRateLimited) {
				if (attachment.attachment.type.isVideo) {
					_queueLoading(controller);
				}
				else {
					Future.microtask(() => controller.preloadFullAttachment());
				}
			}
			return controller;
		});
	}

	void _onScaleStart(ScaleStartDetails details) {
		_lastScale = 1;
		setState(() {
			_showAdjustmentOverlay = true;
		});
	}

	void _onScaleUpdate(ScaleUpdateDetails details) {
		if (details.scale == _lastScale) {
			(_controller.scrollController?.position as ScrollPositionWithSingleContext?)?.pointerScroll(-details.focalPointDelta.dy);
		}
		else {
			context.read<EffectiveSettings>().attachmentsPageMaxCrossAxisExtent = max(100, context.read<EffectiveSettings>().attachmentsPageMaxCrossAxisExtent + (100 * (details.scale - _lastScale)));
			_lastScale = details.scale;
		}
	}

	void _onScaleEnd(ScaleEndDetails details) {
		setState(() {
			_showAdjustmentOverlay = false;
		});
	}

	@override
	Widget build(BuildContext context) {
		final maxCrossAxisExtent = context.select<EffectiveSettings, double>((s) => s.attachmentsPageMaxCrossAxisExtent);
		return RawGestureDetector(
			gestures: {
				ScaleGestureRecognizer: GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
					() => ScaleGestureRecognizer(
						supportedDevices: ScrollConfiguration.of(context).dragDevices
					),
					(instance) =>
						instance..gestureSettings = const DeviceGestureSettings(touchSlop: 9999) // Only claim scales
										..onStart = _onScaleStart
										..onUpdate = _onScaleUpdate
										..onEnd = _onScaleEnd
				)
			},
			child: Stack(
				children: [
					Container(
						color: CupertinoTheme.of(context).scaffoldBackgroundColor,
						child: RefreshableList<TaggedAttachment>(
							key: _listKey,
							filterableAdapter: null,
							id: '${widget.attachments.length} attachments',
							controller: _controller,
							listUpdater: () => throw UnimplementedError(),
							disableUpdates: true,
							initialList: widget.attachments,
							gridDelegate: SliverStaggeredGridDelegate(
								aspectRatios: widget.attachments.map((a) {
									final rawRatio = (a.attachment.width ?? 1) / (a.attachment.height ?? 1);
									// Prevent too extreme dimensions
									return rawRatio.clamp(1/6, 6.0);
								}).toList(),
								maxCrossAxisExtent: maxCrossAxisExtent
							),
							itemBuilder: (context, attachment) => Stack(
								alignment: Alignment.center,
								children: [
									CupertinoButton(
										padding: EdgeInsets.zero,
										onPressed: () async {
											final wasPrimary = _getController(attachment).isPrimary;
											_getController(attachment).isPrimary = false;
											await showGalleryPretagged(
												context: context,
												attachments: widget.attachments,
												initialGoodSources: {
													for (final controller in _controllers.values)
														if (controller.goodImageSource != null)
															controller.attachment: controller.goodImageSource!
												},
												initialAttachment: attachment,
												isAttachmentAlreadyDownloaded: widget.threadState?.isAttachmentDownloaded,
												onAttachmentDownload: widget.threadState?.didDownloadAttachment,
												useHeroDestinationWidget: true,
												heroOtherEndIsBoxFitCover: false
											);
											_getController(attachment).isPrimary = wasPrimary;
											Future.microtask(() => _getController(attachment).loadFullAttachment());
										},
										child: Hero(
											tag: attachment,
											createRectTween: (startRect, endRect) {
												if (startRect != null && endRect != null && attachment.attachment.type == AttachmentType.image) {
													// Need to deflate the original startRect because it has inbuilt layoutInsets
													// This AttachmentViewer doesn't know about them.
													final rootPadding = MediaQueryData.fromView(WidgetsBinding.instance.window).padding - sumAdditionalSafeAreaInsets();
													startRect = rootPadding.deflateRect(startRect);
												}
												return RectTween(begin: startRect, end: endRect);
											},
											child: AnimatedBuilder(
												animation: _getController(attachment),
												builder: (context, child) => SizedBox.expand(
													child: AttachmentViewer(
														controller: _getController(attachment),
														allowGestures: false,
														semanticParentIds: const [-101],
														useHeroDestinationWidget: true,
														heroOtherEndIsBoxFitCover: false,
														videoThumbnailMicroPadding: false,
														onlyRenderVideoWhenPrimary: true,
														additionalContextMenuActions: [
															CupertinoContextMenuAction2(
																trailingIcon: CupertinoIcons.return_icon,
																onPressed: () {
																	Navigator.of(context, rootNavigator: true).pop();
																	Navigator.pop(context, attachment);
																},
																child: const Text('Scroll to post')
															)
														]
													)
												)
											)
										)
									),
									AnimatedBuilder(
										animation: _getController(attachment),
										builder: (context, child) => Visibility(
											visible: (attachment.attachment.type.isVideo && !_getController(attachment).isPrimary),
											child: CupertinoButton(
												onPressed: () {
													_lastPrimaryController?.isPrimary = false;
													Future.microtask(() => _getController(attachment).loadFullAttachment());
													_lastPrimary = attachment;
													_lastPrimaryController?.isPrimary = true;
												},
												child: const Icon(CupertinoIcons.play_fill, size: 50)
											)
										)
									)
								]
							)
						)
					),
					Center(
						child: AnimatedOpacity(
							opacity: _showAdjustmentOverlay ? 1 : 0,
							duration: const Duration(milliseconds: 250),
							curve: Curves.ease,
							child: Container(
								decoration: BoxDecoration(
									borderRadius: BorderRadius.circular(8),
									color: Colors.black54
								),
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										mainAxisSize: MainAxisSize.min,
										children: [
											const Icon(CupertinoIcons.resize),
											const SizedBox(height: 16),
											Text('Max column width: ${maxCrossAxisExtent.round()} px')
										]
									)
								)
							)
						)
					)
				]
			)
		);
	}

	@override
	void dispose() {
		super.dispose();
		_controller.slowScrolls.removeListener(_onSlowScroll);
		_controller.dispose();
		for (final controller in _controllers.values) {
			controller.dispose();
		}
		_loadingQueue.clear();
	}
}

typedef StaggeredGridMember = ({int index, double height, double offset});

class SliverStaggeredGridDelegate extends SliverGridDelegate {
	final List<double> aspectRatios;
	final double maxCrossAxisExtent;

	const SliverStaggeredGridDelegate({
		required this.aspectRatios,
		required this.maxCrossAxisExtent
	});

	@override
	SliverGridLayout getLayout(SliverConstraints constraints) {
		final columnCount = (constraints.crossAxisExtent / maxCrossAxisExtent).ceil();
		final width = constraints.crossAxisExtent / columnCount;
		final columns = List.generate(columnCount, (_) => <StaggeredGridMember>[]);
		final columnHeightRunningTotals = List.generate(columnCount, (_) => 0.0);
		for (int i = 0; i < aspectRatios.length; i++) {
			int column = -1;
			double minHeight = double.infinity;
			for (int j = 0; j < columnCount; j++) {
				if (columnHeightRunningTotals[j] < minHeight) {
					minHeight = columnHeightRunningTotals[j];
					column = j;
				}
			}
			columns[column].add((
				index: i,
				height: width / aspectRatios[i],
				offset: columnHeightRunningTotals[column]
			));
			columnHeightRunningTotals[column] += columns[column].last.height;
		}
		if (aspectRatios.length > columnCount) {
			for (int swap = 0; swap < columnCount; swap++) {
				int shortestColumn = -1;
				double shortestHeight = double.infinity;
				int tallestColumn = -1;
				double tallestHeight = -1;
				for (int i = 0; i < columns.length; i++) {
					final height = columns[i].last.height + columns[i].last.offset;
					if (height < shortestHeight) {
						shortestColumn = i;
						shortestHeight = height;
					}
					if (height > tallestHeight) {
						tallestColumn = i;
						tallestHeight = height;
					}
				}
				final mismatch = tallestHeight - shortestHeight;
				if (columns[tallestColumn].length > 1) {
					final toMove = columns[tallestColumn][columns[tallestColumn].length - 2];
					final mismatchAfter = (mismatch - (2 * toMove.height)).abs();
					if (mismatchAfter < mismatch) {
						columns[tallestColumn].removeAt(columns[tallestColumn].length - 2);
						columns[tallestColumn].last = (
							index: columns[tallestColumn].last.index,
							height: columns[tallestColumn].last.height,
							offset: columns[tallestColumn].last.offset - toMove.height,
						);
						columns[shortestColumn].add((
							index: toMove.index,
							height: toMove.height,
							offset: columns[shortestColumn].last.offset + columns[shortestColumn].last.height
						));
					}
					else {
						break;
					}
				}
			}
		}
		return SliverStaggeredGridLayout(
			columns: columns,
			columnWidth: width
		);
	}

	@override
	bool shouldRelayout(SliverStaggeredGridDelegate oldDelegate) {
		return !listEquals(aspectRatios, oldDelegate.aspectRatios) || maxCrossAxisExtent != oldDelegate.maxCrossAxisExtent;
	}
	
}

class SliverStaggeredGridLayout extends SliverGridLayout {
	final double columnWidth;
	final Map<int, (int, StaggeredGridMember)> _lookupTable = {};
	final List<List<StaggeredGridMember>> columns;

	SliverStaggeredGridLayout({
		required this.columns,
		required this.columnWidth
	}) {
		_lookupTable.addAll({
			for (int i = 0; i < columns.length; i++)
				for (int j = 0; j < columns[i].length; j++)
					columns[i][j].index: (i, columns[i][j])
		});
	}

	@override
	double computeMaxScrollOffset(int childCount) {
		return columns.map((c) => c.fold<double>(0, (runningMax, item) {
			if (item.index < childCount) {
				return max(runningMax, item.offset + item.height);
			}
			return runningMax;
		})).fold<double>(0, max);
	}

	@override
	SliverGridGeometry getGeometryForChildIndex(int index) {
		final item = _lookupTable[index];
		if (item == null) {
			print('Tried to get geometry for invalid index $index (max is ${_lookupTable.length})');
			return const SliverGridGeometry(
				scrollOffset: 0,
				crossAxisOffset: 0,
				mainAxisExtent: 0,
				crossAxisExtent: 0
			);
		}
		return SliverGridGeometry(
			scrollOffset: item.$2.offset,
			crossAxisOffset: columnWidth * item.$1,
			mainAxisExtent: item.$2.height,
			crossAxisExtent: columnWidth
		);
	}

	@override
	int getMaxChildIndexForScrollOffset(double scrollOffset) {
		return _lookupTable.values.where((w) => w.$2.offset < scrollOffset).fold<int>(0, (t, x) => max(t, x.$2.index));
	}

	@override
	int getMinChildIndexForScrollOffset(double scrollOffset) {
		return _lookupTable.values.where((w) => (w.$2.height + w.$2.offset) >= scrollOffset).fold<int>(_lookupTable.length - 1, (t, x) => min(t, x.$2.index));
	}
}

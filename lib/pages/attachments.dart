import 'dart:async';
import 'dart:math';

import 'package:chan/pages/gallery.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/attachment_viewer.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
	AttachmentViewerController? _lastPrimary;
	bool _showAdjustmentOverlay = false;
	double _lastScale = 1;
	final _listKey = GlobalKey();

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
		final lastItem = _controller.middleVisibleItem;
		if (lastItem != null) {
			widget.onChange?.call(lastItem);
			final primary = _controllers[lastItem];
			if (primary != _lastPrimary) {
				_lastPrimary?.isPrimary = false;
				_controllers[lastItem]?.isPrimary = true;
				_lastPrimary = primary;
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
			if (context.watch<EffectiveSettings>().autoloadAttachments) {
				Future.microtask(() => controller.loadFullAttachment());
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
			context.read<EffectiveSettings>().attachmentsPageMaxCrossAxisExtent += 100 * (details.scale - _lastScale);
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
							itemBuilder: (context, attachment) => CupertinoButton(
								padding: EdgeInsets.zero,
								onPressed: () async {
									_getController(attachment).isPrimary = false;
									await showGalleryPretagged(
										context: context,
										attachments: widget.attachments,
										initialAttachment: attachment,
										isAttachmentAlreadyDownloaded: widget.threadState?.isAttachmentDownloaded,
										onAttachmentDownload: widget.threadState?.didDownloadAttachment,
										useHeroDestinationWidget: true,
										heroOtherEndIsBoxFitCover: false
									);
									_getController(attachment).isPrimary = true;
								},
								child: IgnorePointer(
									ignoring: false,
									child: Hero(
										tag: attachment,
										child: AnimatedBuilder(
											animation: _getController(attachment),
											builder: (context, child) => AttachmentViewer(
												controller: _getController(attachment),
												allowGestures: false,
												semanticParentIds: const [-101],
												heroOtherEndIsBoxFitCover: false
											)
										)
									)
								)
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
											Text('Column width: ${maxCrossAxisExtent.round()} px')
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
		final columnCount = constraints.crossAxisExtent ~/ maxCrossAxisExtent;
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
				double tallestHeight = 0;
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
		print(!listEquals(aspectRatios, oldDelegate.aspectRatios) || maxCrossAxisExtent != oldDelegate.maxCrossAxisExtent);
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

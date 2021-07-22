import 'dart:io';

import 'package:chan/models/attachment.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/services/rotating_image_provider.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/circular_loading_indicator.dart';
import 'package:chan/widgets/rx_stream_builder.dart';
import 'package:chan/widgets/util.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:video_player/video_player.dart';

class AttachmentViewer extends StatelessWidget {
	final Attachment attachment;
	final AttachmentStatus status;
	final Color backgroundColor;
	final Object tag;
	final ValueChanged<File>? onCacheCompleted;
	final bool autoRotate;
	final GlobalKey<ExtendedImageGestureState> gestureKey;
	final BehaviorSubject<Null> slideStream;

	AttachmentViewer({
		required this.attachment,
		required this.gestureKey,
		required this.status,
		required this.slideStream,
		this.backgroundColor = Colors.black,
		required this.tag,
		this.onCacheCompleted,
		this.autoRotate = false,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return FirstBuildDetector(
			identifier: tag,
			builder: (context, passedFirstBuild) {
				int quarterTurns = 0;
				final displayIsLandscape = MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
				if (autoRotate && (((attachment.isLandscape ?? false) && !displayIsLandscape) || (!(attachment.isLandscape ?? true) && displayIsLandscape))) {
					quarterTurns = 1;
				}
				if (attachment.type == AttachmentType.Image) {
					Uri url = attachment.thumbnailUrl;
					bool cacheCompleted = false;
					if (status is AttachmentImageUrlAvailableStatus) {
						cacheCompleted = (status as AttachmentImageUrlAvailableStatus).cacheCompleted;
						if (passedFirstBuild) {
							url = (status as AttachmentImageUrlAvailableStatus).url;
						}
					}
					ImageProvider image = ExtendedNetworkImageProvider(
						url.toString(),
						cache: true
					);
					if (url.scheme == 'file') {
						image = ExtendedFileImageProvider(
							File(url.path),
							imageCacheName: 'asdf'
						);
					}
					if (quarterTurns != 0) {
						image = RotatingImageProvider(parent: image, quarterTurns: quarterTurns);
					}
					return ExtendedImage(
						image: image,
						extendedImageGestureKey: gestureKey,
						enableSlideOutPage: true,
						gaplessPlayback: true,
						fit: BoxFit.contain,
						mode: ExtendedImageMode.gesture,
						width: double.infinity,
						height: double.infinity,
						enableLoadState: true,
						handleLoadingProgress: true,
						onDoubleTap: (state) {
							final old = state.gestureDetails!;
							state.gestureDetails = GestureDetails(
								offset: state.pointerDownPosition!.scale(old.layoutRect!.width / MediaQuery.of(context).size.width, old.layoutRect!.height / MediaQuery.of(context).size.height) * -1,
								totalScale: (old.totalScale ?? 1) > 1 ? 1 : 2,
								actionType: ActionType.zoom
							);
						},
						loadStateChanged: (loadstate) {
							if ((loadstate.extendedImageLoadState == LoadState.completed) && (status is AttachmentImageUrlAvailableStatus) && !cacheCompleted) {
								getCachedImageFile(url.toString()).then((file) {
									if (file != null) {
										onCacheCompleted?.call(file);
									}
								});
							}
							if (!cacheCompleted) {
								double? loadingValue;
								if (loadstate.loadingProgress?.cumulativeBytesLoaded != null && loadstate.loadingProgress?.expectedTotalBytes != null) {
									loadingValue = loadstate.loadingProgress!.cumulativeBytesLoaded / loadstate.loadingProgress!.expectedTotalBytes!;
								}
								return Stack(
									children: [
										loadstate.completedWidget,
										RxStreamBuilder(
											stream: slideStream,
											builder: (context, _) => Transform.translate(
												offset: gestureKey.currentState?.extendedImageSlidePageState?.offset ?? Offset.zero,
												child: Transform.scale(
													scale: (gestureKey.currentState?.extendedImageSlidePageState?.scale ?? 1) * (gestureKey.currentState?.gestureDetails?.totalScale ?? 1),
													child: Center(
														child: CircularLoadingIndicator(
															value: loadingValue
														)
													)
												)
											)
										)
									]
								);
							}
						},
						initGestureConfigHandler: (state) {
							return GestureConfig(
								inPageView: true
							);
						},
						heroBuilderForSlidingPage: (Widget result) {
							return Hero(
								tag: tag,
								child: result,
								flightShuttleBuilder: (ctx, animation, direction, from, to) => from.widget
							);
						}
					);
				}
				else {
					return ExtendedImageSlidePageHandler(
						heroBuilderForSlidingPage: (Widget result) {
							return Hero(
								tag: tag,
								child: result,
								flightShuttleBuilder: (ctx, animation, direction, from, to) => from.widget
							);
						},
						child: Stack(
							children: [
								AttachmentThumbnail(
									attachment: attachment,
									width: double.infinity,
									height: double.infinity,
									quarterTurns: quarterTurns,
									gaplessPlayback: true
								),
								if (status is AttachmentUnavailableStatus) Center(
									child: ErrorMessageCard((status as AttachmentUnavailableStatus).cause)
								)
								else if (status is AttachmentLoadingStatus) Center(
									child: CircularLoadingIndicator(value: (status as AttachmentLoadingStatus).progress)
								)
								else if (status is AttachmentVideoAvailableStatus) Center(
									child: RotatedBox(
										quarterTurns: quarterTurns,
										child: AspectRatio(
											aspectRatio: (status as AttachmentVideoAvailableStatus).controller.value.aspectRatio,
											child: VideoPlayer((status as AttachmentVideoAvailableStatus).controller)
										)
									)
								)
							]
						)
					);
				}
			}
		);
	}
}
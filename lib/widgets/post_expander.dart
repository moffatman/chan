import 'package:chan/models/post.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/gallery_manager.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:extended_image/extended_image.dart';

class ExpandingPostZone extends ChangeNotifier {
	final Map<int, bool> _shouldExpandPost = Map();
	final int parentId;

	ExpandingPostZone(this.parentId);

	bool shouldExpandPost(int id) {
		return _shouldExpandPost[id] ?? false;
	}

	void toggleExpansionOfPost(int id) {
		_shouldExpandPost[id] = !shouldExpandPost(id);
		notifyListeners();
	}
}

GlobalKey<ExtendedImageSlidePageState> slidePageKey = GlobalKey();

class ExpandingPost extends StatelessWidget {
	final int id;
	ExpandingPost(this.id);
	
	@override
	Widget build(BuildContext context) {
		return context.watch<ExpandingPostZone>().shouldExpandPost(this.id) ? Provider.value(
			value: context.watch<List<Post>>().firstWhere((p) => p.id == this.id),
			child: PostRow(
				onThumbnailTap: (attachment, {Object? tag}) {
					final url = context.read<ImageboardSite>().getAttachmentUrl(attachment).toString();
					final thumbnailUrl = context.read<ImageboardSite>().getAttachmentThumbnailUrl(attachment).toString();
					Navigator.of(context).push(TransparentRoute(
						builder: (BuildContext context) {
							return ExtendedImageSlidePage(
								key: slidePageKey,
								resetPageDuration: const Duration(milliseconds: 100),
								slidePageBackgroundHandler: (offset, size) {
									return Colors.black.withOpacity((0.38 * (1 - (offset.dx / size.width).abs()) * (1 - (offset.dy / size.height).abs())).clamp(0, 1));
								},
								child: GestureDetector(
									child: ExtendedImage.network(
										url,
										enableSlideOutPage: true,
										cache: true,
										enableLoadState: true,
										loadStateChanged: (loadstate) {
											if (loadstate.extendedImageLoadState == LoadState.loading) {
												return Stack(
													children: [
														ExtendedImage.network(
															thumbnailUrl,
															cache: true,
															height: double.infinity,
															width: double.infinity,
															fit: BoxFit.contain,
														),
														Center(
															child: CircularProgressIndicator()
														)
													]
												);
											}
											else if (loadstate.extendedImageLoadState == LoadState.completed) {
												return null;
											}
											else if (loadstate.extendedImageLoadState == LoadState.failed) {
												return Center(
													child: Text("Error")
												);
											}
										},
										heroBuilderForSlidingPage: (Widget result) {
											return Hero(
												tag: tag!,
												child: result,
												flightShuttleBuilder: (ctx, animation, direction, from, to) {
													return (direction == HeroFlightDirection.pop) ? from.widget : to.widget;
												}
											);
										}
									),
									onTap: () {
										slidePageKey.currentState!.popPage();
										Navigator.of(context).pop();
									}
								)
							);
						}
					));
				}
			)
		) : Container(width: 0, height: 0);
	}
}
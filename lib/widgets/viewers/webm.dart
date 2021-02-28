import 'package:chan/models/attachment.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/services/util.dart';
import 'package:chan/services/webm.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'package:extended_image/extended_image.dart';

enum WEBMViewerStatus {
	Loading,
	Playing,
	Error
}

class WEBMViewer extends StatefulWidget {
	final Uri url;
	final Attachment attachment;
	final Color backgroundColor;

	WEBMViewer({
		required this.url,
		required this.attachment,
		this.backgroundColor = Colors.black
	});

	@override
	createState() => _WEBMViewerState();
}

class _WEBMViewerState extends State<WEBMViewer> {
	late WEBM webm;
	late ChewieController _chewieController;
	late VideoPlayerController _videoPlayerController;
	WEBMViewerStatus playerStatus = WEBMViewerStatus.Loading;
	WEBMStatus loadingStatus = WEBMStatus(type: WEBMStatusType.Idle);

	_initializeWebm() {
		if (isDesktop()) {
			/*_videoPlayerController = VideoPlayerController.network(widget.url.toString());
			_chewieController = ChewieController(
				videoPlayerController: _videoPlayerController,
				autoPlay: true
			);*/
			playerStatus = WEBMViewerStatus.Error;
			loadingStatus = WEBMStatus(type: WEBMStatusType.Error, message: 'WEBM disabled on desktop');
		}
		else {
			webm = WEBM(
				url: widget.url,
				client: context.watch<ImageboardSite>().client
			);
			playerStatus = WEBMViewerStatus.Loading;
			webm.startProcessing();
			webm.status.listen((status) {
				print(status);
				if (status.type == WEBMStatusType.Converted) {
					setState(() {
						_videoPlayerController = VideoPlayerController.file(status.file);
						_videoPlayerController.initialize();
						_chewieController = ChewieController(
							videoPlayerController:  _videoPlayerController,
							autoPlay: true,
							looping: true
						);
						playerStatus = WEBMViewerStatus.Playing;
					});
				}
				else if (status.type == WEBMStatusType.Error) {
					setState(() {
						loadingStatus = status;
						playerStatus = WEBMViewerStatus.Error;
					});
				}
				else {
					setState(() {
						loadingStatus = status;
					});
				}
			});
		}
	}

	@override
	void initState() {
		super.initState();
	}

	@override
	void didChangeDependencies() {
		super.didChangeDependencies();
		_initializeWebm();
	}

	@override
	void didUpdateWidget(WEBMViewer oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.url != widget.url) {
			_initializeWebm();
		}
	}

	Widget build(BuildContext context) {
		return ExtendedImageSlidePageHandler(
			heroBuilderForSlidingPage: (Widget result) {
				return Hero(
					tag: widget.attachment,
					child: result,
					flightShuttleBuilder: (ctx, animation, direction, from, to) {
						return (direction == HeroFlightDirection.pop) ? from.widget : to.widget;
					}
				);
			},
			child: _build(context)
		);
	}

	Widget _build(BuildContext context) {
		if (playerStatus == WEBMViewerStatus.Error) {
			return Center(
				child: Container(
					padding: EdgeInsets.all(16),
					decoration: BoxDecoration(
						color: CupertinoTheme.of(context).scaffoldBackgroundColor,
						borderRadius: BorderRadius.all(Radius.circular(8))
					),
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							Icon(Icons.error, color: DefaultTextStyle.of(context).style.color),
							Text(loadingStatus.message ?? 'Unknown error')
						]
					)
				)
			);
		}
		else if (playerStatus == WEBMViewerStatus.Loading) {
			if (loadingStatus.type == WEBMStatusType.Downloading) {
				return Center(
					child: CircularProgressIndicator(
						value: loadingStatus.progress,
						valueColor: AlwaysStoppedAnimation(Colors.blue)
					)
				);
			}
			else {
				return Center(
					child: CircularProgressIndicator(
						value: loadingStatus.progress,
						valueColor: AlwaysStoppedAnimation(Colors.green),
						backgroundColor: Colors.blue,
					)
				);
			}
		}
		else {
			return Chewie(
				controller: _chewieController
			);
		}
	}
}
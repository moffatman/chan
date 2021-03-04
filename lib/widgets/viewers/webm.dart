import 'package:chan/models/attachment.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/services/util.dart';
import 'package:chan/services/webm.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'package:extended_image/extended_image.dart';

class WEBMViewer extends StatefulWidget {
	final Uri url;
	final Attachment attachment;
	final Color backgroundColor;
	final Object? tag;

	WEBMViewer({
		required this.url,
		required this.attachment,
		this.backgroundColor = Colors.black,
		this.tag
	});

	@override
	createState() => _WEBMViewerState();
}

class _WEBMViewerState extends State<WEBMViewer> {
	late WEBM webm;
	ChewieController? _chewieController;
	VideoPlayerController? _videoPlayerController;
	WEBMStatus? loadingStatus;

	_initializeWebm() {
		if (isDesktop()) {
			/*_videoPlayerController = VideoPlayerController.network(widget.url.toString());
			_chewieController = ChewieController(
				videoPlayerController: _videoPlayerController,
				autoPlay: true
			);*/
			loadingStatus = WEBMErrorStatus('WEBM disabled on desktop');
		}
		else {
			webm = WEBM(
				url: widget.url,
				client: context.watch<ImageboardSite>().client
			);
			webm.startProcessing();
			webm.status.listen((status) async {
				if (status is WEBMReadyStatus) {
					_videoPlayerController = VideoPlayerController.file(status.file);
					await _videoPlayerController!.initialize();
					setState(() {
						_chewieController = ChewieController(
							videoPlayerController:  _videoPlayerController,
							autoPlay: true,
							looping: true,
							customControls: CupertinoTheme(data: CupertinoThemeData(primaryColor: Colors.black), child: MaterialControls()),
							allowPlaybackSpeedChanging: false,
							deviceOrientationsOnEnterFullScreen: [ _videoPlayerController!.value.aspectRatio > 1 ? DeviceOrientation.landscapeLeft : DeviceOrientation.portraitUp],
							deviceOrientationsAfterFullScreen: [
								DeviceOrientation.portraitUp
							]
						);
						loadingStatus = status;
					});
				}
				else if (status is WEBMErrorStatus) {
					setState(() {
						loadingStatus = status;
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
		if (loadingStatus == null) {
			_initializeWebm();
		}
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
					tag: widget.tag ?? widget.attachment,
					child: result
				);
			},
			child: _build(context)
		);
	}

	Widget _build(BuildContext context) {
		if (loadingStatus is WEBMReadyStatus) {
			if (context.watch<Attachment>() != widget.attachment) {
				_chewieController!.pause();
			}
			return Center(
				child: SafeArea(
					top: false,
					child: AspectRatio(
						aspectRatio: _videoPlayerController!.value.aspectRatio,
						child: Chewie(
							controller: _chewieController
						)
					)
				)
			);
		}
		else return Stack(
			children: [
				AttachmentThumbnail(attachment: widget.attachment, width: double.infinity, height: double.infinity),
				if (loadingStatus is WEBMErrorStatus) Center(
					child: Container(
						padding: EdgeInsets.all(16),
						decoration: BoxDecoration(
							color: CupertinoTheme.of(context).scaffoldBackgroundColor,
							borderRadius: BorderRadius.all(Radius.circular(8))
						),
						child: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								Icon(Icons.error),
								Text((loadingStatus as WEBMErrorStatus).errorMessage, style: TextStyle(color: CupertinoTheme.of(context).primaryColor))
							]
						)
					)
				)
				else if (loadingStatus is WEBMLoadingStatus) Center(
					child: CircularProgressIndicator(
						value: (loadingStatus as WEBMLoadingStatus).progress
					)
				)
				else Center(
					child: CircularProgressIndicator()
				)
			],
		);
	}

	@override
	void dispose() {
		_videoPlayerController?.dispose();
		_chewieController?.dispose();
		super.dispose();
	}
}
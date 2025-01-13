import 'package:chan/services/media.dart';
import 'package:chan/widgets/thumbnail_image_provider.dart';
import 'package:chan/widgets/widget_decoration.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MediaThumbnail extends StatefulWidget {
	final Uri uri;
	final Map<String, String>? headers;
	final BoxFit? fit;
	final double? fontSize;
	const MediaThumbnail({
		required this.uri,
		this.headers,
		this.fit,
		this.fontSize,
		Key? key
	}) : super(key: key);

	@override
	createState() => _MediaThumbnailState();
}

class _MediaThumbnailState extends State<MediaThumbnail> {
	MediaScan? scan;

	String get ext => widget.uri.path.split('.').last.toLowerCase();

	bool get isVideo => {
		'webm', 'mp4', 'mov', 'm4v', 'mkv', 'mpeg', 'avi', '3gp', 'm2ts'
	}.contains(ext);

	Future<void> _scan() async {
		if (isVideo) {
			scan = await MediaScan.scan(widget.uri);
			if (mounted) setState(() {});
		}
	}

	@override
	void initState() {
		super.initState();
		_scan();
	}

	@override
	void didUpdateWidget(MediaThumbnail old) {
		super.didUpdateWidget(old);
		if (widget.uri != old.uri) {
			setState(() {
				scan = null;
			});
			_scan();
		}
	}

	@override
	Widget build(BuildContext context) {
		return LayoutBuilder(
			builder: (context, constraints) {
				Widget? label;
				if (scan != null) {
					final minutes = scan!.duration?.inMinutes ?? 0;
					final seconds = (scan!.duration?.inSeconds ?? 0) - (minutes * 60);
					if ((seconds + minutes) > 0) {
						label = Text('${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}', style: TextStyle(fontSize: widget.fontSize));
					}
				}
				final image = Image(
					image: ThumbnailImageProvider(
						uri: widget.uri,
						headers: widget.headers
					),
					loadingBuilder: (context, child, progress) => Center(
						child: progress == null ? child : const CircularProgressIndicator.adaptive()
					),
					errorBuilder: (context, e, st) {
						Future.error(e, st); // crashlytics
						return const Icon(CupertinoIcons.question_square);
					},
					fit: widget.fit
				);
				if ((isVideo) && constraints.maxWidth > 50 && constraints.maxHeight > 50) {
					return Center(
						child: WidgetDecoration(
							position: DecorationPosition.foreground,
							decoration: label != null ? Align(
								alignment: Alignment.bottomRight,
								child: Container(
									decoration: const BoxDecoration(
										borderRadius: BorderRadius.only(topLeft: Radius.circular(4)),
										color: Colors.black54
									),
									padding: const EdgeInsets.only(left: 4, top: 4, right: 2, bottom: 2),
									child: label
								)
							) : null,
							child: image
						)
					);
				}
				else {
					return image;
				}
			}
		);
	}
}

import 'dart:io';

import 'package:chan/models/attachment.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/services/media.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/captcha.dart';
import 'package:chan/widgets/util.dart';
import 'package:chan/widgets/saved_attachment_thumbnail.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:heic_to_jpg/heic_to_jpg.dart';

class _AttachmentSource {
	final ImageSource source;
	final AttachmentType type;
	_AttachmentSource(this.source, this.type);
}

class ReplyBox extends StatefulWidget {
	final ThreadIdentifier thread;
	final VoidCallback onReplyPosted;
	final VoidCallback? onRequestFocus;
	final PersistentThreadState threadState;

	ReplyBox({
		required this.thread,
		required this.onReplyPosted,
		required this.threadState,
		this.onRequestFocus,
		Key? key
	}) : super(key: key);
	createState() => ReplyBoxState();
}

class ReplyBoxState extends State<ReplyBox> {
	final _textFieldController = TextEditingController();
	final _focusNode = FocusNode();
	bool loading = false;
	File? attachment;
	String? overrideAttachmentFilename;

	@override
	void initState() {
		super.initState();
		_textFieldController.addListener(() {
			setState(() {});
		});
	}

	void onTapPostId(int id) {
		widget.onRequestFocus?.call();
		_focusNode.requestFocus();
		int currentPos = _textFieldController.selection.base.offset;
		if (currentPos < 0) {
			currentPos = _textFieldController.text.length;
		}
		String insertedText = '>>$id';
		if (currentPos == _textFieldController.text.length) {
			insertedText += '\n';
		}
		_textFieldController.value = TextEditingValue(
			selection: TextSelection(
				baseOffset: currentPos + insertedText.length,
				extentOffset: currentPos + insertedText.length
			),
			text: _textFieldController.text.substring(0, currentPos) + insertedText + _textFieldController.text.substring(currentPos)
		);
	}

	void shouldRequestFocusNow() {
		_focusNode.requestFocus();
	}

	Future<File?> _showTranscodeWindow({
		required File source,
		int? size,
		int? maximumSize,
		bool? audioPresent,
		bool? audioAllowed,
		int? durationInSeconds,
		int? maximumDurationInSeconds,
		required MediaConversion transcode
	}) async {
		final ext = source.path.split('.').last.toLowerCase();
		bool loading = false;
		ValueNotifier<double?> progress = ValueNotifier<double?>(null);
		final problems = [
			if (ext != transcode.outputFileExtension) 'File type needs to be converted to .${transcode.outputFileExtension} from .$ext',
			if (size != null && maximumSize != null && (size > maximumSize)) 'Size needs to be reduced from ${(size / 1e6).toStringAsFixed(1)} MB to below ${(maximumSize / 1e6).toStringAsFixed(1)} MB',
			if (audioPresent == true && audioAllowed == false) 'Audio track needs to be removed',
			if (durationInSeconds != null && maximumDurationInSeconds != null && (durationInSeconds > maximumDurationInSeconds)) 'Duration needs to be clipped at $maximumDurationInSeconds seconds'
		];
		if (problems.isEmpty && ['jpg', 'jpeg', 'png', 'gif', 'webm'].contains(ext)) {
			return source;
		}
		final existingResult = await transcode.getDestinationIfSatisfiesConstraints();
		if (existingResult != null) {
			if ((audioPresent == true && audioAllowed == true && !existingResult.hasAudio)) {
				problems.add('Previous transcoding stripped out the audio');
			}
			else {
				return existingResult.file;
			}
		}
		return await Navigator.of(context).push<Future<File>>(TransparentRoute(
			builder: (context) => OverscrollModalPage(
				child: Container(
					width: MediaQuery.of(context).size.width,
					color: CupertinoTheme.of(context).scaffoldBackgroundColor,
					padding: EdgeInsets.all(16),
					child: StatefulBuilder(
						builder: (context, _setState) => Column(
							mainAxisSize: MainAxisSize.min,
							crossAxisAlignment: CrossAxisAlignment.center,
							children: [
								Text('Transcoding required'),
								SizedBox(height: 16),
								ConstrainedBox(
									constraints: BoxConstraints(
										maxHeight: 150,
									),
									child: SavedAttachmentThumbnail(file: source)
								),
								SizedBox(height: 32),
								...problems.expand((p) => [Text(p), SizedBox(height: 16)]),
								CupertinoButton(
									child: loading ? Text('Transcoding...') : Text('Start'),
									onPressed: loading ? null : () async {
										_setState(() {
											loading = true;
										});
										transcode.start();
										_setState(() {
											progress = transcode.progress;
										});
										try {
											final result = await transcode.result;
											Navigator.of(context).pop(Future.value(result.file));
										}
										catch (e) {
											Navigator.of(context).pop(Future<File>.error(e));
										}
									}
								),
								if (loading) ValueListenableBuilder(
									valueListenable: progress,
									builder: (context, double? value, child) => LinearProgressIndicator(
										value: value,
										valueColor: AlwaysStoppedAnimation(CupertinoTheme.of(context).primaryColor),
										backgroundColor: CupertinoTheme.of(context).primaryColor.withOpacity(0.7)
									)
								)
							]
						)
					)
				)
			)
		));
	}

	Future<void> _showAttachmentWindow() async {
		if (attachment != null) {
			final ext = attachment!.path.split('.').last.toLowerCase();
			final _controller = TextEditingController()..text = overrideAttachmentFilename?.replaceAll(RegExp('.$ext\$'), '') ?? '';
			await Navigator.of(context).push(TransparentRoute(
				builder: (context) => OverscrollModalPage(
					child: Container(
						width: MediaQuery.of(context).size.width,
						color: CupertinoTheme.of(context).scaffoldBackgroundColor,
						padding: EdgeInsets.all(16),
						child: StatefulBuilder(
							builder: (context, _setState) => Column(
								mainAxisSize: MainAxisSize.min,
								crossAxisAlignment: CrossAxisAlignment.center,
								children: [
									Text('Attachment'),
									SizedBox(height: 16),
									ConstrainedBox(
										constraints: BoxConstraints(
											maxHeight: 150,
										),
										child: SavedAttachmentThumbnail(file: attachment!)
									),
									SizedBox(height: 16),
									Row(
										mainAxisSize: MainAxisSize.min,
										children: [
											SizedBox(
												width: MediaQuery.of(context).size.width * 0.5,
												child: CupertinoTextField(
													controller: _controller,
													placeholder: attachment!.uri.pathSegments.last.replaceAll(RegExp('.$ext\$'), ''),
													placeholderStyle: TextStyle(color: CupertinoTheme.of(context).primaryColor.withBrightness(0.7)),
													maxLines: 1,
													textCapitalization: TextCapitalization.none,
													autocorrect: false,
													keyboardAppearance: CupertinoTheme.of(context).brightness,
													onSubmitted: (newFilename) {
														setState(() {
															overrideAttachmentFilename = newFilename.isEmpty ? null : '$newFilename.$ext';
														});
													}
												)
											),
											Text('.$ext')
										]
									),
									SizedBox(height: 16),
									CupertinoButton(
										child: Text('Remove'),
										onPressed: loading ? null : () async {
											setState(() {
												attachment = null;
												overrideAttachmentFilename = null;
											});
											Navigator.of(context).pop();
										}
									)
								]
							)
						)
					)
				)
			));
		}
	}

	Future<void> _selectAttachment() async {
		final picker = ImagePicker();
		final tileSize = (MediaQuery.of(context).size.width - 16 - (16 * 3)) / 4;
		final savedAttachments = Persistence.savedAttachmentBox.values.toList();
		savedAttachments.sort((a, b) => b.savedTime.compareTo(a.savedTime));
		File? file = await Navigator.of(context).push<File>(TransparentRoute(
			builder: (context) => OverscrollModalPage(
				child: Container(
					width: MediaQuery.of(context).size.width,
					padding: EdgeInsets.only(top: 16, bottom: 16),
					color: CupertinoTheme.of(context).scaffoldBackgroundColor,
					child: Wrap(
						runSpacing: 16,
						alignment: WrapAlignment.start,
						children: [
							...{
								_AttachmentSource(ImageSource.gallery, AttachmentType.Image): Icons.photo_library,
								_AttachmentSource(ImageSource.gallery, AttachmentType.WEBM): Icons.video_library,
								_AttachmentSource(ImageSource.camera, AttachmentType.Image): Icons.camera_alt,
								_AttachmentSource(ImageSource.camera, AttachmentType.WEBM): Icons.videocam
							}.entries.map((entry) => GestureDetector(
								onTap: () async{
									final file = await ((entry.key.type == AttachmentType.Image) ? picker.getImage(source: entry.key.source) : picker.getVideo(source: entry.key.source));
									if (file != null) {
										Navigator.of(context).pop<File>(File(file.path));
									}
								},
								child: Container(
									decoration: BoxDecoration(
										color: CupertinoTheme.of(context).primaryColor,
										borderRadius: BorderRadius.circular(8)
									),
									margin: EdgeInsets.only(left: 8, right: 8),
									width: tileSize,
									height: tileSize,
									child: Icon(entry.value, size: 40, color: CupertinoTheme.of(context).scaffoldBackgroundColor)
								)
							)),
							...savedAttachments.map((attachment) => GestureDetector(
								onTap: () {
									Navigator.of(context).pop(attachment.file);
								},
								child: Container(
									margin: EdgeInsets.only(left: 8, right: 8),
									width: tileSize,
									height: tileSize,
									child: ClipRRect(
										borderRadius: BorderRadius.circular(8),
										child: SavedAttachmentThumbnail(file: attachment.file, fit: BoxFit.cover)
									)
								)
							))
						]
					)
				)
			)
		));
		if (file != null) {
			try {
				final board = Persistence.getBoard(widget.thread.board);
				print(file);
				print(file.path);
				String ext = file.path.split('.').last.toLowerCase();
				if (ext == 'heic') {
					final heicPath = await HeicToJpg.convert(file.path);
					if (heicPath == null) {
						throw Exception('Failed to convert HEIC image to JPEG');
					}
					file = File(heicPath);
					ext = 'jpg';
				}
				final size = (await file.stat()).size;
				if (ext == 'jpg' || ext == 'jpeg' || ext == 'png') {
					file = await _showTranscodeWindow(
						source: file,
						size: size,
						maximumSize: board.maxWebmSizeBytes,
						transcode: MediaConversion.toJpg(
							file.uri,
							maximumSizeInBytes: board.maxWebmSizeBytes,
						)
					);
					print('Returned file had stat ${await file?.stat()}');
				}
				else if (ext == 'gif') {
					if ((board.maxImageSizeBytes == null) || (size > board.maxImageSizeBytes!)) {
						throw Exception('GIF is too large, and automatic re-encoding of GIFs is not supported');
					}
				}
				else if (ext == 'webm') {
					final scan = await MediaScan.scan(file.uri);
					file = await _showTranscodeWindow(
						source: file,
						audioAllowed: board.webmAudioAllowed,
						audioPresent: scan.hasAudio,
						size: size,
						maximumSize: board.maxWebmSizeBytes,
						durationInSeconds: scan.duration?.inSeconds,
						maximumDurationInSeconds: board.maxWebmDurationSeconds,
						transcode: MediaConversion.toWebm(
							file.uri,
							stripAudio: !board.webmAudioAllowed,
							maximumSizeInBytes: board.maxWebmSizeBytes,
							maximumDurationInSeconds: board.maxWebmDurationSeconds
						)
					);
				}
				else if (ext == 'mp4' || ext == 'mov') {
					final scan = await MediaScan.scan(file.uri);
					file = await _showTranscodeWindow(
						source: file,
						audioAllowed: board.webmAudioAllowed,
						audioPresent: scan.hasAudio,
						durationInSeconds: scan.duration?.inSeconds,
						maximumDurationInSeconds: board.maxWebmDurationSeconds,
						transcode: MediaConversion.toWebm(
							file.uri,
							stripAudio: !board.webmAudioAllowed,
							maximumSizeInBytes: board.maxWebmSizeBytes,
							maximumDurationInSeconds: board.maxWebmDurationSeconds
						)
					);
				}
				else {
					throw Exception('Unsupported file type: $ext');
				}
				if (file != null) {
					setState(() {
						attachment = file;
					});
				}
			}
			catch (e, st) {
				print(e);
				print(st);
				alertError(context, e.toString());
			}
		}
	}

	Future<void> _submit() async {
		final site = context.read<ImageboardSite>();
		final captchaKey = await Navigator.of(context).push<String>(TransparentRoute(builder: (context) {
			return OverscrollModalPage(
				child: CaptchaNoJS(
					request: site.getCaptchaRequest(),
					onCaptchaSolved: (key) => Navigator.of(context).pop(key)
				)
			);
		}));
		if (captchaKey == null) {
			return;
		}
		setState(() {
			loading = true;
		});
		try {
			final receipt = await site.postReply(
				thread: widget.thread,
				captchaKey: captchaKey,
				text: _textFieldController.text,
				file: attachment,
				overrideFilename: overrideAttachmentFilename
			);
			_textFieldController.clear();
			setState(() {
				loading = false;
				attachment = null;
				overrideAttachmentFilename = null;
			});
			print(receipt);
			_focusNode.unfocus();
			widget.threadState.receipts = [...widget.threadState.receipts, receipt];
			widget.threadState.save();
			widget.onReplyPosted();
		}
		catch (e, st) {
			print(e);
			print(st);
			setState(() {
				loading = false;
			});
			alertError(context, e.toString());
		}
	}

	@override
	Widget build(BuildContext context) {
		final board = Persistence.getBoard(widget.thread.board);
		return Container(
			constraints: BoxConstraints(
				maxHeight: 200
			),
			decoration: BoxDecoration(
				color: CupertinoTheme.of(context).scaffoldBackgroundColor
			),
			padding: EdgeInsets.all(4),
			child: Stack(
				children: [
					Row(
						children: [
							Expanded(
								child: IntrinsicHeight(
									child: Stack(
										children: [
											CupertinoTextField(
												enabled: !loading,
												controller: _textFieldController,
												maxLines: null,
												minLines: 5,
												autofocus: true,
												focusNode: _focusNode,
												textCapitalization: TextCapitalization.sentences,
												keyboardAppearance: CupertinoTheme.of(context).brightness,
											),
											if (board.maxCommentCharacters != null && ((_textFieldController.text.length / board.maxCommentCharacters!) > 0.5)) IgnorePointer(
												child: Align(
													alignment: Alignment.bottomRight,
													child: Container(
														padding: EdgeInsets.only(bottom: 4, right: 8),
														child: Text(
															'${_textFieldController.text.length} / ${board.maxCommentCharacters}',
															style: TextStyle(
																color: (_textFieldController.text.length > board.maxCommentCharacters!) ? Colors.red : Colors.grey
															)
														)
													)
												)
											)
										]
									)
								)
							),
							Column(
								mainAxisSize: MainAxisSize.min,
								mainAxisAlignment: MainAxisAlignment.end,
								children: [
									if (attachment != null) CupertinoButton(
										child: ClipRRect(
											borderRadius: BorderRadius.circular(4),
											child: ConstrainedBox(
												constraints: BoxConstraints(
													maxWidth: 32,
													maxHeight: 32
												),
												child: SavedAttachmentThumbnail(file: attachment!, fontSize: 12)
											)
										),
										padding: EdgeInsets.zero,
										onPressed: _showAttachmentWindow
									)
									else CupertinoButton(
										child: Icon(Icons.attach_file),
										padding: EdgeInsets.zero,
										onPressed: loading ? null : _selectAttachment
									),
									CupertinoButton(
										child: Icon(Icons.send),
										padding: EdgeInsets.zero,
										onPressed: loading ? null : _submit
									)
								]
							)
						]
					),
					if (loading) Positioned.fill(
							child: Container(
							alignment: Alignment.bottomCenter,
							child: LinearProgressIndicator(
								valueColor: AlwaysStoppedAnimation(CupertinoTheme.of(context).primaryColor),
								backgroundColor: CupertinoTheme.of(context).primaryColor.withOpacity(0.7)
							)
						)
					)
				]
			)
		);
	}
}
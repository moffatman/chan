import 'dart:io';

import 'package:chan/models/attachment.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/pages/web_image_picker.dart';
import 'package:chan/services/media.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/captcha_4chan.dart';
import 'package:chan/widgets/captcha_nojs.dart';
import 'package:chan/widgets/timed_rebuilder.dart';
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

class Expander extends StatelessWidget {
	final Widget child;
	final Duration duration;
	final Curve curve;
	final double height;
	final bool expanded;
	final bool bottomSafe;

	Expander({
		required this.child,
		this.duration = const Duration(milliseconds: 300),
		this.curve = Curves.ease,
		required this.height,
		required this.expanded,
		this.bottomSafe = false
	});

	@override
	Widget build(BuildContext context) {
		return SafeArea(
			top: false,
			bottom: !bottomSafe,
			child: AnimatedContainer(
				curve: Curves.ease,
				alignment: Alignment.topCenter,
				duration: const Duration(milliseconds: 300),
				height: expanded ? height : 0,
				child: Stack(
					clipBehavior: Clip.hardEdge,
					children: [
						Positioned(
							top: 0,
							left: 0,
							right: 0,
							child: Container(
								height: height,
								child: child
							)
						)
					]
				)
			)
		);
	}
}

class ReplyBox extends StatefulWidget {
	final String board;
	final int? threadId;
	final ValueChanged<PostReceipt> onReplyPosted;
	final VoidCallback? onRequestFocus;
	final bool visible;

	ReplyBox({
		required this.board,
		this.threadId,
		required this.onReplyPosted,
		this.onRequestFocus,
		this.visible = true,
		Key? key
	}) : super(key: key);
	createState() => ReplyBoxState();
}

class ReplyBoxState extends State<ReplyBox> {
	final _textFieldController = TextEditingController();
	final _nameFieldController = TextEditingController();
	final _subjectFieldController = TextEditingController();
	final _optionsFieldController = TextEditingController();
	final _textFocusNode = FocusNode();
	bool loading = false;
	File? attachment;
	String? overrideAttachmentFilename;
	bool _showOptions = false;
	bool get showOptions => _showOptions && !loading;

	@override
	void initState() {
		super.initState();
		_textFieldController.addListener(() {
			setState(() {});
		});
	}

	@override
	void didUpdateWidget(ReplyBox old) {
		super.didUpdateWidget(old);
		if (old.visible && !widget.visible) {
			_textFocusNode.unfocus();
		}
		else if (!old.visible && widget.visible) {
			_textFocusNode.requestFocus();
		}
	}

	void onTapPostId(int id) {
		widget.onRequestFocus?.call();
		_textFocusNode.requestFocus();
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

	Future<void> _selectAttachment() async {
		final picker = ImagePicker();
		final savedAttachments = context.read<Persistence>().savedAttachmentsBox.values.toList();
		savedAttachments.sort((a, b) => b.savedTime.compareTo(a.savedTime));
		final sources = {
			_AttachmentSource(ImageSource.gallery, AttachmentType.Image): Icons.photo_library,
			_AttachmentSource(ImageSource.gallery, AttachmentType.WEBM): Icons.video_library,
			_AttachmentSource(ImageSource.camera, AttachmentType.Image): Icons.camera_alt,
			_AttachmentSource(ImageSource.camera, AttachmentType.WEBM): Icons.videocam
		}.entries.toList();
		File? file = await Navigator.of(context).push<File>(TransparentRoute(
			builder: (context) => OverscrollModalPage(
				child: Container(
					width: double.infinity,
					padding: EdgeInsets.all(16),
					color: CupertinoTheme.of(context).scaffoldBackgroundColor,
					child: GridView.builder(
						gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
							maxCrossAxisExtent: 100,
							mainAxisSpacing: 16,
							crossAxisSpacing: 16,
							childAspectRatio: 1
						),
						shrinkWrap: true,
						physics: NeverScrollableScrollPhysics(),
						itemCount: sources.length + 1 + savedAttachments.length,
						itemBuilder: (context, i) {
							if (i < sources.length) {
								final entry = sources[i];
								return GestureDetector(
									onTap: () async {
										final file = await ((entry.key.type == AttachmentType.Image) ? picker.pickImage(source: entry.key.source) : picker.pickVideo(source: entry.key.source));
										if (file != null) {
											Navigator.of(context).pop<File>(File(file.path));
										}
									},
									child: Container(
										decoration: BoxDecoration(
											color: CupertinoTheme.of(context).primaryColor,
											borderRadius: BorderRadius.circular(8)
										),
										child: Icon(entry.value, size: 40, color: CupertinoTheme.of(context).scaffoldBackgroundColor)
									)
								);
							}
							else if (i == sources.length) {
								return GestureDetector(
									onTap: () async {
										final file = await Navigator.of(context, rootNavigator: true).push<File>(CupertinoModalPopupRoute(
											builder: (context) => WebImagePickerPage()
										));
										if (file != null) {
											Navigator.of(context).pop<File>(file);
										}
									},
									child: Container(
										decoration: BoxDecoration(
											color: CupertinoTheme.of(context).primaryColor,
											borderRadius: BorderRadius.circular(8)
										),
										child: Icon(Icons.image_search, size: 40, color: CupertinoTheme.of(context).scaffoldBackgroundColor)
									)
								)
							}
							else {
								final attachment = savedAttachments[i - sources.length];
								return GestureDetector(
									onTap: () {
										Navigator.of(context).pop(attachment.file);
									},
									child: ClipRRect(
										borderRadius: BorderRadius.circular(8),
										child: SavedAttachmentThumbnail(file: attachment.file, fit: BoxFit.cover)
									)
								);
							}
						}
					)
				)
			)
		));
		if (file != null) {
			try {
				final board = context.read<Persistence>().getBoard(widget.board);
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
				if ((ext == 'jpg' || ext == 'jpeg' || ext == 'png')) {
					if (board.maxImageSizeBytes != null && (size > board.maxImageSizeBytes!)) {
						file = await _showTranscodeWindow(
							source: file,
							size: size,
							maximumSize: board.maxImageSizeBytes,
							transcode: MediaConversion.toJpg(
								file.uri,
								maximumSizeInBytes: board.maxImageSizeBytes,
							)
						);
					}
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
		final captchaRequest = site.getCaptchaRequest(widget.board, widget.threadId);
		CaptchaSolution? captchaSolution;
		if (captchaRequest is RecaptchaRequest) {
			captchaSolution = await Navigator.of(context).push<CaptchaSolution>(TransparentRoute(builder: (context) {
				return OverscrollModalPage(
					child: CaptchaNoJS(
						request: captchaRequest,
						onCaptchaSolved: (solution) => Navigator.of(context).pop(solution)
					)
				);
			}));
		}
		else if (captchaRequest is Chan4CustomCaptchaRequest) {
			captchaSolution = await Navigator.of(context).push<CaptchaSolution>(TransparentRoute(builder: (context) {
				return OverscrollModalPage(
					child: Captcha4ChanCustom(
						request: captchaRequest,
						onCaptchaSolved: (key) => Navigator.of(context).pop(key)
					)
				);
			}));
		}
		else if (captchaRequest is NoCaptchaRequest) {
			captchaSolution = NoCaptchaSolution();
		}
		if (captchaSolution == null) {
			return;
		}
		setState(() {
			loading = true;
		});
		try {
			final receipt = (widget.threadId != null) ? (await site.postReply(
				thread: ThreadIdentifier(board: widget.board, id: widget.threadId!),
				name: _nameFieldController.text,
				options: _optionsFieldController.text,
				captchaSolution: captchaSolution,
				text: _textFieldController.text,
				file: attachment,
				overrideFilename: overrideAttachmentFilename
			)) : (await site.createThread(
				board: widget.board,
				name: _nameFieldController.text,
				options: _optionsFieldController.text,
				captchaSolution: captchaSolution,
				text: _textFieldController.text,
				file: attachment,
				overrideFilename: overrideAttachmentFilename,
				subject: _subjectFieldController.text
			));
			_textFieldController.clear();
			_nameFieldController.clear();
			_optionsFieldController.clear();
			_subjectFieldController.clear();
			setState(() {
				loading = false;
				attachment = null;
				overrideAttachmentFilename = null;
			});
			print(receipt);
			_textFocusNode.unfocus();
			final threadState = context.read<Persistence>().getThreadState((widget.threadId != null) ?
				ThreadIdentifier(board: widget.board, id: widget.threadId!) :
				ThreadIdentifier(board: widget.board, id: receipt.id));
			threadState.receipts = [...threadState.receipts, receipt];
			threadState.save();
			widget.onReplyPosted(receipt);
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

	Widget _buildOptions(BuildContext context) {
		final ext = attachment?.path.split('.').last.toLowerCase();
		final _controller = TextEditingController()..text = overrideAttachmentFilename?.replaceAll(RegExp('.$ext\$'), '') ?? '';
		return Container(
			decoration: BoxDecoration(
				border: Border(top: BorderSide(color: CupertinoTheme.of(context).primaryColor.withBrightness(0.2))),
				color: CupertinoTheme.of(context).scaffoldBackgroundColor
			),
			padding: EdgeInsets.only(top: 9, left: 8, right: 8, bottom: 8),
			child: Row(
				children: [
					Flexible(
						flex: 1,
						child: Column(
							mainAxisAlignment: MainAxisAlignment.spaceAround,
							children: [
								CupertinoTextField(
									maxLines: 1,
									placeholder: 'Name',
									keyboardAppearance: CupertinoTheme.of(context).brightness,
									controller: _nameFieldController
								),
								SizedBox(height: 8),
								CupertinoTextField(
									maxLines: 1,
									placeholder: 'Options',
									keyboardAppearance: CupertinoTheme.of(context).brightness,
									controller: _optionsFieldController
								)
							]
						)
					),
					SizedBox(width: 8),
					Flexible(
						child: (attachment != null) ? Column(
							children: [
								Flexible(
									child: Row(
										mainAxisSize: MainAxisSize.max,
										mainAxisAlignment: MainAxisAlignment.center,
										crossAxisAlignment: CrossAxisAlignment.center,
										children: [
											SavedAttachmentThumbnail(file: attachment!),
											CupertinoButton(
												padding: EdgeInsets.zero,
												child: Icon(Icons.close),
												onPressed: () {
													setState(() {
														attachment = null;
														overrideAttachmentFilename = null;
													});
												}
											)
										]
									)
								),
								SizedBox(height: 4),
								Flexible(
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										mainAxisAlignment: MainAxisAlignment.center,
										children: [
											Row(
												children: [
													Flexible(
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
													SizedBox(width: 8),
													Text('.$ext')
												]
											)
										]
									)
								)
							]
						) : Center(
							child: CupertinoButton(
								child: Row(
									mainAxisSize: MainAxisSize.min,
									children: [
										Icon(Icons.image),
										Text(' Select file'),
									]
								),
								onPressed: _selectAttachment
							)
						)
					)
				]
			)
		);
	}

	Widget _buildTextField(BuildContext context) {
		final board = context.watch<Persistence>().getBoard(widget.board);
		return Container(
			padding: EdgeInsets.all(8),
			child: Column(
				children: [
					if (widget.threadId == null) ...[
						CupertinoTextField(
							enabled: !loading,
							controller: _subjectFieldController,
							maxLines: 1,
							placeholder: 'Subject',
							textCapitalization: TextCapitalization.sentences,
							keyboardAppearance: CupertinoTheme.of(context).brightness
						),
						SizedBox(height: 8),
					],
					Flexible(
						child: Stack(
							children: [
								CupertinoTextField(
									enabled: !loading,
									controller: _textFieldController,
									placeholder: 'Comment',
									maxLines: null,
									minLines: 10,
									focusNode: _textFocusNode,
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
				]
			)
		);
	}

	Widget _buildButtons(BuildContext context) {
		final expandAction = loading ? null : () {
			setState(() {
				_showOptions = !_showOptions;
			});
		};
		return Column(
			mainAxisSize: MainAxisSize.min,
			mainAxisAlignment: MainAxisAlignment.spaceAround,
			children: [
				if (!showOptions && attachment != null) CupertinoButton(
					alignment: Alignment.center,
					padding: EdgeInsets.zero,
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
					onPressed: expandAction
				)
				else CupertinoButton(
					child: Icon(showOptions ? Icons.arrow_drop_down : Icons.arrow_drop_up),
					padding: EdgeInsets.zero,
					onPressed: expandAction
				),
				TimedRebuilder(
					interval: Duration(seconds: 1),
					builder: (context) {
						final timeout = context.read<ImageboardSite>().getActionAllowedTime(widget.board, widget.threadId == null ? 
							ImageboardAction.PostThread :
							(attachment != null) ? ImageboardAction.PostReplyWithImage : ImageboardAction.PostReply);
						if (timeout != null) {
							final now = DateTime.now();
							final diff = timeout.difference(now);
							if (!diff.isNegative) {
								return CupertinoButton(
									padding: EdgeInsets.zero,
									child: Text((diff.inMilliseconds / 1000).round().toString(), textAlign: TextAlign.center),
									onPressed: null
								);
							}
						}
						return CupertinoButton(
							child: Icon(Icons.send),
							padding: EdgeInsets.zero,
							onPressed: loading ? null : _submit
						);
					}
				)
			]
		);
	}

	@override
	Widget build(BuildContext context) {
		return Column(
			mainAxisSize: MainAxisSize.min,
			children: [
				Expander(
					expanded: showOptions && widget.visible,
					bottomSafe: true,
					height: 100,
					child: Focus(
						descendantsAreFocusable: showOptions,
						child: _buildOptions(context)
					)
				),
				Expander(
					expanded: widget.visible,
					bottomSafe: !widget.visible,
					height: (widget.threadId == null) ? 150 : 100,
					child: Container(
						decoration: BoxDecoration(
							border: Border(top: BorderSide(color: CupertinoTheme.of(context).primaryColor.withBrightness(0.2))),
							color: CupertinoTheme.of(context).scaffoldBackgroundColor
						),
						padding: EdgeInsets.only(top: 1),
						child: Stack(
							children: [
								Row(
									crossAxisAlignment: CrossAxisAlignment.stretch,
									children: [
										Expanded(
											child: _buildTextField(context)
										),
										_buildButtons(context)
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
					)
				)
			]
		);
	}
}
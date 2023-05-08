import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/services/apple.dart';
import 'package:chan/services/clipboard_image.dart';
import 'package:chan/services/embed.dart';
import 'package:chan/services/media.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/pick_attachment.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/attachment_viewer.dart';
import 'package:chan/widgets/captcha_4chan.dart';
import 'package:chan/widgets/captcha_dvach.dart';
import 'package:chan/widgets/captcha_lynxchan.dart';
import 'package:chan/widgets/captcha_secucap.dart';
import 'package:chan/widgets/captcha_securimage.dart';
import 'package:chan/widgets/captcha_nojs.dart';
import 'package:chan/widgets/cupertino_dialog.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/timed_rebuilder.dart';
import 'package:chan/widgets/util.dart';
import 'package:chan/widgets/saved_attachment_thumbnail.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart' as dio;
import 'package:extended_image/extended_image.dart';
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';
import 'package:provider/provider.dart';
import 'package:heic_to_jpg/heic_to_jpg.dart';
import 'package:string_similarity/string_similarity.dart';

const _captchaContributionServer = 'https://captcha.chance.surf';

class ReplyBox extends StatefulWidget {
	final String board;
	final int? threadId;
	final ValueChanged<PostReceipt> onReplyPosted;
	final String initialText;
	final ValueChanged<String>? onTextChanged;
	final String initialSubject;
	final ValueChanged<String>? onSubjectChanged;
	final VoidCallback? onVisibilityChanged;
	final bool isArchived;
	final bool fullyExpanded;
	final String initialOptions;
	final ValueChanged<String>? onOptionsChanged;
	final String? initialFilePath;
	final ValueChanged<String?>? onFilePathChanged;

	const ReplyBox({
		required this.board,
		this.threadId,
		required this.onReplyPosted,
		this.initialText = '',
		this.onTextChanged,
		this.initialSubject = '',
		this.onSubjectChanged,
		this.onVisibilityChanged,
		this.isArchived = false,
		this.fullyExpanded = false,
		this.initialOptions = '',
		this.onOptionsChanged,
		this.initialFilePath,
		this.onFilePathChanged,
		Key? key
	}) : super(key: key);

	@override
	createState() => ReplyBoxState();
}

final _imageUrlPattern = RegExp(r'https?:\/\/[^. ]\.[^ ]+\.(jpg|jpeg|png|gif)');

class ReplyBoxState extends State<ReplyBox> {
	late final TextEditingController _textFieldController;
	late final TextEditingController _nameFieldController;
	late final TextEditingController _subjectFieldController;
	late final TextEditingController _optionsFieldController;
	late final TextEditingController _filenameController;
	late final FocusNode _textFocusNode;
	bool loading = false;
	MediaScan? _attachmentScan;
	File? attachment;
	String? get attachmentExt => attachment?.path.split('.').last.toLowerCase();
	bool _showOptions = false;
	bool get showOptions => _showOptions && !loading;
	bool _showAttachmentOptions = false;
	bool get showAttachmentOptions => _showAttachmentOptions && !loading;
	bool _show = false;
	bool get show => widget.fullyExpanded || (_show && !_willHideOnPanEnd);
	String? _lastFoundUrl;
	String? _proposedAttachmentUrl;
	CaptchaSolution? _captchaSolution;
	Timer? _autoPostTimer;
	bool spoiler = false;
	List<ImageboardBoardFlag> _flags = [];
	ImageboardBoardFlag? flag;
	double _panStartDy = 0;
	double _replyBoxHeightOffsetAtPanStart = 0;
	bool _willHideOnPanEnd = false;
	late final FocusNode _rootFocusNode;
	(String, ValueListenable<double?>)? _attachmentProgress;
	(String, int)? _spamFilteredPostId;
	bool get hasSpamFilteredPostToCheck => _spamFilteredPostId != null;
	static List<String> _previouslyUsedNames = [];

	Future<void> _checkPreviouslyUsedNames() async {
		_previouslyUsedNames = (await Future.wait(Persistence.sharedThreadStateBox.values.map<Future<Iterable<String>>>((state) async {
			if (state.youIds.isEmpty) {
				return const [];
			}
			final thread = await state.getThread();
			return thread?.posts_.where((p) => state.youIds.contains(p.id) && p.name.trim() != (state.imageboard?.site.defaultUsername ?? 'Anonymous')).map((p) => p.name.trim()).toList() ?? const [];
		}))).expand((s) => s).toSet().toList()..sort();
		setState(() {});
	}

	bool get _haveValidCaptcha {
		if (_captchaSolution == null) {
			return false;
		}
		return _captchaSolution?.expiresAt?.isAfter(DateTime.now()) ?? true;
	}

	void _onTextChanged() async {
		_spamFilteredPostId = null;
		widget.onTextChanged?.call(_textFieldController.text);
		_autoPostTimer?.cancel();
		if (mounted) setState(() {});
		final rawUrl = _imageUrlPattern.firstMatch(_textFieldController.text)?.group(0);
		if (rawUrl != _lastFoundUrl && rawUrl != null) {
			try {
				await context.read<ImageboardSite>().client.head(rawUrl);
				_lastFoundUrl = rawUrl;
				_proposedAttachmentUrl = rawUrl;
				if (mounted) setState(() {});
			}
			catch (e) {
				print('Url did not have a good response: ${e.toStringDio()}');
				_lastFoundUrl = null;
			}
		}
		else {
			final possibleEmbed = findEmbedUrl(text: _textFieldController.text, context: context);
			if (possibleEmbed != _lastFoundUrl && possibleEmbed != null) {
				final embedData = await loadEmbedData(url: possibleEmbed, context: context);
				_lastFoundUrl = possibleEmbed;
				if (embedData?.thumbnailUrl != null) {
					_proposedAttachmentUrl = embedData!.thumbnailUrl!;
					if (mounted) setState(() {});
				}
			}
		}
	}

	@override
	void initState() {
		super.initState();
		_textFieldController = TextEditingController(text: widget.initialText);
		_subjectFieldController = TextEditingController(text: widget.initialSubject);
		_optionsFieldController = TextEditingController(text: widget.initialOptions);
		_filenameController = TextEditingController();
		_nameFieldController = TextEditingController(text: context.read<Persistence>().browserState.postingNames[widget.board]);
		_textFocusNode = FocusNode();
		_rootFocusNode = FocusNode();
		_textFieldController.addListener(_onTextChanged);
		_subjectFieldController.addListener(() {
			_spamFilteredPostId = null;
			widget.onSubjectChanged?.call(_subjectFieldController.text);
		});
		context.read<ImageboardSite>().getBoardFlags(widget.board).then((flags) {
			if (!mounted) return;
			setState(() {
				_flags = flags;
			});
		}).catchError((e) {
			print('Error getting flags for ${widget.board}: $e');
		});
		if (_nameFieldController.text.isNotEmpty || _optionsFieldController.text.isNotEmpty) {
			_showOptions = true;
		}
		_tryUsingInitialFile();
	}

	@override
	void didUpdateWidget(ReplyBox oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.board != widget.board || oldWidget.threadId != widget.threadId) {
			_textFieldController.text = widget.initialText;
			_subjectFieldController.text = widget.initialSubject;
			_optionsFieldController.text = widget.initialOptions;
			attachment = null;
			_attachmentScan = null;
			spoiler = false;
			flag = null;
			widget.onFilePathChanged?.call(null);
		}
		if (oldWidget.board != widget.board) {
			context.read<ImageboardSite>().getBoardFlags(widget.board).then((flags) {
				setState(() {
					_flags = flags;
				});
			});
		}
	}

	void _tryUsingInitialFile() async {
		if (widget.initialFilePath?.isNotEmpty == true) {
			final file = File(widget.initialFilePath!);
			if (await file.exists()) {
				setAttachment(file);
			}
			else if (mounted) {
				showToast(
					context: context,
					icon: Icons.broken_image,
					message: 'Previously-selected file is no longer accessible'
				);
			}
			widget.onFilePathChanged?.call(null);
		}
	}

	void _insertText(String insertedText, {bool addNewlineIfAtEnd = true}) {
		int currentPos = _textFieldController.selection.base.offset;
		if (currentPos < 0) {
			currentPos = _textFieldController.text.length;
		}
		if (addNewlineIfAtEnd && currentPos == _textFieldController.text.length) {
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

	void onTapPostId(int id) {
		if (!widget.isArchived && (context.read<ImageboardSite?>()?.supportsPosting ?? false)) {
			showReplyBox();
			_insertText('>>$id');
		}
	}

	void onQuoteText(String text, {required int fromId}) {
		if (!widget.isArchived) {
			showReplyBox();
			_insertText('>>$fromId');
			_insertText('>${text.replaceAll('\n', '\n>')}');
		}
	}

	void showReplyBox() {
		_checkPreviouslyUsedNames();
		if (_nameFieldController.text.isEmpty && (context.read<Persistence>().browserState.postingNames[widget.board]?.isNotEmpty ?? false)) {
			_nameFieldController.text = context.read<Persistence>().browserState.postingNames[widget.board] ?? '';
			_showOptions = true;
		}
		setState(() {
			_show = true;
		});
		widget.onVisibilityChanged?.call();
		_textFocusNode.requestFocus();
	}

	void hideReplyBox() {
		setState(() {
			_show = false;
		});
		widget.onVisibilityChanged?.call();
		_rootFocusNode.unfocus();
	}

	void toggleReplyBox() {
		if (show) {
			hideReplyBox();
		}
		else {
			showReplyBox();
		}
		lightHapticFeedback();
	}

	void checkForSpamFilteredPost(Post post) {
		if (post.board != _spamFilteredPostId?.$1) return;
		if (post.id != _spamFilteredPostId?.$2) return;
		final similarity = post.span.buildText().similarityTo(_textFieldController.text);
		print('Spam filter similarity: $similarity');
		if (similarity > 0.90) {
			showToast(context: context, message: 'Post successful', icon: CupertinoIcons.smiley, hapticFeedback: false);
			_textFieldController.clear();
			_nameFieldController.clear();
			_optionsFieldController.clear();
			_subjectFieldController.clear();
			_filenameController.clear();
			attachment = null;
			_attachmentScan = null;
			widget.onFilePathChanged?.call(null);
			_showAttachmentOptions = false;
			_spamFilteredPostId = null;
			setState(() {});
		}
	}

	Future<File?> _showTranscodeWindow({
		required File source,
		int? size,
		int? maximumSize,
		bool? audioPresent,
		bool? audioAllowed,
		int? durationInSeconds,
		int? maximumDurationInSeconds,
		int? width,
		int? height,
		int? maximumDimension,
		required MediaConversion transcode
	}) async {
		final ext = source.path.split('.').last.toLowerCase();
		final solutions = [
			if (ext != transcode.outputFileExtension &&
					!(ext == 'jpeg' && transcode.outputFileExtension == 'jpg') &&
					!(ext == 'jpg' && transcode.outputFileExtension == 'jpeg')) 'to .${transcode.outputFileExtension}',
			if (size != null && maximumSize != null && (size > maximumSize)) 'compressing',
			if (audioPresent == true && audioAllowed == false) 'removing audio',
			if (durationInSeconds != null && maximumDurationInSeconds != null && (durationInSeconds > maximumDurationInSeconds)) 'clipping at ${maximumDurationInSeconds}s'
		];
		if (width != null && height != null && maximumDimension != null && (width > maximumDimension || height > maximumDimension)) {
			solutions.add('resizing');
		}
		if (solutions.isEmpty && ['jpg', 'jpeg', 'png', 'gif', 'webm'].contains(ext)) {
			return source;
		}
		final existingResult = await transcode.getDestinationIfSatisfiesConstraints();
		if (existingResult != null) {
			if ((audioPresent == true && audioAllowed == true && !existingResult.hasAudio)) {
				solutions.add('re-adding audio');
			}
			else {
				return existingResult.file;
			}
		}
		if (!mounted) return null;
		showToast(context: context, message: 'Converting: ${solutions.join(', ')}', icon: CupertinoIcons.photo);
		transcode.start();
		setState(() {
			_attachmentProgress = ('Converting', transcode.progress);
		});
		try {
			final result = await transcode.result;
			if (!mounted) return null;
			setState(() {
				_attachmentProgress = null;
			});
			showToast(context: context, message: 'File converted', icon: CupertinoIcons.checkmark);
			return result.file;
		}
		catch (e) {
			if (mounted) {
				setState(() {
					_attachmentProgress = null;
				});
			}
			rethrow;
		}
	}

Future<void> _handleImagePaste({bool manual = true}) async {
		final file = await getClipboardImageAsFile();
		if (file != null) {
			setAttachment(file);
		}
		else if (manual && mounted) {
			showToast(
				context: context,
				message: 'No image in clipboard',
				icon: CupertinoIcons.xmark
			);
		}
	}

	Future<void> setAttachment(File newAttachment) async {
		File? file = newAttachment;
		final settings = context.read<EffectiveSettings>();
		final progress = ValueNotifier<double?>(null);
		setState(() {
			_attachmentProgress = ('Processing', progress);
		});
		try {
			final board = context.read<Persistence>().getBoard(widget.board);
			String ext = file.path.split('.').last.toLowerCase();
			if (ext == 'jpg' || ext == 'jpeg' || ext == 'heic') {
				file = await FlutterExifRotation.rotateImage(path: file.path);
			}
			if (ext == 'heic') {
				final heicPath = await HeicToJpg.convert(file.path);
				if (heicPath == null) {
					throw Exception('Failed to convert HEIC image to JPEG');
				}
				file = File(heicPath);
				ext = 'jpg';
			}
			else if (ext == 'webp') {
				file = await convertToJpg(file);
				ext = 'jpg';
			}
			final size = (await file.stat()).size;
			final scan = await MediaScan.scan(file.uri);
			setState(() {
				_attachmentProgress = null;
			});
			if (ext == 'jpg' || ext == 'jpeg') {
				file = await _showTranscodeWindow(
					source: file,
					size: size,
					maximumSize: board.maxImageSizeBytes,
					width: scan.width,
					height: scan.height,
					maximumDimension: settings.maximumImageUploadDimension,
					transcode: MediaConversion.toJpg(
						file.uri,
						maximumSizeInBytes: board.maxImageSizeBytes,
						maximumDimension: settings.maximumImageUploadDimension
					)
				);
			}
			else if (ext == 'png') {
				file = await _showTranscodeWindow(
					source: file,
					size: size,
					maximumSize: board.maxImageSizeBytes,
					width: scan.width,
					height: scan.height,
					maximumDimension: settings.maximumImageUploadDimension,
					transcode: MediaConversion.toPng(
						file.uri,
						maximumSizeInBytes: board.maxImageSizeBytes,
						maximumDimension: settings.maximumImageUploadDimension
					)
				);
			}
			else if (ext == 'gif') {
				if ((board.maxImageSizeBytes != null) && (size > board.maxImageSizeBytes!)) {
					throw Exception('GIF is too large, and automatic re-encoding of GIFs is not supported');
				}
			}
			else if (ext == 'webm') {
				file = await _showTranscodeWindow(
					source: file,
					audioAllowed: board.webmAudioAllowed,
					audioPresent: scan.hasAudio,
					size: size,
					maximumSize: board.maxWebmSizeBytes,
					durationInSeconds: scan.duration?.inSeconds,
					maximumDurationInSeconds: board.maxWebmDurationSeconds,
					width: scan.width,
					height: scan.height,
					maximumDimension: settings.maximumImageUploadDimension,
					transcode: MediaConversion.toWebm(
						file.uri,
						stripAudio: !board.webmAudioAllowed,
						maximumSizeInBytes: board.maxWebmSizeBytes,
						maximumDurationInSeconds: board.maxWebmDurationSeconds,
						maximumDimension: settings.maximumImageUploadDimension
					)
				);
			}
			else if (ext == 'mp4' || ext == 'mov') {
				file = await _showTranscodeWindow(
					source: file,
					audioAllowed: board.webmAudioAllowed,
					audioPresent: scan.hasAudio,
					durationInSeconds: scan.duration?.inSeconds,
					maximumDurationInSeconds: board.maxWebmDurationSeconds,
					width: scan.width,
					height: scan.height,
					maximumDimension: settings.maximumImageUploadDimension,
					transcode: MediaConversion.toWebm(
						file.uri,
						stripAudio: !board.webmAudioAllowed,
						maximumSizeInBytes: board.maxWebmSizeBytes,
						maximumDurationInSeconds: board.maxWebmDurationSeconds,
						maximumDimension: settings.maximumImageUploadDimension
					)
				);
			}
			else {
				throw Exception('Unsupported file type: $ext');
			}
			if (file != null) {
				_attachmentScan = await MediaScan.scan(file.uri);
				setState(() {
					attachment = file;
				});
				_spamFilteredPostId = null;
				widget.onFilePathChanged?.call(file.path);
			}
		}
		catch (e, st) {
			print(e);
			print(st);
			alertError(context, e.toStringDio());
			setState(() {
				_attachmentProgress = null;
			});
		}
		progress.dispose();
	}

	Future<void> _solveCaptcha() async {
		final site = context.read<ImageboardSite>();
		final settings = context.read<EffectiveSettings>();
		final savedFields = site.loginSystem?.getSavedLoginFields();
		if (savedFields != null) {
			bool shouldAutoLogin = settings.connectivity != ConnectivityResult.mobile;
			if (!shouldAutoLogin) {
				settings.autoLoginOnMobileNetwork ??= await showCupertinoDialog<bool>(
					context: context,
					builder: (context) => CupertinoAlertDialog2(
						title: Text('Use ${site.loginSystem?.name} on mobile networks?'),
						actions: [
							CupertinoDialogAction2(
								child: const Text('Never'),
								onPressed: () {
									Navigator.of(context).pop(false);
								}
							),
							CupertinoDialogAction2(
								child: const Text('Not now'),
								onPressed: () {
									Navigator.of(context).pop();
								}
							),
							CupertinoDialogAction2(
								child: const Text('Just once'),
								onPressed: () {
									shouldAutoLogin = true;
									Navigator.of(context).pop();
								}
							),
							CupertinoDialogAction2(
								child: const Text('Always'),
								onPressed: () {
									Navigator.of(context).pop(true);
								}
							)
						]
					)
				);
				if (settings.autoLoginOnMobileNetwork == true) {
					shouldAutoLogin = true;
				}
			}
			if (shouldAutoLogin) {
				try {
					await site.loginSystem?.login(savedFields);
				}
				catch (e) {
					if (mounted) {
						showToast(
							context: context,
							icon: CupertinoIcons.exclamationmark_triangle,
							message: 'Failed to log in to ${site.loginSystem?.name}'
						);
					}
					print('Problem auto-logging in: $e');
				}
			}
			else {
				await site.loginSystem?.clearLoginCookies(false);
			}
		}
		try {
			final captchaRequest = await site.getCaptchaRequest(widget.board, widget.threadId);
			if (!mounted) return;
			if (captchaRequest is RecaptchaRequest) {
				hideReplyBox();
				_captchaSolution = await Navigator.of(context, rootNavigator: true).push<CaptchaSolution>(TransparentRoute(
					builder: (context) => OverscrollModalPage(
						child: CaptchaNoJS(
							site: site,
							request: captchaRequest,
							onCaptchaSolved: (solution) => Navigator.of(context).pop(solution)
						)
					),
					showAnimations: context.read<EffectiveSettings>().showAnimations
				));
				showReplyBox();
			}
			else if (captchaRequest is Chan4CustomCaptchaRequest) {
				hideReplyBox();
				_captchaSolution = await Navigator.of(context, rootNavigator: true).push<CaptchaSolution>(TransparentRoute(
					builder: (context) => OverscrollModalPage(
						child: Captcha4ChanCustom(
							site: site,
							request: captchaRequest,
							onCaptchaSolved: (key) => Navigator.of(context).pop(key)
						)
					),
					showAnimations: context.read<EffectiveSettings>().showAnimations
				));
				showReplyBox();
			}
			else if (captchaRequest is SecurimageCaptchaRequest) {
				hideReplyBox();
				_captchaSolution = await Navigator.of(context, rootNavigator: true).push<CaptchaSolution>(TransparentRoute(
					builder: (context) => OverscrollModalPage(
						child: CaptchaSecurimage(
							request: captchaRequest,
							onCaptchaSolved: (key) => Navigator.of(context).pop(key),
							site: site
						)
					),
					showAnimations: context.read<EffectiveSettings>().showAnimations
				));
				showReplyBox();
			}
			else if (captchaRequest is DvachCaptchaRequest) {
				hideReplyBox();
				_captchaSolution = await Navigator.of(context, rootNavigator: true).push<CaptchaSolution>(TransparentRoute(
					builder: (context) => OverscrollModalPage(
						child: CaptchaDvach(
							request: captchaRequest,
							onCaptchaSolved: (key) => Navigator.of(context).pop(key),
							site: site
						)
					),
					showAnimations: context.read<EffectiveSettings>().showAnimations
				));
				showReplyBox();
			}
			else if (captchaRequest is LynxchanCaptchaRequest) {
				hideReplyBox();
				_captchaSolution = await Navigator.of(context, rootNavigator: true).push<CaptchaSolution>(TransparentRoute(
					builder: (context) => OverscrollModalPage(
						child: CaptchaLynxchan(
							request: captchaRequest,
							onCaptchaSolved: (key) => Navigator.of(context).pop(key),
							site: site
						)
					),
					showAnimations: context.read<EffectiveSettings>().showAnimations
				));
				showReplyBox();
			}
			else if (captchaRequest is SecucapCaptchaRequest) {
				hideReplyBox();
				_captchaSolution = await Navigator.of(context, rootNavigator: true).push<CaptchaSolution>(TransparentRoute(
					builder: (context) => OverscrollModalPage(
						child: CaptchaSecucap(
							request: captchaRequest,
							onCaptchaSolved: (key) => Navigator.of(context).pop(key),
							site: site
						)
					),
					showAnimations: context.read<EffectiveSettings>().showAnimations
				));
				showReplyBox();
			}
			else if (captchaRequest is NoCaptchaRequest) {
				_captchaSolution = NoCaptchaSolution();
			}
		}
		catch (e, st) {
			print(e);
			print(st);
			if (!mounted) return;
			alertError(context, 'Error getting captcha request:\n${e.toStringDio()}');
		}
	}

	Future<void> _submit() async {
		final site = context.read<ImageboardSite>();
		setState(() {
			loading = true;
		});
		if (_captchaSolution == null) {
			await _solveCaptcha();
		}
		if (_captchaSolution == null) {
			setState(() {
				loading = false;
			});
			return;
		}
		if (!mounted) return;
		try {
			final persistence = context.read<Persistence>();
			final settings = context.read<EffectiveSettings>();
			String? overrideAttachmentFilename;
			if (_filenameController.text.isNotEmpty && attachment != null) {
				overrideAttachmentFilename = '${_filenameController.text}.${attachmentExt!}';
			}
			if (settings.randomizeFilenames && attachment != null) {
				const alphanumericCharacters = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
				overrideAttachmentFilename = '${List.generate(12, (i) => alphanumericCharacters[random.nextInt(alphanumericCharacters.length)]).join('')}.${attachmentExt!}';
			}
			lightHapticFeedback();
			final receipt = (widget.threadId != null) ? (await site.postReply(
				thread: ThreadIdentifier(widget.board, widget.threadId!),
				name: _nameFieldController.text,
				options: _optionsFieldController.text,
				captchaSolution: _captchaSolution!,
				text: _textFieldController.text,
				file: attachment,
				spoiler: spoiler,
				overrideFilename: overrideAttachmentFilename,
				flag: flag
			)) : (await site.createThread(
				board: widget.board,
				name: _nameFieldController.text,
				options: _optionsFieldController.text,
				captchaSolution: _captchaSolution!,
				text: _textFieldController.text,
				file: attachment,
				spoiler: spoiler,
				overrideFilename: overrideAttachmentFilename,
				subject: _subjectFieldController.text,
				flag: flag
			));
			bool spamFiltered = false;
			if (_captchaSolution is Chan4CustomCaptchaSolution) {
				final solution = (_captchaSolution as Chan4CustomCaptchaSolution);
				// ignore: use_build_context_synchronously
				settings.contributeCaptchas ??= await showCupertinoDialog<bool>(
					context: context,
					builder: (context) => CupertinoAlertDialog2(
						title: const Text('Contribute captcha solutions?'),
						content: const Text('The captcha images you solve will be collected to improve the automated solver'),
						actions: [
							CupertinoDialogAction2(
								child: const Text('No'),
								onPressed: () {
									Navigator.of(context).pop(false);
								}
							),
							CupertinoDialogAction2(
								child: const Text('Yes'),
								onPressed: () {
									Navigator.of(context).pop(true);
								}
							)
						]
					)
				);
				if (settings.contributeCaptchas == true) {
					final bytes = await solution.alignedImage?.toByteData(format: ImageByteFormat.png);
					if (bytes == null) {
						print('Something went wrong converting the captcha image to bytes');
					}
					else {
						site.client.post(
							_captchaContributionServer,
							data: dio.FormData.fromMap({
								'text': solution.response,
								'image': dio.MultipartFile.fromBytes(
									bytes.buffer.asUint8List(),
									filename: 'upload.png',
									contentType: MediaType("image", "png")
								)
							}),
							options: dio.Options(
								validateStatus: (x) => true,
								responseType: dio.ResponseType.plain
							)
						).then((response) {
							print(response.data);
						});
					}
				}
				spamFiltered = _captchaSolution?.cloudflare ?? false;
			}
			if (spamFiltered) {
				_spamFilteredPostId = (widget.board, receipt.id);
			}
			else {
				_textFieldController.clear();
				_nameFieldController.clear();
				_optionsFieldController.clear();
				_subjectFieldController.clear();
				_filenameController.clear();
				attachment = null;
				_attachmentScan = null;
				widget.onFilePathChanged?.call(null);
				_showAttachmentOptions = false;
			}
			_show = false;
			loading = false;
			if (mounted) setState(() {});
			print(receipt);
			_rootFocusNode.unfocus();
			final threadState = persistence.getThreadState((widget.threadId != null) ?
				ThreadIdentifier(widget.board, widget.threadId!) :
				ThreadIdentifier(widget.board, receipt.id));
			threadState.receipts = [...threadState.receipts, receipt];
			threadState.save();
			mediumHapticFeedback();
			widget.onReplyPosted(receipt);
			if (spamFiltered) {
				if (mounted) {
					Future.delayed(const Duration(seconds: 10), () {
						if (_spamFilteredPostId == null) {
							// The post appeared after all.
							return;
						}
						alertError(
							context,
							'Your post was likely blocked by 4chan\'s anti-spam firewall.\nIf you don\'t see your post appear, try again later. It has been saved in the reply form.',
							barrierDismissible: true
						);
					});
				}
			}
			else if (mounted) {
				showToast(context: context, message: 'Post successful', icon: CupertinoIcons.check_mark, hapticFeedback: false);
			}
		}
		catch (e, st) {
			print(e);
			print(st);
			setState(() {
				loading = false;
			});
			final bannedCaptchaRequest = site.getBannedCaptchaRequest(_captchaSolution?.cloudflare ?? false);
			if (e is BannedException && bannedCaptchaRequest != null) {
				await showCupertinoDialog(
					context: context,
					builder: (context) {
						return CupertinoAlertDialog2(
							title: const Text('Error'),
							content: Text(e.toString()),
							actions: [
								CupertinoDialogAction2(
									child: const Text('See reason'),
									onPressed: () async {
										if (bannedCaptchaRequest is RecaptchaRequest) {
											final solution = await Navigator.of(context).push<CaptchaSolution>(TransparentRoute(
												builder: (context) => OverscrollModalPage(
													child: CaptchaNoJS(
														site: site,
														request: bannedCaptchaRequest,
														onCaptchaSolved: (solution) => Navigator.of(context).pop(solution)
													)
												),
												showAnimations: context.read<EffectiveSettings>().showAnimations
											));
											if (solution != null) {
												final reason = await site.getBannedReason(solution);
												if (!mounted) return;
												alertError(context, reason);
											}
										}
										else {
											alertError(context, 'Unexpected captcha request type: ${bannedCaptchaRequest.runtimeType}');
										}
									}
								),
								CupertinoDialogAction2(
									child: const Text('OK'),
									onPressed: () {
										Navigator.of(context).pop();
									}
								)
							]
						);
					}
				);
			}
			else {
				if (e is ActionableException) {
					alertError(context, e.message, actions: e.actions);
				}
				else {
					alertError(context, e.toStringDio());
				}
			}
		}
		_captchaSolution = null;
	}

	void _pickEmote() async {
		final emotes = context.read<ImageboardSite>().getEmotes();
		final pickedEmote = await Navigator.of(context).push<ImageboardEmote>(TransparentRoute(
			builder: (context) => OverscrollModalPage(
				child: Container(
					width: MediaQuery.sizeOf(context).width,
					color: CupertinoTheme.of(context).scaffoldBackgroundColor,
					padding: const EdgeInsets.all(16),
					child: StatefulBuilder(
						builder: (context, setEmotePickerState) => Column(
							mainAxisSize: MainAxisSize.min,
							crossAxisAlignment: CrossAxisAlignment.center,
							children: [
								const Text('Select emote'),
								const SizedBox(height: 16),
								GridView.builder(
									gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
										maxCrossAxisExtent: 48,
										childAspectRatio: 1,
										mainAxisSpacing: 16,
										crossAxisSpacing: 16
									),
									itemCount: emotes.length,
									itemBuilder: (context, i) {
										final emote = emotes[i];
										return GestureDetector(
											onTap: () {
												Navigator.of(context).pop(emote);
											},
											child: emote.image != null ? ExtendedImage.network(
												emote.image.toString(),
												fit: BoxFit.contain,
												cache: true
											) : Text(emote.text ?? '', style: const TextStyle(
												fontSize: 40
											))
										);
									},
									shrinkWrap: true,
									physics: const NeverScrollableScrollPhysics(),
								)
							]
						)
					)
				)
			),
			showAnimations: context.read<EffectiveSettings>().showAnimations
		));
		if (pickedEmote != null) {
			_insertText(pickedEmote.code, addNewlineIfAtEnd: false);
		}
	}

	void _pickFlag() async {
		final pickedFlag = await Navigator.of(context).push<ImageboardBoardFlag>(TransparentRoute(
			builder: (context) => OverscrollModalPage(
				child: Container(
					width: MediaQuery.sizeOf(context).width,
					color: CupertinoTheme.of(context).scaffoldBackgroundColor,
					padding: const EdgeInsets.all(16),
					child: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.center,
						children: [
							const Text('Select flag'),
							const SizedBox(height: 16),
							ListView.builder(
								itemCount: _flags.length,
								itemBuilder: (context, i) {
									final flag = _flags[i];
									return CupertinoButton(
										onPressed: () {
											Navigator.of(context).pop(flag);
										},
										child: Row(
											children: [
												if (flag.code == '0') const SizedBox(width: 16)
												else ExtendedImage.network(
													flag.image.toString(),
													fit: BoxFit.contain,
													cache: true
												),
												const SizedBox(width: 8),
												Text(flag.name)
											]
										)
									);
								},
								shrinkWrap: true,
								physics: const NeverScrollableScrollPhysics(),
							)
						]
					)
				)
			),
			showAnimations: context.read<EffectiveSettings>().showAnimations
		));
		if (pickedFlag != null) {
			if (pickedFlag.code == '0') {
				setState(() {
					flag = null;
				});
			}
			else {
				setState(() {
					flag = pickedFlag;
				});
			}
		}
	}

	Widget _buildAttachmentOptions(BuildContext context) {
		final board = context.read<Persistence>().getBoard(widget.board);
		final settings = context.watch<EffectiveSettings>();
		final fakeAttachment = Attachment(
			ext: '.$attachmentExt',
			url: '',
			type: attachmentExt == 'webm' || attachmentExt == 'mp4' ? AttachmentType.webm : AttachmentType.image,
			md5: '',
			id: attachment?.uri.toString() ?? 'zz',
			filename: attachment?.uri.pathSegments.last ?? '',
			thumbnailUrl: '',
			board: widget.board,
			width: null,
			height: null,
			sizeInBytes: null,
			threadId: null
		);
		return Container(
			decoration: BoxDecoration(
				border: Border(top: BorderSide(color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2))),
				color: CupertinoTheme.of(context).scaffoldBackgroundColor
			),
			padding: const EdgeInsets.only(top: 9, left: 8, right: 8, bottom: 10),
			child: Row(
				children: [
					Flexible(
						flex: 1,
						child: Column(
							mainAxisAlignment: MainAxisAlignment.spaceBetween,
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Row(
									children: [
										Flexible(
											child: CupertinoTextField(
												enabled: !settings.randomizeFilenames,
												controller: _filenameController,
												placeholder: (settings.randomizeFilenames || attachment == null) ? '' : attachment!.uri.pathSegments.last.replaceAll(RegExp('.$attachmentExt\$'), ''),
												placeholderStyle: TextStyle(color: CupertinoTheme.of(context).primaryColorWithBrightness(0.7)),
												maxLines: 1,
												textCapitalization: TextCapitalization.none,
												autocorrect: false,
												enableIMEPersonalizedLearning: settings.enableIMEPersonalizedLearning,
												smartDashesType: SmartDashesType.disabled,
												smartQuotesType: SmartQuotesType.disabled,
												keyboardAppearance: CupertinoTheme.of(context).brightness
											)
										),
										const SizedBox(width: 8),
										Text('.$attachmentExt')
									]
								),
								FittedBox(
									fit: BoxFit.contain,
									child: Row(
										children: [
											CupertinoButton(
												padding: EdgeInsets.zero,
												child: Row(
													mainAxisSize: MainAxisSize.min,
													children: [
														Icon(settings.randomizeFilenames ? CupertinoIcons.checkmark_square : CupertinoIcons.square),
														const Text('Random')
													]
												),
												onPressed: () {
													setState(() {
														settings.randomizeFilenames = !settings.randomizeFilenames;
													});
												}
											),
											const SizedBox(width: 8),
											if (board.spoilers == true) Padding(
												padding: const EdgeInsets.only(right: 8),
												child: CupertinoButton(
													padding: EdgeInsets.zero,
													child: Row(
														mainAxisSize: MainAxisSize.min,
														children: [
															Icon(spoiler ? CupertinoIcons.checkmark_square : CupertinoIcons.square),
															const Text('Spoiler')
														]
													),
													onPressed: () {
														setState(() {
															spoiler = !spoiler;
														});
													}
												)
											)
										]
									)
								)
							]
						)
					),
					const SizedBox(width: 8),
					Flexible(
						child: (attachment != null) ? Row(
							mainAxisAlignment: MainAxisAlignment.end,
							crossAxisAlignment: CrossAxisAlignment.center,
							children: [
								Flexible(
									child: Column(
										mainAxisAlignment: MainAxisAlignment.spaceBetween,
										crossAxisAlignment: CrossAxisAlignment.end,
										children: [
											CupertinoButton(
												padding: EdgeInsets.zero,
												minSize: 30,
												child: const Icon(CupertinoIcons.xmark),
												onPressed: () {
													widget.onFilePathChanged?.call(null);
													setState(() {
														attachment = null;
														_attachmentScan = null;
														_showAttachmentOptions = false;
														_filenameController.clear();
													});
												}
											),
											Flexible(
												child: AutoSizeText(
												[
													if (attachmentExt == 'mp4' || attachmentExt == 'webm') ...[
														if (_attachmentScan?.codec != null) _attachmentScan!.codec!.toUpperCase(),
														if (_attachmentScan?.hasAudio == true) 'with audio'
														else 'no audio',
														if (_attachmentScan?.duration != null) formatDuration(_attachmentScan!.duration!),
														if (_attachmentScan?.bitrate != null) '${(_attachmentScan!.bitrate! / (1024 * 1024)).toStringAsFixed(1)} Mbps',
													],
													if (_attachmentScan?.width != null && _attachmentScan?.height != null) '${_attachmentScan?.width}x${_attachmentScan?.height}'
												].join(', '),
												style: const TextStyle(color: Colors.grey),
												maxLines: 3,
												textAlign: TextAlign.right
											))
										]
									)
								),
								const SizedBox(width: 8),
								Flexible(
									child: GestureDetector(
										child: Hero(
											tag: TaggedAttachment(
												attachment: fakeAttachment,
												semanticParentIds: [_textFieldController.hashCode]
											),
											flightShuttleBuilder: (context, animation, direction, fromContext, toContext) {
												return (direction == HeroFlightDirection.push ? fromContext.widget as Hero : toContext.widget as Hero).child;
											},
											createRectTween: (startRect, endRect) {
												if (startRect != null && endRect != null) {
													if (attachmentExt != 'webm') {
														// Need to deflate the original startRect because it has inbuilt layoutInsets
														// This SavedAttachmentThumbnail will always fill its size
														final rootPadding = MediaQueryData.fromView(View.of(context)).padding - sumAdditionalSafeAreaInsets();
														startRect = rootPadding.deflateRect(startRect);
													}
												}
												return CurvedRectTween(curve: Curves.ease, begin: startRect, end: endRect);
											},
											child: SavedAttachmentThumbnail(file: attachment!, fit: BoxFit.contain)
										),
										onTap: () async {
											showGallery(
												attachments: [fakeAttachment],
												context: context,
												semanticParentIds: [_textFieldController.hashCode],
												overrideSources: {
													fakeAttachment: attachment!.uri
												},
												allowChrome: false,
												allowContextMenu: false,
												allowScroll: false,
												heroOtherEndIsBoxFitCover: false
											);
										}
									)
								)
							]
						) : const SizedBox.expand()
					),
				]
			)
		);
	}

	Widget _buildOptions(BuildContext context) {
		final settings = context.watch<EffectiveSettings>();
		return Container(
			decoration: BoxDecoration(
				border: Border(top: BorderSide(color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2))),
				color: CupertinoTheme.of(context).scaffoldBackgroundColor
			),
			padding: const EdgeInsets.only(top: 9, left: 8, right: 8, bottom: 10),
			child: Row(
				children: [
					Flexible(
						child: CupertinoTextField(
							maxLines: 1,
							placeholder: 'Name',
							keyboardAppearance: CupertinoTheme.of(context).brightness,
							controller: _nameFieldController,
							enableIMEPersonalizedLearning: settings.enableIMEPersonalizedLearning,
							smartDashesType: SmartDashesType.disabled,
							smartQuotesType: SmartQuotesType.disabled,
							suffix: CupertinoButton(
								padding: const EdgeInsets.only(right: 8),
								minSize: 0,
								onPressed: _previouslyUsedNames.isEmpty ? null : () async {
									final choice = await showCupertinoModalPopup<String>(
										context: context,
										builder: (context) => CupertinoActionSheet(
											title: const Text('Previously-used names'),
											actions: _previouslyUsedNames.map((name) => CupertinoActionSheetAction2(
												onPressed: () => Navigator.pop(context, name),
												isDefaultAction: _nameFieldController.text == name,
												child: Text(name)
											)).toList(),
											cancelButton: CupertinoActionSheetAction2(
												child: const Text('Cancel'),
												onPressed: () => Navigator.of(context).pop()
											)
										)
									);
									if (choice != null) {
										_nameFieldController.text = choice;
									}
								},
								child: const Icon(CupertinoIcons.list_bullet, size: 20)
							),
							onChanged: (s) {
								context.read<Persistence>().browserState.postingNames[widget.board] = s;
								context.read<Persistence>().didUpdateBrowserState();
							}
						)
					),
					const SizedBox(width: 8),
					Flexible(
						child: CupertinoTextField(
							maxLines: 1,
							placeholder: 'Options',
							enableIMEPersonalizedLearning: settings.enableIMEPersonalizedLearning,
							smartDashesType: SmartDashesType.disabled,
							smartQuotesType: SmartQuotesType.disabled,
							keyboardAppearance: CupertinoTheme.of(context).brightness,
							controller: _optionsFieldController,
							onChanged: (s) {
								widget.onOptionsChanged?.call(s);
							}
						)
					)
				]
			)
		);
	}

	Widget _buildTextField(BuildContext context) {
		final board = context.read<Persistence>().getBoard(widget.board);
		final settings = context.watch<EffectiveSettings>();
		return CallbackShortcuts(
			bindings: {
				LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.enter): _submit,
				LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyV): () async {
					if (await doesClipboardContainImage()) {
						try {
							final image = await getClipboardImageAsFile();
							if (image != null) {
								setAttachment(image);
							}
						}
						catch (e) {
							if (!mounted) return;
							alertError(context, e.toStringDio());
						}
					}
				}
			},
			child: Container(
				padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
				child: Column(
					children: [
						if (widget.threadId == null) ...[
							CupertinoTextField(
								enabled: !loading,
								enableIMEPersonalizedLearning: settings.enableIMEPersonalizedLearning,
								smartDashesType: SmartDashesType.disabled,
								smartQuotesType: SmartQuotesType.disabled,
								controller: _subjectFieldController,
								spellCheckConfiguration: (isOnMac && isDevelopmentBuild) ? null : const SpellCheckConfiguration(),
								maxLines: 1,
								placeholder: 'Subject',
								textCapitalization: TextCapitalization.sentences,
								keyboardAppearance: CupertinoTheme.of(context).brightness
							),
							const SizedBox(height: 8),
						],
						Flexible(
							child: Stack(
								children: [
									CupertinoTextField(
										enabled: !loading,
										enableIMEPersonalizedLearning: settings.enableIMEPersonalizedLearning,
										smartDashesType: SmartDashesType.disabled,
										smartQuotesType: SmartQuotesType.disabled,
										controller: _textFieldController,
										spellCheckConfiguration: (isOnMac && isDevelopmentBuild) ? null : const SpellCheckConfiguration(),
										contextMenuBuilder: (context, editableTextState) => AdaptiveTextSelectionToolbar.buttonItems(
											anchors: editableTextState.contextMenuAnchors,
											buttonItems: [
												...editableTextState.contextMenuButtonItems.map((item) {
													if (item.type == ContextMenuButtonType.paste) {
														return item.copyWith(
															onPressed: () {
																item.onPressed?.call();
																_handleImagePaste(manual: false);
															}
														);
													}
													return item;
												}),
												ContextMenuButtonItem(
													onPressed: _handleImagePaste,
													label: 'Paste image'
												)
											]
										),
										placeholder: 'Comment',
										maxLines: null,
										minLines: 100,
										focusNode: _textFocusNode,
										textCapitalization: TextCapitalization.sentences,
										keyboardAppearance: CupertinoTheme.of(context).brightness,
									),
									if (board.maxCommentCharacters != null && ((_textFieldController.text.length / board.maxCommentCharacters!) > 0.5)) IgnorePointer(
										child: Align(
											alignment: Alignment.bottomRight,
											child: Container(
												padding: const EdgeInsets.only(bottom: 4, right: 8),
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
			)
		);
	}

	Widget _buildButtons(BuildContext context) {
		final expandAttachmentOptions = loading ? null : () {
			setState(() {
				_showAttachmentOptions = !_showAttachmentOptions;
			});
		};
		final expandOptions = loading ? null : () {
			_checkPreviouslyUsedNames();
			setState(() {
				_showOptions = !_showOptions;
			});
		};
		final site = context.read<ImageboardSite>();
		final defaultTextStyle = DefaultTextStyle.of(context).style;
		final settings = context.watch<EffectiveSettings>();
		return Row(
			mainAxisAlignment: MainAxisAlignment.end,
			children: [
				for (final snippet in context.read<ImageboardSite>().getBoardSnippets(widget.board)) CupertinoButton(
					padding: EdgeInsets.zero,
					onPressed: () async {
						final controller = TextEditingController();
						final content = await showCupertinoDialog<String>(
							context: context,
							barrierDismissible: true,
							builder: (context) => CupertinoAlertDialog2(
								title: Text('${snippet.name} block'),
								content: Padding(
									padding: const EdgeInsets.only(top: 16),
									child: CupertinoTextField(
										autofocus: true,
										enableIMEPersonalizedLearning: settings.enableIMEPersonalizedLearning,
										smartDashesType: SmartDashesType.disabled,
										smartQuotesType: SmartQuotesType.disabled,
										minLines: 5,
										maxLines: 5,
										controller: controller,
										onSubmitted: (s) => Navigator.pop(context, s)
									)
								),
								actions: [
									CupertinoDialogAction2(
										child: const Text('Cancel'),
										onPressed: () => Navigator.pop(context)
									),
									if (snippet.previewBuilder != null) CupertinoDialogAction2(
										child: const Text('Preview'),
										onPressed: () {
											showCupertinoDialog<bool>(
												context: context,
												barrierDismissible: true,
												builder: (context) => CupertinoAlertDialog2(
													title: Text('${snippet.name} preview'),
													content: ChangeNotifierProvider<PostSpanZoneData>(
														create: (context) => PostSpanRootZoneData(
															site: site,
															thread: Thread(posts_: [], attachments: [], replyCount: 0, imageCount: 0, id: 0, board: '', title: '', isSticky: false, time: DateTime.now()),
															semanticRootIds: [-14]
														),
														builder: (context, _) => DefaultTextStyle(
															style: defaultTextStyle,
															child: Text.rich(
																snippet.previewBuilder!(controller.text).build(context, context.watch<PostSpanZoneData>(), context.watch<EffectiveSettings>(), PostSpanRenderOptions())
															)
														)
													),
													actions: [
														CupertinoDialogAction2(
															isDefaultAction: true,
															child: const Text('Close'),
															onPressed: () => Navigator.pop(context)
														)
													]
												)
											);
										}
									),
									CupertinoDialogAction2(
										isDefaultAction: true,
										onPressed: () => Navigator.pop(context, controller.text),
										child: const Text('Insert')
									)
								]
							)
						);
						if (content != null) {
							_insertText(snippet.start + content + snippet.end, addNewlineIfAtEnd: false);
						}
						controller.dispose();
					},
					child: Icon(snippet.icon)
				),
				if (_flags.isNotEmpty) Center(
					child: CupertinoButton(
						padding: EdgeInsets.zero,
						onPressed: _pickFlag,
						child: IgnorePointer(
							child: flag != null ? ExtendedImage.network(
								flag!.image.toString(),
								cache: true,
							) : const Icon(CupertinoIcons.flag)
						)
					)
				),
				if (context.read<ImageboardSite>().getEmotes().isNotEmpty) Center(
					child: CupertinoButton(
						padding: EdgeInsets.zero,
						onPressed: _pickEmote,
						child: const Icon(CupertinoIcons.smiley)
					)
				),
				Expanded(
					child: Align(
						alignment: Alignment.centerRight,
						child: AnimatedSize(
							alignment: Alignment.centerLeft,
							duration: const Duration(milliseconds: 250),
							curve: Curves.ease,
							child: attachment != null ? CupertinoButton(
								padding: const EdgeInsets.only(left: 8, right: 8),
								onPressed: expandAttachmentOptions,
								child: Row(
									mainAxisSize: MainAxisSize.min,
									children: [
										showAttachmentOptions ? const Icon(CupertinoIcons.chevron_down) : const Icon(CupertinoIcons.chevron_up),
										const SizedBox(width: 8),
										ClipRRect(
											borderRadius: BorderRadius.circular(4),
											child: ConstrainedBox(
												constraints: const BoxConstraints(
													maxWidth: 32,
													maxHeight: 32
												),
												child: SavedAttachmentThumbnail(file: attachment!, fontSize: 12)
											)
										),
									]
								)
							) : _attachmentProgress != null ? Row(
								mainAxisSize: MainAxisSize.min,
								children: [
									Text(_attachmentProgress!.$1),
									const SizedBox(width: 16),
									SizedBox(
										width: 100,
										child: ClipRRect(
											borderRadius: BorderRadius.circular(4),
											child: ValueListenableBuilder<double?>(
												valueListenable: _attachmentProgress!.$2,
												builder: (context, value, _) => LinearProgressIndicator(
													value: value,
													minHeight: 20,
													valueColor: AlwaysStoppedAnimation(CupertinoTheme.of(context).primaryColor),
													backgroundColor: CupertinoTheme.of(context).primaryColor.withOpacity(0.2)
												)
											)
										)
									)
								]
							) : AnimatedBuilder(
								animation: attachmentSourceNotifier,
								builder: (context, _) => ListView(
									shrinkWrap: true,
									scrollDirection: Axis.horizontal,
									children: [
										for (final file in receivedFilePaths.reversed) CupertinoButton(
											alignment: Alignment.center,
											padding: EdgeInsets.zero,
											onPressed: () => setAttachment(File(file)),
											child: ClipRRect(
												borderRadius: BorderRadius.circular(4),
												child: ConstrainedBox(
													constraints: const BoxConstraints(
														maxWidth: 32,
														maxHeight: 32
													),
													child: SavedAttachmentThumbnail(
														file: File(file)
													)
												)
											)
										),
										for (final picker in getAttachmentSources(context: context, includeClipboard: false)) CupertinoButton(
											padding: EdgeInsets.zero,
											onPressed: () async {
												final path = await picker.pick();
												if (path != null) {
													await setAttachment(File(path));
												}
											},
											child: Icon(picker.icon)
										)
									]
								)
							)
						)
					)
				),
				CupertinoButton(
					padding: EdgeInsets.zero,
					onPressed: expandOptions,
					child: const Icon(CupertinoIcons.gear)
				),
				TimedRebuilder(
					interval: const Duration(seconds: 1),
					enabled: show,
					builder: (context) {
						final timeout = context.read<ImageboardSite>().getActionAllowedTime(widget.board, widget.threadId == null ? 
							ImageboardAction.postThread :
							(attachment != null) ? ImageboardAction.postReplyWithImage : ImageboardAction.postReply);
						if (timeout != null) {
							final now = DateTime.now();
							final diff = timeout.difference(now);
							if (!diff.isNegative) {
								return GestureDetector(
									child: CupertinoButton(
										padding: EdgeInsets.zero,
										child: Column(
											mainAxisSize: MainAxisSize.min,
											crossAxisAlignment: CrossAxisAlignment.center,
											children: [
												if (_autoPostTimer?.isActive ?? false) const Text('Auto', style: TextStyle(fontSize: 12)),
												Text((diff.inMilliseconds / 1000).round().toString())
											]
										),
										onPressed: () async {
											if (!(_autoPostTimer?.isActive ?? false)) {
												if (!_haveValidCaptcha) {
													await _solveCaptcha();
												}
												if (_haveValidCaptcha) {
													_autoPostTimer = Timer(timeout.difference(DateTime.now()), _submit);
													_rootFocusNode.unfocus();
												}
											}
											else {
												_autoPostTimer!.cancel();
											}
											setState(() {});
										}
									),
									onLongPress: () {
										_autoPostTimer?.cancel();
										_submit();
									}
								);
							}
						}
						return CupertinoButton(
							padding: EdgeInsets.zero,
							alignment: Alignment.center,
							onPressed: loading ? null : _submit,
							child: const Icon(CupertinoIcons.paperplane)
						);
					}
				)
			]
		);
	}

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<EffectiveSettings>();
		return Focus(
			focusNode: _rootFocusNode,
			child: Column(
				mainAxisSize: MainAxisSize.min,
				children: [
					Expander(
						expanded: showAttachmentOptions && show,
						bottomSafe: true,
						height: 100,
						child: Focus(
							descendantsAreFocusable: showAttachmentOptions && show,
							child: _buildAttachmentOptions(context)
						)
					),
					Expander(
						expanded: showOptions && show,
						bottomSafe: true,
						height: 55,
						child: Focus(
							descendantsAreFocusable: showOptions && show,
							child: _buildOptions(context)
						)
					),
					Expander(
						expanded: show && _proposedAttachmentUrl != null,
						bottomSafe: true,
						height: 100,
						child: Row(
							mainAxisAlignment: MainAxisAlignment.spaceEvenly,
							children: [
								if (_proposedAttachmentUrl != null) Padding(
									padding: const EdgeInsets.all(8),
									child: ClipRRect(
										borderRadius: const BorderRadius.all(Radius.circular(8)),
										child: Image.network(
											_proposedAttachmentUrl!,
											width: 100
										)
									)
								),
								Flexible(child: CupertinoButton.filled(
									padding: const EdgeInsets.all(4),
									child: const Text('Use suggested image', textAlign: TextAlign.center),
									onPressed: () async {
										final site = context.read<ImageboardSite>();
										try {
											final dir = await (Directory('${Persistence.temporaryDirectory.path}/sharecache')).create(recursive: true);
											final data = await site.client.get(_proposedAttachmentUrl!, options: dio.Options(responseType: dio.ResponseType.bytes));
											final newFile = File('${dir.path}${DateTime.now().millisecondsSinceEpoch}_${_proposedAttachmentUrl!.split('/').last.split('?').first}');
											await newFile.writeAsBytes(data.data);
											setAttachment(newFile);
											_filenameController.text = _proposedAttachmentUrl!.split('/').last.split('.').reversed.skip(1).toList().reversed.join('.');
											_proposedAttachmentUrl = null;
											setState(() {});
										}
										catch (e, st) {
											print(e);
											print(st);
											alertError(context, e.toStringDio());
										}
									}
								)),
								CupertinoButton(
									child: const Icon(CupertinoIcons.xmark),
									onPressed: () {
										setState(() {
											_proposedAttachmentUrl = null;
										});
									}
								)
							]
						)
					),
					Expander(
						expanded: show,
						bottomSafe: !show,
						height: ((widget.threadId == null) ? 150 : 100) + settings.replyBoxHeightOffset,
						child: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								GestureDetector(
									behavior: HitTestBehavior.opaque,
									supportedDevices: const {
										PointerDeviceKind.mouse,
										PointerDeviceKind.stylus,
										PointerDeviceKind.invertedStylus,
										PointerDeviceKind.touch,
										PointerDeviceKind.unknown
									},
									onPanStart: (event) {
										_replyBoxHeightOffsetAtPanStart = settings.replyBoxHeightOffset;
										_panStartDy = event.globalPosition.dy;
									},
									onPanUpdate: (event) {
										final view = PlatformDispatcher.instance.views.first;
										final r = view.devicePixelRatio;
										setState(() {
											_willHideOnPanEnd = ((view.physicalSize.height / r) - event.globalPosition.dy) < (view.viewInsets.bottom / r);
											if (!_willHideOnPanEnd && (event.globalPosition.dy < _panStartDy || settings.replyBoxHeightOffset >= 0)) {
												// touch not above keyboard
												settings.replyBoxHeightOffset = min(MediaQuery.sizeOf(context).height / 2 - kMinInteractiveDimensionCupertino, max(0, settings.replyBoxHeightOffset - event.delta.dy));
											}
										});
									},
									onPanEnd: (event) {
										if (_willHideOnPanEnd) {
											Future.delayed(const Duration(milliseconds: 350), () {
												settings.replyBoxHeightOffset = _replyBoxHeightOffsetAtPanStart;
											});
											lightHapticFeedback();
											hideReplyBox();
											_willHideOnPanEnd = false;
										}
										else {
											settings.finalizeReplyBoxHeightOffset();
										}
									},
									child: Container(
										decoration: BoxDecoration(
											border: Border(top: BorderSide(color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2)))
										),
										height: 40,
										child: _buildButtons(context),
									)
								),
								Flexible(
									child: Container(
										color: CupertinoTheme.of(context).scaffoldBackgroundColor,
										child: Stack(
											children: [
												Column(
													mainAxisSize: MainAxisSize.min,
													children: [
														
														Expanded(child: _buildTextField(context)),
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
						)
					)
				]
			)
		);
	}

	@override
	void dispose() {
		super.dispose();
		_textFieldController.dispose();
		_nameFieldController.dispose();
		_subjectFieldController.dispose();
		_optionsFieldController.dispose();
		_filenameController.dispose();
		_textFocusNode.dispose();
		_rootFocusNode.dispose();
	}
}
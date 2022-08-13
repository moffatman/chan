import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:chan/models/attachment.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/pages/overscroll_modal.dart';
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
import 'package:chan/widgets/captcha_4chan.dart';
import 'package:chan/widgets/captcha_dvach.dart';
import 'package:chan/widgets/captcha_securimage.dart';
import 'package:chan/widgets/captcha_nojs.dart';
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

const _captchaContributionServer = 'https://captcha.moffatman.com';

const double _kArrowScreenPadding = 26.0;

class _ImagePastingTextSelectionControlsToolbar extends StatefulWidget {
	const _ImagePastingTextSelectionControlsToolbar({
		Key? key,
		required this.clipboardStatus,
		required this.endpoints,
		required this.globalEditableRegion,
		required this.handleCopy,
		required this.handleCut,
		required this.handlePaste,
		required this.handleSelectAll,
		required this.selectionMidpoint,
		required this.textLineHeight,
		required this.handleImagePaste,
	}) : super(key: key);

	final ValueListenable<ClipboardStatus>? clipboardStatus;
	final List<TextSelectionPoint> endpoints;
	final Rect globalEditableRegion;
	final VoidCallback? handleCopy;
	final VoidCallback? handleCut;
	final VoidCallback? handlePaste;
	final VoidCallback? handleSelectAll;
	final Offset selectionMidpoint;
	final double textLineHeight;
	final VoidCallback? handleImagePaste;

	@override
	_ImagePastingTextSelectionControlsToolbarState createState() => _ImagePastingTextSelectionControlsToolbarState();
}

class _ImagePastingTextSelectionControlsToolbarState extends State<_ImagePastingTextSelectionControlsToolbar> {
	void _onChangedClipboardStatus() {
		setState(() {
			// Inform the widget that the value of clipboardStatus has changed.
		});
	}

	@override
	void initState() {
		super.initState();
		widget.clipboardStatus?.addListener(_onChangedClipboardStatus);
	}

	@override
	void didUpdateWidget(_ImagePastingTextSelectionControlsToolbar oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.clipboardStatus != widget.clipboardStatus) {
			oldWidget.clipboardStatus?.removeListener(_onChangedClipboardStatus);
      widget.clipboardStatus?.addListener(_onChangedClipboardStatus);
		}
	}

	@override
	void dispose() {
		super.dispose();
		widget.clipboardStatus?.removeListener(_onChangedClipboardStatus);
	}

	@override
	Widget build(BuildContext context) {
		// Don't render the menu until the state of the clipboard is known.
		if (widget.handlePaste != null && widget.clipboardStatus?.value == ClipboardStatus.unknown) {
			return const SizedBox(width: 0.0, height: 0.0);
		}

		assert(debugCheckHasMediaQuery(context));
		final MediaQueryData mediaQuery = MediaQuery.of(context);

		// The toolbar should appear below the TextField when there is not enough
		// space above the TextField to show it, assuming there's always enough
		// space at the bottom in this case.
		final double anchorX = (widget.selectionMidpoint.dx + widget.globalEditableRegion.left).clamp(
			_kArrowScreenPadding + mediaQuery.padding.left,
			mediaQuery.size.width - mediaQuery.padding.right - _kArrowScreenPadding,
		);

		// The y-coordinate has to be calculated instead of directly quoting
		// selectionMidpoint.dy, since the caller
		// (TextSelectionOverlay._buildToolbar) does not know whether the toolbar is
		// going to be facing up or down.
		final Offset anchorAbove = Offset(
			anchorX,
			widget.endpoints.first.point.dy - widget.textLineHeight + widget.globalEditableRegion.top,
		);
		final Offset anchorBelow = Offset(
			anchorX,
			widget.endpoints.last.point.dy + widget.globalEditableRegion.top,
		);

		final List<Widget> items = <Widget>[];
		final CupertinoLocalizations localizations = CupertinoLocalizations.of(context);
		final Widget onePhysicalPixelVerticalDivider =
				SizedBox(width: 1.0 / MediaQuery.of(context).devicePixelRatio);

		void addToolbarButton(
			String text,
			VoidCallback onPressed,
		) {
			if (items.isNotEmpty) {
				items.add(onePhysicalPixelVerticalDivider);
			}

			items.add(CupertinoTextSelectionToolbarButton.text(
				onPressed: onPressed,
				text: text,
			));
		}

		if (widget.handleCut != null) {
			addToolbarButton(localizations.cutButtonLabel, widget.handleCut!);
		}
		if (widget.handleCopy != null) {
			addToolbarButton(localizations.copyButtonLabel, widget.handleCopy!);
		}
		if (widget.handlePaste != null
        && widget.clipboardStatus?.value == ClipboardStatus.pasteable) {
			addToolbarButton(localizations.pasteButtonLabel, widget.handlePaste!);
		}
		if (widget.handleSelectAll != null) {
			addToolbarButton(localizations.selectAllButtonLabel, widget.handleSelectAll!);
		}
		if (widget.handleImagePaste != null) {
			addToolbarButton('Paste image', widget.handleImagePaste!);
		}

		// If there is no option available, build an empty widget.
		if (items.isEmpty) {
			return const SizedBox(width: 0.0, height: 0.0);
		}

		return CupertinoTextSelectionToolbar(
			anchorAbove: anchorAbove,
			anchorBelow: anchorBelow,
			children: items,
		);
	}
}

class _ImagePastingEditingControls extends CupertinoTextSelectionControls {
	final ReplyBoxState replyBox;

	_ImagePastingEditingControls(this.replyBox) : super();

	Future<void> _handleImagePaste(TextSelectionDelegate delegate, {bool manual = true}) async {
		final file = await getClipboardImageAsFile();
		if (file != null) {
			replyBox.setAttachment(file);
		}
		else if (manual) {
			showToast(
				context: replyBox.context,
				message: 'No image in clipboard',
				icon: CupertinoIcons.xmark
			);
			delegate.hideToolbar();
		}
	}

	@override
	Future<void> handlePaste(TextSelectionDelegate delegate) async {
		await super.handlePaste(delegate);
		await _handleImagePaste(delegate, manual: false);
	}

	@override
	Widget buildToolbar(
		BuildContext context,
		Rect globalEditableRegion,
		double textLineHeight,
		Offset selectionMidpoint,
		List<TextSelectionPoint> endpoints,
		TextSelectionDelegate delegate,
		ValueListenable<ClipboardStatus>? clipboardStatus,
		Offset? lastSecondaryTapDownPosition,
	) {
		return _ImagePastingTextSelectionControlsToolbar(
			clipboardStatus: clipboardStatus,
			endpoints: endpoints,
			globalEditableRegion: globalEditableRegion,
			handleCut: canCut(delegate) ? () => handleCut(delegate) : null,
      handleCopy: canCopy(delegate) ? () => handleCopy(delegate) : null,
			handlePaste: canPaste(delegate) ? () => handlePaste(delegate) : null,
			handleSelectAll: canSelectAll(delegate) ? () => handleSelectAll(delegate) : null,
			handleImagePaste: () => _handleImagePaste(delegate),
			selectionMidpoint: selectionMidpoint,
			textLineHeight: textLineHeight,
		);
	}
}

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
	final _filenameController = TextEditingController();
	final _textFocusNode = FocusNode();
	bool loading = false;
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
	final _rootFocusNode = FocusNode();

	bool get _haveValidCaptcha {
		if (_captchaSolution == null) {
			return false;
		}
		return _captchaSolution?.expiresAt?.isAfter(DateTime.now()) ?? true;
	}

	void _onTextChanged() async {
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
		_textFieldController = TextEditingController(text: widget.initialText);
		_subjectFieldController = TextEditingController(text: widget.initialSubject);
		_optionsFieldController = TextEditingController(text: widget.initialOptions);
		_nameFieldController = TextEditingController(text: context.read<Persistence>().browserState.postingName);
		super.initState();
		_textFieldController.addListener(_onTextChanged);
		_subjectFieldController.addListener(() {
			widget.onSubjectChanged?.call(_subjectFieldController.text);
		});
		context.read<ImageboardSite>().getBoardFlags(widget.board).then((flags) {
			setState(() {
				_flags = flags;
			});
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
			spoiler = false;
			flag = null;
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
			else {
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
		if (!widget.isArchived) {
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
		if (_nameFieldController.text.isEmpty && context.read<Persistence>().browserState.postingName.isNotEmpty) {
			_nameFieldController.text = context.read<Persistence>().browserState.postingName;
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
		bool loading = false;
		ValueNotifier<double?> progress = ValueNotifier<double?>(null);
		final problems = [
			if (ext != transcode.outputFileExtension &&
					!(ext == 'jpeg' && transcode.outputFileExtension == 'jpg') &&
					!(ext == 'jpg' && transcode.outputFileExtension == 'jpeg')) 'File type needs to be converted to .${transcode.outputFileExtension} from .$ext',
			if (size != null && maximumSize != null && (size > maximumSize)) 'Size needs to be reduced from ${(size / 1e6).toStringAsFixed(1)} MB to below ${(maximumSize / 1e6).toStringAsFixed(1)} MB',
			if (audioPresent == true && audioAllowed == false) 'Audio track needs to be removed',
			if (durationInSeconds != null && maximumDurationInSeconds != null && (durationInSeconds > maximumDurationInSeconds)) 'Duration needs to be clipped at $maximumDurationInSeconds seconds'
		];
		if (width != null && height != null && maximumDimension != null && (width > maximumDimension || height > maximumDimension)) {
			final size = applyBoxFit(BoxFit.contain, Size(width.toDouble(), height.toDouble()), Size.square(maximumDimension.toDouble())).destination;
			problems.add('Dimensions need to be reduced from ${width}x$height to ${size.width.round()}x${size.height.round()}');
		}
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
		if (!mounted) return null;
		return await Navigator.of(context).push<Future<File>>(TransparentRoute(
			builder: (context) => OverscrollModalPage(
				child: Container(
					width: MediaQuery.of(context).size.width,
					color: CupertinoTheme.of(context).scaffoldBackgroundColor,
					padding: const EdgeInsets.all(16),
					child: StatefulBuilder(
						builder: (context, setTranscodeState) => Column(
							mainAxisSize: MainAxisSize.min,
							crossAxisAlignment: CrossAxisAlignment.center,
							children: [
								const Text('Transcoding required'),
								const SizedBox(height: 16),
								ConstrainedBox(
									constraints: const BoxConstraints(
										maxHeight: 150,
									),
									child: SavedAttachmentThumbnail(file: source)
								),
								const SizedBox(height: 32),
								...problems.expand((p) => [Text(p), const SizedBox(height: 16)]),
								CupertinoButton(
									onPressed: loading ? null : () async {
										setTranscodeState(() {
											loading = true;
										});
										transcode.start();
										setTranscodeState(() {
											progress = transcode.progress;
										});
										try {
											final result = await transcode.result;
											if (!mounted) return;
											Navigator.of(context).pop(Future.value(result.file));
										}
										catch (e) {
											Navigator.of(context).pop(Future<File>.error(e));
										}
									},
									child: loading ? const Text('Transcoding...') : const Text('Start')
								),
								if (loading) ValueListenableBuilder(
									valueListenable: progress,
									builder: (context, double? value, child) => LinearProgressIndicator(
										value: value,
										valueColor: AlwaysStoppedAnimation(CupertinoTheme.of(context).primaryColor),
										backgroundColor: CupertinoTheme.of(context).primaryColor.withOpacity(0.2)
									)
								)
							]
						)
					)
				)
			),
			showAnimations: context.read<EffectiveSettings>().showAnimations
		));
	}

	Future<void> setAttachment(File newAttachment) async {
		File? file = newAttachment;
		final settings = context.read<EffectiveSettings>();
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
			if (ext == 'jpg' || ext == 'jpeg') {
				final scan = await MediaScan.scan(file.uri);
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
				final scan = await MediaScan.scan(file.uri);
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
				final scan = await MediaScan.scan(file.uri);
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
				final scan = await MediaScan.scan(file.uri);
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
				setState(() {
					attachment = file;
				});
				widget.onFilePathChanged?.call(file.path);
			}
		}
		catch (e, st) {
			print(e);
			print(st);
			alertError(context, e.toStringDio());
		}
	}

	Future<void> _solveCaptcha() async {
		final site = context.read<ImageboardSite>();
		final settings = context.read<EffectiveSettings>();
		final savedFields = await site.getSavedLoginFields();
		if (savedFields != null) {
			bool shouldAutoLogin = settings.connectivity != ConnectivityResult.mobile;
			if (!shouldAutoLogin) {
				settings.autoLoginOnMobileNetwork ??= await showCupertinoDialog<bool>(
					context: context,
					builder: (context) => CupertinoAlertDialog(
						title: Text('Use ${site.getLoginSystemName()} on mobile networks?'),
						actions: [
							CupertinoDialogAction(
								child: const Text('Never'),
								onPressed: () {
									Navigator.of(context).pop(false);
								}
							),
							CupertinoDialogAction(
								child: const Text('Not now'),
								onPressed: () {
									Navigator.of(context).pop();
								}
							),
							CupertinoDialogAction(
								child: const Text('Just once'),
								onPressed: () {
									shouldAutoLogin = true;
									Navigator.of(context).pop();
								}
							),
							CupertinoDialogAction(
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
					await site.login(savedFields);
				}
				catch (e) {
					showToast(
						context: context,
						icon: CupertinoIcons.exclamationmark_triangle,
						message: 'Failed to log in to ${site.getLoginSystemName()}'
					);
					print('Problem auto-logging in: $e');
				}
			}
			else {
				await site.clearLoginCookies();
			}
		}
		try {
			final captchaRequest = await site.getCaptchaRequest(widget.board, widget.threadId);
			if (!mounted) return;
			if (captchaRequest is RecaptchaRequest) {
				hideReplyBox();
				_captchaSolution = await Navigator.of(context).push<CaptchaSolution>(TransparentRoute(
					builder: (context) => OverscrollModalPage(
						child: CaptchaNoJS(
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
				_captchaSolution = await Navigator.of(context).push<CaptchaSolution>(TransparentRoute(
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
				_captchaSolution = await Navigator.of(context).push<CaptchaSolution>(TransparentRoute(
					builder: (context) => OverscrollModalPage(
						child: CaptchaSecurimage(
							request: captchaRequest,
							onCaptchaSolved: (key) => Navigator.of(context).pop(key)
						)
					),
					showAnimations: context.read<EffectiveSettings>().showAnimations
				));
				showReplyBox();
			}
			else if (captchaRequest is DvachCaptchaRequest) {
				hideReplyBox();
				_captchaSolution = await Navigator.of(context).push<CaptchaSolution>(TransparentRoute(
					builder: (context) => OverscrollModalPage(
						child: CaptchaDvach(
							request: captchaRequest,
							onCaptchaSolved: (key) => Navigator.of(context).pop(key)
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
			if (_captchaSolution is Chan4CustomCaptchaSolution) {
				final solution = (_captchaSolution as Chan4CustomCaptchaSolution);
				settings.contributeCaptchas ??= await showCupertinoDialog<bool>(
					context: context,
					builder: (context) => CupertinoAlertDialog(
						title: const Text('Contribute captcha solutions?'),
						content: const Text('The captcha images you solve will be collected to improve the automated solver'),
						actions: [
							CupertinoDialogAction(
								child: const Text('No'),
								onPressed: () {
									Navigator.of(context).pop(false);
								}
							),
							CupertinoDialogAction(
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
			}
			_textFieldController.clear();
			_nameFieldController.clear();
			_optionsFieldController.clear();
			_subjectFieldController.clear();
			_filenameController.clear();
			_show = false;
			loading = false;
			attachment = null;
			if (mounted) setState(() {});
			print(receipt);
			_rootFocusNode.unfocus();
			final threadState = persistence.getThreadState((widget.threadId != null) ?
				ThreadIdentifier(widget.board, widget.threadId!) :
				ThreadIdentifier(widget.board, receipt.id));
			threadState.receipts = [...threadState.receipts, receipt];
			threadState.save();
			showToast(context: context, message: 'Post successful', icon: CupertinoIcons.check_mark);
			widget.onReplyPosted(receipt);
		}
		catch (e, st) {
			print(e);
			print(st);
			setState(() {
				loading = false;
			});
			alertError(context, e.toStringDio());
		}
		_captchaSolution = null;
	}

	void _pickEmote() async {
		final emotes = context.read<ImageboardSite>().getEmotes();
		final pickedEmote = await Navigator.of(context).push<ImageboardEmote>(TransparentRoute(
			builder: (context) => OverscrollModalPage(
				child: Container(
					width: MediaQuery.of(context).size.width,
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
					width: MediaQuery.of(context).size.width,
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
		final fakeAttachment = Attachment(
			ext: '.$attachmentExt',
			url: Uri.https('', ''),
			type: attachmentExt == 'webm' || attachmentExt == 'mp4' ? AttachmentType.webm : AttachmentType.image,
			md5: '',
			id: attachment?.uri.toString() ?? 'zz',
			filename: attachment?.uri.pathSegments.last ?? '',
			thumbnailUrl: Uri.https('', ''),
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
												enabled: !context.watch<EffectiveSettings>().randomizeFilenames,
												controller: _filenameController,
												placeholder: (context.watch<EffectiveSettings>().randomizeFilenames || attachment == null) ? '' : attachment!.uri.pathSegments.last.replaceAll(RegExp('.$attachmentExt\$'), ''),
												placeholderStyle: TextStyle(color: CupertinoTheme.of(context).primaryColorWithBrightness(0.7)),
												maxLines: 1,
												textCapitalization: TextCapitalization.none,
												autocorrect: false,
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
														Icon(context.watch<EffectiveSettings>().randomizeFilenames ? CupertinoIcons.checkmark_square : CupertinoIcons.square),
														const Text('Random')
													]
												),
												onPressed: () {
													setState(() {
														context.read<EffectiveSettings>().randomizeFilenames = !context.read<EffectiveSettings>().randomizeFilenames;
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
							mainAxisAlignment: MainAxisAlignment.center,
							crossAxisAlignment: CrossAxisAlignment.center,
							children: [
								Flexible(
									child: GestureDetector(
										child: Hero(
											tag: AttachmentSemanticLocation(
												attachment: fakeAttachment,
												semanticParents: [_textFieldController.hashCode]
											),
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
												allowContextMenu: false
											);
										}
									)
								),
								const SizedBox(width: 8),
								Center(
									child: CupertinoButton(
										padding: EdgeInsets.zero,
										minSize: 30,
										child: const Icon(CupertinoIcons.xmark),
										onPressed: () {
											setState(() {
												attachment = null;
												_showAttachmentOptions = false;
												_filenameController.clear();
											});
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
							onChanged: (s) {
								context.read<Persistence>().browserState.postingName = s;
								context.read<Persistence>().didUpdateBrowserState();
							}
						)
					),
					const SizedBox(width: 8),
					Flexible(
						child: CupertinoTextField(
							maxLines: 1,
							placeholder: 'Options',
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
								controller: _subjectFieldController,
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
										controller: _textFieldController,
										selectionControls: _ImagePastingEditingControls(this),
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
			setState(() {
				_showOptions = !_showOptions;
			});
		};
		final site = context.read<ImageboardSite>();
		final defaultTextStyle = DefaultTextStyle.of(context).style;
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
							builder: (context) => CupertinoAlertDialog(
								title: Text('${snippet.name} block'),
								content: Padding(
									padding: const EdgeInsets.only(top: 16),
									child: CupertinoTextField(
										autofocus: true,
										minLines: 5,
										maxLines: 5,
										controller: controller,
										onSubmitted: (s) => Navigator.pop(context, s)
									)
								),
								actions: [
									CupertinoDialogAction(
										child: const Text('Cancel'),
										onPressed: () => Navigator.pop(context)
									),
									if (snippet.previewBuilder != null) CupertinoDialogAction(
										child: const Text('Preview'),
										onPressed: () {
											showCupertinoDialog<bool>(
												context: context,
												barrierDismissible: true,
												builder: (context) => CupertinoAlertDialog(
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
																snippet.previewBuilder!(controller.text).build(context, PostSpanRenderOptions())
															)
														)
													),
													actions: [
														CupertinoDialogAction(
															isDefaultAction: true,
															child: const Text('Close'),
															onPressed: () => Navigator.pop(context)
														)
													]
												)
											);
										}
									),
									CupertinoDialogAction(
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
							) : AnimatedBuilder(
								animation: attachmentSourceNotifier,
								builder: (context, _) => ListView(
									shrinkWrap: true,
									scrollDirection: Axis.horizontal,
									children: [
										for (final file in receivedFilePaths) CupertinoButton(
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
											final newFile = File('${dir.path}${DateTime.now().millisecondsSinceEpoch}_${_proposedAttachmentUrl!.split('/').last}');
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
										final r = WidgetsBinding.instance.window.devicePixelRatio;
										setState(() {
											_willHideOnPanEnd = ((WidgetsBinding.instance.window.physicalSize.height / r) - event.globalPosition.dy) < (WidgetsBinding.instance.window.viewInsets.bottom / r);
											if (!_willHideOnPanEnd && (event.globalPosition.dy < _panStartDy || settings.replyBoxHeightOffset >= 0)) {
												// touch not above keyboard
												settings.replyBoxHeightOffset = min(MediaQuery.of(context).size.height / 2, max(0, settings.replyBoxHeightOffset - event.delta.dy));
											}
										});
									},
									onPanEnd: (event) {
										if (_willHideOnPanEnd) {
											Future.delayed(const Duration(milliseconds: 350), () {
												settings.replyBoxHeightOffset = _replyBoxHeightOffsetAtPanStart;
											});
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
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/services/apple.dart';
import 'package:chan/services/clipboard_image.dart';
import 'package:chan/services/embed.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/linkifier.dart';
import 'package:chan/services/media.dart';
import 'package:chan/services/outbox.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/pick_attachment.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/text_highlighting.dart';
import 'package:chan/services/text_normalization.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/attachment_viewer.dart';
import 'package:chan/widgets/outbox.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/timed_rebuilder.dart';
import 'package:chan/widgets/util.dart';
import 'package:chan/widgets/saved_attachment_thumbnail.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart' as dio;
import 'package:extended_image/extended_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';
import 'package:linkify/linkify.dart';
import 'package:provider/provider.dart';
import 'package:heic_to_jpg/heic_to_jpg.dart';

class _StoppedValueListenable<T> implements ValueListenable<T> {
	@override
	final T value;

	const _StoppedValueListenable(this.value);
	
	@override
	void addListener(VoidCallback listener) { }

	@override
	void removeListener(VoidCallback listener) { }	
}

class ReplyBoxZone {
	final void Function(int threadId, int id) onTapPostId;

	final void Function(String text, {required int fromId, required int fromThreadId, required bool includeBacklink}) onQuoteText;

	const ReplyBoxZone({
		required this.onTapPostId,
		required this.onQuoteText
	});
}

class ReplyBox extends StatefulWidget {
	final String board;
	final int? threadId;
	final ValueChanged<PostReceipt> onReplyPosted;
	final DraftPost? initialDraft;
	final ValueChanged<DraftPost?>? onDraftChanged;
	final VoidCallback? onVisibilityChanged;
	final bool isArchived;
	final bool fullyExpanded;
	final ValueChanged<ReplyBoxState>? onInitState;

	const ReplyBox({
		required this.board,
		this.threadId,
		required this.onReplyPosted,
		this.initialDraft,
		this.onDraftChanged,
		this.onVisibilityChanged,
		this.isArchived = false,
		this.fullyExpanded = false,
		this.onInitState,
		Key? key
	}) : super(key: key);

	@override
	createState() => ReplyBoxState();
}

class ReplyBoxState extends State<ReplyBox> {
	late final TextEditingController _textFieldController;
	late final TextEditingController _nameFieldController;
	late final TextEditingController _subjectFieldController;
	late final TextEditingController _optionsFieldController;
	late final TextEditingController _filenameController;
	late final FocusNode _textFocusNode;
	QueuedPost? _postingPost;
	bool get loading => _postingPost != null;
	(MediaScan, FileStat, Digest)? _attachmentScan;
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
	bool spoiler = false;
	List<ImageboardBoardFlag> _flags = [];
	ImageboardBoardFlag? flag;
	double _panStartDy = 0;
	double _replyBoxHeightOffsetAtPanStart = 0;
	bool _willHideOnPanEnd = false;
	late final FocusNode _rootFocusNode;
	(String, MediaConversion?)? _attachmentProgress;
	static List<String> _previouslyUsedNames = [];
	static List<String> _previouslyUsedOptions = [];
	late final Timer _focusTimer;
	(DateTime, FocusNode)? _lastNearbyFocus;
	bool _disableLoginSystem = false;
	final Map<ImageboardSnippet, TextEditingController> _snippetControllers = {};
	final List<QueuedPost> _submittingPosts = [];

	ThreadIdentifier? get thread => switch (widget.threadId) {
		int threadId => ThreadIdentifier(widget.board, threadId),
		null => null
	};

	String get text => _textFieldController.text;
	set text(String newText) => _textFieldController.text = newText;

	String get options => _optionsFieldController.text;
	set options(String newOptions) => _optionsFieldController.text = newOptions;

	String get defaultName => context.read<Persistence?>()?.browserState.postingNames[widget.board] ?? '';

	static final _quotelinkPattern = RegExp(r'>>(\d+)');
	set draft(DraftPost? draft) {
		if (draft != null) {
			String text = draft.text;
			if (draft.board != widget.board) {
				// Adjust quotelinks to match cross-board paste
				text = text.replaceAllMapped(_quotelinkPattern, (match) {
					return '>>>/${draft.board}/${match.group(1)}';
				});
			}
			_textFieldController.text = text;
			_optionsFieldController.text = draft.options ?? '';
			_filenameController.text = draft.overrideFilenameWithoutExtension ?? '';
			_nameFieldController.text = draft.name ?? defaultName;
			final subject = draft.subject;
			if (subject != null) {
				_subjectFieldController.text = subject;
			}
			_disableLoginSystem = switch (draft.useLoginSystem) {
				false => true,
				null || true => false
			};
		}
		else {
			_textFieldController.clear();
			// Don't clear options
			_subjectFieldController.clear();
			_nameFieldController.text = defaultName;
			// Don't clear disableLoginSystem
		}
		final file = draft?.file;
		if (file == attachment?.path) {
			// Do nothing
		}
		else {
			attachment = null;
			_showAttachmentOptions = false;
			_attachmentScan = null;
			_filenameController.clear();
			if (file != null) {
				// TODO: Careful here. What if we keep trying the same junk file.
				_tryUsingInitialFile(file);
			}
		}
	}

	static bool _previousPostReceiptIsTooOld(DateTime? time) {
		return DateTime.now().difference(time ?? DateTime(2000)).inDays > 30;
	}

	Future<void> _checkPreviousPostReceipts() async {
		final previouslyUsedNames = <String>{};
		final previouslyUsedOptions = <String>{};
		for (final state in Persistence.sharedThreadStateBox.values) {
			bool anyIncompleteReceipts = false;
			for (final receipt in state.receipts) {
				if (receipt.time == null) {
					// PostReceipt generated before name,options stored
					anyIncompleteReceipts = true;
					continue;
				}
				if (_previousPostReceiptIsTooOld(receipt.time)) {
					continue;
				}
				if (receipt.name.isNotEmpty) {
					previouslyUsedNames.add(receipt.name);
				}
				if (receipt.options.isNotEmpty) {
					previouslyUsedOptions.add(receipt.options.trim());
				}
			}
			if (anyIncompleteReceipts) {
				final thread = await state.getThread();
				if (_previousPostReceiptIsTooOld(thread?.time)) {
					continue;
				}
				for (final post in thread?.posts_ ?? const Iterable.empty()) {
					if (!state.youIds.contains(post.id)) {
						continue;
					}
					final name = post.name.trim();
					if (name == (state.imageboard?.site.defaultUsername ?? 'Anonymous')) {
						continue;
					}
					previouslyUsedNames.add(name);
				}
			}
		}
		_previouslyUsedNames = previouslyUsedNames.toList()..sort();
		_previouslyUsedOptions = previouslyUsedOptions.toList()..sort();
		if (mounted) {
			setState(() {});
		}
	}

	void _onTextChanged() async {
		_didUpdateDraft();
		final rawUrl = linkify(text, linkifiers: const [LooseUrlLinkifier()]).tryMapOnce<String>((element) {
			if (element is UrlElement) {
				final path = Uri.parse(element.url).path;
				if (['.jpg', '.jpeg', '.png', '.gif', '.webm'].any(path.endsWith)) {
					return element.url;
				}
			}
			return null;
		});
		if (rawUrl != _lastFoundUrl && rawUrl != null) {
			try {
				await context.read<ImageboardSite>().client.head(rawUrl);
				_lastFoundUrl = rawUrl;
				_proposedAttachmentUrl = rawUrl;
				if (mounted) setState(() {});
				return;
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
					return;
				}
			}
			else if (possibleEmbed != null) {
				// Don't clear it
				return;
			}
		}
		if (rawUrl == null) {
			// Nothing at all in the text
			_lastFoundUrl = null;
			if (_proposedAttachmentUrl != null && mounted) {
				setState(() {
					_proposedAttachmentUrl = null;
				});
			}
		}
	}

	DraftPost _makeDraft() => DraftPost(
		board: widget.board,
		threadId: widget.threadId,
		subject: _subjectFieldController.text,
		name: null, // It will be stored in postingNames[board]
		options: _optionsFieldController.text,
		text: _textFieldController.text,
		file: attachment?.path,
		spoiler: spoiler,
		overrideFilenameWithoutExtension: _filenameController.text,
		flag: flag,
		useLoginSystem: switch (_disableLoginSystem) {
			true => false,
			_ => null
		}
	);

	void _didUpdateDraft() {
		final draft = _makeDraft();
		widget.onDraftChanged?.call(_isNonTrivial(draft) ? draft : null);
	}

	@override
	void initState() {
		super.initState();
		final persistence = context.read<Persistence>();
		_textFieldController = ReplyBoxTextEditingController(text: widget.initialDraft?.text);
		_subjectFieldController = TextEditingController(text: widget.initialDraft?.subject);
		_optionsFieldController = TextEditingController(text: widget.initialDraft?.options);
		_filenameController = TextEditingController(text: widget.initialDraft?.overrideFilenameWithoutExtension);
		_nameFieldController = TextEditingController(text: persistence.browserState.postingNames[widget.board]);
		spoiler = widget.initialDraft?.spoiler ?? false;
		flag = widget.initialDraft?.flag;
		if (widget.initialDraft?.useLoginSystem == false) {
			_disableLoginSystem = true;
		}
		_textFocusNode = FocusNode();
		_rootFocusNode = FocusNode();
		_textFieldController.addListener(_onTextChanged);
		_subjectFieldController.addListener(_didUpdateDraft);
		context.read<ImageboardSite>().getBoardFlags(widget.board).then((flags) {
			if (!mounted) return;
			setState(() {
				_flags = flags;
			});
		}).catchError((e, st) {
			Future.error(e, st); // Crashlytics
			print('Error getting flags for ${widget.board}: $e');
		});
		if (_nameFieldController.text.isNotEmpty || _optionsFieldController.text.isNotEmpty) {
			_showOptions = true;
		}
		_tryUsingInitialFile(widget.initialDraft?.file);
		widget.onInitState?.call(this);
		_focusTimer = Timer.periodic(const Duration(milliseconds: 200), (_) => _pollFocus());
	}

	void _pollFocus() {
		if (!_show) {
			return;
		}
		final nearbyFocus = FocusScope.of(context).focusedChild;
		if (nearbyFocus != null) {
			_lastNearbyFocus = (DateTime.now(), nearbyFocus);
		}
	}

	@override
	void didUpdateWidget(ReplyBox oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.board != widget.board || oldWidget.threadId != widget.threadId) {
			draft = widget.initialDraft;
		}
		if (oldWidget.board != widget.board) {
			context.read<ImageboardSite>().getBoardFlags(widget.board).then((flags) {
				setState(() {
					_flags = flags;
				});
			});
		}
	}

	void _tryUsingInitialFile(String? path) async {
		if (path != null) {
			final file = File(path);
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
		}
	}

	void _insertText(String insertedText, {bool addNewlineIfAtEnd = true, TextSelection? initialSelection}) {
		final selection = initialSelection ?? _textFieldController.selection;
		if (selection.isCollapsed) {
			// Insert at selection point
			int currentPos = selection.base.offset;
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
		else {
			// Replace selected text
			_textFieldController.value = TextEditingValue(
				selection: TextSelection(
					baseOffset: selection.baseOffset,
					extentOffset: selection.baseOffset + insertedText.length
				),
				text: _textFieldController.text.substring(0, selection.baseOffset) + insertedText + _textFieldController.text.substring(selection.extentOffset)
			);
		}
	}

	void onTapPostId(int threadId, int id) {
		if (!widget.isArchived && (context.read<ImageboardSite?>()?.supportsPosting ?? false)) {
			if (threadId != widget.threadId) {
				showToast(
					context: context,
					message: 'Cross-thread reply!',
					icon: CupertinoIcons.exclamationmark_triangle
				);
			}
			showReplyBox();
			_insertText('>>$id');
		}
	}

	void onQuoteText(String text, {required int fromId, required int fromThreadId, required bool includeBacklink}) {
		if (!widget.isArchived && (context.read<ImageboardSite?>()?.supportsPosting ?? false)) {
			if (fromThreadId != widget.threadId) {
				showToast(
					context: context,
					message: 'Cross-thread reply!',
					icon: CupertinoIcons.exclamationmark_triangle
				);
			}
			showReplyBox();
			if (includeBacklink) {
				_insertText('>>$fromId');
			}
			_insertText('>${text.replaceAll('\n', '\n>')}');
		}
	}

	void showReplyBox() {
		_checkPreviousPostReceipts();
		final persistence = context.read<Persistence>();
		if (_nameFieldController.text.isEmpty) {
			final name = persistence.browserState.postingNames[widget.board];
			if (name?.isNotEmpty ?? false) {
				_nameFieldController.text = name ?? '';
				_showOptions = true;
			}
		}
		for (final draft in Outbox.instance.queuedPostsFor(context.read<Imageboard>().key, widget.board, widget.threadId)) {
			if (!_submittingPosts.contains(draft) && draft != _postingPost) {
				// This is some message restored from persistence.outbox (previous app launch)
				_submittingPosts.add(draft);
				_listenToReplyPosting(draft);
			}
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
		required bool metadataPresent,
		required bool metadataAllowed,
		required bool randomizeChecksum,
		required MediaConversion transcode,
		required bool showToastIfOnlyRandomizingChecksum
	}) async {
		final ext = source.path.split('.').last.toLowerCase();
		final solutions = [
			if (ext != transcode.outputFileExtension &&
					!(ext == 'jpeg' && transcode.outputFileExtension == 'jpg') &&
					!(ext == 'jpg' && transcode.outputFileExtension == 'jpeg')) 'to .${transcode.outputFileExtension}',
			if (size != null && maximumSize != null && (size > maximumSize)) 'compressing',
			if (durationInSeconds != null && maximumDurationInSeconds != null && (durationInSeconds > maximumDurationInSeconds)) 'clipping at ${maximumDurationInSeconds}s',
		];
		if (width != null && height != null && maximumDimension != null && (width > maximumDimension || height > maximumDimension)) {
			solutions.add('resizing');
		}
		const kRandomizingChecksum = 'randomizing checksum';
		if (randomizeChecksum) {
			solutions.add(kRandomizingChecksum);
		}
		transcode.copyStreams = solutions.isEmpty;
		if (metadataPresent && !metadataAllowed) {
			solutions.add('removing metadata');
		}
		if (audioPresent == true && audioAllowed == false) {
			solutions.add('removing audio');
		}
		if (solutions.isEmpty && ['jpg', 'jpeg', 'png', 'gif', 'webm'].contains(ext)) {
			return source;
		}
		final existingResult = await transcode.getDestinationIfSatisfiesConstraints();
		if (existingResult != null) {
			if ((audioPresent == true && audioAllowed == true && !existingResult.hasAudio)) {
				transcode.requireAudio = true;
				solutions.add('re-adding audio');
			}
			else {
				return existingResult.file;
			}
		}
		if (!mounted) return null;
		setState(() {
			_attachmentProgress = ('Converting', transcode);
		});
		try {
			bool toastedStart = false;
			Future.delayed(const Duration(milliseconds: 500), () {
				if (_attachmentProgress != null) {
					showToast(context: context, message: 'Converting: ${solutions.join(', ')}', icon: Adaptive.icons.photo);
					toastedStart = true;
				}
			});
			final result = await transcode.start();
			if (!mounted) return null;
			setState(() {
				_attachmentProgress = null;
			});
			if (toastedStart || showToastIfOnlyRandomizingChecksum || solutions.trySingle != kRandomizingChecksum) {
				showToast(context: context, message: 'File converted${toastedStart ? '' : ': ${solutions.join(', ')}'}', icon: CupertinoIcons.checkmark);
			}
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

	Future<void> setAttachment(File newAttachment, {bool forceRandomizeChecksum = false}) async {
		File? file = newAttachment;
		final settings = Settings.instance;
		final randomizeChecksum = forceRandomizeChecksum || settings.randomizeChecksumOnUploadedFiles;
		setState(() {
			_attachmentProgress = ('Processing', null);
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
			final size = (await file.stat()).size;
			final scan = await MediaScan.scan(file.uri);
			if (ext == 'jpg' || ext == 'jpeg' || ext == 'webp' || ext == 'avif') {
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
						maximumDimension: settings.maximumImageUploadDimension,
						removeMetadata: settings.removeMetadataOnUploadedFiles,
						randomizeChecksum: randomizeChecksum
					),
					metadataPresent: scan.hasMetadata,
					metadataAllowed: !settings.removeMetadataOnUploadedFiles,
					randomizeChecksum: randomizeChecksum,
					showToastIfOnlyRandomizingChecksum: forceRandomizeChecksum
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
						maximumDimension: settings.maximumImageUploadDimension,
						removeMetadata: settings.removeMetadataOnUploadedFiles,
						randomizeChecksum: randomizeChecksum
					),
					metadataPresent: scan.hasMetadata,
					metadataAllowed: !settings.removeMetadataOnUploadedFiles,
					randomizeChecksum: randomizeChecksum,
					showToastIfOnlyRandomizingChecksum: forceRandomizeChecksum
				);
			}
			else if (ext == 'gif') {
				if ((board.maxImageSizeBytes != null) && (size > board.maxImageSizeBytes!)) {
					throw Exception('GIF is too large, and automatic re-encoding of GIFs is not supported');
				}
				if (randomizeChecksum) {
					file = await _showTranscodeWindow(
						source: file,
						metadataPresent: scan.hasMetadata,
						metadataAllowed: !settings.removeMetadataOnUploadedFiles,
						randomizeChecksum: randomizeChecksum,
						transcode: MediaConversion.toGif(
							file.uri,
							randomizeChecksum: randomizeChecksum
						),
						showToastIfOnlyRandomizingChecksum: forceRandomizeChecksum
					);
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
						maximumDurationInSeconds: board.maxWebmDurationSeconds?.toDouble(),
						maximumDimension: settings.maximumImageUploadDimension,
						removeMetadata: settings.removeMetadataOnUploadedFiles,
						randomizeChecksum: randomizeChecksum
					),
					metadataPresent: scan.hasMetadata,
					metadataAllowed: !settings.removeMetadataOnUploadedFiles,
					randomizeChecksum: randomizeChecksum,
					showToastIfOnlyRandomizingChecksum: forceRandomizeChecksum
				);
			}
			else if (ext == 'mp4' || ext == 'mov' || ext == 'm4v' || ext == 'mkv' || ext == 'mpeg') {
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
						maximumDurationInSeconds: board.maxWebmDurationSeconds?.toDouble(),
						maximumDimension: settings.maximumImageUploadDimension,
						removeMetadata: settings.removeMetadataOnUploadedFiles,
						randomizeChecksum: randomizeChecksum
					),
					metadataPresent: scan.hasMetadata,
					metadataAllowed: !settings.removeMetadataOnUploadedFiles,
					randomizeChecksum: randomizeChecksum,
					showToastIfOnlyRandomizingChecksum: forceRandomizeChecksum
				);
			}
			else {
				throw Exception('Unsupported file type: $ext');
			}
			setState(() {
				_attachmentProgress = null;
			});
			if (file != null) {
				_attachmentScan = (await MediaScan.scan(file.uri), await file.stat(), await md5.bind(file.openRead()).first);
				setState(() {
					attachment = file;
				});
				_filenameController.text = file.uri.pathSegments.last.replaceAll(RegExp('.$attachmentExt\$'), '');
				_didUpdateDraft();
			}
		}
		catch (e, st) {
			print(e);
			print(st);
			if (mounted) {
				alertError(context, e.toStringDio());
				setState(() {
					_attachmentProgress = null;
				});
			}
		}
	}

	Future<bool> _shouldUseLoginSystem() async {
		final site = context.read<ImageboardSite>();
		final settings = Settings.instance;
		final savedFields = site.loginSystem?.getSavedLoginFields();
		if (_disableLoginSystem) {
			return false;
		}
		if (savedFields == null) {
			return false;
		}
		if (settings.connectivity != ConnectivityResult.mobile) {
			return true;
		}
		bool? justOnce;
		Settings.autoLoginOnMobileNetworkSetting.value ??= await showAdaptiveDialog<bool>(
			context: context,
			builder: (context) => AdaptiveAlertDialog(
				title: Text('Use ${site.loginSystem?.name} on mobile networks?'),
				actions: [
					AdaptiveDialogAction(
						child: const Text('Never'),
						onPressed: () {
							Navigator.of(context).pop(false);
						}
					),
					AdaptiveDialogAction(
						child: const Text('Not now'),
						onPressed: () {
							Navigator.of(context).pop();
						}
					),
					AdaptiveDialogAction(
						child: const Text('Just once'),
						onPressed: () {
							justOnce = true;
							Navigator.of(context).pop();
						}
					),
					AdaptiveDialogAction(
						child: const Text('Always'),
						onPressed: () {
							Navigator.of(context).pop(true);
						}
					)
				]
			)
		);
		return justOnce ?? Settings.autoLoginOnMobileNetworkSetting.value ?? false;
	}

	Future<void> _submit() async {
		final shouldUseLoginSystem = await _shouldUseLoginSystem();
		if (!mounted) {
			return;
		}
		final imageboard = context.read<Imageboard>();
		// Replace known-bad special symbols
		_textFieldController.text = _textFieldController.text.normalizeSymbols;
		_nameFieldController.text = _nameFieldController.text.normalizeSymbols;
		_optionsFieldController.text = _optionsFieldController.text.normalizeSymbols;
		_subjectFieldController.text = _subjectFieldController.text.normalizeSymbols;
		_filenameController.text = _filenameController.text.normalizeSymbols;
		lightHapticFeedback();
		final post = _makeDraft();
		post.name = _nameFieldController.text;
		post.useLoginSystem = shouldUseLoginSystem;
		final entry = Outbox.instance.submitPost(imageboard.key, post, QueueStateNeedsCaptcha(context,
			beforeModal: hideReplyBox,
			afterModal: showReplyBox
		));
		// Remember _disableLoginSystem, it will also be kept in the draft
		if (!_disableLoginSystem) {
			_showAttachmentOptions = false;
		}
		final oldPostingPost = _postingPost;
		if (oldPostingPost != null) {
			// This should never happen tbqh
			_submittingPosts.add(oldPostingPost);
		}
		_postingPost = entry;
		// This needs to happen last so it doesn't eagerly assume this is an undeletion
		_listenToReplyPosting(entry);
		setState(() {});
	}

	void _reset() {
		_textFieldController.clear();
		_nameFieldController.text = defaultName;
		// Don't clear options field, it should be remembered
		_subjectFieldController.clear();
		_filenameController.clear();
		attachment = null;
		_attachmentScan = null;
		_didUpdateDraft();
	}

	void _postInBackground() {
		final toMove = _postingPost;
		if (toMove == null) {
			return;
		}
		_submittingPosts.add(toMove);
		_reset();
		setState(() {
			_postingPost = null;
		});
	}

	/// Return the primary outgoing post to the reply box
	void _cancel() {
		final post = _postingPost;
		if (post == null) {
			return;
		}
		post.cancel();
		post.delete();
		setState(() {
			_postingPost = null;
		});
		// The old contents should still be in the reply box.
	}

	void _listenToReplyPosting(QueuedPost post) {
		QueueState<PostReceipt>? lastState;
		void listener() async {
			if (!mounted) {
				post.removeListener(listener);
				return;
			}
			final state = post.state;
			if (state == lastState) {
				// Sometimes notifyListeners() just used to internally rebuild
				return;
			}
			lastState = state;
			if (state is QueueStateDeleted<PostReceipt>) {
				// Don't remove listener, in case undeleted
				_submittingPosts.remove(post);
				setState(() {});
				return;
			}
			if (!_submittingPosts.contains(post) && post != _postingPost) {
				// Undelete
				_submittingPosts.add(post);
				setState(() {});
			}
			if (state is QueueStateDone<PostReceipt>) {
				post.removeListener(listener);
				_submittingPosts.remove(post);
				widget.onReplyPosted(state.result);
				mediumHapticFeedback();
				if (post == _postingPost) {
					_reset();
					_rootFocusNode.unfocus();
					// Hide reply box
					setState(() {
						_postingPost = null;
					});
					hideReplyBox();
				}
			}
			else if (state is QueueStateFailed<PostReceipt> && post == _postingPost) {
				post.removeListener(listener);
				post.delete();
				setState(() {
					_postingPost = null;
				});
			}
		}
		post.addListener(listener);
		listener();
	}

	void _pickEmote() async {
		final emotes = context.read<ImageboardSite>().getEmotes();
		final pickedEmote = await Navigator.of(context).push<ImageboardEmote>(TransparentRoute(
			builder: (context) => OverscrollModalPage(
				child: Container(
					width: MediaQuery.sizeOf(context).width,
					color: ChanceTheme.backgroundColorOf(context),
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
			)
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
					color: ChanceTheme.backgroundColorOf(context),
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
									return AdaptiveIconButton(
										onPressed: () {
											Navigator.of(context).pop(flag);
										},
										icon: Row(
											children: [
												if (flag.code == '0') const SizedBox(width: 16)
												else ExtendedImage.network(
													flag.imageUrl,
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
			)
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
		final settings = context.watch<Settings>();
		final fakeAttachment = Attachment(
			ext: '.$attachmentExt',
			url: '',
			type: attachmentExt == 'webm' ?
				AttachmentType.webm :
				(attachmentExt == 'mp4' ? AttachmentType.mp4 : AttachmentType.image),
			md5: _attachmentScan?.$3.toString() ?? '',
			id: '${identityHashCode(attachment)}',
			filename: attachment?.uri.pathSegments.last ?? '',
			thumbnailUrl: '',
			board: 'reply-form',
			width: _attachmentScan?.$1.width,
			height: _attachmentScan?.$1.height,
			sizeInBytes: _attachmentScan?.$1.sizeInBytes,
			threadId: null
		);
		return Container(
			decoration: BoxDecoration(
				border: Border(top: BorderSide(color: ChanceTheme.primaryColorWithBrightness20Of(context))),
				color: ChanceTheme.backgroundColorOf(context)
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
											child: SizedBox(
												height: settings.materialStyle ? 55 : 35,
												child: AdaptiveTextField(
													enabled: !settings.randomizeFilenames && !loading,
													controller: _filenameController,
													placeholder: (settings.randomizeFilenames || attachment == null) ? '' : attachment!.uri.pathSegments.last.replaceAll(RegExp('.$attachmentExt\$'), ''),
													maxLines: 1,
													textCapitalization: TextCapitalization.none,
													autocorrect: false,
													enableIMEPersonalizedLearning: settings.enableIMEPersonalizedLearning,
													smartDashesType: SmartDashesType.disabled,
													smartQuotesType: SmartQuotesType.disabled,
													keyboardAppearance: ChanceTheme.brightnessOf(context)
												)
											)
										),
										const SizedBox(width: 8),
										Text('.$attachmentExt'),
										const SizedBox(width: 8),
										FittedBox(
											child: AdaptiveFilledButton(
												padding: const EdgeInsets.all(4),
												child: Text('MD5:\n${_attachmentScan?.$3.toString().substring(0, 6).toUpperCase()}', textAlign: TextAlign.center),
												onPressed: () async {
													final old = attachment!;
													setState(() {
														attachment = null;
														_attachmentScan = null;
														_showAttachmentOptions = false;
													});
													await setAttachment(old, forceRandomizeChecksum: true);
													setState(() {
														_showAttachmentOptions = true;
													});
												}
											)
										)
									]
								),
								const SizedBox(height: 4),
								Flexible(
									child: Row(
										crossAxisAlignment: CrossAxisAlignment.center,
										children: [
											AdaptiveIconButton(
												padding: EdgeInsets.zero,
												minSize: 0,
												icon: Row(
													mainAxisSize: MainAxisSize.min,
													children: [
														Icon(settings.randomizeFilenames ? CupertinoIcons.checkmark_square : CupertinoIcons.square),
														const Text('Random')
													]
												),
												onPressed: () {
													setState(() {
														Settings.randomizeFilenamesSetting.value = !settings.randomizeFilenames;
													});
												}
											),
											const SizedBox(width: 8),
											if (board.spoilers == true) Padding(
												padding: const EdgeInsets.only(right: 8),
												child: AdaptiveIconButton(
													padding: EdgeInsets.zero,
													minSize: 0,
													icon: Row(
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
											),
											const SizedBox(width: 4),
											Expanded(
												child: LayoutBuilder(
													builder: (context, constraints) {
														final metadata = [
															if (attachmentExt == 'mp4' || attachmentExt == 'webm') ...[
																if (_attachmentScan?.$1.codec != null) _attachmentScan!.$1.codec!.toUpperCase(),
																if (_attachmentScan?.$1.hasAudio == true) 'with audio'
																else 'no audio',
																if (_attachmentScan?.$1.duration != null) formatDuration(_attachmentScan!.$1.duration!),
																if (_attachmentScan?.$1.bitrate != null) '${(_attachmentScan!.$1.bitrate! / (1024 * 1024)).toStringAsFixed(1)} Mbps',
															],
															if (_attachmentScan?.$1.width != null && _attachmentScan?.$1.height != null) '${_attachmentScan?.$1.width}x${_attachmentScan?.$1.height}',
															if (_attachmentScan?.$2.size != null) formatFilesize(_attachmentScan?.$2.size ?? 0)
														].join(', ');
														if (constraints.maxWidth * constraints.maxHeight < (70 * 70)) {
															return Align(
																alignment: Alignment.centerRight,
																child: AdaptiveIconButton(
																	padding: EdgeInsets.zero,
																	minSize: 30,
																	icon: const Icon(CupertinoIcons.info_circle),
																	onPressed: () => alert(context, 'File metadata', metadata)
																)
															);
														}
														return AutoSizeText(
															metadata,
															style: const TextStyle(color: Colors.grey),
															maxLines: null,
															minFontSize: 10,
															wrapWords: false,
															textAlign: TextAlign.right
														);
													}
												)
											),
											const SizedBox(width: 4),
											AdaptiveIconButton(
												padding: EdgeInsets.zero,
												minSize: 30,
												icon: const Icon(CupertinoIcons.xmark),
												onPressed: () {
													setState(() {
														attachment = null;
														_attachmentScan = null;
														_showAttachmentOptions = false;
														_filenameController.clear();
													});
													_didUpdateDraft();
												}
											)
										]
									)
								)
							]
						)
					),
					const SizedBox(width: 8),
					(attachment != null) ? ConstrainedBox(
						constraints: BoxConstraints(
							maxWidth: settings.thumbnailSize
						),
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
									allowChrome: true,
									allowContextMenu: true,
									allowScroll: false,
									heroOtherEndIsBoxFitCover: false
								);
							}
						)
					) : const SizedBox.shrink()
				]
			)
		);
	}

	Widget _buildOptions(BuildContext context) {
		final settings = context.watch<Settings>();
		final site = context.watch<ImageboardSite>();
		final fields = site.loginSystem?.getSavedLoginFields();
		return Container(
			decoration: BoxDecoration(
				border: Border(top: BorderSide(color: ChanceTheme.primaryColorWithBrightness20Of(context))),
				color: ChanceTheme.backgroundColorOf(context)
			),
			padding: const EdgeInsets.only(top: 9, left: 8, right: 8, bottom: 10),
			child: Row(
				children: [
					Flexible(
						child: AdaptiveTextField(
							enabled: !loading,
							maxLines: 1,
							placeholder: 'Name',
							keyboardAppearance: ChanceTheme.brightnessOf(context),
							controller: _nameFieldController,
							enableIMEPersonalizedLearning: settings.enableIMEPersonalizedLearning,
							smartDashesType: SmartDashesType.disabled,
							smartQuotesType: SmartQuotesType.disabled,
							suffix: AdaptiveIconButton(
								padding: const EdgeInsets.only(right: 8),
								minSize: 0,
								onPressed: _previouslyUsedNames.isEmpty ? null : () async {
									final choice = await showAdaptiveModalPopup<String>(
										context: context,
										builder: (context) => AdaptiveActionSheet(
											title: const Text('Previously-used names'),
											actions: _previouslyUsedNames.map((name) => AdaptiveActionSheetAction(
												onPressed: () => Navigator.pop(context, name),
												isDefaultAction: _nameFieldController.text == name,
												child: Text(name)
											)).toList(),
											cancelButton: AdaptiveActionSheetAction(
												child: const Text('Cancel'),
												onPressed: () => Navigator.of(context).pop()
											)
										)
									);
									if (choice != null) {
										_nameFieldController.text = choice;
									}
								},
								icon: const Icon(CupertinoIcons.list_bullet, size: 20)
							),
							onChanged: (s) {
								context.read<Persistence>().browserState.postingNames[widget.board] = s;
								context.read<Persistence>().didUpdateBrowserState();
							}
						)
					),
					const SizedBox(width: 8),
					Flexible(
						child: AdaptiveTextField(
							enabled: !loading,
							maxLines: 1,
							placeholder: 'Options',
							enableIMEPersonalizedLearning: settings.enableIMEPersonalizedLearning,
							smartDashesType: SmartDashesType.disabled,
							smartQuotesType: SmartQuotesType.disabled,
							keyboardAppearance: ChanceTheme.brightnessOf(context),
							controller: _optionsFieldController,
							suffix: AdaptiveIconButton(
								padding: const EdgeInsets.only(right: 8),
								minSize: 0,
								onPressed: _previouslyUsedOptions.isEmpty ? null : () async {
									final choice = await showAdaptiveModalPopup<String>(
										context: context,
										builder: (context) => AdaptiveActionSheet(
											title: const Text('Previously-used options'),
											actions: _previouslyUsedOptions.map((name) => AdaptiveActionSheetAction(
												onPressed: () => Navigator.pop(context, name),
												isDefaultAction: _nameFieldController.text == name,
												child: Text(name)
											)).toList(),
											cancelButton: AdaptiveActionSheetAction(
												child: const Text('Cancel'),
												onPressed: () => Navigator.of(context).pop()
											)
										)
									);
									if (choice != null) {
										_optionsFieldController.text = choice;
									}
								},
								icon: const Icon(CupertinoIcons.list_bullet, size: 20)
							),
							onChanged: (s) {
								_didUpdateDraft();
							}
						)
					),
					if (fields != null) Padding(
						padding: const EdgeInsets.only(left: 8),
						child: AdaptiveIconButton(
							onPressed: () {
								setState(() {
									_disableLoginSystem = !_disableLoginSystem;
								});
							},
							icon: Row(
								mainAxisSize: MainAxisSize.min,
								children: [
									SizedBox(
										width: 16,
										height: 16,
										child: ExtendedImage.network(
											site.passIconUrl.toString(),
											cache: true,
											enableLoadState: false,
											fit: BoxFit.contain
										)
									),
									const SizedBox(width: 2),
									Icon(_disableLoginSystem ? CupertinoIcons.square : CupertinoIcons.checkmark_square)
								]
							)
						)
					)
				]
			)
		);
	}

	Widget _buildTextField(BuildContext context) {
		final board = context.read<Persistence>().getBoard(widget.board);
		final site = context.watch<ImageboardSite>();
		final subjectCharacterLimit = site.subjectCharacterLimit;
		final snippets = site.getBoardSnippets(widget.board);
		const infiniteLimit = 1 << 50;
		final settings = context.watch<Settings>();
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
							AdaptiveTextField(
								enabled: !loading,
								enableIMEPersonalizedLearning: settings.enableIMEPersonalizedLearning,
								smartDashesType: SmartDashesType.disabled,
								smartQuotesType: SmartQuotesType.disabled,
								controller: _subjectFieldController,
								spellCheckConfiguration: !settings.enableSpellCheck || (isOnMac && isDevelopmentBuild) ? null : const SpellCheckConfiguration(),
								maxLines: 1,
								placeholder: 'Subject',
								textCapitalization: TextCapitalization.sentences,
								keyboardAppearance: ChanceTheme.brightnessOf(context)
							),
							const SizedBox(height: 8),
						],
						if (subjectCharacterLimit != null || board.maxCommentCharacters != null) AnimatedBuilder(
							animation: Listenable.merge([
								_textFieldController,
								_subjectFieldController
							]),
							builder: (context, _) {
								final greyColor = ChanceTheme.primaryColorWithBrightness50Of(context);
								final subjectLimit = subjectCharacterLimit ?? infiniteLimit;
								final subjectLength = _subjectFieldController.text.length;
								final showSubjectLimit = subjectLength > (subjectLimit * 0.5);
								final subjectLimitColor = subjectLength > subjectLimit ? Colors.red : greyColor;
								final textLimit = board.maxCommentCharacters ?? infiniteLimit;
								final textLength = _textFieldController.text.length;
								final showTextLimit = textLength > (textLimit * 0.5);
								final textLimitColor = textLength > textLimit ? Colors.red : greyColor;
								return IgnorePointer(
									child: AnimatedSize(
										alignment: Alignment.topCenter,
										duration: const Duration(milliseconds: 250),
										curve: Curves.ease,
										child: (showSubjectLimit || showTextLimit) ? Padding(
											padding: const EdgeInsets.only(bottom: 8),
											child: Row(
												mainAxisAlignment: MainAxisAlignment.end,
												children: [
													if (showSubjectLimit) ...[
														Icon(CupertinoIcons.arrow_up, size: 16, color: subjectLimitColor),
														const SizedBox(width: 4),
														Text(
															'$subjectLength / $subjectLimit',
															style: TextStyle(
																color: subjectLimitColor,
																fontFeatures: const [FontFeature.tabularFigures()]
															)
														),
													],
													if (showTextLimit) ...[
														const SizedBox(width: 4),
														Icon(CupertinoIcons.arrow_down, size: 16, color: textLimitColor),
														const SizedBox(width: 4),
														Text(
															'$textLength / $textLimit',
															style: TextStyle(
																color: textLimitColor,
																fontFeatures: const [FontFeature.tabularFigures()]
															)
														)
													]
												]
											)
										) : const SizedBox(width: double.infinity)
									)
								);
							}
						),
						Flexible(
							child: Stack(
								alignment: Alignment.center,
								children: [
									AdaptiveTextField(
										enabled: !loading,
										enableIMEPersonalizedLearning: settings.enableIMEPersonalizedLearning,
										smartDashesType: SmartDashesType.disabled,
										smartQuotesType: SmartQuotesType.disabled,
										controller: _textFieldController,
										autofocus: widget.fullyExpanded,
										contentInsertionConfiguration: ContentInsertionConfiguration(
											onContentInserted: (content) async {
												final data = content.data;
												if (data == null) {
													return;
												}
												if (data.isEmpty) {
													return;
												}
												String filename = Uri.parse(content.uri).pathSegments.last;
												if (!filename.contains('.')) {
													filename += '.${content.mimeType.split('/').last}';
												}
												final f = File('${Persistence.shareCacheDirectory.path}/${DateTime.now().millisecondsSinceEpoch}/$filename');
												await f.create(recursive: true);
												await f.writeAsBytes(data, flush: true);
												setAttachment(f);
											}
										),
										spellCheckConfiguration: !settings.enableSpellCheck || (isOnMac && isDevelopmentBuild) ? null : const SpellCheckConfiguration(),
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
												),
												if (!editableTextState.textEditingValue.selection.isCollapsed) ...snippets.map((snippet) {
													return ContextMenuButtonItem(
														onPressed: () {
															final selectedText = editableTextState.textEditingValue.selection.textInside(editableTextState.textEditingValue.text);
															editableTextState.userUpdateTextEditingValue(
																editableTextState.textEditingValue.replaced(
																	editableTextState.textEditingValue.selection,
																	snippet.wrap(selectedText)
																),
																SelectionChangedCause.toolbar
															);
														},
														label: snippet.name
													);
												})
											]
										),
										placeholder: 'Comment',
										maxLines: null,
										minLines: 100,
										focusNode: _textFocusNode,
										textCapitalization: TextCapitalization.sentences,
										keyboardAppearance: ChanceTheme.brightnessOf(context),
									),
									if (loading) AdaptiveButton(
										onPressed: _postInBackground,
										child: const Row(
											mainAxisSize: MainAxisSize.min,
											children: [
												Icon(CupertinoIcons.tray_arrow_up),
												SizedBox(width: 8),
												Text('Post in background...')
											]
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
		void expandAttachmentOptions() {
			setState(() {
				_showAttachmentOptions = !_showAttachmentOptions;
			});
		}
		void expandOptions() {
			_checkPreviousPostReceipts();
			setState(() {
				_showOptions = !_showOptions;
			});
		}
		final imageboard = context.read<Imageboard>();
		final defaultTextStyle = DefaultTextStyle.of(context).style;
		final settings = context.watch<Settings>();
		return Row(
			mainAxisAlignment: MainAxisAlignment.end,
			children: [
				for (final snippet in context.read<ImageboardSite>().getBoardSnippets(widget.board)) AdaptiveIconButton(
					onPressed: () async {
						final initialSelection = _textFieldController.selection;
						// This only works because all the ImageboardSnippets are const
						final controller = _snippetControllers.putIfAbsent(snippet, () => TextEditingController());
						if (!initialSelection.isCollapsed) {
							controller.text = initialSelection.textInside(_textFieldController.text);
						}
						final content = await showAdaptiveDialog<String>(
							context: context,
							barrierDismissible: true,
							builder: (context) => AdaptiveAlertDialog(
								title: Text('${snippet.name} block'),
								content: Padding(
									padding: const EdgeInsets.only(top: 16),
									child: AdaptiveTextField(
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
									AdaptiveDialogAction(
										isDefaultAction: true,
										onPressed: () => Navigator.pop(context, controller.text),
										child: const Text('Insert')
									),
									if (snippet.previewBuilder != null) AdaptiveDialogAction(
										child: const Text('Preview'),
										onPressed: () {
											showAdaptiveDialog<bool>(
												context: context,
												barrierDismissible: true,
												builder: (context) => AdaptiveAlertDialog(
													title: Text('${snippet.name} preview'),
													content: ChangeNotifierProvider<PostSpanZoneData>(
														create: (context) => PostSpanRootZoneData(
															imageboard: imageboard,
															thread: Thread(posts_: [], attachments: [], replyCount: 0, imageCount: 0, id: 0, board: '', title: '', isSticky: false, time: DateTime.now()),
															semanticRootIds: [-14],
															style: PostSpanZoneStyle.linear
														),
														builder: (context, _) => DefaultTextStyle(
															style: defaultTextStyle,
															child: Text.rich(
																snippet.previewBuilder!(controller.text).build(context, context.watch<PostSpanZoneData>(), context.watch<Settings>(), context.watch<SavedTheme>(), const PostSpanRenderOptions())
															)
														)
													),
													actions: [
														AdaptiveDialogAction(
															isDefaultAction: true,
															child: const Text('Close'),
															onPressed: () => Navigator.pop(context)
														)
													]
												)
											);
										}
									),
									AdaptiveDialogAction(
										child: const Text('Cancel'),
										onPressed: () => Navigator.pop(context)
									)
								]
							)
						);
						if (content != null) {
							_insertText(snippet.wrap(content), addNewlineIfAtEnd: false, initialSelection: initialSelection);
							controller.clear();
						}
					},
					icon: Icon(snippet.icon)
				),
				if (_flags.isNotEmpty) Center(
					child: AdaptiveIconButton(
						onPressed: _pickFlag,
						icon: IgnorePointer(
							child: flag != null ? ExtendedImage.network(
								flag!.imageUrl,
								cache: true,
							) : const Icon(CupertinoIcons.flag)
						)
					)
				),
				if (context.read<ImageboardSite>().getEmotes().isNotEmpty) Center(
					child: AdaptiveIconButton(
						onPressed: _pickEmote,
						icon: const Icon(CupertinoIcons.smiley)
					)
				),
				Expanded(
					child: Align(
						alignment: Alignment.centerRight,
						child: AnimatedSize(
							alignment: Alignment.centerLeft,
							duration: const Duration(milliseconds: 250),
							curve: Curves.ease,
							child: attachment != null ? AdaptiveIconButton(
								padding: const EdgeInsets.only(left: 8, right: 8),
								onPressed: expandAttachmentOptions,
								icon: Row(
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
										child: AdaptiveButton(
											padding: EdgeInsets.zero,
											onPressed: _attachmentProgress?.$2 == null ? null : () async {
												final confirmed = await confirm(context, 'Stop conversion?', actionName: 'Stop');
												if (confirmed) {
													_attachmentProgress?.$2?.cancel();
													_attachmentProgress = null;
													setState(() {});
												}
											},
											child: ClipRRect(
												borderRadius: BorderRadius.circular(4),
												child: ValueListenableBuilder<double?>(
													valueListenable: _attachmentProgress!.$2?.progress ?? const _StoppedValueListenable(null),
													builder: (context, value, _) => LinearProgressIndicator(
														value: value,
														minHeight: 20,
														valueColor: AlwaysStoppedAnimation(ChanceTheme.primaryColorOf(context)),
														backgroundColor: ChanceTheme.primaryColorOf(context).withOpacity(0.2)
													)
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
										for (final file in receivedFilePaths.reversed) GestureDetector(
											onLongPress: () async {
												if (await confirm(context, 'Remove received file?')) {
													receivedFilePaths.remove(file);
													setState(() {});
												}
											},
											child: AdaptiveIconButton(
												onPressed: () => setAttachment(File(file)),
												icon: ClipRRect(
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
											)
										),
										for (final picker in getAttachmentSources(context: context, includeClipboard: false)) AdaptiveIconButton(
											onPressed: () async {
												FocusNode? focusToRestore;
												if (_lastNearbyFocus?.$1.isAfter(DateTime.now().subtract(const Duration(milliseconds: 300))) ?? false) {
													focusToRestore = _lastNearbyFocus?.$2;
												}
												_attachmentProgress = ('Picking', null);
												setState(() {});
												final path = await picker.pick();
												if (path != null) {
													await setAttachment(File(path));
												}
												else if (mounted) {
													_attachmentProgress = null;
													setState(() {});
												}
												focusToRestore?.requestFocus();
											},
											icon: Transform.scale(
												scale: picker.iconSizeMultiplier,
												child: Icon(picker.icon)
											)
										)
									]
								)
							)
						)
					)
				),
				AdaptiveIconButton(
					onPressed: expandOptions,
					icon: const Icon(CupertinoIcons.gear)
				),
				GestureDetector(
					onLongPress: () {
						// Save as draft
						final persistence = context.read<Persistence>();
						final post = _makeDraft();
						post.name = _nameFieldController.text;
						persistence.browserState.outbox.add(post);
						runWhenIdle(const Duration(milliseconds: 500), persistence.didUpdateBrowserState);
						final entry = Outbox.instance.submitPost(imageboard.key, post, const QueueStateIdle());
						_submittingPosts.add(entry);
						_listenToReplyPosting(entry);
						draft = null; // Clear
						showToast(
							context: context,
							icon: CupertinoIcons.tray_arrow_up,
							message: 'Saved draft'
						);
						setState(() {});
					},
					child: AdaptiveIconButton(
						onPressed: _attachmentProgress != null ? null : (loading ? _cancel : _submit),
						icon: Icon(loading ? CupertinoIcons.xmark : CupertinoIcons.paperplane)
					)
				)
			]
		);
	}

	bool _isNonTrivial(DraftPost draft) {
		return
			// Non-default name
			draft.name != _nameFieldController.text ||
			// Non-default options
			draft.options != _optionsFieldController.text ||
			(draft.file?.isNotEmpty ?? false) ||
			draft.flag != null ||
			(draft.overrideFilenameWithoutExtension?.isNotEmpty ?? false) ||
			(draft.subject?.isNotEmpty ?? false) ||
			draft.text.isNotEmpty;
	}

	void _onDraftTap(QueuedPost entry, bool deleteOriginal) {
		if (!entry.state.isIdle) {
			entry.cancel();
			return;
		}
		// Save current contents
		final old = _makeDraft();
		old.name = _nameFieldController.text;
		// Needed to make equality work
		old.useLoginSystem = entry.useLoginSystem;
		// Apply the new draft
		draft = entry.post;
		if (_nameFieldController.text.isNotEmpty || _optionsFieldController.text.isNotEmpty) {
			setState(() {_showOptions = true;});
		}
		// Delete that draft from the outbox
		if (deleteOriginal) {
			entry.delete();
		}
		// Add the old content as a draft to the outbox, if non-trivial
		if (_isNonTrivial(old) && old != entry.post) {
			Outbox.instance.submitPost(context.read<Imageboard>().key, old, const QueueStateIdle());
		}
		setState(() {});
	}

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<Settings>();
		return Focus(
			focusNode: _rootFocusNode,
			child: Column(
				mainAxisSize: MainAxisSize.min,
				children: [
					Align(
						alignment: Alignment.centerRight,
						child: AnimatedSize(
							duration: const Duration(milliseconds: 300),
							child: AnimatedBuilder(
								animation: Outbox.instance,
								builder: (context, _) {
									final queue = Outbox.instance.queues[(context.watch<Imageboard>().key, widget.board, widget.threadId == null ? ImageboardAction.postThread : ImageboardAction.postReply)] as OutboxQueue<PostReceipt>?;
									Widget build(BuildContext context) {
										final ourCount = _submittingPosts.length + (_postingPost != null ? 1 : 0);
										final activeCount = Outbox.instance.activeCount;
										final othersCount = queue?.list.where((e) => !e.state.isIdle && (e as QueuedPost).post.thread != thread).length ?? 0;
										final DateTime time;
										final now = DateTime.now();
										if (queue != null && queue.captchaAllowedTime.isAfter(now)) {
											time = queue.captchaAllowedTime;
										}
										else if (queue != null && queue.allowedTime.isAfter(now)) {
											time = queue.allowedTime;
										}
										else {
											time = now;
										}
										final shouldShow =
											// There are outbox things in other threads
											(activeCount > ourCount) ||
											// There is a cooldown and nothing else is showing it
											(time != now && _submittingPosts.isEmpty);
										if (!(show && shouldShow)) {
											return const SizedBox(width: double.infinity);
										}
										return Container(
											width: double.infinity,
											decoration: BoxDecoration(
												border: Border(
													top: BorderSide(color: ChanceTheme.primaryColorWithBrightness20Of(context))
												),
												color: ChanceTheme.barColorOf(context)
											),
											child: AdaptiveButton(
												onPressed: () async {
													final selected = await showOutboxModalForThread(
														context: context,
														imageboardKey: context.read<Imageboard?>()?.key,
														board: widget.board,
														threadId: widget.threadId,
														canPopWithDraft: true
													);
													if (selected != null) {
														_onDraftTap(selected.post, selected.deleteOriginal);
													}
												},
												child: Row(
													mainAxisSize: MainAxisSize.min,
													children: [
														if (time != now) TimedRebuilder<String?>(
															interval: const Duration(seconds: 1),
															function: () {
																final delta = time.difference(DateTime.now());
																if (delta.isNegative) {
																	return null;
																}
																return formatDuration(delta);
															},
															builder: (context, str) {
																if (str == null) {
																	return const SizedBox.shrink();
																}
																return Row(
																	children: [
																		const Icon(CupertinoIcons.clock, size: 18),
																		const SizedBox(width: 8),
																		Text(str, style: const TextStyle(
																			fontFeatures: [FontFeature.tabularFigures()]
																		))
																	]
																);
															}
														),
														if (time != now && activeCount > ourCount) const SizedBox(width: 16),
														if (activeCount > ourCount) ...[
															const Icon(CupertinoIcons.tray_arrow_up, size: 18),
															const SizedBox(width: 8),
															Text(
																[
																	describeCount(activeCount - ourCount, 'reply in outbox', plural: 'replies in outbox'),
																	if (othersCount > 0) '($othersCount queued on ${context.watch<ImageboardSite>().formatBoardName(widget.board)})'
																].join(' ')
															)
														]
													]
												)
											)
										);
									}
									if (queue == null) {
										return build(context);
									}
									return AnimatedBuilder(
										animation: queue,
										builder: (context, _) => build(context)
									);
								}
							)
						)
					),
					AnimatedSize(
						duration: const Duration(milliseconds: 300),
						alignment: Alignment.topCenter,
						child: show ? ConstrainedBox(
							constraints: const BoxConstraints(
								maxHeight: 200
							),
							child: TransformedMediaQuery(
								transformation: (context, mq) => mq.copyWith(
									padding: EdgeInsets.zero,
									viewPadding: EdgeInsets.zero,
									viewInsets: EdgeInsets.zero
								),
								child: MaybeScrollbar(
									child: ListView.builder(
										primary: false,
										shrinkWrap: true,
										itemCount: _submittingPosts.length,
										itemBuilder: (context, i) {
											final p = _submittingPosts[i];
											return QueueEntryWidget(
												entry: p,
												replyBoxMode: true,
												onMove: () => _onDraftTap(p, true),
												onCopy: () => _onDraftTap(p, false),
											);
										}
									)
								)
							)
						) : const SizedBox(width: double.infinity)
					),
					Expander(
						expanded: showAttachmentOptions && show,
						bottomSafe: true,
						height: settings.materialStyle ? 125 : 110,
						child: Focus(
							descendantsAreFocusable: showAttachmentOptions && show,
							child: _buildAttachmentOptions(context)
						)
					),
					Expander(
						expanded: showOptions && show,
						bottomSafe: true,
						height: settings.materialStyle ? 75 : 55,
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
								Flexible(child: AdaptiveFilledButton(
									padding: const EdgeInsets.all(4),
									child: const Text('Use suggested image', textAlign: TextAlign.center),
									onPressed: () async {
										final site = context.read<ImageboardSite>();
										try {
											final data = await site.client.get(_proposedAttachmentUrl!, options: dio.Options(responseType: dio.ResponseType.bytes));
											final newFile = File('${Persistence.shareCacheDirectory.path}/${DateTime.now().millisecondsSinceEpoch}_${_proposedAttachmentUrl!.split('/').last.split('?').first}');
											await newFile.writeAsBytes(data.data);
											setAttachment(newFile);
											_filenameController.text = _proposedAttachmentUrl!.split('/').last.split('.').reversed.skip(1).toList().reversed.join('.');
											_proposedAttachmentUrl = null;
											setState(() {});
										}
										catch (e, st) {
											print(e);
											print(st);
											if (context.mounted) {
												alertError(context, e.toStringDio());
											}
										}
									}
								)),
								AdaptiveIconButton(
									icon: const Icon(CupertinoIcons.xmark),
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
						height: ((widget.threadId == null) ? 150 + (settings.materialStyle ? 50 : 0) : 100 + (settings.materialStyle ? 25 : 0)) + settings.replyBoxHeightOffset,
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
											border: Border(top: BorderSide(color: ChanceTheme.primaryColorWithBrightness20Of(context)))
										),
										height: 40,
										child: _buildButtons(context),
									)
								),
								Flexible(
									child: Container(
										color: ChanceTheme.backgroundColorOf(context),
										child: Stack(
											children: [
												_buildTextField(context),
												if (loading) Positioned.fill(
													child: Container(
														alignment: Alignment.bottomCenter,
														child: LinearProgressIndicator(
															valueColor: AlwaysStoppedAnimation(ChanceTheme.primaryColorOf(context)),
															backgroundColor: ChanceTheme.primaryColorOf(context).withOpacity(0.7)
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
		for (final controller in _snippetControllers.values) {
			controller.dispose();
		}
		_focusTimer.cancel();
	}
}

class ReplyBoxTextEditingController extends TextEditingController {
	ReplyBoxTextEditingController({
		super.text
	});

	@override
	TextSpan buildTextSpan({required BuildContext context, TextStyle? style , required bool withComposing}) {
		try {
			assert(!value.composing.isValid || !withComposing || value.isComposingRangeValid);
			final bool composingRegionOutOfRange = !value.isComposingRangeValid || !withComposing;

			return buildHighlightedCommentTextSpan(
				text: text,
				style: style,
				zone: context.read<PostSpanZoneData?>(),
				composing: composingRegionOutOfRange ? null : value.composing
			);
		}
		catch (e, st) {
			Future.error(e, st); // crashlytics
			return super.buildTextSpan(
				context: context,
				style: style,
				withComposing: withComposing
			);
		}
	}
}
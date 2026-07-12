import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:chan/main.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/cookie_browser.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/pages/picker.dart';
import 'package:chan/services/apple.dart';
import 'package:chan/services/clipboard_image.dart';
import 'package:chan/services/embed.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/linkifier.dart';
import 'package:chan/services/md5.dart';
import 'package:chan/services/media.dart';
import 'package:chan/services/outbox.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/pick_attachment.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/text_highlighting.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/attachment_viewer.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/network_image.dart';
import 'package:chan/widgets/notifying_icon.dart';
import 'package:chan/widgets/outbox.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/timed_rebuilder.dart';
import 'package:chan/widgets/util.dart';
import 'package:chan/widgets/media_thumbnail.dart';
import 'package:chan/widgets/widget_decoration.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart' as dio;
import 'package:extended_image/extended_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';
import 'package:linkify/linkify.dart';
import 'package:mutex/mutex.dart';
import 'package:provider/provider.dart';
import 'package:flutter_heic_to_jpg/flutter_heic_to_jpg.dart';

/// Some pickers (iOS) put the file in a Chance-owned path that wouldn't be
/// automatically cleaned up. Move it out of there.
Future<File> _moveFileOutOfDocumentsDir(File file) async {
	final parentResolved = await file.parent.resolveSymbolicLinks();
	final docsResolved = await Persistence.documentsDirectory.resolveSymbolicLinks();
	if (parentResolved == docsResolved) {
		// The file is an immediate child of docs dir. This is because of bad picker behaviour
		// Move it to temp path
		final parent = Persistence.temporaryDirectory.dir('inboxcache/${DateTime.now().millisecondsSinceEpoch}');
		await parent.create(recursive: true);
		final destPath = parent.child(file.basename);
		return await file.rename(destPath);
	}
	return file;
}

typedef PickedAttachment = ({
	File file,
	MediaScan scan,
	FileStat stat,
	String md5
});

class ReplyBoxZone {
	final void Function(int threadId, int id) onTapPostId;

	final void Function(String text, {required PostIdentifier? backlink}) onQuoteText;

	const ReplyBoxZone({
		required this.onTapPostId,
		required this.onQuoteText
	});
}

const _kNonWebmVideoExts = {'mp4', 'mov', 'm4v', 'mkv', 'mpeg', 'avi', '3gp', 'm2ts'};

class _ReplyBoxFile {
	PickedAttachment current;
	PickedAttachment original;
	final TextEditingController filenameController;
	String? get ext => current.file.extensionWithoutDot?.toLowerCase();
	bool overrideRandomizeFilenames = false;
	bool spoiler = false;

	_ReplyBoxFile({
		required this.current,
		required this.original,
		String? initialFilename,
		this.overrideRandomizeFilenames = false,
		this.spoiler = false
	}) : filenameController = TextEditingController(text: initialFilename);

	void dispose() {
		filenameController.dispose();
	}
}

class ReplyBox extends StatefulWidget {
	final BoardKey board;
	final int? threadId;
	final void Function(String board, PostReceipt receipt) onReplyPosted;
	final DraftPost? initialDraft;
	final ValueChanged<DraftPost?> onDraftChanged;
	final VoidCallback? onVisibilityChanged;
	final bool isArchived;
	final bool fullyExpanded;
	final ValueChanged<ReplyBoxState>? onInitState;

	const ReplyBox({
		required this.board,
		this.threadId,
		required this.onReplyPosted,
		this.initialDraft,
		required this.onDraftChanged,
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
	final _textFieldKey = GlobalKey<AdaptiveTextFieldState>(debugLabel: 'ReplyBoxState._textFieldKey');
	late final TextEditingController _textFieldController;
	late final TextEditingController _nameFieldController;
	late final TextEditingController _subjectFieldController;
	late final TextEditingController _optionsFieldController;
	late final FocusNode _textFocusNode;
	late final ValueNotifier<QueuedPost?> postingPost;
	bool get loading => postingPost.value != null;
	final List<_ReplyBoxFile> _attachments = [];
	bool _showOptions = false;
	bool get showOptions => _showOptions && !loading;
	bool _showAttachmentOptions = false;
	bool get showAttachmentOptions => _showAttachmentOptions && !loading && _attachments.isNotEmpty;
	bool _show = false;
	bool get show => widget.fullyExpanded || (_show && !_willHideOnPanEnd);
	String? _lastFoundUrl;
	({String text, String imageUrl, int size})? _proposedAttachmentUrl;
	List<ImageboardBoardFlag> _flags = [];
	ImageboardBoardFlag? flag;
	double _panStartDy = 0;
	double _replyBoxHeightOffsetAtPanStart = 0;
	bool _willHideOnPanEnd = false;
	late final FocusNode _rootFocusNode;
	(String, MediaConversion?)? _attachmentProgress;
	static List<String> _previouslyUsedNames = [];
	static List<String> _previouslyUsedOptions = [];
	bool _disableLoginSystem = false;
	bool get hasLoginSystem => context.read<ImageboardSite>().loginSystem?.getSavedLoginFields() != null;
	final Map<ImageboardSnippet, TextEditingController> _snippetControllers = {};
	final List<QueuedPost> _submittingPosts = [];
	bool _showSubmittingPosts = false;
	ChanTabs? _chanTabs;
	final _makeAttachmentLock = Mutex();
	final _attachmentsLock = Mutex();
	int _neededPosts = 1;

	ThreadIdentifier? get thread => switch (widget.threadId) {
		int threadId => ThreadIdentifier(widget.board.s, threadId),
		null => null
	};

	bool _textIsEmpty = true;
	String get text => _textFieldController.text;
	set text(String newText) => _textFieldController.text = newText;

	String get options => _optionsFieldController.text;
	set options(String newOptions) => _optionsFieldController.text = newOptions;

	String get defaultName => context.read<Persistence?>()?.browserState.postingNames[widget.board] ?? '';
	ImageboardBoardFlag? get defaultFlag => context.read<Persistence?>()?.browserState.postingFlags[widget.board];
	
	Future<void> _setInitialAttachments(List<DraftPostFile> files)
		=> _attachmentsLock.protect(() async {
		// Maybe it changed while waiting for lock
		final newFiles = files.where((f) => !_attachments.any((a) => a.current.file.path == f.path));
		_attachments.removeWhere((a) {
			if (!files.any((f) => f.path == a.current.file.path)) {
				a.dispose();
				return true;
			}
			return false;
		});
		if (newFiles.isEmpty) {
			return;
		}
		for (final newFile in newFiles) {
			bool retry;
			do {
				retry = false;
				try {
					final file = File(newFile.path);
					if (!file.existsSync()) {
						showToast(
							context: context,
							icon: Icons.broken_image,
							message: 'Previously-selected file is no longer accessible'
						);
						continue;
					}
					final attachment = await _makeAttachment(
						null,
						file,
						filenameWithoutExtension: newFile.overrideFilenameWithoutExtension,
						overrideRandomizeFilenames: newFile.overrideRandomizeFilenames,
						spoiler: newFile.spoiler,
						checkForDuplicateFile: false
					);
					if (!mounted || attachment == null) {
						return;
					}
					attachment.filenameController.addListener(() {
						_onFilenameChanged(attachment);
					});
					_attachments.add(attachment);
					setState(() {});
				}
				catch (e, st) {
					if (mounted) {
						await alertError(context, e, st, actions: {
							'Retry': () {
								retry = true;
							}
						});
						// Due to stupid alertError order, the action() will be after the pop
						await Future.delayed(const Duration(milliseconds: 50));
					}
				}
			} while (retry);
		}
		_didUpdateDraft();
		_updateNeededPosts();
	});

	Future<void> _addAttachment(File file) => _attachmentsLock.protect(() async {
		bool retry;
		do {
			retry = false;
			try {
				final attachment = await _makeAttachment(null, file, checkForDuplicateFile: true);
				if (!mounted || attachment == null) {
					return;
				}
				attachment.filenameController.addListener(() {
					_onFilenameChanged(attachment);
				});
				_attachments.add(attachment);
				setState(() {});
				_didUpdateDraft();
				_updateNeededPosts();
			}
			catch (e, st) {
				if (mounted) {
					await alertError(context, e, st, actions: {
						'Retry': () {
							retry = true;
						}
					});
					// Due to stupid alertError order, the action() will be after the pop
					await Future.delayed(const Duration(milliseconds: 50));
				}
			}
		} while (retry);
	});

	static final _quotelinkPattern = RegExp(r'>>(\d+)');
	set draft(DraftPost? draft) {
		if (draft != null) {
			String text = draft.text;
			if (ImageboardBoard.getKey(draft.board) != widget.board) {
				// Adjust quotelinks to match cross-board paste
				text = text.replaceAllMapped(_quotelinkPattern, (match) {
					return '>>>/${draft.board}/${match.group(1)}';
				});
			}
			_textFieldController.text = text;
			_optionsFieldController.text = draft.options ?? '';
			_nameFieldController.text = draft.name ?? defaultName;
			flag = draft.flag ?? defaultFlag;
			final subject = draft.subject;
			if (subject != null) {
				_subjectFieldController.text = subject;
			}
			_disableLoginSystem = switch (draft.useLoginSystem) {
				false => true,
				null || true => false
			};
			_setInitialAttachments(draft.files);
		}
		else {
			_textFieldController.clear();
			// Don't clear options
			_subjectFieldController.clear();
			_nameFieldController.text = defaultName;
			flag = defaultFlag;
			// Don't clear disableLoginSystem
			for (final a in _attachments) {
				a.dispose();
			}
			_attachments.clear();
			_neededPosts = 1;
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
				for (final post in thread?.posts_ ?? const Iterable<Post>.empty()) {
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

	void _onTextChanged() {
		if (text.isEmpty != _textIsEmpty) {
			setState(() {
				_textIsEmpty = text.isEmpty;
			});
		}
		_didUpdateDraft();
		runWhenIdle(const Duration(milliseconds: 50), _scanForUrl);
	}

	void _onFilenameChanged(_ReplyBoxFile file) {
		if (file.filenameController.selection.isValid && file.filenameController.text.isNotEmpty && Settings.instance.randomizeFilenames && !file.overrideRandomizeFilenames) {
			setState(() {
				file.overrideRandomizeFilenames = true;
			});
		}
		_didUpdateDraft();
	}

	Future<void> _scanForUrl() async {
		final original = _textFieldController.text;
		final rawUrl = linkify(text, linkifiers: const [LooseUrlLinkifier(fillInProtocol: true)], options: const LinkifyOptions(
			defaultToHttps: true,
			humanize: false
		)).tryMapOnce<String>((element) {
			if (element is UrlElement) {
				final path = Uri.parse(element.url).path;
				if (supportedFileExtensions.any(path.endsWith)) {
					return element.url;
				}
			}
			return null;
		});
		if (rawUrl != _lastFoundUrl && rawUrl != null) {
			try {
				_lastFoundUrl = rawUrl; // Avoid race
				final response = await context.read<ImageboardSite>().client.head(rawUrl);
				if (_textFieldController.text != original) {
					// Text changed
					return;
				}
				final byteCount = response.headers.value(dio.Headers.contentLengthHeader)?.tryParseInt ?? 0 /* chunked encoding? */;
				_proposedAttachmentUrl = (text: rawUrl, imageUrl: rawUrl, size: byteCount);
				if (mounted) setState(() {});
				return;
			}
			catch (e) {
				print('Url did not have a good response: ${e.toStringDio()}');
				_lastFoundUrl = null;
			}
		}
		else {
			final possibleEmbed = findEmbedUrl(_textFieldController.text);
			if (possibleEmbed != _lastFoundUrl && possibleEmbed != null) {
				final embedData = await loadEmbedData(possibleEmbed, highQuality: true);
				if (_textFieldController.text != original) {
					// Text changed
					return;
				}
				_lastFoundUrl = possibleEmbed;
				if (embedData?.thumbnailUrl != null) {
					_proposedAttachmentUrl = (text: possibleEmbed, imageUrl: embedData!.thumbnailUrl!, size: 0);
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
		board: widget.board.s,
		threadId: widget.threadId,
		subject: _subjectFieldController.text,
		name: null, // It will be stored in postingNames[board]
		options: _optionsFieldController.text,
		text: _textFieldController.text,
		files: _attachments.map((a) => DraftPostFile(
			path: a.current.file.path,
			spoiler: a.spoiler,
			overrideFilenameWithoutExtension: a.filenameController.text,
			overrideRandomizeFilenames: a.overrideRandomizeFilenames
		)).toList(),
		flag: null, // It will be stored in postingFlags[board]
		useLoginSystem: switch (_disableLoginSystem) {
			true => false,
			_ => null
		}
	);

	void _updateNeededPosts() {
		_neededPosts = _makeDraft().calculateNeededPosts(context.read<Imageboard>().persistence.getBoard(widget.board.s));
	}

	void _didUpdateDraft() {
		final draft = _makeDraft();
		widget.onDraftChanged(_isNonTrivial(draft) ? draft : null);
	}

	@override
	void initState() {
		super.initState();
		final persistence = context.read<Persistence>();
		postingPost = ValueNotifier(null);
		_textFieldController = ReplyBoxTextEditingController(text: widget.initialDraft?.text);
		_textIsEmpty = text.isEmpty;
		_subjectFieldController = TextEditingController(text: widget.initialDraft?.subject);
		_optionsFieldController = TextEditingController(text: widget.initialDraft?.options);
		_nameFieldController = TextEditingController(text: persistence.browserState.postingNames[widget.board]);
		flag = widget.initialDraft?.flag ?? persistence.browserState.postingFlags[widget.board];
		if (widget.initialDraft?.useLoginSystem == false) {
			_disableLoginSystem = true;
		}
		_textFocusNode = FocusNode();
		_rootFocusNode = FocusNode();
		_textFieldController.addListener(_onTextChanged);
		_subjectFieldController.addListener(_didUpdateDraft);
		final initialBoard = widget.board;
		context.read<ImageboardSite>().getBoardFlags(widget.board.s).then((flags) {
			if (!mounted || widget.board != initialBoard) return;
			setState(() {
				_flags = flags;
			});
		}).catchError((Object e, StackTrace st) {
			Future.error(e, st); // Crashlytics
			print('Error getting flags for ${widget.board}: $e');
		});
		if (_nameFieldController.text.isNotEmpty || _optionsFieldController.text.isNotEmpty || (_disableLoginSystem && hasLoginSystem)) {
			_showOptions = true;
		}
		_setInitialAttachments(widget.initialDraft?.files ?? []);
		widget.onInitState?.call(this);
	}

	@override
	void didUpdateWidget(ReplyBox oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.board != widget.board || oldWidget.threadId != widget.threadId) {
			draft = widget.initialDraft;
		}
		if (oldWidget.board != widget.board) {
			context.read<ImageboardSite>().getBoardFlags(widget.board.s).then((flags) {
				setState(() {
					_flags = flags;
				});
			});
		}
	}

	/// If we use userUpdateTextEditingValue, the text field animates properly
	set _textFieldValue(TextEditingValue value) {
		final editableText = _textFieldKey.currentState?.editableText;
		if (editableText != null) {
			editableText.userUpdateTextEditingValue(value, null);
		}
		else {
			_textFieldController.value = value;
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
			_textFieldValue = TextEditingValue(
				selection: TextSelection(
					baseOffset: currentPos + insertedText.length,
					extentOffset: currentPos + insertedText.length
				),
				text: _textFieldController.text.substring(0, currentPos) + insertedText + _textFieldController.text.substring(currentPos)
			);
		}
		else {
			// Replace selected text
			_textFieldValue = TextEditingValue(
				selection: TextSelection(
					baseOffset: selection.baseOffset,
					extentOffset: selection.baseOffset + insertedText.length
				),
				text: _textFieldController.text.substring(0, selection.baseOffset) + insertedText + _textFieldController.text.substring(selection.extentOffset)
			);
		}
	}

	void onTapPostId(int threadId, int id) {
		if (context.read<ImageboardSite?>()?.supportsPosting ?? false) {
			if (threadId != widget.threadId) {
				showToast(
					context: context,
					message: 'Cross-thread reply!',
					icon: CupertinoIcons.exclamationmark_triangle
				);
			}
			showReplyBox();
			_postInBackground();
			_insertText('>>$id');
		}
	}

	void onQuoteText(String text, {required PostIdentifier? backlink}) {
		if (context.read<ImageboardSite?>()?.supportsPosting ?? false) {
			if (backlink != null && backlink.thread != thread) {
				showToast(
					context: context,
					message: 'Cross-thread reply!',
					icon: CupertinoIcons.exclamationmark_triangle
				);
			}
			showReplyBox();
			_postInBackground();
			if (backlink != null) {
				if (ImageboardBoard.getKey(backlink.board) != widget.board) {
					_insertText('>>>/${backlink.board}/${backlink.postId}');
				}
				else {
					_insertText('>>${backlink.postId}');
				}
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
		flag ??= persistence.browserState.postingFlags[widget.board];
		for (final draft in Outbox.instance.queuedPostsFor(context.read<Imageboard>().key, widget.board.s, widget.threadId)) {
			if (!_submittingPosts.contains(draft) && draft != postingPost.value) {
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
		_chanTabs?.didOpenReplyBox();
	}

	void hideReplyBox() {
		setState(() {
			_show = false;
		});
		widget.onVisibilityChanged?.call();
		_rootFocusNode.unfocus();
		_chanTabs?.didCloseReplyBox();
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
		String? codec,
		Map<String, Set<String>> allowedCodecs = const {},
		int? durationInSeconds,
		int? maximumDurationInSeconds,
		int? width,
		int? height,
		int? maximumDimension,
		required bool metadataPresent,
		required bool metadataAllowed,
		required bool randomizeChecksum,
		required MediaConversion transcode,
		required bool force,
		required bool showToastIfLong,
	}) async {
		final ext = source.path.afterLast('.').toLowerCase();
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
		if (switch((codec, allowedCodecs[ext])) {
			(String codec_, Set<String> allowedCodecs_) => !allowedCodecs_.contains(codec_),
			_ => false
		}) {
			solutions.add('re-encoding');
		}
		transcode.copyStreams = !force && solutions.isEmpty;
		if (metadataPresent && !metadataAllowed) {
			solutions.add('removing metadata');
		}
		if (audioPresent == true && audioAllowed == false && transcode.outputFileExtension != 'gif') {
			solutions.add('removing audio');
		}
		if (!force && solutions.isEmpty && ['jpg', 'jpeg', 'png', 'gif', 'webm', 'mp4'].contains(ext)) {
			return source;
		}
		final existingResult = await transcode.getDestinationIfSatisfiesConstraints(tryOriginalFile: false);
		if (existingResult != null) {
			if (force) {
				// Delete current file
				await existingResult.file.delete();
			}
			else if ((audioPresent == true && audioAllowed == true && !existingResult.hasAudio)) {
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
			final toastSuffix = solutions.isEmpty ? '' : ': ${solutions.join(', ')}';
			Future.delayed(const Duration(milliseconds: 500), () {
				if (_attachmentProgress != null && mounted) {
					showToast(context: context, message: 'Converting$toastSuffix', icon: Adaptive.icons.photo);
					toastedStart = true;
				}
			});
			final result = await transcode.start();
			if (!mounted) return null;
			setState(() {
				_attachmentProgress = null;
			});
			if (toastedStart || showToastIfLong) {
				showToast(context: context, message: 'File converted${toastedStart ? '' : toastSuffix}', icon: CupertinoIcons.checkmark);
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

Future<bool> _handleImagePaste({bool manual = true}) async {
		try {
			final file = await getClipboardImageAsFile(context);
			if (file != null) {
				_addAttachment(file);
				return true;
			}
			else if (manual && mounted) {
				showToast(
					context: context,
					message: 'No image in clipboard',
					icon: CupertinoIcons.xmark
				);
			}
		}
		catch (e, st) {
			if (mounted && manual) {
				alertError(context, e, st, barrierDismissible: true);
			}
		}
		return false;
	}

Future<_ReplyBoxFile?> _makeAttachment(PickedAttachment? originalAttachment, File newAttachment, {
		required bool checkForDuplicateFile,
		bool spoiler = false,
		bool forceRandomizeChecksum = false,
		int? forceMaximumDimension,
		int? forceMaximumSizeInBytes,
		bool forcePngToJpg = false,
		bool forceWebpToPng = false,
		bool forceMp4ToWebm = false,
		bool forceVideoToGif = false,
		bool forceGifToMp4 = false,
		bool forceConvert = false,
		String? filenameWithoutExtension,
		bool overrideRandomizeFilenames = false
	}) => _makeAttachmentLock.protect(() async {
		File? file = newAttachment;
		final settings = Settings.instance;
		final randomizeChecksum = forceRandomizeChecksum || settings.randomizeChecksumOnUploadedFiles;
		setState(() {
			_attachmentProgress = ('Processing', null);
		});
		try {
			final board = context.read<Persistence>().getBoard(widget.board.s);
			if (!file.uri.pathSegments.last.contains('.')) {
				// No extension
				final scan = await MediaScan.scan(file.uri);
				// Rename it with extension
				file = await file.copy(Persistence.shareCacheDirectory.child('${file.uri.pathSegments.last}.${scan.guessExtension}'));
			}
			if (file.path.endsWith('.pvt')) {
				// Live Photo (it's a directory)
				File? image;
				File? video;
				await for (final child in Directory(file.path).list()) {
					final childExt = child.path.afterLast('.').toLowerCase();
					if (childExt == 'mov') {
						video = File(child.path);
					}
					else if (childExt == 'jpeg' || childExt == 'jpg' || childExt == 'heic') {
						image = File(child.path);
					}
				}
				if (image != null && video != null) {
					if (!mounted) {
						return null;
					}
					file = await showAdaptiveDialog<File>(
						context: context,
						builder: (context) => AdaptiveAlertDialog(
							title: const Text('Live Photo'),
							content: const Text('Which part of the Live Photo do you want to post?'),
							actions: [
								AdaptiveDialogAction(
									onPressed: () => Navigator.pop(context, image),
									child: const Text('Image')
								),
								AdaptiveDialogAction(
									onPressed: () => Navigator.pop(context, video),
									child: const Text('Video')
								),
								AdaptiveDialogAction(
									onPressed: () => Navigator.pop(context),
									child: const Text('Cancel')
								)
							]
						)
					);
					if (file == null) {
						// User cancelled
						return null;
					}
 				}
				else {
					file = image ?? video;
					if (file == null) {
						throw Exception('Failed to extract contents of Live Photo');
					}
				}
			}
			String ext = file.uri.pathSegments.last.afterLast('.').toLowerCase();
			if (ext == 'jpg' || ext == 'jpeg' || ext == 'heic') {
				file = await FlutterExifRotation.rotateImage(path: file.path);
				file = await _moveFileOutOfDocumentsDir(file);
			}
			if (ext == 'heic') {
				final heicPath = await FlutterHeicToJpg.convert(file.path);
				if (heicPath == null) {
					throw Exception('Failed to convert HEIC image to JPEG');
				}
				file = File(heicPath);
				ext = 'jpg';
			}
			final stat = await file.stat();
			int size = stat.size;
			MediaScan scan = await MediaScan.scan(file.uri);
			if (scan.forceFormat == 'mjpeg') {
				// TODO: Just check codec. so it applies to all renames?
				// Wrong file extension, rename it
				file = await file.copy(Persistence.shareCacheDirectory.child('${file.uri.pathSegments.last}.jpeg'));
				ext = 'jpg';
				scan = await MediaScan.scan(file.uri);
			}
			// We may shrink under the size limit just by removing the audio
			if ((scan.duration, scan.audioBitrate) case (Duration duration, int audioBitrate) when !board.webmAudioAllowed) {
				final audioSize = (duration.inSecondsFloat * (audioBitrate / 8)).round();
				// Sanity check the estimated size
				if (audioSize < 0.15 * size) {
					size -= audioSize;
				}
			}
			final originalAttachment2 = originalAttachment ?? (
				file: file,
				scan: scan,
				stat: stat,
				md5: await calculateMD5(file)
			);
			if (checkForDuplicateFile && _attachments.any((a) => a.original.md5 == originalAttachment2.md5 && a.original.stat.size == originalAttachment2.stat.size)) {
				if (!mounted || !await confirm(
					context, 'Add duplicate file?',
					actionName: 'Add',
					content: 'This file is already attached to the draft'
				) || !mounted) {
					return null;
				}
			}
			if (ext == 'jpg' || ext == 'jpeg' || ext == 'webp' || ext == 'avif') {
				file = await _showTranscodeWindow(
					source: file,
					size: size,
					maximumSize: forceMaximumSizeInBytes ?? board.maxImageSizeBytes,
					width: scan.width,
					height: scan.height,
					maximumDimension: forceMaximumDimension ?? settings.maximumImageUploadDimension,
					transcode: forceWebpToPng ? MediaConversion.toPng(
						file.uri,
						maximumSizeInBytes: forceMaximumSizeInBytes ?? board.maxImageSizeBytes,
						maximumDimension: forceMaximumDimension ?? settings.maximumImageUploadDimension,
						removeMetadata: settings.removeMetadataOnUploadedFiles,
						randomizeChecksum: randomizeChecksum
					): MediaConversion.toJpg(
						file.uri,
						maximumSizeInBytes: forceMaximumSizeInBytes ?? board.maxImageSizeBytes,
						maximumDimension: forceMaximumDimension ?? settings.maximumImageUploadDimension,
						removeMetadata: settings.removeMetadataOnUploadedFiles,
						randomizeChecksum: randomizeChecksum
					),
					metadataPresent: scan.hasMetadata,
					metadataAllowed: !settings.removeMetadataOnUploadedFiles,
					randomizeChecksum: randomizeChecksum,
					force: forceConvert,
					showToastIfLong: originalAttachment == null
				);
			}
			else if (ext == 'png') {
				file = await _showTranscodeWindow(
					source: file,
					size: size,
					maximumSize: forceMaximumSizeInBytes ?? board.maxImageSizeBytes,
					width: scan.width,
					height: scan.height,
					maximumDimension: forceMaximumDimension ?? settings.maximumImageUploadDimension,
					transcode: forcePngToJpg ? MediaConversion.toJpg(
						file.uri,
						maximumSizeInBytes: forceMaximumSizeInBytes ?? board.maxImageSizeBytes,
						maximumDimension: forceMaximumDimension ?? settings.maximumImageUploadDimension,
						removeMetadata: settings.removeMetadataOnUploadedFiles,
						randomizeChecksum: randomizeChecksum
					) : MediaConversion.toPng(
						file.uri,
						maximumSizeInBytes: forceMaximumSizeInBytes ?? board.maxImageSizeBytes,
						maximumDimension: forceMaximumDimension ?? settings.maximumImageUploadDimension,
						removeMetadata: settings.removeMetadataOnUploadedFiles,
						randomizeChecksum: randomizeChecksum
					),
					metadataPresent: scan.hasMetadata,
					metadataAllowed: !settings.removeMetadataOnUploadedFiles,
					randomizeChecksum: randomizeChecksum,
					force: forceConvert,
					showToastIfLong: originalAttachment == null
				);
			}
			else if (ext == 'gif') {
				file = await _showTranscodeWindow(
					source: file,
					metadataPresent: scan.hasMetadata,
					metadataAllowed: !settings.removeMetadataOnUploadedFiles,
					size: size,
					maximumSize: forceMaximumSizeInBytes ?? board.maxImageSizeBytes,
					randomizeChecksum: randomizeChecksum,
					force: forceConvert,
					showToastIfLong: originalAttachment == null,
					transcode: forceGifToMp4 ? MediaConversion.toMp4(
						file.uri,
						maximumSizeInBytes: forceMaximumSizeInBytes ?? board.maxWebmSizeBytes ?? board.maxImageSizeBytes,
						maximumDimension: settings.maximumImageUploadDimension,
						maximumDurationInSeconds: board.maxWebmDurationSeconds?.toDouble(),
						removeMetadata: settings.removeMetadataOnUploadedFiles,
						randomizeChecksum: randomizeChecksum
					) : MediaConversion.toGif(
						file.uri,
						maximumSizeInBytes: forceMaximumSizeInBytes ?? board.maxWebmSizeBytes ?? board.maxImageSizeBytes,
						maximumDimension: settings.maximumImageUploadDimension,
						removeMetadata: settings.removeMetadataOnUploadedFiles,
						randomizeChecksum: randomizeChecksum
					)
				);
			}
			else if (ext == 'webm') {
				file = await _showTranscodeWindow(
					source: file,
					audioAllowed: board.webmAudioAllowed,
					audioPresent: scan.hasAudio,
					size: size,
					maximumSize: forceMaximumSizeInBytes ?? board.maxWebmSizeBytes ?? board.maxImageSizeBytes,
					durationInSeconds: scan.duration?.inSeconds,
					maximumDurationInSeconds: board.maxWebmDurationSeconds,
					width: scan.width,
					height: scan.height,
					maximumDimension: forceMaximumDimension ?? settings.maximumImageUploadDimension,
					transcode: forceVideoToGif ? MediaConversion.toGif(
						file.uri,
						maximumSizeInBytes: forceMaximumSizeInBytes ?? board.maxWebmSizeBytes,
						maximumDimension: forceMaximumDimension ?? settings.maximumImageUploadDimension,
						removeMetadata: settings.removeMetadataOnUploadedFiles,
						randomizeChecksum: randomizeChecksum
					) : MediaConversion.toWebm(
						file.uri,
						stripAudio: !board.webmAudioAllowed,
						maximumSizeInBytes: forceMaximumSizeInBytes ?? board.maxWebmSizeBytes,
						maximumDurationInSeconds: board.maxWebmDurationSeconds?.toDouble(),
						maximumDimension: forceMaximumDimension ?? settings.maximumImageUploadDimension,
						removeMetadata: settings.removeMetadataOnUploadedFiles,
						randomizeChecksum: randomizeChecksum
					),
					metadataPresent: scan.hasMetadata,
					metadataAllowed: !settings.removeMetadataOnUploadedFiles,
					randomizeChecksum: randomizeChecksum,
					force: forceConvert,
					showToastIfLong: originalAttachment == null
				);
			}
			else if (_kNonWebmVideoExts.contains(ext)) {
				file = await _showTranscodeWindow(
					source: file,
					audioAllowed: board.webmAudioAllowed,
					audioPresent: scan.hasAudio,
					codec: scan.codec,
					allowedCodecs: {'mp4': {'h264'}},
					durationInSeconds: scan.duration?.inSeconds,
					maximumDurationInSeconds: board.maxWebmDurationSeconds,
					width: scan.width,
					height: scan.height,
					maximumDimension: forceMaximumDimension ?? settings.maximumImageUploadDimension,
					size: size,
					maximumSize: forceMaximumSizeInBytes ?? board.maxWebmSizeBytes,
					transcode: forceVideoToGif ? MediaConversion.toGif(
						file.uri,
						maximumSizeInBytes: forceMaximumSizeInBytes ?? board.maxWebmSizeBytes,
						maximumDimension: forceMaximumDimension ?? settings.maximumImageUploadDimension,
						removeMetadata: settings.removeMetadataOnUploadedFiles,
						randomizeChecksum: randomizeChecksum
					) : (forceMp4ToWebm ? MediaConversion.toWebm(
						file.uri,
						stripAudio: !board.webmAudioAllowed,
						maximumSizeInBytes: forceMaximumSizeInBytes ?? board.maxWebmSizeBytes,
						maximumDurationInSeconds: board.maxWebmDurationSeconds?.toDouble(),
						maximumDimension: forceMaximumDimension ?? settings.maximumImageUploadDimension,
						removeMetadata: settings.removeMetadataOnUploadedFiles,
						randomizeChecksum: randomizeChecksum
					) : MediaConversion.toMp4(
						file.uri,
						stripAudio: !board.webmAudioAllowed,
						maximumSizeInBytes: forceMaximumSizeInBytes ?? board.maxWebmSizeBytes,
						maximumDurationInSeconds: board.maxWebmDurationSeconds?.toDouble(),
						maximumDimension: forceMaximumDimension ?? settings.maximumImageUploadDimension,
						removeMetadata: settings.removeMetadataOnUploadedFiles,
						randomizeChecksum: randomizeChecksum
					)),
					metadataPresent: scan.hasMetadata,
					metadataAllowed: !settings.removeMetadataOnUploadedFiles,
					randomizeChecksum: randomizeChecksum,
					force: forceConvert,
					showToastIfLong: originalAttachment == null
				);
			}
			else {
				throw Exception('Unsupported file type: $ext');
			}
			if (file != null) {
				final newAttachment = (
					file: file,
					scan: await MediaScan.scan(file.uri),
					stat: await file.stat(),
					md5: await calculateMD5(file)
				);
				return _ReplyBoxFile(
					current: newAttachment,
					original: originalAttachment2,
					initialFilename: filenameWithoutExtension ?? file.basenameWithoutExtension,
					spoiler: spoiler,
					overrideRandomizeFilenames: overrideRandomizeFilenames
				);
			}
			return null;
		}
		on MediaConversionCancelledException {
			// Don't throw, the user started it
			return null;
		}
		finally {
			setState(() {
				_attachmentProgress = null;
			});
		}
	});

	Future<bool?> _shouldUseLoginSystem() async {
		final site = context.read<ImageboardSite>();
		final settings = Settings.instance;
		final savedFields = site.loginSystem?.getSavedLoginFields();
		if (_disableLoginSystem) {
			return false;
		}
		if (savedFields == null) {
			return null;
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

	Future<void> _shrinkFilesToFitMultiPosts(ImageboardBoard board) async {
		for (int i = 0; i < _attachments.length; i += board.filesPerPost) {
			final end = math.min(_attachments.length, i + board.filesPerPost);
			final batchSize = end - i;
			// Allow each image to take half of an equal share
			// Then split the other half (or more) proportionally
			int limit = 1 << 50;
			for (int j = i; j < end; j++) {
				final ext = _attachments[j].ext;
				final thisLimit = ((ext == 'webm' || _kNonWebmVideoExts.contains(ext)) ? board.maxWebmSizeBytes : board.maxImageSizeBytes) ?? limit;
				if (thisLimit < limit) {
					limit = thisLimit;
				}
			}
			final minQuota = limit ~/ (2 * batchSize);
			int bytesAvailable = limit ~/ 2;
			int bytesNeeded = 0;
			for (int j = i; j < end; j++) {
				final size = _attachments[j].current.stat.size;
				if (size > minQuota) {
					bytesNeeded += (size - minQuota);
				}
				else {
					// More quota to share
					bytesAvailable += (minQuota - size);
				}
			}
			for (int j = i; j < end; j++) {
				final file = _attachments[j];
				final size = file.current.stat.size;
				if (size > minQuota) {
					final targetSize = ((size / bytesNeeded) * bytesAvailable).floor();
					if (targetSize < size) {
						double quality = 1.0;
						final originalWidth = file.original.scan.width;
						final originalHeight = file.original.scan.height;
						if (originalWidth == null || originalHeight == null) {
							throw Exception('Failed to get width and/or height');
						}
						if (originalWidth > originalHeight) {
							if (file.current.scan.width case final newWidth?) {
								quality = newWidth / originalWidth;
							}
						}
						else {
							if (file.current.scan.height case final newHeight?) {
								quality = newHeight / originalHeight;
							}
						}
						final currentExt = file.current.file.path.afterLast('.').toLowerCase();
						final originalExt = file.original.file.path.afterLast('.').toLowerCase();
						final offerJpg = originalExt == 'png';
						final offerPng = originalExt == 'webp';
						final offerWebm = _kNonWebmVideoExts.contains(originalExt);
						final offerGif = offerWebm || originalExt == 'webm';
						final offerMp4 = originalExt == 'gif';
						bool forcePngToJpg = offerJpg && currentExt == 'jpg';
						bool forceWebpToPng = offerPng && currentExt == 'png';
						bool forceMp4ToWebm = offerWebm && currentExt == 'webm';
						bool forceVideoToGif = offerGif && currentExt == 'gif';
						bool forceGifToMp4 = offerMp4 && currentExt == 'mp4';
						final newAttachment = await _makeAttachment(
							file.original,
							// Convert from original always
							file.original.file,
							forceMaximumSizeInBytes: targetSize,
							// Need to keep current other settings though
							forceMaximumDimension: (math.max(originalWidth, originalHeight) * quality).ceil(),
							forcePngToJpg: forcePngToJpg,
							forceWebpToPng: forceWebpToPng,
							forceMp4ToWebm: forceMp4ToWebm,
							forceVideoToGif: forceVideoToGif,
							forceGifToMp4: forceGifToMp4,
							forceConvert: true,
							checkForDuplicateFile: false
						);
						if (newAttachment != null) {
							file.current = newAttachment.current;
							newAttachment.dispose();
							_didUpdateDraft();
							_updateNeededPosts();
						}
					}
				}
			}
		}
	}

	Future<bool> _handleMultiFileResizing() async {
		final imageboard = context.read<Imageboard>();
		final board = imageboard.persistence.getBoard(widget.board.s);
		if (board.filesPerPost == 0) {
			if (_attachments.isNotEmpty) {
				throw Exception('Posting files not allowed');
			}
			return true;
		}
		final postsNeeded = _makeDraft().calculateNeededPosts(board);
		final minimumPosts = math.max(1, (_attachments.length / board.filesPerPost).ceil());
		if (postsNeeded > minimumPosts) {
			final shrink = await showAdaptiveDialog<bool>(
				barrierDismissible: true,
				context: context,
				builder: (context) => AdaptiveAlertDialog(
					title: const Text('Shrink files?'),
					content: Text('Currently $postsNeeded posts would be needed to post the files as-is. Files could be shrunk to fit into ${describeCount(minimumPosts, 'post')}.'),
					actions: [
						AdaptiveDialogAction(
							onPressed: () => Navigator.pop(context, true),
							child: Text('Shrink (${describeCount(minimumPosts, 'post')})')
						),
						AdaptiveDialogAction(
							onPressed: () => Navigator.pop(context, false),
							child: Text('Keep ($postsNeeded posts)')
						),
						AdaptiveDialogAction(
							onPressed: () => Navigator.pop(context),
							child: const Text('Cancel')
						)
					]
				)
			);
			if (shrink == null) {
				return false;
			}
			if (shrink) {
				await _shrinkFilesToFitMultiPosts(board);
			}
		}
		return true;
	}

	Future<void> _submit() async {
		final shouldUseLoginSystem = await _shouldUseLoginSystem();
		if (!mounted) {
			return;
		}
		final imageboard = context.read<Imageboard>();
		if (widget.isArchived) {
			showAdaptiveDialog(
				barrierDismissible: true,
				context: context,
				builder: (context) => AdaptiveAlertDialog(
					title: const Text('Thread is archived!'),
					actions: [
						AdaptiveDialogAction(
							onPressed: () {
								Clipboard.setData(ClipboardData(text: _textFieldController.text));
								showToast(
									context: context,
									message: 'Copied "${_textFieldController.text}" to clipboard',
									icon: CupertinoIcons.doc_on_clipboard
								);
								Navigator.pop(context);
							},
							child: const Text('Copy text')
						),
						AdaptiveDialogAction(
							onPressed: () {
								final post = _makeDraft();
								post.name = _nameFieldController.text;
								post.useLoginSystem = shouldUseLoginSystem;
								post.flag = defaultFlag;
								imageboard.persistence.browserState.outbox.add(post);
								runWhenIdle(const Duration(milliseconds: 500), imageboard.persistence.didUpdateBrowserState);
								final entry = Outbox.instance.submitPost(imageboard.key, post, QueueStateIdle());
								_submittingPosts.add(entry);
								_listenToReplyPosting(entry);
								draft = null; // Clear
								widget.onDraftChanged(null);
								showToast(
									context: context,
									icon: CupertinoIcons.tray_arrow_up,
									message: 'Saved draft'
								);
								setState(() {});
								Navigator.pop(context);
							},
							child: const Text('Save as draft')
						),
						AdaptiveDialogAction(
							onPressed: () => Navigator.pop(context),
							child: const Text('Cancel')
						)
					]
				)
			);
			return;
		}
		if (!await _handleMultiFileResizing() || !mounted) {
			return;
		}
		lightHapticFeedback();
		final post = _makeDraft();
		post.name = _nameFieldController.text;
		post.useLoginSystem = shouldUseLoginSystem;
		post.flag = defaultFlag;
		bool autohid = false;
		final entry = Outbox.instance.submitPost(imageboard.key, post, QueueStateNeedsCaptcha(
			beforeModal: () {
				if (mounted && show) {
					autohid = true;
					hideReplyBox();
				}
			},
			afterModal: () {
				if (mounted && autohid) {
					showReplyBox();
					autohid = false;
				}
			}
		));
		// Remember _disableLoginSystem, it will also be kept in the draft
		if (!_disableLoginSystem) {
			_showOptions = false;
		}
		final oldPostingPost = postingPost.value;
		if (oldPostingPost != null) {
			// This should never happen tbqh
			_submittingPosts.add(oldPostingPost);
		}
		postingPost.value = entry;
		// This needs to happen last so it doesn't eagerly assume this is an undeletion
		_listenToReplyPosting(entry);
		setState(() {});
		if (context.read<Settings>().closeReplyBoxAfterSubmitting) {
			hideReplyBox();
		}
	}

	void _reset() {
		_textFieldController.clear();
		_nameFieldController.text = defaultName;
		flag = defaultFlag;
		// Don't clear options field, it should be remembered
		_subjectFieldController.clear();
		for (final a in _attachments) {
			a.dispose();
		}
		_attachments.clear();
		_didUpdateDraft();
		_neededPosts = 1;
	}

	void _postInBackground() {
		final toMove = postingPost.value;
		if (toMove == null) {
			return;
		}
		_submittingPosts.add(toMove);
		_reset();
		setState(() {
			postingPost.value = null;
		});
	}

	/// Return the primary outgoing post to the reply box
	void _cancel() {
		final post = postingPost.value;
		if (post == null) {
			return;
		}
		post.cancel();
		post.delete();
		setState(() {
			postingPost.value = null;
		});
		// The old contents should still be in the reply box.
	}

	void _listenToReplyPosting(QueuedPost post) {
		QueueState<QueuedPost, PostReceipt>? lastState;
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
			if (state is QueueStateDeleted<QueuedPost, PostReceipt>) {
				// Don't remove listener, in case undeleted
				_submittingPosts.remove(post);
				if (post == postingPost.value) {
					setState(() {
						postingPost.value = null;
					});
				}
				setState(() {});
				return;
			}
			if (!_submittingPosts.contains(post) && post != postingPost.value) {
				// Undelete
				_submittingPosts.add(post);
				setState(() {});
			}
			if (state is QueueStateDone<QueuedPost, PostReceipt>) {
				post.removeListener(listener);
				_submittingPosts.remove(post);
				widget.onReplyPosted(post.post.board, state.result);
				mediumHapticFeedback();
				final nextPost = state.next;
				if (post == postingPost.value) {
					if (nextPost != null) {
						// Show next post in the box
						draft = nextPost.post;
					}
					else {
						_rootFocusNode.unfocus();
						_reset();
					}
					// Hide reply box
					setState(() {
						postingPost.value = nextPost;
					});
					if (nextPost != null) {
						// This needs to happen last so it doesn't eagerly assume this is an undeletion
						_listenToReplyPosting(nextPost);
					}
					else if (context.read<Settings>().closeReplyBoxAfterSubmitting) {
						hideReplyBox();
					}
				}
				else if (nextPost != null) {
					_submittingPosts.add(nextPost);
					_listenToReplyPosting(nextPost);
				}
			}
			else if (state is QueueStateFailed<QueuedPost, PostReceipt> && post == postingPost.value) {
				post.removeListener(listener);
				post.delete();
				setState(() {
					postingPost.value = null;
				});
				if (!show) {
					showReplyBox();
				}
			}
			else if (state is QueueStateIdle<QueuedPost, PostReceipt> && post == postingPost.value) {
				// User cancelled captcha
				post.removeListener(listener);
				post.delete();
				setState(() {
					postingPost.value = null;
				});
				// Probably they cancelled it to fix a typo or something
				if (!show) {
					showReplyBox();
				}
			}
		}
		post.addListener(listener);
		listener();
	}

	void _pickEmote() async {
		final site = context.read<ImageboardSite>();
		final emotes = site.getEmotes();
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
											child: emote.image != null ? CNetworkImage(
												url: emote.image.toString(),
												client: site.client,
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
		final site = context.read<ImageboardSite>();
		final flags = _flags.cast<ImageboardBoardFlag?>().toList();
		final zeroFlagIndex = _flags.indexWhere((f) => f.code == '0');
		String zeroFlagName = 'Geographic Location';
		if (zeroFlagIndex != -1) {
			zeroFlagName = flags[zeroFlagIndex]?.name ?? zeroFlagName;
			flags[zeroFlagIndex] = null;
		}
		final pickedFlag = await pick<ImageboardBoardFlag?>(
			context: context,
			items: flags,
			getName: (flag) => flag?.name ?? zeroFlagName,
			itemBuilder: (flag) => Row(
				children: [
					if (flag == null) const SizedBox(width: 16)
					else CNetworkImage(
						url: flag.imageUrl,
						client: site.client,
						fit: BoxFit.contain,
						cache: true
					),
					const SizedBox(width: 8),
					Text(flag?.name ?? zeroFlagName)
				]
			),
			selectedItem: flag
		);
		if (mounted) {
			setState(() {
				flag = pickedFlag;
				if (pickedFlag case final pickedFlag?) {
					context.read<Persistence>().browserState.postingFlags[widget.board] = pickedFlag;
				}
				else {
					context.read<Persistence>().browserState.postingFlags.remove(widget.board);
				}
				context.read<Persistence>().didUpdateBrowserState();
			});
		}
	}

	double get _maxReplyBoxHeight => (MediaQuery.sizeOf(context).height / 2) - 100;

	Widget _buildQueueButton() => Align(
		alignment: Alignment.centerRight,
		child: AnimatedSize(
			duration: const Duration(milliseconds: 300),
			child: AnimatedBuilder(
				animation: Outbox.instance,
				builder: (context, _) {
					final queue = Outbox.instance.queues[(context.watch<Imageboard>().key, widget.board, widget.threadId == null ? ImageboardAction.postThread : ImageboardAction.postReply)];
					Widget build(BuildContext context) {
						final ourCount = _submittingPosts.length + (postingPost.value != null ? 1 : 0);
						final activeCount = Outbox.instance.activeCount;
						final othersCount = queue?.list.where((e) => !e.state.isIdle && e.thread != thread).length ?? 0;
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
							// There is a meaningful cooldown and nothing else is showing it
							((time.difference(now) > const Duration(seconds: 5)) && _submittingPosts.isEmpty && postingPost.value == null);
						if (!(show && shouldShow)) {
							return const SizedBox(width: double.infinity);
						}
						return Container(
							width: double.infinity,
							decoration: BoxDecoration(
								border: Border(
									top: BorderSide(color: ChanceTheme.primaryColorWithBrightness20Of(context))
								),
								color: ChanceTheme.primaryColorWithBrightness10Of(context)
							),
							child: AdaptiveButton(
								onPressed: () async {
									final selected = await showOutboxModalForThread(
										context: context,
										imageboardKey: context.read<Imageboard?>()?.key,
										board: widget.board.s,
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
											interval: () => const Duration(seconds: 1),
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
														Text(str, style: CommonTextStyles.tabularFigures)
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
													if (othersCount > 0) '($othersCount queued on ${context.watch<ImageboardSite>().formatBoardName(widget.board.s)})'
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
	);

	Widget _buildSubmittingPosts() => AnimatedSize(
		duration: const Duration(milliseconds: 300),
		alignment: Alignment.topCenter,
		child: show ? Column(
			mainAxisSize: MainAxisSize.min,
			children: _submittingPosts.map((p) => QueueEntryWidget(
				entry: p,
				replyBoxMode: true,
				onMove: () => _onDraftTap(p, true),
				onCopy: () => _onDraftTap(p, false),
			)).toList()
		) : const SizedBox(width: double.infinity)
	);

	Widget _buildAttachmentOptions(BuildContext context, _ReplyBoxFile file) {
		final board = context.read<Persistence>().getBoard(widget.board.s);
		final settings = context.watch<Settings>();
		final fakeAttachment = Attachment(
			ext: '.${file.ext}',
			url: '',
			type: file.ext == 'webm' ?
				AttachmentType.webm :
				(file.ext == 'mp4' ? AttachmentType.mp4 : AttachmentType.image),
			md5: file.current.md5,
			id: '${identityHashCode(file)}',
			filename: file.current.file.uri.pathSegments.last,
			thumbnailUrl: '',
			board: widget.board.s,
			width: file.current.scan.width,
			height: file.current.scan.height,
			sizeInBytes: file.current.stat.size,
			threadId: null
		);
		final decoration = BoxDecoration(
			border: Border(top: BorderSide(color: ChanceTheme.primaryColorWithBrightness20Of(context))),
			color: ChanceTheme.backgroundColorOf(context)
		);
		return Container(
			decoration: decoration,
			// Blank out the widget during collapse animation
			foregroundDecoration: _showAttachmentOptions ? null : decoration,
			padding: const EdgeInsets.only(top: 9, left: 8, right: 8, bottom: 10),
			child: Row(
				children: [
					Expanded(
						child: Column(
							mainAxisSize: MainAxisSize.min,
							mainAxisAlignment: MainAxisAlignment.spaceBetween,
							crossAxisAlignment: CrossAxisAlignment.stretch,
							children: [
								Row(
									children: [
										Flexible(
											child: Opacity(
												opacity: settings.randomizeFilenames && !file.overrideRandomizeFilenames ? 0.5 : 1.0,
												child: AdaptiveTextField(
													enabled: !loading,
													controller: file.filenameController,
													onTap: () {
														if (settings.randomizeFilenames && !file.overrideRandomizeFilenames) {
															setState(() {
																file.overrideRandomizeFilenames = true;
															});
														}
													},
													placeholder: file.current.file.basenameWithoutExtension,
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
										Text('.${file.ext}'),
										const SizedBox(width: 8),
										AdaptiveIconButton(
											padding: EdgeInsets.zero,
											minimumSize: const Size.square(30),
											icon: const Icon(CupertinoIcons.xmark),
											onPressed: () {
												_attachments.remove(file);
												file.dispose();
												if (_attachments.isEmpty) {
													_showAttachmentOptions = false;
												}
												setState(() {});
												_didUpdateDraft();
												_updateNeededPosts();
											}
										)
									]
								),
								const SizedBox(height: 8),
								Wrap(
									alignment: WrapAlignment.end,
									runAlignment: WrapAlignment.spaceBetween,
									crossAxisAlignment: WrapCrossAlignment.center,
									spacing: 8,
									runSpacing: 8,
									children: [
										AdaptiveIconButton(
											padding: EdgeInsets.zero,
											minimumSize: Size.zero,
											icon: Row(
												mainAxisSize: MainAxisSize.min,
												children: [
													Icon(
														settings.randomizeFilenames ?
															(file.overrideRandomizeFilenames ?
																CupertinoIcons.minus_square :
																CupertinoIcons.checkmark_square
															) : CupertinoIcons.square
													),
													const Flexible(
														child: Text('Random filename')
													)
												]
											),
											onPressed: () {
												if (file.overrideRandomizeFilenames) {
													setState(() {
														file.overrideRandomizeFilenames = false;
													});
												}
												else {
													setState(() {
														Settings.randomizeFilenamesSetting.value = !settings.randomizeFilenames;
													});
												}
											}
										),
										if (board.spoilers == true) AdaptiveIconButton(
											padding: EdgeInsets.zero,
											minimumSize: Size.zero,
											icon: Row(
												mainAxisSize: MainAxisSize.min,
												children: [
													Icon(file.spoiler ? CupertinoIcons.checkmark_square : CupertinoIcons.square),
													const Text('Spoiler')
												]
											),
											onPressed: () {
												setState(() {
													file.spoiler = !file.spoiler;
												});
											}
										),
										AdaptiveThinButton(
											padding: const EdgeInsets.all(4),
											onPressed: () async {
												final originalWidth = file.original.scan.width;
												final originalHeight = file.original.scan.height;
												if (originalWidth == null || originalHeight == null) {
													throw Exception('Failed to get width and/or height');
												}
												double quality = 1.0;
												final double qualityStep;
												if (originalWidth > originalHeight) {
													qualityStep = 2 / originalWidth;
													if (file.current.scan.width case final newWidth?) {
														quality = newWidth / originalWidth;
													}
												}
												else {
													qualityStep = 2 / originalHeight;
													if (file.current.scan.height case final newHeight?) {
														quality = newHeight / originalHeight;
													}
												}
												quality = math.min(quality, 1.0); // Floating point error or rounding or idk
												final initialQuality = quality;
												final currentExt = file.current.file.path.afterLast('.').toLowerCase();
												final originalExt = file.original.file.path.afterLast('.').toLowerCase();
												final offerJpg = originalExt == 'png';
												final offerPng = originalExt == 'webp';
												final offerWebm = _kNonWebmVideoExts.contains(originalExt);
												final offerGif = offerWebm || originalExt == 'webm';
												final offerMp4 = originalExt == 'gif';
												bool forcePngToJpg = offerJpg && currentExt == 'jpg';
												bool forceWebpToPng = offerPng && currentExt == 'png';
												bool forceMp4ToWebm = offerWebm && currentExt == 'webm';
												bool forceVideoToGif = offerGif && currentExt == 'gif';
												bool forceGifToMp4 = offerMp4 && currentExt == 'mp4';
												// Minimum 50px width, or 25% width, whichever is lower
												final minQuality = (25 * qualityStep).clamp(0, 0.25).toDouble();
												const maxQuality = 1.0;
												bool forceConvert = false;
												final reencode = await showAdaptiveDialog<bool>(
													context: context,
													barrierDismissible: true,
													builder: (context) => StatefulBuilder(
														builder: (context, setDialogState) => AdaptiveAlertDialog(
															title: Text((offerJpg || offerWebm) ? 'Re-encode' : 'Resize'),
															content: Column(
																mainAxisSize: MainAxisSize.min,
																children: [
																	const SizedBox(height: 8),
																	ConstrainedBox(
																		constraints: const BoxConstraints(
																			maxWidth: 200,
																			maxHeight: 200
																		),
																		child: FittedBox(
																			fit: BoxFit.contain,
																			child: Stack(
																				alignment: Alignment.topLeft,
																				children: [
																					Container(
																						decoration: BoxDecoration(
																							border: Border.all(
																								color: Settings.instance.theme.primaryColor,
																								width: 3
																							)
																						),
																						width: originalWidth.toDouble(),
																						height: originalHeight.toDouble()
																					),
																					Container(
																						color: Colors.red,
																						width: originalWidth * quality,
																						height: originalHeight * quality,
																						child: MediaThumbnail(uri: file.current.file.uri, fit: BoxFit.contain)
																					)
																				]
																			)
																		)
																	),
																	const SizedBox(height: 8),
																	Row(
																		children: [
																			Expanded(
																				child: Text('${(originalWidth * quality).roundToEven}x${(originalHeight * quality).roundToEven}')
																			),
																			AdaptiveIconButton(
																				padding: EdgeInsets.zero,
																				onPressed: quality <= minQuality ? null : () {
																					setDialogState(() {
																						quality -= qualityStep;
																						forceConvert = quality != initialQuality;
																					});
																				},
																				icon: const Icon(CupertinoIcons.minus)
																			),
																			AdaptiveIconButton(
																				padding: EdgeInsets.zero,
																				onPressed: quality >= maxQuality ? null : () {
																					setDialogState(() {
																						quality += qualityStep;
																						forceConvert = quality != initialQuality;
																					});
																				},
																				icon: const Icon(CupertinoIcons.plus)
																			)
																		]
																	),
																	const SizedBox(height: 8),
																	Slider.adaptive(
																		value: quality,
																		min: minQuality,
																		max: maxQuality,
																		onChanged: (newValue) {
																			setDialogState(() {
																				quality = newValue;
																				forceConvert = quality != initialQuality;
																			});
																		}
																	)
																]
															),
															actions: [
																if (offerWebm) AdaptiveDialogAction(
																	onPressed: () {
																		forceMp4ToWebm = !forceMp4ToWebm;
																		forceVideoToGif = false;
																		if (!forceMp4ToWebm) {
																			quality = 1.0;
																		}
																		Navigator.pop(context, true);
																	},
																	child: forceMp4ToWebm ? const Text('Restore to MP4') : const Text('Convert to WEBM')
																),
																if (offerMp4) AdaptiveDialogAction(
																	onPressed: () {
																		forceGifToMp4 = !forceGifToMp4;
																		if (!forceGifToMp4) {
																			quality = 1.0;
																		}
																		Navigator.pop(context, true);
																	},
																	child: forceGifToMp4 ? const Text('Restore to GIF') : const Text('Convert to MP4')
																),
																if (offerGif) AdaptiveDialogAction(
																	onPressed: () {
																		forceVideoToGif = !forceVideoToGif;
																		forceMp4ToWebm = false;
																		if (!forceVideoToGif) {
																			quality = 1.0;
																		}
																		Navigator.pop(context, true);
																	},
																	child: forceVideoToGif ? Text('Restore to ${originalExt.toUpperCase()}') : const Text('Convert to GIF')
																),
																if (offerPng) AdaptiveDialogAction(
																	onPressed: () {
																		forceWebpToPng = !forceWebpToPng;
																		if (!forceWebpToPng) {
																			quality = 1.0;
																		}
																		Navigator.pop(context, true);
																	},
																	// WEBP without force will be JPEG
																	child: forceWebpToPng ? const Text('Restore to JPEG') : const Text('Convert to PNG')
																),
																if (offerJpg) AdaptiveDialogAction(
																	onPressed: () {
																		forcePngToJpg = !forcePngToJpg;
																		if (!forcePngToJpg) {
																			quality = 1.0;
																		}
																		Navigator.pop(context, true);
																	},
																	child: forcePngToJpg ? const Text('Restore to PNG') : const Text('Convert to JPEG')
																),
																AdaptiveDialogAction(
																	isDefaultAction: true,
																	onPressed: forceConvert ? () => Navigator.pop(context, true) : null,
																	child: const Text('Resize')
																),
																AdaptiveDialogAction(
																	child: const Text('Cancel'),
																	onPressed: () => Navigator.pop(context, false)
																)
															]
														)
													)
												);
												if (reencode ?? false) {
													setState(() {
														_showAttachmentOptions = false;
													});
													try {
														final newAttachment = await _makeAttachment(
															file.original,
															file.original.file,
															forceMaximumDimension: (math.max(originalWidth, originalHeight) * quality).ceil(),
															forcePngToJpg: forcePngToJpg,
															forceWebpToPng: forceWebpToPng,
															forceMp4ToWebm: forceMp4ToWebm,
															forceVideoToGif: forceVideoToGif,
															forceGifToMp4: forceGifToMp4,
															forceConvert: forceConvert,
															checkForDuplicateFile: false
														);
														if (newAttachment != null) {
															file.current = newAttachment.current;
															newAttachment.dispose();
															_didUpdateDraft();
															_updateNeededPosts();
														}
													}
													finally {
														setState(() {
															_showAttachmentOptions = true;
														});
													}
												}
											},
											child: Text(
												[
													if (file.ext == 'mp4' || file.ext == 'webm') ...[
														if (file.current.scan.codec != null) file.current.scan.codec!.toUpperCase(),
														if (file.current.scan.hasAudio == true) 'with audio'
														else 'no audio',
														if (file.current.scan.duration != null) formatDuration(file.current.scan.duration!),
														if (file.current.scan.bitrate != null) '${(file.current.scan.bitrate! / (1024 * 1024)).toStringAsFixed(1)} Mbps',
													],
													if (file.current.scan.width != null && file.current.scan.height != null) '${file.current.scan.width}x${file.current.scan.height}',
													formatFilesize(file.current.stat.size)
												].join(', '),
												maxLines: null,
												textAlign: TextAlign.right
											)
										),
										AdaptiveThinButton(
											padding: const EdgeInsets.all(4),
											child: Row(
												mainAxisSize: MainAxisSize.min,
												children: [
													const RotatedBox(
														quarterTurns: 3,
														child: Text('MD5', style: TextStyle(fontSize: 9))
													),
													const SizedBox(width: 2),
													Text(file.current.md5.substring(0, 6).toLowerCase(), textAlign: TextAlign.center)
												]
											),
											onPressed: () async {
												setState(() {
													_showAttachmentOptions = false;
												});
												try {
													final newAttachment = await _makeAttachment(
														file.original, file.current.file, forceRandomizeChecksum: true,
														spoiler: file.spoiler,
														filenameWithoutExtension: file.filenameController.text,
														overrideRandomizeFilenames: file.overrideRandomizeFilenames,
														checkForDuplicateFile: false
													);
													if (newAttachment != null) {
														file.current = newAttachment.current;
														newAttachment.dispose();
														_didUpdateDraft();
														_updateNeededPosts();
													}
												}
												catch (e, st) {
													Future.error(e, st); // crashlytics
													if (context.mounted) {
														alertError(context, e, st);
													}
												}
												finally {
													setState(() {
														_showAttachmentOptions = true;
													});
												}
											}
										)
									]
								)
							]
						)
					),
					const SizedBox(width: 8),
					ConstrainedBox(
						constraints: BoxConstraints(
							maxWidth: 100,
							maxHeight: 100,
							// Make all thumbnails as wide as the widest one
							minWidth: 100 * math.min(1, _attachments.fold(0, (ratio, file) => math.max(ratio, (file.current.scan.width ?? 0) / (file.current.scan.height ?? 1)))),
						),
						child: GestureDetector(
							child: Hero(
								tag: TaggedAttachment(
									attachment: fakeAttachment,
									semanticParentIds: [_textFieldController.hashCode],
									imageboard: context.read<Imageboard>(),
									postId: 0
								),
								flightShuttleBuilder: (context, animation, direction, fromContext, toContext) {
									return (direction == HeroFlightDirection.push ? fromContext.widget as Hero : toContext.widget as Hero).child;
								},
								createRectTween: (startRect, endRect) {
									if (startRect != null && endRect != null) {
										if (file.ext != 'webm') {
											// Need to deflate the original startRect because it has inbuilt layoutInsets
											// This SavedAttachmentThumbnail will always fill its size
											final rootPadding = MediaQueryData.fromView(View.of(context)).padding - sumAdditionalSafeAreaInsets();
											startRect = rootPadding.deflateRect(startRect);
										}
									}
									return CurvedRectTween(curve: Curves.ease, begin: startRect, end: endRect);
								},
								child: MediaThumbnail(uri: file.current.file.uri, fit: BoxFit.contain)
							),
							onTap: () async {
								showGalleryPretagged(
									attachments: [TaggedAttachment(
										attachment: fakeAttachment,
										semanticParentIds: [_textFieldController.hashCode],
										imageboard: context.read<Imageboard>(),
										postId: 0
									)],
									context: context,
									overrideSources: {
										fakeAttachment: file.current.file.uri
									},
									allowChrome: true,
									allowContextMenu: true,
									allowScroll: false,
									heroOtherEndIsBoxFitCover: false
								);
							}
						)
					)
				]
			)
		);
	}

	Widget _buildOptions(BuildContext context) {
		final settings = context.watch<Settings>();
		final imageboard = context.watch<Imageboard>();
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
								minimumSize: Size.zero,
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
								minimumSize: Size.zero,
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
					if (site.supportsWebPostingFallback) Padding(
						padding: const EdgeInsets.only(left: 8),
						child: AdaptiveThinButton(
							padding: const EdgeInsets.all(4),
							onPressed: (_attachmentProgress != null || (!kDebugMode && _textIsEmpty && _attachments.isEmpty)) ? null : () async {
								if (!await _handleMultiFileResizing()) {
									return;
								}
								final draft = _makeDraft();
								draft.name = _nameFieldController.text;
								final board = imageboard.persistence.getBoard(widget.board.s);
								final (currentFiles, nextFiles) = draft.splitFiles(board);
								draft.files = currentFiles;
								final encoded = await site.encodePostForWeb(draft);
								if (encoded == null) {
									throw Exception('Post was not encoded');
								}
								if (!context.mounted) {
									return;
								}
								bool submitted = false;
								final receipt = await Navigator.of(context, rootNavigator: true).push<PostReceipt>(adaptivePageRoute(
									useFullWidthGestures: false, // Some captchas have sliding thing
									builder: (context) => CookieBrowser(
										initialUrl: Uri.parse(site.getWebUrl(board: widget.board.s, threadId: widget.threadId)),
										formFields: encoded.fields,
										javascript: encoded.javascript,
										onFormSubmitted: (fields) {
											submitted = true;
										},
										onLoadStop: (url) async {
											if (!submitted) {
												return;
											}
											final decoded = await site.decodeUrl(url);
											if (decoded == null || !context.mounted) {
												return;
											}
											final threadId = decoded.threadId;
											if (threadId != null && (decoded.postId != null || draft.threadId == null)) {
												Navigator.pop(context, PostReceipt(
													password: encoded.password,
													id: decoded.postId ?? threadId,
													name: draft.name ?? '',
													options: draft.options ?? '',
													time: DateTime.now(),
													post: draft
												));
											}
										}
									)
								));
								if (receipt != null) {
									await imageboard.didSubmitPost(draft, receipt);
									if (nextFiles.isNotEmpty) {
										// Not as easy to reassemble attachment objects. Just remove by order.
										for (int i = 0; i < draft.files.length; i++) {
											_attachments.removeAt(0).dispose();
										}
										if (widget.threadId != null) {
											// Additional reply in same thread, put it in the reply box
											_textFieldController.text = '>>${receipt.id}';
											_didUpdateDraft();
											_updateNeededPosts();
										}
										else {
											// Additional post(s) needed in the newly created thread
											// Add it as the current draft (no auto submission as we are in web posting flow)
											final nextPost = _makeDraft();
											nextPost.threadId = receipt.id;
											nextPost.name = _nameFieldController.text;
											nextPost.subject = null;
											final threadState = imageboard.persistence.getThreadState(ThreadIdentifier(widget.board.s, receipt.id));
											threadState.draft = nextPost;
											_reset();
										}
									}
									else {
										_reset();
									}
									widget.onReplyPosted(draft.board, receipt);
									mediumHapticFeedback();
									_rootFocusNode.unfocus();
									if (Settings.instance.closeReplyBoxAfterSubmitting) {
										hideReplyBox();
									}
								}
							},
							child: const Row(
								mainAxisSize: MainAxisSize.min,
								children: [
									Icon(CupertinoIcons.globe),
									SizedBox(width: 4),
									Icon(CupertinoIcons.paperplane)
								]
							)
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
									ImageboardSiteLoginSystemIcon(
										loginSystem: site.loginSystem
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

	Widget _buildProposedAttachment(BuildContext context) => Container(
		padding: const EdgeInsets.all(8),
		height: 64,
		child: _proposedAttachmentUrl == null ? const SizedBox() : Row(
			mainAxisAlignment: MainAxisAlignment.spaceEvenly,
			children: [
				if (_proposedAttachmentUrl != null) Padding(
					padding: const EdgeInsets.all(8),
					child: _proposedAttachmentUrl!.size > 4e6 /* 4 MB */ ? const SizedBox(
						// Image is large, don't eagerly show it
						width: 100,
						child: Icon(CupertinoIcons.exclamationmark_shield)
					) : ClipRRect(
						borderRadius: const BorderRadius.all(Radius.circular(8)),
						child: Image.network(
							_proposedAttachmentUrl!.imageUrl,
							width: 100
						)
					)
				),
				Flexible(child: AdaptiveFilledButton(
					padding: const EdgeInsets.all(4),
					child: Text.rich(TextSpan(
							children: [
								const TextSpan(text: 'Attach file from link?\n'),
								TextSpan(
									text: (_proposedAttachmentUrl?.text).toString(),
									style: TextStyle(
										color: ChanceTheme.backgroundColorOf(context).withValues(alpha: 0.7),
										fontSize: 14
									)
								)
							]
					), textAlign: TextAlign.center),
					onPressed: () async {
						final proposed = _proposedAttachmentUrl;
						if (proposed == null) {
							return;
						}
						try {
							if (proposed.size > 4e6 /* 4 MB */) {
								// Make sure they really want to download this big image
								final ok = await confirm(context, 'Really download this ${formatFilesize(proposed.size)} file?');
								if (!context.mounted || !ok) {
									return;
								}
							}
							final newFile = await downloadToShareCache(
								context: context,
								url: Uri.parse(proposed.imageUrl)
							);
							if (newFile == null) {
								return;
							}
							await _addAttachment(newFile);
							if (proposed.text == proposed.imageUrl) {
								final original = _textFieldController.text;
								final replaced = original.replaceFirst(proposed.text, '');
								if (replaced.length != _textFieldController.text.length) {
									_textFieldController.text = replaced;
									if (context.mounted) {
										showToast(
											context: context,
											icon: CupertinoIcons.link,
											message: 'Removed URL from text',
											easyButton: ('Restore', () {
												// To prevent "finding" the same URL again
												_lastFoundUrl = proposed.text;
												_textFieldController.text = original;
											})
										);
									}
								}
							}
							_proposedAttachmentUrl = null;
							setState(() {});
						}
						catch (e, st) {
							print(e);
							print(st);
							if (context.mounted) {
								alertError(context, e, st);
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
	);

	Widget _buildTextField(BuildContext context) {
		final board = context.read<Persistence>().getBoard(widget.board.s);
		final site = context.watch<ImageboardSite>();
		final subjectCharacterLimit = site.subjectCharacterLimit;
		final snippets = site.getBoardSnippets(widget.board.s);
		const infiniteLimit = 1 << 50;
		final settings = context.watch<Settings>();
		final postingPost = this.postingPost.value;
		return CallbackShortcuts(
			bindings: {
				LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.enter): _submit,
				LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyV): () async {
					if (await doesClipboardContainImage() && context.mounted) {
						try {
							final image = await getClipboardImageAsFile(context);
							if (image != null) {
								_addAttachment(image);
							}
						}
						catch (e, st) {
							if (!context.mounted) return;
							alertError(context, e, st);
						}
					}
				}
			},
			child: Container(
				padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
				child: Column(
					mainAxisSize: MainAxisSize.min,
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
							child: ConstrainedBox(
								constraints: BoxConstraints(
									minHeight: settings.replyBoxHeightOffset + 100
								),
								child: IntrinsicHeight(
									child: WidgetDecoration(
										// ignore: sort_child_properties_last
										child: Padding(
											padding: settings.materialStyle ? const EdgeInsets.only(top: 4) : EdgeInsets.zero,
											child: AdaptiveTextField(
												key: _textFieldKey,
												enabled: !loading,
												enableIMEPersonalizedLearning: settings.enableIMEPersonalizedLearning,
												smartDashesType: SmartDashesType.disabled,
												smartQuotesType: SmartQuotesType.disabled,
												controller: _textFieldController,
												autofocus: widget.fullyExpanded,
												contentInsertionConfiguration: ContentInsertionConfiguration(
													onContentInserted: (content) async {
														try {
															final data = content.data;
															if (data == null) {
																return;
															}
															if (data.isEmpty) {
																return;
															}
															String filename = Uri.parse(content.uri).pathSegments.last;
															if (!filename.contains('.')) {
																filename += '.${content.mimeType.afterLast('/')}';
															}
															final f = Persistence.shareCacheDirectory.file('${DateTime.now().millisecondsSinceEpoch}/$filename');
															await f.create(recursive: true);
															await f.writeAsBytes(data, flush: true);
															await _addAttachment(f);
														}
														catch (e, st) {
															if (context.mounted) {
																alertError(context, e, st);
															}
														}
													}
												),
												spellCheckConfiguration: !settings.enableSpellCheck || (isOnMac && isDevelopmentBuild) ? null : const SpellCheckConfiguration(),
												contextMenuBuilder: (context, editableTextState) => AdaptiveTextSelectionToolbar.buttonItems(
													anchors: editableTextState.contextMenuAnchors,
													buttonItems: [
														...editableTextState.contextMenuButtonItems.map((item) {
															if (item.type == ContextMenuButtonType.paste) {
																return item.copyWith(
																	onPressed: () async {
																		if (!await _handleImagePaste(manual: false)) {
																			// Only paste text if image wasn't pasted
																			item.onPressed?.call();
																		}
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
												textAlignVertical: TextAlignVertical.top,
												// The ListView eats bottom padding, we need to re-add it
												// for auto-scroll hint to work
												scrollPadding:
													const EdgeInsets.all(20) +
													EdgeInsets.only(
														bottom: MediaQuery.paddingOf(this.context).bottom
													),
												scrollPhysics: const NeverScrollableScrollPhysics(),
												expands: true,
												minLines: null,
												maxLines: null,
												focusNode: _textFocusNode,
												textCapitalization: TextCapitalization.sentences,
												keyboardAppearance: ChanceTheme.brightnessOf(context),
											)
										),
										position: DecorationPosition.foreground,
										decoration: postingPost != null ? Wrap(
											direction: Axis.vertical,
											spacing: 8,
											runSpacing: 8,
											alignment: WrapAlignment.center,
											runAlignment: WrapAlignment.center,
											crossAxisAlignment: WrapCrossAlignment.center,
											children: [
												AnimatedBuilder(
													animation: Outbox.instance,
													builder: (context, _) {
														final queue = Outbox.instance.queues[(context.watch<Imageboard>().key, widget.board, widget.threadId == null ? ImageboardAction.postThread : ImageboardAction.postReply)];
														if (queue == null) {
															return const SizedBox.shrink();
														}
														return AnimatedBuilder(
															animation: queue,
															builder: (context, _) {
																return AnimatedBuilder(
																	animation: postingPost,
																	builder: (context, _) {
																		final pair = postingPost.pair;
																		if (pair == null) {
																			return const SizedBox.shrink();
																		}
																		final time = pair.deadline;
																		return AdaptiveThinButton(
																			backgroundFilled: true,
																			onPressed: () => pair.action(context),
																			padding: const EdgeInsets.all(8),
																			child: Row(
																				mainAxisSize: MainAxisSize.min,
																				children: [
																					Text('${pair.label} '),
																					GreedySizeCachingBox(
																						alignment: Alignment.centerRight,
																						child: TimedRebuilder(
																							interval: () => const Duration(seconds: 1),
																							function: () => formatDuration(time.difference(DateTime.now()).clampAboveZero),
																							builder: (context, delta) => Text(
																								'($delta)',
																								style: CommonTextStyles.tabularFigures
																							)
																						)
																					)
																				]
																			)
																		);
																	}
																);
															}
														);
													}
												),
												AdaptiveThinButton(
													padding: const EdgeInsets.all(8),
													onPressed: _postInBackground,
													backgroundFilled: true,
													child: const Row(
														mainAxisSize: MainAxisSize.min,
														children: [
															Icon(CupertinoIcons.tray_arrow_up, size: 16),
															SizedBox(width: 8),
															Text('Post in background')
														]
													)
												)
											]
										) : const SizedBox.shrink()
									)
								)
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
		final board = imageboard.persistence.getBoard(widget.board.s);
		final emotes = imageboard.site.getEmotes();
		final snippets = context.read<ImageboardSite>().getBoardSnippets(widget.board.s);
		final defaultTextStyle = DefaultTextStyle.of(context).style;
		final settings = context.watch<Settings>();
		return Row(
			mainAxisAlignment: MainAxisAlignment.end,
			children: [
				Expanded(
					child: ListView(
						scrollDirection: Axis.horizontal,
						reverse: true,
						children: [
							for (final snippet in snippets) GestureDetector(
								onLongPress: loading ? null : () {
									if (_textFieldController.selection.isCollapsed) {
										// No selection
										return;
									}
									_insertText(snippet.wrap(_textFieldController.selection.textInside(_textFieldController.text)), addNewlineIfAtEnd: false, initialSelection: _textFieldController.selection);
								},
								child: AdaptiveIconButton(
									onPressed: loading ? null : () async {
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
															final post = Post(
																board: '',
																text: '',
																name: '',
																time: DateTime.now(),
																threadId: 0,
																id: 0,
																spanFormat: PostSpanFormat.stub,
																attachments_: []
															);
															showAdaptiveDialog<bool>(
																context: context,
																barrierDismissible: true,
																builder: (context) => AdaptiveAlertDialog(
																	title: Text('${snippet.name} preview'),
																	content: ChangeNotifierProvider<PostSpanZoneData>(
																		create: (context) => PostSpanRootZoneData(
																			imageboard: imageboard,
																			thread: Thread(posts_: [post], attachments: [], replyCount: 0, imageCount: 0, id: 0, board: '', title: '', isSticky: false, time: post.time),
																			semanticRootIds: [-14],
																			style: PostSpanZoneStyle.linear
																		),
																		builder: (context, _) => DefaultTextStyle(
																			style: defaultTextStyle,
																			child: Text.rich(
																				snippet.previewBuilder!(controller.text).build(context, post, context.watch<PostSpanZoneData>(), context.watch<Settings>(), context.watch<SavedTheme>(), const PostSpanRenderOptions())
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
								)
							),
							if (_flags.isNotEmpty) Center(
								child: AdaptiveIconButton(
									onPressed: loading ? null : _pickFlag,
									icon: IgnorePointer(
										child: flag != null ? CNetworkImage(
											url: flag!.imageUrl,
											client: imageboard.site.client,
											loadStateChanged: (state) {
												if (state.extendedImageLoadState == LoadState.failed) {
													return const Icon(CupertinoIcons.flag);
												}
												return null;
											},
											cache: true,
										) : const Icon(CupertinoIcons.flag)
									)
								)
							),
							if (emotes.isNotEmpty) Center(
								child: loading ? null : AdaptiveIconButton(
									onPressed: _pickEmote,
									icon: const Icon(CupertinoIcons.smiley)
								)
							),
							if (snippets.isNotEmpty || _flags.isNotEmpty || emotes.isNotEmpty) Container(
								margin: const EdgeInsets.symmetric(horizontal: 8),
								width: 1,
								height: 32,
								color: settings.theme.primaryColorWithBrightness(0.2)
							),
							AnimatedSize(
								alignment: Alignment.centerRight,
								duration: const Duration(milliseconds: 250),
								curve: Curves.ease,
								child:  _attachmentProgress != null ? Row(
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
														valueListenable: _attachmentProgress!.$2?.progress ?? const StoppedValueListenable(null),
														builder: (context, value, _) => LinearProgressIndicator(
															value: value,
															minHeight: 20,
															valueColor: AlwaysStoppedAnimation(ChanceTheme.primaryColorOf(context)),
															backgroundColor: ChanceTheme.primaryColorOf(context).withValues(alpha: 0.2)
														)
													)
												)
											)
										)
									]
								) : Row(
									children: [
										if (_attachments.isNotEmpty) AdaptiveIconButton(
											padding: const EdgeInsets.only(left: 8, right: 8),
											onPressed: loading ? null : expandAttachmentOptions,
											icon: Row(
												mainAxisSize: MainAxisSize.min,
												children: [
													if (showAttachmentOptions)
														const Icon(CupertinoIcons.chevron_down)
													else
														const Icon(CupertinoIcons.chevron_up),
													for (final attachment in _attachments) ...[
														const SizedBox(width: 8),
														ClipRRect(
															borderRadius: BorderRadius.circular(4),
															child: ConstrainedBox(
																constraints: const BoxConstraints(
																	maxWidth: 32,
																	maxHeight: 32
																),
																child: MediaThumbnail(uri: attachment.current.file.uri, fontSize: 12)
															)
														),
													]
												]
											)
										),
										if (_attachments.isNotEmpty) Container(
											margin: const EdgeInsets.symmetric(horizontal: 8),
											width: 1,
											height: 32,
											color: settings.theme.primaryColorWithBrightness(0.2)
										),
										if (board.filesPerPost > 0) AnimatedBuilder(
											animation: attachmentSourceNotifier,
											builder: (context, _) => Row(
												mainAxisSize: MainAxisSize.min,
												children: [
													for (final file in receivedFilePaths.reversed) GestureDetector(
														onLongPress: loading ? null : () async {
															if (await confirm(context, 'Remove received file?')) {
																receivedFilePaths.remove(file);
																setState(() {});
															}
														},
														child: AdaptiveIconButton(
															onPressed: loading ? null : () => _addAttachment(File(file)),
															icon: ClipRRect(
																borderRadius: BorderRadius.circular(4),
																child: ConstrainedBox(
																	constraints: const BoxConstraints(
																		maxWidth: 32,
																		maxHeight: 32
																	),
																	child: MediaThumbnail(
																		uri: Uri.file(file)
																	)
																)
															)
														)
													),
													for (final picker in getAttachmentSources(includeClipboard: false)) GestureDetector(
														onLongPress: picker.onLongPress?.bind1(this.context),
														child: AdaptiveIconButton(
															onPressed: loading ? null : () async {
																final focusToRestore = FocusScope.of(this.context).focusedChild;
																_attachmentProgress = ('Picking', null);
																setState(() {});
																// Local [context] is not safe. It will die when we go to 'Picking'
																try {
																	final paths = await picker.pick(this.context, true);
																	if (paths.isNotEmpty) {
																		for (final path in paths) {
																			await _addAttachment(File(path));
																		}
																	}
																	else {
																		_attachmentProgress = null;
																	}
																}
																catch (e, st) {
																	Future.error(e, st);
																	// Local [context] is not safe. It will die when we go to 'Picking'
																	final context = this.context;
																	if (context.mounted) {
																		alertError(context, e, st);
																	}
																	_attachmentProgress = null;
																}
																focusToRestore?.requestFocus();
																if (mounted) {
																	setState(() {});
																}
															},
															icon: Transform.scale(
																scale: picker.iconSizeMultiplier,
																child: Icon(picker.icon)
															)
														)
													)
												]
											)
										)
									]
								)
							)
						].reversed.toList()
					)
				),
				AdaptiveIconButton(
					onPressed: loading ? null : expandOptions,
					icon: const Icon(CupertinoIcons.gear)
				),
				if (_submittingPosts.isNotEmpty) AdaptiveIconButton(
					icon: StationaryNotifyingIcon(
						icon: Icon(_showSubmittingPosts ? CupertinoIcons.tray_arrow_down : CupertinoIcons.tray_arrow_up, size: 20),
						primary: _showSubmittingPosts ? 0 : _submittingPosts.length
					),
					onPressed: () {
						setState(() {
							_showSubmittingPosts = !_showSubmittingPosts;
						});
					}
				),
				GestureDetector(
					onLongPress: loading ? null : () {
						// Save as draft
						final persistence = context.read<Persistence>();
						final post = _makeDraft();
						post.name = _nameFieldController.text;
						persistence.browserState.outbox.add(post);
						runWhenIdle(const Duration(milliseconds: 500), persistence.didUpdateBrowserState);
						final entry = Outbox.instance.submitPost(imageboard.key, post, QueueStateIdle());
						_submittingPosts.add(entry);
						_listenToReplyPosting(entry);
						draft = null; // Clear
						widget.onDraftChanged(null);
						showToast(
							context: context,
							icon: CupertinoIcons.tray_arrow_up,
							message: 'Saved draft'
						);
						setState(() {});
					},
					child: Opacity(
						opacity: widget.isArchived ? 0.5 : 1,
						child: AdaptiveIconButton(
							onPressed: _attachmentProgress != null ? null : (loading ? _cancel : switch ((kDebugMode, _textIsEmpty, _attachments)) {
								// Don't allow empty post in release mode
								(false, true, []) => null,
								_ => _submit
							}),
							icon: Row(
								mainAxisSize: MainAxisSize.min,
								children: [
									const SizedBox(width: 8),
									if (widget.isArchived) const Text('Thread is archived'),
									if (loading) const Icon(CupertinoIcons.xmark)
									else ...[
										const Icon(CupertinoIcons.paperplane),
										if (_neededPosts > 1) Text(' ($_neededPosts)')
									],
									const SizedBox(width: 8)
								]
							)
						)
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
			draft.files.isNotEmpty ||
			draft.flag != null ||
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
		if (_nameFieldController.text.isNotEmpty || _optionsFieldController.text.isNotEmpty || (_disableLoginSystem && hasLoginSystem)) {
			setState(() {_showOptions = true;});
		}
		// Delete that draft from the outbox
		if (deleteOriginal) {
			entry.delete();
		}
		// Add the old content as a draft to the outbox, if non-trivial
		if (_isNonTrivial(old) && old != entry.post) {
			Outbox.instance.submitPost(context.read<Imageboard>().key, old, QueueStateIdle());
		}
		setState(() {});
	}

	@override
	Widget build(BuildContext context) {
		_chanTabs = context.watchIdentity<ChanTabs?>();
		final settings = context.watch<Settings>();
		return Focus(
			focusNode: _rootFocusNode,
			child: TransformedMediaQuery(
				transformation: (context, mq) => mq.removePadding(
					removeTop: true,
					removeBottom: true
				),
				child: PrototypeLayoutWidget(
					prototype: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							 _buildQueueButton(),
							Expander(
								expanded: _showSubmittingPosts,
								curve: Curves.ease,
								bottomSafe: true,
								child: _buildSubmittingPosts()
							),
							Expander(
								expanded: show && showAttachmentOptions,
								bottomSafe: true,
								curve: Curves.ease,
								child: Focus(
									descendantsAreFocusable: showAttachmentOptions && show,
									child: Column(
										mainAxisSize: MainAxisSize.min,
										children: [
											for (final attachment in _attachments)
												_buildAttachmentOptions(context, attachment)
										]
									)
								)
							),
							Expander(
								expanded: show && showOptions,
								bottomSafe: true,
								curve: Curves.ease,
								child: _buildOptions(context)
							),
							Expander(
								expanded: show && _proposedAttachmentUrl != null,
								bottomSafe: true,
								curve: Curves.ease,
								child: _buildProposedAttachment(context)
							),
							Flexible(
								child: Expander(
									expanded: show,
									bottomSafe: true,
									curve: Curves.ease,
									child: SizedBox(
										height:
											((widget.threadId == null) ?
												150 + (settings.materialStyle ? 18 : 0) :
												108)
											+ 32 // Button row
											+ 8 // Padding
											+ MediaQuery.viewInsetsOf(context).bottom
											+ settings.replyBoxHeightOffset
									)
								)
							)
						]
					),
					child: MaybeScrollbar(
						child: CustomScrollView(
							primary: false,
							shrinkWrap: true,
							// This will override default AlwaysScrollable
							physics: ScrollConfiguration.of(context).getScrollPhysics(context),
							slivers: [
								SliverToBoxAdapter(
									child: _buildQueueButton()
								),
								SliverToBoxAdapter(
									child: Expander(
										expanded: _showSubmittingPosts,
										bottomSafe: true,
										child: _buildSubmittingPosts()
									)
								),
								SliverToBoxAdapter(
									child: Expander(
										expanded: showAttachmentOptions && show,
										bottomSafe: true,
										child: Focus(
											descendantsAreFocusable: showAttachmentOptions && show,
											child: ReorderableListView(
												shrinkWrap: true,
												primary: false,
												// Default proxyDecorator causes font size to jump (change in Material.elevation I guess?)
												proxyDecorator: (child, index, animation) => AnimatedBuilder(
													animation: animation,
													builder: (BuildContext context, Widget? child) {
														final double animValue = Curves.easeInOut.transform(animation.value);
														return ClipRect(
															child: ColorFiltered(
																colorFilter: ColorFilter.mode(
																	settings.theme.primaryColor.withValues(alpha: 0.1 * animValue),
																	BlendMode.srcOver
																),
																child: child
															)
														);
													},
													child: child,
												),
												onReorder: (oldIndex, newIndex) {
													if (oldIndex < newIndex) {
														newIndex -= 1;
													}
													final item = _attachments.removeAt(oldIndex);
													_attachments.insert(newIndex, item);
													setState(() {});
													_didUpdateDraft();
													_updateNeededPosts();
												},
												children: [
													for (final (i, attachment) in _attachments.indexed)
														ReorderableDelayedDragStartListener(
															index: i,
															enabled: _attachments.length > 1,
															key: ValueKey(attachment),
															child: _buildAttachmentOptions(context, attachment)
														)
												]
											)
										)
									)
								),
								SliverToBoxAdapter(
									child: Expander(
										expanded: showOptions && show,
										bottomSafe: true,
										child: Focus(
											descendantsAreFocusable: showOptions && show,
											child: _buildOptions(context)
										)
									)
								),
								SliverToBoxAdapter(
									child: Expander(
										expanded: show && _proposedAttachmentUrl != null,
										bottomSafe: true,
										child: _buildProposedAttachment(context)
									)
								),
								PinnedHeaderSliver(
									child: Expander(
										expanded: show,
										bottomSafe: true,
										child: GestureDetector(
											behavior: HitTestBehavior.translucent,
											supportedDevices: const {
												PointerDeviceKind.mouse,
												PointerDeviceKind.stylus,
												PointerDeviceKind.invertedStylus,
												PointerDeviceKind.touch,
												PointerDeviceKind.unknown
											},
											onVerticalDragStart: (event) {
												_replyBoxHeightOffsetAtPanStart = settings.replyBoxHeightOffset;
												_panStartDy = event.globalPosition.dy;
											},
											onVerticalDragUpdate: (event) {
												final view = PlatformDispatcher.instance.views.first;
												final r = view.devicePixelRatio;
												setState(() {
													_willHideOnPanEnd = ((view.physicalSize.height / r) - event.globalPosition.dy) < (view.viewInsets.bottom / r);
													if (!_willHideOnPanEnd && (event.globalPosition.dy < _panStartDy || settings.replyBoxHeightOffset >= -50)) {
														// touch not above keyboard
														settings.replyBoxHeightOffset = (settings.replyBoxHeightOffset - event.delta.dy).clamp(-50, _maxReplyBoxHeight);
													}
												});
											},
											onVerticalDragEnd: (event) {
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
													border: Border(top: BorderSide(color: ChanceTheme.primaryColorWithBrightness20Of(context))),
													color: ChanceTheme.backgroundColorOf(context)
												),
												height: 40,
												child: _buildButtons(context),
											)
										)
									)
								),
								SliverToBoxAdapter(
									child: Expander(
										expanded: show,
										bottomSafe: !show,
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
																backgroundColor: ChanceTheme.primaryColorOf(context).withValues(alpha: 0.7)
															)
														)
													)
												]
											)
										)
									)
								)
							]
						)
					)
				)
			)
		);
	}

	@override
	void dispose() {
		super.dispose();
		if (_show) {
			Future.microtask(() => _chanTabs?.didCloseReplyBox());
		}
		if (postingPost.value != null) {
			// Since we didn't clear out the reply field yet. Just send a fake draft above.
			if (_optionsFieldController.text.isNotEmpty || _disableLoginSystem) {
				// A few things we have to save
				widget.onDraftChanged(DraftPost(
					board: widget.board.s,
					threadId: widget.threadId,
					name: null,
					options: _optionsFieldController.text,
					text: '',
					useLoginSystem: switch (_disableLoginSystem) {
						true => false,
						false => null
					},
					files: []
				));
			}
			else {
				// Just wipe out the draft
				widget.onDraftChanged(null);
			}
		}
		_textFieldController.dispose();
		_nameFieldController.dispose();
		_subjectFieldController.dispose();
		_optionsFieldController.dispose();
		for (final attachment in _attachments) {
			attachment.dispose();
		}
		_textFocusNode.dispose();
		_rootFocusNode.dispose();
		for (final controller in _snippetControllers.values) {
			controller.dispose();
		}
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
				site: context.read<ImageboardSite>(),
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

enum _ReplyBoxLayoutId {
	body,
	replyBox
}

class _ReplyBoxLayoutDelegate extends MultiChildLayoutDelegate {
	final double topPadding;
	final double bottomPadding;

	_ReplyBoxLayoutDelegate({
		required this.topPadding,
		required this.bottomPadding
	});

	@override
	void performLayout(Size size) {
		final replyBoxSize = layoutChild(_ReplyBoxLayoutId.replyBox, BoxConstraints(
			minWidth: size.width,
			maxWidth: size.width,
			maxHeight: size.height - topPadding - bottomPadding
		));
		final threadHeight = size.height - replyBoxSize.height;
		positionChild(_ReplyBoxLayoutId.replyBox, Offset(0, threadHeight - bottomPadding));
		layoutChild(_ReplyBoxLayoutId.body, BoxConstraints.tightFor(
			width: size.width,
			height: threadHeight
		));
		// Body is already at 0,0 (default)
	}

	@override
	bool shouldRelayout(_ReplyBoxLayoutDelegate oldDelegate) {
		return topPadding != oldDelegate.topPadding
							|| bottomPadding != oldDelegate.bottomPadding;
	}
}

class ReplyBoxLayout extends StatelessWidget {
	final Widget body;
	final Widget replyBox;

	const ReplyBoxLayout({
		required this.body,
		required this.replyBox,
		super.key
	});

	@override
	Widget build(BuildContext context) {
		final padding = MediaQuery.paddingOf(context);
		return CustomMultiChildLayout(
			delegate: _ReplyBoxLayoutDelegate(
				topPadding: padding.top + 80, // Don't let thread get so small
				bottomPadding: padding.bottom
			),
			children: [
				LayoutId(
					id: _ReplyBoxLayoutId.body,
					child: body
				),
				LayoutId(
					id: _ReplyBoxLayoutId.replyBox,
					child: replyBox
				)
			]
		);
	}
}

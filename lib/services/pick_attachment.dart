// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/pages/web_image_picker.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/saved_attachment_thumbnail.dart';
import 'package:chan/widgets/util.dart';
import 'package:chan/services/clipboard_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

final List<String> receivedFilePaths = [];

Future<File?> pickAttachment({
	required BuildContext context
}) async {
	final picker = ImagePicker();
	final savedAttachments = context.read<Persistence>().savedAttachments.values.toList();
	savedAttachments.sort((a, b) => b.savedTime.compareTo(a.savedTime));
	final sources = (Platform.isIOS || Platform.isAndroid || kIsWeb) ? [
		if ((Platform.isAndroid) || (Platform.isIOS && await doesClipboardContainImage())) Tuple3('Clipboard', CupertinoIcons.doc_on_clipboard, () => getClipboardImageAsFile().then((x) {
			if (x == null) {
				showToast(
					context: context,
					message: 'No image in clipboard',
					icon: CupertinoIcons.xmark
				);
			}
			return x?.path;
		})),
		Tuple3('Pick photo', CupertinoIcons.photo, () => FilePicker.platform.pickFiles(type: FileType.image).then((x) => x?.files.single.path)),
		Tuple3('Pick video', CupertinoIcons.play_rectangle, () => FilePicker.platform.pickFiles(type: FileType.video).then((x) => x?.files.single.path)),
		Tuple3('Pick file', CupertinoIcons.doc, () => FilePicker.platform.pickFiles(type: FileType.any).then((x) => x?.files.single.path)),
		Tuple3('Take photo', CupertinoIcons.camera, () => picker.pickImage(source: ImageSource.camera).then((x) => x?.path)),
		Tuple3('Take video', CupertinoIcons.videocam, () => picker.pickVideo(source: ImageSource.camera).then((x) => x?.path)),
		Tuple3('Web search', Icons.image_search, () => Navigator.of(context, rootNavigator: true).push<File>(CupertinoModalPopupRoute(
			builder: (context) => const WebImagePickerPage()
		)).then((x) => x?.path))
	] : [
		Tuple3('Pick file', CupertinoIcons.doc, () => FilePicker.platform.pickFiles().then((x) => x?.files.single.path))
	];
	bool loadingPick = false;
	return Navigator.of(context).push<File>(TransparentRoute(
		builder: (context) => StatefulBuilder(
			builder: (context, setPickerDialogState) => OverscrollModalPage(
				child: Container(
					width: double.infinity,
					padding: const EdgeInsets.all(16),
					color: CupertinoTheme.of(context).scaffoldBackgroundColor,
					child: Stack(
						children: [
							GridView.builder(
								gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
									maxCrossAxisExtent: 100,
									mainAxisSpacing: 16,
									crossAxisSpacing: 16,
									childAspectRatio: 1
								),
								shrinkWrap: true,
								physics: const NeverScrollableScrollPhysics(),
								itemCount: sources.length + receivedFilePaths.length + savedAttachments.length,
								itemBuilder: (context, i) {
									if (i < sources.length) {
										final entry = sources[i];
										return GestureDetector(
											onTap: () async {
												loadingPick = true;
												setPickerDialogState(() {});
												try {
													final path = await entry.item3();
													loadingPick = false;
													setPickerDialogState(() {});
													if (path != null) {
														Navigator.of(context).pop<File>(File(path));
													}
												}
												catch (e) {
													alertError(context, e.toStringDio());
													loadingPick = false;
													setPickerDialogState(() {});
												}
											},
											child: Container(
												decoration: BoxDecoration(
													color: CupertinoTheme.of(context).primaryColor,
													borderRadius: BorderRadius.circular(8)
												),
												padding: const EdgeInsets.all(8),
												child: Column(
													mainAxisAlignment: MainAxisAlignment.center,
													children: [
														Icon(entry.item2, size: 40, color: CupertinoTheme.of(context).scaffoldBackgroundColor),
														Flexible(
															child: AutoSizeText(entry.item1, minFontSize: 5, style: TextStyle(color: CupertinoTheme.of(context).scaffoldBackgroundColor), textAlign: TextAlign.center)
														)
													]
												)
											)
										);
									}
									else if (i < (sources.length + receivedFilePaths.length)) {
										// Reverse order
										final file = File(receivedFilePaths[(receivedFilePaths.length - 1) - (i - sources.length)]);
										return GestureDetector(
											onTap: () {
												Navigator.of(context).pop(file);
											},
											child: ClipRRect(
												borderRadius: BorderRadius.circular(8),
												child: SavedAttachmentThumbnail(file: file, fit: BoxFit.cover)
											)
										);
									}
									else {
										final attachment = savedAttachments[i - sources.length - receivedFilePaths.length];
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
							),
							if (loadingPick) Positioned.fill(
								child: Container(
									color: CupertinoTheme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
									child: const CupertinoActivityIndicator()
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
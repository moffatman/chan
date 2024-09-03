import 'dart:io';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/pages/web_image_picker.dart';
import 'package:chan/services/apple.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/saved_attachment_thumbnail.dart';
import 'package:chan/widgets/util.dart';
import 'package:chan/services/clipboard_image.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

final List<String> receivedFilePaths = [];
final attachmentSourceNotifier = EasyListenable();

final supportedFileExtensions = [
	'.jpg', '.jpeg', '.png', '.gif', '.webm',
	'.heic', '.avif', '.webp',
	'.mp4', '.mov', '.m4v', '.mkv', '.mpeg', '.avi', '.3gp', '.m2ts'
];

final _timestampedFilePattern = RegExp(r'^(.*)-\d{10,}(\.[^.]+)$');

Future<String?> _stripFileTimestamp(String? path) async {
	if (!Platform.isIOS) {
		// Seems to only affect iOS
		return path;
	}
	if (path == null) {
		return null;
	}
	final match = _timestampedFilePattern.firstMatch(path);
	if (match == null) {
		// No timestamp
		return path;
	}
	// Assuming ownership of file
	final dest = '${match.group(1)}${match.group(2)}';
	await File(path).rename(dest);
	return dest;
}

Future<String?> _copyFileToSafeLocation(String? path) async {
	if (path == null) {
		return null;
	}
	if (path.startsWith('/') && path.contains('com.moffatman.chan-Inbox')) {
		// Files will be deleted from here eventually by iOS
		final parent = Directory('${Persistence.temporaryDirectory.path}/inboxcache/${DateTime.now().millisecondsSinceEpoch}');
		await parent.create(recursive: true);
		final destPath = '${parent.path}/${path.split('/').last}';
		await File(path).copy(destPath);
		return destPath;
	}
	return path;
}

Future<File?> downloadToShareCache({
	required BuildContext context,
	required Uri url
}) async {
	final client = context.read<ImageboardSite?>()?.client ?? Settings.instance.client;
	final filename = url.pathSegments.tryLast;
	final path = '${Persistence.shareCacheDirectory.path}/${DateTime.now().millisecondsSinceEpoch}_${filename ?? ''}';
	return await modalLoad(context, 'Downloading...', (controller) async {
		final alreadyCached = await getCachedImageFile(url.toString());
		if (alreadyCached != null) {
			return alreadyCached;
		}
		final token = CancelToken();
		controller.onCancel = token.cancel;
		try {
			final response = await client.downloadUri(url, path, onReceiveProgress: (received, total) {
				if (total > 0) {
					controller.progress.value = ('${formatFilesize(received)} / ${formatFilesize(total)}', received / total);
				}
				else {
					controller.progress.value = ('', null);
				}
			}, cancelToken: token);
			if (filename == null || !filename.contains('.')) {
				// No clear filename with extension from URL
				final ext = response.headers.value(Headers.contentTypeHeader)?.split('/').tryLast;
				if (ext != null) {
					// We can use MIME
					return await File(path).rename('${path}thumb.$ext');
				}
				// IDK good luck lol
			}
			return File(path);
		}
		on DioError catch (e) {
			if (e.type == DioErrorType.cancel) {
				// User cancelled, don't throw
				return null;
			}
			// Else it is a normal error
			rethrow;
		}
	}, cancellable: true, wait: const Duration(milliseconds: 50));
}

class AttachmentPickingSource {
	final String name;
	final IconData icon;
	final Future<String?> Function(BuildContext context) pick;
	final double iconSizeMultiplier;

	const AttachmentPickingSource({
		required this.name,
		required this.icon,
		required this.pick,
		this.iconSizeMultiplier = 1
	});
}

List<AttachmentPickingSource> getAttachmentSources({
	required bool includeClipboard
}) {
	final gallery = AttachmentPickingSource(
		name: 'Image Gallery',
		icon: Adaptive.icons.photo,
		pick: (context) => FilePicker.platform.pickFiles(type: FileType.image).then((x) => _stripFileTimestamp(x?.files.trySingle?.path)).then(_copyFileToSafeLocation)
	);
	final videoGallery = AttachmentPickingSource(
		name: 'Video Gallery',
		icon: CupertinoIcons.play_rectangle,
		pick: (context) => FilePicker.platform.pickFiles(type: FileType.video).then((x) => _stripFileTimestamp(x?.files.trySingle?.path)).then(_copyFileToSafeLocation)
	);
	final picker = ImagePicker();
	final camera = AttachmentPickingSource(
		name: 'Camera',
		icon: CupertinoIcons.camera,
		pick: (context) async {
			final video = await showAdaptiveDialog<bool>(
				context: context,
				barrierDismissible: true,
				builder: (context) => AdaptiveAlertDialog(
					title: const Text('Which mode?'),
					actions: {
						false: 'Photo',
						true: 'Video',
						null: 'Cancel'
					}.entries.map((e) => AdaptiveDialogAction(
						onPressed: () => Navigator.pop(context, e.key),
						child: Text(e.value)
					)).toList()
				)
			);
			if (video == null) {
				return null;
			}
			return (video ?
				picker.pickVideo(source: ImageSource.camera) :
				picker.pickImage(source: ImageSource.camera))
				.then((x) => _copyFileToSafeLocation(x?.path));
		}
	);
	final web = AttachmentPickingSource(
		name: 'Web',
		icon: CupertinoIcons.globe,
		pick: (context) => Navigator.of(context, rootNavigator: true).push<File>(CupertinoModalPopupRoute(
			builder: (_) => const WebImagePickerPage()
		)).then((x) => x?.path)
	);
	final file = AttachmentPickingSource(
		name: 'File',
		icon: CupertinoIcons.folder,
		pick: (context) => FilePicker.platform.pickFiles(type: FileType.any).then((x) => _copyFileToSafeLocation(x?.files.single.path))
	);
	final clipboard = AttachmentPickingSource(
		name: 'Clipboard',
		icon: CupertinoIcons.doc_on_clipboard,
		pick: (context) => getClipboardImageAsFile().then((x) {
			if (x == null) {
				showToast(
					context: context,
					message: 'No image in clipboard',
					icon: CupertinoIcons.xmark
				);
			}
			return x?.path;
		})
	);
	final anySaved = ImageboardRegistry.instance.imageboards.any((i) => i.persistence.savedAttachments.isNotEmpty);
	final saved = AttachmentPickingSource(
		name: 'Saved Attachments',
		icon: Adaptive.icons.bookmark,
		pick: (context) {
			final savedAttachments = ImageboardRegistry.instance.imageboardsIncludingDev.expand((i) => i.persistence.savedAttachments.values).toList();
			savedAttachments.sort((a, b) => b.savedTime.compareTo(a.savedTime));
			return Navigator.of(context).push<String>(TransparentRoute(
				builder: (context) => OverscrollModalPage.sliver(
					sliver: DecoratedSliver(
						decoration: BoxDecoration(
							color: ChanceTheme.backgroundColorOf(context)
						),
						sliver: SliverPadding(
							padding: const EdgeInsets.all(16),
							sliver: SliverGrid.builder(
								gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
									maxCrossAxisExtent: 100,
									mainAxisSpacing: 16,
									crossAxisSpacing: 16,
									childAspectRatio: 1
								),
								addAutomaticKeepAlives: false,
								addRepaintBoundaries: false,
								itemCount: savedAttachments.length,
								itemBuilder: (context, i) {
									final attachment = savedAttachments[i];
									return GestureDetector(
										onTap: () {
											Navigator.of(context).pop(attachment.file.path);
										},
										child: ClipRRect(
											borderRadius: BorderRadius.circular(8),
											child: SavedAttachmentThumbnail(file: attachment.file, fit: BoxFit.cover)
										)
									);
								}
							)
						)
					)
				)
			));
		}
	);
	if (Platform.isIOS) {
		return [
			if (anySaved) saved,
			gallery,
			videoGallery,
			file,
			web,
			if (!isOnMac) ...[
				camera,
			],
			if (includeClipboard) clipboard,
		];
	}
	else if (Platform.isAndroid) {
		return [
			if (anySaved) saved,
			gallery,
			file,
			if (includeClipboard) clipboard,
			web,
			camera,
		];
	}
	else {
		return [
			file
		];
	}
}

Future<File?> pickAttachment({
	required BuildContext context
}) async {
	final sources = getAttachmentSources(includeClipboard: true);
	bool loadingPick = false;
	final theme = context.read<SavedTheme>();
	return Navigator.of(context).push<File>(TransparentRoute(
		builder: (context) => StatefulBuilder(
			builder: (context, setPickerDialogState) => OverscrollModalPage(
				child: Container(
					width: double.infinity,
					padding: const EdgeInsets.all(16),
					color: theme.backgroundColor,
					child: Stack(
						children: [
							GridView.builder(
								gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
									maxCrossAxisExtent: 100,
									mainAxisSpacing: 16,
									crossAxisSpacing: 16,
									childAspectRatio: 1
								),
								addAutomaticKeepAlives: false,
								addRepaintBoundaries: false,
								shrinkWrap: true,
								physics: const NeverScrollableScrollPhysics(),
								itemCount: sources.length + receivedFilePaths.length,
								itemBuilder: (context, i) {
									if (i < sources.length) {
										final entry = sources[i];
										return GestureDetector(
											onTap: () async {
												loadingPick = true;
												setPickerDialogState(() {});
												try {
													final path = await entry.pick(context);
													loadingPick = false;
													setPickerDialogState(() {});
													if (path != null && context.mounted) {
														Navigator.of(context).pop<File>(File(path));
													}
												}
												catch (e, st) {
													if (context.mounted) {
														alertError(context, e, st);
													}
													loadingPick = false;
													setPickerDialogState(() {});
												}
											},
											child: Container(
												decoration: BoxDecoration(
													color: theme.primaryColor,
													borderRadius: BorderRadius.circular(8)
												),
												padding: const EdgeInsets.all(8),
												child: Column(
													mainAxisAlignment: MainAxisAlignment.center,
													children: [
														Expanded(
															child: Center(
																child: Transform.scale(
																	scale: entry.iconSizeMultiplier,
																	child: Icon(entry.icon, size: 40, color: theme.backgroundColor)
																)
															)
														),
														Expanded(
															child: Center(
																child: AutoSizeText(entry.name, minFontSize: 5, style: TextStyle(color: theme.backgroundColor), textAlign: TextAlign.center)
															)
														)
													]
												)
											)
										);
									}
									else {
										// Reverse order
										final path = receivedFilePaths[(receivedFilePaths.length - 1) - (i - sources.length)];
										final file = File(path);
										return GestureDetector(
											onTap: () {
												Navigator.of(context).pop(file);
											},
											onLongPress: () async {
												if (await confirm(context, 'Remove received file?')) {
													receivedFilePaths.remove(path);
													setPickerDialogState(() {});
												}
											},
											child: ClipRRect(
												borderRadius: BorderRadius.circular(8),
												child: SavedAttachmentThumbnail(file: file, fit: BoxFit.cover)
											)
										);
									}
								}
							),
							if (loadingPick) Positioned.fill(
								child: Container(
									color: theme.backgroundColor.withOpacity(0.5),
									child: const CircularProgressIndicator.adaptive()
								)
							)
						]
					)
				)
			)
		)
	));
}
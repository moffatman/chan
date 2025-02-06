import 'dart:io';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/pages/web_image_picker.dart';
import 'package:chan/services/apple.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/storage.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/attachment_viewer.dart';
import 'package:chan/widgets/cupertino_inkwell.dart';
import 'package:chan/widgets/media_thumbnail.dart';
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
	final stat = await File(path).stat();
	if (stat.type == FileSystemEntityType.directory) {
		if (await Directory(dest).exists()) {
			await Directory(dest).delete(recursive: true);
		}
		await Directory(path).rename(dest);
	}
	else {
		await File(path).rename(dest);
	}
	return dest;
}

Future<String?> _copyFileToSafeLocation(String? path) async {
	if (path == null) {
		return null;
	}
	// Copy to a timestamp dir. So that multiple picks will get a new path, avoid stale caching
	final parent = Directory('${Persistence.temporaryDirectory.path}/inboxcache/${DateTime.now().millisecondsSinceEpoch}');
	await parent.create(recursive: true);
	final destPath = '${parent.path}/${path.split('/').last}';
	final stat = await File(path).stat();
	if (stat.type == FileSystemEntityType.directory) {
		if (await Directory(destPath).exists()) {
			await Directory(destPath).delete(recursive: true);
		}
		await Directory(path).copy(destPath);
	}
	else {
		await File(path).copy(destPath);
	}
	return destPath;
}

Future<File?> downloadToShareCache({
	required BuildContext context,
	required Uri url
}) async {
	final client =
		ImageboardRegistry.instance.imageboards.tryFirstWhere((i) => i.site.imageUrl == url.host)?.site.client ??
		context.read<ImageboardSite?>()?.client ??
		Settings.instance.client;
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
	final Future<void> Function(BuildContext context)? onLongPress;
	final double iconSizeMultiplier;

	const AttachmentPickingSource({
		required this.name,
		required this.icon,
		required this.pick,
		this.onLongPress,
		this.iconSizeMultiplier = 1
	});
}

Future<String?> chooseAndroidPicker(BuildContext context) async {
	if (!Platform.isAndroid) {
		return '';
	}
	final list = await getPickerList();
	if (list.isEmpty) {
		// Use default
		return '';
	}
	if (list.length == 1) {
		return list.single.package;
	}
	if (context.mounted) {
		return await showAdaptiveModalPopup<String>(
			context: context,
			builder: (context) => AdaptiveActionSheet(
				title: const Text('Choose gallery picker'),
				actions: list.map((intent) => AdaptiveActionSheetAction(
						onPressed: () => Navigator.pop(context, intent.package),
						trailing: switch (intent.icon) {
							MemoryImage image => Image(
								image: image,
								width: 30,
								height: 30
							),
							null => null
						},
						child: Text(intent.label)
				)).toList(),
				cancelButton: AdaptiveActionSheetAction(
					child: const Text('Cancel'),
					onPressed: () => Navigator.pop(context)
				)
			)
		);
	}
	return null;
}

List<AttachmentPickingSource> getAttachmentSources({
	required bool includeClipboard
}) {
	final gallery = AttachmentPickingSource(
		name: 'Gallery',
		icon: Adaptive.icons.photo,
		pick: (context) async {
			String? androidPackage;
			if (Platform.isAndroid) {
				try {
					androidPackage = Settings.instance.androidGalleryPicker ??= await chooseAndroidPicker(context);
					if (androidPackage == null) {
						// User cancelled
						return null;
					}
				}
				catch (e, st) {
					// Who knows what could go wrong here. Don't break the picker, just fallback to default picker (null)
					Future.error(e, st); // crashlytics
				}
			}
			final result = await FilePicker.platform.pickFiles(
				type: FileType.media,
				compressionQuality: 0,
				allowCompression: false,
				androidPackage: androidPackage?.nonEmptyOrNull
			);
			final path = await _stripFileTimestamp(result?.files.trySingle?.path);
			return _copyFileToSafeLocation(path);
		},
		onLongPress: (context) async {
			final choice = await chooseAndroidPicker(context);
			if (choice != null) {
				Settings.instance.androidGalleryPicker = choice;
				if (context.mounted) {
					showToast(
						context: context,
						icon: Adaptive.icons.photo,
						message: 'Media picker chosen'
					);
				}
			}
		}
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
		pick: (context) => FilePicker.platform.pickFiles(type: FileType.any, compressionQuality: 0, allowCompression: false).then((x) => _copyFileToSafeLocation(x?.files.single.path))
	);
	final clipboard = AttachmentPickingSource(
		name: 'Clipboard',
		icon: CupertinoIcons.doc_on_clipboard,
		pick: (context) => getClipboardImageAsFile().then((x) {
			if (x == null && context.mounted) {
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
			final key = GlobalKey<OverscrollModalPageState>();
			return Navigator.of(context).push<String>(TransparentRoute(
				builder: (context) => OverscrollModalPage.sliver(
					key: key,
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
										onLongPress: () {
											showGallery(
												initialAttachment: attachment.attachment,
												context: context,
												attachments: savedAttachments.map((a) => a.attachment).toList(),
												semanticParentIds: [-999],
												overrideSources: {
													for (final l in savedAttachments)
														l.attachment: l.file.uri
												},
												onChange: (a) {
													key.currentState!.animateToProportion(savedAttachments.indexWhere((s) => s.attachment == a) / savedAttachments.length);
												},
												heroOtherEndIsBoxFitCover: false
											);
										},
										child: CupertinoInkwell(
											padding: EdgeInsets.zero,
											onPressed: () {
												Navigator.of(context).pop(attachment.file.path);
											},
											child: ClipRRect(
												borderRadius: BorderRadius.circular(8),
												child: Hero(
													tag: TaggedAttachment(
														attachment: attachment.attachment,
														semanticParentIds: [-999]
													),
													child: MediaThumbnail(
														uri: attachment.file.uri,
														fit: BoxFit.contain
													),
													flightShuttleBuilder: (context, animation, direction, fromContext, toContext) {
														return (direction == HeroFlightDirection.push ? fromContext.widget as Hero : toContext.widget as Hero).child;
													},
													createRectTween: (startRect, endRect) {
														if (startRect != null && endRect != null) {
															if (attachment.attachment.type == AttachmentType.image) {
																// Need to deflate the original startRect because it has inbuilt layoutInsets
																// This SavedAttachmentThumbnail will always fill its size
																final rootPadding = MediaQueryData.fromView(View.of(context)).padding - sumAdditionalSafeAreaInsets();
																startRect = rootPadding.deflateRect(startRect);
															}
														}
														return CurvedRectTween(curve: Curves.ease, begin: startRect, end: endRect);
													}
												)
											)
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
											onLongPress: bind1(entry.onLongPress, context),
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
												child: MediaThumbnail(uri: file.uri, fit: BoxFit.cover)
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
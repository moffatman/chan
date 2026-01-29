import 'dart:io';

import 'package:chan/services/base64_image.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

const _platform = MethodChannel('com.moffatman.chan/storage');

const kGallerySavePathGalleryPrefix = 'gallery://';

Future<String?> pickDirectory() async {
	if (Platform.isAndroid || Platform.isIOS) {
		return await _platform.invokeMethod('pickDirectory');
	}
	else {
		throw UnsupportedError('Platform not supported');
	}
}

Future<String?> pickGallerySavePath(BuildContext context, {List<SaveAsDestination>? menuDestinations}) async {
	if (Platform.isIOS) {
		final menuChoices = (menuDestinations == null || menuDestinations.isEmpty) ? defaultMenuDestinations : menuDestinations;
		Future<String?> pickForDestination(SaveAsDestination menuDestination) async {
			switch (menuDestination) {
				case SaveAsDestination.galleryNoAlbum:
					return kGallerySavePathGalleryPrefix;
				case SaveAsDestination.galleryExistingAlbum:
					final existingAlbums = await PhotoManager.getAssetPathList(type: RequestType.common);
					if (!context.mounted) {
						return null;
					}
					if (existingAlbums.isEmpty) {
						throw Exception('No albums found');
					}
					final albumName = await showAdaptiveModalPopup<String>(
						context: context,
						builder: (context) => AdaptiveActionSheet(
							title: const Text('Choose existing album'),
							actions: [
								for (final album in existingAlbums) AdaptiveActionSheetAction(
									child: Text(album.name),
									onPressed: () => Navigator.pop(context, album.name)
								)
							],
							cancelButton: AdaptiveActionSheetAction(
								child: const Text('Cancel'),
								onPressed: () => Navigator.pop(context)
							)
						)
					);
					if (context.mounted && albumName != null) {
						return '$kGallerySavePathGalleryPrefix${Uri.encodeFull(albumName)}';
					}
					return null;
				case SaveAsDestination.galleryNewAlbum:
					final controller = TextEditingController();
					final useName = await showAdaptiveDialog<bool>(
						context: context,
						builder: (context) => StatefulBuilder(
							builder: (context, setDialogState) => AdaptiveAlertDialog(
								title: const Text('New album'),
								content: AdaptiveTextField(
									controller: controller,
									autofocus: true,
									placeholder: 'Album name',
									smartDashesType: SmartDashesType.disabled,
									smartQuotesType: SmartQuotesType.disabled,
									onChanged: (s) {
										setDialogState(() {});
									},
									onSubmitted: (s) {
										if (s.isNotEmpty) {
											Navigator.pop(context, true);
										}
									}
								),
								actions: [
									AdaptiveDialogAction(
										onPressed: controller.text.isNotEmpty ? () => Navigator.pop(context, true) : null,
										child: const Text('OK')
									),
									AdaptiveDialogAction(
										onPressed: () => Navigator.pop(context),
										child: const Text('Cancel')
									)
								]
							)
						)
					);
					final enteredName = controller.text;
					controller.dispose();
					if (context.mounted && useName == true) {
						if (enteredName.isEmpty) {
							throw Exception('No album name entered');
						}
						return '$kGallerySavePathGalleryPrefix${Uri.encodeFull(enteredName)}';
					}
					return null;
				case SaveAsDestination.files:
					return await pickDirectory();
			}
		}
		if (menuChoices.length == 1) {
			return await pickForDestination(menuChoices.single);
		}
		return await showAdaptiveDialog<String>(
			context: context,
			builder: (context) => AdaptiveAlertDialog(
				title: const Text('Choose save location'),
				actions: [
					for (final menuDestination in menuChoices)
						switch (menuDestination) {
							SaveAsDestination.galleryNoAlbum => AdaptiveDialogAction(
								child: const Text('Gallery (no album)'),
								onPressed: () => Navigator.pop(context, kGallerySavePathGalleryPrefix)
							),
							SaveAsDestination.galleryExistingAlbum => AdaptiveDialogAction(
								child: const Text('Gallery (existing album)'),
								onPressed: () async {
									final path = await pickForDestination(menuDestination);
									if (context.mounted && path != null) {
										Navigator.pop(context, path);
									}
								}
							),
							SaveAsDestination.galleryNewAlbum => AdaptiveDialogAction(
								child: const Text('Gallery (new album)'),
								onPressed: () async {
									final path = await pickForDestination(menuDestination);
									if (context.mounted && path != null) {
										Navigator.pop(context, path);
									}
								}
							),
							SaveAsDestination.files => AdaptiveDialogAction(
								child: const Text('Files'),
								onPressed: () async {
									final path = await pickForDestination(menuDestination);
									if (context.mounted) {
										Navigator.pop(context, path);
									}
								}
							)
						},
					AdaptiveDialogAction(
						child: const Text('Cancel'),
						onPressed: () => Navigator.pop(context)
					)
				]
			)
		);
	}
	return await pickDirectory();
}

class DirectoryNotFoundException implements Exception {
	final String directory;
	const DirectoryNotFoundException(this.directory);
	@override
	String toString() => 'Directory not found: $directory';
}

class InsufficientPermissionException implements Exception {
	final String directory;
	const InsufficientPermissionException(this.directory);
	@override
	String toString() => 'Storage permission expired or needs to be re-acquired for "$directory"';
}

Future<String> saveFile({
	required String sourcePath,
	required String destinationDir,
	required List<String> destinationSubfolders,
	required String destinationName
}) async {
	try {
		return (await _platform.invokeMethod<String>('saveFile', {
			'sourcePath': sourcePath,
			'destinationDir': destinationDir,
			'destinationSubfolders': destinationSubfolders,
			'destinationName': destinationName
		}))!;
	}
	on PlatformException catch (e) {
		if (e.code == 'DirectoryNotFound') {
			throw DirectoryNotFoundException(destinationDir);
		}
		if (e.code == 'InsufficientPermission') {
			throw InsufficientPermissionException(destinationDir);
		}
		rethrow;
	}
}

final bool isSaveFileAsSupported = Platform.isAndroid || Platform.isIOS;

enum SaveAsFileType {
	image,
	video,
	other
}

enum SaveAsDestination {
	galleryNoAlbum,
	galleryExistingAlbum,
	galleryNewAlbum,
	files
}

const List<SaveAsDestination> defaultMenuDestinations = [
	SaveAsDestination.galleryNoAlbum,
	SaveAsDestination.galleryExistingAlbum,
	SaveAsDestination.galleryNewAlbum,
	SaveAsDestination.files
];

Future<String?> saveFileAs({
	required BuildContext context,
	required SaveAsFileType type,
	required String sourcePath,
	required String destinationName,
	SaveAsDestination? destination,
	String? destinationDir,
	List<String> destinationSubfolders = const [],
	List<SaveAsDestination>? menuDestinations
}) async {
	Future<String?> saveToFiles() async {
		return await _platform.invokeMethod<String>('saveFileAs', {
			'sourcePath': sourcePath,
			'destinationName': destinationName,
			if (destinationDir != null) 'destinationDir': destinationDir,
			if (destinationDir != null && destinationSubfolders.isNotEmpty)
				'destinationSubfolders': destinationSubfolders
		});
	}

	// If not running on IOS, show file picker.
	if (!(Platform.isIOS && (type == SaveAsFileType.image || type == SaveAsFileType.video))) {
		return await saveToFiles();
	}

	Future<void> saveToGallery(AssetPathEntity? album) async {
		final asAsset = (type == SaveAsFileType.image) ? 
			await PhotoManager.editor.saveImageWithPath(sourcePath, title: destinationName) :
			await PhotoManager.editor.saveVideo(File(sourcePath), title: destinationName);
		if (asAsset == null) {
			throw Exception('Failed to save to gallery');
		}
		if (album != null) {
			await PhotoManager.editor.copyAssetToPath(asset: asAsset, pathEntity: album);
		}
	}
	Future<String?> saveToExistingAlbum() async {
		final existingAlbums = await PhotoManager.getAssetPathList(type: RequestType.common);
		if (!context.mounted) {
			return null;
		}
		if (existingAlbums.isEmpty) {
			throw Exception('No albums found');
		}
		final album = await showAdaptiveModalPopup<AssetPathEntity>(
			context: context,
			builder: (context) => AdaptiveActionSheet(
				title: const Text('Choose existing album'),
				actions: [
					for (final album in existingAlbums) AdaptiveActionSheetAction(
						child: Text(album.name),
						onPressed: () => Navigator.pop(context, album)
					)
				],
				cancelButton: AdaptiveActionSheetAction(
					child: const Text('Cancel'),
					onPressed: () => Navigator.pop(context)
				)
			)
		);
		if (album != null) {
			await saveToGallery(album);
			return destinationName;
		}
		return null;
	}
	Future<String?> saveToNewAlbum() async {
		final controller = TextEditingController();
		final useName = await showAdaptiveDialog<bool>(
			context: context,
			builder: (context) => StatefulBuilder(
				builder: (context, setDialogState) => AdaptiveAlertDialog(
					title: const Text('New album'),
					content: AdaptiveTextField(
						controller: controller,
						autofocus: true,
						placeholder: 'Album name',
						smartDashesType: SmartDashesType.disabled,
						smartQuotesType: SmartQuotesType.disabled,
						onChanged: (s) {
							setDialogState(() {});
						},
						onSubmitted: (s) {
							if (s.isNotEmpty) {
								Navigator.pop(context, true);
							}
						}
					),
					actions: [
						AdaptiveDialogAction(
							onPressed: controller.text.isNotEmpty ? () => Navigator.pop(context, true) : null,
							child: const Text('OK')
						),
						AdaptiveDialogAction(
							onPressed: () => Navigator.pop(context),
							child: const Text('Cancel')
						)
					]
				)
			)
		);
		final enteredName = controller.text;
		controller.dispose();
		if (useName == true) {
			if (enteredName.isEmpty) {
				throw Exception('No album name entered');
			}
			final album = await PhotoManager.editor.darwin.createAlbum(enteredName);
			await saveToGallery(album);
			return destinationName;
		}
		return null;
	}

	final menuChoices = (menuDestinations == null || menuDestinations.isEmpty) ? defaultMenuDestinations : menuDestinations;
	final effectiveDestination = (destination == null && menuChoices.length == 1) ? menuChoices.single : destination;

	if (effectiveDestination != null) {
		switch (effectiveDestination) {
			case SaveAsDestination.files:
				return await saveToFiles();
			case SaveAsDestination.galleryNoAlbum:
				await saveToGallery(null);
				return destinationName;
			case SaveAsDestination.galleryExistingAlbum:
				return await saveToExistingAlbum();
			case SaveAsDestination.galleryNewAlbum:
				return await saveToNewAlbum();
		}
	}

	if (!context.mounted) return null;

	return await showAdaptiveDialog<String>(
		context: context,
		builder: (context) => AdaptiveAlertDialog(
			title: const Text('Choose save location'),
			actions: [
				for (final menuDestination in menuChoices)
					switch (menuDestination) {
						SaveAsDestination.galleryNoAlbum => AdaptiveDialogAction(
							child: const Text('Gallery (no album)'),
							onPressed: () async {
								await saveToGallery(null);
								if (context.mounted) {
									Navigator.pop(context, destinationName);
								}
							}
						),
						SaveAsDestination.galleryExistingAlbum => AdaptiveDialogAction(
							child: const Text('Gallery (existing album)'),
							onPressed: () async {
								final name = await saveToExistingAlbum();
								if (context.mounted && name != null) {
									Navigator.pop(context, name);
								}
							}
						),
						SaveAsDestination.galleryNewAlbum => AdaptiveDialogAction(
							child: const Text('Gallery (new album)'),
							onPressed: () async {
								final name = await saveToNewAlbum();
								if (context.mounted && name != null) {
									Navigator.pop(context, name);
								}
							}
						),
						SaveAsDestination.files => AdaptiveDialogAction(
							child: const Text('Files'),
							onPressed: () async {
								final name = await saveToFiles();
								if (context.mounted) {
									Navigator.pop(context, name);
								}
							}
						)
					},
				AdaptiveDialogAction(
					child: const Text('Cancel'),
					onPressed: () => Navigator.pop(context)
				)
			]
		)
	);
}

typedef AndroidPickerIntent = ({String label, ImageProvider? icon, String package});

Future<List<AndroidPickerIntent>> getPickerList() async {
	if (!Platform.isAndroid) {
		return [];
	}
	return (await _platform.invokeListMethod<Map>('getPickerList') ?? []).map((intent) => (
		label: intent['label'] as String,
		package: intent['package'] as String,
		icon: switch (intent['icon']) {
			'' => null,
			String base64 => Base64ImageProvider(base64),
			_ => null
		}
	)).toList();
}

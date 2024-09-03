import 'package:chan/models/board.dart';
import 'package:chan/pages/board_switcher.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

abstract class MapValueEditor<T, S> {
	const MapValueEditor();
	S init(T? initialValue);
	Widget build(S controller, ValueChanged<T> pop);
	T? dispose(S controller);
}

class TextMapValueEditor extends MapValueEditor<String, TextEditingController> {
	const TextMapValueEditor();
	@override
	TextEditingController init(String? initialValue) {
		return TextEditingController(text: initialValue);
	}

	@override
	Widget build(TextEditingController controller, ValueChanged<String> pop) {
		return AdaptiveTextField(
			autocorrect: false,
			enableIMEPersonalizedLearning: false,
			smartDashesType: SmartDashesType.disabled,
			smartQuotesType: SmartQuotesType.disabled,
			controller: controller,
			onSubmitted: pop
		);
	}

	@override
	String? dispose(TextEditingController controller) {
		final ret = controller.text;
		controller.dispose();
		return ret;
	}
}

String _toString(dynamic x) => x?.toString() ?? 'null';

Future<void> editSiteBoardMap<T, S>({
	required BuildContext context,
	required FieldReader<PersistentBrowserState, Map<String, T>> field,
	required MapValueEditor<T, S> editor,
	required String name,
	String Function(T) formatter = _toString,
	required String title
}) async {
	final theme = context.read<SavedTheme>();
	await showAdaptiveDialog(
		barrierDismissible: true,
		context: context,
		builder: (context) => StatefulBuilder(
			builder: (context, setDialogState) {
				final entries = ImageboardRegistry.instance.imageboards.expand<(Imageboard, MapEntry<String, T>?)>((imageboard) sync* {
					final map = field.getter(imageboard.persistence.browserState);
					if (map.isEmpty) {
						return;
					}
					yield (imageboard, null);
					for (final pair in map.entries) {
						yield (imageboard, pair);
					}
				}).toList();
				Future<T?> edit(Imageboard imageboard, String board, T? initialValue) async {
					final controller = editor.init(initialValue);
					final change = await showAdaptiveDialog<bool>(
						context: context,
						barrierDismissible: true,
						builder: (context) => AdaptiveAlertDialog(
							title: Text('Edit $name'),
							content: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								mainAxisSize: MainAxisSize.min,
								children: [
									Text('${imageboard.site.name} - ${imageboard.site.formatBoardName(board)}'),
									const SizedBox(height: 16),
									Text(name),
									editor.build(controller, (_) => Navigator.pop(context, true))
								]
							),
							actions: [
								AdaptiveDialogAction(
									isDefaultAction: true,
									child: const Text('Change'),
									onPressed: () => Navigator.pop(context, true)
								),
								AdaptiveDialogAction(
									child: const Text('Cancel'),
									onPressed: () => Navigator.pop(context)
								)
							]
						)
					);
					final value = editor.dispose(controller);
					if (change ?? false) {
						return value;
					}
					return null;
				}
				return AdaptiveAlertDialog(
					title: Padding(
						padding: const EdgeInsets.only(bottom: 16),
						child: Text(title)
					),
					content: SizedBox(
						width: 100,
						height: 350,
						child: ListView.builder(
							itemCount: entries.length,
							itemBuilder: (context, i) {
								final entry = entries[i].$2;
								if (entry == null) {
									return Padding(
										padding: const EdgeInsets.all(4),
										child: Text(entries[i].$1.site.name)
									);
								}
								return Padding(
									padding: const EdgeInsets.all(4),
									child: GestureDetector(
										onTap: () async {
											final value = await edit(entries[i].$1, entry.key, entry.value);
											if (value != null) {
												field.getter(entries[i].$1.persistence.browserState)[entry.key] = value;
												entries[i].$1.persistence.didUpdateBrowserState();
												setDialogState(() {});
											}
										},
										child: Container(
											decoration: BoxDecoration(
												borderRadius: const BorderRadius.all(Radius.circular(4)),
												color: theme.primaryColor.withOpacity(0.1)
											),
											padding: const EdgeInsets.only(left: 16),
											child: Row(
												children: [
													Expanded(
														child: Text('${entries[i].$1.site.formatBoardName(entry.key)}\n${formatter(entry.value)}', style: const TextStyle(fontSize: 15), textAlign: TextAlign.left)
													),
													CupertinoButton(
														child: const Icon(CupertinoIcons.delete),
														onPressed: () {
															entries.removeAt(i);
															setDialogState(() {});
														}
													)
												]
											)
										)
									)
								);
							}
						)
					),
					actions: [
						AdaptiveDialogAction(
							child: Text('Add ${name.toLowerCase()}'),
							onPressed: () async {
								final board = await Navigator.of(context).push<ImageboardScoped<ImageboardBoard>>(TransparentRoute(
									builder: (ctx) => const BoardSwitcherPage()
								));
								if (board == null) {
									return;
								}
								final value = await edit(board.imageboard, board.item.name, null);
								if (value != null) {
									field.getter(board.imageboard.persistence.browserState)[board.item.name] = value;
									setDialogState(() {});
								}
							}
						),
						AdaptiveDialogAction(
							child: const Text('Close'),
							onPressed: () => Navigator.pop(context)
						)
					]
				);
			}
		)
	);
}

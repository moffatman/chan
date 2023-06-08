import 'package:auto_size_text/auto_size_text.dart';
import 'package:chan/main.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/widgets/cupertino_dialog.dart';
import 'package:chan/widgets/cupertino_text_field2.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class ChanceThemeKey {
	final String key;
	const ChanceThemeKey(this.key);

	@override
	String toString() => 'ChanceThemeKey($key)';

	@override
	bool operator == (Object other) =>
		other is ChanceThemeKey &&
		other.key == key;
	
	@override
	int get hashCode => key.hashCode;
}

class ChanceTheme extends StatelessWidget {
	final String themeKey;
	final Widget child;

	const ChanceTheme({
		required this.themeKey,
		required this.child,
		super.key
	});

	@override
	Widget build(BuildContext context) {
		final theme = context.select<EffectiveSettings, SavedTheme>((s) => s.themes[themeKey] ?? s.theme);
		return CupertinoTheme(
			data: theme.cupertinoThemeData,
			child: DefaultTextStyle(
				style: theme.cupertinoThemeData.textTheme.textStyle,
				child: Provider.value(
					value: theme,
					child: Provider.value(
						value: ChanceThemeKey(themeKey),
						child: child
					)
				)
			)
		);
	}

	static Color _selectBackgroundColor(SavedTheme theme) => theme.backgroundColor;
	static Color backgroundColorOf(BuildContext context) => context.select<SavedTheme, Color>(_selectBackgroundColor);
	static Color _selectBarColor(SavedTheme theme) => theme.barColor;
	static Color barColorOf(BuildContext context) => context.select<SavedTheme, Color>(_selectBarColor);
	static Color _selectPrimaryColor(SavedTheme theme) => theme.primaryColor;
	static Color primaryColorOf(BuildContext context) => context.select<SavedTheme, Color>(_selectPrimaryColor);
	static Color _selectPrimaryColorWithBrightness10(SavedTheme theme) => theme.primaryColorWithBrightness(0.1);
	static Color _selectPrimaryColorWithBrightness20(SavedTheme theme) => theme.primaryColorWithBrightness(0.2);
	static Color _selectPrimaryColorWithBrightness50(SavedTheme theme) => theme.primaryColorWithBrightness(0.5);
	static Color _selectPrimaryColorWithBrightness60(SavedTheme theme) => theme.primaryColorWithBrightness(0.6);
	static Color _selectPrimaryColorWithBrightness70(SavedTheme theme) => theme.primaryColorWithBrightness(0.7);
	static Color _selectPrimaryColorWithBrightness80(SavedTheme theme) => theme.primaryColorWithBrightness(0.8);
	static Color primaryColorWithBrightness10Of(BuildContext context) => context.select<SavedTheme, Color>(_selectPrimaryColorWithBrightness10);
	static Color primaryColorWithBrightness20Of(BuildContext context) => context.select<SavedTheme, Color>(_selectPrimaryColorWithBrightness20);
	static Color primaryColorWithBrightness50Of(BuildContext context) => context.select<SavedTheme, Color>(_selectPrimaryColorWithBrightness50);
	static Color primaryColorWithBrightness60Of(BuildContext context) => context.select<SavedTheme, Color>(_selectPrimaryColorWithBrightness60);
	static Color primaryColorWithBrightness70Of(BuildContext context) => context.select<SavedTheme, Color>(_selectPrimaryColorWithBrightness70);
	static Color primaryColorWithBrightness80Of(BuildContext context) => context.select<SavedTheme, Color>(_selectPrimaryColorWithBrightness80);
	static Color _selectSecondaryColor(SavedTheme theme) => theme.secondaryColor;
	static Color secondaryColorOf(BuildContext context) => context.select<SavedTheme, Color>(_selectSecondaryColor);
	static Color _selectTextFieldColor(SavedTheme theme) => theme.textFieldColor;
	static Color textFieldColorOf(BuildContext context) => context.select<SavedTheme, Color>(_selectTextFieldColor);
	static Color _selectSearchTextFieldColor(SavedTheme theme) => theme.searchTextFieldColor;
	static Color searchTextFieldColorOf(BuildContext context) => context.select<SavedTheme, Color>(_selectSearchTextFieldColor);
	static Brightness _selectBrightness(SavedTheme theme) => theme.brightness;
	static Brightness brightnessOf(BuildContext context) => context.select<SavedTheme, Brightness>(_selectBrightness);

	static String keyOf(BuildContext context, {bool listen = true}) => Provider.of<ChanceThemeKey>(context, listen: listen).key;
}

Future<String?> selectThemeKey({
	required BuildContext context,
	required String title,
	required String currentKey,
	required bool allowEditing
}) => showCupertinoDialog<String>(
	barrierDismissible: true,
	context: context,
	builder: (context) => CupertinoAlertDialog2(
		title: Padding(
			padding: const EdgeInsets.only(bottom: 16),
			child: Row(
				mainAxisAlignment: MainAxisAlignment.center,
				children: [
					const Icon(CupertinoIcons.paintbrush),
					const SizedBox(width: 8),
					Text(title)
				]
			)
		),
		content: StatefulBuilder(
			builder: (context, setDialogState) {
				final themes = settings.themes.entries.toList();
				themes.sort((a, b) => a.key.compareTo(b.key));
				return SizedBox(
					width: 200,
					height: 350,
					child: ListView.separated(
						itemCount: themes.length,
						separatorBuilder: (context, i) => const SizedBox(height: 16),
						itemBuilder: (context, i) => GestureDetector(
							onTap: () {
								Navigator.pop(context, themes[i].key);
							},
							child: ChanceTheme(
								themeKey: themes[i].key,
								child: Container(
									decoration: BoxDecoration(
										borderRadius: const BorderRadius.all(Radius.circular(8)),
										color: themes[i].value.backgroundColor
									),
									child: Column(
										mainAxisSize: MainAxisSize.min,
										children: [
											Padding(
												padding: const EdgeInsets.all(16),
												child: Row(
													mainAxisSize: MainAxisSize.min,
													children: [
														if (allowEditing && themes[i].value.locked) Padding(
															padding: const EdgeInsets.only(right: 4),
															child: Icon(CupertinoIcons.lock, color: themes[i].value.primaryColor)
														),
														AutoSizeText(themes[i].key, style: TextStyle(
															fontSize: 18,
															color: themes[i].value.primaryColor,
															fontWeight: themes[i].key == currentKey ? FontWeight.bold : null
														))
													]
												)
											),
											if (allowEditing) Container(
												//margin: const EdgeInsets.all(4),
												decoration: BoxDecoration(
													color: themes[i].value.barColor,
													borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8))
												),
												child: Row(
													mainAxisAlignment: MainAxisAlignment.spaceEvenly,
													children: [
														CupertinoButton(
															child: const Icon(CupertinoIcons.share),
															onPressed: () {
																Clipboard.setData(ClipboardData(
																	text: Uri(
																		scheme: 'chance',
																		host: 'theme',
																		queryParameters: {
																			'name': themes[i].key,
																			'data': themes[i].value.encode()
																		}
																	).toString()
																));
																showToast(
																	context: context,
																	message: 'Copied ${themes[i].key} to clipboard',
																	icon: CupertinoIcons.doc_on_clipboard
																);
															}
														),
														CupertinoButton(
															onPressed: themes[i].value.locked ? null : () async {
																final controller = TextEditingController(text: themes[i].key);
																controller.selection = TextSelection(baseOffset: 0, extentOffset: themes[i].key.length);
																final newName = await showCupertinoDialog<String>(
																	context: context,
																	barrierDismissible: true,
																	builder: (context) => CupertinoAlertDialog2(
																		title: const Text('Enter new name'),
																		content: CupertinoTextField2(
																			autofocus: true,
																			controller: controller,
																			smartDashesType: SmartDashesType.disabled,
																			smartQuotesType: SmartQuotesType.disabled,
																			onSubmitted: (s) => Navigator.pop(context, s)
																		),
																		actions: [
																			CupertinoDialogAction2(
																				child: const Text('Cancel'),
																				onPressed: () => Navigator.pop(context)
																			),
																			CupertinoDialogAction2(
																				isDefaultAction: true,
																				child: const Text('Rename'),
																				onPressed: () => Navigator.pop(context, controller.text)
																			)
																		]
																	)
																);
																if (newName != null) {
																	final effectiveName = settings.addTheme(newName, themes[i].value);
																	settings.themes.remove(themes[i].key);
																	if (settings.lightThemeKey == themes[i].key) {
																		settings.lightThemeKey = effectiveName;
																	}
																	if (settings.darkThemeKey == themes[i].key) {
																		settings.darkThemeKey = effectiveName;
																	}
																	settings.handleThemesAltered();
																	setDialogState(() {});
																}
																controller.dispose();
															},
															child: const Icon(CupertinoIcons.textformat)
														),
														CupertinoButton(
															child: const Icon(CupertinoIcons.doc_on_doc),
															onPressed: () {
																settings.addTheme(themes[i].key, themes[i].value);
																settings.handleThemesAltered();
																setDialogState(() {});
															}
														),
														CupertinoButton(
															onPressed: (themes[i].value.locked || themes[i].key == settings.darkThemeKey || themes[i].key == settings.lightThemeKey) ? null : () async {
																final consent = await showCupertinoDialog<bool>(
																	context: context,
																	barrierDismissible: true,
																	builder: (context) => CupertinoAlertDialog2(
																		title: Text('Delete ${themes[i].key}?'),
																		actions: [
																			CupertinoDialogAction2(
																				child: const Text('Cancel'),
																				onPressed: () {
																					Navigator.of(context).pop();
																				}
																			),
																			CupertinoDialogAction2(
																				isDestructiveAction: true,
																				onPressed: () {
																					Navigator.of(context).pop(true);
																				},
																				child: const Text('Delete')
																			)
																		]
																	)
																);
																if (consent == true) {
																	settings.themes.remove(themes[i].key);
																	settings.handleThemesAltered();
																	setDialogState(() {});
																}
															},
															child: const Icon(CupertinoIcons.delete)
														)
													]
												)
											)
										]
									)
								)
							)
						)
					)
				);
			}
		),
		actions: [
			CupertinoDialogAction2(
				child: const Text('Close'),
				onPressed: () => Navigator.pop(context)
			)
		]
	)
);
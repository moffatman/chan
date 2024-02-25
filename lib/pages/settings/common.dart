import 'dart:ui' as ui;

import 'package:chan/services/imageboard.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// TODO(sync): The sync on/off button

class _SettingsHelpButton extends StatelessWidget {
	final String helpText;

	const _SettingsHelpButton({
		required this.helpText
	});

	@override
	Widget build(BuildContext context) {
		return AdaptiveIconButton(
			icon: const Icon(CupertinoIcons.question_circle),
			onPressed: () {
				showAdaptiveDialog<bool>(
					context: context,
					barrierDismissible: true,
					builder: (context) => AdaptiveAlertDialog(
						content: Text(helpText),
						actions: [
							AdaptiveDialogAction(
								child: const Text('OK'),
								onPressed: () {
									Navigator.of(context).pop();
								}
							)
						]
					)
				);
			}
		);
	}
}

/*
class _SettingsSyncButton extends StatelessWidget {
	final List<String> syncPaths;

	const _SettingsSyncButton({
		required this.syncPaths
	});

	@override
	Widget build(BuildContext context) {
		final disabled = context.select<Settings, bool>((s) => syncPaths.any((p) => s.localSettings.syncDisabledFields.contains(p)));
		return AdaptiveIconButton(
			icon: Icon(CupertinoIcons.cloud, color: disabled ? ChanceTheme.secondaryColorOf(context) : null),
			onPressed: () {
				showToast(
					context: context,
					icon: CupertinoIcons.cloud_fog,
					message: syncPaths.toString()
				);
			}
		);
	}
}
*/

Future<Imageboard?> _pickImageboard(BuildContext context, Imageboard current) {
	return showAdaptiveModalPopup<Imageboard?>(
		context: context,
		builder: (context) => AdaptiveActionSheet(
			title: const Text('Select site'),
			actions: ImageboardRegistry.instance.imageboards.map((imageboard) => AdaptiveActionSheetAction(
				isSelected: imageboard == current,
				child: Row(
					mainAxisSize: MainAxisSize.min,
					children: [
						ImageboardIcon(imageboardKey: imageboard.key),
						const SizedBox(width: 8),
						Text(imageboard.site.name)
					]
				),
				onPressed: () {
					Navigator.of(context, rootNavigator: true).pop(imageboard);
				}
			)).toList(),
			cancelButton: AdaptiveActionSheetAction(
				child: const Text('Cancel'),
				onPressed: () => Navigator.of(context, rootNavigator: true).pop()
			)
		)
	);
}

/// Hack for type inference of List<SettingWidget>
abstract class SettingWidget {
	final MutableSetting<bool>? disabled;
	final bool subsetting;

	const SettingWidget({
		this.disabled,
		this.subsetting = false
	});

	Iterable<SettingWidget> search(String query);

	@protected
	Widget buildImpl(BuildContext context);

	Widget build() {
		return Builder(
			key: ValueKey(this),
			builder: (context) {
				final disabled = this.disabled?.watch(context) ?? false;
				return IgnorePointer(
					ignoring: disabled,
					child: Opacity(
						opacity: disabled ? 0.5 : 1.0,
						child: Padding(
							padding: subsetting ? const EdgeInsets.symmetric(
								vertical: 0,
								horizontal: 32
							) : const EdgeInsets.symmetric(
								vertical: 8,
								horizontal: 16
							),
							child: Builder(
								builder: (context) => buildImpl(context)
							)
						)
					)
				);
			}
		);
	}
}

class _IndentedGroup extends SettingWidget {
	final List<SettingWidget> settings;

	const _IndentedGroup({
		required this.settings
	});

	@override
	Iterable<SettingWidget> search(String query) => throw UnsupportedError('_IndentedGroup is only returned from search results');

	@override
	Widget buildImpl(BuildContext context) => Padding(
		padding: const EdgeInsets.only(left: 16),
		child: Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			mainAxisSize: MainAxisSize.min,
			children: settings.map((s) => s.build()).toList()
		)
	);

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is _IndentedGroup &&
		listEquals(other.settings, settings);
	
	@override
	int get hashCode => settings.hashCode;
}

class CustomMutableSettingWidget<T> extends SettingWidget {
	final String description;
	final MutableSetting<T> setting;
	final Widget Function(T, VoidCallback) builder;

	const CustomMutableSettingWidget({
		required this.description,
		required this.setting,
		required this.builder
	});

	@override
	Iterable<SettingWidget> search(String query) sync* {
		if (description.toLowerCase().contains(query)) {
			yield this;
		}
	}

	@override
	Widget buildImpl(BuildContext context) => builder(setting.watch(context), Settings.instance.didEdit);

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is CustomMutableSettingWidget &&
		other.description == description &&
		other.setting == setting &&
		other.builder == builder;
	
	@override
	int get hashCode => Object.hash(description, setting, builder);
}

abstract class StandardSettingWidget extends SettingWidget {
	final String description;
	final IconData? icon;
	final Widget Function(Color?)? iconBuilder;
	final String? helpText;
	final String Function(BuildContext)? helpTextBuilder;
	final MutableSetting<Color?>? color;
	final List<String> keywords;

	const StandardSettingWidget({
		this.icon,
		this.iconBuilder,
		required this.description,
		this.helpText,
		this.helpTextBuilder,
		this.color,
		super.disabled,
		this.keywords = const [],
		super.subsetting
	});

	@override
	Iterable<SettingWidget> search(String query) sync* {
		if (description.toLowerCase().contains(query)) {
			yield this;
			return;
		}
		for (final keyword in keywords) {
			if (keyword.contains(query)) {
				yield this;
				return;
			}
		}
	}

	Widget _makeIcon([Color? color]) => (iconBuilder != null || icon != null) ? Padding(
		padding: const EdgeInsets.only(right: 8),
		child: iconBuilder?.call(color) ?? Icon(icon, color: color)
	) : const SizedBox.shrink();

	Widget _makeHelpButton(BuildContext context) {
		final text = helpTextBuilder?.call(context) ?? helpText;
		if (text != null) {
			return _SettingsHelpButton(
				helpText: text
			);
		}
		return const SizedBox.shrink();
	}

	Widget _makeSyncButton(List<String> syncPaths) {
		return const SizedBox.shrink();
		/*if (syncPaths.isEmpty) {
			return const SizedBox.shrink();
		}
		return _SettingsSyncButton(
			syncPaths: syncPaths
		);*/
	}
}

abstract class StandardImmutableSettingWidget<T> extends StandardSettingWidget {
	final ImmutableSetting<T> setting;
	final Widget Function(BuildContext, T, ValueChanged<T>)? injectButton;
	final Future<bool> Function(BuildContext, T)? confirm;

	const StandardImmutableSettingWidget({
		required this.setting,
		super.icon,
		super.iconBuilder,
		required super.description,
		super.helpText,
		super.helpTextBuilder,
		super.disabled,
		super.color,
		this.injectButton,
		super.subsetting,
		super.keywords,
		this.confirm
	});

	Future<void> Function(T) makeWriter(BuildContext context) {
		final writer = setting.makeWriter(context);
		final confirm = this.confirm;
		if (confirm == null) {
			return writer;
		}
		return (v) async {
			if (await confirm(context, v)) {
				writer(v);
			}
		};
	}
}

abstract class StandardMutableSettingWidget<T> extends StandardSettingWidget {
	final MutableSetting<T> setting;

	const StandardMutableSettingWidget({
		required this.setting,
		super.icon,
		super.iconBuilder,
		required super.description,
		super.helpText,
		super.disabled
	});
}

class SwitchSettingWidget extends StandardImmutableSettingWidget<bool> {
	const SwitchSettingWidget({
		super.icon,
		super.iconBuilder,
		required super.description,
		required super.setting,
		super.helpText,
		super.helpTextBuilder,
		super.disabled,
		super.subsetting
	});
	@override
	Widget buildImpl(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.symmetric(vertical: 8),
			child: Row(
				children: [
					_makeIcon(),
					Expanded(
						child: Text(description)
					),
					_makeSyncButton(setting.syncPaths),
					_makeHelpButton(context),
					AdaptiveSwitch(
						value: setting.watch(context),
						onChanged: makeWriter(context)
					)
				]
			),
		);
	}

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is SwitchSettingWidget &&
		other.icon == icon &&
		other.iconBuilder == iconBuilder &&
		other.description == description &&
		other.setting == setting &&
		other.helpText == helpText &&
		other.helpTextBuilder == helpTextBuilder &&
		other.disabled == disabled &&
		other.subsetting == subsetting;
	
	@override
	int get hashCode => Object.hash(icon, iconBuilder, description, setting, helpText, helpTextBuilder, disabled, subsetting);
}

class SegmentedSettingWidget<T extends Object> extends StandardImmutableSettingWidget<T> {
	final Map<T, (IconData?, String)> children;
	final double? knownWidth;

	const SegmentedSettingWidget({
		super.icon,
		super.iconBuilder,
		required super.description,
		required super.setting,
		super.helpText,
		required this.children,
		this.knownWidth,
		super.disabled,
		super.injectButton,
		super.confirm
	});

	@override
	Widget buildImpl(BuildContext context) {
		final injectButton = this.injectButton;
		return Column(
			mainAxisSize: MainAxisSize.min,
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				const SizedBox(height: 8),
				Row(
					children: [
						_makeIcon(),
						Expanded(
							child: Text(description)
						),
						_makeSyncButton(setting.syncPaths),
						_makeHelpButton(context),
						if (injectButton != null) injectButton(context, setting.watch(context), makeWriter(context)),
					]
				),
				const SizedBox(height: 16),
				Padding(
					padding: const EdgeInsets.symmetric(horizontal: 16),
					child: StatefulBuilder(
						builder: (context, setState) => AdaptiveChoiceControl<T>(
							children: children,
							groupValue: setting.watch(context),
							knownWidth: knownWidth,
							onValueChanged: (newValue) async {
								await makeWriter(context)(newValue);
								setState(() {}); // Fix stuck button
							}
						)
					)
				)
			]
		);
	}

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is SegmentedSettingWidget &&
		other.icon == icon &&
		other.iconBuilder == iconBuilder &&
		other.description == description &&
		other.setting == setting &&
		other.helpText == helpText &&
		other.helpTextBuilder == helpTextBuilder &&
		other.disabled == disabled &&
		other.subsetting == subsetting &&
		mapEquals(other.children, children);
	
	@override
	int get hashCode => Object.hash(icon, iconBuilder, description, setting, helpText, helpTextBuilder, disabled, subsetting, children);
}

class SteppableSettingWidget<T extends num> extends StandardImmutableSettingWidget<T> {
	final T min;
	final T step;
	final T max;
	final String Function(T) formatter;

	const SteppableSettingWidget({
		super.icon,
		super.iconBuilder,
		required super.description,
		required super.setting,
		super.disabled,
		super.helpText,
		required this.min,
		required this.step,
		required this.max,
		required this.formatter
	});

	@override
	Widget buildImpl(BuildContext context) {
		final value = setting.watch(context);
		return Row(
			mainAxisSize: MainAxisSize.max,
			children: [
				_makeIcon(),
				Expanded(
					child: Text(description)
				),
				_makeSyncButton(setting.syncPaths),
				_makeHelpButton(context),
				AdaptiveIconButton(
					padding: EdgeInsets.zero,
					onPressed: value <= min ? null : () {
						setting.write(context, value - step as T);
					},
					icon: const Icon(CupertinoIcons.minus)
				),
				Text(formatter(value), style: const TextStyle(fontFeatures: [ui.FontFeature.tabularFigures()])),
				AdaptiveIconButton(
					padding: EdgeInsets.zero,
					onPressed: value >= max ? null : () {
						setting.write(context, value + step as T);
					},
					icon: const Icon(CupertinoIcons.plus)
				)
			]
		);
	}

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is SteppableSettingWidget &&
		other.icon == icon &&
		other.iconBuilder == iconBuilder &&
		other.description == description &&
		other.setting == setting &&
		other.helpText == helpText &&
		other.helpTextBuilder == helpTextBuilder &&
		other.disabled == disabled &&
		other.subsetting == subsetting &&
		other.min == min &&
		other.step == step &&
		other.max == max &&
		other.formatter == formatter;
	
	@override
	int get hashCode => Object.hash(icon, iconBuilder, description, setting, helpText, helpTextBuilder, disabled, subsetting, min, step, max, formatter);
}

class NullableSteppableSettingWidget<T extends num> extends StandardImmutableSettingWidget<T?> {
	final T min;
	final T step;
	final T max;
	final String Function(T?) formatter;

	NullableSteppableSettingWidget({
		super.icon,
		super.iconBuilder,
		required super.description,
		required super.setting,
		super.helpText,
		required this.min,
		required this.step,
		required this.max,
		required this.formatter
	});

	@override
	Widget buildImpl(BuildContext context) {
		final value = setting.watch(context);
		return Row(
			children: [
				_makeIcon(),
				Expanded(
					child: Text(description)
				),
				_makeSyncButton(setting.syncPaths),
				_makeHelpButton(context),
				AdaptiveIconButton(
					padding: EdgeInsets.zero,
					onPressed: (value ?? (min + 1)) <= min ? null : () {
						setting.write(context, value ?? (max + step) - step as T);
					},
					icon: const Icon(CupertinoIcons.minus)
				),
				Text(formatter(value), style: const TextStyle(fontFeatures: [ui.FontFeature.tabularFigures()])),
				AdaptiveIconButton(
					padding: EdgeInsets.zero,
					onPressed: (value ?? (max) - 1) >= max ? null : () {
						setting.write(context, value ?? (min - step) + step as T);
					},
					icon: const Icon(CupertinoIcons.plus)
				)
			]
		);
	}

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is NullableSteppableSettingWidget &&
		other.icon == icon &&
		other.iconBuilder == iconBuilder &&
		other.description == description &&
		other.setting == setting &&
		other.helpText == helpText &&
		other.helpTextBuilder == helpTextBuilder &&
		other.disabled == disabled &&
		other.subsetting == subsetting &&
		other.min == min &&
		other.step == step &&
		other.max == max &&
		other.formatter == formatter;
	
	@override
	int get hashCode => Object.hash(icon, iconBuilder, description, setting, helpText, helpTextBuilder, disabled, subsetting, min, step, max, formatter);
}

class SliderSettingWidget extends StandardImmutableSettingWidget<double> {
	final double min;
	final double step;
	final double max;
	final String Function(double)? textFormatter;
	final Widget Function(double)? widgetFormatter;
	final ImmutableSetting<bool>? enabledSetting;

	const SliderSettingWidget({
		super.icon,
		super.iconBuilder,
		required super.description,
		required super.setting,
		super.helpText,
		required this.min,
		required this.step,
		required this.max,
		this.textFormatter,
		this.widgetFormatter,
		this.enabledSetting,
		super.keywords,
		super.disabled
	});

	@override
	Widget buildImpl(BuildContext context) {
		final enabledSetting = this.enabledSetting;
		final textFormatter = this.textFormatter;
		final widgetFormatter = this.widgetFormatter;
		final enabled = enabledSetting?.watch(context);
		final value = setting.watch(context);
		final divisions = ((max - min) / step).round();
		return Padding(
			padding: const EdgeInsets.symmetric(vertical: 8),
			child: Column(
				mainAxisSize: MainAxisSize.min,
				children: [
					Row(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							_makeIcon(),
							Expanded(
								child: Text.rich(
									TextSpan(
										children: [
											TextSpan(text: description),
											if (enabled != null) const TextSpan(text: '\n')
											else if (textFormatter != null) const TextSpan(text: ': '),
											if (textFormatter != null) TextSpan(text: textFormatter(value), style: TextStyle(
												color: (enabled == false) ? ChanceTheme.primaryColorWithBrightness50Of(context) : ChanceTheme.primaryColorWithBrightness80Of(context),
												fontFeatures: const [ui.FontFeature.tabularFigures()]
											))
										]
									)
								)
							),
							_makeSyncButton(setting.syncPaths),
							_makeHelpButton(context),
							if (widgetFormatter != null) widgetFormatter(value),
							if (divisions >= 100) ...[
								AdaptiveIconButton(
									padding: EdgeInsets.zero,
									onPressed: value <= min ? null : () {
										setting.write(context, value - step);
									},
									icon: const Icon(CupertinoIcons.minus)
								),
								AdaptiveIconButton(
									padding: EdgeInsets.zero,
									onPressed: value >= max ? null : () {
										setting.write(context, value + step);
									},
									icon: const Icon(CupertinoIcons.plus)
								)
							],
							if (enabled != null) AdaptiveSwitch(
								value: enabled,
								onChanged: (v) => enabledSetting?.write(context, v)
							),
						]
					),
					const SizedBox(height: 16),
					Padding(
						padding: const EdgeInsets.symmetric(horizontal: 16),
						child: Opacity(
							opacity: enabled == false ? 0.5 : 1,
							child: Slider.adaptive(
								min: min,
								max: max,
								divisions: divisions,
								value: value,
								onChanged: enabled == false ? null : makeWriter(context)
							)
						)
					)
				]
			)
		);
	}


	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is SliderSettingWidget &&
		other.icon == icon &&
		other.iconBuilder == iconBuilder &&
		other.description == description &&
		other.setting == setting &&
		other.helpText == helpText &&
		other.helpTextBuilder == helpTextBuilder &&
		other.disabled == disabled &&
		other.subsetting == subsetting &&
		other.min == min &&
		other.step == step &&
		other.max == max &&
		other.textFormatter == textFormatter &&
		other.widgetFormatter == widgetFormatter &&
		other.enabledSetting == enabledSetting;
	
	@override
	int get hashCode => Object.hash(icon, iconBuilder, description, setting, helpText, helpTextBuilder, disabled, subsetting, min, step, max, textFormatter, widgetFormatter, enabledSetting);
}

class ImmutableButtonSettingWidget<T> extends StandardImmutableSettingWidget<T> {
	final Widget Function(T) builder;
	final void Function(BuildContext context, T, ValueChanged<T>) onPressed;

	const ImmutableButtonSettingWidget({
		super.icon,
		super.iconBuilder,
		required super.description,
		required super.setting,
		super.helpText,
		required this.builder,
		required this.onPressed,
		super.color,
		super.disabled,
		super.injectButton
	});

	@override
	Widget buildImpl(BuildContext context) {
		final injectButton = this.injectButton;
		final color = this.color?.watch(context);
		return Padding(
			padding: const EdgeInsets.symmetric(vertical: 8),
			child: Row(
				children: [
					_makeIcon(color),
					Expanded(
						child: Text(description, style: TextStyle(color: color))
					),
					_makeSyncButton(setting.syncPaths),
					_makeHelpButton(context),
					if (injectButton != null) injectButton(context, setting.watch(context), makeWriter(context)),
					AdaptiveFilledButton(
						padding: const EdgeInsets.all(8),
						color: color,
						onPressed: () => onPressed(context, setting.read(context), makeWriter(context)),
						child: builder(setting.watch(context))
					)
				]
			),
		);
	}
}

class MutableButtonSettingWidget<T> extends StandardMutableSettingWidget<T> {
	final Widget Function(T) builder;
	final void Function(BuildContext context, T value, VoidCallback onChanged) onPressed;

	const MutableButtonSettingWidget({
		super.icon,
		super.iconBuilder,
		required super.description,
		required super.setting,
		super.helpText,
		required this.builder,
		required this.onPressed,
		super.disabled
	});

	@override
	Widget buildImpl(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.symmetric(vertical: 8),
			child: Row(
				children: [
					_makeIcon(),
					Expanded(
						child: Text(description)
					),
					_makeSyncButton(setting.syncPaths),
					_makeHelpButton(context),
					AdaptiveFilledButton(
						padding: const EdgeInsets.all(8),
						onPressed: () => onPressed(context, setting.read(context), setting.makeDidMutate(context)),
						child: builder(setting.watch(context))
					)
				]
			),
		);
	}
}

class SimpleButtonSettingWidget extends StandardSettingWidget {
	final void Function(BuildContext) onPressed;

	const SimpleButtonSettingWidget({
		required super.description,
		required this.onPressed,
		super.icon,
		super.iconBuilder
	});

	@override
	Widget buildImpl(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.symmetric(vertical: 8),
			child: Center(
				child: AdaptiveFilledButton(
					padding: const EdgeInsets.all(16),
					child: Row(
						mainAxisSize: MainAxisSize.min,
						children: [
							_makeIcon(),
							const SizedBox(width: 8),
							Text(description)
						]
					),
					onPressed: () => onPressed(context)
				)
			)
		);
	}
}

class PopupSubpageSettingWidget extends StandardSettingWidget {
	final List<SettingWidget> settings;
	final SettingWidget? preview;

	PopupSubpageSettingWidget({
		required this.settings,
		required super.description,
		super.color,
		super.icon,
		super.iconBuilder,
		this.preview
	});

	@override
	Iterable<SettingWidget> search(String query) sync* {
		if (description.toLowerCase().contains(query)) {
			yield this;
		}
		else {
			final children = settings.expand((s) => s.search(query)).toList();
			if (children.isNotEmpty) {
				yield this;
				yield _IndentedGroup(
					settings: children
				);
			}
		}
	}

	@override
	Widget buildImpl(BuildContext context) {
		final color = this.color?.watch(context);
		return AdaptiveThinButton(
			color: color,
			child: Row(
				children: [
					Icon(icon),
					const SizedBox(width: 16),
					Expanded(
						child: Text(description, style: TextStyle(
							color: color
						))
					),
					Icon(CupertinoIcons.chevron_forward, color: color)
				]
			),
			onPressed: () => Navigator.push(context, adaptivePageRoute(
				builder: (context) => SettingListPage(
					title: description,
					settings: settings,
					preview: preview
				)
			))
		);
	}
}

class PanelSettingWidget extends StandardSettingWidget {
	final WidgetBuilder builder;

	const PanelSettingWidget({
		super.icon,
		super.iconBuilder,
		super.description = '',
		required this.builder,
		super.helpText,
		super.disabled
	});

	@override
	Widget buildImpl(BuildContext context) {
		return Column(
			mainAxisSize: MainAxisSize.min,
			children: [
				if (description.isNotEmpty) ...[
					const SizedBox(height: 8),
					Row(
						children: [
							_makeIcon(),
							Expanded(
								child: Text(description)
							),
							_makeHelpButton(context)
						]
					),
					const SizedBox(height: 16)
				],
				Padding(
					padding: const EdgeInsets.symmetric(horizontal: 16),
					child: Builder(builder: builder)
				)
			]
		);
	}
}

class ImageboardScopedSettingWidget extends SettingWidget {
	final SettingWidget Function(Imageboard) builder;
	final String? description;

	ImageboardScopedSettingWidget({
		required this.builder,
		required this.description
	});

	@override
	Iterable<SettingWidget> search(String query) sync* {
		final description = this.description;
		if (description != null) {
			if (description.toLowerCase().contains(query)) {
				yield this;
			}
		}
		else {
			yield* ImageboardRegistry.instance.imageboards.expand((i) => builder(i).search(query));
		}
	}

	@override
	Widget buildImpl(BuildContext context) {
		return _ImageboardPicker(
			builder: (imageboard, setImageboard) {
				return IntrinsicHeight(
					child: Row(
						crossAxisAlignment: CrossAxisAlignment.center,
						children: [
							Expanded(
								child: builder(imageboard).build()
							),
							const SizedBox(width: 8),
							AdaptiveFilledButton(
								padding: const EdgeInsets.all(8),
								onPressed: () async {
									final newImageboard = await _pickImageboard(context, imageboard);
									if (newImageboard != null) {
										setImageboard(newImageboard);
									}
								},
								child: Row(
									mainAxisSize: MainAxisSize.min,
									children: [
										ImageboardIcon(
											imageboardKey: imageboard.key
										),
										const SizedBox(width: 8),
										Text(imageboard.site.name)
									]
								)
							)
						]
					)
				);
			}
		);
	}
}

class _ImageboardPicker extends StatefulWidget {
	final Widget Function(Imageboard, ValueChanged<Imageboard>) builder;

	const _ImageboardPicker({
		required this.builder
	});

	@override
	createState() => _ImageboardPickerState();
}

class _ImageboardPickerState extends State<_ImageboardPicker> {
	Imageboard imageboard = ImageboardRegistry.instance.imageboards.first;

	@override
	Widget build(BuildContext context) {
		return widget.builder(imageboard, (newImageboard) {
			setState(() {
				imageboard = newImageboard;
			});
		});
	}
}

class ImageboardScopedSettingGroup extends SettingWidget {
	final String title;
	final List<ImageboardScopedSettingWidget> settings;

	ImageboardScopedSettingGroup({
		required this.title,
		required this.settings
	});

	@override
	Iterable<SettingWidget> search(String query) sync* {
		if (title.toLowerCase().contains(query) || settings.any((s) => s.search(query).isNotEmpty)) {
			yield this;
		}
	}

	@override
	Widget buildImpl(BuildContext context) {
		return Container(
			margin: const EdgeInsets.all(16),
			padding: const EdgeInsets.all(16),
			decoration: BoxDecoration(
				color: ChanceTheme.primaryColorWithBrightness10Of(context),
				borderRadius: BorderRadius.circular(12)
			),
			child: _ImageboardPicker(
				builder: (imageboard, setImageboard) => Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						Row(
							children: [
								Expanded(
									child: Text(title)
								),
								const SizedBox(width: 8),
								AdaptiveFilledButton(
									padding: const EdgeInsets.all(8),
									onPressed: () async {
										final newImageboard = await _pickImageboard(context, imageboard);
										if (newImageboard != null) {
											setImageboard(newImageboard);
										}
									},
									child: Row(
										mainAxisSize: MainAxisSize.min,
										children: [
											ImageboardIcon(
												imageboardKey: imageboard.key
											),
											const SizedBox(width: 8),
											Text(imageboard.site.name)
										]
									)
								)
							]
						),
						...settings.map((s) => s.builder(imageboard).build())
					]
				)
			)
		);
	}

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is ImageboardScopedSettingGroup &&
		other.title == title &&
		listEquals(other.settings, settings);
	
	@override
	int get hashCode => Object.hash(title, settings);
}

class SettingHiding extends SettingWidget {
	final SettingWidget setting;
	final MutableSetting<bool> hidden;

	const SettingHiding({
		required this.setting,
		required this.hidden
	}) : super(
		subsetting: true
	);

	@override
	Iterable<SettingWidget> search(String query) {
		// Unconditionally reveal in search
		return setting.search(query);
	}

	@override
	Widget buildImpl(BuildContext context) {
		final hide = hidden.watch(context);
		return AnimatedSize(
			duration: const Duration(milliseconds: 250),
			curve: Curves.ease,
			alignment: Alignment.topCenter,
			child: hide ? const SizedBox(width: double.infinity) : setting.build()
		);
	}
}

class SettingListPage extends StatefulWidget {
	final String title;
	final List<SettingWidget> settings;
	final SettingWidget? preview;
	const SettingListPage({
		required this.settings,
		required this.title,
		this.preview,
		Key? key
	}) : super(key: key);

	@override
	createState() => _SettingListPageState();
}

class _SettingListPageState extends State<SettingListPage> {
	final scrollKey = GlobalKey(debugLabel: '_SettingListPageState.scrollKey');

	@override
	Widget build(BuildContext context) {
		final preview = widget.preview;
		return AdaptiveScaffold(
			resizeToAvoidBottomInset: false,
			bar: AdaptiveBar(
				title: Text(widget.title)
			),
			body: Builder(
				builder: (context) => Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						if (preview != null) ...[
							Expanded(
								child: Container(
									color: ChanceTheme.primaryColorWithBrightness10Of(context),
									padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
									child: LayoutBuilder(
										builder: (context, constraints) => FittedBox(
											child: SizedBox(
												width: constraints.maxWidth,
												child: preview.build()
											)
										)
									)
								)
							),
							const ChanceDivider()
						],
						Expanded(
							child: MediaQuery.removePadding(
								context: context,
								removeTop: preview != null,
								child: Builder(
									builder: (context) => MaybeScrollbar(
										child: ListView.builder(
											padding: MediaQuery.paddingOf(context) + const EdgeInsets.all(16),
											key: scrollKey,
											itemCount: widget.settings.length,
											itemBuilder: (context, i) => Align(
												alignment: Alignment.center,
												child: ConstrainedBox(
													constraints: const BoxConstraints(
														minWidth: 500,
														maxWidth: 500
													),
													child: widget.settings[i].build()
												)
											)
										)
									)
								)
							)
						)
					]
				)
			)
		);
	}
}

class SettingsLoginPanel extends StatefulWidget {
	final ImageboardSiteLoginSystem loginSystem;
	const SettingsLoginPanel({
		required this.loginSystem,
		Key? key
	}) : super(key: key);

	@override
	createState() => _SettingsLoginPanelState();
}

class _SettingsLoginPanelState extends State<SettingsLoginPanel> {
	Map<ImageboardSiteLoginField, String>? savedFields;
	bool loading = true;

	Future<void> _updateStatus() async {
		final newSavedFields = widget.loginSystem.getSavedLoginFields();
		setState(() {
			savedFields = newSavedFields;
			loading = false;
		});
	}

	@override
	void initState() {
		super.initState();
		_updateStatus();
	}

	Future<void> _login() async {
		final fields = {
			for (final field in widget.loginSystem.getLoginFields()) field: ''
		};
		final cont = await showAdaptiveDialog<bool>(
			context: context,
			builder: (context) => AdaptiveAlertDialog(
				title: Text('${widget.loginSystem.name} Login'),
				content: ListBody(
					children: [
						const SizedBox(height: 8),
						for (final field in fields.keys) ...[
							Text(field.displayName, textAlign: TextAlign.left),
							const SizedBox(height: 8),
							AdaptiveTextField(
								autofocus: field == fields.keys.first,
								onChanged: (value) {
									fields[field] = value;
								},
								smartDashesType: SmartDashesType.disabled,
								smartQuotesType: SmartQuotesType.disabled,
								autofillHints: field.autofillHints,
								keyboardType: field.inputType
							),
							const SizedBox(height: 16),
						]
					]
				),
				actions: [
					AdaptiveDialogAction(
						child: const Text('Login'),
						onPressed: () => Navigator.pop(context, true)
					),
					AdaptiveDialogAction(
						child: const Text('Cancel'),
						onPressed: () => Navigator.pop(context)
					)
				]
			)
		);
		if (cont == true) {
			print(fields);
			try {
				await widget.loginSystem.login(null, fields);
				widget.loginSystem.parent.persistence?.browserState.loginFields.clear();
				widget.loginSystem.parent.persistence?.browserState.loginFields.addAll({
					for (final field in fields.entries) field.key.formKey: field.value
				});
				widget.loginSystem.parent.persistence?.didUpdateBrowserState();
			}
			catch (e) {
				if (!mounted) return;
				alertError(context, e.toStringDio());
			}
			await _updateStatus();
		}
	}

	@override
	Widget build(BuildContext context) {
		return Column(
			mainAxisSize: MainAxisSize.min,
			children: [
				if (loading) const Center(
					child: CircularProgressIndicator.adaptive()
				)
				else if (savedFields != null) ...[
					const Text('Credentials saved\n'),
					Wrap(
						spacing: 16,
						runSpacing: 16,
						children: [
							AdaptiveFilledButton(
								child: const Text('Remove'),
								onPressed: () async {
									setState(() {
										loading = true;
									});
									try {
										await widget.loginSystem.clearLoginCookies(null, true);
										await widget.loginSystem.clearSavedLoginFields();
									}
									catch (e) {
										if (context.mounted) {
											await alertError(context, e.toStringDio());
										}
									}
									await _updateStatus();
								}
							)
						]
					)
				]
				else ...[
					AdaptiveFilledButton(
						child: const Text('Login'),
						onPressed: () async {
							try {
								await _login();
							}
							catch (e) {
								if (context.mounted) {
									await alertError(context, e.toStringDio());
								}
							}
						}
					)
				],
				const SegmentedSettingWidget(
					description: 'Use on mobile data?',
					knownWidth: 300,
					setting: MappedSetting(
						Settings.autoLoginOnMobileNetworkSetting,
						FieldMappers.nullSafeOptionalify,
						FieldMappers.unNullSafeOptionalify
					),
					children: {
						NullSafeOptional.false_: (null, 'No'),
						NullSafeOptional.null_: (null, 'Ask'),
						NullSafeOptional.true_: (null, 'Yes')
					}
				).build()
			]
		);
	}
}

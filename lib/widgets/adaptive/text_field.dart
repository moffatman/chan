import 'package:chan/services/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AdaptiveTextField extends StatelessWidget {
	final bool autocorrect;
	final Iterable<String>? autofillHints;
	final bool autofocus;
	final EditableTextContextMenuBuilder? contextMenuBuilder;
	final TextEditingController? controller;
	final bool? enabled;
	final bool enableIMEPersonalizedLearning;
	final bool enableSuggestions;
	final FocusNode? focusNode;
	final Brightness? keyboardAppearance;
	final TextInputType? keyboardType;
	final int? maxLines;
	final int? minLines;
	final ValueChanged<String>? onChanged;
	final ValueChanged<String>? onSubmitted;
	final GestureTapCallback? onTap;
	final String? placeholder;
	final TextStyle? placeholderStyle;
	final SmartDashesType? smartDashesType;
	final SmartQuotesType? smartQuotesType;
	final SpellCheckConfiguration? spellCheckConfiguration;
	final TextStyle? style;
	final Widget? suffix;
	final TextAlign textAlign;
	final TextCapitalization textCapitalization;

	const AdaptiveTextField({
		this.autocorrect = true,
		this.autofillHints = const [],
		this.autofocus = false,
		this.contextMenuBuilder,
		this.controller,
		this.enabled,
		this.enableIMEPersonalizedLearning = true,
		this.enableSuggestions = true,
		this.focusNode,
		this.keyboardAppearance,
		this.keyboardType,
		this.maxLines = 1,
		this.minLines,
		this.onChanged,
		this.onSubmitted,
		this.onTap,
		this.placeholder,
		this.placeholderStyle,
		this.smartDashesType,
		this.smartQuotesType,
		this.spellCheckConfiguration,
		this.style,
		this.suffix,
		this.textAlign = TextAlign.start,
		this.textCapitalization = TextCapitalization.none,
		super.key
	});

	@override
	Widget build(BuildContext context) {
		if (ChanceTheme.materialOf(context)) {
			return TextField(
				autocorrect: autocorrect,
				autofillHints: autofillHints,
				autofocus: autofocus,
				contextMenuBuilder: contextMenuBuilder,
				controller: controller,
				decoration: InputDecoration(
					fillColor: ChanceTheme.textFieldColorOf(context),
					border: OutlineInputBorder(
						borderSide: BorderSide(
							color: ChanceTheme.primaryColorWithBrightness70Of(context),
							width: 0
						)
					),
					enabledBorder: OutlineInputBorder(
						borderSide: BorderSide(
							color: ChanceTheme.primaryColorWithBrightness70Of(context),
							width: 0
						)
					),
					labelText: placeholder,
					labelStyle: TextStyle(
						color: ChanceTheme.primaryColorWithBrightness50Of(context)
					).merge(placeholderStyle),
					suffixIcon: suffix,
					isDense: true
				),
				enabled: enabled,
				enableIMEPersonalizedLearning: enableIMEPersonalizedLearning,
				enableSuggestions: enableSuggestions,
				focusNode: focusNode,
				keyboardAppearance: keyboardAppearance,
				keyboardType: keyboardType,
				maxLines: maxLines,
				minLines: minLines,
				onChanged: onChanged,
				onSubmitted: onSubmitted,
				onTap: onTap,
				smartDashesType: smartDashesType,
				smartQuotesType: smartQuotesType,
				spellCheckConfiguration: spellCheckConfiguration,
				style: style,
				textAlign: textAlign,
				textCapitalization: textCapitalization
			);
		}
		return CupertinoTextField(
			autocorrect: autocorrect,
			autofillHints: autofillHints,
			autofocus: autofocus,
			contextMenuBuilder: contextMenuBuilder,
			controller: controller,
			decoration: BoxDecoration(
				color: ChanceTheme.textFieldColorOf(context),
				border: Border.all(
					color: const CupertinoDynamicColor.withBrightness(
						color: Color(0x33000000),
						darkColor: Color(0x33FFFFFF),
					),
					width: 0
				),
				borderRadius: const BorderRadius.all(Radius.circular(5.0))
			),
			enabled: enabled,
			enableIMEPersonalizedLearning: enableIMEPersonalizedLearning,
			enableSuggestions: enableSuggestions,
			focusNode: focusNode,
			keyboardAppearance: keyboardAppearance,
			keyboardType: keyboardType,
			maxLines: maxLines,
			minLines: minLines,
			onChanged: onChanged,
			onSubmitted: onSubmitted,
			onTap: onTap,
			placeholder: placeholder,
			placeholderStyle: placeholderStyle ?? const TextStyle(
				fontWeight: FontWeight.w400,
				color: CupertinoColors.placeholderText,
			),
			smartDashesType: smartDashesType,
			smartQuotesType: smartQuotesType,
			spellCheckConfiguration: spellCheckConfiguration,
			style: style,
			suffix: suffix,
			textAlign: textAlign,
			textCapitalization: textCapitalization
		);
	}
}

class AdaptiveSearchTextField extends StatelessWidget {
	final TextEditingController? controller;
	final bool enableIMEPersonalizedLearning;
	final FocusNode? focusNode;
	final ValueChanged<String>? onChanged;
	final ValueChanged<String>? onSubmitted;
	final VoidCallback? onSuffixTap;
	final VoidCallback? onTap;
	final String? placeholder;
	final Widget? prefixIcon;
	final SmartDashesType? smartDashesType;
	final SmartQuotesType? smartQuotesType;
	final bool? suffixVisible;

	const AdaptiveSearchTextField({
		this.controller,
		this.enableIMEPersonalizedLearning = true,
		this.focusNode,
		this.onChanged,
		this.onSubmitted,
		this.onSuffixTap,
		this.onTap,
		this.placeholder,
		this.prefixIcon = const Icon(CupertinoIcons.search),
		this.smartDashesType,
		this.smartQuotesType,
		this.suffixVisible,
		super.key
	});

	@override
	Widget build(BuildContext context) {
		if (ChanceTheme.materialOf(context)) {
			final border = OutlineInputBorder(
				borderSide: BorderSide(
					color: ChanceTheme.searchTextFieldColorOf(context),
					width: 0
				)
			);
			return TextField(
				decoration: InputDecoration(
					fillColor: ChanceTheme.searchTextFieldColorOf(context),
					filled: true,
					suffixIcon: (suffixVisible ?? (controller?.text.isNotEmpty ?? false) ? IconButton(
						icon: const Icon(Icons.clear),
						color: ChanceTheme.primaryColorOf(context),
						onPressed: onSuffixTap ?? () {
							controller?.clear();
							focusNode?.unfocus();
						},
					) : null),
					border: border,
					enabledBorder: border,
					focusedBorder: null,
					labelText: placeholder,
					prefixIcon: prefixIcon ?? const SizedBox.shrink(),
					prefixIconConstraints: prefixIcon == null ? const BoxConstraints.tightFor(width: 12, height: 48) : null,
					prefixIconColor: ChanceTheme.primaryColorOf(context),
					labelStyle: TextStyle(
						color: ChanceTheme.primaryColorOf(context)
					),
					floatingLabelBehavior: FloatingLabelBehavior.never,
					contentPadding: const EdgeInsetsDirectional.only(end: 8),
					isDense: true
				),
				controller: controller,
				enableIMEPersonalizedLearning: enableIMEPersonalizedLearning,
				focusNode: focusNode,
				onChanged: onChanged,
				onSubmitted: onSubmitted,
				onTap: onTap,
				smartDashesType: smartDashesType,
				smartQuotesType: smartQuotesType
			);
		}
		return CupertinoSearchTextField(
			backgroundColor: ChanceTheme.searchTextFieldColorOf(context),
			controller: controller,
			enableIMEPersonalizedLearning: enableIMEPersonalizedLearning,
			focusNode: focusNode,
			onChanged: onChanged,
			onSubmitted: onSubmitted,
			suffixMode: switch(suffixVisible) {
				true => OverlayVisibilityMode.always,
				null => OverlayVisibilityMode.editing,
				false => OverlayVisibilityMode.never
			},
			onSuffixTap: onSuffixTap,
			onTap: onTap,
			placeholder: placeholder,
			prefixIcon: prefixIcon ?? const SizedBox.shrink(),
			smartDashesType: smartDashesType,
			smartQuotesType: smartQuotesType
		);
	}
}
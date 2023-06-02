import 'package:chan/services/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class CupertinoTextField2 extends StatelessWidget {
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

	const CupertinoTextField2({
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
		this.placeholderStyle = const TextStyle(
      fontWeight: FontWeight.w400,
      color: CupertinoColors.placeholderText,
    ),
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
		return CupertinoTextField(
			autocorrect: autocorrect,
			autofillHints: autofillHints,
			autofocus: autofocus,
			contextMenuBuilder: contextMenuBuilder,
			controller: controller,
			decoration: BoxDecoration(
				color: context.select<EffectiveSettings, Color>((s) => s.theme.textFieldColor),
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
			placeholderStyle: placeholderStyle,
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

class CupertinoSearchTextField2 extends StatelessWidget {
	final TextEditingController? controller;
	final bool enableIMEPersonalizedLearning;
	final FocusNode? focusNode;
	final ValueChanged<String>? onChanged;
	final ValueChanged<String>? onSubmitted;
	final VoidCallback? onSuffixTap;
	final VoidCallback? onTap;
	final String? placeholder;
	final Widget prefixIcon;
	final SmartDashesType? smartDashesType;
	final SmartQuotesType? smartQuotesType;

	const CupertinoSearchTextField2({
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
		super.key
	});

	@override
	Widget build(BuildContext context) {
		return CupertinoSearchTextField(
			backgroundColor: context.select<EffectiveSettings, Color>((s) => s.theme.searchTextFieldColor),
			controller: controller,
			enableIMEPersonalizedLearning: enableIMEPersonalizedLearning,
			focusNode: focusNode,
			onChanged: onChanged,
			onSubmitted: onSubmitted,
			onSuffixTap: onSuffixTap,
			onTap: onTap,
			placeholder: placeholder,
			prefixIcon: prefixIcon,
			smartDashesType: smartDashesType,
			smartQuotesType: smartQuotesType
		);
	}
}
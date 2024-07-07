import 'package:chan/services/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AdaptiveTextField extends StatefulWidget {
	final bool autocorrect;
	final Iterable<String>? autofillHints;
	final bool autofocus;
	final ContentInsertionConfiguration? contentInsertionConfiguration;
	final EditableTextContextMenuBuilder? contextMenuBuilder;
	final TextEditingController? controller;
	final bool enabled;
	final bool enableIMEPersonalizedLearning;
	final bool enableSuggestions;
	final bool expands;
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
	final OverlayVisibilityMode suffixMode;
	final TextAlign textAlign;
	final TextAlignVertical? textAlignVertical;
	final TextCapitalization textCapitalization;

	const AdaptiveTextField({
		this.autocorrect = true,
		this.autofillHints = const [],
		this.autofocus = false,
		this.contentInsertionConfiguration,
		this.contextMenuBuilder,
		this.controller,
		this.enabled = true,
		this.enableIMEPersonalizedLearning = true,
		this.enableSuggestions = true,
		this.expands = false,
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
		this.suffixMode = OverlayVisibilityMode.always,
		this.textAlign = TextAlign.start,
		this.textAlignVertical,
		this.textCapitalization = TextCapitalization.none,
		super.key
	});

	@override
	createState() => AdaptiveTextFieldState();
}

class AdaptiveTextFieldState extends State<AdaptiveTextField> {
	final _textFieldKey = GlobalKey(debugLabel: 'AdaptiveTextFieldState._textFieldKey');

	 static Widget _defaultMaterialContextMenuBuilder(BuildContext context, EditableTextState editableTextState) {
		return AdaptiveTextSelectionToolbar.editableText(
			editableTextState: editableTextState,
		);
	}

	Widget _defaultCupertinoContextMenuBuilder(BuildContext context, EditableTextState editableTextState) {
		return CupertinoAdaptiveTextSelectionToolbar.editableText(
			editableTextState: editableTextState,
		);
	}

	EditableTextState? get editableText {
		final textFieldState = _textFieldKey.currentState;
		if (textFieldState is TextSelectionGestureDetectorBuilderDelegate) {
			return (textFieldState as TextSelectionGestureDetectorBuilderDelegate).editableTextKey.currentState;
		}
		return null;
	}

	@override
	Widget build(BuildContext context) {
		if (ChanceTheme.materialOf(context)) {
			return TextField(
				key: _textFieldKey,
				autocorrect: widget.autocorrect,
				autofillHints: widget.autofillHints,
				autofocus: widget.autofocus,
				contentInsertionConfiguration: widget.contentInsertionConfiguration,
				contextMenuBuilder: widget.contextMenuBuilder ?? _defaultMaterialContextMenuBuilder,
				controller: widget.controller,
				decoration: InputDecoration(
					fillColor: ChanceTheme.textFieldColorOf(context),
					alignLabelWithHint: (widget.maxLines ?? 2) > 1,
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
					labelText: widget.placeholder,
					labelStyle: TextStyle(
						color: ChanceTheme.primaryColorWithBrightness50Of(context)
					).merge(widget.placeholderStyle),
					suffixIcon: (widget.controller == null || widget.suffix == null) ? widget.suffix : AnimatedBuilder(
						animation: widget.controller!,
						builder: (context, _) {
							Widget? ret;
							if (widget.controller!.text.isNotEmpty) {
								ret = widget.suffix;
							}
							return ret ?? const SizedBox.shrink();
						}
					),
					isDense: true
				),
				enabled: widget.enabled,
				enableIMEPersonalizedLearning: widget.enableIMEPersonalizedLearning,
				enableSuggestions: widget.enableSuggestions,
				expands: widget.expands,
				focusNode: widget.focusNode,
				keyboardAppearance: widget.keyboardAppearance,
				keyboardType: widget.keyboardType,
				maxLines: widget.maxLines,
				minLines: widget.minLines,
				onChanged: widget.onChanged,
				onSubmitted: widget.onSubmitted,
				onTap: widget.onTap,
				smartDashesType: widget.smartDashesType,
				smartQuotesType: widget.smartQuotesType,
				spellCheckConfiguration: widget.spellCheckConfiguration,
				style: widget.style,
				textAlign: widget.textAlign,
				textAlignVertical: widget.textAlignVertical,
				textCapitalization: widget.textCapitalization
			);
		}
		final placeholderColor = ChanceTheme.primaryColorOf(context).withOpacity(0.75);
		return Opacity(
			opacity: widget.enabled ? 1 : 0.5,
			child: CupertinoTextField(
				key: _textFieldKey,
				autocorrect: widget.autocorrect,
				autofillHints: widget.autofillHints,
				autofocus: widget.autofocus,
				contentInsertionConfiguration: widget.contentInsertionConfiguration,
				contextMenuBuilder: widget.contextMenuBuilder ?? _defaultCupertinoContextMenuBuilder,
				controller: widget.controller,
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
				enabled: widget.enabled,
				enableIMEPersonalizedLearning: widget.enableIMEPersonalizedLearning,
				enableSuggestions: widget.enableSuggestions,
				expands: widget.expands,
				focusNode: widget.focusNode,
				keyboardAppearance: widget.keyboardAppearance,
				keyboardType: widget.keyboardType,
				maxLines: widget.maxLines,
				minLines: widget.minLines,
				onChanged: widget.onChanged,
				onSubmitted: widget.onSubmitted,
				onTap: widget.onTap,
				placeholder: widget.placeholder,
				placeholderStyle: widget.placeholderStyle ?? TextStyle(
					fontWeight: FontWeight.w400,
					color: placeholderColor,
				),
				smartDashesType: widget.smartDashesType,
				smartQuotesType: widget.smartQuotesType,
				spellCheckConfiguration: widget.spellCheckConfiguration,
				style: widget.style,
				suffix: widget.suffix,
				suffixMode: widget.suffixMode,
				textAlign: widget.textAlign,
				textAlignVertical: widget.textAlignVertical,
				textCapitalization: widget.textCapitalization
			)
		);
	}
}

class AdaptiveSearchTextField extends StatelessWidget {
	final bool autofocus;
	final TextEditingController? controller;
	final bool enableIMEPersonalizedLearning;
	final FocusNode? focusNode;
	final ValueChanged<String>? onChanged;
	final ValueChanged<String>? onSubmitted;
	final VoidCallback? onSuffixTap;
	final VoidCallback? onTap;
	final String? placeholder;
	final IconData? prefixIcon;
	final SmartDashesType? smartDashesType;
	final SmartQuotesType? smartQuotesType;
	final bool? suffixVisible;

	const AdaptiveSearchTextField({
		this.autofocus = false,
		this.controller,
		this.enableIMEPersonalizedLearning = true,
		this.focusNode,
		this.onChanged,
		this.onSubmitted,
		this.onSuffixTap,
		this.onTap,
		this.placeholder,
		this.prefixIcon = CupertinoIcons.search,
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
				autofocus: autofocus,
				decoration: InputDecoration(
					fillColor: ChanceTheme.searchTextFieldColorOf(context),
					filled: true,
					suffixIcon: (suffixVisible ?? (controller?.text.isNotEmpty ?? false) ? IconButton(
						icon: const Icon(Icons.clear),
						color: ChanceTheme.primaryColorOf(context),
						onPressed: onSuffixTap ?? () {
							controller?.clear();
							focusNode?.unfocus();
							onChanged?.call('');
						},
					) : null),
					border: border,
					enabledBorder: border,
					focusedBorder: null,
					labelText: placeholder,
					prefixIcon: prefixIcon == null ? const SizedBox.shrink() : Icon(prefixIcon),
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
		final placeholderColor = ChanceTheme.primaryColorOf(context).withOpacity(0.75);
		return CupertinoSearchTextField(
			autofocus: autofocus,
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
			placeholderStyle: TextStyle(
				color: placeholderColor
			),
			onSuffixTap: onSuffixTap,
			onTap: onTap,
			placeholder: placeholder,
			prefixIcon: prefixIcon == null ? const SizedBox.shrink() : Padding(
				padding: const EdgeInsets.only(top: 3),
				child: Icon(prefixIcon, color: placeholderColor)
			),
			smartDashesType: smartDashesType,
			smartQuotesType: smartQuotesType
		);
	}
}
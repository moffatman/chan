import 'dart:ui' as ui;

import 'package:chan/services/css.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
	test('css', () {
		Map<String, String> resolveInlineCssText(String css) => {
			for (final entry in resolveInlineCss(css).entries)
				entry.key: entry.value.string
		};
		expect(resolveInlineCssText('display:none;display:inline'), {'display': 'inline'});
		expect(resolveInlineCssText('display:inline;display:none'), {'display': 'none'});
		expect(resolveInlineCssText('display:inline !important;display:none'), {'display': 'inline'});
		expect(resolveInlineCssText('display:inline !important !important;display:none'), {'display': 'none'});
		expect(resolveInlineCssText('display:none;display:block flow'), {'display': 'block flow'});
		expect(resolveInlineCssText('/*comment*/display/*comment*/:/*comment*/none /* junk comment */;/*comment*/display/*comment*/:/*comment*/inline /* comment */ /*comment*/'), {'display': 'inline'});
		expect(resolveInlineCss('opacity: 100%')['opacity']?.scalar, 1);
		expect(resolveInlineCss('opacity: 0%')['opacity']?.scalar, 0);
		expect(resolveInlineCss('opacity: 3%')['opacity']?.scalar, 0.03);
		expect(resolveInlineCss('opacity: 0')['opacity']?.scalar, 0);
		expect(resolveInlineCss('opacity: 0.3')['opacity']?.scalar, 0.3);
		expect(resolveInlineCss('margin: auto')['margin']?.edges, const CssEdgeSizes.all(CssEdgeSizeAuto()));
		expect(resolveInlineCss('margin: 1px 2px 3px 4px')['margin']?.edges, const CssEdgeSizes.only(
			top: CssEdgeSizePixels(1),
			right: CssEdgeSizePixels(2),
			bottom: CssEdgeSizePixels(3),
			left: CssEdgeSizePixels(4)
		));
		expect(resolveInlineCss('color: rgb(123, 234, 32)')['color']?.color, const ui.Color.fromARGB(255, 123, 234, 32));
		expect(resolveInlineCss('color: rgb(123 234 32)')['color']?.color, const ui.Color.fromARGB(255, 123, 234, 32));
		expect(resolveInlineCss('color: red')['color']?.color, const ui.Color.fromARGB(255, 255, 0, 0));
		expect(resolveInlineCss('color: #12345678')['color']?.color, const ui.Color.fromARGB(0x12, 0x34, 0x56, 0x78));
		expect(resolveInlineCss('color: #123456')['color']?.color, const ui.Color.fromARGB(0xFF, 0x12, 0x34, 0x56));
		expect(resolveInlineCss('color: rgb(123, 234, 32, 56%)')['color']?.color, const ui.Color.fromRGBO(123, 234, 32, 0.56));
		expect(resolveInlineCss('color: rgb(123 234 32 / 0.87)')['color']?.color, const ui.Color.fromRGBO(123, 234, 32, 0.87));
		expect(resolveInlineCss('text-shadow: 1px 1px 2px black, #ffcc00 1px 0 10px, 5px 5px #558abb, white 2px 5px, 5px 10px')['text-shadow']?.shadows, const [
			ui.Shadow(
				color: ui.Color(0xFF000000),
				offset: Offset(1, 1),
				blurRadius: 2
			),
			ui.Shadow(
				color: ui.Color(0xFFFFCC00),
				offset: Offset(1, 0),
				blurRadius: 10
			),
			ui.Shadow(
				offset: Offset(5, 5),
				color: ui.Color(0xFF558ABB),
				blurRadius: 0 // default
			),
			ui.Shadow(
				offset: Offset(2, 5),
				color: ui.Color(0xFFFFFFFF),
				blurRadius: 0 // default
			),
			ui.Shadow(
				offset: Offset(5, 10),
				color: ui.Color(0xFF000000), // default
				blurRadius: 0 // default
			)
		]);
	});
}

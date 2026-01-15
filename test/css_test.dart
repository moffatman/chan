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
	});
}

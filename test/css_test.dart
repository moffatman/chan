import 'package:chan/services/css.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
	test('css', () {
		expect(resolveInlineCss('display:none;display:inline'), {'display': 'inline'});
		expect(resolveInlineCss('display:inline;display:none'), {'display': 'none'});
		expect(resolveInlineCss('display:inline !important;display:none'), {'display': 'inline'});
		expect(resolveInlineCss('display:inline !important !important;display:none'), {'display': 'none'});
		expect(resolveInlineCss('display:none;display:block flow'), {'display': 'block flow'});
		expect(resolveInlineCss('/*comment*/display/*comment*/:/*comment*/none /* junk comment */;/*comment*/display/*comment*/:/*comment*/inline /* comment */ /*comment*/'), {'display': 'inline'});
	});
}

import 'package:csslib/parser.dart';
import 'package:csslib/visitor.dart';

const _kValues = {
	'display': {
		'block', 'inline', 'inline-block', 'flex', 'inline-flex', 'grid', 'inline-grid', 'flow-root',
		'none', 'contents',
		'block flex', 'block flow', 'block flow-root', 'block grid', 'inline flex', 'inline flow', 'inline flow-root', 'inline grid',
		'table', 'table-row', 'list-item'
	},
	'visibility': {'visible', 'hidden', 'collapse'}
};
const _kGlobalValues = {'inherit', 'initial', 'revert', 'revert-layer', 'unset'};

extension _ToString on Expression {
	String get stringValue => switch (this) {
		Expressions expressions => expressions.expressions.map((e) => e.stringValue).join(' '),
		LiteralTerm literalTerm => literalTerm.text,
		_ => toString()
	};
}

Map<String, String> resolveInlineCss(String css) {
	final declarations = <String, ({String value, bool important})>{};
	final group = parseDeclarations(css);
	for (final declaration in group.declarations) {
		if (declaration is Declaration) {
			final value = declaration.expression?.stringValue;
			if (value == null) {
				// Skip
				continue;
			}
			if (!((_kValues[declaration.property]?.contains(value) ?? true) || _kGlobalValues.contains(value))) {
				// Not allowed value
				continue;
			}
			if ((declarations[declaration.property]?.important ?? false) && !declaration.important) {
				// Can't override earlier important declaration
				continue;
			}
			declarations[declaration.property] = (value: value, important: declaration.important);
		}
	}
	return {
		for (final d in declarations.entries)
			d.key: d.value.value
	};
}

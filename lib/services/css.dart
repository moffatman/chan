import 'package:csslib/parser.dart';
import 'package:csslib/visitor.dart';
export 'package:csslib/visitor.dart' show Expression;

const _kStringValues = {
	'display': {
		'block', 'inline', 'inline-block', 'flex', 'inline-flex', 'grid', 'inline-grid', 'flow-root',
		'none', 'contents',
		'block flex', 'block flow', 'block flow-root', 'block grid', 'inline flex', 'inline flow', 'inline flow-root', 'inline grid',
		'table', 'table-row', 'list-item'
	},
	'visibility': {'visible', 'hidden', 'collapse'}
};
const _kGlobalStringValues = {'inherit', 'initial', 'revert', 'revert-layer', 'unset'};

sealed class CssEdgeSize {
	const CssEdgeSize();
}

class CssEdgeSizePixels extends CssEdgeSize {
	final double pixels;
	const CssEdgeSizePixels(this.pixels);

	@override
	String toString() => 'CssEdgeSizePixels($pixels)';

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is CssEdgeSizePixels &&
		other.pixels == pixels;
	
	@override
	int get hashCode => pixels.hashCode;
}

class CssEdgeSizeFractional extends CssEdgeSize {
	final double fraction;
	const CssEdgeSizeFractional(this.fraction);

	@override
	String toString() => 'CssEdgeSizeFractional($fraction)';

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is CssEdgeSizeFractional &&
		other.fraction == fraction;
	
	@override
	int get hashCode => fraction.hashCode;
}

class CssEdgeSizeAuto extends CssEdgeSize {
	const CssEdgeSizeAuto();
	
	@override
	String toString() => 'CssEdgeSizeAuto()';

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is CssEdgeSizeAuto;
	
	@override
	int get hashCode => 0;
}

class CssEdgeSizes {
	final CssEdgeSize left;
	final CssEdgeSize top;
	final CssEdgeSize right;
	final CssEdgeSize bottom;

	const CssEdgeSizes.only({
		this.left = const CssEdgeSizePixels(0),
		this.top = const CssEdgeSizePixels(0),
		this.right = const CssEdgeSizePixels(0),
		this.bottom = const CssEdgeSizePixels(0)
	});

	const CssEdgeSizes.all(CssEdgeSize value) : left = value, top = value, right = value, bottom = value;

	@override
	String toString() => 'CssEdgeSizes(left: $left, top: $top, right: $right, bottom: $bottom)';

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is CssEdgeSizes &&
		other.left == left &&
		other.top == top &&
		other.right == right &&
		other.bottom == bottom;
	
	@override
	int get hashCode => Object.hash(left, top, right, bottom);
}

extension ToString on Expression {
	String get string => switch (this) {
		Expressions expressions => expressions.expressions.map((e) => e.string).join(' '),
		LiteralTerm literalTerm => literalTerm.text,
		_ => toString()
	};
	double? get scalar => switch (this) {
		Expressions(expressions: [Expression e]) => e.scalar,
		NumberTerm(value: num x) => x.toDouble(),
		PercentageTerm(value: num x) => x.toDouble() / 100,
		_ => null
	};
	CssEdgeSizes? get edges {
		final parts = switch (this) {
			Expressions expressions => expressions.expressions,
			Expression single => [single]
		}.map((expr) => switch (expr) {
			NumberTerm(value: num value) => CssEdgeSizePixels(value.toDouble()),
			PercentageTerm(value: num value) => CssEdgeSizeFractional(value.toDouble() / 100),
			LengthTerm(value: num value, unit: int unit) => switch (unit) {
				TokenKind.UNIT_LENGTH_PX => CssEdgeSizePixels(value.toDouble()),
				TokenKind.UNIT_LENGTH_CM => CssEdgeSizePixels((96/2.54) * value.toDouble()),
        TokenKind.UNIT_LENGTH_MM => CssEdgeSizePixels((96/0.254) * value.toDouble()),
        TokenKind.UNIT_LENGTH_IN => CssEdgeSizePixels(96 * value.toDouble()),
        TokenKind.UNIT_LENGTH_PT => CssEdgeSizePixels((4/3) * value.toDouble()),
        TokenKind.UNIT_LENGTH_PC => CssEdgeSizePixels(16 * value.toDouble()),
				_ => null
			},
			LiteralTerm(text: 'auto') => const CssEdgeSizeAuto(),
			_ => null
		}).toList();
		return switch (parts) {
			[CssEdgeSize single] => CssEdgeSizes.all(single),
			[CssEdgeSize vertical, CssEdgeSize horizontal] => CssEdgeSizes.only(
				left: horizontal,
				right: horizontal,
				top: vertical,
				bottom: vertical
			),
			[CssEdgeSize top, CssEdgeSize horizontal, CssEdgeSize bottom] => CssEdgeSizes.only(
				top: top,
				left: horizontal,
				right: horizontal,
				bottom: bottom
			),
			[CssEdgeSize top, CssEdgeSize right, CssEdgeSize bottom, CssEdgeSize left] => CssEdgeSizes.only(
				top: top,
				right: right,
				bottom: bottom,
				left: left
			),
			_ => null
		};
	}
}

Map<String, Expression> resolveInlineCss(String css) {
	final declarations = <String, ({Expression expression, bool important})>{};
	final group = parseDeclarations(css);
	for (final declaration in group.declarations) {
		if (declaration is Declaration) {
			final expression = declaration.expression;
			if (expression == null) {
				continue;
			}
			final stringValue = expression.string;
			if (!((_kStringValues[declaration.property]?.contains(stringValue) ?? true) || _kGlobalStringValues.contains(stringValue))) {
				// Not allowed value
				continue;
			}
			if ((declarations[declaration.property]?.important ?? false) && !declaration.important) {
				// Can't override earlier important declaration
				continue;
			}
			declarations[declaration.property] = (expression: expression, important: declaration.important);
		}
	}
	return {
		for (final d in declarations.entries)
			d.key: d.value.expression
	};
}

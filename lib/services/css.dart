import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:chan/util.dart';
import 'package:chan/widgets/util.dart';
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
	'visibility': {'visible', 'hidden', 'collapse'},
	'float': {'left', 'right', 'none', 'inline-start', 'inline-end'}
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
		Expressions expressions => expressions.expressions.expand((e) {
			if (e is OperatorComma) {
				// Quirk: no space before comma
				return [','];
			}
			return [' ', e.string];
		}).skip(1).join(),
		FunctionTerm function => '${function.text}(${function.params.string})',
		LiteralTerm literalTerm => literalTerm.text,
		OperatorComma() => ',',
		_ => toString()
	};
	double? get scalar => switch (this) {
		Expressions(expressions: [Expression e]) => e.scalar,
		NumberTerm(value: num x) => x.toDouble(),
		PercentageTerm(value: num x) => x.toDouble() / 100,
		_ => null
	};
	double? get pixels => switch (this) {
		LengthTerm(value: num value, unit: int unit) => switch (unit) {
			TokenKind.UNIT_LENGTH_PX => value.toDouble(),
			TokenKind.UNIT_LENGTH_CM => (96/2.54) * value.toDouble(),
			TokenKind.UNIT_LENGTH_MM => (96/0.254) * value.toDouble(),
			TokenKind.UNIT_LENGTH_IN => 96 * value.toDouble(),
			TokenKind.UNIT_LENGTH_PT => (4/3) * value.toDouble(),
			TokenKind.UNIT_LENGTH_PC => 16 * value.toDouble(),
			_ => null
		},
		NumberTerm(value: 0) => 0,
		_ => null
	};
	CssEdgeSizes? get edges {
		final parts = switch (this) {
			Expressions expressions => expressions.expressions,
			Expression single => [single]
		}.map((expr) => switch (expr) {
			NumberTerm(value: num value) => CssEdgeSizePixels(value.toDouble()),
			PercentageTerm(value: num value) => CssEdgeSizeFractional(value.toDouble() / 100),
			LengthTerm term => switch (term.pixels) {
				double pixels => CssEdgeSizePixels(pixels),
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
	ui.Color? get color => switch (this) {
		// Need to add alpha bits if not specified
		HexColorTerm(value: int color, text: String text) when text.length <= 6 => ui.Color(0xFF000000 | color),
		HexColorTerm(value: int color) => ui.Color(color),
		FunctionTerm(text: 'rgb' || 'rgba', params: Expressions(expressions: [
			NumberTerm(value: num r), OperatorComma(),
			NumberTerm(value: num g), OperatorComma(),
			NumberTerm(value: num b)
		] || [
			NumberTerm(value: num r), NumberTerm(value: num g), NumberTerm(value: num b)
		])) => ui.Color.fromARGB(255, r.toInt().clamp(0, 255), g.toInt().clamp(0, 255), b.toInt().clamp(0, 255)),
		FunctionTerm(text: 'rgb' || 'rgba', params: Expressions(expressions: [
			NumberTerm(value: num r), OperatorComma(),
			NumberTerm(value: num g), OperatorComma(),
			NumberTerm(value: num b), OperatorComma(),
			LiteralTerm alpha
		] || [
			NumberTerm(value: num r), NumberTerm(value: num g), NumberTerm(value: num b), OperatorSlash(), LiteralTerm alpha
		])) => ui.Color.fromRGBO(r.toInt().clamp(0, 255), g.toInt().clamp(0, 255), b.toInt().clamp(0, 255), alpha.scalar?.clamp(0, 1) ?? 1),
		LengthTerm() => null,
		LiteralTerm term => colorToHex(term.text, requireHash: true),
		Expressions(expressions: [Expression single]) => single.color,
		_ => null
	};
	ui.Gradient? linearGradient(ui.Rect rect, {ui.TileMode tileMode = ui.TileMode.clamp}) {
		final parameters = switch (this) {
			FunctionTerm(text: 'linear-gradient', params: Expressions p) => p,
			Expressions(expressions: [FunctionTerm(text: 'linear-gradient', params: Expressions p)]) => p,
			_ => null
		}?.expressions;
		if (parameters == null) {
			return null;
		}
		final argGroups = parameters.splitWhere((e) => e is OperatorComma);
		double radians = 1;
		final colors = <ui.Color>[];
		for (final group in argGroups) {
			switch (group) {
				case [LiteralTerm(text: 'to'), LiteralTerm(text: 'left')]:
					radians = 1.5 * math.pi;
				case [LiteralTerm(text: 'to'), LiteralTerm(text: 'right')]:
					radians = 0.5 * math.pi;
				case [LiteralTerm(text: 'to'), LiteralTerm(text: 'top')]:
					radians = 0;
				case [LiteralTerm(text: 'to'), LiteralTerm(text: 'bottom')]:
					radians = math.pi;
				case [AngleTerm(value: num angle, unit: TokenKind.UNIT_ANGLE_DEG)]:
					radians = angle.toDouble() * (math.pi / 180);
				case [AngleTerm(value: num angle, unit: TokenKind.UNIT_ANGLE_RAD)]:
					radians = angle.toDouble();
				case [AngleTerm(value: num angle, unit: TokenKind.UNIT_ANGLE_GRAD)]:
					radians = angle.toDouble() * (math.pi / 200);
				case [AngleTerm(value: num angle, unit: TokenKind.UNIT_ANGLE_TURN)]:
					radians = angle.toDouble() * (2 * math.pi);
				case [HexColorTerm color]:
					colors.maybeAdd(color.color);
				default:
					return null;
			}
		}
		// Need to pick points such that 0 and 1 are contained within the rectangle
		final dir = ui.Offset(math.sin(radians), -math.cos(radians));
		double dot(ui.Offset p) => p.dx * dir.dx + p.dy * dir.dy;
		double minDot = double.infinity;
		double maxDot = -double.infinity;
		for (final p in [rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight]) {
			final d = dot(p);
			if (d < minDot) minDot = d;
			if (d > maxDot) maxDot = d;
		}
		final cDot = dot(rect.center);
		final t0 = minDot - cDot;
		final t1 = maxDot - cDot;
		final start = ui.Offset(rect.center.dx + dir.dx * t0, rect.center.dy + dir.dy * t0);
		final end   = ui.Offset(rect.center.dx + dir.dx * t1, rect.center.dy + dir.dy * t1);
		return ui.Gradient.linear(
			start,
			end,
			colors,
			List.generate(colors.length, (i) => i / colors.length),
			tileMode
		);
	}
	List<ui.Shadow>? get shadows {
		final expressions = switch (this) {
			Expressions e => e.expressions,
			_ => null
		};
		if (expressions == null) {
			return null;
		}
		final shadows = <ui.Shadow>[];
		for (final shadow in expressions.splitWhere((x) => x is OperatorComma)) {
			double? offsetX;
			double? offsetY;
			double? blurRadius;
			ui.Color? color;
			if (shadow.length == 4) {
				if (shadow[0].color case final c?) {
					color = c;
					offsetX = shadow[1].pixels;
					offsetY = shadow[2].pixels;
					blurRadius = shadow[3].pixels;
				}
				else if (shadow[3].color case final c?) {
					offsetX = shadow[0].pixels;
					offsetY = shadow[1].pixels;
					blurRadius = shadow[2].pixels;
					color = c;
				}
			}
			else if (shadow.length == 3) {
				if (shadow[0].color case final c?) {
					color = c;
					offsetX = shadow[1].pixels;
					offsetY = shadow[2].pixels;
				}
				else if (shadow[2].color case final c?) {
					offsetX = shadow[0].pixels;
					offsetY = shadow[1].pixels;
					color = c;
				}
			}
			else if (shadow.length == 2) {
				offsetX = shadow[0].pixels;
				offsetY = shadow[1].pixels;
			}
			if (offsetX == null || offsetY == null) {
				return null;
			}
			shadows.add(ui.Shadow(
				offset: ui.Offset(offsetX, offsetY),
				color: color ?? const ui.Color(0xFF000000),
				blurRadius: blurRadius ?? 0
			));
		}
		return shadows;
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

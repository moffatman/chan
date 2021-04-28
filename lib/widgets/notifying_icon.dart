import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';

class NotifyingIcon extends StatelessWidget {
	final IconData icon;
	final ValueListenable<int> primaryCount;
	final ValueListenable<int>? secondaryCount;
	final double topOffset;
	NotifyingIcon({
		required this.icon,
		required this.primaryCount,
		required this.secondaryCount,
		this.topOffset = 0
	});

	Widget _build(BuildContext context, int primary, [int secondary = 0]) {
		final r = Radius.circular(10);
		return Stack(
			clipBehavior: Clip.none,
			children: [
				Icon(icon),
				if (primary > 0 || secondary > 0) Positioned(
					right: -10,
					top: -10 + topOffset,
					child: Row(
						children: [
							if (primary > 0) Container(
								decoration: BoxDecoration(
									color: Colors.red,
									borderRadius: (secondary > 0) ? BorderRadius.only(topLeft: r, bottomLeft: r) : BorderRadius.all(r)
								),
								constraints: BoxConstraints(
									minWidth: 20
								),
								height: 20,
								alignment: Alignment.center,
								padding: EdgeInsets.all(2),
								child: AutoSizeText(
									primary.toString(),
									style: TextStyle(
										color: Colors.white
									)
								)
							),
							if (secondary > 0) Container(
								decoration: BoxDecoration(
									color: CupertinoTheme.of(context).primaryColor,
									borderRadius: (primary > 0) ? BorderRadius.only(topRight: r, bottomRight: r) : BorderRadius.all(r)
								),
								constraints: BoxConstraints(
									minWidth: 20
								),
								height: 20,
								alignment: Alignment.center,
								padding: EdgeInsets.all(2),
								child:AutoSizeText(
									secondary.toString(),
									maxLines: 1,
									minFontSize: 0,
									textAlign: TextAlign.center,
									style: TextStyle(
										color: CupertinoTheme.of(context).scaffoldBackgroundColor
									)
								)
							)
						]
					)
				)
			]
		);
	}

	@override
	Widget build(BuildContext context) {
		return ValueListenableBuilder(
			valueListenable: primaryCount,
			builder: (BuildContext context, int primary, Widget? child) => (secondaryCount == null) ? _build(context, primary) : ValueListenableBuilder(
				valueListenable: secondaryCount!,
				builder: (BuildContext context, int secondary, Widget? child) => _build(context, primary, secondary)
			)
		);
	}
}
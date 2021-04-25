import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';

class NotifyingIcon extends StatelessWidget {
	final IconData icon;
	final ValueListenable<int> notificationCount;
	final double topOffset;
	NotifyingIcon({
		required this.icon,
		required this.notificationCount,
		this.topOffset = 0
	});

	@override
	Widget build(BuildContext context) {
		return  ValueListenableBuilder(
			valueListenable: notificationCount,
			builder: (BuildContext context, int count, Widget? child) => Stack(
				clipBehavior: Clip.none,
				children: [
					Icon(icon),
					if (count > 0) Positioned(
						right: -10,
						top: -10 + topOffset,
						child: Container(
							decoration: BoxDecoration(
								color: Colors.red,
								borderRadius: BorderRadius.all(Radius.circular(10))
							),
							constraints: BoxConstraints(
								minWidth: 20
							),
							height: 20,
							alignment: Alignment.center,
							padding: EdgeInsets.all(2),
							child:AutoSizeText(
								count.toString(),
								maxLines: 1,
								minFontSize: 0,
								textAlign: TextAlign.center,
								style: TextStyle(
									color: Colors.white
								)
							)
						)
					)
				]
			)
		);
	}
}
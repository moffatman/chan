import 'package:chan/providers/4chan.dart';
import 'package:flutter/material.dart';

class ChanSite extends InheritedWidget {
	final Widget child;
	final Provider4Chan provider;

	ChanSite({Key? key, required this.child, required this.provider}) : super(key: key, child: child);

	static ChanSite of(BuildContext context) {
		return context.dependOnInheritedWidgetOfExactType<ChanSite>()!;
	}

	@override
	bool updateShouldNotify(ChanSite oldWidget) {
		return true;
	}
}
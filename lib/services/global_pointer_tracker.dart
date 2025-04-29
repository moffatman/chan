import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

class GlobalPointerTracker extends ChangeNotifier implements ValueListenable<PointerEvent?> {
	static final _instance = GlobalPointerTracker._();
	static GlobalPointerTracker get instance => _instance;
	GlobalPointerTracker._();

	PointerEvent? _value;
	@override
	PointerEvent? get value => _value;

	void initialize() {
		GestureBinding.instance.pointerRouter.addGlobalRoute(_route);
	}

	void _route(PointerEvent event) {
		_value = event;
	}

	@override
	void dispose() {
		super.dispose();
		GestureBinding.instance.pointerRouter.removeGlobalRoute(_route);
	}
}

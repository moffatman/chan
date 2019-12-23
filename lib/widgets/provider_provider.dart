import 'package:flutter/widgets.dart';
import 'package:chan/providers/provider.dart';

class ProviderProvider extends InheritedWidget {
	final ImageboardProvider provider;
	const ProviderProvider({
		@required this.provider,
		@required Widget child,
		Key key
	}): super(key: key, child: child);

	static ProviderProvider of(BuildContext context) {
		return context.inheritFromWidgetOfExactType(ProviderProvider) as ProviderProvider;
	}

	@override
	bool updateShouldNotify(ProviderProvider old) => provider != old.provider;
}
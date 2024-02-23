import 'package:chan/services/settings.dart';
import 'package:chan/widgets/adaptive.dart';

export 'adaptive/buttons.dart';
export 'adaptive/dialog.dart';
export 'adaptive/icons.dart';
export 'adaptive/list.dart';
export 'adaptive/modal_popup.dart';
export 'adaptive/page_route.dart';
export 'adaptive/scaffold.dart';
export 'adaptive/segmented_control.dart';
export 'adaptive/switch.dart';
export 'adaptive/text_field.dart';

class Adaptive {
	static AdaptiveIconSet get icons {
		if (Settings.instance.materialStyle) {
			return const AdaptiveIconSetMaterial();
		}
		return const AdaptiveIconSetCupertino();
	}
}
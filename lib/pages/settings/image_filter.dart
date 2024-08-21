import 'package:chan/pages/settings/common.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:flutter/cupertino.dart';

void _afterChange() {
	Settings.instance.didUpdateImageFilter();
}

const imageFilterSettings = [
	SwitchSettingWidget(
		icon: CupertinoIcons.list_bullet_below_rectangle,
		description: 'Filter threads by image MD5',
		setting: HookedSetting(
			setting: Settings.applyImageFilterToThreadsSetting,
			afterChange: _afterChange
		)
	),
	SegmentedSettingWidget(
		icon: CupertinoIcons.list_bullet_below_rectangle,
		description: 'Hide replies to images',
		setting: HookedSetting(
			setting: Settings.imageMetaFilterDepthSetting,
			afterChange: _afterChange
		),
		children: {
			0: (null, 'None'),
			1: (null, 'Direct Replies'),
			2: (null, 'Full Chains')
		}
	),
];

class SettingsImageFilterPage extends StatefulWidget {
	const SettingsImageFilterPage({
		Key? key
	}) : super(key: key);

	@override
	createState() => _SettingsImageFilterPageState();
}

class _SettingsImageFilterPageState extends State<SettingsImageFilterPage> {
	late final TextEditingController controller;

	@override
	void initState() {
		super.initState();
		controller = TextEditingController(text: Persistence.settings.hiddenImageMD5s.join('\n'));
	}

	@override
	Widget build(BuildContext context) {
		return AdaptiveScaffold(
			resizeToAvoidBottomInset: false,
			disableAutoBarHiding: true,
			bar: const AdaptiveBar(
				title: Text('Image Filter Settings')
			),
			body: SafeArea(
				child: Padding(
					padding: const EdgeInsets.all(16),
					child: Column(
						children: [
							...imageFilterSettings.map((s) => s.build()),
							const SizedBox(height: 16),
							const Text('One image MD5 per line'),
							const SizedBox(height: 8),
							Expanded(
								child: AdaptiveTextField(
									controller: controller,
									enableIMEPersonalizedLearning: false,
									onChanged: (s) {
										Settings.instance.setHiddenImageMD5s(s.split(lineSeparatorPattern).where((x) => x.isNotEmpty));
									},
									maxLines: null
								)
							)
						]
					)
				)
			)
		);
	}

	@override
	void dispose() {
		super.dispose();
		controller.dispose();
	}
}

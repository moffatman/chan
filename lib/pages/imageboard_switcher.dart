import 'dart:math';

import 'package:chan/services/imageboard.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:flutter/cupertino.dart';

class ImageboardSwitcherPage extends StatefulWidget {
	final Widget Function(BuildContext context, FocusNode descendantFocusNode) builder;
	final String? initialImageboardKey;

	const ImageboardSwitcherPage({
		required this.builder,
		this.initialImageboardKey,
		Key? key
	}) : super(key: key);

	@override
	createState() => _ImageboardSwitcherPageState();
}

class _ImageboardSwitcherPageState extends State<ImageboardSwitcherPage> {
	late final PageController _controller = PageController(
		initialPage: max(0, ImageboardRegistry.instance.imageboardsIncludingUninitialized.toList().indexWhere((b) => b.key == widget.initialImageboardKey))
	);
	final _focusNodes = <int, FocusNode>{};

	@override
	Widget build(BuildContext context) {
		final imageboards = ImageboardRegistry.instance.imageboardsIncludingUninitialized.toList();
		return PageView.builder(
			controller: _controller,
			itemCount: imageboards.length,
			onPageChanged: (i) {
				_focusNodes[i]?.requestFocus();
			},
			itemBuilder: (context, i) => ImageboardScope(
				imageboardKey: null,
				imageboard: imageboards[i],
				child: Stack(
					children: [
						Builder(
							builder: (context) => widget.builder(context, _focusNodes.putIfAbsent(i, () => FocusNode()))
						),
						Positioned.fill(
							child: Align(
								alignment: Alignment.bottomCenter,
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Container(
										decoration: BoxDecoration(
											borderRadius: BorderRadius.circular(16),
											color: CupertinoTheme.of(context).scaffoldBackgroundColor
										),
										padding: const EdgeInsets.all(16),
										child: Row(
											mainAxisSize: MainAxisSize.min,
											children: [
												CupertinoButton(
													padding: EdgeInsets.zero,
													minSize: 0,
													onPressed: (i == 0) ? null : () {
														_controller.animateToPage(i - 1, duration: const Duration(milliseconds: 250), curve: Curves.ease);
													},
													child: const Icon(CupertinoIcons.chevron_left)
												),
												const SizedBox(width: 8),
												Text(imageboards[i].key),
												const SizedBox(width: 8),
												CupertinoButton(
													padding: EdgeInsets.zero,
													minSize: 0,
													onPressed: (i + 1 >= imageboards.length) ? null : () {
														_controller.animateToPage(i + 1, duration: const Duration(milliseconds: 250), curve: Curves.ease);
													},
													child: const Icon(CupertinoIcons.chevron_right)
												)
											]
										)
									)
								)
							)
						)
					]
				)
			)
		);
	}

	@override
	void dispose() {
		super.dispose();
		_controller.dispose();
		for (final focusNode in _focusNodes.values) {
			focusNode.dispose();
		}
	}
}
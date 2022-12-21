import 'dart:math';

import 'package:chan/services/imageboard.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class ImageboardSwitcherPage extends StatefulWidget {
	final Widget Function(BuildContext context, FocusNode descendantFocusNode) builder;
	final bool Function(Imageboard imageboard)? filterImageboards;
	final String? initialImageboardKey;

	const ImageboardSwitcherPage({
		required this.builder,
		this.filterImageboards,
		this.initialImageboardKey,
		Key? key
	}) : super(key: key);

	@override
	createState() => _ImageboardSwitcherPageState();
}

class _ImageboardSwitcherPageState extends State<ImageboardSwitcherPage> {
	late final PageController _controller;
	final _focusNodes = <int, FocusNode>{};
	int _currentPage = 0;

	@override
	void initState() {
		super.initState();
		_currentPage = max(0, ImageboardRegistry.instance.imageboardsIncludingUninitialized.where(widget.filterImageboards ?? (_) => true).toList().indexWhere((b) => b.key == widget.initialImageboardKey));
		_controller = PageController(
			initialPage: _currentPage
		);
	}

	@override
	Widget build(BuildContext context) {
		final imageboards = ImageboardRegistry.instance.imageboardsIncludingUninitialized.where(widget.filterImageboards ?? (_) => true).toList();
		return Stack(
			children: [
				PageView.builder(
					controller: _controller,
					itemCount: imageboards.length,
					onPageChanged: (i) {
						_focusNodes[i]?.requestFocus();
						_currentPage = i;
					},
					itemBuilder: (context, i) => ImageboardScope(
						imageboardKey: null,
						imageboard: imageboards[i],
						child: Builder(
							builder: (context) => widget.builder(context, _focusNodes.putIfAbsent(i, () => FocusNode()))
						)
					)
				),
				Positioned.fill(
					child: Align(
						alignment: Alignment.bottomCenter,
						child: Container(
							padding: const EdgeInsets.all(16),
							width: 250 * context.select<EffectiveSettings, double>((s) => s.textScale),
							child: AnimatedBuilder(
								animation: _controller,
								builder: (context, _) => Container(
									decoration: BoxDecoration(
										borderRadius: BorderRadius.circular(16),
										color: CupertinoTheme.of(context).scaffoldBackgroundColor
									),
									padding: const EdgeInsets.all(16),
									child: Row(
										children: [
											CupertinoButton(
												padding: EdgeInsets.zero,
												minSize: 0,
												onPressed: (_currentPage == 0) ? null : () {
													_controller.animateToPage(_currentPage - 1, duration: const Duration(milliseconds: 250), curve: Curves.ease);
													_currentPage--;
												},
												child: const Icon(CupertinoIcons.chevron_left)
											),
											const SizedBox(width: 8),
											Expanded(
												child: Row(
													mainAxisAlignment: MainAxisAlignment.center,
													children: [
														ImageboardIcon(imageboardKey: imageboards[_currentPage].key),
														const SizedBox(width: 8),
														Flexible(
															child: Text(imageboards[_currentPage].key)
														),
													]
												)
											),
											const SizedBox(width: 8),
											CupertinoButton(
												padding: EdgeInsets.zero,
												minSize: 0,
												onPressed: (_currentPage + 1 >= imageboards.length) ? null : () {
													_controller.animateToPage(_currentPage + 1, duration: const Duration(milliseconds: 250), curve: Curves.ease);
													_currentPage++;
												},
												child: const Icon(CupertinoIcons.chevron_right)
											)
										]
									)
								)
							)
						)
					)
				)
			]
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
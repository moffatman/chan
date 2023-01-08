import 'dart:async';

import 'package:chan/services/imageboard.dart';
import 'package:chan/widgets/weak_gesture_recognizer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class CooperativeInAppBrowser extends StatefulWidget {
	final URLRequest? initialUrlRequest;

	const CooperativeInAppBrowser({
		this.initialUrlRequest,
		super.key
	});

	@override
	createState() => _CooperativeInAppBrowserState();
}

class _CooperativeInAppBrowserState extends State<CooperativeInAppBrowser> {
	final Set<AxisDirection> _allowedDirections = {...AxisDirection.values};
	InAppWebViewController? _controller;
	late Timer _pollAllowedDirections;
	bool _pageReady = false;
	bool _canGoBack = false;
	bool _canGoForward = false;
	Uri? _url;
	late final ValueNotifier<double?> _progress;

	@override
	void initState() {
		super.initState();
		_pollAllowedDirections = Timer.periodic(const Duration(milliseconds: 75), (t) => _updateAllowedDirections());
		_progress = ValueNotifier<double>(0);
	}

	Future<void> _updateAllowedDirections() async {
		if (_controller == null || !mounted) return;
		_canGoBack = (await _controller?.canGoBack()) ?? false;
		if (!mounted) return;
		_canGoForward = (await _controller?.canGoForward()) ?? false;
		if (!mounted) return;
		_url = await _controller?.getUrl();
		if (!mounted) return;
		if (_pageReady) {
			final Map? v = await _controller?.evaluateJavascript(source: '''(() => ({
				top: window.scrollY < 50,
				bottom: document.body.scrollHeight < (window.scrollY + window.innerHeight + 50),
				left: window.scrollX < 50,
				right: document.body.scrollWidth < (window.scrollX + window.innerWidth + 50)
			}))()''');
			if (v != null) {
				_allowedDirections.clear();
				_allowedDirections.addAll([
					if (!v['top']!) AxisDirection.down,
					if (!v['bottom']!) AxisDirection.up,
					if (!v['left']!) AxisDirection.right,
					if (!v['right']!) AxisDirection.left
				]);
			}
		}
		else {
			_allowedDirections.clear();
			_allowedDirections.addAll([
				AxisDirection.up,
				AxisDirection.left,
				AxisDirection.right
			]);
		}
		if (!mounted) return;
		setState(() {});
	}

	@override
	Widget build(BuildContext context) {
		return SafeArea(
			top: false,
			child: Container(
				margin: EdgeInsets.only(
					top: MediaQuery.paddingOf(ImageboardRegistry.instance.context ?? context).top
				),
				decoration: BoxDecoration(
					border: Border(
						top: BorderSide(
							color: _allowedDirections.contains(AxisDirection.down) ? Colors.green : Colors.red,
							width: 10
						),
						bottom: BorderSide(
							color: _allowedDirections.contains(AxisDirection.up) ? Colors.green : Colors.red,
							width: 10
						),
						left: BorderSide(
							color: _allowedDirections.contains(AxisDirection.right) ? Colors.green : Colors.red,
							width: 10
						),
						right: BorderSide(
							color: _allowedDirections.contains(AxisDirection.left) ? Colors.green : Colors.red,
							width: 10
						)
					)
				),
				child: Column(
					children: [
						Expanded(
							child: InAppWebView(
								onLoadStart: (controller, url) {
									_controller = controller;
									_pageReady = false;
									_progress.value = null;
								},
								onProgressChanged: (controller, progress) {
									_controller = controller;
									_progress.value = progress / 100;
									if (progress > 0) {
										_pageReady = true;
									}
								},
								onLoadStop: (controller, url) {
									_controller = controller;
									_progress.value = 1;
									_pageReady = true;
								},
								gestureRecognizers: {
									Factory<WeakPanGestureRecognizer>(() => WeakPanGestureRecognizer(
										weakness: 0.5,
										allowedDirections: _allowedDirections,
										debugOwner: this
										)
										..gestureSettings = MediaQuery.maybeGestureSettingsOf(context)
										..onStart = (_) {})
								},
								initialUrlRequest: widget.initialUrlRequest
							)
						),
						ValueListenableBuilder<double?>(
							valueListenable: _progress,
							builder: (context, progress, _) => LinearProgressIndicator(
								value: progress
							)
						),
						DecoratedBox(
							decoration: BoxDecoration(
								color: CupertinoTheme.of(context).scaffoldBackgroundColor
							),
							child: Row(
								children: [
									CupertinoButton(
										onPressed: _canGoBack ? _controller?.goBack : null,
										child: const Icon(CupertinoIcons.arrow_left)
									),
									Expanded(
										child: Text(_url.toString(), maxLines: 1, overflow: TextOverflow.ellipsis)
									),
									CupertinoButton(
										onPressed: _controller?.reload,
										child: const Icon(CupertinoIcons.refresh)
									),
									CupertinoButton(
										onPressed: _canGoForward ? _controller?.goForward : null,
										child: const Icon(CupertinoIcons.arrow_right)
									)
								]
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
		_pollAllowedDirections.cancel();
		_progress.dispose();
	}
}
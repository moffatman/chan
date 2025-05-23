import 'dart:async';

import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/share.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/util.dart';
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
	final Set<AxisDirection> _allowedDirections = {};
	InAppWebViewController? _controller;
	late Timer _pollAllowedDirections;
	bool _pageReady = false;
	bool _canGoBack = false;
	bool _canGoForward = false;
	bool _showProgress = true;
	Timer? _showProgressTimer;
	Uri? _url;
	late final ValueNotifier<double?> _progress;

	@override
	void initState() {
		super.initState();
		_pollAllowedDirections = Timer.periodic(const Duration(milliseconds: 75), (t) => _updateAllowedDirections());
		_progress = ValueNotifier<double?>(0);
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
			final v = (await _controller?.evaluateJavascript(source: '''(() => {
				var top = Math.max(window.scrollY, visualViewport.offsetTop, document.body.scrollTop)
				var left = Math.max(window.scrollX, visualViewport.offsetLeft, document.body.scrollLeft)
				return {
					top: top < 50,
					bottom: Math.max(document.documentElement.scrollHeight, document.body.scrollHeight) < (top + visualViewport.height + 50),
					left: left < 50,
					right: Math.max(document.documentElement.scrollWidth, document.body.scrollWidth) < (left + visualViewport.width + 50)
				}
			})()''') as Map?)?.cast<String, bool>();
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

	bool _shouldPlatformViewAccept(Offset offset) {
		final rect = context.findRenderObject()?.semanticBounds;
		if (rect == null) {
			return true;
		}
		return const EdgeInsets.only(top: 64, left: 64, right: 64, bottom: 200).deflateRect(rect).contains(offset);
	}

	@override
	Widget build(BuildContext context) {
		return PopScope(
			canPop: !_canGoBack,
			onPopInvokedWithResult: (didPop, result) {
				if (!didPop) {
					_controller?.goBack();
				}
			},
			child: Container(
				color: ChanceTheme.backgroundColorOf(context),
				child: SafeArea(
					top: false,
					child: Padding(
						padding: EdgeInsets.only(
							top: MediaQuery.paddingOf(ImageboardRegistry.instance.context ?? context).top
						),
						child: Column(
							children: [
								Expanded(
									child: InAppWebView(
										onLoadStart: (controller, url) {
											_controller = controller;
											_pageReady = false;
											_progress.value = null;
											_showProgressTimer?.cancel();
											_showProgressTimer = null;
											_showProgress = true;
											setState(() {});
										},
										onProgressChanged: (controller, progress) {
											_controller = controller;
											_progress.value = progress / 100;
											if (progress > 0) {
												_pageReady = true;
												_showProgressTimer?.cancel();
												_showProgressTimer = null;
												_showProgress = true;
												setState(() {});
											}
										},
										onLoadStop: (controller, url) {
											_controller = controller;
											_progress.value = 1;
											_pageReady = true;
											_showProgressTimer = Timer(const Duration(milliseconds: 300), () => setState(() {
												_showProgress = false;
											}));
										},
										gestureRecognizers: {
											Factory<WeakPanGestureRecognizer>(() => WeakPanGestureRecognizer(
												weakness: 0.49,
												allowedDirections: _allowedDirections,
												shouldAcceptRegardlessOfGlobalMovementDirection: _shouldPlatformViewAccept,
												debugOwner: this
												)
												..gestureSettings = MediaQuery.maybeGestureSettingsOf(context)
												..onStart = (_) {})
										},
										initialUrlRequest: widget.initialUrlRequest,
										initialSettings: InAppWebViewSettings(
											userAgent: Persistence.settings.userAgent
										),
									)
								),
								AnimatedSwitcher(
									duration: const Duration(milliseconds: 500),
									switchInCurve: Curves.ease,
									switchOutCurve: Curves.ease,
									child: _showProgress ? ValueListenableBuilder<double?>(
										valueListenable: _progress,
										builder: (context, progress, _) => LinearProgressIndicator(
											minHeight: 5,
											value: progress,
											valueColor: AlwaysStoppedAnimation(ChanceTheme.primaryColorOf(context)),
											backgroundColor: ChanceTheme.backgroundColorOf(context)
										)
									) : const SizedBox(
										height: 5,
										width: double.infinity
									)
								),
								DecoratedBox(
									decoration: BoxDecoration(
										color: ChanceTheme.backgroundColorOf(context)
									),
									child: Row(
										children: [
											AdaptiveIconButton(
												padding: const EdgeInsets.all(16.0),
												onPressed: _canGoBack ? _controller?.goBack : null,
												icon: const Icon(CupertinoIcons.arrow_left)
											),
											AdaptiveIconButton(
												padding: const EdgeInsets.all(16.0),
												onPressed: _canGoForward ? _controller?.goForward : null,
												icon: const Icon(CupertinoIcons.arrow_right)
											),
											AdaptiveIconButton(
												padding: const EdgeInsets.all(16.0),
												onPressed: () {
													_showProgressTimer?.cancel();
													_showProgressTimer = null;
													_showProgress = true;
													setState(() {});
													_controller?.reload();
												},
												icon: const Icon(CupertinoIcons.refresh)
											),
											Expanded(
												child: Row(
													mainAxisAlignment: MainAxisAlignment.center,
													children: [
														if (_url?.scheme == 'https') ...[
															const Icon(CupertinoIcons.padlock_solid, size: 15),
															const SizedBox(width: 4)
														],
														Flexible(
															child: Text(_url?.host ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)
														),
													]
												)
											),
											AdaptiveIconButton(
												padding: const EdgeInsets.all(16.0),
												onPressed: () {
													final url = _url ?? widget.initialUrlRequest?.url;
													if (url == null) {
														alertError(context, 'No URL', null);
													}
													else {
														_controller?.loadUrl(urlRequest: URLRequest(
															url: WebUri(Uri.https('archive.today', '/', {
																'run': '1',
																'url': url.toString()
															}).toString())
														));
													}
												},
												icon: const Icon(CupertinoIcons.archivebox)
											),
											AdaptiveIconButton(
												padding: const EdgeInsets.all(16.0),
												onPressed: () {
													final url = _url ?? widget.initialUrlRequest?.url;
													if (url == null) {
														alertError(context, 'No URL', null);
													}
													else {
														openBrowser(context, url);
													}
												},
												icon: const Icon(CupertinoIcons.compass)
											),
											Builder(
												builder: (context) => AdaptiveIconButton(
													padding: const EdgeInsets.all(16.0),
													onPressed: () async {
														final url = _url ?? widget.initialUrlRequest?.url;
														if (url == null) {
															alertError(context, 'No URL', null);
														}
														else {
															await shareOne(
																context: context,
																text: url.toString(),
																type: 'text',
																sharePositionOrigin: context.globalPaintBounds
															);
														}
													},
													icon: Icon(Adaptive.icons.share)
												)
											)
										]
									)
								)
							]
						)
					)
				)
			)
		);
	}

	@override
	void dispose() {
		super.dispose();
		_pollAllowedDirections.cancel();
		_progress.dispose();
		_showProgressTimer?.cancel();
	}
}
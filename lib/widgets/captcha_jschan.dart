import 'package:chan/services/cookies.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/timed_rebuilder.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CaptchaJsChan extends StatefulWidget {
	final JsChanCaptchaRequest request;
	final ValueChanged<JsChanCaptchaSolution> onCaptchaSolved;
	final ImageboardSite site;

	const CaptchaJsChan({
		required this.request,
		required this.onCaptchaSolved,
		required this.site,
		Key? key
	}) : super(key: key);

	@override
	createState() => _CaptchaJsChanState();
}

class CaptchaJsChanException implements Exception {
	String message;
	CaptchaJsChanException(this.message);

	@override
	String toString() => 'JsChan captcha error: $message';
}

class CaptchaJsChanChallenge {
	final String id;
	final DateTime acquiredAt;
	final Duration lifetime;
	DateTime get expiresAt => acquiredAt.add(lifetime);
	final Uint8List imageBytes;

	CaptchaJsChanChallenge({
		required this.id,
		required this.acquiredAt,
		required this.lifetime,
		required this.imageBytes
	});
}

class _CaptchaJsChanState extends State<CaptchaJsChan> {
	(Object, StackTrace)? error;
	CaptchaJsChanChallenge? challenge;
	final selected = <int>{};
	late final TextEditingController controller;
	late final FocusNode _solutionNode;

	@override
	void initState() {
		super.initState();
		_tryRequestChallenge();
		controller = TextEditingController();
		_solutionNode = FocusNode();
	}

	Future<CaptchaJsChanChallenge> _requestChallenge() async {
		final response = await widget.site.client.getUri(widget.request.challengeUrl, options: Options(
			responseType: ResponseType.bytes,
			extra: {
				kPriority: RequestPriority.interactive,
				kDisableCookies: true
			}
		));
		if (response.statusCode != 200) {
			throw CaptchaJsChanException('Got status code ${response.statusCode}');
		}
		final filenameParts = response.redirects.tryLast?.location.pathSegments.tryLast?.split('.') ?? <String>[];
		if (filenameParts.length != 2) {
			throw CaptchaJsChanException('Response not as expected!');
		}
		return CaptchaJsChanChallenge(
			id: filenameParts[0],
			acquiredAt: DateTime.now(),
			lifetime: const Duration(seconds: 300),
			imageBytes: Uint8List.fromList(response.data as List<int>)
		);
	}

	void _tryRequestChallenge() async {
		try {
			setState(() {
				error = null;
				challenge = null;
			});
			challenge = await _requestChallenge();
			setState(() {});
			if (widget.request.type == 'text') {
				_solutionNode.requestFocus();
			}
		}
		catch(e, st) {
			print(e);
			print(st);
			setState(() {
				error = (e, st);
			});
		}
	}

	void _solveText() {
		widget.onCaptchaSolved(JsChanTextCaptchaSolution(
			id: challenge!.id,
			text: controller.text,
			lifetime: challenge!.lifetime,
			acquiredAt: challenge!.acquiredAt
		));
	}

	void _solveGrid() {
		widget.onCaptchaSolved(JsChanGridCaptchaSolution(
			id: challenge!.id,
			selected: selected.toSet(),
			lifetime: challenge!.lifetime,
			acquiredAt: challenge!.acquiredAt
		));
	}

	void _solve() {
		if (widget.request.type == 'text') {
			_solveText();
		}
		else if (widget.request.type == 'grid') {
			_solveGrid();
		}
		else {
			throw ArgumentError('Unrecognized captcha type', widget.request.type);
		}
	}

	Widget _build(BuildContext context) {
		if (error != null) {
			return Center(
				child: Column(
					children: [
						Row(
							mainAxisAlignment: MainAxisAlignment.center,
							children: [
								Flexible(
									child: Text(error!.$1.toStringDio())
								),
								AdaptiveIconButton(
									onPressed: () => alertError(context, error!.$1, error!.$2, barrierDismissible: true),
									icon: const Icon(CupertinoIcons.info)
								)
							]
						),
						AdaptiveIconButton(
							onPressed: _tryRequestChallenge,
							icon: const Icon(CupertinoIcons.refresh)
						)
					]
				)
			);
		}
		else if (challenge != null) {
			return Column(
				mainAxisSize: MainAxisSize.min,
				children: [
					if (widget.request.type == 'grid') ...[
						const Text('Select the solid/filled icons'),
						const SizedBox(height: 16),
						Flexible(
							child: ConstrainedBox(
								constraints: const BoxConstraints(
									maxWidth: 500
								),
								child: Row(
									children: [
										Flexible(
											flex: 1,
											fit: FlexFit.tight,
											child: Image.memory(
												challenge!.imageBytes,
												width: 150,
												height: 150
											)
										),
										Flexible(
											flex: 1,
											fit: FlexFit.loose,
											child: Center(
												child: SizedBox(
													width: 150,
													height: 150,
													child: GridView.builder(
														shrinkWrap: true,
														gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
															crossAxisCount: 4,
															childAspectRatio: 1
														),
														itemCount: 16,
														itemBuilder: (context, i) => Checkbox.adaptive(
															value: selected.contains(i),
															onChanged: (v) {
																if (v ?? false) {
																	selected.add(i);
																}
																else {
																	selected.remove(i);
																}
																setState(() {});
															},
														)
													)
												)
											)
										)
									]
								)
							)
						),
					]
					else if (widget.request.type == 'text') ...[
						const Text('Enter the text in the image below'),
						const SizedBox(height: 16),
						Flexible(
							child: ConstrainedBox(
								constraints: const BoxConstraints(
									maxWidth: 500
								),
								child: FractionallySizedBox(
									widthFactor: 0.5,
									child: Image.memory(
										challenge!.imageBytes,
										width: 150,
										height: 150
									)
								)
							)
						),
						const SizedBox(height: 16),
						SizedBox(
							width: 150,
							child: AdaptiveTextField(
								focusNode: _solutionNode,
								enableIMEPersonalizedLearning: false,
								autocorrect: false,
								controller: controller,
								placeholder: 'Captcha text',
								onSubmitted: (_) => _solveText()
							)
						)
					]
					else Text('Unrecognized captcha type: ${widget.request.type}'),
					const SizedBox(height: 16),
					ConstrainedBox(
						constraints: const BoxConstraints(
							maxWidth: 500
						),
						child: Row(
							mainAxisAlignment: MainAxisAlignment.spaceBetween,
							children: [
								Padding(
									padding: const EdgeInsets.only(right: 38),
									child: AdaptiveIconButton(
										onPressed: _tryRequestChallenge,
										icon: const Icon(CupertinoIcons.refresh)
									)
								),
								AdaptiveThinButton(
									padding: const EdgeInsets.all(8),
									onPressed: _solve,
									child: const Text('Submit')
								),
								Row(
									children: [
										const Icon(CupertinoIcons.timer),
										const SizedBox(width: 16),
										GreedySizeCachingBox(
											alignment: Alignment.centerRight,
											child: TimedRebuilder(
												enabled: true,
												interval: const Duration(seconds: 1),
												function: () {
													return challenge!.expiresAt.difference(DateTime.now()).inSeconds;
												},
												builder: (context, seconds) {
													return Text(
														seconds > 0 ? '$seconds' : 'Expired',
														style: CommonTextStyles.tabularFigures
													);
												}
											)
										)
									]
								)
							]
						)
					)
				]
			);
		}
		else {
			return const Center(
				child: CircularProgressIndicator.adaptive()
			);
		}
	}

	@override
	Widget build(BuildContext context) {
		return Container(
			decoration: BoxDecoration(
				color: ChanceTheme.backgroundColorOf(context),
			),
			width: double.infinity,
			padding: const EdgeInsets.all(16),
			child: AnimatedSize(
				duration: const Duration(milliseconds: 100),
				child: _build(context)
			)
		);
	}

	@override
	void dispose() {
		super.dispose();
		controller.dispose();
		_solutionNode.dispose();
	}
}
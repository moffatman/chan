import 'dart:async';
import 'dart:typed_data';

import 'package:chan/services/theme.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/timed_rebuilder.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CaptchaDvach extends StatefulWidget {
	final DvachCaptchaRequest request;
	final ValueChanged<DvachCaptchaSolution> onCaptchaSolved;
	final ImageboardSite site;

	const CaptchaDvach({
		required this.request,
		required this.onCaptchaSolved,
		required this.site,
		Key? key
	}) : super(key: key);

	@override
	createState() => _CaptchaDvachState();
}

class CaptchaDvachException implements Exception {
	String message;
	CaptchaDvachException(this.message);

	@override
	String toString() => 'Dvach captcha error: $message';
}

class CaptchaDvachChallenge {
	final String id;
	final String inputType;
	final DateTime acquiredAt;
	final Duration lifetime;
	DateTime get expiresAt => acquiredAt.add(lifetime);
	final Uint8List imageBytes;

	CaptchaDvachChallenge({
		required this.id,
		required this.inputType,
		required this.acquiredAt,
		required this.lifetime,
		required this.imageBytes
	});
}

class _CaptchaDvachState extends State<CaptchaDvach> {
	(Object, StackTrace)? error;
	CaptchaDvachChallenge? challenge;
	late final FocusNode _solutionNode;

	@override
	void initState() {
		super.initState();
		_solutionNode = FocusNode();
		_tryRequestChallenge();
	}

	Future<CaptchaDvachChallenge> _requestChallenge() async {
		final idResponse = await widget.site.client.getUri(Uri.https(widget.site.baseUrl, '/api/captcha/2chcaptcha/id'), options: Options(
			responseType: ResponseType.json,
			extra: {
				kPriority: RequestPriority.interactive
			}
		));
		if (idResponse.statusCode != 200) {
			throw CaptchaDvachException('Got status code ${idResponse.statusCode}');
		}
		if (idResponse.data['error'] != null) {
			throw CaptchaDvachException(idResponse.data['error']['message'] as String);
		}
		final id = idResponse.data['id'] as String;
		final inputType = idResponse.data['input'] as String;
		final imageResponse = await widget.site.client.getUri(Uri.https(widget.site.baseUrl, '/api/captcha/2chcaptcha/show', {
			'id': id
		}), options: Options(
			responseType: ResponseType.bytes,
			extra: {
				kPriority: RequestPriority.interactive
			}
		));
		if (imageResponse.statusCode != 200) {
			throw CaptchaDvachException('Got status code ${idResponse.statusCode}');
		}
		return CaptchaDvachChallenge(
			id: id,
			inputType: inputType,
			acquiredAt: DateTime.now(),
			lifetime: widget.request.challengeLifetime,
			imageBytes: Uint8List.fromList(imageResponse.data as List<int>)
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
			_solutionNode.requestFocus();
		}
		catch(e, st) {
			print(e);
			print(st);
			setState(() {
				error = (e, st);
			});
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
					const Text('Enter the text in the image below'),
					const SizedBox(height: 16),
					Flexible(
						child: ConstrainedBox(
							constraints: const BoxConstraints(
								maxWidth: 500
							),
							child: Image.memory(
								challenge!.imageBytes
							)
						)
					),
					const SizedBox(height: 16),
					ConstrainedBox(
						constraints: const BoxConstraints(
							maxWidth: 500
						),
						child: Row(
							mainAxisAlignment: MainAxisAlignment.spaceBetween,
							children: [
								AdaptiveIconButton(
									onPressed: _tryRequestChallenge,
									icon: const Icon(CupertinoIcons.refresh)
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
					),
					const SizedBox(height: 16),
					SizedBox(
						width: 150,
						child: AdaptiveTextField(
							focusNode: _solutionNode,
							enableIMEPersonalizedLearning: false,
							autocorrect: false,
							placeholder: 'Captcha text',
							keyboardType: challenge?.inputType == 'numeric' ? TextInputType.number : null,
							onSubmitted: (response) async {
								widget.onCaptchaSolved(DvachCaptchaSolution(
									id: challenge!.id,
									response: response,
									acquiredAt: challenge!.acquiredAt,
									lifetime: challenge!.lifetime
								));
							},
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
		_solutionNode.dispose();
	}
}
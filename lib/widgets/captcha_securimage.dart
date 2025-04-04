import 'dart:async';
import 'dart:convert';
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

class CaptchaSecurimage extends StatefulWidget {
	final SecurimageCaptchaRequest request;
	final ValueChanged<SecurimageCaptchaSolution> onCaptchaSolved;
	final ImageboardSite site;

	const CaptchaSecurimage({
		required this.request,
		required this.onCaptchaSolved,
		required this.site,
		Key? key
	}) : super(key: key);

	@override
	createState() => _CaptchaSecurimageState();
}

class CaptchaSecurimageException implements Exception {
	String message;
	CaptchaSecurimageException(this.message);

	@override
	String toString() => 'Securimage captcha error: $message';
}

class CaptchaSecurimageChallenge {
	final String cookie;
	final DateTime acquiredAt;
	final Duration lifetime;
	DateTime get expiresAt => acquiredAt.add(lifetime);
	final Uint8List imageBytes;

	CaptchaSecurimageChallenge({
		required this.cookie,
		required this.acquiredAt,
		required this.lifetime,
		required this.imageBytes
	});
}

class _CaptchaSecurimageState extends State<CaptchaSecurimage> {
	(Object, StackTrace)? error;
	CaptchaSecurimageChallenge? challenge;
	late final FocusNode _solutionNode;

	@override
	void initState() {
		super.initState();
		_solutionNode = FocusNode();
		_tryRequestChallenge();
	}

	Future<CaptchaSecurimageChallenge> _requestChallenge() async {
		final challengeResponse = await widget.site.client.getUri(widget.request.challengeUrl.replace(queryParameters: {
			'mode': 'get',
			'extra': 'abcdefghijklmnopqrstuvwxyz'
		}), options: Options(
			responseType: ResponseType.json,
			extra: {
				kPriority: RequestPriority.interactive
			}
		));
		if (challengeResponse.statusCode != 200) {
			throw CaptchaSecurimageException('Got status code ${challengeResponse.statusCode}');
		}
		final data = challengeResponse.data;
		if (data['error'] case String error) {
			throw CaptchaSecurimageException(error);
		}
		final base64Data = RegExp(r'base64,([^"]+)').firstMatch(data['captchahtml'] as String)?.group(1);
		if (base64Data == null) {
			throw CaptchaSecurimageException('Image missing from response');
		}
		return CaptchaSecurimageChallenge(
			cookie: data['cookie'] as String,
			acquiredAt: DateTime.now(),
			lifetime: Duration(seconds: (data['expires_in'] as num).toInt()),
			imageBytes: base64Decode(base64Data)
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
							onSubmitted: (response) async {
								widget.onCaptchaSolved(SecurimageCaptchaSolution(
									cookie: challenge!.cookie,
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
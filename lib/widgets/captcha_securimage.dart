import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/timed_rebuilder.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class CaptchaSecurimage extends StatefulWidget {
	final SecurimageCaptchaRequest request;
	final ValueChanged<SecurimageCaptchaSolution> onCaptchaSolved;

	const CaptchaSecurimage({
		required this.request,
		required this.onCaptchaSolved,
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
	DateTime expiresAt;
	Uint8List imageBytes;

	CaptchaSecurimageChallenge({
		required this.cookie,
		required this.expiresAt,
		required this.imageBytes
	});
}

class _CaptchaSecurimageState extends State<CaptchaSecurimage> {
	String? errorMessage;
	CaptchaSecurimageChallenge? challenge;
	final _solutionNode = FocusNode();

	@override
	void initState() {
		super.initState();
		_tryRequestChallenge();
	}

	Future<CaptchaSecurimageChallenge> _requestChallenge() async {
		final challengeResponse = await context.read<ImageboardSite>().client.get(widget.request.challengeUrl.toString(), queryParameters: {
			'mode': 'get',
			'extra': 'abcdefghijklmnopqrstuvwxyz'
		}, options: Options(
			responseType: ResponseType.json
		));
		if (challengeResponse.statusCode != 200) {
			throw CaptchaSecurimageException('Got status code ${challengeResponse.statusCode}');
		}
		final data = challengeResponse.data;
		if (data['error'] != null) {
			throw CaptchaSecurimageException(data['error']);
		}
		final base64Data = RegExp(r'base64,([^"]+)').firstMatch(data['captchahtml'])?.group(1);
		if (base64Data == null) {
			throw CaptchaSecurimageException('Image missing from response');
		}
		return CaptchaSecurimageChallenge(
			cookie: data['cookie'],
			expiresAt: DateTime.now().add(Duration(seconds: data['expires_in'])),
			imageBytes: base64Decode(base64Data)
		);
	}

	void _tryRequestChallenge() async {
		try {
			setState(() {
				errorMessage = null;
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
				errorMessage = e.toStringDio();
			});
		}
	}

	Widget _build(BuildContext context) {
		if (errorMessage != null) {
			return Center(
				child: Column(
					children: [
						Text(errorMessage!),
						CupertinoButton(
							onPressed: _tryRequestChallenge,
							child: const Icon(CupertinoIcons.refresh)
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
								CupertinoButton(
									onPressed: _tryRequestChallenge,
									child: const Icon(CupertinoIcons.refresh)
								),
								Row(
									children: [
										const Icon(CupertinoIcons.timer),
										const SizedBox(width: 16),
										SizedBox(
											width: 60,
											child: TimedRebuilder(
												enabled: true,
												interval: const Duration(seconds: 1),
												builder: (context) {
													final seconds = challenge!.expiresAt.difference(DateTime.now()).inSeconds;
													return Text(
														seconds > 0 ? '$seconds' : 'Expired'
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
						child: CupertinoTextField(
							focusNode: _solutionNode,
							autocorrect: false,
							placeholder: 'Captcha text',
							onSubmitted: (response) async {
								widget.onCaptchaSolved(SecurimageCaptchaSolution(
									cookie: challenge!.cookie,
									response: response,
									expiresAt: challenge!.expiresAt
								));
							},
						)
					)
				]
			);
		}
		else {
			return const Center(
				child: CupertinoActivityIndicator()
			);
		}
	}

	@override
	Widget build(BuildContext context) {
		return Container(
			decoration: BoxDecoration(
				color: CupertinoTheme.of(context).scaffoldBackgroundColor,
			),
			width: double.infinity,
			padding: const EdgeInsets.all(16),
			child: AnimatedSize(
				duration: const Duration(milliseconds: 100),
				child: _build(context)
			)
		);
	}
}
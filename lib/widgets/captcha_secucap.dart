import 'dart:async';
import 'dart:typed_data';

import 'package:chan/services/theme.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CaptchaSecucap extends StatefulWidget {
	final SecucapCaptchaRequest request;
	final ValueChanged<SecucapCaptchaSolution> onCaptchaSolved;
	final ImageboardSite site;

	const CaptchaSecucap({
		required this.request,
		required this.onCaptchaSolved,
		required this.site,
		Key? key
	}) : super(key: key);

	@override
	createState() => _CaptchaSecucapState();
}

class CaptchaSecucapException implements Exception {
	String message;
	CaptchaSecucapException(this.message);

	@override
	String toString() => 'Secucap captcha error: $message';
}


class CaptchaSecucapChallenge {
	final Uint8List imageBytes;
	final DateTime acquiredAt;

	CaptchaSecucapChallenge({
		required this.imageBytes,
		required this.acquiredAt
	});
}

class _CaptchaSecucapState extends State<CaptchaSecucap> {
	(Object, StackTrace)? error;
	CaptchaSecucapChallenge? challenge;
	late final FocusNode _solutionNode;

	@override
	void initState() {
		super.initState();
		_solutionNode = FocusNode();
		_tryRequestChallenge();
	}

	Future<CaptchaSecucapChallenge> _requestChallenge() async {
		final challengeResponse = await widget.site.client.getUri(widget.request.challengeUrl, options: Options(
			responseType: ResponseType.bytes,
			extra: {
				kPriority: RequestPriority.interactive
			}
		));
		if (challengeResponse.statusCode != 200) {
			throw CaptchaSecucapException('Got status code ${challengeResponse.statusCode}');
		}
		return CaptchaSecucapChallenge(
			imageBytes: Uint8List.fromList((challengeResponse.data as List<int>)),
			acquiredAt: DateTime.now()
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
							child: RotatedBox(
								quarterTurns: 2,
								child: Image.memory(
									challenge!.imageBytes,
									scale: 0.5
								)
							)
						)
					),
					const SizedBox(height: 16),
					ConstrainedBox(
						constraints: const BoxConstraints(
							maxWidth: 500
						),
						child: Row(
							mainAxisAlignment: MainAxisAlignment.center,
							children: [
								AdaptiveIconButton(
									onPressed: _tryRequestChallenge,
									icon: const Icon(CupertinoIcons.refresh)
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
								widget.onCaptchaSolved(SecucapCaptchaSolution(
									response: response,
									acquiredAt: challenge!.acquiredAt
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
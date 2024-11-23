import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:chan/services/theme.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CaptchaMcCaptcha extends StatefulWidget {
	final McCaptchaRequest request;
	final ValueChanged<McCaptchaSolution> onCaptchaSolved;
	final ImageboardSite site;

	const CaptchaMcCaptcha({
		required this.request,
		required this.onCaptchaSolved,
		required this.site,
		super.key
	});

	@override
	createState() => _CaptchaMcCaptchaState();
}

class CaptchaMcCaptchaException implements Exception {
	String message;
	CaptchaMcCaptchaException(this.message);

	@override
	String toString() => 'McCaptcha error: $message';
}


class CaptchaMcCaptchaChallenge {
	final ui.Image image;
	final String guid;
	final DateTime acquiredAt;

	CaptchaMcCaptchaChallenge({
		required this.image,
		required this.guid,
		required this.acquiredAt
	});
}

class _CaptchaMcCaptchaState extends State<CaptchaMcCaptcha> {
	final _customPaintKey = GlobalKey(debugLabel: '_CaptchaMcCaptchaState._customPaintKey');
	(Object, StackTrace)? error;
	CaptchaMcCaptchaChallenge? challenge;
	/// Unit vector (0,1)
	Offset? tappedPosition;
	late final TextEditingController answerController;

	@override
	void initState() {
		super.initState();
		answerController = TextEditingController();
		_tryRequestChallenge();
	}

	Future<CaptchaMcCaptchaChallenge> _requestChallenge() async {
		final challengeResponse = await widget.site.client.getUri(widget.request.challengeUrl, options: Options(
			responseType: ResponseType.plain,
			extra: {
				kPriority: RequestPriority.interactive
			}
		));
		if (challengeResponse.statusCode != 200) {
			throw CaptchaMcCaptchaException('Got status code ${challengeResponse.statusCode}');
		}
		final data = jsonDecode(challengeResponse.data as String);
		final b64str = data['base64Image'] as String;
		const kHint = ';base64,';
		return CaptchaMcCaptchaChallenge(
			image: await decodeImageFromList(Uint8List.fromList(base64Decode(b64str.substring(b64str.indexOf(kHint) + kHint.length)))),
			guid: data['guid'] as String,
			acquiredAt: DateTime.now()
		);
	}

	void _tryRequestChallenge() async {
		try {
			challenge?.image.dispose();
			setState(() {
				error = null;
				challenge = null;
				tappedPosition = null;
			});
			challenge = await _requestChallenge();
			setState(() {});
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
		final challenge = this.challenge;
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
								const SizedBox(width: 8),
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
			final tappedPosition = this.tappedPosition;
			return Column(
				mainAxisSize: MainAxisSize.min,
				children: [
					Flexible(
						child: ConstrainedBox(
							constraints: const BoxConstraints(
								maxWidth: 500
							),
							child: GestureDetector(
								onTapUp: (details) {
									final size = (_customPaintKey.currentContext?.findRenderObject() as RenderBox).paintBounds.size;
									setState(() {
										this.tappedPosition = Offset(details.localPosition.dx / size.width, details.localPosition.dy / size.height);
									});
								},
								child: CustomPaint(
									key: _customPaintKey,
									size: Size(challenge.image.width.toDouble(), challenge.image.height.toDouble()),
									painter: _CaptchaMcCaptchaCustomPainter(
										image: challenge.image,
										tappedPosition: tappedPosition
									)
								)
							)
						)
					),
					if (widget.request.question != null) ...[
						const SizedBox(height: 16),
						Text(widget.request.question!),
						const SizedBox(height: 16),
						SizedBox(
							width: 150,
							child: AdaptiveTextField(
								controller: answerController,
								enableIMEPersonalizedLearning: false,
								autocorrect: false,
							)
						)
					],
					const SizedBox(height: 16),
					Row(
						mainAxisSize: MainAxisSize.min,
						children: [
							AdaptiveIconButton(
								onPressed: _tryRequestChallenge,
								icon: const Text('Refresh')
							),
							const SizedBox(width: 32),
							AdaptiveIconButton(
								onPressed: tappedPosition == null ? null : () {
									widget.onCaptchaSolved(McCaptchaSolution(
										answer: answerController.text,
										acquiredAt: challenge.acquiredAt,
										guid: challenge.guid,
										x: (tappedPosition.dx * challenge.image.width).round(),
										y: (tappedPosition.dy * challenge.image.height).round()
									));
								},
								icon: const Text('Submit')
							)
						]
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
		challenge?.image.dispose();
		answerController.dispose();
	}
}

class _CaptchaMcCaptchaCustomPainter extends CustomPainter{
	final ui.Image image;
	final Offset? tappedPosition;

	_CaptchaMcCaptchaCustomPainter({
		required this.image,
		required this.tappedPosition
	});

	@override
	void paint(Canvas canvas, Size size) {
		final double height = image.height.toDouble();
		final double width = image.width.toDouble();
		canvas.drawImageRect(
			image,
			Rect.fromLTWH(0, 0, width, height),
			Rect.fromLTWH(0, 0, size.width, size.height),
			Paint()
		);
		final tappedPosition = this.tappedPosition;
		if (tappedPosition != null) {
			final paint = Paint()..color = Colors.blue..strokeWidth = 5;
			canvas.drawLine(Offset(0, tappedPosition.dy * height), Offset(width, tappedPosition.dy * height), paint);
			canvas.drawLine(Offset(tappedPosition.dx * width, 0), Offset(tappedPosition.dx * width, height), paint);
		}
	}

	@override
	bool shouldRepaint(_CaptchaMcCaptchaCustomPainter oldDelegate) {
		return image != oldDelegate.image ||
		       tappedPosition != oldDelegate.tappedPosition;
	}
}

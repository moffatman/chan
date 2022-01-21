import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui show Image, PictureRecorder;

import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/timed_rebuilder.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class Captcha4ChanCustom extends StatefulWidget {
	final Chan4CustomCaptchaRequest request;
	final ValueChanged<Chan4CustomCaptchaSolution> onCaptchaSolved;

	const Captcha4ChanCustom({
		required this.request,
		required this.onCaptchaSolved,
		Key? key
	}) : super(key: key);

	@override
	createState() => _Captcha4ChanCustomState();
}

class Captcha4ChanCustomException implements Exception {
	String message;
	Captcha4ChanCustomException(this.message);

	@override
	String toString() => '4chan captcha error: $message';
}

class Captcha4ChanCustomChallenge {
	String challenge;
	DateTime expiresAt;
	ui.Image? foregroundImage;
	ui.Image? backgroundImage;

	Captcha4ChanCustomChallenge({
		required this.challenge,
		required this.expiresAt,
		required this.foregroundImage,
		required this.backgroundImage
	});

	void dispose() {
		foregroundImage?.dispose();
		backgroundImage?.dispose();
	}
}

class _Captcha4ChanCustomPainter extends CustomPainter{
	final ui.Image foregroundImage;
	final ui.Image? backgroundImage;
	final int backgroundSlide;
	_Captcha4ChanCustomPainter({
		required this.foregroundImage,
		required this.backgroundImage,
		required this.backgroundSlide
	});

	@override
	void paint(Canvas canvas, Size size) {
		final double height = foregroundImage.height.toDouble();
		final double width = foregroundImage.width.toDouble();
		if (backgroundImage != null) {
			canvas.drawImageRect(
				backgroundImage!,
				Rect.fromLTWH(backgroundSlide.toDouble(), 0, width, height),
				Rect.fromLTWH(0, 0, size.width, size.height),
				Paint()
			);
		}
		canvas.drawImageRect(
			foregroundImage,
			Rect.fromLTWH(0, 0, width, height),
			Rect.fromLTWH(0, 0, size.width, size.height),
			Paint()
		);
	}

	@override
	bool shouldRepaint(_Captcha4ChanCustomPainter oldDelegate) {
		return foregroundImage != oldDelegate.foregroundImage && backgroundImage != oldDelegate.backgroundImage && backgroundSlide != oldDelegate.backgroundSlide;
	}
}

class _Captcha4ChanCustomState extends State<Captcha4ChanCustom> {
	String? errorMessage;
	DateTime? tryAgainAt;
	Captcha4ChanCustomChallenge? challenge;
	int backgroundSlide = 0;
	final _solutionNode = FocusNode();

	Future<Captcha4ChanCustomChallenge> _requestChallenge() async {
		final challengeResponse = await context.read<ImageboardSite>().client.get(widget.request.challengeUrl.toString());
		if (challengeResponse.statusCode != 200) {
			throw Captcha4ChanCustomException('Got status code ${challengeResponse.statusCode}');
		}
		final data = challengeResponse.data;
		if (data['cd'] != null) {
			tryAgainAt = DateTime.now().add(Duration(seconds: data['cd']));
		}
		if (data['error'] != null) {
			throw Captcha4ChanCustomException(data['error']);
		}
		Completer<ui.Image>? foregroundImageCompleter;
		if (data['img'] != null) {
			foregroundImageCompleter = Completer<ui.Image>();
			MemoryImage(base64Decode(data['img'])).resolve(const ImageConfiguration()).addListener(ImageStreamListener((info, isSynchronous) {
				foregroundImageCompleter!.complete(info.image);
			}, onError: (e, st) {
				foregroundImageCompleter!.completeError(e);
			}));
		}
		Completer<ui.Image>? backgroundImageCompleter;
		if (data['bg'] != null) {
			backgroundImageCompleter = Completer<ui.Image>();
			MemoryImage(base64Decode(data['bg'])).resolve(const ImageConfiguration()).addListener(ImageStreamListener((info, isSynchronous) {
				backgroundImageCompleter!.complete(info.image);
			}, onError: (e, st) {
				backgroundImageCompleter!.completeError(e);
			}));
		}
		final foregroundImage = await foregroundImageCompleter?.future;
		final backgroundImage = await backgroundImageCompleter?.future;
		return Captcha4ChanCustomChallenge(
			challenge: data['challenge'],
			expiresAt: DateTime.now().add(Duration(seconds: data['ttl'])),
			foregroundImage: foregroundImage,
			backgroundImage: backgroundImage
		);
	}

	void _tryRequestChallenge() async {
		try {
			setState(() {
				errorMessage = null;
				tryAgainAt = null;
				challenge?.dispose();
				challenge = null;
			});
			challenge = await _requestChallenge();
			if (challenge!.foregroundImage == null && challenge!.backgroundImage == null) {
				if (challenge!.challenge == 'noop') {
					widget.onCaptchaSolved(Chan4CustomCaptchaSolution(
						challenge: 'noop',
						response: ''
					));
					return;
				}
				else {
					throw Captcha4ChanCustomException('Unknown error, maybe the captcha format has changed: ${challenge!.challenge}');
				}
			}
			backgroundSlide = 0;
			if (challenge!.backgroundImage != null) {
				await _alignImage();
			}
			setState(() {});
			_solutionNode.requestFocus();
		}
		catch(e) {
			setState(() {
				errorMessage = e.toStringDio();
			});
		}
	}

	Future<void> _alignImage() async {
		int? lowestMismatch;
		int? bestSlide;
		final width = challenge!.foregroundImage!.width;
		final height = challenge!.foregroundImage!.height;
		final foregroundBytes = (await challenge!.foregroundImage!.toByteData())!;
		final checkRights = [];
		final checkDowns = [];
		for (int x = 0; x < width - 1; x++) {
			for (int y = 0; y < height - 1; y++) {
				final thisA = foregroundBytes.getUint8((4 * (x + (y * width))) + 3);
				final rightA = foregroundBytes.getUint8((4 * ((x + 1) + (y * width))) + 3);
				final downA = foregroundBytes.getUint8((4 * (x + ((y + 1) * width))) + 3);
				if (thisA != rightA) {
					checkRights.add(4 * (x + (y * width)));
				}
				if (thisA != downA) {
					checkDowns.add(4 * (x + (y * width)));
				}
			}
		}
		for (var i = 0; i < (challenge!.backgroundImage!.width - width); i++) {
			final recorder = ui.PictureRecorder();
			final canvas = Canvas(recorder);
			_Captcha4ChanCustomPainter(
				backgroundImage: challenge!.backgroundImage!,
				foregroundImage: challenge!.foregroundImage!,
				backgroundSlide: i
			).paint(canvas, Size(width.toDouble(), height.toDouble()));
			final image = await recorder.endRecording().toImage(width, height);
			final bytes = (await image.toByteData())!;
			int mismatch = 0;
			for (final checkRight in checkRights) {
				final thisR = bytes.getUint8(checkRight);
				final rightR = bytes.getUint8(checkRight + 4);
				mismatch += (thisR - rightR).abs();
			}
			for (final checkDown in checkDowns) {
				final thisR = bytes.getUint8(checkDown);
				final downR = bytes.getUint8(checkDown + (4 * width));
				mismatch += (thisR - downR).abs();
			}
			if (lowestMismatch == null || mismatch < lowestMismatch) {
				lowestMismatch = mismatch;
				bestSlide = i;
			}
		}
		if (bestSlide != null) {
			setState(() {
				backgroundSlide = bestSlide!;
			});
		}
	}

	@override
	void initState() {
		super.initState();
		_tryRequestChallenge();
	}

	Widget _cooldownedRetryButton(BuildContext context) {
		if (tryAgainAt != null) {
			return TimedRebuilder(
				interval: const Duration(seconds: 1),
				builder: (context) {
					final seconds = tryAgainAt!.difference(DateTime.now()).inSeconds;
					return CupertinoButton(
						child: Row(
							mainAxisSize: MainAxisSize.min,
							children: [
								const Icon(CupertinoIcons.refresh),
								const SizedBox(width: 16),
								SizedBox(
									width: 24,
									child: seconds > 0 ? Text('$seconds') : Container()
								)
							]
						),
						onPressed: seconds > 0 ? null : _tryRequestChallenge
					);
				}
			);
		}
		return CupertinoButton(
			child: const Icon(CupertinoIcons.refresh),
			onPressed: _tryRequestChallenge
		);
	}

	Widget _build(BuildContext context) {
		if (errorMessage != null) {
			return Center(
				child: Column(
					children: [
						Text(errorMessage!),
						_cooldownedRetryButton(context)
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
							child: (challenge!.foregroundImage == null) ? const Text('Verification not required') : AspectRatio(
								aspectRatio: challenge!.foregroundImage!.width / challenge!.foregroundImage!.height,
								child: CustomPaint(
									size: Size(challenge!.foregroundImage!.width.toDouble(), challenge!.foregroundImage!.height.toDouble()),
									painter: _Captcha4ChanCustomPainter(
										foregroundImage: challenge!.foregroundImage!,
										backgroundImage: challenge!.backgroundImage,
										backgroundSlide: backgroundSlide
									)
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
							mainAxisAlignment: MainAxisAlignment.spaceBetween,
							children: [
								_cooldownedRetryButton(context),
								if (challenge!.backgroundImage != null) CupertinoSlider(
									value: backgroundSlide.toDouble(),
									divisions: challenge!.backgroundImage!.width - challenge!.foregroundImage!.width,
									max: (challenge!.backgroundImage!.width - challenge!.foregroundImage!.width).toDouble(),
									onChanged: (newOffset) {
										setState(() {
											backgroundSlide = newOffset.floor();
										});
									}
								),
								Row(
									children: [
										const Icon(CupertinoIcons.timer),
										const SizedBox(width: 16),
										SizedBox(
											width: 60,
											child: TimedRebuilder(
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
							onSubmitted: (response) => widget.onCaptchaSolved(Chan4CustomCaptchaSolution(
								challenge: challenge!.challenge,
								response: response
							)),
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
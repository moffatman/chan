import 'dart:async';
import 'dart:ui' as ui show Image;

import 'package:chan/sites/imageboard_site.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' show Document;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:html/parser.dart' show parse;

class CaptchaNoJS extends StatefulWidget {
	final CaptchaRequest request;
	final ValueChanged<String> onCaptchaSolved;

	CaptchaNoJS({
		required this.request,
		required this.onCaptchaSolved
	});

	@override
	createState() => _CaptchaNoJSState();
}

// Copied from Clover
const Map _HEADERS = {
	'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.131 Safari/537.36',
	'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3',
	'Accept-Language': 'en-US',
	'Accept-Encoding': 'deflate, br',
	'Cookie': 'NID=87=gkOAkg09AKnvJosKq82kgnDnHj8Om2pLskKhdna02msog8HkdHDlasDf'
};

class CaptchaNoJSException implements Exception {
	String message;
	CaptchaNoJSException(this.message);

	String toString() => 'Captcha error: $message';
}

class _CaptchaNoJSSubimagePainter extends CustomPainter{
	final ui.Image image;
	final CaptchaNoJSSubimage subimage;
	_CaptchaNoJSSubimagePainter(this.image, this.subimage);

	@override
	void paint(Canvas canvas, Size size) {
		canvas.drawImageRect(
			image,
			subimage.rect,
			Rect.fromLTWH(0, 0, size.width, size.height),
			Paint()
		);
	}

	@override
	bool shouldRepaint(_CaptchaNoJSSubimagePainter oldDelegate) {
		return image != oldDelegate.image && subimage != oldDelegate.subimage && subimage.selected != oldDelegate.subimage.selected;
	}
}

class CaptchaNoJSSubimage {
	final int id;
	bool selected;
	final Rect rect;
	CaptchaNoJSSubimage({
		required this.id,
		required this.rect,
		this.selected = false
	});
}

class CaptchaNoJSChallenge {
	String title;
	String responseKey;
	ui.Image image;
	List<List<CaptchaNoJSSubimage>> subimages;

	CaptchaNoJSChallenge({
		required this.title,
		required this.responseKey,
		required this.image,
		required this.subimages,
	});

	String submitAnswer(Map<int, bool> checkboxes) {
		throw CaptchaNoJSException('unimplemented');
	}

	void dispose() {
		image.dispose();
	}
}

class _CaptchaNoJSState extends State<CaptchaNoJS> with SingleTickerProviderStateMixin {
	final http.Client client = IOClient();
	String? errorMessage;
	CaptchaNoJSChallenge? challenge;

	List<List<CaptchaNoJSSubimage>> _makeSubimages(ui.Image image, int columns, int rows) {
		double subimageHeight = image.height / rows;
		double subimageWidth = image.width / columns;
		return List.generate(rows, (row) {
			return List.generate(columns, (column) {
				return CaptchaNoJSSubimage(
					id: (row * rows) + column,
					rect: Rect.fromLTWH(column * subimageWidth, row * subimageHeight, subimageWidth, subimageHeight)
				);
			});
		});
	}

	Future<CaptchaNoJSChallenge> _gotChallengePage(Document document) async {
		final img = document.querySelector('img.fbc-imageselect-payload');
		if (img == null) {
			throw CaptchaNoJSException('Image missing from challenge');
		}
		final challengeImageCompleter = Completer<ui.Image>();
		NetworkImage('https://www.google.com' + img.attributes['src']!).resolve(ImageConfiguration()).addListener(ImageStreamListener((info, isSynchronous) {
			challengeImageCompleter.complete(info.image);
		}, onError: (e, st) {
			challengeImageCompleter.completeError(e);
		}));
		final checkboxes = Set<int>();
		for (final checkbox in document.querySelectorAll('input[name="response"]')) {
			checkboxes.add(int.parse(checkbox.attributes['value']!));
		}
		final challengeImage = await challengeImageCompleter.future;
		List<List<CaptchaNoJSSubimage>>? subimages;
		if (checkboxes.length == 8) {
			// Storefronts (2x4)
			subimages = _makeSubimages(challengeImage, 2, 4);
		}
		else if (checkboxes.length == 9) {
			// Normal 3x3
			subimages = _makeSubimages(challengeImage, 3, 3);
		}
		if (subimages == null) {
			throw CaptchaNoJSException('Captcha had an unexpected number of images: ${checkboxes.length}');
		}
		return CaptchaNoJSChallenge(
			title: document.querySelector('.rc-imageselect-desc-no-canonical')!.text,
			responseKey: document.querySelector('input[name="c"]')!.attributes['value']!,
			image: challengeImage,
			subimages: subimages
		);
	}

	Future<CaptchaNoJSChallenge> _requestChallenge() async {
		final challengeResponse = await client.get(Uri.https('www.google.com', '/recaptcha/api/fallback', {
			'k': widget.request.key
		}), headers: {
			'Referer': widget.request.sourceUrl,
			..._HEADERS
		});
		if (challengeResponse.statusCode != 200) {
			print(challengeResponse.request!.url);
			throw CaptchaNoJSException('Got status code ${challengeResponse.statusCode}');
		}
		final document = parse(challengeResponse.body);
		return _gotChallengePage(document);
	}

	void _tryRequestChallenge() async {
		try {
			setState(() {
				errorMessage = null;
				challenge?.dispose();
				challenge = null;
			});
			this.challenge = await _requestChallenge();
			setState(() {});
		}
		catch(e, st) {
			print(e);
			print(st);
			setState(() {
				this.errorMessage = e.toString();
			});
		}
	}

	Future<void> _submitChallenge() async {
		if (challenge == null) {
			print('Tried to submit non-existent challenge');
			return;
		}
		final chal = challenge!;
		setState(() {
			errorMessage = null;
			challenge = null;
		});
		final submissionResponse = await client.post(Uri.https('www.google.com', '/recaptcha/api/fallback', {
			'k': widget.request.key
		}), headers: {
			'Referer': 'https://www.google.com/recaptcha/api/fallback?k=${widget.request.key}',
			'Content-Type': 'application/x-www-form-urlencoded',
			..._HEADERS
		}, body: 'c=${chal.responseKey}' + chal.subimages.expand((r) => r).where((s) => s.selected).map((s) => '&response=${s.id}').join());
		if (submissionResponse.statusCode != 200) {
			throw CaptchaNoJSException('Got status code ${submissionResponse.statusCode}');
		}
		final document = parse(submissionResponse.body);
		final tokenElement = document.querySelector('.fbc-verification-token textarea');
		if (tokenElement != null) {
			widget.onCaptchaSolved(tokenElement.text);
		}
		else {
			this.challenge = await _gotChallengePage(document);
			setState(() {});
		}
	}

	void _trySubmitChallenge() async {
		try {
			await _submitChallenge();
		}
		catch(e, st) {
			print(e);
			print(st);
			setState(() {
				this.errorMessage = e.toString();
			});
		}
	}

	@override
	void initState() {
		super.initState();
		_tryRequestChallenge();
	}

	Widget _build(BuildContext context) {
		if (errorMessage != null) {
			return Center(
				child: Column(
					children: [
						Text(errorMessage!),
						CupertinoButton(
							child: Text('Retry'),
							onPressed: _tryRequestChallenge
						)
					]
				)
			);
		}
		else if (challenge != null) {
			return Column(
				mainAxisSize: MainAxisSize.min,
				children: [
					Text(challenge!.title),
					SizedBox(height: 16),
					...challenge!.subimages.map((row) {
						return Row(
							mainAxisSize: MainAxisSize.min,
							children: row.map((subimage) {
								return GestureDetector(
									child: Container(
										decoration: BoxDecoration(
											border: Border.all(
												color: subimage.selected ? Colors.blue : Colors.transparent,
												width: 4
											)
										),
										child: CustomPaint(
											size: subimage.rect.size,
											painter: _CaptchaNoJSSubimagePainter(challenge!.image, subimage)
										)
									),
									onTap: () {
										subimage.selected = !subimage.selected;
										setState(() {});
									}
								);
							}).expand((e) => [SizedBox(width: 12), e]).skip(1).toList()
						);
					}).expand((e) => [SizedBox(height: 12), e]).skip(1).toList(),
					SizedBox(height: 16),
					Row(
						mainAxisSize: MainAxisSize.min,
						children: [
							CupertinoButton(
								child: Text('Refresh'),
								onPressed: _tryRequestChallenge
							),
							SizedBox(width: 32),
							CupertinoButton(
								child: Text('Submit'),
								onPressed: _trySubmitChallenge
							)
						]
					)
				]
			);
		}
		else {
			return Center(
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
			padding: EdgeInsets.all(16),
			child: AnimatedSize(
				duration: const Duration(milliseconds: 100),
				vsync: this,
				child: _build(context)
			)
		);
	}
}
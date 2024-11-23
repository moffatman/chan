import 'dart:async';
import 'dart:typed_data';

import 'package:chan/services/cloudflare.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/sites/8chan.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/lynxchan.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/timed_rebuilder.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart';

class CaptchaLynxchan extends StatefulWidget {
	final LynxchanCaptchaRequest request;
	final ValueChanged<LynxchanCaptchaSolution> onCaptchaSolved;
	final ImageboardSite site;

	const CaptchaLynxchan({
		required this.request,
		required this.onCaptchaSolved,
		required this.site,
		Key? key
	}) : super(key: key);

	@override
	createState() => _CaptchaLynxchanState();
}

class CaptchaLynxchanException implements Exception {
	String message;
	CaptchaLynxchanException(this.message);

	@override
	String toString() => 'Lynxchan captcha error: $message';
}

class CaptchaLynxchanChallenge {
	final String id;
	final DateTime acquiredAt;
	final Duration lifetime;
	DateTime get expiresAt => acquiredAt.add(lifetime);
	final Uint8List imageBytes;

	CaptchaLynxchanChallenge({
		required this.id,
		required this.acquiredAt,
		required this.lifetime,
		required this.imageBytes
	});
}

class _CaptchaLynxchanState extends State<CaptchaLynxchan> {
	(Object, StackTrace)? error;
	CaptchaLynxchanChallenge? challenge;
	late final FocusNode _solutionNode;

	@override
	void initState() {
		super.initState();
		_solutionNode = FocusNode();
		_tryRequestChallenge();
	}

	Future<CaptchaLynxchanChallenge> _requestChallenge() async {
		Persistence.currentCookies.delete(Uri.https(widget.site.baseUrl, '/captcha.js'), true);
		final lastSolvedCaptcha = widget.site.persistence?.browserState.loginFields[SiteLynxchan.kLoginFieldLastSolvedCaptchaKey];
		final idResponse = await widget.site.client.getUri(Uri.https(widget.site.baseUrl, '/captcha.js', {
			'boardUri': widget.request.board,
			'd': (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
			if (lastSolvedCaptcha != null) 'solvedCaptcha': lastSolvedCaptcha
		}), options: Options(
			responseType: ResponseType.json,
			followRedirects: false, // dio loses the cookies in the first 303 response
			validateStatus: (status) => (status ?? 0) < 400,
			extra: {
				kPriority: RequestPriority.interactive,
				// Or else it confuses the redirect gateway and the captcha image redirect
				kCloudflare: widget.site is Site8Chan
			}
		));
		final String id;
		final String imagePath;
		final redirectPath = idResponse.headers.value('location');
		if (redirectPath != null && redirectPath.startsWith('/.global/captchas/')) {
			id = redirectPath.split('/').last;
			imagePath = redirectPath;
		}
		else if (idResponse.data is String) {
			final fromCookie = idResponse.headers['set-cookie']?.tryMapOnce((cookie) {
				return RegExp(r'captchaid=([^;]+)').firstMatch(cookie)?.group(1);
			});
			if (fromCookie != null) {
				id = fromCookie;
				imagePath = '/captcha.js?captchaId=${id.substring(0, 24)}';
			}
			else {
				// 8chan has a <html> with <img>
				final doc = parse(idResponse.data);
				final src = doc.querySelector('img')?.attributes['src'];
				if (src == null) {
					throw CaptchaLynxchanException('Captcha response has changed');
				}
				final uri = Uri.parse(src);
				id = uri.pathSegments.last;
				imagePath = uri.path;
			}
		}
		else {
			if (idResponse.data['error'] != null) {
				throw CaptchaLynxchanException(idResponse.data['error']['message'] as String);
			}
			id = idResponse.data['data'] as String;
			imagePath = '/.global/captchas/${id.substring(0, 24)}';
		}
		final imageResponse = await widget.site.client.get('https://${widget.site.baseUrl}$imagePath', options: Options(
			responseType: ResponseType.bytes,
			extra: {
				kPriority: RequestPriority.interactive
			}
		));
		if (imageResponse.statusCode != 200) {
			throw CaptchaLynxchanException('Got status code ${idResponse.statusCode}');
		}
		return CaptchaLynxchanChallenge(
			id: id,
			acquiredAt: DateTime.now(),
			lifetime: const Duration(minutes: 2),
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

	void _solve(String answer) {
		widget.onCaptchaSolved(LynxchanCaptchaSolution(
			id: challenge!.id,
			answer: answer,
			acquiredAt: challenge!.acquiredAt,
			lifetime: challenge!.lifetime
		));
		widget.site.persistence?.browserState.loginFields[SiteLynxchan.kLoginFieldLastSolvedCaptchaKey] = challenge!.id;
		widget.site.persistence?.didUpdateBrowserState();
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
							onSubmitted: _solve,
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
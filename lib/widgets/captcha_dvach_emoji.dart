import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/cupertino_inkwell.dart';
import 'package:chan/widgets/timed_rebuilder.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CaptchaDvachEmoji extends StatefulWidget {
	final DvachEmojiCaptchaRequest request;
	final ValueChanged<DvachEmojiCaptchaSolution> onCaptchaSolved;
	final ImageboardSite site;

	const CaptchaDvachEmoji({
		required this.request,
		required this.onCaptchaSolved,
		required this.site,
		Key? key
	}) : super(key: key);

	@override
	createState() => _CaptchaDvachEmojiState();
}

class CaptchaDvachEmojiException implements Exception {
	String message;
	CaptchaDvachEmojiException(this.message);

	@override
	String toString() => 'Dvach emoji captcha error: $message';
}

class CaptchaDvachEmojiChallenge {
	final String id;
	final DateTime acquiredAt;
	final Duration lifetime;
	DateTime get expiresAt => acquiredAt.add(lifetime);

	CaptchaDvachEmojiChallenge({
		required this.id,
		required this.acquiredAt,
		required this.lifetime
	});
}

class CaptchaDvachEmojiPage {
	final ui.Image image;
	final List<ui.Image> keyboardImages;

	CaptchaDvachEmojiPage({
		required this.image,
		required this.keyboardImages
	});

	void dispose() {
		image.dispose();
		for (final img in keyboardImages) {
			img.dispose();
		}
	}
}

class _CaptchaDvachEmojiState extends State<CaptchaDvachEmoji> {
	(Object, StackTrace)? error;
	(CaptchaDvachEmojiChallenge, CaptchaDvachEmojiPage)? challenge;
	final imageStack = <ui.Image>[];
	bool clicking = false;

	@override
	void initState() {
		super.initState();
		_tryRequestChallenge();
	}

	static Future<CaptchaDvachEmojiPage> _makePage(Map response) async {
		return CaptchaDvachEmojiPage(
			image: await decodeImageFromList(base64.decode(response['image'] as String)),
			keyboardImages: await Future.wait((response['keyboard'] as List).cast<String>().map((bytes) => decodeImageFromList(base64.decode(bytes))))
		);
	}

	Future<(CaptchaDvachEmojiChallenge, CaptchaDvachEmojiPage)> _requestChallenge() async {
		final idResponse = await widget.site.client.getUri(Uri.https(widget.site.baseUrl, '/api/captcha/emoji/id'), options: Options(
			responseType: ResponseType.json,
			extra: {
				kPriority: RequestPriority.interactive
			}
		));
		if (idResponse.statusCode != 200) {
			throw CaptchaDvachEmojiException('Got status code ${idResponse.statusCode}');
		}
		if (idResponse.data['error'] != null) {
			throw CaptchaDvachEmojiException(idResponse.data['error']['message'] as String);
		}
		final chal = CaptchaDvachEmojiChallenge(
			acquiredAt: DateTime.now(),
			id: idResponse.data['id'] as String,
			lifetime: widget.request.challengeLifetime
		);
		final imageResponse = await widget.site.client.getUri(Uri.https(widget.site.baseUrl, '/api/captcha/emoji/show', {
			'id': chal.id
		}), options: Options(
			responseType: ResponseType.json,
			extra: {
				kPriority: RequestPriority.interactive
			}
		));
		if (imageResponse.statusCode != 200) {
			throw CaptchaDvachEmojiException('Got status code ${idResponse.statusCode}');
		}
		return (chal, await _makePage(imageResponse.data as Map));
	}

	void _tryRequestChallenge() async {
		try {
			setState(() {
				error = null;
				challenge?.$2.dispose();
				challenge = null;
				clicking = false;
				imageStack.clear();
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

	void _tryClick(int emojiNumber) async {
		try {
			setState(() {
				imageStack.add(challenge!.$2.keyboardImages[emojiNumber].clone());
				clicking = true;
			});
			final response = await widget.site.client.postUri(Uri.https(widget.site.baseUrl, '/api/captcha/emoji/click'), data: {
				'captchaTokenID': challenge!.$1.id,
				'emojiNumber': emojiNumber
			}, options: Options(
				responseType: ResponseType.json
			));
			if (response.data['success'] case String success) {
				// Done
				widget.onCaptchaSolved(DvachEmojiCaptchaSolution(
					id: success,
					acquiredAt: challenge!.$1.acquiredAt,
					lifetime: challenge!.$1.lifetime
				));
			}
			else {
				final oldPage = challenge!.$2;
				challenge = (challenge!.$1, await _makePage(response.data as Map));
				oldPage.dispose();
			}
		}
		catch (e, st) {
			if (mounted) {
				alertError(context, e, st);
			}
		}
		finally {
			if (mounted) {
				setState(() {
					clicking = false;
				});
			}
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
			final theme = context.watch<SavedTheme>();
			return Stack(
				alignment: Alignment.center,
				children: [
					Opacity(
						opacity: clicking ? 0.5 : 1,
						child: IgnorePointer(
							ignoring: clicking,
							child: Column(
								mainAxisSize: MainAxisSize.min,
								children: [
									const Text('Select all symbols in the picture\n1. The order in which you enter the icons is not important\n2. Not all icons are displayed at once\n3. Missing icons will appear in the following steps'),
									const SizedBox(height: 16),
									Flexible(
										child: ConstrainedBox(
											constraints: const BoxConstraints(
												maxWidth: 500
											),
											child: RawImage(
												image: challenge!.$2.image
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
																	return challenge!.$1.expiresAt.difference(DateTime.now()).inSeconds;
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
									Container(
										margin: const EdgeInsets.all(8),
										decoration: BoxDecoration(
											borderRadius: BorderRadius.circular(8),
											color: theme.barColor
										),
										padding: const EdgeInsets.all(8),
										constraints: const BoxConstraints(
											minHeight: 46
										),
										width: 500,
										child: Wrap(
											spacing: 8,
											runSpacing: 8,
											children: imageStack.map((image) => ColorFiltered(
												colorFilter: ColorFilter.mode(
													theme.primaryColor,
													BlendMode.srcIn
												),
												child: RawImage(
													image: image,
													width: 30,
													height: 30,
													fit: BoxFit.contain
												)
											)).toList()
										)
									),
									const SizedBox(height: 16),
									Wrap(
										alignment: WrapAlignment.center,
										children: challenge!.$2.keyboardImages.indexed.map((pair) => CupertinoInkwell(
											onPressed: () => _tryClick(pair.$1),
											child: ColorFiltered(
												colorFilter: ColorFilter.mode(
													theme.primaryColor,
													BlendMode.srcIn
												),
												child: RawImage(
													image: pair.$2,
													width: 60,
													height: 60,
													fit: BoxFit.contain
												)
											)
										)).toList()
									)
								]
							)
						)
					),
					if (clicking) const CircularProgressIndicator.adaptive()
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
		for (final img in imageStack) {
			img.dispose();
		}
		challenge?.$2.dispose();
	}
}
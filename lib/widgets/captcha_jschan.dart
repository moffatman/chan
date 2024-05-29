import 'package:chan/services/cookies.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/timed_rebuilder.dart';
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
	String? errorMessage;
	CaptchaJsChanChallenge? challenge;
	final selected = <int>{};

	@override
	void initState() {
		super.initState();
		_tryRequestChallenge();
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
			imageBytes: Uint8List.fromList(response.data)
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
		}
		catch(e, st) {
			print(e);
			print(st);
			setState(() {
				errorMessage = e.toStringDio();
			});
		}
	}

	void _solve() {
		widget.onCaptchaSolved(JsChanCaptchaSolution(
			id: challenge!.id,
			selected: selected.toSet(),
			lifetime: challenge!.lifetime,
			acquiredAt: challenge!.acquiredAt
		));
	}

	Widget _build(BuildContext context) {
		if (errorMessage != null) {
			return Center(
				child: Column(
					children: [
						Text(errorMessage!),
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
										SizedBox(
											width: 60,
											child: TimedRebuilder(
												enabled: true,
												interval: const Duration(seconds: 1),
												function: () {
													return challenge!.expiresAt.difference(DateTime.now()).inSeconds;
												},
												builder: (context, seconds) {
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
}
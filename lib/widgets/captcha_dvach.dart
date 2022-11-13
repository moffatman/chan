import 'dart:async';
import 'dart:typed_data';

import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/timed_rebuilder.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

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
	DateTime expiresAt;
	Uint8List imageBytes;

	CaptchaDvachChallenge({
		required this.id,
		required this.inputType,
		required this.expiresAt,
		required this.imageBytes
	});
}

class _CaptchaDvachState extends State<CaptchaDvach> {
	String? errorMessage;
	CaptchaDvachChallenge? challenge;
	late final FocusNode _solutionNode;

	@override
	void initState() {
		super.initState();
		_solutionNode = FocusNode();
		_tryRequestChallenge();
	}

	Future<CaptchaDvachChallenge> _requestChallenge() async {
		final idResponse = await widget.site.client.get(Uri.https(widget.site.baseUrl, '/api/captcha/2chcaptcha/id').toString(), options: Options(
			responseType: ResponseType.json
		));
		if (idResponse.statusCode != 200) {
			throw CaptchaDvachException('Got status code ${idResponse.statusCode}');
		}
		if (idResponse.data['error'] != null) {
			throw CaptchaDvachException(idResponse.data['error']['message']);
		}
		final String id = idResponse.data['id'];
		final String inputType = idResponse.data['input'];
		final DateTime expiresAt = DateTime.now().add(widget.request.challengeLifetime);
		final imageResponse = await widget.site.client.get(Uri.https(widget.site.baseUrl, '/api/captcha/2chcaptcha/show').toString(), queryParameters: {
			'id': id
		}, options: Options(
			responseType: ResponseType.bytes
		));
		if (imageResponse.statusCode != 200) {
			throw CaptchaDvachException('Got status code ${idResponse.statusCode}');
		}
		return CaptchaDvachChallenge(
			id: id,
			inputType: inputType,
			expiresAt: expiresAt,
			imageBytes: Uint8List.fromList(imageResponse.data)
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
							enableIMEPersonalizedLearning: false,
							autocorrect: false,
							placeholder: 'Captcha text',
							keyboardType: challenge?.inputType == 'numeric' ? TextInputType.number : null,
							onSubmitted: (response) async {
								widget.onCaptchaSolved(DvachCaptchaSolution(
									id: challenge!.id,
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

	@override
	void dispose() {
		super.dispose();
		_solutionNode.dispose();
	}
}
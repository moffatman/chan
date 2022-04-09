import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui show Image, PictureRecorder;

import 'package:chan/services/captcha_4chan.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/timed_rebuilder.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
	final _solutionController = TextEditingController();
	final _letterPickerControllers = List.generate(5, (i) => FixedExtentScrollController());
	List<double> _guessConfidences = List.generate(5, (i) => 1.0);
	String _lastGuessText = "";
	bool _greyOutPickers = true;
	final _pickerKeys = List.generate(5, (i) => GlobalKey());
	double _guessingProgress = 0.0;

	Future<void> _animateGuess() async {
		setState(() {
			_guessingProgress = 0.0;
			_greyOutPickers = true;
		});
		try {
			final _guess = await guess(
				await _screenshotImage(),
				onProgress: (progress) {
					setState(() {
						_guessingProgress = progress;
					});
				}
			);
			_solutionController.text = _guess.guess;
			_lastGuessText = _guess.guess;
			_guessConfidences = _guess.confidences;
		}
		catch (e, st) {
			print(e);
			print(st);
		}
		if (context.read<EffectiveSettings>().supportMouse.value) {
			_solutionController.selection = const TextSelection(baseOffset: 0, extentOffset: 1);
			_solutionNode.requestFocus();
		}
		setState(() {
			_greyOutPickers = false;
		});
	}

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
						response: '',
						expiresAt: challenge!.expiresAt,
						alignedImage: null
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
			if (context.read<EffectiveSettings>().useNewCaptchaForm) {
				_solutionController.text = "00000";
				setState(() {});
				await _animateGuess();
			}
			else {
				setState(() {});
				_solutionNode.requestFocus();
			}
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

	Future<ui.Image> _screenshotImage() {
		final recorder = ui.PictureRecorder();
		final canvas = Canvas(recorder);
		final width = challenge!.foregroundImage!.width;
		final height = challenge!.foregroundImage!.height;
		_Captcha4ChanCustomPainter(
			backgroundImage: challenge!.backgroundImage,
			foregroundImage: challenge!.foregroundImage!,
			backgroundSlide: backgroundSlide
		).paint(canvas, Size(width.toDouble(), height.toDouble()));
		return recorder.endRecording().toImage(width, height);
	}

	String _previousText = "00000";
	TextSelection _previousSelection = const TextSelection(baseOffset: 0, extentOffset: 1);
	bool _modifyingFromPicker = false;

	void _onSolutionControllerUpdate() {
		final selection = _solutionController.selection;
		final newText = _solutionController.text;
		if (_solutionController.text.length != 5) {
			_solutionController.text = _solutionController.text.substring(0, min(5, _solutionController.text.length)).padRight(5, ' ');
		}
		for (int i = 0; i < 5; i++) {
			final char = _solutionController.text[i].toUpperCase();
			if (!captchaLetters.contains(char)) {
				const remap = {
					'B': '8',
					'F': 'P',
					'U': 'V',
					'Z': '2',
					'O': '0'
				};
				if (remap[char] != null) {
					_solutionController.text = _solutionController.text.replaceRange(i, i + 1, remap[char]!);
				}
				else {
					_solutionController.text = _previousText;
					_solutionController.selection = TextSelection(baseOffset: i, extentOffset: i + 1);
				}
			}
		}
		int start = selection.baseOffset % 5;
		if (selection.isCollapsed) {
			if (_previousSelection.baseOffset == selection.baseOffset && _previousText == newText) {
				// Left-arrow was pressed
				start = (start - 1) % 5;
			}
			_solutionController.selection = TextSelection(baseOffset: start, extentOffset: start + 1);
		}
		if (!_modifyingFromPicker && _previousText != _solutionController.text) {
			for (int i = 0; i < 5; i++) {
				if (_previousText[i] != _solutionController.text[i]) {
					_guessConfidences[i] = 1;
					_letterPickerControllers[i].animateToItem(captchaLetters.indexOf(newText[i].toUpperCase()), duration: const Duration(milliseconds: 250), curve: Curves.elasticIn);
					setState(() {});
				}
			}
		}
		_previousText = _solutionController.text;
		_previousSelection = _solutionController.selection;
	}

	Future<void> _submit(String response) async {
		widget.onCaptchaSolved(Chan4CustomCaptchaSolution(
			challenge: challenge!.challenge,
			response: response,
			expiresAt: challenge!.expiresAt,
			alignedImage: await _screenshotImage()
		));
	}

	@override
	void initState() {
		super.initState();
		if (context.read<EffectiveSettings>().useNewCaptchaForm) {
			_solutionController.text = "00000";
			_solutionController.selection = const TextSelection(baseOffset: 0, extentOffset: 1);
			_solutionController.addListener(_onSolutionControllerUpdate);
		}
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
									width: 32,
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
			return Center(
				child: ConstrainedBox(
					constraints: const BoxConstraints(
						maxWidth: 500
					),
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							const Text('Enter the text in the image below'),
							const SizedBox(height: 16),
							Flexible(
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
							),
							const SizedBox(height: 16),
							Row(
								mainAxisAlignment: MainAxisAlignment.center,
								children: [
									Flexible(
										fit: FlexFit.tight,
										flex: 1,
										child:  _cooldownedRetryButton(context)
									),
									if (challenge!.backgroundImage != null) Flexible(
										flex: 2,
										fit: FlexFit.tight,
										child: Padding(
											padding: const EdgeInsets.symmetric(horizontal: 16),
											child: IgnorePointer(
												ignoring: _greyOutPickers,
												child: Opacity(
													opacity: _greyOutPickers ? 0.5 : 1.0,
													child: CupertinoSlider(
														value: backgroundSlide.toDouble(),
														divisions: challenge!.backgroundImage!.width - challenge!.foregroundImage!.width,
														max: (challenge!.backgroundImage!.width - challenge!.foregroundImage!.width).toDouble(),
														onChanged: (newOffset) {
															setState(() {
																backgroundSlide = newOffset.floor();
															});
														},
														onChangeEnd: (newOffset) {
															if (_solutionController.text.toUpperCase() == _lastGuessText.toUpperCase()) {
																_animateGuess();
															}
														}
													)
												)
											)
										)
									),
									Flexible(
										flex: 1,
										fit: FlexFit.tight,
										child: Row(
											mainAxisAlignment: MainAxisAlignment.end,
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
									)
								]
							),
							const SizedBox(height: 0),
							Visibility(
								visible: !context.read<EffectiveSettings>().useNewCaptchaForm,
								maintainAnimation: true,
								maintainState: true,
								child: SizedBox(
									width: 150,
									child: Actions(
										actions: {
											ExtendSelectionVerticallyToAdjacentLineIntent: CallbackAction<ExtendSelectionVerticallyToAdjacentLineIntent>(
												onInvoke: (intent) {
													final controller = _letterPickerControllers[_solutionController.selection.baseOffset];
													if (intent.forward) {
														controller.animateToItem(
															controller.selectedItem + 1,
															duration: const Duration(milliseconds: 100),
															curve: Curves.ease
														);
													}
													else {
														controller.animateToItem(
															controller.selectedItem - 1,
															duration: const Duration(milliseconds: 100),
															curve: Curves.ease
														);
													}
													return null;
												}
											)
										},
										child: CupertinoTextField(
											focusNode: _solutionNode,
											controller: _solutionController,
											autocorrect: false,
											placeholder: 'Captcha text',
											onSubmitted: (text) {
												if (!context.read<EffectiveSettings>().useNewCaptchaForm || WidgetsBinding.instance.window.viewInsets.bottom < 100) {
													// Only submit on enter key if on old form or on hardware keyboard
													_submit(text);
												}
											}
										)
									)
								)
							),
							if (context.read<EffectiveSettings>().useNewCaptchaForm) IgnorePointer(
								ignoring: _greyOutPickers,
								child: Opacity(
									opacity: _greyOutPickers ? 0.5 : 1.0,
									child: Row(
										mainAxisAlignment: MainAxisAlignment.center,
										children: [
											for (int i = 0; i < 5; i++) ...[
												Flexible(
													flex: 1,
													fit: FlexFit.tight,
													child: SizedBox(
														height: 200,
														child: Stack(
															fit: StackFit.expand,
															children: [
																NotificationListener(
																	onNotification: (notification) {
																		if (notification is ScrollEndNotification && notification.metrics is FixedExtentMetrics) {
																			_modifyingFromPicker = true;
																			final selection = _solutionController.selection;
																			_solutionController.text = _solutionController.text.replaceRange(i, i + 1, captchaLetters[(notification.metrics as FixedExtentMetrics).itemIndex]);
																			_solutionController.selection = selection;
																			if (_guessConfidences[i] != 1) {
																				setState(() {
																					_guessConfidences[i] = 1;
																				});
																			}
																			_modifyingFromPicker = false;
																			return true;
																		}
																		return false;
																	},
																	child: CupertinoPicker.builder(
																		key: _pickerKeys[i],
																		scrollController: _letterPickerControllers[i],
																		selectionOverlay: AnimatedBuilder(
																			animation: _solutionController,
																			builder: (context, child) => CupertinoPickerDefaultSelectionOverlay(
																				background: ColorTween(
																					begin: CupertinoColors.tertiarySystemFill.resolveFrom(context),
																					end: CupertinoTheme.of(context).primaryColor
																				).transform((_solutionNode.hasFocus && (_solutionController.selection.baseOffset <= i) && (i < _solutionController.selection.extentOffset)) ? 0.5 : 0)!
																			)
																		),
																		childCount: captchaLetters.length,
																		itemBuilder: (context, l) => Padding(
																			padding: const EdgeInsets.all(6),
																			child: Center(
																				child: Text(captchaLetters[l],
																					style: TextStyle(
																						fontSize: 34,
																						color:  ColorTween(
																							begin: CupertinoTheme.of(context).primaryColor,
																							end: const Color.fromARGB(255, 241, 190, 19)).transform(1 - _guessConfidences[i]
																						)!
																					)
																				)
																			)
																		),
																		itemExtent: 50,
																		onSelectedItemChanged: null
																	)
																),
																Column(
																	crossAxisAlignment: CrossAxisAlignment.stretch,
																	children: [
																		GestureDetector(
																			child:const SizedBox(height: 75),
																			behavior: HitTestBehavior.translucent,
																			onTap: () {
																				_letterPickerControllers[i].animateToItem(
																					_letterPickerControllers[i].selectedItem - 1,
																					duration: const Duration(milliseconds: 100),
																					curve: Curves.ease
																				);
																			}
																		),
																		GestureDetector(
																			child: const SizedBox(height: 50),
																			behavior: HitTestBehavior.translucent,
																			onTap: () {
																				_solutionController.selection = TextSelection(baseOffset: i, extentOffset: i + 1);
																				_solutionNode.requestFocus();
																			}
																		),
																		GestureDetector(
																			child: const SizedBox(height: 75),
																			behavior: HitTestBehavior.translucent,
																			onTap: () {
																				_letterPickerControllers[i].animateToItem(
																					_letterPickerControllers[i].selectedItem + 1,
																					duration: const Duration(milliseconds: 100),
																					curve: Curves.ease
																				);
																			}
																		)
																	]
																)
															]
														)
													)
												),
											]
										]
									)
								)
							),
							if (context.read<EffectiveSettings>().useNewCaptchaForm) Stack(
								children: [
									ClipRRect(
										borderRadius: BorderRadius.circular(8),
										child: LinearProgressIndicator(
											value: _guessingProgress,
											minHeight: 50,
											valueColor: AlwaysStoppedAnimation(CupertinoTheme.of(context).primaryColor),
											backgroundColor: CupertinoTheme.of(context).primaryColor.withOpacity(0.3)
										)
									),
									CupertinoButton(
										padding: EdgeInsets.zero,
										child: SizedBox(
											height: 50,
											child: Center(
												child: Text(
													'Submit',
													style: TextStyle(
														fontSize: 20,
														color: CupertinoTheme.of(context).scaffoldBackgroundColor
													)
												)
											)
										),
										onPressed: _greyOutPickers ? null : () {
											_submit(_solutionController.text);
										}
									)
								]
							)
						]
					)
				)
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
		_solutionController.dispose();
		for (final controller in _letterPickerControllers) {
			controller.dispose();
		}
	}
}
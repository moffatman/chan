import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui show Image, PictureRecorder;

import 'package:async/async.dart';
import 'package:chan/services/captcha_4chan.dart';
import 'package:chan/services/cloudflare.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/timed_rebuilder.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:provider/provider.dart';

class _ModifiedBouncingScrollSimulation extends Simulation {
  _ModifiedBouncingScrollSimulation({
    required double position,
    required double velocity,
    required this.leadingExtent,
    required this.trailingExtent,
    required this.spring,
    Tolerance tolerance = Tolerance.defaultTolerance,
  }): assert(leadingExtent <= trailingExtent), super(tolerance: tolerance) {
    if (position < leadingExtent) {
      _springSimulation = _underscrollSimulation(position, velocity);
      _springTime = double.negativeInfinity;
    } else if (position > trailingExtent) {
      _springSimulation = _overscrollSimulation(position, velocity);
      _springTime = double.negativeInfinity;
    } else {
      // Modified to increase friction
      _frictionSimulation = FrictionSimulation(0.0004, position, velocity);
      final double finalX = _frictionSimulation.finalX;
      if (velocity > 0.0 && finalX > trailingExtent) {
        _springTime = _frictionSimulation.timeAtX(trailingExtent);
        _springSimulation = _overscrollSimulation(
          trailingExtent,
          min(_frictionSimulation.dx(_springTime), maxSpringTransferVelocity),
        );
        assert(_springTime.isFinite);
      } else if (velocity < 0.0 && finalX < leadingExtent) {
        _springTime = _frictionSimulation.timeAtX(leadingExtent);
        _springSimulation = _underscrollSimulation(
          leadingExtent,
          min(_frictionSimulation.dx(_springTime), maxSpringTransferVelocity),
        );
        assert(_springTime.isFinite);
      } else {
        _springTime = double.infinity;
      }
    }
  }

  static const double maxSpringTransferVelocity = 5000.0;

  final double leadingExtent;

  final double trailingExtent;

  final SpringDescription spring;

  late FrictionSimulation _frictionSimulation;
  late Simulation _springSimulation;
  late double _springTime;
  double _timeOffset = 0.0;

  Simulation _underscrollSimulation(double x, double dx) {
    return ScrollSpringSimulation(spring, x, leadingExtent, dx);
  }

  Simulation _overscrollSimulation(double x, double dx) {
    return ScrollSpringSimulation(spring, x, trailingExtent, dx);
  }

  Simulation _simulation(double time) {
    final Simulation simulation;
    if (time > _springTime) {
      _timeOffset = _springTime.isFinite ? _springTime : 0.0;
      simulation = _springSimulation;
    } else {
      _timeOffset = 0.0;
      simulation = _frictionSimulation;
    }
    return simulation..tolerance = tolerance;
  }

  @override
  double x(double time) => _simulation(time).x(time - _timeOffset);

  @override
  double dx(double time) => _simulation(time).dx(time - _timeOffset);

  @override
  bool isDone(double time) => _simulation(time).isDone(time - _timeOffset);

  @override
  String toString() {
    return '${objectRuntimeType(this, '_ModifiedBouncingScrollSimulation')}(leadingExtent: $leadingExtent, trailingExtent: $trailingExtent)';
  }
}

class _ModifiedBouncingScrollPhysics extends BouncingScrollPhysics {
  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final Tolerance tolerance = this.tolerance;
    if (velocity.abs() >= tolerance.velocity || position.outOfRange) {
      return _ModifiedBouncingScrollSimulation(
        spring: spring,
        position: position.pixels,
        velocity: velocity,
        leadingExtent: position.minScrollExtent,
        trailingExtent: position.maxScrollExtent,
        tolerance: tolerance,
      );
    }
    return null;
  }

	@override
	String toString() => '_ModifiedBouncingScrollPhysics()';
}

class Captcha4ChanCustom extends StatefulWidget {
	final ImageboardSite site;
	final Chan4CustomCaptchaRequest request;
	final ValueChanged<Chan4CustomCaptchaSolution> onCaptchaSolved;

	const Captcha4ChanCustom({
		required this.site,
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
	bool cloudflare;

	Captcha4ChanCustomChallenge({
		required this.challenge,
		required this.expiresAt,
		required this.foregroundImage,
		required this.backgroundImage,
		required this.cloudflare
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

int numLetters = 6;

class _Captcha4ChanCustomState extends State<Captcha4ChanCustom> {
	String? errorMessage;
	DateTime? tryAgainAt;
	Captcha4ChanCustomChallenge? challenge;
	int backgroundSlide = 0;
	late final FocusNode _solutionNode;
	late final TextEditingController _solutionController;
	late final List<FixedExtentScrollController> _letterPickerControllers;
	List<double> _guessConfidences = List.generate(6, (i) => 1.0);
	String _lastGuessText = "";
	bool _greyOutPickers = true;
	final _pickerKeys = List.generate(6, (i) => GlobalKey());
	double _guessingProgress = 0.0;
	CancelableOperation<Chan4CustomCaptchaGuess>? _guessInProgress;

	Future<void> _animateGuess() async {
		setState(() {
			_guessingProgress = 0.0;
			_greyOutPickers = true;
		});
		try {
			_guessInProgress?.cancel();
			_guessInProgress = guess(
				await _screenshotImage(),
				numLetters: numLetters,
				onProgress: (progress) {
					setState(() {
						_guessingProgress = progress;
					});
				}
			);
			final bestGuess = await _guessInProgress!.value;
			numLetters = bestGuess.numLetters;
			setState(() {});
			final selection = _solutionController.selection;
			_solutionController.text = bestGuess.guess;
			_solutionController.selection = TextSelection(
				baseOffset: min(numLetters - 1, selection.baseOffset),
				extentOffset: min(numLetters, selection.extentOffset)
			);
			_lastGuessText = bestGuess.guess;
			_guessConfidences = bestGuess.confidences;
		}
		catch (e, st) {
			print(e);
			print(st);
		}
		if (mounted && context.read<EffectiveSettings>().supportMouse.value) {
			_solutionController.selection = const TextSelection(baseOffset: 0, extentOffset: 1);
			_solutionNode.requestFocus();
		}
		setState(() {
			_greyOutPickers = false;
		});
	}

	Future<Captcha4ChanCustomChallenge> _requestChallenge() async {
		final challengeResponse = await widget.site.client.getUri(widget.request.challengeUrl);
		if (challengeResponse.statusCode != 200) {
			throw Captcha4ChanCustomException('Got status code ${challengeResponse.statusCode}');
		}
		dynamic data = challengeResponse.data;
		if (data is String) {
			final match = RegExp(r'window.parent.postMessage\(({.*\}),').firstMatch(data);
			if (match == null) {
				throw Captcha4ChanCustomException('Response doesn\'t match, 4chan must have changed their captcha system');
			}
			data = jsonDecode(match.group(1)!)['twister'];
		}
		if (data['cd'] != null) {
			tryAgainAt = DateTime.now().add(Duration(seconds: data['cd'].toInt()));
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
			expiresAt: DateTime.now().add(Duration(seconds: data['ttl'].toInt())),
			foregroundImage: foregroundImage,
			backgroundImage: backgroundImage,
			cloudflare: challengeResponse.cloudflare
		);
	}

	void _tryRequestChallenge() async {
		final settings = context.read<EffectiveSettings>();
		try {
			setState(() {
				errorMessage = null;
				tryAgainAt = null;
				challenge?.dispose();
				challenge = null;
			});
			challenge = await _requestChallenge();
			if (!mounted) return;
			if (challenge!.foregroundImage == null && challenge!.backgroundImage == null) {
				if (challenge!.challenge == 'noop') {
					widget.onCaptchaSolved(Chan4CustomCaptchaSolution(
						challenge: 'noop',
						response: '',
						expiresAt: challenge!.expiresAt,
						alignedImage: null,
						cloudflare: challenge!.cloudflare
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
				if (!mounted) return;
			}
			if (settings.useNewCaptchaForm) {
				_solutionController.text = "00000";
				setState(() {});
				await _animateGuess();
			}
			else {
				setState(() {});
				_solutionNode.requestFocus();
			}
		}
		catch(e, st) {
			print(e);
			print(st);
			if (!mounted) return;
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

	String _previousText = "000000";
	TextSelection _previousSelection = const TextSelection(baseOffset: 0, extentOffset: 1);
	bool _modifyingFromPicker = false;

	void _onSolutionControllerUpdate() {
		TextSelection selection = _solutionController.selection;
		final newText = _solutionController.text;
		if (_solutionController.text.length != numLetters) {
			if (_previousText.length == numLetters && _solutionController.text.length == numLetters - 1 && selection.isCollapsed && selection.isValid) {
				final index = selection.baseOffset;
				if ((_previousText.substring(0, index) == _solutionController.text.substring(0, index)) &&
						(_previousText.substring(index + 1) == _solutionController.text.substring(index))) {
					// backspace was pressed
					_solutionController.text = _previousText;
					if (index > 0) {
						_solutionController.selection = TextSelection(baseOffset: index - 1, extentOffset: index);
					}
					else {
						_solutionController.selection = TextSelection(baseOffset: numLetters - 1, extentOffset: numLetters);
					}
					selection = _solutionController.selection;
				}
			}
			else {
				_solutionController.text = _solutionController.text.substring(0, min(numLetters, _solutionController.text.length)).padRight(numLetters, ' ');
			}
		}
		for (int i = 0; i < numLetters; i++) {
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
		int start = selection.baseOffset % numLetters;
		if (selection.isCollapsed) {
			if (_previousSelection.baseOffset == selection.baseOffset && _previousText == newText) {
				// Left-arrow was pressed
				start = (start - 1) % numLetters;
			}
			_solutionController.selection = TextSelection(baseOffset: start, extentOffset: start + 1);
		}
		if (!_modifyingFromPicker && _previousText != _solutionController.text) {
			for (int i = 0; i < numLetters; i++) {
				if (i >= _previousText.length || _previousText[i] != _solutionController.text[i]) {
					if (i < _guessConfidences.length ) {
						_guessConfidences[i] = 1;
					}
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
			alignedImage: await _screenshotImage(),
			cloudflare: challenge!.cloudflare
		));
	}

	@override
	void initState() {
		super.initState();
	_solutionNode = FocusNode();
	_solutionController = TextEditingController();
	_letterPickerControllers = List.generate(6, (i) => FixedExtentScrollController());
		if (context.read<EffectiveSettings>().useNewCaptchaForm) {
			_solutionController.text = "000000";
			_solutionController.selection = const TextSelection(baseOffset: 0, extentOffset: 1);
			_solutionController.addListener(_onSolutionControllerUpdate);
		}
		else {
			_greyOutPickers = false;
		}
		_tryRequestChallenge();
	}

	Widget _cooldownedRetryButton(BuildContext context) {
		if (tryAgainAt != null) {
			return TimedRebuilder(
				enabled: true,
				interval: const Duration(seconds: 1),
				builder: (context) {
					final seconds = tryAgainAt!.difference(DateTime.now()).inSeconds;
					return CupertinoButton(
						onPressed: seconds > 0 ? null : _tryRequestChallenge,
						child: FittedBox(
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
							)
						)
					);
				}
			);
		}
		return CupertinoButton(
			onPressed: _tryRequestChallenge,
			child: const Icon(CupertinoIcons.refresh)
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
										child: FittedBox(
											child: Row(
												mainAxisAlignment: MainAxisAlignment.end,
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
											onSubmitted: _submit
										)
									)
								)
							),
							if (context.read<EffectiveSettings>().useNewCaptchaForm) ...[
								CupertinoSegmentedControl<int>(
									children: const {
										5: Padding(
											padding: EdgeInsets.all(8),
											child: Text('5 letters')
										),
										6: Padding(
											padding: EdgeInsets.all(8),
											child: Text('6 letters')
										)
									},
									groupValue: numLetters,
									onValueChanged: (x) {
										if (x != numLetters) {
											setState(() {
												numLetters = x;
											});
											_animateGuess();
										}
									}
								),
								IgnorePointer(
									ignoring: _greyOutPickers,
									child: Opacity(
										opacity: _greyOutPickers ? 0.5 : 1.0,
										child: SizedBox(
											height: 200,
											child: LayoutBuilder(
												builder: (context, constraints) => ReorderableListView(
													scrollDirection: Axis.horizontal,
													physics: const NeverScrollableScrollPhysics(),
													onReorder: (a, b) {
														if (a < b) {
															for (int i = a; i < b - 1; i++) {
																final tmp = _letterPickerControllers[i].selectedItem;
																_letterPickerControllers[i].jumpToItem(_letterPickerControllers[i + 1].selectedItem);
																_letterPickerControllers[i + 1].jumpToItem(tmp);
															}
														}
														else {
															for (int i = a; i > b; i--) {
																final tmp = _letterPickerControllers[i].selectedItem;
																_letterPickerControllers[i].jumpToItem(_letterPickerControllers[i - 1].selectedItem);
																_letterPickerControllers[i - 1].jumpToItem(tmp);
															}
														}
													},
													proxyDecorator: (child, index, animation) => AnimatedBuilder(
														animation: animation,
														builder: (BuildContext context, Widget? child) {
															final double animValue = Curves.easeInOut.transform(animation.value);
															return ColorFiltered(
																colorFilter: ColorFilter.mode(
																	CupertinoTheme.of(context).primaryColor.withOpacity(0.2 * animValue),
																	BlendMode.srcOver
																),
																child: child
															);
														},
														child: child,
													),
													children: [
														for (int i = 0; i < numLetters; i++) ...[
															ReorderableDelayedDragStartListener(
																index: i,
																key: ValueKey(i),
																child: SizedBox(
																	height: 200,
																	width: min(constraints.maxWidth, 500) / numLetters,
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
																				child: ScrollConfiguration(
																					behavior: ScrollConfiguration.of(context).copyWith(
																						physics: _ModifiedBouncingScrollPhysics()
																					),
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
																											end: const Color.fromARGB(255, 241, 190, 19)).transform(1 - _guessConfidences[min(_guessConfidences.length - 1, i)]
																										)!
																									)
																								)
																							)
																						),
																						itemExtent: 50,
																						onSelectedItemChanged: null
																					)
																				)
																			),
																			Column(
																				crossAxisAlignment: CrossAxisAlignment.stretch,
																				children: [
																					GestureDetector(
																						behavior: HitTestBehavior.translucent,
																						onTap: () {
																							_letterPickerControllers[i].animateToItem(
																								_letterPickerControllers[i].selectedItem - 1,
																								duration: const Duration(milliseconds: 100),
																								curve: Curves.ease
																							);
																						},
																						child:const SizedBox(height: 75)
																					),
																					GestureDetector(
																						behavior: HitTestBehavior.translucent,
																						onTap: () {
																							_solutionController.selection = TextSelection(baseOffset: i, extentOffset: i + 1);
																							_solutionNode.requestFocus();
																						},
																						child: const SizedBox(height: 50)
																					),
																					GestureDetector(
																						behavior: HitTestBehavior.translucent,
																						onTap: () {
																							_letterPickerControllers[i].animateToItem(
																								_letterPickerControllers[i].selectedItem + 1,
																								duration: const Duration(milliseconds: 100),
																								curve: Curves.ease
																							);
																						},
																						child: const SizedBox(height: 75)
																					)
																				]
																			)
																		]
																	)
																)
															)
														]
													]
												)
											)
										)
									)
								),
								Stack(
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
											onPressed: _greyOutPickers ? null : () {
												_submit(_solutionController.text);
											},
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
											)
										)
									]
								)
							]
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
		_guessInProgress?.cancel();
	}
}
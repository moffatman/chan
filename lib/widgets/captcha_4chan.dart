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
import 'package:dio/dio.dart';
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
    final Tolerance tolerance = toleranceFor(position);
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

typedef _PickerStuff = ({GlobalKey key, UniqueKey wrapperKey, FixedExtentScrollController controller});

class _Captcha4ChanCustomState extends State<Captcha4ChanCustom> {
	String? errorMessage;
	DateTime? tryAgainAt;
	Captcha4ChanCustomChallenge? challenge;
	int backgroundSlide = 0;
	late final FocusNode _solutionNode;
	late final TextEditingController _solutionController;
	List<double> _guessConfidences = List.generate(6, (i) => 1.0);
	Chan4CustomCaptchaGuesses? _lastGuesses;
	late Chan4CustomCaptchaGuess _lastGuess;
	bool _greyOutPickers = true;
	final Map<Chan4CustomCaptchaLetterKey, _PickerStuff> _pickerStuff = {};
	final List<_PickerStuff> _orphanPickerStuff = [];
	double _guessingProgress = 0.0;
	CancelableOperation<Chan4CustomCaptchaGuesses>? _guessInProgress;
	bool _offerGuess = false;

	int get numLetters => context.read<EffectiveSettings>().captcha4ChanCustomNumLetters;
	set numLetters(int setting) => context.read<EffectiveSettings>().captcha4ChanCustomNumLetters = setting;

	Future<void> _animateGuess() async {
		setState(() {
			_guessingProgress = 0.0;
			_greyOutPickers = true;
			_offerGuess = false;
		});
		try {
			_guessInProgress?.cancel();
			_guessInProgress = guess(
				await _screenshotImage(),
				maxNumLetters: 6,
				onProgress: (progress) {
					setState(() {
						_guessingProgress = progress;
					});
				}
			);
			_lastGuesses = await _guessInProgress!.value;
			numLetters = _lastGuesses!.likelyNumLetters;
			final selection = _solutionController.selection;
			final lastResolvedPickerStuff = {
				for (int i = 0; i < _pickerStuff.length; i++)
					i: _getPickerStuffForWidgetIndex(i)
			};
			_pickerStuff.clear();
			final newGuess = _lastGuesses!.forNumLetters(numLetters);
			_lastGuess = newGuess;
			// We want widget-indexes to match up to same pickerStuff, not to keys
			for (int i = 0; i < numLetters; i++) {
				final key = newGuess.keys[i];
				final previousPickerStuffInThisSlot = lastResolvedPickerStuff.remove(i);
				if (previousPickerStuffInThisSlot != null) {
					_pickerStuff[key] = previousPickerStuffInThisSlot;
				}
			}
			for (final orphan in lastResolvedPickerStuff.values) {
				_orphanPickerStuff.add(orphan);
			}
			_solutionController.text = newGuess.guess;
			_solutionController.selection = TextSelection(
				baseOffset: min(numLetters - 1, selection.baseOffset),
				extentOffset: min(numLetters, selection.extentOffset)
			);
			_guessConfidences = newGuess.confidences.toList();
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

	_PickerStuff _getPickerStuffForWidgetIndex(int i) {
		return _pickerStuff.putIfAbsent(_lastGuess.keys[i], () => _orphanPickerStuff.tryRemoveFirst() ?? (
			key: GlobalKey(debugLabel: '_Captcha4ChanCustomState._pickerStuff.key'),
			wrapperKey: UniqueKey(),
			controller: FixedExtentScrollController()
		));
	}

	Future<Captcha4ChanCustomChallenge> _requestChallenge() async {
		final challengeResponse = await widget.site.client.getUri(widget.request.challengeUrl, options: Options(
			headers: widget.request.challengeHeaders
		));
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
			tryAgainAt = DateTime.now().add(Duration(seconds: data['cd'].toInt() + 2));
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
			if (challenge!.backgroundImage != null) {
				await _alignImage();
				if (!mounted) return;
			}
			if (settings.useNewCaptchaForm) {
				await _animateGuess();
			}
			else {
				backgroundSlide = 0;
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
		TextSelection newSelection = _solutionController.selection;
		String newText = _solutionController.text;
		if (newText.length != numLetters) {
			if (_previousText.length == numLetters && newText.length == numLetters - 1 && newSelection.isCollapsed && newSelection.isValid) {
				final index = newSelection.baseOffset;
				if ((_previousText.substring(0, index) == newText.substring(0, index)) &&
						(_previousText.substring(index + 1) == newText.substring(index))) {
					// backspace was pressed
					newText = _previousText;
					if (index > 0) {
						newSelection = TextSelection(baseOffset: index - 1, extentOffset: index);
					}
					else {
						newSelection = TextSelection(baseOffset: numLetters - 1, extentOffset: numLetters);
					}
				}
			}
			else {
				newText = newText.substring(0, min(numLetters, newText.length)).padRight(numLetters, ' ');
			}
		}
		final spaceLocations = <int>[];
		for (int i = 0; i < numLetters; i++) {
			final char = newText[i].toUpperCase();
			if (!captchaLetters.contains(char)) {
				const remap = {
					'B': '8',
					'F': 'P',
					'U': 'V',
					'Z': '2',
					'O': '0'
				};
				if (remap[char] != null) {
					newText = newText.replaceRange(i, i + 1, remap[char]!);
				}
				else {
					newText = _previousText;
					newSelection = TextSelection(baseOffset: i, extentOffset: i + 1);
					if (char == ' ') {
						spaceLocations.add(i);
					}
				}
			}
		}
		if (spaceLocations.length == 1) {
			final start = (spaceLocations.single + 1) % numLetters;
			newSelection = TextSelection(baseOffset: start, extentOffset: start + 1);
		}
		int start = newSelection.baseOffset % numLetters;
		if (newSelection.isCollapsed) {
			if (_previousSelection.baseOffset == newSelection.baseOffset && _previousText == newText) {
				// Left-arrow was pressed
				start = (start - 1) % numLetters;
			}
			newSelection = TextSelection(baseOffset: start, extentOffset: start + 1);
		}
		if (!_modifyingFromPicker && _previousText != newText) {
			for (int i = 0; i < numLetters; i++) {
				if (i >= _previousText.length || _previousText[i] != newText[i] || _previousText.length != newText.length) {
					if (i < _guessConfidences.length && newText[i] != _lastGuess.guess[i]) {
						_guessConfidences[i] = 1;
					}
					WidgetsBinding.instance.addPostFrameCallback((_) => _getPickerStuffForWidgetIndex(i).controller.animateToItem(captchaLetters.indexOf(newText[i].toUpperCase()), duration: const Duration(milliseconds: 250), curve: Curves.elasticIn));
				}
			}
		}
		_previousText = _solutionController.text;
		_previousSelection = _solutionController.selection;
		_solutionController.value = _solutionController.value.copyWith(
			text: newText,
			selection: newSelection,
			composing: TextRange.empty
		);
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
		_lastGuess = Chan4CustomCaptchaGuess.dummy('0' * numLetters);
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
							fit: BoxFit.scaleDown,
							child: Row(
								mainAxisSize: MainAxisSize.min,
								children: [
									const Icon(CupertinoIcons.refresh),
									const SizedBox(width: 16),
									SizedBox(
										width: 32,
										child: seconds > 0 ? Text('$seconds') : const SizedBox.shrink()
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
			int minGuessConfidenceIndex = 0;
			if (numLetters == 5) {
				// Only emphasize worst letter on 6-captcha form
				minGuessConfidenceIndex = -1;
			}
			else {
				for (int i = 1; i < _guessConfidences.length; i++) {
					if (_guessConfidences[i] < _guessConfidences[minGuessConfidenceIndex]) {
						minGuessConfidenceIndex = i;
					}
				}
			}
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
									child: GestureDetector(
										onDoubleTap: () async {
											if (challenge?.backgroundImage != null) {
												await _alignImage();
											}
											await _animateGuess();
										},
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
															if (_solutionController.text.toUpperCase() == _lastGuess.guess.toUpperCase()) {
																_animateGuess();
															}
															else {
																setState(() {
																	_offerGuess = true;
																});
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
											fit: BoxFit.scaleDown,
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
													final controller = _getPickerStuffForWidgetIndex(_solutionController.selection.baseOffset).controller;
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
											enableIMEPersonalizedLearning: false,
											keyboardType: TextInputType.visiblePassword,
											controller: _solutionController,
											autocorrect: false,
											placeholder: 'Captcha text',
											onSubmitted: _submit
										)
									)
								)
							),
							if (context.read<EffectiveSettings>().useNewCaptchaForm) ...[
								Row(
									mainAxisAlignment: MainAxisAlignment.center,
									children: [
										const SizedBox(width: 40),
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
													numLetters = x;
													final selection = _solutionController.selection;
													final oldGuess = _lastGuess;
													_lastGuess = _lastGuesses!.forNumLetters(numLetters);
													String newGuessText = _lastGuess.guess;
													_guessConfidences = _lastGuess.confidences.toList();
													// We want keys to match up to same pickerStuff, not to widget-indexes
													final tmp = _pickerStuff.keys.toSet();
													for (final id in _lastGuess.keys.asMap().entries) {
														if (_pickerStuff.containsKey(id.value)) {
															// Same key in both guesses
															tmp.remove(id.value);
															final indexInOldGuess = oldGuess.keys.indexOf(id.value);
															if (indexInOldGuess != -1) {
																// Copy the old letter, in case the user modified it
																newGuessText = newGuessText.replaceRange(id.key, id.key + 1, _solutionController.text[indexInOldGuess]);
															}
														}
													}
													for (final orphanKey in tmp) {
														// Old letter slot not in new guess
														final orphan = _pickerStuff.remove(orphanKey);
														if (orphan != null) {
															_orphanPickerStuff.add(orphan);
														}
													}
													_solutionController.text = newGuessText;
													_solutionController.selection = TextSelection(
														baseOffset: min(numLetters - 1, selection.baseOffset),
														extentOffset: min(numLetters, selection.extentOffset)
													);
													setState(() {});
												}
											}
										),
										SizedBox(
											width: 40,
											child: _offerGuess ? CupertinoButton(
												padding: EdgeInsets.zero,
												minSize: 0,
												onPressed: _animateGuess,
												child: const Icon(CupertinoIcons.goforward)
											) : null
										)
									]
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
																final tmp = _getPickerStuffForWidgetIndex(i).controller.selectedItem;
																_getPickerStuffForWidgetIndex(i).controller.jumpToItem(_getPickerStuffForWidgetIndex(i + 1).controller.selectedItem);
																_getPickerStuffForWidgetIndex(i + 1).controller.jumpToItem(tmp);
															}
														}
														else {
															for (int i = a; i > b; i--) {
																final tmp = _getPickerStuffForWidgetIndex(i).controller.selectedItem;
																_getPickerStuffForWidgetIndex(i).controller.jumpToItem(_getPickerStuffForWidgetIndex(i - 1).controller.selectedItem);
																_getPickerStuffForWidgetIndex(i - 1).controller.jumpToItem(tmp);
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
																key: _getPickerStuffForWidgetIndex(i).wrapperKey,
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
																						final newLetter = captchaLetters[(notification.metrics as FixedExtentMetrics).itemIndex];
																						_solutionController.value = TextEditingValue(
																							text: _solutionController.text.replaceRange(i, i + 1, newLetter),
																							selection: _solutionController.selection,
																							composing: TextRange.empty
																						);
																						if (_guessConfidences[i] != 1 && _lastGuess.guess.substring(i, i + 1) != newLetter) {
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
																						key: _getPickerStuffForWidgetIndex(i).key,
																						scrollController: _getPickerStuffForWidgetIndex(i).controller,
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
																							key: ValueKey(captchaLetters[l]),
																							padding: const EdgeInsets.all(6),
																							child: Center(
																								child: Text(captchaLetters[l],
																									style: TextStyle(
																										fontSize: 34,
																										color:  ColorTween(
																											begin: CupertinoTheme.of(context).primaryColor,
																											end: const Color.fromARGB(255, 241, 190, 19)).transform(0.4 - 0.4*_guessConfidences[min(_guessConfidences.length - 1, i)] + (i == minGuessConfidenceIndex ? 0.6 : 0)
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
																							_getPickerStuffForWidgetIndex(i).controller.animateToItem(
																								_getPickerStuffForWidgetIndex(i).controller.selectedItem - 1,
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
																							setState(() {});
																						},
																						child: const SizedBox(height: 50)
																					),
																					GestureDetector(
																						behavior: HitTestBehavior.translucent,
																						onTap: () {
																							_getPickerStuffForWidgetIndex(i).controller.animateToItem(
																								_getPickerStuffForWidgetIndex(i).controller.selectedItem + 1,
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
		for (final stuff in _pickerStuff.values.followedBy(_orphanPickerStuff)) {
			stuff.controller.dispose();
		}
		_guessInProgress?.cancel();
	}
}
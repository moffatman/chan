import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:normal/normal.dart';
import 'package:pool/pool.dart';

part 'captcha_4chan.data.dart';

class Chan4CustomCaptchaGuess {
	final String guess;
	final List<List<String>> alternatives;
	final double confidence;
	final List<double> confidences;
	const Chan4CustomCaptchaGuess({
		required this.guess,
		required this.alternatives,
		required this.confidence,
		required this.confidences
	});

	@override
	String toString() => '_Chan4CustomCaptchaGuess(guess: $guess, alternatives: $alternatives, confidence: $confidence)';
}

int _floodFillBuffer({
	required Uint8List buffer,
	required int width,
	required int height,
	required int seedX,
	required int seedY,
	required int fillColor
}) {
	final int _startColor = buffer[(width * seedY) + seedX];
	final List<bool> _pixelsChecked = List<bool>.filled(width * height, false);
	final Queue<_FloodFillRange> _ranges = Queue<_FloodFillRange>();
	int pixelsChanged = 0;

	bool _checkPixel(int x, int y) {
    return buffer[(y * width) + x] == _startColor;
  }

	void _linearFill(int x, int y) {
    int lFillLoc = x;
    int pxIdx = (width * y) + x;
    while (true) {
			buffer[(y * width) + x] = fillColor;
			pixelsChanged++;
      _pixelsChecked[pxIdx] = true;
      lFillLoc--;
      pxIdx--;
      if (lFillLoc < 0 ||
          (_pixelsChecked[pxIdx]) ||
          !_checkPixel(lFillLoc, y)) {
        break;
      }
    }
    lFillLoc++;
    int rFillLoc = x;
    pxIdx = (width * y) + x;
    while (true) {
      buffer[(y * width) + x] = fillColor;
			pixelsChanged++;
      _pixelsChecked[pxIdx] = true;
      rFillLoc++;
      pxIdx++;
      if (rFillLoc >= width ||
          _pixelsChecked[pxIdx] ||
          !_checkPixel(rFillLoc, y)) {
        break;
      }
    }
    rFillLoc--;
    _FloodFillRange r = _FloodFillRange(lFillLoc, rFillLoc, y);
    _ranges.add(r);
  }

	_linearFill(seedX, seedY);
	_FloodFillRange range;
	while (_ranges.isNotEmpty) {
		range = _ranges.removeFirst();
		int downPxIdx = (width * (range.y + 1)) + range.startX;
		int upPxIdx = (width * (range.y - 1)) + range.startX;
		int upY = range.y - 1;
		int downY = range.y + 1;
		for (int i = range.startX; i <= range.endX; i++) {
			if (range.y > 0 && (!_pixelsChecked[upPxIdx]) && _checkPixel(i, upY)) {
				_linearFill(i, upY);
			}
			if (range.y < (height - 1) &&
					(!_pixelsChecked[downPxIdx]) &&
					_checkPixel(i, downY)) {
				_linearFill(i, downY);
			}
			downPxIdx++;
			upPxIdx++;
		}
	}
	return pixelsChanged;
}

class _FloodFillRange {
  int startX;
  int endX;
  int y;
  _FloodFillRange(this.startX, this.endX, this.y);
}

Future<Uint8List> _getRedChannelOnly(ByteData rgbaData) async {
	final rgba = rgbaData.buffer.asUint32List();
	return Uint8List.fromList(rgba.map((p) => p & 0xFF).toList());
}

class _LetterImage {
	final int width;
	final int height;
	final double adjustment;
	final Uint8List bytes;
	_LetterImage({
		required this.width,
		required this.height,
		required this.adjustment,
		required String data
	}) : bytes = Uint8List.fromList(ZLibCodec().decode(base64Decode(data)));

	@override
	String toString() => '_LetterImage(width: $width, height: $height)';
}

class _LetterScore {
	final double score;
	final String letter;
	final int y;
	final int x;
	final int letterImageWidth;
	const _LetterScore({
		required this.score,
		required this.letter,
		required this.y,
		required this.x,
		required this.letterImageWidth
	});

	@override
	String toString() => '_LetterScore(letter: $letter, score: $score, x: $x, y: $y, letterImageWidth: $letterImageWidth)';
}

class _ScoreArrayForLetterParam {
	final String letter;
	final Uint8List captcha;
	final int width;
	final int height;

	const _ScoreArrayForLetterParam({
		required this.letter,
		required this.captcha,
		required this.width,
		required this.height
	});
}

List<_LetterScore> _scoreArrayForLetter(_ScoreArrayForLetterParam param) {
	final scores = <_LetterScore>[];
	for (final subimage in captchaLetterImages[param.letter]!) {
		final maxY = (param.height * 0.9).toInt() - subimage.height;
		final maxX = param.width - subimage.width;
		for (int y = param.height ~/ 5; y < maxY; y++) {
			for (int x = 0; x < maxX; x++) {
				double score = 0;
				for (int y_ = 0; y_ < subimage.height; y_++) {
					for (int x_ = 0; x_ < subimage.width; x_++) {
						if (subimage.bytes[(y_ * subimage.width) + x_] == 0x00) {
							if (param.captcha[((y + y_) * param.width) + x + x_] == 0xFF) {
								score += 2;
							}
						}
						else if (param.captcha[((y + y_) * param.width) + x + x_] == 0x00) {
							score += 1;
						}
					}
				}
				score /= (subimage.width / 10) * (subimage.height / 10);
				score += subimage.adjustment;
				scores.add(_LetterScore(
					score: score,
					letterImageWidth: subimage.width,
					x: x,
					y: y,
					letter: param.letter
				));
			}
		}
	}
	return scores;
}

const _preprocessProportion = 0.3;
const _scoreArrayProportion = 0.55;

void _guess(_GuessParam param) async {
	Uint8List captcha = await _getRedChannelOnly(param.rgbaData);
	final random = Random();
	final width = param.width;
	final height = param.height;
	// Threshold
	for (int y = 0; y < height; y++) {
		for (int x = 0; x < width; x++) {
			if (captcha[(y * width) + x] > 127) {
				captcha[(y * width) + x] = 255;
			}
			else {
				captcha[(y * width) + x] = 0;
			}
		}
	}
	// Preprocess
	for (int i = 0; i < 10000; i++) {
		final seedX = random.nextInt(width);
		final seedY = random.nextInt(height);
		if (captcha[(seedY * width) + seedX] == 255) {
			continue;
		}
		final filled = Uint8List.fromList(captcha);
		final count = _floodFillBuffer(
			buffer: filled,
			seedX: seedX,
			seedY: seedY,
			width: width,
			height: height,
			fillColor: 255
		);
		if ((count / captcha.length) < 0.02) {
			captcha = filled;
		}
	}
	param.sendPort.send(_preprocessProportion);
	// Create score array
	final pool = Pool(Platform.numberOfProcessors);
	final letterFutures = <Future<List<_LetterScore>>>[];
	int lettersDone = 0;
	for (final letter in captchaLetters) {
		letterFutures.add(pool.withResource(() async {
			final data = await compute(_scoreArrayForLetter, _ScoreArrayForLetterParam(
				captcha: captcha,
				letter: letter,
				width: width,
				height: height
			));
			lettersDone++;
			param.sendPort.send(_preprocessProportion + (_scoreArrayProportion * (lettersDone / captchaLetters.length)));
			return data;
		}));
	}
	final scores = (await Future.wait(letterFutures)).expand((x) => x).toList();
	// Pick best set of letters
	List<_LetterScore> __guess({
		List<_LetterScore> deadAnswers = const []
	}) {
		final answers = <_LetterScore>[];
		final deadXes = List.filled(width, 0);
		final xAdjustments = <int, List<double>>{};
		final possibleSubimageWidths = captchaLetterImages.values.expand((x) => x).map((x) => x.width).toSet().toList();
		for (final possibleWidth in possibleSubimageWidths) {
			xAdjustments[possibleWidth] = List.filled(width, 0);
		}
		final deadLetters = List<Set<String>>.generate(width, (i) => {});
		for (final deadAnswer in deadAnswers) {
			for (int x = max(deadAnswer.x - 14, 0); x < min(width, deadAnswer.x + 15); x++) {
				deadLetters[x].add(deadAnswer.letter);
			}
		}
		for (int i = 0; i < 5; i++) {
			_LetterScore bestScore = scores.first;
			for (final score in scores) {
				if (deadLetters[score.x].contains(score.letter)) {
					continue;
				}
				if ((score.score + (i > 0 ? xAdjustments[score.letterImageWidth]![score.x] : 0)) < bestScore.score) {
					bestScore = score;
				}
			}
			final subimageEndX = bestScore.x + bestScore.letterImageWidth;
			for (int x = bestScore.x; x < subimageEndX; x++) {
				deadXes[x] = 1;
			}
			for (final possibleWidth in possibleSubimageWidths) {
				for (int x = max(bestScore.x - possibleWidth, 0); x < subimageEndX; x++) {
					xAdjustments[possibleWidth]![x] = 0;
					for (int x_ = x; x_ < min(width, x + possibleWidth); x_++) {
						xAdjustments[possibleWidth]![x] += deadXes[x_] * 3.57;
					}
				}
			}
			answers.add(bestScore);
		}
		return answers;
	}
	final answersBest = __guess();
	answersBest.sort((a, b) => a.x - b.x);
	/*final answers2 = __guess(deadAnswers: answersBest);
	final answers3 = __guess(deadAnswers: answersBest.followedBy(answers2).toList());
	final alternativeAnswers = answers2.followedBy(answers3).toList();
	final alternatives = answersBest.map((answer) {
		final ret = <String>[];
		for (final alternative in alternativeAnswers) {
			if ((alternative.x - answer.x).abs() < 15) {
				ret.add(alternative.letter);
			}
		}
		return ret;
	}).toList();*/
	final maxScore = answersBest.map((x) => x.score).reduce(max);
	param.sendPort.send(1.0);
	param.sendPort.send(Chan4CustomCaptchaGuess(
		guess: answersBest.map((x) => x.letter).join(''),
		//alternatives: alternatives,
		alternatives: [[], [], [], [], []],
		confidence: (1 - Normal.cdf(
			maxScore,
			mean: 33.04293065376995,
			variance: 5.498314092366682
		)) * (1 - Normal.cdf(
			maxScore,
			mean: 39.635586723948464,
			variance: 7.1408268142981015
		)),
		confidences: answersBest.map((x) => (1 - Normal.cdf(
			x.score,
			mean: 23.81770143538823,
			variance: 7.07775508044155
		)) * (1 - Normal.cdf(
			x.score,
			mean: 33.94387053066409,
			variance: 9.811289141395186
		))).toList()
	));
}

class _GuessParam {
	final ByteData rgbaData;
	final int width;
	final int height;
	final SendPort sendPort;
	const _GuessParam({
		required this.rgbaData,
		required this.width,
		required this.height,
		required this.sendPort
	});
}

Future<Chan4CustomCaptchaGuess> guess(ui.Image image, {
	ValueChanged<double>? onProgress
}) async {
	final receivePort = ReceivePort();
	await Isolate.spawn(_guess, _GuessParam(
		rgbaData: (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!,
		width: image.width,
		height: image.height,
		sendPort: receivePort.sendPort
	));
	await for (final datum in receivePort) {
		if (datum is double) {
			onProgress?.call(datum);
		}
		else if (datum is Chan4CustomCaptchaGuess) {
			return datum;
		}
	}
	throw Exception('Computation failed');
}
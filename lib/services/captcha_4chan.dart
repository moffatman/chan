import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:async/async.dart';
import 'package:chan/services/util.dart';
import 'package:flutter/foundation.dart';
import 'package:normal/normal.dart';
import 'package:pool/pool.dart';

part 'captcha_4chan.data.dart';

class Chan4CustomCaptchaGuess {
	final String guess;
	final int numLetters;
	final List<List<String>> alternatives;
	final double confidence;
	final List<double> confidences;
	const Chan4CustomCaptchaGuess({
		required this.guess,
		required this.numLetters,
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
	final int startColor = buffer[(width * seedY) + seedX];
	final List<bool> pixelsChecked = List<bool>.filled(width * height, false);
	final Queue<_FloodFillRange> ranges = Queue<_FloodFillRange>();
	int pixelsChanged = 0;

	bool checkPixel(int x, int y) {
    return buffer[(y * width) + x] == startColor;
  }

	void linearFill(int x, int y) {
    int lFillLoc = x;
    int pxIdx = (width * y) + x;
    while (true) {
			buffer[(y * width) + x] = fillColor;
			pixelsChanged++;
      pixelsChecked[pxIdx] = true;
      lFillLoc--;
      pxIdx--;
      if (lFillLoc < 0 ||
          (pixelsChecked[pxIdx]) ||
          !checkPixel(lFillLoc, y)) {
        break;
      }
    }
    lFillLoc++;
    int rFillLoc = x;
    pxIdx = (width * y) + x;
    while (true) {
      buffer[(y * width) + x] = fillColor;
			pixelsChanged++;
      pixelsChecked[pxIdx] = true;
      rFillLoc++;
      pxIdx++;
      if (rFillLoc >= width ||
          pixelsChecked[pxIdx] ||
          !checkPixel(rFillLoc, y)) {
        break;
      }
    }
    rFillLoc--;
    _FloodFillRange r = _FloodFillRange(lFillLoc, rFillLoc, y);
    ranges.add(r);
  }

	linearFill(seedX, seedY);
	_FloodFillRange range;
	while (ranges.isNotEmpty) {
		range = ranges.removeFirst();
		int downPxIdx = (width * (range.y + 1)) + range.startX;
		int upPxIdx = (width * (range.y - 1)) + range.startX;
		int upY = range.y - 1;
		int downY = range.y + 1;
		for (int i = range.startX; i <= range.endX; i++) {
			if (range.y > 0 && (!pixelsChecked[upPxIdx]) && checkPixel(i, upY)) {
				linearFill(i, upY);
			}
			if (range.y < (height - 1) &&
					(!pixelsChecked[downPxIdx]) &&
					checkPixel(i, downY)) {
				linearFill(i, downY);
			}
			downPxIdx++;
			upPxIdx++;
		}
	}
	return pixelsChanged;
}

Uint8List _fixCuts({
	required Uint8List buffer,
	required int width,
	required int height
}) {
	final out1 = Uint8List.fromList(buffer);
	// dilate
	for (int y = 1; y < height - 1; y++) {
		for (int x = 1; x < width - 1; x++) {
			final pos = y * width + x;
			if (buffer[pos + 1] == 0 || buffer[pos - 1] == 0 || buffer[pos + width] == 0 || buffer[pos - width] == 0) {
				out1[pos] = 0;
			}
		}
	}
	final out2 = Uint8List.fromList(out1);
	// erode
	for (int y = 1; y < height - 1; y++) {
		for (int x = 1; x < width - 1; x++) {
			final pos = y * width + x;
			if (out1[pos + 1] == 0xFF || out1[pos - 1] == 0xFF || out1[pos + width] == 0xFF || out1[pos - width] == 0xFF) {
				out2[pos] = 0;
			}
		}
	}
	return out2;
}

int _estimateNumLetters({
	required Uint8List buffer,
	required int width,
	required int height
}) {
	final cols = List.generate(width, (i) => 0, growable: false);
	for (int x = 0; x < width; x++) {
		for (int y = 0; y < height; y++) {
			if (buffer[y * width + x] == 0xFF) {
				cols[x] += 1;
			}
		}
	}
	cols.sort();
	print(cols);
	if (cols[(cols.length * 0.8).floor()] == height) {
		// at least 20% (by columns) is all white
		return 5;
	}
	return 6;
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

class _Letter {
	final double adjustment;
	final Map<_LetterImageType, List<_LetterImage>> images;
	_Letter({
		required this.adjustment,
		required this.images
	});

	@override
	String toString() => '_Letter(adjustment: $adjustment)';
}

class _LetterImage {
	final int width;
	final int height;
	final Uint8List bytes;
	_LetterImage({
		required this.width,
		required this.height,
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

enum _LetterImageType {
	primary,
	secondary
}

class _ScoreArrayForLetterParam {
	final String letter;
	final Uint8List captcha;
	final int width;
	final int height;
	final _LetterImageType type;

	const _ScoreArrayForLetterParam({
		required this.letter,
		required this.captcha,
		required this.width,
		required this.height,
		required this.type
	});
}

List<_LetterScore> _scoreArrayForLetter(_ScoreArrayForLetterParam param) {
	final scores = <_LetterScore>[];
	for (final subimage in _captchaLetterImages[param.letter]!.images[param.type]!) {
		final maxY = (param.height * 0.9).toInt() - subimage.height;
		final maxX = param.width - subimage.width;
		// Increment by 2 to speed up, the images are high-enough resolution that this doesn't really affect accuracy
		for (int y = param.height ~/ 5; y < maxY; y += 2) {
			for (int x = 0; x < maxX; x += 2) {
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
				score += _captchaLetterImages[param.letter]!.adjustment;
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

const _preprocessProportion = 0.4;
const _scoreArrayProportion = 0.45;
const _guessProportion = 0.15;
const _floodFillIterations = 10000;

void _guess(_GuessParam param) async {
	Uint8List captcha = await _getRedChannelOnly(param.rgbaData);
	final width = param.width;
	final height = param.height;
	captcha = _fixCuts(
		buffer: captcha,
		width: width,
		height: height
	);
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
	Uint8List filling = Uint8List.fromList(captcha);
	for (int i = 0; i < _floodFillIterations; i++) {
		final seedX = random.nextInt(width);
		final seedY = random.nextInt(height);
		if (filling[(seedY * width) + seedX] == 255) {
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
		if ((count / captcha.length) < 0.015) {
			captcha = filled;
		}
		else {
			// Write into a parallel image to prevent rechecking this same blob
			_floodFillBuffer(
				buffer: filling,
				seedX: seedX,
				seedY: seedY,
				width: width,
				height: height,
				fillColor: 255
			);
		}
		if (i % 100 == 0) {
			param.sendPort.send(_preprocessProportion * i / _floodFillIterations);
		}
	}
	param.sendPort.send(_preprocessProportion);
	// Create score array
	Future<List<_LetterScore>> createScoreArray(_LetterImageType type) async {
		final pool = Pool(Platform.numberOfProcessors);
		final letterFutures = <Future<List<_LetterScore>>>[];
		int lettersDone = 0;
		for (final letter in captchaLetters) {
			letterFutures.add(pool.withResource(() async {
				final data = await compute(_scoreArrayForLetter, _ScoreArrayForLetterParam(
					captcha: captcha,
					letter: letter,
					width: width,
					height: height,
					type: _LetterImageType.primary
				));
				lettersDone++;
				param.sendPort.send(_preprocessProportion + (_scoreArrayProportion * (lettersDone / captchaLetters.length)));
				return data;
			}));
		}
		return (await Future.wait(letterFutures)).expand((x) => x).toList();
	}
	final primaryScores = await createScoreArray(_LetterImageType.primary);
	List<_LetterScore>? secondaryScores;
	final numLetters = param.numLetters ?? _estimateNumLetters(
		buffer: captcha,
		width: width,
		height: height
	);
	// Pick best set of letters
	Future<List<_LetterScore>> guess({
		List<_LetterScore> deadAnswers = const [],
		bool sendUpdates = false
	}) async {
		final answers = <_LetterScore>[];
		final deadXes = List.filled(width, 0);
		final xAdjustments = <int, List<double>>{};
		final possibleSubimageWidths = _captchaLetterImages.values.expand((x) => x.images.values.expand((i) => i)).map((x) => x.width).toSet().toList();
		for (final possibleWidth in possibleSubimageWidths) {
			xAdjustments[possibleWidth] = List.filled(width, 0);
		}
		final deadLetters = List<Set<String>>.generate(width, (i) => {});
		for (final deadAnswer in deadAnswers) {
			for (int x = max(deadAnswer.x - 14, 0); x < min(width, deadAnswer.x + 15); x++) {
				deadLetters[x].add(deadAnswer.letter);
			}
		}
		for (int i = 0; i < numLetters; i++) {
			_LetterScore bestScore = primaryScores.first;
			for (final score in primaryScores) {
				if (deadLetters[score.x].contains(score.letter)) {
					continue;
				}
				if ((score.score + (i > 0 ? xAdjustments[score.letterImageWidth]![score.x] : 0)) < bestScore.score) {
					bestScore = score;
				}
			}
			if (bestScore.score > 30) {
				secondaryScores ??= await createScoreArray(_LetterImageType.secondary);
				for (final score in secondaryScores!) {
					if (deadLetters[score.x].contains(score.letter)) {
						continue;
					}
					if ((score.score + (i > 0 ? xAdjustments[score.letterImageWidth]![score.x] : 0)) < bestScore.score) {
						bestScore = score;
					}
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
			if (sendUpdates) {
				param.sendPort.send(_preprocessProportion + _scoreArrayProportion + _guessProportion * ((i + 1) / numLetters));
			}
		}
		return answers;
	}
	final answersBest = await guess(sendUpdates: true);
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
		numLetters: numLetters,
		//alternatives: alternatives,
		alternatives: [[], [], [], [], []],
		confidence: (1 - Normal.cdf(
			maxScore,
			mean: 31.99121650969569,
			variance: 5.6186633357112274
		)) * (1 - Normal.cdf(
			maxScore,
			mean: 39.019931473509175,
			variance: 8.9437836310256
		)),
		confidences: answersBest.map((x) => (1 - Normal.cdf(
			x.score,
			mean: 22.030712707662314,
			variance: 6.6035697391139445
		)) * (1 - Normal.cdf(
			x.score,
			mean: 32.892141079395095,
			variance: 11.419233352647126
		))).toList()
	));
}

class _GuessParam {
	final ByteData rgbaData;
	final int? numLetters;
	final int width;
	final int height;
	final SendPort sendPort;
	const _GuessParam({
		required this.rgbaData,
		required this.numLetters,
		required this.width,
		required this.height,
		required this.sendPort
	});
}

CancelableOperation<Chan4CustomCaptchaGuess> guess(ui.Image image, {
	required int? numLetters,
	ValueChanged<double>? onProgress
}) {
	Isolate? isolate;
	return CancelableOperation.fromFuture(
		() async {
			final receivePort = ReceivePort();
			isolate = await Isolate.spawn(_guess, _GuessParam(
				rgbaData: (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!,
				numLetters: numLetters,
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
		}(),
		onCancel: () {
			isolate?.kill();
		}
	);
}
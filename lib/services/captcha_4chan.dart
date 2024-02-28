import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:async/async.dart';
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
	final List<Chan4CustomCaptchaLetterKey> keys;
	const Chan4CustomCaptchaGuess({
		required this.guess,
		required this.numLetters,
		required this.alternatives,
		required this.confidence,
		required this.confidences,
		required this.keys
	});

	factory Chan4CustomCaptchaGuess.dummy(String guess) {
		return Chan4CustomCaptchaGuess(
			guess: guess,
			numLetters: guess.length,
			alternatives: List.generate(guess.length, (_) => []),
			confidence: 1,
			confidences: List.filled(guess.length, 1),
			keys: List.generate(guess.length, (i) => Chan4CustomCaptchaLetterKey._(i))
		);
	}

	@override
	String toString() => '_Chan4CustomCaptchaGuess(guess: $guess, alternatives: $alternatives, confidence: $confidence, confidences: $confidences, keys: $keys)';
}

class Chan4CustomCaptchaLetterKey {
	final int _key;
	const Chan4CustomCaptchaLetterKey._(this._key);

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is Chan4CustomCaptchaLetterKey &&
		other._key == _key;
	@override
	int get hashCode => _key.hashCode;

	@override
	String toString() => 'Chan4CustomCaptchaLetterKey($_key)';
}

class Chan4CustomCaptchaGuesses {
	final List<_LetterScore> _answersBest;
	final int likelyNumLetters;

	const Chan4CustomCaptchaGuesses._(this._answersBest, this.likelyNumLetters);

	@override
	String toString() {
		return 'Chan4CustomCaptchaGuesses(_answersBest: $_answersBest, likelyNumLetters: $likelyNumLetters)';
	}

	factory Chan4CustomCaptchaGuesses.dummy(String answer, int maxNumLetters) {
		final answersBest = [
			for (int i = 0; i < maxNumLetters; i++) _LetterScore(
				score: i.toDouble(),
				letter: i < answer.length ? answer[i] : '0',
				y: 0,
				x: i,
				letterImageWidth: 0
			)
		];
		return Chan4CustomCaptchaGuesses._(answersBest, answer.length);
	}

	Chan4CustomCaptchaGuess forNumLetters(int numLetters) {
		List<MapEntry<int, _LetterScore>> answersBest = _answersBest.asMap().entries.toList();
		answersBest.sort((a, b) => a.value.score.compareTo(b.value.score));
		answersBest = answersBest.sublist(0, numLetters);
		answersBest.sort((a, b) => a.value.x - b.value.x);
		final maxScore = answersBest.map((x) => x.value.score).reduce(max);
		return Chan4CustomCaptchaGuess(
			guess: answersBest.map((x) => x.value.letter).join(''),
			numLetters: numLetters,
			keys: answersBest.map((x) => Chan4CustomCaptchaLetterKey._(x.key)).toList(),
			alternatives: [[], [], [], [], []],
			confidence: (1 - Normal.cdf(
				maxScore,
				mean: 34.61089431538079, 
				variance: 4.17640652209748
			)) * (1 - Normal.cdf(
				maxScore,
				mean: 37.965435072982544,
				variance: 4.9745338087187525
			)),
			confidences: answersBest.map((x) => (1 - Normal.cdf(
				x.value.score,
				mean: 26.632857611907685,
				variance: 6.143543497479517
			)) * (1 - Normal.cdf(
				x.value.score,
				mean: 32.25173511673559,
				variance: 6.8081240822553175
			))).toList()
		);
	}
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

const _preprocessProportion = 0.1;
const _scoreArrayProportion = 0.75;
const _guessProportion = 0.25;

void _guess(_GuessParam param) async {
	Uint8List captcha = await _getRedChannelOnly(param.rgbaData);
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
	final usefulXes = List.filled(width, false);
	final usefulXThreshold = (height * 0.18).round();
	for (int x = 0; x < width; x++) {
		int total = 0;
		for (int y = 0; y < height; y++) {
			if (captcha[(y * width) + x] == 0) {
				total++;
				if (total > usefulXThreshold) {
					usefulXes[x] = true;
					break;
				}
			}
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
		for (int i = 0; i < param.maxNumLetters; i++) {
			int remainingX = 0;
			for (int x = 0; x < width; x++) {
				if (deadXes[x] == 0 && usefulXes[x]) {
					remainingX++;
				}
			}
			final xBudget = remainingX * (2 / (param.maxNumLetters - i));
			(double, _LetterScore) bestScore = (primaryScores.first.score, primaryScores.first);
			for (final score in primaryScores) {
				if (deadLetters[score.x].contains(score.letter)) {
					continue;
				}
				final adjustedScore = score.score + xAdjustments[score.letterImageWidth]![score.x] + (score.letterImageWidth > xBudget ? 10 : 0);
				if (adjustedScore < bestScore.$1) {
					bestScore = (adjustedScore, score);
				}
			}
			if (bestScore.$2.score > 30) {
				secondaryScores ??= await createScoreArray(_LetterImageType.secondary);
				for (final score in secondaryScores!) {
					if (deadLetters[score.x].contains(score.letter)) {
						continue;
					}
					final adjustedScore = score.score + xAdjustments[score.letterImageWidth]![score.x] + (score.letterImageWidth > xBudget ? 10 : 0);
					if (adjustedScore < bestScore.$1) {
						bestScore = (adjustedScore, score);
					}
				}
			}
			final subimageEndX = bestScore.$2.x + bestScore.$2.letterImageWidth;
			for (int x = bestScore.$2.x; x < subimageEndX; x++) {
				deadXes[x] = 1;
			}
			for (final possibleWidth in possibleSubimageWidths) {
				for (int x = max(bestScore.$2.x - possibleWidth, 0); x < subimageEndX; x++) {
					xAdjustments[possibleWidth]![x] = 0;
					for (int x_ = x; x_ < min(width, x + possibleWidth); x_++) {
						xAdjustments[possibleWidth]![x] += deadXes[x_] * 3.57;
					}
				}
			}
			answers.add(bestScore.$2);
			if (sendUpdates) {
				param.sendPort.send(_preprocessProportion + _scoreArrayProportion + _guessProportion * ((i + 1) / param.maxNumLetters));
			}
		}
		return answers;
	}
	final answersBest = await guess(sendUpdates: true);
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
	param.sendPort.send(1.0);
	final numLettersGuess = (answersBest.last.score < 45) ? answersBest.length : answersBest.length - 1;
	param.sendPort.send(Chan4CustomCaptchaGuesses._(answersBest, numLettersGuess));
}

class _GuessParam {
	final ByteData rgbaData;
	final int maxNumLetters;
	final int width;
	final int height;
	final SendPort sendPort;
	const _GuessParam({
		required this.rgbaData,
		required this.maxNumLetters,
		required this.width,
		required this.height,
		required this.sendPort
	});
}

CancelableOperation<Chan4CustomCaptchaGuesses> guess(ui.Image image, {
	required int maxNumLetters,
	ValueChanged<double>? onProgress
}) {
	Isolate? isolate;
	return CancelableOperation.fromFuture(
		() async {
			final receivePort = ReceivePort();
			isolate = await Isolate.spawn(_guess, _GuessParam(
				rgbaData: (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!,
				maxNumLetters: maxNumLetters,
				width: image.width,
				height: image.height,
				sendPort: receivePort.sendPort
			));
			await for (final datum in receivePort) {
				if (datum is double) {
					onProgress?.call(datum);
				}
				else if (datum is Chan4CustomCaptchaGuesses) {
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
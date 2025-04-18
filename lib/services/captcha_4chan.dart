import 'dart:math';
import 'package:normal/normal.dart';

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

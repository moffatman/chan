import 'dart:convert';

import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/sites/4chan.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/captcha_4chan.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' show parse;

typedef OwoVgWsSend = void Function(Map<String, dynamic> payload);

class OwoVgInteractiveCaptcha {
	final String challenge;
	final List<Map<String, dynamic>> tasks;
	final Duration lifetime;
	final String solutionString;
	final bool suggestOnly;
	const OwoVgInteractiveCaptcha({
		required this.challenge,
		required this.tasks,
		required this.lifetime,
		required this.solutionString,
		required this.suggestOnly
	});
}

OwoVgInteractiveCaptcha? parseOwoVgInteractiveCaptchaHtml(String html) {
	final document = parse(html);
	final challenge = document.querySelector('input[name="t-challenge"]')?.attributes['value']?.trim();
	if (challenge == null || challenge.isEmpty) {
		return null;
	}
	final tasks = _extractTasksJson(html);
	if (tasks == null || tasks.isEmpty) {
		return null;
	}
	final solutionString = _extractSolutionString(html) ?? List.filled(tasks.length, '_').join();
	return OwoVgInteractiveCaptcha(
		challenge: challenge,
		tasks: tasks,
		lifetime: _extractLifetime(html),
		solutionString: solutionString,
		suggestOnly: _extractSuggestOnly(html)
	);
}

List<Map<String, dynamic>>? _extractTasksJson(String html) {
	const prefix = 'const tasks = ';
	final start = html.indexOf(prefix);
	if (start == -1) {
		return null;
	}
	var index = start + prefix.length;
	while (index < html.length && html[index].trim().isEmpty) {
		index++;
	}
	if (index >= html.length || html[index] != '[') {
		return null;
	}
	var depth = 0;
	final begin = index;
	for (; index < html.length; index++) {
		final char = html[index];
		if (char == '[') {
			depth++;
		}
		else if (char == ']') {
			depth--;
			if (depth == 0) {
				final decoded = jsonDecode(html.substring(begin, index + 1));
				if (decoded is! List) {
					return null;
				}
				return decoded.cast<Map>().map((task) => Map<String, dynamic>.from(task)).toList();
			}
		}
	}
	return null;
}

String? _extractSolutionString(String html) {
	final match = RegExp(r"const solutionString = '([^']*)'").firstMatch(html);
	return match?.group(1);
}

bool _extractSuggestOnly(String html) {
	final match = RegExp(r'const suggestOnly = (true|false)').firstMatch(html);
	return match?.group(1) == 'true';
}

List<int?> taskHintsFromSolutionString(String solutionString, int taskCount) {
	return [
		for (var i = 0; i < taskCount; i++)
			if (i < solutionString.length && solutionString[i] != '_')
				int.tryParse(solutionString[i])
			else
				null
	];
}

Duration _extractLifetime(String html) {
	final timMatch = RegExp(r'let tim = (\d+)').firstMatch(html);
	if (timMatch case final match?) {
		final ms = int.tryParse(match.group(1)!);
		if (ms != null && ms > 0) {
			return Duration(milliseconds: ms);
		}
	}
	final timeoutMatch = RegExp(r'setTimeout\([^,]+,\s*(\d+)\)').firstMatch(html);
	if (timeoutMatch case final match?) {
		final ms = int.tryParse(match.group(1)!);
		if (ms != null && ms > 0) {
			return Duration(milliseconds: ms);
		}
	}
	return const Duration(minutes: 2);
}

Future<bool> showOwoVgCaptchaDialog({
	required BuildContext context,
	required Site4Chan site,
	required Chan4CustomCaptchaRequest request,
	required String html,
	required OwoVgWsSend sendMessage
}) async {
	final parsed = parseOwoVgInteractiveCaptchaHtml(html);
	if (parsed == null) {
		return false;
	}
	final acquiredAt = DateTime.now();
	final taskHints = taskHintsFromSolutionString(parsed.solutionString, parsed.tasks.length);
	final autoApplyHints = !parsed.suggestOnly && !parsed.solutionString.contains('_');
	final challenge = await buildCaptcha4ChanCustomChallengeTasks(
		request: request,
		challenge: parsed.challenge,
		rawTasks: parsed.tasks,
		acquiredAt: acquiredAt,
		tryAgainAt: null,
		lifetime: parsed.lifetime,
		cloudflare: false,
		taskHints: taskHints,
		autoApplyHints: autoApplyHints,
		originalData: {
			'source': 'owovg',
			'challenge': parsed.challenge,
			'tasks': parsed.tasks,
			'solutionString': parsed.solutionString,
			'suggestOnly': parsed.suggestOnly,
		}
	);
	if (!context.mounted) {
		challenge.dispose();
		return false;
	}
	final solved = await Navigator.of(context, rootNavigator: true).push<bool>(TransparentRoute(
		builder: (dialogContext) => OverscrollModalPage(
			increasePopDifficulty: true,
			child: Captcha4ChanCustom(
				site: site,
				request: request,
				initialChallenge: challenge,
				allowChallengeRefresh: false,
				onCaptchaSolved: (solution) {
					if (solution != null) {
						sendMessage({
							't': 'solve',
							't-response': solution.response,
							't-challenge': solution.challenge,
						});
					}
					Navigator.of(dialogContext).pop(solution != null);
				}
			)
		)
	));
	if (solved != true) {
		challenge.dispose();
	}
	return solved ?? false;
}

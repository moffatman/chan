import 'dart:convert';
import 'dart:math' as math;

import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/owovg_captcha.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class OwoVgEmailHcaptchaPrompt {
	final String title;
	final String sitekey;
	final String nonce;
	final String? pageHtml;
	final bool report;
	const OwoVgEmailHcaptchaPrompt({
		required this.title,
		required this.sitekey,
		required this.nonce,
		this.pageHtml,
		this.report = false
	});

	factory OwoVgEmailHcaptchaPrompt.fromJson(Map json) => OwoVgEmailHcaptchaPrompt(
		title: json['title'] as String? ?? 'hCAPTCHA',
		sitekey: json['sitekey'] as String? ?? '',
		nonce: json['nonce'] as String? ?? '',
		pageHtml: json['html'] as String?,
		report: json['report'] as bool? ?? false
	);

	bool get isValid => sitekey.isNotEmpty && nonce.isNotEmpty;
}

bool isValidOwoVgHcaptchaToken(String token) {
	return token.startsWith('P1_') || token.startsWith('F1_');
}

String _buildEmailHcaptchaHtml(OwoVgEmailHcaptchaPrompt prompt) {
	final formId = 'hcap_${DateTime.now().microsecondsSinceEpoch}';
	final pageHtmlB64 = base64Encode(utf8.encode(prompt.pageHtml ?? ''));
	final sitekeyJson = jsonEncode(prompt.sitekey);
	final nonceJson = jsonEncode(prompt.nonce);
	final pageHtmlB64Json = jsonEncode(pageHtmlB64);
	return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
html, body {
  margin: 0;
  padding: 0;
  background: transparent;
  overflow-x: hidden;
}
#hcap-root-$formId {
  width: 100%;
  max-width: 520px;
  font-family: sans-serif;
  box-sizing: border-box;
}
#hcap-widget-$formId {
  min-height: 420px;
  display: flex;
  justify-content: center;
  align-items: flex-start;
  padding: 8px 0;
  box-sizing: border-box;
}
#hcap-frame-$formId {
  width: 0;
  height: 0;
  border: 0;
  position: absolute;
  opacity: 0;
  pointer-events: none;
}
</style>
</head>
<body>
<div id="hcap-root-$formId">
  <iframe id="hcap-frame-$formId" sandbox="allow-scripts allow-same-origin"></iframe>
  <div id="hcap-widget-$formId"></div>
</div>
<script>
(() => {
  const formId = ${jsonEncode(formId)};
  const nonce = $nonceJson;
  const sitekey = $sitekeyJson;
  const pageHtml = $pageHtmlB64Json.length ? atob($pageHtmlB64Json) : '';
  let done = false;

  const submitToken = (token) => {
    if (done || !token || typeof token !== 'string') return;
    if (!token.startsWith('P1_') && !token.startsWith('F1_')) return;
    done = true;
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      window.flutter_inappwebview.callHandler('owoVgHcaptchaDone', token);
    }
  };

  const iframe = document.getElementById('hcap-frame-' + formId);
  if (iframe && pageHtml) {
    iframe.src = URL.createObjectURL(new Blob([pageHtml], { type: 'text/html;charset=utf-8' }));
  }

  window.addEventListener('message', (ev) => {
    const data = ev.data;
    if (!data || typeof data !== 'object') return;
    if (data.t === 'solve_email_hcaptcha') {
      submitToken(data.token || data['h-captcha-response']);
    }
  }, true);

  window.pcd_c_done = submitToken;
  window.pcd_c_loaded = () => {
    if (done || !window.hcaptcha || !sitekey) return;
    try {
      window.hcaptcha.render('hcap-widget-' + formId, {
        sitekey: sitekey,
        callback: 'pcd_c_done',
      });
    } catch (err) {
      console.error('hCaptcha render failed', err);
    }
  };

  if (sitekey) {
    const script = document.createElement('script');
    script.src = 'https://js.hcaptcha.com/1/api.js?onload=pcd_c_loaded&render=explicit&recaptchacompat=off';
    script.async = true;
    script.defer = true;
    script.onerror = () => console.error('failed to load hCaptcha script');
    document.head.appendChild(script);
  }
})();
</script>
</body>
</html>
''';
}

Future<bool> showOwoVgEmailHcaptchaDialog({
	required BuildContext context,
	required OwoVgEmailHcaptchaPrompt prompt,
	required OwoVgWsSend sendMessage
}) async {
	if (!prompt.isValid) {
		return false;
	}
	final size = MediaQuery.sizeOf(context);
	final width = math.min(520.0, size.width - 24);
	final height = math.min(520.0, size.height * 0.75);
	return await showAdaptiveDialog<bool>(
		context: context,
		barrierDismissible: false,
		builder: (dialogContext) => AdaptiveAlertDialog(
			title: Text(prompt.title),
			content: SizedBox(
				width: width,
				height: height,
				child: OwoVgEmailHcaptchaWebView(
					prompt: prompt,
					onSolved: (token) {
						sendMessage({
							't': 'solve_email_hcaptcha',
							'h-captcha-response': token,
							't-challenge': prompt.nonce,
							'sitekey': prompt.sitekey,
						});
						Navigator.of(dialogContext).pop(true);
					}
				)
			),
			actions: [
				AdaptiveDialogAction(
					child: const Text('Cancel'),
					onPressed: () => Navigator.of(dialogContext).pop(false)
				)
			]
		)
	) ?? false;
}

class OwoVgEmailHcaptchaWebView extends StatefulWidget {
	final OwoVgEmailHcaptchaPrompt prompt;
	final ValueChanged<String> onSolved;
	const OwoVgEmailHcaptchaWebView({
		required this.prompt,
		required this.onSolved,
		super.key
	});

	@override
	State<OwoVgEmailHcaptchaWebView> createState() => _OwoVgEmailHcaptchaWebViewState();
}

class _OwoVgEmailHcaptchaWebViewState extends State<OwoVgEmailHcaptchaWebView> {
	static final _pageUrl = WebUri('https://owo.vg/');
	var _solved = false;

	@override
	Widget build(BuildContext context) {
		return InAppWebView(
			initialData: InAppWebViewInitialData(
				data: _buildEmailHcaptchaHtml(widget.prompt),
				baseUrl: _pageUrl,
				mimeType: 'text/html',
				encoding: 'utf-8'
			),
			initialSettings: InAppWebViewSettings(
				javaScriptEnabled: true,
				domStorageEnabled: true,
				mediaPlaybackRequiresUserGesture: false,
				transparentBackground: true,
				useWideViewPort: true,
				verticalScrollBarEnabled: true,
				disableVerticalScroll: false,
				supportMultipleWindows: true,
				javaScriptCanOpenWindowsAutomatically: true,
				overScrollMode: OverScrollMode.IF_CONTENT_SCROLLS
			),
			onWebViewCreated: (controller) {
				controller.addJavaScriptHandler(
					handlerName: 'owoVgHcaptchaDone',
					callback: (args) {
						if (_solved || args.isEmpty) {
							return;
						}
						final raw = args.first;
						if (raw is! String || !isValidOwoVgHcaptchaToken(raw)) {
							return;
						}
						_solved = true;
						if (mounted) {
							widget.onSolved(raw);
						}
					}
				);
			},
		);
	}
}

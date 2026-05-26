import 'package:chan/models/owovg_post_extras.dart';
import 'package:chan/pages/cookie_browser.dart';
import 'package:chan/services/owovg.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/4chan.dart';
import 'package:chan/services/util.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/html_rich_text.dart';
import 'package:chan/widgets/util.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class OwoVgReplyExtrasPanel extends StatefulWidget {
	final Site4Chan site;
	final String board;
	final OwoVgPostExtras extras;
	final ValueChanged<OwoVgPostExtras> onChanged;
	const OwoVgReplyExtrasPanel({
		required this.site,
		required this.board,
		required this.extras,
		required this.onChanged,
		super.key
	});

	@override
	State<OwoVgReplyExtrasPanel> createState() => _OwoVgReplyExtrasPanelState();
}

class _OwoVgReplyExtrasPanelState extends State<OwoVgReplyExtrasPanel> {
	OwoVgMeta? _meta;
	bool _loadingMeta = true;
	List<(String, String)> _recycleIpOptions = const [];
	final _peeTextController = TextEditingController();

	@override
	void initState() {
		super.initState();
		_peeTextController.text = widget.extras.peeText ?? '';
		_loadMeta();
	}

	@override
	void didUpdateWidget(OwoVgReplyExtrasPanel oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.board != widget.board) {
			_loadMeta();
		}
		if (oldWidget.extras.peeText != widget.extras.peeText) {
			_peeTextController.text = widget.extras.peeText ?? '';
		}
	}

	@override
	void dispose() {
		_peeTextController.dispose();
		super.dispose();
	}

	Future<void> _loadMeta() async {
		setState(() => _loadingMeta = true);
		try {
			final meta = await OwoVgService.fetchMeta(widget.site, board: widget.board);
			if (!mounted) return;
			setState(() {
				_meta = meta;
				_recycleIpOptions = OwoVgService.parseRecycleIpOptions(meta.ipMarkup);
				_loadingMeta = false;
			});
		}
		catch (e) {
			if (!mounted) return;
			setState(() => _loadingMeta = false);
		}
	}

	void _update(OwoVgPostExtras extras) => widget.onChanged(extras);

	Future<void> _pickPeeFiles() async {
		final result = await FilePicker.platform.pickFiles(allowMultiple: true);
		if (result == null) return;
		final paths = result.paths.whereType<String>().toList();
		if (paths.isEmpty) return;
		_update(widget.extras.copyWith(peeFiles: [...widget.extras.peeFiles, ...paths].take(16).toList()));
	}

	Future<void> _pickFakeThumbnail() async {
		final result = await FilePicker.platform.pickFiles(allowMultiple: false);
		final path = result?.files.single.path;
		if (path == null) return;
		_update(widget.extras.copyWith(fakeThumbnail: path));
	}

	Future<void> _complain() async {
		final controller = TextEditingController();
		final message = await showAdaptiveDialog<String>(
			context: context,
			builder: (context) => AdaptiveAlertDialog(
				title: const Text('Complain'),
				content: TextField(
					controller: controller,
					maxLines: 4,
					autocorrect: false,
					decoration: const InputDecoration(
						hintText: 'Complain about owo.vg bugs and posting issues here.'
					)
				),
				actions: [
					AdaptiveDialogAction(
						child: const Text('Cancel'),
						onPressed: () => Navigator.pop(context)
					),
					AdaptiveDialogAction(
						child: const Text('Send'),
						onPressed: () => Navigator.pop(context, controller.text)
					)
				]
			)
		);
		controller.dispose();
		if (message == null || !mounted) return;
		try {
			final response = await OwoVgService.submitFeedback(widget.site, message);
			if (!mounted) return;
			showToast(context: context, message: response, icon: CupertinoIcons.checkmark_circle);
		}
		catch (e) {
			if (!mounted) return;
			showToast(context: context, message: e.toString(), icon: CupertinoIcons.exclamationmark_triangle);
		}
	}

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<Settings>();
		final useOwoVg = settings.fourChanPostingBackend == OwoVgPostingBackend.owoVg;
		final gold = _meta?.gold ?? false;
		final skipAutosolverLabel = gold ? 'Manual captcha' : 'Skip autosolver';
		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				Padding(
					padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							const Text('Posting backend', style: TextStyle(fontWeight: FontWeight.w600)),
							const SizedBox(height: 8),
							AdaptiveSegmentedControl<OwoVgPostingBackend>(
								groupValue: settings.fourChanPostingBackend,
								fillWidth: true,
								padding: EdgeInsets.zero,
								onValueChanged: (backend) {
									settings.fourChanPostingBackend = backend;
									setState(() {});
								},
								children: const {
									OwoVgPostingBackend.direct: (null, '4chan'),
									OwoVgPostingBackend.owoVg: (null, 'owo.vg'),
								}
							),
							if (useOwoVg) ...[
								const SizedBox(height: 12),
								const Text('Pool', style: TextStyle(fontWeight: FontWeight.w600)),
								const SizedBox(height: 8),
								AdaptiveSegmentedControl<String>(
									groupValue: settings.owoVgPool,
									fillWidth: true,
									padding: EdgeInsets.zero,
									onValueChanged: (pool) {
										settings.owoVgPool = pool;
										setState(() {});
									},
									children: const {
										's': (null, 'Shitposting'),
										'l': (null, 'Legitposting'),
										'c': (null, '😭'),
									}
								),
							]
							else const Padding(
								padding: EdgeInsets.only(top: 12),
								child: Text(
									'Posts go directly to 4chan.',
									style: TextStyle(fontSize: 13)
								)
							),
						]
					)
				),
				if (_loadingMeta)
					const Padding(
						padding: EdgeInsets.all(8),
						child: Center(child: CupertinoActivityIndicator())
					),
				if (_meta?.news case final news? when news.trim().isNotEmpty)
					Padding(
						padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
						child: HtmlRichText(
							html: news,
							style: TextStyle(color: Colors.red.shade700, fontSize: 13),
							linkStyle: TextStyle(
								color: Colors.red.shade700,
								fontSize: 13,
								decoration: TextDecoration.underline
							)
						)
					),
				if (!useOwoVg)
					const SizedBox(height: 8)
				else ...[
				Wrap(
					spacing: 8,
					runSpacing: 8,
					children: [
						AdaptiveThinButton(
							onPressed: _complain,
							child: const Text('Complain')
						),
						if (gold) AdaptiveThinButton(
							onPressed: () => openCookieBrowser(
								context,
								Uri.https(widget.site.owoVgUrl, '/eck_bans'),
								useFullWidthGestures: false
							),
							child: const Text('My Bans')
						),
						if (_meta?.metathreadUrl case final url?) AdaptiveThinButton(
							onPressed: () => openCookieBrowser(context, Uri.parse(url), useFullWidthGestures: false),
							child: const Text('Metathread')
						),
					]
				),
				const SizedBox(height: 8),
				SwitchListTile(
					title: Text(skipAutosolverLabel),
					subtitle: Text(gold ? 'Force interactive captcha instead of autosolver' : 'Solve captcha yourself instead of waiting for autosolver'),
					value: settings.owoVgManualCaptcha,
					onChanged: (v) {
						settings.owoVgManualCaptcha = v;
						setState(() {});
					}
				),
				if (gold) SwitchListTile(
					title: const Text('Email IPs'),
					value: settings.owoVgEmailIps,
					onChanged: (v) {
						settings.owoVgEmailIps = v;
						setState(() {});
					}
				),
				if (gold && _recycleIpOptions.isNotEmpty) ListTile(
					title: const Text('Recycle IP'),
					subtitle: DropdownButton<String>(
						isExpanded: true,
						value: settings.owoVgRecycleIps,
						items: [
							for (final (value, label) in _recycleIpOptions)
								DropdownMenuItem(value: value, child: Text(label))
						],
						onChanged: (v) {
							if (v == null) return;
							settings.owoVgRecycleIps = v;
							setState(() {});
						}
					)
				),
				if (gold && (_meta?.emailVerificationProviders.isNotEmpty ?? false)) ListTile(
					title: const Text('Email type'),
					subtitle: DropdownButton<String>(
						isExpanded: true,
						value: settings.owoVgEmailVerificationStock.isEmpty ? '' : settings.owoVgEmailVerificationStock,
						items: [
							const DropdownMenuItem(value: '', child: Text('Auto (server pool)')),
							for (final provider in _meta!.emailVerificationProviders.where((p) => p.id.isNotEmpty && !p.disabled))
								DropdownMenuItem(
									value: provider.id,
									child: Text(_providerLabel(provider))
								)
						],
						onChanged: (v) {
							settings.owoVgEmailVerificationStock = v ?? '';
							setState(() {});
						}
					)
				),
				SwitchListTile(
					title: const Text('Change hash'),
					subtitle: const Text('Recompress uploaded file to change perceptual hash'),
					value: settings.owoVgRecompression,
					onChanged: (v) {
						settings.owoVgRecompression = v;
						setState(() {});
					}
				),
				ExpansionTile(
					title: const Text('Gimmicks'),
					children: [
						SwitchListTile(
							title: const Text('Evade perceptual hash'),
							value: settings.owoVgAntiphash,
							onChanged: (v) {
								settings.owoVgAntiphash = v;
								setState(() {});
							}
						),
						ListTile(
							title: const Text('Fake thumbnail'),
							subtitle: Text(widget.extras.fakeThumbnail?.afterLast('/') ?? 'None selected'),
							trailing: Row(
								mainAxisSize: MainAxisSize.min,
								children: [
									if (widget.extras.fakeThumbnail != null) IconButton(
										icon: const Icon(CupertinoIcons.xmark),
										onPressed: () => _update(widget.extras.copyWith(clearFakeThumbnail: true))
									),
									IconButton(
										icon: const Icon(CupertinoIcons.photo),
										onPressed: _pickFakeThumbnail
									)
								]
							)
						)
					]
				),
				ListTile(
					title: const Text('PEE'),
					subtitle: Text(widget.extras.peeFiles.isEmpty ? 'No hidden embed files' : describeCount(widget.extras.peeFiles.length, 'file')),
					trailing: Row(
						mainAxisSize: MainAxisSize.min,
						children: [
							if (widget.extras.peeFiles.isNotEmpty) IconButton(
								icon: const Icon(CupertinoIcons.trash),
								onPressed: () => _update(const OwoVgPostExtras())
							),
							IconButton(
								icon: const Icon(CupertinoIcons.add),
								onPressed: _pickPeeFiles
							)
						]
					)
				),
				Padding(
					padding: const EdgeInsets.symmetric(horizontal: 16),
					child: TextField(
						controller: _peeTextController,
						maxLines: 2,
						decoration: const InputDecoration(
							labelText: 'PEE text',
							hintText: 'Hidden text that PEE users see in your file'
						),
						onChanged: (v) => _update(widget.extras.copyWith(peeText: v)),
					)
				),
				const SizedBox(height: 8)
				],
			]
		);
	}

	String _providerLabel(OwoVgEmailVerificationProvider provider) {
		final parts = [provider.label];
		if (provider.stockDisplay != null) parts.add('stock ${provider.stockDisplay}');
		if (provider.successRateDisplay != null) parts.add(provider.successRateDisplay!);
		return parts.join(' | ');
	}
}

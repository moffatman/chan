import 'package:chan/services/filtering.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/filter_editor.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingsFilterPage extends StatefulWidget {
	const SettingsFilterPage({
		Key? key
	}) : super(key: key);

	@override
	createState() => _SettingsFilterPageState();
}

class _SettingsFilterPageState extends State<SettingsFilterPage> {
	bool showFilterRegex = false;

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<Settings>();
		return AdaptiveScaffold(
			resizeToAvoidBottomInset: false,
			disableAutoBarHiding: true,
			bar: const AdaptiveBar(
				title: Text('Filter Settings')
			),
			body: SafeArea(
				child: Column(
					children: [
						const SizedBox(height: 16),
						Row(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								const SizedBox(width: 16),
								const Padding(
									padding: EdgeInsets.only(top: 4),
									child: Row(
										mainAxisSize: MainAxisSize.min,
										children: [
											Icon(CupertinoIcons.scope),
											SizedBox(width: 8),
											Text('Filters')
										]
									)
								),
								const SizedBox(width: 32),
								Expanded(
									child: Wrap(
										alignment: WrapAlignment.end,
										spacing: 16,
										runSpacing: 16,
										children: [
											AdaptiveFilledButton(
												padding: const EdgeInsets.all(8),
												borderRadius: BorderRadius.circular(4),
												minSize: 0,
												child: const Text('Test filter setup'),
												onPressed: () {
													Navigator.of(context).push(adaptivePageRoute(
														builder: (context) => const FilterTestPage()
													));
												}
											),
											AdaptiveSegmentedControl<bool>(
												padding: EdgeInsets.zero,
												groupValue: showFilterRegex,
												children: const {
													false: (null, 'Wizard'),
													true: (null, 'Regex')
												},
												onValueChanged: (v) => setState(() {
													showFilterRegex = v;
												})
											)
										]
									)
								),
								const SizedBox(width: 16)
							]
						),
						if (settings.filterError != null) Padding(
							padding: const EdgeInsets.only(top: 16),
							child: Text(
								settings.filterError!,
								style: const TextStyle(
									color: Colors.red
								)
							)
						),
						Expanded(
							child: FilterEditor(
								showRegex: showFilterRegex,
								fillHeight: true
							)
						)
					]
				)
			)
		);
	}
}

class FilterTestPage extends StatefulWidget {
	const FilterTestPage({
		Key? key
	}) : super(key: key);

	@override
	createState() => _FilterTestPageState();
}

class _FilterTestPageState extends State<FilterTestPage> implements Filterable {
	late final TextEditingController _boardController;
	late final TextEditingController _idController;
	late final TextEditingController _textController;
	late final TextEditingController _subjectController;
	late final TextEditingController _nameController;
	late final TextEditingController _filenameController;
	late final TextEditingController _dimensionsController;
	late final TextEditingController _posterIdController;
	late final TextEditingController _flagController;
	late final TextEditingController _replyCountController;

	@override
	void initState() {
		super.initState();
		_boardController = TextEditingController();
		_idController = TextEditingController();
		_textController = TextEditingController();
		_subjectController = TextEditingController();
		_nameController = TextEditingController();
		_filenameController = TextEditingController();
		_dimensionsController = TextEditingController();
		_posterIdController = TextEditingController();
		_flagController = TextEditingController();
		_replyCountController = TextEditingController();
	}

	@override
	String get board => _boardController.text;

	@override
	int get id => -1;

	@override
	bool get hasFile => _filenameController.text.isNotEmpty;

	@override
	bool isThread = true;

	@override
	bool isDeleted = false;

	@override
	List<int> get repliedToIds => [];

	@override
	int get replyCount => int.tryParse(_replyCountController.text) ?? 0;

	@override
	Iterable<String> get md5s => [];

	@override
	String? getFilterFieldText(String fieldName) {
		switch (fieldName) {
			case 'subject':
				return _subjectController.text;
			case 'name':
				return _nameController.text;
			case 'filename':
				return _filenameController.text;
			case 'dimensions':
				return _dimensionsController.text;
			case 'text':
				return _textController.text;
			case 'postID':
				return _idController.text;
			case 'posterID':
				return _posterIdController.text;
			case 'flag':
				return _flagController.text;
			default:
				return null;
		}
	}

	FilterResult? result;

	void _recalculate() {
		result = makeFilter(Settings.instance.filterConfiguration).filter(this);
		setState(() {});
	}

	String _filterResultType(FilterResultType? type) {
		final results = <String>[];
		if (type?.hide == true) {
			results.add('Hidden');
		}
		if (type?.highlight == true) {
			results.add('Highlighted');
		}
		if (type?.pinToTop == true) {
			results.add('Pinned to top of catalog');
		}
		if (type?.autoSave == true) {
			results.add('Auto-saved');
		}
		if (type?.autoWatch != null) {
			results.add('Auto-watched');
		}
		if (type?.notify == true) {
			results.add('Notified');
		}
		if (type?.collapse == true) {
			results.add('Collapsed (tree mode)');
		}
		if (type?.hideReplies == true) {
			results.add('Replies hidden');
		}
		if (results.isEmpty) {
			return 'No action';
		}
		return results.join(', ');
	}

	@override
	Widget build(BuildContext context) {
		return _OldSettingsPage(
			title: 'Filter testing',
			children: [
				const Text('Fill the fields here to see how your filter setup will categorize threads and posts'),
				const SizedBox(height: 16),
				Text('Filter outcome:  ${_filterResultType(result?.type)}\nReason: ${result?.reason ?? 'No match'}'),
				const SizedBox(height: 16),
				AdaptiveSegmentedControl<bool>(
					children: const {
						false: (null, 'Post'),
						true: (null, 'Thread')
					},
					groupValue: isThread,
					onValueChanged: (setting) {
						isThread = setting;
						_recalculate();
					}
				),
				const SizedBox(height: 16),
				AdaptiveSegmentedControl<bool>(
					children: const {
						false: (null, 'Not deleted'),
						true: (null, 'Deleted')
					},
					groupValue: isDeleted,
					onValueChanged: (setting) {
						isDeleted = setting;
						_recalculate();
					}
				),
				const SizedBox(height: 16),
				for (final field in [
					('Board', _boardController, null),
					(isThread ? 'Thread no.' : 'Post no.', _idController, null),
					('Reply Count', _replyCountController, null),
					if (isThread) ('Subject', _subjectController, null),
					('Name', _nameController, null),
					('Poster ID', _posterIdController, null),
					('Flag', _flagController, null),
					('Filename', _filenameController, null),
					('File dimensions', _dimensionsController, null),
					('Text', _textController, 5),
				]) ...[
					Text(field.$1),
					Padding(
						padding: const EdgeInsets.all(16),
						child: AdaptiveTextField(
							controller: field.$2,
							minLines: field.$3,
							maxLines: null,
							smartDashesType: SmartDashesType.disabled,
							smartQuotesType: SmartQuotesType.disabled,
							onChanged: (_) {
								_recalculate();
							}
						)
					)
				]
			]
		);
	}

	@override
	void dispose() {
		super.dispose();
		_boardController.dispose();
		_idController.dispose();
		_textController.dispose();
		_subjectController.dispose();
		_nameController.dispose();
		_filenameController.dispose();
		_dimensionsController.dispose();
		_posterIdController.dispose();
		_flagController.dispose();
	}
}

class _OldSettingsPage extends StatefulWidget {
	final String title;
	final List<Widget> children;
	const _OldSettingsPage({
		required this.children,
		required this.title,
		Key? key
	}) : super(key: key);

	@override
	createState() => _OldSettingsPageState();
}

class _OldSettingsPageState extends State<_OldSettingsPage> {
	final scrollKey = GlobalKey(debugLabel: '_SettingsPageState.scrollKey');

	@override
	Widget build(BuildContext context) {
		return AdaptiveScaffold(
			resizeToAvoidBottomInset: false,
			bar: AdaptiveBar(
				title: Text(widget.title)
			),
			body: Builder(
				builder: (context) => MaybeScrollbar(
					child: ListView.builder(
						padding: MediaQuery.paddingOf(context) + const EdgeInsets.all(16),
						key: scrollKey,
						itemCount: widget.children.length,
						itemBuilder: (context, i) => Align(
							alignment: Alignment.center,
							child: ConstrainedBox(
								constraints: const BoxConstraints(
									minWidth: 500,
									maxWidth: 500
								),
								child: widget.children[i]
							)
						)
					)
				)
			)
		);
	}
}

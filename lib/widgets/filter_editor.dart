import 'package:chan/services/filtering.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

class FilterEditor extends StatefulWidget {
	final bool showRegex;
	final String? forBoard;
	final CustomFilter? blankFilter;

	const FilterEditor({
		required this.showRegex,
		this.forBoard,
		this.blankFilter,
		Key? key
	}) : super(key: key);

	@override
	createState() => _FilterEditorState();
}

class _FilterEditorState extends State<FilterEditor> {
	late final TextEditingController regexController;
	late final FocusNode regexFocusNode;
	bool dirty = false;

	@override
	void initState() {
		super.initState();
		regexController = TextEditingController(text: context.read<EffectiveSettings>().filterConfiguration);
		regexFocusNode = FocusNode();
	}

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<EffectiveSettings>();
		final filters = <int, CustomFilter>{};
		for (final line in settings.filterConfiguration.split('\n').asMap().entries) {
			if (line.value.isEmpty) {
				continue;
			}
			try {
				filters[line.key] = CustomFilter.fromStringConfiguration(line.value);
			}
			on FilterException {
				// don't show
			}
		}
		if (widget.forBoard != null) {
			filters.removeWhere((k, v) {
				return v.excludeBoards.contains(widget.forBoard!) || (v.boards.isNotEmpty && !v.boards.contains(widget.forBoard!));
			});
		}
		Future<Tuple2<bool, CustomFilter?>?> editFilter(CustomFilter? originalFilter) {
			final filter = originalFilter ?? widget.blankFilter ?? CustomFilter(
				configuration: '',
				pattern: RegExp('', caseSensitive: false)
			);
			final patternController = TextEditingController(text: filter.pattern.pattern);
			bool isCaseSensitive = filter.pattern.isCaseSensitive;
			final labelController = TextEditingController(text: filter.label);
			final patternFields = filter.patternFields.toList();
			bool? hasFile = filter.hasFile;
			bool threadOnly = filter.threadOnly;
			final List<String> boards = filter.boards.toList();
			final List<String> excludeBoards = filter.excludeBoards.toList();
			int? minRepliedTo = filter.minRepliedTo;
			bool hide = filter.outputType.hide;
			bool highlight = filter.outputType.highlight;
			bool pinToTop = filter.outputType.pinToTop;
			bool autoSave = filter.outputType.autoSave;
			bool notify = filter.outputType.notify;
			const labelStyle = TextStyle(fontWeight: FontWeight.bold);
			return showCupertinoModalPopup<Tuple2<bool, CustomFilter?>>(
				context: context,
				builder: (context) => StatefulBuilder(
					builder: (context, setInnerState) => CupertinoActionSheet(
						title: const Text('Edit filter'),
						message: DefaultTextStyle(
							style: DefaultTextStyle.of(context).style,
							child: Column(
								mainAxisSize: MainAxisSize.min,
								crossAxisAlignment: CrossAxisAlignment.center,
								children: [
									const Text('Label', style: labelStyle),
									Padding(
										padding: const EdgeInsets.all(16),
										child: SizedBox(
											width: 300,
											child: CupertinoTextField(
												controller: labelController
											)
										)
									),
									const Text('Pattern', style: labelStyle),
									Padding(
										padding: const EdgeInsets.all(16),
										child: SizedBox(
											width: 300,
											child: CupertinoTextField(
												controller: patternController,
												autocorrect: false,
												enableIMEPersonalizedLearning: false,
												enableSuggestions: false
											)
										)
									),
									ClipRRect(
										borderRadius: BorderRadius.circular(8),
										child: CupertinoListSection(
											topMargin: 0,
											margin: EdgeInsets.zero,
											children: [
												CupertinoListTile(
													title: const Text('Case-sensitive'),
													trailing: isCaseSensitive ? const Icon(CupertinoIcons.check_mark) : const SizedBox.shrink(),
													onTap: () {
														isCaseSensitive = !isCaseSensitive;
														setInnerState(() {});
													}
												)
											]
										)
									),
									const SizedBox(height: 16),
									const Text('Search in fields', style: labelStyle),
									const SizedBox(height: 16),
									ClipRRect(
										borderRadius: BorderRadius.circular(8),
										child: CupertinoListSection(
											topMargin: 0,
											margin: EdgeInsets.zero,
											children: [
												for (final field in allPatternFields) CupertinoListTile(
													title: Text(const{
														'text': 'Text',
														'subject': 'Subject',
														'name': 'Name',
														'filename': 'Filename',
														'postID': 'Post ID',
														'posterID': 'Poster ID',
														'flag': 'Flag'
													}[field] ?? field),
													trailing: patternFields.contains(field) ? const Icon(CupertinoIcons.check_mark) : const SizedBox.shrink(),
													onTap:() {
														if (patternFields.contains(field)) {
															patternFields.remove(field);
														}
														else {
															patternFields.add(field);
														}
														setInnerState(() {});
													}
												)
											]
										)
									),
									const SizedBox(height: 16),
									Container(
										padding: const EdgeInsets.all(16),
										alignment: Alignment.center,
										child: CupertinoSegmentedControl<NullSafeOptional>(
											groupValue: hasFile.value,
											onValueChanged: (v) {
												setInnerState(() {
													hasFile = v.value;
												});
											},
											children: const {
												NullSafeOptional.null_: Padding(
													padding: EdgeInsets.all(8),
													child: Text('All posts', textAlign: TextAlign.center)
												),
												NullSafeOptional.false_: Padding(
													padding: EdgeInsets.all(8),
													child: Text('Without images', textAlign: TextAlign.center)
												),
												NullSafeOptional.true_: Padding(
													padding: EdgeInsets.all(8),
													child: Text('With images', textAlign: TextAlign.center)
												)
											}
										)
									),
									Padding(
										padding: const EdgeInsets.all(16),
										child: CupertinoSegmentedControl<bool>(
											groupValue: threadOnly,
											onValueChanged: (v) {
												setInnerState(() {
													threadOnly = v;
												});
											},
											children: const {
												false: Padding(
													padding: EdgeInsets.all(8),
													child: Text('All posts')
												),
												true: Padding(
													padding: EdgeInsets.all(8),
													child: Text('Threads only')
												)
											}
										)
									),
									const SizedBox(height: 16),
									CupertinoButton.filled(
										padding: const EdgeInsets.all(16),
										onPressed: () async {
											await editStringList(
												context: context,
												list: boards,
												name: 'board',
												title: 'Edit boards'
											);
											setInnerState(() {});
										},
										child: Text(boards.isEmpty ? 'All boards' : 'Only on ${boards.map((b) => '/$b/').join(', ')}')
									),
									const SizedBox(height: 16),
									CupertinoButton.filled(
										padding: const EdgeInsets.all(16),
										onPressed: () async {
											await editStringList(
												context: context,
												list: excludeBoards,
												name: 'excluded board',
												title: 'Edit excluded boards'
											);
											setInnerState(() {});
										},
										child: Text(excludeBoards.isEmpty ? 'No excluded boards' : 'Exclude ${excludeBoards.map((b) => '/$b/').join(', ')}')
									),
									const SizedBox(height: 16),
									CupertinoButton.filled(
										padding: const EdgeInsets.all(16),
										onPressed: () async {
											final controller = TextEditingController(text: minRepliedTo?.toString());
											await showCupertinoDialog(
												context: context,
												barrierDismissible: true,
												builder: (context) => CupertinoAlertDialog(
													title: const Text('Set minimum replied-to posts count'),
													actions: [
														CupertinoButton(
															child: const Text('Clear'),
															onPressed: () {
																controller.text = '';
																Navigator.pop(context);
															}
														),
														CupertinoButton(
															child: const Text('Close'),
															onPressed: () => Navigator.pop(context)
														)
													],
													content: Padding(
														padding: const EdgeInsets.only(top: 16),
														child: CupertinoTextField(
															autofocus: true,
															keyboardType: TextInputType.number,
															controller: controller,
															onSubmitted: (s) {
																Navigator.pop(context);
															}
														)
													)
												)
											);
											minRepliedTo = int.tryParse(controller.text);
											controller.dispose();
											setInnerState(() {});
										},
										child: Text(minRepliedTo == null ? 'No replied-to criteria' : 'With at least $minRepliedTo replied-to posts')
									),
									const SizedBox(height: 16),
									const Text('Action', style: labelStyle),
									Container(
										padding: const EdgeInsets.all(16),
										alignment: Alignment.center,
										child: ClipRRect(
											borderRadius: BorderRadius.circular(8),
											child: CupertinoListSection(
												topMargin: 0,
												margin: EdgeInsets.zero,
												children: [
													CupertinoListTile(
														title: const Text('Hide'),
														trailing: hide ? const Icon(CupertinoIcons.check_mark) : const SizedBox.shrink(),
														onTap: () {
															if (!hide) {
																hide = true;
																highlight = false;
																pinToTop = false;
																autoSave = false;
																notify = false;
															}
															setInnerState(() {});
														}
													)
												]
											)
										)
									),
									Container(
										padding: const EdgeInsets.all(16),
										alignment: Alignment.center,
										child: ClipRRect(
											borderRadius: BorderRadius.circular(8),
											child: CupertinoListSection(
												topMargin: 0,
												margin: EdgeInsets.zero,
												children: [
													Tuple3('Highlight', highlight, (v) => highlight = v),
													Tuple3('Pin-to-top', pinToTop, (v) => pinToTop = v),
													Tuple3('Auto-save', autoSave, (v) => autoSave = v),
													Tuple3('Notify', notify, (v) => notify = v),
												].map((t) => CupertinoListTile(
													title: Text(t.item1),
													trailing: t.item2 ? const Icon(CupertinoIcons.check_mark) : const SizedBox.shrink(),
													onTap: () {
														t.item3(!t.item2);
														hide = !(highlight || pinToTop || autoSave || notify);
														setInnerState(() {});
													},
												)).toList()
											)
										)
									)
								]
							)
						),
						actions: [
							if (originalFilter != null) CupertinoDialogAction(
								isDestructiveAction: true,
								onPressed: () => Navigator.pop(context, const Tuple2(true, null)),
								child: const Text('Delete')
							),
							CupertinoDialogAction(
								onPressed: () {
									Navigator.pop(context, Tuple2(false, CustomFilter(
										pattern: RegExp(patternController.text, caseSensitive: isCaseSensitive),
										patternFields: patternFields,
										boards: boards,
										excludeBoards: excludeBoards,
										hasFile: hasFile,
										threadOnly: threadOnly,
										minRepliedTo: minRepliedTo,
										outputType: FilterResultType(
											hide: hide,
											highlight: highlight,
											pinToTop: pinToTop,
											autoSave: autoSave,
											notify: notify
										),
										label: labelController.text
									)));
								},
								child: originalFilter == null ? const Text('Add') : const Text('Save')
							)
						],
						cancelButton: CupertinoDialogAction(
							onPressed: () => Navigator.pop(context),
							child: const Text('Cancel')
						)
					)
				)
			);
		}
		return AnimatedSize(
			duration: const Duration(milliseconds: 350),
			curve: Curves.ease,
			alignment: Alignment.topCenter,
			child: AnimatedSwitcher(
				duration: const Duration(milliseconds: 350),
				switchInCurve: Curves.ease,
				switchOutCurve: Curves.ease,
				child: widget.showRegex ? Column(
					mainAxisSize: MainAxisSize.min,
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						Wrap(
							crossAxisAlignment: WrapCrossAlignment.center,
							alignment: WrapAlignment.start,
							spacing: 16,
							runSpacing: 16,
							children: [
								CupertinoButton(
									minSize: 0,
									padding: EdgeInsets.zero,
									child: const Icon(CupertinoIcons.question_circle),
									onPressed: () {
										showCupertinoModalPopup(
											context: context,
											builder: (context) => CupertinoActionSheet(
												message: Text.rich(
													buildFakeMarkdown(context,
														'One regular expression per line, lines starting with # will be ignored\n'
														'Example: `/sneed/` will hide any thread or post containing "sneed"\n'
														'Example: `/bane/;boards:tv;thread` will hide any thread containing "sneed" in the OP on /tv/\n'
														'Add `i` after the regex to make it case-insensitive\n'
														'Example: `/sneed/i` will match `SNEED`\n'
														'You can write text before the opening slash to give the filter a label: `Funposting/bane/i`'
														'\n'
														'Qualifiers may be added after the regex:\n'
														'`;boards:<list>` Only apply on certain boards\n'
														'Example: `;board:tv,mu` will only apply the filter on /tv/ and /mu/\n'
														'`;exclude:<list>` Don\'t apply on certain boards\n'
														'`;highlight` Highlight instead of hiding matches\n'
														'`;top` Pin match to top of list instead of hiding\n'
														'`;save` Send a push notification (if enabled) for matches\n'
														'`;notify` Automatically save matching threads\n'
														'`;file:only` Only apply to posts with files\n'
														'`;file:no` Only apply to posts without files\n'
														'`;thread` Only apply to threads\n'
														'`;type:<list>` Only apply regex filter to certain fields\n'
														'The list of possible fields is $allPatternFields\n'
														'The default fields that are searched are $defaultPatternFields'
													),
													textAlign: TextAlign.left,
													style: const TextStyle(
														fontSize: 16,
														height: 1.5
													)
												)
											)
										);
									}
								),
								if (dirty) CupertinoButton(
									padding: EdgeInsets.zero,
									minSize: 0,
									child: const Text('Save'),
									onPressed: () {
										settings.filterConfiguration = regexController.text;
										regexFocusNode.unfocus();
										setState(() {
											dirty = false;
										});
									}
								)
							]
						),
						const SizedBox(height: 16),
						CupertinoTextField(
							style: GoogleFonts.ibmPlexMono(),
							minLines: 5,
							maxLines: 5,
							focusNode: regexFocusNode,
							controller: regexController,
							enableSuggestions: false,
							enableIMEPersonalizedLearning: false,
							autocorrect: false,
							onChanged: (_) {
								if (!dirty) {
									setState(() {
										dirty = true;
									});
								}
							}
						)
					]
				) : ClipRRect(
					borderRadius: BorderRadius.circular(8),
					child: CupertinoListSection(
						topMargin: 0,
						margin: EdgeInsets.zero,
						children: [
							...filters.entries.map((filter) {
								final icons = [
									if (filter.value.outputType.hide) const Icon(CupertinoIcons.eye_slash),
									if (filter.value.outputType.highlight) const Icon(CupertinoIcons.sun_max_fill),
									if (filter.value.outputType.pinToTop) const Icon(CupertinoIcons.arrow_up_to_line),
									if (filter.value.outputType.autoSave) const Icon(CupertinoIcons.bookmark_fill),
									if (filter.value.outputType.notify) const Icon(CupertinoIcons.bell_fill)
								];
								return Row(
									children: [
										Expanded(
											child: Opacity(
												opacity: filter.value.disabled ? 0.5 : 1,
												child: CupertinoListTile(
													title: Text(filter.value.label.isNotEmpty ? filter.value.label : filter.value.pattern.pattern),
													leading: FittedBox(fit: BoxFit.contain, child: Column(
														mainAxisAlignment: MainAxisAlignment.spaceBetween,
														children: [
															for (int i = 0; i < icons.length; i += 2) Row(
																mainAxisAlignment: MainAxisAlignment.spaceBetween,
																children: [
																	if (i < icons.length) icons[i],
																	if ((i + 1) < icons.length) icons[i + 1]
																]
															)
														]
													)),
													subtitle: Text.rich(
														TextSpan(
															children: [
																if (filter.value.minRepliedTo != null) TextSpan(text: 'Replying to >=${filter.value.minRepliedTo}'),
																if (filter.value.threadOnly) const TextSpan(text: 'Threads only'),
																if (filter.value.hasFile == true) const WidgetSpan(
																	child: Icon(CupertinoIcons.doc)
																)
																else if (filter.value.hasFile == false) WidgetSpan(
																	child: Stack(
																		children: const [
																			Icon(CupertinoIcons.doc),
																			Icon(CupertinoIcons.xmark)
																		]
																	)
																),
																for (final board in filter.value.boards) TextSpan(text: '/$board/'),
																for (final board in filter.value.excludeBoards) TextSpan(text: 'not /$board/'),
																if (!setEquals(filter.value.patternFields.toSet(), defaultPatternFields.toSet()))
																	for (final field in filter.value.patternFields) TextSpan(text: field)
															].expand((x) => [const TextSpan(text: ', '), x]).skip(1).toList()
														),
														overflow: TextOverflow.ellipsis
													),
													onTap: () async {
														final newFilter = await editFilter(filter.value);
														if (newFilter != null) {
															final lines = settings.filterConfiguration.split('\n');
															if (newFilter.item1) {
																lines.removeAt(filter.key);
															}
															else {
																lines[filter.key] = newFilter.item2!.toStringConfiguration();
															}
															settings.filterConfiguration = lines.join('\n');
															regexController.text = settings.filterConfiguration;
														}
													}
												)
											)
										),
										Material(
											type: MaterialType.transparency,
											child: Checkbox(
												activeColor: CupertinoTheme.of(context).primaryColor,
												checkColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
												fillColor: MaterialStateColor.resolveWith((states) => CupertinoTheme.of(context).primaryColor),
												value: !filter.value.disabled,
												onChanged: (value) {
													filter.value.disabled = !filter.value.disabled;
													final lines = settings.filterConfiguration.split('\n');
													lines[filter.key] = filter.value.toStringConfiguration();
													settings.filterConfiguration = lines.join('\n');
													regexController.text = settings.filterConfiguration;
												}
											)
										)
									]
								);
							}),
							if (filters.isEmpty) CupertinoListTile(
								title: const Text('Suggestion: Add a mass-reply filter'),
								leading: const Icon(CupertinoIcons.lightbulb),
								onTap: () async {
									settings.filterConfiguration += '\nMass-reply//;minReplied:10';
									regexController.text = settings.filterConfiguration;
								}
							),
							CupertinoListTile(
								title: const Text('New filter'),
								leading: const Icon(CupertinoIcons.plus),
								onTap: () async {
									final newFilter = await editFilter(null);
									if (newFilter?.item2 != null) {
										settings.filterConfiguration += '\n${newFilter!.item2!.toStringConfiguration()}';
										regexController.text = settings.filterConfiguration;
									}
								}
							)
						]
					)
				)
			)
		);
	}

	@override
	void dispose() {
		super.dispose();
		regexController.dispose();
		regexFocusNode.dispose();
	}
}
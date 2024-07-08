import 'dart:convert';

import 'package:chan/models/search.dart';
import 'package:chan/services/pick_attachment.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/util.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';


enum _MediaFilter {
	none,
	onlyWithMedia,
	onlyWithNoMedia,
	withSpecificMedia
}

extension _ConvertToPublic on _MediaFilter {
	MediaFilter? get value {
		switch (this) {
			case _MediaFilter.none:
				return MediaFilter.none;
			case _MediaFilter.onlyWithMedia:
				return MediaFilter.onlyWithMedia;
			case _MediaFilter.onlyWithNoMedia:
				return MediaFilter.onlyWithNoMedia;
			default:
				return null;
		}
	}
}

extension _ConvertToPrivate on MediaFilter {
	_MediaFilter? get value {
		switch (this) {
			case MediaFilter.none:
				return _MediaFilter.none;
			case MediaFilter.onlyWithMedia:
				return _MediaFilter.onlyWithMedia;
			case MediaFilter.onlyWithNoMedia:
				return _MediaFilter.onlyWithNoMedia;
		}
	}
}

class SearchQueryEditor extends StatefulWidget {
	final ImageboardArchiveSearchQuery query;
	final VoidCallback onChanged;
	final VoidCallback onSubmitted;
	final VoidCallback? onPickerShow;
	final VoidCallback? onPickerHide;
	final double? knownWidth;

	const SearchQueryEditor({
		required this.query,
		required this.onChanged,
		required this.onSubmitted,
		this.onPickerShow,
		this.onPickerHide,
		this.knownWidth,
		super.key
	});

	@override
	createState() => _SearchQueryEditorState();
}

class _SearchQueryEditorState extends State<SearchQueryEditor> {
	late ImageboardArchiveSearchQuery _lastQuery;
	late final TextEditingController _subjectFieldController;
	late final TextEditingController _nameFieldController;
	late final TextEditingController _tripFieldController;

	@override
	void initState() {
		super.initState();
		_lastQuery = widget.query;
		_subjectFieldController = TextEditingController();
		_nameFieldController = TextEditingController();
		_tripFieldController = TextEditingController();
	}

	@override
	void didUpdateWidget(SearchQueryEditor oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (widget.query != _lastQuery) {
			// Mutated above
			_subjectFieldController.text = widget.query.subject ?? '';
			_nameFieldController.text = widget.query.name ?? '';
			_tripFieldController.text = widget.query.trip ?? '';
		}
	}

	@override
	Widget build(BuildContext context) {
		final query = widget.query;
		final imageboard = query.imageboard;
		final support = imageboard?.site.supportsSearch(query.boards.tryFirst);
		final options = support?.options ?? const ImageboardSearchOptions();
		return Column(
			mainAxisSize: MainAxisSize.min,
			children: [
				const SizedBox(height: 16),
				if (options.supportedPostTypeFilters.length > 1) ...[
					AdaptiveChoiceControl<PostTypeFilter>(
						knownWidth: widget.knownWidth,
						children: {
							for (final type in options.supportedPostTypeFilters)
								type: switch (type) {
									PostTypeFilter.none => (null, 'All posts'),
									PostTypeFilter.onlyOPs => (null, 'Threads'),
									PostTypeFilter.onlyReplies => (null, 'Replies'),
									PostTypeFilter.onlyStickies => (null, 'Stickies')
								}
						},
						groupValue: query.postTypeFilter,
						onValueChanged: (newValue) {
							query.postTypeFilter = newValue;
							widget.onChanged();
						}
					),
					const SizedBox(height: 16),
				],
				if (options.withMedia || options.imageMD5) ...[
					AdaptiveChoiceControl<_MediaFilter>(
						knownWidth: widget.knownWidth,
						children: {
							_MediaFilter.none: (null, 'All posts'),
							if (options.withMedia) _MediaFilter.onlyWithMedia: (null, 'With images'),
							if (options.withMedia) _MediaFilter.onlyWithNoMedia: (null, 'Without images'),
							if (options.imageMD5) _MediaFilter.withSpecificMedia: (null, 'With MD5')
						},
						groupValue: query.md5 == null ? query.mediaFilter.value : _MediaFilter.withSpecificMedia,
						onValueChanged: (newValue) async {
							if (newValue.value != null) {
								query.md5 = null;
								query.mediaFilter = newValue.value!;
							}
							else {
								widget.onPickerShow?.call();
								final controller = TextEditingController(text: query.md5);
								final md5Str = await showAdaptiveModalPopup<String>(
									context: context,
									builder: (context) => AdaptiveAlertDialog(
										title: const Text('Search by MD5'),
										content: AdaptiveTextField(
											controller: controller,
											placeholder: 'MD5',
											maxLines: 5,
											onSubmitted: (s) => Navigator.pop(context, s)
										),
										actions: [
											AdaptiveDialogAction(
												isDefaultAction: true,
												child: const Text('OK'),
												onPressed: () => Navigator.pop(context, controller.text)
											),
											AdaptiveDialogAction(	
												child: const Text('Pick file'),
												onPressed: () async {
													final file = await pickAttachment(context: context);
													if (file != null && context.mounted) {
														controller.text = base64Encode((await md5.bind(file.openRead()).first).bytes);
													}
												}
											),
											AdaptiveDialogAction(
												child: const Text('Cancel'),
												onPressed: () => Navigator.pop(context)
											)
										]
									)
								);
								controller.dispose();
								widget.onPickerHide?.call();
								if (md5Str == null) {
									// Cancelled
								}
								else {
									query.md5 = md5Str.nonEmptyOrNull;
									query.mediaFilter = MediaFilter.none;
								}
							}
							widget.onChanged();
						}
					),
					const SizedBox(height: 16),
				],
				if (options.isDeleted) ...[
					AdaptiveChoiceControl<PostDeletionStatusFilter>(
						knownWidth: widget.knownWidth,
						children: const {
							PostDeletionStatusFilter.none: (null, 'All posts'),
							PostDeletionStatusFilter.onlyDeleted: (null, 'Only deleted'),
							PostDeletionStatusFilter.onlyNonDeleted: (null, 'Only non-deleted')
						},
						groupValue: query.deletionStatusFilter,
						onValueChanged: (newValue) {
							query.deletionStatusFilter = newValue;
							widget.onChanged();
						}
					),
					const SizedBox(height: 16),
				],
				if (options.date) ...[
					Wrap(
						runSpacing: 16,
						alignment: WrapAlignment.center,
						runAlignment: WrapAlignment.center,
						children: [
							Container(
								padding: const EdgeInsets.symmetric(horizontal: 8),
								child: AdaptiveThinButton(
									filled: query.startDate != null,
									child: Text(
										(query.startDate != null) ? 'Posted after ${query.startDate!.toISO8601Date}' : 'Posted after...',
										textAlign: TextAlign.center
									),
									onPressed: () async {
										widget.onPickerShow?.call();
										final newDate = await pickDate(
											context: context,
											initialDate: query.startDate
										);
										widget.onPickerHide?.call();
										query.startDate = newDate;
										widget.onChanged();
									}
								)
							),
							Container(
								padding: const EdgeInsets.symmetric(horizontal: 8),
								child: AdaptiveThinButton(
									filled: query.endDate != null,
									child: Text(
										(query.endDate != null) ? 'Posted before ${query.endDate!.toISO8601Date}' : 'Posted before...',
										textAlign: TextAlign.center
									),
									onPressed: () async {
										widget.onPickerShow?.call();
										final newDate = await pickDate(
											context: context,
											initialDate: query.endDate
										);
										widget.onPickerHide?.call();
										query.endDate = newDate;
										widget.onChanged();
									}
								)
							)
						]
					),
				],
				if (options.name || options.subject || options.trip) Wrap(
					alignment: WrapAlignment.center,
					runAlignment: WrapAlignment.center,
					children: [
						for (final field in [
							if (options.subject) (
								name: 'Subject',
								cb: (String s) => query.subject = s,
								controller: _subjectFieldController
							),
							if (options.name) (
								name: 'Name',
								cb: (String s) => query.name = s,
								controller: _nameFieldController
							),
							if (options.trip) (
								name: 'Trip',
								cb: (String s) => query.trip = s,
								controller: _tripFieldController
							)
						]) Container(
							width: 200,
							padding: const EdgeInsets.all(16),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Text(field.name),
									const SizedBox(height: 4),
									AdaptiveTextField(
										controller: field.controller,
										onChanged: field.cb
									)
								]
							)
						)
					]
				),
				if (options.imageMD5 && query.md5 != null) Container(
					padding: const EdgeInsets.only(top: 16),
					alignment: Alignment.center,
					child: Text('MD5: ${query.md5}')
				),
				Container(
					padding: const EdgeInsets.only(top: 16),
					alignment: Alignment.center,
					child: AdaptiveFilledButton(
						onPressed: widget.onSubmitted,
						child: const Text('Search')
					)
				)
			]
		);
	}

	@override
	void dispose() {
		super.dispose();
		_subjectFieldController.dispose();
		_nameFieldController.dispose();
		_tripFieldController.dispose();
	}
}

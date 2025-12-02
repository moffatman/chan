import 'dart:math';

import 'package:chan/services/apple.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/util.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

Future<T?> pick<T>({
	required BuildContext context,
	required List<T> items,
	required String Function(T) getName,
	String Function(T)? getCode,
	required Widget Function(T) itemBuilder,
	required T? selectedItem,
}) async {
	final picked = await Navigator.push<Wrapper<T>>(context, TransparentRoute(
		builder: (context) => PickerPage<T>(
			selectedItem: selectedItem,
			itemBuilder: itemBuilder,
			getName: getName,
			getCode: getCode,
			items: items
		)
	));
	if (picked != null) {
		return picked.value;
	}
	// If they popped it, just return original selection
	return selectedItem;
}

class _Item<T> {
	final T item;
	final String string;
	final int matchIndex;
	final bool exactMatch;

	const _Item({
		required this.item,
		required this.string,
		required this.matchIndex,
		required this.exactMatch
	});

	@override
	String toString() => '_Item<$T>(item: $item, string: $string, matchIndex: $matchIndex, exactMatch: $exactMatch)';

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is _Item &&
		other.item == item &&
		other.string == string &&
		other.matchIndex == matchIndex &&
		other.exactMatch == exactMatch;
	
	@override
	int get hashCode => Object.hash(item, string, matchIndex, exactMatch);
}

class PickerPage<T> extends StatefulWidget {
	final List<T> items;
	final Widget Function(T) itemBuilder;
	final String Function(T) getName;
	final String? Function(T)? getCode;
	final T? selectedItem;

	const PickerPage({
		required this.items,
		required this.itemBuilder,
		required this.getName,
		required this.getCode,
		required this.selectedItem,
		super.key
	});

	@override
	createState() => _PickerPageState<T>();
}

class _PickerPageState<T> extends State<PickerPage<T>> {
	late final FocusNode _focusNode;

	String searchString = '';
	late final ScrollController scrollController;
	late final ValueNotifier<Color?> _backgroundColor;
	int _pointersDownCount = 0;
	bool _popping = false;
	int _selectedIndex = 0;
	bool _showSelectedItem = isOnMac;
	late TextEditingController _textEditingController;
	final Map<T?, BuildContext> _contexts = {};

	static const _kRowHeight = 64.0;

	bool isPhoneSoftwareKeyboard() {
		return MediaQueryData.fromView(View.of(context)).viewInsets.bottom > 100;
	}

	@override
	void initState() {
		super.initState();
		scrollController = ScrollController();
		_backgroundColor = ValueNotifier<Color?>(null);
		_focusNode = FocusNode();
		scrollController.addListener(_onScroll);
		_textEditingController = TextEditingController();
	}

	List<T> getFilteredItems() {
		final keywords = searchString.toLowerCase().split(' ').where((s) => s.isNotEmpty).map((s) => (str: s, fin: true)).toList();
		if (keywords.tryLast?.str case String str when !searchString.endsWith(' ')) {
			keywords.last = (str: str, fin: false);
		}
		final filteredItems = widget.items.tryMap((item) {
			final name = widget.getName(item).toLowerCase();
			final code = widget.getCode?.call(item)?.toLowerCase();
			/// For GB = United Kingdom, synthesize UK, etc
			String? synthCode;
			if (name.contains(' ')) {
				synthCode = name.split(' ').map((s) => s[0]).join('');
				if (synthCode == code) {
					synthCode = null;
				}
			}
			bool exactMatch = false;
			int bestMatchIndex = -1;
			for (final (str: keyword, fin:_) in keywords) {
				final nameIndex = name.indexOf(keyword);
				final codeIndex = code?.indexOf(keyword) ?? -1;
				final synthCodeIndex = synthCode?.indexOf(keyword) ?? -1;
				if (nameIndex == -1 && codeIndex == -1 && synthCodeIndex == -1) {
					return null;
				}
				if ((codeIndex == 0 && code?.length == keyword.length) || (nameIndex == 0 && name.length == keyword.length) || (synthCodeIndex == 0 && synthCode?.length == keyword.length)) {
					bestMatchIndex = 0;
					exactMatch = true;
				}
				else if (bestMatchIndex == -1 || (codeIndex != -1 && codeIndex < bestMatchIndex) || (nameIndex != -1 && nameIndex < bestMatchIndex) || (synthCodeIndex != -1 && synthCodeIndex < bestMatchIndex)) {
					bestMatchIndex = codeIndex == -1 ? (synthCodeIndex == -1 ? nameIndex : synthCodeIndex) : codeIndex;
				}
			}
			return _Item(
				item: item,
				string: name,
				matchIndex: bestMatchIndex,
				exactMatch: exactMatch
			);
		}).toList();
		if (keywords.isEmpty) {
			filteredItems.sort((a, b) {
				if (a.item == null && b.item == null) {
					return 0;
				}
				else if (a.item == null) {
					return -1;
				}
				else if (b.item == null) {
					return 1;
				}
				return a.string.compareTo(b.string);
			});
		}
		else {
			filteredItems.sort((a, b) {
				if (a.exactMatch && !b.exactMatch) {
					return -1;
				}
				if (b.exactMatch && !a.exactMatch) {
					return 1;
				}
				final matchComparison = a.matchIndex - b.matchIndex;
				if (matchComparison != 0) {
					return matchComparison;
				}
				return a.string.compareTo(b.string);
			});
		}
		return filteredItems.map((b) => b.item).toList();
	}

	void _checkForKeyboard() {
		if (!mounted) {
			return;
		}
		if (!_focusNode.hasFocus) {
			return;
		}
		_showSelectedItem = !isPhoneSoftwareKeyboard();
		setState(() {});
	}

	double _getOverscroll() {
		final position = scrollController.tryPosition;
		if (position == null) {
			return 0;
		}
		final overscrollTop = position.minScrollExtent - position.pixels;
		final overscrollBottom = position.pixels - position.maxScrollExtent;
		return max(overscrollTop, overscrollBottom);
	}

	void _onScroll() async {
		if (_focusNode.hasFocus && isPhoneSoftwareKeyboard() && ((scrollController.tryPosition?.extentAfter ?? 0) > (MediaQueryData.fromView(View.of(context)).viewInsets.bottom + 100))) {
			_focusNode.unfocus();
		}
		final backgroundColor = context.read<SavedTheme>().backgroundColor;
		final overscroll1 = _getOverscroll();
		await Future.delayed(const Duration(milliseconds: 50));
		if (mounted) {
			_backgroundColor.value = backgroundColor.withValues(alpha: 1.0 - max(0, min(overscroll1, _getOverscroll()) / 50).clamp(0, 1));
		}
	}

	void _afterScroll() {
		if (!_popping && _pointersDownCount == 0) {
			if (_getOverscroll() > 50) {
				_popping = true;
				lightHapticFeedback();
				Navigator.pop(context);
			}
		}
	}

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<Settings>();
		final theme = context.watch<SavedTheme>();
		_backgroundColor.value ??= theme.backgroundColor;
		final filteredItems = getFilteredItems();
		final effectiveSelectedIndex = filteredItems.isEmpty ? 0 : _selectedIndex.clamp(0, filteredItems.length - 1);
		return AdaptiveScaffold(
			disableAutoBarHiding: true,
			resizeToAvoidBottomInset: false,
			backgroundColor: Colors.transparent,
			bar: AdaptiveBar(
				title: FractionallySizedBox(
					widthFactor: 0.75,
					child: CallbackShortcuts(
						bindings: {
							LogicalKeySet(LogicalKeyboardKey.arrowDown): () {
								if (effectiveSelectedIndex < filteredItems.length - 1) {
									setState(() {
										_selectedIndex++;
									});
									final context = _contexts[filteredItems[_selectedIndex]];
									if (context != null) {
										Scrollable.ensureVisible(context, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
									}
								}
							},
							LogicalKeySet(LogicalKeyboardKey.arrowUp): () {
								if (effectiveSelectedIndex > 0) {
									setState(() {
										_selectedIndex--;
									});
									final context = _contexts[filteredItems[_selectedIndex]];
									if (context != null) {
										Scrollable.ensureVisible(context, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart);
									}
								}
							}
						},
						child: AdaptiveTextField(
							autofocus: settings.boardSwitcherHasKeyboardFocus,
							enableIMEPersonalizedLearning: settings.enableIMEPersonalizedLearning,
							smartDashesType: SmartDashesType.disabled,
							smartQuotesType: SmartQuotesType.disabled,
							autocorrect: false,
							placeholder: 'Search...',
							textAlign: TextAlign.center,
							focusNode: _focusNode,
							enableSuggestions: false,
							suffixMode: OverlayVisibilityMode.editing,
							controller: _textEditingController,
							suffix: Padding(
								padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 5, 2),
								child: AdaptiveIconButton(
									onPressed: () {
										_textEditingController.clear();
										setState(() {
											searchString = '';
										});
									},
									minimumSize: Size.zero,
									padding: EdgeInsets.zero,
									icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 20, applyTextScaling: true)
								)
							),
							onTap: () {
								if (scrollController.hasOnePosition) {
									scrollController.jumpTo(scrollController.position.pixels);
								}
								if (!_showSelectedItem) {
									Future.delayed(const Duration(milliseconds: 500), _checkForKeyboard);
								}
							},
							onSubmitted: (String board) {
								if (filteredItems.isNotEmpty) {
									final selected = filteredItems[effectiveSelectedIndex];
									lightHapticFeedback();
									Navigator.pop(context, Wrapper<T>(selected));
								}
								_focusNode.requestFocus();
							},
							onChanged: (String newSearchString) {
								// Jump to start, or else we might end up deeply overscrolled (blurred)
								if (scrollController.hasOnePosition) {
									scrollController.jumpTo(0);
								}
								setState(() {
									searchString = newSearchString;
								});
							}
						)
					)
				)
			),
			body: Listener(
				onPointerDown: (event) {
					_pointersDownCount++;
				},
				onPointerCancel: (event) {
					_pointersDownCount--;
				},
				onPointerUp: (event) {
					_pointersDownCount--;
					_afterScroll();
				},
				onPointerPanZoomStart: (event) {
					_pointersDownCount++;
				},
				onPointerPanZoomEnd: (event) {
					_pointersDownCount--;
					_afterScroll();
				},
				child: Stack(
					children: [
						ValueListenableBuilder<Color?>(
							valueListenable: _backgroundColor,
							builder: (context, color, child) => Container(
								color: color
							)
						),
						(filteredItems.isEmpty) ? const Center(
							child: Text('No matching items')
						) : Builder(
							builder: (context) => ListView.separated(
								physics: const AlwaysScrollableScrollPhysics(),
								controller: scrollController,
								padding: const EdgeInsets.only(top: 4, bottom: 4) + MediaQuery.paddingOf(context),
								separatorBuilder: (context, i) => const SizedBox(height: 2),
								itemCount: filteredItems.length,
								findChildIndexCallback: (key) {
									if (key case ValueKey(value: int index)) {
										return index;
									}
									return null;
								},
								itemBuilder: (context, i) {
									final item = filteredItems[i];
									final isSelected = _showSelectedItem && i == effectiveSelectedIndex;
									return BuildContextMapRegistrant(
										key: ValueKey(i),
										map: _contexts,
										value: filteredItems[i],
										child: CupertinoButton(
											padding: EdgeInsets.zero,
											child: Container(
												padding: const EdgeInsets.all(4),
												height: _kRowHeight,
												decoration: BoxDecoration(
													borderRadius: const BorderRadius.all(Radius.circular(4)),
													color: theme.primaryColor.withValues(alpha: isSelected ? 0.3 : 0.1)
												),
												child: Row(
													children: [
														const SizedBox(width: 16),
														Expanded(
															child: widget.itemBuilder(item)
														),
														if (item == widget.selectedItem) const Padding(
															padding: EdgeInsets.symmetric(horizontal: 8),
															child: Icon(CupertinoIcons.check_mark, size: 20)
														),
														const SizedBox(width: 8)
													]
												)
											),
											onPressed: () {
												lightHapticFeedback();
												Navigator.pop(context, Wrapper<T>(item));
											}
										)
									);
								}
							)
						)
					]
				)
			)
		);
	}

	@override
	void dispose() {
		super.dispose();
		scrollController.dispose();
		_backgroundColor.dispose();
		_focusNode.dispose();
		_textEditingController.dispose();
	}
}

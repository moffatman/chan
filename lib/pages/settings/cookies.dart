import 'dart:io' show SameSite;

import 'package:chan/services/cookies.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/util.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/cupertino_inkwell.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:chan/widgets/util.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum _CookieTreeItemType {
	domain,
	host,
	cookie;
}

class _CookieTreeItem {
	final int id;
	final int? parentId;
	final _CookieTreeItemType type;
	final String label;
	final int childCount;
	final StoredCookie? storedCookie;
	final String? newCookieHost;
	final String? newCookieDomain;

	const _CookieTreeItem({
		required this.id,
		required this.parentId,
		required this.type,
		required this.label,
		this.childCount = 0,
		this.storedCookie,
		this.newCookieHost,
		this.newCookieDomain
	});
}

class _CookieGroupRow extends StatelessWidget {
	final _CookieTreeItem item;
	final bool collapsed;
	final VoidCallback onAdd;

	const _CookieGroupRow({
		required this.item,
		required this.collapsed,
		required this.onAdd
	});

	@override
	Widget build(BuildContext context) {
		return Container(
			width: double.infinity,
			padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
			color: item.type == _CookieTreeItemType.domain
				? ChanceTheme.primaryColorOf(context).withValues(alpha: 0.12)
				: ChanceTheme.primaryColorOf(context).withValues(alpha: 0.06),
			child: Row(
				children: [
					Icon(
						item.type == _CookieTreeItemType.domain
							? CupertinoIcons.globe
							: CupertinoIcons.rectangle_stack,
						size: 20
					),
					const SizedBox(width: 10),
					Expanded(
						child: Text(
							item.label,
							style: const TextStyle(fontWeight: FontWeight.w600)
						)
					),
					AdaptiveIconButton(
						minimumSize: const Size.square(36),
						icon: const Icon(CupertinoIcons.add, size: 19),
						onPressed: onAdd
					),
					Text(
						describeCount(item.childCount, 'cookie'),
						style: TextStyle(
							color: ChanceTheme.primaryColorWithBrightness50Of(context)
						)
					),
					const SizedBox(width: 8),
					Icon(
						collapsed ? CupertinoIcons.chevron_down : CupertinoIcons.chevron_up,
						size: 17
					)
				]
			)
		);
	}
}

class _CookieRow extends StatelessWidget {
	final StoredCookie storedCookie;
	final VoidCallback onEdit;
	final VoidCallback onDelete;

	const _CookieRow({
		required this.storedCookie,
		required this.onEdit,
		required this.onDelete
	});

	@override
	Widget build(BuildContext context) {
		final cookie = storedCookie.cookie;
		final metadata = <String>[
			storedCookie.path,
			if (cookie.expires case final expires?) 'Expires ${expires.toLocal().toISO8601Date}',
			if (cookie.expires == null && cookie.maxAge == null) 'Session',
			if (cookie.maxAge case final maxAge?) 'Max-Age $maxAge',
			if (cookie.secure) 'Secure',
			if (cookie.httpOnly) 'HttpOnly',
			if (cookie.sameSite case final sameSite?) 'SameSite ${sameSite.name}'
		];
		return CupertinoInkwell(
			padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
			onPressed: onEdit,
			child: Row(
				crossAxisAlignment: CrossAxisAlignment.center,
				children: [
					const Padding(
						padding: EdgeInsets.only(top: 2),
						child: Icon(Icons.cookie_outlined, size: 20)
					),
					const SizedBox(width: 10),
					Expanded(
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Text(cookie.name, style: const TextStyle(fontWeight: FontWeight.w600)),
								const SizedBox(height: 2),
								Text(cookie.value, maxLines: 2, overflow: TextOverflow.ellipsis),
								const SizedBox(height: 4),
								Text(
									metadata.join(' · '),
									style: TextStyle(
										fontSize: 12,
										color: ChanceTheme.primaryColorWithBrightness50Of(context)
									)
								)
							]
						)
					),
					AdaptiveIconButton(
						icon: const Icon(CupertinoIcons.trash, size: 20),
						onPressed: onDelete
					)
				]
			)
		);
	}
}

enum _SameSiteChoice {
	unset,
	lax,
	strict,
	none;
}

class _CookieEditorTextField extends StatelessWidget {
	final String label;
	final TextEditingController controller;
	final TextInputType? keyboardType;
	final int? minLines;
	final int maxLines;

	const _CookieEditorTextField({
		required this.label,
		required this.controller,
		this.keyboardType,
		this.minLines,
		this.maxLines = 1
	});

	@override
	Widget build(BuildContext context) {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
				const SizedBox(height: 6),
				AdaptiveTextField(
					controller: controller,
					keyboardType: keyboardType,
					autocorrect: false,
					minLines: minLines,
					maxLines: maxLines
				)
			]
		);
	}
}

class CookieSettingsPage extends StatefulWidget {
	final CookieJar jar;

	const CookieSettingsPage({
		required this.jar,
		super.key
	});

	@override
	createState() => _CookieSettingsPageState();
}

class _CookieSettingsPageState extends State<CookieSettingsPage> {
	late final RefreshableListController<_CookieTreeItem> _controller;
	final Map<String, int> _ids = {};
	int _nextId = -2;

	@override
	void initState() {
		super.initState();
		_controller = RefreshableListController();
	}

	@override
	void dispose() {
		_controller.dispose();
		super.dispose();
	}

	int _idFor(String key) => _ids.putIfAbsent(key, () => _nextId--);

	Future<List<_CookieTreeItem>> _loadCookies(RefreshableListUpdateOptions options) async {
		final cookies = await loadAllCookies(widget.jar);
		final grouped = <String, Map<String, List<StoredCookie>>>{};
		for (final cookie in cookies) {
			final domain = cookieRootDomain(cookie.storageKey);
			final host = cookie.scope == StoredCookieScope.domain ? '*.${cookie.storageKey}' : cookie.storageKey;
			grouped
				.putIfAbsent(domain, () => {})
				.putIfAbsent(host, () => [])
				.add(cookie);
		}

		final output = <_CookieTreeItem>[];
		final domains = grouped.keys.toList()..sort();
		for (final domain in domains) {
			final domainId = _idFor('domain:$domain');
			final hosts = grouped[domain]!;
			final domainCookieCount = hosts.values.fold<int>(0, (sum, values) => sum + values.length);
			output.add(_CookieTreeItem(
				id: domainId,
				parentId: null,
				type: _CookieTreeItemType.domain,
				label: domain,
				childCount: domainCookieCount,
				newCookieHost: domain,
				newCookieDomain: '.$domain'
			));
			final hostNames = hosts.keys.toList()
				..sort((a, b) {
					if (a.startsWith('*.') != b.startsWith('*.')) {
						return a.startsWith('*.') ? -1 : 1;
					}
					return a.compareTo(b);
				});
			for (final host in hostNames) {
				final hostId = _idFor('host:$domain:$host');
				final hostCookies = hosts[host]!
					..sort((a, b) {
						final byName = a.cookie.name.compareTo(b.cookie.name);
						return byName != 0 ? byName : a.path.compareTo(b.path);
					});
				output.add(_CookieTreeItem(
					id: hostId,
					parentId: domainId,
					type: _CookieTreeItemType.host,
					label: host,
					childCount: hostCookies.length,
					newCookieHost: host.startsWith('*.') ? host.substring(2) : host,
					newCookieDomain: host.startsWith('*.') ? '.${host.substring(2)}' : null
				));
				for (final storedCookie in hostCookies) {
					output.add(_CookieTreeItem(
						id: _idFor('cookie:${storedCookie.identity}'),
						parentId: hostId,
						type: _CookieTreeItemType.cookie,
						label: storedCookie.cookie.name,
						storedCookie: storedCookie
					));
				}
			}
		}
		return output;
	}

	Future<void> _refresh() async {
		await _controller.blockAndUpdate();
	}

	Future<void> _deleteCookie(StoredCookie storedCookie) async {
		if (!await confirm(context, 'Really delete the cookie “${storedCookie.cookie.name}”?', actionName: 'Delete')) {
			return;
		}
		try {
			await deleteStoredCookie(widget.jar, storedCookie);
			await _refresh();
		}
		catch (e, st) {
			if (mounted) {
				alertError(context, e, st);
			}
		}
	}

	Future<void> _addCookie({String host = '', String? domain}) => _showCookieEditor(
		initialHost: host,
		initialDomain: domain
	);

	Future<void> _editCookie(StoredCookie storedCookie) => _showCookieEditor(
		storedCookie: storedCookie
	);

	Future<void> _showCookieEditor({
		StoredCookie? storedCookie,
		String initialHost = '',
		String? initialDomain
	}) async {
		final adding = storedCookie == null;
		final cookie = storedCookie?.cookie ?? (MyCookie('', '')
			..httpOnly = false
			..path = '/');
		final nameController = TextEditingController(text: cookie.name);
		final valueController = TextEditingController(text: cookie.value);
		final hostController = TextEditingController(
			text: initialHost.isNotEmpty ? initialHost : storedCookie?.storageKey ?? ''
		);
		final domainController = TextEditingController(text: initialDomain ?? cookie.domain ?? '');
		final pathController = TextEditingController(text: cookie.path ?? storedCookie?.path ?? '/');
		final maxAgeController = TextEditingController(text: cookie.maxAge?.toString() ?? '');
		DateTime? expires = cookie.expires;
		bool secure = cookie.secure;
		bool httpOnly = cookie.httpOnly;
		_SameSiteChoice sameSite = switch (cookie.sameSite) {
			SameSite.lax => _SameSiteChoice.lax,
			SameSite.strict => _SameSiteChoice.strict,
			SameSite.none => _SameSiteChoice.none,
			_ => _SameSiteChoice.unset
		};
		final result = await showAdaptiveDialog<({Cookie cookie, String host})>(
			context: context,
			barrierDismissible: true,
			builder: (dialogContext) => StatefulBuilder(
				builder: (context, setDialogState) => AdaptiveAlertDialog(
					title: Text(adding ? 'Add cookie' : 'Edit cookie'),
					content: SizedBox(
						width: 460,
						child: SingleChildScrollView(
							child: Column(
								mainAxisSize: MainAxisSize.min,
								crossAxisAlignment: CrossAxisAlignment.stretch,
								children: [
									_CookieEditorTextField(
										label: 'Key',
										controller: nameController
									),
									const SizedBox(height: 10),
									_CookieEditorTextField(
										label: 'Value',
										controller: valueController,
										minLines: 2,
										maxLines: 4
									),
									const SizedBox(height: 10),
									_CookieEditorTextField(
										label: 'Host',
										controller: hostController
									),
									const SizedBox(height: 10),
									_CookieEditorTextField(
										label: 'Domain (blank for host-only cookie)',
										controller: domainController
									),
									const SizedBox(height: 10),
									_CookieEditorTextField(
										label: 'Path',
										controller: pathController
									),
									const SizedBox(height: 10),
									_CookieEditorTextField(
										label: 'Max-Age (seconds, optional)',
										controller: maxAgeController,
										keyboardType: TextInputType.number
									),
									const SizedBox(height: 10),
									AdaptiveThinButton(
										onPressed: () async {
											final picked = await pickDate(context: context, initialDate: expires);
											setDialogState(() => expires = picked?.endOfDay);
										},
										child: Text(expires == null
											? 'Expiration date: None'
											: 'Expiration: ${expires!.toLocal().toISO8601Date}')
									),
									const SizedBox(height: 10),
									const Text('SameSite', style: TextStyle(fontWeight: FontWeight.w600)),
									const SizedBox(height: 6),
									AdaptiveChoiceControl<_SameSiteChoice>(
										knownWidth: 250,
										groupValue: sameSite,
										children: const {
											_SameSiteChoice.unset: (null, 'Unspecified'),
											_SameSiteChoice.lax: (null, 'Lax'),
											_SameSiteChoice.strict: (null, 'Strict'),
											_SameSiteChoice.none: (null, 'None')
										},
										onValueChanged: (value) => setDialogState(() => sameSite = value)
									),
									const SizedBox(height: 10),
									Row(
										children: [
											const Expanded(child: Text('Secure')),
											AdaptiveSwitch(
												value: secure,
												onChanged: (value) => setDialogState(() => secure = value)
											)
										]
									),
									Row(
										children: [
											const Expanded(child: Text('HTTP only')),
											AdaptiveSwitch(
												value: httpOnly,
												onChanged: (value) => setDialogState(() => httpOnly = value)
											)
										]
									)
								]
							)
						)
					),
					actions: [
						AdaptiveDialogAction(
							isDefaultAction: true,
							onPressed: () {
								try {
									if (nameController.text.isEmpty) {
										throw const FormatException('Cookie key cannot be empty');
									}
									if (domainController.text.trim().isEmpty && hostController.text.trim().isEmpty) {
										throw const FormatException('A host is required for a host-only cookie');
									}
									final maxAgeText = maxAgeController.text.trim();
									final maxAge = maxAgeText.isEmpty ? null : int.parse(maxAgeText);
									final edited = MyCookie(nameController.text, valueController.text)
										..domain = domainController.text.trim().nonEmptyOrNull
										..path = pathController.text.trim().nonEmptyOrNull
										..expires = expires
										..maxAge = maxAge
										..secure = secure
										..httpOnly = httpOnly
										..sameSite = switch (sameSite) {
											_SameSiteChoice.unset => null,
											_SameSiteChoice.lax => SameSite.lax,
											_SameSiteChoice.strict => SameSite.strict,
											_SameSiteChoice.none => SameSite.none
										};
									Navigator.pop(dialogContext, (
										cookie: edited,
										host: hostController.text.trim()
									));
								}
								catch (e, st) {
									alertError(context, e, st);
								}
							},
							child: const Text('Save')
						),
						AdaptiveDialogAction(
							onPressed: () => Navigator.pop(dialogContext),
							child: const Text('Cancel')
						)
					]
				)
			)
		);
		nameController.dispose();
		valueController.dispose();
		hostController.dispose();
		domainController.dispose();
		pathController.dispose();
		maxAgeController.dispose();
		if (result == null) {
			return;
		}
		try {
			if (storedCookie == null) {
				await addStoredCookie(widget.jar, host: result.host, cookie: result.cookie);
			}
			else {
				await replaceStoredCookie(widget.jar, storedCookie, result.cookie, host: result.host);
			}
			await _refresh();
		}
		catch (e, st) {
			if (mounted) {
				alertError(context, e, st);
			}
		}
	}

	@override
	Widget build(BuildContext context) {
		return AdaptiveScaffold(
			bar: AdaptiveBar(
				title: const Text('Cookies'),
				actions: [
					AdaptiveIconButton(
						icon: const Icon(CupertinoIcons.add),
						onPressed: _addCookie
					),
					AdaptiveIconButton(
						icon: const Icon(CupertinoIcons.delete),
						onPressed: () async {
							final confirmed = await confirm(
								context,
								'Are you sure you want to clear all cookies?',
								actionName: 'Delete all'
							);
							if (confirmed) {
								await Persistence.clearCookies(fromWifi: widget.jar == Persistence.wifiCookies);
								_controller.blockAndUpdate();
							}
						}
					)
				]
			),
			body: SafeArea(
				bottom: false,
				child: RefreshableList<_CookieTreeItem>(
					controller: _controller,
					id: 'cookieSettings',
					listUpdater: _loadCookies,
					filterableAdapter: null,
					useFiltersFromContext: false,
					itemBuilder: (context, item, options) => switch (item.type) {
						_CookieTreeItemType.domain || _CookieTreeItemType.host => _CookieGroupRow(
							item: item,
							collapsed: false,
							onAdd: () => _addCookie(
								host: item.newCookieHost!,
								domain: item.newCookieDomain
							)
						),
						_CookieTreeItemType.cookie => _CookieRow(
							storedCookie: item.storedCookie!,
							onEdit: () => _editCookie(item.storedCookie!),
							onDelete: () => _deleteCookie(item.storedCookie!)
						)
					},
					collapsedItemBuilder: ({
						required context,
						required value,
						required collapsedChildIds,
						required loading,
						required peekContentHeight,
						required stubChildIds,
						required alreadyDim
					}) {
						return value == null ? const SizedBox.shrink() : _CookieGroupRow(
							item: value,
							collapsed: true,
							onAdd: () => _addCookie(
								host: value.newCookieHost!,
								domain: value.newCookieDomain
							)
						);
					},
					useTree: true,
					treeAdapter: RefreshableTreeAdapter(
						getId: (item) => item.id,
						getParentIds: (item) => [
							if (item.parentId case final parentId?) parentId
						],
						getHasOmittedReplies: (_) => false,
						updateWithStubItems: (currentList, stubIds, cancelToken) async => currentList,
						opId: -1,
						wrapTreeChild: (child, parentIds) => child,
						getIsStub: (_) => false,
						getIsPageStub: (_) => false,
						initiallyCollapseSecondLevelReplies: false,
						collapsedItemsShowBody: true,
						repliesToOPAreTopLevel: false,
						newRepliesAreLinear: false,
						isPaged: false
					)
				)
			)
		);
	}
}

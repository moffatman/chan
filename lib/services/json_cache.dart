import 'dart:convert';
import 'dart:io';

import 'package:chan/services/apple.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/util.dart';
import 'package:chan/version.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mutex/mutex.dart';

class JsonCache {
	static final JsonCache _instance = JsonCache._();
	static JsonCache get instance => _instance;
	JsonCache._();

	final lock = Mutex();

	Future<void> initialize() async {
		for (final entry in _entries) {
			await entry.loadFromDisk();
			if (entry.value == null) {
				await entry.update();
			}
			else if (identical(entry.defaultValue, entry.value) || random.nextDouble() < entry.updateOdds) {
				entry.update(); // Don't block
			}
		}
	}
	
	late final JsonCacheEntry<Map<String, Map>> sites = JsonCacheEntry<Map<String, Map>>._(
		parent: this,
		name: 'sites',
		updater: () async {
			String platform = Platform.operatingSystem;
			if (Platform.isIOS && isDevelopmentBuild) {
				platform += '-dev';
			}
			final response = await Settings.instance.client.get<Map>('$contentSettingsApiRoot/sites', queryParameters: {
				'platform': platform
			}, options: Options(responseType: ResponseType.json, headers: {
				HttpHeaders.userAgentHeader: 'Chance/$kChanceVersion'
			}));
			final remoteMap = (response.data!['data'] as Map).cast<String, Map>();
			final current = sites.value ?? {};
			final result = Map<String, Map>.from({
				...current,
				...remoteMap,
			});
			return result;
		},
		caster: (data) => (data as Map).cast<String, Map>(),
		defaultValue: null // force download
	);
	late final embedRegexes = JsonCacheEntry<List<String>>._(
		parent: this,
		name: 'embedRegexes',
		defaultValue: const [],
		updater: () async {
			final response = await Settings.instance.client.get('https://noembed.com/providers', options: Options(
				responseType: ResponseType.plain
			));
			final data = jsonDecode(response.data as String) as List;
			return List<String>.from(data.cast<Map>().expand((x) => (x['patterns'] as List).cast<String>()));
		},
		caster: (list) => (list as List).cast<String>(),
		updateOdds: 0.1 // Update on 10% of launches
	);
	late final _entries = [embedRegexes, sites];
}

class JsonCacheEntry<T extends Object> extends ChangeNotifier {
	final String name;
	final JsonCache parent;
	final Future<T> Function() updater;
	final T Function(dynamic) caster;
	T? defaultValue;
	T? value;
	double updateOdds;

	JsonCacheEntry._({
		required this.name,
		required this.updater,
		required this.caster,
		required this.parent,
		required this.defaultValue,
		this.updateOdds = 1
	}) : value = defaultValue;

	late final _file = Persistence.documentsDirectory.file('$name.json');

	Future<void> loadFromDisk() => parent.lock.protect(() async {
		Map<String, Map>? defaultSitesMap;
		if (name == 'sites') {
			try {
				final str = await rootBundle.loadString('assets/sites_default.json');
				defaultSitesMap = (jsonDecode(str) as Map).cast<String, Map>();
			}
			catch (e) {
				print('Failed to load assets/sites_default.json: $e');
			}
		}

		if (await _file.exists()) {
			try {
				final str = await _file.readAsString();
				final decoded = jsonDecode(str);
				if (defaultSitesMap != null) {
					final diskMap = (decoded as Map).cast<String, Map>();
					value = caster({
						...defaultSitesMap,
						...diskMap,
					});
				}
				else {
					value = caster(decoded);
				}
				notifyListeners();
			}
			on TypeError {
				print('Type error handling $name');
			}
			on FormatException {
				// Ignore invalid JSON
				_file.delete();
			}
			on FileSystemException {
				// Problem reading file
				_file.delete(); // Throw away exception
			}
		}
		else if (name == 'sites') {
			if (defaultSitesMap != null) {
				value = caster(defaultSitesMap);
				notifyListeners();
				await _file.writeAsString(jsonEncode(value));
			}
		}
	});

	Future<void> update() async {
		print('update $name');
		final obj = value = await updater();
		notifyListeners();
		parent.lock.protect(() async {
			await _file.writeAsString(jsonEncode(obj));
		});
	}
}
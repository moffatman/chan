import 'dart:convert';
import 'dart:io';

import 'package:chan/services/apple.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
	
	late final sites = JsonCacheEntry<Map<String, Map>>._(
		parent: this,
		name: 'sites',
		updater: () async {
			String platform = Platform.operatingSystem;
			if (Platform.isIOS && isDevelopmentBuild) {
				platform += '-dev';
			}
			final response = await Settings.instance.client.get('$contentSettingsApiRoot/sites', queryParameters: {
				'platform': platform
			});
			return (response.data['data'] as Map).cast<String, Map>();
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
			return List<String>.from(data.expand((x) => (x['patterns'] as List<dynamic>).cast<String>()));
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

	late final _file = File('${Persistence.documentsDirectory.path}/$name.json');

	Future<void> loadFromDisk() => parent.lock.protect(() async {
		if (await _file.exists()) {
			try {
				final str = await _file.readAsString();
				value = caster(jsonDecode(str));
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
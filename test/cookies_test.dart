import 'package:chan/services/cookies.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryCookieStorage extends Storage {
	final values = <String, String>{};

	@override
	Future<void> init(bool persistSession, bool ignoreExpires) async {}

	@override
	Future<String?> read(String key) async => values[key];

	@override
	Future<void> write(String key, String value) async {
		values[key] = value;
	}

	@override
	Future<void> delete(String key) async {
		values.remove(key);
	}

	@override
	Future<void> deleteAll(List<String> keys) async {
		for (final key in keys) {
			values.remove(key);
		}
	}
}

void main() {
	test('Apple WebView host-only cookies keep host scope', () {
		expect(
			normalizeWebViewCookieDomain(
				'sys.4chan.org',
				leadingDotIndicatesDomainCookie: true
			),
			isNull
		);
		expect(
			normalizeWebViewCookieDomain(
				'.4chan.org',
				leadingDotIndicatesDomainCookie: true
			),
			'.4chan.org'
		);
		expect(
			normalizeWebViewCookieDomain(
				'4chan.org',
				leadingDotIndicatesDomainCookie: false
			),
			'4chan.org'
		);
	});

	test('cookie roots retain subdomains as tree children', () {
		expect(cookieRootDomain('sys.4chan.org'), '4chan.org');
		expect(cookieRootDomain('boards.example.co.uk'), 'example.co.uk');
		expect(cookieRootDomain('127.0.0.1'), '127.0.0.1');
	});

	test('new host and domain cookies are persisted', () async {
		final storage = _MemoryCookieStorage();
		final jar = PersistCookieJar(storage: storage);
		await addStoredCookie(
			jar,
			host: 'sys.4chan.org',
			cookie: MyCookie('host-cookie', 'one')..path = '/'
		);
		await addStoredCookie(
			jar,
			host: '4chan.org',
			cookie: MyCookie('domain-cookie', 'two')
				..domain = '.4chan.org'
				..path = '/'
		);

		final reloaded = await loadAllCookies(PersistCookieJar(storage: storage));
		expect(
			reloaded.singleWhere((cookie) => cookie.cookie.name == 'host-cookie').scope,
			StoredCookieScope.host
		);
		expect(
			reloaded.singleWhere((cookie) => cookie.cookie.name == 'domain-cookie').scope,
			StoredCookieScope.domain
		);
	});

	test('cookie editor loads, replaces, and deletes persisted cookies', () async {
		final storage = _MemoryCookieStorage();
		final initialJar = PersistCookieJar(storage: storage);
		final uri = Uri.parse('https://sys.4chan.org/settings');
		await initialJar.saveFromResponse(uri, [
			MyCookie('host-key', 'old-value')..path = '/settings'
		]);
		await initialJar.saveFromResponse(uri, [
			MyCookie('shared-key', 'shared-value')
				..domain = '.4chan.org'
				..path = '/'
		]);

		final editingJar = PersistCookieJar(storage: storage);
		await editingJar.forceInit();
		// cookie_jar can leave lazily-decoded host paths as a CastMap whose
		// nested values still have a dynamic runtime type.
		editingJar.hostCookies['sys.4chan.org'] = <String, dynamic>{
			'/settings': <String, dynamic>{}
		}.cast<String, Map<String, SerializableCookie>>();
		final initialCookies = await loadAllCookies(editingJar);
		expect(initialCookies, hasLength(2));
		expect(
			initialCookies.where((cookie) => cookie.scope == StoredCookieScope.host).single.storageKey,
			'sys.4chan.org'
		);
		expect(
			initialCookies.where((cookie) => cookie.scope == StoredCookieScope.domain).single.storageKey,
			'4chan.org'
		);

		final hostCookie = initialCookies.where((cookie) => cookie.scope == StoredCookieScope.host).single;
		await replaceStoredCookie(
			editingJar,
			hostCookie,
			MyCookie('renamed-key', 'new-value')
				..path = '/new-path'
				..secure = true
		);

		final afterEditJar = PersistCookieJar(storage: storage);
		final afterEdit = await loadAllCookies(afterEditJar);
		expect(afterEdit.map((cookie) => cookie.cookie.name), isNot(contains('host-key')));
		final renamed = afterEdit.singleWhere((cookie) => cookie.cookie.name == 'renamed-key');
		expect(renamed.cookie.value, 'new-value');
		expect(renamed.path, '/new-path');
		expect(renamed.cookie.secure, isTrue);

		final shared = afterEdit.singleWhere((cookie) => cookie.scope == StoredCookieScope.domain);
		await deleteStoredCookie(afterEditJar, shared);

		final afterDeleteJar = PersistCookieJar(storage: storage);
		final afterDelete = await loadAllCookies(afterDeleteJar);
		expect(afterDelete, hasLength(1));
		expect(afterDelete.single.cookie.name, 'renamed-key');
	});
}

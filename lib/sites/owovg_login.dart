import 'package:chan/services/owovg.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/sites/4chan.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class SiteOwoVgGoldLoginSystem extends ImageboardSiteLoginSystem {
	@override
	final Site4Chan parent;

	SiteOwoVgGoldLoginSystem(this.parent);

	@override
	List<ImageboardSiteLoginField> getLoginFields() {
		return const [
			ImageboardSiteLoginField(
				displayName: 'Token',
				formKey: 'owovg_id',
				autofillHints: [AutofillHints.username]
			),
			ImageboardSiteLoginField(
				displayName: 'PIN',
				formKey: 'owovg_pin',
				inputType: TextInputType.number,
				autofillHints: [AutofillHints.password]
			)
		];
	}

	Uri get _authUri => Uri.https(parent.owoVgUrl, '/auth');

	@override
	Future<void> logoutImpl(bool fromBothWifiAndCellular, CancelToken cancelToken) async {
		await parent.client.postUri(
			_authUri,
			data: {
				'logout': '1'
			},
			options: Options(
				contentType: Headers.formUrlEncodedContentType,
				headers: {
					'user-agent': OwoVgService.userAgentFor(parent),
					'origin': Uri.https(parent.owoVgUrl).origin,
					'referer': '${Uri.https(parent.owoVgUrl).origin}/',
				},
				extra: {
					kPriority: RequestPriority.interactive
				}
			),
			cancelToken: cancelToken
		);
		loggedIn[Persistence.currentCookies] = false;
		OwoVgService.invalidateMetaCache();
		if (fromBothWifiAndCellular) {
			await CookieManager.instance().deleteCookies(
				url: WebUri(parent.owoVgUrl)
			);
			await Persistence.nonCurrentCookies.deletePreservingCloudflare(Uri.https(parent.owoVgUrl, '/'), true);
			loggedIn[Persistence.nonCurrentCookies] = false;
		}
	}

	@override
	Future<void> login(Map<ImageboardSiteLoginField, String> fields, CancelToken cancelToken) async {
		final id = fields.entries.tryFirstWhere((e) => e.key.formKey == 'owovg_id')?.value.trim();
		final pin = fields.entries.tryFirstWhere((e) => e.key.formKey == 'owovg_pin')?.value.trim();
		if (id == null || pin == null) {
			throw const ImageboardSiteLoginException('Token and PIN are required');
		}
		final response = await parent.client.postUri(
			_authUri,
			data: {
				'id': id,
				'pin': pin,
				'long_login': '1',
			},
			options: Options(
				responseType: ResponseType.plain,
				contentType: Headers.formUrlEncodedContentType,
				validateStatus: (status) => status != null && status < 500,
				headers: {
					'user-agent': OwoVgService.userAgentFor(parent),
					'origin': Uri.https(parent.owoVgUrl).origin,
					'referer': '${Uri.https(parent.owoVgUrl).origin}/auth',
				},
				extra: {
					kPriority: RequestPriority.interactive
				}
			),
			cancelToken: cancelToken
		);
		final body = response.data as String? ?? '';
		if (response.statusCode != 200) {
			loggedIn[Persistence.currentCookies] = false;
			await logout(false, cancelToken);
			throw ImageboardSiteLoginException(body.trim().isEmpty ? 'Login failed (${response.statusCode})' : body.trim());
		}
		if (!body.contains('Success!')) {
			loggedIn[Persistence.currentCookies] = false;
			await logout(false, cancelToken);
			throw ImageboardSiteLoginException(body.trim().isEmpty ? 'Login failed' : body.trim());
		}
		loggedIn[Persistence.currentCookies] = true;
		OwoVgService.invalidateMetaCache();
		try {
			final meta = await OwoVgService.fetchMeta(parent, forceRefresh: true);
			if (!meta.gold) {
				loggedIn[Persistence.currentCookies] = false;
				throw const ImageboardSiteLoginException('Logged in but gold status not detected');
			}
		}
		catch (e) {
			if (e is ImageboardSiteLoginException) {
				rethrow;
			}
		}
	}

	@override
	String get name => 'owo.vg Gold Pass';

	@override
	Uri? get iconUrl => Uri.https(parent.staticUrl, '/image/minileaf.gif');

	@override
	bool get hidden => false;

	@override
	bool isLoggedIn(CookieJar jar) {
		if (loggedIn[jar] == true) {
			return true;
		}
		return getSavedLoginFields() != null;
	}
}

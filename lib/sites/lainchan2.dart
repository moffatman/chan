import 'package:chan/services/cloudflare.dart';
import 'package:chan/sites/lainchan_org.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart';

class FormBypassInterceptor extends Interceptor {
	final SiteLainchan2 site;

	FormBypassInterceptor(this.site);

	@override
	void onResponse(Response response, ResponseInterceptorHandler handler) async {
		try {
			if (response.realUri.host == site.baseUrl) {
				final formBypass = site.formBypass[response.realUri.path];
				if (formBypass != null) {
					final document = parse(response.data);
					String? action = document.querySelector('form')?.attributes['action'];
					if (action != null) {
						if (action.startsWith('/')) {
							action = 'https://${site.baseUrl}$action';
						}
						final postResponse = await site.client.post(action, data: FormData.fromMap(formBypass), options: Options(
							validateStatus: (x) => x != null && (x >= 200 || x < 400),
							followRedirects: true,
							extra: {
								if (response.cloudflare) 'cloudflare': true
							}
						));
						if (postResponse.realUri.path != response.realUri.path) {
							// Success
							handler.next(await site.client.fetch(response.requestOptions));
							return;
						}
					}
				}
			}
			handler.next(response);
		}
		catch (e, st) {
			Future.error(e, st); // Crashlytics
			handler.reject(DioError(
				requestOptions: response.requestOptions,
				error: e
			));
		}
	}
}

/// The old SiteLainchan and SiteLainchanOrg can't really be modified due to backwards compatibility
class SiteLainchan2 extends SiteLainchanOrg {
	@override
	final String? imageThumbnailExtension;
	final Map<String, Map<String, String>> formBypass;

	SiteLainchan2({
		required super.baseUrl,
		required super.name,
		required this.formBypass,
		required this.imageThumbnailExtension,
		super.archives,
		super.faviconPath,
		super.boardsPath,
		super.defaultUsername
	}) {
		client.interceptors.add(FormBypassInterceptor(this));
	}

	@override
	String get siteType => 'lainchan2';
	@override
	String get siteData => baseUrl;

	@override
	bool operator == (Object other) =>
		(other is SiteLainchan2) &&
		(other.baseUrl == baseUrl) &&
		(other.name == name) &&
		listEquals(other.archives, archives) &&
		(other.faviconPath == faviconPath) &&
		(other.defaultUsername == defaultUsername) &&
		(other.boardsPath == boardsPath) &&
		mapEquals(other.formBypass, formBypass) &&
		(other.imageThumbnailExtension == imageThumbnailExtension) &&
		(other.boardsPath == boardsPath) &&
		(other.faviconPath == faviconPath);

	@override
	int get hashCode => Object.hash(baseUrl, name, archives, faviconPath, defaultUsername, formBypass, imageThumbnailExtension, boardsPath, faviconPath);
}
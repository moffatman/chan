import 'package:chan/pages/cloudflare.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/cupertino_page_route.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:html/parser.dart';
import 'package:provider/provider.dart';

class CloudflareInterceptor extends Interceptor {
	final ImageboardSiteArchive site;
	CloudflareInterceptor(this.site);
	@override
	void onError(DioError err, ErrorInterceptorHandler handler) async {
		if (err.type == DioErrorType.response && err.response?.statusCode == 403) {
				if (err.response!.headers.value(Headers.contentTypeHeader)!.contains('text/html')) {
					final document = parse(err.response!.data);
					if (document.querySelector('title')?.text.contains('Cloudflare') ?? false) {
						final response = await Navigator.of(site.context).push<String>(FullWidthCupertinoPageRoute(
							builder: (context) => CloudflareLoginPage(
								desiredUrl: err.requestOptions.uri
							),
							showAnimations: site.context.read<EffectiveSettings?>()?.showAnimations ?? true
						));
						if (response != null) {
							handler.resolve(Response(
								data: response,
								requestOptions: err.requestOptions
							));
							return;
						}
					}
				}
			}
			handler.next(err);
	}
}
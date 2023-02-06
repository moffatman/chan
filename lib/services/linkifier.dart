import 'package:linkify/linkify.dart';

final _looseUrlRegex = RegExp(
  r'^(.*?)((https?:\/\/)?(www\.)?([-a-zA-Z0-9@:%_.\+~#=]{1,256}\.[a-z]{2,})\b[-a-zA-Z0-9@:%_\+.~#?&//=]*)',
  caseSensitive: false,
  dotAll: true,
);

final _protocolIdentifierRegex = RegExp(
  r'^(https?:\/\/)',
  caseSensitive: false,
);

class LooseUrlLinkifier extends Linkifier {
  const LooseUrlLinkifier();

  @override
  List<LinkifyElement> parse(elements, options) {
    final list = <LinkifyElement>[];

    for (final element in elements) {
      if (element is TextElement) {
        var match = _looseUrlRegex.firstMatch(element.text);

        if (match == null || (match.group(5)?.contains('..') ?? false)) {
          list.add(element);
        } else {
          final text = element.text.replaceFirst(match.group(0)!, '');

          if (match.group(1)?.isNotEmpty == true) {
            list.add(TextElement(match.group(1)!));
          }

          if (match.group(2)?.isNotEmpty == true) {
            var originalUrl = match.group(2)!;
            String? end;

            if ((options.excludeLastPeriod) &&
                originalUrl[originalUrl.length - 1] == ".") {
              end = ".";
              originalUrl = originalUrl.substring(0, originalUrl.length - 1);
            }

            var url = originalUrl;

            if (!originalUrl.startsWith(_protocolIdentifierRegex)) {
              originalUrl = (options.defaultToHttps ? "https://" : "http://") +
                  originalUrl;
            }

            if ((options.humanize) || (options.removeWww)) {
              if (options.humanize) {
                url = url.replaceFirst(RegExp(r'https?://'), '');
              }
              if (options.removeWww) {
                url = url.replaceFirst(RegExp(r'www\.'), '');
              }

              list.add(UrlElement(
                originalUrl,
                url,
              ));
            } else {
              list.add(UrlElement(originalUrl));
            }

            if (end != null) {
              list.add(TextElement(end));
            }
          }

          if (text.isNotEmpty) {
            list.addAll(parse([TextElement(text)], options));
          }
        }
      } else {
        list.add(element);
      }
    }

    return list;
  }
}

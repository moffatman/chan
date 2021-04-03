import 'dart:convert';
import 'dart:io';

import 'package:chan/models/attachment.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/post_element.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/sites/4chan.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:http/http.dart' as http;
import 'package:html_unescape/html_unescape_small.dart';

class FoolFuukaArchive implements ImageboardSiteArchive {
	final http.Client client = http.Client();
	List<ImageboardBoard>? _boards;
	final unescape = HtmlUnescape();
	final String baseUrl;
	final String staticUrl;
	final String name;
	ImageboardFlag? _makeFlag(dynamic data) {
		if (data['poster_country'] != null) {
			return ImageboardFlag(
				name: data['poster_country_name'],
				imageUrl: Uri.https(staticUrl, '/image/country/${data['poster_country'].toLowerCase()}.gif').toString(),
				imageWidth: 16,
				imageHeight: 11
			);
		}
		else if (data['troll_country_name'] != null) {
			return ImageboardFlag(
				name: data['troll_country_name'],
				imageUrl: Uri.https(staticUrl, '/image/country/troll/${data['troll_country_code'].toLowerCase()}.gif').toString(),
				imageWidth: 16,
				imageHeight: 11
			);
		}
	}
	Attachment? _makeAttachment(dynamic data) {
		if (data['media'] != null) {
			final List<String> serverFilenameParts =  data['media']['media_orig'].split('.');
			return Attachment(
				board: data['board']['shortname'],
				id: int.parse(serverFilenameParts.first),
				filename: data['media']['media_filename'],
				ext: '.' + serverFilenameParts.last,
				type: serverFilenameParts.last == 'webm' ? AttachmentType.WEBM : AttachmentType.Image,
				url: Uri.parse(data['media']['media_link']),
				thumbnailUrl: Uri.parse(data['media']['thumb_link'])
			);
		}	
	}
	Post _makePost(dynamic data) {
		return Post(
			board: data['board']['shortname'],
			text: data['comment_processed'] ?? '',
			name: data['name'],
			time: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] * 1000),
			id: data['num'],
			attachment: _makeAttachment(data),
			span: PostNodeSpan(Site4Chan.makeSpans(data['com'] ?? '')),
			flag: _makeFlag(data),
			posterId: data['id']
		);
	}
	Future<Post> getPost(String board, int id) async {
		final response = await client.get(Uri.https(baseUrl, '/_/api/chan/post', {
			'board': board,
			'num': id
		}));
		if (response.statusCode != 200) {
			if (response.statusCode == 404) {
				return Future.error(ThreadNotFoundException(board, id));
			}
			return Future.error(HTTPStatusException(response.statusCode));
		}
		final data = json.decode(response.body);
		return _makePost(data);
	}
	Future<Thread> getThreadContainingPost(String board, int id) async {
		throw Exception('Unimplemented');
	}
	Future<Thread> getThread(String board, int id) async {
		final response = await client.get(Uri.https(baseUrl, '/_/api/chan/thread', {
			'board': board,
			'num': id
		}));
		if (response.statusCode != 200) {
			if (response.statusCode == 404) {
				return Future.error(ThreadNotFoundException(board, id));
			}
			return Future.error(HTTPStatusException(response.statusCode));
		}
		final data = json.decode(response.body);
		final postObjects = [data['op'], ...data['posts'].values];
		final posts = postObjects.map<Post>(_makePost).toList();
		final String? title = postObjects.first['title'];
		return Thread(
			board: board,
			isDeleted: false,
			replyCount: posts.length - 1,
			imageCount: posts.where((post) => post.attachment != null).length,
			isArchived: true,
			posts: posts,
			id: id,
			attachment: _makeAttachment(postObjects.first),
			title: (title == null) ? null : unescape.convert(title),
			isSticky: postObjects.first['sticky'] == 1,
			time: posts.first.time,
			flag: _makeFlag(postObjects.first)
		);
	}
	Future<List<Thread>> getCatalog(String board) async {
		throw Exception('Catalog not supported on $name');
	}
	Future<List<ImageboardBoard>> _getBoards() async {
		final response = await client.get(Uri.https(baseUrl, '/_/api/chan/archives'));
		if (response.statusCode != 200) {
			throw HTTPStatusException(response.statusCode);
		}
		final data = json.decode(response.body);
		return data['archives'].values.map((archive) {
			return ImageboardBoard(
				name: archive['shortname'],
				title: archive['name'],
				isWorksafe: !archive['is_nsfw'],
				webmAudioAllowed: false
			);
		});
	}
	Future<List<ImageboardBoard>> getBoards() async {
		if (_boards != null) {
			_boards = await _getBoards();
		}
		return _boards!;
	}

	FoolFuukaArchive({
		required this.baseUrl,
		required this.staticUrl,
		required this.name
	});
}
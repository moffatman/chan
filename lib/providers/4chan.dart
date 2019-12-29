import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:meta/meta.dart';
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;

import 'package:chan/providers/provider.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/models/post_element.dart';

class Provider4Chan implements ImageboardProvider {
	final String name;
	final String apiUrl;
	final String imageUrl;

	List<PostElement> _makeElements(String data) {
		final doc = parse(data);
		final elements = List<PostElement>();
		bool passedFirstLinebreak = false;
		for (final node in doc.body.nodes) {
			if (node is dom.Element) {
				if (node.localName == 'br') {
					if (passedFirstLinebreak) {
						elements.add(LineBreakElement());
					}
					else {
						elements.add(NewLineElement());
						passedFirstLinebreak = true;
					}
				}
				else {
					passedFirstLinebreak = false;
					if (node.localName == 'a') {
						elements.add(QuoteLinkElement(num.tryParse(node.attributes['href'].substring(2))));
					}
					else if (node.localName == 'span') {
						if (node.attributes['class'].contains('deadlink')) {
							elements.add(DeadQuoteLinkElement(num.tryParse(node.innerHtml.substring(8))));
						}
						else if (node.attributes['class'].contains('quote')) {
							elements.add(QuoteElement(node.text));
						}
						else {
							throw 'Unknown span: ' + node.outerHtml;
						}
					}
          else if (node.localName == 'wbr') {
            // do nothing
          }
					else {
						elements.add(TextElement(node.outerHtml));
					}
				}
			}
			else {
				passedFirstLinebreak = false;
				elements.add(TextElement(node.text));
			}
		}
		return elements;
	}

	Post _makePost(String board, dynamic data) {
		Post p = Post(
			text: data['com'] ?? '',
			name: data['name'] ?? '',
			time: DateTime.fromMillisecondsSinceEpoch(data['time'] * 1000),
			id: data['no'],
			attachment: (data['filename'] != null) ? _makeAttachment(board, data) : null,
			elements: _makeElements(data['com'] ?? '')
		);

		return p;
	}
	Attachment _makeAttachment(String board, dynamic data) {
		return ImageAttachment(
			thumbnailUrl: '$imageUrl/$board/${data['tim']}s.jpg',
			imageUrl: '$imageUrl/$board/${data['tim']}${data['ext']}',
			filename: (data['filename'] ?? '') + (data['ext'] ?? '')
		);
	}
	Future<Thread> getThread(String board, int id) async {
		final response = await http.get(apiUrl + '/' + board + '/thread/' + id.toString() + '.json');
		if (response.statusCode != 200) {
			throw HTTPStatusException(response.statusCode);
		}
		final data = json.decode(response.body);
		return Thread(
			board: board,
			isDeleted: false,
			replyCount: data['posts'][0]['replies'],
			imageCount: data['posts'][0]['images'],
			isArchived: (data['posts'][0]['archived'] ?? 0) == 1,
			posts: (data['posts'] ?? []).map<Post>((postData) {
				return _makePost(board, postData);
			}).toList(),
			id: data['posts'][0]['no'],
			attachment: _makeAttachment(board, data),
			title: data['posts'][0]['sub']
		);
	}

	Future<Thread> getThreadContainingPost(String board, int id) async {

	}

	Future<List<Thread>> getCatalog(String board) async {
		final response = await http.get(apiUrl + '/' + board + '/catalog.json');
		final data = json.decode(response.body);
		final threads = List<Thread>();
		for (final page in data) {
			for (final threadData in page['threads']) {
				/*List<Post> lastReplies = (threadData['last_replies'] ?? []).map<Post>((postData) {
					return _makePost(board, postData);
				}).toList();*/
        List<Post> lastReplies = [];
				lastReplies.insert(0, _makePost(board, threadData));
				Thread thread = Thread(
					board: board,
					id: threadData['no'],
					replyCount: threadData['replies'],
					imageCount: threadData['images'],
					isArchived: false,
					isDeleted: false,
					attachment: _makeAttachment(board, threadData),
					posts: lastReplies,
					title: threadData['sub']
				);
				threads.add(thread);
			}
		}
		return threads;
	}

	const Provider4Chan({
		@required this.apiUrl,
		@required this.imageUrl,
		@required this.name
	});
}
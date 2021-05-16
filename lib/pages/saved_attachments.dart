import 'package:chan/pages/gallery.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/saved_attachment_thumbnail.dart';
import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SavedAttachmentsPage extends StatefulWidget {
	createState() => _SavedAttachmentsPageState();
}

class _SavedAttachmentsPageState extends State<SavedAttachmentsPage> {
	@override
	Widget build(BuildContext context) {
		return CupertinoPageScaffold(
			navigationBar: CupertinoNavigationBar(
				transitionBetweenRoutes: false,
				middle: Text('Saved Attachments')
			),
			child: ValueListenableBuilder(
				valueListenable: Persistence.savedAttachmentBox.listenable(),
				builder: (context, box, child) {
					final list = Persistence.savedAttachmentBox.values.toList();
					list.sort((a, b) => b.savedTime.compareTo(a.savedTime));
					return GridView.builder(
						itemCount: list.length,
						itemBuilder: (context, i) {
							return GestureDetector(
								child: Hero(
									child: SavedAttachmentThumbnail(
										file: list[i].file
									),
									tag: AttachmentSemanticLocation(
										attachment: list[i].attachment,
										semanticParents: []
									)
								),
								onTap: () => showGallery(
									context: context,
									initiallyShowChrome: true,
									attachments: list.map((a) => a.attachment).toList(),
									overrideSources: {
										for (final a in list) a.attachment: a.file.uri
									},
									initialAttachment: list[i].attachment,
									semanticParentIds: [],
								)
							);
						},
						gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
							crossAxisCount: 4
						)
					);
				}				
			)
		);
	}
}
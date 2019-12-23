import 'package:flutter/material.dart';

enum AttachmentType {
	Image,
	Video,
	Gallery
}

class Attachment {
	AttachmentType type;
	String thumbnailUrl;
	Attachment(this.type, this.thumbnailUrl);
}

class ImageAttachment extends Attachment {
	String imageUrl;
	String filename;
	ImageAttachment({
		@required String thumbnailUrl,
		@required String imageUrl,
		@required String filename
	}): super(AttachmentType.Image, thumbnailUrl) {
	}
}
import 'package:flutter/material.dart';

enum AttachmentType {
	Image,
	WEBM
}

class Attachment {
	final String board;
	final int id;
	final String ext;
	final String filename;
	final AttachmentType type;
	final String providerId;
	Attachment({
		@required this.type,
		@required this.board,
		@required this.id,
		@required this.ext,
		@required this.filename,
		this.providerId
	});
}
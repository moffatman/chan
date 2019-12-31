import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/viewers/viewer.dart';
import 'package:flutter/material.dart';

import 'package:chan/models/attachment.dart';

class AttachmentGallery extends StatefulWidget {
	final List<Attachment> attachments;
	final ValueChanged<Attachment> onClose;
	final Attachment initialAttachment;
	final double thumbnailSize;
	final double height;
	final Color backgroundColor;

	const AttachmentGallery({
		@required this.attachments,
		this.onClose,
		this.initialAttachment,
		this.thumbnailSize = 32,
		this.height = double.infinity,
		this.backgroundColor = Colors.black
	});

	@override
	createState() => _AttachmentGalleryState();
}

class _AttachmentGalleryState extends State<AttachmentGallery> {
	PageController _pageController;
	ScrollController _scrollController;

	int _currentIndex = 0;
	bool _lock = false;

	@override
	void initState() {
		super.initState();
		if (widget.initialAttachment != null) {
			_currentIndex = widget.attachments.indexOf(widget.initialAttachment);
		}
		_pageController = PageController(
			initialPage: _currentIndex
		);
		_scrollController = ScrollController();
	}

	@override
	void dispose() {
		super.dispose();
		_pageController.dispose();
		_scrollController.dispose();
	}

	void _onPageChanged(int index) {
		setState(() {
			_currentIndex = index;
			_scrollController.animateTo(
				(widget.thumbnailSize + 8),
				duration: const Duration(milliseconds: 200),
				curve: Curves.ease
			);
		});
	}

	void _selectImage(int index) {
		setState(() {
			_pageController.animateToPage(
				index,
				duration: const Duration(milliseconds: 500),
				curve: Curves.ease
			);
			_lock = false;
		});
	}

	@override
	Widget build(BuildContext context) {
		return Container(
			height: widget.height,
			color: widget.backgroundColor,
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.center,
				children: [
					Expanded(
						child: PageView(
							physics: _lock ? NeverScrollableScrollPhysics() : null,
							onPageChanged: _onPageChanged,
							controller: _pageController,
							children: widget.attachments.map((attachment) {
								return AttachmentViewer(attachment: attachment, onDeepInteraction: (currentInteraction) {
									setState(() {
										_lock = currentInteraction;
									});
								});	
							}).toList()
						)
					),
					SizedBox(height: 8),
					Container(
						height: widget.thumbnailSize,
						child: ListView.builder(
							controller: _scrollController,
							itemCount: widget.attachments.length,
							scrollDirection: Axis.horizontal,
							itemBuilder: (context, index) {
								return GestureDetector(
									onTap: () {
										_selectImage(index);
									},
									child: Container(
										decoration: BoxDecoration(
											color: Colors.white,
											border: index == _currentIndex ? Border.all(color: Colors.blue, width: 2) : null
										),
										margin: const EdgeInsets.only(left: 8),
										child: AttachmentThumbnail(
											attachment: widget.attachments[index],
											width: widget.thumbnailSize,
											height: widget.thumbnailSize
										)
									)
								);
							}
						)
					),
					SizedBox(height: 8)
				]
			)
		);
	}
}
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/viewers/viewer.dart';
import 'package:flutter/material.dart';

import 'package:chan/models/attachment.dart';

class AttachmentGallery extends StatefulWidget {
	final List<Attachment> attachments;
	final ValueChanged<Attachment> onChange;
	final ValueChanged<Attachment> onTap;
	final Attachment initialAttachment;
	final double thumbnailSize;
	final double height;
	final Color backgroundColor;
	final bool showThumbnails;

	const AttachmentGallery({
		@required this.attachments,
		this.onChange,
		this.onTap,
		this.initialAttachment,
		this.thumbnailSize = 32,
		this.height = double.infinity,
		this.backgroundColor = Colors.transparent,
		this.showThumbnails = true,
		Key key
	}) : super(key: key);

	@override
	createState() => _AttachmentGalleryState();
}

GlobalKey<_AttachmentGalleryState> galleryKey = GlobalKey();

class _AttachmentGalleryState extends State<AttachmentGallery> {
	PageController _pageController;
	ScrollController _scrollController;
	List<Widget> pageWidgets;

	int _currentIndex = 0;
	bool _lock = false;

	void _generatePageWidgets() {
		print('_generatePageWidgets');
		pageWidgets = widget.attachments.map((attachment) {
			return GestureDetector(
				child: AttachmentViewer(
					attachment: attachment,
					backgroundColor: widget.backgroundColor,
					onDeepInteraction: (currentInteraction) {
						print('onDeepInteraction: $currentInteraction');
						setState(() {
							_lock = currentInteraction;
						});
					}
				),
				onTap: () {
					if (widget.onTap != null) widget.onTap(attachment);
				}
			);
		}).toList();
	}

	@override
	void initState() {
		super.initState();
		print('gallery initstate');
		if (widget.initialAttachment != null) {
			_currentIndex = widget.attachments.indexOf(widget.initialAttachment);
		}
		_pageController = PageController(
			initialPage: _currentIndex
		);
		_scrollController = ScrollController();
		_generatePageWidgets();
	}

	@override void didUpdateWidget(AttachmentGallery old) {
		super.didUpdateWidget(old);
		if (widget.attachments != old.attachments) {
			print('regenerating');
			_generatePageWidgets();
		}
		if (widget.initialAttachment != old.initialAttachment) {
			_currentIndex = widget.attachments.indexOf(widget.initialAttachment);
		}
	}

	@override
	void dispose() {
		super.dispose();
		_pageController.dispose();
		_scrollController.dispose();
	}

	void _onPageChanged(int index) {
		if (widget.onChange != null) widget.onChange(widget.attachments[index]);
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
		if (widget.onChange != null) widget.onChange(widget.attachments[index]);
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
			child: Stack(
				children: [
					PageView(
						physics: _lock ? NeverScrollableScrollPhysics() : null,
						onPageChanged: _onPageChanged,
						controller: _pageController,
						children: pageWidgets
					),
					Visibility(
						visible: widget.showThumbnails,
						maintainState: true,
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.center,
							children: [
								Expanded(
									child: Container()
								),
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
					)
				]
			)
		);
	}
}
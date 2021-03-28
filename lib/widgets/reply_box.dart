import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/captcha.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

final GlobalKey<_ReplyBoxState> replyBoxKey = GlobalKey();

class ReplyBox extends StatefulWidget {
	final ImageboardBoard board;
	final int threadId;
	final ValueChanged<PostReceipt> onReplyPosted;
	final VoidCallback? onRequestFocus;

	ReplyBox({
		required this.board,
		required this.threadId,
		required this.onReplyPosted,
		this.onRequestFocus,
		Key? key
	}) : super(key: key);
	createState() => _ReplyBoxState();
}

class _ReplyBoxState extends State<ReplyBox> {
	final _textFieldController = TextEditingController();
	final _focusNode = FocusNode();
	bool loading = false;

	@override
	void initState() {
		super.initState();
		_textFieldController.addListener(() {
			setState(() {});
		});
	}

	void onTapPostId(int id) {
		widget.onRequestFocus?.call();
		_focusNode.requestFocus();
		int currentPos = _textFieldController.selection.base.offset;
		if (currentPos < 0) {
			currentPos = _textFieldController.text.length;
		}
		String insertedText = '>>$id';
		if (currentPos == _textFieldController.text.length) {
			insertedText += '\n';
		}
		_textFieldController.value = TextEditingValue(
			selection: TextSelection(
				baseOffset: currentPos + insertedText.length,
				extentOffset: currentPos + insertedText.length
			),
			text: _textFieldController.text.substring(0, currentPos) + insertedText + _textFieldController.text.substring(currentPos)
		);
	}

	void shouldRequestFocusNow() {
		_focusNode.requestFocus();
	}

	@override
	Widget build(BuildContext context) {
		final site = context.watch<ImageboardSite>();
		return Container(
			constraints: BoxConstraints(
				maxHeight: 200
			),
			decoration: BoxDecoration(
				color: CupertinoTheme.of(context).scaffoldBackgroundColor
			),
			padding: EdgeInsets.all(4),
			child: Row(
				children: [
					Expanded(
						child: IntrinsicHeight(
							child: Stack(
								children: [
									CupertinoTextField(
										enabled: !loading,
										controller: _textFieldController,
										maxLines: null,
										minLines: 4,
										autofocus: true,
										focusNode: _focusNode,
										textCapitalization: TextCapitalization.sentences,
										keyboardAppearance: CupertinoTheme.of(context).brightness,
									),
									if (widget.board.maxCommentCharacters != null && ((_textFieldController.text.length / widget.board.maxCommentCharacters!) > 0.5)) IgnorePointer(
										child: Align(
											alignment: Alignment.bottomRight,
											child: Container(
												padding: EdgeInsets.only(bottom: 4, right: 8),
												child: Text(
													'${_textFieldController.text.length} / ${widget.board.maxCommentCharacters}',
													style: TextStyle(
														color: (_textFieldController.text.length > widget.board.maxCommentCharacters!) ? Colors.red : Colors.grey
													)
												)
											)
										)
									)
								]
							)
						)
					),
					Column(
						mainAxisSize: MainAxisSize.min,
						mainAxisAlignment: MainAxisAlignment.end,
						children: [
							CupertinoButton(
								child: Text('Attach file'),
								onPressed: null
							),
							CupertinoButton(
								child: loading ? CircularProgressIndicator() : Text('Submit'),
								onPressed: loading ? null : () async {
									final captchaKey = await Navigator.of(context).push<String>(TransparentRoute(builder: (context) {
										return OverscrollModalPage(
											child: CaptchaNoJS(
												request: site.getCaptchaRequest(),
												onCaptchaSolved: (key) => Navigator.of(context).pop(key)
											)
										);
									}));
									if (captchaKey == null) {
										return;
									}
									setState(() {
										loading = true;
									});
									try {
										final receipt = await site.postReply(
											board: widget.board.name,
											threadId: widget.threadId,
											captchaKey: captchaKey,
											text: _textFieldController.text
										);
										_textFieldController.clear();
										setState(() {
											loading = false;
										});
										print(receipt);
										_focusNode.unfocus();
										widget.onReplyPosted(receipt);
									}
									catch (e, st) {
										print(e);
										print(st);
										setState(() {
											loading = false;
										});
										alertError(context, e.toString());
									}
								}
							)
						]
					)
				]
			)
		);
	}
}
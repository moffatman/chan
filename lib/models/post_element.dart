import 'package:flutter/material.dart';

abstract class PostElement {
	Widget toWidget();
	const PostElement();
}

class TextElement extends PostElement {
	final String text;
	const TextElement(this.text);
	Widget toWidget() {
		return Text(this.text);
	}
}

class LineBreakElement extends PostElement {
	const LineBreakElement();
	Widget toWidget() {
		return Row(
			children: [
				Text('')
			]
		);
	}
}

class QuoteElement extends PostElement {
	final String text;
	const QuoteElement(this.text);
	Widget toWidget() {
		return Text(this.text, style: TextStyle(color: Colors.green));
	}
}

class QuoteLinkElement extends PostElement {
	final int id;
	const QuoteLinkElement(this.id);
	Widget toWidget() {
		return Text('>>' + this.id.toString(), style: TextStyle(color: Colors.red));
	}
}

class DeadQuoteLinkElement extends PostElement {
	final int id;
	const DeadQuoteLinkElement(this.id);
	Widget toWidget() {
		return Text('>>' + this.id.toString(), style: TextStyle(decoration: TextDecoration.lineThrough, color: Colors.red));
	}
}

class NewLineElement extends PostElement {
	const NewLineElement();
	Widget toWidget() {
		return Row();
	}
}
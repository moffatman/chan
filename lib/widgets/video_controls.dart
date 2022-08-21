import 'dart:math';

import 'package:chan/services/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

class VideoControls extends StatefulWidget {
	final VideoPlayerController controller;
	final bool hasAudio;

	const VideoControls({
		required this.controller,
		required this.hasAudio,
		Key? key
	}) : super(key: key);

	@override
	createState() => _VideoControlsState();
}

class _VideoControlsState extends State<VideoControls> {
	double sliderValue = 0;
	late VideoPlayerValue value;
	late bool wasAlreadyPlaying;

	@override
	void initState() {
		super.initState();
		value = widget.controller.value;
		sliderValue = max(0, value.position.inMilliseconds).toDouble();
		wasAlreadyPlaying = value.isPlaying;
		widget.controller.addListener(_onControllerUpdate);
	}

	@override
	void didUpdateWidget(VideoControls old) {
		super.didUpdateWidget(old);
		if (widget.controller != old.controller) {
			old.controller.removeListener(_onControllerUpdate);
			value = widget.controller.value;
			sliderValue = max(0, value.position.inMilliseconds).toDouble();
			widget.controller.addListener(_onControllerUpdate);
		}
	}

	void _onControllerUpdate() {
		setState(() {
			if (mounted) {
				value = widget.controller.value;
				sliderValue = max(0, value.position.inMilliseconds).toDouble();
			}
		});
	}

	String _formatDuration(Duration d) {
		return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
	}

	@override
	Widget build(BuildContext context) {
		return Row(
			mainAxisAlignment: MainAxisAlignment.spaceEvenly,
			children: [
				const SizedBox(width: 8),
				Text(_formatDuration(value.position), style: const TextStyle(color: Colors.white)),
				Expanded(
					child: CupertinoSlider(
						value: sliderValue,
						max: max(0.01, max(sliderValue, value.duration.inMilliseconds).toDouble()),
						onChangeStart: (newSliderValue) {
							wasAlreadyPlaying = value.isPlaying;
							widget.controller.pause();
						},
						onChanged: (newSliderValue) {
							setState(() {
								sliderValue = newSliderValue;
							});
						},
						onChangeEnd: (newSliderValue) async {
							await widget.controller.seekTo(Duration(milliseconds: newSliderValue.round()));
							await widget.controller.play();
							if (!wasAlreadyPlaying) {
								await widget.controller.pause();
							}
						},
					)
				),
				Text(_formatDuration(value.duration), style: const TextStyle(color: Colors.white)),
				if (widget.hasAudio) AnimatedBuilder(
					animation: context.read<EffectiveSettings>().muteAudio,
					builder: (context, _) => CupertinoButton(
						padding: EdgeInsets.zero,
						child: Icon(value.volume > 0 ? CupertinoIcons.volume_up : CupertinoIcons.volume_off),
						onPressed: () async {
							final settings = context.read<EffectiveSettings>();
							if (value.volume > 0) {
								await widget.controller.setVolume(0);
								settings.setMuteAudio(true);
							}
							else {
								await widget.controller.setVolume(1);
								settings.setMuteAudio(false);
							}
						}
					)
				),
				CupertinoButton(
					padding: EdgeInsets.zero,
					child: Icon(value.isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_arrow_solid),
					onPressed: () async {
						if (value.isPlaying) {
							await widget.controller.pause();
						}
						else {
							await widget.controller.play();
						}
					},
				)
			]
		);
	}

	@override
	void dispose() {
		super.dispose();
		widget.controller.removeListener(_onControllerUpdate);
	}
}
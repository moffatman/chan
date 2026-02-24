import 'dart:async';

import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/attachment_viewer.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class VideoControls extends StatefulWidget {
	final AttachmentViewerController controller;
	final bool showMuteButton;

	const VideoControls({
		required this.controller,
		this.showMuteButton = true,
		Key? key
	}) : super(key: key);

	@override
	createState() => _VideoControlsState();
}

class _VideoControlsState extends State<VideoControls> {
	VideoController? videoPlayerController;
	PlayerState? value;
	StreamSubscription<Duration>? _positionSubscription;
	StreamSubscription<bool>? _playingSubscription;
	StreamSubscription<Duration>? _durationSubscription;
	StreamSubscription<double>? _volumeSubscription;
	ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
	final _clipRRectKey = GlobalKey(debugLabel: '_VideoControlsState._clipRRectKey');

	@override
	void initState() {
		super.initState();
		videoPlayerController = widget.controller.videoPlayerController;
		_playingSubscription = videoPlayerController?.player.stream.playing.listen(_onVideoUpdate);
		_positionSubscription = videoPlayerController?.player.stream.position.listen(_onVideoUpdate);
		_durationSubscription = videoPlayerController?.player.stream.duration.listen(_onVideoUpdate);
		_volumeSubscription = videoPlayerController?.player.stream.volume.listen(_onVideoUpdate);
		if (videoPlayerController?.player.state case final state?) {
			value = state;
			position.value = state.position;
		}
		widget.controller.addListener(_onControllerUpdate);
	}

	@override
	void didUpdateWidget(VideoControls old) {
		super.didUpdateWidget(old);
		if (widget.controller != old.controller) {
			old.controller.removeListener(_onControllerUpdate);
			widget.controller.addListener(_onControllerUpdate);
			Future.microtask(_onControllerUpdate);
		}
	}

	void _onControllerUpdate() {
		if (!mounted) {
			return;
		}
		if (widget.controller.videoPlayerController != videoPlayerController) {
			_positionSubscription?.cancel();
			_playingSubscription?.cancel();
			_durationSubscription?.cancel();
			_volumeSubscription?.cancel();
			videoPlayerController = widget.controller.videoPlayerController;
			_positionSubscription = videoPlayerController?.player.stream.position.listen(_onVideoUpdate);
			_playingSubscription = videoPlayerController?.player.stream.playing.listen(_onVideoUpdate);
			_volumeSubscription = videoPlayerController?.player.stream.volume.listen(_onVideoUpdate);
			_durationSubscription = videoPlayerController?.player.stream.duration.listen(_onVideoUpdate);
		}
		setState(() {});
	}

	void _onVideoUpdate(Object _) {
		if (!mounted) return;
		final v = videoPlayerController?.player.state;
		if (v != null) {
			position.value = v.position;
			setState(() {
				value = v;
			});
		}
	}

	double _calculateSliderWidth() {
		return (_clipRRectKey.currentContext?.findRenderObject() as RenderBox?)?.paintBounds.width ?? MediaQuery.sizeOf(context).width;
	}

	@override
	Widget build(BuildContext context) {
		final primaryColor = ChanceTheme.primaryColorOf(context);
		return SizedBox(
			height: 44,
			child: Row(
				mainAxisAlignment: MainAxisAlignment.spaceEvenly,
				children: [
					const SizedBox(width: 8),
					ValueListenableBuilder(
						valueListenable: position,
						builder: (context, Duration positionValue, _) => SizedBox(
							width: 40,
							child: FittedBox(
								fit: BoxFit.scaleDown,
								child: Text(formatDuration(positionValue), style: TextStyle(color: primaryColor))
							)
						)
					),
					Expanded(
						child: Padding(
							padding: const EdgeInsets.all(8),
							child: GestureDetector(
								onTapUp: (x) async {
									await widget.controller.onLongPressStart(absolute: true);
									await widget.controller.onCoalescedLongPressUpdate(x.localPosition.dx / _calculateSliderWidth());
									await widget.controller.onLongPressEnd();
								},
								onHorizontalDragStart: (x) => widget.controller.onLongPressStart(absolute: true),
								onHorizontalDragUpdate: (x) => widget.controller.onLongPressUpdate(x.localPosition.dx / _calculateSliderWidth()),
								onHorizontalDragEnd: (x) => widget.controller.onLongPressEnd(),
								child: ClipRRect(
									borderRadius: BorderRadius.circular(8),
									key: _clipRRectKey,
									child: Stack(
										alignment: Alignment.bottomCenter,
										children: [
											ValueListenableBuilder(
												valueListenable: widget.controller.showLoadingProgress,
												builder: (context, showLoadingProgress, _) => (showLoadingProgress || !widget.controller.cacheCompleted) ? ValueListenableBuilder(
													valueListenable: widget.controller.videoLoadingProgress,
													builder: (context, double? value, _) => LinearProgressIndicator(
														minHeight: 44,
														value: value,
														valueColor: AlwaysStoppedAnimation(primaryColor.withValues(alpha: 0.3)),
														backgroundColor: Colors.transparent
													)
												) : const SizedBox.shrink()
											),
											ValueListenableBuilder(
												valueListenable: position,
												builder: (context, Duration positionValue, _) => LinearProgressIndicator(
													minHeight: 44,
													value: switch (value?.duration.inMilliseconds) {
														int ms => positionValue.inMilliseconds / ms.clamp(1, double.maxFinite),
														null => 0
													},
													valueColor: AlwaysStoppedAnimation(primaryColor),
													backgroundColor: !widget.controller.cacheCompleted ? Colors.transparent : primaryColor.withValues(alpha: 0.3)
												)
											)
										]
									)
								)
							)
						)
					),
					SizedBox(
						width: 40,
						child: FittedBox(
							fit: BoxFit.scaleDown,
							child: Text(formatDuration(value?.duration), style: TextStyle(color: primaryColor))
						)
					),
					if (widget.controller.hasAudio && widget.showMuteButton) AnimatedBuilder(
						animation: Settings.instance.muteAudio,
						builder: (context, _) {
							final mutedNow = value?.volume == 0 || Settings.instance.muteAudio.value;
							return AdaptiveIconButton(
								icon: Icon(mutedNow ? CupertinoIcons.volume_off : CupertinoIcons.volume_up),
								onPressed: value == null ? null : () async {
									if (!mutedNow) {
										await videoPlayerController?.player.setVolume(0);
										Settings.instance.setMuteAudio(true);
									}
									else {
										await videoPlayerController?.player.setVolume(100);
										Settings.instance.setMuteAudio(false);
									}
								}
							);
						}
					),
					AdaptiveIconButton(
						icon: Icon((widget.controller.currentlyWithinLongPress ? widget.controller.playingBeforeLongPress : (value?.playing ?? false)) ? CupertinoIcons.pause_fill : CupertinoIcons.play_arrow_solid),
						onPressed: value == null ? null : () async {
							if (value?.playing ?? false) {
								await videoPlayerController?.player.pause();
							}
							else {
								await videoPlayerController?.player.play();
							}
						},
					)
				]
			)
		);
	}

	@override
	void dispose() {
		super.dispose();
		widget.controller.removeListener(_onControllerUpdate);
		_positionSubscription?.cancel();
		_playingSubscription?.cancel();
		_durationSubscription?.cancel();
		_volumeSubscription?.cancel();
	}
}
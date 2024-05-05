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
import 'package:mutex/mutex.dart';

const _positionUpdatePeriod = Duration(milliseconds: 30);

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
	late PlayerState value;
	late bool wasAlreadyPlaying;
	StreamSubscription<Duration>? _positionSubscription;
	StreamSubscription<bool>? _playingSubscription;
	StreamSubscription<Duration>? _durationSubscription;
	final position = ValueNotifier(Duration.zero);
	bool _playingBeforeLongPress = false;
	bool _currentlyWithinLongPress = false;
	final _mutex = Mutex();
	final _clipRRectKey = GlobalKey(debugLabel: '_VideoControlsState._clipRRectKey');
	int _lastGoodDurationInMilliseconds = 0;

	@override
	void initState() {
		super.initState();
		videoPlayerController = widget.controller.videoPlayerController;
		_playingSubscription = videoPlayerController?.player.stream.playing.listen(_onVideoUpdate);
		_positionSubscription = videoPlayerController?.player.stream.position.listen(_onVideoUpdate);
		_durationSubscription = videoPlayerController?.player.stream.duration.listen(_onVideoUpdate);
		value = videoPlayerController?.player.state ?? const PlayerState();
		position.value = value.position;
		wasAlreadyPlaying = value.playing;
		widget.controller.addListener(_onControllerUpdate);
		Future.delayed(_positionUpdatePeriod, _updatePosition);
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
			videoPlayerController = widget.controller.videoPlayerController;
			_positionSubscription = videoPlayerController?.player.stream.position.listen(_onVideoUpdate);
			_playingSubscription = videoPlayerController?.player.stream.playing.listen(_onVideoUpdate);
			_durationSubscription = videoPlayerController?.player.stream.duration.listen(_onVideoUpdate);
		}
		setState(() {});
	}

	void _onVideoUpdate(Object _) {
		if (!mounted) return;
		final v = videoPlayerController?.player.state;
		final duration = (v?.duration ?? Duration.zero);
		if (duration > Duration.zero) {
			_lastGoodDurationInMilliseconds = duration.inMilliseconds;
		}
		if (v != null) {
			setState(() {
				value = v;
			});
		}
	}

	void _updatePosition() async {
		if (!mounted) {
			return;
		}
		if (!_currentlyWithinLongPress) {
			final newPosition = videoPlayerController?.player.state.position;
			if (newPosition != null) {
				position.value = newPosition;
			}
		}
		Future.delayed(_positionUpdatePeriod, _updatePosition);
	}

	Future<void> _onLongPressStart() => _mutex.protect(() async {
		_playingBeforeLongPress = value.playing;
		_currentlyWithinLongPress = true;
	});

	Future<void> _onLongPressUpdate(double relativePosition) async {
		if (_currentlyWithinLongPress) {
			final newPosition = Duration(milliseconds: (relativePosition.clamp(0, 1) * _lastGoodDurationInMilliseconds).round());
			if (!_mutex.isLocked) {
				await _mutex.protect(() async {
					position.value = newPosition;
					await videoPlayerController?.player.seek(newPosition);
					await videoPlayerController?.player.play();
					await videoPlayerController?.player.pause();
					await Future.delayed(const Duration(milliseconds: 50));
				});
			}
		}
	}

	Future<void> _onLongPressEnd() => _mutex.protect(() async {
		if (_playingBeforeLongPress) {
			await videoPlayerController?.player.play();
		}
		_currentlyWithinLongPress = false;
	});

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
									await _onLongPressStart();
									await _onLongPressUpdate(x.localPosition.dx / _calculateSliderWidth());
									await _onLongPressEnd();
								},
								onHorizontalDragStart: (x) => _onLongPressStart(),
								onHorizontalDragUpdate: (x) => _onLongPressUpdate(x.localPosition.dx / _calculateSliderWidth()),
								onHorizontalDragEnd: (x) => _onLongPressEnd(),
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
														valueColor: AlwaysStoppedAnimation(primaryColor.withOpacity(0.3)),
														backgroundColor: Colors.transparent
													)
												) : const SizedBox.shrink()
											),
											ValueListenableBuilder(
												valueListenable: position,
												builder: (context, Duration positionValue, _) => LinearProgressIndicator(
													minHeight: 44,
													value: positionValue.inMilliseconds / value.duration.inMilliseconds.clamp(1, double.maxFinite),
													valueColor: AlwaysStoppedAnimation(primaryColor),
													backgroundColor: !widget.controller.cacheCompleted ? Colors.transparent : primaryColor.withOpacity(0.3)
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
							child: Text(formatDuration(value.duration), style: TextStyle(color: primaryColor))
						)
					),
					if (widget.controller.hasAudio && widget.showMuteButton) AnimatedBuilder(
						animation: Settings.instance.muteAudio,
						builder: (context, _) => AdaptiveIconButton(
							icon: Icon(value.volume > 0 ? CupertinoIcons.volume_up : CupertinoIcons.volume_off),
							onPressed: () async {
								if (value.volume > 0) {
									await videoPlayerController?.player.setVolume(0);
									Settings.instance.setMuteAudio(true);
								}
								else {
									await videoPlayerController?.player.setVolume(100);
									Settings.instance.setMuteAudio(false);
								}
							}
						)
					),
					AdaptiveIconButton(
						icon: Icon((_currentlyWithinLongPress ? _playingBeforeLongPress : value.playing) ? CupertinoIcons.pause_fill : CupertinoIcons.play_arrow_solid),
						onPressed: () async {
							if (value.playing) {
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
	}
}
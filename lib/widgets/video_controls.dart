import 'package:chan/services/settings.dart';
import 'package:chan/widgets/attachment_viewer.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mutex/mutex.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

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
	late VideoPlayerController videoPlayerController;
	late VideoPlayerValue value;
	late bool wasAlreadyPlaying;
	final position = ValueNotifier(Duration.zero);
	bool _playingBeforeLongPress = false;
	bool _currentlyWithinLongPress = false;
	final _mutex = Mutex();
	final _clipRRectKey = GlobalKey();

	@override
	void initState() {
		super.initState();
		videoPlayerController = widget.controller.videoPlayerController!;
		videoPlayerController.addListener(_onVideoPlayerControllerUpdate);
		value = videoPlayerController.value;
		position.value = value.position;
		wasAlreadyPlaying = value.isPlaying;
		widget.controller.addListener(_onControllerUpdate);
		Future.delayed(_positionUpdatePeriod, _updatePosition);
	}

	@override
	void didUpdateWidget(VideoControls old) {
		super.didUpdateWidget(old);
		if (widget.controller != old.controller) {
			old.controller.removeListener(_onControllerUpdate);
			widget.controller.addListener(_onControllerUpdate);
			videoPlayerController = widget.controller.videoPlayerController!;
			value = videoPlayerController.value;
		}
	}

	void _onControllerUpdate() {
		if (!mounted) {
			return;
		}
		if (widget.controller.videoPlayerController != videoPlayerController) {
			videoPlayerController.removeListener(_onVideoPlayerControllerUpdate);
			if (widget.controller.videoPlayerController != null) {
				// If a force-reload occurs it could be null.
				videoPlayerController = widget.controller.videoPlayerController!;
				videoPlayerController.addListener(_onVideoPlayerControllerUpdate);
			}
		}
		setState(() {});
	}

	void _onVideoPlayerControllerUpdate() {
		if (!mounted) return;
		setState(() {
			value = videoPlayerController.value;
		});
	}

	void _updatePosition() async {
		if (!mounted) {
			return;
		}
		if (!_currentlyWithinLongPress) {
			final newPosition = await videoPlayerController.position;
			if (newPosition != null) {
				position.value = newPosition;
			}
		}
		Future.delayed(_positionUpdatePeriod, _updatePosition);
	}

	Future<void> _onLongPressStart() => _mutex.protect(() async {
		_playingBeforeLongPress = value.isPlaying;
		if (!widget.controller.swapIncoming || widget.controller.swapAvailable) {
			await videoPlayerController.pause();
			await widget.controller.potentiallySwapVideo();
		}
		_currentlyWithinLongPress = true;
	});

	Future<void> _onLongPressUpdate(double relativePosition) async {
		if (_currentlyWithinLongPress) {
			final duration = (widget.controller.duration ?? value.duration).inMilliseconds;
			final newPosition = Duration(milliseconds: (relativePosition.clamp(0, 1) * (duration)).round());
			if (!_mutex.isLocked) {
				_mutex.protect(() async {
					if (widget.controller.swapIncoming) {
						return;
					}
					await videoPlayerController.seekTo(newPosition);
					await videoPlayerController.play();
					await videoPlayerController.pause();
					await Future.delayed(const Duration(milliseconds: 50));
				});
			}
			if (!widget.controller.swapIncoming) {
				position.value = newPosition;
			}
		}
	}

	Future<void> _onLongPressEnd() => _mutex.protect(() async {
		await widget.controller.potentiallySwapVideo();
		if (_playingBeforeLongPress) {
			await videoPlayerController.play();
		}
		_currentlyWithinLongPress = false;
	});

	double _calculateSliderWidth() {
		return (_clipRRectKey.currentContext?.findRenderObject() as RenderBox?)?.paintBounds.width ?? MediaQuery.sizeOf(context).width;
	}

	@override
	Widget build(BuildContext context) {
		final primaryColor = CupertinoTheme.of(context).primaryColor;
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
											if (widget.controller.swapIncoming) ValueListenableBuilder(
												valueListenable: widget.controller.videoLoadingProgress,
												builder: (context, double? value, _) => LinearProgressIndicator(
													minHeight: 44,
													value: value,
													valueColor: AlwaysStoppedAnimation(primaryColor.withOpacity(0.3)),
													backgroundColor: Colors.transparent
												)
											),
											ValueListenableBuilder(
												valueListenable: position,
												builder: (context, Duration positionValue, _) => LinearProgressIndicator(
													minHeight: 44,
													value: positionValue.inMilliseconds / (widget.controller.duration ?? value.duration).inMilliseconds.clamp(1, double.maxFinite),
													valueColor: AlwaysStoppedAnimation(primaryColor),
													backgroundColor: widget.controller.swapIncoming ? Colors.transparent : primaryColor.withOpacity(0.3)
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
							child: Text(formatDuration(widget.controller.duration ?? value.duration), style: TextStyle(color: primaryColor))
						)
					),
					if (widget.controller.hasAudio && widget.showMuteButton) AnimatedBuilder(
						animation: context.read<EffectiveSettings>().muteAudio,
						builder: (context, _) => CupertinoButton(
							padding: EdgeInsets.zero,
							child: Icon(value.volume > 0 ? CupertinoIcons.volume_up : CupertinoIcons.volume_off),
							onPressed: () async {
								final settings = context.read<EffectiveSettings>();
								if (value.volume > 0) {
									await videoPlayerController.setVolume(0);
									settings.setMuteAudio(true);
								}
								else {
									await videoPlayerController.setVolume(1);
									settings.setMuteAudio(false);
								}
							}
						)
					),
					CupertinoButton(
						padding: EdgeInsets.zero,
						child: Icon((_currentlyWithinLongPress ? _playingBeforeLongPress : value.isPlaying) ? CupertinoIcons.pause_fill : CupertinoIcons.play_arrow_solid),
						onPressed: () async {
							if (value.isPlaying) {
								await videoPlayerController.pause();
								await widget.controller.potentiallySwapVideo();
							}
							else {
								await videoPlayerController.play();
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
		videoPlayerController.removeListener(_onVideoPlayerControllerUpdate);
	}
}
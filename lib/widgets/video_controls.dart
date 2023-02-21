import 'package:chan/services/settings.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mutex/mutex.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

const _positionUpdatePeriod = Duration(milliseconds: 30);

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
	late VideoPlayerValue value;
	late bool wasAlreadyPlaying;
	final position = ValueNotifier(Duration.zero);
	bool _playingBeforeLongPress = false;
	bool _currentlyWithinLongPress = false;
	final _mutex = Mutex();

	@override
	void initState() {
		super.initState();
		value = widget.controller.value;
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
			value = widget.controller.value;
			widget.controller.addListener(_onControllerUpdate);
		}
	}

	void _onControllerUpdate() {
		if (!mounted) {
			return;
		}
		setState(() {
			value = widget.controller.value;
		});
	}

	void _updatePosition() async {
		if (!mounted) {
			return;
		}
		if (!_currentlyWithinLongPress) {
			final newPosition = await widget.controller.position;
			if (newPosition != null) {
				position.value = newPosition;
			}
		}
		Future.delayed(_positionUpdatePeriod, _updatePosition);
	}

	Future<void> _onLongPressStart() => _mutex.protect(() async {
		_playingBeforeLongPress = value.isPlaying;
		await widget.controller.pause();
		_currentlyWithinLongPress = true;
	});

	Future<void> _onLongPressUpdate(double relativePosition) async {
		if (_currentlyWithinLongPress) {
			final duration = value.duration.inMilliseconds;
			final newPosition = Duration(milliseconds: (relativePosition.clamp(0, 1) * (duration)).round());
			if (!_mutex.isLocked) {
				_mutex.protect(() async {
					await widget.controller.seekTo(newPosition);
					await widget.controller.play();
					await widget.controller.pause();
					await Future.delayed(const Duration(milliseconds: 50));
				});
			}
			position.value = newPosition;
		}
	}

	Future<void> _onLongPressEnd() => _mutex.protect(() async {
		if (_playingBeforeLongPress) {
			await widget.controller.play();
		}
		_currentlyWithinLongPress = false;
	});

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
							child: LayoutBuilder(
								builder: (context, constraints) => GestureDetector(
									onTapUp: (x) async {
										await _onLongPressStart();
										await _onLongPressUpdate(x.localPosition.dx / constraints.maxWidth);
										await _onLongPressEnd();
									},
									onHorizontalDragStart: (x) => _onLongPressStart(),
									onHorizontalDragUpdate: (x) => _onLongPressUpdate(x.localPosition.dx / constraints.maxWidth),
									onHorizontalDragEnd: (x) => _onLongPressEnd(),
									child: ClipRRect(
										borderRadius: BorderRadius.circular(8),
										child: ValueListenableBuilder(
											valueListenable: position,
											builder: (context, Duration positionValue, _) => LinearProgressIndicator(
												minHeight: 44,
												value: positionValue.inMilliseconds / value.duration.inMilliseconds.clamp(1, double.maxFinite),
												valueColor: AlwaysStoppedAnimation(primaryColor),
												backgroundColor: primaryColor.withOpacity(0.3)
											)
										)
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
						child: Icon((_currentlyWithinLongPress ? _playingBeforeLongPress : value.isPlaying) ? CupertinoIcons.pause_fill : CupertinoIcons.play_arrow_solid),
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
			)
		);
	}

	@override
	void dispose() {
		super.dispose();
		widget.controller.removeListener(_onControllerUpdate);
	}
}
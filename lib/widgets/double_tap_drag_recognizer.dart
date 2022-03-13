import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

class DoubleTapDragUpdateDetails {
  const DoubleTapDragUpdateDetails({
    this.globalPosition = Offset.zero,
    Offset? localPosition,
    this.offsetFromOrigin = Offset.zero,
    Offset? localOffsetFromOrigin,
    this.delta = Offset.zero,
    Offset? localDelta
  }) : localPosition = localPosition ?? globalPosition,
       localOffsetFromOrigin = localOffsetFromOrigin ?? offsetFromOrigin,
       localDelta = delta;

  final Offset globalPosition;
  final Offset localPosition;
  final Offset offsetFromOrigin;
  final Offset localOffsetFromOrigin;
  final Offset delta;
  final Offset localDelta;
}

typedef GestureDoubleTapDragUpdateCallback = void Function(DoubleTapDragUpdateDetails details);

/// CountdownZoned tracks whether the specified duration has elapsed since
/// creation, honoring [Zone].
class _CountdownZoned {
  _CountdownZoned({ required Duration duration }) {
    Timer(duration, _onTimeout);
  }

  bool _timeout = false;

  bool get timeout => _timeout;

  void _onTimeout() {
    _timeout = true;
  }
}

/// TapTracker helps track individual tap sequences as part of a
/// larger gesture.
class _TapTracker {
  _TapTracker({
    required PointerDownEvent event,
    required this.entry,
    required Duration doubleTapMinTime,
    required this.gestureSettings,
  }) : pointer = event.pointer,
       _initialGlobalPosition = event.position,
       _initialLocalPosition = event.localPosition,
       initialButtons = event.buttons,
       _doubleTapMinTimeCountdown = _CountdownZoned(duration: doubleTapMinTime);

  final DeviceGestureSettings? gestureSettings;
  final int pointer;
  final GestureArenaEntry entry;
  final Offset _initialGlobalPosition;
  final Offset _initialLocalPosition;
  final int initialButtons;
  final _CountdownZoned _doubleTapMinTimeCountdown;

  bool _isTrackingPointer = false;

  void startTrackingPointer(PointerRoute route, Matrix4? transform) {
    if (!_isTrackingPointer) {
      _isTrackingPointer = true;
      GestureBinding.instance.pointerRouter.addRoute(pointer, route, transform);
    }
  }

  void stopTrackingPointer(PointerRoute route) {
    if (_isTrackingPointer) {
      _isTrackingPointer = false;
      GestureBinding.instance.pointerRouter.removeRoute(pointer, route);
    }
  }

  bool isWithinGlobalTolerance(PointerEvent event, double tolerance) {
    final Offset offset = event.position - _initialGlobalPosition;
    return offset.distance <= tolerance;
  }

  bool hasElapsedMinTime() {
    return _doubleTapMinTimeCountdown.timeout;
  }

  bool hasSameButton(PointerDownEvent event) {
    return event.buttons == initialButtons;
  }
}

class DoubleTapDragGestureRecognizer extends GestureRecognizer {
  DoubleTapDragGestureRecognizer({
    Object? debugOwner,
    Set<PointerDeviceKind>? supportedDevices,
  }) : super(
		debugOwner: debugOwner,
		supportedDevices: supportedDevices,
	);

  // Implementation notes:
  //
  // The double tap recognizer can be in one of four states. There's no
  // explicit enum for the states, because they are already captured by
  // the state of existing fields. Specifically:
  //
  // 1. Waiting on first tap: In this state, the _trackers list is empty, and
  //    _firstTap is null.
  // 2. First tap in progress: In this state, the _trackers list contains all
  //    the states for taps that have begun but not completed. This list can
  //    have more than one entry if two pointers begin to tap.
  // 3. Waiting on second tap: In this state, one of the in-progress taps has
  //    completed successfully. The _trackers list is again empty, and
  //    _firstTap records the successful tap.
  // 4. Second tap in progress: Much like the "first tap in progress" state, but
  //    _firstTap is non-null. If a tap completes successfully while in this
  //    state, the callback is called and the state is reset.
  //
  // There are various other scenarios that cause the state to reset:
  //
  // - All in-progress taps are rejected (by time, distance, pointercancel, etc)
  // - The long timer between taps expires
  // - The gesture arena decides we have been rejected wholesale

  /// A pointer has contacted the screen with a primary button at the same
  /// location twice in quick succession, which might be the start of a double
  /// tap.
  ///
  /// This triggers immediately after the down event of the second tap.
  ///
  /// If this recognizer doesn't win the arena, [onDoubleTapCancel] is called
  /// next. Otherwise, [onDoubleTap] is called next.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  ///  * [TapDownDetails], which is passed as an argument to this callback.
  ///  * [GestureDetector.onDoubleTapDown], which exposes this callback.
  GestureTapDownCallback? onDoubleTapDown;

  /// Called when the user has tapped the screen with a primary button at the
  /// same location twice in quick succession.
  ///
  /// This triggers when the pointer stops contacting the device after the
  /// second tap.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  ///  * [GestureDetector.onDoubleTap], which exposes this callback.
  GestureDoubleTapCallback? onDoubleTap;

  GestureDoubleTapDragUpdateCallback? onDoubleTapDrag;

  /// A pointer that previously triggered [onDoubleTapDown] will not end up
  /// causing a double tap.
  ///
  /// This triggers once the gesture loses the arena if [onDoubleTapDown] has
  /// previously been triggered.
  ///
  /// If this recognizer wins the arena, [onDoubleTap] is called instead.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  ///  * [GestureDetector.onDoubleTapCancel], which exposes this callback.
  GestureTapCancelCallback? onDoubleTapCancel;

  Timer? _doubleTapTimer;
  _TapTracker? _firstTap;
  final Map<int, _TapTracker> _trackers = <int, _TapTracker>{};

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    if (_firstTap == null) {
      switch (event.buttons) {
        case kPrimaryButton:
          if (onDoubleTapDown == null &&
              onDoubleTap == null &&
              onDoubleTapCancel == null) {
            return false;
					}
          break;
        default:
          return false;
      }
    }
    return super.isPointerAllowed(event);
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    bool acceptImmediately = false;
    if (_firstTap != null) {
      if (!_firstTap!.isWithinGlobalTolerance(event, kDoubleTapSlop)) {
        // Ignore out-of-bounds second taps.
        return;
      } else if (!_firstTap!.hasElapsedMinTime() || !_firstTap!.hasSameButton(event)) {
        // Restart when the second tap is too close to the first (touch screens
        // often detect touches intermittently), or when buttons mismatch.
        _reset();
        return _trackTap(event);
      } else {
        if (onDoubleTapDown != null) {
          final TapDownDetails details = TapDownDetails(
            globalPosition: event.position,
            localPosition: event.localPosition,
            kind: getKindForPointer(event.pointer),
          );
          invokeCallback<void>('onDoubleTapDown', () => onDoubleTapDown!(details));
        }
        acceptImmediately = true;
      }
    }
    _trackTap(event, acceptImmediately: acceptImmediately);
  }

  void _trackTap(PointerDownEvent event, {bool acceptImmediately = false}) {
    _stopDoubleTapTimer();
    final _TapTracker tracker = _TapTracker(
      event: event,
      entry: GestureBinding.instance.gestureArena.add(event.pointer, this),
      doubleTapMinTime: kDoubleTapMinTime,
      gestureSettings: gestureSettings,
    );
    _trackers[event.pointer] = tracker;
    tracker.startTrackingPointer(_handleEvent, event.transform);
    if (acceptImmediately) {
      tracker.entry.resolve(GestureDisposition.accepted);
    }
  }

  void _handleEvent(PointerEvent event) {
    final _TapTracker tracker = _trackers[event.pointer]!;
    if (event is PointerUpEvent) {
      if (_firstTap == null) {
        _registerFirstTap(tracker);
			}
      else {
        _registerSecondTap(tracker);
			}
    } else if (event is PointerMoveEvent) {
      if (_firstTap == tracker) {
				if (!tracker.isWithinGlobalTolerance(event, kDoubleTapTouchSlop)) {
        	_reject(tracker);
				}
			}
			else if (_firstTap != null && onDoubleTapDrag != null) {
				final DoubleTapDragUpdateDetails details = DoubleTapDragUpdateDetails(
          globalPosition: event.position,
          localPosition: event.localPosition,
          offsetFromOrigin: event.position - tracker._initialGlobalPosition,
          localOffsetFromOrigin: event.localPosition - tracker._initialLocalPosition,
          delta: event.delta,
          localDelta: event.localDelta
        );
        invokeCallback('onDoubleTapDrag', () => onDoubleTapDrag!(details));
			}
    } else if (event is PointerCancelEvent) {
      _reject(tracker);
    }
  }

  @override
  void acceptGesture(int pointer) { }

  @override
  void rejectGesture(int pointer) {
    _TapTracker? tracker = _trackers[pointer];
    // If tracker isn't in the list, check if this is the first tap tracker
    if (tracker == null &&
        _firstTap != null &&
        _firstTap!.pointer == pointer) {
      tracker = _firstTap;
		}
    // If tracker is still null, we rejected ourselves already
    if (tracker != null) {
      _reject(tracker);
		}
  }

  void _reject(_TapTracker tracker) {
    _trackers.remove(tracker.pointer);
    tracker.entry.resolve(GestureDisposition.rejected);
    _freezeTracker(tracker);
    if (_firstTap != null) {
      if (tracker == _firstTap) {
        _reset();
      } else {
        _checkCancel();
        if (_trackers.isEmpty) {
          _reset();
				}
      }
    }
  }

  @override
  void dispose() {
    _reset();
    super.dispose();
  }

  void _reset() {
    _stopDoubleTapTimer();
    if (_firstTap != null) {
      if (_trackers.isNotEmpty) {
        _checkCancel();
			}
      // Note, order is important below in order for the resolve -> reject logic
      // to work properly.
      final _TapTracker tracker = _firstTap!;
      _firstTap = null;
      _reject(tracker);
      GestureBinding.instance.gestureArena.release(tracker.pointer);
    }
    _clearTrackers();
  }

  void _registerFirstTap(_TapTracker tracker) {
    _startDoubleTapTimer();
    GestureBinding.instance.gestureArena.hold(tracker.pointer);
    // Note, order is important below in order for the clear -> reject logic to
    // work properly.
    _freezeTracker(tracker);
    _trackers.remove(tracker.pointer);
    _clearTrackers();
    _firstTap = tracker;
  }

  void _registerSecondTap(_TapTracker tracker) {
    _firstTap!.entry.resolve(GestureDisposition.accepted);
    tracker.entry.resolve(GestureDisposition.accepted);
    _freezeTracker(tracker);
    _trackers.remove(tracker.pointer);
    _checkUp(tracker.initialButtons);
    _reset();
  }

  void _clearTrackers() {
    _trackers.values.toList().forEach(_reject);
    assert(_trackers.isEmpty);
  }

  void _freezeTracker(_TapTracker tracker) {
    tracker.stopTrackingPointer(_handleEvent);
  }

  void _startDoubleTapTimer() {
    _doubleTapTimer ??= Timer(kDoubleTapTimeout, _reset);
  }

  void _stopDoubleTapTimer() {
    if (_doubleTapTimer != null) {
      _doubleTapTimer!.cancel();
      _doubleTapTimer = null;
    }
  }

  void _checkUp(int buttons) {
    assert(buttons == kPrimaryButton);
    if (onDoubleTap != null) {
      invokeCallback<void>('onDoubleTap', onDoubleTap!);
		}
  }

  void _checkCancel() {
    if (onDoubleTapCancel != null) {
      invokeCallback<void>('onDoubleTapCancel', onDoubleTapCancel!);
		}
  }

  @override
  String get debugDescription => 'double tap';
}
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This file is a modified copy of Flutter's cupertino `route.dart`
// allowing to change the width of area where back swipe gesture is accepted

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:math';

import 'package:chan/services/apple.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

extension WithinRange on num {
  bool withinRange(num low, num high) {
    return this >= low && this <= high;
  }
}

bool eventTooCloseToEdge(Offset globalPosition) {
  final mq = MediaQueryData.fromView(PlatformDispatcher.instance.views.first);
  return !(Platform.isIOS ? (mq.viewPadding - sumAdditionalSafeAreaInsets()) : mq.systemGestureInsets).deflateRect(Offset.zero & mq.size).contains(globalPosition);
}

enum _DragState {
	ready,
	possible,
	accepted,
}

/// Device types that scrollables should accept drag gestures from by default.
const Set<PointerDeviceKind> _kTouchLikeDeviceTypes = <PointerDeviceKind>{
  PointerDeviceKind.touch,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
  PointerDeviceKind.trackpad,
  // The VoiceAccess sends pointer events with unknown type when scrolling
  // scrollables.
  PointerDeviceKind.unknown,
};

const _weakSlowAcceptTime = Duration(milliseconds: 50);
abstract class WeakDragGestureRecognizer extends OneSequenceGestureRecognizer {
	WeakDragGestureRecognizer({
		Object? debugOwner,
		Set<PointerDeviceKind>? supportedDevices,
		this.dragStartBehavior = DragStartBehavior.start,
    this.multitouchDragStrategy = MultitouchDragStrategy.latestPointer,
		this.velocityTrackerBuilder = _defaultBuilder,
	}) : super(debugOwner: debugOwner, supportedDevices: supportedDevices);

	static VelocityTracker _defaultBuilder(PointerEvent event) => VelocityTracker.withKind(event.kind);

	DragStartBehavior dragStartBehavior;

  MultitouchDragStrategy multitouchDragStrategy;

	GestureDragDownCallback? onDown;

	GestureDragStartCallback? onStart;

	GestureDragUpdateCallback? onUpdate;

	GestureDragEndCallback? onEnd;

	GestureDragCancelCallback? onCancel;

	double? minFlingDistance;

	double? minFlingVelocity;

	double? maxFlingVelocity;

	GestureVelocityTrackerBuilder velocityTrackerBuilder;

	_DragState _state = _DragState.ready;
	late OffsetPair _initialPosition;
	late OffsetPair _pendingDragOffset;
	Duration? _lastPendingEventTimestamp;
	int? _initialButtons;
	Matrix4? _lastTransform;

  late Offset _globalMoved;
	late double _globalDistanceMoved;

	bool isFlingGesture(VelocityEstimate estimate, PointerDeviceKind kind);

  DragEndDetails? _considerFling(VelocityEstimate estimate, PointerDeviceKind kind);

	Offset _getDeltaForDetails(Offset delta);
	double? _getPrimaryValueFromOffset(Offset value);
  _DragDirection? _getPrimaryDragAxis() => null;
	double _calculateAcceptFactor(PointerEvent event, double? deviceTouchSlop);

	final Map<int, VelocityTracker> _velocityTrackers = <int, VelocityTracker>{};
  final Map<int, Offset> _moveDeltaBeforeFrame = <int, Offset>{};
  Duration? _frameTimeStamp;
  Offset _lastUpdatedDeltaForPan = Offset.zero;
	final Map<int, Duration> _pointerDownTimes = <int, Duration>{};

	bool _hasSufficientDurationToAccept(PointerEvent event) {
		if (_pointerDownTimes[event.pointer] != null) {
			return _weakSlowAcceptTime.compareTo(event.timeStamp - _pointerDownTimes[event.pointer]!).isNegative;
		}
		return false;
	}

	@override
	bool isPointerAllowed(PointerEvent event) {
		if (_initialButtons == null) {
			switch (event.buttons) {
				case kPrimaryButton:
					if (onDown == null &&
							onStart == null &&
							onUpdate == null &&
							onEnd == null &&
							onCancel == null) {
						return false;
					}
					break;
				default:
					return false;
			}
		} else {
			// There can be multiple drags simultaneously. Their effects are combined.
			if (event.buttons != _initialButtons) {
				return false;
			}
		}
		return super.isPointerAllowed(event as PointerDownEvent);
	}

	@override
	void addAllowedPointer(PointerEvent event) {
		startTrackingPointer(event.pointer, event.transform);
		_velocityTrackers[event.pointer] = velocityTrackerBuilder(event);
		if (_state == _DragState.ready) {
			_state = _DragState.possible;
			_initialPosition = OffsetPair(global: event.position, local: event.localPosition);
			_initialButtons = event.buttons;
			_pendingDragOffset = OffsetPair.zero;
			_globalDistanceMoved = 0.0;
      _globalMoved = Offset.zero;
			_lastPendingEventTimestamp = event.timeStamp;
			_lastTransform = event.transform;
			_checkDown();
		} else if (_state == _DragState.accepted) {
			resolve(GestureDisposition.accepted);
		}
	}

  @override
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) => true;

  @override
  void addAllowedPointerPanZoom(PointerPanZoomStartEvent event) {
    super.addAllowedPointerPanZoom(event);
		startTrackingPointer(event.pointer);
    _velocityTrackers[event.pointer] = velocityTrackerBuilder(event);
    if (_state == _DragState.ready) {
      _state = _DragState.possible;
      _initialPosition = OffsetPair(global: event.position, local: event.localPosition);
      _initialButtons = kPrimaryButton;
      _pendingDragOffset = OffsetPair.zero;
      _globalDistanceMoved = 0.0;
      _globalMoved = Offset.zero;
      _lastPendingEventTimestamp = event.timeStamp;
      _lastTransform = event.transform;
      _checkDown();
    } else if (_state == _DragState.accepted) {
      resolve(GestureDisposition.accepted);
    }
  }

  bool _shouldTrackMoveEvent(int pointer) {
    final bool result;
    switch (multitouchDragStrategy) {
      case MultitouchDragStrategy.sumAllPointers:
      case MultitouchDragStrategy.averageBoundaryPointers:
        result = true;
      case MultitouchDragStrategy.latestPointer:
        result = _activePointer == null || pointer == _activePointer;
    }
    return result;
  }

  void _recordMoveDeltaForMultitouch(int pointer, Offset localDelta) {
    if (multitouchDragStrategy != MultitouchDragStrategy.averageBoundaryPointers) {
      assert(_frameTimeStamp == null);
      assert(_moveDeltaBeforeFrame.isEmpty);
      return;
    }

    assert(_frameTimeStamp == SchedulerBinding.instance.currentSystemFrameTimeStamp);

    if (_state != _DragState.accepted || localDelta == Offset.zero) {
      return;
    }

    if (_moveDeltaBeforeFrame.containsKey(pointer)) {
      final Offset offset = _moveDeltaBeforeFrame[pointer]!;
      _moveDeltaBeforeFrame[pointer] = offset + localDelta;
    } else {
      _moveDeltaBeforeFrame[pointer] = localDelta;
    }
  }

  double _getSumDelta({
    required int pointer,
    required bool positive,
    required _DragDirection axis,
  }) {
    double sum = 0.0;

    if (!_moveDeltaBeforeFrame.containsKey(pointer)) {
      return sum;
    }

    final Offset offset = _moveDeltaBeforeFrame[pointer]!;
    if (positive) {
      if (axis == _DragDirection.vertical) {
        sum = max(offset.dy, 0.0);
      } else {
        sum = max(offset.dx, 0.0);
      }
    } else {
      if (axis == _DragDirection.vertical) {
        sum = min(offset.dy, 0.0);
      } else {
        sum = min(offset.dx, 0.0);
      }
    }

    return sum;
  }

  int? _getMaxSumDeltaPointer({
    required bool positive,
    required _DragDirection axis,
  }) {
    if (_moveDeltaBeforeFrame.isEmpty) {
      return null;
    }

    int? ret;
    double? max;
    double sum;
    for (final int pointer in _moveDeltaBeforeFrame.keys) {
      sum = _getSumDelta(pointer: pointer, positive: positive, axis: axis);
      if (ret == null) {
        ret = pointer;
        max = sum;
      } else {
        if (positive) {
          if (sum > max!) {
            ret = pointer;
            max = sum;
          }
        } else {
          if (sum < max!) {
            ret = pointer;
            max = sum;
          }
        }
      }
    }
    assert(ret != null);
    return ret;
  }

  Offset _resolveLocalDeltaForMultitouch(int pointer, Offset localDelta) {
    if (multitouchDragStrategy != MultitouchDragStrategy.averageBoundaryPointers) {
      if (_frameTimeStamp != null) {
        _moveDeltaBeforeFrame.clear();
        _frameTimeStamp = null;
        _lastUpdatedDeltaForPan = Offset.zero;
      }
      return localDelta;
    }

    final Duration currentSystemFrameTimeStamp = SchedulerBinding.instance.currentSystemFrameTimeStamp;
    if (_frameTimeStamp != currentSystemFrameTimeStamp) {
      _moveDeltaBeforeFrame.clear();
      _lastUpdatedDeltaForPan = Offset.zero;
      _frameTimeStamp = currentSystemFrameTimeStamp;
    }

    assert(_frameTimeStamp == SchedulerBinding.instance.currentSystemFrameTimeStamp);

    final _DragDirection? axis = _getPrimaryDragAxis();

    if (_state != _DragState.accepted || localDelta == Offset.zero || (_moveDeltaBeforeFrame.isEmpty && axis != null)) {
      return localDelta;
    }

    final double dx,dy;
    if (axis == _DragDirection.horizontal) {
      dx = _resolveDelta(pointer: pointer, axis: _DragDirection.horizontal, localDelta: localDelta);
      assert(dx.abs() <= localDelta.dx.abs());
      dy = 0.0;
    } else if (axis == _DragDirection.vertical) {
      dx = 0.0;
      dy = _resolveDelta(pointer: pointer, axis: _DragDirection.vertical, localDelta: localDelta);
      assert(dy.abs() <= localDelta.dy.abs());
    } else {
      final double averageX = _resolveDeltaForPanGesture(axis: _DragDirection.horizontal, localDelta: localDelta);
      final double averageY = _resolveDeltaForPanGesture(axis: _DragDirection.vertical, localDelta: localDelta);
      final Offset updatedDelta = Offset(averageX, averageY) - _lastUpdatedDeltaForPan;
      _lastUpdatedDeltaForPan = Offset(averageX, averageY);
      dx = updatedDelta.dx;
      dy = updatedDelta.dy;
    }

    return Offset(dx, dy);
  }

  double _resolveDelta({
    required int pointer,
    required _DragDirection axis,
    required Offset localDelta,
  }) {
    final bool positive = axis == _DragDirection.horizontal ? localDelta.dx > 0 : localDelta.dy > 0;
    final double delta = axis == _DragDirection.horizontal ? localDelta.dx : localDelta.dy;
    final int? maxSumDeltaPointer = _getMaxSumDeltaPointer(positive: positive, axis: axis);
    assert(maxSumDeltaPointer != null);

    if (maxSumDeltaPointer == pointer) {
      return delta;
    } else {
      final double maxSumDelta = _getSumDelta(pointer: maxSumDeltaPointer!, positive: positive, axis: axis);
      final double curPointerSumDelta = _getSumDelta(pointer: pointer, positive: positive, axis: axis);
      if (positive) {
        if (curPointerSumDelta + delta > maxSumDelta) {
          return curPointerSumDelta + delta - maxSumDelta;
        } else {
          return 0.0;
        }
      } else {
        if (curPointerSumDelta + delta < maxSumDelta) {
          return curPointerSumDelta + delta - maxSumDelta;
        } else {
          return 0.0;
        }
      }
    }
  }

  double _resolveDeltaForPanGesture({
    required _DragDirection axis,
    required Offset localDelta,
  }) {
    final double delta = axis == _DragDirection.horizontal ? localDelta.dx : localDelta.dy;
    final int pointerCount = _acceptedActivePointers.length;
    assert(pointerCount >= 1);

    double sum = delta;
    for (final Offset offset in _moveDeltaBeforeFrame.values) {
      if (axis == _DragDirection.horizontal) {
        sum += offset.dx;
      } else {
        sum += offset.dy;
      }
    }
    return sum / pointerCount;
  }

  @override
  void handleEvent(PointerEvent event) {
    assert(_state != _DragState.ready);
    if (!event.synthesized
        && (event is PointerDownEvent || event is PointerMoveEvent || event is PointerPanZoomUpdateEvent)) {
      final VelocityTracker tracker = _velocityTrackers[event.pointer]!;
      if (event is PointerPanZoomUpdateEvent) {
        tracker.addPosition(event.timeStamp, event.pan);
      }
      else {
        tracker.addPosition(event.timeStamp, event.localPosition);
      }
    }

    if (event is PointerMoveEvent && _shouldTrackMoveEvent(event.pointer)) {
      if (event.buttons != _initialButtons) {
        _giveUpPointer(event.pointer);
        return;
      }
      final Offset resolvedDelta = _resolveLocalDeltaForMultitouch(event.pointer, event.localDelta);
      if (_state == _DragState.accepted) {
        _checkUpdate(
          sourceTimeStamp: event.timeStamp,
          delta: _getDeltaForDetails(resolvedDelta),
          primaryDelta: _getPrimaryValueFromOffset(resolvedDelta),
          globalPosition: event.position,
          localPosition: event.localPosition,
        );
      } else {
        _pendingDragOffset += OffsetPair(local: event.localDelta, global: event.delta);
        _lastPendingEventTimestamp = event.timeStamp;
        _lastTransform = event.transform;
        final Offset movedLocally = _getDeltaForDetails(event.localDelta);
        final Matrix4? localToGlobalTransform = event.transform == null ? null : Matrix4.tryInvert(event.transform!);
        _globalDistanceMoved += PointerEvent.transformDeltaViaPositions(
          transform: localToGlobalTransform,
          untransformedDelta: movedLocally,
          untransformedEndPosition: event.localPosition,
        ).distance * (_getPrimaryValueFromOffset(movedLocally) ?? 1).sign;
        _globalMoved += PointerEvent.transformDeltaViaPositions(
          transform: localToGlobalTransform,
          untransformedDelta: movedLocally,
          untransformedEndPosition: event.localPosition,
        );
        resolve(GestureDisposition.accepted, bid: _calculateAcceptFactor(event, gestureSettings?.touchSlop));
      }
      _recordMoveDeltaForMultitouch(event.pointer, event.localDelta);
    }
    if (event is PointerPanZoomUpdateEvent) {
      final Offset resolvedDelta = _resolveLocalDeltaForMultitouch(event.pointer, event.panDelta);
      if (_state == _DragState.accepted) {
        _checkUpdate(
          sourceTimeStamp: event.timeStamp,
          delta: _getDeltaForDetails(resolvedDelta),
          primaryDelta: _getPrimaryValueFromOffset(resolvedDelta),
          globalPosition: event.position + event.pan,
          localPosition: event.localPosition + event.pan
        );
      }
      else {
        _pendingDragOffset += OffsetPair(local: event.panDelta, global: event.panDelta);
        _lastPendingEventTimestamp = event.timeStamp;
        _lastTransform = event.transform;
        final Offset movedLocally = _getDeltaForDetails(event.panDelta);
        final Matrix4? localToGlobalTransform = event.transform == null ? null : Matrix4.tryInvert(event.transform!);
        _globalDistanceMoved += PointerEvent.transformDeltaViaPositions(
          transform: localToGlobalTransform,
          untransformedDelta: movedLocally,
          untransformedEndPosition: event.localPosition + event.pan
        ).distance * (_getPrimaryValueFromOffset(movedLocally) ?? 1).sign;
        _globalMoved += PointerEvent.transformDeltaViaPositions(
          transform: localToGlobalTransform,
          untransformedDelta: movedLocally,
          untransformedEndPosition: event.localPosition + event.pan
        );
        resolve(GestureDisposition.accepted, bid: _calculateAcceptFactor(event, gestureSettings?.touchSlop));
      }
      _recordMoveDeltaForMultitouch(event.pointer, event.panDelta);
    }
    if (event is PointerUpEvent || event is PointerCancelEvent || event is PointerPanZoomEndEvent) {
      _giveUpPointer(event.pointer);
    }
  }

	final List<int> _acceptedActivePointers = <int>[];
  int? _activePointer;

	@override
	void acceptGesture(int pointer) {
		super.acceptGesture(pointer);
		assert(!_acceptedActivePointers.contains(pointer));
		_acceptedActivePointers.add(pointer);
    _activePointer = pointer;
		if (_state != _DragState.accepted) {
			_state = _DragState.accepted;
			final OffsetPair delta = _pendingDragOffset;
			final Duration timestamp = _lastPendingEventTimestamp!;
			final Matrix4? transform = _lastTransform;
			final Offset localUpdateDelta;
			switch (dragStartBehavior) {
				case DragStartBehavior.start:
					_initialPosition = _initialPosition + delta;
					localUpdateDelta = Offset.zero;
					break;
				case DragStartBehavior.down:
					localUpdateDelta = _getDeltaForDetails(delta.local);
					break;
			}
			_pendingDragOffset = OffsetPair.zero;
			_lastPendingEventTimestamp = null;
			_lastTransform = null;
			_checkStart(timestamp, pointer);
			if (localUpdateDelta != Offset.zero && onUpdate != null) {
				final Matrix4? localToGlobal = transform != null ? Matrix4.tryInvert(transform) : null;
				final Offset correctedLocalPosition = _initialPosition.local + localUpdateDelta;
				final Offset globalUpdateDelta = PointerEvent.transformDeltaViaPositions(
					untransformedEndPosition: correctedLocalPosition,
					untransformedDelta: localUpdateDelta,
					transform: localToGlobal,
				);
				final OffsetPair updateDelta = OffsetPair(local: localUpdateDelta, global: globalUpdateDelta);
				final OffsetPair correctedPosition = _initialPosition + updateDelta; // Only adds delta for down behaviour
				_checkUpdate(
					sourceTimeStamp: timestamp,
					delta: localUpdateDelta,
					primaryDelta: _getPrimaryValueFromOffset(localUpdateDelta),
					globalPosition: correctedPosition.global,
					localPosition: correctedPosition.local,
				);
			}
		}
	}

	@override
	void rejectGesture(int pointer) {
		super.rejectGesture(pointer);
		_giveUpPointer(pointer);
	}

	@override
	void didStopTrackingLastPointer(int pointer) {
		assert(_state != _DragState.ready);
		switch(_state) {
			case _DragState.ready:
				break;

			case _DragState.possible:
				resolve(GestureDisposition.rejected);
				_checkCancel();
				break;

			case _DragState.accepted:
				_checkEnd(pointer);
				break;
		}
		_velocityTrackers.clear();
		_initialButtons = null;
		_state = _DragState.ready;
	}

	void _giveUpPointer(int pointer) {
		stopTrackingPointer(pointer);
		// If we never accepted the pointer, we reject it since we are no longer
		// interested in winning the gesture arena for it.
		if (!_acceptedActivePointers.remove(pointer)) {
			resolvePointer(pointer, GestureDisposition.rejected);
		}

    _moveDeltaBeforeFrame.remove(pointer);
    if (_activePointer == pointer) {
      _activePointer =
        _acceptedActivePointers.isNotEmpty ? _acceptedActivePointers.first : null;
    }
	}

	void _checkDown() {
		assert(_initialButtons == kPrimaryButton);
		if (onDown != null) {
			final DragDownDetails details = DragDownDetails(
				globalPosition: _initialPosition.global,
				localPosition: _initialPosition.local,
			);
			invokeCallback<void>('onDown', () => onDown!(details));
		}
	}

	void _checkStart(Duration timestamp, int pointer) {
		assert(_initialButtons == kPrimaryButton);
		if (onStart != null) {
			final DragStartDetails details = DragStartDetails(
				sourceTimeStamp: timestamp,
				globalPosition: _initialPosition.global,
				localPosition: _initialPosition.local,
				kind: getKindForPointer(pointer),
			);
			invokeCallback<void>('onStart', () => onStart!(details));
		}
	}

	void _checkUpdate({
		Duration? sourceTimeStamp,
		required Offset delta,
		double? primaryDelta,
		required Offset globalPosition,
		Offset? localPosition,
	}) {
		assert(_initialButtons == kPrimaryButton);
		if (onUpdate != null) {
			final DragUpdateDetails details = DragUpdateDetails(
				sourceTimeStamp: sourceTimeStamp,
				delta: delta,
				primaryDelta: primaryDelta,
				globalPosition: globalPosition,
				localPosition: localPosition,
			);
			invokeCallback<void>('onUpdate', () => onUpdate!(details));
		}
	}

	void _checkEnd(int pointer) {
		if (onEnd == null) {
			return;
		}

		final VelocityTracker tracker = _velocityTrackers[pointer]!;
		final VelocityEstimate? estimate = tracker.getVelocityEstimate();

		DragEndDetails? details;
		final String Function() debugReport;
		if (estimate == null) {
			debugReport = () => 'Could not estimate velocity.';
		} else {
			details = _considerFling(estimate, tracker.kind);
			debugReport = (details != null)
				? () => '$estimate; fling at ${details!.velocity}.'
				: () => '$estimate; judged to not be a fling.';
		}
		details ??= DragEndDetails(primaryVelocity: 0.0);

		invokeCallback<void>('onEnd', () => onEnd!(details!), debugReport: debugReport);
	}

	void _checkCancel() {
		assert(_initialButtons == kPrimaryButton);
		if (onCancel != null) {
			invokeCallback<void>('onCancel', onCancel!);
		}
	}

	@override
	void dispose() {
		_velocityTrackers.clear();
		super.dispose();
	}
	@override
	void debugFillProperties(DiagnosticPropertiesBuilder properties) {
		super.debugFillProperties(properties);
		properties.add(EnumProperty<DragStartBehavior>('start behavior', dragStartBehavior));
	}
}

class WeakVerticalDragGestureRecognizer extends WeakDragGestureRecognizer {
	final double weakness;
	final double? sign;

	WeakVerticalDragGestureRecognizer({
		required this.weakness,
		this.sign,
		Object? debugOwner,
		Set<PointerDeviceKind>? supportedDevices = _kTouchLikeDeviceTypes
	}) : super(debugOwner: debugOwner, supportedDevices: supportedDevices);

	@override
	bool isFlingGesture(VelocityEstimate estimate, PointerDeviceKind kind) {
		final double minVelocity = minFlingVelocity ?? kMinFlingVelocity;
		final double minDistance = minFlingDistance ?? computeHitSlop(kind, gestureSettings);
		return estimate.pixelsPerSecond.dy.abs() > minVelocity && estimate.offset.dy.abs() > minDistance;
	}

  @override
  DragEndDetails? _considerFling(VelocityEstimate estimate, PointerDeviceKind kind) {
    if (!isFlingGesture(estimate, kind)) {
      return null;
    }
    final double maxVelocity = maxFlingVelocity ?? kMaxFlingVelocity;
    final double dy = clampDouble(estimate.pixelsPerSecond.dy, -maxVelocity, maxVelocity);
    return DragEndDetails(
      velocity: Velocity(pixelsPerSecond: Offset(0, dy)),
      primaryVelocity: dy,
    );
  }

	@override
	double _calculateAcceptFactor(PointerEvent event, double? deviceTouchSlop) {
		if (_globalDistanceMoved.sign != sign?.sign) {
			return 0;
		}
		if (_hasSufficientDurationToAccept(event)) {
			return _globalDistanceMoved.abs() / computeHitSlop(event.kind, gestureSettings);
		}
		return _globalDistanceMoved.abs() / (weakness * computeHitSlop(event.kind, gestureSettings));
	}

	@override
	Offset _getDeltaForDetails(Offset delta) => Offset(0.0, delta.dy);

	@override
	double _getPrimaryValueFromOffset(Offset value) => value.dy;

  @override
  _DragDirection? _getPrimaryDragAxis() => _DragDirection.vertical;

	@override
	String get debugDescription => 'vertical drag';
}

class WeakHorizontalDragGestureRecognizer extends WeakDragGestureRecognizer {
	double weakness;
	double? sign;

	WeakHorizontalDragGestureRecognizer({
		required this.weakness,
		this.sign,
		Object? debugOwner,
		Set<PointerDeviceKind>? supportedDevices = _kTouchLikeDeviceTypes
	}) : super(debugOwner: debugOwner, supportedDevices: supportedDevices);

	@override
	bool isFlingGesture(VelocityEstimate estimate, PointerDeviceKind kind) {
		final double minVelocity = minFlingVelocity ?? kMinFlingVelocity;
		final double minDistance = minFlingDistance ?? computeHitSlop(kind, gestureSettings);
		return estimate.pixelsPerSecond.dx.abs() > minVelocity && estimate.offset.dx.abs() > minDistance;
	}

  @override
  DragEndDetails? _considerFling(VelocityEstimate estimate, PointerDeviceKind kind) {
    if (!isFlingGesture(estimate, kind)) {
      return null;
    }
    final double maxVelocity = maxFlingVelocity ?? kMaxFlingVelocity;
    final double dx = clampDouble(estimate.pixelsPerSecond.dx, -maxVelocity, maxVelocity);
    return DragEndDetails(
      velocity: Velocity(pixelsPerSecond: Offset(dx, 0)),
      primaryVelocity: dx,
    );
  }

	@override
	double _calculateAcceptFactor(PointerEvent event, double? deviceTouchSlop) {
		if (_globalDistanceMoved.sign != sign?.sign) {
			return 0;
		}
		if (_hasSufficientDurationToAccept(event)) {
			return _globalDistanceMoved.abs() / computeHitSlop(event.kind, gestureSettings);
		}
		return _globalDistanceMoved.abs() / (weakness * computeHitSlop(event.kind, gestureSettings));
	}

	@override
	Offset _getDeltaForDetails(Offset delta) => Offset(delta.dx, 0.0);

	@override
	double _getPrimaryValueFromOffset(Offset value) => value.dx;

  @override
  _DragDirection? _getPrimaryDragAxis() => _DragDirection.horizontal;

	@override
	String get debugDescription => 'horizontal drag';
}

class WeakPanGestureRecognizer extends WeakDragGestureRecognizer {
	final double weakness;
	final bool allowedToAccept;
	final Set<AxisDirection> allowedDirections;
	final bool Function(Offset localOrigin)? shouldAcceptRegardlessOfGlobalMovementDirection;

	WeakPanGestureRecognizer({
		required this.weakness,
		this.allowedToAccept = true,
		this.shouldAcceptRegardlessOfGlobalMovementDirection,
		this.allowedDirections = const {
      AxisDirection.up,
      AxisDirection.down,
      AxisDirection.left,
      AxisDirection.right,
    },
		Set<PointerDeviceKind>? supportedDevices = _kTouchLikeDeviceTypes,
		Object? debugOwner
	}) : super(debugOwner: debugOwner, supportedDevices: supportedDevices);

	@override
	bool isFlingGesture(VelocityEstimate estimate, PointerDeviceKind kind) {
		final double minVelocity = minFlingVelocity ?? kMinFlingVelocity;
		final double minDistance = minFlingDistance ?? computeHitSlop(kind, gestureSettings);
		return estimate.pixelsPerSecond.distanceSquared > minVelocity * minVelocity
				&& estimate.offset.distanceSquared > minDistance * minDistance;
	}

  @override
  DragEndDetails? _considerFling(VelocityEstimate estimate, PointerDeviceKind kind) {
    if (!isFlingGesture(estimate, kind)) {
      return null;
    }
    final Velocity velocity = Velocity(pixelsPerSecond: estimate.pixelsPerSecond)
        .clampMagnitude(minFlingVelocity ?? kMinFlingVelocity, maxFlingVelocity ?? kMaxFlingVelocity);
    return DragEndDetails(velocity: velocity);
  }

  bool _globalMovementDirectionIsOK() {
    if (shouldAcceptRegardlessOfGlobalMovementDirection?.call(_initialPosition.local) ?? false) {
      return true;
    }
    return allowedDirections.any((d) {
      switch (d) {
        case AxisDirection.up:
          return _globalMoved.direction.withinRange(math.pi * -0.75, math.pi * -0.25);
        case AxisDirection.down:
          return _globalMoved.direction.withinRange(math.pi * 0.25, math.pi * 0.75);
        case AxisDirection.left:
          return _globalMoved.direction.abs() > 0.75;
        case AxisDirection.right:
          return _globalMoved.direction.abs() < 0.25;
      }
    });
  }

	@override
	double _calculateAcceptFactor(PointerEvent event, double? deviceTouchSlop) {
		if (!allowedToAccept || !_globalMovementDirectionIsOK()) {
			return 0;
		}
		if (_hasSufficientDurationToAccept(event)) {
			return _globalDistanceMoved.abs() / computeHitSlop(event.kind, gestureSettings);
		}
		return _globalDistanceMoved.abs() / (weakness * computeHitSlop(event.kind, gestureSettings));
	}

	@override
	Offset _getDeltaForDetails(Offset delta) => delta;

	@override
	double? _getPrimaryValueFromOffset(Offset value) => null;

	@override
	String get debugDescription => 'pan';
}

enum _DragDirection {
  horizontal,
  vertical
}

// The following is copied from 'multitap.dart', with the arena holding and releasing removed.

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
       initialButtons = event.buttons,
       _doubleTapMinTimeCountdown = _CountdownZoned(duration: doubleTapMinTime);

  final DeviceGestureSettings? gestureSettings;
  final int pointer;
  final GestureArenaEntry entry;
  final Offset _initialGlobalPosition;
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

/// Recognizes when the user has tapped the screen at the same location twice in
/// quick succession.
///
/// [DoubleTapGestureRecognizer] competes on pointer events of [kPrimaryButton]
/// only when it has a non-null callback. If it has no callbacks, it is a no-op.
///
class WeakDoubleTapGestureRecognizer extends GestureRecognizer {
  /// Create a gesture recognizer for double taps.
  ///
  /// {@macro flutter.gestures.GestureRecognizer.supportedDevices}
  WeakDoubleTapGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
  });

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
    if (_firstTap != null) {
      if (!_firstTap!.isWithinGlobalTolerance(event, kDoubleTapSlop)) {
        // Ignore out-of-bounds second taps.
        return;
      } else if (!_firstTap!.hasElapsedMinTime() || !_firstTap!.hasSameButton(event)) {
        // Restart when the second tap is too close to the first (touch screens
        // often detect touches intermittently), or when buttons mismatch.
        _reset();
        return _trackTap(event);
      } else if (onDoubleTapDown != null) {
        final TapDownDetails details = TapDownDetails(
          globalPosition: event.position,
          localPosition: event.localPosition,
          kind: getKindForPointer(event.pointer),
        );
        invokeCallback<void>('onDoubleTapDown', () => onDoubleTapDown!(details));
      }
    }
    _trackTap(event);
  }

  void _trackTap(PointerDownEvent event) {
    _stopDoubleTapTimer();
    final _TapTracker tracker = _TapTracker(
      event: event,
      entry: GestureBinding.instance.gestureArena.add(event.pointer, this),
      doubleTapMinTime: kDoubleTapMinTime,
      gestureSettings: gestureSettings,
    );
    _trackers[event.pointer] = tracker;
    tracker.startTrackingPointer(_handleEvent, event.transform);
  }

  void _handleEvent(PointerEvent event) {
    final _TapTracker tracker = _trackers[event.pointer]!;
    if (event is PointerUpEvent) {
      if (_firstTap == null) {
        _registerFirstTap(tracker);
      } else {
        _registerSecondTap(tracker);
      }
    } else if (event is PointerMoveEvent) {
      if (!tracker.isWithinGlobalTolerance(event, kDoubleTapTouchSlop)) {
        _reject(tracker);
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
    }
    _clearTrackers();
  }

  void _registerFirstTap(_TapTracker tracker) {
    _startDoubleTapTimer();
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
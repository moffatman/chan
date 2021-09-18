// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This file is a modified copy of Flutter's cupertino `route.dart`
// allowing to change the width of area where back swipe gesture is accepted

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:vector_math/vector_math_64.dart';

enum _DragState {
	ready,
	possible,
	accepted,
}


const _WEAK_SLOW_ACCEPT_TIME = Duration(milliseconds: 50);
abstract class WeakDragGestureRecognizer extends OneSequenceGestureRecognizer {
	WeakDragGestureRecognizer({
		Object? debugOwner,
		Set<PointerDeviceKind>? supportedDevices,
		this.dragStartBehavior = DragStartBehavior.start,
		this.velocityTrackerBuilder = _defaultBuilder,
	}) : super(debugOwner: debugOwner, supportedDevices: supportedDevices);

	static VelocityTracker _defaultBuilder(PointerEvent event) => VelocityTracker.withKind(event.kind);

	DragStartBehavior dragStartBehavior;

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

	late double _globalDistanceMoved;

	bool isFlingGesture(VelocityEstimate estimate, PointerDeviceKind kind);

	Offset _getDeltaForDetails(Offset delta);
	double? _getPrimaryValueFromOffset(Offset value);
	bool _hasSufficientGlobalDistanceToAccept(PointerEvent event, double? deviceTouchSlop);

	final Map<int, VelocityTracker> _velocityTrackers = <int, VelocityTracker>{};
	final Map<int, Duration> _pointerDownTimes = <int, Duration>{};

	bool _hasSufficientDurationToAccept(PointerEvent event) {
		if (_pointerDownTimes[event.pointer] != null) {
			return _WEAK_SLOW_ACCEPT_TIME.compareTo(event.timeStamp - _pointerDownTimes[event.pointer]!).isNegative;
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
							onCancel == null)
						return false;
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
			_lastPendingEventTimestamp = event.timeStamp;
			_lastTransform = event.transform;
			_checkDown();
		} else if (_state == _DragState.accepted) {
			resolve(GestureDisposition.accepted);
		}
	}

  @override
  void handleEvent(PointerEvent event) {
    assert(_state != _DragState.ready);
    if (!event.synthesized
        && (event is PointerDownEvent || event is PointerMoveEvent)) {
      final VelocityTracker tracker = _velocityTrackers[event.pointer]!;
      tracker.addPosition(event.timeStamp, event.localPosition);
    }

    if (event is PointerMoveEvent) {
      if (event.buttons != _initialButtons) {
        _giveUpPointer(event.pointer);
        return;
      }
      if (_state == _DragState.accepted) {
        _checkUpdate(
          sourceTimeStamp: event.timeStamp,
          delta: _getDeltaForDetails(event.localDelta),
          primaryDelta: _getPrimaryValueFromOffset(event.localDelta),
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
        if (_hasSufficientGlobalDistanceToAccept(event, gestureSettings?.touchSlop))
          resolve(GestureDisposition.accepted);
      }
    }
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _giveUpPointer(event.pointer);
    }
  }

	final Set<int> _acceptedActivePointers = <int>{};

	@override
	void acceptGesture(int pointer) {
		assert(!_acceptedActivePointers.contains(pointer));
		_acceptedActivePointers.add(pointer);
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
		if (!_acceptedActivePointers.remove(pointer))
			resolvePointer(pointer, GestureDisposition.rejected);
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
		assert(_initialButtons == kPrimaryButton);
		if (onEnd == null)
			return;

		final VelocityTracker tracker = _velocityTrackers[pointer]!;

		final DragEndDetails details;
		final String Function() debugReport;

		final VelocityEstimate? estimate = tracker.getVelocityEstimate();
		if (estimate != null && isFlingGesture(estimate, tracker.kind)) {
			final Velocity velocity = Velocity(pixelsPerSecond: estimate.pixelsPerSecond)
				.clampMagnitude(minFlingVelocity ?? kMinFlingVelocity, maxFlingVelocity ?? kMaxFlingVelocity);
			details = DragEndDetails(
				velocity: velocity,
				primaryVelocity: _getPrimaryValueFromOffset(velocity.pixelsPerSecond),
			);
			debugReport = () {
				return '$estimate; fling at $velocity.';
			};
		} else {
			details = DragEndDetails(
				velocity: Velocity.zero,
				primaryVelocity: 0.0,
			);
			debugReport = () {
				if (estimate == null)
					return 'Could not estimate velocity.';
				return '$estimate; judged to not be a fling.';
			};
		}
		invokeCallback<void>('onEnd', () => onEnd!(details), debugReport: debugReport);
	}

	void _checkCancel() {
		assert(_initialButtons == kPrimaryButton);
		if (onCancel != null)
			invokeCallback<void>('onCancel', onCancel!);
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
		Set<PointerDeviceKind>? supportedDevices
	}) : super(debugOwner: debugOwner, supportedDevices: supportedDevices);

	@override
	bool isFlingGesture(VelocityEstimate estimate, PointerDeviceKind kind) {
		final double minVelocity = minFlingVelocity ?? kMinFlingVelocity;
		final double minDistance = minFlingDistance ?? computeHitSlop(kind, gestureSettings);
		return estimate.pixelsPerSecond.dy.abs() > minVelocity && estimate.offset.dy.abs() > minDistance;
	}

	@override
	bool _hasSufficientGlobalDistanceToAccept(PointerEvent event, double? deviceTouchSlop) {
		return (sign != null && _globalDistanceMoved.sign == sign!.sign) &&  _globalDistanceMoved.abs() > (weakness * computeHitSlop(event.kind, gestureSettings)) || (
			(_globalDistanceMoved.abs() > computeHitSlop(event.kind, gestureSettings)) &&
			_hasSufficientDurationToAccept(event)
		);
	}

	@override
	Offset _getDeltaForDetails(Offset delta) => Offset(0.0, delta.dy);

	@override
	double _getPrimaryValueFromOffset(Offset value) => value.dy;

	@override
	String get debugDescription => 'vertical drag';
}

class WeakHorizontalDragGestureRecognizer extends WeakDragGestureRecognizer {
	final double weakness;
	final double? sign;

	WeakHorizontalDragGestureRecognizer({
		required this.weakness,
		this.sign,
		Object? debugOwner,
		Set<PointerDeviceKind>? supportedDevices
	}) : super(debugOwner: debugOwner, supportedDevices: supportedDevices);

	@override
	bool isFlingGesture(VelocityEstimate estimate, PointerDeviceKind kind) {
		final double minVelocity = minFlingVelocity ?? kMinFlingVelocity;
		final double minDistance = minFlingDistance ?? computeHitSlop(kind, gestureSettings);
		return estimate.pixelsPerSecond.dx.abs() > minVelocity && estimate.offset.dx.abs() > minDistance;
	}

	@override
	bool _hasSufficientGlobalDistanceToAccept(PointerEvent event, double? deviceTouchSlop) {
		return (sign != null && _globalDistanceMoved.sign == sign!.sign) &&  _globalDistanceMoved.abs() > (weakness * computeHitSlop(event.kind, gestureSettings)) || (
			(_globalDistanceMoved.abs() > computeHitSlop(event.kind, gestureSettings)) &&
			_hasSufficientDurationToAccept(event)
		);
	}

	@override
	Offset _getDeltaForDetails(Offset delta) => Offset(delta.dx, 0.0);

	@override
	double _getPrimaryValueFromOffset(Offset value) => value.dx;

	@override
	String get debugDescription => 'horizontal drag';
}

class WeakPanGestureRecognizer extends WeakDragGestureRecognizer {
	final double weakness;
	final bool allowedToAccept;
	final double? sign;

	WeakPanGestureRecognizer({
		required this.weakness,
		this.allowedToAccept = true,
		this.sign,
		Object? debugOwner
	}) : super(debugOwner: debugOwner);

	@override
	bool isFlingGesture(VelocityEstimate estimate, PointerDeviceKind kind) {
		final double minVelocity = minFlingVelocity ?? kMinFlingVelocity;
		final double minDistance = minFlingDistance ?? computeHitSlop(kind, gestureSettings);
		return estimate.pixelsPerSecond.distanceSquared > minVelocity * minVelocity
				&& estimate.offset.distanceSquared > minDistance * minDistance;
	}

	@override
	bool _hasSufficientGlobalDistanceToAccept(PointerEvent event, double? deviceTouchSlop) {
		return allowedToAccept && (sign != null && _globalDistanceMoved.sign == sign!.sign) && _globalDistanceMoved.abs() > (weakness * computePanSlop(event.kind, gestureSettings)) || (
			(_globalDistanceMoved.abs() > computePanSlop(event.kind, gestureSettings)) &&
			_hasSufficientDurationToAccept(event)
		);
	}

	@override
	Offset _getDeltaForDetails(Offset delta) => delta;

	@override
	double? _getPrimaryValueFromOffset(Offset value) => null;

	@override
	String get debugDescription => 'pan';
}

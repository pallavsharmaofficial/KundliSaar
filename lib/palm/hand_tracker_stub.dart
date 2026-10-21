import 'hand_tracker.dart';

/// For a platform that has neither the native runtime (hand_tracker_native.dart)
/// nor a browser's (hand_tracker_web.dart): no automatic capture, and the hand
/// tracer is used instead.
const bool handDetectionSupported = false;

HandTracker createHandTracker() =>
    throw UnsupportedError('Hand detection is not available on this platform.');

import 'hand_tracker.dart';

/// Browsers cannot run the native model runtime, so the web build has no
/// automatic capture and sends people to the hand tracer.
const bool handDetectionSupported = false;

HandTracker createHandTracker() =>
    throw UnsupportedError('Hand detection needs the phone app.');

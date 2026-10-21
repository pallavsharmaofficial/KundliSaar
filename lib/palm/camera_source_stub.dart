import 'camera_source.dart';

/// Only the web build has a browser camera; everywhere else the `camera`
/// plugin is used and this is never called.
CameraSource createWebCameraSource() =>
    throw UnsupportedError('The browser camera needs the web build.');

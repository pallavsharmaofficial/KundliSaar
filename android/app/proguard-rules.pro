# Flutter and its plugins keep their entry points through reflection.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Speech recognition and text to speech are resolved by name at runtime.
-keep class com.csdcorp.speech_to_text.** { *; }
-keep class com.tundralabs.fluttertts.** { *; }

# TensorFlow Lite (LiteRT) is reached from Dart through its C API, not through
# Java, so nothing here is called by name. These rules only stop the shrinker
# failing on the GPU delegate classes the runtime's AAR mentions but this app
# never loads.
-dontwarn org.tensorflow.lite.gpu.**
-dontwarn com.google.ai.edge.litert.gpu.**
-keep class org.tensorflow.lite.** { *; }
-keep class com.google.ai.edge.litert.** { *; }

# PathSaathi R8/ProGuard keep rules
# Keep native-bridged plugin classes so R8 shrinking doesn't strip code that is
# only referenced from native (.so) or via reflection/JNI.

# Flutter engine
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# On-device AI runtimes (loaded via JNI / FFI)
-keep class ai.onnxruntime.** { *; }
-keep class com.whispercpp.** { *; }
-keep class org.tensorflow.** { *; }
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**
# MediaPipe uses protobuf-generated classes that are referenced reflectively.
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**
-keepclassmembers class * extends com.google.protobuf.GeneratedMessageLite {
    <fields>;
}

# Biometric (local_auth)
-keep class androidx.biometric.** { *; }
-keep class androidx.fragment.app.** { *; }

# Keep annotations & native method names
-keepattributes *Annotation*
-keepclasseswithmembernames class * {
    native <methods>;
}

# OkHttp / Dio networking — these optional TLS providers are referenced but not
# bundled; tell R8 they are safe to ignore so minify doesn't fail.
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
-dontwarn okhttp3.internal.platform.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okio.**

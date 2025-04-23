# Flutter/Dart specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Add project specific ProGuard rules here.
# By default, the flags in this file are appended to flags specified
# in /Users/USERNAME/Library/Android/sdk/tools/proguard/proguard-android.txt
#
# You can edit this file to add custom rules.

# Keep rules for packages reported missing by R8 (broadened)
-keep class com.google.mediapipe.** { *; }
-keep class com.google.protobuf.** { *; }
-keep class javax.lang.model.** { *; }
-keep class org.bouncycastle.** { *; }
-keep class org.conscrypt.** { *; }
-keep class org.openjsse.** { *; }
-keep class com.google.android.play.core.** { *; }

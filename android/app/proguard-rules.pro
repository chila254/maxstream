# Flutter
-keepattributes Signature
-keep class com.myapp.inappwebview.** { *; }
-keep class io.flutter.app.FlutterApplication { *; }
-keep class io.flutter.plugin.common.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn com.myapp.inappwebview.**
-dontwarn io.flutter.app.**
-dontwarn io.flutter.plugin.**

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Kotlin
-dontwarn kotlin.**
-dontwarn kotlin.Metadata

# WorkManager
-keep class androidx.work.** { *; }
-keep interface androidx.work.** { *; }
-dontwarn androidx.work.**
-keepclassmembers class androidx.work.** { *; }

# Keep line numbers for debugging
-keepattributes SourceFile,LineNumberTable
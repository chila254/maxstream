# Flutter
-keepattributes Signature
-keep class com.myapp.inappwebview.** { *; }
-keep class io.flutter.app.FlutterApplication { *; }
-keep class io.flutter.plugin.common.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn com.myapp.inappwebview.**
-dontwarn io.flutter.app.**
-dontwarn io.flutter.plugin.$

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Kotlin
-dontwarn kotlin.**
-dontwarn kotlin.Metadata

# org.json - Firebase Database uses its own bundled version; prevent R8 from
# renaming JSONStringer fields which causes NoSuchFieldError at runtime.
-keep class org.json.** { *; }

# flutter_local_notifications - keep drawable resources referenced by string at runtime
-keep class **.R$drawable { *; }
-keepclassmembers class **.R$drawable { *; }

# Keep line numbers for debugging
-keepattributes SourceFile,LineNumberTable

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

# Keep line numbers for debugging
-keepattributes SourceFile,LineNumberTable

# VLC - stable decoder for VidLink (flutter_vlc_player 7.4.4 bundles 5 ABIs)
-keep class org.videolan.** { *; }
-keep class org.videolan.libvlc.** { *; }
-dontwarn org.videolan.**
-keep class com.example.flutter_vlc_player.** { *; }

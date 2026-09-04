# MaxStream TV (native Kotlin) ProGuard rules.
-keep class com.maxstream.app.** { *; }

# Media3 / ExoPlayer + nextlib FFmpeg extension
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**
-keep class io.github.anilbeesetti.** { *; }
-dontwarn io.github.anilbeesetti.**

# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**

# Gson (kept for safety / future use)
-keepattributes Signature,InnerClasses,EnclosingMethod
-keep class com.google.code.gson.** { *; }

# Glide
-keep public class * implements com.bumptech.glide.module.GlideModule
-keep class * extends com.bumptech.glide.module.AppGlideModule

# Leanback
-keep class androidx.leanback.** { *; }
-dontwarn androidx.leanback.**

# Coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

# Keep generic signatures for runtime type resolution.
-keepattributes Signature,InnerClasses,EnclosingMethod

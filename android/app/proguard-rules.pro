# Standard Kotlin / Retrofit / Moshi ProGuard rules.
# R8 full mode is enabled by default in AGP 8.0+.

# Keep Moshi JSON model classes (reflection-based deserialization)
-keep class com.whowouldin.whowouldwin.network.** { *; }
-keepclassmembers class com.whowouldin.whowouldwin.network.** { *; }

# Retrofit
-keepattributes Signature, InnerClasses, EnclosingMethod
-keepattributes RuntimeVisibleAnnotations, RuntimeVisibleParameterAnnotations
-keepattributes AnnotationDefault
-keep,allowobfuscation,allowshrinking interface retrofit2.Call
-keep,allowobfuscation,allowshrinking class retrofit2.Response

# OkHttp
-dontwarn okhttp3.internal.platform.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# Moshi
-keepclasseswithmembers class * {
    @com.squareup.moshi.* <methods>;
}
-keep @com.squareup.moshi.JsonQualifier interface *

# Coroutines
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}

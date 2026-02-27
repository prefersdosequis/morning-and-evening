# Add project specific ProGuard rules here.
# Used in release builds (minifyEnabled=true in build.gradle) for code obfuscation and shrinking.

# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Preserve line numbers for stack traces
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Keep application class
-keep public class * extends android.app.Application

# Keep MainActivity
-keep class com.tkirk.morning_and_evening_app.MainActivity { *; }

# Prevent obfuscation of model classes (if you add any in the future)
# -keep class com.tkirk.morning_and_evening_app.models.** { *; }

# Google Fonts
-keep class com.google.gson.** { *; }
-keepattributes *Annotation*

# SharedPreferences
-keep class android.content.SharedPreferences { *; }
-keep class android.content.SharedPreferences$Editor { *; }


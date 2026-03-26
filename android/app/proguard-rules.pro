# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core (referenced by Flutter engine internally)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class androidx.security.crypto.** { *; }

# image_picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# app_links / deep links
-keep class com.urbandroid.applinks.** { *; }

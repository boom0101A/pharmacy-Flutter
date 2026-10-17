# ML Kit — نستخدم التعرف على النص اللاتيني فقط.
# حزمة google_mlkit_text_recognition تشير إلى بقية اللغات في الكود،
# لكننا لا نضمّن مكتباتها، فيتوقف R8 عند فقدها. هذه القواعد تُسكت ذلك.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

-keep class com.google.mlkit.vision.text.latin.** { *; }
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text** { *; }

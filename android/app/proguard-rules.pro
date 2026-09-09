# Liblinphone uses JNI callbacks; its classes must survive shrinking.
-keep class org.linphone.core.** { *; }
-keep class org.linphone.mediastream.** { *; }
-dontwarn org.linphone.**

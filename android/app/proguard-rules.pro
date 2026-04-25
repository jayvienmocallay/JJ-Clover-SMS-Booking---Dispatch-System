# Keep SQLCipher native classes from being stripped during release builds
-keep class net.sqlcipher.** { *; }

# Keep SMS broadcast entry points used by Android and the telephony plugin.
-keep class com.jjclover.smartrelay.DefaultSmsReceiver { *; }
-keep class com.jjclover.smartrelay.SmsBackgroundBridge { *; }
-keep class com.jjclover.smartrelay.DefaultMmsReceiver { *; }
-keep class com.jjclover.smartrelay.RespondViaMessageService { *; }
-keep class com.shounakmulay.telephony.** { *; }

# Keep SQLCipher native classes from being stripped during release builds
-keep class net.sqlcipher.** { *; }

@echo off
"C:\\Users\\USER\\AppData\\Local\\Android\\sdk\\cmake\\3.22.1\\bin\\cmake.exe" ^
  "-HC:\\flutter\\packages\\flutter_tools\\gradle\\src\\main\\groovy" ^
  "-DCMAKE_SYSTEM_NAME=Android" ^
  "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON" ^
  "-DCMAKE_SYSTEM_VERSION=26" ^
  "-DANDROID_PLATFORM=android-26" ^
  "-DANDROID_ABI=armeabi-v7a" ^
  "-DCMAKE_ANDROID_ARCH_ABI=armeabi-v7a" ^
  "-DANDROID_NDK=C:\\Users\\USER\\AppData\\Local\\Android\\sdk\\ndk\\29.0.13113456" ^
  "-DCMAKE_ANDROID_NDK=C:\\Users\\USER\\AppData\\Local\\Android\\sdk\\ndk\\29.0.13113456" ^
  "-DCMAKE_TOOLCHAIN_FILE=C:\\Users\\USER\\AppData\\Local\\Android\\sdk\\ndk\\29.0.13113456\\build\\cmake\\android.toolchain.cmake" ^
  "-DCMAKE_MAKE_PROGRAM=C:\\Users\\USER\\AppData\\Local\\Android\\sdk\\cmake\\3.22.1\\bin\\ninja.exe" ^
  "-DCMAKE_LIBRARY_OUTPUT_DIRECTORY=C:\\Users\\USER\\resellerapp\\android\\app\\build\\intermediates\\cxx\\RelWithDebInfo\\4kh1w6c3\\obj\\armeabi-v7a" ^
  "-DCMAKE_RUNTIME_OUTPUT_DIRECTORY=C:\\Users\\USER\\resellerapp\\android\\app\\build\\intermediates\\cxx\\RelWithDebInfo\\4kh1w6c3\\obj\\armeabi-v7a" ^
  "-DCMAKE_BUILD_TYPE=RelWithDebInfo" ^
  "-BC:\\Users\\USER\\resellerapp\\android\\app\\.cxx\\RelWithDebInfo\\4kh1w6c3\\armeabi-v7a" ^
  -GNinja ^
  -Wno-dev ^
  --no-warn-unused-cli

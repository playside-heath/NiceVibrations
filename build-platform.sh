#!/bin/bash
# Copyright (c) Meta Platforms, Inc. and affiliates. 

exit_with_failure()
{
    echo "❌ $*" 1>&2 ; exit 1;
}

# Git Bash on GitHub Actions often reports `uname -s` as MINGW64_NT-* while OSTYPE is not `msys*`.
is_windows_build_host() {
    [[ "${OSTYPE:-}" == "msys"* || "${OSTYPE:-}" == "cygwin"* ]] && return 0
    case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) return 0 ;; esac
    return 1
}

TARGET=$1

# Source paths
SOURCE_ANDROID_AAR_FILE=interfaces/android/LofeltHaptics/LofeltHaptics/build/outputs/aar/LofeltHaptics-release.aar
SOURCE_ANDROID_JAVADOC_DIR=interfaces/android/LofeltHaptics/javadoc

SOURCE_IOS_DEVICE_FRAMEWORK_DIR=interfaces/ios/LofeltHaptics/build/XCArchives/ios.xcarchive/Products/Library/Frameworks
SOURCE_IOS_SIMULATOR_FRAMEWORK_DIR=interfaces/ios/LofeltHaptics/build/XCArchives/ios_simulator.xcarchive/Products/Library/Frameworks
SOURCE_IOS_XCFRAMEWORK_DIR=interfaces/ios/LofeltHaptics/build/XCFramework

# Destination paths
DEST_UNITY_PLUGIN_DIR=interfaces/unity/NiceVibrations/Assets/NiceVibrations/Plugins
DEST_UNITY_ANDROID_PLUGIN_DIR=$DEST_UNITY_PLUGIN_DIR/Android/libs
DEST_UNITY_IOS_PLUGIN_DIR=$DEST_UNITY_PLUGIN_DIR/iOS
DEST_UNITY_MAC_PLUGIN_DIR=$DEST_UNITY_PLUGIN_DIR/macOS
DEST_UNITY_WIN_PLUGIN_DIR=$DEST_UNITY_PLUGIN_DIR/Windows/x64
DEST_ANDROID_LIBRARY_DIR=android-library
DEST_IOS_FRAMEWORK_DIR=ios-framework

# Validate arguments.
if [[ "$TARGET" != "ios" && "$TARGET" != "android" && "$TARGET" != "unity-editor-plugin-host" ]]; then
    exit_with_failure "First argument is the target and needs to be 'ios', 'android' or 'unity-editor-plugin-host'."
fi

if [ "$TARGET" = "ios" ]; then
    echo "➡️ Cleaning copied build artifacts"
    rm -rf $DEST_IOS_FRAMEWORK_DIR/
    rm -rf $DEST_UNITY_IOS_PLUGIN_DIR/LofeltHaptics.framework/

    echo "➡️ Building for iOS"
    cd "interfaces/ios/LofeltHaptics"
    sh build-xcframework.sh || exit_with_failure "Building iOS XCFramework failed"
    cd ../../..

    echo "➡️ Copying build artifacts"
    mkdir -p $DEST_IOS_FRAMEWORK_DIR || exit_with_failure "Unable to create iOS framework directory"
    mkdir -p $DEST_IOS_FRAMEWORK_DIR/Xcode11 || exit_with_failure "Unable to create iOS framework directory"
    mkdir -p $DEST_IOS_FRAMEWORK_DIR/Xcode12AndHigher || exit_with_failure "Unable to create iOS framework directory"
    mkdir -p $DEST_UNITY_IOS_PLUGIN_DIR || exit_with_failure "Unable to create Android Unity asset directory"

    cp -vr $SOURCE_IOS_DEVICE_FRAMEWORK_DIR/ $DEST_IOS_FRAMEWORK_DIR/Xcode11/devices/ || exit_with_failure "Copying iOS devices framework failed"
    cp -vr $SOURCE_IOS_SIMULATOR_FRAMEWORK_DIR/ $DEST_IOS_FRAMEWORK_DIR/Xcode11/simulator/ || exit_with_failure "Copying iOS simulator framework failed"
    cp -vr $SOURCE_IOS_XCFRAMEWORK_DIR/ $DEST_IOS_FRAMEWORK_DIR/Xcode12AndHigher/ || exit_with_failure "Copying iOS XCFramework failed"
    cp -vR $SOURCE_IOS_DEVICE_FRAMEWORK_DIR/* $DEST_UNITY_IOS_PLUGIN_DIR/
    echo "✅ Building for iOS done! 🍏"
elif [ "$TARGET" = "android" ]; then
    echo "➡️ Cleaning copied build artifacts"
    rm -rf $DEST_ANDROID_LIBRARY_DIR/
    rm -rf $DEST_UNITY_ANDROID_PLUGIN_DIR/libs/LofeltHaptics.aar

    echo "➡️ Building for Android"
    cd "interfaces/android/LofeltHaptics"
    sh build-library.sh || exit_with_failure "Building Android library failed"
    cd ../../..

    echo "➡️ Copying build artifacts"
    mkdir -p $DEST_ANDROID_LIBRARY_DIR || exit_with_failure "Unable to create Android library directory"
    mkdir -p $DEST_UNITY_ANDROID_PLUGIN_DIR || exit_with_failure "Unable to create Android asset directory"

    cp -vr $SOURCE_ANDROID_AAR_FILE $DEST_ANDROID_LIBRARY_DIR/LofeltHaptics.aar || exit_with_failure "Copying Android library failed"
    cp -vr $SOURCE_ANDROID_JAVADOC_DIR/ $DEST_ANDROID_LIBRARY_DIR/docs || exit_with_failure "Copying Android API documentation failed"
    cp -vr $SOURCE_ANDROID_AAR_FILE $DEST_UNITY_ANDROID_PLUGIN_DIR/LofeltHaptics.aar
    echo "✅ Building for Android done! 🤖"
elif [ "$TARGET" = "unity-editor-plugin-host" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "➡️ Cleaning copied build artifacts"
        rm -rf $DEST_UNITY_MAC_PLUGIN_DIR/libnice_vibrations_editor_plugin.dylib
        echo "➡️ Building Unity editor plugin for the host system"
        cd "unity-editor-plugin"
        sh build-shared-library.sh || exit_with_failure "Failed to build Unity editor plugin"
        echo "➡️ Copying build artifacts to Unity folder"
        cd ../
        cp target/universal/release/libnice_vibrations_editor_plugin.dylib $DEST_UNITY_MAC_PLUGIN_DIR/ || exit_with_failure "Failed to copy Unity editor plugin"
    elif is_windows_build_host; then
        echo "➡️ Cleaning copied build artifacts"
        rm -rf $DEST_UNITY_WIN_PLUGIN_DIR/nice_vibrations_editor_plugin.dll
        echo "➡️ Building Unity editor plugin for the host system"
        cd "unity-editor-plugin"
        sh build-shared-library.sh || exit_with_failure "Failed to build Unity editor plugin"
        echo "➡️ Copying build artifacts to Unity folder"
        cd ../
        mkdir -p $DEST_UNITY_WIN_PLUGIN_DIR && cp target/release/nice_vibrations_editor_plugin.dll $DEST_UNITY_WIN_PLUGIN_DIR/ || exit_with_failure "Failed to copy Unity editor plugin"
    else
        exit_with_failure "Unsupported host OS"
    fi

    echo "✅ Building unity-editor-plugin-host done!"
fi

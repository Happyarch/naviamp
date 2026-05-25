#!/usr/bin/env sh
# Dev environment for naviamp.
# Usage: source dev-env.sh

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export PATH="$ANDROID_HOME/platform-tools:$PATH"
export PATH="$ANDROID_HOME/build-tools/36.0.0:$PATH"

# Suppresses "upstream unknown source" warning from shallow submodule clone
export FLUTTER_GIT_URL=https://github.com/flutter/flutter.git

# Rust toolchain (required by flutter_discord_rpc / cargokit)
export PATH="$HOME/.cargo/bin:$PATH"

echo "naviamp dev env ready"
echo "  JAVA_HOME    = $JAVA_HOME"
echo "  ANDROID_HOME = $ANDROID_HOME"
echo "  flutter      = use ./flutterw"

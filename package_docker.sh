#!/usr/bin/env bash

# Docker packages bundler
# Purpose: Extract multiple packages, strip /data/adb paths, and combine into a single Docker archive
# Handles special filenames with colons by renaming before extraction

set -eo pipefail # Exit immediately if command fails
trap 'echo "Error occurred at line $LINENO"; cleanup' ERR

STAGING_DIR="staging_$(date +%s)"
OUTPUT_FILE="docker.tar.xz"
STRIP_PATH="/data/adb/docker"
PACKAGES=(
    "containerd"
    "docker"
    "runc"
    "docker-compose"
    "resolv-conf"
    "libandroid-support"
    "libaio"
    "lvm2"
    "readline"
    "ncurses"
)

dir=$(pwd)

# Setup logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Cleanup function
cleanup() {
    log "Cleaning up temporary files..."
    if [ -d "$STAGING_DIR" ]; then
        rm -rf "$STAGING_DIR"
    fi
    log "Cleanup completed"
}

# Find package files that match the base name
find_package_files() {
    local pkg_name="$1"
    local found_files=()

    if compgen -G "${pkg_name}-*.tar*" >/dev/null; then
        found_files+=("${pkg_name}-"*.pkg.tar.xz)
    fi

    for file in "${found_files[@]}"; do
        echo "$file"
    done
}

# Extract packages and strip /data/adb paths
extract_packages() {
    log "Creating temporary directories"
    mkdir -p "$STAGING_DIR"

    log "Beginning extraction and processing of packages..."

    for package in "${PACKAGES[@]}"; do
        log "Searching for package: $package"

        # Find package files using custom function
        readarray -t package_files < <(find_package_files "$package")

        if [ ${#package_files[@]} -eq 0 ]; then
            log "Warning: No files found for package '$package', skipping"
            continue
        fi

        for pkg_file in "${package_files[@]}"; do
            if [ -f "$pkg_file" ]; then
                log "Processing file: $pkg_file"

                if [[ "$pkg_file" == *:* ]]; then
                    new_filename="${pkg_file//:/}"
                    mv "$pkg_file" "$new_filename"
                    pkg_file="$new_filename"
                fi

                if [[ "$pkg_file" == *.tar.xz ]]; then
                    tar -xf "$pkg_file" -C "$STAGING_DIR" || {
                        log "Error: Failed to extract $pkg_file"
                        continue
                    }
                else
                    log "Error: Unsupported archive format for $pkg_file"
                    continue
                fi
            fi
        done
    done

    log "Extraction and processing completed successfully"
}

build_tiny() {
    if [ -z "$ANDROID_NDK" ]; then
        echo "Please set ANDROID_NDK environment variable to your NDK installation path"
        echo "Example: export ANDROID_NDK=/path/to/android-ndk"
        return 1
    fi

    API=27
    TOOLCHAIN=$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64
    TARGET=aarch64-linux-android
    
    export CC=$TOOLCHAIN/bin/${TARGET}${API}-clang
    export CXX=$TOOLCHAIN/bin/${TARGET}${API}-clang++
    export AR=$TOOLCHAIN/bin/${TARGET}-ar
    export RANLIB=$TOOLCHAIN/bin/${TARGET}-ranlib
    export STRIP=$TOOLCHAIN/bin/${TARGET}-strip
    
    TMPDIR=/tmp/tini-android
    PREFIX=$TMPDIR/output
    mkdir -p $TMPDIR
    cd $TMPDIR
    
    wget -q https://github.com/krallin/tini/archive/v0.19.0.tar.gz
    tar xf v0.19.0.tar.gz
    cd tini-0.19.0
    
    sed -i 's/\([a-zA-Z_][a-zA-Z0-9_]*\s\+[a-zA-Z_][a-zA-Z0-9_]*\s*\)()[ ]*{/\1(void) {/g' src/tini.c
    
    # Create CMakeLists.txt
    cat >CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.10)
project(tini C)
option(MINIMAL "Optimize for size" ON)
set(tini_VERSION_MAJOR 0)
set(tini_VERSION_MINOR 19)
set(tini_VERSION_PATCH 0)
set(TINI_VERSION "${tini_VERSION_MAJOR}.${tini_VERSION_MINOR}.${tini_VERSION_PATCH}")
configure_file(
  "${PROJECT_SOURCE_DIR}/src/tiniConfig.h.in"
  "${PROJECT_BINARY_DIR}/tiniConfig.h"
)
include_directories("${PROJECT_BINARY_DIR}")
set(tini_SOURCES src/tini.c)
add_executable(tini ${tini_SOURCES})
if(MINIMAL)
  target_compile_definitions(tini PRIVATE -DMINIMAL=1)
endif()
target_compile_definitions(tini PRIVATE
  TINI_VERSION="${TINI_VERSION}"
)
install(TARGETS tini
        RUNTIME DESTINATION bin)
EOF

    cat >src/tiniConfig.h.in <<'EOF'
#ifndef TINI_CONFIG_H
#define TINI_CONFIG_H
#define TINI_VERSION_MAJOR @tini_VERSION_MAJOR@
#define TINI_VERSION_MINOR @tini_VERSION_MINOR@
#define TINI_VERSION_PATCH @tini_VERSION_PATCH@
#define TINI_VERSION "@TINI_VERSION@"
#define TINI_GIT ""
#endif
EOF

    mkdir -p build
    cd build
    
    cmake \
        -DCMAKE_SYSTEM_NAME=Android \
        -DCMAKE_SYSTEM_VERSION=$API \
        -DCMAKE_ANDROID_ARCH_ABI=arm64-v8a \
        -DCMAKE_ANDROID_NDK=$ANDROID_NDK \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=$PREFIX \
        -DMINIMAL=ON \
        ..
    
    log "Building tini for Android ARM64"
    make -j$(nproc)
    make install
    
    cd $dir
    cp $PREFIX/bin/tini $dir/$STAGING_DIR$STRIP_PATH/bin/docker-init
    cp $PREFIX/bin/tini $dir/$STAGING_DIR$STRIP_PATH/bin/tini
}

create_archive() {
    log "Creating final archive: $OUTPUT_FILE"

    if [ -f "$OUTPUT_FILE" ]; then
        log "Warning: Overwriting existing $OUTPUT_FILE"
        rm -f "$OUTPUT_FILE"
    fi

    tar -cJf "$OUTPUT_FILE" -C "$STAGING_DIR$STRIP_PATH" . || {
        log "Error: Failed to create $OUTPUT_FILE"
        return 1
    }

    if [ -f "$OUTPUT_FILE" ]; then
        size=$(du -h "$OUTPUT_FILE" | cut -f1)
        log "Successfully created $OUTPUT_FILE (Size: $size)"
        log "Contents summary:"
        tar -tf "$OUTPUT_FILE" | grep -v "/$" | wc -l | xargs -I{} echo "  {} files"
    else
        log "Error: Failed to create $OUTPUT_FILE"
        return 1
    fi
}

postprocess() {
    sed -i "s|\\\$PREFIX|$STRIP_PATH|g" "$STAGING_DIR$STRIP_PATH/etc/containerd/config.toml"
    rm -f "$STAGING_DIR$STRIP_PATH/bin/dockerd"
    rm -rf "$STAGING_DIR$STRIP_PATH/share/man"
    rm -rf "$STAGING_DIR$STRIP_PATH/share/doc"
}

main() {
    log "=== Docker Package Bundling Script ==="
    log "Starting process at $(date)"

    extract_packages
    postprocess
    build_tiny
    create_archive
    log "All operations completed successfully"
}

main
exit 0
#!/bin/bash
#rsiv macOS ビルド
#前提として Homebrew で入れておくもの:
#	brew install glfw libpng jpeg-turbo webp giflib librsvg pkg-config
#アプリ本体は Objective-C（Foundation は本物、UnFoundation.m が包む）
#GLEW は使わない（GLFW_INCLUDE_GLCOREARB で <OpenGL/gl3.h> を直接使う）
set -e
cd "$(dirname "$0")"

BREW_PREFIX=$(brew --prefix)
export PKG_CONFIG_PATH="$BREW_PREFIX/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

clang \
	-O2 \
	-DGL_SILENCE_DEPRECATION \
	-I"$BREW_PREFIX/include" \
	-x objective-c \
	src/main.m \
	src/gpuui.m \
	src/testpattern.m \
	src/chinko.m \
	src/thumbnail.m \
	src/macopen.m \
	src/UnFoundation.m \
	\
	src/format/*.m \
	\
	-x objective-c++ \
	src/format/jpeg.mm \
	\
	-L"$BREW_PREFIX/lib" \
	-lglfw -lpng -ljpeg -lwebp -lgif -lwebpdemux \
	$(pkg-config --cflags --libs librsvg-2.0) \
	-framework Foundation -framework OpenGL \
	-o rsiv.out

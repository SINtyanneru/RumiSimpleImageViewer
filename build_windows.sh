#!/bin/bash
#rsiv Windows ビルド（MSYS2 MINGW64 のシェルで実行する）
#前提として入れておくパッケージ:
#	pacman -S mingw-w64-x86_64-clang mingw-w64-x86_64-pkg-config
#	pacman -S mingw-w64-x86_64-gnustep-make mingw-w64-x86_64-gnustep-base
#	pacman -S mingw-w64-x86_64-glfw mingw-w64-x86_64-glew
#	pacman -S mingw-w64-x86_64-libpng mingw-w64-x86_64-libjpeg-turbo
#	pacman -S mingw-w64-x86_64-libwebp mingw-w64-x86_64-giflib
#	pacman -S mingw-w64-x86_64-librsvg
set -e

clang \
	src/main.m \
	src/gpuui.m \
	src/testpattern.m \
	src/chinko.m \
	src/thumbnail.m \
	\
	src/format/*.m \
	\
	-lglfw3 -lglew32 -lopengl32 -lgdi32 -lpng -ljpeg -lwebp -lgif -lwebpdemux -lpthread \
	$(pkg-config --cflags --libs librsvg-2.0) \
	$(gnustep-config --objc-flags) $(gnustep-config --base-libs) \
	-mwindows \
	-o rsiv.exe

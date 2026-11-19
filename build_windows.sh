#!/bin/bash
#rsiv Windows ビルド（MSYS2 MINGW64 のシェルで実行する）
#前提として入れておくパッケージ:
#	pacman -S mingw-w64-x86_64-clang mingw-w64-x86_64-pkg-config
#	pacman -S mingw-w64-x86_64-glfw mingw-w64-x86_64-glew
#	pacman -S mingw-w64-x86_64-libpng mingw-w64-x86_64-libjpeg-turbo
#	pacman -S mingw-w64-x86_64-libwebp mingw-w64-x86_64-giflib
#	pacman -S mingw-w64-x86_64-librsvg
#アプリ本体は C としてコンパイルする（ObjC ランタイムは通らない。Foundation の代わりは UnFoundation.c）
#jpeg だけは MinGW の COM ヘッダーの都合で Objective-C++ のままにする
set -e

clang \
	-x c \
	src/main.m \
	src/gpuui.m \
	src/testpattern.m \
	src/chinko.m \
	src/thumbnail.m \
	src/UnFoundation.c \
	\
	src/format/*.m \
	\
	-x objective-c++ \
	src/format/jpeg.mm \
	\
	-lglfw3 -lglew32 -lopengl32 -lgdi32 -lpng -ljpeg -lwebp -lgif -lwebpdemux -lpthread -lshell32 \
	$(pkg-config --cflags --libs librsvg-2.0) \
	$(pkg-config --cflags --libs freetype2) \
	-mwindows \
	-o rsiv.exe

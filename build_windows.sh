#!/bin/bash
#rsiv Windows ビルド（MSYS2 MINGW64 のシェルで実行する）
#前提として入れておくパッケージ:
#	pacman -S mingw-w64-x86_64-clang mingw-w64-x86_64-pkg-config
#	pacman -S mingw-w64-x86_64-gcc（libobjc と objc ヘッダー用。Foundation は自前の UnFoundation を使う）
#	pacman -S mingw-w64-x86_64-glfw mingw-w64-x86_64-glew
#	pacman -S mingw-w64-x86_64-libpng mingw-w64-x86_64-libjpeg-turbo
#	pacman -S mingw-w64-x86_64-libwebp mingw-w64-x86_64-giflib
#	pacman -S mingw-w64-x86_64-librsvg
set -e

GCC_INCLUDE=$(gcc -print-file-name=include)

clang \
	-fobjc-runtime=gcc -fconstant-string-class=NSConstantString -I"$GCC_INCLUDE" \
	src/main.m \
	src/gpuui.m \
	src/testpattern.m \
	src/chinko.m \
	src/thumbnail.m \
	src/UnFoundation.m \
	\
	src/format/*.m src/format/*.mm \
	\
	-lglfw3 -lglew32 -lopengl32 -lgdi32 -lpng -ljpeg -lwebp -lgif -lwebpdemux -lpthread -lobjc -lshell32 \
	$(pkg-config --cflags --libs librsvg-2.0) \
	-mwindows \
	-o rsiv.exe

@echo off
setlocal
rem ============================================================
rem rsiv Windows ビルド
rem 前提: MSYS2 (C:\msys64) の MINGW64 環境
rem 入れておくパッケージ:
rem   pacman -S mingw-w64-x86_64-clang mingw-w64-x86_64-pkg-config
rem   pacman -S mingw-w64-x86_64-gnustep-make mingw-w64-x86_64-gnustep-base
rem   pacman -S mingw-w64-x86_64-glfw mingw-w64-x86_64-glew
rem   pacman -S mingw-w64-x86_64-libpng mingw-w64-x86_64-libjpeg-turbo
rem   pacman -S mingw-w64-x86_64-libwebp mingw-w64-x86_64-giflib
rem   pacman -S mingw-w64-x86_64-librsvg
rem ============================================================

set MSYS2_ROOT=C:\msys64
set PATH=%MSYS2_ROOT%\mingw64\bin;%MSYS2_ROOT%\usr\bin;%PATH%

rem gnustep-config と pkg-config はシェルスクリプトなので sh 経由で取得する
for /f "tokens=*" %%i in ('sh -c "gnustep-config --objc-flags"') do set OBJC_FLAGS=%%i
for /f "tokens=*" %%i in ('sh -c "gnustep-config --base-libs"') do set BASE_LIBS=%%i
for /f "tokens=*" %%i in ('sh -c "pkg-config --cflags --libs librsvg-2.0"') do set RSVG_FLAGS=%%i

clang src\main.m src\gpuui.m src\testpattern.m src\chinko.m src\thumbnail.m ^
  src\format\format.m src\format\png.m src\format\jpeg.m src\format\webp.m ^
  src\format\gif.m src\format\mag.m src\format\maki.m src\format\bmp.m ^
  src\format\pi.m src\format\svg.m ^
  -lglfw3 -lglew32 -lopengl32 -lgdi32 -lpng -ljpeg -lwebp -lgif -lwebpdemux -lpthread ^
  %RSVG_FLAGS% %OBJC_FLAGS% %BASE_LIBS% -mwindows -o rsiv.exe

if errorlevel 1 (
	echo build failed
	exit /b 1
)
echo built: rsiv.exe
endlocal

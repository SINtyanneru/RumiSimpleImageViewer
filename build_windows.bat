@echo off
setlocal
rem ============================================================
rem rsiv Windows ビルド
rem 実体は build_windows.sh で、MSYS2 の bash から実行する
rem （gnustep-config や pkg-config はシェル側の道具なので、
rem   cmd から直接呼ぶと別の物を掴んでしまうため）
rem MSYS2 の置き場所が違うときは MSYS2_ROOT を変えること
rem ============================================================

set MSYS2_ROOT=C:\msys64

cd /d %~dp0
"%MSYS2_ROOT%\usr\bin\bash.exe" -lc "cd \"$(cygpath -u '%CD%')\" && ./build_windows.sh"

if errorlevel 1 (
	echo build failed
	exit /b 1
)
echo built: rsiv.exe
endlocal

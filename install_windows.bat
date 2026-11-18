@echo off
setlocal
rem ============================================================
rem rsiv Windows インストール（ユーザー単位、管理者権限は不要）
rem インストール先: %LOCALAPPDATA%\Programs\rsiv
rem ============================================================

set MSYS2_ROOT=C:\msys64
set INSTALL_DIR=%LOCALAPPDATA%\Programs\rsiv
set PROGID=rsiv.Document

if not exist "%~dp0rsiv.exe" (
	echo rsiv.exe ga nai. saki ni build_windows.bat de build shite ne
	exit /b 1
)

if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
copy /y "%~dp0rsiv.exe" "%INSTALL_DIR%\rsiv.exe" >nul
echo copy: rsiv.exe --- %INSTALL_DIR%\rsiv.exe

rem 実行に要る DLL を一緒にコピーする
rem まず、この bat と同じ場所にある DLL（配布物に同梱された物）を全部入れる
if exist "%~dp0*.dll" copy /y "%~dp0*.dll" "%INSTALL_DIR%\" >nul
rem 足りない物は MSYS2 から補う（実際に要る物は環境で変わるので、足りないときは ldd rsiv.exe で確認）
for %%d in (glfw3.dll glew32.dll libpng16-16.dll libjpeg-8.dll libwebp-7.dll libwebpdemux-2.dll libgif-7.dll librsvg-2-2.dll libcairo-2.dll libgobject-2.0-0.dll libglib-2.0-0.dll libgio-2.0-0.dll libwinpthread-1.dll) do (
	if not exist "%INSTALL_DIR%\%%d" if exist "%MSYS2_ROOT%\mingw64\bin\%%d" copy /y "%MSYS2_ROOT%\mingw64\bin\%%d" "%INSTALL_DIR%\" >nul
)
echo copy: DLLs

rem ファイル関連付け（HKCU\Software\Classes）
reg add "HKCU\Software\Classes\%PROGID%" /ve /d "RSIV Image" /f >nul
reg add "HKCU\Software\Classes\%PROGID%\DefaultIcon" /ve /d "%INSTALL_DIR%\rsiv.exe,0" /f >nul
reg add "HKCU\Software\Classes\%PROGID%\shell\open\command" /ve /d "\"%INSTALL_DIR%\rsiv.exe\" \"%%1\"" /f >nul

rem MAG / MAKI / PI は他に開くアプリがほぼ無いので既定にする
for %%e in (.mag .mki .pi) do (
	reg add "HKCU\Software\Classes\%%e" /ve /d "%PROGID%" /f >nul
	reg add "HKCU\Software\Classes\%%e" /v "PerceivedType" /d "image" /f >nul
)
reg add "HKCU\Software\Classes\.mag" /v "Content Type" /d "image/x-mag" /f >nul
reg add "HKCU\Software\Classes\.mki" /v "Content Type" /d "image/x-maki" /f >nul
reg add "HKCU\Software\Classes\.pi" /v "Content Type" /d "image/x-pi" /f >nul

rem 一般の画像形式は「プログラムから開く」に出すだけ（既定は奪わない）
for %%e in (.png .jpg .jpeg .gif .webp .bmp .svg) do (
	reg add "HKCU\Software\Classes\%%e\OpenWithProgids" /v "%PROGID%" /t REG_NONE /f >nul
)

echo installed: %INSTALL_DIR%\rsiv.exe
endlocal

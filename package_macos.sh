#!/bin/bash
#rsiv macOS パッケージング（.app 化 + dmg 作成）
#前提として build_macos.sh の前提に加えて入れておくもの:
#	brew install dylibbundler create-dmg
set -e
cd "$(dirname "$0")"

./build_macos.sh

#app バンドルを組み立てる
rm -rf rsiv.app
mkdir -p rsiv.app/Contents/MacOS rsiv.app/Contents/Frameworks
cp rsiv.out rsiv.app/Contents/MacOS/rsiv
cp macos/Info.plist rsiv.app/Contents/Info.plist

#Homebrew の dylib をバンドル内に取り込む（Homebrew の無い Mac でも動くように）
dylibbundler -od -cd -b -x rsiv.app/Contents/MacOS/rsiv -d rsiv.app/Contents/Frameworks -p @executable_path/../Frameworks

#アドホック署名（署名が無いと Gatekeeper に起動を止められる）
codesign --force --deep --sign - rsiv.app

#dmg を作る（背景・アイコン位置・Applications へのエイリアス付き）
rm -f rsiv-macos.dmg
create-dmg \
	--volname "rsiv" \
	--background "dmg/background.png" \
	--window-pos 200 120 \
	--window-size 660 400 \
	--icon-size 128 \
	--icon "rsiv.app" 170 190 \
	--hide-extension "rsiv.app" \
	--app-drop-link 490 190 \
	--no-internet-enable \
	rsiv-macos.dmg \
	rsiv.app

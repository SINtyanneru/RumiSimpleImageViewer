#!/bin/bash
set -e

./build_linux.sh
echo "ﾋﾞﾙﾄﾞ: rsiv.out"

sudo cp rsiv.out /bin/rsiv.new
echo "ｺﾋﾟｰ: rsiv.out ---> /bin/rsiv.new"

sudo chmod 755 /bin/rsiv.new
echo "ﾁｪﾝｼﾞﾓｰﾄﾞ: 755 ---> /bin/rsiv"

sudo mv /bin/rsiv.new /bin/rsiv
echo "ｲﾄﾞｳ: /bin/rsiv.new ---> /bin/rsiv"

sudo tee /usr/share/mime/packages/rsiv.xml > /dev/null <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
	<mime-type type="image/x-mag">
		<comment>MAG image</comment>
		<comment xml:lang="ja">MAG画像</comment>
		<magic priority="60">
			<match value="MAKI02 " type="string" offset="0"/>
		</magic>
		<glob pattern="*.mag"/>
		<glob pattern="*.MAG"/>
	</mime-type>
	<mime-type type="image/x-maki">
		<comment>MAKI image</comment>
		<comment xml:lang="ja">MAKI画像</comment>
		<magic priority="60">
			<match value="MAKI01" type="string" offset="0"/>
		</magic>
		<glob pattern="*.mki"/>
		<glob pattern="*.MKI"/>
	</mime-type>
	<mime-type type="image/x-pi">
		<comment>PI image</comment>
		<comment xml:lang="ja">PI画像</comment>
		<glob pattern="*.pi"/>
		<glob pattern="*.PI"/>
	</mime-type>
</mime-info>
EOF
echo "ｶｷｺﾐ: ----> /usr/share/mime/packages/rsiv.xml"

echo "MimeType DB ｺｳｼﾝﾁｭｳ..."
if command -v update-mime-database > /dev/null; then
	sudo update-mime-database /usr/share/mime
fi

sudo tee /usr/share/applications/rsiv.desktop > /dev/null <<'EOF'
[Desktop Entry]
Type=Application
Version=1.0
Name=RSIV
GenericName=Image Viewer
GenericName[ja]=画像ビューア
Comment=RumiSimpleImageViewer
Comment[ja]=るみのシンプルな画像ビュワー
Exec=/bin/rsiv %f
Terminal=false
Categories=Graphics;Viewer;
MimeType=image/png;image/jpeg;image/gif;image/webp;image/bmp;image/svg+xml;
StartupNotify=true
EOF
echo "ｶｷｺﾐ: ----> /usr/share/applications/rsiv.desktop"

echo "ｱﾌﾟﾘDB ｺｳｼﾝﾁｭｳ..."
if command -v update-desktop-database > /dev/null; then
	sudo update-desktop-database /usr/share/applications
fi

echo "MAG MAKI PIｦ ｶﾝﾚﾝｽﾞｹｼﾃｲﾏｽ..."
if command -v xdg-mime > /dev/null; then
	xdg-mime default rsiv.desktop image/x-mag
	xdg-mime default rsiv.desktop image/x-maki
	xdg-mime default rsiv.desktop image/x-pi
fi

sudo cp rsiv.thumbnailer /usr/share/thumbnailers/rsiv.thumbnailer
echo "ｶｷｺﾐ: ----> /usr/share/thumbnailers/rsiv.thumbnailer"

echo "ｶﾝﾘｮｳ, ｲﾝｽﾄｰﾙOK"
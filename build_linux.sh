clang \
	src/main.m \
	src/gpuui.m \
	src/testpattern.m \
	src/chinko.m \
	src/thumbnail.m \
	src/UnFoundation.m \
	\
	src/format/*.m src/format/*.mm \
	\
	-lglfw -lGLEW -lGL -lpng -pthread -ljpeg -lwebp -lgif -lwebpdemux \
	$(pkg-config --cflags --libs freetype2) \
	$(pkg-config --cflags --libs librsvg-2.0) \
	$(gnustep-config --objc-flags) -I "$(gcc -print-file-name=include)" $(gnustep-config --base-libs) \
	-o rsiv.out
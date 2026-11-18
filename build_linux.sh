clang \
	src/main.m \
	src/gpuui.m \
	src/testpattern.m \
	src/chinko.m \
	src/thumbnail.m \
	\
	src/format/*.m \
	\
	-lglfw -lGLEW -lGL -lpng -pthread -ljpeg -lwebp -lgif -lwebpdemux \
	$(pkg-config --cflags --libs librsvg-2.0) \
	$(gnustep-config --objc-flags) -I /usr/lib/gcc/x86_64-linux-gnu/14/include/ $(gnustep-config --base-libs) \
	-o rsiv.out
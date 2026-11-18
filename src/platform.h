//OSごとの差分を吸収する
#ifndef RSIV_PLATFORM_H
#define RSIV_PLATFORM_H

#include <stdio.h>

#ifdef _WIN32

#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <stdlib.h>
#include <string.h>

//WindowsのfopenはUTF-8のパスを解釈しないので、ワイド文字版（_wfopen）を使う
//これをしないと日本語を含むファイル名が開けない
static inline FILE *rsiv_fopen(const char *path, const char *mode) {
	int wlen = MultiByteToWideChar(CP_UTF8, 0, path, -1, NULL, 0);
	if (wlen <= 0)
		return NULL;

	wchar_t *wpath = malloc(sizeof(wchar_t) * (size_t)wlen);
	if (wpath == NULL)
		return NULL;

	MultiByteToWideChar(CP_UTF8, 0, path, -1, wpath, wlen);

	wchar_t wmode[8];
	size_t mlen = strlen(mode);
	if (mlen >= sizeof(wmode) / sizeof(wmode[0])) {
		free(wpath);
		return NULL;
	}
	for (size_t i = 0; i <= mlen; i++)
		wmode[i] = (wchar_t)mode[i];

	FILE *f = _wfopen(wpath, wmode);
	free(wpath);

	return f;
}

#else

static inline FILE *rsiv_fopen(const char *path, const char *mode) {
	return fopen(path, mode);
}

#endif

#endif

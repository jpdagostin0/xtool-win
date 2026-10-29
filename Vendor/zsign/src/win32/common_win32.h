#pragma once

// SwiftPM variant of build/windows/vs2022/zsign/src/common_win32.h.
// OpenSSL and system libraries are linked via Package.swift instead of
// #pragma comment(lib) with paths relative to the VS project.

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <windows.h>
#include <shlobj.h>
#include <Shlwapi.h>
#include <shellapi.h>
#include <direct.h>
#include <io.h>
#include "iconv.h"
#include "getopt.h"

#ifndef PATH_MAX
#define PATH_MAX					4096
#endif
#define strerror(x)					#x
#define _fopen64(fp, path, mode)	{ fopen_s(&fp, path, mode); }

static inline int vasprintf(char** strp, const char* fmt, va_list ap)
{
	va_list ap2;
	va_copy(ap2, ap);
	int len = _vscprintf(fmt, ap2);
	va_end(ap2);
	if (len < 0) {
		*strp = NULL;
		return -1;
	}
	*strp = (char*)malloc((size_t)len + 1);
	if (NULL == *strp) {
		return -1;
	}
	return vsnprintf(*strp, (size_t)len + 1, fmt, ap);
}

static inline int asprintf(char** strp, const char* fmt, ...)
{
	va_list ap;
	va_start(ap, fmt);
	int ret = vasprintf(strp, fmt, ap);
	va_end(ap);
	return ret;
}

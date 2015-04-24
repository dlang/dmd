#ifndef UTILS_H
#define UTILS_H

#if __DMC__
#pragma once
#endif

#if __linux__ || __APPLE__
#define HAS_POSIX_SPAWN 1
#include        <spawn.h>
#if __APPLE__
#include <crt_externs.h>
#endif
#else
#define HAS_POSIX_SPAWN 0
#endif

#if _WIN32

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#include <stdlib.h>
#include <direct.h>
#include <process.h>
#include <errno.h>

#ifndef _INTPTR_T_DEFINED
#ifdef _WIN64
typedef int64_t        intptr_t;
#else
typedef int            intptr_t;
#endif
#define _INTPTR_T_DEFINED
#endif

char *wideToUTF8(const LPCWSTR wstr);
LPCWSTR UTF8toWide(const char *str);
const char **getUTF8argvs(int argc, const wchar_t *wargv[]);
void freeUTF8argvs(int argc, const char *argv[]);
int dspawnv(int mode, const char *file, const char *const *argv);

#endif

char* dgetenv(const char *name);
int dputenv(const char *env);
int dmkdir(const char *name);
int dspawnlp(int mode, const char *file, const char *arg0, const char *arg1, const char *arg2);
int dspawnl(int mode, const char *file, const char *arg0, const char *arg1, const char *arg2);

#endif

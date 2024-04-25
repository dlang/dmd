#ifdef _WIN32

#include <windows.h>

#define LIB_SO "lib.dll"

void *loadLib(const char *name) { return LoadLibraryA(name); }
int closeLib(void *handle) { return FreeLibrary(handle); }
void *loadSym(void *handle, const char *name) { return GetProcAddress(handle, name); }

#else

#include <dlfcn.h>

#if __APPLE__
#define LIB_SO "lib.dylib"
#else
#define LIB_SO "lib.so"
#endif

void *loadLib(const char *name) { return dlopen(name, RTLD_LAZY); }
int closeLib(void *handle) { return dlclose(handle) == 0 ? 1 : 0; }
void *loadSym(void *handle, const char *name) { return dlsym(handle, name); }

#endif

/**
 * D header file for POSIX.
 *
 * Copyright: Public Domain
 * License:   Public Domain
 * Authors:   Sean Kelly
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */
module core.sys.posix.dlfcn;

private import core.sys.posix.config;

extern (C):

//
// XOpen (XSI)
//
/*
RTLD_LAZY
RTLD_NOW
RTLD_GLOBAL
RTLD_LOCAL

int   dlclose(void*);
char* dlerror();
void* dlopen(in char*, int);
void* dlsym(void*, in char*);
*/

version( linux )
{
    const RTLD_LAZY     = 0x00001;
    const RTLD_NOW      = 0x00002;
    const RTLD_GLOBAL   = 0x00100;
    const RTLD_LOCAL    = 0x00000;

    int   dlclose(void*);
    char* dlerror();
    void* dlopen(in char*, int);
    void* dlsym(void*, in char*);
}
else version( darwin )
{
    const RTLD_LAZY     = 0x00001;
    const RTLD_NOW      = 0x00002;
    const RTLD_GLOBAL   = 0x00100;
    const RTLD_LOCAL    = 0x00000;

    int   dlclose(void*);
    char* dlerror();
    void* dlopen(in char*, int);
    void* dlsym(void*, in char*);
}
else version( freebsd )
{
    const RTLD_LAZY     = 1;
    const RTLD_NOW      = 2;
    const RTLD_GLOBAL   = 0x100;
    const RTLD_LOCAL    = 0;

    int   dlclose(void*);
    char* dlerror();
    void* dlopen(in char*, int);
    void* dlsym(void*, in char*);
}

/**
 * D header file for POSIX.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Sean Kelly, Alex Rønne Petersen
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */

/*          Copyright Sean Kelly 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.sys.posix.dlfcn;

private import core.sys.posix.config;

version (Posix):
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
    version (X86)
    {
        enum RTLD_LAZY      = 0x00001;
        enum RTLD_NOW       = 0x00002;
        enum RTLD_GLOBAL    = 0x00100;
        enum RTLD_LOCAL     = 0x00000;
    }
    else version (X86_64)
    {
        enum RTLD_LAZY      = 0x00001;
        enum RTLD_NOW       = 0x00002;
        enum RTLD_GLOBAL    = 0x00100;
        enum RTLD_LOCAL     = 0x00000;
    }
    else version (MIPS32)
    {
        enum RTLD_LAZY      = 0x0001;
        enum RTLD_NOW       = 0x0002;
        enum RTLD_GLOBAL    = 0x0004;
        enum RTLD_LOCAL     = 0;
    }
    else version (PPC)
    {
        enum RTLD_LAZY      = 0x00001;
        enum RTLD_NOW       = 0x00002;
        enum RTLD_GLOBAL    = 0x00100;
        enum RTLD_LOCAL     = 0;
    }
    else version (PPC64)
    {
        enum RTLD_LAZY      = 0x00001;
        enum RTLD_NOW       = 0x00002;
        enum RTLD_GLOBAL    = 0x00100;
        enum RTLD_LOCAL     = 0;
    }
    else version (AArch64)
    {
        enum RTLD_LAZY      = 0x00001;
        enum RTLD_NOW       = 0x00002;
        enum RTLD_GLOBAL    = 0x00100;
        enum RTLD_LOCAL     = 0;
    }
    else
        static assert(0, "unimplemented");

    int   dlclose(void*);
    char* dlerror();
    void* dlopen(in char*, int);
    void* dlsym(void*, in char*);

    deprecated("Please use core.sys.linux.dlfcn for non-POSIX extensions")
    {
        int   dladdr(void* addr, Dl_info* info);
        void* dlvsym(void* handle, in char* symbol, in char* version_);

        struct Dl_info
        {
            const(char)* dli_fname;
            void*        dli_fbase;
            const(char)* dli_sname;
            void*        dli_saddr;
        }
    }
}
else version( OSX )
{
    enum RTLD_LAZY      = 0x00001;
    enum RTLD_NOW       = 0x00002;
    enum RTLD_GLOBAL    = 0x00100;
    enum RTLD_LOCAL     = 0x00000;

    int   dlclose(void*);
    char* dlerror();
    void* dlopen(in char*, int);
    void* dlsym(void*, in char*);
    int   dladdr(void* addr, Dl_info* info);

    struct Dl_info
    {
        const(char)* dli_fname;
        void*        dli_fbase;
        const(char)* dli_sname;
        void*        dli_saddr;
    }
}
else version( FreeBSD )
{
    enum RTLD_LAZY      = 1;
    enum RTLD_NOW       = 2;
    enum RTLD_GLOBAL    = 0x100;
    enum RTLD_LOCAL     = 0;

    int   dlclose(void*);
    char* dlerror();
    void* dlopen(in char*, int);
    void* dlsym(void*, in char*);
    int   dladdr(const(void)* addr, Dl_info* info);

    struct Dl_info
    {
        const(char)* dli_fname;
        void*        dli_fbase;
        const(char)* dli_sname;
        void*        dli_saddr;
    }
}

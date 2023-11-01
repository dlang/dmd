/*************************************************/

// https://issues.dlang.org/show_bug.cgi?id=24187

#ifdef linux
#ifndef __aarch64__
extern _Complex _Float32 cacosf32 (_Complex _Float32 __z) __attribute__ ((__nothrow__ , __leaf__));

extern _Complex _Float32x __cacosf32x (_Complex _Float32x __z) __attribute__ ((__nothrow__ , __leaf__));
#endif
#endif

/**
 * D header file for C99.
 *
 * This contains bindings to selected types and functions from the standard C
 * header $(LINK2 http://pubs.opengroup.org/onlinepubs/009695399/basedefs/string.h.html, <string.h>). Note
 * that this is not automatically generated, and may omit some types/functions
 * from the original C header.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Sean Kelly
 * Source:    $(DRUNTIMESRC core/stdc/_string.d)
 * Standards: ISO/IEC 9899:1999 (E)
 */

module core.stdc.string;

private import core.stdc.stddef; // for size_t

extern (C):
@system:
nothrow:
@nogc:

///
pure void* memchr(in void* s, int c, size_t n);
///
pure int   memcmp(in void* s1, in void* s2, size_t n);
///
pure void* memcpy(void* s1, in void* s2, size_t n);
version (Windows)
{
    ///
    int memicmp(in char* s1, in char* s2, size_t n);
}
///
pure void* memmove(void* s1, in void* s2, size_t n);
///
pure void* memset(void* s, int c, size_t n);

///
pure char*  strcpy(char* s1, in char* s2);
///
pure char*  strncpy(char* s1, in char* s2, size_t n);
///
pure char*  strcat(char* s1, in char* s2);
///
pure char*  strncat(char* s1, in char* s2, size_t n);
///
pure int    strcmp(in char* s1, in char* s2);
///
int    strcoll(in char* s1, in char* s2);
///
pure int    strncmp(in char* s1, in char* s2, size_t n);
///
size_t strxfrm(char* s1, in char* s2, size_t n);
///
pure char*  strchr(in char* s, int c);
///
pure size_t strcspn(in char* s1, in char* s2);
///
pure char*  strpbrk(in char* s1, in char* s2);
///
pure char*  strrchr(in char* s, int c);
///
pure size_t strspn(in char* s1, in char* s2);
///
pure char*  strstr(in char* s1, in char* s2);
///
char*  strtok(char* s1, in char* s2);
///
char*  strerror(int errnum);
version (linux)
{
    ///
    const(char)* strerror_r(int errnum, char* buf, size_t buflen);
}
else version (Posix)
{
    ///
    int strerror_r(int errnum, char* buf, size_t buflen);
}
///
pure size_t strlen(in char* s);
///
char*  strdup(in char *s);

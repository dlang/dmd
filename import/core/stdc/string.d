/**
 * D header file for C99.
 *
 * Copyright: Public Domain
 * License:   Public Domain
 * Authors:   Sean Kelly
 * Standards: ISO/IEC 9899:1999 (E)
 */
module core.stdc.string;

private import core.stdc.stddef; // for size_t

extern (C):

void* memchr(in void* s, int c, size_t n);
int   memcmp(in void* s1, in void* s2, size_t n);
void* memcpy(void* s1, in void* s2, size_t n);
void* memmove(void* s1, in void* s2, size_t n);
void* memset(void* s, int c, size_t n);

char*  strcpy(char* s1, in char* s2);
char*  strncpy(char* s1, in char* s2, size_t n);
char*  strcat(char* s1, in char* s2);
char*  strncat(char* s1, in char* s2, size_t n);
int    strcmp(in char* s1, in char* s2);
int    strcoll(in char* s1, in char* s2);
int    strncmp(in char* s1, in char* s2, size_t n);
size_t strxfrm(char* s1, in char* s2, size_t n);
char*  strchr(in char* s, int c);
size_t strcspn(in char* s1, in char* s2);
char*  strpbrk(in char* s1, in char* s2);
char*  strrchr(in char* s, int c);
size_t strspn(in char* s1, in char* s2);
char*  strstr(in char* s1, in char* s2);
char*  strtok(char* s1, in char* s2);
char*  strerror(int errnum);
size_t strlen(in char* s);

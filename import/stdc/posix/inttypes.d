/**
 * D header file for POSIX.
 *
 * Copyright: Public Domain
 * License:   Public Domain
 * Authors:   Sean Kelly
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */
module stdc.posix.inttypes;

private import stdc.posix.config;
public import stdc.inttypes;

//
// Required
//
/*
intmax_t  imaxabs(intmax_t);
imaxdiv_t imaxdiv(intmax_t, intmax_t);
intmax_t  strtoimax(in char*, char**, int);
uintmax_t strtoumax(in char *, char**, int);
intmax_t  wcstoimax(in wchar_t*, wchar_t**, int);
uintmax_t wcstoumax(in wchar_t*, wchar_t**, int);
*/
intmax_t  imaxabs(intmax_t);
imaxdiv_t imaxdiv(intmax_t, intmax_t);
intmax_t  strtoimax(in char*, char**, int);
uintmax_t strtoumax(in char *, char**, int);
intmax_t  wcstoimax(in wchar_t*, wchar_t**, int);
uintmax_t wcstoumax(in wchar_t*, wchar_t**, int);

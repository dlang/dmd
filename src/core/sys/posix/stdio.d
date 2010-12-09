/**
 * D header file for POSIX.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Sean Kelly
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */

/*          Copyright Sean Kelly 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.sys.posix.stdio;

private import core.sys.posix.config;
public import core.stdc.stdio;
public import core.sys.posix.sys.types; // for off_t

extern (C):

//
// Required (defined in core.stdc.stdio)
//
/*
BUFSIZ
_IOFBF
_IOLBF
_IONBF
L_tmpnam
SEEK_CUR
SEEK_END
SEEK_SET
FILENAME_MAX
FOPEN_MAX
TMP_MAX
EOF
NULL
stderr
stdin
stdout
FILE
fpos_t
size_t

void   clearerr(FILE*);
int    fclose(FILE*);
int    feof(FILE*);
int    ferror(FILE*);
int    fflush(FILE*);
int    fgetc(FILE*);
int    fgetpos(FILE*, fpos_t *);
char*  fgets(char*, int, FILE*);
FILE*  fopen(in char*, in char*);
int    fprintf(FILE*, in char*, ...);
int    fputc(int, FILE*);
int    fputs(in char*, FILE*);
size_t fread(void *, size_t, size_t, FILE*);
FILE*  freopen(in char*, in char*, FILE*);
int    fscanf(FILE*, in char*, ...);
int    fseek(FILE*, c_long, int);
int    fsetpos(FILE*, in fpos_t*);
c_long ftell(FILE*);
size_t fwrite(in void *, size_t, size_t, FILE*);
int    getc(FILE*);
int    getchar();
char*  gets(char*);
void   perror(in char*);
int    printf(in char*, ...);
int    putc(int, FILE*);
int    putchar(int);
int    puts(in char*);
int    remove(in char*);
int    rename(in char*, in char*);
void   rewind(FILE*);
int    scanf(in char*, ...);
void   setbuf(FILE*, char*);
int    setvbuf(FILE*, char*, int, size_t);
int    snprintf(char*, size_t, in char*, ...);
int    sprintf(char*, in char*, ...);
int    sscanf(in char*, in char*, int ...);
FILE*  tmpfile();
char*  tmpnam(char*);
int    ungetc(int, FILE*);
int    vfprintf(FILE*, in char*, va_list);
int    vfscanf(FILE*, in char*, va_list);
int    vprintf(in char*, va_list);
int    vscanf(in char*, va_list);
int    vsnprintf(char*, size_t, in char*, va_list);
int    vsprintf(char*, in char*, va_list);
int    vsscanf(in char*, in char*, va_list arg);
*/

version( linux )
{
    static if( __USE_LARGEFILE64 )
    {
        int   fgetpos64(FILE*, fpos_t *);
        alias fgetpos64 fgetpos;

        FILE* fopen64(in char*, in char*);
        alias fopen64 fopen;

        FILE* freopen64(in char*, in char*, FILE*);
        alias freopen64 freopen;

        int   fseek64(FILE*, c_long, int);
        alias fseek64 fseek;

        int   fsetpos64(FILE*, in fpos_t*);
        alias fsetpos64 fsetpos;

        FILE* tmpfile64();
        alias tmpfile64 tmpfile;
    }
    else
    {
        int   fgetpos(FILE*, fpos_t *);
        FILE* fopen(in char*, in char*);
        FILE* freopen(in char*, in char*, FILE*);
        int   fseek(FILE*, c_long, int);
        int   fsetpos(FILE*, in fpos_t*);
        FILE* tmpfile();
    }
}

//
// C Extension (CX)
//
/*
L_ctermid

char*  ctermid(char*);
FILE*  fdopen(int, in char*);
int    fileno(FILE*);
int    fseeko(FILE*, off_t, int);
off_t  ftello(FILE*);
char*  gets(char*);
int    pclose(FILE*);
FILE*  popen(in char*, in char*);
*/

version( linux )
{
    enum L_ctermid = 9;

  static if( __USE_FILE_OFFSET64 )
  {
    int   fseeko64(FILE*, off_t, int);
    alias fseeko64 fseeko;
  }
  else
  {
    int   fseeko(FILE*, off_t, int);
  }

  static if( __USE_LARGEFILE64 )
  {
    off_t ftello64(FILE*);
    alias ftello64 ftello;
  }
  else
  {
    off_t ftello(FILE*);
  }
}
else version( Posix )
{
    int   fseeko(FILE*, off_t, int);
    off_t ftello(FILE*);
}

version( Posix )
{
    char*  ctermid(char*);
    FILE*  fdopen(int, in char*);
    int    fileno(FILE*);
    //int    fseeko(FILE*, off_t, int);
    //off_t  ftello(FILE*);
    char*  gets(char*);
    int    pclose(FILE*);
    FILE*  popen(in char*, in char*);
}

//
// Thread-Safe Functions (TSF)
//
/*
void   flockfile(FILE*);
int    ftrylockfile(FILE*);
void   funlockfile(FILE*);
int    getc_unlocked(FILE*);
int    getchar_unlocked();
int    putc_unlocked(int, FILE*);
int    putchar_unlocked(int);
*/

version( linux )
{
    void   flockfile(FILE*);
    int    ftrylockfile(FILE*);
    void   funlockfile(FILE*);
    int    getc_unlocked(FILE*);
    int    getchar_unlocked();
    int    putc_unlocked(int, FILE*);
    int    putchar_unlocked(int);
}

//
// XOpen (XSI)
//
/*
P_tmpdir
va_list (defined in core.stdc.stdarg)

char*  tempnam(in char*, in char*);
*/

version( linux )
{
    enum P_tmpdir  = "/tmp";

    char*  tempnam(in char*, in char*);
}

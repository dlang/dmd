
// Copyright (c) 1999-2013 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// https://github.com/D-Programming-Language/dmd/blob/master/src/errors.c
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <stdarg.h>

#include "mars.h"
#include "module.h"


unsigned Global::startGagging()
{
    ++gag;
    return gaggedErrors;
}

bool Global::endGagging(unsigned oldGagged)
{
    bool anyErrs = (gaggedErrors != oldGagged);
    --gag;
    // Restore the original state of gagged errors; set total errors
    // to be original errors + new ungagged errors.
    errors -= (gaggedErrors - oldGagged);
    gaggedErrors = oldGagged;
    return anyErrs;
}

bool Global::isSpeculativeGagging()
{
    return gag && gag == speculativeGag;
}

void Global::increaseErrorCount()
{
    if (gag)
        ++gaggedErrors;
    ++errors;
}


char *Loc::toChars()
{
    OutBuffer buf;

    if (filename)
    {
        buf.printf("%s", filename);
    }

    if (linnum)
        buf.printf("(%d)", linnum);
    buf.writeByte(0);
    return (char *)buf.extractData();
}

Loc::Loc(Module *mod, unsigned linnum)
{
    this->linnum = linnum;
    this->filename = mod ? mod->srcfile->toChars() : NULL;
}

bool Loc::equals(const Loc& loc)
{
    return linnum == loc.linnum && FileName::equals(filename, loc.filename);
}

/**************************************
 * Print error message
 */

void error(Loc loc, const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    verror(loc, format, ap);
    va_end(ap);
}

void error(const char *filename, unsigned linnum, const char *format, ...)
{   Loc loc;
    loc.filename = (char *)filename;
    loc.linnum = linnum;
    va_list ap;
    va_start(ap, format);
    verror(loc, format, ap);
    va_end(ap);
}

/**************************************
 * Print warning message
 */

void warning(Loc loc, const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    vwarning(loc, format, ap);
    va_end(ap);
}

/**************************************
 * Print supplementary message about the last error
 * Used for backtraces, etc
 */
void errorSupplemental(Loc loc, const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    verrorSupplemental(loc, format, ap);
    va_end(ap);
}

/**************************************
 * Print deprecation message
 */

void deprecation(Loc loc, const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    vdeprecation(loc, format, ap);
    va_end(ap);
}


// Just print, doesn't care about gagging
void verrorPrint(Loc loc, const char *header, const char *format, va_list ap,
                 const char *p1, const char *p2)
{
    char *p = loc.toChars();

    if (*p)
        fprintf(stderr, "%s: ", p);
    mem.free(p);

    fputs(header, stderr);
    if (p1)
        fprintf(stderr, "%s ", p1);
    if (p2)
        fprintf(stderr, "%s ", p2);

    OutBuffer tmp;
    tmp.vprintf(format, ap);
    fprintf(stderr, "%s", tmp.toChars());

    fprintf(stderr, "\n");
    fflush(stderr);
}

// header is "Error: " by default (see mars.h)
void verror(Loc loc, const char *format, va_list ap,
            const char *p1, const char *p2, const char *header)
{
    if (!global.gag)
    {
        verrorPrint(loc, header, format, ap, p1, p2);
        if (global.errors >= 20)        // moderate blizzard of cascading messages
            fatal();
        //halt();
    }
    else
    {
        global.gaggedErrors++;
    }
    global.errors++;
}

// Doesn't increase error count, doesn't print "Error:".
void verrorSupplemental(Loc loc, const char *format, va_list ap)
{
    if (!global.gag)
        verrorPrint(loc, "       ", format, ap);
}

void vwarning(Loc loc, const char *format, va_list ap)
{
    if (global.params.warnings && !global.gag)
    {
        verrorPrint(loc, "Warning: ", format, ap);
        //halt();
        if (global.params.warnings == 1)
            global.warnings++;  // warnings don't count if gagged
    }
}

void vdeprecation(Loc loc, const char *format, va_list ap,
                  const char *p1, const char *p2)
{
    static const char *header = "Deprecation: ";
    if (global.params.useDeprecated == 0)
        verror(loc, format, ap, p1, p2, header);
    else if (global.params.useDeprecated == 2 && !global.gag)
        verrorPrint(loc, header, format, ap, p1, p2);
}

/***************************************
 * Call this after printing out fatal error messages to clean up and exit
 * the compiler.
 */

void fatal()
{
#if 0
    halt();
#endif
    exit(EXIT_FAILURE);
}

/**************************************
 * Try to stop forgetting to remove the breakpoints from
 * release builds.
 */
void halt()
{
#ifdef DEBUG
    *(volatile char*)0=0;
#endif
}




// Copyright (c) 2013 by Digital Mars
// All Rights Reserved
// written by Iain Buclaw
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <assert.h>

#include "target.h"
#include "mars.h"
#include "mtype.h"

int Target::ptrsize;
int Target::realsize;
int Target::realpad;
int Target::realalignsize;
bool Target::reverseCppOverloads;


void Target::init()
{
    // These have default values for 32 bit code, they get
    // adjusted for 64 bit code.
    ptrsize = 4;

    if (global.params.isLinux || global.params.isFreeBSD
        || global.params.isOpenBSD || global.params.isSolaris)
    {
        realsize = 12;
        realpad = 2;
        realalignsize = 4;
    }
    else if (global.params.isOSX)
    {
        realsize = 16;
        realpad = 6;
        realalignsize = 16;
    }
    else if (global.params.isWindows)
    {
        realsize = 10;
        realpad = 0;
        realalignsize = 2;
        reverseCppOverloads = !global.params.is64bit;
    }
    else
        assert(0);

    if (global.params.is64bit)
    {
        if (global.params.isLinux || global.params.isFreeBSD || global.params.isSolaris)
        {
            realsize = 16;
            realpad = 6;
            realalignsize = 16;
        }
    }

    if (global.params.isLP64)
        ptrsize = 8;
}

/******************************
 * Return memory alignment size of type.
 */

unsigned Target::alignsize(Type* type)
{
    assert (type->isTypeBasic());

    switch (type->ty)
    {
        case Tfloat80:
        case Timaginary80:
        case Tcomplex80:
            return Target::realalignsize;

        case Tcomplex32:
            if (global.params.isLinux || global.params.isOSX || global.params.isFreeBSD
                || global.params.isOpenBSD || global.params.isSolaris)
                return 4;
            break;

        case Tint64:
        case Tuns64:
        case Tfloat64:
        case Timaginary64:
        case Tcomplex64:
            if (global.params.isLinux || global.params.isOSX || global.params.isFreeBSD
                || global.params.isOpenBSD || global.params.isSolaris)
                return global.params.is64bit ? 8 : 4;
            break;

        default:
            break;
    }
    return (unsigned)type->size(Loc());
}

/******************************
 * Return field alignment size of type.
 */

unsigned Target::fieldalign(Type* type)
{
    return type->alignsize();
}

/***********************************
 * Return size of OS critical section.
 * NOTE: can't use the sizeof() calls directly since cross compiling is
 * supported and would end up using the host sizes rather than the target
 * sizes.
 */
unsigned Target::critsecsize()
{
    if (global.params.isWindows)
    {
        // sizeof(CRITICAL_SECTION) for Windows.
        return global.params.isLP64 ? 40 : 24;
    }
    else if (global.params.isLinux)
    {
        // sizeof(pthread_mutex_t) for Linux.
        if (global.params.is64bit)
            return global.params.isLP64 ? 40 : 32;
        else
            return global.params.isLP64 ? 40 : 24;
    }
    else if (global.params.isFreeBSD)
    {
        // sizeof(pthread_mutex_t) for FreeBSD.
        return global.params.isLP64 ? 8 : 4;
    }
    else if (global.params.isOpenBSD)
    {
        // sizeof(pthread_mutex_t) for OpenBSD.
        return global.params.isLP64 ? 8 : 4;
    }
    else if (global.params.isOSX)
    {
        // sizeof(pthread_mutex_t) for OSX.
        return global.params.isLP64 ? 64 : 44;
    }
    else if (global.params.isSolaris)
    {
        // sizeof(pthread_mutex_t) for Solaris.
        return 24;
    }
    assert(0);
    return 0;
}


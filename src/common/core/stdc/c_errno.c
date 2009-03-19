/**
 * This file contains wrapper functions for macro-defined C rouines.
 *
 * Copyright: Copyright (C) 2005-2009 Sean Kelly.  All rights reserved.
 * License:   BSD Style, see LICENSE
 * Authors:   Sean Kelly
 */
#include <errno.h>


int getErrno()
{
    return errno;
}


int setErrno( int val )
{
    errno = val;
    return val;
}

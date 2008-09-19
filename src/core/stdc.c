/**
 * This file contains wrapper functions for macro-defined C rouines.
 *
 * Copyright: Copyright (c) 2005-2008, The D Runtime Project
 * License:   BSD Style, see LICENSE
 * Authors:   Sean Kelly
 */
#include <errno.h>


int _d_getErrno()
{
    return errno;
}


int _d_setErrno( int val )
{
    errno = val;
    return val;
}

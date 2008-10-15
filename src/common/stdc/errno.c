/**
 * This file contains wrapper functions for macro-defined C rouines.
 *
 * Copyright: Copyright (c) 2005-2008, The D Runtime Project
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

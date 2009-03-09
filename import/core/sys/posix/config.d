/**
 * D header file for POSIX.
 *
 * Copyright: Public Domain
 * License:   Public Domain
 * Authors:   Sean Kelly
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */
module core.sys.posix.config;

public import core.stdc.config;

extern (C):

version( linux )
{
  version( X86_64 )
  {
    enum bool  __USE_LARGEFILE64    = true;
  }
  else
  {
    enum bool  __USE_LARGEFILE64    = false;
  }
    enum bool  __USE_FILE_OFFSET64  = __USE_LARGEFILE64;
    enum bool  __REDIRECT           = false;
}

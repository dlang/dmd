/**
 * D header file for C99.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Sean Kelly
 * Source:    $(DRUNTIMESRC core/stdc/_config.d)
 * Authors:   Sean Kelly
 * Standards: ISO/IEC 9899:1999 (E)
 */

module core.stdc.config;

extern (C):
@trusted: // Types only.
nothrow:
@nogc:

version( Windows )
{
    alias int   c_long;
    alias uint  c_ulong;
}
else
{
  static if( (void*).sizeof > int.sizeof )
  {
    alias long  c_long;
    alias ulong c_ulong;
  }
  else
  {
    alias int   c_long;
    alias uint  c_ulong;
  }
}

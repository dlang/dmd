/**
 * D header file for C99.
 *
 * Copyright: Public Domain
 * License:   Public Domain
 * Authors:   Sean Kelly
 * Standards: ISO/IEC 9899:1999 (E)
 */
module stdc.config;

extern (C):

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

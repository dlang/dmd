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
    struct __c_long
    {
      pure nothrow @nogc @safe:
        this(int x) { lng = x; }
        int lng;
        alias lng this;
    }

    struct __c_ulong
    {
      pure nothrow @nogc @safe:
        this(uint x) { lng = x; }
        uint lng;
        alias lng this;
    }

    /*
     * This is cpp_long instead of c_long because:
     * 1. Implicit casting of an int to __c_long doesn't happen, because D doesn't
     *    allow constructor calls in implicit conversions.
     * 2. long lng;
     *    cast(__c_long)lng;
     *    does not work because lng has to be implicitly cast to an int in the constructor,
     *    and since that truncates it is not done.
     * Both of these break existing code, so until we find a resolution the types are named
     * cpp_xxxx.
     */

    alias __c_long   cpp_long;
    alias __c_ulong  cpp_ulong;

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
    struct __c_long
    {
      pure nothrow @nogc @safe:
        this(int x) { lng = x; }
        int lng;
        alias lng this;
    }

    struct __c_ulong
    {
      pure nothrow @nogc @safe:
        this(uint x) { lng = x; }
        uint lng;
        alias lng this;
    }

    alias __c_long   cpp_long;
    alias __c_ulong  cpp_ulong;

    alias int   c_long;
    alias uint  c_ulong;
  }
}

version( DigitalMars )
{
    version( CRuntime_Microsoft )
    {
        /* long double is 64 bits, not 80 bits, but is mangled differently
         * than double. To distinguish double from long double, create a wrapper to represent
         * long double, then recognize that wrapper specially in the compiler
         * to generate the correct name mangling and correct function call/return
         * ABI conformance.
         */
        struct __c_long_double
        {
          pure nothrow @nogc @safe:
            this(double d) { ld = d; }
            double ld;
            alias ld this;
        }

        alias __c_long_double c_long_double;
    }
    else version( X86 )
    {
        alias real c_long_double;
    }
    else version( X86_64 )
    {
        version( linux )
            alias real c_long_double;
        else version( FreeBSD )
            alias real c_long_double;
        else version( OSX )
            alias real c_long_double;
    }
}
else version( GNU )
    alias real c_long_double;
else version( LDC )
{
    version( X86 )
        alias real c_long_double;
    else version( X86_64 )
        alias real c_long_double;
}
else version( SDC )
{
    version( X86 )
        alias real c_long_double;
    else version( X86_64 )
        alias real c_long_double;
}

static assert(is(c_long_double), "c_long_double needs to be declared for this platform/architecture.");

/**
* Configuration options for druntime
*
* Copyright: Copyright Digital Mars 2014.
* License: Distributed under the
*      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
*    (See accompanying file LICENSE)
* Authors:   Rainer Schuetze
* Source: $(DRUNTIMESRC src/rt/_config.d)
*/

module rt.config;

// The default way to configure the runtime is by passing command line arguments
// starting with "--DRT-" and followed by the option name, e.g. "--DRT-gcopt" to
// configure the GC.
// Command line options starting with "--DRT-" are filtered out before calling main,
// so the program will not see them. They are still available via rt_args().
//
// Configuration via the command line can be disabled by declaring a variable for the
// linker to pick up before using it's default from the runtime:
//
//   extern(C) __gshared bool drt_cmdline_enabled = false;
//
// Likewise, declare a boolean drt_envvars_enabled to enable configuration via the
// environment variable "DRT_" followed by the option name, e.g. "DRT_GCOPT":
//
//   extern(C) __gshared bool drt_envvars_enabled = true;
//
// Setting default configuration properties in the executable can be done by specifying an
// array of options named drt_args:
//
//   extern(C) __gshared string[] drt_args = [ "gcopt=precise:1 profile:1"];
//
// Evaluation order of options is drt_args, then environment variables, then command
// line arguments, i.e. if command line arguments are not disabled, they can override
// options specified through the environment or embedded in the executable.


// put each variable in its own COMDAT by making them template instances
template drt_envvars_enabled()
{
    pragma(mangle,"drt_envvars_enabled") extern(C) __gshared bool drt_envvars_enabled = false;
}
template drt_cmdline_enabled()
{
    pragma(mangle,"drt_cmdline_enabled") extern(C) __gshared bool drt_cmdline_enabled = true;
}
template drt_args()
{
    pragma(mangle,"drt_args") extern(C) __gshared string[] drt_args = [];
}

import core.stdc.ctype : toupper;
import core.stdc.stdlib : getenv;
import core.stdc.string : strlen;

extern extern(C) string[] rt_args() @nogc nothrow;

/**
* get a druntme config option using standard configuration options
*      opt             name of the option to retreive
*
* returns the options' value if
*  - set on the command line as "--DRT-<opt>=value" (drt_cmdline_enabled enabled)
*  - the environment variable "DRT_<OPT>" is set (drt_envvars_enabled enabled)
*  - drt_args[] contains an entry "<opt>=value"
*  - null otherwise
*/
extern(C) string drtConfigOption(string opt) @nogc nothrow
{
    if(drt_cmdline_enabled!())
    {
        foreach (a; rt_args)
        {
            if (a.length >= opt.length + 7 && a[0..6] == "--DRT-" &&
                a[6 .. 6 + opt.length] == opt && a[6 + opt.length] == '=')
                return a[7 + opt.length .. $];
        }
    }
    if(drt_envvars_enabled!())
    {
        if (opt.length >= 32)
            assert(0);

        char[40] var;
        var[0 .. 4] = "DRT_";
        foreach (i, c; opt)
            var[4 + i] = cast(char) toupper(c);
        var[4 + opt.length] = 0;

        auto p = getenv(var.ptr);
        if (p)
            return cast(string) p[0 .. strlen(p)];
    }
    foreach (a; drt_args!())
    {
        if(a.length > opt.length && a[0..opt.length] == opt && a[opt.length] == '=')
            return a[opt.length + 1 .. $];
    }
    return null;
}


/**
* Contains the garbage collector configuration.
*
* Copyright: Copyright Digital Mars 2014
* License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
*/

module gc.config;

// The default way to configure the GC is by passing command line argument --DRT-gcopt to
// the executable, use --DRT-gcopt=help for a list of available options.
//
// Configuration via the command line can be disabled by declaring a variable for the
// linker to pick up before using it's defult from the runtime:
//
//   extern(C) __gshared bool drt_cmdline_enabled = false;
//
// Likewise, declare a boolean drt_envvars_enabled to enable configuration via the
// environment variable DRT_GCOPT:
//
//   extern(C) __gshared bool drt_envvars_enabled = true;
//
// Setting default configuration properties in the executable can be done by specifying an
// array of options named drt_args:
//
//   extern(C) __gshared string[] drt_args = [ "gcopt=precise=1 profile=1"];
//
// Evaluation order of options is drt_args, then environment variables, then command
// line arguments, i.e. if command line arguments are not disabled, they can override
// options specified through the environment or embedded in the executable.

import core.stdc.stdlib;
import core.stdc.stdio;
import core.stdc.ctype;
import core.stdc.string;
import core.vararg;

extern extern(C) string[] rt_args();

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

struct Config
{
    bool disable;            // start disabled
    bool profile;            // enable profiling with summary when terminating program
    bool precise;            // enable precise scanning
    bool concurrent;         // enable concurrent collection

    size_t initReserve;      // initial reserve (MB)
    size_t minPoolSize = 1;  // initial and minimum pool size (MB)
    size_t maxPoolSize = 64; // maximum pool size (MB)
    size_t incPoolSize = 3;  // pool size increment (MB)

    bool initialize(...) // avoid inlining
    {
        foreach (a; drt_args!())
        {
            if(a.length >= 6 && a[0..6] == "gcopt=")
                if (!parseOptions(a[6 .. $]))
                    return false;
        }
        if(drt_envvars_enabled!())
        {
            auto p = getenv("DRT_GCOPT");
            if (p)
                if (!parseOptions(p[0 .. strlen(p)]))
                    return false;
        }
        if(drt_cmdline_enabled!())
        {
            foreach (a; rt_args)
            {
                if(a.length >= 12 && a[0..12] == "--DRT-gcopt=")
                    if (!parseOptions(a[12 .. $]))
                        return false;
            }
        }
        return true;
    }

    string help() @nogc
    {
        return "GC options are specified as white space separated assignments:
    disable=0|1     - start disabled
    profile=0|1     - enable profiling with summary when terminating program
    precise=0|1     - enable precise scanning (not implemented yet)
    concurrent=0|1  - enable concurrent collection (not implemented yet)

    initReserve=N   - initial memory to reserve (MB), default 0
    minPoolSize=N   - initial and minimum pool size (MB), default 1
    maxPoolSize=N   - maximum pool size (MB), default 64
    incPoolSize=N   - pool size increment (MB), defaut 3
";
    }

    bool parseOptions(const(char)[] opt) @nogc
    {
        size_t p = 0;
        while(p < opt.length)
        {
            while (p < opt.length && isspace(opt[p]))
                p++;
            if (p >= opt.length)
                break;
            auto q = p;
            while (q < opt.length && opt[q] != '=' && !isspace(opt[q]))
                q++;

            auto s = opt[p .. q];
            if(s == "help")
            {
                printf("%s", help().ptr);
                p = q;
            }
            else if (q < opt.length)
            {
                auto r = q + 1;
                size_t v = 0;
                for ( ; r < opt.length && isdigit(opt[r]); r++)
                    v = v * 10 + opt[r] - '0';

                if(s == "disable")
                    disable = v != 0;
                else if(s == "profile")
                    profile = v != 0;
                else if(s == "precise")
                    precise = v != 0;
                else if(s == "concurrent")
                    concurrent = v != 0;
                else if(s == "initReserve")
                    initReserve = v;
                else if(s == "minPoolSize")
                    minPoolSize = v;
                else if(s == "maxPoolSize")
                    maxPoolSize = v;
                else if(s == "incPoolSize")
                    incPoolSize = v;
                else
                {
                    printf("Unknown GC option \"%.*s\"\n", cast(int) s.length, s.ptr);
                    return false;
                }
                p = r;
            }
            else
            {
                printf("Incomplete GC option \"%.*s\"\n", cast(int) s.length, s.ptr);
                return false;
            }
        }
        return true;
    }
}

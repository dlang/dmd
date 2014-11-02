/**
* Contains the garbage collector configuration.
*
* Copyright: Copyright Digital Mars 2014
* License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
*/

module gc.config;

import core.stdc.stdlib;
import core.stdc.stdio;
import core.stdc.ctype;
import core.stdc.string;
import core.vararg;

extern extern(C) string[] rt_args();

extern extern(C) __gshared bool drt_envvars_enabled;
extern extern(C) __gshared bool drt_cmdline_enabled;
extern extern(C) __gshared string[] drt_args;

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
        foreach (a; drt_args)
        {
            if(a.length >= 6 && a[0..6] == "gcopt=")
                if (!parseOptions(a[6 .. $]))
                    return false;
        }
        if(drt_envvars_enabled)
        {
            auto p = getenv("DRT_GCOPT");
            if (p)
                if (!parseOptions(p[0 .. strlen(p)]))
                    return false;
        }
        if(drt_cmdline_enabled)
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

    void help() @nogc
    {
        string s = "GC options are specified as white space separated assignments:
    disable:0|1    - start disabled (%d)
    profile:0|1    - enable profiling with summary when terminating program (%d)
    precise:0|1    - enable precise scanning (not implemented yet)
    concurrent:0|1 - enable concurrent collection (not implemented yet)

    initReserve:N  - initial memory to reserve in MB (%lld)
    minPoolSize:N  - initial and minimum pool size in MB (%lld)
    maxPoolSize:N  - maximum pool size in MB (%lld)
    incPoolSize:N  - pool size increment MB (%lld)
";
        printf(s.ptr, disable, profile, cast(long)initReserve, 
               cast(long)minPoolSize, cast(long)maxPoolSize, cast(long)incPoolSize);
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
            while (q < opt.length && opt[q] != ':' && opt[q] != '=' && !isspace(opt[q]))
                q++;

            auto s = opt[p .. q];
            if(s == "help")
            {
                help();
                p = q;
            }
            else if (q < opt.length)
            {
                auto r = q + 1;
                size_t v = 0;
                for ( ; r < opt.length && isdigit(opt[r]); r++)
                    v = v * 10 + opt[r] - '0';
                if(r == q + 1)
                {
                    printf("numeric argument expected for GC option \"%.*s\"\n", cast(int) s.length, s.ptr);
                    return false;
                }
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

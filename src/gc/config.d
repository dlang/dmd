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

extern extern(C) __gshared bool rt_envvars_enabled;
extern extern(C) __gshared bool rt_cmdline_enabled;
extern extern(C) __gshared string[] rt_options;

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
    float heapSizeFactor = 2.0;

    bool initialize() @nogc
    {
        import core.internal.traits : externDFunc;

        alias rt_configCallBack = string delegate(string) @nogc nothrow;
        alias fn_configOption = string function(string opt, scope rt_configCallBack dg, bool reverse) @nogc nothrow;

        alias rt_configOption = externDFunc!("rt.config.rt_configOption", fn_configOption);

        string parse(string opt) @nogc nothrow
        {
            if (!parseOptions(opt))
                return "err";
            return null; // continue processing
        }
        string s = rt_configOption("gcopt", &parse, true);
        return s is null;
    }

    void help() @nogc nothrow
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
    heapSizeFactor:N - targeted heap size to used memory ratio (%f)
";
        printf(s.ptr, disable, profile, cast(long)initReserve, cast(long)minPoolSize,
               cast(long)maxPoolSize, cast(long)incPoolSize, heapSizeFactor);
    }

    bool parseOptions(const(char)[] opt) @nogc nothrow
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
                // TODO: scanf
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
                else if(s == "heapSizeFactor")
                    heapSizeFactor = v;
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

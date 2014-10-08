/**
* Contains the garbage collector configuration.
*
* Copyright: Copyright Digital Mars 2014
* License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
*/

module gc.config;

// The default way to confige the GC is by passing command line argument --DRT-gcopt to
// the executable, use --DRT-gcopt=help for a list of available options.
//
// Configuration can be disabled by building this module with version noinitGCFromCommandline
// and linking it with your executable:
//      dmd -version=noinitGCFromCommandline main.d /path/to/druntime/src/gc/config.d
//
// If you want to allow configuration by an environment variable DRT_GCOPT aswell, compile
// gc.config with version initGCFromEnvironment:
//      dmd -version=initGCFromEnvironment main.d /path/to/druntime/src/gc/config.d

//version = initGCFromEnvironment; // read settings from environment variable DRT_GCOPT
version(noinitGCFromCommandline) {} else
version = initGCFromCommandLine; // read settings from command line argument "--DRT-gcopt=options"

version(initGCFromEnvironment)
    version = configurable;
version(initGCFromCommandLine)
    version = configurable;

import core.stdc.stdlib;
import core.stdc.stdio;
import core.stdc.ctype;
import core.stdc.string;
import core.vararg;

extern extern(C) string[] rt_args();

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
        version(initGCFromEnvironment)
        {
            auto p = getenv("DRT_GCOPT");
            if (p)
                if (!parseOptions(p[0 .. strlen(p)]))
                    return false;
        }
        version(initGCFromCommandLine)
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

    version (configurable):

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

/**
* parse configuration options
*
* Copyright: Copyright Digital Mars 2017
* License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
*
* Source: $(DRUNTIMESRC src/core/internal/parseoptions.d)
*/

module core.internal.parseoptions;

import core.stdc.stdlib;
import core.stdc.stdio;
import core.stdc.ctype;
import core.stdc.string;
import core.vararg;

@nogc nothrow:
extern extern(C) string[] rt_args();

extern extern(C) __gshared bool rt_envvars_enabled;
extern extern(C) __gshared bool rt_cmdline_enabled;
extern extern(C) __gshared string[] rt_options;

/**
* initialize members of struct CFG from rt_config options
*
* options will be read from the environment, the command line or embedded
* into the executable as configured (see rt.config)
*
* fields of the struct are populated by parseOptions().
*/
bool initConfigOptions(CFG)(ref CFG cfg, string cfgname)
{
    import core.internal.traits : externDFunc;

    alias rt_configCallBack = string delegate(string) @nogc nothrow;
    alias fn_configOption = string function(string opt, scope rt_configCallBack dg, bool reverse) @nogc nothrow;

    alias rt_configOption = externDFunc!("rt.config.rt_configOption", fn_configOption);

    string parse(string opt) @nogc nothrow
    {
        if (!parseOptions(cfg, opt))
            return "err";
        return null; // continue processing
    }
    string s = rt_configOption(cfgname, &parse, true);
    return s is null;
}

/**
* initialize members of struct CFG from a string of sub-options.
*
* fields of the struct are populated by listing them as space separated
* sub-options <field-name>:value, e.g. "precise:1 profile:1"
*
* supported field value types:
*  - strings (without spaces)
*  - integer types (positive values only)
*  - bool
*  - float
*
* If the struct has a member "help" it is called if it is found as a sub-option.
* If the struct has a member "errorName", is used as the name reported in error
* messages. Otherwise the struct name is used.
*/
bool parseOptions(CFG)(ref CFG cfg, string opt)
{
    static if (is(typeof(__traits(getMember, CFG, "errorName"))))
        string errName = cfg.errorName;
    else
        string errName = CFG.stringof;
    opt = skip!isspace(opt);
    while (opt.length)
    {
        auto tail = find!(c => c == ':' || c == '=' || c == ' ')(opt);
        auto name = opt[0 .. $ - tail.length];
        static if (is(typeof(__traits(getMember, CFG, "help"))))
            if (name == "help")
            {
                version (unittest) {} else
                cfg.help();
                opt = skip!isspace(tail);
                continue;
            }
        if (tail.length <= 1 || tail[0] == ' ')
            return optError("Missing argument for", name, errName);
        tail = tail[1 .. $];

        switch (name)
        {
            foreach (field; __traits(allMembers, CFG))
            {
                static if (!is(typeof(__traits(getMember, cfg, field)) == function))
                {
                    case field:
                        if (!parse(name, tail, __traits(getMember, cfg, field), errName))
                            return false;
                        break;
                }
            }
            break;

            default:
                return optError("Unknown", name, errName);
        }
        opt = skip!isspace(tail);
    }
    return true;
}

private:

bool optError(in char[] msg, in char[] name, const(char)[] errName)
{
    version (unittest) if (inUnittest) return false;

    fprintf(stderr, "%.*s %.*s option '%.*s'.\n",
            cast(int)msg.length, msg.ptr,
            cast(int)errName.length, errName.ptr,
            cast(int)name.length, name.ptr);
    return false;
}

inout(char)[] skip(alias pred)(inout(char)[] str)
{
    return find!(c => !pred(c))(str);
}

inout(char)[] find(alias pred)(inout(char)[] str)
{
    foreach (i; 0 .. str.length)
        if (pred(str[i])) return str[i .. $];
    return null;
}

bool parse(T:size_t)(const(char)[] optname, ref inout(char)[] str, ref T res, const(char)[] errName)
in { assert(str.length); }
body
{
    size_t i, v;
    for (; i < str.length && isdigit(str[i]); ++i)
        v = 10 * v + str[i] - '0';

    if (!i)
        return parseError("a number", optname, str, errName);
    if (v > res.max)
        return parseError("a number " ~ T.max.stringof ~ " or below", optname, str[0 .. i], errName);
    str = str[i .. $];
    res = cast(T) v;
    return true;
}

bool parse(const(char)[] optname, ref inout(char)[] str, ref bool res, const(char)[] errName)
in { assert(str.length); }
body
{
    if (str[0] == '1' || str[0] == 'y' || str[0] == 'Y')
        res = true;
    else if (str[0] == '0' || str[0] == 'n' || str[0] == 'N')
        res = false;
    else
        return parseError("'0/n/N' or '1/y/Y'", optname, str, errName);
    str = str[1 .. $];
    return true;
}

bool parse(const(char)[] optname, ref inout(char)[] str, ref float res, const(char)[] errName)
in { assert(str.length); }
body
{
    // % uint f %n \0
    char[1 + 10 + 1 + 2 + 1] fmt=void;
    // specify max-width
    immutable n = snprintf(fmt.ptr, fmt.length, "%%%uf%%n", cast(uint)str.length);
    assert(n > 4 && n < fmt.length);

    int nscanned;
    version (CRuntime_DigitalMars)
    {
        /* Older sscanf's in snn.lib can write to its first argument, causing a crash
        * if the string is in readonly memory. Recent updates to DMD
        * https://github.com/dlang/dmd/pull/6546
        * put string literals in readonly memory.
        * Although sscanf has been fixed,
        * http://ftp.digitalmars.com/snn.lib
        * this workaround is here so it still works with the older snn.lib.
        */
        // Create mutable copy of str
        const length = str.length;
        char* mptr = cast(char*)malloc(length + 1);
        assert(mptr);
        memcpy(mptr, str.ptr, length);
        mptr[length] = 0;
        const result = sscanf(mptr, fmt.ptr, &res, &nscanned);
        free(mptr);
        if (result < 1)
            return parseError("a float", optname, str, errName);
    }
    else
    {
        if (sscanf(str.ptr, fmt.ptr, &res, &nscanned) < 1)
            return parseError("a float", optname, str, errName);
    }
    str = str[nscanned .. $];
    return true;
}

bool parse(const(char)[] optname, ref inout(char)[] str, ref inout(char)[] res, const(char)[] errName)
in { assert(str.length); }
body
{
    auto tail = str.find!(c => c == ':' || c == '=' || c == ' ');
    res = str[0 .. $ - tail.length];
    if (!res.length)
        return parseError("an identifier", optname, str, errName);
    str = tail;
    return true;
}

bool parseError(in char[] exp, in char[] opt, in char[] got, const(char)[] errName)
{
    version (unittest) if (inUnittest) return false;

    fprintf(stderr, "Expecting %.*s as argument for %.*s option '%.*s', got '%.*s' instead.\n",
            cast(int)exp.length, exp.ptr,
            cast(int)errName.length, errName.ptr,
            cast(int)opt.length, opt.ptr,
            cast(int)got.length, got.ptr);
    return false;
}

size_t min(size_t a, size_t b) { return a <= b ? a : b; }

version (unittest) __gshared bool inUnittest;

unittest
{
    inUnittest = true;
    scope (exit) inUnittest = false;

    static struct Config
    {
        bool disable;            // start disabled
        ubyte profile;           // enable profiling with summary when terminating program
        string gc = "conservative"; // select gc implementation conservative|manual

        size_t initReserve;      // initial reserve (MB)
        size_t minPoolSize = 1;  // initial and minimum pool size (MB)
        float heapSizeFactor = 2.0; // heap size to used memory ratio

        @nogc nothrow:
        void help();
        string errorName() @nogc nothrow { return "GC"; }
    }
    Config conf;

    assert(!conf.parseOptions("disable"));
    assert(!conf.parseOptions("disable:"));
    assert(!conf.parseOptions("disable:5"));
    assert(conf.parseOptions("disable:y") && conf.disable);
    assert(conf.parseOptions("disable:n") && !conf.disable);
    assert(conf.parseOptions("disable:Y") && conf.disable);
    assert(conf.parseOptions("disable:N") && !conf.disable);
    assert(conf.parseOptions("disable:1") && conf.disable);
    assert(conf.parseOptions("disable:0") && !conf.disable);

    assert(conf.parseOptions("disable=y") && conf.disable);
    assert(conf.parseOptions("disable=n") && !conf.disable);

    assert(conf.parseOptions("profile=0") && conf.profile == 0);
    assert(conf.parseOptions("profile=1") && conf.profile == 1);
    assert(conf.parseOptions("profile=2") && conf.profile == 2);
    assert(!conf.parseOptions("profile=256"));

    assert(conf.parseOptions("disable:1 minPoolSize:16"));
    assert(conf.disable);
    assert(conf.minPoolSize == 16);

    assert(conf.parseOptions("heapSizeFactor:3.1"));
    assert(conf.heapSizeFactor == 3.1f);
    assert(conf.parseOptions("heapSizeFactor:3.1234567890 disable:0"));
    assert(conf.heapSizeFactor > 3.123f);
    assert(!conf.disable);
    assert(!conf.parseOptions("heapSizeFactor:3.0.2.5"));
    assert(conf.parseOptions("heapSizeFactor:2"));
    assert(conf.heapSizeFactor == 2.0f);

    assert(!conf.parseOptions("initReserve:foo"));
    assert(!conf.parseOptions("initReserve:y"));
    assert(!conf.parseOptions("initReserve:20.5"));

    assert(conf.parseOptions("help"));
    assert(conf.parseOptions("help profile:1"));
    assert(conf.parseOptions("help profile:1 help"));

    assert(conf.parseOptions("gc:manual") && conf.gc == "manual");
    assert(conf.parseOptions("gc:my-gc~modified") && conf.gc == "my-gc~modified");
    assert(conf.parseOptions("gc:conservative help profile:1") && conf.gc == "conservative" && conf.profile == 1);

    // the config parse doesn't know all available GC names, so should accept unknown ones
    assert(conf.parseOptions("gc:whatever"));
}

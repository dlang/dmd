/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * This modules helps to create a list of supported features (aka probing output).
 * The probing information is returned in JSON.
 *
 * Copyright:   Copyright (c) 1999-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/probing.d, _probing.d)
 * Documentation:  https://dlang.org/phobos/dmd_probing.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/probing.d
 */

module dmd.probing;

/**
Prints a list of supported features (aka probing output) to stdout.
The output is in JSON.
*/
void printProbingInfo()
{
    import core.stdc.stdio : printf;
    import dmd.globals : global;

    printf("{\n");
    bool needsComma;
    void printKey(const(char*) key, void function() value)
    {
        if (needsComma)
            printf(",");
        printf("\n");
        needsComma = true;
        printf("    \"%s\": ", key);
        value();
    }

    printKey("compiler", (){
        printf(`"%s"`, determineCompiler());
    });
    printKey("frontendVersion", (){
        printf("%d", versionXX());
    });
    printKey("compilerFrontend", (){
        printf(`"%s"`, global._version);
    });
    printKey("config", (){
        if (*global.inifilename != '\0')
            printf(`"%s"`, global.inifilename);
        else
            printf("null");
    });
    printKey("binary", (){
        printf(`"%s"`, global.params.argv0);
    });
    printKey("platform", (){
        printJSONArray(&determinePlatform);
    });
    printKey("architecture", (){
        printJSONArray(&determineArchitecture);
    });
    printKey("predefinedVersions", (){
        printJSONArray(&predefinedVersions);
    });
    printf("\n}\n");
}

private long versionXX()
{
    import dmd.lexer : parseVersionXX;
    import dmd.globals : global;
    return global._version.parseVersionXX;
}

private const(char*) determineCompiler()
{
    import core.stdc.string : strcmp;
    import dmd.globals : global;

    if (strcmp(global.compiler.vendor, "Digital Mars D") == 0)
        return "dmd";
    else if (strcmp(global.compiler.vendor, "LDC") == 0)
        return "ldc";
    else if (strcmp(global.compiler.vendor, "GNU") == 0)
        return "gdc";
    else if (strcmp(global.compiler.vendor, "SDC") == 0)
        return "sdc";

    return null;
};

private void printJSONArray(void function(void delegate(string)) fun)
{
    import core.stdc.stdio : printf;
    static immutable const(char*) indent = "    ";

    bool isFirst = true;
    printf("[\n");
    void print(string s)
    {
        if (!isFirst)
            printf(",\n");
        printf(`%s%s"%s"`, indent, indent, s.ptr);
        isFirst = false;
    }
    fun(&print);
    printf("\n%s]", indent);
}

private void determinePlatform(void delegate(string) print)
{
    import dmd.globals : global;

    if (global.params.isWindows)
    {
        print("windows");
    }
    else
    {
        print("posix");
        if (global.params.isLinux)
            print("linux");
        if (global.params.isOSX)
            print("osx");
        if (global.params.isFreeBSD)
        {
            print("freebsd");
            print("bsd");
        }
        if (global.params.isOpenBSD)
        {
            print("openbsd");
            print("bsd");
        }
        if (global.params.isSolaris)
        {
            print("solaris");
            print("bsd");
        }
    }
}

private void determineArchitecture(void delegate(string) print)
{
    import dmd.globals : global;

    if (global.params.is64bit)
        print("x86_64");
    else
        version(X86) print("x86");
}

private void predefinedVersions(void delegate(string) print)
{
    import dmd.globals : global;
    foreach (const s; *global.versionids)
    {
        print(cast(string) s.toString);
    }
}

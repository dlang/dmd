module compilable.crlf;

import support : afterEach, beforeEach, defaultImportPaths;

@beforeEach initializeFrontend()
{
    import dmd.frontend : initDMD;
    initDMD();
}

@afterEach deinitializeFrontend()
{
    import dmd.frontend : deinitializeDMD;
    deinitializeDMD();
}

@("test CRLF and mixed line endings")
unittest
{
    import std.array : join;
    import std.format : format;

    import support : compiles, stripDelimited;

    // not using token string due to https://issues.dlang.org/show_bug.cgi?id=19315
    enum crLFCode = `
        #!/usr/bin/env dmd -run

        #line 4

        void main()
        {
        }

        // single-line comment

        /*
          multi-line comment
        */

        /+
          nested comment
        +/

        /**
          doc comment
        */
        void documentee() {}
    `
    .stripDelimited
    .toCRLF;


    enum codeLines = [
        "// mixed\n// line\n// endings",
        "void fun()\n{\n}",

        format!`enum str = "%s";`("\r\nfoo\r\nbar\nbaz\r\n"),
        `static assert(str == "\nfoo\nbar\nbaz\n");` ,

        format!"enum bstr = `%s`;"("\r\nfoo\r\nbar\nbaz\r\n"),
        `static assert(bstr == "\nfoo\nbar\nbaz\n");`,

        format!`enum wstr = q"%s";`("EOF\r\nfoo\r\nbar\nbaz\r\nEOF"),
        `static assert(wstr == "foo\nbar\nbaz\n");`,

        format!`enum dstr = q"(%s)";`("\r\nfoo\r\nbar\nbaz\r\n"),
        `static assert(dstr == "\nfoo\nbar\nbaz\n");`
    ];

    enum code = crLFCode ~ "\r\n" ~ codeLines.join('\n') ~ '\n';

    assert(compiles(code));
}

private:

string toCRLF(string str)
{
    import std.string : lineSplitter, join;

    return str.lineSplitter.join("\r\n");
}

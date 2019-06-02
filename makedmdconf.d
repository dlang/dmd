#!/usr/bin/env rdmd
module makedmdconf;

import core.stdc.stdlib : exit;
import std.getopt, std.string;
import std.path, std.file, std.stdio;
import std.process;

int main(string[] args)
{
    bool mscoff = false;

    auto helpInfo = getopt(args,
        "mscoff", &mscoff);
    enum nonOptionArgCount = 3;
    const wrongArgCount = (args.length != nonOptionArgCount + 1);
    if (wrongArgCount || helpInfo.helpWanted)
    {
        if (wrongArgCount)
            writefln("Error: expected %s non-option args but got %s", nonOptionArgCount, args.length - 1);
        defaultGetoptPrinter("Usage: makedmdconf [-options] <outfile> <os> <bulid>", helpInfo.options);
        return 1;
    }

    const outFile = args[1];
    const os      = args[2];
    const build   = args[3];

    if (updateIfChanged(outFile, generateDmdConf(os, build, mscoff)))
        writefln("updated '%s'", outFile);
    else
        writefln("already up-to-date '%s'", outFile);
    return 0;
}

string generateDmdConf(string os, string build, bool mscoff)
{
    string sharedflags = "";
    string model32flags = "";
    string model64flags = "";

    sharedflags  ~= " -I%@P%/../../../../../druntime/import";
    sharedflags  ~= " -I%@P%/../../../../../phobos";
    model32flags ~= " -L-L%@P%/../../../../../phobos/generated/{os}/{build}/32";
    model64flags ~= " -L-L%@P%/../../../../../phobos/generated/{os}/{build}/64";

    if (os == "windows")
    {
        // NOTE: I don't think I need to add user32/kernel32 because I think the
        //       phobos library itself will cause them to be added
        if (mscoff)
        {
            model32flags ~= " -defaultlib=phobos32mscoff";
            model64flags ~= " -defaultlib=phobos64mscoff";
        }
        else
        {
            model32flags ~= " -defaultlib=phobos";
        }
    }

    if (os == "linux" || os == "freebsd" || os == "openbsd" || os == "solaris" || os == "dragonflybsd")
    {
        sharedflags  ~= " -defaultlib=libphobos2.a";
        model64flags ~= " -fPIC";
    }
    if (os == "linux")
        sharedflags ~= " -L-lpthread -L-lm -L-ldl -L-lrt";
    if (os == "osx")
        sharedflags ~= " -L--export-dynamic";

    string content = "";
    if (model32flags.length)
        content ~= "[Environment32]\nDFLAGS=" ~ sharedflags ~ model32flags ~ "\n";
    if (model64flags.length)
        content ~= "[Environment64]\nDFLAGS=" ~ sharedflags ~ model64flags ~ "\n";
    return content.replace("{os}", os).replace("{build}", build);
}

bool updateIfChanged(const string path, const string content)
{
    if (path.exists)
    {
        if (path.readText == content)
            return false; // up-to-date
    }
    else
        mkdirRecurse(path.dirName);
    std.file.write(path, content);
    return true;
}

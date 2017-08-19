#!/usr/bin/env rdmd
/*
 * Footer generator for the specification pages.
 * This script can be used to update the nav footers.
 *
 * Copyright (C) 2017 by D Language Foundation
 *
 * Author: Sebastian Wilzbach
 *
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
*/
// Written in the D programming language.

void main()
{
    import std.algorithm, std.array, std.ascii, std.conv, std.file, std.path, std.range, std.string, std.typecons;
    import std.stdio : File, writeln, writefln;
    auto specDir = __FILE_FULL_PATH__.dirName.buildNormalizedPath;
    auto mainFile = specDir.buildPath("./spec.ddoc");
    enum ddocKey = "$(SPEC_SUBNAV_";

    alias Entry = Tuple!(string, "name", string, "title");
    Entry[] entries;

    // parse the menu from the Ddoc file
    auto specText = mainFile.readText;
    if (!specText.findSkip("SUBMENU2"))
        writeln("Menu file has an invalid format.");
    foreach (line; specText.splitter("\n"))
    {
        enum ddocEntryStart = "$(ROOT_DIR)spec/";
        if (line.canFind(ddocEntryStart))
        {
            auto ps = line.splitter(ddocEntryStart).dropOne.front.splitter(",");
            entries ~= Entry(ps.front.stripExtension.withExtension(".dd").to!string,
                             ps.dropOne.front.idup.strip);
        }
    }

    foreach (i, entry; entries)
    {
        // build the prev|next Ddoc string
        string navString = ddocKey;
        if (i == 0)
            navString ~= text("NEXT ", entries[i + 1].name.stripExtension, ", ", entries[i + 1].title);
        else if (i < entries.length - 1)
            navString ~= text("PREV_NEXT ", entries[i - 1].name.stripExtension, ", ", entries[i - 1].title, ", ",
                entries[i + 1].name.stripExtension, ", ", entries[i + 1].title);
        else
            navString ~= text("PREV ", entries[i - 1].name.stripExtension, ", ", entries[i - 1].title);

        navString ~= ")";
        writefln("%s: %s", entry.name, navString);
        auto fileName = specDir.buildPath(entry.name);

        auto text = fileName.readText;
        // idempotency - check for existing tags, otherwise insert new
        auto pos = text.representation.countUntil(ddocKey);
        if (pos > 0)
        {
            auto len = text[pos .. $].representation.countUntil(")");
            text = text.replace(text[pos .. pos + len + 1], navString);
        }
        else
        {
            // insert at the end of the ddoc page
            auto v = text[0 .. $ - text.retro.countUntil((newline ~ "Macros:").retro)];
            pos = v.length - v.retro.countUntil(")");
            text.insertInPlace(pos - 1, navString ~ "\n");
        }
        fileName.write(text);
    }
}

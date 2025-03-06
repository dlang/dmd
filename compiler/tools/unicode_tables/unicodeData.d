/**
This module parses the UCD UnicodeData.txt file.

Copyright:   Copyright (C) 1999-2025 by The D Language Foundation, All Rights Reserved
Authors:     $(LINK2 https://cattermole.co.nz, Richard (Rikki) Andrew Cattermole
License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
module unicode_tables.unicodeData;
import unicode_tables.util;

UDEntry[] udEntries;

void parseUnicodeData(string dataFile)
{
    import std.algorithm : countUntil, endsWith;
    import std.file : readText;
    import std.string : lineSplitter, strip, split;
    import std.conv : parse;

    bool expectedRangeEnd, nextRangeEnd;

    foreach (line; readText(dataFile).lineSplitter)
    {
        {
            // handle end of line comment
            ptrdiff_t offset = line.countUntil('#');
            if (offset >= 0)
                line = line[0 .. offset];
            line = line.strip;
        }

        string[] fields = line.split(";");
        {
            foreach (ref field; fields)
            {
                field = field.strip;
            }

            if (fields.length == 0)
            {
                continue;
            }
            else if (fields.length != 15)
            {
                continue;
            }
        }

        {
            /+
            How first field ranges are specified (the First, Last bit):
            3400;<CJK Ideograph Extension A, First>;Lo;0;L;;;;;N;;;;;
            4DBF;<CJK Ideograph Extension A, Last>;Lo;0;L;;;;;N;;;;;
            +/

            if (fields[1].endsWith(">"))
            {
                if (fields[1].endsWith("First>"))
                {
                    nextRangeEnd = true;
                }
                else if (fields[1].endsWith("Last>"))
                {
                    assert(nextRangeEnd);
                    nextRangeEnd = false;
                    expectedRangeEnd = true;
                }
                else if (fields[1] == "<control>")
                    {
                        if (expectedRangeEnd)
                        {
                            nextRangeEnd = false;
                            expectedRangeEnd = false;
                            continue;
                        }
                    }
                    else
                    {
                        continue;
                    }
            }
            else if (expectedRangeEnd)
            {
                continue;
            }
        }

        uint character = parse!uint(fields[0], 16);

        if (expectedRangeEnd)
        {
            udEntries[$ - 1].range.end = character;
            expectedRangeEnd = false;
            continue;
        }

        {
            UDEntry entry;
            entry.range = ValueRange(character);

            static foreach (GC; __traits(allMembers, GeneralCategory))
            {
                if (fields[2] == GC)
                    entry.generalCategory = __traits(getMember, GeneralCategory, GC);
            }

            entry.canonicalCombiningClass = parse!int(fields[3]);

            udEntries ~= entry;
        }
    }
}

struct UDEntry
{
    ValueRange range;
    GeneralCategory generalCategory;
    int canonicalCombiningClass;

    @safe:

    bool isStarter()
    {
        return canonicalCombiningClass == 0;
    }

    bool isAlpha()
    {
        switch (generalCategory)
        {
            case GeneralCategory.Lu:
            case GeneralCategory.Ll:
            case GeneralCategory.Lt:
            case GeneralCategory.Lm:
            case GeneralCategory.Lo:
                return true;
            default:
                return false;
        }
    }
}

enum GeneralCategory
{
    None, ///
    Lu, ///
    Ll, ///
    Lt, ///
    LC, ///
    Lm, ///
    Lo, ///
    L, ///
    Mn, ///
    Mc, ///
    Me, ///
    M, ///
    Nd, ///
    Nl, ///
    No, ///
    N, ///
    Pc, ///
    Pd, ///
    Ps, ///
    Pe, ///
    Pi, ///
    Pf, ///
    Po, ///
    P, ///
    Sm, ///
    Sc, ///
    Sk, ///
    So, ///
    S, ///
    Zs, ///
    Zl, ///
    Zp, ///
    Z, ///
    Cc, ///
    Cf, ///
    Cs, ///
    Co, ///
    Cn, ///
    C, ///
}

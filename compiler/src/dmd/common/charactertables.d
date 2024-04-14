/**
 * Character tables related to identifiers.
 *
 * Supports UAX31, C99, C11 and least restrictive (All).
 *
 * Supports normalization quick check algorithm, ignores maybe value.
 *
 * Copyright: Copyright (C) 1999-2024 by The D Language Foundation, All Rights Reserved
 * Authors:   $(LINK2 https://cattermole.co.nz, Richard (Rikki) Andrew Cattermole)
 * License:   $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/common/charactertables.d, common/charactertables.d)
 * Documentation: https://dlang.org/phobos/dmd_common_charactertables.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/common/charactertables.d
 */
module dmd.common.charactertables;
import dmd.common.identifiertables;

// Has to be above the @nogc
private template PlaneOffsetForRanges(alias Ranges)
{
    enum PlaneOffsetForRanges = () {
        size_t[] result = new size_t[18];
        ptrdiff_t lastPlane = -1;
        size_t offset;

        // Add a plane for a given index.
        // If we don't do it like this we're gonna have problems where planes get missed out.
        // So the tables won't be as sequentially or predictable as required.
        void add(int plane, size_t indexOfPlaneStart)
        {
            foreach (p; lastPlane + 1 .. plane)
            {
                result[offset++] = indexOfPlaneStart;
                lastPlane = p;
            }

            if (plane > lastPlane)
            {
                assert(plane == offset);
                assert(plane == lastPlane + 1);

                result[offset++] = indexOfPlaneStart;
                lastPlane = plane;
            }
        }

        foreach (indexOfPlaneStart, v; Ranges)
        {
            int startPlane = (cast(int) v[0]) >> 16;
            const endPlane = (cast(int) v[1]) >> 16;

            add(startPlane, indexOfPlaneStart);
            startPlane++;

            while (startPlane <= endPlane)
            {
                add(startPlane++, indexOfPlaneStart);
            }
        }

        // 16 planes in Unicode, you need one more to make it a naive plane + 1 to remove extra conditionals.
        foreach (_; offset .. 18)
        {
            result[offset++] = Ranges.length;
        }

        return result;
    }();
}

@safe nothrow @nogc pure:

extern (C++):

///
enum IdentifierTable
{
    UAX31, ///
    C99, ///
    C11, ///
    LR, /// Least Restrictive aka All
}

///
struct IdentifierCharLookup
{
@safe nothrow @nogc pure:

    ///
    extern (C++) bool function(dchar) isStart;
    ///
    extern (C++) bool function(dchar, ref UnicodeQuickCheckState) isContinue;

    /// Lookup the table given the table name
    static IdentifierCharLookup forTable(IdentifierTable table)
    {
        // Awful solution to require these lambdas.
        // However without them the extern(C++) ABI issues crop up for isInRange,
        //  and then it can't access the tables.

        // dfmt off
        final switch (table)
        {
        case IdentifierTable.UAX31:
            return IdentifierCharLookup(
                    (c) => isInRange!UAX31_Start(c),
                    (c, ref unicodeQuickCheckState) => isInRange!UAX31_Continue(c, unicodeQuickCheckState));
        case IdentifierTable.C99:
            return IdentifierCharLookup(
                    (c) => isInRange!FixedTable_C99_Start(c),
                    (c, ref unicodeQuickCheckState) => isInRange!FixedTable_C99_Continue(c, unicodeQuickCheckState));
        case IdentifierTable.C11:
            return IdentifierCharLookup(
                    (c) => isInRange!FixedTable_C11_Start(c),
                    (c, ref unicodeQuickCheckState) => isInRange!FixedTable_C11_Continue(c, unicodeQuickCheckState));
        case IdentifierTable.LR:
            return IdentifierCharLookup(
                    (c) => isInRange!LeastRestrictive_Start(c),
                    (c, ref unicodeQuickCheckState) => isInRange!LeastRestrictive_Continue(c, unicodeQuickCheckState));
        }
        //dfmt on
    }
}

/// Normalization strategies
enum NormalizationStrategy
{
    SilentlyAccept, /// Silently accept unnormalized strategies
    Normalize, /// Unimplemented
    Deprecate, /// Emit deprecations but accept
    Warning, /// Emit warning but accept
}

/**
State for normalization quick check algorithm.

https://unicode.org/reports/tr15/#Detecting_Normalization_Forms
*/
struct UnicodeQuickCheckState
{
    ubyte lastCCC;
    bool isNormalized = true;
}

/**
Convenience function for use in places where we just don't care,
what the identifier ranges are, or if it is start/continue.

Returns: is character a member of least restrictive of all.
*/
bool isAnyIdentifierCharacter(dchar c)
{
    return isInRange!LeastRestrictive_OfAll(c);
}

///
unittest
{
    assert(isAnyIdentifierCharacter('ğ'));
}

/**
Convenience function for use in places where we just don't care,
what the identifier ranges are.

Returns: is character a member of restrictive Start
*/
bool isAnyStart(dchar c)
{
    return isInRange!LeastRestrictive_Start(c);
}

///
unittest
{
    assert(isAnyStart('ğ'));
}

/**
Convenience function for use in places where we just don't care,
what the identifier ranges are.

Returns: is character a member of least restrictive Continue
*/
bool isAnyContinue(dchar c)
{
    return isInRange!LeastRestrictive_Continue(c);
}

///
unittest
{
    assert(isAnyContinue('ğ'));
}

/// UTF line separator
enum LS = 0x2028;
/// UTF paragraph separator
enum PS = 0x2029;

private
{
    enum CMoctal = 0x1;
    enum CMhex = 0x2;
    enum CMidchar = 0x4;
    enum CMzerosecond = 0x8;
    enum CMdigitsecond = 0x10;
    enum CMsinglechar = 0x20;
}

///
bool isoctal(const char c)
{
    return (cmtable[c] & CMoctal) != 0;
}

///
bool ishex(const char c)
{
    return (cmtable[c] & CMhex) != 0;
}

///
bool isidchar(const char c)
{
    return (cmtable[c] & CMidchar) != 0;
}

///
bool isZeroSecond(const char c)
{
    return (cmtable[c] & CMzerosecond) != 0;
}

///
bool isDigitSecond(const char c)
{
    return (cmtable[c] & CMdigitsecond) != 0;
}

///
bool issinglechar(const char c)
{
    return (cmtable[c] & CMsinglechar) != 0;
}

///
bool c_isxdigit(const int c)
{
    return ((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'));
}

///
bool c_isalnum(const int c)
{
    return ((c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'));
}

extern (D) private:

bool isInRange(alias Ranges)(dchar c)
{
    pragma(inline, true);
    return findInBinaryTablePair!Ranges(c) >= 0;
}

bool isInRange(alias Ranges)(dchar c, ref UnicodeQuickCheckState unicodeQuickCheckState)
{
    // Boot strap compiler cannot inline this function.
    // As of 2024Q1

    if (findInBinaryTablePair!Ranges(c) < 0)
        return false;

    // For more information on the following see the normalization quick check algorithm.
    // https://unicode.org/reports/tr15/#Detecting_Normalization_Forms

    // Note how maybe gets rolled into no,
    //  from a practical stand point that means we have to do normalization more often.
    // But it also means we can simplify our implementation greatly.

    const isNormalized = findInBinaryTablePair!IsCharacterNotNormalized(c) >= 0;

    const cccIndex = findInBinaryTablePair!IndexTableForCCC(c);
    assert(cccIndex >= 0, "CCC lookup table _must_ have every CCC value for each character in any input character table, unmapped value provided.");
    const ccc = ValueTableForCCC[cccIndex];

    // If we are not normalized
    //  or if our last ccc is more than ours
    //  and ours isn't a starter.
    // Then we have a bit of a problem,
    //  this can't be normalized.
    if (!isNormalized || (unicodeQuickCheckState.lastCCC > ccc && ccc > 0))
        unicodeQuickCheckState.isNormalized = false;

    unicodeQuickCheckState.lastCCC = ccc;
    return true;
}

// The reason we return a ptrdiff_t, is to be able to use it for maps.
// An index table + a value table, of same length.
// This is an appropriete approach for the CCC table,
//  but will work equally well for normal check if character is in set.
ptrdiff_t findInBinaryTablePair(alias Ranges)(dchar c)
{
    // Boot strap compiler cannot inline this function.
    // As of 2024Q1

    // Buckets the ranges based upon plane (per 0xFFFF).
    // Original code used wchar's instead of dchar's,
    //  as a result this reverts the performance back to pre-UAX31 levels,
    //  which is a good thing if we want it to be "fast".
    static immutable PlaneOffsets = PlaneOffsetForRanges!Ranges;

    // Do not attempt to optimize this further by switching off of bucketed binary search without benchmarking.
    // Alternatives that were attempted:
    // - Binary search (original)
    // - Bucketed binary search (by plane)
    // - Fibonaccian search (naive)
    // - Fibonaccian search (Knuth)
    // - Bucketed Fibonaccian search (Knuth)
    // Bucketed binary search was just under half the running time over binary search.
    // Fibonaccian search (Knuth) may seem like an ultra good idea to take advantage of probabilities,
    //  and it may be better, however...
    //  it uses a lot of ROM and any wins is only over the binary search and not the bucketed binary search.

    // It may appear to be a good idea to inject extra information into the tables LSB,
    //  such as the Yes/No/Maybe NFC normalized table,
    //  however it will balloon the source file over 98mb.
    // Use separate tables, even if it costs a little more CPU and ROM.

    const plane = c >> 16;
    // Due to universal character names for ImportC, the plane may be > 16.
    // This is not a bug in this code, but does indicate bad input.
    if (plane > 16)
        return -1;

    const planeStart = PlaneOffsets[plane], planeNextStart = PlaneOffsets[plane + 1];
    if (planeStart < planeNextStart)
    {
        immutable(dchar[2][]) pairs = Ranges[planeStart .. planeNextStart];

        size_t high = pairs.length - 1;
        // Shortcut search if c is out of range
        size_t low = (c < pairs[0][0] || pairs[high][1] < c) ? high + 1 : 0;

        // Binary search
        while (low <= high)
        {
            const mid = low + ((high - low) >> 1);

            if (c < pairs[mid][0])
                high = mid - 1;
            else if (pairs[mid][1] < c)
                low = mid + 1;
            else
            {
                assert(pairs[mid][0] <= c && c <= pairs[mid][1]);
                return planeStart + mid;
            }
        }
    }

    return -1;
}

// Verify that all the tables can actually find start/mid/end in them
unittest
{
    void verify(alias Ranges, alias ToTest)()
    {
        foreach (toTest; ToTest)
        {
            const c = cast(dchar) toTest[0];
            const index = toTest[1];

            assert(findInBinaryTablePair!Ranges(c) == index);
        }
    }

    verify!(UAX31_Start, UAX31_Start_Test);
    verify!(UAX31_Continue, UAX31_Continue_Test);
    verify!(FixedTable_C99_Continue, FixedTable_C99_Continue_Test);
    verify!(FixedTable_C11_Continue, FixedTable_C11_Continue_Test);
    verify!(LeastRestrictive_OfAll, LeastRestrictive_OfAll_Test);
    verify!(LeastRestrictive_Start, LeastRestrictive_Start_Test);
    verify!(LeastRestrictive_Continue, LeastRestrictive_Continue_Test);
    verify!(IsCharacterNotNormalized, IsCharacterNotNormalized_Test);
    verify!(IndexTableForCCC, IndexTableForCCC_Test);
}

/********************************************
 * Do our own char maps
 */
// originally from dmd.lexer (was private)
static immutable cmtable = () {
    ubyte[256] table;
    foreach (const c; 0 .. table.length)
    {
        if ('0' <= c && c <= '7')
            table[c] |= CMoctal;
        if (c_isxdigit(c))
            table[c] |= CMhex;
        if (c_isalnum(c) || c == '_')
            table[c] |= CMidchar;

        switch (c)
        {
        case 'x':
        case 'X':
        case 'b':
        case 'B':
            table[c] |= CMzerosecond;
            break;

        case '0':
                .. case '9':
        case 'e':
        case 'E':
        case 'f':
        case 'F':
        case 'l':
        case 'L':
        case 'p':
        case 'P':
        case 'u':
        case 'U':
        case 'i':
        case '.':
        case '_':
            table[c] |= CMzerosecond | CMdigitsecond;
            break;

        default:
            break;
        }

        switch (c)
        {
        case '\\':
        case '\n':
        case '\r':
        case 0:
        case 0x1A:
        case '\'':
            break;
        default:
            if (!(c & 0x80))
                table[c] |= CMsinglechar;
            break;
        }
    }
    return table;
}();

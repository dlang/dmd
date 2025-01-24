/**
 * Encapsulates file/line/column locations.
 *
 * Copyright:   Copyright (C) 1999-2024 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/location.d, _location.d)
 * Documentation:  https://dlang.org/phobos/dmd_location.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/location.d
 */

module dmd.location;

import core.stdc.stdio;

import dmd.common.outbuffer;
import dmd.root.array;
import dmd.root.filename;
import dmd.root.string: toDString;

/// How code locations are formatted for diagnostic reporting
enum MessageStyle : ubyte
{
    digitalmars,  /// filename.d(line): message
    gnu,          /// filename.d:line: message, see https://www.gnu.org/prep/standards/html_node/Errors.html
    sarif         /// JSON SARIF output, see https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html
}
/**
A source code location

Used for error messages, `__FILE__` and `__LINE__` tokens, `__traits(getLocation, XXX)`,
debug info etc.
*/
struct Loc
{
    private uint index = 0; // offset into lineTable[]

    // FIXME: This arbitrary size increase is needed to prevent segfault in
    // runnable/test42.d on Ubuntu x86 when DMD was built with DMD 2.105 .. 2.110
    // https://github.com/dlang/dmd/pull/20777#issuecomment-2614128849
    version (linux) version (DigitalMars) static if (size_t.sizeof == 4)
        private uint dummy;

    static immutable Loc initial; /// use for default initialization of const ref Loc's

    extern (C++) __gshared bool showColumns;
    extern (C++) __gshared MessageStyle messageStyle;

nothrow:

    /*******************************
     * Configure how display is done
     * Params:
     *  showColumns = when to display columns
     *  messageStyle = digitalmars or gnu style messages
     */
    extern (C++) static void set(bool showColumns, MessageStyle messageStyle)
    {
        this.showColumns = showColumns;
        this.messageStyle = messageStyle;
    }

    static Loc singleFilename(const char* filename)
    {
        Loc result;
        locFileTable ~= BaseLoc(filename.toDString, locIndex, 0, [0]);
        result.index = locIndex++;
        return result;
    }

    /// utf8 code unit index relative to start of line, starting from 1
    extern (C++) uint charnum() const @nogc @safe
    {
        return SourceLoc(this).column;
    }

    /// line number, starting from 1
    extern (C++) uint linnum() const @nogc @trusted
    {
        return SourceLoc(this).line;
    }

    /// Advance this location to the first column of the next line
    void nextLine()
    {
        const i = fileTableIndex(this.index);
        const j = locFileTable[i].getLineIndex(this.index - locFileTable[i].startIndex);
        if (j + 1 < locFileTable[i].lines.length)
            index = locFileTable[i].startIndex + locFileTable[i].lines[j + 1];
    }

    /***
     * Returns: filename for this location, null if none
     */
    extern (C++) const(char)* filename() const @nogc
    {
        return SourceLoc(this).filename.ptr; // _filename;
    }

    extern (C++) const(char)* toChars(
        bool showColumns = Loc.showColumns,
        MessageStyle messageStyle = Loc.messageStyle) const nothrow
    {
        return SourceLoc(this).toChars(showColumns, messageStyle);
    }

    /// Returns: byte offset into source file
    uint fileOffset() const
    {
        return SourceLoc(this).fileOffset;
    }

    /**
     * Checks for equivalence by comparing the filename contents (not the pointer) and character location.
     *
     * Note:
     *  - Uses case-insensitive comparison on Windows
     *  - Ignores `charnum` if `Columns` is false.
     */
    extern (C++) bool equals(ref const(Loc) loc) const
    {
        SourceLoc lhs = SourceLoc(this);
        SourceLoc rhs = SourceLoc(loc);
        return (!showColumns || lhs.column == rhs.column) &&
               lhs.line == rhs.line &&
               FileName.equals(lhs.filename, rhs.filename);
    }

    /**
     * `opEquals()` / `toHash()` for AA key usage
     *
     * Compare filename contents (case-sensitively on Windows too), not
     * the pointer - a static foreach loop repeatedly mixing in a mixin
     * may lead to multiple equivalent filenames (`foo.d-mixin-<line>`),
     * e.g., for test/runnable/test18880.d.
     */
    extern (D) bool opEquals(ref const(Loc) loc) const @trusted nothrow @nogc
    {
        return this.index == loc.index;
    }

    /// ditto
    extern (D) size_t toHash() const @trusted nothrow
    {
        return hashOf(this.index);
    }

    /******************
     * Returns:
     *   true if Loc has been set to other than the default initialization
     */
    bool isValid() const pure @safe
    {
        return this.index != 0;
    }
}

/**
 * Format a source location for error messages
 *
 * Params:
 *   buf = buffer to write string into
 *   loc = source location to write
 *   showColumns = include column number in message
 *   messageStyle = select error message format
 */
void writeSourceLoc(ref OutBuffer buf,
    SourceLoc loc,
    bool showColumns,
    MessageStyle messageStyle) nothrow
{
    if (loc.filename.length == 0)
        return;
    buf.writestring(loc.filename);
    if (loc.line == 0)
        return;

    final switch (messageStyle)
    {
        case MessageStyle.digitalmars:
            buf.writeByte('(');
            buf.print(loc.line);
            if (showColumns && loc.column)
            {
                buf.writeByte(',');
                buf.print(loc.column);
            }
            buf.writeByte(')');
            break;
        case MessageStyle.gnu: // https://www.gnu.org/prep/standards/html_node/Errors.html
            buf.writeByte(':');
            buf.print(loc.line);
            if (showColumns && loc.column)
            {
                buf.writeByte(':');
                buf.print(loc.column);
            }
            break;
        case MessageStyle.sarif: // https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html
            // No formatting needed here for SARIF
            break;
    }
}

/**
 * Describes a location in the source code as a file + line number + column number
 *
 * While `Loc` is a compact opaque location meant to be stored in the AST,
 * this struct has simple modifiable fields and is used for printing.
 */
struct SourceLoc
{
    const(char)[] filename; /// name of source file
    uint line; /// line number (starts at 1)
    uint column; /// column number (starts at 1)
    uint fileOffset; /// byte index into file

    // aliases for backwards compatibility
    alias linnum = line;
    alias charnum = column;

    this(const(char)[] filename, uint line, uint column, uint fileOffset = 0) nothrow @nogc pure @safe
    {
        this.filename = filename;
        this.line = line;
        this.column = column;
        this.fileOffset = fileOffset;
    }

    this(Loc loc) nothrow @nogc @trusted
    {
        if (loc.index == 0 || locFileTable.length == 0)
            return;

        const i = fileTableIndex(loc.index);
        this = locFileTable[i].getSourceLoc(loc.index - locFileTable[i].startIndex);
    }

    extern (C++) const(char)* toChars(
        bool showColumns = Loc.showColumns,
        MessageStyle messageStyle = Loc.messageStyle) const nothrow
    {
        OutBuffer buf;
        writeSourceLoc(buf, this, showColumns, messageStyle);
        return buf.extractChars();
    }

    bool opEquals(SourceLoc other) const nothrow
    {
        return this.filename == other.filename && this.line == other.line && this.column == other.column;
    }

}

private size_t fileTableIndex(uint index) nothrow @nogc
{
    // To speed up linear find, we cache the last hit and compare that first,
    // since usually we stay in the same file for some time when resolving source locations.
    // If it's a differnet file now, either scan forwards / backwards
    __gshared size_t lastI = 0; // index of last found hit

    size_t i = lastI;
    if (index >= locFileTable[i].startIndex)
    {
        while (i + 1 < locFileTable.length && index >= locFileTable[i+1].startIndex)
            i++;
    }
    else
    {
        while (index < locFileTable[i].startIndex)
            i--;
    }

    lastI = i;
    return i;
}

/**
 * Create a new source location map for a file
 * Params:
 *   filename = source file name
 *   size = space to reserve for locations, equal to the file size in bytes
 * Returns: new BaseLoc
 */
BaseLoc* newBaseLoc(const(char)* filename, size_t size) nothrow
{
    locFileTable ~= BaseLoc(filename.toDString, locIndex, 1, [0]);
    // Careful: the endloc of a funcdeclaration can
    // be one past the very last byte in the file, so account for that
    locIndex += size + 1;
    return &locFileTable[$ - 1];
}

/// Mapping from byte offset into source file to line/column numbers
struct BaseLoc
{
@safe nothrow:

    const(char)[] filename; // Source file name
    uint startIndex; // Subtract this from Loc.index to get file offset
    int startLine = 1; // Line number at index 0
    uint[] lines; // For each line, the file offset at which it starts
    BaseLoc[] substitutions; // Substitutions from #line / #file directives

    /// Register that a new line starts at `offset`
    void newLine(uint offset)
    {
        lines ~= offset;
    }

    Loc getLoc(uint offset) @nogc
    {
        Loc result;
        // import std.stdio; debug writeln(startIndex, " + ", offset, " = ", startIndex + offset);
        result.index = startIndex + offset;
        return result;
    }

    /// Handles #file and #line directives
    void addSubstitution(uint offset, const(char)* filename, uint linnum) @system
    {
        auto fname = filename.toDString;
        if (fname.length == 0 && substitutions.length > 0)
            fname = substitutions[$ - 1].filename;
        substitutions ~= BaseLoc(fname, offset, cast(int) (linnum - lines.length + startLine - 2));
    }

    /// Returns: `loc` modified by substitutions from #file / #line directives
    SourceLoc substitute(SourceLoc loc, uint offset) @nogc
    {
        // printf("substitutions: %d\n", cast(int) substitutions.length);
        size_t latest = -1;
        foreach (i, ref sub; substitutions)
        {
            if (offset >= sub.startIndex)
                latest = i;
            else
                break;
        }
        if (latest != -1)
        {
            if (substitutions[latest].filename.length > 0)
                loc.filename = substitutions[latest].filename;
            loc.linnum += substitutions[latest].startLine;
        }
        return loc;
    }

    // Resolve an offset into this file to a filename + line + column
    private SourceLoc getSourceLoc(uint offset) @nogc
    {
        const i = getLineIndex(offset);
        const sl = SourceLoc(filename, cast(int) (i + startLine), cast(int) (1 + offset - lines[i]), offset);
        return substitute(sl, offset);
    }

    // Binary search the index in this.lines corresponding to `offset`
    private size_t getLineIndex(uint offset) @nogc
    {
        size_t lo = 0;
        size_t hi = lines.length + -1;
        size_t mid = 0;
        while (lo <= hi)
        {
            mid = lo + (hi - lo) / 2;
            if (lines[mid] <= offset)
            {
                if (mid == lines.length - 1 || lines[mid + 1] > offset)
                    return mid;

                lo = mid + 1;
            }
            else
            {
                hi = mid - 1;
            }
        }
        assert(0);
    }
}

private __gshared uint locIndex = 1; // Index of start of the file
private __gshared BaseLoc[] locFileTable;

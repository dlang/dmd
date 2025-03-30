/**
 * Implementation of code coverage analyzer.
 *
 * Copyright: Copyright Digital Mars 1995 - 2015.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Walter Bright, Sean Kelly
 * Source: $(DRUNTIMESRC rt/_cover.d)
 */

module rt.cover;

import core.internal.utf;
import core.internal.util.math : max, min;
import core.stdc.stdio : EOF, fclose, fgetc, FILE, fileno, fprintf, fread, fseek, ftell, printf, SEEK_END, SEEK_SET,
    stderr;
import core.stdc.stdlib : exit, EXIT_FAILURE;

version (Windows)
{
    import core.stdc.stdio : _fdopen, _get_osfhandle, _O_BINARY, _O_CREAT, _O_RDWR, _S_IREAD, _S_IWRITE, _wopen;
    import core.sys.windows.basetsd;
    import core.sys.windows.winbase;
}
else version (Posix)
{
    import core.stdc.stdio : fopen;
    import core.sys.posix.fcntl : O_CREAT, O_RDWR, open, S_IRGRP, S_IROTH, S_IRUSR, S_IWGRP, S_IWOTH, S_IWUSR;
    import core.sys.posix.unistd : ftruncate;
}
else
    static assert(0, "Unsupported platform");

private
{
    struct BitArray
    {
        size_t  len;
        size_t* ptr;

        bool opIndex( size_t i )
        in
        {
            assert( i < len );
        }
        do
        {
            static if (size_t.sizeof == 8)
                return ((ptr[i >> 6] & (1L << (i & 63)))) != 0;
            else static if (size_t.sizeof == 4)
                return ((ptr[i >> 5] & (1  << (i & 31)))) != 0;
            else
                static assert(0);
        }
    }

    struct Cover                // one of these for each module being analyzed
    {
        string      filename;
        BitArray    valid;      // bit array of which source lines are executable code lines
        uint[]      data;       // array of line execution counts
        ubyte       minPercent; // minimum percentage coverage required
    }

    __gshared
    {
        Cover[] gdata;
        Config config;
    }

    struct Config
    {
        string  srcpath;
        string  dstpath;
        bool    disable;
        bool    merge;

    @nogc nothrow:

        bool initialize()
        {
            import core.internal.parseoptions : initConfigOptions;
            return initConfigOptions(this, this.errorName);
        }

        void help()
        {
            string s = "Code coverage options are specified as whitespace separated assignments:
    merge:0|1      - 0 overwrites existing reports, 1 merges current run with existing coverage reports (default: %d)
    disable:0|1    - 1 disables writing coverage report even if binary is compiled with coverage
    dstpath:<PATH> - writes code coverage reports to <PATH> (default: current
            working directory)
    srcpath:<PATH> - sets the path where the source files are located to <PATH>
    (default: current working directory)
";
            printf(s.ptr, merge);
        }

        string errorName() { return "covopt"; }
    }
}


/**
 * Set path to where source files are located.
 *
 * Params:
 *  pathname = The new path name.
 */
extern (C) void dmd_coverSourcePath( string pathname )
{
    config.srcpath = pathname;
}


/**
 * Set path to where listing files are to be written.
 *
 * Params:
 *  pathname = The new path name.
 */
extern (C) void dmd_coverDestPath( string pathname )
{
    config.dstpath = pathname;
}


/**
 * Set merge mode.
 *
 * Params:
 *      flag = true means new data is summed with existing data in the listing
 *         file; false means a new listing file is always created.
 */
extern (C) void dmd_coverSetMerge( bool flag )
{
    config.merge = flag;
}


/**
 * The coverage callback.
 *
 * Params:
 *  filename = The name of the coverage file.
 *  valid    = Bit array containing the valid code lines for coverage
 *  data     = Array containg the coverage hits of each line
 *  minPercent = minimal coverage of the module
 */
extern (C) void _d_cover_register2(string filename, size_t[] valid, uint[] data, ubyte minPercent)
{
    assert(minPercent <= 100);

    Cover c;

    c.filename  = filename;
    c.valid.ptr = valid.ptr;
    c.valid.len = valid.length;
    c.data      = data;
    c.minPercent = minPercent;
    gdata      ~= c;
}

/* Kept for the moment for backwards compatibility.
 */
extern (C) void _d_cover_register( string filename, size_t[] valid, uint[] data )
{
    _d_cover_register2(filename, valid, data, 0);
}

private:

// returns 0 if s isn't a number
uint parseNum(const(char)[] s)
{
    while (s.length && s[0] == ' ')
        s = s[1 .. $];
    uint res;
    while (s.length && s[0] >= '0' && s[0] <= '9')
    {
        res = 10 * res + s[0] - '0';
        s = s[1 .. $];
    }
    return res;
}

const(char)[] parseContent(const(char)[] s)
{
    while (s.length && s[0] != '|')
        s = s[1 .. $];
    return s[1 .. $];
}

bool lstEquals(char[][] sourceLines, char[][] lstLines)
{
    if (sourceLines.length != lstLines.length - 1U)
        return false;

    foreach (i, line; sourceLines)
    {
        auto content = parseContent(lstLines[i]);
        // length mismatch
        if (line.length != content.length) return false;

        // char content mismatch
        foreach (j, c; content)
            if (line[j] != c) return false;
    }

    return true;
}

unittest
{
    char[][] src = cast(char[][])[ "12345", " | 12345, asasd", "|", ".;" ];
    char[][] lst = cast(char[][])[ "       |12345", "       | | 12345, asasd", "      1||", "0000000|.;", "" ];
    char[][] badLst = cast(char[][])[ "       |12344", "       | | 12345, asasd", "      1||", "0000000|.;", "" ];
    assert(lstEquals(src, lst));
    assert(!lstEquals(src, []));
    assert(!lstEquals(src, badLst));
}

shared static this()
{
    config.initialize();
}

shared static ~this()
{
    if (!gdata.length || config.disable) return;

    const NUMLINES = 16384 - 1;
    const NUMCHARS = 16384 * 16 - 1;

    auto buf = new char[NUMCHARS];
    auto lines = new char[][NUMLINES];
    auto lstLines = new char[][NUMLINES];

    foreach (c; gdata)
    {
        auto fname = appendFN(config.dstpath, addExt(baseName(c.filename), "lst"));
        auto flst = openOrCreateFile(fname);
        if (flst is null)
            continue;
        lockFile(fileno(flst)); // gets unlocked by fclose
        scope(exit) fclose(flst);

        if (!readFile(appendFN(config.srcpath, c.filename), buf))
            continue;
        splitLines(buf, lines);

        // Calculate the minimum line length between the source file and c.data
        auto minLineLength = min(c.data.length, lines.length);

        foreach (i; 0 .. minLineLength)
            lines[i] = expandTabs(lines[i]);

        auto buf2 = new char[NUMCHARS];
        if (config.merge && readFile(flst, buf2))
        {
            splitLines(buf2, lstLines);

            // check if source is the same before merge
            if (lstEquals(lines, lstLines))
                foreach (i, line; lstLines[0 .. min($, c.data.length)])
                    c.data[i] += parseNum(line);
        }

        // Calculate the maximum number of digits in the line with the greatest
        // number of calls.
        uint maxCallCount;
        foreach (n; c.data[0 .. minLineLength])
            maxCallCount = max(maxCallCount, n);

        // Make sure that there are a minimum of seven columns in each file so
        // that unless there are a very large number of calls, the columns in
        // each files lineup.
        immutable maxDigits = max(7, digits(maxCallCount));

        uint nno;
        uint nyes;

        // rewind for overwriting
        fseek(flst, 0, SEEK_SET);

        foreach (i, n; c.data[0 .. minLineLength])
        {
            auto line = lines[i];

            if (n == 0)
            {
                if (c.valid[i])
                {
                    ++nno;
                    fprintf(flst, "%0*u|%.*s\n", maxDigits, 0, cast(int)line.length, line.ptr);
                }
                else
                {
                    fprintf(flst, "%*s|%.*s\n", maxDigits, " ".ptr, cast(int)line.length, line.ptr);
                }
            }
            else
            {
                ++nyes;
                fprintf(flst, "%*u|%.*s\n", maxDigits, n, cast(int)line.length, line.ptr);
            }
        }

        if (nyes + nno) // no divide by 0 bugs
        {
            uint percent = ( nyes * 100 ) / ( nyes + nno );
            fprintf(flst, "%.*s is %d%% covered\n", cast(int)c.filename.length, c.filename.ptr, percent);
            if (percent < c.minPercent)
            {
                fprintf(stderr, "Error: %.*s is %d%% covered, less than required %d%%\n",
                    cast(int)c.filename.length, c.filename.ptr, percent, c.minPercent);
                exit(EXIT_FAILURE);
            }
        }
        else
        {
            fprintf(flst, "%.*s has no code\n", cast(int)c.filename.length, c.filename.ptr);
        }

        version (Windows)
            SetEndOfFile(handle(fileno(flst)));
        else version (Posix)
            ftruncate(fileno(flst), ftell(flst));
    }
}

uint digits(uint number)
{
    import core.stdc.math : floor, log10;
    return number ? cast(uint)floor(log10(number)) + 1 : 1;
}

unittest
{
    static void testDigits(uint num, uint dgts)
    {
        assert(digits(num) == dgts);
        assert(digits(num - 1) == dgts - 1);
        assert(digits(num + 1) == dgts);
    }
    assert(digits(0) == 1);
    assert(digits(1) == 1);
    testDigits(10, 2);
    testDigits(1_000, 4);
    testDigits(1_000_000, 7);
    testDigits(1_000_000_000, 10);
}

string appendFN( string path, string name )
{
    if (!path.length) return name;

    version (Windows)
        const char sep = '\\';
    else version (Posix)
        const char sep = '/';

    auto dest = path;

    if ( dest.length && dest[$ - 1] != sep )
        dest ~= sep;
    dest ~= name;
    return dest;
}


string baseName( string name, string ext = null )
{
    string ret;
    foreach (c; name)
    {
        switch (c)
        {
        case ':':
        case '\\':
        case '/':
            ret ~= '-';
            break;
        default:
            ret ~= c;
        }
    }
    return ext.length ? chomp(ret,  ext) : ret;
}


string getExt( string name )
{
    auto i = name.length;

    while ( i > 0 )
    {
        if ( name[i - 1] == '.' )
            return name[i .. $];
        --i;
        version (Windows)
        {
            if ( name[i] == ':' || name[i] == '\\' )
                break;
        }
        else version (Posix)
        {
            if ( name[i] == '/' )
                break;
        }
    }
    return null;
}


string addExt( string name, string ext )
{
    auto  existing = getExt( name );

    if ( existing.length == 0 )
    {
        if ( name.length && name[$ - 1] == '.' )
            name ~= ext;
        else
            name = name ~ "." ~ ext;
    }
    else
    {
        name = name[0 .. $ - existing.length] ~ ext;
    }
    return name;
}


string chomp( string str, string delim = null )
{
    if ( delim is null )
    {
        auto len = str.length;

        if ( len )
        {
            auto c = str[len - 1];

            if ( c == '\r' )
                --len;
            else if ( c == '\n' && str[--len - 1] == '\r' )
                --len;
        }
        return str[0 .. len];
    }
    else if ( str.length >= delim.length )
    {
        if ( str[$ - delim.length .. $] == delim )
            return str[0 .. $ - delim.length];
    }
    return str;
}

// open/create file for read/write, pointer at beginning
FILE* openOrCreateFile(string name)
{
    version (Windows)
        immutable fd = _wopen(toUTF16z(name), _O_RDWR | _O_CREAT | _O_BINARY, _S_IREAD | _S_IWRITE);
    else version (Posix)
        immutable fd = open((name ~ '\0').ptr, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP |
                S_IROTH | S_IWOTH);
    version (CRuntime_Microsoft)
        alias fdopen = _fdopen;
    else version (Posix)
        import core.sys.posix.stdio : fdopen;
    return fdopen(fd, "r+b");
}

version (Windows) HANDLE handle(int fd)
{
    return cast(HANDLE)_get_osfhandle(fd);
}

void lockFile(int fd)
{
    version (CRuntime_Bionic)
    {
        import core.sys.bionic.fcntl : LOCK_EX;
        import core.sys.bionic.unistd : flock;
        flock(fd, LOCK_EX); // exclusive lock
    }
    else version (Posix)
    {
        import core.sys.posix.unistd : F_LOCK, lockf;
        lockf(fd, F_LOCK, 0); // exclusive lock
    }
    else version (Windows)
    {
        OVERLAPPED off;
        // exclusively lock first byte
        LockFileEx(handle(fd), LOCKFILE_EXCLUSIVE_LOCK, 0, 1, 0, &off);
    }
}

bool readFile(FILE* file, ref char[] buf)
{
    if (fseek(file, 0, SEEK_END) != 0)
        assert(0, "fseek failed");
    immutable len = ftell(file);
    if (len == -1)
        assert(0, "ftell failed");
    else if (len == 0)
        return false;

    buf.length = len;
    fseek(file, 0, SEEK_SET);
    if (fread(buf.ptr, 1, buf.length, file) != buf.length)
        assert(0, "fread failed");
    if (fgetc(file) != EOF)
        assert(0, "EOF not reached");
    return true;
}

version (Windows) extern (C) nothrow @nogc FILE* _wfopen(scope const wchar* filename, scope const wchar* mode);


bool readFile(string name, ref char[] buf)
{
    version (Windows)
        auto file = _wfopen(toUTF16z(name), "rb"w.ptr);
    else version (Posix)
        auto file = fopen((name ~ '\0').ptr, "rb".ptr);
    if (file is null) return false;
    scope(exit) fclose(file);
    return readFile(file, buf);
}

void splitLines( char[] buf, ref char[][] lines )
{
    size_t  beg = 0,
            pos = 0;

    lines.length = 0;
    for ( ; pos < buf.length; ++pos )
    {
        char c = buf[pos];

        switch ( buf[pos] )
        {
        case '\r':
        case '\n':
            lines ~= buf[beg .. pos];
            beg = pos + 1;
            if ( buf[pos] == '\r' && pos < buf.length - 1 && buf[pos + 1] == '\n' )
            {
                ++pos; ++beg;
            }
            continue;
        default:
            continue;
        }
    }
    if ( beg != pos )
    {
        lines ~= buf[beg .. pos];
    }
}


char[] expandTabs( char[] str, int tabsize = 8 )
{
    const dchar LS = '\u2028'; // UTF line separator
    const dchar PS = '\u2029'; // UTF paragraph separator

    bool changes = false;
    char[] result = str;
    int column;
    int nspaces;

    foreach ( size_t i, dchar c; str )
    {
        switch ( c )
        {
            case '\t':
                nspaces = tabsize - (column % tabsize);
                if ( !changes )
                {
                    changes = true;
                    result = null;
                    result.length = str.length + nspaces - 1;
                    result.length = i + nspaces;
                    result[0 .. i] = str[0 .. i];
                    result[i .. i + nspaces] = ' ';
                }
                else
                {   auto j = result.length;
                    result.length = j + nspaces;
                    result[j .. j + nspaces] = ' ';
                }
                column += nspaces;
                break;

            case '\r':
            case '\n':
            case PS:
            case LS:
                column = 0;
                goto L1;

            default:
                column++;
            L1:
                if (changes)
                {
                    if (c <= 0x7F)
                        result ~= cast(char)c;
                    else
                    {
                        dchar[1] ca = c;
                        foreach (char ch; ca[])
                            result ~= ch;
                    }
                }
                break;
        }
    }
    return result;
}

/**
 * Implementation of code coverage analyzer.
 *
 * Copyright: Copyright Digital Mars 1995 - 2015.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Walter Bright, Sean Kelly
 * Source: $(DRUNTIMESRC src/rt/_cover.d)
 */

module rt.cover;

private
{
    version( Windows )
        import core.sys.windows.windows;
    else version( Posix )
    {
        import core.sys.posix.fcntl;
        import core.sys.posix.unistd;
    }
    import core.stdc.stdio;
    import core.stdc.stdlib;
    import rt.util.utf;

    struct BitArray
    {
        size_t  len;
        size_t* ptr;

        bool opIndex( size_t i )
        in
        {
            assert( i < len );
        }
        body
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
        string  srcpath;
        string  dstpath;
        bool    merge;
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
    srcpath = pathname;
}


/**
 * Set path to where listing files are to be written.
 *
 * Params:
 *  pathname = The new path name.
 */
extern (C) void dmd_coverDestPath( string pathname )
{
    dstpath = pathname;
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
    merge = flag;
}


/**
 * The coverage callback.
 *
 * Params:
 *  filename = The name of the coverage file.
 *  valid    = ???
 *  data     = ???
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

shared static ~this()
{
    if (!gdata.length) return;

    const NUMLINES = 16384 - 1;
    const NUMCHARS = 16384 * 16 - 1;

    char[]      srcbuf      = new char[NUMCHARS];
    char[][]    srclines    = new char[][NUMLINES];
    char[]      lstbuf      = new char[NUMCHARS];
    char[][]    lstlines    = new char[][NUMLINES];

    foreach( Cover c; gdata )
    {
        if( !readFile( appendFN( srcpath, c.filename ), srcbuf ) )
            continue;
        splitLines( srcbuf, srclines );

        if( merge )
        {
            if( !readFile( appendFN(dstpath, addExt( baseName( c.filename ), "lst" )), lstbuf ) )
                break;
            splitLines( lstbuf, lstlines );

            for( size_t i = 0; i < lstlines.length; ++i )
            {
                if( i >= c.data.length )
                    break;

                int count = 0;

                foreach( char c2; lstlines[i] )
                {
                    switch( c2 )
                    {
                    case ' ':
                        continue;
                    case '0': case '1': case '2': case '3': case '4':
                    case '5': case '6': case '7': case '8': case '9':
                        count = count * 10 + c2 - '0';
                        continue;
                    default:
                        break;
                    }
                }
                c.data[i] += count;
            }
        }

        FILE* flst = fopen( appendFN(dstpath, (addExt(baseName( c.filename ), "lst\0" ))).ptr, "wb" );

        if( !flst )
            continue; //throw new Exception( "Error opening file for write: " ~ lstfn );

        // Calculate the maximum number of digits in the line with the greatest
        // number of calls.
        uint maxCallCount = 0;
        foreach (i; 0..c.data.length)
        {
            if ( i < srclines.length )
            {
                const uint lineCallCount = c.data[i];
                if (maxCallCount < lineCallCount)
                    maxCallCount = lineCallCount;
            }
        }

        // Make sure that there are a minimum of seven columns in each file so
        // that unless there are a very large number of calls, the columns in
        // each files lineup.
        uint maxDigits = digits(maxCallCount);
        if (maxDigits < 7)
            maxDigits = 7;

        uint nno;
        uint nyes;

        foreach (i; 0..c.data.length)
        {
            if( i < srclines.length )
            {
                uint    n    = c.data[i];
                char[]  line = srclines[i];

                line = expandTabs( line );

                if( n == 0 )
                {
                    if( c.valid[i] )
                    {
                        nno++;
                        fprintf( flst, "%0*u|%.*s\n", maxDigits, 0, cast(int)line.length, line.ptr );
                    }
                    else
                    {
                        fprintf( flst, "%*s|%.*s\n", maxDigits, " ".ptr, cast(int)line.length, line.ptr );
                    }
                }
                else
                {
                    nyes++;
                    fprintf( flst, "%*u|%.*s\n", maxDigits, n, cast(int)line.length, line.ptr );
                }
            }
        }
        if( nyes + nno ) // no divide by 0 bugs
        {
            uint percent = ( nyes * 100 ) / ( nyes + nno );
            fprintf( flst, "%.*s is %d%% covered\n", cast(int)c.filename.length, c.filename.ptr, percent );
            if (percent < c.minPercent)
            {
                fclose(flst);
                fprintf(stderr, "Error: %.*s is %d%% covered, less than required %d%%\n",
                    cast(int)c.filename.length, c.filename.ptr, percent, c.minPercent);
                exit(EXIT_FAILURE);
            }
        }
        fclose( flst );
    }
}

uint digits( uint number )
{
    if (number < 10)
        return 1;

    return digits(number / 10) + 1;
}

string appendFN( string path, string name )
{
    if (!path.length) return name;

    version( Windows )
        const char sep = '\\';
    else version( Posix )
        const char sep = '/';

    auto dest = path;

    if( dest.length && dest[$ - 1] != sep )
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

    while( i > 0 )
    {
        if( name[i - 1] == '.' )
            return name[i .. $];
        --i;
        version( Windows )
        {
            if( name[i] == ':' || name[i] == '\\' )
                break;
        }
        else version( Posix )
        {
            if( name[i] == '/' )
                break;
        }
    }
    return null;
}


string addExt( string name, string ext )
{
    auto  existing = getExt( name );

    if( existing.length == 0 )
    {
        if( name.length && name[$ - 1] == '.' )
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
    if( delim is null )
    {
        auto len = str.length;

        if( len )
        {
            auto c = str[len - 1];

            if( c == '\r' )
                --len;
            else if( c == '\n' && str[--len - 1] == '\r' )
                --len;
        }
        return str[0 .. len];
    }
    else if( str.length >= delim.length )
    {
        if( str[$ - delim.length .. $] == delim )
            return str[0 .. $ - delim.length];
    }
    return str;
}


bool readFile( string name, ref char[] buf )
{
    version( Windows )
    {
        auto    wnamez  = toUTF16z( name );
        HANDLE  file    = CreateFileW( wnamez,
                                       GENERIC_READ,
                                       FILE_SHARE_READ,
                                       null,
                                       OPEN_EXISTING,
                                       FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,
                                       cast(HANDLE) null );

        if( file == INVALID_HANDLE_VALUE )
            return false;
        scope( exit ) CloseHandle( file );

        DWORD   num = 0;
        DWORD   pos = 0;

        buf.length = 4096;
        while( true )
        {
            if( !ReadFile( file, &buf[pos], cast(DWORD)( buf.length - pos ), &num, null ) )
                return false;
            if( !num )
                break;
            pos += num;
            buf.length = pos * 2;
        }
        buf.length = pos;
        return true;
    }
    else version( Posix )
    {
        char[]  namez = new char[name.length + 1];
                        namez[0 .. name.length] = name[];
                        namez[$ - 1] = 0;
        int     file = open( namez.ptr, O_RDONLY );

        if( file == -1 )
            return false;
        scope( exit ) close( file );

        uint pos = 0;

        buf.length = 4096;
        while( true )
        {
            auto num = read( file, &buf[pos], cast(uint)( buf.length - pos ) );
            if( num == -1 )
                return false;
            if( !num )
                break;
            pos += num;
            buf.length = pos * 2;
        }
        buf.length = pos;
        return true;
    }
}


void splitLines( char[] buf, ref char[][] lines )
{
    size_t  beg = 0,
            pos = 0;

    lines.length = 0;
    for( ; pos < buf.length; ++pos )
    {
        char c = buf[pos];

        switch( buf[pos] )
        {
        case '\r':
        case '\n':
            lines ~= buf[beg .. pos];
            beg = pos + 1;
            if( buf[pos] == '\r' && pos < buf.length - 1 && buf[pos + 1] == '\n' )
            {
                ++pos; ++beg;
            }
            continue;
        default:
            continue;
        }
    }
    if( beg != pos )
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

    foreach( size_t i, dchar c; str )
    {
        switch( c )
        {
            case '\t':
                nspaces = tabsize - (column % tabsize);
                if( !changes )
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

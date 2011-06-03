/**
 * Implementation of code coverage analyzer.
 *
 * Copyright: Copyright Digital Mars 2000 - 2010.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright, Sean Kelly
 */

/*          Copyright Digital Mars 2000 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
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
    import core.bitop;
    import core.stdc.stdio;
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
            return cast(bool) bt( ptr, i );
        }
    }

    struct Cover
    {
        string      filename;
        BitArray    valid;
        uint[]      data;
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
extern (C) void _d_cover_register( string filename, BitArray valid, uint[] data )
{
    Cover c;

    c.filename  = filename;
    c.valid     = valid;
    c.data      = data;
    gdata      ~= c;
}


shared static ~this()
{
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

        uint nno;
        uint nyes;

        for( int i = 0; i < c.data.length; i++ )
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
                        fprintf( flst, "0000000|%.*s\n", line.length, line.ptr );
                    }
                    else
                    {
                        fprintf( flst, "       |%.*s\n", line.length, line.ptr );
                    }
                }
                else
                {
                    nyes++;
                    fprintf( flst, "%7u|%.*s\n", n, line.length, line.ptr );
                }
            }
        }
        if( nyes + nno ) // no divide by 0 bugs
        {
            fprintf( flst, "%.*s is %d%% covered\n", c.filename.length, c.filename.ptr, ( nyes * 100 ) / ( nyes + nno ) );
        }
        fclose( flst );
    }
}

string appendFN( string path, string name )
{
    if (!path.length) return name;

    version( Windows )
        const char sep = '\\';
    else
        const char sep = '/';

    auto dest = path;

    if( dest && dest[$ - 1] != sep )
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
    return chomp( ret, ext ? ext : "" );
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

        delete wnamez;
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
                        namez[0 .. name.length] = name;
                        namez[$ - 1] = 0;
        int     file = open( namez.ptr, O_RDONLY );

        delete namez;
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
                ++pos, ++beg;
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
                        encode(result, c);
                }
                break;
        }
    }
    return result;
}

/**
 * The demangle module converts mangled D symbols to a representation similar
 * to what would have existed in code.
 *
 * Copyright: Copyright Sean Kelly 2010 - 2010.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Sean Kelly
 */

/*          Copyright Sean Kelly 2010 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.demangle;


debug(trace) import core.stdc.stdio : printf;
debug(info) import core.stdc.stdio : printf;
import core.stdc.stdio : snprintf;
import core.stdc.string : memmove;
import core.stdc.stdlib : strtold;


private struct Demangle
{
    // NOTE: This implementation currently only works with mangled function
    //       names as they exist in an object file.  Type names mangled via
    //       the .mangleof property are effectively incomplete as far as the
    //       ABI is concerned and so are not considered to be mangled symbol
    //       names.

    // NOTE: This implementation builds the demangled buffer in place by
    //       writing data as it is decoded and then rearranging it later as
    //       needed.  In practice this results in very little data movement,
    //       and the performance cost is more than offset by the gain from
    //       not allocating dynamic memory to assemble the name piecemeal.
    //
    //       If the destination buffer is too small, parsing will restart
    //       with a larger buffer.  Since this generally means only one
    //       allocation during the course of a parsing run, this is still
    //       faster than assembling the result piecemeal.


    enum AddType { no, yes }


    this( const(char)[] buf_, char[] dst_ = null )
    {
        this( buf_, AddType.yes, dst_ );
    }


    this( const(char)[] buf_, AddType addType_, char[] dst_ = null )
    {
        buf     = buf_;
        addType = addType_;
        dst     = dst_;
    }


    enum minBufSize = 4000;


    const(char)[]   buf     = null;
    char[]          dst     = null;
    size_t          pos     = 0;
    size_t          len     = 0;
    AddType         addType = AddType.yes;


    static class ParseException : Exception
    {
        this( string msg )
        {
            super( msg );
        }
    }


    static class OverflowException : Exception
    {
        this( string msg )
        {
            super( msg );
        }
    }


    static void error( string msg = "Invalid symbol" )
    {
        //throw new ParseException( msg );
        debug(info) printf( "error: %.*s\n", cast(int) msg.length, msg.ptr );
        throw cast(ParseException) cast(void*) ParseException.classinfo.init;

    }


    static void overflow( string msg = "Buffer overflow" )
    {
        //throw new OverflowException( msg );
        debug(info) printf( "overflow: %.*s\n", cast(int) msg.length, msg.ptr );
        throw cast(OverflowException) cast(void*) OverflowException.classinfo.init;
    }


    //////////////////////////////////////////////////////////////////////////
    // Type Testing and Conversion
    //////////////////////////////////////////////////////////////////////////


    static bool isAlpha( char val )
    {
        return ('a' <= val && 'z' >= val) ||
               ('A' <= val && 'Z' >= val);
    }


    static bool isDigit( char val )
    {
        return '0' <= val && '9' >= val;
    }


    static bool isHexDigit( char val )
    {
        return ('0' <= val && '9' >= val) ||
               ('a' <= val && 'f' >= val) ||
               ('A' <= val && 'F' >= val);
    }


    static ubyte ascii2hex( char val )
    {
        switch( val )
        {
        case 'a': .. case 'f':
            return cast(ubyte)(val - 'a' + 10);
        case 'A': .. case 'F':
            return cast(ubyte)(val - 'A' + 10);
        case '0': .. case '9':
            return cast(ubyte)(val - '0');
        default:
            error();
            return 0;
        }
    }


    //////////////////////////////////////////////////////////////////////////
    // Data Output
    //////////////////////////////////////////////////////////////////////////


    static bool contains( const(char)[] a, const(char)[] b )
    {
        return a.length &&
               b.ptr >= a.ptr &&
               b.ptr + b.length <= a.ptr + a.length;
    }


    char[] shift( const(char)[] val )
    {
        void exch( size_t a, size_t b )
        {
            char t = dst[a];
            dst[a] = dst[b];
            dst[b] = t;
        }

        if( val.length )
        {
            assert( contains( dst[0 .. len], val ) );
            debug(info) printf( "shifting (%.*s)\n", cast(int) val.length, val.ptr );

            for( size_t n = 0; n < val.length; n++ )
            {
                for( auto v = val.ptr - dst.ptr; v + 1 < len; v++ )
                {
                    exch( v, v + 1 );
                }
            }
            return dst[len - val.length .. len];
        }
        return null;
    }


    char[] append( const(char)[] val )
    {
        if( val.length )
        {
            if( !dst.length )
                dst.length = minBufSize;
            assert( !contains( dst[0 .. len], val ) );
            debug(info) printf( "appending (%.*s)\n", cast(int) val.length, val.ptr );

            if( dst.ptr + len == val.ptr &&
                dst.length - len >= val.length )
            {
                // data is already in place
                auto t = dst[len .. len + val.length];
                len += val.length;
                return t;
            }
            if( dst.length - len >= val.length )
            {
                dst[len .. len + val.length] = val[];
                auto t = dst[len .. len + val.length];
                len += val.length;
                return t;
            }
            overflow();
        }
        return null;
    }


    char[] put( const(char)[] val )
    {
        if( val.length )
        {
            if( !contains( dst[0 .. len], val ) )
                return append( val );
            return shift( val );
        }
        return null;
    }


    char[] putAsHex( size_t val, int width = 0 )
    {
        char tmp[20];
        int  pos = tmp.length;

        while( val )
        {
            int  digit = val % 16;

            tmp[--pos] = digit < 10 ? cast(char)(digit + '0') :
                                      cast(char)((digit - 10) + 'a');
            val /= 16;
            width--;
        }
        for( ; width > 0; width-- )
            tmp[--pos] = '0';
        return put( tmp[pos .. $] );
    }


    void pad( const(char)[] val )
    {
        if( val.length )
        {
            append( " " );
            put( val );
        }
    }


    void silent( lazy void dg )
    {
        debug(trace) printf( "silent+\n" );
        debug(trace) scope(success) printf( "silent-\n" );
        auto n = len; dg(); len = n;
    }


    //////////////////////////////////////////////////////////////////////////
    // Parsing Utility
    //////////////////////////////////////////////////////////////////////////


    char tok()
    {
        if( pos < buf.length )
            return buf[pos];
        return char.init;
    }


    void test( char val )
    {
        if( val != tok() )
            error();
    }


    void next()
    {
        if( pos++ >= buf.length )
            error();
    }


    void match( char val )
    {
        test( val );
        next();
    }


    void match( const(char)[] val )
    {
        foreach( e; val )
        {
            test( e );
            next();
        }
    }


    void eat( char val )
    {
        if( val == tok() )
            next();
    }


    //////////////////////////////////////////////////////////////////////////
    // Parsing Implementation
    //////////////////////////////////////////////////////////////////////////


    /*
    Number:
        Digit
        Digit Number
    */
    const(char)[] sliceNumber()
    {
        debug(trace) printf( "sliceNumber+\n" );
        debug(trace) scope(success) printf( "sliceNumber-\n" );

        auto beg = pos;

        while( true )
        {
            switch( tok() )
            {
            case '0': .. case '9':
                next();
                continue;
            default:
                return buf[beg .. pos];
            }
        }
    }


    size_t decodeNumber()
    {
        debug(trace) printf( "decodeNumber+\n" );
        debug(trace) scope(success) printf( "decodeNumber-\n" );

        return decodeNumber( sliceNumber() );
    }


    size_t decodeNumber( const(char)[] num )
    {
        debug(trace) printf( "decodeNumber+\n" );
        debug(trace) scope(success) printf( "decodeNumber-\n" );

        size_t val = 0;

        foreach( i, e; num )
        {
            size_t n = e - '0';
            if( val > (val.max - n) / 10 )
                error();
            val = val * 10 + n;
        }
        return val;
    }


    void parseReal()
    {
        debug(trace) printf( "parseReal+\n" );
        debug(trace) scope(success) printf( "parseReal-\n" );

        char[64] tbuf = void;
        size_t   tlen = 0;
        real     val  = void;

        if( 'I' == tok() )
        {
            match( "INF" );
            put( "real.infinity" );
            return;
        }
        if( 'N' == tok() )
        {
            next();
            if( 'I' == tok() )
            {
                match( "INF" );
                put( "-real.infinity" );
                return;
            }
            if( 'A' == tok() )
            {
                match( "AN" );
                put( "real.nan" );
                return;
            }
            tbuf[tlen++] = '-';
        }

        tbuf[tlen++] = '0';
        tbuf[tlen++] = 'X';
        if( !isHexDigit( tok() ) )
            error( "Expected hex digit" );
        tbuf[tlen++] = tok();
        tbuf[tlen++] = '.';
        next();

        while( isHexDigit( tok() ) )
        {
            tbuf[tlen++] = tok();
            next();
        }
        match( 'P' );
        tbuf[tlen++] = 'p';
        if( 'N' == tok() )
        {
            tbuf[tlen++] = '-';
            next();
        }
        else
        {
            tbuf[tlen++] = '+';
        }
        while( isDigit( tok() ) )
        {
            tbuf[tlen++] = tok();
            next();
        }

        tbuf[tlen] = 0;
        debug(info) printf( "got (%s)\n", tbuf.ptr );
        val = strtold( tbuf.ptr, null );
        tlen = snprintf( tbuf.ptr, tbuf.length, "%#Lg", val );
        debug(info) printf( "converted (%.*s)\n", cast(int) tlen, tbuf.ptr );
        put( tbuf[0 .. tlen] );
    }


    /*
    LName:
        Number Name

    Name:
        Namestart
        Namestart Namechars

    Namestart:
        _
        Alpha

    Namechar:
        Namestart
        Digit

    Namechars:
        Namechar
        Namechar Namechars
    */
    void parseLName()
    {
        debug(trace) printf( "parseLName+\n" );
        debug(trace) scope(success) printf( "parseLName-\n" );

        auto n = decodeNumber();

        if( !n || n > buf.length || n > buf.length - pos )
            error( "LName must be at least 1 character" );
        if( '_' != tok() && !isAlpha( tok() ) )
            error( "Invalid character in LName" );
        foreach( e; buf[pos + 1 .. pos + n] )
        {
            if( '_' != e && !isAlpha( e ) && !isDigit( e ) )
                error( "Invalid character in LName" );
        }

        put( buf[pos .. pos + n] );
        pos += n;
    }


    /*
    Type:
        Shared
        Const
        Immutable
        Wild
        TypeArray
        TypeNewArray
        TypeStaticArray
        TypeAssocArray
        TypePointer
        TypeFunction
        TypeIdent
        TypeClass
        TypeStruct
        TypeEnum
        TypeTypedef
        TypeDelegate
        TypeNone
        TypeVoid
        TypeByte
        TypeUbyte
        TypeShort
        TypeUshort
        TypeInt
        TypeUint
        TypeLong
        TypeUlong
        TypeFloat
        TypeDouble
        TypeReal
        TypeIfloat
        TypeIdouble
        TypeIreal
        TypeCfloat
        TypeCdouble
        TypeCreal
        TypeBool
        TypeChar
        TypeWchar
        TypeDchar
        TypeTuple

    Shared:
        O Type

    Const:
        x Type

    Immutable:
        y Type

    Wild:
        Ng Type

    TypeArray:
        A Type

    TypeNewArray:
        Ne Type

    TypeStaticArray:
        G Number Type

    TypeAssocArray:
        H Type Type

    TypePointer:
        P Type

    TypeFunction:
        CallConvention FuncAttrs Arguments ArgClose Type

    TypeIdent:
        I LName

    TypeClass:
        C LName

    TypeStruct:
        S LName

    TypeEnum:
        E LName

    TypeTypedef:
        T LName

    TypeDelegate:
        D TypeFunction

    TypeNone:
        n

    TypeVoid:
        v

    TypeByte:
        g

    TypeUbyte:
        h

    TypeShort:
        s

    TypeUshort:
        t

    TypeInt:
        i

    TypeUint:
        k

    TypeLong:
        l

    TypeUlong:
        m

    TypeFloat:
        f

    TypeDouble:
        d

    TypeReal:
        e

    TypeIfloat:
        o

    TypeIdouble:
        p

    TypeIreal:
        j

    TypeCfloat:
        q

    TypeCdouble:
        r

    TypeCreal:
        c

    TypeBool:
        b

    TypeChar:
        a

    TypeWchar:
        u

    TypeDchar:
        w

    TypeTuple:
        B Number Arguments
    */
    char[] parseType( char[] name = null )
    {
        debug(trace) printf( "parseType+\n" );
        debug(trace) scope(success) printf( "parseType-\n" );
        auto beg = len;

        switch( tok() )
        {
        case 'O': // Shared (O Type)
            next();
            put( "shared(" );
            parseType();
            put( ")" );
            pad( name );
            return dst[beg .. len];
        case 'x': // Const (x Type)
            next();
            put( "const(" );
            parseType();
            put( ")" );
            pad( name );
            return dst[beg .. len];
        case 'y': // Immutable (y Type)
            next();
            put( "immutable(" );
            parseType();
            put( ")" );
            pad( name );
            return dst[beg .. len];
        case 'N':
            next();
            switch( tok() )
            {
            case 'g': // Wild (Ng Type)
                next();
                // TODO: Anything needed here?
                put( "inout(" );
                parseType();
                put( ")" );
                return dst[beg .. len];
            case 'e': // TypeNewArray (Ne Type)
                next();
                // TODO: Anything needed here?
                parseType();
                return dst[beg .. len];
            default:
                error();
                assert( 0 );
            }
        case 'A': // TypeArray (A Type)
            next();
            parseType();
            put( "[]" );
            pad( name );
            return dst[beg .. len];
        case 'G': // TypeStaticArray (G Number Type)
            next();
            auto num = sliceNumber();
            parseType();
            put( "[" );
            put( num );
            put( "]" );
            pad( name );
            return dst[beg .. len];
        case 'H': // TypeAssocArray (H Type Type)
            next();
            // skip t1
            auto t = parseType();
            parseType();
            put( "[" );
            put( t );
            put( "]" );
            pad( name );
            return dst[beg .. len];
        case 'P': // TypePointer (P Type)
            next();
            parseType();
            put( "*" );
            pad( name );
            return dst[beg .. len];
        case 'F': case 'U': case 'W': case 'V': case 'R': // TypeFunction
            return parseTypeFunction( name );
        case 'I': // TypeIdent (I LName)
        case 'C': // TypeClass (C LName)
        case 'S': // TypeStruct (S LName)
        case 'E': // TypeEnum (E LName)
        case 'T': // TypeTypedef (T LName)
            next();
            parseQualifiedName();
            pad( name );
            return dst[beg .. len];
        case 'D': // TypeDelegate (D TypeFunction)
            next();
            parseTypeFunction( name, IsDelegate.yes );
            return dst[beg .. len];
        case 'n': // TypeNone (n)
            next();
            // TODO: Anything needed here?
            return dst[beg .. len];
        case 'v': // TypeVoid (v)
            next();
            put( "void" );
            pad( name );
            return dst[beg .. len];
        case 'g': // TypeByte (g)
            next();
            put( "byte" );
            pad( name );
            return dst[beg .. len];
        case 'h': // TypeUbyte (h)
            next();
            put( "ubyte" );
            pad( name );
            return dst[beg .. len];
        case 's': // TypeShort (s)
            next();
            put( "short" );
            pad( name );
            return dst[beg .. len];
        case 't': // TypeUshort (t)
            next();
            put( "ushort" );
            pad( name );
            return dst[beg .. len];
        case 'i': // TypeInt (i)
            next();
            put( "int" );
            pad( name );
            return dst[beg .. len];
        case 'k': // TypeUint (k)
            next();
            put( "uint" );
            pad( name );
            return dst[beg .. len];
        case 'l': // TypeLong (l)
            next();
            put( "long" );
            pad( name );
            return dst[beg .. len];
        case 'm': // TypeUlong (m)
            next();
            put( "ulong" );
            pad( name );
            return dst[beg .. len];
        case 'f': // TypeFloat (f)
            next();
            put( "float" );
            pad( name );
            return dst[beg .. len];
        case 'd': // TypeDouble (d)
            next();
            put( "double" );
            pad( name );
            return dst[beg .. len];
        case 'e': // TypeReal (e)
            next();
            put( "real" );
            pad( name );
            return dst[beg .. len];
        case 'o': // TypeIfloat (o)
            next();
            put( "ifloat" );
            pad( name );
            return dst[beg .. len];
        case 'p': // TypeIdouble (p)
            next();
            put( "idouble" );
            pad( name );
            return dst[beg .. len];
        case 'j': // TypeIreal (j)
            next();
            put( "ireal" );
            pad( name );
            return dst[beg .. len];
        case 'q': // TypeCfloat (q)
            next();
            put( "cfloat" );
            pad( name );
            return dst[beg .. len];
        case 'r': // TypeCdouble (r)
            next();
            put( "cdouble" );
            pad( name );
            return dst[beg .. len];
        case 'c': // TypeCreal (c)
            next();
            put( "creal" );
            pad( name );
            return dst[beg .. len];
        case 'b': // TypeBool (b)
            next();
            put( "bool" );
            pad( name );
            return dst[beg .. len];
        case 'a': // TypeChar (a)
            next();
            put( "char" );
            pad( name );
            return dst[beg .. len];
        case 'u': // TypeWchar (u)
            next();
            put( "wchar" );
            pad( name );
            return dst[beg .. len];
        case 'w': // TypeDchar (w)
            next();
            put( "dchar" );
            pad( name );
            return dst[beg .. len];
        case 'B': // TypeTuple (B Number Arguments)
            next();
            // TODO: Handle this.
            return dst[beg .. len];
        default:
            error(); return null;
        }
    }


    /*
    TypeFunction:
        CallConvention FuncAttrs Arguments ArgClose Type

    CallConvention:
        F       // D
        U       // C
        W       // Windows
        V       // Pascal
        R       // C++

    FuncAttrs:
        FuncAttr
        FuncAttr FuncAttrs

    FuncAttr:
        empty
        FuncAttrPure
        FuncAttrNothrow
        FuncAttrProperty
        FuncAttrRef
        FuncAttrTrusted
        FuncAttrSafe

    FuncAttrPure:
        Na

    FuncAttrNothrow:
        Nb

    FuncAttrRef:
        Nc

    FuncAttrProperty:
        Nd

    FuncAttrTrusted:
        Ne

    FuncAttrSafe:
        Nf

    Arguments:
        Argument
        Argument Arguments

    Argument:
        Argument2
        M Argument2     // scope

    Argument2:
        Type
        J Type     // out
        K Type     // ref
        L Type     // lazy

    ArgClose
        X     // variadic T t,...) style
        Y     // variadic T t...) style
        Z     // not variadic
    */
    enum IsDelegate { no, yes }
    char[] parseTypeFunction( char[] name = null, IsDelegate isdg = IsDelegate.no )
    {
        debug(trace) printf( "parseTypeFunction+\n" );
        debug(trace) scope(success) printf( "parseTypeFunction-\n" );
        auto beg = len;

        // CallConvention
        switch( tok() )
        {
        case 'F': // D
            next();
            break;
        case 'U': // C
            next();
            put( "extern (C) " );
            break;
        case 'W': // Windows
            next();
            put( "extern (Windows) " );
            break;
        case 'V': // Pascal
            next();
            put( "extern (Pascal) " );
            break;
        case 'R': // C++
            next();
            put( "extern (C++) " );
            break;
        default:
            error();
        }

        // FuncAttrs
        breakFuncAttrs:
        while( 'N' == tok() )
        {
            next();
            switch( tok() )
            {
            case 'a': // FuncAttrPure
                next();
                put( "pure " );
                continue;
            case 'b': // FuncAttrNoThrow
                next();
                put( "nothrow " );
                continue;
            case 'c': // FuncAttrRef
                next();
                put( "ref " );
                continue;
            case 'd': // FuncAttrProperty
                next();
                put( "@property " );
                continue;
            case 'e': // FuncAttrTrusted
                next();
                put( "@trusted " );
                continue;
            case 'f': // FuncAttrSafe
                next();
                put( "@safe " );
                continue;
            case 'g':
                // NOTE: The inout parameter type is represented as "Ng",
                //       which makes it look like a FuncAttr.  So if we
                //       see an "Ng" FuncAttr we know we're really in
                //       the parameter list.  Rewind and break.
                pos--;
                break breakFuncAttrs;
            default:
                error();
            }
        }

        beg = len;
        put( "(" );
        scope(success)
        {
            put( ")" );
            auto t = len;
            parseType();
            put( " " );
            if( name.length )
            {
                if( !contains( dst[0 .. len], name ) )
                    put( name );
                else if( shift( name ).ptr != name.ptr )
                {
                    beg -= name.length;
                    t -= name.length;
                }
            }
            else if( IsDelegate.yes == isdg )
                put( "delegate" );
            else
                put( "function" );
            shift( dst[beg .. t] );
        }

        // Arguments
        for( size_t n = 0; true; n++ )
        {
            debug(info) printf( "tok (%c)\n", tok() );
            switch( tok() )
            {
            case 'X': // ArgClose (variadic T t...) style)
                next();
                put( "..." );
                return dst[beg .. len];
            case 'Y': // ArgClose (variadic T t,...) style)
                next();
                put( ", ..." );
                return dst[beg .. len];
            case 'Z': // ArgClose (not variadic)
                next();
                return dst[beg .. len];
            default:
                break;
            }
            if( n )
            {
                put( ", " );
            }
            if( 'M' == tok() )
            {
                next();
                put( "scope " );
            }
            switch( tok() )
            {
            case 'J': // out (J Type)
                next();
                put( "out " );
                parseType();
                continue;
            case 'K': // ref (K Type)
                next();
                put( "ref " );
                parseType();
                continue;
            case 'L': // lazy (L Type)
                next();
                put( "lazy " );
                parseType();
                continue;
            default:
                parseType();
            }
        }
    }


    /*
    Value:
        n
        Number
        i Number
        N Number
        e HexFloat
        c HexFloat c HexFloat
        A Number Value...

    HexFloat:
        NAN
        INF
        NINF
        N HexDigits P Exponent
        HexDigits P Exponent

    Exponent:
        N Number
        Number

    HexDigits:
        HexDigit
        HexDigit HexDigits

    HexDigit:
        Digit
        A
        B
        C
        D
        E
        F
    */
    void parseValue( char[] name = null, char type = '\0' )
    {
        debug(trace) printf( "parseValue+\n" );
        debug(trace) scope(success) printf( "parseValue-\n" );

//        printf( "*** %c\n", tok() );
        switch( tok() )
        {
        case 'n':
            next();
            put( "null" );
            return;
        case 'i':
            next();
            if( '0' > tok() || '9' < tok() )
                error( "Number expected" );
            // fall-through intentional
        case '0': .. case '9':
            parseIntegerValue( name, type );
            return;
        case 'N':
            next();
            put( "-" );
            parseIntegerValue( name, type );
            return;
        case 'e':
            next();
            parseReal();
            return;
        case 'c':
            next();
            parseReal();
            put( "+" );
            match( 'c' );
            parseReal();
            put( "i" );
            return;
        case 'a': case 'w': case 'd':
            char t = tok();
            next();
            auto n = decodeNumber();
            match( '_' );
            put( "\"" );
            for( auto i = 0; i < n; i++ )
            {
                auto a = ascii2hex( tok() ); next();
                auto b = ascii2hex( tok() ); next();
                auto v = cast(char)((a << 4) | b);
                put( (cast(char*) &v)[0 .. 1] );
            }
            put( "\"" );
            if( 'a' != t )
                put( (cast(char*) &t)[0 .. 1] );
            return;
        case 'A':
            // NOTE: This is kind of a hack.  An associative array literal
            //       [1:2, 3:4] is represented as HiiA2i1i2i3i4, so the type
            //       is "Hii" and the value is "A2i1i2i3i4".  Thus the only
            //       way to determine that this is an AA value rather than an
            //       array value is for the caller to supply the type char.
            //       Hopefully, this will change so that the value is
            //       "H2i1i2i3i4", rendering this unnecesary.
            if( 'H' == type )
                goto LassocArray;
            // A Number Value...
            // An array literal. Value is repeated Number times.
            next();
            put( "[" );
            auto n = decodeNumber();
            foreach( i; 0 .. n )
            {
                if( i != 0 )
                    put( ", " );
                parseValue();
            }
            put( "]" );
            return;
        case 'H':
        LassocArray:
            // H Number Value...
            // An associative array literal. Value is repeated 2*Number times.
            next();
            put( "[" );
            auto n = decodeNumber();
            foreach( i; 0 .. n )
            {
                if( i != 0 )
                    put( ", " );
                parseValue();
                put(":");
                parseValue();
            }
            put( "]" );
            return;
        case 'S':
            // S Number Value...
            // A struct literal. Value is repeated Number times.
            next();
            if( name.length )
                put( name );
            put( "(" );
            auto n = decodeNumber();
            foreach( i; 0 .. n )
            {
                if( i != 0 )
                    put( ", " );
                parseValue();
            }
            put( ")" );
            return;
        default:
            error();
        }
    }


    void parseIntegerValue( char[] name = null, char type = '\0' )
    {
        debug(trace) printf( "parseIntegerValue+\n" );
        debug(trace) scope(success) printf( "parseIntegerValue-\n" );

        switch( type )
        {
        case 'a': // char
        case 'u': // wchar
        case 'w': // dchar
        {
            auto val = sliceNumber();
            auto num = decodeNumber( val );

            switch( num )
            {
            case '\'':
                put( "'\\''" );
                return;
            // \", \?
            case '\\':
                put( "'\\\\'" );
                return;
            case '\a':
                put( "'\\a'" );
                return;
            case '\b':
                put( "'\\b'" );
                return;
            case '\f':
                put( "'\\f'" );
                return;
            case '\n':
                put( "'\\n'" );
                return;
            case '\r':
                put( "'\\r'" );
                return;
            case '\t':
                put( "'\\t'" );
                return;
            case '\v':
                put( "'\\v'" );
                return;
            default:
                switch( type )
                {
                case 'a':
                    if( num >= 0x20 && num < 0x7F )
                    {
                        put( "'" );
                        put( (cast(char*) &num)[0 .. 1] );
                        put( "'" );
                        return;
                    }
                    put( "\\x" );
                    putAsHex( num, 2 );
                    return;
                case 'u':
                    put( "'\\u" );
                    putAsHex( num, 4 );
                    put( "'" );
                    return;
                case 'w':
                    put( "'\\U" );
                    putAsHex( num, 8 );
                    put( "'" );
                    return;
                default:
                    assert( 0 );
                }
            }
        }
        case 'b': // bool
            put( decodeNumber() ? "true" : "false" );
            return;
        case 'h', 't', 'k': // ubyte, ushort, uint
            put( sliceNumber() );
            put( "u" );
            return;
        case 'l': // long
            put( sliceNumber() );
            put( "L" );
            return;
        case 'm': // ulong
            put( sliceNumber() );
            put( "uL" );
            return;
        default:
            put( sliceNumber() );
            return;
        }
    }


    /*
    TemplateArgs:
        TemplateArg
        TemplateArg TemplateArgs

    TemplateArg:
        T Type
        V Type Value
        S LName
    */
    void parseTemplateArgs()
    {
        debug(trace) printf( "parseTemplateArgs+\n" );
        debug(trace) scope(success) printf( "parseTemplateArgs-\n" );

        for( size_t n = 0; true; n++ )
        {
            switch( tok() )
            {
            case 'T':
                next();
                if( n ) put( ", " );
                parseType();
                continue;
            case 'V':
                next();
                if( n ) put( ", " );
                // NOTE: In the few instances where the type is actually
                //       desired in the output it should precede the value
                //       generated by parseValue, so it is safe to simply
                //       decrement len and let put/append do its thing.
                char t = tok(); // peek at type for parseValue
                char[] name; silent( name = parseType() );
                parseValue( name, t );
                continue;
            case 'S':
                next();
                if( n ) put( ", " );
                parseQualifiedName();
                continue;
            default:
                return;
            }
        }
    }


    /*
    TemplateInstanceName:
        Number __T LName TemplateArgs Z
    */
    void parseTemplateInstanceName()
    {
        debug(trace) printf( "parseTemplateInstanceName+\n" );
        debug(trace) scope(success) printf( "parseTemplateInstanceName-\n" );

        auto sav = pos;
        scope(failure) pos = sav;
        auto n = decodeNumber();
        auto beg = pos;
        match( "__T" );
        parseLName();
        put( "!(" );
        parseTemplateArgs();
        match( 'Z' );
        if( pos - beg != n )
            error( "Template name length mismatch" );
        put( ")" );
    }


    bool mayBeTemplateInstanceName()
    {
        debug(trace) printf( "mayBeTemplateInstanceName+\n" );
        debug(trace) scope(success) printf( "mayBeTemplateInstanceName-\n" );

        auto p = pos;
        scope(exit) pos = p;
        auto n = decodeNumber();
        return n >= 5 &&
               pos < buf.length && '_' == buf[pos++] &&
               pos < buf.length && '_' == buf[pos++] &&
               pos < buf.length && 'T' == buf[pos++];
    }


    /*
    SymbolName:
        LName
        TemplateInstanceName
    */
    void parseSymbolName()
    {
        debug(trace) printf( "parseSymbolName+\n" );
        debug(trace) scope(success) printf( "parseSymbolName-\n" );

        // LName -> Number
        // TemplateInstanceName -> Number "__T"
        switch( tok() )
        {
        case '0': .. case '9':
            if( mayBeTemplateInstanceName() )
            {
                auto t = len;

                try
                {
                    debug(trace) printf( "may be template instance name\n" );
                    parseTemplateInstanceName();
                    return;
                }
                catch( ParseException e )
                {
                    debug(trace) printf( "not a template instance name\n" );
                    len = t;
                }
            }
            parseLName();
            return;
        default:
            error();
        }
    }


    /*
    QualifiedName:
        SymbolName
        SymbolName QualifiedName
    */
    char[] parseQualifiedName()
    {
        debug(trace) printf( "parseQualifiedName+\n" );
        debug(trace) scope(success) printf( "parseQualifiedName-\n" );
        size_t  beg = len;
        size_t  n   = 0;

        do
        {
            if( n++ )
                put( "." );
            parseSymbolName();
        } while( isDigit( tok() ) );
        return dst[beg .. len];
    }


    /*
    MangledName:
        _D QualifiedName Type
        _D QualifiedName M Type
    */
    void parseMangledName()
    {
        debug(trace) printf( "parseMangledName+\n" );
        debug(trace) scope(success) printf( "parseMangledName-\n" );
        char[] name = null;

        eat( '_' );
        match( 'D' );
        do
        {
            name = parseQualifiedName();
            debug(info) printf( "name (%.*s)\n", cast(int) name.length, name.ptr );
            if( 'M' == tok() )
                next(); // has 'this' pointer
            if( AddType.yes == addType )
                parseType( name );
            if( pos >= buf.length )
                return;
            put( "." );
        } while( true );
    }


    char[] opCall()
    {
        while( true )
        {
            try
            {
                debug(info) printf( "demangle(%.*s)\n", cast(int) buf.length, buf.ptr );
                parseMangledName();
                return dst[0 .. len];
            }
            catch( OverflowException e )
            {
                debug(trace) printf( "overflow... restarting\n" );
                auto a = minBufSize;
                auto b = 2 * dst.length;
                auto newsz = a < b ? b : a;
                debug(info) printf( "growing dst to %lu bytes\n", newsz );
                dst.length = newsz;
                pos = len = 0;
                continue;
            }
            catch( ParseException e )
            {
                debug(info)
                {
                    auto msg = e.toString;
                    printf( "error: %.*s\n", cast(int) msg.length, msg.ptr );
                }
                if( dst.length < buf.length )
                    dst.length = buf.length;
                dst[0 .. buf.length] = buf[];
                return dst[0 .. buf.length];
            }
        }
    }
}


/**
 * Demangles D mangled names.  If it is not a D mangled name, it returns its
 * argument name.
 *
 * Params:
 *  buf = The string to demangle.
 *  dst = An optional destination buffer.
 *
 * Returns:
 *  The demangled name or the original string if the name is not a mangled D
 *  name.
 */
char[] demangle( const(char)[] buf, char[] dst = null )
{
    //return Demangle(buf, dst)();
    auto d = Demangle(buf, dst);
    return d();
}


unittest
{
    static string[2][] table =
    [
        ["printf", "printf"],
        ["_foo", "_foo"],
        ["_D88", "_D88"],
        ["_D4test3fooAa", "char[] test.foo"],
        ["_D8demangle8demangleFAaZAa", "char[] demangle.demangle(char[])"],
        ["_D6object6Object8opEqualsFC6ObjectZi", "int object.Object.opEquals(Object)"],
        ["_D4test2dgDFiYd", "double test.dg(int, ...)"],
        //["_D4test58__T9factorialVde67666666666666860140VG5aa5_68656c6c6fVPvnZ9factorialf", ""],
        //["_D4test101__T9factorialVde67666666666666860140Vrc9a999999999999d9014000000000000000c00040VG5aa5_68656c6c6fVPvnZ9factorialf", ""],
        ["_D4test34__T3barVG3uw3_616263VG3wd3_646566Z1xi", "int test.bar!(\"abc\"w, \"def\"d).x"],
        ["_D8demangle4testFLC6ObjectLDFLiZiZi", "int demangle.test(lazy Object, lazy int delegate(lazy int))"],
        ["_D8demangle4testFAiXi", "int demangle.test(int[]...)"],
        ["_D8demangle4testFAiYi", "int demangle.test(int[], ...)"],
        ["_D8demangle4testFLAiXi", "int demangle.test(lazy int[]...)"],
        ["_D8demangle4testFLAiYi", "int demangle.test(lazy int[], ...)"],
        ["_D6plugin8generateFiiZAya", "immutable(char)[] plugin.generate(int, int)"],
        ["_D6plugin8generateFiiZAxa", "const(char)[] plugin.generate(int, int)"],
        ["_D6plugin8generateFiiZAOa", "shared(char)[] plugin.generate(int, int)"],
        ["_D8demangle3fnAFZv3fnBMFZv", "void demangle.fnA().void fnB()"],
        ["_D8demangle4mainFZv1S3fnCFZv", "void demangle.main().void S.fnC()"],
        ["_D8demangle4mainFZv1S3fnDMFZv", "void demangle.main().void S.fnD()"],
        ["_D8demangle20__T2fnVAiA4i1i2i3i4Z2fnFZv", "void demangle.fn!([1, 2, 3, 4]).fn()"],
        ["_D8demangle10__T2fnVi1Z2fnFZv", "void demangle.fn!(1).fn()"],
        ["_D8demangle26__T2fnVS8demangle1SS2i1i2Z2fnFZv", "void demangle.fn!(demangle.S(1, 2)).fn()"],
        ["_D8demangle13__T2fnVeeNANZ2fnFZv", "void demangle.fn!(real.nan).fn()"],
        ["_D8demangle14__T2fnVeeNINFZ2fnFZv", "void demangle.fn!(-real.infinity).fn()"],
        ["_D8demangle13__T2fnVeeINFZ2fnFZv", "void demangle.fn!(real.infinity).fn()"],
        ["_D8demangle21__T2fnVHiiA2i1i2i3i4Z2fnFZv", "void demangle.fn!([1:2, 3:4]).fn()"],
        ["_D8demangle2fnFNgiZNgi", "inout(int) demangle.fn(inout(int))"],
        ["_D8demangle29__T2fnVa97Va9Va0Vu257Vw65537Z2fnFZv", "void demangle.fn!('a', '\\t', \\x00, '\\u0101', '\\U00010001').fn()"]
    ];

    foreach( i, name; table )
    {
        auto r = demangle( name[0] );
        assert( r == name[1],
                "demangled \"" ~ name[0] ~ "\" as \"" ~ r ~ "\" but expected \"" ~ name[1] ~ "\"");
    }
}


/*
 *
 */
string decodeDmdString( const(char)[] ln, ref int p )
{
    string s;
    uint zlen, zpos;

    // decompress symbol
    while( p < ln.length )
    {
        int ch = cast(ubyte) ln[p++];
        if( (ch & 0xc0) == 0xc0 )
        {
            zlen = (ch & 0x7) + 1;
            zpos = ((ch >> 3) & 7) + 1; // + zlen;
            if( zpos > s.length )
                break;
            s ~= s[$ - zpos .. $ - zpos + zlen];
        }
        else if( ch >= 0x80 )
        {
            if( p >= ln.length )
                break;
            int ch2 = cast(ubyte) ln[p++];
            zlen = (ch2 & 0x7f) | ((ch & 0x38) << 4);
            if( p >= ln.length )
                break;
            int ch3 = cast(ubyte) ln[p++];
            zpos = (ch3 & 0x7f) | ((ch & 7) << 7);
            if( zpos > s.length )
                break;
            s ~= s[$ - zpos .. $ - zpos + zlen];
        }
        else if( Demangle.isAlpha(cast(char)ch) || Demangle.isDigit(cast(char)ch) || ch == '_' )
            s ~= cast(char) ch;
        else
        {
            p--;
            break;
        }
    }
    return s;
}

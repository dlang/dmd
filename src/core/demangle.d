/**
 * The demangle module converts mangled D symbols to a representation similar
 * to what would have existed in code.
 *
 * Copyright: Copyright Sean Kelly 2010 - 2014.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Sean Kelly
 * Source:    $(DRUNTIMESRC core/_demangle.d)
 */

module core.demangle;


debug(trace) import core.stdc.stdio : printf;
debug(info) import core.stdc.stdio : printf;

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


    enum size_t minBufSize = 4000;


    const(char)[]   buf     = null;
    char[]          dst     = null;
    size_t          pos     = 0;
    size_t          len     = 0;
    AddType         addType = AddType.yes;


    static class ParseException : Exception
    {
        @safe pure nothrow this( string msg )
        {
            super( msg );
        }
    }


    static class OverflowException : Exception
    {
        @safe pure nothrow this( string msg )
        {
            super( msg );
        }
    }


    static void error( string msg = "Invalid symbol" )
    {
        //throw new ParseException( msg );
        debug(info) printf( "error: %.*s\n", cast(int) msg.length, msg.ptr );
        throw __ctfe ? new ParseException(msg)
                     : cast(ParseException) cast(void*) typeid(ParseException).init;

    }


    static void overflow( string msg = "Buffer overflow" )
    {
        //throw new OverflowException( msg );
        debug(info) printf( "overflow: %.*s\n", cast(int) msg.length, msg.ptr );
        throw cast(OverflowException) cast(void*) typeid(OverflowException).init;
    }


    //////////////////////////////////////////////////////////////////////////
    // Type Testing and Conversion
    //////////////////////////////////////////////////////////////////////////


    static bool isAlpha( char val )
    {
        return ('a' <= val && 'z' >= val) ||
               ('A' <= val && 'Z' >= val) ||
               (0x80 & val); // treat all unicode as alphabetic
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
        if (val >= 'a' && val <= 'f')
            return cast(ubyte)(val - 'a' + 10);
        if (val >= 'A' && val <= 'F')
            return cast(ubyte)(val - 'A' + 10);
        if (val >= '0' && val <= '9')
            return cast(ubyte)(val - '0');
        error();
        return 0;
    }


    //////////////////////////////////////////////////////////////////////////
    // Data Output
    //////////////////////////////////////////////////////////////////////////


    static bool contains( const(char)[] a, const(char)[] b )
    {
        if (a.length && b.length)
        {
            auto bend = b.ptr + b.length;
            auto aend = a.ptr + a.length;
            return a.ptr <= b.ptr && bend <= aend;
        }
        return false;
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
                for( size_t v = val.ptr - dst.ptr; v + 1 < len; v++ )
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
        char[20] tmp;
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
        foreach(char e; val )
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
            auto t = tok();
            if (t >= '0' && t <= '9')
                next();
            else
                return buf[beg .. pos];
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
        import core.stdc.stdlib : strtold;
        val = strtold( tbuf.ptr, null );
        import core.stdc.stdio : snprintf;
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
        foreach(char e; buf[pos + 1 .. pos + n] )
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
        TypeVector
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

    TypeVector:
        Nh Type

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
        static immutable string[23] primitives = [
            "char", // a
            "bool", // b
            "creal", // c
            "double", // d
            "real", // e
            "float", // f
            "byte", // g
            "ubyte", // h
            "int", // i
            "ireal", // j
            "uint", // k
            "long", // l
            "ulong", // m
            null, // n
            "ifloat", // o
            "idouble", // p
            "cfloat", // q
            "cdouble", // r
            "short", // s
            "ushort", // t
            "wchar", // u
            "void", // v
            "dchar", // w
        ];

        debug(trace) printf( "parseType+\n" );
        debug(trace) scope(success) printf( "parseType-\n" );
        auto beg = len;
        auto t = tok();

        switch( t )
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
            case 'h': // TypeVector (Nh Type)
                next();
                put( "__vector(" );
                parseType();
                put( ")" );
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
            auto tx = parseType();
            parseType();
            put( "[" );
            put( tx );
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
        case 'B': // TypeTuple (B Number Arguments)
            next();
            // TODO: Handle this.
            return dst[beg .. len];
        case 'Z': // Internal symbol
            // This 'type' is used for untyped internal symbols, i.e.:
            // __array
            // __init
            // __vtbl
            // __Class
            // __Interface
            // __ModuleInfo
            next();
            return dst[beg .. len];
        default:
            if (t >= 'a' && t <= 'w')
            {
                next();
                put( primitives[cast(size_t)(t - 'a')] );
                pad( name );
                return dst[beg .. len];
            }
            error();
            return null;
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

    FuncAttrNogc:
        Ni

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
    void parseCallConvention()
    {
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
    }

    void parseFuncAttr()
    {
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
            case 'h':
                // NOTE: The inout parameter type is represented as "Ng".
                //       The vector parameter type is represented as "Nh".
                //       These make it look like a FuncAttr, but infact
                //       if we see these, then we know we're really in
                //       the parameter list.  Rewind and break.
                pos--;
                break breakFuncAttrs;
            case 'i': // FuncAttrNogc
                next();
                put( "@nogc " );
                continue;
            default:
                error();
            }
        }
    }

    void parseFuncArguments()
    {
        // Arguments
        for( size_t n = 0; true; n++ )
        {
            debug(info) printf( "tok (%c)\n", tok() );
            switch( tok() )
            {
            case 'X': // ArgClose (variadic T t...) style)
                next();
                put( "..." );
                return;
            case 'Y': // ArgClose (variadic T t,...) style)
                next();
                put( ", ..." );
                return;
            case 'Z': // ArgClose (not variadic)
                next();
                return;
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

    enum IsDelegate { no, yes }
    // returns the argument list with the left parenthesis, but not the right
    char[] parseTypeFunction( char[] name = null, IsDelegate isdg = IsDelegate.no )
    {
        debug(trace) printf( "parseTypeFunction+\n" );
        debug(trace) scope(success) printf( "parseTypeFunction-\n" );
        auto beg = len;

        parseCallConvention();
        parseFuncAttr();

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
        parseFuncArguments();
        return dst[beg..len];
    }

    static bool isCallConvention( char ch )
    {
        switch( ch )
        {
            case 'F', 'U', 'V', 'W', 'R':
                return true;
            default:
                return false;
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
            goto case;
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
            foreach (i; 0..n)
            {
                auto a = ascii2hex( tok() ); next();
                auto b = ascii2hex( tok() ); next();
                auto v = cast(char)((a << 4) | b);
                put( __ctfe ? [v] : (cast(char*) &v)[0 .. 1] );
            }
            put( "\"" );
            if( 'a' != t )
                put( __ctfe ? [t] : (cast(char*) &t)[0 .. 1] );
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
                        char[1] tmp = cast(char)num;
                        put( tmp[] );
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

                if ( mayBeMangledNameArg() )
                {
                    auto l = len;
                    auto p = pos;

                    try
                    {
                        debug(trace) printf( "may be mangled name arg\n" );
                        parseMangledNameArg();
                        continue;
                    }
                    catch( ParseException e )
                    {
                        len = l;
                        pos = p;
                        debug(trace) printf( "not a mangled name arg\n" );
                    }
                }

                parseQualifiedName();
                continue;
            default:
                return;
            }
        }
    }


    bool mayBeMangledNameArg()
    {
        debug(trace) printf( "mayBeMangledNameArg+\n" );
        debug(trace) scope(success) printf( "mayBeMangledNameArg-\n" );

        auto p = pos;
        scope(exit) pos = p;
        auto n = decodeNumber();
        return n >= 4 &&
           pos < buf.length && '_' == buf[pos++] &&
           pos < buf.length && 'D' == buf[pos++] &&
           isDigit(buf[pos]);
    }


    void parseMangledNameArg()
    {
        debug(trace) printf( "parseMangledNameArg+\n" );
        debug(trace) scope(success) printf( "parseMangledNameArg-\n" );

        auto n = decodeNumber();
        parseMangledName( n );
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

            if( isCallConvention( tok() ) )
            {
                // try to demangle a function, in case we are pointing to some function local
                auto prevpos = pos;
                auto prevlen = len;

                // we don't want calling convention and attributes in the qualified name
                parseCallConvention();
                parseFuncAttr();
                len = prevlen;

                put( "(" );
                parseFuncArguments();
                put( ")" );
                if( !isDigit( tok() ) ) // voldemort types don't have a return type on the function
                {
                    auto funclen = len;
                    parseType();

                    if( !isDigit( tok() ) )
                    {
                        // not part of a qualified name, so back up
                        pos = prevpos;
                        len = prevlen;
                    }
                    else
                        len = funclen; // remove return type from qualified name
                }
            }
        } while( isDigit( tok() ) );
        return dst[beg .. len];
    }


    /*
    MangledName:
        _D QualifiedName Type
        _D QualifiedName M Type
    */
    void parseMangledName(size_t n = 0)
    {
        debug(trace) printf( "parseMangledName+\n" );
        debug(trace) scope(success) printf( "parseMangledName-\n" );
        char[] name = null;

        auto end = pos + n;

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
            if( pos >= buf.length || (n != 0 && pos >= end) )
                return;
            put( "." );
        } while( true );
    }


    char[] doDemangle(alias FUNC)()
    {
        while( true )
        {
            try
            {
                debug(info) printf( "demangle(%.*s)\n", cast(int) buf.length, buf.ptr );
                FUNC();
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
                    auto msg = e.toString();
                    printf( "error: %.*s\n", cast(int) msg.length, msg.ptr );
                }
                if( dst.length < buf.length )
                    dst.length = buf.length;
                dst[0 .. buf.length] = buf[];
                return dst[0 .. buf.length];
            }
        }
    }

    char[] demangleName()
    {
        return doDemangle!parseMangledName();
    }

    char[] demangleType()
    {
        return doDemangle!parseType();
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
    return d.demangleName();
}


/**
 * Demangles a D mangled type.
 *
 * Params:
 *  buf = The string to demangle.
 *  dst = An optional destination buffer.
 *
 * Returns:
 *  The demangled type name or the original string if the name is not a
 *  mangled D type.
*/
char[] demangleType( const(char)[] buf, char[] dst = null )
{
    auto d = Demangle(buf, dst);
    return d.demangleType();
}


/**
 * Mangles a D symbol.
 *
 * Params:
 *  T = The type of the symbol.
 *  fqn = The fully qualified name of the symbol.
 *  dst = An optional destination buffer.
 *
 * Returns:
 *  The mangled name for a symbols of type T and the given fully
 *  qualified name.
 */
char[] mangle(T)(const(char)[] fqn, char[] dst = null) @safe pure nothrow
{
    static size_t numToString(char[] dst, size_t val) @safe pure nothrow
    {
        char[20] buf = void;
        size_t i = buf.length;
        do
        {
            buf[--i] = cast(char)(val % 10 + '0');
        } while (val /= 10);
        immutable len = buf.length - i;
        if (dst.length >= len)
            dst[0 .. len] = buf[i .. $];
        return len;
    }

    static struct DotSplitter
    {
    @safe pure nothrow:
        const(char)[] s;

        @property bool empty() const { return !s.length; }

        @property const(char)[] front() const
        {
            immutable i = indexOfDot();
            return i == -1 ? s[0 .. $] : s[0 .. i];
        }

        void popFront()
        {
            immutable i = indexOfDot();
            s = i == -1 ? s[$ .. $] : s[i+1 .. $];
        }

        private ptrdiff_t indexOfDot() const
        {
            foreach (i, c; s) if (c == '.') return i;
            return -1;
        }
    }

    size_t len = "_D".length;
    foreach (comp; DotSplitter(fqn))
        len += numToString(null, comp.length) + comp.length;
    len += T.mangleof.length;
    if (dst.length < len) dst.length = len;

    size_t i = "_D".length;
    dst[0 .. i] = "_D";
    foreach (comp; DotSplitter(fqn))
    {
        i += numToString(dst[i .. $], comp.length);
        dst[i .. i + comp.length] = comp[];
        i += comp.length;
    }
    dst[i .. i + T.mangleof.length] = T.mangleof[];
    i += T.mangleof.length;
    return dst[0 .. i];
}


///
unittest
{
    assert(mangle!int("a.b") == "_D1a1bi");
    assert(mangle!(char[])("test.foo") == "_D4test3fooAa");
    assert(mangle!(int function(int))("a.b") == "_D1a1bPFiZi");
}

unittest
{
    static assert(mangle!int("a.b") == "_D1a1bi");

    auto buf = new char[](10);
    buf = mangle!int("a.b", buf);
    assert(buf == "_D1a1bi");
    buf = mangle!(char[])("test.foo", buf);
    assert(buf == "_D4test3fooAa");
    buf = mangle!(real delegate(int))("modµ.dg");
    assert(buf == "_D5modµ2dgDFiZe", buf);
}


/**
 * Mangles a D function.
 *
 * Params:
 *  T = function pointer type.
 *  fqn = The fully qualified name of the symbol.
 *  dst = An optional destination buffer.
 *
 * Returns:
 *  The mangled name for a function with function pointer type T and
 *  the given fully qualified name.
 */
char[] mangleFunc(T:FT*, FT)(const(char)[] fqn, char[] dst = null) @safe pure nothrow if (is(FT == function))
{
    static if (isExternD!FT)
    {
        return mangle!FT(fqn, dst);
    }
    else static if (hasPlainMangling!FT)
    {
        dst.length = fqn.length;
        dst[] = fqn[];
        return dst;
    }
    else static if (isExternCPP!FT)
    {
        static assert(0, "Can't mangle extern(C++) functions.");
    }
    else
    {
        static assert(0, "Can't mangle function with unknown linkage ("~FT.stringof~").");
    }
}


///
unittest
{
    assert(mangleFunc!(int function(int))("a.b") == "_D1a1bFiZi");
    assert(mangleFunc!(int function(Object))("object.Object.opEquals") == "_D6object6Object8opEqualsFC6ObjectZi");
}

unittest
{
    int function(lazy int[], ...) fp;
    assert(mangle!(typeof(fp))("demangle.test") == "_D8demangle4testPFLAiYi");
    assert(mangle!(typeof(*fp))("demangle.test") == "_D8demangle4testFLAiYi");
}

private template isExternD(FT) if (is(FT == function))
{
    enum isExternD = FT.mangleof[0] == 'F';
}

private template isExternCPP(FT) if (is(FT == function))
{
    enum isExternCPP = FT.mangleof[0] == 'R';
}

private template hasPlainMangling(FT) if (is(FT == function))
{
    enum c = FT.mangleof[0];
    // C || Pascal || Windows
    enum hasPlainMangling = c == 'U' || c == 'V' || c == 'W';
}

unittest
{
    static extern(D) void fooD();
    static extern(C) void fooC();
    static extern(Pascal) void fooP();
    static extern(Windows) void fooW();
    static extern(C++) void fooCPP();

    bool check(FT)(bool isD, bool isCPP, bool isPlain)
    {
        return isExternD!FT == isD && isExternCPP!FT == isCPP &&
            hasPlainMangling!FT == isPlain;
    }
    static assert(check!(typeof(fooD))(true, false, false));
    static assert(check!(typeof(fooC))(false, false, true));
    static assert(check!(typeof(fooP))(false, false, true));
    static assert(check!(typeof(fooW))(false, false, true));
    static assert(check!(typeof(fooCPP))(false, true, false));

    static assert(__traits(compiles, mangleFunc!(typeof(&fooD))("")));
    static assert(__traits(compiles, mangleFunc!(typeof(&fooC))("")));
    static assert(__traits(compiles, mangleFunc!(typeof(&fooP))("")));
    static assert(__traits(compiles, mangleFunc!(typeof(&fooW))("")));
    static assert(!__traits(compiles, mangleFunc!(typeof(&fooCPP))("")));
}

/**
* Mangles a C function or variable.
*
* Params:
*  dst = An optional destination buffer.
*
* Returns:
*  The mangled name for a C function or variable, i.e.
*  an underscore is prepended or not, depending on the
*  compiler/linker tool chain
*/
char[] mangleC(const(char)[] sym, char[] dst = null)
{
    version(Win32)
        enum string prefix = "_";
    else version(OSX)
        enum string prefix = "_";
    else
        enum string prefix = "";

    auto len = sym.length + prefix.length;
    if( dst.length < len )
        dst.length = len;

    dst[0 .. prefix.length] = prefix[];
    dst[prefix.length .. len] = sym[];
    return dst[0 .. len];
}


version(unittest)
{
    immutable string[2][] table =
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
        ["_D8demangle3fnAFZv3fnBMFZv", "void demangle.fnA().fnB()"],
        ["_D8demangle4mainFZv1S3fnCFZv", "void demangle.main().S.fnC()"],
        ["_D8demangle4mainFZv1S3fnDMFZv", "void demangle.main().S.fnD()"],
        ["_D8demangle20__T2fnVAiA4i1i2i3i4Z2fnFZv", "void demangle.fn!([1, 2, 3, 4]).fn()"],
        ["_D8demangle10__T2fnVi1Z2fnFZv", "void demangle.fn!(1).fn()"],
        ["_D8demangle26__T2fnVS8demangle1SS2i1i2Z2fnFZv", "void demangle.fn!(demangle.S(1, 2)).fn()"],
        ["_D8demangle13__T2fnVeeNANZ2fnFZv", "void demangle.fn!(real.nan).fn()"],
        ["_D8demangle14__T2fnVeeNINFZ2fnFZv", "void demangle.fn!(-real.infinity).fn()"],
        ["_D8demangle13__T2fnVeeINFZ2fnFZv", "void demangle.fn!(real.infinity).fn()"],
        ["_D8demangle21__T2fnVHiiA2i1i2i3i4Z2fnFZv", "void demangle.fn!([1:2, 3:4]).fn()"],
        ["_D8demangle2fnFNgiZNgi", "inout(int) demangle.fn(inout(int))"],
        ["_D8demangle29__T2fnVa97Va9Va0Vu257Vw65537Z2fnFZv", "void demangle.fn!('a', '\\t', \\x00, '\\u0101', '\\U00010001').fn()"],
        ["_D2gc11gctemplates56__T8mkBitmapTS3std5range13__T4iotaTiTiZ4iotaFiiZ6ResultZ8mkBitmapFNbNiNfPmmZv",
         "nothrow @nogc @safe void gc.gctemplates.mkBitmap!(std.range.iota!(int, int).iota(int, int).Result).mkBitmap(ulong*, ulong)"],
        ["_D8serenity9persister6Sqlite70__T15SqlitePersisterTS8serenity9persister6Sqlite11__unittest6FZv4TestZ15SqlitePersister12__T7opIndexZ7opIndexMFmZS8serenity9persister6Sqlite11__unittest6FZv4Test",
         "serenity.persister.Sqlite.__unittest6().Test serenity.persister.Sqlite.SqlitePersister!(serenity.persister.Sqlite.__unittest6().Test).SqlitePersister.opIndex!().opIndex(ulong)"],
        ["_D8bug100274mainFZv5localMFZi","int bug10027.main().local()"],
        ["_D8demangle4testFNhG16gZv", "void demangle.test(__vector(byte[16]))"],
        ["_D8demangle4testFNhG8sZv", "void demangle.test(__vector(short[8]))"],
        ["_D8demangle4testFNhG4iZv", "void demangle.test(__vector(int[4]))"],
        ["_D8demangle4testFNhG2lZv", "void demangle.test(__vector(long[2]))"],
        ["_D8demangle4testFNhG4fZv", "void demangle.test(__vector(float[4]))"],
        ["_D8demangle4testFNhG2dZv", "void demangle.test(__vector(double[2]))"],
        ["_D8demangle4testFNhG4fNhG4fZv", "void demangle.test(__vector(float[4]), __vector(float[4]))"],
        ["_D8bug1119234__T3fooS23_D8bug111924mainFZ3bariZ3fooMFZv","void bug11192.foo!(int bug11192.main().bar).foo()"],
        ["_D13libd_demangle12__ModuleInfoZ", "libd_demangle.__ModuleInfo"],
        ["_D15TypeInfo_Struct6__vtblZ", "TypeInfo_Struct.__vtbl"],
        ["_D3std5stdio12__ModuleInfoZ", "std.stdio.__ModuleInfo"],
        ["_D3std6traits15__T8DemangleTkZ8Demangle6__initZ", "std.traits.Demangle!(uint).Demangle.__init"],
        ["_D3foo3Bar7__ClassZ", "foo.Bar.__Class"],
        ["_D3foo3Bar6__vtblZ", "foo.Bar.__vtbl"],
        ["_D3foo3Bar11__interfaceZ", "foo.Bar.__interface"],
        ["_D3foo7__arrayZ", "foo.__array"],
    ];

    template staticIota(int x)
    {
        template Seq(T...){ alias T Seq; }

        static if (x == 0)
            alias Seq!() staticIota;
        else
            alias Seq!(staticIota!(x - 1), x - 1) staticIota;
    }
}
unittest
{
    foreach( i, name; table )
    {
        auto r = demangle( name[0] );
        assert( r == name[1],
                "demangled \"" ~ name[0] ~ "\" as \"" ~ r ~ "\" but expected \"" ~ name[1] ~ "\"");
    }
    foreach( i; staticIota!(table.length) )
    {
        enum r = demangle( table[i][0] );
        static assert( r == table[i][1],
                "demangled \"" ~ table[i][0] ~ "\" as \"" ~ r ~ "\" but expected \"" ~ table[i][1] ~ "\"");
    }
}


/*
 *
 */
string decodeDmdString( const(char)[] ln, ref size_t p )
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


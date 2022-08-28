// This file is part of Visual D
//
// Visual D integrates the D programming language into Visual Studio
// Copyright (c) 2010-2011 by Rainer Schuetze, All Rights Reserved
//
// Distributed under the Boost Software License, Version 1.0.
// See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt

module vdc.lexer;

import std.ascii;
import std.uni : isAlpha;
import std.utf;
import std.conv;

enum supportUnorderedCompareOps = false;

// current limitations:
// - nested comments must not nest more than 255 times
// - braces must not nest more than 4095 times inside token string
// - number of different delimiters must not exceed 256

enum TokenCat : int
{
    // assumed to match beginning of visuald.colorizer.TokenColor
    Text,
    Keyword,
    Comment,
    Identifier,
    String,
    Literal,
    Text2,
    Operator,
}

struct TokenInfo
{
    TokenCat type;
    int tokid;
    int StartIndex;
    int EndIndex;
}

///////////////////////////////////////////////////////////////////////////////

struct Lexer
{
    enum State
    {
        kWhite,
        kBlockComment,
        kNestedComment,
        kStringCStyle,
        kStringWysiwyg,
        kStringAltWysiwyg,
        kStringDelimited,
        kStringDelimitedNestedBracket,
        kStringDelimitedNestedParen,
        kStringDelimitedNestedBrace,
        kStringDelimitedNestedAngle,
        kStringTokenFirst,  // after 'q', but before '{' to pass '{' as single operator
        kStringToken,  // encoded by tokenStringLevel > 0
        kStringHex,    // for now, treated as State.kStringWysiwyg
        kStringEscape, // removed in D2.026, not supported
    }

    // lexer scan state is: ___TTNNS
    // TT: token string nesting level
    // NN: comment nesting level/string delimiter id
    // S: State
    static State scanState(int state) { return cast(State) (state & 0xf); }
    static int nestingLevel(int state) { return (state >> 4) & 0xff; } // used for state kNestedComment and kStringDelimited
    static int tokenStringLevel(int state) { return (state >> 12) & 0xff; }
    static int getOtherState(int state) { return (state & 0xfff00000); }

    bool mTokenizeTokenString = true;
    bool mSplitNestedComments = true;
    bool mAllowDollarInIdentifiers = false;

    static int toState(State s, int nesting, int tokLevel, int otherState)
    {
        static assert(State.kStringToken <= 15);
        assert(s >= State.kWhite && s <= State.kStringToken);
        assert(nesting < 32);
        assert(tokLevel < 32);

        return s | ((nesting & 0xff) << 4) | ((tokLevel & 0xff) << 12) | otherState;
    }

    static bool isStringState(State state) { return state >= State.kStringCStyle; }
    static bool isCommentState(State state) { return state == State.kBlockComment || state == State.kNestedComment; }

    static string[256] s_delimiters;
    static int s_nextDelimiter;

    static int getDelimiterIndex(string delim)
    {
        int idx = (s_nextDelimiter - 1) & 0xff;
        for( ; idx != s_nextDelimiter; idx = (idx - 1) & 0xff)
            if(delim == s_delimiters[idx])
                return idx;

        s_nextDelimiter = (s_nextDelimiter + 1) & 0xff;
        s_delimiters[idx] = delim;
        return idx;
    }

    int scanIdentifier(S)(S text, size_t startpos, ref size_t pos)
    {
        int pid;
        return scanIdentifier(text, startpos, pos, pid);
    }

    int scanIdentifier(S)(S text, size_t startpos, ref size_t pos, ref int pid)
    {
        while(pos < text.length)
        {
            auto nextpos = pos;
            dchar ch = decode(text, nextpos);
            if(!isIdentifierCharOrDigit(ch))
                break;
            pos = nextpos;
        }
        string ident = toUTF8(text[startpos .. pos]);

        if(findKeyword(ident, pid))
            return pid == TOK_is ? TokenCat.Operator : TokenCat.Keyword;
        if(findSpecial(ident, pid))
            return TokenCat.String;

        pid = TOK_Identifier;
        return TokenCat.Identifier;
    }

    static int scanOperator(S)(S text, size_t startpos, ref size_t pos, ref int pid)
    {
        size_t len;
        int id = parseOperator(text, startpos, len);
        if(id == TOK_error)
            return TokenCat.Text;

        pid = id;
        pos = startpos + len;
        return TokenCat.Operator;
    }

    static dchar trydecode(S)(S text, ref size_t pos)
    {
        if(pos >= text.length)
            return 0;
        dchar ch = decode(text, pos);
        return ch;
    }

    static void skipDigits(S)(S text, ref size_t pos, int base)
    {
        while(pos < text.length)
        {
            auto nextpos = pos;
            dchar ch = decode(text, nextpos);
            if(ch != '_')
            {
                if(base < 16 && (ch < '0' || ch >= '0' + base))
                    break;
                else if(base == 16 && !isHexDigit(ch))
                    break;
            }
            pos = nextpos;
        }
    }

    static int scanNumber(S)(S text, dchar ch, ref size_t pos)
    {
        int pid;
        return scanNumber(text, ch, pos, pid);
    }

    static int scanNumber(S)(S text, dchar ch, ref size_t pos, ref int pid)
    {
        // pos after first digit
        int base = 10;
        size_t nextpos = pos;
        if(ch == '.')
            goto L_float;

        if(ch == '0')
        {
            size_t prevpos = pos;
            ch = trydecode(text, pos);
            ch = toLower(ch);
            if(ch == 'b')
                base = 2;
            else if (ch == 'x')
                base = 16;
            else
            {
                base = 8;
                pos = prevpos;
            }
        }

        // pos now after prefix or first digit
        skipDigits(text, pos, base);
        // pos now after last digit of integer part

        nextpos = pos;
        ch = trydecode(text, nextpos);

        if((base == 10 && toLower(ch) == 'e') || (base == 16 && toLower(ch) == 'p'))
            goto L_exponent;
        if(base >= 8 && ch == '.') // ".." is the slice token
        {
            { // mute errors about goto skipping declaration
                size_t trypos = nextpos;
                dchar trych = trydecode(text, trypos);
                if (trych == '.')
                    goto L_integer;
                //if (isAlpha(trych) || trych == '_' || (p[1] & 0x80))
                //    goto done;
            }
            // float
            if(base < 10)
                base = 10;
L_float:
            pos = nextpos;
            skipDigits(text, pos, base);

            nextpos = pos;
            ch = trydecode(text, nextpos);
            if((base == 10 && toLower(ch) == 'e') || (base == 16 && toLower(ch) == 'p'))
            {
L_exponent:
                // exponent
                pos = nextpos;
                ch = trydecode(text, nextpos);
                if(ch == '-' || ch == '+')
                    pos = nextpos;
                skipDigits(text, pos, 10);
            }

            // suffix
            nextpos = pos;
            ch = trydecode(text, nextpos);
            if(ch == 'L' || toUpper(ch) == 'F')
            {
L_floatLiteral:
                pos = nextpos;
                ch = trydecode(text, nextpos);
            }
            if(ch == 'i')
L_complexLiteral:
                pos = nextpos;
            pid = TOK_FloatLiteral;
        }
        else
        {
            // check integer suffix
            if(ch == 'i')
                goto L_complexLiteral;
            if(toUpper(ch) == 'F')
                goto L_floatLiteral;

            if(toUpper(ch) == 'U')
            {
                pos = nextpos;
                ch = trydecode(text, nextpos);
                if(ch == 'L')
                    pos = nextpos;
            }
            else if (ch == 'L')
            {
                pos = nextpos;
                ch = trydecode(text, nextpos);
                if(ch == 'i')
                    goto L_complexLiteral;
                if(toUpper(ch) == 'U')
                    pos = nextpos;
            }
L_integer:
            pid = TOK_IntegerLiteral;
        }
        return TokenCat.Literal;
    }

    version(unspecified) unittest
    {
        int pid;
        size_t pos = 1;
        auto cat = scanNumber("0.0i", '0', pos, pid);
        assert(pid == TOK_FloatLiteral);
        pos = 1;
        cat = scanNumber("0.i", '0', pos, pid);
        assert(pid == TOK_IntegerLiteral);
    }

    static State scanBlockComment(S)(S text, ref size_t pos)
    {
        while(pos < text.length)
        {
            dchar ch = decode(text, pos);
            while(ch == '*')
            {
                if (pos >= text.length)
                    return State.kBlockComment;
                ch = decode(text, pos);
                if(ch == '/')
                    return State.kWhite;
            }
        }
        return State.kBlockComment;
    }

    State scanNestedComment(S)(S text, size_t startpos, ref size_t pos, ref int nesting)
    {
        while(pos < text.length)
        {
            dchar ch = decode(text, pos);
            while(ch == '/')
            {
                if (pos >= text.length)
                    return State.kNestedComment;
                ch = decode(text, pos);
                if(ch == '+')
                {
                    if(mSplitNestedComments && pos > startpos + 2)
                    {
                        pos -= 2;
                        return State.kNestedComment;
                    }
                    nesting++;
                    goto nextChar;
                }
            }
            while(ch == '+')
            {
                if (pos >= text.length)
                    return State.kNestedComment;
                ch = decode(text, pos);
                if(ch == '/')
                {
                    nesting--;
                    if(nesting == 0)
                        return State.kWhite;
                    if(mSplitNestedComments)
                        return State.kNestedComment;
                    break;
                }
            }
        nextChar:;
        }
        return State.kNestedComment;
    }

    static State scanStringPostFix(S)(S text, ref size_t pos)
    {
        size_t nextpos = pos;
        dchar ch = trydecode(text, nextpos);
        if(ch == 'c' || ch == 'w' || ch == 'd')
            pos = nextpos;
        return State.kWhite;
    }

    static State scanStringWysiwyg(S)(S text, ref size_t pos)
    {
        while(pos < text.length)
        {
            dchar ch = decode(text, pos);
            if(ch == '"')
                return scanStringPostFix(text, pos);
        }
        return State.kStringWysiwyg;
    }

    static State scanStringAltWysiwyg(S)(S text, ref size_t pos)
    {
        while(pos < text.length)
        {
            dchar ch = decode(text, pos);
            if(ch == '`')
                return scanStringPostFix(text, pos);
        }
        return State.kStringAltWysiwyg;
    }

    static State scanStringCStyle(S)(S text, ref size_t pos, dchar term)
    {
        while(pos < text.length)
        {
            dchar ch = decode(text, pos);
            if(ch == '\\')
            {
                if (pos >= text.length)
                    break;
                ch = decode(text, pos);
            }
            else if(ch == term)
                return scanStringPostFix(text, pos);
        }
        return State.kStringCStyle;
    }

    State startDelimiterString(S)(S text, ref size_t pos, ref int nesting)
    {
        import std.uni : isWhite;
        nesting = 1;

        auto startpos = pos;
        dchar ch = trydecode(text, pos);
        State s = State.kStringDelimited;
        if(ch == '[')
            s = State.kStringDelimitedNestedBracket;
        else if(ch == '(')
            s = State.kStringDelimitedNestedParen;
        else if(ch == '{')
            s = State.kStringDelimitedNestedBrace;
        else if(ch == '<')
            s = State.kStringDelimitedNestedAngle;
        else if(ch == 0 || isWhite(ch)) // bad delimiter, fallback to wysiwyg string
            s = State.kStringWysiwyg;
        else
        {
            if(isIdentifierChar(ch))
                scanIdentifier(text, startpos, pos);
            string delim = toUTF8(text[startpos .. pos]);
            nesting = getDelimiterIndex(delim);
        }
        return s;
    }

    State scanTokenString(S)(S text, ref size_t pos, ref int tokLevel)
    {
        int state = toState(State.kWhite, 0, 0, 0);
        int id = -1;
        while(pos < text.length && tokLevel > 0)
        {
            int type = scan(state, text, pos, id);
            if(id == TOK_lcurly)
                tokLevel++;
            else if(id == TOK_rcurly)
                tokLevel--;
        }
        return (tokLevel > 0 ? State.kStringToken : State.kWhite);
    }

    static bool isStartingComment(S)(S txt, ref size_t idx)
    {
        if(idx >= 0 && idx < txt.length-1 && txt[idx] == '/' && (txt[idx+1] == '*' || txt[idx+1] == '+'))
            return true;
        if((txt[idx] == '*' || txt[idx] == '+') && idx > 0 && txt[idx-1] == '/')
        {
            idx--;
            return true;
        }
        return false;
    }

    static bool isEndingComment(S)(S txt, ref size_t pos)
    {
        if(pos < txt.length && pos > 0 && txt[pos] == '/' && (txt[pos-1] == '*' || txt[pos-1] == '+'))
        {
            pos--;
            return true;
        }
        if(pos < txt.length-1 && pos >= 0 && (txt[pos] == '*' || txt[pos] == '+') && txt[pos+1] == '/')
            return true;
        return false;
    }

    bool isIdentifierChar(dchar ch)
    {
        if(mAllowDollarInIdentifiers && ch == '$')
            return true;
        return isAlpha(ch) || ch == '_' || ch == '@';
    }

    bool isIdentifierCharOrDigit(dchar ch)
    {
        return isIdentifierChar(ch) || isDigit(ch);
    }

    bool isIdentifier(S)(S text)
    {
        if(text.length == 0)
            return false;

        size_t pos;
        dchar ch = decode(text, pos);
        if(!isIdentifierChar(ch))
            return false;

        while(pos < text.length)
        {
            ch = decode(text, pos);
            if(!isIdentifierCharOrDigit(ch))
                return false;
        }
        return true;
    }

    static bool isInteger(S)(S text)
    {
        if(text.length == 0)
            return false;

        size_t pos;
        while(pos < text.length)
        {
            dchar ch = decode(text, pos);
            if(!isDigit(ch))
                return false;
        }
        return true;
    }

    static bool isBracketPair(dchar ch1, dchar ch2)
    {
        switch(ch1)
        {
        case '{': return ch2 == '}';
        case '}': return ch2 == '{';
        case '(': return ch2 == ')';
        case ')': return ch2 == '(';
        case '[': return ch2 == ']';
        case ']': return ch2 == '[';
        default:  return false;
        }
    }

    static bool isOpeningBracket(dchar ch)
    {
        return ch == '[' || ch == '(' || ch == '{';
    }

    static bool isClosingBracket(dchar ch)
    {
        return ch == ']' || ch == ')' || ch == '}';
    }

    static dchar openingBracket(State s)
    {
        switch(s)
        {
        case State.kStringDelimitedNestedBracket: return '[';
        case State.kStringDelimitedNestedParen:   return '(';
        case State.kStringDelimitedNestedBrace:   return '{';
        case State.kStringDelimitedNestedAngle:   return '<';
        default: break;
        }
        assert(0);
    }

    static dchar closingBracket(State s)
    {
        switch(s)
        {
        case State.kStringDelimitedNestedBracket: return ']';
        case State.kStringDelimitedNestedParen:   return ')';
        case State.kStringDelimitedNestedBrace:   return '}';
        case State.kStringDelimitedNestedAngle:   return '>';
        default: break;
        }
        assert(0);
    }

    static bool isCommentOrSpace(S)(int type, S text)
    {
        return (type == TokenCat.Comment || (type == TokenCat.Text && isWhite(text[0])));
    }

    static State scanNestedDelimiterString(S)(S text, ref size_t pos, State s, ref int nesting)
    {
        dchar open  = openingBracket(s);
        dchar close = closingBracket(s);

        while(pos < text.length)
        {
            dchar ch = decode(text, pos);
            if(ch == open)
                nesting++;
            else if(ch == close && nesting > 0)
                nesting--;
            else if(ch == '"' && nesting == 0)
                return scanStringPostFix(text, pos);
        }
        return s;
    }

    State scanDelimitedString(S)(S text, ref size_t pos, ref int delim)
    {
        string delimiter = s_delimiters[delim];

        while(pos < text.length)
        {
            auto startpos = pos;
            dchar ch = decode(text, pos);
            if(isIdentifierChar(ch))
                scanIdentifier(text, startpos, pos);
            string ident = toUTF8(text[startpos .. pos]);
            if(ident == delimiter)
            {
                ch = trydecode(text, pos);
                if(ch == '"')
                {
                    delim = 0; // reset delimiter id, it shadows nesting
                    return scanStringPostFix(text, pos);
                }
            }
        }
        return State.kStringDelimited;
    }

    int scan(S)(ref int state, in S text, ref size_t pos, ref int id)
    {
        State s = scanState(state);
        int nesting = nestingLevel(state);
        int tokLevel = tokenStringLevel(state);
        int otherState = getOtherState(state);

        int type = TokenCat.Text;
        size_t startpos = pos;
        dchar ch;

        id = TOK_Space;

        switch(s)
        {
        case State.kWhite:
            ch = decode(text, pos);
            if(ch == 'r' || ch == 'x' || ch == 'q')
            {
                size_t prevpos = pos;
                dchar nch = trydecode(text, pos);
                if(nch == '"' && ch == 'q')
                {
                    s = startDelimiterString(text, pos, nesting);
                    if(s == State.kStringDelimited)
                        goto case State.kStringDelimited;
                    else if(s == State.kStringWysiwyg)
                        goto case State.kStringWysiwyg;
                    else
                        goto case State.kStringDelimitedNestedBracket;
                }
                else if(tokLevel == 0 && ch == 'q' && nch == '{')
                {
                    type = TokenCat.String;
                    id = TOK_StringLiteral;
                    if(mTokenizeTokenString)
                    {
                        pos = prevpos;
                        s = State.kStringTokenFirst;
                    }
                    else
                    {
                        tokLevel = 1;
                        s = scanTokenString(text, pos, tokLevel);
                    }
                    break;
                }
                else if(nch == '"')
                {
                    goto case State.kStringWysiwyg;
                }
                else
                {
                    pos = prevpos;
                    type = scanIdentifier(text, startpos, pos, id);
                }
            }
            else if(isIdentifierChar(ch))
                type = scanIdentifier(text, startpos, pos, id);
            else if(isDigit(ch))
                type = scanNumber(text, ch, pos, id);
            else if (ch == '.')
            {
                size_t nextpos = pos;
                ch = trydecode(text, nextpos);
                if(isDigit(ch))
                    type = scanNumber(text, '.', pos, id);
                else
                    type = scanOperator(text, startpos, pos, id);
            }
            else if (ch == '/')
            {
                size_t prevpos = pos;
                ch = trydecode(text, pos);
                if (ch == '/')
                {
                    // line comment
                    type = TokenCat.Comment;
                    id = TOK_Comment;
                    while(pos < text.length && decode(text, pos) != '\n') {}
                }
                else if (ch == '*')
                {
                    s = scanBlockComment(text, pos);
                    type = TokenCat.Comment;
                    id = TOK_Comment;
                }
                else if (ch == '+')
                {
                    nesting = 1;
                    s = scanNestedComment(text, startpos, pos, nesting);
                    type = TokenCat.Comment;
                    id = TOK_Comment;
                }
                else
                {
                    // step back to position after '/'
                    pos = prevpos;
                    type = scanOperator(text, startpos, pos, id);
                }
            }
            else if (ch == '"')
                goto case State.kStringCStyle;

            else if (ch == '`')
                goto case State.kStringAltWysiwyg;

            else if (ch == '\'')
            {
                s = scanStringCStyle(text, pos, '\'');
                id = TOK_CharacterLiteral;
                type = TokenCat.String;
            }
            else if (ch == '#')
            {
                // display #! or #line as line comment
                type = TokenCat.Comment;
                id = TOK_Comment;
                while(pos < text.length && decode(text, pos) != '\n') {}
            }
            else
            {
                if (tokLevel > 0)
                {
                    if(ch == '{')
                        tokLevel++;
                    else if (ch == '}')
                        tokLevel--;
                    if(!isWhite(ch))
                        type = scanOperator(text, startpos, pos, id);
                    id = TOK_StringLiteral;
                }
                else if(!isWhite(ch))
                    type = scanOperator(text, startpos, pos, id);
            }
            break;

        case State.kStringTokenFirst:
            ch = decode(text, pos);
            assert(ch == '{');

            tokLevel = 1;
            type = TokenCat.Operator;
            id = TOK_StringLiteral;
            s = State.kWhite;
            break;

        case State.kStringToken:
            type = TokenCat.String;
            id = TOK_StringLiteral;
            s = scanTokenString(text, pos, tokLevel);
            break;

        case State.kBlockComment:
            s = scanBlockComment(text, pos);
            type = TokenCat.Comment;
            id = TOK_Comment;
            break;

        case State.kNestedComment:
            s = scanNestedComment(text, pos, pos, nesting);
            type = TokenCat.Comment;
            id = TOK_Comment;
            break;

        case State.kStringCStyle:
            s = scanStringCStyle(text, pos, '"');
            type = TokenCat.String;
            id = TOK_StringLiteral;
            break;

        case State.kStringWysiwyg:
            s = scanStringWysiwyg(text, pos);
            type = TokenCat.String;
            id = TOK_StringLiteral;
            break;

        case State.kStringAltWysiwyg:
            s = scanStringAltWysiwyg(text, pos);
            type = TokenCat.String;
            id = TOK_StringLiteral;
            break;

        case State.kStringDelimited:
            s = scanDelimitedString(text, pos, nesting);
            type = TokenCat.String;
            id = TOK_StringLiteral;
            break;

        case State.kStringDelimitedNestedBracket:
        case State.kStringDelimitedNestedParen:
        case State.kStringDelimitedNestedBrace:
        case State.kStringDelimitedNestedAngle:
            s = scanNestedDelimiterString(text, pos, s, nesting);
            type = TokenCat.String;
            id = TOK_StringLiteral;
            break;

        default:
            break;
        }
        state = toState(s, nesting, tokLevel, otherState);

        if(tokLevel > 0)
            id = TOK_StringLiteral;
        return type;
    }

    int scan(S)(ref int state, in S text, ref size_t pos)
    {
        int id;
        return scan(state, text, pos, id);
    }

    ///////////////////////////////////////////////////////////////
    TokenInfo[] ScanLine(S)(int iState, S text)
    {
        TokenInfo[] lineInfo;
        for(size_t pos = 0; pos < text.length; )
        {
            TokenInfo info;
            info.StartIndex = pos;
            info.type = cast(TokenCat) scan(iState, text, pos, info.tokid);
            info.EndIndex = pos;
            lineInfo ~= info;
        }
        return lineInfo;
    }
}

///////////////////////////////////////////////////////////////

// converted int[string] to short[string] due to bug #2500
__gshared short[string] keywords_map; // maps to TOK enumerator
__gshared short[string] specials_map; // maps to TOK enumerator
alias AssociativeArray!(string, short) _wa1; // fully instantiate type info
alias AssociativeArray!(int, const(int)) _wa2; // fully instantiate type info

shared static this()
{
    foreach(i, s; keywords)
        keywords_map[s] = cast(short) (TOK_begin_Keywords + i);

    foreach(i, s; specials)
        specials_map[s] = cast(short) i;
}

bool findKeyword(string ident, ref int id)
{
    if(__ctfe)
    {
        // slow, but compiles
        foreach(i, k; keywords)
            if(k == ident)
            {
                id = cast(int) (TOK_begin_Keywords + i);
                return true;
            }
    }
    else if(auto pident = ident in keywords_map)
    {
        id = *pident;
        return true;
    }
    return false;
}

bool isKeyword(string ident)
{
    int id;
    return findKeyword(ident, id);
}

bool findSpecial(string ident, ref int id)
{
    if(__ctfe)
    {
        // slow, but compiles
        foreach(i, k; specials)
            if(k == ident)
            {
                id = TOK_StringLiteral;
                return true;
            }
    }
    else if(auto pident = ident in specials_map)
    {
        id = TOK_StringLiteral;
        return true;
    }
    return false;
}

const string[] keywords =
[
    "this",
    "super",
    "assert",
    "null",
    "true",
    "false",
    "cast",
    "new",
    "delete",
    "throw",
    "module",
    "pragma",
    "typeof",
    "typeid",
    "template",

    "void",
    "byte",
    "ubyte",
    "short",
    "ushort",
    "int",
    "uint",
    "long",
    "ulong",
    "cent",
    "ucent",
    "float",
    "double",
    "real",
    "bool",
    "char",
    "wchar",
    "dchar",
    "ifloat",
    "idouble",
    "ireal",

    "cfloat",
    "cdouble",
    "creal",

    "delegate",
    "function",

    "is",
    "if",
    "else",
    "while",
    "for",
    "do",
    "switch",
    "case",
    "default",
    "break",
    "continue",
    "synchronized",
    "return",
    "goto",
    "try",
    "catch",
    "finally",
    "with",
    "asm",
    "foreach",
    "foreach_reverse",
    "scope",

    "struct",
    "class",
    "interface",
    "union",
    "enum",
    "import",
    "mixin",
    "static",
    "final",
    "const",
    "typedef",
    "alias",
    "override",
    "abstract",
    "volatile",
    "debug",
    "deprecated",
    "in",
    "out",
    "inout",
    "lazy",
    "auto",

    "align",
    "extern",
    "private",
    "package",
    "protected",
    "public",
    "export",

    "body",
    "invariant",
    "unittest",
    "version",
    //{    "manifest",    TOKmanifest    },

    // Added after 1.0
    "ref",
    "macro",
    "pure",
    "nothrow",
    "__gshared",
    "__thread",
    "__traits",
    "__overloadset",
    "__parameters",
    "__argTypes",
    "__vector",

    "__FILE__",
    "__LINE__",
    "__FUNCTION__",
    "__PRETTY_FUNCTION__",
    "__MODULE__",

    "shared",
    "immutable",

    "@disable",
    "@property",
    "@nogc",
    "@safe",
    "@system",
    "@trusted",

];

// not listed as keywords, but "special tokens"
const string[] specials =
[
    "__DATE__",
    "__EOF__",
    "__TIME__",
    "__TIMESTAMP__",
    "__VENDOR__",
    "__VERSION__",
];

////////////////////////////////////////////////////////////////////////
enum
{
    TOK_begin_Generic,
    TOK_Space = TOK_begin_Generic,
    TOK_Comment,
    TOK_Identifier,
    TOK_IntegerLiteral,
    TOK_FloatLiteral,
    TOK_StringLiteral,
    TOK_CharacterLiteral,
    TOK_EOF,
    TOK_RECOVER,
    TOK_end_Generic
}

string genKeywordEnum(string kw)
{
    if(kw[0] == '@')
        kw = kw[1..$];
    return "TOK_" ~ kw;
}

string genKeywordsEnum(T)(const string[] kwords, T begin)
{
    string enums = "enum { TOK_begin_Keywords = " ~ to!string(begin) ~ ", ";
    bool first = true;
    foreach(kw; kwords)
    {
        enums ~= genKeywordEnum(kw);
        if(first)
        {
            first = false;
            enums ~= " = TOK_begin_Keywords";
        }
        enums ~= ",";
    }
    enums ~= "TOK_end_Keywords }";
    return enums;
}

mixin(genKeywordsEnum(keywords, "TOK_end_Generic"));

const string[2][] operators =
[
    [ "lcurly",           "{" ],
    [ "rcurly",           "}" ],
    [ "lparen",           "(" ],
    [ "rparen",           ")" ],
    [ "lbracket",         "[" ],
    [ "rbracket",         "]" ],
    [ "semicolon",        ";" ],
    [ "colon",            ":" ],
    [ "comma",            "," ],
    [ "dot",              "." ],

    // binary operators
    [ "xor",              "^" ],
    [ "lt",               "<" ],
    [ "gt",               ">" ],
    [ "le",               "<=" ],
    [ "ge",               ">=" ],
    [ "equal",            "==" ],
    [ "notequal",         "!=" ],
    [ "lambda",           "=>" ],

    [ "unord",            "!<>=" ],
    [ "ue",               "!<>" ],
    [ "lg",               "<>" ],
    [ "leg",              "<>=" ],
    [ "ule",              "!>" ],
    [ "ul",               "!>=" ],
    [ "uge",              "!<" ],
    [ "ug",               "!<=" ],
    [ "notcontains",      "!in" ],
    [ "notidentity",      "!is" ],

    [ "shl",              "<<" ],
    [ "shr",              ">>" ],
    [ "ushr",             ">>>" ],
    [ "add",              "+" ],
    [ "min",              "-" ],
    [ "mul",              "*" ],
    [ "div",              "/" ],
    [ "mod",              "%" ],
    [ "pow",              "^^" ],
    [ "and",              "&" ],
    [ "andand",           "&&" ],
    [ "or",               "|" ],
    [ "oror",             "||" ],
    [ "tilde",            "~" ],

    [ "assign",           "=" ],
    [ "xorass",           "^=" ],
    [ "addass",           "+=" ],
    [ "minass",           "-=" ],
    [ "mulass",           "*=" ],
    [ "divass",           "/=" ],
    [ "modass",           "%=" ],
    [ "powass",           "^^=" ],
    [ "shlass",           "<<=" ],
    [ "shrass",           ">>=" ],
    [ "ushrass",          ">>>=" ],
    [ "andass",           "&=" ],
    [ "orass",            "|=" ],
    [ "catass",           "~=" ],

    // end of binary operators

    [ "not",              "!" ],
    [ "dollar",           "$" ],
    [ "slice",            ".." ],
    [ "dotdotdot",        "..." ],
    [ "plusplus",         "++" ],
    [ "minusminus",       "--" ],
    [ "question",         "?" ],
/+
    [ "array",            "[]" ],
    // symbols with duplicate meaning
    [ "address",          "&" ],
    [ "star",             "*" ],
    [ "preplusplus",      "++" ],
    [ "preminusminus",    "--" ],
    [ "neg",              "-" ],
    [ "uadd",             "+" ],
    [ "cat",              "~" ],
    [ "identity",         "is" ],
    [ "plus",             "++" ],
    [ "minus",            "--" ],
+/
];

string genOperatorEnum(T)(const string[2][] ops, T begin)
{
    string enums = "enum { TOK_begin_Operators = " ~ to!string(begin) ~ ", ";
    bool first = true;
    for(int o = 0; o < ops.length; o++)
    {
        enums ~= "TOK_" ~ ops[o][0];
        if(first)
        {
            first = false;
            enums ~= " = TOK_begin_Operators";
        }
        enums ~= ",";
    }
    enums ~= "TOK_end_Operators }";
    return enums;
}

mixin(genOperatorEnum(operators, "TOK_end_Keywords"));

enum TOK_binaryOperatorFirst = TOK_xor;
enum TOK_binaryOperatorLast  = TOK_catass;
enum TOK_assignOperatorFirst = TOK_assign;
enum TOK_assignOperatorLast  = TOK_catass;
enum TOK_unorderedOperatorFirst = TOK_unord;
enum TOK_unorderedOperatorLast  = TOK_ug;

enum TOK_error = -1;

bool _stringEqual(string s1, string s2, int length)
{
    if(s1.length < length || s2.length < length)
        return false;
    for(int i = 0; i < length; i++)
        if(s1[i] != s2[i])
            return false;
    return true;
}

int[] sortedOperatorIndexArray()
{
    // create sorted list of operators
    int[] opIndex;
    for(int o = 0; o < operators.length; o++)
    {
        string op = operators[o][1];
        int p = 0;
        while(p < opIndex.length)
        {
            assert(op != operators[opIndex[p]][1], "duplicate operator " ~ op);
            if(op < operators[opIndex[p]][1])
                break;
            p++;
        }
        // array slicing does not work in CTFE?
        // opIndex ~= opIndex[0..p] ~ o ~ opIndex[p..$];
        int[] nIndex;
        for(int i = 0; i < p; i++)
            nIndex ~= opIndex[i];
        nIndex ~= o;
        for(int i = p; i < opIndex.length; i++)
            nIndex ~= opIndex[i];
        opIndex = nIndex;
    }
    return opIndex;
}

string[] sortedOperatorArray()
{
    string[] array;
    foreach(o; sortedOperatorIndexArray())
        array ~= operators[o][1];
    return array;
}

string genOperatorParser(string getch)
{
    int[] opIndex = sortedOperatorIndexArray();

    int matchlen = 0;
    string indent = "";
    string[] defaults = [ "error" ];
    string txt = indent ~ "dchar ch;\n";
    for(int o = 0; o < opIndex.length; o++)
    {
        string op = operators[opIndex[o]][1];
        string nextop;
        if(o + 1 < opIndex.length)
            nextop = operators[opIndex[o+1]][1];

        while(op.length > matchlen)
        {
            if(matchlen > 0)
                txt ~= indent ~ "case '" ~ op[matchlen-1] ~ "':\n";
            indent ~= "  ";
            txt ~= indent ~ "ch = " ~ getch ~ ";\n";
            txt ~= indent ~ "switch(ch)\n";
            txt ~= indent ~ "{\n";
            indent ~= "  ";
            int len = (matchlen > 0 ? matchlen - 1 : 0);
            while(len > 0 && defaults[len] == defaults[len+1])
                len--;
            txt ~= indent ~ "default: len = " ~ to!string(len) ~ "; return TOK_" ~ defaults[$-1] ~ ";\n";
            //txt ~= indent ~ "case '" ~ op[matchlen] ~ "':\n";
            defaults ~= defaults[$-1];
            matchlen++;
        }
        if(nextop.length > matchlen && nextop[0..matchlen] == op)
        {
            if(matchlen > 0)
                txt ~= indent ~ "case '" ~ op[matchlen-1] ~ "':\n";
            indent ~= "  ";
            txt ~= indent ~ "ch = " ~ getch ~ ";\n";
            txt ~= indent ~ "switch(ch)\n";
            txt ~= indent ~ "{\n";
            indent ~= "  ";
            txt ~= indent ~ "default: len = " ~ to!string(matchlen) ~ "; return TOK_" ~ operators[opIndex[o]][0] ~ "; // " ~ op ~ "\n";
            defaults ~= operators[opIndex[o]][0];
            matchlen++;
        }
        else
        {
            string case_txt = "case '" ~ op[matchlen-1] ~ "':";
            if(isAlphaNum(op[matchlen-1]))
                case_txt ~= " ch = getch(); if(isAlphaNum(ch) || ch == '_') goto default;\n" ~ indent ~ "  ";
            txt ~= indent ~ case_txt ~ " len = " ~ to!string(matchlen) ~ "; return TOK_" ~ operators[opIndex[o]][0] ~ "; // " ~ op ~ "\n";

            while(nextop.length < matchlen || (matchlen > 0 && !_stringEqual(op, nextop, matchlen-1)))
            {
                matchlen--;
                indent = indent[0..$-2];
                txt ~= indent ~ "}\n";
                indent = indent[0..$-2];
                defaults = defaults[0..$-1];
            }
        }
    }
    return txt;
}

int parseOperator(S)(S txt, size_t pos, ref size_t len)
{
    dchar getch()
    {
        if(pos >= txt.length)
            return 0;
        return decode(txt, pos);
    }

    mixin(genOperatorParser("getch()"));
}

////////////////////////////////////////////////////////////////////////
version(none)
{
    pragma(msg, genKeywordsEnum(keywords, "TOK_end_Generic"));
    pragma(msg, genOperatorEnum(operators, "TOK_end_Keywords"));
    pragma(msg, sortedOperatorArray());
    pragma(msg, genOperatorParser("getch()"));
}

string tokenString(int id)
{
    switch(id)
    {
        case TOK_Space:            return " ";
        case TOK_Comment:          return "/**/";
        case TOK_Identifier:       return "Identifier";
        case TOK_IntegerLiteral:   return "IntegerLiteral";
        case TOK_FloatLiteral:     return "FloatLiteral";
        case TOK_StringLiteral:    return "StringtLiteral";
        case TOK_CharacterLiteral: return "CharacterLiteral";
        case TOK_EOF:              return "__EOF__";
        case TOK_RECOVER:          return "__RECOVER__";
        case TOK_begin_Keywords: .. case TOK_end_Keywords - 1:
            return keywords[id - TOK_begin_Keywords];
        case TOK_begin_Operators: .. case TOK_end_Operators - 1:
            return operators[id - TOK_begin_Operators][1];
        default:
            assert(false);
    }
}

string operatorName(int id)
{
    switch(id)
    {
        case TOK_begin_Operators: .. case TOK_end_Operators - 1:
            return operators[id - TOK_begin_Operators][0];
        default:
            assert(false);
    }
}

enum case_TOKs_BasicTypeX = q{
    case TOK_bool:
    case TOK_byte:
    case TOK_ubyte:
    case TOK_short:
    case TOK_ushort:
    case TOK_int:
    case TOK_uint:
    case TOK_long:
    case TOK_ulong:
    case TOK_char:
    case TOK_wchar:
    case TOK_dchar:
    case TOK_float:
    case TOK_double:
    case TOK_real:
    case TOK_ifloat:
    case TOK_idouble:
    case TOK_ireal:
    case TOK_cfloat:
    case TOK_cdouble:
    case TOK_creal:
    case TOK_void:
};

enum case_TOKs_TemplateSingleArgument = q{
    case TOK_Identifier:
    case TOK_CharacterLiteral:
    case TOK_StringLiteral:
    case TOK_IntegerLiteral:
    case TOK_FloatLiteral:
    case TOK_true:
    case TOK_false:
    case TOK_null:
    case TOK___FILE__:
    case TOK___LINE__:
}; // + case_TOKs_BasicTypeX;

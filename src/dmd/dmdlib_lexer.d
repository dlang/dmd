module dmd.dmdlib_lexer;


import core.stdc.ctype;
import core.stdc.errno;
import core.stdc.stdarg;
import core.stdc.stdio;
import core.stdc.stdlib : getenv;
import core.stdc.string;
import core.stdc.time;

import dmd.entity;
import dmd.errors;
import dmd.globals;
import dmd.id;
import dmd.identifier;
import dmd.root.array;
import dmd.root.ctfloat;
import dmd.common.outbuffer;
import dmd.root.port;
import dmd.root.rmem;
import dmd.root.string;
import dmd.root.utf;
import dmd.tokens;
import dmd.utils;
import dmd.lexer;

nothrow:

version = DMDLIB;

enum CommentOptions {
    None,
    All,
    AllCondensed,
}

enum WhitespaceOptions {
    None,
    OnlySpaces,
    OnlyNewLines,
    OnlyTabs,
    All,
    AllCondensed,
}

struct LexerConfig
{
    bool doc;
    CommentOptions comm;
    WhitespaceOptions ws;
}

class ConfigurableLexer : Lexer
{
    LexerConfig config;

    this(const(char)* filename, const(char)* base, size_t begoffset,
        size_t endoffset, bool doDocComment = false, bool commentToken = false, bool whitespaceToken = false) pure
    {
        super(filename, base, begoffset, endoffset, doDocComment, commentToken);
        this.config.doc = doDocComment;
        this.config.comm = commentToken ? CommentOptions.All : CommentOptions.None;
        this.config.ws = whitespaceToken ? WhitespaceOptions.All : WhitespaceOptions.None;
    }

    this(const(char)* filename, const(char)* base, size_t begoffset,
        size_t endoffset, LexerConfig config) pure
    {
        bool doDocComment = config.doc;
        bool commentToken = config.comm == CommentOptions.None ? false : true;
        super(filename, base, begoffset, endoffset, doDocComment, commentToken);
        this.config = config;
    }

    bool empty() const pure @property @nogc @safe
    {
        return front() == TOK.endOfFile;
    }

    TOK front() const pure @property @nogc @safe
    {
        return token.value;
    }

    void popFront()
    {
        nextToken();
    }

    final bool skipCondensed(TOK last, TOK current) nothrow
    {
        return (config.comm == CommentOptions.AllCondensed && last == TOK.comment && current == TOK.comment) ||
            (config.ws == WhitespaceOptions.AllCondensed && last == TOK.whitespace && current == TOK.whitespace) ||
            (config.ws == WhitespaceOptions.AllCondensed && last == TOK.endOfLine && current == TOK.endOfLine);
    }

    override TOK nextToken()
    {
        prevloc = token.loc;
        if (token.next)
        {
            Token* t = token.next;
            memcpy(&token, t, Token.sizeof);
            releaseToken(t);
        }
        else
        {
            TOK lastTOK = token.value;
            do
                scan(&token);
            while (skipCondensed(lastTOK, token.value));
        }
        //printf(token.toChars());
        return token.value;
    }

    /****************************
     * Turn next token in buffer into a token.
     * Params:
     *  t = the token to set the resulting Token to
     */
    override void scan(Token* t)
    {
        const lastLine = scanloc.linnum;
        Loc startLoc;
        t.blockComment = null;
        t.lineComment = null;

        while (1)
        {
            t.ptr = p;
            //printf("p = %p, *p = '%c'\n",p,*p);
            t.loc = loc();
            switch (*p)
            {
            case 0:
            case 0x1A:
                t.value = TOK.endOfFile; // end of file
                // Intentionally not advancing `p`, such that subsequent calls keep returning TOK.endOfFile.
                return;
            case ' ':
                if (config.ws == WhitespaceOptions.None || config.ws == WhitespaceOptions.AllCondensed)
                {
                    // Skip 4 spaces at a time after aligning 'p' to a 4-byte boundary.
                    while ((cast(size_t)p) % uint.sizeof)
                    {
                        if (*p != ' ')
                            goto LendSkipFourSpaces;
                        p++;
                    }
                    while (*(cast(uint*)p) == 0x20202020) // ' ' == 0x20
                        p += 4;
                    // Skip over any remaining space on the line.
                    while (*p == ' ')
                        p++;
                }
                else if (config.ws == WhitespaceOptions.All || config.ws == WhitespaceOptions.OnlySpaces)
                {
                    p++;
                }
            LendSkipFourSpaces:
                if (config.ws != WhitespaceOptions.None)
                {
                    t.value = TOK.whitespace;
                    return;
                }
                continue; // skip white space
            case '\t':
            case '\v':
            case '\f':
                p++;
                if (config.ws == WhitespaceOptions.OnlyTabs ||
                    config.ws == WhitespaceOptions.All ||
                    config.ws == WhitespaceOptions.AllCondensed)
                {
                    t.value = TOK.whitespace;
                    return;
                }
                continue; // skip white space
            case '\r':
                p++;
                if (*p != '\n') // if CR stands by itself
                {
                    endOfLine();
                    if (tokenizeNewlines)
                    {
                        t.value = TOK.endOfLine;
                        tokenizeNewlines = false;
                        return;
                    }
                    else if (config.ws == WhitespaceOptions.OnlyNewLines ||
                        config.ws == WhitespaceOptions.All ||
                        config.ws == WhitespaceOptions.AllCondensed)
                    {
                        t.value = TOK.endOfLine;
                        return;
                    }
                }
                if (config.ws == WhitespaceOptions.All ||
                    config.ws == WhitespaceOptions.AllCondensed)
                {
                    t.value = TOK.whitespace;
                    return;
                }
                continue; // skip white space
            case '\n':
                p++;
                endOfLine();
                if (tokenizeNewlines)
                {
                    t.value = TOK.endOfLine;
                    tokenizeNewlines = false;
                    return;
                }
                else if (config.ws == WhitespaceOptions.OnlyNewLines ||
                    config.ws == WhitespaceOptions.All ||
                    config.ws == WhitespaceOptions.AllCondensed)
                {
                    t.value = TOK.endOfLine;
                    return;
                }
                continue; // skip white space
            case '0':
                if (!isZeroSecond(p[1]))        // if numeric literal does not continue
                {
                    ++p;
                    t.unsvalue = 0;
                    t.value = TOK.int32Literal;
                    return;
                }
                goto Lnumber;

            case '1': .. case '9':
                if (!isDigitSecond(p[1]))       // if numeric literal does not continue
                {
                    t.unsvalue = *p - '0';
                    ++p;
                    t.value = TOK.int32Literal;
                    return;
                }
            Lnumber:
                t.value = number(t);
                return;

            case '\'':
                if (issinglechar(p[1]) && p[2] == '\'')
                {
                    t.unsvalue = p[1];        // simple one character literal
                    t.value = TOK.charLiteral;
                    p += 3;
                }
                else if (Ccompile)
                {
                    clexerCharConstant(*t, 0);
                }
                else
                {
                    t.value = charConstant(t);
                }
                return;

            case 'u':
            case 'U':
            case 'L':
                if (!Ccompile)
                    goto case_ident;
                if (p[1] == '\'')       // C wide character constant
                {
                    char c = *p;
                    if (c == 'L')       // convert L to u or U
                        c = (wchar_tsize == 4) ? 'u' : 'U';
                    ++p;
                    clexerCharConstant(*t, c);
                    return;
                }
                else if (p[1] == '\"')  // C wide string literal
                {
                    const c = *p;
                    ++p;
                    escapeStringConstant(t);
                    t.postfix = c == 'L' ? (wchar_tsize == 2 ? 'w' : 'd') :
                                c == 'u' ? 'w' :
                                'd';
                    return;
                }
                else if (p[1] == '8' && p[2] == '\"') // C UTF-8 string literal
                {
                    p += 2;
                    escapeStringConstant(t);
                    return;
                }
                goto case_ident;

            case 'r':
                if (Ccompile || p[1] != '"')
                    goto case_ident;
                p++;
                goto case '`';
            case '`':
                if (Ccompile)
                    goto default;
                wysiwygStringConstant(t);
                return;
            case 'q':
                if (Ccompile)
                    goto case_ident;
                if (p[1] == '"')
                {
                    p++;
                    delimitedStringConstant(t);
                    return;
                }
                else if (p[1] == '{')
                {
                    p++;
                    tokenStringConstant(t);
                    return;
                }
                else
                    goto case_ident;
            case '"':
                escapeStringConstant(t);
                return;
            case 'a':
            case 'b':
            case 'c':
            case 'd':
            case 'e':
            case 'f':
            case 'g':
            case 'h':
            case 'i':
            case 'j':
            case 'k':
            case 'l':
            case 'm':
            case 'n':
            case 'o':
            case 'p':
                /*case 'q': case 'r':*/
            case 's':
            case 't':
            //case 'u':
            case 'v':
            case 'w':
            case 'x':
            case 'y':
            case 'z':
            case 'A':
            case 'B':
            case 'C':
            case 'D':
            case 'E':
            case 'F':
            case 'G':
            case 'H':
            case 'I':
            case 'J':
            case 'K':
            //case 'L':
            case 'M':
            case 'N':
            case 'O':
            case 'P':
            case 'Q':
            case 'R':
            case 'S':
            case 'T':
            //case 'U':
            case 'V':
            case 'W':
            case 'X':
            case 'Y':
            case 'Z':
            case '_':
            case_ident:
                {
                    while (1)
                    {
                        const c = *++p;
                        if (isidchar(c))
                            continue;
                        else if (c & 0x80)
                        {
                            const s = p;
                            const u = decodeUTF();
                            if (isUniAlpha(u))
                                continue;
                            error("char 0x%04x not allowed in identifier", u);
                            p = s;
                        }
                        break;
                    }
                    Identifier id = Identifier.idPool(cast(char*)t.ptr, cast(uint)(p - t.ptr));
                    t.ident = id;
                    t.value = cast(TOK)id.getValue();

                    anyToken = 1;

                    /* Different keywords for C and D
                     */
                    if (Ccompile)
                    {
                        if (t.value != TOK.identifier)
                        {
                            t.value = Ckeywords[t.value];  // filter out D keywords
                        }
                    }
                    else if (t.value >= FirstCKeyword)
                        t.value = TOK.identifier;       // filter out C keywords

                    else if (*t.ptr == '_') // if special identifier token
                    {
                        // Lazy initialization
                        TimeStampInfo.initialize(t.loc);

                        if (id == Id.DATE)
                        {
                            t.ustring = TimeStampInfo.date.ptr;
                            goto Lstr;
                        }
                        else if (id == Id.TIME)
                        {
                            t.ustring = TimeStampInfo.time.ptr;
                            goto Lstr;
                        }
                        else if (id == Id.VENDOR)
                        {
                            t.ustring = global.vendor.xarraydup.ptr;
                            goto Lstr;
                        }
                        else if (id == Id.TIMESTAMP)
                        {
                            t.ustring = TimeStampInfo.timestamp.ptr;
                        Lstr:
                            t.value = TOK.string_;
                            t.postfix = 0;
                            t.len = cast(uint)strlen(t.ustring);
                        }
                        else if (id == Id.VERSIONX)
                        {
                            t.value = TOK.int64Literal;
                            t.unsvalue = global.versionNumber();
                        }
                        else if (id == Id.EOFX)
                        {
                            t.value = TOK.endOfFile;
                            // Advance scanner to end of file
                            while (!(*p == 0 || *p == 0x1A))
                                p++;
                        }
                    }
                    //printf("t.value = %d\n",t.value);
                    return;
                }
            case '/':
                p++;
                switch (*p)
                {
                case '=':
                    p++;
                    t.value = TOK.divAssign;
                    return;
                case '*':
                    p++;
                    startLoc = loc();
                    while (1)
                    {
                        while (1)
                        {
                            const c = *p;
                            switch (c)
                            {
                            case '/':
                                break;
                            case '\n':
                                endOfLine();
                                p++;
                                continue;
                            case '\r':
                                p++;
                                if (*p != '\n')
                                    endOfLine();
                                continue;
                            case 0:
                            case 0x1A:
                                error("unterminated /* */ comment");
                                p = end;
                                t.loc = loc();
                                t.value = TOK.endOfFile;
                                return;
                            default:
                                if (c & 0x80)
                                {
                                    const u = decodeUTF();
                                    if (u == PS || u == LS)
                                        endOfLine();
                                }
                                p++;
                                continue;
                            }
                            break;
                        }
                        p++;
                        if (p[-2] == '*' && p - 3 != t.ptr)
                            break;
                    }
                    if (config.comm != CommentOptions.None)
                    {
                        t.loc = startLoc;
                        t.value = TOK.comment;
                        return;
                    }
                    else if (config.doc && t.ptr[2] == '*' && p - 4 != t.ptr)
                    {
                        // if /** but not /**/
                        getDocComment(t, lastLine == startLoc.linnum, startLoc.linnum - lastDocLine > 1);
                        lastDocLine = scanloc.linnum;
                    }
                    continue;
                case '/': // do // style comments
                    startLoc = loc();
                    while (1)
                    {
                        const c = *++p;
                        switch (c)
                        {
                        case '\n':
                            break;
                        case '\r':
                            if (p[1] == '\n')
                                p++;
                            break;
                        case 0:
                        case 0x1A:
                            if (config.comm != CommentOptions.None)
                            {
                                p = end;
                                t.loc = startLoc;
                                t.value = TOK.comment;
                                return;
                            }
                            if (config.doc && t.ptr[2] == '/')
                            {
                                getDocComment(t, lastLine == startLoc.linnum, startLoc.linnum - lastDocLine > 1);
                                lastDocLine = scanloc.linnum;
                            }
                            p = end;
                            t.loc = loc();
                            t.value = TOK.endOfFile;
                            return;
                        default:
                            if (c & 0x80)
                            {
                                const u = decodeUTF();
                                if (u == PS || u == LS)
                                    break;
                            }
                            continue;
                        }
                        break;
                    }
                    if (config.comm != CommentOptions.None)
                    {
                        // commented this so we can tokenize new lines after comments
                        // p++;
                        // endOfLine();
                        t.loc = startLoc;
                        t.value = TOK.comment;
                        return;
                    }
                    if (config.doc && t.ptr[2] == '/')
                    {
                        getDocComment(t, lastLine == startLoc.linnum, startLoc.linnum - lastDocLine > 1);
                        lastDocLine = scanloc.linnum;
                    }
                    p++;
                    endOfLine();
                    continue;
                case '+':
                    if (!Ccompile)
                    {
                        int nest;
                        startLoc = loc();
                        p++;
                        nest = 1;
                        while (1)
                        {
                            char c = *p;
                            switch (c)
                            {
                            case '/':
                                p++;
                                if (*p == '+')
                                {
                                    p++;
                                    nest++;
                                }
                                continue;
                            case '+':
                                p++;
                                if (*p == '/')
                                {
                                    p++;
                                    if (--nest == 0)
                                        break;
                                }
                                continue;
                            case '\r':
                                p++;
                                if (*p != '\n')
                                    endOfLine();
                                continue;
                            case '\n':
                                endOfLine();
                                p++;
                                continue;
                            case 0:
                            case 0x1A:
                                error("unterminated /+ +/ comment");
                                p = end;
                                t.loc = loc();
                                t.value = TOK.endOfFile;
                                return;
                            default:
                                if (c & 0x80)
                                {
                                    uint u = decodeUTF();
                                    if (u == PS || u == LS)
                                        endOfLine();
                                }
                                p++;
                                continue;
                            }
                            break;
                        }
                        if (config.comm != CommentOptions.None)
                        {
                            t.loc = startLoc;
                            t.value = TOK.comment;
                            return;
                        }
                        if (config.doc && t.ptr[2] == '+' && p - 4 != t.ptr)
                        {
                            // if /++ but not /++/
                            getDocComment(t, lastLine == startLoc.linnum, startLoc.linnum - lastDocLine > 1);
                            lastDocLine = scanloc.linnum;
                        }
                        continue;
                    }
                    break;
                default:
                    break;
                }
                t.value = TOK.div;
                return;
            case '.':
                p++;
                if (isdigit(*p))
                {
                    /* Note that we don't allow ._1 and ._ as being
                     * valid floating point numbers.
                     */
                    p--;
                    t.value = inreal(t);
                }
                else if (p[0] == '.')
                {
                    if (p[1] == '.')
                    {
                        p += 2;
                        t.value = TOK.dotDotDot;
                    }
                    else
                    {
                        p++;
                        t.value = TOK.slice;
                    }
                }
                else
                    t.value = TOK.dot;
                return;
            case '&':
                p++;
                if (*p == '=')
                {
                    p++;
                    t.value = TOK.andAssign;
                }
                else if (*p == '&')
                {
                    p++;
                    t.value = TOK.andAnd;
                }
                else
                    t.value = TOK.and;
                return;
            case '|':
                p++;
                if (*p == '=')
                {
                    p++;
                    t.value = TOK.orAssign;
                }
                else if (*p == '|')
                {
                    p++;
                    t.value = TOK.orOr;
                }
                else
                    t.value = TOK.or;
                return;
            case '-':
                p++;
                if (*p == '=')
                {
                    p++;
                    t.value = TOK.minAssign;
                }
                else if (*p == '-')
                {
                    p++;
                    t.value = TOK.minusMinus;
                }
                else if (*p == '>')
                {
                    ++p;
                    t.value = TOK.arrow;
                }
                else
                    t.value = TOK.min;
                return;
            case '+':
                p++;
                if (*p == '=')
                {
                    p++;
                    t.value = TOK.addAssign;
                }
                else if (*p == '+')
                {
                    p++;
                    t.value = TOK.plusPlus;
                }
                else
                    t.value = TOK.add;
                return;
            case '<':
                p++;
                if (*p == '=')
                {
                    p++;
                    t.value = TOK.lessOrEqual; // <=
                }
                else if (*p == '<')
                {
                    p++;
                    if (*p == '=')
                    {
                        p++;
                        t.value = TOK.leftShiftAssign; // <<=
                    }
                    else
                        t.value = TOK.leftShift; // <<
                }
                else if (*p == ':' && Ccompile)
                {
                    ++p;
                    t.value = TOK.leftBracket;  // <:
                }
                else if (*p == '%' && Ccompile)
                {
                    ++p;
                    t.value = TOK.leftCurly;    // <%
                }
                else
                    t.value = TOK.lessThan; // <
                return;
            case '>':
                p++;
                if (*p == '=')
                {
                    p++;
                    t.value = TOK.greaterOrEqual; // >=
                }
                else if (*p == '>')
                {
                    p++;
                    if (*p == '=')
                    {
                        p++;
                        t.value = TOK.rightShiftAssign; // >>=
                    }
                    else if (*p == '>')
                    {
                        p++;
                        if (*p == '=')
                        {
                            p++;
                            t.value = TOK.unsignedRightShiftAssign; // >>>=
                        }
                        else
                            t.value = TOK.unsignedRightShift; // >>>
                    }
                    else
                        t.value = TOK.rightShift; // >>
                }
                else
                    t.value = TOK.greaterThan; // >
                return;
            case '!':
                p++;
                if (*p == '=')
                {
                    p++;
                    t.value = TOK.notEqual; // !=
                }
                else
                    t.value = TOK.not; // !
                return;
            case '=':
                p++;
                if (*p == '=')
                {
                    p++;
                    t.value = TOK.equal; // ==
                }
                else if (*p == '>')
                {
                    p++;
                    t.value = TOK.goesTo; // =>
                }
                else
                    t.value = TOK.assign; // =
                return;
            case '~':
                p++;
                if (*p == '=')
                {
                    p++;
                    t.value = TOK.concatenateAssign; // ~=
                }
                else
                    t.value = TOK.tilde; // ~
                return;
            case '^':
                p++;
                if (*p == '^')
                {
                    p++;
                    if (*p == '=')
                    {
                        p++;
                        t.value = TOK.powAssign; // ^^=
                    }
                    else
                        t.value = TOK.pow; // ^^
                }
                else if (*p == '=')
                {
                    p++;
                    t.value = TOK.xorAssign; // ^=
                }
                else
                    t.value = TOK.xor; // ^
                return;
            case '(':
                p++;
                t.value = TOK.leftParenthesis;
                return;
            case ')':
                p++;
                t.value = TOK.rightParenthesis;
                return;
            case '[':
                p++;
                t.value = TOK.leftBracket;
                return;
            case ']':
                p++;
                t.value = TOK.rightBracket;
                return;
            case '{':
                p++;
                t.value = TOK.leftCurly;
                return;
            case '}':
                p++;
                t.value = TOK.rightCurly;
                return;
            case '?':
                p++;
                t.value = TOK.question;
                return;
            case ',':
                p++;
                t.value = TOK.comma;
                return;
            case ';':
                p++;
                t.value = TOK.semicolon;
                return;
            case ':':
                p++;
                if (*p == ':')
                {
                    ++p;
                    t.value = TOK.colonColon;
                }
                else if (*p == '>' && Ccompile)
                {
                    ++p;
                    t.value = TOK.rightBracket;
                }
                else
                    t.value = TOK.colon;
                return;
            case '$':
                p++;
                t.value = TOK.dollar;
                return;
            case '@':
                p++;
                t.value = TOK.at;
                return;
            case '*':
                p++;
                if (*p == '=')
                {
                    p++;
                    t.value = TOK.mulAssign;
                }
                else
                    t.value = TOK.mul;
                return;
            case '%':
                p++;
                if (*p == '=')
                {
                    p++;
                    t.value = TOK.modAssign;
                }
                else if (*p == '>' && Ccompile)
                {
                    ++p;
                    t.value = TOK.rightCurly;
                }
                else if (*p == ':' && Ccompile)
                {
                    goto case '#';      // %: means #
                }
                else
                    t.value = TOK.mod;
                return;
            case '#':
                {
                    // https://issues.dlang.org/show_bug.cgi?id=22825
                    // Special token sequences are terminated by newlines,
                    // and should not be skipped over.
                    this.tokenizeNewlines = true;
                    p++;
                    if (parseSpecialTokenSequence())
                        continue;
                    t.value = TOK.pound;
                    return;
                }
            default:
                {
                    dchar c = *p;
                    if (c & 0x80)
                    {
                        c = decodeUTF();
                        // Check for start of unicode identifier
                        if (isUniAlpha(c))
                            goto case_ident;
                        if (c == PS || c == LS)
                        {
                            endOfLine();
                            p++;
                            if (tokenizeNewlines)
                            {
                                t.value = TOK.endOfLine;
                                tokenizeNewlines = false;
                                return;
                            }
                            continue;
                        }
                    }
                    if (c < 0x80 && isprint(c))
                        error("character '%c' is not a valid token", c);
                    else
                        error("character 0x%02x is not a valid token", c);
                    p++;
                    continue;
                }
            }
        }
    }

}

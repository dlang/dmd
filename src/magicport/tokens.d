
import std.ascii;
import std.array;
import std.string;
import std.algorithm;
import std.stdio;

enum TokenType
{
    TOKstring,
    TOKop,
    TOKchar,
    TOKnum,
    TOKid,
    TOKkey,
    TOKcomment,
    TOKeof
};
alias TokenType.TOKstring  TOKstring;
alias TokenType.TOKop      TOKop;
alias TokenType.TOKchar    TOKchar;
alias TokenType.TOKnum     TOKnum;
alias TokenType.TOKid      TOKid;
alias TokenType.TOKkey     TOKkey;
alias TokenType.TOKcomment TOKcomment;
alias TokenType.TOKeof     TOKeof;

struct Token
{
    string file;
    size_t line;
    string text;
    TokenType type;
    bool flag;
};

struct Lexer
{
    string file;
    size_t line = 1;
    string t;
    Token current;
    bool skipcomments = false;

    this(string t, string fn)
    {
        this.file = fn;
        this.t = t;
        popFront();
    }

    bool empty() { return current.type == TOKeof; }
    Token front() { return current; }
    void popFront()
    {
        auto f = t;
        while (current.type != TOKeof)
        {
            if (t.length >= 1 && isWhite(t[0])) SkipWhitespace();
            else if (skipcomments && t.startsWith("/*")) ReadComment();
            else if (skipcomments && t.startsWith("//")) ReadLineComment();
            else break;
        }
        if (t.empty)
        {
            current = Token(file, line, null, TOKeof);
            return;
        }

        if (0) {}
        else if (t.startsWith("\"")) current = ReadStringLiteral();
        else if (t.startsWith("'")) current = ReadCharLiteral();
        else if (t.startsWith("/*")) current = ReadComment();
        else if (t.startsWith("//")) current = ReadLineComment();
        else if (t.length >= 1 && (isAlpha(t[0]) || t[0] == '_')) current = ReadIdentifier();
        else if (t.length >= 1 && isDigit(t[0])) current = ReadNumber();
        else current = ReadOperator();
        line += count(f[0..$-t.length], '\n');
        current.line = line;
        current.file = file;
        //writeln(current);
    }

    void SkipWhitespace()
    {
        assert(isWhite(t[0]));
        auto i = 0;
        while(!t.empty && isWhite(t.front))
            t.popFront();
    }

    Token ReadComment()
    {
        assert(t.startsWith("/*"));
        size_t i = 2;
        bool found = false;

        while (i < t.length)
        {
            if (t[i..$].startsWith("*/")) break;
            i++;
        }

        assert(t[i..$].startsWith("*/"));
        auto tk = Token(file, line, t[0..i+2], TOKcomment);
        t = t[i+2..$];
        return tk;
    }

    Token ReadLineComment()
    {
        assert(t.startsWith("//"));
        size_t i = 2;
        while(i < t.length && t[i] != '\n')
            i++;
        auto tk = Token(file, line, t[0..i], TOKcomment);
        t = t[i..$];
        return tk;
    }

    Token ReadStringLiteral()
    {
        assert(t[0] == '"');

        bool Escape = false;
        auto s = "\"";
        auto i = 1;

        while( i < t.length && !(t[i] == '"' && !Escape) )
        {
            if (t[i] == '\\' || Escape)
            {
                Escape = !Escape;
                if (t[i] == '\n')
                {
                    s = s[0..$-1];
                    i++;
                    continue;
                }
            }
            s ~= t[i];
            ++i;
        }

        assert(t[i] == '"');
        s ~= t[i];
        t = t[i+1..$];
        return Token(file, line, s, TOKstring);
    }

    Token ReadCharLiteral()
    {
        assert(t[0] == '\'');

        bool Escape = false;
        auto i = 1;

        while( i < t.length && !(t[i] == '\'' && !Escape) )
        {
            if (t[i] == '\\' || Escape)
                Escape = !Escape;
            ++i;
        }

        assert(t[i] == '\'');
        auto tk = Token(file, line, t[0..i+1], TOKchar);
        t = t[i+1..$];
        return tk;
    }

    Token ReadIdentifier()
    {
        assert(t[0] == '_' || isAlpha(t[0]));

        auto i = 1;
        while( i < t.length && (t[i] == '_' || isAlpha(t[i]) || isDigit(t[i])))
            ++i;
        auto tk = Token(file, line, t[0..i], TOKid, t[i] == '(');
        t = t[i..$];
        if (t[0] != ' ')
            tk.flag = true;
        return tk;
    }

    Token ReadNumber()
    {
        auto i = 1;
        while (i < t.length &&
            (
                isDigit(t[i]) ||
                t[i] == '.' ||
                t[i] == 'x' ||
                t[i] == 'X' ||
                (t[i] >= 'a' && t[i] <= 'f') ||
                (t[i] >= 'A' && t[i] <= 'F') ||
                (t[i] == 'u' || t[i] == 'U') ||
                (t[i] == 'l' || t[i] == 'L')
            ))
            ++i;
        auto tk = Token(file, line, t[0..i], TOKnum);
        t = t[i..$];
        return tk;
    }

    Token ReadOperator()
    {
        static immutable operators =
        [
            "#ifndef",
            "#endif", "#ifdef",
            "#else", "#elif",
            "!<>=",
            "#if", "<<=", ">>=", "<>=", "!<>", "!<=", "!>=", "...",
            "!<", "!>", "++", "<>", "--", "==", "!=", ">=", "<=", "&&", "||", "<<", ">>", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "->", "::", "##",
            "=", "+", "-", "*", "/", "%", ">", "<", "!", "~", "&", "|", "^", "[", "]", ".", "(", ")", ":", "?", "{", "}", ";", ",", "#", "\\"
        ];
        size_t l;
        foreach(o; operators)
        {
            if (t.startsWith(o))
            {
                l = o.length;
                break;
            }
        }
        assert(l, '`' ~ t[0..min(50,$)] ~ '`');

        auto tk = Token(file, line, t[0..l], TOKop);
        t = t[l..$];
        return tk;
    }
};

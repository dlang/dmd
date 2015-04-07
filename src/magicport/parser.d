
import core.stdc.stdlib;

import std.conv;
import std.array;
import std.algorithm;
import std.stdio;

import tokens;
import ast;

Token[] tx;
Token t;
string currentfile;
void error(size_t line = __LINE__, T...)(string format, T args)
{
    writef("Error: %s(%s): ", currentfile, t.line);
    writefln(format, args);
    core.stdc.stdlib.exit(1);
    assert(0, "at: " ~ to!string(line));
}
void fail(size_t line = __LINE__)
{
    error("Unknown at line %d", line);
}
string check(string s, size_t line = __LINE__)
{
    if (t.text != s)
        error("'%s' expected, not '%s'", s, t.text);
    // if (s == "(" || s == "[" || s == "{")
    // {
        // level++;
        // marker ~= s;
    // }
    // else if (s == ")" || s == "]" || s == "}")
    // {
        // if (!level)
            // writeln(line);
        // level--;
        // marker = marker[0..$-1];
    // }
    return nextToken();
}
string nextToken()
{
    auto l = t.text;
    if (tx.empty)
        t = Token("__file__", 0, null, TOKeof);
    else
    {
        t = tx.front;
        tx.popFront();
    }
    if (l == "(" || l == "[" || l == "{")
    {
        level++;
        marker ~= l;
    }
    else if (l == ")" || l == "]" || l == "}")
    {
        level--;
        marker = marker[0..$-1];
    }
    return l;
}
// void skipComment(size_t line = __LINE__)
// {
    // while(t.type == TOKcomment)
    // {
        // writefln("skipped comment(%d): %s", line, nextToken());
    // }
// }
string trailingComment(string s = ";")
{
    auto line = t.line;
    check(s);
    if (t.type == TOKcomment && t.line == line)
        return nextToken();
    return null;
}

int level;
string[] marker;
// void enter(string s, size_t line = __LINE__) { check(s, line); level++; marker ~= s; }
// void exit(string s, size_t line = __LINE__) { check(s, line); level--; marker = marker[0..$-1]; }
void enter(string s, size_t line = __LINE__) { check(s, line); }
void exit(string s, size_t line = __LINE__) { check(s, line); }

int inFunc;

Module parse(Token[] tokens, string fn)
{
    tx = tokens;
    currentfile = fn;
    Declaration[] decls;

    nextToken();

    if (t.type == TOKcomment)
    {
        // writeln("Module comment: ");
        parseComment();
    }

    while (1)
    {
        auto lastt = t;
        switch(t.text)
        {
        case "":
            assert(t.type == TOKeof);
            return new Module(fn, decls);
        default:
            decls ~= parseDecl();
            break;
        };
        assert(lastt.text.ptr != t.text.ptr);
    }
    fail();
}

/********************************************************/

Declaration parsePreprocessor(ref bool hascomment, string comment)
{
    debug(PARSE) writeln("parsePreprocessor");
    check("#");
    if (t.type != TOKid)
        fail();
    switch(t.text)
    {
    case "include":
        nextToken();
        string fn;
        if (t.text == "<")
        {
            nextToken();
            while (t.text != ">")
            {
                fn ~= t.text;
                nextToken();
            }
            trailingComment(">");
        } else if (t.type == TOKstring)
        {
            fn = t.text[1..$-1];
            trailingComment(t.text);
        }
        hascomment = false;
        return new ImportDeclaration(fn);
    case "define":
        nextToken();
        if (t.type != TOKid)
            fail();
        auto flag = t.flag;
        auto xline = t.line;
        auto id = parseIdent();
        if (t.text == "(" && flag)
        {
            hascomment = false;
            enter("(");
            string[] params;
            if (t.text != ")")
            do
            {
                params ~= parseIdent();
                if (t.text != ")")
                    check(",");
            } while (t.text != ")");
            auto line = t.line;
            exit(")");
            if (t.line != line)
                return new MacroDeclaration(id, params, null, comment);
            auto e = parseExpr();
            /*Token[] mbody;
            while (line == t.line)
            {
                if (t.text == "\\")
                    line++;
                else
                    mbody ~= t;
                nextToken();
            }*/
            return new MacroDeclaration(id, params, e, comment);
        } else {
            Expression e;
            if (t.line == xline)
                e = parseExpr();
            hascomment = false;
            return new VarDeclaration(null, id, e ? new ExprInit(e) : null, STCconst, comment, null);
        }
    case "undef":
        nextToken();
        return new MacroUnDeclaration(parseIdent());
    case "pragma":
        nextToken();
        auto line = t.line;
        auto s = "#pragma ";
        while(t.line == line && t.type != TOKeof)
            s ~= nextToken();
        return new DummyDeclaration(s);
    case "error":
        nextToken();
        auto line = t.line;
        string s;
        if (t.type == TOKstring)
        {
            s = nextToken();
        }
        else
        {
            s = nextToken();
            while(t.line == line && t.type != TOKeof)
            {
                s ~= " " ~ nextToken();
            }
            s = "\"" ~ s ~ "\"";
        }
        return new ErrorDeclaration(new LitExpr(s));
    default:
        fail();
        assert(0);
    }
}

/********************************************************/

Expression parseExpr()
{
    debug(PARSE) writeln("parseExpr");
    return parseCommaExpr();
}

Expression parseCommaExpr()
{
    auto e = parseAssignExpr();
    while (t.text == ",")
    {
        nextToken();
        e = new CommaExpr(e, parseAssignExpr());
    }
    return e;
}

auto assignOps = ["=", "|=", "&=", "+=", ">>=", "*=", "-=", "/=", "^=", "%=", "<<="];

Expression parseAssignExpr()
{
    auto e = parseCondExpr();
    if (assignOps.canFind(t.text))
    {
        auto op = nextToken();
        e = new AssignExpr(op, e, parseAssignExpr());
    }
    return e;
}

Expression parseCondExpr()
{
    auto ec = parseOrOrExpr();
    if (t.text == "?")
    {
        nextToken();
        auto e1 = parseExpr();
        check(":");
        auto e2 = parseCondExpr();
        ec = new CondExpr(ec, e1, e2);
    }
    return ec;
}

Expression parseOrOrExpr()
{
    auto e = parseAndAndExpr();
    while (t.text == "||")
    {
        nextToken();
        e = new OrOrExpr(e, parseAndAndExpr());
    }
    return e;
}

Expression parseAndAndExpr()
{
    auto e = parseOrExpr();
    while (t.text == "&&")
    {
        nextToken();
        e = new AndAndExpr(e, parseOrExpr());
    }
    return e;
}

Expression parseOrExpr()
{
    auto e = parseXorExpr();
    while (t.text == "|")
    {
        nextToken();
        e = new OrExpr(e, parseXorExpr());
    }
    return e;
}

Expression parseXorExpr()
{
    auto e = parseAndExpr();
    while (t.text == "^")
    {
        nextToken();
        e = new XorExpr(e, parseAndExpr());
    }
    return e;
}

Expression parseAndExpr()
{
    auto e = parseCmpExpr();
    while (t.text == "&")
    {
        nextToken();
        e = new AndExpr(e, parseCmpExpr());
    }
    return e;
}

auto cmpOps = ["==", "!=", "<", ">", "<=", ">=", "<>=", "<>", "!<>=", "!<>", "!<=", "!<", "!>=", "!>"];

Expression parseCmpExpr()
{
    auto e = parseShiftExpr();
    while (cmpOps.canFind(t.text))
    {
        auto op = nextToken();
        e = new CmpExpr(op, e, parseShiftExpr());
    }
    return e;
}

Expression parseShiftExpr()
{
    auto e = parseAddExpr();
    while (t.text == "<<" || t.text == ">>")
    {
        auto op = nextToken();
        e = new AddExpr(op, e, parseAddExpr());
    }
    return e;
}

Expression parseAddExpr()
{
    auto e = parseMulExpr();
    while (t.text == "+" || t.text == "-")
    {
        auto op = nextToken();
        e = new AddExpr(op, e, parseMulExpr());
    }
    return e;
}

Expression parseMulExpr()
{
    auto e = parseUnaryExpr();
    while (t.text == "*" || t.text == "/" || t.text == "%")
    {
        auto op = nextToken();
        e = new MulExpr(op, e, parseUnaryExpr());
    }
    return e;
}

Expression parseUnaryExpr()
{
    switch(t.text)
    {
    case "*":
        nextToken();
        return new PtrExpr(parseUnaryExpr());
    case "!":
        nextToken();
        return new NotExpr(parseUnaryExpr());
    case "new":
        nextToken();
        Expression placement;
        if (t.text == "(")
        {
            nextToken();
            placement = parseAssignExpr();
            check(")");
        }
        auto type = parseType();
        Expression dim;
        if (t.text == "[")
        {
            enter("[");
            dim = parseExpr();
            exit("]");
            //type = new ArrayType(type, null);
        }
        Expression[] args;
        if (t.text == "(")
            args = parseArgs();
        return new NewExpr(type, args, dim, placement);
    case "&":
        nextToken();
        return new AddrExpr(parseUnaryExpr());
    case "-":
        nextToken();
        return new NegExpr(parseUnaryExpr());
    case "~":
        nextToken();
        return new ComExpr(parseUnaryExpr());
    case "--", "++":
        auto op = nextToken();
        return new PreExpr(op, parseUnaryExpr());
    case "delete":
        nextToken();
        return new DeleteExpr(parseUnaryExpr());
    case "#":
        nextToken();
        return new StringofExpr(parseUnaryExpr());
    default:
        return parsePostfixExpr();
    }
}

Expression parsePostfixExpr()
{
    Expression e = parsePrimaryExpr();
    while (true)
    {
        if (t.text == "." || t.text == "->" || t.text == "::")
        {
            auto op = nextToken();
            auto id = parseIdent();
            e = new DotIdExpr(op, e, id);
        }
        else if (t.text == "(")
        {
            auto args = parseArgs();
            e = new CallExpr(e, args);
        }
        else if (t.text == "++" || t.text == "--")
        {
            e = new PostExpr(nextToken(), e);
        }
        else if (t.text == "[")
        {
            e = new IndexExpr(e, parseArgs("["));
        }
        else
        {
            return e;
        }
    }
}

Expression parsePrimaryExpr()
{
    switch(t.type)
    {
    case TOKnum:
    case TOKchar:
        auto e = t.text;
        nextToken();
        return new LitExpr(e);
    case TOKstring:
        string e;
        e ~= nextToken()[0..$-1];
        while(t.type == TOKstring)
            e ~= nextToken()[1..$-1];
        e ~= "\"";
        return new LitExpr(e);
    case TOKid:
        if (t.text == "sizeof")
        {
            Expression e;
            nextToken();
            enter("(");
            if (isType())
                e = new SizeofExpr(parseType());
            else
                e = new SizeofExpr(parseExpr());
            exit(")");
            return e;
        }
        if (t.text == "const_cast" || t.text == "static_cast")
        {
            nextToken();
            check("<");
            auto type = parseType();
            check(">");
            return new CastExpr(type, parseUnaryExpr());
        }
        else if (t.text == "static" || t.text == "STATIC" || t.text == "struct" || t.text == "const" || t.text == "union" || t.text == "class" || t.text == "enum" || t.text == "typedef" || t.text == "register")
        {
            return new DeclarationExpr(parseDecl(null, true));
        }
        else if (isType())
        {
            auto type = parseType();
            if (t.type == TOKid)
                return new DeclarationExpr(parseDecl(type, true));
            return new IdentExpr(type.id);
        }
        return new IdentExpr(parseIdent());
    default:
        switch (t.text)
        {
        case "(":
            auto save = tx;
            nextToken();
            if (!isType())
            {
notCast:
                auto e = parseExpr();
                e.hasParens = true;
                check(")");
                return e;
            }
            auto type = parseType();
            if (t.text != ")")
            {
                tx = save;
                nextToken();
                goto notCast;
            }
            check(")");
            return new CastExpr(type, parseUnaryExpr());
        case "::":
            nextToken();
            return new OuterScopeExpr(parseExpr());
        default:
            break;
        }
    }
    error("Unrecognised expression: '%s'", t.text);
    assert(0);
}

Expression[] parseArgs(string delim = "(")
{
    auto map = ["(" : ")", "[" : "]", "{" : "}"];
    Expression[] e;
    enter(delim);
    if (t.text != map[delim])
    {
        do
        {
            e ~= parseAssignExpr();
            if (t.text != map[delim])
                check(",");
        } while (t.text != map[delim]);
    }
    exit(map[delim]);
    return e;
}

Init parseInit()
{
    if (t.text == "{")
    {
        Init[] e;
        enter("{");
        while (t.text != "}")
        {
            e ~= parseInit();
            if (t.text != "}")
                check(",");
        }
        exit("}");
        return new ArrayInit(e);
    } else {
        return new ExprInit(parseAssignExpr());
    }
}

/********************************************************/

STC parseStorageClasses()
{
    STC stc;
    while(true)
    {
        switch (t.text)
        {
        case "inline":
            nextToken();
            break;
        case "static":
        case "STATIC":
            nextToken();
            stc |= STCstatic;
            break;
        case "virtual":
            nextToken();
            stc |= STCvirtual;
            break;
        case "extern":
            nextToken();
            if (t.text == "\"C\"")
            {
                stc |= STCexternc;
                nextToken();
            } else
                stc |= STCextern;
            break;
        default:
            return stc;
        }
    }
}

Declaration parseDecl(Type tx = null, bool inExpr = false)
{
    STC stc;
    // writeln("parseDecl ", t.text);
    bool destructor;
    string comment;
    bool hascomment;
    scope(exit) assert(!hascomment, text(t.line));
    if (t.type == TOKcomment)
    {
        comment = parseComment();
        hascomment = true;
    }
    if (t.text == "template")
    {
        nextToken();
        check("<");
        check("typename");
        check("TYPE");
        check(">");
        check("struct");
        check("Array");
        check(";");
        hascomment = false;
        return new DummyDeclaration("template<typename TYPE> struct Array;");
    }
    else if (t.text == "~")
    {
        destructor = true;
        nextToken();
        tx = new ClassType(t.text);
        goto getid;
    } else if (t.text == "private" || t.text == "public")
    {
        auto p = nextToken();
        check(":");
        return new ProtDeclaration(p);
    } else if (t.text == "#")
    {
        return parsePreprocessor(hascomment, comment);
    } else if ((t.text == "#if" || t.text == "#ifdef" || t.text == "#ifndef") && !inExpr)
    {
        auto ndef = (t.text == "#ifndef");
        auto def = (t.text == "#ifdef" || t.text == "#ifndef");
        auto tsave = t;
        nextToken();
        auto e = def ? new IdentExpr(parseIdent()) : parseExpr();
        if (ndef)
            e = new NotExpr(e);
        auto l = level;
        Expression[] es = [e];
        Declaration[][] d;
        d.length = 1;
        while (t.text != "#endif")
        {
            if (t.text == "#else")
            {
                nextToken();
                ++es.length;
                ++d.length;
                continue;
            } else if (t.text == "#elif")
            {
                nextToken();
                ++d.length;
                es ~= parseExpr();
            }
            d[$-1] ~= parseDecl();
        }
        assert(l == level);
        trailingComment("#endif");
        hascomment = false;
        return new VersionDeclaration(es, d, t.file, t.line, comment);
    } else if (t.text == "typedef")
    {
        nextToken();
        string id;
        auto type = parseType(&id);
        if (!id.length)
            error("Identifier expected for typedef");
        if (!inExpr)
            check(";");
        hascomment = false;
        return new TypedefDeclaration(type, id, comment);
    } else if (t.text == "struct" || t.text == "union" || t.text == "class")
    {
        auto kind = nextToken();
        if (t.text == "{")
        {
            enter("{");
            Declaration[] d;
            auto save = inFunc;
            inFunc = 0;
            while(t.text != "}")
                d ~= parseDecl();
            inFunc = save;
            exit("}");
            string id;
            if (t.text != ";")
                id = parseIdent();
            if (!inExpr)
                check(";");
            return new AnonStructDeclaration(kind, id, d);
        }
        auto id = parseIdent();
        if (kind == "class" && !classTypes.lookup(id))
            error("class %s is not in the class types list", id);
        else if (kind != "class" && !structTypes.lookup(id))
            error("%s %s is not in the struct types list", kind, id);
        string s;
        if (t.text == ":")
        {
            assert(kind == "class", "non-class " ~ id ~ " is using inheritance");
            nextToken();
            if (t.text == "public")
                nextToken();
            s = parseIdent();
        }
        if (t.text == "{")
        {
            enter("{");
            Declaration[] d;
            auto save = inFunc;
            inFunc = 0;
            while(t.text != "}")
            {
                d ~= parseDecl();
            }
            inFunc = save;
            exit("}");
            if (!inExpr)
                check(";");
            hascomment = false;
            return new StructDeclaration(kind, id, d, s, comment);
        } else
        {
            assert(!s);
            tx = new ClassType(kind ~ " " ~ id);
            if (t.text == ";")
            {
                nextToken();
                hascomment = false;
                return new DummyDeclaration(kind ~ " " ~ id ~ ";");
            }
        }
    } else if (t.text == "enum")
    {
        nextToken();
        string id;
        if (t.type == TOKid)
        {
            id = parseIdent();
            //writeln(id);
        }
        if (t.text == "{")
        {
            enter("{");
            EnumMember[] members;
            while (t.text != "}")
            {
                if (t.type == TOKcomment)
                {
                    members ~= new EnumMember(null, null, parseComment);
                    continue;
                }

                auto mid = parseIdent();
                Expression val;
                string mcomment;
                if (t.text == "=")
                {
                    nextToken();
                    val = parseAssignExpr();
                }
                if (t.type == TOKcomment)
                {
                    mcomment = parseComment();
                    assert(t.text == "}");
                }
                if (t.text != "}")
                    mcomment = trailingComment(",");
                members ~= new EnumMember(mid, val, mcomment);
            }
            exit("}");
            if (!inExpr)
                check(";");
            hascomment = false;
            return new EnumDeclaration(id, members, t.file, t.line, comment);
        } else
        {
            tx = new EnumType("enum " ~ id);
        }
    }

    stc = parseStorageClasses();
    if (stc & STCexternc)
    {
        if (t.text == "{")
        {
            enter("{");
            Declaration[] d;
            while (t.text != "}")
                d ~= parseDecl();
            exit("}");
            hascomment = false;
            return new ExternCDeclaration(d, t.file, t.line, comment);
        } else {
            hascomment = false;
            return new ExternCDeclaration([parseDecl()], t.file, t.line, comment);
        }
    }
    if (t.text == "__attribute__")
    {
        nextToken();
        enter("(");
        enter("(");
        check("noreturn");
        exit(")");
        exit(")");
    }
    else if (t.text == "__declspec")
    {
        nextToken();
        enter("(");
        check("noreturn");
        exit(")");
    }
getid:
    auto type = tx ? tx : parseType();

    string id;
    bool constructor;
    if (t.text == "(")
    {
        constructor = true;
        id = (cast(ClassType)type).id;
        goto func;
    } else if (t.text == "::")
    {
        constructor = true;
        id = (cast(ClassType)type).id;
        goto memberfunc;
    }
    else if (t.text == ";")
    {
        nextToken();
        assert(cast(EnumType)type);
        return new DummyDeclaration(type.id ~ ";");
    }
    else
    {
        if (t.type != TOKid)
            fail();
    }

    id = parseIdent();
    Type parseArrayPost(Type prev)
    {
        if (t.text != "[")
            return prev;
        nextToken();
        Expression dim;
        if (t.text != "]")
            dim = parseExpr();
        check("]");
        return new ArrayType(parseArrayPost(prev), dim);
    }
    type = parseArrayPost(type);

    if (t.text == "(")
    {
        if (!inFunc)
        {
func:
            if (destructor)
                id = "~" ~ id;
            auto params = parseParams();
            if (t.text == "const")
            {
                nextToken();
                type.isConst = true;
            }
            CallExpr[] initlist;
            if (t.text == ":" && constructor)
            {
                do
                {
                    nextToken();
                    auto iid = parseIdent();
                    initlist ~= new CallExpr(new IdentExpr(iid), parseArgs());
                } while (t.text == ",");
            }
            Statement[] fbody;
            bool hasbody;
            if (t.text == "=")
            {
                // assert(stc & STCvirtual);
                nextToken();
                check("0");
                check(";");
                stc |= STCabstract;
            }
            else if (t.text == ";")
            {
                auto trailing = trailingComment(";");
                if (comment)
                    comment ~= "\n" ~ trailing;
                else
                    comment = trailing;
            }
            else if (t.text == "{") {
                inFunc++;
                check("{");
                fbody = parseStatements();
                hasbody = true;
                check("}");
                inFunc--;
            } else
                fail();
            hascomment = false;
            return new FuncDeclaration(type, id, params, fbody, stc, initlist, hasbody, comment);
        } else {
            auto args = parseArgs();
            return new ConstructDeclaration(type, id, args);
        }
    } else if (t.text == "::")
    {
memberfunc:
        nextToken();
        if (t.text == "~")
        {
            nextToken();
            destructor = true;
        }
        auto id2 = parseIdent();
        if (destructor)
            id2 = "~" ~ id2;
        while (t.text == "[")
        {
            nextToken();
            Expression dim;
            if (t.text != "]")
                dim = parseExpr();
            check("]");
            type = new ArrayType(type, dim);
        }

        if (t.text == "=")
        {
            nextToken();
            auto init = parseInit();
            hascomment = false;
            return new StaticMemberVarDeclaration(type, id, id2, init, comment, trailingComment());
        }
        if (t.text == ";")
        {
            hascomment = false;
            return new StaticMemberVarDeclaration(type, id, id2, null, comment, trailingComment());
        }
        auto params = parseParams();
        CallExpr[] initlist;
        if (t.text == ":" && constructor)
        {
            do
            {
                nextToken();
                auto iid = parseIdent();
                initlist ~= new CallExpr(new IdentExpr(iid), parseArgs());
            } while (t.text == ",");
        }
        Statement[] fbody;
        bool hasbody;
        if (t.type == TOKcomment && !comment)
            comment = parseComment();
        if (t.text == "{") {
            inFunc++;
            check("{");
            fbody = parseStatements();
            hasbody = true;
            check("}");
            inFunc--;
        } else
            fail();
        hascomment = false;
        return new FuncBodyDeclaration(type, id, id2, params, fbody, stc, initlist, hasbody, comment);
    } else if (t.text == "," || t.text == "=" || t.text == ";")
    {
        auto ids = [id];
        auto types = [type];
        if (auto pt = cast(PointerType)type)
            type = pt.next;
        Init[] inits;
        if (t.text == "=")
        {
            nextToken();
            inits = [parseInit()];
        } else
            inits = [null];
        while (t.text == ",")
        {
            nextToken();
            auto txx = type;
            while (t.text == "*")
            {
                nextToken();
                txx = new PointerType(txx);
            }
            ids ~= parseIdent();
            types ~= txx;
            if (t.text == "=")
            {
                nextToken();
                inits ~= parseInit();
            } else
                ++inits.length;
        }
        if (types.length == 1)
        {
            hascomment = false;
            string trail;
            if (!inExpr)
                trail = trailingComment();
            return new VarDeclaration(types[0], ids[0], inits[0], stc, comment, trail);
        }
        else
        {
            if (!inExpr)
                check(";");
            return new MultiVarDeclaration(types, ids, inits, stc);
        }
    } else {
        error("Unknown declaration: '%s'", t.text);
        assert(0);
    }
}

/********************************************************/

string parseIdent()
{
    debug(PARSE) writeln("parseIdent");
    if (t.type != TOKid)
        error("Identifier expected, not '%s'", t.text);
    if (t.text == "operator")
    {
        nextToken();
        return "operator " ~ nextToken();
    }
    return nextToken();
}

/********************************************************/

Type parseType(string* id = null)
{
    debug(PARSE) writeln("parseType");
    bool isConst;
    if (t.text == "const")
    {
        nextToken();
        isConst = true;
    }
    auto tx = parseBasicType(id !is null);
    tx.isConst = isConst;
    parsePostConst(tx);
    while (true)
    {
        if (t.text == "*")
        {
            nextToken();
            tx = new PointerType(tx);
            parsePostConst(tx);
        } else if (t.text == "&")
        {
            nextToken();
            tx = new RefType(tx);
        } else if (t.text == "<")
        {
            nextToken();
            auto p = parseType();
            tx = new TemplateType(tx, p);
            check(">");
        } else
            break;
    }
    if (id)
    {
        if (t.text == "(")
        {
            check("(");
            if (t.text == "*")
                check("*");
            *id = parseIdent();
            check(")");
            auto params = parseParams();
            tx = new FunctionType(tx, params);
        }
        else if (t.text != "," && t.text != ")")
            *id = parseIdent();
    }

    return tx;
}

void parsePostConst(Type tx)
{
    if (t.text == "const")
    {
        nextToken();
        tx.isConst = true;
    }
}

import typenames;

Type parseBasicType(bool flag = false)
{
    debug(PARSE) writeln("parseBasicType");
    if (t.text == "unsigned" || t.text == "signed" || t.text == "volatile" || t.text == "long" || t.text == "_Complex")
    {
        auto id = parseIdent();
        if (t.text == "char" || t.text == "short" || t.text == "int" || t.text == "float" || t.text == "long" || t.text == "double")
        {
            id ~= " ";
            id ~= parseIdent();
            if (t.text == "long" || t.text == "double")
            {
                id ~= " ";
                id ~= parseIdent();
            }
        }
        return new BasicType(id);
    }
    if (basicTypes.lookup(t.text))
        return new BasicType(parseIdent());
    else if (classTypes.lookup(t.text) || structTypes.lookup(t.text))
    {
        Type tx = new ClassType(parseIdent());
        if (t.text == "::" && flag)
        {
            nextToken();
            //tx = new QualifiedType(tx, parseIdent());
            tx = new BasicType(parseIdent());
        }
        return tx;
    }
    else
    {
        switch(t.text)
        {
        case "class", "struct", "union":
            auto kind = nextToken();
            return new ClassType(kind ~ ' ' ~ parseIdent());
        default:
            break;
        }
    }
    error("Unknown basic type %s", t.text);
    assert(0);
}

bool isType()
{
    if (basicTypes.lookup(t.text))
        return true;
    else if (classTypes.lookup(t.text))
        return true;
    else if (structTypes.lookup(t.text))
        return true;
    else
    {
        switch(t.text)
        {
        case "enum", "const", "struct":
            return true;
        default:
            break;
        }
    }
    return false;
}

/********************************************************/

Param[] parseParams()
{
    debug(PARSE) writeln("parseParams");
    Param[] p;
    enter("(");

    while(t.text != ")")
        p ~= parseParam();

    exit(")");
    return p;
}

Param parseParam()
{
    debug(PARSE) writeln("parseParam");
    if (t.text == "...")
    {
        return new Param(null, nextToken(), null);
    }
    string id;
    auto tx = parseType(&id);
    while (t.text == "[")
    {
        nextToken();
        Expression dim;
        if (t.text != "]")
            dim = parseAssignExpr();
        check("]");
        tx = new ArrayType(tx, dim);
    }
    Expression def;
    if (t.text == "=")
    {
        nextToken();
        def = parseAssignExpr();
    }
    if (t.text == ",")
        nextToken();
    return new Param(tx, id, def);
}

/********************************************************/

Statement parseCompoundStatement()
{
    debug(PARSE) writeln("parseCompoundStatement");
    enter("{");
    auto s = parseStatements();
    exit("}");
    return new CompoundStatement(s);
}

Statement[] parseStatements()
{
    debug(PARSE) writeln("parseStatements");
    Statement[] s;
    while (t.text != "}")
        s ~= parseStatement();
    return s;
}

string parseComment()
{
    assert(t.type == TOKcomment);
    string c = nextToken();
    while (t.type == TOKcomment)
        c ~= "\n" ~ nextToken();
    return c;
}

Statement parseStatement()
{
    debug(PARSE) writeln("parseStatement");
    if (t.type == TOKcomment)
    {
        return new CommentStatement(parseComment());
    }
    switch (t.text)
    {
    case "{":
        return parseCompoundStatement();
    case "return":
        return parseReturnStatement();
    case "if":
        return parseIfStatement();
    case "for":
        return parseForStatement();
    case "switch":
        return parseSwitchStatement();
    case "case":
        return parseCaseStatement();
    case "continue":
        return parseContinueStatement();
    case "break":
        return parseBreakStatement();
    case "default":
        return parseDefaultStatement();
    case "while":
        return parseWhileStatement();
    case "goto":
        return parseGotoStatement();
    // case "else":
        // return parseDanglingElseStatement();
    case "do":
        return parseDoWhileStatement();
    case "#if", "#ifdef", "#ifndef":
        auto ndef = (t.text == "#ifndef");
        auto def = (t.text == "#ifdef" || t.text == "#ifndef");
        nextToken();
        auto e = def ? new IdentExpr(parseIdent()) : parseExpr();
        if (ndef)
            e = new NotExpr(e);
        auto l = level;
        if (!marker.length || marker[$-1] == "{")
        {
            Statement[][] s;
            s.length = 1;
            Expression[] cond = [e];
            while (true)
            {
                if (t.text == "#else")
                {
                    nextToken();
                    ++cond.length;
                    ++s.length;
                }
                else if (t.text == "#elif")
                {
                    nextToken();
                    cond ~= parseExpr();
                    ++s.length;
                }
                else if (t.text == "#endif")
                {
                    nextToken();
                    break;
                }
                else
                    s[$-1] ~= parseStatement();
            }
            assert(l == level);
            return new VersionStatement(cond, s);
        }
        else
            fail();
    case "#":
        return new ExpressionStatement(new DeclarationExpr(parseDecl(null, true)), null);
    default:
        return parseExpressionStatement();
    }
}

Statement parseReturnStatement()
{
    debug(PARSE) writeln("parseReturnStatement");
    check("return");
    Expression e;
    if (t.text != ";")
        e = parseExpr();
    auto tc = trailingComment(";");
    return new ReturnStatement(e, tc);
}

Statement parseForStatement()
{
    debug(PARSE) writeln("parseForStatement");
    check("for");
    enter("(");
    Expression init, cond, inc;
    if (t.text != ";")
        init = parseExpr();
    check(";");
    if (t.text != ";")
        cond = parseExpr();
    check(";");
    if (t.text != ")")
        inc = parseExpr();
    auto tc = trailingComment(")");
    auto sbody = parseStatement();
    return new ForStatement(init, cond, inc, sbody, tc);
}

Statement parseIfStatement()
{
    debug(PARSE) writeln("parseIfStatement");
    check("if");
    check("(");
    auto e = parseExpr();
    auto comment = trailingComment(")");
    auto sbody = parseStatement();
    Statement selse;
    string ec;
    if (t.text == "else")
    {
        ec = trailingComment("else");
        selse = parseStatement();
    }
    return new IfStatement(e, sbody, selse, comment, ec);
}

Statement parseDoWhileStatement()
{
    debug(PARSE) writeln("parseDoWhileStatement");
    check("do");
    auto sbody = parseStatement();
    check("while");
    enter("(");
    auto e = parseExpr();
    exit(")");
    auto tc = trailingComment(";");
    return new DoWhileStatement(sbody, e, tc);
}

Statement parseExpressionStatement()
{
    debug(PARSE) writeln("parseExpressionStatement");
    Expression e;
    if (t.text != ";")
        e = parseExpr();
    if (t.text == ":")
    {
        nextToken();
        auto id = cast(IdentExpr)e;
        if (!id)
            error("this should be an identifier: '%s'", e);
        if (t.text == ";")
            nextToken();
        return new LabelStatement(id.id);
    }
    auto tc = trailingComment(";");
    return new ExpressionStatement(e, tc);
}

Statement parseSwitchStatement()
{
    debug(PARSE) writeln("parseSwitchStatement");
    check("switch");
    enter("(");
    auto e = parseExpr();
    exit(")");
    check("{");
    auto sbody = parseStatements();
    check("}");
    return new SwitchStatement(e, sbody);
}

Statement parseWhileStatement()
{
    debug(PARSE) writeln("parseWhileStatement");
    check("while");
    enter("(");
    auto e = parseExpr();
    auto tc = trailingComment(")");
    auto sbody = parseStatement();
    return new WhileStatement(e, sbody, tc);
}

Statement parseCaseStatement()
{
    debug(PARSE) writeln("parseCaseStatement");
    check("case");
    auto e = parseExpr();
    check(":");
    return new CaseStatement(e);
}

Statement parseBreakStatement()
{
    debug(PARSE) writeln("parseBreakStatement");
    check("break");
    check(";");
    return new BreakStatement();
}

Statement parseContinueStatement()
{
    debug(PARSE) writeln("parseContinueStatement");
    check("continue");
    check(";");
    return new ContinueStatement();
}

Statement parseDefaultStatement()
{
    debug(PARSE) writeln("parseDefaultStatement");
    check("default");
    check(":");
    return new DefaultStatement();
}

Statement parseGotoStatement()
{
    debug(PARSE) writeln("parseGotoStatement");
    check("goto");
    auto id = parseIdent();
    check(";");
    return new GotoStatement(id);
}

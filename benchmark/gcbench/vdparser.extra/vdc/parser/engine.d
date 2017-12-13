// This file is part of Visual D
//
// Visual D integrates the D programming language into Visual Studio
// Copyright (c) 2010-2011 by Rainer Schuetze, All Rights Reserved
//
// Distributed under the Boost Software License, Version 1.0.
// See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt

module vdc.parser.engine;

import std.exception;
import std.stdio;
import std.string;
import std.conv;
import std.utf;

import stdext.util;

import core.bitop;

import vdc.util;
import vdc.lexer;
import vdc.parser.expr;
import vdc.parser.mod;
import vdc.parser.stmt;

import vdc.ast.node;
import vdc.ast.writer;

// debug version = TraceParser;
// version = recoverError;

class ParseException : Exception
{
    this(TextSpan _span, string msg)
    {
        super(msg);
        span = _span;
    }

    this()
    {
        super("syntax error");
    }

    TextSpan span;
}

alias Action function (Parser p) State;

enum { Forward, Accept, Reject }

alias int Action;
alias TokenId Info;

struct Stack(T)
{
    int depth;
    T[] stack; // use Appender instead?

    ref T top()
    {
        assert(depth > 0);
        return stack[depth-1];
    }

    void push(T t)
    {
        static if(is(T == Token))
        {
            if(depth >= stack.length)
            {
                stack ~= new T;
            }
            stack[depth].copy(t);
        }
        else
        {
            if(depth >= stack.length)
                stack ~= t;
            else
                stack[depth] = t;
        }
        depth++;
    }

    T pop()
    {
        assert(depth > 0);
        auto s = stack[--depth];
        return s;
    }

    void copyTo(ref Stack!T other)
    {
        other.depth = depth;
        other.stack.length = depth;
        other.stack[] = stack[0..depth];
    }

    bool compare(ref Stack!T other, int maxdepth)
    {
        if(maxdepth > depth)
            maxdepth = depth;
        if(other.depth < maxdepth)
            return false;
        for(int i = 0; i < maxdepth; i++)
            if(stack[i] !is other.stack[i])
                return false;
        return true;
    }
}

struct Snapshot
{
    int stateStackDepth;
    int nodeStackDepth;
    int tokenStackDepth;

    int tokenPos;
    State rollbackState;
}

struct ParseError
{
    TextSpan span;
    string msg;
}

class Parser
{
    Stack!State stateStack;
    Stack!Node  nodeStack;
    Stack!Token tokenStack;

    Stack!Snapshot rollbackStack;  // for backtracking parsing
    Stack!Snapshot recoverStack;   // to continue after errors

    Stack!Token tokenHistory;
    int tokenHistoryStart;

    Stack!Token redoTokens;

    string filename;
    int lineno;
    int tokenPos;
    Token lookaheadToken;
    Token tok;
    Token lexerTok;
    string partialString;
    TextSpan partialStringSpan;

    int countErrors;
    int lastErrorTokenPos;
    string lastError;
    TextSpan lastErrorSpan;

    version(recoverError)
    {
        Stack!State errStateStack;
        Stack!Node  errNodeStack;
        Stack!Token errTokenStack;
    }

    version(TraceParser) State[] traceState;
    version(TraceParser) string[] traceToken;

    bool recovering;
    bool abort;
    bool saveErrors;
    ParseError[] errors;
    State lastState;

    this()
    {
        lexerTok = new Token;
    }

    // node stack //////////////////
    @property T topNode(T = Node)()
    {
        Node n = nodeStack.top();
        return static_cast!T(n);
    }

    void pushNode(Node n)
    {
        nodeStack.push(n);
    }

    T popNode(T = Node)()
    {
        Node n = nodeStack.pop();
        nodeStack.stack[nodeStack.depth] = null;
        return static_cast!T(n);
    }

    // replace item on the node stack, appending old top as child
    void appendReplaceTopNode(Node n)
    {
        auto node = popNode();
        n.addMember(node);
        pushNode(n);
    }

    // pop top item from the node stack and add it to the members of the new top item
    void popAppendTopNode(T = Node, P = Node)()
    {
        auto node = popNode();
        if(!__ctfe) assert(cast(P) node);
        if(!__ctfe) assert(cast(T) topNode());
        topNode().addMember(node);
    }

    // extend the full psan of the node on top of the node stack
    void extendTopNode(Token tok)
    {
        if(nodeStack.depth > 0)
            topNode().extendSpan(tok.span);
    }

    // state stack //////////////////
    void pushState(State fn)
    {
        stateStack.push(fn);
    }

    State popState()
    {
        State s = stateStack.pop();
        stateStack.stack[stateStack.depth] = null;
        return s;
    }

    // token stack //////////////////
    Token topToken()
    {
        return tokenStack.top();
    }

    void pushToken(Token token)
    {
        tokenStack.push(token);
    }

    Token popToken()
    {
        return tokenStack.pop();
    }

    // error handling //////////////////
    string createError(string msg)
    {
        string where;
        if(filename.length)
            where = filename ~ "(" ~ text(lineno) ~ "): '" ~ tok.txt ~ "' - ";
        else
            where = "line " ~ text(lineno) ~ " '" ~ tok.txt ~ "': ";
        return where ~ msg;
    }

    Action parseError(string msg)
    {
        if(tokenPos < lastErrorTokenPos || recovering)
            return Reject;

        lastErrorTokenPos = tokenPos;
        lastError = createError(msg);
        lastErrorSpan = tok.span;

        version(recoverError)
        {
            stateStack.copyTo(errStateStack);
            nodeStack.copyTo(errNodeStack);
            tokenStack.copyTo(errTokenStack);
            errStateStack.push(lastState);
        }

        return Reject;
    }

    void writeError(ref const(TextSpan) errorSpan, string msg)
    {
        if(saveErrors)
            errors ~= ParseError(errorSpan, msg);
        else
            writeln(msg);
        countErrors++;
    }

    void writeError(string msg)
    {
        writeError(tok.span, msg);
    }

    Action notImplementedError(string what = "")
    {
        return parseError("not implemented: " ~ what);
    }

    // backtrace parsing
    void pushRollback(State rollbackState)
    {
        Snapshot ss;
        ss.stateStackDepth = stateStack.depth;
        ss.nodeStackDepth = nodeStack.depth;
        ss.tokenStackDepth = tokenStack.depth;
        ss.tokenPos = tokenHistory.depth;
        ss.rollbackState = rollbackState;

        rollbackStack.push(ss);
    }

    void popRollback()
    {
        rollbackStack.pop();
        if(rollbackStack.depth == 0)
            tokenHistory.depth = 0;
    }

    void rollback()
    {
        Snapshot ss = rollbackStack.pop();

        assert(stateStack.depth >= ss.stateStackDepth);
        assert(nodeStack.depth >= ss.nodeStackDepth);
        assert(tokenStack.depth >= ss.tokenStackDepth);
        assert(ss.tokenPos < tokenHistory.depth);

        stateStack.depth = ss.stateStackDepth;
        nodeStack.depth = ss.nodeStackDepth;
        tokenStack.depth = ss.tokenStackDepth;

        while(ss.tokenPos < tokenHistory.depth)
        {
            Token token = tokenHistory.pop();
            redoTokens.push(token);
            tokenPos--;
        }

        pushState(ss.rollbackState);
    }

    version(recoverError)
    void recoverNode(ref Snapshot ss)
    {
        assert(stateStack.compare(errStateStack, ss.stateStackDepth));
        assert(nodeStack.compare(errNodeStack, ss.nodeStackDepth));
        assert(tokenStack.compare(errTokenStack, ss.tokenStackDepth));

        Token _tok = new Token;
        _tok.copy(lexerTok);
        _tok.id = TOK_RECOVER;
        _tok.txt = "__recover" ~ to!string(countErrors);
        _tok.span.end = tok.span.start;
        tok = _tok;

        recovering = true;
        scope(exit) recovering = false;

        errStateStack.copyTo(stateStack);
        errNodeStack.copyTo(nodeStack);
        errTokenStack.copyTo(tokenStack);

        Action act = Forward;
        while(stateStack.depth > ss.stateStackDepth &&
              nodeStack.depth >= ss.nodeStackDepth &&
              tokenStack.depth >= ss.tokenStackDepth &&
              act == Forward)
        {
            State fn = popState();
            act = fn(this);
        }
    }

    // recover from error
    void pushRecoverState(State recoverState)
    {
        Snapshot ss;
        ss.stateStackDepth = stateStack.depth;
        ss.nodeStackDepth = nodeStack.depth;
        ss.tokenStackDepth = tokenStack.depth;
        ss.rollbackState = recoverState;

        recoverStack.push(ss);
    }

    void popRecoverState()
    {
        recoverStack.pop();
    }

    void recover()
    {
        Snapshot ss = recoverStack.top();

        assert(stateStack.depth >= ss.stateStackDepth);
        assert(nodeStack.depth >= ss.nodeStackDepth);
        assert(tokenStack.depth >= ss.tokenStackDepth);

        version(recoverError)
            recoverNode(ss);

        stateStack.depth = ss.stateStackDepth;
        nodeStack.depth = ss.nodeStackDepth;
        tokenStack.depth = ss.tokenStackDepth;

        pushState(ss.rollbackState);
    }


    static Action keepRecover(Parser p)
    {
        // can be inserted into the state stack to avoid implicitely removing an entry of the recover stack
        return Forward;
    }
    static Action recoverSemiCurly(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_semicolon:
                return Accept;
            case TOK_EOF:
            case TOK_rcurly:
                return Forward;
            case TOK_lcurly:
                // stop after closing curly (if not nested in some other braces
                p.pushState(&recoverBlock!TOK_rcurly);
                return Accept;
            case TOK_lparen:
                p.pushState(&recoverSemiCurly);
                p.pushState(&recoverBlock!TOK_rparen);
                return Accept;
            case TOK_lbracket:
                p.pushState(&recoverSemiCurly);
                p.pushState(&recoverBlock!TOK_rbracket);
                return Accept;
            default:
                p.pushState(&recoverSemiCurly);
                return Accept;
        }
    }
    // skip over nested brace blocks
    static Action recoverBlock(TokenId id)(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_EOF:
                return Forward;

            case TOK_rcurly:
            case TOK_rparen:
            case TOK_rbracket:
                return p.tok.id == id ? Accept : Forward;

            case TOK_lparen:
                p.pushState(&recoverBlock!id);
                p.pushState(&recoverBlock!TOK_rparen);
                return Accept;
            case TOK_lbracket:
                p.pushState(&recoverBlock!id);
                p.pushState(&recoverBlock!TOK_rbracket);
                return Accept;
            case TOK_lcurly:
                p.pushState(&recoverBlock!id);
                p.pushState(&recoverBlock!TOK_rcurly);
                return Accept;
            default:
                p.pushState(&recoverBlock!id);
                return Accept;
        }
    }

    ///////////////////////////////////////////////////////////
    void verifyAttributes(Attribute attr, ref Attribute newAttr, Attribute mask)
    {
        if((newAttr & mask) && (attr & mask) && (newAttr & mask) != (attr & mask))
        {
            string txt;
            writeError(createError("conflicting attributes " ~
                                   attrToString(attr & mask) ~ " and " ~
                                   attrToString(newAttr & mask)));
            newAttr &= ~mask;
        }
    }

    void combineAttributes(ref Attribute attr, Attribute newAttr)
    {
        if(newAttr & attr)
        {
            string txt;
            DCodeWriter writer = new DCodeWriter(getStringSink(txt));
            writer.writeAttributes(newAttr & attr);
            writeError(createError("multiple specification of " ~ txt));
        }
        verifyAttributes(attr, newAttr, Attr_AlignMask);
        verifyAttributes(attr, newAttr, Attr_CallMask);
        verifyAttributes(attr, newAttr, Attr_ShareMask);

        attr = attr | newAttr;
    }

    void verifyAnnotations(Annotation annot, ref Annotation newAnnot, Annotation mask)
    {
        if((newAnnot & mask) && (annot & mask) && (newAnnot & mask) != (annot & mask))
        {
            string txt;
            writeError(createError("conflicting attributes " ~
                                   annotationToString(annot & mask) ~ " and " ~
                                   annotationToString(newAnnot & mask)));
            newAnnot &= ~mask;
        }
    }

    void combineAnnotations(ref Annotation annot, Annotation newAnnot)
    {
        if(newAnnot & annot)
        {
            string txt;
            DCodeWriter writer = new DCodeWriter(getStringSink(txt));
            writer.writeAnnotations(newAnnot & annot);
            writeError(createError("multiple specification of " ~ txt));
        }
        verifyAttributes(annot, newAnnot, Annotation_ProtectionMask);
        verifyAttributes(annot, newAnnot, Annotation_SafeMask);

        annot = annot | newAnnot;
    }

    ///////////////////////////////////////////////////////////
    // skip over nested parenthesis blocks
    static Action lookaheadParen(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_EOF:
                return Forward;
            case TOK_rparen:
                return Accept;
            case TOK_lparen:
                p.pushState(&lookaheadParen);
                p.pushState(&lookaheadParen);
                return Accept;
            default:
                p.pushState(&lookaheadParen);
                return Accept;
        }
    }

    static Action finishLookaheadParen(Parser p)
    {
        p.lookaheadToken = p.tok;
        return Reject;
    }

    static Action rollbackPeekAfterParen(Parser p)
    {
        assert(p.tok.id == TOK_lparen);
        return Forward;
    }

    // look ahead after closing paren and return token after ')' on token stack
    Action peekAfterParen(Parser p, State fn)
    {
        assert(tok.id == TOK_lparen);
        p.pushState(fn);
        p.pushRollback(&rollbackPeekAfterParen);
        p.pushState(&finishLookaheadParen);
        return lookaheadParen(p);
    }

    // parsing //////////////////
    static Action forward(Parser p)
    {
        return Forward;
    }

    static Action popForward(Parser p)
    {
        p.popAppendTopNode!()();
        return Forward;
    }

    static Action accept(Parser p)
    {
        return Accept;
    }

    Action shiftOne(Token _tok)
    {
        tok = _tok;
        Action act;
        do
        {
            assert(stateStack.depth > 0);

            State fn = popState();
            lastState = fn;

            while(recoverStack.depth > 0 && stateStack.depth <= recoverStack.top().stateStackDepth)
                popRecoverState();

            version(TraceParser)
            {
                traceState ~= fn;
                traceToken ~= tok.txt;
                if(traceState.length > 200)
                {
                    traceState = traceState[$-100 .. $];
                    traceToken = traceToken[$-100 .. $];
                }
            }

            act = fn(this);
            if(act == Accept)
                extendTopNode(tok);
        }
        while(act == Forward);
        return act;
    }

    bool shift(Token _tok)
    {
        Action act;
        redoTokens.push(_tok);

        while(redoTokens.depth > 0)
        {
            Token t = redoTokens.pop();
            tokenPos++;
        retryToken:
            act = shiftOne(t);
            if(rollbackStack.depth > 0)
                tokenHistory.push(tok);

            if(act == Reject)
            {
                if(rollbackStack.depth > 0)
                {
                    rollback();
                    continue;
                }
                if(recoverStack.depth > 0)
                {
                    writeError(lastErrorSpan, lastError);
                    recover();
                    goto retryToken;
                }
                throw new ParseException(lastErrorSpan, lastError);
            }
        }

        return act == Accept;
    }

    bool shiftEOF()
    {
        lexerTok.id = TOK_EOF;
        lexerTok.txt = "";
        if(!shift(lexerTok))
            return false;

        if (nodeStack.depth > 1)
            return parseError("parsing unfinished before end of file") == Accept;
        if (nodeStack.depth == 0)
            return false;
        return true;
    }

    void parseLine(S)(ref int state, S line, int lno)
    {
        version(log) writeln(line);

        if(partialString.length)
            partialString ~= "\n";

        lineno = lno;
        for(uint pos = 0; pos < line.length && !abort; )
        {
            int tokid;
            uint prevpos = pos;
            TokenCat type = cast(TokenCat) Lexer.scan(state, line, pos, tokid);

            if(tokid != TOK_Space && tokid != TOK_Comment)
            {
                string txt = line[prevpos .. pos];
                lexerTok.span.start.line = lexerTok.span.end.line = lineno;
                lexerTok.span.start.index = prevpos;
                lexerTok.span.end.index = pos;

                if(tokid == TOK_StringLiteral)
                {
                    if(Lexer.scanState(state) != Lexer.State.kWhite ||
                       Lexer.tokenStringLevel(state) > 0)
                    {
                        if(partialString.length == 0)
                            partialStringSpan = lexerTok.span;
                        partialString ~= txt;
                        continue;
                    }
                    else
                    {
                        if(partialString.length)
                        {
                            lexerTok.span.start.line = partialStringSpan.start.line;
                            lexerTok.span.start.index = partialStringSpan.start.index;
                            txt = partialString ~ txt;
                            partialString = partialString.init;
                        }
                    }
                }

                lexerTok.txt = txt;
                lexerTok.id = tokid;
                shift(lexerTok);
            }
        }
    }

    void parseText(S)(S text)
    {
        int state = 0;

    version(all)
    {
        Lexer lex;
        lex.mTokenizeTokenString = false;
        lineno = 1;
        size_t linepos = 0; // position after last line break
        int tokid;
        for(size_t pos = 0; pos < text.length && !abort; )
        {
            int prevlineno = lineno;
            size_t prevlinepos = linepos;
            size_t prevpos = pos;
            TokenCat type = cast(TokenCat) lex.scan(state, text, pos, tokid);

            if(tokid == TOK_Space || tokid == TOK_Comment || tokid == TOK_StringLiteral || tokid == TOK_CharacterLiteral)
            {
                for(size_t lpos = prevpos; lpos < pos; lpos++)
                    if(text[lpos] == '\n')
                    {
                        lineno++;
                        linepos = lpos + 1;
                    }
            }
            if(tokid != TOK_Space && tokid != TOK_Comment)
            {
                lexerTok.txt = text[prevpos .. pos];
                lexerTok.id = tokid;
                lexerTok.span.start.line = prevlineno;
                lexerTok.span.end.line = lineno;
                lexerTok.span.start.index = cast(int) (prevpos - prevlinepos);
                lexerTok.span.end.index   = cast(int) (pos - linepos);
                shift(lexerTok);
            }
        }
    }
    else
    {
        S[] lines = splitLines(text);
        foreach(lno, line; lines)
            parseLine(state, line, lno + 1);
    }
    }

    Node parseModule(S)(S text)
    {
        reinit();
        pushState(&Module.enter);

        parseText(text);

        if(abort || !shiftEOF())
            return null;
        return popNode();
    }

    Node[] parseCurlyBlock(S)(S text, TextSpan mixinSpan)
    {
        lexerTok.txt = "{";
        lexerTok.id = TOK_lcurly;
        lexerTok.span = mixinSpan;
        lexerTok.span.end.index = mixinSpan.end.index + 1;
        if(!shift(lexerTok))
            return null;

        parseText(text);

        lexerTok.txt = "}";
        lexerTok.id = TOK_rcurly;
        if(abort || !shift(lexerTok))
            return null;
        if (nodeStack.depth > 1)
        {
            parseError("parsing unfinished before end of mixin");
            return null;
        }
        return popNode().members;
    }

    Node[] parseDeclarations(S)(S text, TextSpan mixinSpan)
    {
        reinit();
        pushState(&DeclarationBlock.enter);

        return parseCurlyBlock(text, mixinSpan);
    }

    Node[] parseStatements(S)(S text, TextSpan mixinSpan)
    {
        reinit();
        pushState(&BlockStatement.enter);

        return parseCurlyBlock(text, mixinSpan);
    }

    Node parseExpression(S)(S text, TextSpan mixinSpan)
    {
        reinit();
        pushState(&Expression.enter);

        lexerTok.txt = "(";
        lexerTok.id = TOK_lparen;
        lexerTok.span = mixinSpan;
        lexerTok.span.end.index = mixinSpan.end.index + 1;
        if(!shift(lexerTok))
            return null;

        parseText(text);

        lexerTok.txt = ")";
        lexerTok.id = TOK_rparen;
        if(abort || !shift(lexerTok))
            return null;
        if (nodeStack.depth > 1)
        {
            parseError("parsing unfinished before end of mixin");
            return null;
        }
        return popNode();
    }

    void reinit()
    {
        stateStack = stateStack.init;
        nodeStack  = nodeStack.init;
        tokenStack = tokenStack.init;
        version(recoverError)
        {
            errStateStack = errStateStack.init;
            errNodeStack  = errNodeStack.init;
            errTokenStack = errTokenStack.init;
        }
        lastErrorTokenPos = 0;
        lastError = "";
        errors = errors.init;
        countErrors = 0;
        abort = false;
        recovering = false;
        lastState = null;
    }
}

string readUtf8(string fname)
{
    /* Convert all non-UTF-8 formats to UTF-8.
     * BOM : http://www.unicode.org/faq/utf_bom.html
     * 00 00 FE FF  UTF-32BE, big-endian
     * FF FE 00 00  UTF-32LE, little-endian
     * FE FF        UTF-16BE, big-endian
     * FF FE        UTF-16LE, little-endian
     * EF BB BF     UTF-8
     */
    static const ubyte[4] bomUTF32BE = [ 0x00, 0x00, 0xFE, 0xFF ]; // UTF-32, big-endian
    static const ubyte[4] bomUTF32LE = [ 0xFF, 0xFE, 0x00, 0x00 ]; // UTF-32, little-endian
    static const ubyte[2] bomUTF16BE = [ 0xFE, 0xFF ];             // UTF-16, big-endian
    static const ubyte[2] bomUTF16LE = [ 0xFF, 0xFE ];             // UTF-16, little-endian
    static const ubyte[3] bomUTF8    = [ 0xEF, 0xBB, 0xBF ];       // UTF-8

    import std.file : read;
    ubyte[] data = cast(ubyte[]) read(fname);
    if(data.length >= 4 && data[0..4] == bomUTF32BE[])
        foreach(ref d; cast(uint[]) data)
            d = bswap(d);
    if(data.length >= 2 && data[0..2] == bomUTF16BE[])
        foreach(ref d; cast(ushort[]) data)
            d = bswap(d) >> 16;

    if(data.length >= 4 && data[0..4] == bomUTF32LE[])
        return toUTF8(cast(dchar[]) data[4..$]);
    if(data.length >= 2 && data[0..2] == bomUTF16LE[])
        return toUTF8(cast(wchar[]) data[2..$]);
    if(data.length >= 3 && data[0..3] == bomUTF8[])
        return toUTF8(cast(string) data[3..$]);

    return cast(string)data;
}

////////////////////////////////////////////////////////////////

bool isInOps(ops...)(TokenId tok)
{
    foreach(o; ops)
        if(tok == o)
            return true;
    return false;
}

class NoASTNode {}

// always adds a node with an array of ASTNodeType nodes, even if empty
// if trailingSeparator, sep at the end is allowed, but closing bracket is expected afterwards
mixin template ListNode(ASTNodeType, SubType, TokenId sep, bool trailingSeparator = false, bool allowEmpty = false)
{
    static Action enter(Parser p)
    {
        static if(!is(ASTNodeType == NoASTNode))
            p.pushNode(new ASTNodeType(p.tok));

        static if(allowEmpty)
            switch(p.tok.id)
            {
                case TOK_rparen:
                case TOK_rbracket:
                case TOK_rcurly:
                    return Forward;
                default:
            }

        p.pushState(&shift);
        return SubType.enter(p);
    }

    static Action shift(Parser p)
    {
        p.popAppendTopNode!ASTNodeType();
        if(p.tok.id != sep)
            return Forward;

        static if(trailingSeparator)
        {
            p.pushState(&shiftSeparator);
        }
        else
        {
            p.pushState(&shift);
            p.pushState(&SubType.enter);
        }
        return Accept;
    }

    static if(trailingSeparator)
    static Action shiftSeparator(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_rparen:
            case TOK_rbracket:
            case TOK_rcurly:
                return Forward;
            default:
                p.pushState(&shift);
                return SubType.enter(p);
        }
    }
}

// binary operator, left/right/no recursion
//
//BinaryNode:
//    SubType
// R: SubType    op BinaryNode
// L: BinaryNode op SubType
// N: SubType    op SubType
mixin template BinaryNode(ASTNodeType, string recursion, SubType, ops...)
{
    static assert(recursion == "L" || recursion == "R" || recursion == "N");

    static Action enter(Parser p)
    {
        p.pushState(&shift);
        return SubType.enter(p);
    }

    static Action shift(Parser p)
    {
        if(!isInOps!(ops)(p.tok.id))
            return Forward;

        p.appendReplaceTopNode(new ASTNodeType(p.tok));
        p.pushState(&shiftNext);

        static if(recursion == "L" || recursion == "N")
            p.pushState(&SubType.enter);
        else
            p.pushState(&enter);
        return Accept;
    }

    static Action shiftNext(Parser p)
    {
        p.popAppendTopNode!ASTNodeType();

        static if(recursion == "L")
            return shift(p);
        else
            return Forward;
    }
}

// ternary operator, right recursion
//
//TernaryNode:
//    SubType1
//    SubType1 op1 SubType2 op2 TernaryNode
mixin template TernaryNode(ASTNodeType, SubType1, TokenId op1, SubType2, TokenId op2)
{
    static Action enter(Parser p)
    {
        p.pushState(&shift);
        return SubType1.enter(p);
    }

    static Action shift(Parser p)
    {
        if(p.tok.id != op1)
            return Forward;

        p.appendReplaceTopNode(new ASTNodeType(p.tok));
        p.pushState(&shiftNext);
        p.pushState(&SubType2.enter);
        return Accept;
    }

    static Action shiftNext(Parser p)
    {
        if(p.tok.id != op2)
            return p.parseError("second operator '" ~ tokenString(op2) ~ "'in ternary expression expected");

        p.popAppendTopNode!ASTNodeType();

        p.pushState(&shiftLast);
        p.pushState(&enter);
        return Accept;
    }

    static Action shiftLast(Parser p)
    {
        p.popAppendTopNode!ASTNodeType();
        return Forward;
    }
}

//OptionalNode:
//    SubType1
//    SubType1 op SubType2
mixin template OptionalNode(ASTNodeType, SubType1, TokenId op, SubType2)
{
    static Action enter(Parser p)
    {
        p.pushState(&shiftSubType1);
        return SubType1.enter(p);
    }

    static Action shiftSubType1(Parser p)
    {
        if(p.tok.id != op)
            return Forward;

        p.appendReplaceTopNode(new ASTNodeType(p.tok));
        p.pushState(&shiftSubType2);
        p.pushState(&SubType2.enter);
        return Accept;
    }

    static Action shiftSubType2(Parser p)
    {
        p.popAppendTopNode!ASTNodeType();
        return Forward;
    }
}

//SequenceNode:
//    SubType1/Token1 SubType2/Token2 SubType3/Token3 SubType4/Token4
mixin template SequenceNode(ASTNodeType, T...)
{
    static Action enter(Parser p)
    {
        static if(!is(ASTNodeType == NoASTNode))
            p.pushNode(new ASTNodeType(p.tok));

        return shift0.next(p);
    }

    mixin template ShiftState(int n, alias shiftFn, alias nextFn)
    {
        static if(n < T.length)
        {
            static Action shift(Parser p)
            {
                static if(is(T[n-1] == class))
                {
                    static if(!__traits(compiles,T[n-1].doNotPopNode))
                        static if(!is(ASTNodeType == NoASTNode))
                            p.popAppendTopNode!ASTNodeType();
                }
                return next(p);
            }

            static Action next(Parser p)
            {
                static if (is(typeof(& T[n]) U : U*) && is(U == function))
                {
                    return T[n](p);
                }
                else
                {
                    static if(__traits(compiles,T[n].startsWithOp(p.tok.id)))
                        if(!T[n].startsWithOp(p.tok.id))
                            return nextFn(p);

                    static if(n < T.length-1)
                        p.pushState(&shiftFn);

                    static if(is(T[n] == class))
                    {
                        static if(n == T.length-1)
                            p.pushState(&reduce);

                        return T[n].enter(p);
                    }
                    else
                    {
                        if(p.tok.id != T[n])
                            return p.parseError("'" ~ tokenString(T[n]) ~ "' expected");
                        return Accept;
                    }
                }
            }
        }
        else
        {
            static Action shift(Parser p) { return Forward; }
            static Action next(Parser p) { return Forward; }
        }
    }

    mixin ShiftState!(9, reduce,       reduce)      shift9;
    mixin ShiftState!(8, shift9.shift, shift9.next) shift8;
    mixin ShiftState!(7, shift8.shift, shift8.next) shift7;
    mixin ShiftState!(6, shift7.shift, shift7.next) shift6;
    mixin ShiftState!(5, shift6.shift, shift6.next) shift5;
    mixin ShiftState!(4, shift5.shift, shift5.next) shift4;
    mixin ShiftState!(3, shift4.shift, shift4.next) shift3;
    mixin ShiftState!(2, shift3.shift, shift3.next) shift2;
    mixin ShiftState!(1, shift2.shift, shift2.next) shift1;
    mixin ShiftState!(0, shift1.shift, shift1.next) shift0;

    static Action reduce(Parser p)
    {
        static if(!is(ASTNodeType == NoASTNode))
            p.popAppendTopNode!ASTNodeType();
        return Forward;
    }
}

class Opt(NT, ops...)
{
    static bool startsWithOp(TokenId tok)
    {
        foreach(o; ops)
            if(tok == o)
                return true;
        return false;
    }
    static Action enter(Parser p)
    {
        return NT.enter(p);
    }
}

////////////////////////////////////////////////////////////////

// unfortunately, states have to be in reverse order because of unresolved forward references

mixin template stateEnterToken(TokenId id, ASTType, alias newstate)
{
    static Action enter(Parser p)
    {
        switch(p.tok.id)
        {
            case id:
                static if(!is(ASTType : NoASTNode))
                    p.pushNode(new ASTType(p.tok));
                p.pushState(&newstate);
                return Accept;
            default:
                return p.parseError(tokenString(id) ~ " expected");
        }
    }
}

mixin template stateEnterClass(SubType, ASTType, alias newstate)
{
    static Action enter(Parser p)
    {
        static if(!is(ASTType : NoASTNode))
            p.pushNode(new ASTType(p.tok));
        p.pushState(&enterReduce);
        return SubType.enter(p);
    }
    static Action enterReduce(Parser p)
    {
        static if(!is(ASTType : NoASTNode))
            p.popAppendTopNode!();
        return newstate(p);
    }
}

mixin template stateShiftToken(TokenId id1, alias newstate1,
                               TokenId id2 = 0, alias newstate2 = Parser.forward,
                               TokenId id3 = 0, alias newstate3 = Parser.forward,
                               TokenId id4 = 0, alias newstate4 = Parser.forward)
{
    static Action shift(Parser p)
    {
        switch(p.tok.id)
        {
            static if(id1 > 0)
            {
                case id1:
                    static if(&newstate1 !is &Parser.forward)
                        p.pushState(&newstate1);
                    return Accept;
            }
            static if(id2 > 0)
            {
                case id2:
                    static if(&newstate2 !is &Parser.forward)
                        p.pushState(&newstate2);
                    return Accept;
            }
            static if(id3 > 0)
            {
                case id3:
                    static if(&newstate3 !is &Parser.forward)
                        p.pushState(&newstate3);
                    return Accept;
            }
            static if(id4 > 0)
            {
                case id4:
                    static if(&newstate4 !is &Parser.forward)
                        p.pushState(&newstate4);
                    return Accept;
            }
            default:
                static if(id1 == -1)
                    static if(&newstate1 is &Parser.forward)
                        return Forward;
                    else
                        return newstate1(p);

                else static if(id2 == -1)
                    static if(&newstate2 is &Parser.forward)
                        return Forward;
                    else
                        return newstate2(p);

                else static if(id3 == -1)
                    static if(&newstate3 is &Parser.forward)
                        return Forward;
                    else
                        return newstate3(p);

                else static if(id4 == -1)
                    static if(&newstate4 is &Parser.forward)
                        return Forward;
                    else
                        return newstate4(p);

                else
                {
                    string msg = tokenString(id1);
                    static if(id2 != 0) msg ~= " or " ~ tokenString(id2);
                    static if(id3 != 0) msg ~= " or " ~ tokenString(id3);
                    static if(id4 != 0) msg ~= " or " ~ tokenString(id4);
                    return p.parseError(tokenString(id1) ~ " expected");
                }
        }
    }
}

mixin template stateAppendClass(C, alias newstate)
{
    static Action shift(Parser p)
    {
        p.pushState(&reduce);
        return C.enter(p);
    }
    static Action reduce(Parser p)
    {
        p.popAppendTopNode!();
        return newstate(p);
    }
}

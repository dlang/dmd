/**
 * Takes a token stream from the lexer, and parses it into an abstract syntax tree.
 *
 * Specification: C11
 *
 * Copyright:   Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/cparse.d, _cparse.d)
 * Documentation:  https://dlang.org/phobos/dmd_cparse.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/cparse.d
 */

module dmd.cparse;

import core.stdc.stdio;
import core.stdc.string;
import dmd.globals;
import dmd.id;
import dmd.identifier;
import dmd.lexer;
import dmd.parse;
import dmd.errors;
import dmd.root.filename;
import dmd.root.outbuffer;
import dmd.root.rmem;
import dmd.root.rootobject;
import dmd.root.string;
import dmd.tokens;

/***********************************************************
 */
final class CParser(AST) : Parser!AST
{
    AST.Dsymbols* symbols;      // symbols declared in current scope

    const ubyte longsize;         /// size of C long, 4 or 8
    const ubyte long_doublesize;  /// size of C long double, 8 or D real.sizeof
    const ubyte wchar_tsize;      /// size of C wchar_t, 2 or 4

    bool addFuncName;             /// add declaration of __func__ to function symbol table

    extern (D) this(AST.Module _module, const(char)[] input, bool doDocComment,
        ubyte longsize, ubyte long_doublesize, ubyte wchar_tsize)
    {
        super(_module, input, doDocComment);

        //printf("CParser.this()\n");
        mod = _module;
        linkage = LINK.c;
        Ccompile = true;

        // Configure sizes for C `long`, `long double`, `wchar_t`
        this.longsize = longsize;
        this.long_doublesize = long_doublesize;
        this.wchar_tsize = wchar_tsize;

        // C `char` is always unsigned in ImportC
    }

    /********************************************
     * Parse translation unit.
     * C11 6.9
     * translation-unit:
     *    external-declaration
     *    translation-unit external-declaration
     *
     * external-declaration:
     *    function-definition
     *    declaration
     * Returns:
     *  array of Dsymbols that were declared
     */
    override AST.Dsymbols* parseModule()
    {
        //printf("cparseTranslationUnit()\n");
        symbols = new AST.Dsymbols();
        while (1)
        {
            if (token.value == TOK.endOfFile)
            {
                // wrap the symbols in `extern (C) { symbols }`
                auto wrap = new AST.Dsymbols();
                auto ld = new AST.LinkDeclaration(token.loc, LINK.c, symbols);
                wrap.push(ld);

                return wrap;
            }

            cparseDeclaration(LVL.global);
        }
    }

    /******************************************************************************/
    /********************************* Statement Parser ***************************/
    //{

    /**********************
     * C11 6.8
     * statement:
     *    labeled-statement
     *    compound-statement
     *    expression-statement
     *    selection-statement
     *    iteration-statement
     *    jump-statement
     *
     * Params:
     *      flags = PSxxxx
     *      endPtr = store location of closing brace
     *      pEndloc = if { ... statements ... }, store location of closing brace, otherwise loc of last token of statement
     * Returns:
     *      parsed statement
     */
    AST.Statement cparseStatement(int flags, const(char)** endPtr = null, Loc* pEndloc = null)
    {
        AST.Statement s;
        const loc = token.loc;

        //printf("cparseStatement()\n");

        auto symbolsSave = symbols;
        if (!(flags & (ParseStatementFlags.scope_ | ParseStatementFlags.curlyScope)))
            symbols = new AST.Dsymbols();

        switch (token.value)
        {
        case TOK.identifier:
            /* A leading identifier can be a declaration, label, or expression.
             * A quick check of the next token can disambiguate most cases.
             */
            switch (peekNext())
            {
                case TOK.colon:
                {
                    // It's a label
                    auto ident = token.ident;
                    nextToken();    // advance to `:`
                    nextToken();    // advance past `:`
                    if (token.value == TOK.rightCurly)
                        s = null;
                    else if (token.value == TOK.leftCurly)
                        s = cparseStatement(ParseStatementFlags.curly | ParseStatementFlags.scope_);
                    else
                        s = cparseStatement(ParseStatementFlags.semiOk);
                    s = new AST.LabelStatement(loc, ident, s);
                    break;
                }

                case TOK.dot:
                case TOK.arrow:
                case TOK.plusPlus:
                case TOK.minusMinus:
                case TOK.leftBracket:
                case TOK.question:
                case TOK.assign:
                case TOK.addAssign:
                case TOK.minAssign:
                case TOK.mulAssign:
                case TOK.divAssign:
                case TOK.modAssign:
                case TOK.andAssign:
                case TOK.orAssign:
                case TOK.xorAssign:
                case TOK.leftShiftAssign:
                case TOK.rightShiftAssign:
                    goto Lexp;

                default:
                {
                    /* If tokens look like a declaration, assume it is one
                     */
                    auto tk = &token;
                    if (isCDeclaration(tk))
                        goto Ldeclaration;
                    goto Lexp;
                }
            }
            break;

        case TOK.int32Literal:
        case TOK.uns32Literal:
        case TOK.int64Literal:
        case TOK.uns64Literal:
        case TOK.int128Literal:
        case TOK.uns128Literal:
        case TOK.float32Literal:
        case TOK.float64Literal:
        case TOK.float80Literal:
        case TOK.imaginary32Literal:
        case TOK.imaginary64Literal:
        case TOK.imaginary80Literal:
        case TOK.charLiteral:
        case TOK.wcharLiteral:
        case TOK.dcharLiteral:
        case TOK.leftParenthesis:
        case TOK.mul:
        case TOK.min:
        case TOK.add:
        case TOK.not:
        case TOK.plusPlus:
        case TOK.minusMinus:
        case TOK.functionString:
        case TOK.sizeof_:
        Lexp:
            auto exp = cparseExpression();
            if (token.value == TOK.identifier && exp.op == TOK.identifier)
            {
                error("found `%s` when expecting `;` or `=`, did you mean `%s %s = %s`?", peek(&token).toChars(), exp.toChars(), token.toChars(), peek(peek(&token)).toChars());
                nextToken();
            }
            else
                check(TOK.semicolon, "statement");
            s = new AST.ExpStatement(loc, exp);
            break;

        // type-specifiers
        case TOK.void_:
        case TOK.char_:
        case TOK.int16:
        case TOK.int32:
        case TOK.int64:
        case TOK.float32:
        case TOK.float64:
        case TOK.signed:
        case TOK.unsigned:
        case TOK._Bool:
        //case TOK._Imaginary:
        case TOK._Complex:
        case TOK.struct_:
        case TOK.union_:
        case TOK.enum_:

        // storage-class-specifiers
        case TOK.typedef_:
        case TOK.extern_:
        case TOK.static_:
        case TOK._Thread_local:
        case TOK.auto_:
        case TOK.register:

        // function-specifiers
        case TOK.inline:
        case TOK._Noreturn:

        // type-qualifiers
        case TOK.const_:
        case TOK.volatile:
        case TOK.restrict:
        case TOK.__restrict:

        // alignment-specifier
        case TOK._Alignas:

        // atomic-type-specifier or type_qualifier
        case TOK._Atomic:

        Ldeclaration:
        {
            cparseDeclaration(LVL.local);
            if (symbols.length > 1)
            {
                auto as = new AST.Statements();
                as.reserve(symbols.length);
                foreach (d; (*symbols)[])
                {
                    s = new AST.ExpStatement(loc, d);
                    as.push(s);
                }
                s = new AST.CompoundDeclarationStatement(loc, as);
                symbols.setDim(0);
            }
            else if (symbols.length == 1)
            {
                auto d = (*symbols)[0];
                s = new AST.ExpStatement(loc, d);
                symbols.setDim(0);
            }
            else
                s = new AST.ExpStatement(loc, cast(AST.Expression)null);
            if (flags & ParseStatementFlags.scope_)
                s = new AST.ScopeStatement(loc, s, token.loc);
            break;
        }

        case TOK._Static_assert:        // _Static_assert ( constant-expression, string-literal ) ;
            s = new AST.StaticAssertStatement(cparseStaticAssert());
            break;

        case TOK.leftCurly:
        {
            /* C11 6.8.2
             * compound-statement:
             *    { block-item-list (opt) }
             *
             * block-item-list:
             *    block-item
             *    block-item-list block-item
             *
             * block-item:
             *    declaration
             *    statement
             */
            nextToken();
            auto statements = new AST.Statements();
            while (token.value != TOK.rightCurly && token.value != TOK.endOfFile)
            {
                statements.push(cparseStatement(ParseStatementFlags.semi | ParseStatementFlags.curlyScope));
            }
            if (endPtr)
                *endPtr = token.ptr;
            endloc = token.loc;
            if (pEndloc)
            {
                *pEndloc = token.loc;
                pEndloc = null; // don't set it again
            }
            s = new AST.CompoundStatement(loc, statements);
            if (flags & (ParseStatementFlags.scope_ | ParseStatementFlags.curlyScope))
                s = new AST.ScopeStatement(loc, s, token.loc);
            check(TOK.rightCurly, "compound statement");
            break;
        }

        case TOK.while_:
        {
            nextToken();
            check(TOK.leftParenthesis);
            auto condition = cparseExpression();
            check(TOK.rightParenthesis);
            Loc endloc;
            auto _body = cparseStatement(ParseStatementFlags.scope_, null, &endloc);
            s = new AST.WhileStatement(loc, condition, _body, endloc, null);
            break;
        }

        case TOK.semicolon:
            /* C11 6.8.3 null statement
             */
            nextToken();
            s = new AST.ExpStatement(loc, cast(AST.Expression)null);
            break;

        case TOK.do_:
        {
            nextToken();
            auto _body = cparseStatement(ParseStatementFlags.scope_);
            check(TOK.while_);
            check(TOK.leftParenthesis);
            auto condition = cparseExpression();
            check(TOK.rightParenthesis);
            check(TOK.semicolon, "terminating `;` required after do-while statement");
            s = new AST.DoStatement(loc, _body, condition, token.loc);
            break;
        }

        case TOK.for_:
        {
            AST.Statement _init;
            AST.Expression condition;
            AST.Expression increment;

            nextToken();
            check(TOK.leftParenthesis);
            if (token.value == TOK.semicolon)
            {
                _init = null;
                nextToken();
            }
            else
            {
                _init = cparseStatement(0);
            }
            if (token.value == TOK.semicolon)
            {
                condition = null;
                nextToken();
            }
            else
            {
                condition = cparseExpression();
                check(TOK.semicolon, "`for` condition");
            }
            if (token.value == TOK.rightParenthesis)
            {
                increment = null;
                nextToken();
            }
            else
            {
                increment = cparseExpression();
                check(TOK.rightParenthesis);
            }
            Loc endloc;
            auto _body = cparseStatement(ParseStatementFlags.scope_, null, &endloc);
            s = new AST.ForStatement(loc, _init, condition, increment, _body, endloc);
            break;
        }

        case TOK.if_:
        {
            nextToken();
            check(TOK.leftParenthesis);
            auto condition = cparseExpression();
            check(TOK.rightParenthesis);
            auto ifbody = cparseStatement(ParseStatementFlags.scope_);
            AST.Statement elsebody;
            if (token.value == TOK.else_)
            {
                nextToken();
                elsebody = cparseStatement(ParseStatementFlags.scope_);
            }
            else
                elsebody = null;
            if (condition && ifbody)
                s = new AST.IfStatement(loc, null, condition, ifbody, elsebody, token.loc);
            else
                s = null; // don't propagate parsing errors
            break;
        }

        case TOK.else_:
            error("found `else` without a corresponding `if` statement");
            goto Lerror;

        case TOK.switch_:
        {
            nextToken();
            check(TOK.leftParenthesis);
            auto condition = cparseExpression();
            check(TOK.rightParenthesis);
            auto _body = cparseStatement(ParseStatementFlags.scope_);
            s = new AST.SwitchStatement(loc, condition, _body, false);
            break;
        }

        case TOK.case_:
        {

            nextToken();
            auto exp = cparseAssignExp();
            check(TOK.colon);

            if (flags & ParseStatementFlags.curlyScope)
            {
                auto statements = new AST.Statements();
                while (token.value != TOK.case_ && token.value != TOK.default_ && token.value != TOK.endOfFile && token.value != TOK.rightCurly)
                {
                    auto cur = cparseStatement(ParseStatementFlags.semi | ParseStatementFlags.curlyScope);
                    statements.push(cur);

                    // https://issues.dlang.org/show_bug.cgi?id=21739
                    // Stop at the last break s.t. the following non-case statements are
                    // not merged into the current case. This can happen for
                    // case 1: ... break;
                    // debug { case 2: ... }
                    if (cur.isBreakStatement())
                        break;
                }
                s = new AST.CompoundStatement(loc, statements);
            }
            else
            {
                s = cparseStatement(ParseStatementFlags.semi);
            }
            s = new AST.ScopeStatement(loc, s, token.loc);
            s = new AST.CaseStatement(loc, exp, s);
            break;
        }

        case TOK.default_:
        {
            nextToken();
            check(TOK.colon);

            if (flags & ParseStatementFlags.curlyScope)
            {
                auto statements = new AST.Statements();
                while (token.value != TOK.case_ && token.value != TOK.default_ && token.value != TOK.endOfFile && token.value != TOK.rightCurly)
                {
                    statements.push(cparseStatement(ParseStatementFlags.semi | ParseStatementFlags.curlyScope));
                }
                s = new AST.CompoundStatement(loc, statements);
            }
            else
                s = cparseStatement(ParseStatementFlags.semi);
            s = new AST.ScopeStatement(loc, s, token.loc);
            s = new AST.DefaultStatement(loc, s);
            break;
        }

        case TOK.return_:
        {
            /*  return ;
             *  return expression ;
             */
            nextToken();
            auto exp = token.value == TOK.semicolon ? null : cparseExpression();
            check(TOK.semicolon, "`return` statement");
            s = new AST.ReturnStatement(loc, exp);
            break;
        }

        case TOK.break_:
            nextToken();
            check(TOK.semicolon, "`break` statement");
            s = new AST.BreakStatement(loc, null);
            break;

        case TOK.continue_:
            nextToken();
            check(TOK.semicolon, "`continue` statement");
            s = new AST.ContinueStatement(loc, null);
            break;

        case TOK.goto_:
        {
            Identifier ident;
            nextToken();
            if (token.value != TOK.identifier)
            {
                error("identifier expected following `goto`");
                ident = null;
            }
            else
            {
                ident = token.ident;
                nextToken();
            }
            s = new AST.GotoStatement(loc, ident);
            check(TOK.semicolon, "`goto` statement");
            break;
        }

        case TOK.asm_:
            s = parseAsm();
            break;

        default:
            error("found `%s` instead of statement", token.toChars());
            goto Lerror;

        Lerror:
            panic();
            if (token.value == TOK.semicolon)
                nextToken();
            s = null;
            break;
        }
        if (pEndloc)
            *pEndloc = prevloc;
        symbols = symbolsSave;
        return s;
    }

    //}
    /*******************************************************************************/
    /********************************* Expression Parser ***************************/
    //{

    /**************
     * C11 6.5.17
     * expression:
     *  assignment-expression
     *  expression , assignment-expression
     */
    AST.Expression cparseExpression()
    {
        auto loc = token.loc;

        //printf("cparseExpression() loc = %d\n", loc.linnum);
        auto e = cparseAssignExp();
        while (token.value == TOK.comma)
        {
            nextToken();
            auto e2 = cparseAssignExp();
            e = new AST.CommaExp(loc, e, e2, false);
            loc = token.loc;
        }
        return e;
    }


    /*********************
     * C11 6.5.1
     * primary-expression:
     *    identifier
     *    constant
     *    string-literal
     *    ( expression )
     *    generic-selection
     */
    AST.Expression cparsePrimaryExp()
    {
        AST.Expression e;
        const loc = token.loc;

        //printf("parsePrimaryExp(): loc = %d\n", loc.linnum);
        switch (token.value)
        {
        case TOK.identifier:
            if (token.ident is Id.__func__)
            {
                addFuncName = true;     // implicitly declare __func__
            }
            e = new AST.IdentifierExp(loc, token.ident);
            nextToken();
            break;

        case TOK.int32Literal:
            e = new AST.IntegerExp(loc, token.intvalue, AST.Type.tint32);
            nextToken();
            break;

        case TOK.uns32Literal:
            e = new AST.IntegerExp(loc, token.unsvalue, AST.Type.tuns32);
            nextToken();
            break;

        case TOK.int64Literal:
            e = new AST.IntegerExp(loc, token.intvalue, AST.Type.tint64);
            nextToken();
            break;

        case TOK.uns64Literal:
            e = new AST.IntegerExp(loc, token.unsvalue, AST.Type.tuns64);
            nextToken();
            break;

        case TOK.float32Literal:
            e = new AST.RealExp(loc, token.floatvalue, AST.Type.tfloat32);
            nextToken();
            break;

        case TOK.float64Literal:
            e = new AST.RealExp(loc, token.floatvalue, AST.Type.tfloat64);
            nextToken();
            break;

        case TOK.float80Literal:
            e = new AST.RealExp(loc, token.floatvalue, AST.Type.tfloat80);
            nextToken();
            break;

        case TOK.imaginary32Literal:
            e = new AST.RealExp(loc, token.floatvalue, AST.Type.timaginary32);
            nextToken();
            break;

        case TOK.imaginary64Literal:
            e = new AST.RealExp(loc, token.floatvalue, AST.Type.timaginary64);
            nextToken();
            break;

        case TOK.imaginary80Literal:
            e = new AST.RealExp(loc, token.floatvalue, AST.Type.timaginary80);
            nextToken();
            break;

        case TOK.functionString:
            e = new AST.FuncInitExp(loc);
            nextToken();
            break;

        case TOK.charLiteral:
            e = new AST.IntegerExp(loc, token.unsvalue, AST.Type.tchar);
            nextToken();
            break;

        case TOK.wchar_tLiteral:
            e = new AST.IntegerExp(loc, token.unsvalue, AST.Type.twchar); // correct to twchar_t in semantic()
            nextToken();
            break;

        case TOK.string_:
        {
            // cat adjacent strings
            auto s = token.ustring;
            auto len = token.len;
            auto postfix = token.postfix;
            while (1)
            {
                nextToken();
                if (token.value == TOK.string_)
                {
                    if (token.postfix)
                    {
                        if (token.postfix != postfix)
                            error("mismatched string literal postfixes `'%c'` and `'%c'`", postfix, token.postfix);
                        postfix = token.postfix;
                    }

                    const len1 = len;
                    const len2 = token.len;
                    len = len1 + len2;
                    auto s2 = cast(char*)mem.xmalloc_noscan(len * char.sizeof);
                    memcpy(s2, s, len1 * char.sizeof);
                    memcpy(s2 + len1, token.ustring, len2 * char.sizeof);
                    s = s2;
                }
                else
                    break;
            }
            e = new AST.StringExp(loc, s[0 .. len], len, 1, postfix);
            break;
        }

        case TOK.leftParenthesis:
            nextToken();
            e = cparseExpression();
            check(TOK.rightParenthesis);
            break;

        case TOK._Generic:
            e = cparseGenericSelection();
            break;

        default:
            error("expression expected, not `%s`", token.toChars());
            // Anything for e, as long as it's not NULL
            e = new AST.IntegerExp(loc, 0, AST.Type.tint32);
            nextToken();
            break;
        }
        return e;
    }

    /************************
     * C11 6.5.3
     * unary-expression:
     *    postfix-expression
     *    ++ unary-expression
     *    -- unary-expression
     *    unary-operator cast-expression
     *    sizeof unary-expression
     *    sizeof ( type-name )
     *    _Alignof ( type-name )
     *
     * unary-operator:
     *    & * + - ~ !
     */
    private AST.Expression cparseUnaryExp()
    {
        AST.Expression e;
        const loc = token.loc;

        switch (token.value)
        {
        case TOK.and:
            nextToken();
            e = cparseUnaryExp();
            e = new AST.AddrExp(loc, e);
            break;

        case TOK.plusPlus:
            nextToken();
            e = cparseUnaryExp();
            e = new AST.PreExp(TOK.prePlusPlus, loc, e);
            break;

        case TOK.minusMinus:
            nextToken();
            e = cparseUnaryExp();
            e = new AST.PreExp(TOK.preMinusMinus, loc, e);
            break;

        case TOK.mul:
            nextToken();
            e = cparseUnaryExp();
            e = new AST.PtrExp(loc, e);
            break;

        case TOK.min:
            nextToken();
            e = cparseUnaryExp();
            e = new AST.NegExp(loc, e);
            break;

        case TOK.add:
            nextToken();
            e = cparseUnaryExp();
            e = new AST.UAddExp(loc, e);
            break;

        case TOK.not:
            nextToken();
            e = cparseUnaryExp();
            e = new AST.NotExp(loc, e);
            break;

        case TOK.tilde:
            nextToken();
            e = cparseUnaryExp();
            e = new AST.ComExp(loc, e);
            break;

        case TOK.sizeof_:
        {
            nextToken();
            if (token.value == TOK.leftParenthesis)
            {
                auto tk = peek(&token);
                if (isTypeName(tk))
                {
                    nextToken();
                    auto t = cparseTypeName();
                    check(TOK.rightParenthesis);
                    e = new AST.TypeExp(loc, t);
                    e = new AST.DotIdExp(loc, e, Id.__sizeof);
                    break;
                }
                nextToken();
                e = cparseExpression();
                check(TOK.rightParenthesis);
                e = new AST.DotIdExp(loc, e, Id.__sizeof);
                break;
            }
            e = cparseUnaryExp();
            e = new AST.DotIdExp(loc, e, Id.__sizeof);
            break;
        }

        case TOK._Alignof:
        {
            nextToken();
            check(TOK.leftParenthesis);
            auto t = cparseTypeName();
            check(TOK.rightParenthesis);
            e = new AST.TypeExp(loc, t);
            e = new AST.DotIdExp(loc, e, Id.__xalignof);
            break;
        }

        case TOK.leftParenthesis:
        {
            auto tk = peek(&token);

            // If ( type-name )
            if (isTypeName(tk))
            {
                // (type-name) cast_exp
                nextToken();
                auto t = cparseTypeName();
                check(TOK.rightParenthesis);

                if (token.value == TOK.leftCurly)
                {
                    // ( type-name ) { initializer-list }
                    cparseInitializer();
                    error(" `(type-name ) { initializer-list }` is not supported");  // TODO
                    e = new AST.IntegerExp(loc, 0, AST.Type.tint32);
                }
                else
                {
                    // (type-name) cast_exp
                    e = cparseUnaryExp();
                    e = new AST.CastExp(loc, e, t);
                    break;
                }
            }

            e = cparsePrimaryExp();
            e = cparsePostExp(e);
            break;
        }

        default:
            e = cparsePrimaryExp();
            e = cparsePostExp(e);
            break;
        }
        assert(e);
        return e;
    }

    /*********************************
     * C11 6.5.2
     * postfix-expression:
     *    primary-expression
     *    postfix-expression [ expression ]
     *    postfix-expression ( argument-expression-list (opt) )
     *    postfix-expression . identifier
     *    postfix-expression -> identifier
     *    postfix-expression ++
     *    postfix-expression --
     *    ( type-name ) { initializer-list }
     *    ( type-name ) { initializer-list , }
     *
     * argument-expression-list:
     *    assignment-expression
     *    argument-expression-list , assignment-expression
     */
    private AST.Expression cparsePostExp(AST.Expression e)
    {
        while (1)
        {
            const loc = token.loc;
            switch (token.value)
            {
            case TOK.dot:
            case TOK.arrow:
                nextToken();
                if (token.value == TOK.identifier)
                {
                    Identifier id = token.ident;
                    e = new AST.DotIdExp(loc, e, id);
                    break;
                }
                error("identifier expected following `.`, not `%s`", token.toChars());
                break;

            case TOK.plusPlus:
                e = new AST.PostExp(TOK.plusPlus, loc, e);
                break;

            case TOK.minusMinus:
                e = new AST.PostExp(TOK.minusMinus, loc, e);
                break;

            case TOK.leftParenthesis:
                e = new AST.CallExp(loc, e, cparseArguments());
                continue;

            case TOK.leftBracket:
                {
                    // array dereferences:
                    //      array[index]
                    AST.Expression index;
                    auto arguments = new AST.Expressions();

                    inBrackets++;
                    nextToken();
                    index = cparseAssignExp();
                    arguments.push(index);
                    check(TOK.rightBracket);
                    inBrackets--;
                    e = new AST.ArrayExp(loc, e, arguments);
                    continue;
                }
            default:
                return e;
            }
            nextToken();
        }
    }

    /**************
     * C11 6.5.5
     * multiplicative-expression
     *    cast-expression
     *    multiplicative-expression * cast-expression
     *    multiplicative-expression / cast-expression
     *    multiplicative-expression % cast-expression
     */
    private AST.Expression cparseMulExp()
    {
        const loc = token.loc;
        auto e = cparseUnaryExp();

        while (1)
        {
            switch (token.value)
            {
            case TOK.mul:
                nextToken();
                auto e2 = cparseUnaryExp();
                e = new AST.MulExp(loc, e, e2);
                continue;

            case TOK.div:
                nextToken();
                auto e2 = cparseUnaryExp();
                e = new AST.DivExp(loc, e, e2);
                continue;

            case TOK.mod:
                nextToken();
                auto e2 = cparseUnaryExp();
                e = new AST.ModExp(loc, e, e2);
                continue;

            default:
                break;
            }
            break;
        }
        return e;
    }

    /**************
     * C11 6.5.6
     * additive-expression
     *    multiplicative-expression
     *    additive-expression + multiplicative-expression
     *    additive-expression - multiplicative-expression
     */
    private AST.Expression cparseAddExp()
    {
        const loc = token.loc;
        auto e = cparseMulExp();

        while (1)
        {
            switch (token.value)
            {
            case TOK.add:
                nextToken();
                auto e2 = cparseMulExp();
                e = new AST.AddExp(loc, e, e2);
                continue;

            case TOK.min:
                nextToken();
                auto e2 = cparseMulExp();
                e = new AST.MinExp(loc, e, e2);
                continue;

            default:
                break;
            }
            break;
        }
        return e;
    }

    /**************
     * C11 6.5.7
     * shift-expression
     *    additive-expression
     *    shift-expression << additive-expression
     *    shift-expression >> additive-expression
     */
    private AST.Expression cparseShiftExp()
    {
        const loc = token.loc;
        auto e = cparseAddExp();

        while (1)
        {
            switch (token.value)
            {
            case TOK.leftShift:
                nextToken();
                auto e2 = cparseAddExp();
                e = new AST.ShlExp(loc, e, e2);
                continue;

            case TOK.rightShift:
                nextToken();
                auto e2 = cparseAddExp();
                e = new AST.ShrExp(loc, e, e2);
                continue;

            default:
                break;
            }
            break;
        }
        return e;
    }

    /**************
     * C11 6.5.8
     * relational-expression
     *    shift-expression
     *    relational-expression < shift-expression
     *    relational-expression > shift-expression
     *    relational-expression <= shift-expression
     *    relational-expression >= shift-expression
     */
    private AST.Expression cparseRelationalExp()
    {
        const loc = token.loc;

        auto e = cparseShiftExp();
        TOK op = token.value;

        switch (op)
        {
        case TOK.lessThan:
        case TOK.lessOrEqual:
        case TOK.greaterThan:
        case TOK.greaterOrEqual:
            nextToken();
            auto e2 = cparseShiftExp();
            e = new AST.CmpExp(op, loc, e, e2);
            break;

        default:
            break;
        }
        return e;
    }

    /**************
     * C11 6.5.9
     * equality-expression
     *    relational-expression
     *    equality-expression == relational-expression
     *    equality-expression != relational-expression
     */
    private AST.Expression cparseEqualityExp()
    {
        const loc = token.loc;

        auto e = cparseRelationalExp();
        const TOK op = token.value;

        switch (op)
        {
        case TOK.equal:
        case TOK.notEqual:
            nextToken();
            auto e2 = cparseRelationalExp();
            e = new AST.EqualExp(op, loc, e, e2);
            break;

        default:
            break;
        }
        return e;
    }

    /**************
     * C11 6.5.10
     * AND-expression
     *    equality-expression
     *    AND-expression & equality-expression
     */
    private AST.Expression cparseAndExp()
    {
        Loc loc = token.loc;
        auto e = cparseEqualityExp();
        while (token.value == TOK.and)
        {
            nextToken();
            auto e2 = cparseEqualityExp();
            e = new AST.AndExp(loc, e, e2);
            loc = token.loc;
        }
        return e;
    }

    /**************
     * C11 6.5.11
     * exclusive-OR-expression
     *    AND-expression
     *    exclusive-OR-expression ^ AND-expression
     */
    private AST.Expression cparseXorExp()
    {
        const loc = token.loc;

        auto e = cparseAndExp();
        while (token.value == TOK.xor)
        {
            nextToken();
            auto e2 = cparseAndExp();
            e = new AST.XorExp(loc, e, e2);
        }
        return e;
    }

    /**************
     * C11 6.5.12
     * inclusive-OR-expression
     *    exclusive-OR-expression
     *    inclusive-OR-expression | exclusive-OR-expression
     */
    private AST.Expression cparseOrExp()
    {
        const loc = token.loc;

        auto e = cparseXorExp();
        while (token.value == TOK.or)
        {
            nextToken();
            auto e2 = cparseXorExp();
            e = new AST.OrExp(loc, e, e2);
        }
        return e;
    }

    /**************
     * C11 6.5.13
     * logical-AND-expression
     *    inclusive-OR-expression
     *    logical-AND-expression && inclusive-OR-expression
     */
    private AST.Expression cparseAndAndExp()
    {
        const loc = token.loc;

        auto e = cparseOrExp();
        while (token.value == TOK.andAnd)
        {
            nextToken();
            auto e2 = cparseOrExp();
            e = new AST.LogicalExp(loc, TOK.andAnd, e, e2);
        }
        return e;
    }

    /**************
     * C11 6.5.14
     * logical-OR-expression
     *    logical-AND-expression
     *    logical-OR-expression || logical-AND-expression
     */
    private AST.Expression cparseOrOrExp()
    {
        const loc = token.loc;

        auto e = cparseAndAndExp();
        while (token.value == TOK.orOr)
        {
            nextToken();
            auto e2 = cparseAndAndExp();
            e = new AST.LogicalExp(loc, TOK.orOr, e, e2);
        }
        return e;
    }

    /**************
     * C11 6.5.15
     * conditional-expression:
     *    logical-OR-expression
     *    logical-OR-expression ? expression : conditional-expression
     */
    private AST.Expression cparseCondExp()
    {
        const loc = token.loc;

        auto e = cparseOrOrExp();
        if (token.value == TOK.question)
        {
            nextToken();
            auto e1 = cparseExpression();
            check(TOK.colon);
            auto e2 = cparseCondExp();
            e = new AST.CondExp(loc, e, e1, e2);
        }
        return e;
    }

    /**************
     * C11 6.5.16
     * assignment-expression:
     *    conditional-expression
     *    unary-expression assignment-operator assignment-expression
     *
     * assignment-operator:
     *    = *= /= %= += -= <<= >>= &= ^= |=
     */
    AST.Expression cparseAssignExp()
    {
        AST.Expression e;
        e = cparseCondExp(); // constrain it to being unary-expression in semantic pass
        if (e is null)
            return e;

        const loc = token.loc;
        switch (token.value)
        {
        case TOK.assign:
            nextToken();
            auto e2 = cparseAssignExp();
            e = new AST.AssignExp(loc, e, e2);
            break;

        case TOK.addAssign:
            nextToken();
            auto e2 = cparseAssignExp();
            e = new AST.AddAssignExp(loc, e, e2);
            break;

        case TOK.minAssign:
            nextToken();
            auto e2 = cparseAssignExp();
            e = new AST.MinAssignExp(loc, e, e2);
            break;

        case TOK.mulAssign:
            nextToken();
            auto e2 = cparseAssignExp();
            e = new AST.MulAssignExp(loc, e, e2);
            break;

        case TOK.divAssign:
            nextToken();
            auto e2 = cparseAssignExp();
            e = new AST.DivAssignExp(loc, e, e2);
            break;

        case TOK.modAssign:
            nextToken();
            auto e2 = cparseAssignExp();
            e = new AST.ModAssignExp(loc, e, e2);
            break;

        case TOK.andAssign:
            nextToken();
            auto e2 = cparseAssignExp();
            e = new AST.AndAssignExp(loc, e, e2);
            break;

        case TOK.orAssign:
            nextToken();
            auto e2 = cparseAssignExp();
            e = new AST.OrAssignExp(loc, e, e2);
            break;

        case TOK.xorAssign:
            nextToken();
            auto e2 = cparseAssignExp();
            e = new AST.XorAssignExp(loc, e, e2);
            break;

        case TOK.leftShiftAssign:
            nextToken();
            auto e2 = cparseAssignExp();
            e = new AST.ShlAssignExp(loc, e, e2);
            break;

        case TOK.rightShiftAssign:
            nextToken();
            auto e2 = cparseAssignExp();
            e = new AST.ShrAssignExp(loc, e, e2);
            break;

        default:
            break;
        }

        return e;
    }

    /***********************
     * C11 6.5.1.1
     * _Generic ( assignment-expression, generic-assoc-list )
     *
     * generic-assoc-list:
     *   generic-association
     *   generic-assoc-list generic-association
     *
     * generic-association:
     *   type-name : assignment-expression
     *   default : assignment-expression
     */
    private AST.Expression cparseGenericSelection()
    {
        const loc = token.loc;
        nextToken();
        check(TOK.leftParenthesis);
        cparseAssignExp();
        check(TOK.comma);
        bool sawDefault;
        while (1)
        {
            if (token.value == TOK.default_)
            {
                if (sawDefault)
                    error("only one `default` allowed in generic-assoc-list");
                sawDefault = true;
            }
            else
                cparseTypeName();

            check(TOK.colon);
            cparseAssignExp();
            if (token.value == TOK.rightParenthesis || token.value == TOK.endOfFile)
                break;
        }
        check(TOK.rightParenthesis);
        error("`_Generic` not supported");  // TODO
        return new AST.IntegerExp(loc, 0, AST.Type.tint32);
    }

    /***********************
     * C11 6.6 Constant expressions
     * constant-expression:
     *   conditional-expression
     */
    private AST.Expression cparseConstantExp()
    {
        return cparseAssignExp();
    }

    //}
    /********************************************************************************/
    /********************************* Declaration Parser ***************************/
    //{

    /*************************************
     * C11 6.7
     * declaration:
     *    declaration-specifiers init-declarator-list (opt) ;
     *    static_assert-declaration
     *
     * init-declarator-list:
     *    init-declarator
     *    init-declarator-list , init-declarator
     *
     * init-declarator:
     *    declarator
     *    declarator = initializer
     *
     * Params:
     *    level = declaration context
     */
    void cparseDeclaration(LVL level)
    {
        //printf("cparseDeclaration(level = %d)\n", level);
        if (token.value == TOK._Static_assert)
        {
            auto s = cparseStaticAssert();
            symbols.push(s);
            return;
        }

        auto symbolsSave = symbols;
        SCW scw;
        MOD mod;
        Identifier idtypedef;
        auto tspec = cparseDeclarationSpecifiers(level, scw, mod, idtypedef);

        bool first = true;
        while (1)
        {
            Identifier id;
            AST.Expression asmname;
            auto dt = cparseDeclarator(tspec, id);
            if (!dt)
            {
                panic();
                nextToken();
                break;          // error recovery
            }
            if (mod & MOD.xconst)
                dt = dt.addSTC(STC.const_);

            if (!id)    // no identifier
            {
                if (dt !is tspec)
                {
                    error("identifier or `(` expected"); // )
                    panic();
                    break;
                }
            }

            /* GNU Extensions
             * init-declarator:
             *    declarator simple-asm-expr[opt] gnu-attributes[opt]
             *    declarator simple-asm-expr[opt] gnu-attributes[opt] = initializer
             */
            switch (token.value)
            {
                case TOK.assign:
                case TOK.comma:
                case TOK.semicolon:
                case TOK.asm_:
                case TOK.__attribute__:
                    /* This is a data definition, there cannot now be a
                     * function definition.
                     */
                    first = false;
                    if (token.value == TOK.asm_)
                        asmname = cparseAsmLabel();
                    break;

                default:
                    break;
            }

            /* C11 6.9.1 Function Definitions
             * function-definition:
             *   declaration-specifiers declarator declaration-list (opt) compound-statement
             *
             * declaration-list:
             *    declaration
             *    declaration-list declaration
             */
            auto t = &token;
            if (first &&                   // first declarator
                id &&
                dt.isTypeFunction() &&     // function type not inherited from a typedef
                isDeclarationList(t) &&    // optional declaration-list
                level == LVL.global &&     // function definitions only at global scope
                t.value == TOK.leftCurly)  // start of compound-statement
            {
                auto s = cparseFunctionDefinition(id, dt.isTypeFunction(), scw);
                symbols = symbolsSave;
                symbols.push(s);
                return;
            }
            AST.Dsymbol s = null;
            symbols = symbolsSave;
            if (!symbols)
                symbols = new AST.Dsymbols;     // lazilly create it

            if (level != LVL.global && !tspec && !scw && !mod)
                error("declaration-specifier-seq required");
            else if (scw == SCW.xtypedef)
            {
                if (token.value == TOK.assign)
                    error("no initializer for typedef declaration");
                s = new AST.AliasDeclaration(token.loc, id, dt);
            }
            else if (id)
            {
                if (level == LVL.prototype)
                    break;      // declared later as Parameter, not VarDeclaration

                if (dt.ty == AST.Tvoid)
                    error("`void` has no value");

                AST.Initializer initializer;
                bool hasInitializer;
                if (token.value == TOK.assign)
                {
                    nextToken();
                    hasInitializer = true;
                    initializer = cparseInitializer();
                }
                else
                    initializer = new AST.VoidInitializer(token.loc);
                // declare the symbol
                assert(id);
                if (dt.isTypeFunction())
                {
                    if (hasInitializer)
                        error("no initializer for function declaration");
                    s = new AST.FuncDeclaration(token.loc, Loc.initial, id, SCWtoSTC(level, scw), dt);
                }
                else
                {
                    s = new AST.VarDeclaration(token.loc, dt, id, initializer, SCWtoSTC(level, scw));
                }
            }
            if (s !is null)
            {
                if (asmname)
                {
                    auto args = new AST.Expressions(1);
                    (*args)[0] = asmname;
                    auto decls = new AST.Dsymbols(1);
                    (*decls)[0] = s;
                    s = new AST.PragmaDeclaration(asmname.loc, Id.mangle, args, decls);
                }
                symbols.push(s);
            }
            first = false;

            switch (token.value)
            {
                case TOK.identifier:
                    error("missing comma");
                    goto default;

                case TOK.semicolon:
                    nextToken();
                    return;

                case TOK.comma:
                    nextToken();
                    break;

                default:
                    error("`=`, `;` or `,` expected");
                    while (token.value != TOK.semicolon && token.value != TOK.endOfFile)
                        nextToken();
                    nextToken();
                    return;
            }
        }
    }

    /***************************************
     * C11 Function Definitions
     * function-definition
     *    declaration-specifiers declarator declaration-list (opt) compound-statement
     *
     * declaration-list:
     *    declaration
     *    declaration-list declaration
     *
     * It's already been parsed up to the declaration-list (opt).
     * Pick it up from there.
     * Params:
     *    id = function identifier
     *    ft = function type
     *    scw = function storage classes
     * Returns:
     *  Dsymbol for the function
     */
    AST.Dsymbol cparseFunctionDefinition(Identifier id, AST.TypeFunction ft, SCW scw)
    {
        if (token.value != TOK.leftCurly)       // if not start of a compound-statement
        {
            // Do declaration-list
            do
            {
                cparseDeclaration(LVL.parameter);
            } while (token.value != TOK.leftCurly);

            /* Since there were declarations, the parameter-list must have been
             * an identifier-list.
             */
            auto pl = ft.parameterList;
            pl.hasIdentifierList = true;        // semantic needs to know to adjust parameter types
            if (pl.varargs != AST.VarArg.none)
                error("function identifier-list cannot end with `...`");
            auto plLength = pl.length;
            if (symbols.length != plLength)
                error("%d identifiers does not match %d declarations", cast(int)plLength, cast(int)symbols.length);

            /* Transfer the types and storage classes from symbols[] to pl[]
             */
            foreach (i; 0 .. plLength)
            {
                auto p = pl[i];  // yes, quadratic

                // Convert typedef-identifier to identifier
                if (p.type)
                {
                    if (auto t = p.type.isTypeIdentifier())
                    {
                        p.ident = t.ident;
                        p.type = null;
                    }
                }

                if (p.type || !(p.storageClass & STC.parameter))
                    error("storage class and type are not allowed in identifier-list");
                foreach (s; (*symbols)[]) // yes, quadratic
                {
                    auto d = s.isDeclaration();
                    if (p.ident == d.ident && d.type)
                    {
                        p.type = d.type;
                        p.storageClass = d.storage_class;
                        d.type = null; // don't reuse
                        break;
                    }
                }
                if (!p.type)
                    error("no declaration for identifier `%s`", p.ident.toChars());
            }
        }

        addFuncName = false;    // gets set to true if somebody references __func__ in this function
        const locFunc = token.loc;

        auto body = cparseStatement(ParseStatementFlags.curly);  // don't start a new scope; continue with parameter scope
        auto fd = new AST.FuncDeclaration(token.loc, Loc.initial, id, SCWtoSTC(LVL.global, scw), ft);

        if (addFuncName)
        {
            /* C11 6.4.2.2 Predefine
             * `static const char __func__[] = " function-name ";`
             * and add to symbol table at opening brace of start of function body
             */
            const fn = id.toString();  // function-name
            auto efn = new AST.StringExp(locFunc, fn, fn.length, 1, 'c');
            auto ifn = new AST.ExpInitializer(locFunc, efn);
            auto lenfn = new AST.IntegerExp(locFunc, fn.length + 1, AST.Type.tuns32); // +1 for terminating 0
            auto tfn = new AST.TypeSArray(AST.Type.tchar, lenfn);
            auto sfn = new AST.VarDeclaration(locFunc, tfn, Id.__func__, ifn, STC.gshared | STC.immutable_);
            auto e = new AST.DeclarationExp(locFunc, sfn);
            auto stmt = new AST.ExpStatement(locFunc, e);

            body = new AST.CompoundStatement(locFunc, stmt, body);
        }
        fd.fbody = body;

        // TODO add `symbols` to the function's local symbol table `sc2` in FuncDeclaration::semantic3()

        return fd;
    }

    /***************************************
     * C11 Initialization
     * initializer:
     *    assignment-expression
     *    { initializer-list }
     *    { initializer-list , }
     *
     * initializer-list:
     *    designation (opt) initializer
     *    initializer-list , designation (opt) initializer
     *
     * designation:
     *    designator-list =
     *
     * designator-list:
     *    designator
     *    designator-list designator
     *
     * designator:
     *    [ constant-expression ]
     *    . identifier
     */
    AST.Initializer cparseInitializer()
    {
        if (token.value != TOK.leftCurly)
        {
            auto ae = cparseAssignExp();
            return new AST.ExpInitializer(token.loc, ae);
        }
        nextToken();
        while (1)
        {
            bool hasDesignation = false;
            while (1)
            {
                if (token.value == TOK.leftBracket)
                {
                    nextToken();
                    cparseConstantExp();
                    check(TOK.rightBracket);
                    hasDesignation = true;
                }
                else if (token.value == TOK.dot)
                {
                    nextToken();
                    if (token.value != TOK.identifier)
                    {
                        error("identifier expected following `.` designator");
                        break;
                    }
                    nextToken();
                    hasDesignation = true;
                }
                else
                    break;
            }
            if (hasDesignation)
            {
                check(TOK.assign);
                error("initializer designations are not supported"); // TODO
            }
            cparseInitializer();
            if (token.value == TOK.rightCurly || token.value == TOK.endOfFile)
                break;
        }
        check(TOK.rightCurly);
        error("`{ initializer-list }` is not implemented"); // TODO
        auto e = new AST.IntegerExp(token.loc, 0, AST.Type.tint32);
        return new AST.ExpInitializer(token.loc, e);
    }

    /*************************************
     * C11 6.7
     * declaration-specifier:
     *    storage-class-specifier declaration-specifiers (opt)
     *    type-specifier declaration-specifiers (opt)
     *    type-qualifier declaration-specifiers (opt)
     *    function-specifier declaration-specifiers (opt)
     *    alignment-specifier declaration-specifiers (opt)
     * Params:
     *  level = declaration context
     *  pscw = storage class in and out
     *  pmod = type modifiers out
     *  pident = saw identifer, may be a typedef-name
     * Returns:
     *  resulting type, null if not specified
     */
    private AST.Type cparseDeclarationSpecifiers(LVL level, ref SCW pscw, ref MOD pmod, ref Identifier pident)
    {
        enum TKW : uint
        {
            xnone      = 0,
            xchar      = 1,
            xsigned    = 2,
            xunsigned  = 4,
            xshort     = 8,
            xint       = 0x10,
            xlong      = 0x20,
            xllong     = 0x40,
            xfloat     = 0x80,
            xdouble    = 0x100,
            xldouble   = 0x200,
            xtag       = 0x400,
            xident     = 0x800,
            xvoid      = 0x1000,
            xbool      = 0x4000,
            ximaginary = 0x8000,
            xcomplex   = 0x10000,
            x_Atomic   = 0x20000,
        }

        AST.Type t;
        Loc loc;
        //printf("parseDeclarationSpecifiers()\n");

        TKW tkw;
        SCW scw = pscw & SCW.xtypedef;
        MOD mod;
        Identifier id;
        Identifier previd;

    Lwhile:
        while (1)
        {
            //printf("token %s\n", token.toChars());
            TKW tkwx;
            SCW scwx;
            MOD modx;
            switch (token.value)
            {
                // Storage class specifiers
                case TOK.static_:    scwx = SCW.xstatic;    break;
                case TOK.extern_:    scwx = SCW.xextern;    break;
                case TOK.auto_:      scwx = SCW.xauto;      break;
                case TOK.register:   scwx = SCW.xregister;  break;
                case TOK.typedef_:   scwx = SCW.xtypedef;   break;
                case TOK.inline:     scwx = SCW.xinline;    break;
                case TOK._Noreturn:  scwx = SCW.x_Noreturn; break;
                case TOK._Thread_local: scwx = SCW.x_Thread_local; break;

                // Type qualifiers
                case TOK.const_:     modx = MOD.xconst;     break;
                case TOK.volatile:   modx = MOD.xvolatile;  break;
                case TOK.__restrict:
                case TOK.restrict:   modx = MOD.xrestrict;  break;

                // Type specifiers
                case TOK.char_:      tkwx = TKW.xchar;      break;
                case TOK.signed:     tkwx = TKW.xsigned;    break;
                case TOK.unsigned:   tkwx = TKW.xunsigned;  break;
                case TOK.int16:      tkwx = TKW.xshort;     break;
                case TOK.int32:      tkwx = TKW.xint;       break;
                case TOK.int64:      tkwx = TKW.xlong;      break;
                case TOK.float32:    tkwx = TKW.xfloat;     break;
                case TOK.float64:    tkwx = TKW.xdouble;    break;
                case TOK.void_:      tkwx = TKW.xvoid;      break;
                case TOK._Bool:      tkwx = TKW.xbool;      break;
                case TOK._Imaginary: tkwx = TKW.ximaginary; break;
                case TOK._Complex:   tkwx = TKW.xcomplex;   break;

                case TOK.identifier:
                    tkwx = TKW.xident;
                    id = token.ident;
                    break;

                case TOK.struct_:
                case TOK.union_:
                    t = cparseStruct(symbols);
                    tkwx = TKW.xtag;
                    break;

                case TOK.enum_:
                    t = cparseEnum(symbols);
                    tkwx = TKW.xtag;
                    break;

                case TOK._Atomic:
                {
                    // C11 6.7.2.4
                    // type-specifier if followed by `( type-name )`
                    auto tk = peek(&token);
                    if (tk.value == TOK.leftParenthesis)
                    {
                        tk = peek(tk);
                        if (isTypeName(tk) && tk.value == TOK.rightParenthesis)
                        {
                            nextToken();
                            t = cparseTypeName();
                            // TODO - implement the "atomic" part of t
                            tkwx = TKW.x_Atomic;
                            break;
                        }
                    }
                    // C11 6.7.3 type-qualifier if not
                    modx = MOD.x_Atomic;
                    break;
                }

                case TOK._Alignas:
                {
                    /* C11 6.7.5
                     * _Alignas ( type-name )
                     * _Alignas ( constant-expression )
                     */
                    nextToken();
                    check(TOK.leftParenthesis);
                    auto tk = &token;
                    if (isTypeName(tk))
                    {
                        cparseTypeName();
                    }
                    else
                    {
                        cparseConstantExp();
                    }
                    check(TOK.rightParenthesis);
                    error("`_Alignas` not supported");  // TODO
                    break;
                }

                default:
                    break Lwhile;
            }

            if (tkwx)
            {
                if (tkw & TKW.xlong && tkwx & TKW.xlong)
                {
                    tkw &= ~TKW.xlong;
                    tkwx = TKW.xllong;
                }
                if (tkw && tkwx & TKW.xident)
                {
                    // 2nd identifier can't be a typedef
                    break Lwhile; // leave parser on the identifier for the following declarator
                }
                else if (tkwx & TKW.xident)
                {
                    // 1st identifier, save it for TypeIdentifier
                    previd = id;
                }
                if (tkw & TKW.xident && tkwx ||  // typedef-name followed by type-specifier
                    tkw & tkwx)                  // duplicate type-specifiers
                {
                    error("illegal combination of type specifiers");
                    tkwx = TKW.init;
                }
                tkw |= tkwx;
                if (!(tkw & TKW.xtag))  // if parser already advanced
                    nextToken();
                continue;
            }

            if (modx)
            {
                mod |= modx;
                nextToken();
                continue;
            }

            if (scwx)
            {
                if (scw & scwx)
                    error("duplicate storage class");
                scw |= scwx;
                const scw2 = scw & (SCW.xstatic | SCW.xextern | SCW.xauto | SCW.xregister | SCW.xtypedef);
                if (scw2 & (scw2 - 1) ||
                    scw & (SCW.xauto | SCW.xregister) && scw & (SCW.xinline | SCW.x_Noreturn))
                {
                    error("conflicting storage class");
                    scw &= ~scwx;
                }
                if (level & (LVL.parameter | LVL.prototype) &&
                    scw & ~SCW.xregister)
                {
                    error("only `register` storage class allowed for function parameters");
                    scw &= ~scwx;
                }
                if (level == LVL.global &&
                    scw & (SCW.xauto | SCW.xregister))
                {
                    error("`auto` and `register` storage class not allowed for global");
                    scw &= ~scwx;
                }
                nextToken();
                continue;
            }
        }

        pscw = scw;
        pmod = mod;

        // Convert TKW bits to type t
        switch (tkw)
        {
            case TKW.xnone:                     t = null; break;

            case TKW.xchar:                     t = AST.Type.tchar; break;
            case TKW.xsigned | TKW.xchar:       t = AST.Type.tint8; break;
            case TKW.xunsigned | TKW.xchar:     t = AST.Type.tuns8; break;

            case TKW.xshort:
            case TKW.xsigned | TKW.xshort:
            case TKW.xsigned | TKW.xshort | TKW.xint:
            case TKW.xshort | TKW.xint:         t = AST.Type.tint16; break;

            case TKW.xunsigned | TKW.xshort | TKW.xint:
            case TKW.xunsigned | TKW.xshort:    t = AST.Type.tint16; break;

            case TKW.xint:
            case TKW.xsigned:
            case TKW.xsigned | TKW.xint:        t = AST.Type.tint32; break;

            case TKW.xunsigned:
            case TKW.xunsigned | TKW.xint:      t = AST.Type.tuns32; break;

            case TKW.xlong:
            case TKW.xsigned | TKW.xlong:
            case TKW.xsigned | TKW.xlong | TKW.xint:
            case TKW.xlong | TKW.xint:          t = longsize == 4 ? AST.Type.tint32 : AST.Type.tint64; break;

            case TKW.xunsigned | TKW.xlong | TKW.xint:
            case TKW.xunsigned | TKW.xlong:     t = longsize == 4 ? AST.Type.tuns32 : AST.Type.tuns64; break;

            case TKW.xllong:
            case TKW.xsigned | TKW.xllong:
            case TKW.xsigned | TKW.xllong | TKW.xint:
            case TKW.xllong | TKW.xint:          t = AST.Type.tint64; break;

            case TKW.xunsigned | TKW.xllong | TKW.xint:
            case TKW.xunsigned | TKW.xllong:     t = AST.Type.tuns64; break;

            case TKW.xvoid:                     t = AST.Type.tvoid; break;
            case TKW.xbool:                     t = AST.Type.tbool; break;

            case TKW.xfloat:                    t = AST.Type.tfloat32; break;
            case TKW.xdouble:                   t = AST.Type.tfloat64; break;
            case TKW.xlong | TKW.xdouble:       t = realType(RTFlags.realfloat); break;

            case TKW.ximaginary | TKW.xfloat:              t = AST.Type.timaginary32; break;
            case TKW.ximaginary | TKW.xdouble:             t = AST.Type.timaginary64; break;
            case TKW.ximaginary | TKW.xlong | TKW.xdouble: t = realType(RTFlags.imaginary); break;

            case TKW.xcomplex | TKW.xfloat:                t = AST.Type.tcomplex32; break;
            case TKW.xcomplex | TKW.xdouble:               t = AST.Type.tcomplex64; break;
            case TKW.xcomplex | TKW.xlong | TKW.xdouble:   t = realType(RTFlags.complex); break;

            case TKW.xident:                    t = new AST.TypeIdentifier(loc, previd);
                break;

            case TKW.xtag:
                break;          // t is already set

            default:
                error("illegal type combination");
                t = AST.Type.terror;
                break;
        }

        pident = id;
        return t;
    }

    /********************************
     * C11 6.7.6
     * Parse a declarator (including function definitions).
     * declarator:
     *    pointer (opt) direct-declarator
     *
     * direct-declarator :
     *    identifier
     *    ( declarator )
     *    direct-declarator [ type-qualifier-list (opt) assignment-expression (opt) ]
     *    direct-declarator [ static type-qualifier-list (opt) assignment-expression ]
     *    direct-declarator [ type-qualifier-list static assignment-expression (opt) ]
     *    direct-declarator [ type-qualifier-list (opt) * ]
     *    direct-declarator ( parameter-type-list )
     *    direct-declarator ( identifier-list (opt) )
     *
     * pointer :
     *    * type-qualifier-list (opt)
     *    * type-qualifier-list (opt) pointer
     *
     * type-qualifier-list :
     *    type-qualifier
     *    type-qualifier-list type-qualifier
     *
     * parameter-type-list :
     *    parameter-list
     *    parameter-list , ...
     *
     * parameter-list :
     *    parameter-declaration
     *    parameter-list , parameter-declaration
     *
     * parameter-declaration :
     *    declaration-specifiers declarator
     *    declaration-specifiers abstract-declarator (opt)
     *
     * identifier-list :
     *    identifier
     *    identifier-list , identifier
     *
     * Params:
     *  t            = base type to start with
     *  pident       = set to Identifier if there is one, null if not
     *  storageClass = any storage classes seen so far
     * Returns:
     *  type declared. If a TypeFunction is returned, this.symbols is the
     *  symbol table for the parameter-type-list, which will contain any
     *  declared struct, union or enum tags.
     */
    private AST.Type cparseDeclarator(AST.Type t, out Identifier pident,
        StorageClass storageClass = 0)
    {
        //printf("cparseDeclarator()\n");

        if (token.value == TOK.colon)
        {
            // C11 6.7.2.1-12 unnamed bit-field
            nextToken();
            cparseConstantExp();
            error("unnamed bit fields are not supported"); // TODO
            return AST.Type.tuns32;
        }

        AST.Type ts;
        while (1)
        {
            switch (token.value)
            {
            case TOK.identifier:        // identifier
                //printf("identifier %s\n", token.ident.toChars());
                pident = token.ident;
                ts = t;
                nextToken();
                break;

            case TOK.leftParenthesis:   // ( declarator )
                /* like: T (*fp)();
                 *       T ((*fp))();
                 */
                nextToken();
                ts = cparseDeclarator(t, pident);
                check(TOK.rightParenthesis);
                break;

            case TOK.mul:               // pointer
                t = new AST.TypePointer(t);
                nextToken();
                // add post fixes
                /*const mod =*/ cparseTypeQualifierList();
                // t = t.addSTC(stc); // TODO
                continue;

            default:
                ts = t;
                break;
            }
            break;
        }

        // parse DeclaratorSuffixes
        while (1)
        {
            /* Insert tx into
             *   ts -> ... -> t
             * so that
             *   ts -> ... -> tx -> t
             */
            static void insertTx(ref AST.Type ts, AST.Type tx, AST.Type t)
            {
                AST.Type* pt;
                for (pt = &ts; *pt != t; pt = &(cast(AST.TypeNext)*pt).next)
                {
                }
                *pt = tx;
            }

            switch (token.value)
            {
                case TOK.leftBracket:
                {
                    // post [] syntax.
                    AST.TypeNext ta;
                    nextToken();

                    // pick up any leading type qualifiers, `static` and `*`
                    bool isStatic;
                    if (token.value == TOK.static_)
                    {
                        isStatic = true;
                        nextToken();
                    }
                    /*const tqual =*/ cparseTypeQualifierList(); // TODO do something with tqual
                    bool isVLA;
                    if (!isStatic)
                    {
                        if (token.value == TOK.static_)
                        {
                            isStatic = true;
                            nextToken();
                        }
                        else if (token.value == TOK.mul)
                        {
                            if (peekNext() == TOK.rightBracket)
                            {
                                isVLA = true;
                                nextToken();
                            }
                        }
                    }
                    if (isVLA) // C11 6.7.6.2
                    {
                        error("variable length arrays are not supported");
                    }
                    if (isStatic) // C11 6.7.6.3
                    {
                        error("static array parameters are not supported");
                    }

                    if (token.value == TOK.rightBracket)
                    {
                        // An array of unknown size, fake it with a DArray
                        ta = new AST.TypeDArray(t); // []
                        nextToken();
                    }
                    else
                    {
                        //printf("It's a static array\n");
                        AST.Expression e = cparseAssignExp(); // [ expression ]
                        ta = new AST.TypeSArray(t, e);
                        check(TOK.rightBracket);
                    }

                    insertTx(ts, ta, t);  // ts -> ... -> ta -> t
                    continue;
                }

                case TOK.leftParenthesis:
                {
                    // New symbol table for parameter-list
                    auto symbolsSave = this.symbols;
                    this.symbols = null;

                    auto parameterList = cparseParameterList();
                    AST.Type tf = new AST.TypeFunction(parameterList, t, linkage, 0);
//                  tf = tf.addSTC(storageClass);  // TODO
                    insertTx(ts, tf, t);  // ts -> ... -> tf -> t

                    if (ts != tf)
                        this.symbols = symbolsSave;
                    break;
                }

                default:
                    break;
            }
            break;
        }
        if (token.value == TOK.colon)
        {
            // C11 6.7.2.1 bit-field
            nextToken();
            cparseConstantExp();
            error("bit fields are not supported"); // TODO
        }
        return ts;
    }

    /******************************
     * C11 6.7.3
     * type-qualifier:
     *    const
     *    restrict
     *    volatile
     *    _Atomic
     */
    MOD cparseTypeQualifierList()
    {
        MOD mod;
        while (1)
        {
            switch (token.value)
            {
                case TOK.const_:     mod |= MOD.xconst;     break;
                case TOK.volatile:   mod |= MOD.xvolatile;  break;
                case TOK.__restrict:
                case TOK.restrict:   mod |= MOD.xrestrict;  break;
                case TOK._Atomic:    mod |= MOD.x_Atomic;   break;

                default:
                    return mod;
            }
            nextToken();
        }
    }

    /***********************************
     * C11 6.7.7
     */
    AST.Type cparseTypeName()
    {
        auto tspec = cparseSpecifierQualifierList();
        Identifier id;
        auto dt = cparseDeclarator(tspec, id);
        if (id)
            error("identifier not allowed in abstract-declarator");
        return dt;
    }

    /***********************************
     * C11 6.7.2.1
     * specifier-qualifier-list:
     *    type-specifier specifier-qualifier-list (opt)
     *    type-qualifier specifier-qualifier-list (opt)
     */
    AST.Type cparseSpecifierQualifierList()
    {
        SCW scw;
        MOD mod;
        Identifier id;
        auto t = cparseDeclarationSpecifiers(LVL.global, scw, mod, id);
        if (scw)
            error("storage class not allowed in specifier-qualified-list");
        return t;
    }

    /***********************************
     * C11 6.7.6.3
     * ( parameter-type-list )
     * ( identifier-list (opt) )
     */
    AST.ParameterList cparseParameterList()
    {
        auto parameters = new AST.Parameters();
        AST.VarArg varargs = AST.VarArg.none;
        StorageClass varargsStc;

        check(TOK.leftParenthesis);
        if (token.value == TOK.void_ && peekNext() == TOK.rightParenthesis)
        {
            nextToken();
            nextToken();
            return AST.ParameterList(parameters, varargs, varargsStc);
        }

        /* The check for identifier-list comes later,
         * when doing the trailing declaration-list (opt)
         */
        while (1)
        {
            if (token.value == TOK.rightParenthesis)
                break;
            if (token.value == TOK.dotDotDot)
            {
                varargs = AST.VarArg.variadic;  // C-style variadics
                nextToken();
                check(TOK.rightParenthesis);
                return AST.ParameterList(parameters, varargs, varargsStc);
            }

            SCW scw;
            MOD mod;
            Identifier idtypedef;
            auto tspec = cparseDeclarationSpecifiers(LVL.prototype, scw, mod, idtypedef);

            Identifier id;
            auto t = cparseDeclarator(tspec, id);
            if (mod & MOD.xconst)
                t = t.addSTC(STC.const_);
            auto param = new AST.Parameter(STC.parameter, t, id, null, null);
            parameters.push(param);
            if (token.value == TOK.rightParenthesis)
                break;
            check(TOK.comma);
        }
        nextToken();
        return AST.ParameterList(parameters, varargs, varargsStc);
    }

    /***********************************
     * C11 6.7.10
     * _Static_assert ( constant-expression , string-literal ) ;
     */
    private AST.StaticAssert cparseStaticAssert()
    {
        const loc = token.loc;

        //printf("cparseStaticAssert()\n");
        nextToken();
        check(TOK.leftParenthesis);
        auto exp = cparseConstantExp();
        check(TOK.comma);
        if (token.value != TOK.string_)
            error("string literal expected");
        auto msg = cparsePrimaryExp();
        check(TOK.rightParenthesis);
        check(TOK.semicolon);
        return new AST.StaticAssert(loc, exp, msg);
    }

    /*************************
     * Collect argument list.
     * Parser is on opening parenthesis.
     * Returns:
     *    the arguments
     */
    private AST.Expressions* cparseArguments()
    {
        nextToken();
        auto arguments = new AST.Expressions();
        while (token.value != TOK.rightParenthesis && token.value != TOK.endOfFile)
        {
            auto arg = cparseAssignExp();
            arguments.push(arg);
            if (token.value != TOK.comma)
                break;

            nextToken(); // consume comma
        }

        check(TOK.rightParenthesis);

        return arguments;
    }

    /*************************
     * __declspec parser
     * https://docs.microsoft.com/en-us/cpp/cpp/declspec
     * decl-specifier:
     *    __declspec ( extended-decl-modifier-seq )
     *
     * extended-decl-modifier-seq:
     *    extended-decl-modifier (opt)
     *    extended-decl-modifier extended-decl-modifier-seq
     *
     * extended-decl-modifier:
     *    dllimport
     *    dllexport
     */
    private void cparseDeclspec()
    {
        /* Check for dllexport, dllimport
         * Ignore the rest
         */
        bool dllimport;  // TODO implement
        bool dllexport;  // TODO implement
        nextToken();     // move past __declspec
        check(TOK.leftParenthesis);
        while (1)
        {
            if (token.value == TOK.rightParenthesis)
            {
                nextToken();
                break;
            }
            else if (token.value == TOK.endOfFile)
                break;
            else if (token.value == TOK.identifier)
            {
                if (token.ident == Id.dllimport)
                {
                    dllimport = true;
                    nextToken();
                }
                else if (token.ident == Id.dllexport)
                {
                    dllexport = true;
                    nextToken();
                }
                else
                {
                    nextToken();
                    if (token.value == TOK.leftParenthesis)
                        cparseParens();
                }
            }
            else
            {
                error("extended-decl-modifier expected");
            }
            break;
        }
    }

    /*************************
     * Simple __asm__ parser
     * https://gcc.gnu.org/onlinedocs/gcc/Asm-Labels.html
     * simple-asm-expr:
     *   asm ( asm-string-literal )
     *
     * asm-string-literal:
     *   string-literal
     */
    private AST.Expression cparseAsmLabel()
    {
        nextToken();     // move past __asm__
        check(TOK.leftParenthesis);
        if (token.value != TOK.string_)
            error("string literal expected");
        auto label = cparsePrimaryExp();
        check(TOK.rightParenthesis);
        return label;
    }

    /*************************
     * __attribute__ parser
     * https://gcc.gnu.org/onlinedocs/gcc/Attribute-Syntax.html
     * attribute-specifier:
     *    __attribute__ (( attribute-list ))
     *
     * attribute-list:
     *    attribute (opt)
     *    attribute-list , attribute
     *
     * attribute:
     *    attribute-name
     *    attribute-name ( identifier )
     *    attribute-name ( identifier , expression-list )
     *    attribute-name ( expression-list (opt) )
     *
     * attribute-name:
     *    keyword
     *    identifier
     *
     * expression-list:
     *    constant-expression
     *    expression-list constant-expression
     */
    private void cparseAttribute()
    {
        /* Check for dllimport, dllexport, vector_size(bytes)
         * Ignore the rest
         */
        bool dllimport;  // TODO implement
        bool dllexport;  // TODO implement
        nextToken();     // move past __attribute__
        check(TOK.leftParenthesis);
        check(TOK.leftParenthesis);
        while (1)
        {
            if (token.value == TOK.rightParenthesis)
            {
                nextToken();
                check(TOK.rightParenthesis);
                break;
            }
            else if (token.value == TOK.endOfFile)
                break;
            else if (token.value == TOK.identifier)
            {
                if (token.ident == Id.dllimport)
                {
                    dllimport = true;
                    nextToken();
                }
                else if (token.ident == Id.dllexport)
                {
                    dllexport = true;
                    nextToken();
                }
                else if (token.ident == Id.vector_size)
                {
                    nextToken();
                    check(TOK.leftParenthesis);
                    cparseConstantExp();  // TODO implement
                    check(TOK.rightParenthesis);
                }
                else
                {
                    nextToken();
                    if (token.value == TOK.leftParenthesis)
                        cparseParens();
                }
            }
            else
            {
                error("extended-decl-modifier expected");
            }
            break;
        }
    }

    /***************************
     * Like skipParens(), but consume the tokens.
     */
    private void cparseParens()
    {
        check(TOK.leftParenthesis);
        int parens = 0;

        while (1)
        {
            switch (token.value)
            {
                case TOK.leftParenthesis:
                    ++parens;
                    break;

                case TOK.rightParenthesis:
                    --parens;
                    if (parens < 0)
                    {
                        error("extra right parenthesis");
                        return;
                    }
                    if (parens == 0)
                        return;
                    break;

                case TOK.endOfFile:
                    error("end of file found before right parenthesis");
                    return;

                default:
                    break;
            }
            nextToken();
        }
    }

    //}
    /******************************************************************************/
    /***************************** Struct & Enum Parser ***************************/
    //{

    /*************************************
     * C11 6.7.2.2
     * enum-specifier:
     *    enum identifier (opt) { enumerator-list }
     *    enum identifier (opt) { enumerator-list , }
     *    enum identifier
     *
     * enumerator-list:
     *    enumerator
     *    enumerator-list , enumerator
     *
     * enumerator:
     *    enumeration-constant
     *    enumeration-constant = constant-expression
     *
     * enumeration-constant:
     *    identifier
     *
     * Params:
     *  symbols = symbols to add enum declaration to
     * Returns:
     *  type of the enum
     */
    private AST.TypeEnum cparseEnum(ref AST.Dsymbols* symbols)
    {
        const loc = token.loc;
        nextToken();

        Identifier tag;
        if (token.value == TOK.identifier)
        {
            tag = token.ident;
            nextToken();
        }

        auto etag = new AST.EnumDeclaration(loc, tag, AST.Type.tint32);
        if (!symbols)
            symbols = new AST.Dsymbols();
        symbols.push(etag);

        if (token.value == TOK.leftCurly)
        {
            nextToken();
            Identifier lastId;
            while (token.value == TOK.identifier)
            {
                auto id = token.ident;  // enumeration-constant
                nextToken();
                auto mloc = token.loc;

                AST.Expression value;
                if (token.value == TOK.assign)
                {
                    nextToken();
                    value = cparseConstantExp();
                }
                else if (lastId)
                {
                    auto one = new AST.IntegerExp(mloc, 1, AST.Type.tint32);
                    auto last = new AST.IdentifierExp(mloc, lastId);
                    value = new AST.AddExp(mloc, last, one);            // value = lastId + 1
                }
                else
                    value = new AST.IntegerExp(mloc, 0, AST.Type.tint32);  // value = 0

                /* C enum members are equivalent to D manifest constants
                 */
                auto _init = new AST.ExpInitializer(mloc, value);
                auto man = new AST.VarDeclaration(mloc, AST.Type.tint32, id, _init, STC.manifest);
                symbols.push(man);

                if (token.value == TOK.comma)
                {
                    lastId = id;
                    nextToken();
                    continue;
                }
                break;
            }
            check(TOK.rightCurly);
        }
        else if (!tag)
            error("missing `identifier` after `enum`");
        return new AST.TypeEnum(etag);
    }

    /*************************************
     * C11 6.7.2.1
     * Parse struct and union specifiers.
     * struct-or-union-specifier:
     *    struct-or-union identifier (opt) { struct-declaration-list }
     *    struct-or-union identifier
     *
     * struct-or-union:
     *    struct
     *    union
     *
     * struct-declaration-list:
     *    struct-declaration
     *    struct-declaration-list struct-declaration
     *
     * struct-declaration:
     *    specifier-qualifier-list struct-declarator-list (opt) ;
     *    static_assert-declaration
     *
     * specifier-qualifier-list:
     *    type-specifier specifier-qualifier-list (opt)
     *    type-qualifier specifier-qualifier-list (opt)
     *
     * struct-declarator-list:
     *    struct-declarator
     *    struct-declarator-list , struct-declarator
     *
     * struct-declarator:
     *    declarator
     *    declarator (opt) : constant-expression
     *
     * Params:
     *  symbols = symbols to add enum declaration to
     * Returns:
     *  type of the struct
     */
    private AST.TypeStruct cparseStruct(ref AST.Dsymbols* symbols)
    {
        auto structOrUnion = token;
        const loc = token.loc;
        nextToken();

        Identifier tag;
        if (token.value == TOK.identifier)
        {
            tag = token.ident;
            nextToken();
        }

        auto stag = new AST.StructDeclaration(loc, tag, false);
        if (!symbols)
            symbols = new AST.Dsymbols();
        symbols.push(stag);

        if (token.value == TOK.leftCurly)
        {
            nextToken();
            auto symbolsSave = symbols;
            symbols = null;
            while (token.value != TOK.rightCurly)
            {
                cparseDeclaration(LVL.member);

                if (token.value == TOK.endOfFile)
                    break;
            }
            stag.members = symbols;
            symbols = symbolsSave;
            check(TOK.rightCurly);

            if (tag && (!stag.members || stag.members.length == 0)) // C11 6.7.2.1-2
                error("no struct-declarator-list for `%s %s`", structOrUnion.toChars(), tag.toChars());
        }
        else if (!tag)
            error("missing `identifier` after `%s`", structOrUnion.toChars());

        return new AST.TypeStruct(stag);
    }

    //}
    /******************************************************************************/
    /********************************* Lookahead Parser ***************************/
    //{

    /************************************
     * Determine if the scanner is sitting on the start of a declaration.
     * Params:
     *      t       = current token of the scanner
     *      needId  = flag with additional requirements for a declaration
     *      endtok  = ending token
     *      pt      = will be set ending token (if not null)
     * Returns:
     *      true at start of a declaration
     */
    private bool isCDeclaration(ref Token* pt)
    {
        //printf("isCDeclaration()\n");
        auto t = pt;
        if (!isDeclarationSpecifiers(t))
            return false;

        while (1)
        {
            if (t.value == TOK.semicolon)
            {
                t = peek(t);
                pt = t;
                return true;
            }
            if (!isCDeclarator(t, false))
                return false;
            if (t.value == TOK.asm_)
            {
                t = peek(t);
                if (t.value != TOK.leftParenthesis || !skipParens(t, &t))
                    return false;
            }
            if (t.value == TOK.assign)
            {
                t = peek(t);
                if (!isInitializer(t))
                    return false;
            }
            switch (t.value)
            {
                case TOK.comma:
                    t = peek(t);
                    break;

                case TOK.semicolon:
                    t = peek(t);
                    pt = t;
                    return true;

                default:
                    return false;
            }
        }
    }

    /********************************
     * See if match for initializer.
     * Params:
     *  pt = starting token, updated to one past end of initializer if true
     * Returns:
     *  true if initializer
     */
    private bool isInitializer(ref Token* pt)
    {
        //printf("isInitializer()\n");
        auto t = pt;

        if (t.value == TOK.leftCurly)
        {
            if (!skipBraces(t))
                return false;
            t = peek(t);
            return true;
        }

        // skip over assignment-expression, ending before comma or semiColon or EOF
        if (!isAssignmentExpression(t))
            return false;
        t = peek(t);
        return true;
    }

    /********************************
     * See if match for assignment-expression.
     * Params:
     *  pt = starting token, updated to one past end of assignment-expression if true
     * Returns:
     *  true if assignment-expression
     */
    private bool isAssignmentExpression(ref Token* pt)
    {
        //printf("isAssignmentExpression()\n");
        auto t = pt;

        /* This doesn't actually check for grammar matching an
         * assignment-expression. It just matches ( ) [ ] looking for
         * an ending token that would terminate one.
         */
        bool any;
        while (1)
        {
            switch (t.value)
            {
                case TOK.comma:
                case TOK.semicolon:
                case TOK.rightParenthesis:
                case TOK.rightBracket:
                case TOK.endOfFile:
                    if (!any)
                        return false;
                    break;

                case TOK.leftParenthesis:
                    if (!skipParens(t, &t))
                        return false;
                    continue;

                case TOK.leftBracket:
                    if (!skipBrackets(t))
                        return false;
                    continue;

                default:
                    any = true;   // assume token was part of an a-e
                    t = peek(t);
                    continue;
            }
            pt = t;
            return true;
        }
    }

    /********************************
     * See if match for constant-expression.
     * Params:
     *  pt = starting token, updated to one past end of constant-expression if true
     * Returns:
     *  true if constant-expression
     */
    private bool isConstantExpression(ref Token* pt)
    {
        return isAssignmentExpression(pt);
    }

    /********************************
     * See if match for declaration-specifiers.
     * No errors are diagnosed.
     * Params:
     *  pt = starting token, updated to one past end of declaration-specifiers if true
     * Returns:
     *  true if declaration-specifiers
     */
    private bool isDeclarationSpecifiers(ref Token* pt)
    {
        //printf("isDeclarationSpecifiers()\n");

        auto t = pt;

        bool any;
        while (1)
        {
            switch (t.value)
            {
                // type-specifiers
                case TOK.void_:
                case TOK.char_:
                case TOK.int16:
                case TOK.int32:
                case TOK.int64:
                case TOK.float32:
                case TOK.float64:
                case TOK.signed:
                case TOK.unsigned:
                case TOK._Bool:
                //case TOK._Imaginary:
                case TOK._Complex:
                case TOK.identifier: // typedef-name

                case TOK.struct_:
                case TOK.union_:
                case TOK.enum_:
                    t = peek(t);
                    if (t.value == TOK.identifier)
                    {
                        t = peek(t);
                        if (t.value == TOK.leftCurly)
                        {
                            if (!skipBraces(t))
                                return false;
                        }
                    }
                    else if (t.value == TOK.leftCurly)
                    {
                        if (!skipBraces(t))
                            return false;
                    }
                    else
                        return false;
                    any = true;
                    continue;

                // storage-class-specifiers
                case TOK.typedef_:
                case TOK.extern_:
                case TOK.static_:
                case TOK._Thread_local:
                case TOK.auto_:
                case TOK.register:

                // function-specifiers
                case TOK.inline:
                case TOK._Noreturn:

                // type-qualifiers
                case TOK.const_:
                case TOK.volatile:
                case TOK.restrict:
                case TOK.__restrict:
                    t = peek(t);
                    any = true;
                    continue;

                case TOK._Alignas:      // alignment-specifier
                case TOK.__declspec:    // decl-specifier
                case TOK.__attribute__: // attribute-specifier
                    t = peek(t);
                    if (!skipParens(t, &t))
                        return false;
                    any = true;
                    continue;

                // either atomic-type-specifier or type_qualifier
                case TOK._Atomic:  // TODO _Atomic ( type-name )
                    t = peek(t);
                    if (t.value == TOK.leftParenthesis) // maybe atomic-type-specifier
                    {
                        auto tsave = t;
                        t = peek(t);
                        if (!isTypeName(t) || t.value != TOK.rightParenthesis)
                        {   // it's a type-qualifier
                            t = tsave;  // back up parser
                            any = true;
                            continue;
                        }
                        t = peek(t);    // move past right parenthesis of atomic-type-specifier
                    }
                    any = true;
                    continue;

                default:
                    break;
            }
            break;
        }

        if (any)
        {
            pt = t;
            return true;
        }
        return false;
    }

    /**************************************
     * See if declaration-list is present.
     * Returns:
     *    true if declaration-list is present, even an empty one
     */
    bool isDeclarationList(ref Token* pt)
    {
        auto t = pt;
        while (1)
        {
            if (t.value == TOK.leftCurly)
            {
                pt = t;
                return true;
            }
            if (!isCDeclaration(t))
                return false;
        }
    }

    /*******************************************
     * Skip braces.
     * Params:
     *      pt = enters on left brace, set to token past right bracket on true
     * Returns:
     *      true if successful
     */
    private bool skipBraces(ref Token* pt)
    {
        auto t = pt;
        if (t.value != TOK.leftCurly)
            return false;

        int braces = 0;

        while (1)
        {
            switch (t.value)
            {
                case TOK.leftCurly:
                    ++braces;
                    t = peek(t);
                    continue;

                case TOK.rightCurly:
                    --braces;
                    if (braces == 0)
                    {
                        pt = peek(t);
                        return true;
                    }
                    if (braces < 0)
                        return false;

                    t = peek(t);
                    continue;

                case TOK.endOfFile:
                    return false;

                default:
                    t = peek(t);
                    continue;
            }
        }
    }

    /*******************************************
     * Skip brackets.
     * Params:
     *      pt = enters on left bracket, set to token past right bracket on true
     * Returns:
     *      true if successful
     */
    private bool skipBrackets(ref Token* pt)
    {
        auto t = pt;
        if (t.value != TOK.leftBracket)
            return false;

        int brackets = 0;

        while (1)
        {
            switch (t.value)
            {
                case TOK.leftBracket:
                    ++brackets;
                    t = peek(t);
                    continue;

                case TOK.rightBracket:
                    --brackets;
                    if (brackets == 0)
                    {
                        pt = peek(t);
                        return true;
                    }
                    if (brackets < 0)
                        return false;

                    t = peek(t);
                    continue;

                case TOK.endOfFile:
                    return false;

                default:
                    t = peek(t);
                    continue;
            }
        }
    }

    /*********************************
     * Check to see if tokens starting with *pt form a declarator.
     * Params:
     *  pt = pointer to starting token, updated to point past declarator if true is returned
     *  isAbstract = true if abstract-declarator instead of just declarator
     * Returns:
     *  true if it does
     */
    private bool isCDeclarator(ref Token* pt, bool isAbstract)
    {
        auto t = pt;
        if (t.value == TOK.colon)
        {
            t = peek(t);
            if (!isConstantExpression(t))
                return false;
            return true;        // unnamed bit-field
        }
        while (1)
        {
            if (t.value == TOK.mul)     // pointer
            {
                t = peek(t);
                if (!isTypeQualifierList(t))
                    return false;
            }
            else
                break;
        }

        if (t.value == TOK.identifier)
        {
            if (isAbstract)
                return false;
            t = peek(t);
        }
        else if (t.value == TOK.leftParenthesis)
        {
            t = peek(t);
            if (!isCDeclarator(t, isAbstract))
                return false;
            if (t.value != TOK.rightParenthesis)
                return false;
            t = peek(t);
        }
        else
            return true;        // declarator is optional

        if (t.value == TOK.leftBracket)
        {
            if (!skipBrackets(t))
                return false;
        }
        else if (t.value == TOK.leftParenthesis)
        {
            if (!skipParens(t, &t))
                 return false;
        }

        if (t.value == TOK.colon)
        {
            t = peek(t);
            if (!isConstantExpression(t))
                return false;
        }
        pt = t;
        return true;
    }

    /***************************
     * Is this the start of a type-qualifier-list?
     * (Can be empty.)
     * Params:
     *  pt = first token; updated with past end of type-qualifier-list if true
     * Returns:
     *  true if start of type-qualifier-list
     */
    private bool isTypeQualifierList(ref Token* pt)
    {
        auto t = pt;
        while (1)
        {
            switch (t.value)
            {
                case TOK.const_:
                case TOK.restrict:
                case TOK.__restrict:
                case TOK.volatile:
                case TOK._Atomic:
                    t = peek(t);
                    continue;

                default:
                    break;
            }
            break;
        }
        pt = t;
        return true;
    }

    /***************************
     * Is this the start of a type-name?
     * Params:
     *  pt = first token; updated with past end of type-name if true
     * Returns:
     *  true if start of type-name
     */
    private bool isTypeName(ref Token* pt)
    {
        auto t = pt;
        if (!isSpecifierQualifierList(t))
            return false;
        if (!isCDeclarator(t, true))
            return false;
        pt = t;
        return true;
    }

    /***************************
     * Is this the start of a specifier-qualifier-list?
     * Params:
     *  pt = first token; updated with past end of specifier-qualifier-list if true
     * Returns:
     *  true if start of specifier-qualifier-list
     */
    private bool isSpecifierQualifierList(ref Token* pt)
    {
        auto t = pt;
        bool result;
        while (1)
        {
            switch (t.value)
            {
                // Type Qualifiers
                case TOK.const_:
                case TOK.restrict:
                case TOK.__restrict:
                case TOK.volatile:

                // Type Specifiers
                case TOK.char_:
                case TOK.signed:
                case TOK.unsigned:
                case TOK.int16:
                case TOK.int32:
                case TOK.int64:
                case TOK.float32:
                case TOK.float64:
                case TOK.void_:
                case TOK._Bool:
                //case TOK._Imaginary: // ? missing in Spec
                case TOK._Complex:

                // typedef-name
                case TOK.identifier:    // will not know until semantic if typedef
                    t = peek(t);
                    break;

                // struct-or-union-specifier
                // enum-specifier
                case TOK.struct_:
                case TOK.union_:
                case TOK.enum_:
                    t = peek(t);
                    if (t.value == TOK.identifier)
                    {
                        t = peek(t);
                        if (t.value == TOK.leftCurly)
                        {
                            if (!skipBraces(t))
                                return false;
                        }
                    }
                    else if (t.value == TOK.leftCurly)
                    {
                        if (!skipBraces(t))
                            return false;
                    }
                    else
                        return false;
                    break;

                // atomic-type-specifier
                case TOK._Atomic:
                    t = peek(t);
                    if (t.value != TOK.leftParenthesis ||
                        !skipParens(t, &t))
                        return false;
                    break;

                default:
                    if (result)
                        pt = t;
                    return result;
            }
            result = true;
        }
    }

    //}
    /******************************************************************************/
    /********************************* More ***************************************/
    //{

    /**************
     * Declaration context
     */
    enum LVL
    {
        global    = 1,    /// global
        parameter = 2,    /// function parameter (declarations for function identifier-list)
        prototype = 4,    /// function prototype
        local     = 8,    /// local
        member    = 0x10, /// struct member
    }

    /// C11 6.7.1 Storage-class specifiers
    enum SCW : uint
    {
        xnone      = 0,
        xtypedef   = 1,
        xextern    = 2,
        xstatic    = 4,
        x_Thread_local = 8,
        xauto      = 0x10,
        xregister  = 0x20,
        // C11 6.7.4 Function specifiers
        xinline    = 0x40,
        x_Noreturn = 0x80,
    }

    /// C11 6.7.3 Type qualifiers
    enum MOD : uint
    {
        xnone     = 0,
        xconst    = 1,
        xvolatile = 2,
        xrestrict = 4,
        x_Atomic  = 8,
    }

    /***********************
     * Convert from C storage class to D storage class
     * Params:
     *  level = declaration context
     *  scw = C storage class specifiers
     * Returns:
     *  corresponding D storage class
     */
    StorageClass SCWtoSTC(LVL level, SCW scw)
    {
        StorageClass stc;
        if (scw & SCW.x_Thread_local)
        {
            if (level == LVL.global)
            {
                if (scw & SCW.xextern)
                   stc = AST.STC.extern_;
            }
            else if (level == LVL.local)
            {
                if (scw & SCW.xextern)
                   stc = AST.STC.extern_;
                else if (scw & SCW.xstatic)
                    stc = AST.STC.static_;
            }
            else if (level == LVL.member)
            {
                if (scw & SCW.xextern)
                   stc = AST.STC.extern_;
                else if (scw & SCW.xstatic)
                    stc = AST.STC.static_;
            }
        }
        else
        {
            if (level == LVL.global)
            {
                if (scw & SCW.xextern)
                   stc = AST.STC.extern_ | AST.STC.gshared;
            }
            else if (level == LVL.local)
            {
                if (scw & SCW.xextern)
                   stc = AST.STC.extern_ | AST.STC.gshared;
                else if (scw & SCW.xstatic)
                    stc = AST.STC.gshared;
            }
            else if (level == LVL.member)
            {
                if (scw & SCW.xextern)
                   stc = AST.STC.extern_ | AST.STC.gshared;
                else if (scw & SCW.xstatic)
                    stc = AST.STC.gshared;
            }
        }
        return stc;
    }

    /***********************
     * Return suitable D float type for C `long double`
     * Params:
     *  flags = kind of float to return (real, imaginary, complex).
     * Returns:
     *  corresponding D type
     */
    private AST.Type realType(RTFlags flags)
    {
        if (long_doublesize == AST.Type.tfloat80.size())
        {
            // On GDC and LDC, D `real` types map to C `long double`, so never
            // return a double type when real.sizeof == double.sizeof.
            final switch (flags)
            {
                case RTFlags.realfloat: return AST.Type.tfloat80;
                case RTFlags.imaginary: return AST.Type.timaginary80;
                case RTFlags.complex:   return AST.Type.tcomplex80;
            }
        }
        else
        {
            final switch (flags)
            {
                case RTFlags.realfloat: return long_doublesize == 8 ? AST.Type.tfloat64 : AST.Type.tfloat80;
                case RTFlags.imaginary: return long_doublesize == 8 ? AST.Type.timaginary64 : AST.Type.timaginary80;
                case RTFlags.complex:   return long_doublesize == 8 ? AST.Type.tcomplex64 : AST.Type.tcomplex80;
            }
        }
    }

    /**************
     * Flags for realType
     */
    private enum RTFlags
    {
        realfloat,
        imaginary,
        complex,
    }

    /************************
     * After encountering an error, scan forward until a right brace or ; is found
     * or the end of the file.
     */
    void panic()
    {
        while (token.value != TOK.rightCurly && token.value != TOK.semicolon && token.value != TOK.endOfFile)
            nextToken();
    }

    //}
}

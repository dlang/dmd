// This file is part of Visual D
//
// Visual D integrates the D programming language into Visual Studio
// Copyright (c) 2010-2011 by Rainer Schuetze, All Rights Reserved
//
// Distributed under the Boost Software License, Version 1.0.
// See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt

module vdc.parser.decl;

import vdc.util;
import vdc.lexer;
import vdc.parser.engine;
import vdc.parser.expr;
import vdc.parser.misc;
import vdc.parser.tmpl;
import vdc.parser.mod;

import ast = vdc.ast.all;

import stdext.util;

//-- GRAMMAR_BEGIN --
//Declaration:
//    alias LinkageAttribute_opt Decl
//    typedef Decl /* for legacy code */
//    Decl
//    alias Identifier this
//    alias this = Identifier
class Declaration
{
    static Action enter(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_alias:
                p.pushState(&shiftAlias);
                return Accept;

            case TOK_typedef:
                p.pushState(&shiftTypedef);
                p.pushState(&Decl!true.enter);
                return Accept;
            default:
                return Decl!true.enter(p);
        }
    }

    static Action shiftAlias(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_extern:
                p.pushState(&shiftAliasLinkage);
                p.pushState(&Decl!true.enter);
                return LinkageAttribute.enter(p);

            case TOK_Identifier:
                p.pushToken(p.tok);
                p.pushState(&shiftAliasIdentifier);
                return Accept;

            case TOK_this:
                p.pushState(&shiftThis);
                return Accept;

            default:
                p.pushState(&shiftTypedef);
                return Decl!true.enter(p);
        }
    }

    static Action shiftAliasLinkage(Parser p)
    {
        auto decl = p.popNode!(ast.Decl)();
        auto link = p.popNode!(ast.AttributeSpecifier)();
        p.combineAttributes(decl.attr, link.attr);
        p.pushNode(decl);
        return Forward;
    }

    // assumes identifier token on the info stack
    static Action shiftAliasIdentifier(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_this:
                auto tok = p.popToken();
                p.pushNode(new ast.AliasThis(tok));
                p.pushState(&shiftAliasThis);
                return Accept;
            case TOK_assign:
                p.pushState(&shiftAliasAssign);
                p.pushState(&Type.enter);
                return Accept;
            default:
                p.pushState(&shiftTypedef);
                return Decl!true.enterTypeIdentifier(p);
        }
    }

    static Action shiftThis(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_assign:
                p.pushState(&shiftThisAssign);
                return Accept;
            default:
                return p.parseError("'=' expected after alias this");
        }
    }

    static Action shiftThisAssign(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_Identifier:
                p.pushNode(new ast.AliasThis(p.tok));
                p.pushState(&shiftAliasThis);
                return Accept;
            default:
                return p.parseError("identifier expected after alias this =");
        }
    }

    static Action shiftAliasThis(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_semicolon:
                return Accept;
            default:
                return p.parseError("semicolon expected after alias this;");
        }
    }

    // assumes identifier token on the info stack
    static Action shiftAliasAssign(Parser p)
    {
        auto type = static_cast!(ast.Type)(p.popNode());

        auto tok = p.popToken();
        auto decl = new ast.Decl(type.id, type.span);
        auto decls = new ast.Declarators(tok);
        decls.addMember(new ast.Declarator(tok));
        // insert type before declarator identifier
        decl.addMember(type);
        decl.addMember(decls);
        decl.isAlias = true;
        decl.hasSemi = true;
        p.pushNode(decl);

        switch(p.tok.id)
        {
            case TOK_semicolon:
                return Accept;
            case TOK_comma:
            default:
                return p.parseError("semicolon expected after alias identifier = type");
        }
    }

    static Action shiftTypedef(Parser p)
    {
        //p.appendReplaceTopNode(new ast.AliasDeclaration(p.tok));
        p.topNode!(ast.Decl)().isAlias = true;
        return Forward;
    }
}

//-- GRAMMAR_BEGIN --
//Decl:
//    StorageClasses Decl
//    BasicType BasicTypes2_opt Declarators ;
//    BasicType BasicTypes2_opt Declarator FunctionBody
//    AutoDeclaration
//
//AutoDeclaration:
//    StorageClasses Identifier = AssignExpression ;
class Decl(bool checkSemi = true)
{
    // storage class stored in Decl.attr, first child is Type (TOK_auto if not present)
    static Action enter(Parser p)
    {
        auto decl = new ast.Decl(p.tok);
        decl.hasSemi = checkSemi;
        p.pushNode(decl);

        if(isTypeModifier(p.tok.id))
        {
            // could be storage class or BasicType
            p.pushToken(p.tok);
            p.pushState(&shiftTypeModifier);
            return Accept;
        }
        if(isStorageClass(p.tok.id))
        {
            p.combineAttributes(decl.attr, tokenToAttribute(p.tok.id));
            p.combineAnnotations(decl.annotation, tokenToAnnotation(p.tok.id));
            p.pushState(&shiftStorageClass);
            return Accept;
        }
        p.pushState(&shiftBasicType);
        return BasicType.enter(p);
    }

    // switch here from AttributeSpecifier when detecting a '(' after const,etc
    // assumes modifier token on the info stack
    static Action enterAttributeSpecifier(Parser p)
    {
        assert(p.tok.id == TOK_lparen);

        auto decl = new ast.Decl(p.tok);
        decl.hasSemi = checkSemi;
        p.pushNode(decl);
        p.pushState(&shiftBasicType);
        return BasicType.shiftTypeModifier(p);
    }

    // disambiguate "const x" and "const(int) x"
    // assumes modifier token on the info stack
    static Action shiftTypeModifier(Parser p)
    {
        if(p.tok.id == TOK_lparen)
        {
            p.pushState(&shiftBasicType);
            return BasicType.shiftTypeModifier(p);
        }

        auto decl = p.topNode!(ast.Decl)();
        Token tok = p.popToken();
        p.combineAttributes(decl.attr, tokenToAttribute(tok.id));
        return shiftStorageClass(p);
    }

    static Action enterAfterStorageClass(Parser p, TokenId storage)
    {
        auto decl = new ast.Decl(p.tok);
        decl.hasSemi = checkSemi;
        p.pushNode(decl);
        decl.attr = tokenToAttribute(storage);
        return shiftStorageClass(p);
    }

    static Action shiftStorageClass(Parser p)
    {
        if(p.tok.id == TOK_Identifier)
        {
            p.pushToken(p.tok);
            p.pushState(&shiftIdentifier);
            return Accept;
        }
        if(isTypeModifier(p.tok.id))
        {
            // could be storage class or BasicType
            p.pushToken(p.tok);
            p.pushState(&shiftTypeModifier);
            return Accept;
        }
        if(isStorageClass(p.tok.id))
        {
            auto decl = p.topNode!(ast.Decl)();
            p.combineAttributes(decl.attr, tokenToAttribute(p.tok.id));
            p.combineAnnotations(decl.annotation, tokenToAnnotation(p.tok.id));
            p.pushState(&shiftStorageClass);
            return Accept;
        }
        p.pushState(&shiftBasicType);
        return BasicType.enter(p);
    }

    // switch here from Statement when detecting a declaration after an identifier
    // assumes identifier token on the info stack
    static Action enterTypeIdentifier(Parser p)
    {
        auto decl = new ast.Decl(p.tok);
        decl.hasSemi = checkSemi;
        p.pushNode(decl);

        p.pushState(&shiftBasicType);
        return BasicType.enterIdentifier(p);
    }

    // assumes identifier token on the info stack
    static Action enterIdentifier(Parser p)
    {
        auto decl = new ast.Decl(p.tok);
        decl.hasSemi = checkSemi;
        p.pushNode(decl);

        return shiftIdentifier(p);
    }

    // assumes identifier token on the info stack
    static Action shiftIdentifier(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_assign:
                auto bt = new ast.AutoType(TOK_auto, p.topToken().span);
                p.topNode!(ast.Decl)().addMember(bt);

                p.pushState(&shiftDeclarators);
                return Declarators.enterAfterIdentifier(p);
            case TOK_lparen:
                // storageclass identifier(... must be function with auto return
                auto bt = new ast.AutoType(TOK_auto, p.topToken().span);
                p.topNode!(ast.Decl).addMember(bt);
                p.pushState(&shiftDeclarators);
                return Declarators.enterAfterIdentifier(p);
            default:
                p.pushState(&shiftBasicType);
                return BasicType.enterIdentifier(p);
        }
    }

    // assumes identifier token on the info stack
    static Action enterAutoReturn(Parser p)
    {
        assert(p.tok.id == TOK_lparen);

        auto decl = new ast.Decl(p.topToken());
        decl.hasSemi = checkSemi;
        p.pushNode(decl);

        auto bt = new ast.AutoType(TOK_auto, p.topToken().span);
        decl.addMember(bt);

        p.pushState(&shiftDeclarators);
        return Declarators.enterAfterIdentifier(p);
    }

    static Action shiftBasicType(Parser p)
    {
        switch(p.tok.id)
        {
            mixin(BasicType2.case_TOKs);
                p.pushState(&shiftBasicTypes2);
                return BasicTypes2.enter(p);
            default:
                return shiftBasicTypes2(p);
        }
    }

    static Action shiftBasicTypes2(Parser p)
    {
        p.popAppendTopNode!(ast.Decl, ast.Type)();
        p.pushState(&shiftDeclarators);
        return Declarators.enter(p);
    }

    static Action shiftDeclarators(Parser p)
    {
        p.popAppendTopNode!(ast.Decl)();
        static if(checkSemi)
        {
            if(p.tok.id == TOK_RECOVER)
                return Forward;
            auto decl = p.topNode!(ast.Decl)();
            if(decl.members.length == 2 && // BasicType and Declarators
               decl.members[1].members.length == 1 && // only one declarator
               FunctionBody.isInitTerminal(p.tok))
            {
                decl.hasSemi = false;
                p.pushState(&shiftFunctionBody);
                return FunctionBody.enter(p);
            }
            if(p.tok.id != TOK_semicolon)
                return p.parseError("semicolon expected after declaration");
            return Accept;
        }
        else
        {
            return Forward;
        }
    }

    static Action shiftFunctionBody(Parser p)
    {
        p.popAppendTopNode!(ast.Decl)();
        return Forward;
    }
}

//-- GRAMMAR_BEGIN --
//Declarators:
//    DeclaratorInitializer
//    DeclaratorInitializer , DeclaratorIdentifierList
class Declarators
{
    mixin ListNode!(ast.Declarators, DeclaratorInitializer, TOK_comma);

    // assumes identifier token on the info stack
    static Action enterAfterIdentifier(Parser p)
    {
        p.pushNode(new ast.Declarators(p.tok));
        p.pushState(&shift);
        return DeclaratorInitializer.enterAfterIdentifier(p);
    }
}

//-- GRAMMAR_BEGIN --
//DeclaratorInitializer:
//    Declarator
//    Declarator = Initializer
class DeclaratorInitializer
{
    mixin OptionalNode!(ast.DeclaratorInitializer, Declarator, TOK_assign, Initializer);

    // assumes identifier token on the info stack
    static Action enterAfterIdentifier(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_assign:
                auto tok = p.popToken();
                p.pushNode(new ast.Declarator(tok));
                return shiftSubType1(p);
            default:
                p.pushState(&shiftSubType1);
                return Declarator.enterAfterIdentifier(p);
        }
    }
}

//-- GRAMMAR_BEGIN --
//DeclaratorIdentifierList:
//    DeclaratorIdentifier
//    DeclaratorIdentifier , DeclaratorIdentifierList
class DeclaratorIdentifierList
{
    mixin ListNode!(ast.DeclaratorIdentifierList, DeclaratorIdentifier, TOK_comma);
}

//-- GRAMMAR_BEGIN --
//DeclaratorIdentifier:
//    Identifier
//    Identifier = Initializer
class DeclaratorIdentifier
{
    mixin OptionalNode!(ast.DeclaratorIdentifier, Identifier, TOK_assign, Initializer);
}

//-- GRAMMAR_BEGIN --
//Initializer:
//    VoidInitializer
//    NonVoidInitializer
//
//NonVoidInitializer:
//    AssignExpression
//    ArrayInitializer  /* same as ArrayLiteral? */
//    StructInitializer
class Initializer
{
    static Action enter(Parser p)
    {
        if(p.tok.id == TOK_void)
        {
            p.pushRollback(&rollbackVoid);
            p.pushState(&shiftVoid);
            return Accept;
        }
        // StructInitializer not implemented
        return AssignExpression.enter(p);
    }

    static Action shiftVoid(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_dot:
                return p.parseError("unexpected '.' in void initializer");
            default:
                p.popRollback();
                p.pushNode(new ast.VoidInitializer(p.tok));
                return Forward;
        }
    }

    static Action rollbackVoid(Parser p)
    {
        return AssignExpression.enter(p);
    }
}

//-- GRAMMAR_BEGIN --
//BasicType:
//    BasicTypeX
//    . IdentifierList
//    IdentifierList
//    Typeof
//    Typeof . IdentifierList
//    ModifiedType
//    VectorType
//
//ModifiedType:
//    const ( Type )
//    immutable ( Type )
//    shared ( Type )
//    inout ( Type )
class BasicType
{
    static Action enter(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_dot:
            case TOK_Identifier:
                p.pushNode(new ast.IdentifierType(p.tok));
                p.pushState(&shiftIdentifierList);
                return GlobalIdentifierList.enter(p);
            case TOK_typeof:
                p.pushState(&shiftTypeof);
                return Typeof.enter(p);

            mixin(case_TOKs_BasicTypeX);
                p.pushNode(new ast.BasicType(p.tok));
                return Accept;

            mixin(case_TOKs_TypeModifier);
                p.pushToken(p.tok);
                p.pushState(&shiftTypeModifier);
                return Accept;

            case TOK___vector:
                return VectorType.enter(p);

            default:
                return p.parseError("unexpected token in BasicType");
        }
    }

    // assumes modifier token on the info stack
    static Action shiftTypeModifier(Parser p)
    {
        Token tok = p.popToken();
        p.pushNode(new ast.ModifiedType(tok));

        switch(p.tok.id)
        {
            case TOK_lparen:
                p.pushState(&shiftParenType);
                p.pushState(&Type.enter);
                return Accept;
            default:
                p.pushState(&shiftType);
                return Type.enter(p);
        }
    }

    static Action shiftParenType(Parser p)
    {
        if(p.tok.id != TOK_rparen)
            return p.parseError("closing parenthesis expected");
        p.popAppendTopNode();
        return Accept;
    }

    static Action shiftType(Parser p)
    {
        p.popAppendTopNode();
        return Forward;
    }

    // entry point on token after identifier
    // assumes identifier token on the info stack
    static Action enterIdentifier(Parser p)
    {
        p.pushNode(new ast.IdentifierType(p.topToken()));
        p.pushState(&shiftIdentifierList);
        return IdentifierList.enterAfterIdentifier(p);
    }

    static Action shiftIdentifierList(Parser p)
    {
        p.popAppendTopNode!(ast.IdentifierType)();
        return Forward;
    }

    static Action shiftTypeof(Parser p)
    {
        if(p.tok.id != TOK_dot)
            return Forward;

        p.pushState(&shiftTypeofIdentifierList);
        p.pushState(&IdentifierList.enter);
        return Accept;
    }

    static Action shiftTypeofIdentifierList(Parser p)
    {
        p.popAppendTopNode!(ast.Typeof, ast.IdentifierList)();
        return Forward;
    }

}

enum case_TOKs_TypeModifier = q{
        case TOK_const:
        case TOK_shared:
        case TOK_immutable:
        case TOK_inout:
};

bool isTypeModifier(TokenId tok)
{
    switch(tok)
    {
        mixin(case_TOKs_TypeModifier);
            return true;
        default:
            return false;
    }
}

//-- GRAMMAR_BEGIN --
//BasicTypeX:
//    bool
//    byte
//    ubyte
//    short
//    ushort
//    int
//    uint
//    long
//    ulong
//    char
//    wchar
//    dchar
//    float
//    double
//    real
//    ifloat
//    idouble
//    ireal
//    cfloat
//    cdouble
//    creal
//    void

bool isBasicTypeX(TokenId tok)
{
    switch(tok)
    {
        mixin(case_TOKs_BasicTypeX);
            return true;
        default:
            return false;
    }
}

//-- GRAMMAR_BEGIN --
//VectorType:
//    __vector ( Type )
class VectorType
{
    mixin SequenceNode!(ast.VectorType, TOK___vector, TOK_lparen, Type, TOK_rparen);
}

//-- GRAMMAR_BEGIN --
//Typeof:
//    typeof ( Expression )
//    typeof ( return )
class Typeof
{
    static Action enter(Parser p)
    {
        if(p.tok.id != TOK_typeof)
            return p.parseError("typeof expected");
        p.pushNode(new ast.Typeof(p.tok));
        p.pushState(&shiftLparen);
        return Accept;
    }

    static Action shiftLparen(Parser p)
    {
        if(p.tok.id != TOK_lparen)
            return p.parseError("opening parenthesis expected");
        p.pushState(&shiftArgument);
        return Accept;
    }

    static Action shiftArgument(Parser p)
    {
        if(p.tok.id == TOK_return)
        {
            p.topNode!(ast.Typeof).id = TOK_return;
            p.pushState(&shiftRparen);
            return Accept;
        }
        p.pushState(&shiftExpression);
        return Expression.enter(p);
    }

    static Action shiftExpression(Parser p)
    {
        if(p.tok.id != TOK_rparen)
            return p.parseError("closing parenthesis expected");
        p.popAppendTopNode!(ast.Typeof)();
        return Accept;
    }

    static Action shiftRparen(Parser p)
    {
        if(p.tok.id != TOK_rparen)
            return p.parseError("closing parenthesis expected");
        return Accept;
    }
}

//-- GRAMMAR_BEGIN --
//Declarator:
//    Identifier DeclaratorSuffixes_opt
class Declarator
{
    static Action enter(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_Identifier:
                p.pushNode(new ast.Declarator(p.tok));
                p.pushState(&shiftIdentifier);
                return Accept;

            default:
                return p.parseError("unexpected token in Declarator");
        }
    }

    static Action shiftIdentifier(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_lparen:
            case TOK_lbracket:
                return DeclaratorSuffixes.enter(p); // appends to Declarator
            default:
                return Forward;
        }
    }

    // assumes identifier token on the info stack
    static Action enterAfterIdentifier(Parser p)
    {
        auto tok = p.popToken();
        p.pushNode(new ast.Declarator(tok));
        return shiftIdentifier(p);
    }
}

//-- GRAMMAR_BEGIN --
// always optional
//BasicType2:
//    *
//    [ ]
//    [ AssignExpression ]
//    [ AssignExpression .. AssignExpression ]
//    [ Type ]
//    delegate Parameters FunctionAttributes_opt
//    function Parameters FunctionAttributes_opt
class BasicType2
{
    enum case_TOKs = q{
            case TOK_mul:
            case TOK_lbracket:
            case TOK_delegate:
            case TOK_function:
    };

    static Action enter(Parser p)
    {
        assert(p.topNode!(ast.Type));
        switch(p.tok.id)
        {
            case TOK_mul:
                p.appendReplaceTopNode(new ast.TypePointer(p.tok));
                return Accept;
            case TOK_lbracket:
                p.pushState(&shiftLbracket);
                return Accept;

            case TOK_delegate:
                p.appendReplaceTopNode(new ast.TypeDelegate(p.tok));
                p.pushState(&shiftParameters);
                p.pushState(&Parameters.enter);
                return Accept;

            case TOK_function:
                p.appendReplaceTopNode(new ast.TypeFunction(p.tok));
                p.pushState(&shiftParameters);
                p.pushState(&Parameters.enter);
                return Accept;
            default:
                return p.parseError("unexpected token in BasicType2");
        }
    }

    static Action shiftLbracket(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_rbracket:
                p.appendReplaceTopNode(new ast.TypeDynamicArray(p.tok));
                return Accept;
            default:
                p.pushState(&shiftTypeOrExpression);
                return TypeOrExpression!TOK_rbracket.enter(p);
        }
    }

    static Action shiftTypeOrExpression(Parser p)
    {
        if(cast(ast.Type) p.topNode())
        {
            auto keyType = p.popNode!(ast.Type);
            p.appendReplaceTopNode(new ast.TypeAssocArray(p.tok));
            p.topNode().addMember(keyType);
            if(p.tok.id != TOK_rbracket)
                return p.parseError("']' expected");
            return Accept;
        }

        switch(p.tok.id)
        {
            case TOK_rbracket:
                auto dim = p.popNode!(ast.Expression);
                p.appendReplaceTopNode(new ast.TypeStaticArray(p.tok));
                p.topNode().addMember(dim);
                return Accept;
            case TOK_slice:
                auto low = p.popNode!(ast.Expression);
                p.appendReplaceTopNode(new ast.TypeArraySlice(p.tok));
                p.topNode().addMember(low);
                p.pushState(&shiftSliceUpper);
                p.pushState(&AssignExpression.enter);
                return Accept;
            default:
                return p.parseError("']' expected");
        }
    }

    static Action shiftSliceUpper(Parser p)
    {
        p.popAppendTopNode!(ast.TypeArraySlice)();
        switch(p.tok.id)
        {
            case TOK_rbracket:
                return Accept;
            default:
                return p.parseError("']' expected");
        }
    }

    static Action shiftParameters(Parser p)
    {
        p.popAppendTopNode();
        return shiftAttributes(p);
    }

    static Action shiftAttributes(Parser p)
    {
        switch(p.tok.id)
        {
            mixin(case_TOKs_MemberFunctionAttribute); // no member attributes?
                {
                    auto type = p.topNode!(ast.Type);
                    p.combineAttributes(type.attr, tokenToAttribute(p.tok.id));
                    p.pushState(&shiftAttributes);
                }
                return Accept;
            default:
                return Forward;
        }
    }
}

//-- GRAMMAR_BEGIN --
//BasicTypes2:
//    BasicType2
//    BasicType2 BasicTypes2
class BasicTypes2
{
    static Action enter(Parser p)
    {
        assert(p.topNode!(ast.Type));
        switch(p.tok.id)
        {
            mixin(BasicType2.case_TOKs);
                p.pushState(&shiftBasicType);
                return BasicType2.enter(p);
            default:
                return p.parseError("unexpected token in BasicType2");
        }
    }

    static Action shiftBasicType(Parser p)
    {
        switch(p.tok.id)
        {
            mixin(BasicType2.case_TOKs);
                p.pushState(&shiftBasicType);
                return BasicType2.enter(p);
            default:
                return Forward;
        }
    }
}

//-- GRAMMAR_BEGIN --
//DeclaratorSuffixes:
//    DeclaratorSuffix
//    DeclaratorSuffix DeclaratorSuffixes
//
// obsolete C-style?
//DeclaratorSuffix:
//    TemplateParameterList_opt Parameters MemberFunctionAttributes_opt Constraint_opt
//    [ ]
//    [ AssignExpression ]
//    [ Type ]
class DeclaratorSuffixes
{
    static Action enter(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_lparen:
                p.pushRollback(&rollbackParametersFailure);
                p.pushState(&shiftParameters);
                return Parameters.enter(p);
            case TOK_lbracket:
                p.pushState(&shiftLbracket);
                return Accept;
            default:
                return p.parseError("opening parenthesis or bracket expected");
        }
    }

    static Action nextSuffix(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_lbracket:
                p.pushState(&shiftLbracket);
                return Accept;
            default:
                return Forward;
        }
    }

    static Action shiftLbracket(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_rbracket:
                p.topNode().addMember(new ast.SuffixDynamicArray(p.tok));
                p.pushState(&nextSuffix);
                return Accept;
            default:
                p.pushState(&shiftTypeOrExpression);
                return TypeOrExpression!(TOK_rbracket).enter(p);
        }
        // return p.notImplementedError("C style declarators");
    }

    static Action shiftTypeOrExpression(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_rbracket:
                auto node = p.popNode();
                ast.Node n = new ast.SuffixArray(p.tok);
                n.addMember(node);
                p.topNode().addMember(n);
                p.pushState(&nextSuffix);
                return Accept;
            default:
                return p.parseError("']' expected in C style declarator");
        }
    }

    static Action shiftParameters(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_lparen:
                // somehow made it through the parameters, but another parameters list follow...
                return Reject; // so rollback to retry with template parameter list

            mixin(case_TOKs_MemberFunctionAttribute);
                p.popRollback();
                auto param = p.topNode!(ast.ParameterList);
                p.combineAttributes(param.attr, tokenToAttribute(p.tok.id));
                p.pushState(&shiftMemberFunctionAttribute);
                return Accept;
            case TOK_if:
                p.popRollback();
                p.popAppendTopNode!(ast.Declarator, ast.ParameterList)();
                p.pushState(&shiftConstraint);
                return Constraint.enter(p);
            default:
                p.popRollback();
                p.popAppendTopNode!(ast.Declarator, ast.ParameterList)();
                return Forward;
        }
    }

    static Action shiftMemberFunctionAttribute(Parser p)
    {
        switch(p.tok.id)
        {
            mixin(case_TOKs_MemberFunctionAttribute);
                {
                    auto param = p.topNode!(ast.ParameterList);
                    p.combineAttributes(param.attr, tokenToAttribute(p.tok.id));
                    p.pushState(&shiftMemberFunctionAttribute);
                }
                return Accept;
            case TOK_if:
                p.popAppendTopNode!(ast.Declarator, ast.ParameterList)();
                p.pushState(&shiftConstraint);
                return Constraint.enter(p);
            default:
                p.popAppendTopNode!(ast.Declarator, ast.ParameterList)();
                return Forward;
        }
    }

    static Action shiftConstraint(Parser p)
    {
        p.popAppendTopNode!(ast.Declarator, ast.Constraint)();
        return Forward;
    }

    static Action rollbackParametersFailure(Parser p)
    {
        p.pushState(&shiftTemplateParameterList);
        return TemplateParameters.enter(p);
    }

    static Action shiftTemplateParameterList(Parser p)
    {
        p.popAppendTopNode(); // append to declarator
        switch(p.tok.id)
        {
            case TOK_lparen:
                p.pushState(&shiftParametersAfterTempl);
                return Parameters.enter(p);
            default:
                return p.parseError("parameter list expected after template arguments");
        }
    }

    static Action shiftParametersAfterTempl(Parser p)
    {
        return shiftMemberFunctionAttribute(p);
    }
}

//-- GRAMMAR_BEGIN --
//GlobalIdentifierList:
//    IdentifierList
//    . IdentifierList
class GlobalIdentifierList
{
    static Action enter(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_dot:
                return IdentifierList.enterGlobal(p);
            default:
                return IdentifierList.enter(p);
        }
    }

}

//-- GRAMMAR_BEGIN --
//IdentifierList:
//    Identifier
//    Identifier . IdentifierList
//    TemplateInstance
//    TemplateInstance . IdentifierList
//
// using IdentifierOrTemplateInstance
class IdentifierList
{
    mixin ListNode!(ast.IdentifierList, IdentifierOrTemplateInstance, TOK_dot);

    // if preceded by '.', enter here fore global scope
    static Action enterGlobal(Parser p)
    {
        assert(p.tok.id == TOK_dot);

        auto list = new ast.IdentifierList(p.tok);
        list.global = true;
        p.pushNode(list);
        p.pushState(&shift);
        p.pushState(&IdentifierOrTemplateInstance.enter);
        return Accept;
    }

    // assumes identifier token on the info stack
    static Action enterAfterIdentifier(Parser p)
    {
        auto list = new ast.IdentifierList(p.topToken());
        p.pushNode(list);
        p.pushState(&shift);
        return IdentifierOrTemplateInstance.enterIdentifier(p);
    }
}

class Identifier
{
    static Action enter(Parser p)
    {
        if(p.tok.id != TOK_Identifier)
            return p.parseError("identifier expected");

        p.pushNode(new ast.Identifier(p.tok));
        return Accept;
    }
}

//-- GRAMMAR_BEGIN --
//StorageClasses:
//    StorageClass
//    StorageClass StorageClasses
//
//StorageClass:
//    AttributeOrStorageClass
//    extern
//    nothrow
//    pure
//    synchronized
bool isStorageClass(TokenId tok)
{
    switch(tok)
    {
        case TOK_extern:
        case TOK_synchronized:
        mixin(case_TOKs_FunctionAttribute);
        mixin(case_TOKs_AttributeOrStorageClass);
            return true;
        default:
            return false;
    }
}

//-- GRAMMAR_BEGIN --
//AttributeOrStorageClass:
//    deprecated
//    static
//    final
//    override
//    abstract
//    const
//    auto
//    scope
//  __gshared
//  __thread
//    shared
//    immutable
//    inout
//    ref
enum case_TOKs_AttributeOrStorageClass = q{
        case TOK_deprecated:
        case TOK_static:
        case TOK_final:
        case TOK_override:
        case TOK_abstract:
        case TOK_const:
        case TOK_auto:
        case TOK_scope:
        case TOK_volatile:
        case TOK___gshared:
        case TOK___thread:
        case TOK_shared:
        case TOK_immutable:
        case TOK_inout:
        case TOK_ref:
};
bool isAttributeOrStorageClass(TokenId tok)
{
    switch(tok)
    {
        mixin(case_TOKs_AttributeOrStorageClass);
            return true;
        default:
            return false;
    }
}

//-- GRAMMAR_BEGIN --
//Type:
//    BasicType
//    BasicType Declarator2
//
//Declarator2:
//    BasicType2 Declarator2
//    ( Declarator2 )
//    ( Declarator2 ) DeclaratorSuffixes
//
class Type
{
    static Action enter(Parser p)
    {
        p.pushState(&shiftBasicType);
        return BasicType.enter(p);
    }

    static Action shiftBasicType(Parser p)
    {
        switch(p.tok.id)
        {
            mixin(BasicType2.case_TOKs);
                p.pushState(&shiftBasicType);
                return BasicType2.enter(p);

            case TOK_lparen:
// not implemented, better forward, it might also be constructor arguments
//                p.pushState(&shiftDeclarator2);
//                return Accept;

            default:
                return Forward;
        }
    }

    // entry point from EnumMember: Type Identifier = AssignExpression
    // and             ForeachType: ref_opt Type_opt Identifier
    // assumes identifier pushed onto token stack
    static Action enterIdentifier(Parser p)
    {
        p.pushState(&shiftBasicType);
        return BasicType.enterIdentifier(p);
    }

    // assumes modifier token on the info stack
    static Action enterTypeModifier(Parser p)
    {
        p.pushState(&shiftBasicType);
        return BasicType.shiftTypeModifier(p);
    }

    static Action shiftDeclarator2(Parser p)
    {
        return p.notImplementedError();
    }

}

//-- GRAMMAR_BEGIN --
//TypeWithModifier:
//    Type
//    const TypeWithModifier
//    immutable TypeWithModifier
//    inout TypeWithModifier
//    shared TypeWithModifier
class TypeWithModifier
{
    static Action enter(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_const:
            case TOK_immutable:
            case TOK_inout:
            case TOK_shared:
                p.pushToken(p.tok);
                p.pushState(&shiftModifier);
                return Accept;
            default:
                return Type.enter(p);
        }
    }

    static Action shiftModifier(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_lparen:
                return Type.enterTypeModifier(p);

            default:
                auto tok = p.popToken();
                p.pushNode(new ast.ModifiedType(tok));
                p.pushState(&shiftModifiedType);
                return enter(p);
        }
    }

    static Action shiftModifiedType(Parser p)
    {
        p.popAppendTopNode!(ast.ModifiedType)();
        return Forward;
    }
}

//-- GRAMMAR_BEGIN --
//Parameters:
//    ( ParameterList )
//    ( )
class Parameters
{
    static Action enter(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_lparen:
                p.pushState(&shiftLparen);
                return Accept;
            default:
                return p.parseError("opening parenthesis expected in parameter list");
        }
    }

    static Action shiftLparen(Parser p)
    {
        if(p.tok.id == TOK_rparen)
        {
            p.pushNode(new ast.ParameterList(p.tok));
            return Accept;
        }
        p.pushState(&shiftParameterList);
        return ParameterList.enter(p);
    }

    static Action shiftParameterList(Parser p)
    {
        if(p.tok.id != TOK_rparen)
            return p.parseError("closing parenthesis expected for parameter list");
        return Accept;
    }
}

//-- GRAMMAR_BEGIN --
//ParameterList:
//    Parameter
//    Parameter , ParameterList
//    Parameter ...
//    ...
class ParameterList
{
    static Action enter(Parser p)
    {
        p.pushNode(new ast.ParameterList(p.tok));
        return shift(p);
    }

    static Action shift(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_dotdotdot:
                p.topNode!(ast.ParameterList)().anonymous_varargs = true;
                return Accept;
            default:
                p.pushState(&shiftParameter);
                return Parameter.enter(p);
        }
    }

    static Action shiftParameter(Parser p)
    {
        p.popAppendTopNode!(ast.ParameterList)();

        switch(p.tok.id)
        {
            case TOK_dotdotdot:
                p.topNode!(ast.ParameterList)().varargs = true;
                return Accept;
            case TOK_comma:
                p.pushState(&shift);
                return Accept;
            default:
                return Forward;
        }
    }
}

//-- GRAMMAR_BEGIN --
///* Declarator replaced with ParameterDeclarator */
//Parameter:
//    InOut_opt ParameterDeclarator DefaultInitializerExpression_opt
//
//DefaultInitializerExpression:
//    = AssignExpression
//    = __FILE__ // already in primary expression
//    = __LINE__ // already in primary expression
class Parameter
{
    static Action enter(Parser p)
    {
        p.pushNode(new ast.Parameter(p.tok));
        p.pushState(&shiftParameterDeclarator);

        if(isInOut(p.tok.id))
        {
            p.topNode!(ast.Parameter)().io = p.tok.id;
            p.pushState(&ParameterDeclarator.enter);
            return Accept;
        }
        return ParameterDeclarator.enter(p);
    }

    static Action shiftParameterDeclarator(Parser p)
    {
        p.popAppendTopNode!(ast.Parameter)();
        if(p.tok.id != TOK_assign)
            return Forward;
        p.pushState(&shiftInitializer);
        p.pushState(&AssignExpression.enter);
        return Accept;
    }

    static Action shiftInitializer(Parser p)
    {
        p.popAppendTopNode!(ast.Parameter)();
        return Forward;
    }
}

//-- GRAMMAR_BEGIN --
//ParameterDeclarator:
//    StorageClasses_opt BasicType BasicTypes2_opt Declarator_opt
// /*Identifier DeclaratorSuffixes_opt*/
class ParameterDeclarator
{
    // very similar to Decl, combine?
    // differences: no auto, single Declarator only
    static Action enter(Parser p)
    {
        auto decl = new ast.ParameterDeclarator(p.tok);
        p.pushNode(decl);
        return shift(p);
    }

    static Action shift(Parser p)
    {
        if(isTypeModifier(p.tok.id))
        {
            // could be storage class or BasicType
            p.pushToken(p.tok);
            p.pushState(&shiftTypeModifier);
            return Accept;
        }
        if(isStorageClass(p.tok.id))
        {
            auto decl = p.topNode!(ast.ParameterDeclarator)();
            p.combineAttributes(decl.attr, tokenToAttribute(p.tok.id));
            p.combineAnnotations(decl.annotation, tokenToAnnotation(p.tok.id));
            p.pushState(&shiftStorageClass);
            return Accept;
        }
        p.pushState(&shiftBasicType);
        return BasicType.enter(p);
    }

    // disambiguate "const x" and "const(int) x"
    // assumes modifier token on the info stack
    static Action shiftTypeModifier(Parser p)
    {
        if(p.tok.id == TOK_lparen)
        {
            p.pushState(&shiftBasicType);
            return BasicType.shiftTypeModifier(p);
        }

        auto decl = p.topNode!(ast.ParameterDeclarator)();
        Token tok = p.popToken();
        p.combineAttributes(decl.attr, tokenToAttribute(tok.id));
        return shift(p);
    }

    static Action shiftStorageClass(Parser p)
    {
        if(isTypeModifier(p.tok.id))
        {
            // could be storage class or BasicType
            p.pushToken(p.tok);
            p.pushState(&shiftTypeModifier);
            return Accept;
        }
        if(isStorageClass(p.tok.id))
        {
            auto decl = p.topNode!(ast.ParameterDeclarator)();
            p.combineAttributes(decl.attr, tokenToAttribute(p.tok.id));
            p.combineAnnotations(decl.annotation, tokenToAnnotation(p.tok.id));
            p.pushState(&shiftStorageClass);
            return Accept;
        }
        p.pushState(&shiftBasicType);
        return BasicType.enter(p);
    }

    // switch here from TemplateValueParameter when detecting a declaration after an identifier
    // assumes identifier token on the info stack
    static Action enterTypeIdentifier(Parser p)
    {
        auto decl = new ast.ParameterDeclarator(p.tok);
        p.pushNode(decl);

        p.pushState(&shiftBasicType);
        return BasicType.enterIdentifier(p);
    }

    static Action shiftBasicType(Parser p)
    {
        switch(p.tok.id)
        {
            mixin(BasicType2.case_TOKs);
                p.pushState(&shiftBasicTypes2);
                return BasicTypes2.enter(p);
            default:
                return shiftBasicTypes2(p);
        }
    }

    static Action shiftBasicTypes2(Parser p)
    {
        p.popAppendTopNode!(ast.ParameterDeclarator, ast.Type)();
        if(p.tok.id != TOK_Identifier)
            return Forward;
        p.pushState(&shiftDeclarator);
        return Declarator.enter(p);
    }

    static Action shiftDeclarator(Parser p)
    {
        p.popAppendTopNode!(ast.ParameterDeclarator)();
        return Forward;
    }

}

//-- GRAMMAR_BEGIN --
//InOut:
//    in
//    out
//    ref
//    lazy
//    scope /* ? */
enum case_TOKs_InOut = q{
        case TOK_in:
        case TOK_out:
        case TOK_ref:
        case TOK_lazy:
        case TOK_scope:
};
bool isInOut(TokenId tok)
{
    switch(tok)
    {
        mixin(case_TOKs_InOut);
            return true;
        default:
            return false;
    }
}

//-- GRAMMAR_BEGIN --
//FunctionAttributes:
//    FunctionAttribute
//    FunctionAttribute FunctionAttributes
//
//FunctionAttribute:
//    nothrow
//    pure
enum case_TOKs_FunctionAttribute = q{
        case TOK_nothrow:
        case TOK_pure:
        case TOK_safe:
        case TOK_system:
        case TOK_trusted:
        case TOK_property:
        case TOK_disable:
        case TOK_nogc:
};

bool isFunctionAttribute(TokenId tok)
{
    switch(tok)
    {
        mixin(case_TOKs_FunctionAttribute);
            return true;
        default:
            return false;
    }
}

//-- GRAMMAR_BEGIN --
//MemberFunctionAttributes:
//    MemberFunctionAttribute
//    MemberFunctionAttribute MemberFunctionAttributes
//
//MemberFunctionAttribute:
//    const
//    immutable
//    inout
//    shared
//    FunctionAttribute
//
enum case_TOKs_MemberFunctionAttribute = q{
        case TOK_const:
        case TOK_immutable:
        case TOK_inout:
        case TOK_shared:
} ~ case_TOKs_FunctionAttribute;

bool isMemberFunctionAttribute(TokenId tok)
{
    switch(tok)
    {
        mixin(case_TOKs_MemberFunctionAttribute);
            return true;
        default:
            return false;
    }
}

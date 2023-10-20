// This file is part of Visual D
//
// Visual D integrates the D programming language into Visual Studio
// Copyright (c) 2010-2011 by Rainer Schuetze, All Rights Reserved
//
// Distributed under the Boost Software License, Version 1.0.
// See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt

module vdc.parser.mod;

import vdc.util;
import vdc.lexer;
import vdc.parser.engine;
import vdc.parser.decl;
import vdc.parser.expr;
import vdc.parser.misc;
import vdc.parser.aggr;
import vdc.parser.tmpl;
import vdc.parser.stmt;

import ast = vdc.ast.mod;

import std.conv;

////////////////////////////////////////////////////////////////

//-- GRAMMAR_BEGIN --
//Module:
//    ModuleDeclaration DeclDefs_opt
//    DeclDefs_opt
//
class Module
{
    static Action enter(Parser p)
    {
        p.pushNode(new ast.Module(p.tok));

        if(p.tok.id == TOK_module)
        {
            p.pushRecoverState(&recoverModuleDeclaration);

            p.pushState(&shiftModuleDeclaration);
            return ModuleDeclaration.enter(p);
        }

        if(p.tok.id == TOK_EOF)
            return Accept;

        p.pushState(&shiftModuleDeclDefs);
        return DeclDefs.enter(p);
    }

    static Action shiftModuleDeclaration(Parser p)
    {
        p.popAppendTopNode!(ast.Module)();
        if(p.tok.id == TOK_EOF)
            return Accept;

        p.pushState(&shiftModuleDeclDefs);
        return DeclDefs.enter(p);
    }

    static Action shiftModuleDeclDefs(Parser p)
    {
        if(p.tok.id != TOK_EOF)
        {
            // recover by assuming the mismatched braces, trying to add more declarations to the module
            p.pushRecoverState(&recoverModuleDeclaration);

            return p.parseError("EOF expected");
        }
        return Accept;
    }

    static Action recoverModuleDeclaration(Parser p)
    {
        p.pushState(&afterRecover);
        return Parser.recoverSemiCurly(p);
    }

    static Action recoverDeclDef(Parser p)
    {
        p.pushState(&afterRecover);
            return Parser.recoverSemiCurly(p);
    }

    static Action afterRecover(Parser p)
    {
        if(p.tok.id == TOK_EOF)
            return Accept;

        if(p.tok.id == TOK_rcurly)
        {
            // eat pending '}'
            p.pushState(&afterRecover);
            return Accept;
        }
        p.pushState(&shiftModuleDeclDefs);
        return DeclDefs.enter(p);
    }
}

//-- GRAMMAR_BEGIN --
//ModuleDeclaration:
//    module ModuleFullyQualifiedName ;
class ModuleDeclaration
{
    static Action enter(Parser p)
    {
        if(p.tok.id != TOK_module)
            return p.parseError("module expected");

        p.pushNode(new ast.ModuleDeclaration(p.tok));

        p.pushState(&shiftName);
        p.pushState(&ModuleFullyQualifiedName.enter);
        return Accept;
    }

    static Action shiftName(Parser p)
    {
        if(p.tok.id != TOK_semicolon)
            return p.parseError("semicolon expected");
        p.popAppendTopNode!(ast.ModuleDeclaration)();
        return Accept;
    }
}

//-- GRAMMAR_BEGIN --
//ModuleFullyQualifiedName:
//    ModuleName
//    Packages . ModuleName
//
//ModuleName:
//    Identifier
//
//Packages:
//    PackageName
//    Packages . PackageName
//
//PackageName:
//    Identifier
class ModuleFullyQualifiedName
{
    mixin ListNode!(ast.ModuleFullyQualifiedName, Identifier, TOK_dot);
}

/* might also be empty, but the grammar reflects this by the _opt suffix where used */
//-- GRAMMAR_BEGIN --
//DeclDefs:
//    DeclDef
//    DeclDef DeclDefs
class DeclDefs
{
    enum doNotPopNode = true;

    // does not create new Node, but inserts DeclDef into module or block
    static Action enter(Parser p)
    {
        if(p.tok.id == TOK_rcurly || p.tok.id == TOK_EOF)
            return Forward;

        p.pushRecoverState(&recover);
        p.pushState(&Parser.keepRecover);   // add a "guard" state to avoid popping recover

        p.pushState(&shiftDeclDef);
        return DeclDef.enter(p);
    }

    static Action next(Parser p)
    {
        if(p.tok.id == TOK_rcurly || p.tok.id == TOK_EOF || p.tok.id == TOK_RECOVER)
            return Forward;

        p.pushState(&shiftDeclDef);
        return DeclDef.enter(p);
    }

    static Action shiftDeclDef(Parser p)
    {
        p.popAppendTopNode();
        return next(p);
    }

    static Action recover(Parser p)
    {
        auto node = new ast.ParseRecoverNode(p.tok);
        if(p.nodeStack.depth)
            node.fulspan.start = p.topNode().fulspan.end; // record span of removed text
        p.pushNode(node);
        p.pushState(&afterRecover);
        return Parser.recoverSemiCurly(p);
    }

    static Action afterRecover(Parser p)
    {
        p.popAppendTopNode!(ast.Node, ast.ParseRecoverNode)();

        p.pushRecoverState(&recover);
        p.pushState(&Parser.keepRecover);   // add a "guard" state to avoid popping recover

        return next(p);
    }
}

//-- GRAMMAR_BEGIN --
//DeclDef:
//    AttributeSpecifier
//    PragmaSpecifier
//    ImportDeclaration
//    EnumDeclaration
//    ClassDeclaration
//    InterfaceDeclaration
//    AggregateDeclaration
//    Declaration
//    Constructor
//    Destructor
//    Invariant
//    UnitTest
//    StaticConstructor
//    StaticDestructor
//    SharedStaticConstructor
//    SharedStaticDestructor
//    DebugSpecification
//    VersionSpecification
//    ConditionalDeclaration
//    StaticAssert
//    TemplateDeclaration
//    TemplateMixinDeclaration
//    TemplateMixin
//    MixinDeclaration
//    ClassAllocator
//    ClassDeallocator
//    ;
class DeclDef
{
    // does not create new Node, but inserts DeclDef into module or block
    static Action enter(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_pragma:
                return Pragma.enter(p);
            case TOK_mixin:
                p.pushState(&shiftMixin);
                return Accept;
            case TOK_import:
                return ImportDeclaration.enter(p);
            case TOK_enum:
                return EnumDeclaration.enter(p);

            case TOK_struct:
            case TOK_union:
            case TOK_class:
            case TOK_interface:
                return AggregateDeclaration.enter(p);

            case TOK_this:
                return Constructor.enter(p);
            case TOK_tilde:
                return Destructor.enter(p);
            case TOK_invariant:
                return Invariant.enter(p);
            case TOK_unittest:
                return Unittest.enter(p);
            case TOK_debug:
                return DebugCondOrSpec.enter(p);
            case TOK_version:
                return VersionCondOrSpec.enter(p);
            case TOK_template:
                return TemplateDeclaration.enter(p);
            case TOK_new:
                return ClassAllocator.enter(p);
            case TOK_delete:
                return ClassDeallocator.enter(p);

            case TOK_semicolon:
                p.pushNode(new ast.EmptyDeclDef(p.tok));
                return Accept;

            case TOK_static:
                p.pushToken(p.tok);
                p.pushState(&shiftStatic);
                return Accept;

            default:
                if(AttributeSpecifier.tryenter(p) == Accept)
                    return Accept;
                return Declaration.enter(p);
        }
    }

    static Action shiftStatic(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_if: // only after static
                p.popToken();
                return ConditionalDeclaration.enterAfterStatic(p);
            case TOK_assert: // only after static
                p.popToken();
                return StaticAssert.enterAfterStatic(p);
            default:
                return AttributeSpecifier.enterAfterStatic(p);
        }
    }

    static Action shiftMixin(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_template:
                return TemplateMixinDeclaration.enterAfterMixin(p);
            case TOK_lparen:
                return MixinDeclaration.enterAfterMixin(p);
            default:
                return TemplateMixin.enterAfterMixin(p);
        }
    }
}

//-- GRAMMAR_BEGIN --
//AttributeSpecifier:
//    Attribute :
//    Attribute DeclarationBlock
//
//Attribute:
//    LinkageAttribute
//    AlignAttribute
//    AttributeOrStorageClass
//    ProtectionAttribute
//    @disable
//    @property
//    @safe
//    @system
//    @trusted
class AttributeSpecifier
{
    // no members means "Attribute:"

    static Action enter(Parser p)
    {
        if(tryenter(p) != Accept)
            return p.parseError("attribute specifier expected");
        return Accept;
    }

    static Action tryenter(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_align:
                p.pushState(&shiftAttribute);
                return AlignAttribute.enter(p);
            case TOK_extern:
                p.pushState(&shiftAttribute);
                return LinkageAttribute.enter(p);
            case TOK_Identifier:
                if(p.tok.txt[0] != '@')
                    return Forward;
                return UserAttributeSpecifier.enter(p);
            case TOK_deprecated:
                return UserAttributeSpecifier.enter(p);

            default:
                if(tokenToAnnotation(p.tok.id) == 0 &&
                   tokenToProtection(p.tok.id) == 0 &&
                   tokenToAttribute(p.tok.id) == 0)
                    return Forward;

                p.pushToken(p.tok);
                p.pushState(&shiftColonOrLcurly);
                return Accept;
        }
    }

    // assumes attribute on the token stack
    static Action enterAfterStatic(Parser p)
    {
        return shiftColonOrLcurly(p);
    }

    static ast.AttributeSpecifier createFromToken(Token tok)
    {
        TokenId id = tok.id;
        ast.AttributeSpecifier n;
        Annotation annot = tokenToAnnotation(id);
        if(annot == 0)
            annot = tokenToProtection(id);
        if(annot != 0)
        {
            n = new ast.AttributeSpecifier(tok);
            n.annotation = annot;
        }
        else
        {
            Attribute attr = tokenToAttribute(id);
            if(attr != 0)
            {
                n = new ast.AttributeSpecifier(tok);
                n.attr = attr;
            }
        }
        assert(n);
        return n;
    }

    static Action shiftColonOrLcurly(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_lparen:
                if(isTypeModifier(p.topToken().id))
                    // running into a type instead of an attribute, so switch to Declaration
                    return Decl!true.enterAttributeSpecifier(p);
                goto default;
            default:
                Token tok = p.popToken();
                auto attr = createFromToken(tok);
                p.pushNode(attr);
                return shiftAttribute(p);
        }
    }

    static Action shiftAttribute(Parser p)
    {
        auto attr = p.topNode!(ast.AttributeSpecifier);
        switch(p.tok.id)
        {
            case TOK_colon:
                attr.id = TOK_colon;
                return Accept;

            case TOK_lcurly:
                attr.id = TOK_lcurly;
                p.pushState(&shiftRcurly);
                p.pushState(&DeclDefs.enter);
                p.pushNode(new ast.DeclarationBlock(p.tok));
                return Accept;

            case TOK_Identifier:
                // identifier can be basic type or identifier of an AutoDeclaration
                p.pushToken(p.tok);
                p.pushState(&shiftIdentifier);
                return Accept;

            case TOK_alias:
            case TOK_typedef:
                p.pushState(&shiftDeclDef);
                return Declaration.enter(p);

            case TOK_align:
                p.pushState(&shiftDeclDef);
                p.pushState(&shiftAttribute);
                return AlignAttribute.enter(p);
            case TOK_extern:
                p.pushState(&shiftDeclDef);
                p.pushState(&shiftAttribute);
                return LinkageAttribute.enter(p);

            case TOK_pragma:
            case TOK_mixin:
            case TOK_import:
            case TOK_enum:
            case TOK_struct:
            case TOK_union:
            case TOK_class:
            case TOK_interface:
            case TOK_this:
            case TOK_tilde:
            case TOK_invariant:
            case TOK_unittest:
            case TOK_debug:
            case TOK_version:
            case TOK_template:
            case TOK_semicolon:
            case TOK_static:
                p.pushState(&shiftDeclDef);
                return DeclDef.enter(p);
            default:
                if(isTypeModifier(p.tok.id))
                {
                    p.pushState(&shiftDeclDef);
                    p.pushToken(p.tok);
                    p.pushState(&shiftColonOrLcurly);
                    return Accept;
                }
                int annot = tokenToAnnotation(p.tok.id) | tokenToProtection(p.tok.id);
                int attrib = tokenToAttribute(p.tok.id);
                if(annot || attrib)
                {
                    p.combineAnnotations(attr.annotation, annot);
                    p.combineAttributes(attr.attr, attrib);
                    p.pushState(&shiftAttribute);
                    return Accept;
                }
                p.pushState(&shiftDeclDef);
                return Decl!true.enter(p);
        }
    }

    static Action shiftRcurly(Parser p)
    {
        if(p.tok.id != TOK_rcurly)
            return p.parseError("closing brace expected for declaration block");

        p.popAppendTopNode!(ast.AttributeSpecifier)();
        return Accept;
    }

    static Action shiftDeclDef(Parser p)
    {
        p.popAppendTopNode!(ast.AttributeSpecifier)();
        return Forward;
    }

    static Action shiftIdentifier(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_assign:
                p.pushState(&shiftDeclDef);
                return Decl!true.enterIdentifier(p);
            case TOK_lparen:
                p.pushState(&shiftDeclDef);
                return Decl!true.enterAutoReturn(p);
            default:
                p.pushState(&shiftDeclDef);
                return Decl!true.enterTypeIdentifier(p);
        }
    }
}

//-- GRAMMAR_BEGIN --
//UserAttributeSpecifier:
//    deprectated
//    @identifier
//    deprecated ( ArgumentList )
//    @identifier ( ArgumentList )
class UserAttributeSpecifier
{
    static Action enter(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_deprecated:
            case TOK_Identifier:
                auto attr = new ast.UserAttributeSpecifier(p.tok);
                attr.ident = p.tok.txt;
                p.pushNode(attr);
                p.pushState(&shiftIdentifier);
                return Accept;
            default:
                return p.parseError("@identifier expected in user attribute");
        }
    }

    static Action shiftIdentifier(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_lparen:
                p.pushState(&shiftArgumentList);
                return Arguments.enter(p);
            default:
                return Forward;
        }
    }

    static Action shiftArgumentList(Parser p)
    {
        p.popAppendTopNode!(ast.UserAttributeSpecifier, ast.ArgumentList)();
        return Forward;
    }
}

//-- GRAMMAR_BEGIN --
//DeclarationBlock:
//    DeclDef
//    { DeclDefs_opt }
class DeclarationBlock
{
    static Action enter(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_lcurly:
                auto decl = new ast.DeclarationBlock(p.tok);
                p.pushNode(decl);
                p.pushState(&shiftLcurly);
                return Accept;
            default:
                return DeclDef.enter(p);
        }
    }
    static Action shiftLcurly(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_rcurly:
                return Accept;
            default:
                p.pushState(&shiftDeclDefs);
                return DeclDefs.enter(p);
        }
    }

    static Action shiftDeclDefs(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_rcurly:
                return Accept;
            default:
                return p.parseError("'}' expected");
        }
    }
}


//-- GRAMMAR_BEGIN --
//LinkageAttribute:
//    extern ( LinkageType )
//
//LinkageType:
//    "C"
//    "C" ++
//    "D"
//    "Windows"
//    "System"
class LinkageAttribute
{
    static Action enter(Parser p)
    {
        if(p.tok.id != TOK_extern)
            return p.parseError("extern expected");
        p.pushState(&shiftLparen);
        return Accept;
    }

    static Action shiftLparen(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_lparen:
                p.pushNode(new ast.LinkageAttribute(p.tok));
                p.pushState(&shiftLinkageType);
                return Accept;
            default:
                auto attr = new ast.AttributeSpecifier(p.tok);
                attr.attr = Attr_Extern;
                p.pushNode(attr);
                return Forward;
        }
    }

    static Action shiftLinkageType(Parser p)
    {
        Attribute attr = tokenToLinkageType(p.tok);
        if(attr == 0)
            return p.parseError("linkage type expected in extern");
        p.topNode!(ast.LinkageAttribute)().attr = attr;

        p.pushState(&shiftRParen);
        return Accept;
    }

    static Action shiftRParen(Parser p)
    {
        assert(cast(ast.LinkageAttribute)p.topNode());
        if(p.tok.id == TOK_rparen)
            return Accept;

        if(p.topNode().attr != Attr_ExternC || p.tok.id != TOK_plusplus)
            return p.parseError("closing parenthesis expected after linkage type");

        p.topNode().attr = Attr_ExternCPP;
        p.pushState(&shiftRParen);
        return Accept;
    }
}

Attribute tokenToLinkageType(Token tok)
{
    if(tok.id != TOK_Identifier)
        return 0;

    switch(tok.txt)
    {
        case "C":       return Attr_ExternC;
        case "D":       return Attr_ExternD;
        case "Windows": return Attr_ExternWindows;
        case "System":  return Attr_ExternSystem;
        default:        return 0;
    }
}

//-- GRAMMAR_BEGIN --
//AlignAttribute:
//    align
//    align ( Integer )
class AlignAttribute
{
    static Action enter(Parser p)
    {
        if(p.tok.id != TOK_align)
            return p.parseError("align expected");

        p.pushNode(new ast.AlignAttribute(p.tok));
        p.pushState(&shiftLparen);
        return Accept;
    }

    static Action shiftLparen(Parser p)
    {
        if(p.tok.id != TOK_lparen)
            return Forward;

        p.pushState(&shiftInteger);
        return Accept;
    }

    static Action shiftInteger(Parser p)
    {
        if(p.tok.id != TOK_IntegerLiteral)
            return p.parseError("integer expected in align");
        int algn = parse!int(p.tok.txt);
        Attribute attr = alignmentToAttribute(algn);
        if(attr == 0)
            return p.parseError("alignment not supported: " ~ p.tok.txt);

        p.topNode!(ast.AlignAttribute)().attr = attr;
        p.pushState(&shiftRParen);
        return Accept;
    }

    static Action shiftRParen(Parser p)
    {
        assert(cast(ast.AlignAttribute)p.topNode());
        if(p.tok.id != TOK_rparen)
            return p.parseError("closing parenthesis expected after align");
        return Accept;
    }
}

Attribute alignmentToAttribute(int algn)
{
    switch(algn)
    {
        case 1:  return Attr_Align1;
        case 2:  return Attr_Align2;
        case 4:  return Attr_Align4;
        case 8:  return Attr_Align8;
        case 16: return Attr_Align16;
        default: return 0;
    }
}

//-- GRAMMAR_BEGIN --
//ProtectionAttribute:
//    private
//    package
//    protected
//    public
//    export

//PragmaSpecifier:
//    Pragma DeclDef
//Pragma:
//    pragma ( Identifier )
//    pragma ( Identifier , TemplateArgumentList )
class Pragma
{
    static Action enter(Parser p)
    {
        if(p.tok.id != TOK_pragma)
            return p.parseError("pragma expected");

        p.pushNode(new ast.Pragma(p.tok));
        p.pushState(&shiftLparen);
        return Accept;
    }

    static Action shiftLparen(Parser p)
    {
        if(p.tok.id != TOK_lparen)
            return Forward;

        p.pushState(&shiftIdentifier);
        return Accept;
    }

    static Action shiftIdentifier(Parser p)
    {
        if(p.tok.id != TOK_Identifier)
            return p.parseError("integer expected in align");

        p.topNode!(ast.Pragma)().ident = p.tok.txt;

        p.pushState(&shiftCommaOrRParen);
        return Accept;
    }

    static Action shiftCommaOrRParen(Parser p)
    {
        if(p.tok.id == TOK_comma)
        {
            p.pushState(&shiftArgumentList);
            p.pushState(&TemplateArgumentList.enter);
            return Accept;
        }
        return shiftRParen(p);
    }

    static Action shiftRParen(Parser p)
    {
        assert(cast(ast.Pragma)p.topNode());
        if(p.tok.id != TOK_rparen)
            return p.parseError("closing parenthesis expected for pragma");
        return Accept;
    }

    static Action shiftArgumentList(Parser p)
    {
        p.popAppendTopNode!(ast.Pragma)();
        return shiftRParen(p);
    }
}


//-- GRAMMAR_BEGIN --
//ImportDeclaration:
//    import ImportList ;
class ImportDeclaration
{
    mixin SequenceNode!(ast.ImportDeclaration, TOK_import, ImportList, TOK_semicolon);
}

//-- GRAMMAR_BEGIN --
//ImportList:
//    Import
//    ImportBindings
//    Import , ImportList
//
//ImportBindings:
//    Import : ImportBindList

class ImportList
{
    static Action enter(Parser p)
    {
        p.pushNode(new ast.ImportList(p.tok));
        p.pushState(&shiftImport);
        return Import.enter(p);
    }

    static Action shiftImport(Parser p)
    {
        if(p.tok.id == TOK_colon)
        {
            p.pushState(&shiftImportBindList);
            p.pushState(&ImportBindList.enter);
            return Accept;
        }
        p.popAppendTopNode!(ast.ImportList)();

        if(p.tok.id == TOK_comma)
        {
            p.pushState(&shiftImport);
            p.pushState(&Import.enter);
            return Accept;
        }
        return Forward;
    }

    static Action shiftImportBindList(Parser p)
    {
        p.popAppendTopNode!(ast.Import)();
        p.popAppendTopNode!(ast.ImportList)();
        return Forward;
    }
}

//-- GRAMMAR_BEGIN --
//Import:
//    ModuleFullyQualifiedName
//    ModuleAliasIdentifier = ModuleFullyQualifiedName
//
//ModuleAliasIdentifier:
//    Identifier
class Import
{
    static Action enter(Parser p)
    {
        if(p.tok.id != TOK_Identifier)
            return p.parseError("identifier expected in import");

        p.pushToken(p.tok);
        p.pushNode(new ast.Import(p.tok));
        p.pushState(&shiftIdentifier);
        return Accept;
    }

    static Action shiftIdentifier(Parser p)
    {
        p.pushState(&shiftFullyQualifiedName);

        if(p.tok.id == TOK_assign)
        {
            p.topNode!(ast.Import)().aliasIdent = p.popToken().txt;
            p.pushState(&ModuleFullyQualifiedName.enter);
            return Accept;
        }

        // delegate into ModuleFullyQualifiedName
        p.pushNode(new ast.ModuleFullyQualifiedName(p.tok));
        auto id = new ast.Identifier(p.popToken());
        p.pushNode(id);
        return ModuleFullyQualifiedName.shift(p);
    }

    static Action shiftFullyQualifiedName(Parser p)
    {
        p.popAppendTopNode!(ast.Import)();
        return Forward;
    }
}

//-- GRAMMAR_BEGIN --
//ImportBindList:
//    ImportBind
//    ImportBind , ImportBindList
class ImportBindList
{
    mixin ListNode!(ast.ImportBindList, ImportBind, TOK_comma);
}


//-- GRAMMAR_BEGIN --
//ImportBind:
//    Identifier
//    Identifier = Identifier
class ImportBind
{
    mixin OptionalNode!(ast.ImportBind, Identifier, TOK_assign, Identifier);
}

//-- GRAMMAR_BEGIN --
//MixinDeclaration:
//    mixin ( AssignExpression ) ;
class MixinDeclaration
{
    mixin SequenceNode!(ast.MixinDeclaration, TOK_mixin, TOK_lparen, AssignExpression, TOK_rparen, TOK_semicolon);

    static Action enterAfterMixin(Parser p)
    {
        p.pushNode(new ast.MixinDeclaration(p.tok));
        return shift1.shift(p);
    }
}

//-- GRAMMAR_BEGIN --
//Unittest:
//    unittest BlockStatement
class Unittest
{
    mixin SequenceNode!(ast.Unittest, TOK_unittest, BlockStatement);
}

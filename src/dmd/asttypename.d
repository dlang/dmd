/**
 * Development utility for printing AST nodes by their internal name, instead of as D source code.
 *
 * Copyright:   Copyright (C) 1999-2020 by The D Language Foundation, All Rights Reserved
 * Authors:     Stefan Koch
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/asttypename.d, _asttypename.d)
 * Documentation:  https://dlang.org/phobos/dmd_asttypename.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/asttypename.d
 */

module dmd.asttypename;

import dmd.ast_node : ASTNode;
import dmd.attrib : AttribDeclaration, CompileDeclaration, UserAttributeDeclaration, LinkDeclaration, AnonDeclaration, AlignDeclaration, CPPMangleDeclaration, CPPNamespaceDeclaration, ProtDeclaration, PragmaDeclaration, StorageClassDeclaration, ConditionalDeclaration, StaticForeachDeclaration, DeprecatedDeclaration, StaticIfDeclaration, ForwardingAttribDeclaration;
import dmd.aliasthis : AliasThis;
import dmd.aggregate : AggregateDeclaration;
// import dmd.complex : ;
import dmd.cond : Condition, StaticIfCondition, DVCondition, DebugCondition, VersionCondition;
import dmd.ctfeexpr : ClassReferenceExp, ThrownExceptionExp;
import dmd.dclass : ClassDeclaration, InterfaceDeclaration;
// import dmd.declaration : ;
// import dmd.denum : ;
// import dmd.dimport : ;
import dmd.declaration : Declaration, VarDeclaration, AliasDeclaration, TupleDeclaration, OverDeclaration, SymbolDeclaration, ThisDeclaration, TypeInfoDeclaration, TypeInfoStructDeclaration, TypeInfoClassDeclaration, TypeInfoInterfaceDeclaration, TypeInfoPointerDeclaration, TypeInfoArrayDeclaration, TypeInfoStaticArrayDeclaration, TypeInfoAssociativeArrayDeclaration, TypeInfoEnumDeclaration, TypeInfoFunctionDeclaration, TypeInfoDelegateDeclaration, TypeInfoTupleDeclaration, TypeInfoConstDeclaration, TypeInfoInvariantDeclaration, TypeInfoSharedDeclaration, TypeInfoWildDeclaration, TypeInfoVectorDeclaration;
import dmd.dstruct : StructDeclaration, UnionDeclaration;
import dmd.dsymbol : Dsymbol, ScopeDsymbol, OverloadSet, WithScopeSymbol, ArrayScopeSymbol;
import dmd.dtemplate : TemplateParameter, TemplateDeclaration, TemplateInstance, TemplateMixin, TemplateAliasParameter, TemplateTypeParameter, TemplateTupleParameter, TemplateValueParameter, TemplateThisParameter, Tuple;
import dmd.dversion : DebugSymbol, VersionSymbol;
import dmd.expression : Expression, DeclarationExp, IntegerExp, NewAnonClassExp, IsExp, RealExp, NullExp, TypeidExp, TraitsExp, StringExp, NewExp, AssocArrayLiteralExp, ArrayLiteralExp, CompileExp, FuncExp, IntervalExp, TypeExp, ScopeExp, IdentifierExp, UnaExp, DefaultInitExp, BinExp, DsymbolExp, TemplateExp, SymbolExp, TupleExp, ThisExp, VarExp, DollarExp, SuperExp, AddrExp, PreExp, PtrExp, NegExp, UAddExp, NotExp, ComExp, DeleteExp, CastExp, CallExp, DotIdExp, AssertExp, ImportExp, DotTemplateInstanceExp, ArrayExp, FuncInitExp, PrettyFuncInitExp, FileInitExp, LineInitExp, ModuleInitExp, CommaExp, PostExp, PowExp, MulExp, DivExp, ModExp, AddExp, MinExp, CatExp, ShlExp, ShrExp, UshrExp, EqualExp, InExp, IdentityExp, CmpExp, AndExp, XorExp, OrExp, LogicalExp, CondExp, AssignExp, BinAssignExp, AddAssignExp, MinAssignExp, MulAssignExp, DivAssignExp, ModAssignExp, PowAssignExp, AndAssignExp, OrAssignExp, XorAssignExp, ShlAssignExp, ShrAssignExp, UshrAssignExp, CatAssignExp, ErrorExp, ComplexExp, StructLiteralExp, ObjcClassReferenceExp, SymOffExp, OverExp, HaltExp, DotTemplateExp, DotVarExp, DelegateExp, DotTypeExp, VectorExp, VectorArrayExp, SliceExp, ArrayLengthExp, DelegatePtrExp, DelegateFuncptrExp, DotExp, IndexExp, ConstructExp, BlitExp, RemoveExp, VoidInitExp;
import dmd.func : FuncDeclaration, FuncLiteralDeclaration, PostBlitDeclaration, CtorDeclaration, DtorDeclaration, InvariantDeclaration, UnitTestDeclaration, NewDeclaration, StaticCtorDeclaration, StaticDtorDeclaration, SharedStaticCtorDeclaration, SharedStaticDtorDeclaration, FuncAliasDeclaration;
import dmd.denum : EnumDeclaration, EnumMember;
import dmd.dimport : Import;
import dmd.dmodule : Package, Module;
import dmd.mtype : Parameter, Type, TypeBasic, TypeError, TypeNull, TypeVector, TypeEnum, TypeTuple, TypeClass, TypeStruct, TypeNext, TypeQualified, TypeTraits, TypeMixin, TypeReference, TypeSlice, TypeDelegate, TypePointer, TypeFunction, TypeArray, TypeDArray, TypeAArray, TypeSArray, TypeIdentifier, TypeReturn, TypeTypeof, TypeInstance;
// import dmd.typinf : ;
// import dmd.identifier : ;
import dmd.init : Initializer, ExpInitializer, StructInitializer, ArrayInitializer, VoidInitializer, ErrorInitializer;
// import dmd.doc : ;
import dmd.root.rootobject : RootObject, DYNCAST;
import dmd.statement : Statement, ImportStatement, ScopeStatement, ReturnStatement, LabelStatement, StaticAssertStatement, CompileStatement, WhileStatement, ForStatement, DoStatement, ForeachRangeStatement, ForeachStatement, IfStatement, ScopeGuardStatement, ConditionalStatement, StaticForeachStatement, PragmaStatement, SwitchStatement, CaseRangeStatement, CaseStatement, DefaultStatement, BreakStatement, ContinueStatement, GotoDefaultStatement, GotoCaseStatement, GotoStatement, SynchronizedStatement, WithStatement, TryCatchStatement, TryFinallyStatement, ThrowStatement, AsmStatement, ExpStatement, CompoundStatement, CompoundDeclarationStatement, CompoundAsmStatement, InlineAsmStatement, GccAsmStatement, ErrorStatement, PeelStatement, UnrolledLoopStatement, SwitchErrorStatement, DebugStatement, DtorExpStatement, ForwardingStatement, LabelDsymbol;
import dmd.staticassert : StaticAssert;
import dmd.nspace : Nspace;
import dmd.visitor : Visitor;

/// Returns: the typename of the dynamic ast-node-type
/// (this is a development tool, do not use in actual code)
string astTypeName(RootObject node)
{
    final switch (node.dyncast())
    {
        case DYNCAST.object:
            return "RootObject";
        case DYNCAST.identifier:
            return "Identifier";
        case DYNCAST.tuple:
            return "Tuple";

        case DYNCAST.expression:
            return astTypeName(cast(Expression) node);
        case DYNCAST.dsymbol:
            return astTypeName(cast(Dsymbol) node);
        case DYNCAST.type:
            return astTypeName(cast(Type) node);
        case DYNCAST.parameter:
            return astTypeName(cast(Parameter) node);
        case DYNCAST.statement:
            return astTypeName(cast(Statement) node);
        case DYNCAST.condition:
            return astTypeName(cast(Condition) node);
        case DYNCAST.templateparameter:
            return astTypeName(cast(TemplateParameter) node);
    }
}

extern(D) enum mixin_string =
({
    string astTypeNameFunctions;
    string visitOverloads;

    foreach (ov; __traits(getOverloads, Visitor, "visit"))
    {
        static if (is(typeof(ov) P == function))
        {
            static if (is(P[0] S == super) && is(S[0] == ASTNode))
            {
                astTypeNameFunctions ~= `
string astTypeName(` ~ P[0].stringof ~ ` node)
{
    scope tsv = new AstTypeNameVisitor;
    node.accept(tsv);
    return tsv.typeName;
}
`;
            }

            visitOverloads ~= `
    override void visit (` ~ P[0].stringof ~ ` _)
    {
        typeName = "` ~ P[0].stringof ~ `";
    }
`;
        }
    }

    return astTypeNameFunctions ~ `
private extern(C++) final class AstTypeNameVisitor : Visitor
{
    alias visit = Visitor.visit;
public :
    string typeName;
` ~ visitOverloads ~ "}";
}());

// pragma(msg, mixin_string);
mixin(mixin_string);
///
unittest
{
    import dmd.globals : Loc;
    Expression e = new TypeidExp(Loc.initial, null);
    Tuple t = new Tuple();
    TemplateTypeParameter tp = new TemplateTypeParameter(Loc.initial, null, null, null);
    assert(e.astTypeName == "TypeidExp");
    assert(t.astTypeName == "Tuple");
    assert(tp.astTypeName == "TemplateTypeParameter");
}

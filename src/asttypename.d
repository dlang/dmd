module ddmd.asttypename;

import ddmd.attrib;
import ddmd.aliasthis;
import ddmd.aggregate;
import ddmd.complex;
import ddmd.cond;
import ddmd.ctfeexpr;
import ddmd.dclass;
import ddmd.declaration;
import ddmd.denum;
import ddmd.dimport;
import ddmd.declaration;
import ddmd.dstruct;
import ddmd.dsymbol;
import ddmd.dtemplate;
import ddmd.dversion;
import ddmd.expression;
import ddmd.func;
import ddmd.denum;
import ddmd.dimport;
import ddmd.dmodule;
import ddmd.mtype;
import ddmd.typinf;
import ddmd.identifier;
import ddmd.init;
import ddmd.globals;
import ddmd.doc;
import ddmd.root.rootobject;
import ddmd.statement;
import ddmd.staticassert;
import ddmd.nspace;
import ddmd.visitor;

string astTypeName(RootObject node)
{
    switch(node.dyncast())
    {
        case DYNCAST_OBJECT:
            return "RootObject";
        case DYNCAST_EXPRESSION:
            return astTypeName(cast(Expression)node);
        case DYNCAST_DSYMBOL:
            return astTypeName(cast(Dsymbol)node);
        case DYNCAST_TYPE:
            return astTypeName(cast(Type)node);
        case DYNCAST_IDENTIFIER:
            return astTypeName(cast(Identifier)node);
        case DYNCAST_TUPLE:
            return astTypeName(cast(Tuple)node);
        case DYNCAST_PARAMETER:
            return astTypeName(cast(Parameter)node);
        case DYNCAST_STATEMENT:
            return astTypeName(cast(Statement)node);
        default : assert(0, "don't know this DYNCAST");
    }
}

string astTypeName(Dsymbol node)
{
    scope tsv = new AstTypeNameVisitor;
    node.accept(tsv);
    return tsv.typeName;
}

string astTypeName(Expression node)
{
    scope tsv = new AstTypeNameVisitor;
    node.accept(tsv);
    return tsv.typeName;
}

string astTypeName(Statement node)
{
    scope tsv = new AstTypeNameVisitor;
    node.accept(tsv);
    return tsv.typeName;
}

string astTypeName(Type node)
{
    scope tsv = new AstTypeNameVisitor;
    node.accept(tsv);
    return tsv.typeName;
}

string astTypeName(Identifier node)
{
    return "Identifier";
}

string astTypeName(Initializer node)
{
    scope tsv = new AstTypeNameVisitor;
    node.accept(tsv);
    return tsv.typeName;
}

string astTypeName(Condition node)
{
    scope tsv = new AstTypeNameVisitor;
    node.accept(tsv);
    return tsv.typeName;
}

string astTypeName(TemplateParameter node)
{
    scope tsv = new AstTypeNameVisitor;
    node.accept(tsv);
    return tsv.typeName;
}

extern(C++) final class AstTypeNameVisitor : Visitor
{
    alias visit = super.visit;
public :
    string typeName;


    void visit(RootObject node)
    {
        typeName = "RootObject";
    }

    override void visit(Condition node)
    {
        typeName = "Condition";
    }

    void visit(Identifier node)
    {
        typeName = "Identifier";
    }

    override void visit(Statement node)
    {
        typeName = "Statement";
    }

    void visit(Catch node)
    {
        typeName = "Catch";
    }

    override void visit(Dsymbol node)
    {
        typeName = "Dsymbol";
    }

    void visit(DsymbolTable node)
    {
        typeName = "DsymbolTable";
    }

    void visit(Tuple node)
    {
        typeName = "Tuple";
    }

    override void visit(Initializer node)
    {
        typeName = "Initializer";
    }

    override void visit(Type node)
    {
        typeName = "Type";
    }

    override void visit(Parameter node)
    {
        typeName = "Parameter";
    }

    override void visit(Expression node)
    {
        typeName = "Expression";
    }

    override void visit(AliasThis node)
    {
        typeName = "AliasThis";
    }

    override void visit(DVCondition node)
    {
        typeName = "DVCondition";
    }

    override void visit(StaticIfCondition node)
    {
        typeName = "StaticIfCondition";
    }

    override void visit(ClassReferenceExp node)
    {
        typeName = "ClassReferenceExp";
    }

    override void visit(VoidInitExp node)
    {
        typeName = "VoidInitExp";
    }

    override void visit(ThrownExceptionExp node)
    {
        typeName = "ThrownExceptionExp";
    }

    void visit(CTFEExp node)
    {
        typeName = "CTFEExp";
    }

    override void visit(Import node)
    {
        typeName = "Import";
    }

    override void visit(DebugSymbol node)
    {
        typeName = "DebugSymbol";
    }

    override void visit(VersionSymbol node)
    {
        typeName = "VersionSymbol";
    }

    override void visit(StaticAssert node)
    {
        typeName = "StaticAssert";
    }

    override void visit(ErrorStatement node)
    {
        typeName = "ErrorStatement";
    }

    override void visit(PeelStatement node)
    {
        typeName = "PeelStatement";
    }

    override void visit(ExpStatement node)
    {
        typeName = "ExpStatement";
    }

    override void visit(CompileStatement node)
    {
        typeName = "CompileStatement";
    }

    override void visit(CompoundStatement node)
    {
        typeName = "CompoundStatement";
    }

    override void visit(UnrolledLoopStatement node)
    {
        typeName = "UnrolledLoopStatement";
    }

    override void visit(ScopeStatement node)
    {
        typeName = "ScopeStatement";
    }

    override void visit(WhileStatement node)
    {
        typeName = "WhileStatement";
    }

    override void visit(DoStatement node)
    {
        typeName = "DoStatement";
    }

    override void visit(ForStatement node)
    {
        typeName = "ForStatement";
    }

    override void visit(ForeachStatement node)
    {
        typeName = "ForeachStatement";
    }

    override void visit(ForeachRangeStatement node)
    {
        typeName = "ForeachRangeStatement";
    }

    override void visit(IfStatement node)
    {
        typeName = "IfStatement";
    }

    override void visit(ConditionalStatement node)
    {
        typeName = "ConditionalStatement";
    }

    override void visit(PragmaStatement node)
    {
        typeName = "PragmaStatement";
    }

    override void visit(StaticAssertStatement node)
    {
        typeName = "StaticAssertStatement";
    }

    override void visit(SwitchStatement node)
    {
        typeName = "SwitchStatement";
    }

    override void visit(CaseStatement node)
    {
        typeName = "CaseStatement";
    }

    override void visit(CaseRangeStatement node)
    {
        typeName = "CaseRangeStatement";
    }

    override void visit(DefaultStatement node)
    {
        typeName = "DefaultStatement";
    }

    override void visit(GotoDefaultStatement node)
    {
        typeName = "GotoDefaultStatement";
    }

    override void visit(GotoCaseStatement node)
    {
        typeName = "GotoCaseStatement";
    }

    override void visit(SwitchErrorStatement node)
    {
        typeName = "SwitchErrorStatement";
    }

    override void visit(ReturnStatement node)
    {
        typeName = "ReturnStatement";
    }

    override void visit(BreakStatement node)
    {
        typeName = "BreakStatement";
    }

    override void visit(ContinueStatement node)
    {
        typeName = "ContinueStatement";
    }

    override void visit(SynchronizedStatement node)
    {
        typeName = "SynchronizedStatement";
    }

    override void visit(WithStatement node)
    {
        typeName = "WithStatement";
    }

    override void visit(TryCatchStatement node)
    {
        typeName = "TryCatchStatement";
    }

    override void visit(TryFinallyStatement node)
    {
        typeName = "TryFinallyStatement";
    }

    override void visit(OnScopeStatement node)
    {
        typeName = "OnScopeStatement";
    }

    override void visit(ThrowStatement node)
    {
        typeName = "ThrowStatement";
    }

    override void visit(DebugStatement node)
    {
        typeName = "DebugStatement";
    }

    override void visit(GotoStatement node)
    {
        typeName = "GotoStatement";
    }

    override void visit(LabelStatement node)
    {
        typeName = "LabelStatement";
    }

    override void visit(LabelDsymbol node)
    {
        typeName = "LabelDsymbol";
    }

    override void visit(AsmStatement node)
    {
        typeName = "AsmStatement";
    }

    override void visit(ImportStatement node)
    {
        typeName = "ImportStatement";
    }

    override void visit(AttribDeclaration node)
    {
        typeName = "AttribDeclaration";
    }

    override void visit(Declaration node)
    {
        typeName = "Declaration";
    }

    override void visit(ScopeDsymbol node)
    {
        typeName = "ScopeDsymbol";
    }

    override void visit(OverloadSet node)
    {
        typeName = "OverloadSet";
    }

    void visit(TypeDeduced node)
    {
        typeName = "TypeDeduced";
    }

    override void visit(VoidInitializer node)
    {
        typeName = "VoidInitializer";
    }

    override void visit(ErrorInitializer node)
    {
        typeName = "ErrorInitializer";
    }

    override void visit(StructInitializer node)
    {
        typeName = "StructInitializer";
    }

    override void visit(ArrayInitializer node)
    {
        typeName = "ArrayInitializer";
    }

    override void visit(ExpInitializer node)
    {
        typeName = "ExpInitializer";
    }

    override void visit(TypeError node)
    {
        typeName = "TypeError";
    }

    override void visit(TypeNext node)
    {
        typeName = "TypeNext";
    }

    override void visit(TypeBasic node)
    {
        typeName = "TypeBasic";
    }

    override void visit(TypeVector node)
    {
        typeName = "TypeVector";
    }

    override void visit(TypeQualified node)
    {
        typeName = "TypeQualified";
    }

    override void visit(TypeStruct node)
    {
        typeName = "TypeStruct";
    }

    override void visit(TypeEnum node)
    {
        typeName = "TypeEnum";
    }

    override void visit(TypeClass node)
    {
        typeName = "TypeClass";
    }

    override void visit(TypeTuple node)
    {
        typeName = "TypeTuple";
    }

    override void visit(TypeNull node)
    {
        typeName = "TypeNull";
    }

    override void visit(IntegerExp node)
    {
        typeName = "IntegerExp";
    }

    override void visit(ErrorExp node)
    {
        typeName = "ErrorExp";
    }

    override void visit(RealExp node)
    {
        typeName = "RealExp";
    }

    override void visit(ComplexExp node)
    {
        typeName = "ComplexExp";
    }

    override void visit(IdentifierExp node)
    {
        typeName = "IdentifierExp";
    }

    override void visit(DsymbolExp node)
    {
        typeName = "DsymbolExp";
    }

    override void visit(ThisExp node)
    {
        typeName = "ThisExp";
    }

    override void visit(NullExp node)
    {
        typeName = "NullExp";
    }

    override void visit(StringExp node)
    {
        typeName = "StringExp";
    }

    override void visit(TupleExp node)
    {
        typeName = "TupleExp";
    }

    override void visit(ArrayLiteralExp node)
    {
        typeName = "ArrayLiteralExp";
    }

    override void visit(AssocArrayLiteralExp node)
    {
        typeName = "AssocArrayLiteralExp";
    }

    override void visit(StructLiteralExp node)
    {
        typeName = "StructLiteralExp";
    }

    override void visit(TypeExp node)
    {
        typeName = "TypeExp";
    }

    override void visit(ScopeExp node)
    {
        typeName = "ScopeExp";
    }

    override void visit(TemplateExp node)
    {
        typeName = "TemplateExp";
    }

    override void visit(NewExp node)
    {
        typeName = "NewExp";
    }

    override void visit(NewAnonClassExp node)
    {
        typeName = "NewAnonClassExp";
    }

    override void visit(SymbolExp node)
    {
        typeName = "SymbolExp";
    }

    override void visit(OverExp node)
    {
        typeName = "OverExp";
    }

    override void visit(FuncExp node)
    {
        typeName = "FuncExp";
    }

    override void visit(DeclarationExp node)
    {
        typeName = "DeclarationExp";
    }

    override void visit(TypeidExp node)
    {
        typeName = "TypeidExp";
    }

    override void visit(TraitsExp node)
    {
        typeName = "TraitsExp";
    }

    override void visit(HaltExp node)
    {
        typeName = "HaltExp";
    }

    override void visit(IsExp node)
    {
        typeName = "IsExp";
    }

    override void visit(UnaExp node)
    {
        typeName = "UnaExp";
    }

    override void visit(BinExp node)
    {
        typeName = "BinExp";
    }

    override void visit(IntervalExp node)
    {
        typeName = "IntervalExp";
    }

    override void visit(DefaultInitExp node)
    {
        typeName = "DefaultInitExp";
    }

    override void visit(DebugCondition node)
    {
        typeName = "DebugCondition";
    }

    override void visit(VersionCondition node)
    {
        typeName = "VersionCondition";
    }

    override void visit(EnumDeclaration node)
    {
        typeName = "EnumDeclaration";
    }

    override void visit(Package node)
    {
        typeName = "Package";
    }

    override void visit(Nspace node)
    {
        typeName = "Nspace";
    }

    override void visit(AggregateDeclaration node)
    {
        typeName = "AggregateDeclaration";
    }

    override void visit(DtorExpStatement node)
    {
        typeName = "DtorExpStatement";
    }

    override void visit(CompoundDeclarationStatement node)
    {
        typeName = "CompoundDeclarationStatement";
    }

    override void visit(CompoundAsmStatement node)
    {
        typeName = "CompoundAsmStatement";
    }

    override void visit(StorageClassDeclaration node)
    {
        typeName = "StorageClassDeclaration";
    }

    override void visit(LinkDeclaration node)
    {
        typeName = "LinkDeclaration";
    }

    override void visit(CPPMangleDeclaration node)
    {
        typeName = "CPPMangleDeclaration";
    }

    override void visit(ProtDeclaration node)
    {
        typeName = "ProtDeclaration";
    }

    override void visit(AlignDeclaration node)
    {
        typeName = "AlignDeclaration";
    }

    override void visit(AnonDeclaration node)
    {
        typeName = "AnonDeclaration";
    }

    override void visit(PragmaDeclaration node)
    {
        typeName = "PragmaDeclaration";
    }

    override void visit(ConditionalDeclaration node)
    {
        typeName = "ConditionalDeclaration";
    }

    override void visit(CompileDeclaration node)
    {
        typeName = "CompileDeclaration";
    }

    override void visit(UserAttributeDeclaration node)
    {
        typeName = "UserAttributeDeclaration";
    }

    override void visit(TupleDeclaration node)
    {
        typeName = "TupleDeclaration";
    }

    override void visit(AliasDeclaration node)
    {
        typeName = "AliasDeclaration";
    }

    override void visit(OverDeclaration node)
    {
        typeName = "OverDeclaration";
    }

    override void visit(VarDeclaration node)
    {
        typeName = "VarDeclaration";
    }

    override void visit(SymbolDeclaration node)
    {
        typeName = "SymbolDeclaration";
    }

    override void visit(WithScopeSymbol node)
    {
        typeName = "WithScopeSymbol";
    }

    override void visit(ArrayScopeSymbol node)
    {
        typeName = "ArrayScopeSymbol";
    }

    override void visit(TemplateDeclaration node)
    {
        typeName = "TemplateDeclaration";
    }

    override void visit(TemplateInstance node)
    {
        typeName = "TemplateInstance";
    }

    override void visit(FuncDeclaration node)
    {
        typeName = "FuncDeclaration";
    }

    override void visit(TypeArray node)
    {
        typeName = "TypeArray";
    }

    override void visit(TypePointer node)
    {
        typeName = "TypePointer";
    }

    override void visit(TypeReference node)
    {
        typeName = "TypeReference";
    }

    override void visit(TypeFunction node)
    {
        typeName = "TypeFunction";
    }

    override void visit(TypeDelegate node)
    {
        typeName = "TypeDelegate";
    }

    override void visit(TypeIdentifier node)
    {
        typeName = "TypeIdentifier";
    }

    override void visit(TypeInstance node)
    {
        typeName = "TypeInstance";
    }

    override void visit(TypeTypeof node)
    {
        typeName = "TypeTypeof";
    }

    override void visit(TypeReturn node)
    {
        typeName = "TypeReturn";
    }

    override void visit(TypeSlice node)
    {
        typeName = "TypeSlice";
    }

    override void visit(DollarExp node)
    {
        typeName = "DollarExp";
    }

    override void visit(SuperExp node)
    {
        typeName = "SuperExp";
    }

    override void visit(SymOffExp node)
    {
        typeName = "SymOffExp";
    }

    override void visit(VarExp node)
    {
        typeName = "VarExp";
    }

    override void visit(BinAssignExp node)
    {
        typeName = "BinAssignExp";
    }

    override void visit(CompileExp node)
    {
        typeName = "CompileExp";
    }

    override void visit(ImportExp node)
    {
        typeName = "ImportExp";
    }

    override void visit(AssertExp node)
    {
        typeName = "AssertExp";
    }

    override void visit(DotIdExp node)
    {
        typeName = "DotIdExp";
    }

    override void visit(DotTemplateExp node)
    {
        typeName = "DotTemplateExp";
    }

    override void visit(DotVarExp node)
    {
        typeName = "DotVarExp";
    }

    override void visit(DotTemplateInstanceExp node)
    {
        typeName = "DotTemplateInstanceExp";
    }

    override void visit(DelegateExp node)
    {
        typeName = "DelegateExp";
    }

    override void visit(DotTypeExp node)
    {
        typeName = "DotTypeExp";
    }

    override void visit(CallExp node)
    {
        typeName = "CallExp";
    }

    override void visit(AddrExp node)
    {
        typeName = "AddrExp";
    }

    override void visit(PtrExp node)
    {
        typeName = "PtrExp";
    }

    override void visit(NegExp node)
    {
        typeName = "NegExp";
    }

    override void visit(UAddExp node)
    {
        typeName = "UAddExp";
    }

    override void visit(ComExp node)
    {
        typeName = "ComExp";
    }

    override void visit(NotExp node)
    {
        typeName = "NotExp";
    }

    override void visit(DeleteExp node)
    {
        typeName = "DeleteExp";
    }

    override void visit(CastExp node)
    {
        typeName = "CastExp";
    }

    override void visit(VectorExp node)
    {
        typeName = "VectorExp";
    }

    override void visit(SliceExp node)
    {
        typeName = "SliceExp";
    }

    override void visit(ArrayLengthExp node)
    {
        typeName = "ArrayLengthExp";
    }

    override void visit(ArrayExp node)
    {
        typeName = "ArrayExp";
    }

    override void visit(DotExp node)
    {
        typeName = "DotExp";
    }

    override void visit(CommaExp node)
    {
        typeName = "CommaExp";
    }

    override void visit(DelegatePtrExp node)
    {
        typeName = "DelegatePtrExp";
    }

    override void visit(DelegateFuncptrExp node)
    {
        typeName = "DelegateFuncptrExp";
    }

    override void visit(IndexExp node)
    {
        typeName = "IndexExp";
    }

    override void visit(PostExp node)
    {
        typeName = "PostExp";
    }

    override void visit(PreExp node)
    {
        typeName = "PreExp";
    }

    override void visit(AssignExp node)
    {
        typeName = "AssignExp";
    }

    override void visit(AddExp node)
    {
        typeName = "AddExp";
    }

    override void visit(MinExp node)
    {
        typeName = "MinExp";
    }

    override void visit(CatExp node)
    {
        typeName = "CatExp";
    }

    override void visit(MulExp node)
    {
        typeName = "MulExp";
    }

    override void visit(DivExp node)
    {
        typeName = "DivExp";
    }

    override void visit(ModExp node)
    {
        typeName = "ModExp";
    }

    override void visit(PowExp node)
    {
        typeName = "PowExp";
    }

    override void visit(ShlExp node)
    {
        typeName = "ShlExp";
    }

    override void visit(ShrExp node)
    {
        typeName = "ShrExp";
    }

    override void visit(UshrExp node)
    {
        typeName = "UshrExp";
    }

    override void visit(AndExp node)
    {
        typeName = "AndExp";
    }

    override void visit(OrExp node)
    {
        typeName = "OrExp";
    }

    override void visit(XorExp node)
    {
        typeName = "XorExp";
    }

    override void visit(OrOrExp node)
    {
        typeName = "OrOrExp";
    }

    override void visit(AndAndExp node)
    {
        typeName = "AndAndExp";
    }

    override void visit(CmpExp node)
    {
        typeName = "CmpExp";
    }

    override void visit(InExp node)
    {
        typeName = "InExp";
    }

    override void visit(RemoveExp node)
    {
        typeName = "RemoveExp";
    }

    override void visit(EqualExp node)
    {
        typeName = "EqualExp";
    }

    override void visit(IdentityExp node)
    {
        typeName = "IdentityExp";
    }

    override void visit(CondExp node)
    {
        typeName = "CondExp";
    }

    override void visit(FileInitExp node)
    {
        typeName = "FileInitExp";
    }

    override void visit(LineInitExp node)
    {
        typeName = "LineInitExp";
    }

    override void visit(ModuleInitExp node)
    {
        typeName = "ModuleInitExp";
    }

    override void visit(FuncInitExp node)
    {
        typeName = "FuncInitExp";
    }

    override void visit(PrettyFuncInitExp node)
    {
        typeName = "PrettyFuncInitExp";
    }

    override void visit(ClassDeclaration node)
    {
        typeName = "ClassDeclaration";
    }

    override void visit(EnumMember node)
    {
        typeName = "EnumMember";
    }

    override void visit(Module node)
    {
        typeName = "Module";
    }

    override void visit(StructDeclaration node)
    {
        typeName = "StructDeclaration";
    }

    override void visit(DeprecatedDeclaration node)
    {
        typeName = "DeprecatedDeclaration";
    }

    override void visit(StaticIfDeclaration node)
    {
        typeName = "StaticIfDeclaration";
    }

    override void visit(TypeInfoDeclaration node)
    {
        typeName = "TypeInfoDeclaration";
    }

    override void visit(ThisDeclaration node)
    {
        typeName = "ThisDeclaration";
    }

    override void visit(TemplateMixin node)
    {
        typeName = "TemplateMixin";
    }

    override void visit(FuncAliasDeclaration node)
    {
        typeName = "FuncAliasDeclaration";
    }

    override void visit(FuncLiteralDeclaration node)
    {
        typeName = "FuncLiteralDeclaration";
    }

    override void visit(CtorDeclaration node)
    {
        typeName = "CtorDeclaration";
    }

    override void visit(PostBlitDeclaration node)
    {
        typeName = "PostBlitDeclaration";
    }

    override void visit(DtorDeclaration node)
    {
        typeName = "DtorDeclaration";
    }

    override void visit(StaticCtorDeclaration node)
    {
        typeName = "StaticCtorDeclaration";
    }

    override void visit(StaticDtorDeclaration node)
    {
        typeName = "StaticDtorDeclaration";
    }

    override void visit(InvariantDeclaration node)
    {
        typeName = "InvariantDeclaration";
    }

    override void visit(UnitTestDeclaration node)
    {
        typeName = "UnitTestDeclaration";
    }

    override void visit(NewDeclaration node)
    {
        typeName = "NewDeclaration";
    }

    override void visit(DeleteDeclaration node)
    {
        typeName = "DeleteDeclaration";
    }

    override void visit(TypeSArray node)
    {
        typeName = "TypeSArray";
    }

    override void visit(TypeDArray node)
    {
        typeName = "TypeDArray";
    }

    override void visit(TypeAArray node)
    {
        typeName = "TypeAArray";
    }

    override void visit(ConstructExp node)
    {
        typeName = "ConstructExp";
    }

    override void visit(BlitExp node)
    {
        typeName = "BlitExp";
    }

    override void visit(AddAssignExp node)
    {
        typeName = "AddAssignExp";
    }

    override void visit(MinAssignExp node)
    {
        typeName = "MinAssignExp";
    }

    override void visit(MulAssignExp node)
    {
        typeName = "MulAssignExp";
    }

    override void visit(DivAssignExp node)
    {
        typeName = "DivAssignExp";
    }

    override void visit(ModAssignExp node)
    {
        typeName = "ModAssignExp";
    }

    override void visit(AndAssignExp node)
    {
        typeName = "AndAssignExp";
    }

    override void visit(OrAssignExp node)
    {
        typeName = "OrAssignExp";
    }

    override void visit(XorAssignExp node)
    {
        typeName = "XorAssignExp";
    }

    override void visit(PowAssignExp node)
    {
        typeName = "PowAssignExp";
    }

    override void visit(ShlAssignExp node)
    {
        typeName = "ShlAssignExp";
    }

    override void visit(ShrAssignExp node)
    {
        typeName = "ShrAssignExp";
    }

    override void visit(UshrAssignExp node)
    {
        typeName = "UshrAssignExp";
    }

    override void visit(CatAssignExp node)
    {
        typeName = "CatAssignExp";
    }

    override void visit(InterfaceDeclaration node)
    {
        typeName = "InterfaceDeclaration";
    }

    override void visit(UnionDeclaration node)
    {
        typeName = "UnionDeclaration";
    }

    override void visit(TypeInfoStructDeclaration node)
    {
        typeName = "TypeInfoStructDeclaration";
    }

    override void visit(TypeInfoClassDeclaration node)
    {
        typeName = "TypeInfoClassDeclaration";
    }

    override void visit(TypeInfoInterfaceDeclaration node)
    {
        typeName = "TypeInfoInterfaceDeclaration";
    }

    override void visit(TypeInfoPointerDeclaration node)
    {
        typeName = "TypeInfoPointerDeclaration";
    }

    override void visit(TypeInfoArrayDeclaration node)
    {
        typeName = "TypeInfoArrayDeclaration";
    }

    override void visit(TypeInfoStaticArrayDeclaration node)
    {
        typeName = "TypeInfoStaticArrayDeclaration";
    }

    override void visit(TypeInfoAssociativeArrayDeclaration node)
    {
        typeName = "TypeInfoAssociativeArrayDeclaration";
    }

    override void visit(TypeInfoEnumDeclaration node)
    {
        typeName = "TypeInfoEnumDeclaration";
    }

    override void visit(TypeInfoFunctionDeclaration node)
    {
        typeName = "TypeInfoFunctionDeclaration";
    }

    override void visit(TypeInfoDelegateDeclaration node)
    {
        typeName = "TypeInfoDelegateDeclaration";
    }

    override void visit(TypeInfoTupleDeclaration node)
    {
        typeName = "TypeInfoTupleDeclaration";
    }

    override void visit(TypeInfoConstDeclaration node)
    {
        typeName = "TypeInfoConstDeclaration";
    }

    override void visit(TypeInfoInvariantDeclaration node)
    {
        typeName = "TypeInfoInvariantDeclaration";
    }

    override void visit(TypeInfoSharedDeclaration node)
    {
        typeName = "TypeInfoSharedDeclaration";
    }

    override void visit(TypeInfoWildDeclaration node)
    {
        typeName = "TypeInfoWildDeclaration";
    }

    override void visit(TypeInfoVectorDeclaration node)
    {
        typeName = "TypeInfoVectorDeclaration";
    }

    override void visit(SharedStaticCtorDeclaration node)
    {
        typeName = "SharedStaticCtorDeclaration";
    }

    override void visit(SharedStaticDtorDeclaration node)
    {
        typeName = "SharedStaticDtorDeclaration";
    }
}

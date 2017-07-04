module ddmd.astsemantic;

import ddmd.mixinastnodes;
import ddmd.astbasevisitor;

struct ASTSemantic
{
    import ddmd.root.rootobject;
    import ddmd.root.array;
    import ddmd.root.stringtable;
    import ddmd.root.ctfloat;
    import ddmd.root.rmem;
    import ddmd.root.outbuffer;
    import ddmd.root.file;
    import ddmd.root.filename;

    import ddmd.tokens;
    import ddmd.identifier;
    import ddmd.globals;
    import ddmd.id;
    import ddmd.errors;
    import ddmd.lexer;
    import ddmd.astattributes;

    import core.stdc.string;
    import core.stdc.stdarg;

    mixin MArrays;
    mixin MAttributes;

    extern (C++) class Dsymbol : RootObject
    {
        mixin MDsymbol!ASTSemantic;
        final extern (D) this() {}
        final extern (D) this(Identifier ident)
        {
            this.ident = ident;
        }
    }

    extern (C++) class AliasThis : Dsymbol
    {
        mixin MAliasThis!ASTSemantic;
    }

    extern (C++) abstract class Declaration : Dsymbol
    {
        mixin MDeclaration!ASTSemantic;
    }

    extern (C++) class ScopeDsymbol : Dsymbol
    {
        mixin MScopeDsymbol!ASTSemantic;
    }

    extern (C++) class Import : Dsymbol
    {
        mixin MImport!ASTSemantic;
    }

    extern (C++) abstract class AttribDeclaration : Dsymbol
    {
        mixin MAttribDeclaration!ASTSemantic;
    }

    extern (C++) final class StaticAssert : Dsymbol
    {
        mixin MStaticAssert!ASTSemantic;
    }

    extern (C++) class DebugSymbol : Dsymbol { mixin MDebugSymbol!ASTSemantic; }
    extern (C++) class VersionSymbol : Dsymbol { mixin MVersionSymbol!ASTSemantic; }
    extern (C++) class VarDeclaration : Declaration { mixin MVarDeclaration!ASTSemantic; }
    extern (C++) class FuncDeclaration : Declaration { mixin MFuncDeclaration!ASTSemantic; }
    extern (C++) class AliasDeclaration : Declaration
    {
        mixin MAliasDeclaration!ASTSemantic;
        override bool isOverloadable()
        {
            //assume overloadable until alias is resolved;
            // should be modified when semantic analysis is added
            return true;
        }
    }
    extern (C++) class TupleDeclaration : Declaration { mixin MTupleDeclaration!ASTSemantic; }
    extern (C++) class FuncLiteralDeclaration : FuncDeclaration { mixin MFuncLiteralDeclaration!ASTSemantic; }
    extern (C++) class PostBlitDeclaration : FuncDeclaration { mixin MPostBlitDeclaration!ASTSemantic; }
    extern (C++) class CtorDeclaration : FuncDeclaration { mixin MCtorDeclaration!ASTSemantic; }
    extern (C++) class DtorDeclaration : FuncDeclaration { mixin MDtorDeclaration!ASTSemantic; }
    extern (C++) class InvariantDeclaration : FuncDeclaration { mixin MInvariantDeclaration!ASTSemantic; }
    extern (C++) class UnitTestDeclaration : FuncDeclaration { mixin MUnitTestDeclaration!ASTSemantic; }
    extern (C++) class NewDeclaration : FuncDeclaration { mixin MNewDeclaration!ASTSemantic; }
    extern (C++) class DeleteDeclaration : FuncDeclaration { mixin MDeleteDeclaration!ASTSemantic; }
    extern (C++) class StaticCtorDeclaration : FuncDeclaration { mixin MStaticCtorDeclaration!ASTSemantic; }
    extern (C++) class StaticDtorDeclaration : FuncDeclaration { mixin MStaticDtorDeclaration!ASTSemantic; }
    extern (C++) class SharedStaticCtorDeclaration : StaticCtorDeclaration { mixin MSharedStaticCtorDeclaration!ASTSemantic; }
    extern (C++) class SharedStaticDtorDeclaration : StaticDtorDeclaration { mixin MSharedStaticDtorDeclaration!ASTSemantic; }
    extern (C++) class Package : ScopeDsymbol { mixin MPackage!ASTSemantic; }
    extern (C++) class EnumDeclaration : ScopeDsymbol { mixin MEnumDeclaration!ASTSemantic; }
    extern (C++) abstract class AggregateDeclaration : ScopeDsymbol { mixin MAggregateDeclaration!ASTSemantic; }
    extern (C++) class TemplateDeclaration : ScopeDsymbol { mixin MTemplateDeclaration!ASTSemantic; }
    extern (C++) class TemplateInstance : ScopeDsymbol { mixin MTemplateInstance!ASTSemantic; }
    extern (C++) class Nspace : ScopeDsymbol { mixin MNspace!ASTSemantic; }
    extern (C++) class CompileDeclaration : AttribDeclaration { mixin MCompileDeclaration!ASTSemantic; }
    extern (C++) class UserAttributeDeclaration : AttribDeclaration { mixin MUserAttributeDeclaration!ASTSemantic; }
    extern (C++) class LinkDeclaration : AttribDeclaration { mixin MLinkDeclaration!ASTSemantic; }
    extern (C++) class AnonDeclaration : AttribDeclaration { mixin MAnonDeclaration!ASTSemantic; }
    extern (C++) class AlignDeclaration : AttribDeclaration { mixin MAlignDeclaration!ASTSemantic; }
    extern (C++) class CPPMangleDeclaration : AttribDeclaration { mixin MCPPMangleDeclaration!ASTSemantic; }
    extern (C++) class ProtDeclaration : AttribDeclaration { mixin MProtDeclaration!ASTSemantic; }
    extern (C++) class PragmaDeclaration : AttribDeclaration { mixin MPragmaDeclaration!ASTSemantic; }
    extern (C++) class StorageClassDeclaration : AttribDeclaration { mixin MStorageClassDeclaration!ASTSemantic; }
    extern (C++) class ConditionalDeclaration : AttribDeclaration { mixin MConditionalDeclaration!ASTSemantic; }
    extern (C++) class DeprecatedDeclaration : StorageClassDeclaration { mixin MDeprecatedDeclaration!ASTSemantic; }
    extern (C++) class StaticIfDeclaration : ConditionalDeclaration { mixin MStaticIfDeclaration!ASTSemantic; }
    extern (C++) class EnumMember : VarDeclaration { mixin MEnumMember!ASTSemantic; }
    extern (C++) class Module : Package
    {
        mixin MModule!ASTSemantic;
        extern (D) this(const(char)* filename, Identifier ident, int doDocComment, int doHdrGen)
        {
            super(ident);
            this.arg = filename;
            const(char)* srcfilename = FileName.defaultExt(filename, global.mars_ext);
            srcfile = new File(srcfilename);
        }
    }
    extern (C++) class StructDeclaration : AggregateDeclaration { mixin MStructDeclaration!ASTSemantic; }
    extern (C++) class UnionDeclaration : StructDeclaration { mixin MUnionDeclaration!ASTSemantic; }
    extern (C++) class ClassDeclaration : AggregateDeclaration { mixin MClassDeclaration!ASTSemantic; }
    extern (C++) class InterfaceDeclaration : ClassDeclaration { mixin MInterfaceDeclaration!ASTSemantic; }
    extern (C++) class TemplateMixin : TemplateInstance { mixin MTemplateMixin!ASTSemantic; }
    extern (C++) class Parameter : RootObject { mixin MParameter!ASTSemantic; }
    extern (C++) abstract class Statement : RootObject { mixin MStatement!ASTSemantic; }
    extern (C++) class ImportStatement : Statement { mixin MImportStatement!ASTSemantic; }
    extern (C++) class ScopeStatement : Statement { mixin MScopeStatement!ASTSemantic; }
    extern (C++) class ReturnStatement : Statement { mixin MReturnStatement!ASTSemantic; }
    extern (C++) class LabelStatement : Statement { mixin MLabelStatement!ASTSemantic; }
    extern (C++) class StaticAssertStatement : Statement { mixin MStaticAssertStatement!ASTSemantic; }
    extern (C++) class CompileStatement : Statement { mixin MCompileStatement!ASTSemantic; }
    extern (C++) class WhileStatement : Statement { mixin MWhileStatement!ASTSemantic; }
    extern (C++) class ForStatement : Statement { mixin MForStatement!ASTSemantic; }
    extern (C++) class DoStatement : Statement { mixin MDoStatement!ASTSemantic; }
    extern (C++) class ForeachRangeStatement : Statement { mixin MForeachRange!ASTSemantic; }
    extern (C++) class ForeachStatement : Statement { mixin MForeachStatement!ASTSemantic; }
    extern (C++) class IfStatement : Statement { mixin MIfStatement!ASTSemantic; }
    extern (C++) class OnScopeStatement : Statement { mixin MOnScopeStatement!ASTSemantic; }
    extern (C++) class ConditionalStatement : Statement { mixin MConditionalStatement!ASTSemantic; }
    extern (C++) class PragmaStatement : Statement { mixin MPragmaStatement!ASTSemantic; }
    extern (C++) class SwitchStatement : Statement { mixin MSwitchStatement!ASTSemantic; }
    extern (C++) class CaseRangeStatement : Statement { mixin MCaseRangeStatement!ASTSemantic; }
    extern (C++) class CaseStatement : Statement { mixin MCaseStatement!ASTSemantic; }
    extern (C++) class DefaultStatement : Statement { mixin MDefaultStatement!ASTSemantic; }
    extern (C++) class BreakStatement : Statement { mixin MBreakStatement!ASTSemantic; }
    extern (C++) class ContinueStatement : Statement { mixin MContinueStatement!ASTSemantic; }
    extern (C++) class GotoDefaultStatement : Statement { mixin MGotoDefaultStatement!ASTSemantic; }
    extern (C++) class GotoCaseStatement : Statement { mixin MGotoCaseStatement!ASTSemantic; }
    extern (C++) class GotoStatement : Statement { mixin MGotoStatement!ASTSemantic; }
    extern (C++) class SynchronizedStatement : Statement { mixin MSynchronizedStatement!ASTSemantic; }
    extern (C++) class WithStatement : Statement { mixin MWithStatement!ASTSemantic; }
    extern (C++) class TryCatchStatement : Statement { mixin MTryCatchStatement!ASTSemantic; }
    extern (C++) class TryFinallyStatement : Statement { mixin MTryFinallyStatement!ASTSemantic; }
    extern (C++) class ThrowStatement : Statement { mixin MThrowStatement!ASTSemantic; }
    extern (C++) class AsmStatement : Statement { mixin MAsmStatement!ASTSemantic; }
    extern (C++) class ExpStatement : Statement { mixin MExpStatement!ASTSemantic; }
    extern (C++) class CompoundStatement : Statement { mixin MCompoundStatement!ASTSemantic; }
    extern (C++) class CompoundDeclarationStatement : CompoundStatement { mixin MCompoundDeclarationStatement!ASTSemantic; }
    extern (C++) class CompoundAsmStatement : CompoundStatement { mixin MCompoundAsmStatement!ASTSemantic; }
    extern (C++) class Catch : RootObject { mixin MCatch!ASTSemantic; }

    extern (C++) __gshared int Tsize_t = Tuns32;
    extern (C++) __gshared int Tptrdiff_t = Tint32;

    extern (C++) abstract class Type : RootObject
    {
        // These members are probably used in semnatic analysis
        //TypeInfoDeclaration vtinfo;
        //type* ctype;

        mixin MType!ASTSemantic;
        override const(char)* toChars()
        {
            return "type";
        }

        final Type nullAttributes()
        {
            uint sz = sizeTy[ty];
            Type t = cast(Type)mem.xmalloc(sz);
            memcpy(cast(void*)t, cast(void*)this, sz);
            // t.mod = NULL;  // leave mod unchanged
            t.deco = null;
            t.arrayof = null;
            t.pto = null;
            t.rto = null;
            t.cto = null;
            t.ito = null;
            t.sto = null;
            t.scto = null;
            t.wto = null;
            t.wcto = null;
            t.swto = null;
            t.swcto = null;
            //t.vtinfo = null; these aren't used in parsing
            //t.ctype = null;
            if (t.ty == Tstruct)
                (cast(TypeStruct)t).att = RECfwdref;
            if (t.ty == Tclass)
                (cast(TypeClass)t).att = RECfwdref;
            return t;
        }

        // Truncated
        final Type merge()
        {
            if (ty == Terror)
                return this;
            if (ty == Ttypeof)
                return this;
            if (ty == Tident)
                return this;
            if (ty == Tinstance)
                return this;
            if (ty == Taarray && !(cast(TypeAArray)this).index.merge().deco)
                return this;
            if (ty != Tenum && nextOf() && !nextOf().deco)
                return this;

            // if (!deco) - code missing

            Type t = this;
            assert(t);
            return t;
        }
    }

    // missing functionality in constructor, but that's ok
    // since the class is needed only for its size; need to add all method definitions
    extern (C++) class TypeBasic : Type { mixin MTypeBasic!ASTSemantic; }
    extern (C++) class TypeError : Type { mixin MTypeError!ASTSemantic; }
    extern (C++) class TypeNull : Type { mixin MTypeNull!ASTSemantic; }
    extern (C++) class TypeVector : Type { mixin MTypeVector!ASTSemantic; }
    extern (C++) class TypeEnum : Type { mixin MTypeEnum!ASTSemantic; }
    extern (C++) class TypeTuple : Type { mixin MTypeTuple!ASTSemantic; }
    extern (C++) class TypeClass : Type { mixin MTypeClass!ASTSemantic; }
    extern (C++) class TypeStruct : Type { mixin MTypeStruct!ASTSemantic; }
    extern (C++) class TypeReference : TypeNext { mixin MTypeReference!ASTSemantic; }
    extern (C++) abstract class TypeNext : Type { mixin MTypeNext!ASTSemantic; }
    extern (C++) class TypeSlice : TypeNext { mixin MTypeSlice!ASTSemantic; }
    extern (C++) class TypeDelegate : TypeNext { mixin MTypeDelegate!ASTSemantic; }
    extern (C++) class TypePointer : TypeNext { mixin MTypePointer!ASTSemantic; }
    extern (C++) class TypeFunction : TypeNext { mixin MTypeFunction!ASTSemantic; }
    extern (C++) class TypeArray : TypeNext { mixin MTypeArray!ASTSemantic; }
    extern (C++) class TypeDArray : TypeArray { mixin MTypeDArray!ASTSemantic; }
    extern (C++) class TypeAArray : TypeArray { mixin MTypeAArray!ASTSemantic; }
    extern (C++) class TypeSArray : TypeArray { mixin MTypeSArray!ASTSemantic; }
    extern (C++) abstract class TypeQualified : Type { mixin MTypeQualified!ASTSemantic; }
    extern (C++) class TypeIdentifier : TypeQualified { mixin MTypeIdentifier!ASTSemantic; }
    extern (C++) class TypeReturn : TypeQualified { mixin MTypeReturn!ASTSemantic; }
    extern (C++) class TypeTypeof : TypeQualified { mixin MTypeTypeOf!ASTSemantic; }
    extern (C++) class TypeInstance : TypeQualified { mixin MTypeInstance!ASTSemantic; }
    extern (C++) abstract class Expression : RootObject { mixin MExpression!ASTSemantic; }
    extern (C++) class DeclarationExp : Expression { mixin MDeclarationExp!ASTSemantic; }
    extern (C++) class IntegerExp : Expression { mixin MIntegerExp!ASTSemantic; }
    extern (C++) class NewAnonClassExp : Expression { mixin MNewAnonClassExp!ASTSemantic; }
    extern (C++) class IsExp : Expression { mixin MIsExp!ASTSemantic; }
    extern (C++) class RealExp : Expression { mixin MRealExp!ASTSemantic; }
    extern (C++) class NullExp : Expression { mixin MNullExp!ASTSemantic; }
    extern (C++) class TypeidExp : Expression { mixin MTypeidExp!ASTSemantic; }
    extern (C++) class TraitsExp : Expression { mixin MTraitsExp!ASTSemantic; }
    extern (C++) class StringExp : Expression { mixin MStringExp!ASTSemantic; }
    extern (C++) class NewExp : Expression { mixin MNewExp!ASTSemantic; }
    extern (C++) class AssocArrayLiteralExp : Expression { mixin MAssocArrayLiteralExp!ASTSemantic; }
    extern (C++) class ArrayLiteralExp : Expression { mixin MArrayLiteralExp!ASTSemantic; }
    extern (C++) class FuncExp : Expression { mixin MFuncExp!ASTSemantic; }
    extern (C++) class IntervalExp : Expression { mixin MIntervalExp!ASTSemantic; }
    extern (C++) class TypeExp : Expression { mixin MTypeExp!ASTSemantic; }
    extern (C++) class ScopeExp : Expression { mixin MScopeExp!ASTSemantic; }
    extern (C++) class IdentifierExp : Expression { mixin MIdentifierExp!ASTSemantic; }
    extern (C++) class UnaExp : Expression { mixin MUnaExp!ASTSemantic; }
    extern (C++) class DefaultInitExp : Expression { mixin MDefaultInitExp!ASTSemantic; }
    extern (C++) abstract class BinExp : Expression { mixin MBinExp!ASTSemantic; }
    extern (C++) class DsymbolExp : Expression { mixin MDsymbolExp!ASTSemantic; }
    extern (C++) class TemplateExp : Expression { mixin MTemplateExp!ASTSemantic; }
    extern (C++) class SymbolExp : Expression { mixin MSymbolExp!ASTSemantic; }
    extern (C++) class VarExp : SymbolExp { mixin MVarExp!ASTSemantic; }
    extern (C++) class TupleExp : Expression { mixin MTupleExp!ASTSemantic; }
    extern (C++) class DollarExp : IdentifierExp { mixin MDollarExp!ASTSemantic; }
    extern (C++) class ThisExp : Expression { mixin MThisExp!ASTSemantic; }
    extern (C++) class SuperExp : ThisExp { mixin MSuperExp!ASTSemantic; }
    extern (C++) class AddrExp : UnaExp { mixin MAddrExp!ASTSemantic; }
    extern (C++) class PreExp : UnaExp { mixin MPreExp!ASTSemantic; }
    extern (C++) class PtrExp : UnaExp { mixin MPtrExp!ASTSemantic; }
    extern (C++) class NegExp : UnaExp { mixin MNegExp!ASTSemantic; }
    extern (C++) class UAddExp : UnaExp { mixin MUAddExp!ASTSemantic; }
    extern (C++) class NotExp : UnaExp { mixin MNotExp!ASTSemantic; }
    extern (C++) class ComExp : UnaExp { mixin MComExp!ASTSemantic; }
    extern (C++) class DeleteExp : UnaExp { mixin MDeleteExp!ASTSemantic; }
    extern (C++) class CastExp : UnaExp { mixin MCastExp!ASTSemantic; }
    extern (C++) class CallExp : UnaExp { mixin MCallExp!ASTSemantic; }
    extern (C++) class DotIdExp : UnaExp { mixin MDotIdExp!ASTSemantic; }
    extern (C++) class AssertExp : UnaExp { mixin MAssertExp!ASTSemantic; }
    extern (C++) class CompileExp : UnaExp { mixin MCompileExp!ASTSemantic; }
    extern (C++) class ImportExp : UnaExp { mixin MImportExp!ASTSemantic; }
    extern (C++) class DotTemplateInstanceExp : UnaExp { mixin MDotTemplateInstanceExp!ASTSemantic; }
    extern (C++) class ArrayExp : UnaExp { mixin MArrayExp!ASTSemantic; }
    extern (C++) class FuncInitExp : DefaultInitExp { mixin MFuncInitExp!ASTSemantic; }
    extern (C++) class PrettyFuncInitExp : DefaultInitExp { mixin MPrettyFuncInitExp!ASTSemantic; }
    extern (C++) class FileInitExp : DefaultInitExp { mixin MFileInitExp!ASTSemantic; }
    extern (C++) class LineInitExp : DefaultInitExp { mixin MLineInitExp!ASTSemantic; }
    extern (C++) class ModuleInitExp : DefaultInitExp { mixin MModuleInitExp!ASTSemantic; }
    extern (C++) class CommaExp : BinExp { mixin MCommaExp!ASTSemantic; }
    extern (C++) class PostExp : BinExp { mixin MPostExp!ASTSemantic; }
    extern (C++) class PowExp : BinExp { mixin MBinCommon!(TOKpow, PowExp, ASTSemantic); }
    extern (C++) class MulExp : BinExp { mixin MBinCommon!(TOKmul, MulExp, ASTSemantic); }
    extern (C++) class DivExp : BinExp { mixin MBinCommon!(TOKdiv, DivExp, ASTSemantic); }
    extern (C++) class ModExp : BinExp { mixin MBinCommon!(TOKmod, ModExp, ASTSemantic); }
    extern (C++) class AddExp : BinExp { mixin MBinCommon!(TOKadd, AddExp, ASTSemantic); }
    extern (C++) class MinExp : BinExp { mixin MBinCommon!(TOKmin, MinExp, ASTSemantic); }
    extern (C++) class CatExp : BinExp { mixin MBinCommon!(TOKcat, CatExp, ASTSemantic); }
    extern (C++) class ShlExp : BinExp { mixin MBinCommon!(TOKshl, ShlExp, ASTSemantic); }
    extern (C++) class ShrExp : BinExp { mixin MBinCommon!(TOKshr, ShrExp, ASTSemantic); }
    extern (C++) class UshrExp : BinExp { mixin MBinCommon!(TOKushr, UshrExp, ASTSemantic); }
    extern (C++) class EqualExp : BinExp { mixin MBinCommon2!(EqualExp, ASTSemantic); }
    extern (C++) class InExp : BinExp { mixin MBinCommon!(TOKin, InExp, ASTSemantic); }
    extern (C++) class IdentityExp : BinExp { mixin MBinCommon2!(IdentityExp, ASTSemantic); }
    extern (C++) class CmpExp : BinExp { mixin MBinCommon2!(CmpExp, ASTSemantic); }
    extern (C++) class AndExp : BinExp { mixin MBinCommon!(TOKand, AndExp, ASTSemantic); }
    extern (C++) class XorExp : BinExp { mixin MBinCommon!(TOKxor, XorExp, ASTSemantic); }
    extern (C++) class OrExp : BinExp { mixin MBinCommon!(TOKor, OrExp, ASTSemantic); }
    extern (C++) class AndAndExp : BinExp { mixin MBinCommon!(TOKandand, AndAndExp, ASTSemantic); }
    extern (C++) class OrOrExp : BinExp { mixin MBinCommon!(TOKoror, OrOrExp, ASTSemantic); }
    extern (C++) class CondExp : BinExp { mixin MCondExp!ASTSemantic; }
    extern (C++) class AssignExp : BinExp { mixin MBinCommon!(TOKassign, AssignExp, ASTSemantic); }
    extern (C++) class BinAssignExp : BinExp { mixin MBinAssignExp!ASTSemantic; }
    extern (C++) class AddAssignExp : BinAssignExp { mixin MBinCommon!(TOKaddass, AddAssignExp, ASTSemantic); }
    extern (C++) class MinAssignExp : BinAssignExp { mixin MBinCommon!(TOKminass, MinAssignExp, ASTSemantic); }
    extern (C++) class MulAssignExp : BinAssignExp { mixin MBinCommon!(TOKmulass, MulAssignExp, ASTSemantic); }
    extern (C++) class DivAssignExp : BinAssignExp { mixin MBinCommon!(TOKdivass, DivAssignExp, ASTSemantic); }
    extern (C++) class ModAssignExp : BinAssignExp { mixin MBinCommon!(TOKmodass, ModAssignExp, ASTSemantic); }
    extern (C++) class PowAssignExp : BinAssignExp { mixin MBinCommon!(TOKpowass, PowAssignExp, ASTSemantic); }
    extern (C++) class AndAssignExp : BinAssignExp { mixin MBinCommon!(TOKandass, AndAssignExp, ASTSemantic); }
    extern (C++) class OrAssignExp : BinAssignExp { mixin MBinCommon!(TOKorass, OrAssignExp, ASTSemantic); }
    extern (C++) class XorAssignExp : BinAssignExp { mixin MBinCommon!(TOKxorass, XorAssignExp, ASTSemantic); }
    extern (C++) class ShlAssignExp : BinAssignExp { mixin MBinCommon!(TOKshlass, ShlAssignExp, ASTSemantic); }
    extern (C++) class ShrAssignExp : BinAssignExp { mixin MBinCommon!(TOKshrass, ShrAssignExp, ASTSemantic); }
    extern (C++) class UshrAssignExp : BinAssignExp { mixin MBinCommon!(TOKushrass, UshrAssignExp, ASTSemantic); }
    extern (C++) class CatAssignExp : BinAssignExp { mixin MBinCommon!(TOKcatass, CatAssignExp, ASTSemantic); }
    extern (C++) class TemplateParameter { mixin MTemplateParameter!ASTSemantic; }
    extern (C++) class TemplateAliasParameter : TemplateParameter { mixin MTemplateAliasParameter!ASTSemantic; }
    extern (C++) class TemplateTypeParameter : TemplateParameter { mixin MTemplateTypeParameter!ASTSemantic; }
    extern (C++) class TemplateTupleParameter : TemplateParameter { mixin MTemplateTupleParameter!ASTSemantic; }
    extern (C++) class TemplateValueParameter : TemplateParameter { mixin MTemplateValueParameter!ASTSemantic; }
    extern (C++) class TemplateThisParameter : TemplateTypeParameter { mixin MTemplateThisParameter!ASTSemantic; }
    extern (C++) abstract class Condition : RootObject { mixin MCondition!ASTSemantic; }
    extern (C++) class StaticIfCondition : Condition { mixin MStaticIfCondition!ASTSemantic; }
    extern (C++) class DVCondition : Condition { mixin MDVCondition!ASTSemantic; }
    extern (C++) class DebugCondition : DVCondition { mixin MDebugCondition!ASTSemantic; }
    extern (C++) class VersionCondition : DVCondition { mixin MVersionCondition!ASTSemantic; }
    extern (C++) class Initializer : RootObject { mixin MInitializer!ASTSemantic; }
    extern (C++) class ExpInitializer : Initializer { mixin MExpInitializer!ASTSemantic; }
    extern (C++) class StructInitializer : Initializer { mixin MStructInitializer!ASTSemantic; }
    extern (C++) class ArrayInitializer : Initializer { mixin MArrayInitializer!ASTSemantic; }
    extern (C++) class VoidInitializer : Initializer { mixin MVoidInitializer!ASTSemantic; }
    extern (C++) class Tuple : RootObject { mixin MTuple!ASTSemantic; }

    struct BaseClass
    {
        Type type;
    }

    struct Scope {}

    struct ModuleDeclaration
    {
        Loc loc;
        Identifier id;
        Identifiers *packages;
        bool isdeprecated;
        Expression msg;

        extern (D) this(Loc loc, Identifiers* packages, Identifier id, Expression msg, bool isdeprecated)
        {
            this.loc = loc;
            this.packages = packages;
            this.id = id;
            this.msg = msg;
            this.isdeprecated = isdeprecated;
        }

        extern (C++) const(char)* toChars()
        {
            OutBuffer buf;
            if (packages && packages.dim)
            {
                for (size_t i = 0; i < packages.dim; i++)
                {
                    Identifier pid = (*packages)[i];
                    buf.writestring(pid.toChars());
                    buf.writeByte('.');
                }
            }
            buf.writestring(id.toChars());
            return buf.extractString();
        }
    }

    struct Prot
    {
        PROTKIND kind;
        Package pkg;
    }

    struct Target
    {
        extern (C++) static __gshared int ptrsize;

        extern (C++) static Type va_listType()
        {
            if (global.params.isWindows)
            {
                return Type.tchar.pointerTo();
            }
            else if (global.params.isLinux || global.params.isFreeBSD || global.params.isOpenBSD || global.params.isSolaris || global.params.isOSX)
            {
                if (global.params.is64bit)
                {
                    return (new TypeIdentifier(Loc(), Identifier.idPool("__va_list_tag"))).pointerTo();
                }
                else
                {
                    return Type.tchar.pointerTo();
                }
            }
            else
            {
                assert(0);
            }
        }

        extern (C++) static LINK systemLinkage()
        {
            return global.params.isWindows ? LINKwindows : LINKc;
        }
    }

    mixin MStaticHelperFunctions;
}

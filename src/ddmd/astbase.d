module ddmd.astbase;

import ddmd.astbasevisitor;
import ddmd.mixinastnodes;

/** The ASTBase  family defines a family of AST nodes appropriate for parsing with
  * no semantic information. It defines all the AST nodes that the parser needs
  * and also all the conveniance methods and variables. The resulting AST can be
  * visited with the strict, permissive and transitive visitors.
  * The ASTBase family is used to instantiate the parser in the parser library.
  */
struct ASTBase
{
    import ddmd.root.file;
    import ddmd.root.filename;
    import ddmd.root.array;
    import ddmd.root.rootobject;
    import ddmd.root.outbuffer;
    import ddmd.root.ctfloat;
    import ddmd.root.rmem;
    import ddmd.root.stringtable;

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
        mixin MDsymbol!ASTBase;
        final extern (D) this() {}
        final extern (D) this(Identifier ident)
        {
            this.ident = ident;
        }
    }
    extern (C++) class AliasThis : Dsymbol { mixin MAliasThis!ASTBase; }
    extern (C++) abstract class Declaration : Dsymbol { mixin MDeclaration!ASTBase; }
    extern (C++) class ScopeDsymbol : Dsymbol { mixin MScopeDsymbol!ASTBase; }
    extern (C++) class Import : Dsymbol { mixin MImport!ASTBase; }
    extern (C++) abstract class AttribDeclaration : Dsymbol { mixin MAttribDeclaration!ASTBase; }
    extern (C++) class StaticAssert : Dsymbol { mixin MStaticAssert!ASTBase; }
    extern (C++) class DebugSymbol : Dsymbol { mixin MDebugSymbol!ASTBase; }
    extern (C++) class VersionSymbol : Dsymbol { mixin MVersionSymbol!ASTBase; }
    extern (C++) class VarDeclaration : Declaration { mixin MVarDeclaration!ASTBase; }
    extern (C++) class FuncDeclaration : Declaration { mixin MFuncDeclaration!ASTBase; }
    extern (C++) class AliasDeclaration : Declaration
    {
        mixin MAliasDeclaration!ASTBase;
        override bool isOverloadable()
        {
            //assume overloadable until alias is resolved;
            // should be modified when semantic analysis is added
            return true;
        }
    }
    extern (C++) class TupleDeclaration : Declaration { mixin MTupleDeclaration!ASTBase; }
    extern (C++) class FuncLiteralDeclaration : FuncDeclaration { mixin MFuncLiteralDeclaration!ASTBase; }
    extern (C++) class PostBlitDeclaration : FuncDeclaration { mixin MPostBlitDeclaration!ASTBase; }
    extern (C++) class CtorDeclaration : FuncDeclaration { mixin MCtorDeclaration!ASTBase; }
    extern (C++) class DtorDeclaration : FuncDeclaration { mixin MDtorDeclaration!ASTBase; }
    extern (C++) class InvariantDeclaration : FuncDeclaration { mixin MInvariantDeclaration!ASTBase; }
    extern (C++) class UnitTestDeclaration : FuncDeclaration { mixin MUnitTestDeclaration!ASTBase; }
    extern (C++) class NewDeclaration : FuncDeclaration { mixin MNewDeclaration!ASTBase; }
    extern (C++) class DeleteDeclaration : FuncDeclaration { mixin MDeleteDeclaration!ASTBase; }
    extern (C++) class StaticCtorDeclaration : FuncDeclaration { mixin MStaticCtorDeclaration!ASTBase; }
    extern (C++) class StaticDtorDeclaration : FuncDeclaration { mixin MStaticDtorDeclaration!ASTBase; }
    extern (C++) class SharedStaticCtorDeclaration : StaticCtorDeclaration { mixin MSharedStaticCtorDeclaration!ASTBase; }
    extern (C++) class SharedStaticDtorDeclaration : StaticDtorDeclaration { mixin MSharedStaticDtorDeclaration!ASTBase; }
    extern (C++) class Package : ScopeDsymbol { mixin MPackage!ASTBase; }
    extern (C++) class EnumDeclaration : ScopeDsymbol { mixin MEnumDeclaration!ASTBase; }
    extern (C++) abstract class AggregateDeclaration : ScopeDsymbol { mixin MAggregateDeclaration!ASTBase; }
    extern (C++) class TemplateDeclaration : ScopeDsymbol { mixin MTemplateDeclaration!ASTBase; }
    extern (C++) class TemplateInstance : ScopeDsymbol { mixin MTemplateInstance!ASTBase; }
    extern (C++) class Nspace : ScopeDsymbol { mixin MNspace!ASTBase; }
    extern (C++) class CompileDeclaration : AttribDeclaration { mixin MCompileDeclaration!ASTBase; }
    extern (C++) class UserAttributeDeclaration : AttribDeclaration { mixin MUserAttributeDeclaration!ASTBase; }
    extern (C++) class LinkDeclaration : AttribDeclaration { mixin MLinkDeclaration!ASTBase; }
    extern (C++) class AnonDeclaration : AttribDeclaration { mixin MAnonDeclaration!ASTBase; }
    extern (C++) class AlignDeclaration : AttribDeclaration { mixin MAlignDeclaration!ASTBase; }
    extern (C++) class CPPMangleDeclaration : AttribDeclaration { mixin MCPPMangleDeclaration!ASTBase; }
    extern (C++) class ProtDeclaration : AttribDeclaration { mixin MProtDeclaration!ASTBase; }
    extern (C++) class PragmaDeclaration : AttribDeclaration { mixin MPragmaDeclaration!ASTBase; }
    extern (C++) class StorageClassDeclaration : AttribDeclaration { mixin MStorageClassDeclaration!ASTBase; }
    extern (C++) class ConditionalDeclaration : AttribDeclaration { mixin MConditionalDeclaration!ASTBase; }
    extern (C++) class DeprecatedDeclaration : StorageClassDeclaration { mixin MDeprecatedDeclaration!ASTBase; }
    extern (C++) class StaticIfDeclaration : ConditionalDeclaration { mixin MStaticIfDeclaration!ASTBase; }
    extern (C++) class EnumMember : VarDeclaration { mixin MEnumMember!ASTBase; }
    extern (C++) class Module : Package
    {
        mixin MModule!ASTBase;
        extern (D) this(const(char)* filename, Identifier ident, int doDocComment, int doHdrGen)
        {
            super(ident);
            this.arg = filename;
            const(char)* srcfilename = FileName.defaultExt(filename, global.mars_ext);
            srcfile = new File(srcfilename);
        }
    }
    extern (C++) class StructDeclaration : AggregateDeclaration { mixin MStructDeclaration!ASTBase; }
    extern (C++) class UnionDeclaration : StructDeclaration { mixin MUnionDeclaration!ASTBase; }
    extern (C++) class ClassDeclaration : AggregateDeclaration { mixin MClassDeclaration!ASTBase; }
    extern (C++) class InterfaceDeclaration : ClassDeclaration { mixin MInterfaceDeclaration!ASTBase; }
    extern (C++) class TemplateMixin : TemplateInstance { mixin MTemplateMixin!ASTBase; }
    extern (C++) class Parameter : RootObject { mixin MParameter!ASTBase; }
    extern (C++) abstract class Statement : RootObject { mixin MStatement!ASTBase; }
    extern (C++) class ImportStatement : Statement { mixin MImportStatement!ASTBase; }
    extern (C++) class ScopeStatement : Statement { mixin MScopeStatement!ASTBase; }
    extern (C++) class ReturnStatement : Statement { mixin MReturnStatement!ASTBase; }
    extern (C++) class LabelStatement : Statement { mixin MLabelStatement!ASTBase; }
    extern (C++) class StaticAssertStatement : Statement { mixin MStaticAssertStatement!ASTBase; }
    extern (C++) class CompileStatement : Statement { mixin MCompileStatement!ASTBase; }
    extern (C++) class WhileStatement : Statement { mixin MWhileStatement!ASTBase; }
    extern (C++) class ForStatement : Statement { mixin MForStatement!ASTBase; }
    extern (C++) class DoStatement : Statement { mixin MDoStatement!ASTBase; }
    extern (C++) class ForeachRangeStatement : Statement { mixin MForeachRange!ASTBase; }
    extern (C++) class ForeachStatement : Statement { mixin MForeachStatement!ASTBase; }
    extern (C++) class IfStatement : Statement { mixin MIfStatement!ASTBase; }
    extern (C++) class OnScopeStatement : Statement { mixin MOnScopeStatement!ASTBase; }
    extern (C++) class ConditionalStatement : Statement { mixin MConditionalStatement!ASTBase; }
    extern (C++) class PragmaStatement : Statement { mixin MPragmaStatement!ASTBase; }
    extern (C++) class SwitchStatement : Statement { mixin MSwitchStatement!ASTBase; }
    extern (C++) class CaseRangeStatement : Statement { mixin MCaseRangeStatement!ASTBase; }
    extern (C++) class CaseStatement : Statement { mixin MCaseStatement!ASTBase; }
    extern (C++) class DefaultStatement : Statement { mixin MDefaultStatement!ASTBase; }
    extern (C++) class BreakStatement : Statement { mixin MBreakStatement!ASTBase; }
    extern (C++) class ContinueStatement : Statement { mixin MContinueStatement!ASTBase; }
    extern (C++) class GotoDefaultStatement : Statement { mixin MGotoDefaultStatement!ASTBase; }
    extern (C++) class GotoCaseStatement : Statement { mixin MGotoCaseStatement!ASTBase; }
    extern (C++) class GotoStatement : Statement { mixin MGotoStatement!ASTBase; }
    extern (C++) class SynchronizedStatement : Statement { mixin MSynchronizedStatement!ASTBase; }
    extern (C++) class WithStatement : Statement { mixin MWithStatement!ASTBase; }
    extern (C++) class TryCatchStatement : Statement { mixin MTryCatchStatement!ASTBase; }
    extern (C++) class TryFinallyStatement : Statement { mixin MTryFinallyStatement!ASTBase; }
    extern (C++) class ThrowStatement : Statement { mixin MThrowStatement!ASTBase; }
    extern (C++) class AsmStatement : Statement { mixin MAsmStatement!ASTBase; }
    extern (C++) class ExpStatement : Statement { mixin MExpStatement!ASTBase; }
    extern (C++) class CompoundStatement : Statement { mixin MCompoundStatement!ASTBase; }
    extern (C++) class CompoundDeclarationStatement : CompoundStatement { mixin MCompoundDeclarationStatement!ASTBase; }
    extern (C++) class CompoundAsmStatement : CompoundStatement { mixin MCompoundAsmStatement!ASTBase; }
    extern (C++) class Catch : RootObject { mixin MCatch!ASTBase; }

    extern (C++) __gshared int Tsize_t = Tuns32;
    extern (C++) __gshared int Tptrdiff_t = Tint32;

    extern (C++) abstract class Type : RootObject
    {
        // These members are probably used in semnatic analysis
        //TypeInfoDeclaration vtinfo;
        //type* ctype;

        mixin MType!ASTBase;
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
    extern (C++) class TypeBasic : Type { mixin MTypeBasic!ASTBase; }
    extern (C++) class TypeError : Type { mixin MTypeError!ASTBase; }
    extern (C++) class TypeNull : Type { mixin MTypeNull!ASTBase; }
    extern (C++) class TypeVector : Type { mixin MTypeVector!ASTBase; }
    extern (C++) class TypeEnum : Type { mixin MTypeEnum!ASTBase; }
    extern (C++) class TypeTuple : Type { mixin MTypeTuple!ASTBase; }
    extern (C++) class TypeClass : Type { mixin MTypeClass!ASTBase; }
    extern (C++) class TypeStruct : Type { mixin MTypeStruct!ASTBase; }
    extern (C++) class TypeReference : TypeNext { mixin MTypeReference!ASTBase; }
    extern (C++) abstract class TypeNext : Type { mixin MTypeNext!ASTBase; }
    extern (C++) class TypeSlice : TypeNext { mixin MTypeSlice!ASTBase; }
    extern (C++) class TypeDelegate : TypeNext { mixin MTypeDelegate!ASTBase; }
    extern (C++) class TypePointer : TypeNext { mixin MTypePointer!ASTBase; }
    extern (C++) class TypeFunction : TypeNext { mixin MTypeFunction!ASTBase; }
    extern (C++) class TypeArray : TypeNext { mixin MTypeArray!ASTBase; }
    extern (C++) class TypeDArray : TypeArray { mixin MTypeDArray!ASTBase; }
    extern (C++) class TypeAArray : TypeArray { mixin MTypeAArray!ASTBase; }
    extern (C++) class TypeSArray : TypeArray { mixin MTypeSArray!ASTBase; }
    extern (C++) abstract class TypeQualified : Type { mixin MTypeQualified!ASTBase; }
    extern (C++) class TypeIdentifier : TypeQualified { mixin MTypeIdentifier!ASTBase; }
    extern (C++) class TypeReturn : TypeQualified { mixin MTypeReturn!ASTBase; }
    extern (C++) class TypeTypeof : TypeQualified { mixin MTypeTypeOf!ASTBase; }
    extern (C++) class TypeInstance : TypeQualified { mixin MTypeInstance!ASTBase; }
    extern (C++) abstract class Expression : RootObject { mixin MExpression!ASTBase; }
    extern (C++) class DeclarationExp : Expression { mixin MDeclarationExp!ASTBase; }
    extern (C++) class IntegerExp : Expression { mixin MIntegerExp!ASTBase; }
    extern (C++) class NewAnonClassExp : Expression { mixin MNewAnonClassExp!ASTBase; }
    extern (C++) class IsExp : Expression { mixin MIsExp!ASTBase; }
    extern (C++) class RealExp : Expression { mixin MRealExp!ASTBase; }
    extern (C++) class NullExp : Expression { mixin MNullExp!ASTBase; }
    extern (C++) class TypeidExp : Expression { mixin MTypeidExp!ASTBase; }
    extern (C++) class TraitsExp : Expression { mixin MTraitsExp!ASTBase; }
    extern (C++) class StringExp : Expression { mixin MStringExp!ASTBase; }
    extern (C++) class NewExp : Expression { mixin MNewExp!ASTBase; }
    extern (C++) class AssocArrayLiteralExp : Expression { mixin MAssocArrayLiteralExp!ASTBase; }
    extern (C++) class ArrayLiteralExp : Expression { mixin MArrayLiteralExp!ASTBase; }
    extern (C++) class FuncExp : Expression { mixin MFuncExp!ASTBase; }
    extern (C++) class IntervalExp : Expression { mixin MIntervalExp!ASTBase; }
    extern (C++) class TypeExp : Expression { mixin MTypeExp!ASTBase; }
    extern (C++) class ScopeExp : Expression { mixin MScopeExp!ASTBase; }
    extern (C++) class IdentifierExp : Expression { mixin MIdentifierExp!ASTBase; }
    extern (C++) class UnaExp : Expression { mixin MUnaExp!ASTBase; }
    extern (C++) class DefaultInitExp : Expression { mixin MDefaultInitExp!ASTBase; }
    extern (C++) abstract class BinExp : Expression { mixin MBinExp!ASTBase; }
    extern (C++) class DsymbolExp : Expression { mixin MDsymbolExp!ASTBase; }
    extern (C++) class TemplateExp : Expression { mixin MTemplateExp!ASTBase; }
    extern (C++) class SymbolExp : Expression { mixin MSymbolExp!ASTBase; }
    extern (C++) class VarExp : SymbolExp { mixin MVarExp!ASTBase; }
    extern (C++) class TupleExp : Expression { mixin MTupleExp!ASTBase; }
    extern (C++) class DollarExp : IdentifierExp { mixin MDollarExp!ASTBase; }
    extern (C++) class ThisExp : Expression { mixin MThisExp!ASTBase; }
    extern (C++) class SuperExp : ThisExp { mixin MSuperExp!ASTBase; }
    extern (C++) class AddrExp : UnaExp { mixin MAddrExp!ASTBase; }
    extern (C++) class PreExp : UnaExp { mixin MPreExp!ASTBase; }
    extern (C++) class PtrExp : UnaExp { mixin MPtrExp!ASTBase; }
    extern (C++) class NegExp : UnaExp { mixin MNegExp!ASTBase; }
    extern (C++) class UAddExp : UnaExp { mixin MUAddExp!ASTBase; }
    extern (C++) class NotExp : UnaExp { mixin MNotExp!ASTBase; }
    extern (C++) class ComExp : UnaExp { mixin MComExp!ASTBase; }
    extern (C++) class DeleteExp : UnaExp { mixin MDeleteExp!ASTBase; }
    extern (C++) class CastExp : UnaExp { mixin MCastExp!ASTBase; }
    extern (C++) class CallExp : UnaExp { mixin MCallExp!ASTBase; }
    extern (C++) class DotIdExp : UnaExp { mixin MDotIdExp!ASTBase; }
    extern (C++) class AssertExp : UnaExp { mixin MAssertExp!ASTBase; }
    extern (C++) class CompileExp : UnaExp { mixin MCompileExp!ASTBase; }
    extern (C++) class ImportExp : UnaExp { mixin MImportExp!ASTBase; }
    extern (C++) class DotTemplateInstanceExp : UnaExp { mixin MDotTemplateInstanceExp!ASTBase; }
    extern (C++) class ArrayExp : UnaExp { mixin MArrayExp!ASTBase; }
    extern (C++) class FuncInitExp : DefaultInitExp { mixin MFuncInitExp!ASTBase; }
    extern (C++) class PrettyFuncInitExp : DefaultInitExp { mixin MPrettyFuncInitExp!ASTBase; }
    extern (C++) class FileInitExp : DefaultInitExp { mixin MFileInitExp!ASTBase; }
    extern (C++) class LineInitExp : DefaultInitExp { mixin MLineInitExp!ASTBase; }
    extern (C++) class ModuleInitExp : DefaultInitExp { mixin MModuleInitExp!ASTBase; }
    extern (C++) class CommaExp : BinExp { mixin MCommaExp!ASTBase; }
    extern (C++) class PostExp : BinExp { mixin MPostExp!ASTBase; }
    extern (C++) class PowExp : BinExp { mixin MBinCommon!(TOKpow, PowExp, ASTBase); }
    extern (C++) class MulExp : BinExp { mixin MBinCommon!(TOKmul, MulExp, ASTBase); }
    extern (C++) class DivExp : BinExp { mixin MBinCommon!(TOKdiv, DivExp, ASTBase); }
    extern (C++) class ModExp : BinExp { mixin MBinCommon!(TOKmod, ModExp, ASTBase); }
    extern (C++) class AddExp : BinExp { mixin MBinCommon!(TOKadd, AddExp, ASTBase); }
    extern (C++) class MinExp : BinExp { mixin MBinCommon!(TOKmin, MinExp, ASTBase); }
    extern (C++) class CatExp : BinExp { mixin MBinCommon!(TOKcat, CatExp, ASTBase); }
    extern (C++) class ShlExp : BinExp { mixin MBinCommon!(TOKshl, ShlExp, ASTBase); }
    extern (C++) class ShrExp : BinExp { mixin MBinCommon!(TOKshr, ShrExp, ASTBase); }
    extern (C++) class UshrExp : BinExp { mixin MBinCommon!(TOKushr, UshrExp, ASTBase); }
    extern (C++) class EqualExp : BinExp { mixin MBinCommon2!(EqualExp, ASTBase); }
    extern (C++) class InExp : BinExp { mixin MBinCommon!(TOKin, InExp, ASTBase); }
    extern (C++) class IdentityExp : BinExp { mixin MBinCommon2!(IdentityExp, ASTBase); }
    extern (C++) class CmpExp : BinExp { mixin MBinCommon2!(CmpExp, ASTBase); }
    extern (C++) class AndExp : BinExp { mixin MBinCommon!(TOKand, AndExp, ASTBase); }
    extern (C++) class XorExp : BinExp { mixin MBinCommon!(TOKxor, XorExp, ASTBase); }
    extern (C++) class OrExp : BinExp { mixin MBinCommon!(TOKor, OrExp, ASTBase); }
    extern (C++) class AndAndExp : BinExp { mixin MBinCommon!(TOKandand, AndAndExp, ASTBase); }
    extern (C++) class OrOrExp : BinExp { mixin MBinCommon!(TOKoror, OrOrExp, ASTBase); }
    extern (C++) class CondExp : BinExp { mixin MCondExp!ASTBase; }
    extern (C++) class AssignExp : BinExp { mixin MBinCommon!(TOKassign, AssignExp, ASTBase); }
    extern (C++) class BinAssignExp : BinExp { mixin MBinAssignExp!ASTBase; }
    extern (C++) class AddAssignExp : BinAssignExp { mixin MBinCommon!(TOKaddass, AddAssignExp, ASTBase); }
    extern (C++) class MinAssignExp : BinAssignExp { mixin MBinCommon!(TOKminass, MinAssignExp, ASTBase); }
    extern (C++) class MulAssignExp : BinAssignExp { mixin MBinCommon!(TOKmulass, MulAssignExp, ASTBase); }
    extern (C++) class DivAssignExp : BinAssignExp { mixin MBinCommon!(TOKdivass, DivAssignExp, ASTBase); }
    extern (C++) class ModAssignExp : BinAssignExp { mixin MBinCommon!(TOKmodass, ModAssignExp, ASTBase); }
    extern (C++) class PowAssignExp : BinAssignExp { mixin MBinCommon!(TOKpowass, PowAssignExp, ASTBase); }
    extern (C++) class AndAssignExp : BinAssignExp { mixin MBinCommon!(TOKandass, AndAssignExp, ASTBase); }
    extern (C++) class OrAssignExp : BinAssignExp { mixin MBinCommon!(TOKorass, OrAssignExp, ASTBase); }
    extern (C++) class XorAssignExp : BinAssignExp { mixin MBinCommon!(TOKxorass, XorAssignExp, ASTBase); }
    extern (C++) class ShlAssignExp : BinAssignExp { mixin MBinCommon!(TOKshlass, ShlAssignExp, ASTBase); }
    extern (C++) class ShrAssignExp : BinAssignExp { mixin MBinCommon!(TOKshrass, ShrAssignExp, ASTBase); }
    extern (C++) class UshrAssignExp : BinAssignExp { mixin MBinCommon!(TOKushrass, UshrAssignExp, ASTBase); }
    extern (C++) class CatAssignExp : BinAssignExp { mixin MBinCommon!(TOKcatass, CatAssignExp, ASTBase); }
    extern (C++) class TemplateParameter { mixin MTemplateParameter!ASTBase; }
    extern (C++) class TemplateAliasParameter : TemplateParameter { mixin MTemplateAliasParameter!ASTBase; }
    extern (C++) class TemplateTypeParameter : TemplateParameter { mixin MTemplateTypeParameter!ASTBase; }
    extern (C++) class TemplateTupleParameter : TemplateParameter { mixin MTemplateTupleParameter!ASTBase; }
    extern (C++) class TemplateValueParameter : TemplateParameter { mixin MTemplateValueParameter!ASTBase; }
    extern (C++) class TemplateThisParameter : TemplateTypeParameter { mixin MTemplateThisParameter!ASTBase; }
    extern (C++) abstract class Condition : RootObject { mixin MCondition!ASTBase; }
    extern (C++) class StaticIfCondition : Condition { mixin MStaticIfCondition!ASTBase; }
    extern (C++) class DVCondition : Condition { mixin MDVCondition!ASTBase; }
    extern (C++) class DebugCondition : DVCondition { mixin MDebugCondition!ASTBase; }
    extern (C++) class VersionCondition : DVCondition { mixin MVersionCondition!ASTBase; }
    extern (C++) class Initializer : RootObject { mixin MInitializer!ASTBase; }
    extern (C++) class ExpInitializer : Initializer { mixin MExpInitializer!ASTBase; }
    extern (C++) class StructInitializer : Initializer { mixin MStructInitializer!ASTBase; }
    extern (C++) class ArrayInitializer : Initializer { mixin MArrayInitializer!ASTBase; }
    extern (C++) class VoidInitializer : Initializer { mixin MVoidInitializer!ASTBase; }
    extern (C++) class Tuple : RootObject { mixin MTuple!ASTBase; }

    struct BaseClass
    {
        Type type;
    }

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

    struct Scope
    {

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

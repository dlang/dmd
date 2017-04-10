module ddmd.astnull;

struct ASTNull
{
    import ddmd.root.file;
    import ddmd.root.array;
    import ddmd.root.rootobject;

    import ddmd.tokens;
    import ddmd.identifier;
    import ddmd.globals;

    alias Dsymbols              = Array!(Dsymbol);
    alias Objects               = Array!(RootObject);
    alias Expressions           = Array!(Expression);
    alias TemplateParameters    = Array!(TemplateParameter);
    alias BaseClasses           = Array!(BaseClass*);
    alias Parameters            = Array!(Parameter);
    alias Statements            = Array!(Statement);
    alias Catches               = Array!(Catch);
    alias Identifiers           = Array!(Identifier);

    enum PROTKIND : int
    {
        PROTundefined,
        PROTnone,
        PROTprivate,
        PROTpackage,
        PROTprotected,
        PROTpublic,
        PROTexport,
    }

    alias PROTprivate       = PROTKIND.PROTprivate;
    alias PROTpackage       = PROTKIND.PROTpackage;
    alias PROTprotected     = PROTKIND.PROTprotected;
    alias PROTpublic        = PROTKIND.PROTpublic;
    alias PROTexport        = PROTKIND.PROTexport;
    alias PROTundefined     = PROTKIND.PROTundefined;

    enum MODconst            = 0;
    enum MODimmutable        = 0;
    enum MODshared           = 0;
    enum MODwild             = 0;

    enum STCconst                  = 0;
    enum STCimmutable              = 0;
    enum STCshared                 = 0;
    enum STCwild                   = 0;
    enum STCin                     = 0;
    enum STCout                    = 0;
    enum STCref                    = 0;
    enum STClazy                   = 0;
    enum STCscope                  = 0;
    enum STCfinal                  = 0;
    enum STCauto                   = 0;
    enum STCreturn                 = 0;
    enum STCmanifest               = 0;
    enum STCgshared                = 0;
    enum STCtls                    = 0;
    enum STCsafe                   = 0;
    enum STCsystem                 = 0;
    enum STCtrusted                = 0;
    enum STCnothrow                = 0;
    enum STCpure                   = 0;
    enum STCproperty               = 0;
    enum STCnogc                   = 0;
    enum STCdisable                = 0;
    enum STCundefined              = 0;
    enum STC_TYPECTOR              = 0;
    enum STCoverride               = 0;
    enum STCabstract               = 0;
    enum STCsynchronized           = 0;
    enum STCdeprecated             = 0;
    enum STCstatic                 = 0;
    enum STCextern                 = 0;

    enum Tident                    = 0;
    enum Tfunction                 = 0;
    enum Taarray                   = 0;
    enum Tsarray                   = 0;

    extern (C++) class Dsymbol
    {
        Loc loc;
        Identifier ident;
        UnitTestDeclaration ddocUnittest;
        UserAttributeDeclaration userAttribDecl;

        final extern (D) this() {}

        void addComment(const(char)* comment) {}
        AttribDeclaration isAttribDeclaration()
        {
            return null;
        }
    }

    extern (C++) class AliasThis : Dsymbol
    {
        final extern (D) this(A, B)(A a, B b) {}
    }

    extern (C++) class Declaration : Dsymbol
    {
        StorageClass storage_class;

        final extern (D) this(A)(A a) {}
    }

    extern (C++) class ScopeDsymbol : Dsymbol
    {
        Dsymbols* members;
        final extern (D) this() {}
    }

    extern (C++) class Import : Dsymbol
    {
        final extern (D) this(A, B, C, D, E)(A a, B b, C c, D d, E e) {}
        void addAlias(A, B)(A a, B b) {}
    }

    extern (C++) abstract class AttribDeclaration : Dsymbol
    {
        final extern (D) this(A)(A a) {}
    }

    extern (C++) final class StaticAssert : Dsymbol
    {
        final extern (D) this(A, B, C)(A a, B b, C c) {}
    }

    extern (C++) final class DebugSymbol : Dsymbol
    {
        final extern (D) this(A, B)(A a, B b) {}
    }

    extern (C++) final class VersionSymbol : Dsymbol
    {
        final extern (D) this(A, B)(A a, B b) {}
    }

    extern (C++) class VarDeclaration : Declaration
    {
        final extern (D) this(A, B, C, D)(A a, B b, C c, D d, StorageClass st = STCundefined)
        {
            super(0);
        }
    }

    extern (C++) class FuncDeclaration : Declaration
    {
        Statement fbody;
        Statement frequire;
        Statement fensure;
        Loc endloc;
        Identifier outId;

        final extern (D) this(A, B, C, D, E)(A a, B b, C c, D d, E e)
        {
            super(0);
        }

        FuncLiteralDeclaration* isFuncLiteralDeclaration()
        {
            return null;
        }
    }

    extern (C++) final class AliasDeclaration : Declaration
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0);
        }
    }

    extern (C++) final class FuncLiteralDeclaration : FuncDeclaration
    {
        final extern (D) this(A, B, C, D, E)(A a, B b, C c, D d, E e)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class PostBlitDeclaration : FuncDeclaration
    {
        final extern (D) this(A, B, C, D)(A a, B b, C c, D d)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class CtorDeclaration : FuncDeclaration
    {
        final extern (D) this(A, B, C, D)(A a, B b, C c, D d)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class DtorDeclaration : FuncDeclaration
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0, 0, 0, 0, 0);
        }
        final extern (D) this(A, B, C, D)(A a, B b, C c, D d)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class InvariantDeclaration : FuncDeclaration
    {
        final extern (D) this(A, B, C, D, E)(A a, B b, C c, D d, E e)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class UnitTestDeclaration : FuncDeclaration
    {
        final extern (D) this(A, B, C, D)(A a, B b, C c, D d)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class NewDeclaration : FuncDeclaration
    {
        final extern (D) this(A, B, C, D, E)(A a, B b, C c, D d, E e)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class DeleteDeclaration : FuncDeclaration
    {
        final extern (D) this(A, B, C, D)(A a, B b, C c, D d)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) class StaticCtorDeclaration : FuncDeclaration
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) class StaticDtorDeclaration : FuncDeclaration
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
        final extern (D) this(A, B, C, D)(A a, B b, C c, D d)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class SharedStaticCtorDeclaration : StaticCtorDeclaration
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0);
        }
    }

    extern (C++) final class SharedStaticDtorDeclaration : StaticDtorDeclaration
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0);
        }
    }

    extern (C++) class Package : ScopeDsymbol
    {
        final extern (D) this() {}
    }

    extern (C++) class EnumDeclaration : ScopeDsymbol
    {
        final extern (D) this(A, B, C)(A a, B b, C c) {}
    }

    extern (C++) abstract class AggregateDeclaration : ScopeDsymbol
    {
        final extern (D) this(A, B)(A a, B b) {}
    }

    extern (C++) class TemplateDeclaration : ScopeDsymbol
    {
        final extern (D) this(A, B, C, D, E)(A a, B b, C c, D d, E e, bool f=false, bool g=false) {}
    }

    extern (C++) class TemplateInstance : ScopeDsymbol
    {
        final extern (D) this(A, B, C)(A a, B b, C c) {}
    }

    extern (C++) class Nspace : ScopeDsymbol
    {
        final extern (D) this(A, B, C)(A a, B b, C c) {}
    }

    extern (C++) final class CompileDeclaration : AttribDeclaration
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0);
        }
    }

    extern (C++) final class UserAttributeDeclaration : AttribDeclaration
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0);
        }
        static Expressions* concat(Expressions* a, Expressions* b)
        {
            return null;
        }
    }

    extern (C++) final class LinkDeclaration : AttribDeclaration
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0);
        }
    }

    extern (C++) final class AnonDeclaration : AttribDeclaration
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0);
        }
    }

    extern (C++) final class AlignDeclaration : AttribDeclaration
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0);
        }
    }

    extern (C++) final class CPPMangleDeclaration : AttribDeclaration
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0);
        }
    }

    extern (C++) final class ProtDeclaration : AttribDeclaration
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0);
        }
    }

    extern (C++) final class PragmaDeclaration : AttribDeclaration
    {
        final extern (D) this(A, B, C, D)(A a, B b, C c, D d)
        {
            super(0);
        }
    }

    extern (C++) class StorageClassDeclaration : AttribDeclaration
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0);
        }
    }

    extern (C++) class ConditionalDeclaration : AttribDeclaration
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0);
        }
    }

    extern (C++) final class DeprecatedDeclaration : StorageClassDeclaration
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0, 0);
        }
    }

    extern (C++) class StaticIfDeclaration : ConditionalDeclaration
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0);
        }
    }

    extern (C++) class EnumMember : VarDeclaration
    {
        final extern (D) this(A, B, C, D)(A a, B b, C c, D d)
        {
            super(0, 0, 0, 0);
        }
    }

    extern (C++) class Module : Package
    {
        File* srcfile;
        const(char)* srcfilePath;

        final extern (D) this() {}
        const(char)* toChars() const
        {
            return "";
        }
    }

    extern (C++) class StructDeclaration : AggregateDeclaration
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0, 0);
        }
    }

    extern (C++) final class UnionDeclaration : StructDeclaration
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0, 0);
        }
    }

    extern (C++) class ClassDeclaration : AggregateDeclaration
    {
        final extern (D) this(A, B, C, D, E)(A a, B b, C c, D d, E e)
        {
            super(0, 0);
        }
    }

    extern (C++) class InterfaceDeclaration : ClassDeclaration
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) class TemplateMixin : TemplateInstance
    {
        final extern (D) this(A, B, C, D)(A a, B b, C c, D d)
        {
            super(0, 0, 0);
        }
    }

    extern (C++) final class Parameter : RootObject
    {
        final extern (D) this(A, B, C, D)(A a, B b, C c, D d) {}

        static size_t dim(Parameters* parameters)
        {
            return 0;
        }
    }

    extern (C++) abstract class Statement : RootObject
    {
        final extern (D) this(A)(A a) {}
    }

    extern (C++) final class ImportStatement : Statement
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0);
        }
    }

    extern (C++) final class ScopeStatement : Statement
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0);
        }
    }

    extern (C++) final class ReturnStatement : Statement
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0);
        }
    }

    extern (C++) final class LabelStatement : Statement
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0);
        }
    }

    extern (C++) final class StaticAssertStatement : Statement
    {
        final extern (D) this(A)(A a)
        {
            super(0);
        }
    }

    extern (C++) final class CompileStatement : Statement
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0);
        }
    }

    extern (C++) final class WhileStatement : Statement
    {
        final extern (D) this(A, B, C, D)(A a, B b, C c, D d)
        {
            super(0);
        }
    }

    extern (C++) final class ForStatement : Statement
    {
        final extern (D) this(A, B, C, D, E, F)(A a, B b, C c, D d, E e, F f)
        {
            super(0);
        }
    }

    extern (C++) final class DoStatement : Statement
    {
        final extern (D) this(A, B, C, D)(A a, B b, C c, D d)
        {
            super(0);
        }
    }

    extern (C++) final class ForeachRangeStatement : Statement
    {
        final extern (D) this(A, B, C, D, E, F, G)(A a, B b, C c, D d, E e, F f, G g)
        {
            super(0);
        }
    }

    extern (C++) final class ForeachStatement : Statement
    {
        final extern (D) this(A, B, C, D, E, F)(A a, B b, C c, D d, E e, F f)
        {
            super(0);
        }
    }

    extern (C++) final class IfStatement : Statement
    {
        final extern (D) this(A, B, C, D, E, F)(A a, B b, C c, D d, E e, F f)
        {
            super(0);
        }
    }

    extern (C++) final class OnScopeStatement : Statement
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0);
        }
    }

    extern (C++) final class ConditionalStatement : Statement
    {
        final extern (D) this(A, B, C, D)(A a, B b, C c, D d)
        {
            super(0);
        }
    }

    extern (C++) final class PragmaStatement : Statement
    {
        final extern (D) this(A, B, C, D)(A a, B b, C c, D d)
        {
            super(0);
        }
    }

    extern (C++) final class SwitchStatement : Statement
    {
        final extern (D) this(A, B, C, D)(A a, B b, C c, D d)
        {
            super(0);
        }
    }

    extern (C++) final class CaseRangeStatement : Statement
    {
        final extern (D) this(A, B, C, D)(A a, B b, C c, D d)
        {
            super(0);
        }
    }

    extern (C++) final class CaseStatement : Statement
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0);
        }
    }

    extern (C++) final class DefaultStatement : Statement
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0);
        }
    }

    extern (C++) final class BreakStatement : Statement
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0);
        }
    }

    extern (C++) final class ContinueStatement : Statement
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0);
        }
    }

    extern (C++) final class GotoDefaultStatement : Statement
    {
        final extern (D) this(A)(A a)
        {
            super(0);
        }
    }

    extern (C++) final class GotoCaseStatement : Statement
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0);
        }
    }

    extern (C++) final class GotoStatement : Statement
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0);
        }
    }

    extern (C++) final class SynchronizedStatement : Statement
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0);
        }
    }

    extern (C++) final class WithStatement : Statement
    {
        final extern (D) this(A, B, C, D)(A a, B b, C c, D d)
        {
            super(0);
        }
    }

    extern (C++) final class TryCatchStatement : Statement
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0);
        }
    }

    extern (C++) final class TryFinallyStatement : Statement
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0);
        }
    }

    extern (C++) final class ThrowStatement : Statement
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0);
        }
    }

    extern (C++) final class AsmStatement : Statement
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0);
        }
    }

    extern (C++) class ExpStatement : Statement
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0);
        }
    }

    extern (C++) class CompoundStatement : Statement
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0);
        }
    }

    extern (C++) final class CompoundDeclarationStatement : CompoundStatement
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0, 0);
        }
    }

    extern (C++) final class CompoundAsmStatement : CompoundStatement
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0);
        }
    }

    extern (C++) final class Catch : RootObject
    {
        final extern (D) this(A, B, C, D)(A a, B b, C c, D d) {}
    }
    extern (C++) abstract class Type : RootObject
    {
        ubyte ty;

        extern (C++) static __gshared Type tvoid;
        extern (C++) static __gshared Type tint8;
        extern (C++) static __gshared Type tuns8;
        extern (C++) static __gshared Type tint16;
        extern (C++) static __gshared Type tuns16;
        extern (C++) static __gshared Type tint32;
        extern (C++) static __gshared Type tuns32;
        extern (C++) static __gshared Type tint64;
        extern (C++) static __gshared Type tuns64;
        extern (C++) static __gshared Type tint128;
        extern (C++) static __gshared Type tuns128;
        extern (C++) static __gshared Type tfloat32;
        extern (C++) static __gshared Type tfloat64;
        extern (C++) static __gshared Type tfloat80;
        extern (C++) static __gshared Type timaginary32;
        extern (C++) static __gshared Type timaginary64;
        extern (C++) static __gshared Type timaginary80;
        extern (C++) static __gshared Type tcomplex32;
        extern (C++) static __gshared Type tcomplex64;
        extern (C++) static __gshared Type tcomplex80;
        extern (C++) static __gshared Type tbool;
        extern (C++) static __gshared Type tchar;
        extern (C++) static __gshared Type twchar;
        extern (C++) static __gshared Type tdchar;

        extern (C++) static __gshared Type terror;

        final extern (D) this(A)(A a) {}

        final Type addSTC(B)(B b)
        {
            return null;
        }
        Expression toExpression()
        {
            return null;
        }
        Type syntaxCopy()
        {
            return null;
        }
        final Type addMod(T)(T...)
        {
            return null;
        }
    }

    extern (C++) class TypeVector : Type
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0);
        }
    }

    extern (C++) abstract class TypeNext : Type
    {
        Type next;
        final extern (D) this(A, B)(A a, B b)
        {
            super(0);
        }
    }

    extern (C++) final class TypeSlice : TypeNext
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0);
        }
    }

    extern (C++) class TypeDelegate : TypeNext
    {
        final extern (D) this(A)(A a)
        {
            super(0, 0);
        }
    }

    extern (C++) final class TypePointer : TypeNext
    {
        final extern (D) this(A)(A a)
        {
            super(0 ,0);
        }
    }

    extern (C++) class TypeFunction : TypeNext
    {
        final extern (D) this(A, B, C, D, E)(A a, B b, C c, D d, E e)
        {
            super(0, 0);
        }
    }

    extern (C++) class TypeArray : TypeNext
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0, 0);
        }
    }

    extern (C++) final class TypeDArray : TypeArray
    {
        final extern (D) this(A)(A a)
        {
            super(0, 0);
        }
    }

    extern (C++) final class TypeAArray : TypeArray
    {
        Type index;

        final extern (D) this(A, B)(A a, B b)
        {
            super(0, 0);
        }
    }

    extern (C++) final class TypeSArray : TypeArray
    {
        Expression dim;

        final extern (D) this(A, B)(A a, B b)
        {
            super(0, 0);
        }
    }

    extern (C++) abstract class TypeQualified : Type
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0);
        }

        final void addIdent(Identifier id) {}
        final void addInst(TemplateInstance ti) {}
        final void addIndex(RootObject e) {}
    }

    extern (C++) final class TypeIdentifier : TypeQualified
    {
        Identifier ident;

        final extern (D) this(A, B)(A a, B b)
        {
            super(0, 0);
        }
    }

    extern (C++) final class TypeReturn : TypeQualified
    {
        final extern (D) this(A)(A a)
        {
            super(0, 0);
        }
    }

    extern (C++) final class TypeTypeof : TypeQualified
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0, 0);
        }
    }

    extern (C++) final class TypeInstance : TypeQualified
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0, 0);
        }
    }

    extern (C++) abstract class Expression : RootObject
    {
        TOK op;
        Loc loc;
        ubyte parens;

        final extern (D) this(A, B, C)(A a, B b, C c) {}

        Expression syntaxCopy()
        {
            return null;
        }
    }

    extern (C++) final class IntegerExp : Expression
    {
        extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0);
        }
    }

    extern (C++) final class NewAnonClassExp : Expression
    {
        final extern (D) this(A, B, C, D, E)(A a, B b, C c, D d, E e)
        {
            super(0, 0, 0);
        }
    }

    extern (C++) final class IsExp : Expression
    {
        final extern (D) this(A, B, C, D, E, F, G)(A a, B b, C c, D d, E e, F f, G g)
        {
            super(0, 0, 0);
        }
    }

    extern (C++) final class RealExp : Expression
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0);
        }
    }

    extern (C++) final class NullExp : Expression
    {
        final extern (D) this(A)(A a)
        {
            super(0, 0, 0);
        }
    }

    extern (C++) final class TypeidExp : Expression
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0, 0, 0);
        }
    }

    extern (C++) final class TraitsExp : Expression
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0);
        }
    }

    extern (C++) final class StringExp : Expression
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0, 0, 0);
        }

        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0);
        }

        final extern (D) this(A, B, C, D)(A a, B b, C c, D d)
        {
            super(0, 0, 0);
        }
    }

    extern (C++) final class NewExp : Expression
    {
        final extern (D) this(A, B, C, D, E)(A a, B b, C c, D d, E e)
        {
            super(0, 0, 0);
        }
    }

    extern (C++) final class AssocArrayLiteralExp : Expression
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0);
        }
    }

    extern (C++) final class ArrayLiteralExp : Expression
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0, 0, 0);
        }
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0);
        }
    }

    extern (C++) final class FuncExp : Expression
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0, 0, 0);
        }
    }

    extern (C++) final class IntervalExp : Expression
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0);
        }
    }

    extern (C++) final class TypeExp : Expression
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0, 0, 0);
        }
    }

    extern (C++) final class ScopeExp : Expression
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0, 0, 0);
        }
    }

    extern (C++) class IdentifierExp : Expression
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0, 0, 0);
        }
    }

    extern (C++) class UnaExp : Expression
    {
        Expression e1;

        final extern (D) this(A, B, C, D)(A a, B b, C c, D d)
        {
            super(0, 0, 0);
        }
    }

    extern (C++) class DefaultInitExp : Expression
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0);
        }
    }

    extern (C++) abstract class BinExp : Expression
    {
        final extern (D) this(A, B, C, D, E)(A a, B b, C c, D d, E e)
        {
            super(0, 0, 0);
        }
    }


    extern (C++) final class DollarExp : IdentifierExp
    {
        final extern (D) this(A)(A a)
        {
            super(0, 0);
        }
    }

    extern (C++) class ThisExp : Expression
    {
        final extern (D) this(A)(A a)
        {
            super(0, 0, 0);
        }
    }

    extern (C++) final class SuperExp : ThisExp
    {
        final extern (D) this(A)(A a)
        {
            super(0);
        }
    }

    extern (C++) final class AddrExp : UnaExp
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0, 0, 0, 0);
        }
    }

    extern (C++) final class PreExp : UnaExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0);
        }
    }

    extern (C++) final class PtrExp : UnaExp
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0, 0, 0, 0);
        }
    }

    extern (C++) final class NegExp : UnaExp
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0, 0, 0, 0);
        }
    }

    extern (C++) final class UAddExp : UnaExp
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0, 0, 0, 0);
        }
    }

    extern (C++) final class NotExp : UnaExp
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0, 0, 0, 0);
        }
    }

    extern (C++) final class ComExp : UnaExp
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0, 0, 0, 0);
        }
    }

    extern (C++) final class DeleteExp : UnaExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0);
        }
    }

    extern (C++) final class CastExp : UnaExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0);
        }
    }

    extern (C++) final class CallExp : UnaExp
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0, 0, 0, 0);
        }
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0);
        }
    }

    extern (C++) final class DotIdExp : UnaExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0);
        }
    }

    extern (C++) final class AssertExp : UnaExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0);
        }
    }

    extern (C++) final class CompileExp : UnaExp
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0, 0, 0, 0);
        }
    }

    extern (C++) final class ImportExp : UnaExp
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0, 0, 0, 0);
        }
    }

    extern (C++) final class DotTemplateInstanceExp : UnaExp
    {
        final extern (D) this(A, B, C, D)(A a, B b, C c, D d)
        {
            super(0, 0, 0, 0);
        }
    }

    extern (C++) final class ArrayExp : UnaExp
    {
        final extern (D) this(A, B)(A a, B b, Expression index = null)
        {
            super(0, 0, 0, 0);
        }
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0);
        }
    }

    extern (C++) final class FuncInitExp : DefaultInitExp
    {
        final extern (D) this(A)(A a)
        {
            super(0, 0, 0);
        }
    }

    extern (C++) final class PrettyFuncInitExp : DefaultInitExp
    {
        final extern (D) this(A)(A a)
        {
            super(0, 0, 0);
        }
    }

    extern (C++) final class FileInitExp : DefaultInitExp
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0, 0, 0);
        }
    }

    extern (C++) final class LineInitExp : DefaultInitExp
    {
        final extern (D) this(A)(A a)
        {
            super(0, 0, 0);
        }
    }

    extern (C++) final class ModuleInitExp : DefaultInitExp
    {
        final extern (D) this(A)(A a)
        {
            super(0, 0, 0);
        }
    }

    extern (C++) final class CommaExp : BinExp
    {
        final extern (D) this(A, B, C, D)(A a, B b, C c, D d)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class PostExp : BinExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class PowExp : BinExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class MulExp : BinExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class DivExp : BinExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class ModExp : BinExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class AddExp : BinExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class MinExp : BinExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class CatExp : BinExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class ShlExp : BinExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) class BinAssignExp : BinExp
    {
        final extern (D) this(A, B, C, D, E)(A a, B b, C c, D d, E e)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class ShrExp : BinExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class UshrExp : BinExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class EqualExp : BinExp
    {
        final extern (D) this(A, B, C, D)(A a, B b, C c, D d)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class InExp : BinExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class IdentityExp : BinExp
    {
        final extern (D) this(A, B, C, D)(A a, B b, C c, D d)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class CmpExp : BinExp
    {
        final extern (D) this(A, B, C, D)(A a, B b, C c, D d)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class AndExp : BinExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class XorExp : BinExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class OrExp : BinExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class AndAndExp : BinExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class OrOrExp : BinExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class CondExp : BinExp
    {
        final extern (D) this(A, B, C, D)(A a, B b, C c, D d)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class AssignExp : BinExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class AddAssignExp : BinAssignExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class MinAssignExp : BinAssignExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class MulAssignExp : BinAssignExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class DivAssignExp : BinAssignExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class ModAssignExp : BinAssignExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class PowAssignExp : BinAssignExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class AndAssignExp : BinAssignExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class OrAssignExp : BinAssignExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class XorAssignExp : BinAssignExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class ShlAssignExp : BinAssignExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class ShrAssignExp : BinAssignExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class UshrAssignExp : BinAssignExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) final class CatAssignExp : BinAssignExp
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0, 0, 0);
        }
    }

    extern (C++) class TemplateParameter
    {
        final extern (D) this(A, B)(A a, B b) {}
        void foo() {}
    }

    extern (C++) final class TemplateAliasParameter : TemplateParameter
    {
        final extern (D) this(A, B, C, D, E)(A a, B b, C c, D d, E e)
        {
            super(0, 0);
        }
    }

    extern (C++) class TemplateTypeParameter : TemplateParameter
    {
        final extern (D) this(A, B, C, D)(A a, B b, C c, D d)
        {
            super(0, 0);
        }
    }

    extern (C++) final class TemplateTupleParameter : TemplateParameter
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0, 0);
        }
    }

    extern (C++) final class TemplateValueParameter : TemplateParameter
    {
        final extern (D) this(A, B, C, D, E)(A a, B b, C c, D d, E e)
        {
            super(0, 0);
        }
    }

    extern (C++) final class TemplateThisParameter : TemplateTypeParameter
    {
        final extern (D) this(A, B, C, D)(A a, B b, C c, D d)
        {
            super(0, 0, 0, 0);
        }
    }

    extern (C++) abstract class Condition : RootObject
    {
        final extern (D) this(A)(A a) {}
    }

    extern (C++) final class StaticIfCondition : Condition
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0);
        }
    }

    extern (C++) class DVCondition : Condition
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0);
        }
    }

    extern (C++) final class DebugCondition : DVCondition
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0);
        }
    }

    extern (C++) final class VersionCondition : DVCondition
    {
        final extern (D) this(A, B, C)(A a, B b, C c)
        {
            super(0, 0, 0);
        }
    }

    extern (C++) class Initializer : RootObject
    {
        final extern (D) this(A)(A a) {}

        Expression toExpression(Type t = null)
        {
            return null;
        }
    }

    extern (C++) final class ExpInitializer : Initializer
    {
        final extern (D) this(A, B)(A a, B b)
        {
            super(0);
        }
    }

    extern (C++) final class StructInitializer : Initializer
    {
        final extern (D) this(A)(A a)
        {
            super(0);
        }

        void addInit(Identifier id, Initializer init) {}
    }

    extern (C++) final class ArrayInitializer : Initializer
    {
        final extern (D) this(A)(A a)
        {
            super(0);
        }

        void addInit(Expression e, Initializer i) {}
    }

    extern (C++) final class VoidInitializer : Initializer
    {
        final extern (D) this(A)(A a)
        {
            super(0);
        }
    }

    struct BaseClass
    {
        Type t;
    }

    struct ModuleDeclaration
    {
        Identifier id;
        Identifiers *packages;

        extern (D) this(A, B, C, D, E)(A a, B b, C c, D d, E e) {}

        extern (C++) const(char)* toChars()
        {
            return "";
        }
    }

    struct Prot
    {
        PROTKIND kind;
    }

    extern (C++) static const(char)* protectionToChars(PROTKIND kind)
    {
        return null;
    }

    extern (C++) static bool stcToBuffer(A, B)(A a, B b)
    {
        return false;
    }

    extern (C++) static bool linkageToChars(A)(A a)
    {
        return false;
    }

}


import tokens : Token;
import visitor;

/********************************************************/

enum
{
    STCstatic = 1,
    STCconst = 2,
    STCextern = 4,
    STCexternc = 8,
    STCvirtual = 16,
    STCcdecl = 32,
    STCabstract = 64,
    STCinline = 128,
    STCregister = 256,
};
alias uint STC;

enum visitor_str = `override void visit(Visitor v) { v.depth++; v.visit(this); v.depth--; }`;

class Ast
{
    abstract void visit(Visitor v);
};

class Module : Ast
{
    string file;
    Declaration[] decls;
    this(string file, Declaration[] decls) { this.file = file; this.decls = decls; }
    mixin(visitor_str);
}

class Declaration : Ast
{
};

class ImportDeclaration : Declaration
{
    string fn;
    this(string fn) { this.fn = fn; }
    mixin(visitor_str);
};

class FuncDeclaration : Declaration
{
    Type type;
    string id;
    Param[] params;
    Statement[] fbody;
    bool hasbody;
    STC stc;
    CallExpr[] initlist;
    string structid;
    string comment;
    this(Type type, string id, Param[] params, Statement[] fbody, STC stc, CallExpr[] initlist, bool hasbody, string comment)
    {
        this.type = type;
        this.id = id;
        this.params = params;
        this.fbody = fbody;
        this.stc = stc;
        this.initlist = initlist;
        this.hasbody = hasbody;
        this.comment = comment;
    }
    mixin(visitor_str);
    bool skip;
}

class FuncBodyDeclaration : Declaration
{
    Type type;
    string id;
    string id2;
    Param[] params;
    Statement[] fbody;
    bool hasbody;
    STC stc;
    CallExpr[] initlist;
    string comment;
    this(Type type, string id, string id2, Param[] params, Statement[] fbody, STC stc, CallExpr[] initlist, bool hasbody, string comment)
    {
        this.type = type;
        this.id = id;
        this.id2 = id2;
        this.params = params;
        this.fbody = fbody;
        this.stc = stc;
        this.initlist = initlist;
        this.hasbody = hasbody;
        this.comment = comment;
    }
    mixin(visitor_str);
}

class StaticMemberVarDeclaration : Declaration
{
    Type type;
    string id;
    string id2;
    Init xinit;
    string comment;
    string trailingcomment;
    this(Type type, string id, string id2, Init xinit, string comment, string trailingcomment)
    {
        this.type = type;
        this.id = id;
        this.id2 = id2;
        this.xinit = xinit;
        this.comment = comment;
        this.trailingcomment = trailingcomment;
    }
    mixin(visitor_str);
}

class VarDeclaration : Declaration
{
    Type type;
    string id;
    Init xinit;
    STC stc;
    string comment;
    string trailingcomment;
    this(Type type, string id, Init xinit, STC stc, string comment, string trailingcomment)
    {
        this.type = type;
        this.id = id;
        this.xinit = xinit;
        this.stc = stc;
        this.comment = comment;
        this.trailingcomment = trailingcomment;
    }
    mixin(visitor_str);
}

class MultiVarDeclaration : Declaration
{
    Type[] types;
    string[] ids;
    Init[] inits;
    STC stc;
    this(Type[] types, string[] ids, Init[] inits, STC stc) { this.types = types; this.ids = ids; this.inits = inits; this.stc = stc; }
    mixin(visitor_str);
}

class ConstructDeclaration : Declaration
{
    Type type;
    string id;
    Expression[] args;
    this(Type type, string id, Expression[] args) { this.type = type; this.id = id; this.args = args; }
    mixin(visitor_str);
}

class VersionDeclaration : Declaration
{
    Expression[] cond;
    Declaration[][] members;
    int[] realdecls;
    string file;
    size_t line;
    string comment;
    this(Expression[] cond, Declaration[][] members, string file, size_t line, string comment)
    {
        this.cond = cond;
        this.members = members;
        this.file = file;
        this.line = line;
        this.comment = comment;
    }
    mixin(visitor_str);
}

class TypedefDeclaration : Declaration
{
    Type t;
    string id;
    string comment;
    this(Type t, string id, string comment) { this.t = t; this.id = id; this.comment = comment; }
    mixin(visitor_str);
}

class MacroDeclaration : Declaration
{
    string id;
    string[] params;
    //Token[] toks;
    Expression e;
    string comment;
    this(string id, string[] params, Expression e, string comment) { this.id = id; this.params = params; this.e = e; this.comment = comment; }
    mixin(visitor_str);
}

class MacroUnDeclaration : Declaration
{
    string id;
    this(string id) { this.id = id; }
    mixin(visitor_str);
}

class StructDeclaration : Declaration
{
    string kind;
    string id;
    string superid;
    Declaration[] decls;
    string comment;
    this(string kind, string id, Declaration[] decls, string superid, string comment) { this.kind = kind; this.id = id; this.decls = decls; this.superid = superid; this.comment = comment; }
    mixin(visitor_str);
}

class AnonStructDeclaration : Declaration
{
    string kind;
    string id;
    Declaration[] decls;
    this(string kind, string id, Declaration[] decls) { this.kind = kind; this.id = id; this.decls = decls; }
    mixin(visitor_str);
}

class ExternCDeclaration : Declaration
{
    bool block;
    Declaration[] decls;
    string file;
    size_t line;
    string comment;
    this(Declaration[] decls, string file, size_t line, string comment) { this.decls = decls; block = true; this.file = file; this.line = line; this.comment = comment; }
    mixin(visitor_str);
}

class EnumMember
{
    string id;
    Expression val;
    string comment;
    this(string id, Expression val, string comment)
    {
        this.id = id;
        this.val = val;
        this.comment = comment;
    }
}

class EnumDeclaration : Declaration
{
    string id;
    EnumMember[] members;
    string file;
    size_t line;
    string comment;
    this (string id, EnumMember[] members, string file, size_t line, string comment)
    {
        this.id = id;
        this.members = members;
        this.file = file;
        this.line = line;
        this.comment = comment;
    }
    mixin(visitor_str);
}

class DummyDeclaration : Declaration
{
    string s;
    this(string s) { this.s = s; }
    mixin(visitor_str);
}

class ErrorDeclaration : Declaration
{
    Expression e;
    this(Expression e) { this.e = e; }
    mixin(visitor_str);
}

class ProtDeclaration : Declaration
{
    string id;
    this(string id) { this.id = id; }
    mixin(visitor_str);
}

/********************************************************/

class Expression : Ast
{
    bool hasParens;
};

class LitExpr : Expression
{
    string val;
    this(string val) { this.val = val; }
    mixin(visitor_str);
};

class IdentExpr : Expression
{
    string id;
    this(string id) { this.id = id; }
    mixin(visitor_str);
}

class DotIdExpr : Expression
{
    string op;
    Expression e;
    string id;
    this (string op, Expression e, string id) { this.op = op; this.e = e; this.id = id; }
    mixin(visitor_str);
}

class CallExpr : Expression
{
    Expression func;
    Expression[] args;
    this(Expression func, Expression[] args) { this.func = func; this.args = args; }
    mixin(visitor_str);
}

class BinaryExpr : Expression
{
    string op;
    Expression e1, e2;
    this(string op, Expression e1, Expression e2) { this.op = op; this.e1 = e1; this.e2 = e2; }
}

class CmpExpr : BinaryExpr
{
    this(string op, Expression e1, Expression e2) { super(op, e1, e2); }
    mixin(visitor_str);
}

class MulExpr : BinaryExpr
{
    this(string op, Expression e1, Expression e2) { super(op, e1, e2); }
    mixin(visitor_str);
}

class AddExpr : BinaryExpr
{
    this(string op, Expression e1, Expression e2) { super(op, e1, e2); }
    mixin(visitor_str);
}

class OrOrExpr : BinaryExpr
{
    this(Expression e1, Expression e2) { super("||", e1, e2); }
    mixin(visitor_str);
}

class AndAndExpr : BinaryExpr
{
    this(Expression e1, Expression e2) { super("&&", e1, e2); }
    mixin(visitor_str);
}

class OrExpr : BinaryExpr
{
    this(Expression e1, Expression e2) { super("|", e1, e2); }
    mixin(visitor_str);
}

class XorExpr : BinaryExpr
{
    this(Expression e1, Expression e2) { super("^", e1, e2); }
    mixin(visitor_str);
}

class AndExpr : BinaryExpr
{
    this(Expression e1, Expression e2) { super("&", e1, e2); }
    mixin(visitor_str);
}

class AssignExpr : BinaryExpr
{
    this(string op, Expression e1, Expression e2) { super(op, e1, e2); }
    mixin(visitor_str);
}

class DeclarationExpr : Expression
{
    Declaration d;
    this(Declaration d) { this.d = d; }
    mixin(visitor_str);
}

class UnaryExpr : Expression
{
    string op;
    Expression e;
    this(string op, Expression e) { this.op = op; this.e = e; }
}

class PostExpr : UnaryExpr
{
    this(string op, Expression e) { super(op, e); }
    mixin(visitor_str);
}

class PreExpr : UnaryExpr
{
    this(string op, Expression e) { super(op, e); }
    mixin(visitor_str);
}

class PtrExpr : UnaryExpr
{
    this(Expression e) { super("ptr", e); }
    mixin(visitor_str);
}

class AddrExpr : UnaryExpr
{
    this(Expression e) { super("&", e); }
    mixin(visitor_str);
}

class NegExpr : UnaryExpr
{
    this(Expression e) { super("-", e); }
    mixin(visitor_str);
}

class ComExpr : UnaryExpr
{
    this(Expression e) { super("~", e); }
    mixin(visitor_str);
}

class DeleteExpr : UnaryExpr
{
    this(Expression e) { super("delete", e); }
    mixin(visitor_str);
}

class NotExpr : UnaryExpr
{
    this(Expression e) { super("!", e); }
    mixin(visitor_str);
}

class StringofExpr : UnaryExpr
{
    this(Expression e) { super("#", e); }
    mixin(visitor_str);
}

class IndexExpr : Expression
{
    Expression e;
    Expression[] args;
    this(Expression e, Expression[] args) { this.e = e; this.args = args; }
    mixin(visitor_str);
}

class CondExpr : Expression
{
    Expression cond, e1, e2;
    this (Expression cond, Expression e1, Expression e2) { this.cond = cond; this.e1 = e1; this.e2 = e2; }
    mixin(visitor_str);
}

class CastExpr : Expression
{
    Type t;
    Expression e;
    this(Type t, Expression e) { this.t = t; this.e = e; }
    mixin(visitor_str);
}

class NewExpr : Expression
{
    Type t;
    Expression[] args;
    Expression dim;
    Expression placement;
    this(Type t, Expression[] args, Expression dim, Expression placement) { this.t = t; this.args = args; this.dim = dim; this.placement = placement; }
    mixin(visitor_str);
}

class OuterScopeExpr : UnaryExpr
{
    this(Expression e) { super("::", e); }
    mixin(visitor_str);
}

class CommaExpr : BinaryExpr
{
    this(Expression e1, Expression e2) { super(",", e1, e2); }
    mixin(visitor_str);
}

class SizeofExpr : Expression
{
    Type t;
    Expression e;
    this(Type t) { this.t = t; }
    this(Expression e) { this.e = e; }
    mixin(visitor_str);
}

/********************************************************/

class Init : Ast
{
}

class ExprInit : Init
{
    Expression e;
    this (Expression e) { this.e = e; }
    mixin(visitor_str);
}

class ArrayInit : Init
{
    Init[] xinit;
    this (Init[] xinit) { this.xinit = xinit; }
    mixin(visitor_str);
}

/********************************************************/

class Type : Ast
{
    string id;
    bool isConst;
    abstract string mangle();
};

class BasicType : Type
{
    this(string id) { this.id = id; }
    mixin(visitor_str);
    override string mangle() { return id; }
}

class ClassType : Type
{
    this(string id) { this.id = id; }
    mixin(visitor_str);
    override string mangle() { return id; }
}

class EnumType : Type
{
    this(string id) { this.id = id; }
    mixin(visitor_str);
    override string mangle() { return id; }
}

class PointerType : Type
{
    Type next;
    this(Type next) { this.next = next; }
    mixin(visitor_str);
    override string mangle() { return next.mangle() ~ "*"; }
}

class RefType : Type
{
    Type next;
    this(Type next) { this.next = next; }
    mixin(visitor_str);
    override string mangle() { return next.mangle() ~ "&"; }
}

class ArrayType : Type
{
    Type next;
    Expression dim;
    this(Type next, Expression dim) { this.next = next; this.dim = dim; }
    mixin(visitor_str);
    override string mangle() { return next.mangle() ~ "[]"; }
}

class FunctionType : Type
{
    Type next;
    Param[] params;
    bool cdecl;
    this(Type next, Param[] params) { this.next = next; this.params = params; }
    mixin(visitor_str);
    override string mangle() { return next.mangle() ~ "()"; }
}

class TemplateType : Type
{
    Type next;
    Type param;
    this(Type next, Type param) { this.next = next; this.param = param; }
    mixin(visitor_str);
    override string mangle() { return next.mangle() ~ "!"; }
}

/********************************************************/

class Param : Ast
{
    Type t;
    string id;
    Expression def;
    this(Type t, string id, Expression def) { this.t = t; this.id = id; this.def = def; }
    mixin(visitor_str);
};

/********************************************************/

class Statement : Ast
{
};

class CommentStatement : Statement
{
    string comment;
    this(string comment) { this.comment = comment; }
    mixin(visitor_str);
};

class CompoundStatement : Statement
{
    Statement[] s;
    this(Statement[] s) { this.s = s; }
    mixin(visitor_str);
};

class ReturnStatement : Statement
{
    Expression e;
    string trailingcomment;
    this(Expression e, string trailingcomment) { this.e = e; this.trailingcomment = trailingcomment; }
    mixin(visitor_str);
}

class ExpressionStatement : Statement
{
    Expression e;
    string trailingcomment;
    this(Expression e, string trailingcomment) { this.e = e; this.trailingcomment = trailingcomment; }
    mixin(visitor_str);
}

class VersionStatement : Statement
{
    Expression[] cond;
    Statement[][] members;
    this(Expression[] cond, Statement[][] members) { this.cond = cond; this.members = members; }
    mixin(visitor_str);
}

class IfStatement : Statement
{
    Expression e;
    Statement sbody;
    Statement selse;
    string trailingcomment;
    string elsecomment;
    this(Expression e, Statement sbody, Statement selse, string trailingcomment, string elsecomment) { this.e = e; this.sbody = sbody; this.selse = selse; this.trailingcomment = trailingcomment; this.elsecomment = elsecomment; }
    mixin(visitor_str);
}

class ForStatement : Statement
{
    Expression xinit, cond, inc;
    Statement sbody;
    string trailingcomment;
    this(Expression xinit, Expression cond, Expression inc, Statement sbody, string trailingcomment) { this.xinit = xinit; this.cond = cond; this.inc = inc; this.sbody = sbody; this.trailingcomment = trailingcomment; }
    mixin(visitor_str);
}

class SwitchStatement : Statement
{
    Expression e;
    Statement[] sbody;
    bool hasdefault;
    this(Expression e, Statement[] sbody) { this.e = e; this.sbody = sbody; }
    mixin(visitor_str);
}

class CaseStatement : Statement
{
    Expression e;
    this(Expression e) { this.e = e; }
    mixin(visitor_str);
}

class BreakStatement : Statement
{
    this() {}
    mixin(visitor_str);
}

class ContinueStatement : Statement
{
    this() {}
    mixin(visitor_str);
}

class DefaultStatement : Statement
{
    this() {}
    mixin(visitor_str);
}

class WhileStatement : Statement
{
    Expression e;
    Statement sbody;
    string trailingcomment;
    this(Expression e, Statement sbody, string trailingcomment) { this.e = e; this.sbody = sbody; this.trailingcomment = trailingcomment; }
    mixin(visitor_str);
}

class DoWhileStatement : Statement
{
    Expression e;
    Statement sbody;
    string trailingcomment;
    this(Statement sbody, Expression e, string trailingcomment) { this.e = e; this.sbody = sbody; this.trailingcomment = trailingcomment; }
    mixin(visitor_str);
}

class GotoStatement : Statement
{
    string id;
    this(string id) { this.id = id; }
    mixin(visitor_str);
}

class LabelStatement : Statement
{
    string id;
    this(string id) { this.id = id; }
    mixin(visitor_str);
}

bool typeMatch(Type t1, Type t2)
{
    assert(t1);
    assert(t2);
    if (t1 == t2)
        return true;
    if (typeid(t1) != typeid(t2))
        return false;
    if (t1.id != t2.id)
        return false;
    if (cast(PointerType)t1)
        return typeMatch((cast(PointerType)t1).next, (cast(PointerType)t2).next);
    if (cast(RefType)t1)
        return typeMatch((cast(RefType)t1).next, (cast(RefType)t2).next);
    if (cast(ArrayType)t1)
        return typeMatch((cast(ArrayType)t1).next, (cast(ArrayType)t2).next);
    if (cast(FunctionType)t1)
    {
        auto tf1 = cast(FunctionType)t1;
        auto tf2 = cast(FunctionType)t2;
        auto m = typeMatch(tf1.next, tf2.next);
        if (!m) return false;
        assert(tf1.cdecl == tf2.cdecl);
        m = tf1.params.length == tf2.params.length;
        if (!m) return false;
        foreach(i; 0..tf1.params.length)
        {
            m = tf1.params[i].t is tf2.params[i].t;
            if (!m && (tf1.params[i].id == "..." || tf2.params[i].id == "..."))
                return tf1.params[i].id == "..." && tf2.params[i].id == "...";
            if (!m)
                m = typeMatch(tf1.params[i].t, tf2.params[i].t);
            if (!m) return false;
        }
        return true;
    }
    assert(cast(ClassType)t1 || cast(BasicType)t1 || cast(EnumType)t1, typeid(t1).toString());
    return true;
}

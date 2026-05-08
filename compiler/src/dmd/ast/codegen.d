/**
 * Defines AST nodes for the code generation stage.
 *
 * Documentation:  https://dlang.org/phobos/dmd_ast/codegen.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/ast/codegen.d
 */
module dmd.ast.codegen;


struct ASTCodegen
{
    public import dmd.ast.aggregate;
    public import dmd.ast.aliasthis;
    public import dmd.ast.attrib;
    public import dmd.ast.cond;
    public import dmd.ast.dclass;
    public import dmd.ast.declaration;
    public import dmd.ast.denum;
    public import dmd.ast.dimport;
    public import dmd.ast.dmodule;
    public import dmd.ast.dstruct;
    public import dmd.ast.dsymbol;
    public import dmd.ast.dtemplate;
    public import dmd.ast.dversion;
    public import dmd.ast.expression;
    public import dmd.ast.func;
    public import dmd.ast.init;
    public import dmd.ast.mtype;
    public import dmd.ast.nspace;
    public import dmd.ast.statement;
    public import dmd.ast.staticassert;
    public import dmd.ast.init : Designator;

    public import dmd.arraytypes;
    public import dmd.initsem;
    public import dmd.hdrgen;
    public import dmd.typesem;

    alias addSTC                    = dmd.typesem.addSTC;
    alias initializerToExpression   = dmd.initsem.initializerToExpression;
    alias typeToExpression          = dmd.ast.mtype.typeToExpression;
    alias UserAttributeDeclaration  = dmd.ast.attrib.UserAttributeDeclaration;
    alias Ensure                    = dmd.ast.func.Ensure; // workaround for bug in older DMD frontends
    alias ErrorExp                  = dmd.ast.expression.ErrorExp;
    alias ArgumentLabel             = dmd.ast.expression.ArgumentLabel;

    alias MODFlags                  = dmd.ast.mtype.MODFlags;
    alias Type                      = dmd.ast.mtype.Type;
    alias Parameter                 = dmd.ast.mtype.Parameter;
    alias Tarray                    = dmd.ast.mtype.Tarray;
    alias Taarray                   = dmd.ast.mtype.Taarray;
    alias Tbool                     = dmd.ast.mtype.Tbool;
    alias Tchar                     = dmd.ast.mtype.Tchar;
    alias Tdchar                    = dmd.ast.mtype.Tdchar;
    alias Tdelegate                 = dmd.ast.mtype.Tdelegate;
    alias Tenum                     = dmd.ast.mtype.Tenum;
    alias Terror                    = dmd.ast.mtype.Terror;
    alias Tfloat32                  = dmd.ast.mtype.Tfloat32;
    alias Tfloat64                  = dmd.ast.mtype.Tfloat64;
    alias Tfloat80                  = dmd.ast.mtype.Tfloat80;
    alias Tfunction                 = dmd.ast.mtype.Tfunction;
    alias Tpointer                  = dmd.ast.mtype.Tpointer;
    alias Treference                = dmd.ast.mtype.Treference;
    alias Tident                    = dmd.ast.mtype.Tident;
    alias Tint8                     = dmd.ast.mtype.Tint8;
    alias Tint16                    = dmd.ast.mtype.Tint16;
    alias Tint32                    = dmd.ast.mtype.Tint32;
    alias Tint64                    = dmd.ast.mtype.Tint64;
    alias Tsarray                   = dmd.ast.mtype.Tsarray;
    alias Tstruct                   = dmd.ast.mtype.Tstruct;
    alias Tuns8                     = dmd.ast.mtype.Tuns8;
    alias Tuns16                    = dmd.ast.mtype.Tuns16;
    alias Tuns32                    = dmd.ast.mtype.Tuns32;
    alias Tuns64                    = dmd.ast.mtype.Tuns64;
    alias Tvoid                     = dmd.ast.mtype.Tvoid;
    alias Twchar                    = dmd.ast.mtype.Twchar;
    alias Tnoreturn                 = dmd.ast.mtype.Tnoreturn;

    alias Timaginary32              = dmd.ast.mtype.Timaginary32;
    alias Timaginary64              = dmd.ast.mtype.Timaginary64;
    alias Timaginary80              = dmd.ast.mtype.Timaginary80;
    alias Tcomplex32                = dmd.ast.mtype.Tcomplex32;
    alias Tcomplex64                = dmd.ast.mtype.Tcomplex64;
    alias Tcomplex80                = dmd.ast.mtype.Tcomplex80;

    alias ModToStc                  = dmd.ast.mtype.ModToStc;
    alias ParameterList             = dmd.ast.mtype.ParameterList;
    alias VarArg                    = dmd.ast.mtype.VarArg;
    alias STC                       = dmd.ast.declaration.STC;
    alias Dsymbol                   = dmd.ast.dsymbol.Dsymbol;
    alias Dsymbols                  = dmd.ast.dsymbol.Dsymbols;
    alias Visibility                = dmd.ast.dsymbol.Visibility;

    alias stcToBuffer               = dmd.hdrgen.stcToBuffer;
    alias linkageToChars            = dmd.hdrgen.linkageToChars;
    alias visibilityToChars         = dmd.hdrgen.visibilityToChars;

    alias isType                    = dmd.ast.dtemplate.isType;
    alias isExpression              = dmd.ast.dtemplate.isExpression;
    alias isTuple                   = dmd.ast.dtemplate.isTuple;

    alias SearchOpt                 = dmd.ast.dsymbol.SearchOpt;
    alias PASS                      = dmd.ast.dsymbol.PASS;
}

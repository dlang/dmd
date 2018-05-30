module dmd.astcodegen;

/**
 * Documentation:  https://dlang.org/phobos/dmd_astcodegen.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/astcodegen.d
 */

struct ASTCodegen
{
    public import dmd.aggregate;
    public import dmd.aliasthis;
    public import dmd.arraytypes;
    public import dmd.attrib;
    public import dmd.cond;
    public import dmd.dclass;
    public import dmd.declaration;
    public import dmd.denum;
    public import dmd.dimport;
    public import dmd.dmodule;
    public import dmd.dstruct;
    public import dmd.dsymbol;
    public import dmd.dtemplate;
    public import dmd.dversion;
    public import dmd.expression;
    public import dmd.func;
    public import dmd.hdrgen;
    public import dmd.init;
    public import dmd.initsem;
    public import dmd.mtype;
    public import dmd.nspace;
    public import dmd.statement;
    public import dmd.staticassert;
    public import dmd.typesem;
    public import dmd.ctfeexpr;


    alias initializerToExpression   = dmd.initsem.initializerToExpression;
    alias typeToExpression          = dmd.typesem.typeToExpression;
    alias UserAttributeDeclaration  = dmd.attrib.UserAttributeDeclaration;
    alias Ensure                    = dmd.func.Ensure; // workaround for bug in older DMD frontends

    alias MODFlags                  = dmd.mtype.MODFlags;
    alias Type                      = dmd.mtype.Type;
    alias Tident                    = dmd.mtype.Tident;
    alias Tfunction                 = dmd.mtype.Tfunction;
    alias Parameter                 = dmd.mtype.Parameter;
    alias Taarray                   = dmd.mtype.Taarray;
    alias Tsarray                   = dmd.mtype.Tsarray;
    alias Terror                    = dmd.mtype.Terror;

    alias STC                       = dmd.declaration.STC;
    alias Dsymbol                   = dmd.dsymbol.Dsymbol;
    alias Dsymbols                  = dmd.dsymbol.Dsymbols;
    alias Prot                      = dmd.dsymbol.Prot;

    alias stcToBuffer               = dmd.hdrgen.stcToBuffer;
    alias linkageToChars            = dmd.hdrgen.linkageToChars;
    alias protectionToChars         = dmd.hdrgen.protectionToChars;

    alias isType                    = dmd.dtemplate.isType;
    alias isExpression              = dmd.dtemplate.isExpression;
    alias isTuple                   = dmd.dtemplate.isTuple;

}

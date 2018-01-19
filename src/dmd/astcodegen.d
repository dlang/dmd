module dmd.astcodegen;

/**
 * Documentation:  https://dlang.org/phobos/dmd_astcodegen.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/astcodegen.d
 */

struct ASTCodegen
{
    import dmd.aggregate;
    import dmd.aliasthis;
    import dmd.arraytypes;
    import dmd.attrib;
    import dmd.cond;
    import dmd.dclass;
    import dmd.declaration;
    import dmd.denum;
    import dmd.dimport;
    import dmd.dmodule;
    import dmd.dstruct;
    import dmd.dsymbol;
    import dmd.dtemplate;
    import dmd.dversion;
    import dmd.expression;
    import dmd.func;
    import dmd.hdrgen;
    import dmd.init;
    import dmd.initsem;
    import dmd.mtype;
    import dmd.nspace;
    import dmd.statement;
    import dmd.staticassert;
    import dmd.typesem;
    import dmd.ctfeexpr;

    alias initializerToExpression   = dmd.initsem.initializerToExpression;
    alias typeToExpression          = dmd.typesem.typeToExpression;
    alias UserAttributeDeclaration  = dmd.attrib.UserAttributeDeclaration;

    alias MODFlags                  = dmd.mtype.MODFlags;
    alias Type                      = dmd.mtype.Type;
    alias Parameter                 = dmd.mtype.Parameter;

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

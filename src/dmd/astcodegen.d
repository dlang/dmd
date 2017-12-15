module dmd.astcodegen;

// Online documentation: https://dlang.org/phobos/dmd_astcodegen.html

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

    alias MODconst                  = dmd.mtype.MODconst;
    alias MODimmutable              = dmd.mtype.MODimmutable;
    alias MODshared                 = dmd.mtype.MODshared;
    alias MODwild                   = dmd.mtype.MODwild;
    alias Type                      = dmd.mtype.Type;
    alias Tident                    = dmd.mtype.Tident;
    alias Tfunction                 = dmd.mtype.Tfunction;
    alias Parameter                 = dmd.mtype.Parameter;
    alias Taarray                   = dmd.mtype.Taarray;
    alias Tsarray                   = dmd.mtype.Tsarray;
    alias Terror                    = dmd.mtype.Terror;

    alias STCconst                  = dmd.declaration.STCconst;
    alias STCimmutable              = dmd.declaration.STCimmutable;
    alias STCshared                 = dmd.declaration.STCshared;
    alias STCwild                   = dmd.declaration.STCwild;
    alias STCin                     = dmd.declaration.STCin;
    alias STCout                    = dmd.declaration.STCout;
    alias STCref                    = dmd.declaration.STCref;
    alias STClazy                   = dmd.declaration.STClazy;
    alias STCscope                  = dmd.declaration.STCscope;
    alias STCfinal                  = dmd.declaration.STCfinal;
    alias STCauto                   = dmd.declaration.STCauto;
    alias STCreturn                 = dmd.declaration.STCreturn;
    alias STCmanifest               = dmd.declaration.STCmanifest;
    alias STCgshared                = dmd.declaration.STCgshared;
    alias STCtls                    = dmd.declaration.STCtls;
    alias STCsafe                   = dmd.declaration.STCsafe;
    alias STCsystem                 = dmd.declaration.STCsystem;
    alias STCtrusted                = dmd.declaration.STCtrusted;
    alias STCnothrow                = dmd.declaration.STCnothrow;
    alias STCpure                   = dmd.declaration.STCpure;
    alias STCproperty               = dmd.declaration.STCproperty;
    alias STCnogc                   = dmd.declaration.STCnogc;
    alias STCdisable                = dmd.declaration.STCdisable;
    alias STCundefined              = dmd.declaration.STCundefined;
    alias STC_TYPECTOR              = dmd.declaration.STC_TYPECTOR;
    alias STCoverride               = dmd.declaration.STCoverride;
    alias STCabstract               = dmd.declaration.STCabstract;
    alias STCsynchronized           = dmd.declaration.STCsynchronized;
    alias STCdeprecated             = dmd.declaration.STCdeprecated;
    alias STCstatic                 = dmd.declaration.STCstatic;
    alias STCextern                 = dmd.declaration.STCextern;
    alias STCfuture                 = dmd.declaration.STCfuture;
    alias STCalias                  = dmd.declaration.STCalias;
    alias STClocal                  = dmd.declaration.STClocal;

    alias Dsymbol                   = dmd.dsymbol.Dsymbol;
    alias Dsymbols                  = dmd.dsymbol.Dsymbols;
    alias PROTprivate               = dmd.dsymbol.PROTprivate;
    alias PROTpackage               = dmd.dsymbol.PROTpackage;
    alias PROTprotected             = dmd.dsymbol.PROTprotected;
    alias PROTpublic                = dmd.dsymbol.PROTpublic;
    alias PROTexport                = dmd.dsymbol.PROTexport;
    alias PROTundefined             = dmd.dsymbol.PROTundefined;
    alias Prot                      = dmd.dsymbol.Prot;

    alias stcToBuffer               = dmd.hdrgen.stcToBuffer;
    alias linkageToChars            = dmd.hdrgen.linkageToChars;
    alias protectionToChars         = dmd.hdrgen.protectionToChars;

    alias isType                    = dmd.dtemplate.isType;
    alias isExpression              = dmd.dtemplate.isExpression;
    alias isTuple                   = dmd.dtemplate.isTuple;
}

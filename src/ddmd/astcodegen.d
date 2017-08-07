module ddmd.astcodegen;

struct ASTCodegen
{
    import ddmd.aggregate;
    import ddmd.aliasthis;
    import ddmd.arraytypes;
    import ddmd.attrib;
    import ddmd.cond;
    import ddmd.dclass;
    import ddmd.declaration;
    import ddmd.denum;
    import ddmd.dimport;
    import ddmd.dmodule;
    import ddmd.dstruct;
    import ddmd.dsymbol;
    import ddmd.dtemplate;
    import ddmd.dversion;
    import ddmd.expression;
    import ddmd.func;
    import ddmd.hdrgen;
    import ddmd.init;
    import ddmd.initsem;
    import ddmd.mtype;
    import ddmd.nspace;
    import ddmd.statement;
    import ddmd.staticassert;
    import ddmd.typesem;

    alias initializerToExpression   = ddmd.initsem.initializerToExpression;
    alias typeToExpression          = ddmd.typesem.typeToExpression;
    alias UserAttributeDeclaration  = ddmd.attrib.UserAttributeDeclaration;

    alias MODconst                  = ddmd.mtype.MODconst;
    alias MODimmutable              = ddmd.mtype.MODimmutable;
    alias MODshared                 = ddmd.mtype.MODshared;
    alias MODwild                   = ddmd.mtype.MODwild;
    alias Type                      = ddmd.mtype.Type;
    alias Tident                    = ddmd.mtype.Tident;
    alias Tfunction                 = ddmd.mtype.Tfunction;
    alias Parameter                 = ddmd.mtype.Parameter;
    alias Taarray                   = ddmd.mtype.Taarray;
    alias Tsarray                   = ddmd.mtype.Tsarray;

    alias STCconst                  = ddmd.declaration.STCconst;
    alias STCimmutable              = ddmd.declaration.STCimmutable;
    alias STCshared                 = ddmd.declaration.STCshared;
    alias STCwild                   = ddmd.declaration.STCwild;
    alias STCin                     = ddmd.declaration.STCin;
    alias STCout                    = ddmd.declaration.STCout;
    alias STCref                    = ddmd.declaration.STCref;
    alias STClazy                   = ddmd.declaration.STClazy;
    alias STCscope                  = ddmd.declaration.STCscope;
    alias STCfinal                  = ddmd.declaration.STCfinal;
    alias STCauto                   = ddmd.declaration.STCauto;
    alias STCreturn                 = ddmd.declaration.STCreturn;
    alias STCmanifest               = ddmd.declaration.STCmanifest;
    alias STCgshared                = ddmd.declaration.STCgshared;
    alias STCtls                    = ddmd.declaration.STCtls;
    alias STCsafe                   = ddmd.declaration.STCsafe;
    alias STCsystem                 = ddmd.declaration.STCsystem;
    alias STCtrusted                = ddmd.declaration.STCtrusted;
    alias STCnothrow                = ddmd.declaration.STCnothrow;
    alias STCpure                   = ddmd.declaration.STCpure;
    alias STCproperty               = ddmd.declaration.STCproperty;
    alias STCnogc                   = ddmd.declaration.STCnogc;
    alias STCdisable                = ddmd.declaration.STCdisable;
    alias STCundefined              = ddmd.declaration.STCundefined;
    alias STC_TYPECTOR              = ddmd.declaration.STC_TYPECTOR;
    alias STCoverride               = ddmd.declaration.STCoverride;
    alias STCabstract               = ddmd.declaration.STCabstract;
    alias STCsynchronized           = ddmd.declaration.STCsynchronized;
    alias STCdeprecated             = ddmd.declaration.STCdeprecated;
    alias STCstatic                 = ddmd.declaration.STCstatic;
    alias STCextern                 = ddmd.declaration.STCextern;
    alias STCfuture                 = ddmd.declaration.STCfuture;
    alias STCalias                  = ddmd.declaration.STCalias;
    alias STClocal                  = ddmd.declaration.STClocal;

    alias Dsymbol                   = ddmd.dsymbol.Dsymbol;
    alias Dsymbols                  = ddmd.dsymbol.Dsymbols;
    alias PROTprivate               = ddmd.dsymbol.PROTprivate;
    alias PROTpackage               = ddmd.dsymbol.PROTpackage;
    alias PROTprotected             = ddmd.dsymbol.PROTprotected;
    alias PROTpublic                = ddmd.dsymbol.PROTpublic;
    alias PROTexport                = ddmd.dsymbol.PROTexport;
    alias PROTundefined             = ddmd.dsymbol.PROTundefined;
    alias Prot                      = ddmd.dsymbol.Prot;

    alias stcToBuffer               = ddmd.hdrgen.stcToBuffer;
    alias linkageToChars            = ddmd.hdrgen.linkageToChars;
    alias protectionToChars         = ddmd.hdrgen.protectionToChars;
}

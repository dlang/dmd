// https://issues.dlang.org/show_bug.cgi?id=11970

// structs with either an `opAssign` or postblit have side
// effects

struct SA
{
    void opAssign(SA s) { }
}

struct SP
{
    this(this) { }
}

struct SAP
{
    this(this) { }
    void opAssign(SAP s) { }
}

void main()
{
    SA sa;
    sa = sa;

    SP sp;
    sp = sp;

    SAP sap;
    sap = sap;

    SA[2] sa2;
    sa2 = sa2;

    SP[2] sp2;
    sp2 = sp2;

    SAP[2] sap2;
    sap2 = sap2;

    SA[] san;
    san = san;

    SP[] spn;
    spn = spn;

    SAP[] sapn;
    sapn = sapn;
}

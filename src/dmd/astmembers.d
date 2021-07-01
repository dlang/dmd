// This file contains mixin templates that define the parse time fields and methods of AST nodes.
module dmd.astmembers;

mixin template parseTimePropertiesAliasThis()
{
    Identifier ident;

    extern (D) this(const ref Loc loc, Identifier ident)
    {
        super(loc, null);    // it's anonymous (no identifier)
        this.ident = ident;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

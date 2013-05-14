/*
TEST_OUTPUT:
---
fail_compilation/ice10076.d(21): Error: template instance getMembersAndAttributesWhere!() template 'getMembersAndAttributesWhere' is not defined
fail_compilation/ice10076.d(26): Error: template instance ice10076.getValidaterAttrs!(string) error instantiating
fail_compilation/ice10076.d(16):        instantiated from here: validate!(string)
fail_compilation/ice10076.d(26): Error: forward reference to 'getMembersAndAttributesWhere!().Elements'
fail_compilation/ice10076.d(26): Error: forward reference to 'getMembersAndAttributesWhere!().Elements'
fail_compilation/ice10076.d(16): Error: template instance ice10076.validate!(string) error instantiating
---
*/

void main()
{
    string s;
    validate(s);
}

template getValidaterAttrs(T)
{
    alias getMembersAndAttributesWhere!().Elements getValidaterAttrs;
}

void validate(T)(T)
{
    alias getValidaterAttrs!T memberAttrs;
    auto x = memberAttrs.length;
}

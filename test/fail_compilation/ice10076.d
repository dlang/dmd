/*
TEST_OUTPUT:
---
fail_compilation/ice10076.d(20): Error: template instance getMembersAndAttributesWhere!() template 'getMembersAndAttributesWhere' is not defined
fail_compilation/ice10076.d(25): Error: template instance ice10076.getValidaterAttrs!string error instantiating
fail_compilation/ice10076.d(15):        instantiated from here: validate!string
fail_compilation/ice10076.d(25): Error: forward reference to 'getMembersAndAttributesWhere!().Elements'
fail_compilation/ice10076.d(25): Error: forward reference to 'getMembersAndAttributesWhere!().Elements'
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

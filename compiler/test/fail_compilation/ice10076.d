/*
TEST_OUTPUT:
---
fail_compilation/ice10076.d(24): Error: template instance `getMembersAndAttributesWhere!()` template `getMembersAndAttributesWhere` is not defined
    alias getMembersAndAttributesWhere!().Elements getValidaterAttrs;
          ^
fail_compilation/ice10076.d(29): Error: template instance `ice10076.getValidaterAttrs!string` error instantiating
    alias getValidaterAttrs!T memberAttrs;
          ^
fail_compilation/ice10076.d(19):        instantiated from here: `validate!string`
    validate(s);
            ^
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

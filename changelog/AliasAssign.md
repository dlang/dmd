# Add Alias Assignment

This adds the ability for an alias declaration inside a template to be
assigned a new value. For example, the recursive template:

---
template staticMap(alias F, T...)
{
    static if (T.length == 0)
	alias staticMap = AliasSym!();
    else
        alias staticMap = AliasSym!(F!(T[0]), staticMap!(T[0 .. T.length]));
}
---

can now be reworked into an iterative template:

---
template staticMap(alias F, T...)
{
    alias A = AliasSeq!();
    static foreach (t; T)
	A = AliasSeq!(A, F!t); // alias assignment here
    alias staticMap = A;
}
---

Using the iterative approach will eliminate the combinatorial explosion of recursive
template instantiations, eliminating the associated high memory and runtime costs,
as well as eliminating the issues with limits on the nesting depth of templates.
It will eliminate the obtuse error messages generated when deep in recursion.

The grammar:

---
AliasAssign:
    Identifier = Type;
---

is added to the expansion of DeclDef. The Identifier must resolve to a lexically
preceding AliasDeclaration:

---
alias Identifier = Type;
---

where the Identifier's match, and both are members of the same TemplateDeclaration.
Upon semantic processing, when the AliasAssign is encountered the Type in the
AliasAssign replaces the Type from the corresponding AliasDeclaration or any previous matching
AliasAssign.

The AliasAssign grammar was previously rejected by the parser, so adding it
should not break existing code.

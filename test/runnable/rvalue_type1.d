// REQUIRED_ARGS: -preview=rvaluetype

void main()
{
static if (is(TypeInfo_Rvalue))
{
    assert(typeid(@rvalue(int)) != typeid(int));
    assert(typeid(@rvalue(int)).toString() == "@rvalue(int)");
    assert(typeid(@rvalue(const(int))).toString() == "@rvalue(const(int))");
    assert(typeid(@rvalue(const(shared(int)))).toString() == "@rvalue(shared(const(int)))");
    assert(typeid(@rvalue(immutable(int))).toString() == "@rvalue(immutable(int))");
    assert(is(typeof(typeid(@rvalue(int))) == TypeInfo_Rvalue));
}
}

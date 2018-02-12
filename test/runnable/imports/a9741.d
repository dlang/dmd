module imports.a9741;

template ShowAttributes(alias X)
{
    pragma(msg, X.stringof);
    pragma(msg, __traits(getAttributes, X));
}

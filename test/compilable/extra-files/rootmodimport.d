module rootmodimport;

static if (__traits(isRootModule))
{
    pragma(msg, "isRootModule 1");
}
else
{
    pragma(msg, "isRootModule 0");
}

module imports.test75;

void foo(alias pred)()
{
    pred();
}

void tfoo(alias tmpl)()
{
    enum res = tmpl!();
}

void Tfoo(alias Type)()
{
    Type t;
}

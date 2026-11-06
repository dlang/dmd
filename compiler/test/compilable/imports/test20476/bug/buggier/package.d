module bug.buggier;

void fn() {}

void self()
{
    // https://issues.dlang.org/show_bug.cgi?id=24632
    // Fully qualifying a package.d module's own name from inside itself
    // used to require `static import bug.buggier;` -- it shouldn't.
    alias thisModule = bug.buggier;
    bug.buggier.fn();
}

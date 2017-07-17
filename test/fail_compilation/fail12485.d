void dorecursive()
{
    recursive!"ratherLongSymbolNameToHitTheMaximumSymbolLengthEarlierThanTheTemplateRecursionLimit_";
}

void recursive(string name)()
{
    struct S {} // define type to kick off mangler
    recursive!(name ~ name);
}


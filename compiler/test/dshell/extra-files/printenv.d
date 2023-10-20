import std.array, std.stdio, std.process, std.algorithm;

auto filterEnv(T)(T env)
{
    // Windows shell output is not in UTF-8
    // https://github.com/dlang/phobos/pull/7342#issuecomment-571154708
    return env.filter!(e => !e.key.among("BUILD_SOURCEVERSIONAUTHOR"));
}

void main()
{
    foreach (varPair; environment.toAA().byKeyValue.filterEnv.array.sort!"a.key < b.key")
    {
        if (varPair.key != "_")
        {
            writeln(varPair.key, "=", varPair.value);
        }
    }
}

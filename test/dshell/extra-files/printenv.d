import std.array, std.stdio, std.process, std.algorithm;
void main()
{
    foreach (varPair; environment.toAA().byKeyValue.array.sort!"a.key < b.key")
    {
        if (varPair.key != "_")
        {
            writeln(varPair.key, "=", varPair.value);
        }
    }
}

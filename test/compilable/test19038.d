module test19038;

void test()
{
    string mutableStr = "x";
    const string constStr = mutableStr;

    if ([[constStr]] == [[mutableStr]])
    {
    }

    int mutableInt = 5;
    const int constInt = mutableInt;

    if ([[constInt]] == [[mutableInt]])
    {
    }
}

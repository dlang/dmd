// REQUIRED_ARGS: -O

void test(bool cond, string msg)
{
    string text = cond ? "empty" : (msg ~ " world");
}

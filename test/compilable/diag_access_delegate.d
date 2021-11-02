// REQUIRED_ARGS: -wi -unittest -vunused -debug

/*
TEST_OUTPUT:
---

---
*/

string generate(string function(int x) dg)
{
    string code;
    code ~= dg(42);
    return code;
}

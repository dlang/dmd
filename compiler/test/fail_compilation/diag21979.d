/*
TEST_OUTPUT:
---
{
        "severity":"Error",
        "uri":"fail_compilation/diag2179.d",
        "line:":27,
        "column":12,
        "description":"return value `"hi"` of type `string` does not match return type `int`, and cannot be implicitly converted",
}
---
*/

int num(int a)
{
    return "hi";
}
void main()
{
    int ch = num(5);
    writeln(ch);
} 
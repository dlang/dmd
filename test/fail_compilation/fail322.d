/*
TEST_OUTPUT:
---
fail_compilation/fail322.d(11): Error: function `fail322.digestToString2(ref char[16] digest)` is not callable using argument types `(string)`
fail_compilation/fail322.d(11):        cannot pass rvalue argument `"1234567890123456"` of type `string` to parameter `ref char[16] digest`
---
*/

void main()
{
    digestToString2("1234567890123456");
}

void digestToString2(ref char[16] digest)
{
    assert(digest[0] == 0xc3);
    assert(digest[15] == 0x3b);
}

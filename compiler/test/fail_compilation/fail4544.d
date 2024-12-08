/*
TEST_OUTPUT:
---
fail_compilation/fail4544.d(25): Error: character constant has multiple characters
    char c = 'asd';
             ^
fail_compilation/fail4544.d(26): Error: `0x` isn't a valid integer literal, use `0x0` instead
    int 0x = 'k';
    ^
fail_compilation/fail4544.d(26): Error: no identifier for declarator `int`
    int 0x = 'k';
        ^
fail_compilation/fail4544.d(27): Error: unterminated character constant
    foo('dasadasdaasdasdaslkdhasdlashdsalk, xxx);
        ^
fail_compilation/fail4544.d(28): Error: character constant has multiple characters
    goo('asdasdsa');
        ^
---
*/

int foo(char n, int m)
{
    int k = 5;
    char c = 'asd';
    int 0x = 'k';
    foo('dasadasdaasdasdaslkdhasdlashdsalk, xxx);
    goo('asdasdsa');
    for (int i = 0; i < 10; i++)
    {
        k++;
    }
}

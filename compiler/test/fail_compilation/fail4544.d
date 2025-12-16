/*
TEST_OUTPUT:
---
fail4544.d(15): Error: character constant has multiple characters - did you mean "asd"?
fail4544.d(16): Error: `0x` isn't a valid integer literal, use `0x0` instead
fail4544.d(16): Error: variable name expected after type `int`, not `0`
fail4544.d(17): Error: unterminated character constant
fail4544.d(18): Error: character constant has multiple characters - did you mean "asdasdsa"?
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

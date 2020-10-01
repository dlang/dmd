/*
REQUIRED_ARGS: -preview=nodiscard
*/
@nodiscard struct S {}

void assign()
{
    S a, b;
    a = b;
}

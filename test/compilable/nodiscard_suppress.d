/*
REQUIRED_ARGS: -preview=nodiscard
*/
@nodiscard extern int func();

void ignore()
{
    cast(void) func();
}

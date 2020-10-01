/*
REQUIRED_ARGS: -preview=nodiscard
*/
@nodiscard extern int func();
auto fp = &func;

void ignore()
{
    fp();
}

@nodiscard extern int func();
auto fp = &func;

void ignore()
{
    fp();
}

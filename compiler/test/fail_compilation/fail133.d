/*
TEST_OUTPUT:
---
fail_compilation/fail133.d(17): Error: function `D main` circular dependency. Functions cannot be interpreted while being compiled
int main()
    ^
fail_compilation/fail133.d(19):        called from here: `main()`
    return t!(main() + 8);
                  ^
---
*/

template t(int t)
{
}

int main()
{
    return t!(main() + 8);
}

/*
REQUIRED_ARGS: -g
PERMUTE_ARGS:
GDB_SCRIPT:
---
run
---
GDB_MATCH: \*ptr = 1
*/

static
void foo(int* ptr)
{
    *ptr = 1;
}

int main(int argc, char** argv)
{
    foo(0);
    return 0;
}

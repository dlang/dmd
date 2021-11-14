// https://issues.dlang.org/show_bug.cgi?id=22422

int foo(void *p __attribute__((align_value(64))))
{
}

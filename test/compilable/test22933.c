// https://issues.dlang.org/show_bug.cgi?id=22933

void fn()
{
    goto L;
    int x = 1;
  L:
    return;
}

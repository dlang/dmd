// https://issues.dlang.org/show_bug.cgi?id=22333

enum E {
  oldval __attribute__((deprecated)) = 0,
  newval
};

int
fn (void)
{
  return oldval;
}


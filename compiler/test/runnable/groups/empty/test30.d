// https://issues.dlang.org/show_bug.cgi?id=444

shared static this()
{
  int nothing( int delegate(ref int) dg ) {return 0;}
  foreach(int x; &nothing)
    assert(0);
}

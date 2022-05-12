struct Ty
{
  int x;
}
void main()
{
  float f = 420.0;
  Ty* ptr = new Ty;
  ptr.x = 299792458;
  int xx;
  long yx;
  static assert(!__traits(compiles, xx = yx));
  int res = mixin[C]("xx = yx");
  int x = mixin[C]("(int) f");
  auto g = mixin[C]("sizeof(struct Ty)");
}

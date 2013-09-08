void main()
{
  ubyte from, to;
  foreach(i; from..to)
  {
    static assert(is(typeof(i) == ubyte));
  }
}

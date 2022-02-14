module testcov1b;

class ArraySet(Key, int div = 1)
{
  private Key[][div] polje;

  public this(in ArraySet a)
  {
    foreach(Key k, uint i; a)
      this.add(k);
  }

  public void add(Key elem)
  {
  }

  int opApply(int delegate(ref Key x, ref uint y) dg) const
  {
	return 0;
  }
}



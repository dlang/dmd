// REQUIRED_ARGS: -preview=dip1000

class C
{
   R r;

   this() @safe
   {
	r = new R();
   }

   class R
   {
   }
}


class F
{
    G foo() @safe
    {
	return new G();
    }

    class G
    {
    }
}



void test()
{
    class H { }
    auto x = new immutable(H);
}

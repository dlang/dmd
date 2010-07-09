// 85

interface I
{
        I[] foo();
        uint x();
}

class Class : I
{
        I[] foo()
	{
                // changing this to I[] f = new Class[1] fixes the bug
		Class[] f = new Class[1];
		//I[] f = new Class[1];
                f[0] = new Class;
                return f;
        }

        uint x()
	{
                return 0;
        }
}

void main() {
        Class c = new Class();
        assert (c.x == 0);
        assert (c.foo[0].x == 0);
}


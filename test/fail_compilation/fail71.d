
class C
{
    const int y;

    this()
    {	C c = this;

	y = 7;
	c.y = 8;
    }
}

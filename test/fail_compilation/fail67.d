
class C
{
    const int y;

    this()
    {
	y = 7;
    }
}

int main()
{
    C c = new C();

    c.y = 3;

    return 0;
}



void main()
{
    enum E { a, b }
    E i = E.a;
    final switch (i)
    {
	case E.a: .. case E.b:
	    break;
    }
}

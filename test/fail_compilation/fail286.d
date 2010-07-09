enum E
{
    A,B,C
}

void main()
{
    E e;
    final switch (e)
    {
	case E.A:
//	case E.B:
	case E.C:
	    ;
    }
}

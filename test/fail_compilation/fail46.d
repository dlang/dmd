
// compile with -inline

struct MyStruct
{
    int bug()
    {
	return 3;
    }
}

int main()
{
    assert(MyStruct.bug() == 3);
    return 0;
}


// 1336 Internal error when trying to construct a class declared within a unittest from a templated class.

class X(T)
{
        void bar()
        {
                auto t = new T;
        }
}

void foo()
{
	class DummyClass
        {
        }

	//auto x = new X!(DummyClass);
	X!(DummyClass) x;
}


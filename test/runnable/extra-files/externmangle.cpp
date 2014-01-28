
#include <stdint.h>

template<class X>
struct Foo 
{
	X *v;
};

template<class X>
struct Boo 
{
	X *v;
}; 

void test1(Foo<int> arg1)
{
}


void test2(int* arg2, Boo<int*> arg1)
{
}

template<int X, int Y>
struct Test3
{

}; 

void test3(Test3<3,3> arg1)
{
}

void test4(Foo<int*> arg1, Boo<int*> arg2, Boo<int*> arg3, int*, Foo<double>)
{
}

void test5(Foo<int*> arg1, Boo<int*> arg2, Boo<int*> arg3)
{
}

struct Goo
{

	template<class X>
	struct Foo 
	{
		X* v;
	};

	template<class X>
	struct Boo 
	{
		template<class Y>
		struct Xoo 
		{
			Y* v;
		};
		X* v;
	}; 


	void test6(Foo<Boo<Foo<void> > > arg1);
	void test7(Boo<void>::Xoo<int> arg1);
};

void Goo::test6(Goo::Foo<Goo::Boo<Goo::Foo<void> > > arg1)
{
}

void Goo::test7(Goo::Boo<void>::Xoo<int> arg1)
{
}

struct P1
{
	template<class T>
	struct Mem
	{
	};
};

struct P2
{
	template<class T>
	struct Mem
	{
	};
};

void test8(P1::Mem<int>, P2::Mem<int>){}
void test9(Foo<int**>, Foo<int*>, int**, int*){}



class Test10
{
    private: void test10();
    public: void test11();
    protected: void test12();
    public: void test13() const;

    private: virtual void test14();
    public: virtual void test15();
    protected: virtual void test16();   

    private: static void test17();
    public: static void test18();
    protected: static void test19();
};

Test10* Test10Ctor()
{
    return new Test10();
}

void Test10Dtor(Test10*& ptr)
{
    delete ptr;
    ptr = 0;
}

void Test10::test10(){}
void Test10::test11(){}
void Test10::test12(){} 
void Test10::test13() const{} 
void Test10::test14(){}
void Test10::test15(){}
void Test10::test16(){} 
void Test10::test17(){}
void Test10::test18(){}
void Test10::test19(){} 

struct Test20
{
    private: static int test20;
    protected: static int test21;
    public: static int test22;
};

int Test20::test20 = 20;
int Test20::test21 = 21;
int Test20::test22 = 22;

int test23(Test10**, Test10*, Test10***, const Test10*)
{
    return 1;
}

int test23b(const Test10**, const Test10*, Test10*)
{
    return 1;
}

void test24(int(*)(int,int))
{
}

void test25(int(* arr)[5][6][291])
{
}

int test26(int arr[5][6][291])
{
    return arr[1][1][1];
}

void test27(int, ...){}
void test28(int){}

void test29(float){}
void test30(const float){}

template<class T>
struct Array
{
    int dim;
};

class Module
{
public: 
    static void imports(Module*);
    static int dim(Array<Module*>*);
}; 


void Module::imports(Module*)
{
}

int Module::dim(Array<Module*>* arr)
{
    return arr->dim;
}

#if _LP64
unsigned long testlongmangle(int32_t a, uint32_t b, long c, unsigned long d)
{
    return a + b + c + d;
}
#else
unsigned long long testlongmangle(int32_t a, uint32_t b, long long c, unsigned long long d)
{
    return a + b + c + d;
}
#endif

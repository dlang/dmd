// Error: pure function 'h' cannot call impure function 'g'

void f() pure
{   void g()
    {
     void h() pure
     {
	void i() { }
	void j() { i(); g(); }
     }
    }
}


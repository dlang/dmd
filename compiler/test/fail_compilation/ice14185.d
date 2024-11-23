/*
TEST_OUTPUT:
---
fail_compilation/ice14185.d(14): Error: cannot implicitly convert expression `this` of type `Mutexed` to `Mutexed*`
		return Lock (this);
               ^
---
*/

struct Mutexed
{
	auto acquire ()
	{
		return Lock (this);
	}
	alias acquire this;

	struct Lock
	{
		Mutexed* source;
	}
}
void main ()
{
	Mutexed x;
}

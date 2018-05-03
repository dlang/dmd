// 7886

struct A {
	static assert (__traits(derivedMembers, A).length == 0);
}

struct S2 {
	int field2;
};
void fn()
{
	struct S2 *const s;
	int x = s->field2; // here
}

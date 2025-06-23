/* TEST_OUTPUT:
---
fail_compilation\aaerrros.d-mixin-32(33): Error: `assert(aai[1] == 0)` failed
fail_compilation\aaerrros.d-mixin-32(34):        called from here: `(*function () pure nothrow @safe => true)()`
fail_compilation\aaerrros.d-mixin-33(34): Error: `assert((aai[1] = 1) == 0)` failed
fail_compilation\aaerrros.d-mixin-33(35):        called from here: `(*function () pure nothrow @safe => true)()`
fail_compilation\aaerrros.d-mixin-34(35): Error: `assert(*(1 in aai) == 3)` failed
fail_compilation\aaerrros.d-mixin-34(36):        called from here: `(*function () pure nothrow @safe => true)()`
fail_compilation\aaerrros.d-mixin-35(36): Error: `assert(aai.remove(2))` failed
fail_compilation\aaerrros.d-mixin-35(37):        called from here: `(*function () pure nothrow @safe => true)()`
fail_compilation\aaerrros.d-mixin-42(43): Error: `assert(aas[1].x == 0)` failed
fail_compilation\aaerrros.d-mixin-42(44):        called from here: `(*function () @system => true)()`
fail_compilation\aaerrros.d-mixin-43(44): Error: `assert((aas[1] = 1).x == 0)` failed
fail_compilation\aaerrros.d-mixin-43(45):        called from here: `(*function () @system => true)()`
fail_compilation\aaerrros.d-mixin-44(45): Error: `assert((*(1 in aas)).x == 0)` failed
fail_compilation\aaerrros.d-mixin-44(46):        called from here: `(*function () @system => true)()`
---
*/

struct S
{
	int x;
	this(int _x){ x = _x; }
	ref S opAssign(int _x){ x = _x; return this; }
}

string gentest_ii(string expr)
{
	return "() { int[int] aai = [ 1 : 2 ];\n assert(" ~ expr ~ ");\n return true; }()\n";
}

const ii1 = mixin(gentest_ii("aai[1] == 0"));
const ii2 = mixin(gentest_ii("(aai[1] = 1) == 0"));
const ii3 = mixin(gentest_ii("*(1 in aai) == 3"));
const ii4 = mixin(gentest_ii("aai.remove(2)"));

string gentest_is(string expr)
{
	return "() { S[int] aas = [ 1 : S(2) ];\n assert(" ~ expr ~ ");\n return true; }()\n";
}

const is1 = mixin(gentest_is("aas[1].x == 0"));
const is2 = mixin(gentest_is("(aas[1] = 1).x == 0"));
const is3 = mixin(gentest_is("(1 in aas).x == 0"));

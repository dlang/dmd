// ensure iasm can be used in __traits(compiles without killing the compiler

static assert(__traits(compiles, {
	asm {nop;}; // control test
}));

static assert(!__traits(compiles, {
	asm {#$%^&*;};
}));

//

static assert(__traits(compiles, {
	x!()();
}));
void x()() {asm {nop;};};

static assert(!__traits(compiles, {
	y!()();
}));
void y()() {asm {#$%^&*;};};

//

static assert(__traits(compiles, {
	mixin a!();
}));
mixin template a() {
	auto a = ({asm {nop;}; return 1;})();
};

static assert(!__traits(compiles, {
	mixin b!();
}));
mixin template b() {
	auto b = ({asm {#$%^&*;}; return 1;})();
};

//

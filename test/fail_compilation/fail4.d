// REQUIRED_ARGS: -d
// On DMD0.165 fails only with typedef, not alias

typedef foo bar;
typedef bar foo;

// fail\fail4.d(2): typedef fail4.foo circular definition


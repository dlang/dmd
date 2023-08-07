module imports.pragma_lib_local;


pragma(libLocal, "extra-files/fake.a");

extern(C) int lib_get_int();

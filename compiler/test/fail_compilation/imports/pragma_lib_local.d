module imports.pragma_lib_local;


pragma(libLocal, "extra-files/local_lib.a");

extern(C) int lib_get_int();

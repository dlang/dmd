// https://issues.dlang.org/show_bug.cgi?id=23548
// REQUIRED_ARGS: -Icompilable/extra-files/issue23548
// EXTRA_FILES: extra-files/issue23548/imports/imp23548.d imports/imp23548.c
import imports.imp23548;
static assert(issue23548 == true);

// https://issues.dlang.org/show_bug.cgi?id=23548
// EXTRA_FILES: imports/imp23548.d imports/imp23548.c
import imports.imp23548;
static assert(issue23548 == true);

//https://issues.dlang.org/show_bug.cgi?id=23012
import imports.asmmerge; //.c for reference

static assert(fun22.mangleof == "test1");

static assert(xs.mangleof == "test2");

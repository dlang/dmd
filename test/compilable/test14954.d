/*
https://issues.dlang.org/show_bug.cgi?id=14954

EXTRA_SOURCES: imports/test14954_implementation.d
LINK:
*/

extern(C) struct UndeclaredStruct;
extern(C) __gshared extern UndeclaredStruct blah;
__gshared auto p = &blah;

void main() {}

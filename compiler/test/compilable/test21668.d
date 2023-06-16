// https://issues.dlang.org/show_bug.cgi?id=21668
// https://issues.dlang.org/show_bug.cgi?id=23995

struct Opaque;

void byPtr(Opaque*) {}
void byRef(ref Opaque) {} // Fails
void byRef(out Opaque) {} // Fails
void bySlice(Opaque[]) {}

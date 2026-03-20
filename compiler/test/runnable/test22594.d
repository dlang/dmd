// https://github.com/dlang/dmd/issues/22594
// PERMUTE_ARGS:

import core.memory : GC;

class C(Ts...) {
    Ts tuple;
}

void main() {
    alias NoPointers = C!int;
    alias WithPointers = C!(void*);

    assert(typeid(NoPointers).m_flags & TypeInfo_Class.ClassFlags.noPointers);
    assert(!(typeid(WithPointers).m_flags & TypeInfo_Class.ClassFlags.noPointers));

    auto noPointers = new NoPointers;
    // FIXME: regressed with v2.103
    //assert(GC.getAttr(cast(void*) noPointers) & GC.BlkAttr.NO_SCAN);

    auto withPointers = new WithPointers;
    assert(!(GC.getAttr(cast(void*) withPointers) & GC.BlkAttr.NO_SCAN));
}

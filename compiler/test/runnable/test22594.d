// https://github.com/dlang/dmd/issues/22594
// https://github.com/dlang/dmd/issues/22599
// PERMUTE_ARGS:

import core.memory : GC;

class C(Ts...) {
    Ts tuple;
}

// https://github.com/dlang/dmd/issues/22608
class C22608 {
    void function() functionPointer; // can't point to GC data
    typeof(null) nullPointer;        // ditto, is guaranteed null
    void*[0] emptyStaticArray;
}

void main() {
    alias NoPointers = C!int;
    alias WithPointers = C!(void*);

    assert(typeid(NoPointers).m_flags & TypeInfo_Class.ClassFlags.noPointers);
    assert(!(typeid(WithPointers).m_flags & TypeInfo_Class.ClassFlags.noPointers));
    assert(typeid(C22608).m_flags & TypeInfo_Class.ClassFlags.noPointers);

    auto noPointers = new NoPointers;
    assert(GC.getAttr(cast(void*) noPointers) & GC.BlkAttr.NO_SCAN);

    auto withPointers = new WithPointers;
    assert(!(GC.getAttr(cast(void*) withPointers) & GC.BlkAttr.NO_SCAN));

    auto c22608 = new C22608;
    assert(GC.getAttr(cast(void*) c22608) & GC.BlkAttr.NO_SCAN);
}

module core.internal.cast_;


// Needed because ClassInfo.opEquals(Object) does a dynamic cast,
// but we are trying to implement dynamic cast.
bool areClassInfosEqual(scope const ClassInfo a, scope const ClassInfo b) pure nothrow @safe @nogc
{
    // same class if signatures match, works with potential duplicates across binaries
    if (a is b)
        return true;

    // new fast way
    if (a.m_flags & TypeInfo_Class.ClassFlags.hasNameSig)
        return a.nameSig[0] == b.nameSig[0]
            && a.nameSig[1] == b.nameSig[1]
            && a.nameSig[2] == b.nameSig[2]
            && a.nameSig[3] == b.nameSig[3];

    // old slow way for temporary binary compatibility
    return a.name == b.name;
}


/*****
 * Dynamic cast from a class object `o` to class or interface `c`, where `c` is a subtype of `o`.
 * Params:
 *      o = instance of class
 *      c = a subclass of o
 * Returns:
 *      null if o is null or c is not a subclass of o. Otherwise, return o.
 */
void* _d_dynamic_cast(To)(Object o) @trusted
{
    debug(cast_) printf("_d_dynamic_cast(o = %p, c = '%.*s')\n", o, cast(int) c.name.length, c.name.ptr);

    void* res = null;
    size_t offset = 0;
    if (o && _d_isbaseof2!To(typeid(o), offset))
    {
        debug(cast_) printf("\toffset = %zd\n", offset);
        res = cast(void*) o + offset;
    }
    debug(cast_) printf("\tresult = %p\n", res);
    return res;
}


private bool _d_isbaseof2(To)(scope ClassInfo oc, scope ref size_t offset)
{
    auto c = typeid(To).info;

    if (areClassInfosEqual(oc, c))
        return true;

    do
    {
        if (oc.base && areClassInfosEqual(oc.base, c))
            return true;

        // Bugzilla 2013: Use depth-first search to calculate offset
        // from the derived (oc) to the base (c).
        foreach (iface; oc.interfaces)
        {
            if (areClassInfosEqual(iface.classinfo, c) || _d_isbaseof2!To(iface.classinfo, offset))
            {
                offset += iface.offset;
                return true;
            }
        }

        oc = oc.base;
    } while (oc);

    return false;
}

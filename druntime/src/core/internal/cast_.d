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
 * Dynamic cast from a class object `o` to class or interface `To`, where `To` is a subtype of `o`.
 * Params:
 *      o = instance of class
 *      To = class or interface that is a subtype of `o`
 * Returns:
 *      null if `o` is null or `To` is not a subclass type of `o`. Otherwise, return `o`.
 */
private void* _d_dynamic_cast(To)(const return scope Object o) @trusted
{
    void* res = null;
    size_t offset = 0;

    if (o && _d_isbaseof2!To(typeid(o), offset))
    {
        res = cast(void*) o + offset;
    }
    return res;
}

/**
 * Dynamic cast `o` to final class `To` only one level down
 * Params:
 *      o = object that is instance of a class
 *      To = final class that is a subclass type of `o`
 * Returns:
 *      o if it succeeds, null if it fails
 */
private void* _d_paint_cast(To)(const return scope Object o)
{
    /* If o is really an instance of c, just do a paint
     */
    auto p = o && cast(void*)(areClassInfosEqual(typeid(o), typeid(To).info)) ? o : null;
    debug assert(cast(void*)p is cast(void*)_d_dynamic_cast!To(o));
    return cast(void*)p;
}

private void* _d_class_cast_impl(const return scope Object o, const ClassInfo c) pure nothrow @safe @nogc
{
    if (!o)
        return null;

    ClassInfo oc = typeid(o);
    int delta = oc.depth;

    if (delta && c.depth)
    {
        delta -= c.depth;
        if (delta < 0)
            return null;

        while (delta--)
            oc = oc.base;
        if (areClassInfosEqual(oc, c))
            return cast(void*)o;
        return null;
    }

    // no depth data - support the old way
    do
    {
        if (areClassInfosEqual(oc, c))
            return cast(void*)o;
        oc = oc.base;
    } while (oc);
    return null;
}

/*****
 * Dynamic cast from a class object o to class type `To`, where `To` is a subclass type of `o`.
 * Params:
 *      o = instance of class
 *      To = a subclass type of o
 * Returns:
 *      null if `o` is null or `To` is not a subclass type of `o`. Otherwise, return `o`.
 */
private void* _d_class_cast(To)(const return scope Object o)
{
    return _d_class_cast_impl(o, typeid(To));
}

/**
* Hook that detects the type of cast performed and calls the appropriate function.
* Params:
*      o = object that is being casted
*      To = type to which the object is being casted
* Returns:
*      null if the cast fails, otherwise returns the object casted to the type `To`.
*/
void* _d_cast(To, From)(From o) @trusted
{
    static if (is(From == class) && is(To == interface))
    {
        return _d_dynamic_cast!To(o);
    }

    static if (is(From == class) && is(To == class))
    {
        static if (is(From FromSupers == super) && is(To ToSupers == super))
        {
            /* Check for:
            *  class A { }
            *  final class B : A { }
            *  ... cast(B) A ...
            */
            // Multiple inheritance is not allowed, so we can safely assume
            // that the second super can only be an interface.
            static if (__traits(isFinalClass, To) && is(ToSupers[0] == From) &&
                       ToSupers.length == 1 && FromSupers.length <= 1)
            {
                return _d_paint_cast!To(o);
            }
        }

        static if (is (To : From))
        {
            static if (is (To == From))
            {
                return cast(void*)o;
            }
            else
            {
                return _d_class_cast!To(o);
            }
        }

        return null;
    }

    return null;
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

@safe pure unittest
{
    interface I {}

    class A {}
    class B : A {}
    class C : B, I{}

    A ac = new C();
    assert(_d_cast!I(ac) !is null); // A(c) to I
    assert(_d_dynamic_cast!I(ac) !is null);

    A ab = new B();
    assert(_d_cast!I(ab) is null); // A(b) to I
    assert(_d_dynamic_cast!I(ab) is null);
}

@safe pure unittest
{
    class A {}
    class B : A {}
    class C : B {}
    final class D : C {}

    C cd = new D();
    assert(_d_cast!D(cd) !is null); // C(d) to D
    assert(_d_paint_cast!D(cd) !is null);

    class G {}
    final class J {}
    A a = new A();
    assert(_d_cast!G(a) is null); // A(a) to G
    assert(_d_paint_cast!G(a) is null);

    assert(_d_cast!J(a) is null); // A(a) to J
    assert(_d_paint_cast!J(a) is null);
}

@safe pure unittest
{
    class A {}
    class B : A {}
    class C : B {}
    class D {}

    A ac = new C();
    assert(_d_cast!C(ac) !is null); // A(c) to C
    assert(_d_class_cast!C(ac) !is null);

    assert(_d_cast!B(ac) !is null); // A(c) to B
    assert(_d_class_cast!B(ac) !is null);

    A ab = new B();
    assert(_d_cast!C(ab) is null); // A(b) to C
    assert(_d_class_cast!C(ab) is null);

    A a = new A();
    assert(_d_cast!D(a) is null); // A(a) to D
    assert(_d_class_cast!D(a) is null);
}

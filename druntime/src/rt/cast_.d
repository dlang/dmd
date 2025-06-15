/**
 * Implementation of array assignment support routines.
 *
 * Copyright: Copyright Digital Mars 2004 - 2010.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Walter Bright, Sean Kelly
 * Source: $(DRUNTIMESRC rt/_cast_.d)
 */

/*          Copyright Digital Mars 2004 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.cast_;

debug(cast_) import core.stdc.stdio : printf;
import core.internal.cast_ : areClassInfosEqual;

extern (C):
@nogc:
nothrow:
pure:

/******************************************
 * Given a pointer:
 *      If it is an Object, return that Object.
 *      If it is an interface, return the Object implementing the interface.
 *      If it is null, return null.
 *      Else, undefined crash
 */
Object _d_toObject(return scope void* p)
{
    if (!p)
        return null;

    Object o = cast(Object) p;
    ClassInfo oc = typeid(o);
    Interface* pi = **cast(Interface***) p;

    /* Interface.offset lines up with ClassInfo.name.ptr,
     * so we rely on pointers never being less than 64K,
     * and Objects never being greater.
     */
    if (pi.offset < 0x10000)
    {
        debug(cast_) printf("\tpi.offset = %zd\n", pi.offset);
        return cast(Object)(p - pi.offset);
    }
    return o;
}

/*************************************
 * Attempts to cast interface Object o to class c.
 * Returns o if successful, null if not.
 */
void* _d_interface_cast(void* p, ClassInfo c)
{
    debug(cast_) printf("_d_interface_cast(p = %p, c = '%.*s')\n", p, cast(int) c.name.length, c.name.ptr);
    if (!p)
        return null;

    Interface* pi = **cast(Interface***) p;

    debug(cast_) printf("\tpi.offset = %zd\n", pi.offset);
    Object o2 = cast(Object)(p - pi.offset);
    void* res = null;
    size_t offset = 0;
    if (o2 && _d_isbaseof2(typeid(o2), c, offset))
    {
        debug(cast_) printf("\toffset = %zd\n", offset);
        res = cast(void*) o2 + offset;
    }
    debug(cast_) printf("\tresult = %p\n", res);
    return res;
}

int _d_isbaseof2(scope ClassInfo oc, scope const ClassInfo c, scope ref size_t offset) @safe
{
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
            if (areClassInfosEqual(iface.classinfo, c) || _d_isbaseof2(iface.classinfo, c, offset))
            {
                offset += iface.offset;
                return true;
            }
        }

        oc = oc.base;
    } while (oc);

    return false;
}

int _d_isbaseof(scope ClassInfo oc, scope const ClassInfo c) @safe
{
    size_t offset = 0;
    return _d_isbaseof2(oc, c, offset);
}

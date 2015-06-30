/**
Array utilities.

Copyright: Denis Shelomovskij 2013
License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Denis Shelomovskij
Source: $(DRUNTIMESRC src/rt/util/_array.d)
*/
module rt.util.array;


import core.internal.string;


@safe /* pure dmd @@@BUG11461@@@ */ nothrow:

void enforceTypedArraysConformable(T)(in char[] action,
    in T[] a1, in T[] a2, in bool allowOverlap = false)
{
    _enforceSameLength(action, a1.length, a2.length);
    if(!allowOverlap)
        _enforceNoOverlap(action, a1.ptr, a2.ptr, T.sizeof * a1.length);
}

void enforceRawArraysConformable(in char[] action, in size_t elementSize,
    in void[] a1, in void[] a2, in bool allowOverlap = false)
{
    _enforceSameLength(action, a1.length, a2.length);
    if(!allowOverlap)
        _enforceNoOverlap(action, a1.ptr, a2.ptr, elementSize * a1.length);
}

private void _enforceSameLength(in char[] action,
    in size_t length1, in size_t length2)
{
    if(length1 == length2)
        return;

    UnsignedStringBuf tmpBuff = void;
    string msg = "Array lengths don't match for ";
    msg ~= action;
    msg ~= ": ";
    msg ~= length1.unsignedToTempString(tmpBuff, 10);
    msg ~= " != ";
    msg ~= length2.unsignedToTempString(tmpBuff, 10);
    throw new Error(msg);
}

private void _enforceNoOverlap(in char[] action,
    in void* ptr1, in void* ptr2, in size_t bytes)
{
    const size_t d = ptr1 > ptr2 ? ptr1 - ptr2 : ptr2 - ptr1;
    if(d >= bytes)
        return;
    const overlappedBytes = bytes - d;

    UnsignedStringBuf tmpBuff = void;
    string msg = "Overlapping arrays in ";
    msg ~= action;
    msg ~= ": ";
    msg ~= overlappedBytes.unsignedToTempString(tmpBuff, 10);
    msg ~= " byte(s) overlap of ";
    msg ~= bytes.unsignedToTempString(tmpBuff, 10);
    throw new Error(msg);
}

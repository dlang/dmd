/**
 * This module contains ABI definitions in form of structs and helper functions
 * sizes and offsets are in Bytes
 * Copyright:   Copyright (C) 2022 by The D Language Foundation, All Rights Reserved
 * Authors:     Stefan Koch, Max Haughton
 */
module dmd.ctfe.bc_abi;

import dmd.ctfe.bc_limits;
import dmd.ctfe.bc_common;


enum PtrSize = 4;

enum uint stackAddrMask = ((1 << 31) |
                           (1 << 30) |
                           (1 << 29));

static bool isStackAddress(uint unrealPointer)
{
    pragma(inline, true);
    // a stack address has the upper 3 bits set
    return (unrealPointer & stackAddrMask) == stackAddrMask;
}

static bool isHeapAddress (uint unrealPointer)
{
    pragma(inline, true);
    // a heap address does not have the upper 3 bits set
    return (unrealPointer & stackAddrMask) != stackAddrMask;
}

static uint toStackOffset(uint unrealPointer)
{
    assert(isStackAddress(unrealPointer));
    return (unrealPointer & ~stackAddrMask);
}

static assert(toStackOffset(minStackAddress) == 0);
static assert(toStackOffset(maxStackAddress) == 0x1fffffff);

enum maxHeapAddress =  0b1101_1111_1111_1111_1111_1111_1111_1111;
enum minHeapAddress =  0b0000_0000_0000_0000_0000_0000_0000_0000;

enum minStackAddress = 0b1110_0000_0000_0000_0000_0000_0000_0000;
enum maxStackAddress = 0b1111_1111_1111_1111_1111_1111_1111_1111;

static assert(isStackAddress(uint.max - ushort.max));
static assert(!isStackAddress(int.max));
static assert(isHeapAddress(maxHeapAddress));
static assert(!isHeapAddress(minStackAddress));
static assert(!isHeapAddress(minStackAddress));
static assert(!isStackAddress(!maxHeapAddress));

bool needsUserSize(BCTypeEnum type)
{
    with (BCTypeEnum) return type == Array || type == Struct;
}

bool typeIsPointerOnStack(BCTypeEnum type)
{
    with (BCTypeEnum) return type == Class;
}

/// appended to a struct
/// behind the last member
struct StructMetaData
{
    enum VoidInitBitfieldOffset = 0;
    enum Size = 4;
}

/// appended to union
/// behind the biggest Member
struct UnionMetaData
{
    enum VoidInitBitfieldOffset = 0;
    enum Size = bc_max_members/8;
}

/// prepended to a class
/// before the first member
struct ClassMetaData
{
    enum VtblOffset = 0;
    enum TypeIdIdxOffset = 4;
    enum Size = 8;
}

/// SliceDescriptor is the ABI for a { ptr, size } aggregate
/// known as a slice
struct SliceDescriptor
{
    enum BaseOffset = 0;
    enum LengthOffset = 4;
    enum CapacityOffset = 8;
    enum ExtraFlagsOffset = 12;
    enum Size = 16;
}

/// DelegateDescriptor is the ABI for a { funcPtr, ContextPtr } aggregate
/// known as a delegate
struct DelegateDescriptor
{
    enum FuncPtrOffset = 0;
    enum ContextPtrOffset = 4;
    enum Size = 8;
}

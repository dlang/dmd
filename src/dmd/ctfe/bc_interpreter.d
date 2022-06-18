/**
 * Implements the interpreter loop for the bytecode interpreter engine.
 *
 * Copyright:   Copyright (C) 2022 by The D Language Foundation, All Rights Reserved
 * Authors:     Stefan Koch, Max Haughton
 */
module dmd.ctfe.bc_interpreter;
import dmd.ctfe.bc_common;
import dmd.ctfe.bc;
import dmd.ctfe.bc_abi;
///
auto interpret(ref BCGen gen, BCValue[] args, BCHeap* heapPtr = null) @trusted
{
    with(gen)
    {
        BCFunction f = BCFunction(cast(void*)fd,
        1,
        BCFunctionTypeEnum.Bytecode,
        parameterCount,
        cast(ushort)(temporaryCount + localCount + parameterCount),
        cast(uint[])byteCodeArray[0 .. ip]
        );
        return interpret_(0, args, heapPtr, &f, &calls[0]);
    }
}
/* TODO: This interface (interpret_) is absolutely awful */
///
const(BCValue) interpret_(int fnId, const BCValue[] args,
    BCHeap* heapPtr = null, const BCFunction* functions = null,
    const RetainedCall* calls = null,
    BCValue* ev1 = null, BCValue* ev2 = null, BCValue* ev3 = null,
    BCValue* ev4 = null, const RE* errors = null,
    long[] stackPtr = null,
    const string[ushort] stackMap = null,
    /+    DebugCommand function() reciveCommand = {return DebugCommand(DebugCmdEnum.Nothing);},
    BCValue* debugOutput = null,+/ uint stackOffset = 0)  @trusted
{
    const (uint[])* byteCode = getCodeForId(fnId, functions);

    uint callDepth = 0;
    uint inThrow = false;
    import std.stdio;

    bool paused; /// true if we are in a breakpoint.


    uint[] breakLines = [];
    uint lastLine;
    const (char)* lastComment;
    BCValue cRetval;
    ReturnAddr[max_call_depth] returnAddrs;
    Catch[] catches;
    uint n_return_addrs;
    if (!__ctfe)
    {
        // writeln("Args: ", args, "BC:", (*byteCode).printInstructions(stackMap));
    }
    auto stack = stackPtr ? stackPtr : new long[](ushort.max / 4);

    // first push the args on
    debug (bc)
        if (!__ctfe)
        {
            printf("before pushing args");
        }
    long* framePtr = &stack[0] + (stackOffset / 4);
/+
    struct Stack
    {
        long* opIndex(size_t idx) pure
        {
            long* result = &stack[0] + (stackOffset / 4) + idx;
            debug if (!__ctfe) { writeln("SP[", idx*4, "] = ", *result); }
            return result;
        }
    }
    auto stackP = Stack();
+/
    size_t argOffset = 1;
    foreach (arg; args)
    {
        switch (arg.type.type)
        {
            case BCTypeEnum.u32, BCTypeEnum.f23, BCTypeEnum.c8:
            case BCTypeEnum.u16, BCTypeEnum.u8, BCTypeEnum.c16, BCTypeEnum.c32:
            case BCTypeEnum.i32, BCTypeEnum.i16, BCTypeEnum.i8:
            {
                (framePtr[argOffset++]) = cast(uint)arg.imm32;
            }
            break;

            case BCTypeEnum.i64, BCTypeEnum.u64, BCTypeEnum.f52:
            {
                (framePtr[argOffset]) = arg.imm64;
                argOffset += 2;
            }
            break;
            // all of thsose get passed by pointer and therefore just take one stack slot
            case BCTypeEnum.Struct, BCTypeEnum.Class, BCTypeEnum.string8, BCTypeEnum.Array, BCTypeEnum.Ptr, BCTypeEnum.Null:
                {
                    // This might need to be removed again?
                    (framePtr[argOffset++]) = arg.heapAddr.addr;
                }
                break;
            default:
            //return -1;
                   assert(0, "unsupported Type " ~ enumToString(arg.type.type));
        }
    }
    uint ip = 4;
    bool cond;

    BCValue returnValue;

    bool HandleExp()
    {
            if (cRetval.vType == BCValueType.Exception)
            {
                debug { if (!__ctfe) writeln("Exception in flight ... length of catches: ", catches ? catches.length : -1) ; }
                debug { if (!__ctfe) writeln("catches: ", catches);  }

                // we return to unroll
                // lets first handle the case in which there are catches on the catch stack
                if (catches.length)
                {
                    const catch_ = catches[$-1];
                    debug { if (!__ctfe) writefln("CallDepth:(%d) Catches (%s)", callDepth, catches); }

                    // in case we are above at the callDepth of the next catch
                    // we need to pass this return value on
                    if (catch_.stackDepth < callDepth)
                    {
                        auto returnAddr = returnAddrs[--n_return_addrs];
                        ip = returnAddr.ip;
                        debug { if (!__ctfe) writefln("CatchDepth:(%d) lower than current callStack:(%d) Depth. Returning to ip = %d", catch_.stackDepth, callDepth, ip); }
                        byteCode = getCodeForId(returnAddr.fnId, functions);
                        fnId = returnAddr.fnId;
                        --callDepth;
                        return false;
                    }
                    // In case we are at the callDepth we need to go to the right catch
                    else if (catch_.stackDepth == callDepth)
                    {
                        debug { if (!__ctfe) writeln("stackdepth == Calldepth. Executing catch at: ip=", ip, " byteCode.length="); }
                        ip = catch_.ip;
                        // we need to also remove the catches so we don't end up here next time
                        catches = catches[0 .. $-1];
                        // resume execution at execption handler block
                        return false;
                    }
                    // in case we end up here there is a catch handler but we skipped it
                    // this can happen if non of the handlers matched we return the execption
                    // out of the function .. we can ignore the state of the stack and such
                    else
                    {
                       
                        debug { if (!__ctfe) writeln("we have not been able to catch the expection returning."); }
                        return true;
                    }
                }
                // if we go here it means there are no catches anymore to catch this.
                // we will go on returning this out of the callstack until we hit the end
                else
                {
                    return true;
                }

                // in case we are at the depth we need to jump to Throw
                // assert(!catches.length, "We should goto the catchBlock here.");
            }
            else
                assert(0);
    }
     

    bool Return()
    {
        if (n_return_addrs)
        {
            auto returnAddr = returnAddrs[--n_return_addrs];
            byteCode = getCodeForId(returnAddr.fnId, functions);
            fnId = returnAddr.fnId;
            ip = returnAddr.ip;

            framePtr = framePtr - (returnAddr.stackSize / 4);
            callDepth--;
            if (cRetval.vType == BCValueType.Exception)
            {
                return HandleExp();
            }
            if (cRetval.vType == BCValueType.Error || cRetval.vType == BCValueType.Bailout)
            {
                return true;
            }
            if (cRetval.type.type == BCTypeEnum.i64 || cRetval.type.type == BCTypeEnum.u64 || cRetval.type.type == BCTypeEnum.f52)
            {
                (*returnAddr.retval) = cRetval.imm64;
            }
            else
            {
                (*returnAddr.retval) = cRetval.imm32;
            }
            return false;
        }
        else
        {
            return true;
        }
    }

    // debug(bc) { import std.stdio; writeln("BC.len = ", byteCode.length); }
    if ((*byteCode).length < 6 || (*byteCode).length <= ip)
        return typeof(return).init;

    while (true && ip <= (*byteCode).length - 1)
    {
/+
        DebugCommand command = reciveCommand();
        do
        {
            debug
            {
                import std.stdio;
                if (!__ctfe) writeln("Order: ", enumToString(command.order));
            }

            Switch : final switch(command.order) with(DebugCmdEnum)
            {
                case Invalid : {assert(0, "Invalid DebugCmdEnum");} break;
                case SetBreakpoint :
                {
                    auto bl = command.v1;
                    foreach(_bl;breakLines)
                    {
                        if (bl == _bl)
                            break Switch;
                    }

                    breakLines ~= bl;
                } break;
                case UnsetBreakpoint :
                {
                    auto bl = command.v1;
                    foreach(uint i, _bl;breakLines)
                    {
                        if (_bl == bl)
                        {
                            breakLines[i] = breakLines[$-1];
                            breakLines = breakLines[0 .. $-1];
                            break;
                        }
                    }
                } break;
                case ReadStack : {assert(0);} break;
                case WriteStack : {assert(0);} break;
                case ReadHeap : {assert(0);} break;
                case WriteHeap : {assert(0);} break;
                case Continue : {paused = false;} break;
                case Nothing :
                {
                    if (!paused)
                    { /*__mmPause()*/ }
                } break;
            }

        } while (paused || command.order != DebugCmdEnum.Nothing);
+/
        debug (bc_stack)
            foreach (si; 0 .. stackOffset + 32)
            {
                if (!__ctfe)
                {
                    printf("StackIndex %d, Content %x\t".ptr, si, stack[cast(uint) si]);
                    printf("HeapIndex %d, Content %x\n".ptr, si, heapPtr.heapData[cast(uint) si]);
                }
            }
        // debug if (!__ctfe) writeln("ip: ", ip);
        const lw = (*byteCode)[ip];
        const uint hi = (*byteCode)[ip + 1];
        const int imm32c = *(cast(int*)&((*byteCode)[ip + 1]));
        ip += 2;

        // consider splitting the stackPointer in stackHigh and stackLow

        const uint opRefOffset = (lw >> 16) & 0xFFFF;
        const uint lhsOffset = hi & 0xFFFF;
        const uint rhsOffset = (hi >> 16) & 0xFFFF;

        auto lhsRef = (&framePtr[(lhsOffset / 4)]);
        auto rhs = (&framePtr[(rhsOffset / 4)]);
        auto lhsStackRef = (&framePtr[(opRefOffset / 4)]);
        auto opRef = &framePtr[(opRefOffset / 4)];

        if (!lw)
        { // Skip NOPS
            continue;
        }

        final switch (cast(LongInst)(lw & InstMask))
        {
        case LongInst.ImmAdd:
            {
                (*lhsStackRef) += imm32c;
            }
            break;

        case LongInst.ImmSub:
            {
                (*lhsStackRef) -= imm32c;
            }
            break;

        case LongInst.ImmMul:
            {
                (*lhsStackRef) *= imm32c;
            }
            break;

        case LongInst.ImmDiv:
            {
                (*lhsStackRef) /= imm32c;
            }
            break;

        case LongInst.ImmUdiv:
            {
                (*cast(ulong*)lhsStackRef) /= imm32c;
            }
            break;

        case LongInst.ImmAnd:
            {
                (*lhsStackRef) &= hi;
            }
            break;
        case LongInst.ImmAnd32:
            {
                *lhsStackRef = (cast(uint)*lhsStackRef) & hi;
            }
            break;
        case LongInst.ImmOr:
            {
                (*lhsStackRef) |= hi;
            }
            break;
        case LongInst.ImmXor:
            {
                (*lhsStackRef) ^= hi;
            }
            break;
        case LongInst.ImmXor32:
            {
                *lhsStackRef = (cast(uint)*lhsStackRef) ^ hi;
            }
            break;

        case LongInst.ImmLsh:
            {
                (*lhsStackRef) <<= hi;
            }
            break;
        case LongInst.ImmRsh:
            {
                (*lhsStackRef) >>>= hi;
            }
            break;

        case LongInst.ImmMod:
            {
                (*lhsStackRef) %= imm32c;
            }
            break;
        case LongInst.ImmUmod:
            {
                (*cast(ulong*)lhsStackRef) %= imm32c;
            }
            break;

        case LongInst.SetImm8:
            {
                (*lhsStackRef) = hi;
                assert(hi <= ubyte.max);
            }
            break;
        case LongInst.SetImm32:
            {
                (*lhsStackRef) = hi;
            }
            break;
        case LongInst.SetHighImm32:
            {
                *lhsStackRef = (*lhsStackRef & 0x00_00_00_00_FF_FF_FF_FF) | (ulong(hi) << 32UL);
            }
            break;
        case LongInst.ImmEq:
            {
                if ((*lhsStackRef) == imm32c)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }
            }
            break;
        case LongInst.ImmNeq:
            {
                if ((*lhsStackRef) != imm32c)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }
            }
            break;

        case LongInst.ImmUlt:
            {
                if ((cast(ulong)(*lhsStackRef)) < cast(uint)hi)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }
            }
            break;
        case LongInst.ImmUgt:
            {
                if ((cast(ulong)(*lhsStackRef)) > cast(uint)hi)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }
            }
            break;
        case LongInst.ImmUle:
            {
                if ((cast(ulong)(*lhsStackRef)) <= cast(uint)hi)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }
            }
            break;
        case LongInst.ImmUge:
            {
                if ((cast(ulong)(*lhsStackRef)) >= cast(uint)hi)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }
            }
            break;

        case LongInst.ImmLt:
            {
                if ((*lhsStackRef) < imm32c)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }
            }
            break;
        case LongInst.ImmGt:
            {
                if (cast()(*lhsStackRef) > imm32c)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }
            }
            break;
        case LongInst.ImmLe:
            {
                if ((*lhsStackRef) <= imm32c)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }
            }
            break;
        case LongInst.ImmGe:
            {
                if ((*lhsStackRef) >= imm32c)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }
            }
            break;

        case LongInst.Add:
            {
                (*lhsRef) += *rhs;
            }
            break;
        case LongInst.Sub:
            {
                (*lhsRef) -= *rhs;
            }
            break;
        case LongInst.Mul:
            {
                (*lhsRef) *= *rhs;
            }
            break;
        case LongInst.Div:
            {
                (*lhsRef) /= *rhs;
            }
            break;
        case LongInst.Udiv:
            {
                (*cast(ulong*)lhsRef) /= (*cast(ulong*)rhs);
            }
            break;
        case LongInst.And:
            {
                (*lhsRef) &= *rhs;
            }
            break;
        case LongInst.And32:
            {
               (*lhsRef) = (cast(uint) *lhsRef) & (cast(uint)*rhs);
            }
            break;
        case LongInst.Or:
            {
                (*lhsRef) |= *rhs;
            }
            break;
        case LongInst.Xor32:
            {
                (*lhsRef) = (cast(uint) *lhsRef) ^ (cast(uint)*rhs);
            }
            break;
        case LongInst.Xor:
            {
                (*lhsRef) ^= *rhs;
            }
            break;

        case LongInst.Lsh:
            {
                (*lhsRef) <<= *rhs;
            }
            break;
        case LongInst.Rsh:
            {
                (*lhsRef) >>>= *rhs;
            }
            break;
        case LongInst.Mod:
            {
                (*lhsRef) %= *rhs;
            }
            break;
        case LongInst.Umod:
            {
                (*cast(ulong*)lhsRef) %= (*cast(ulong*)rhs);
            }
            break;
        case LongInst.FGt32 :
            {
                uint _lhs = *lhsRef & uint.max;
                float flhs = *cast(float*)&_lhs;
                uint _rhs = *rhs & uint.max;
                float frhs = *cast(float*)&_rhs;

                cond = flhs > frhs;
            }
            break;
        case LongInst.FGe32 :
            {
                uint _lhs = *lhsRef & uint.max;
                float flhs = *cast(float*)&_lhs;
                uint _rhs = *rhs & uint.max;
                float frhs = *cast(float*)&_rhs;

                cond = flhs >= frhs;
            }
            break;
        case LongInst.FEq32 :
            {
                uint _lhs = *lhsRef & uint.max;
                float flhs = *cast(float*)&_lhs;
                uint _rhs = *rhs & uint.max;
                float frhs = *cast(float*)&_rhs;

                cond = flhs == frhs;
            }
            break;
        case LongInst.FNeq32 :
            {
                uint _lhs = *lhsRef & uint.max;
                float flhs = *cast(float*)&_lhs;
                uint _rhs = *rhs & uint.max;
                float frhs = *cast(float*)&_rhs;

                cond = flhs != frhs;
            }
            break;
        case LongInst.FLt32 :
            {
                uint _lhs = *lhsRef & uint.max;
                float flhs = *cast(float*)&_lhs;
                uint _rhs = *rhs & uint.max;
                float frhs = *cast(float*)&_rhs;

                cond = flhs < frhs;
            }
            break;
        case LongInst.FLe32 :
            {
                uint _lhs = *lhsRef & uint.max;
                float flhs = *cast(float*)&_lhs;
                uint _rhs = *rhs & uint.max;
                float frhs = *cast(float*)&_rhs;

                cond = flhs <= frhs;
            }
            break;
        case LongInst.F32ToF64 :
            {
                uint rhs32 = (*rhs & uint.max);
                float frhs = *cast(float*)&rhs32;
                double flhs = frhs;
                *lhsRef = *cast(long*)&flhs;
            }
            break;
        case LongInst.F32ToI :
            {
                uint rhs32 = (*rhs & uint.max);
                float frhs = *cast(float*)&rhs32;
                uint _lhs = cast(int)frhs;
                *lhsRef = _lhs;
            }
            break;
        case LongInst.IToF32 :
            {
                float frhs = *rhs;
                uint _lhs = *cast(uint*)&frhs;
                *lhsRef = _lhs;
            }
            break;

        case LongInst.FAdd32:
            {
                uint _lhs = *lhsRef & uint.max;
                float flhs = *cast(float*)&_lhs;
                uint _rhs = *rhs & uint.max;
                float frhs = *cast(float*)&_rhs;

                flhs += frhs;

                _lhs = *cast(uint*)&flhs;
                *lhsRef = _lhs;
            }
            break;
        case LongInst.FSub32:
            {
                uint _lhs = *lhsRef & uint.max;
                float flhs = *cast(float*)&_lhs;
                uint _rhs = *rhs & uint.max;
                float frhs = *cast(float*)&_rhs;

                flhs -= frhs;

                _lhs = *cast(uint*)&flhs;
                *lhsRef = _lhs;
            }
            break;
        case LongInst.FMul32:
            {
                uint _lhs = *lhsRef & uint.max;
                float flhs = *cast(float*)&_lhs;
                uint _rhs = *rhs & uint.max;
                float frhs = *cast(float*)&_rhs;

                flhs *= frhs;

                _lhs = *cast(uint*)&flhs;
                *lhsRef = _lhs;
            }
            break;
        case LongInst.FDiv32:
            {
                uint _lhs = *lhsRef & uint.max;
                float flhs = *cast(float*)&_lhs;
                uint _rhs = *rhs & uint.max;
                float frhs = *cast(float*)&_rhs;

                flhs /= frhs;

                _lhs = *cast(uint*)&flhs;
                *lhsRef = _lhs;
            }
            break;
        case LongInst.FMod32:
            {
                uint _lhs = *lhsRef & uint.max;
                float flhs = *cast(float*)&_lhs;
                uint _rhs = *rhs & uint.max;
                float frhs = *cast(float*)&_rhs;

                flhs %= frhs;

                _lhs = *cast(uint*)&flhs;
                *lhsRef = _lhs;
            }
            break;
        case LongInst.FEq64 :
            {
                ulong _lhs = *lhsRef;
                double flhs = *cast(double*)&_lhs;
                ulong _rhs = *rhs;
                double frhs = *cast(double*)&_rhs;

                cond = flhs == frhs;
            }
            break;
        case LongInst.FNeq64 :
            {
                ulong _lhs = *lhsRef;
                double flhs = *cast(double*)&_lhs;
                ulong _rhs = *rhs;
                double frhs = *cast(double*)&_rhs;

                cond = flhs < frhs;
            }
            break;
        case LongInst.FLt64 :
            {
                ulong _lhs = *lhsRef;
                double flhs = *cast(double*)&_lhs;
                ulong _rhs = *rhs;
                double frhs = *cast(double*)&_rhs;

                cond = flhs < frhs;
            }
            break;
        case LongInst.FLe64 :
            {
                ulong _lhs = *lhsRef;
                double flhs = *cast(double*)&_lhs;
                ulong _rhs = *rhs;
                double frhs = *cast(double*)&_rhs;

                cond = flhs <= frhs;
            }
            break;
        case LongInst.FGt64 :
            {
                ulong _lhs = *lhsRef;
                double flhs = *cast(double*)&_lhs;
                ulong _rhs = *rhs;
                double frhs = *cast(double*)&_rhs;

                cond = flhs > frhs;
            }
            break;
        case LongInst.FGe64 :
            {
                ulong _lhs = *lhsRef;
                double flhs = *cast(double*)&_lhs;
                ulong _rhs = *rhs;
                double frhs = *cast(double*)&_rhs;

                cond = flhs >= frhs;
            }
            break;

        case LongInst.F64ToF32 :
            {
                double frhs = *cast(double*)rhs;
                float flhs = frhs;
                *lhsRef = *cast(uint*)&flhs;
            }
            break;
        case LongInst.F64ToI :
            {
                float frhs = *cast(double*)rhs;
                *lhsRef = cast(long)frhs;
            }
            break;
        case LongInst.IToF64 :
            {
                double frhs = cast(double)*rhs;
                *lhsRef = *cast(long*)&frhs;
            }
            break;

        case LongInst.FAdd64:
            {
                ulong _lhs = *lhsRef;
                double flhs = *cast(double*)&_lhs;
                ulong _rhs = *rhs;
                double frhs = *cast(double*)&_rhs;

                flhs += frhs;

                _lhs = *cast(ulong*)&flhs;
                *lhsRef = _lhs;
            }
            break;
        case LongInst.FSub64:
            {
                ulong _lhs = *lhsRef;
                double flhs = *cast(double*)&_lhs;
                ulong _rhs = *rhs;
                double frhs = *cast(double*)&_rhs;

                flhs -= frhs;

                _lhs = *cast(ulong*)&flhs;
                *lhsRef = _lhs;
            }
            break;
        case LongInst.FMul64:
            {
                ulong _lhs = *lhsRef;
                double flhs = *cast(double*)&_lhs;
                ulong _rhs = *rhs;
                double frhs = *cast(double*)&_rhs;

                flhs *= frhs;

                _lhs = *cast(ulong*)&flhs;
                *lhsRef = _lhs;
            }
            break;
        case LongInst.FDiv64:
            {
                ulong _lhs = *lhsRef;
                double flhs = *cast(double*)&_lhs;
                ulong _rhs = *rhs;
                double frhs = *cast(double*)&_rhs;

                flhs /= frhs;

                _lhs = *cast(ulong*)&flhs;
                *(cast(ulong*)lhsRef) = _lhs;
            }
            break;
        case LongInst.FMod64:
            {
                ulong _lhs = *lhsRef;
                double flhs = *cast(double*)&_lhs;
                ulong _rhs = *rhs;
                double frhs = *cast(double*)&_rhs;

                flhs %= frhs;

                _lhs = *cast(ulong*)&flhs;
                *(cast(ulong*)lhsRef) = _lhs;
            }
            break;

        case LongInst.Assert:
            {
                debug
                {
	            //writeln((*byteCode).printInstructions(stackMap));

                    writeln("ip:", ip, "Assert(&", opRefOffset, " *",  *opRef, ")");
                }
                if (*opRef == 0)
                {
                    BCValue retval = imm32(hi);
                    retval.vType = BCValueType.Error;

                    static if (is(RetainedError))
                    {
                        if (hi - 1 < bc_max_errors)
                        {
                            auto err = errors[cast(uint)(hi - 1)];

                            *ev1 = imm32(framePtr[err.v1.addr / 4] & uint.max);
                            *ev2 = imm32(framePtr[err.v2.addr / 4] & uint.max);
                            *ev3 = imm32(framePtr[err.v3.addr / 4] & uint.max);
                            *ev4 = imm32(framePtr[err.v4.addr / 4] & uint.max);
                        }
                    }
                    return retval;

                }
            }
            break;
        case LongInst.Eq:
            {
                if ((*lhsRef) == *rhs)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }

            }
            break;

        case LongInst.Neq:
            {
                if ((*lhsRef) != *rhs)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }
            }
            break;

        case LongInst.Set:
            {
                (*lhsRef) = *rhs;
            }
            break;

        case LongInst.Ult:
            {
                if ((cast(ulong)(*lhsRef)) < (cast(ulong)*rhs))
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }
            }
            break;
        case LongInst.Ugt:
            {
                if (cast(ulong)(*lhsRef) > cast(ulong)*rhs)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }
            }
            break;
        case LongInst.Ule:
            {
                if ((cast(ulong)(*lhsRef)) <= (cast(ulong)*rhs))
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }
            }
            break;
        case LongInst.Uge:
            {
                if ((cast(ulong)(*lhsRef)) >= (cast(ulong)*rhs))
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }

            }
            break;

        case LongInst.Lt:
            {
                if ((*lhsRef) < *rhs)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }

            }
            break;
        case LongInst.Gt:
            {
                if ((*lhsRef) > *rhs)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }
            }
            break;
        case LongInst.Le:
            {
                if ((*lhsRef) <= *rhs)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }

            }
            break;
        case LongInst.Ge:
            {
                if ((*lhsRef) >= *rhs)
                {
                    cond = true;
                }
                else
                {
                    cond = false;
                }

            }
            break;

        case LongInst.PushCatch:
            {
                debug
                {
                    printf("PushCatch is executing\n");
                }
                Catch catch_ = Catch(ip, callDepth);
                catches ~= catch_;
            }
            break;

            case LongInst.PopCatch:
            {
                debug { if (!__ctfe) writeln("Poping a Catch"); }
                catches = catches[0 .. $-1];
            }
            break;

            case LongInst.Throw:
            {
                uint expP = ((*opRef) & uint.max);
                debug { if (!__ctfe) writeln("*opRef: ", expP); } 
                auto expTypeIdx = heapPtr.heapData[expP + ClassMetaData.TypeIdIdxOffset];
                auto expValue = BCValue(HeapAddr(expP), BCType(BCTypeEnum.Class, expTypeIdx));
                expValue.vType = BCValueType.Exception;

                cRetval = expValue;
                if (HandleExp())
                    return cRetval;
            }
            break;

        case LongInst.Jmp:
            {
                ip = hi;
            }
            break;
        case LongInst.JmpNZ:
            {
                if ((*lhsStackRef) != 0)
                {
                    ip = hi;
                }
            }
            break;
        case LongInst.JmpZ:
            {
                if ((*lhsStackRef) == 0)
                {
                    ip = hi;
                }
            }
            break;
        case LongInst.JmpFalse:
            {
                if (!cond)
                {
                    ip = (hi);
                }
            }
            break;
        case LongInst.JmpTrue:
            {
                if (cond)
                {
                    ip = (hi);
                }
            }
            break;

        case LongInst.HeapLoad8:
            {
                assert(*rhs, "trying to deref null pointer inLine: " ~ itos(lastLine));
                (*lhsRef) = heapPtr.heapData[*rhs];
                debug
                {
                    import std.stdio;
                    writeln("Loaded[",*rhs,"] = ",*lhsRef);
                }
            }
            break;
        case LongInst.HeapStore8:
            {
                assert(*lhsRef, "trying to deref null pointer SP[" ~ itos(cast(int)((lhsRef - &framePtr[0])*4)) ~ "] at : &" ~ itos (ip - 2));
                heapPtr.heapData[*lhsRef] = ((*rhs) & 0xFF);
                debug
                {
                    import std.stdio;
                    if (!__ctfe)
                    {
                        writeln(ip,":Store[",*lhsRef,"] = ",*rhs & uint.max);
                    }
                }
            }
            break;

            case LongInst.HeapLoad16:
            {
                assert(*rhs, "trying to deref null pointer inLine: " ~ itos(lastLine));
                const addr = *lhsRef;
                (*lhsRef) =  heapPtr.heapData[addr]
                          | (heapPtr.heapData[addr + 1] << 8);

                debug
                {
                    import std.stdio;
                    writeln("Loaded[",*rhs,"] = ",*lhsRef);
                }
            }
            break;
            case LongInst.HeapStore16:
            {
                assert(*lhsRef, "trying to deref null pointer SP[" ~ itos(cast(int)((lhsRef - &framePtr[0])*4)) ~ "] at : &" ~ itos (ip - 2));
                const addr = *lhsRef;
                heapPtr.heapData[addr    ] = ((*rhs     ) & 0xFF);
                heapPtr.heapData[addr + 1] = ((*rhs >> 8) & 0xFF);
                debug
                {
                    import std.stdio;
                    if (!__ctfe)
                    {
                        writeln(ip,":Store[",*lhsRef,"] = ",*rhs & uint.max);
                    }
                }
            }
            break;

            case LongInst.HeapLoad32:
            {
                const addr = cast(uint) *rhs;
                if (isStackAddress(addr))
                {
                    auto sAddr = toStackOffset(addr);
                    (*lhsRef) = stackPtr[sAddr / 4];
                    continue;
                }


                assert(*rhs, "trying to deref null pointer inLine: " ~ itos(lastLine));
                (*lhsRef) = loadu32(heapPtr.heapData.ptr + addr);
                debug
                {
                    import std.stdio;
                    writeln("Loaded[",*rhs,"] = ",*lhsRef);
                }
            }
            break;
        case LongInst.HeapStore32:
            {
                assert(*lhsRef, "trying to deref null pointer SP[" ~ itos(cast(int)((lhsRef - &framePtr[0])*4)) ~ "] at : &" ~ itos (ip - 2));

                const addr = cast(uint) *lhsRef;
                if (isStackAddress(addr))
                {
                    auto sAddr = toStackOffset(addr);
                    stackPtr[sAddr / 4] = ((*rhs) & uint.max);
                    continue;
                }

                storeu32((&heapPtr.heapData[*lhsRef]),  (*rhs) & uint.max);

                debug
                {
                    import std.stdio;
                    if (!__ctfe)
                    {
                        writeln(ip,":Store[",*lhsRef,"] = ",*rhs & uint.max);
                    }
                }
            }
            break;

        case LongInst.HeapLoad64:
            {
                assert(*rhs, "trying to deref null pointer ");
                const addr = *rhs;
                (*lhsRef) =       loadu32(&heapPtr.heapData[addr])
                          | ulong(loadu32(&heapPtr.heapData[addr + 4])) << 32UL;

                debug
                {
                    import std.stdio;
                    if (!__ctfe)
                    {
                        writeln(ip,":Loaded[",*rhs,"] = ",*lhsRef);
                    }
                }
            }
            break;

        case LongInst.HeapStore64:
            {
                assert(*lhsRef, "trying to deref null pointer SP[" ~ itos(cast(int)(lhsRef - &framePtr[0])*4) ~ "] at : &" ~ itos (ip - 2));
                const heapOffset = *lhsRef;
                assert(heapOffset < heapPtr.heapSize, "Store out of range at ip: &" ~ itos(ip - 2) ~ " atLine: " ~ itos(lastLine));
                auto basePtr = (heapPtr.heapData.ptr + *lhsRef);
                const addr = *lhsRef;
                const value = *rhs;

                storeu32(&heapPtr.heapData[addr],     value & uint.max);
                storeu32(&heapPtr.heapData[addr + 4], cast(uint)(value >> 32));
            }
            break;

        case LongInst.Ret32:
            {
                debug (bc)
                    if (!__ctfe)
                    {
                        import std.stdio;

                        writeln("Ret32 SP[", lhsOffset, "] (", *opRef, ")\n");
                    }
                cRetval = imm32(*opRef & uint.max);
                if (Return()) return cRetval;
            }
            break;
        case LongInst.RetS32:
            {
                debug (bc)
                    if (!__ctfe)
                {
                    import std.stdio;
                    writeln("Ret32 SP[", lhsOffset, "] (", *opRef, ")\n");
                }
                cRetval = imm32(*opRef & uint.max, true);
                if (Return()) return cRetval;
            }
            break;
        case LongInst.RetS64:
            {
                cRetval = BCValue(Imm64(*opRef, true));
                if (Return()) return cRetval;
            }
            break;

        case LongInst.Ret64:
            {
                cRetval = BCValue(Imm64(*opRef, false));
                if (Return()) return cRetval;
            }
            break;
        case LongInst.RelJmp:
            {
                ip += (cast(short)(lw >> 16)) - 2;
            }
            break;
        case LongInst.PrintValue:
            {
                if (!__ctfe)
                {
                    if ((lw & ushort.max) >> 8)
                    {
                        auto offset = *opRef;
                        auto length = heapPtr.heapData[offset];
                        auto string_start = cast(char*)&heapPtr.heapData[offset + 1];
                        printf("Printing string: '%.*s'\n", length, string_start);
                    }
                    else
                    {
                        printf("Addr: %lu, Value %lx\n", (opRef - framePtr) * 4, *opRef);
                    }
                }
            }
            break;
        case LongInst.Not:
            {
                (*opRef) = ~(*opRef);
            }
            break;
        case LongInst.Flg:
            {
                (*opRef) = cond;
            }
            break;

        case LongInst.BuiltinCall:
            {
                assert(0, "Unsupported right now: BCBuiltin");
            }
        case LongInst.Cat:
            {
                if (*rhs == 0 && *lhsRef == 0)
                {
                    *lhsStackRef = 0;
                }
                else
                {
                    const elemSize = (lw >> 8) & 255;
                    const uint _lhs =  *lhsRef & uint.max;
                    const uint _rhs =  *rhs & uint.max;

                    const llbasep = &heapPtr.heapData[_lhs + SliceDescriptor.LengthOffset];
                    const rlbasep = &heapPtr.heapData[_rhs + SliceDescriptor.LengthOffset];

                    const lhs_length = _lhs ? loadu32(llbasep) : 0;
                    const rhs_length = _rhs ? loadu32(rlbasep) : 0;

                    if (const newLength = lhs_length + rhs_length)
                    {
                        // TODO if lhs.capacity bla bla
                        const lhsBase = loadu32(&heapPtr.heapData[_lhs + SliceDescriptor.BaseOffset]);
                        const rhsBase = loadu32(&heapPtr.heapData[_rhs + SliceDescriptor.BaseOffset]);

                        const resultPtr = heapPtr.heapSize;

                        const resultLengthP = resultPtr + SliceDescriptor.LengthOffset;
                        const resultBaseP   = resultPtr + SliceDescriptor.BaseOffset;
                        const resultBase    = resultPtr + SliceDescriptor.Size;

                        const allocSize = (newLength * elemSize) + SliceDescriptor.Size;
                        const heapSize  = heapPtr.heapSize;

                        if(heapSize + allocSize  >= heapPtr.heapMax)
                        {
                            // we will now resize the heap to 8 times its former size
                            const newHeapMax =
                                ((allocSize < heapPtr.heapMax * 4) ?
                                    heapPtr.heapMax * 8 :
                                    align4(cast(uint)(heapPtr.heapMax + allocSize)) * 4);

                            if (newHeapMax >= 2 ^^ 31)
                                assert(0, "!!! HEAP OVERFLOW !!!");

                            auto newHeap = new ubyte[](newHeapMax);
                            assert(newHeap && newHeap.ptr && newHeapMax > heapSize);
                            newHeap[0 .. heapSize] = heapPtr.heapData[0 .. heapSize];
                            if (!__ctfe) heapPtr.heapData.destroy();

                            heapPtr.heapData = newHeap;
                            heapPtr.heapMax = newHeapMax;

                        }

                        heapPtr.heapSize += allocSize;

                        const scaled_lhs_length = (lhs_length * elemSize);
                        const scaled_rhs_length = (rhs_length * elemSize);
                        const result_lhs_end    = resultBase + scaled_lhs_length;

                        storeu32(&heapPtr.heapData[resultBaseP],  resultBase);
                        storeu32(&heapPtr.heapData[resultLengthP], newLength);

                        heapPtr.heapData[resultBase .. result_lhs_end] =
                            heapPtr.heapData[lhsBase .. lhsBase + scaled_lhs_length];

                        heapPtr.heapData[result_lhs_end ..  result_lhs_end + scaled_rhs_length] =
                            heapPtr.heapData[rhsBase .. rhsBase + scaled_rhs_length];

                        *lhsStackRef = resultPtr;
                    }
                }
            }
            break;

        case LongInst.Call:
            {
                assert(functions, "When calling functions you need functions to call");
                auto call = calls[uint((*rhs & uint.max)) - 1];
                auto returnAddr = ReturnAddr(ip, fnId, call.callerSp, lhsRef);

                uint fn = (call.fn.vType == BCValueType.Immediate ?
                    call.fn.imm32 :
                    framePtr[call.fn.stackAddr.addr / 4]
                ) & uint.max;

                fnId = fn - 1;

                auto stackOffsetCall = stackOffset + call.callerSp;
                auto newStack = framePtr + (call.callerSp / 4);

                if (fn == skipFn)
                    continue;


                if (!__ctfe)
                {
                    debug writeln("call.fn = ", call.fn);
                    debug writeln("fn = ", fn);
                    debug writeln((functions + fn - 1).byteCode.printInstructions);
                    debug writeln("stackOffsetCall: ", stackOffsetCall);
                    debug writeln("call.args = ", call.args);
                }


                foreach(size_t i,ref arg;call.args)
                {
                    const argOffset_ = (i * 1) + 1;
                    if(isStackValueOrParameter(arg))
                    {
                            newStack[argOffset_] = framePtr[arg.stackAddr.addr / 4];
                    }
                    else if (arg.vType == BCValueType.Immediate)
                    {
                        newStack[argOffset_] = arg.imm64;
                    }
                    else
                    {
                        assert(0, "Argument " ~ itos(cast(int)i) ~" ValueType unhandeled: " ~ enumToString(arg.vType));
                    }
                }

                debug { if (!__ctfe) writeln("Stack after pushing: ", newStack[0 .. 64]); }

                if (callDepth++ == max_call_depth)
                {
                        BCValue bailoutValue;
                        bailoutValue.vType = BCValueType.Bailout;
                        bailoutValue.imm32.imm32 = 2000;
                        return bailoutValue;
                }
                {
                    returnAddrs[n_return_addrs++] = returnAddr;
                    framePtr = framePtr + (call.callerSp / 4);
                    byteCode = getCodeForId(cast(int)(fn - 1), functions);
                    ip = 4;
                }
/+
                auto cRetval = interpret_(fn - 1,
                    callArgs[0 .. call.args.length], heapPtr, functions, calls, ev1, ev2, ev3, ev4, errors, stack, catches, stackMap, stackOffsetCall);
+/
        LreturnTo:
            }
            break;

        case LongInst.Alloc:
            {
                const allocSize = *rhs;
                const heapSize = heapPtr.heapSize;
                // T(1) << bsr(val)
                static uint nextPow2(uint n)
                {
                    import core.bitop;
                    return (1 << (bsr(n) + 1));
                }
                if(heapSize + allocSize  >= heapPtr.heapMax)
                {
                    auto newHeapMax =
                        ((allocSize < heapPtr.heapMax * 1.6) ?
                            nextPow2(cast(uint)(heapPtr.heapMax * 1.6)) :
                            nextPow2(cast(uint)(heapPtr.heapMax + allocSize * 1.3)));

                    // our last try to avoid to the heap overflow!
                    if (newHeapMax > maxHeapAddress && (heapSize + allocSize) <= maxHeapAddress)
                    {
                        newHeapMax = maxHeapAddress;
                    }
                    //if (!__ctfe) printf("newHeapMax: %u\n", newHeapMax);
                    if (newHeapMax > maxHeapAddress || newHeapMax < heapPtr.heapMax)
                        assert(0, "!!! HEAP OVERFLOW !!!");

                    auto newHeap = new ubyte[](newHeapMax);

                    assert(newHeap && newHeap.ptr);
                    assert(newHeapMax > heapSize);
                    newHeap[0 .. heapSize] = heapPtr.heapData[0 .. heapSize];
                    if (!__ctfe) heapPtr.heapData.destroy();

                    heapPtr.heapData = newHeap;
                    heapPtr.heapMax = newHeapMax;
                }

                *lhsRef = heapSize;
                heapPtr.heapSize += allocSize;

                debug
                {
                    if (!__ctfe)
                    {
                        printf("Alloc(#%llu) = &%lld\n", allocSize, *lhsRef);
                    }
                }

            }
            break;
        case LongInst.LoadFramePointer:
            {
                // lets compute the offset from the beginning of the stack
                const uint FP = ((framePtr - &stack[0]) & uint.max) | stackAddrMask;
                (*lhsStackRef) = (FP + imm32c);
            }
            break;
        case LongInst.MemCpy:
            {
                auto cpySize = cast(uint) *opRef;
                auto cpySrc = cast(uint) *rhs;
                auto cpyDst = cast(uint) *lhsRef;
                debug
                {
                    writefln("%d: MemCpy(dst: &Heap[%d], src: &Heap[%d], size: #%d", (ip-2), cpyDst, cpySrc, cpySize);
                }
                if (cpySrc != cpyDst && cpySize != 0)
                {
                    // assert(cpySize, "cpySize == 0");
                    assert(cpySrc, "cpySrc == 0" ~ " inLine: " ~ itos(lastLine));

                    assert(cpyDst, "cpyDst == 0" ~ " inLine: " ~ itos(lastLine));

                    assert(cpyDst >= cpySrc + cpySize || cpyDst + cpySize <= cpySrc, "Overlapping MemCpy is not supported --- src: " ~ itos(cpySrc)
                        ~ " dst: " ~ itos(cpyDst) ~ " size: " ~ itos(cpySize));
                    heapPtr.heapData[cpyDst .. cpyDst + cpySize] = heapPtr.heapData[cpySrc .. cpySrc + cpySize];
                }
            }
            break;

        case LongInst.Comment:
            {
                if (!__ctfe) lastComment = cast(const char*) (byteCode.ptr + ip);
                ip += align4(hi) / 4;
            }
            break;
        case LongInst.StrEq:
            {
                cond = false;

                auto _lhs = cast(uint)*lhsRef;
                auto _rhs = cast(uint)*rhs;

                assert(_lhs && _rhs, "trying to deref nullPointers");
                if (_lhs == _rhs)
                {
                    cond = true;
                }
                else
                {
                    immutable lhUlength = heapPtr.heapData[_lhs + SliceDescriptor.LengthOffset];
                    immutable rhUlength = heapPtr.heapData[_rhs + SliceDescriptor.LengthOffset];
                    if (lhUlength == rhUlength)
                    {
                        immutable lhsBase = heapPtr.heapData[_lhs + SliceDescriptor.BaseOffset];
                        immutable rhsBase = heapPtr.heapData[_rhs + SliceDescriptor.BaseOffset];
                        cond = true;
                        foreach (i; 0 .. lhUlength)
                        {
                            if (heapPtr.heapData[rhsBase + i] != heapPtr.heapData[lhsBase + i])
                            {
                                cond = false;
                                break;
                            }
                        }
                    }
                }
            }
            break;
        case LongInst.File :
            {
                goto case LongInst.Comment;
            }
        case LongInst.Line :
            {
                uint breakingOn;
                uint line = hi;
                lastLine = line;
                foreach(bl;breakLines)
                {
                    if (line == bl)
                    {
                        debug
                        if (!__ctfe)
                        {
                            import std.stdio;
                            writeln("breaking at: ", ip-2);

                        }
                        paused = true;
                    }
                    break;
                }
            }
            break;
        }
    }
    Lbailout :
    BCValue bailoutValue;
    bailoutValue.vType = BCValueType.Bailout;
    return bailoutValue;

    debug (ctfe)
    {
        assert(0, "I would be surprised if we got here -- withBC: " ~ (*byteCode).printInstructions);
    }
}

unittest
{
    auto testRelJmp()
    {
        BCGen gen;
        with (gen)
        {
            Initialize();
            auto result = genTemporary(i32Type);
            Set(result, BCValue(Imm32(2)));
            auto evalCond = genLabel();
            Eq3(BCValue.init, result, BCValue(Imm32(12)));
            auto cndJmp = beginCndJmp();
            Ret(result);
            endCndJmp(cndJmp, genLabel());
            Add3(result, result, BCValue(Imm32(1)));
            Jmp(evalCond);
            Finalize();
            return gen;
        }
    }


    // Fact(n) = (n > 1 ? ( n*(n-1) * Fact(n-2) ) : 1);
    auto testFact()
    {
        BCGen gen;
        with (gen)
        {
            Initialize();
            {
                auto n = genParameter(i32Type, "n");
                beginFunction(0);
                {
                    auto result = genLocal(i32Type, "result");
                    Gt3(BCValue.init, n, imm32(1, true));
                    auto j_n_lt_1 = beginCndJmp();
                    {
                        auto n_sub_1 = genTemporary(i32Type);
                        Sub3(n_sub_1, n, imm32(1));
                        auto n_mul_n_sub_1 = genTemporary(i32Type);
                        Mul3(n_mul_n_sub_1, n, n_sub_1);
                        Sub3(n, n, imm32(2));

                        auto result_fact = genTemporary(i32Type);
                        Call(result_fact, imm32(1), [n]);

                        Mul3(result, n_mul_n_sub_1, result_fact);
                        Ret(result);
                    }
                    auto l_n_lt_1 = genLabel();
                    {
                        Set(result, imm32(1));
                        Ret(result);
                    }
                    endCndJmp(j_n_lt_1, l_n_lt_1);
                }
                endFunction();
            }
            Finalize();
            return gen;
        }
    }

    static assert(testFact().interpret([imm32(5)]) == imm32(120));
}
module dmd.dfa.utils;
import dmd.dfa.common;
import dmd.statement;
import dmd.expression;
import dmd.tokens;
import dmd.astenums;
import dmd.mtype;
import dmd.visitor;
import dmd.identifier;
import core.stdc.stdio;

//version = DebugJoinMeetOp;

bool isTypePointer(Type type)
{
    if (type is null)
        return false;

    switch (type.ty)
    {
    case TY.Tarray, TY.Taarray, TY.Tpointer, TY.Treference, TY.Tfunction,
            TY.Tclass, TY.Tdelegate:
            return true;

    case TY.Tstruct:
        TypeStruct type2 = type.isTypeStruct();
        return type2 !is null ? type2.sym.hasPointerField : false;

    default:
        return false;
    }
}

bool isTyWithoutValue(TY ty)
{
    switch (ty)
    {
    case TY.Tnone, TY.Tvoid, TY.Tnoreturn:
        return true;

    default:
        return false;
    }
}

bool isEXPLiteral(EXP exp)
{
    switch (exp)
    {
    case EXP.null_, EXP.arrayLiteral, EXP.assocArrayLiteral, EXP.structLiteral,
            EXP.string_, EXP.this_, EXP.int64, EXP.float64, EXP.complex80,
            EXP.compoundLiteral, EXP.blit:
            return true;

    default:
        return false;
    }
}

bool isPointerMutable(StorageClass storedIn, Type from, Type viaType)
{
    if (!from.isTypePointer || isTyWithoutValue(from.ty))
        return false;
    else if ((storedIn & (STC.const_ | STC.immutable_)) != 0)
        return false;
    else if (!viaType.isMutable())
        return false;

    if (auto da = viaType.isTypeDArray)
    {
        if ((da.next.mod & (MODFlags.const_ | MODFlags.immutable_)) != 0)
            return false;
    }

    return true;
}

bool isIndexContextAA(IndexExp ie)
{
    if (ie is null || ie.e1 is null || ie.e1.type is null)
        return false;
    return ie.e1.type.toBasetype.isTypeAArray !is null;
}

int concatNullableResult(Type lhs, Type rhs)
{
    // T[] ~ T[]
    // T[] ~ T
    // T ~ T[]
    // T ~ T

    if (lhs.isStaticOrDynamicArray)
    {
        if (rhs.isStaticOrDynamicArray)
            return 1; // Depends on lhs and rhs
        return 2; // non-null
    }
    else if (rhs.isStaticOrDynamicArray)
        return 2;

    return 0; // Unknown
}

int equalityArgTypes(Type lhs, Type rhs)
{
    // struct
    // floating point
    // lhs && rhs    static, dyamic array
    // lhs && rhs    associative array
    // otherwise integral

    if (lhs.ty == Tstruct)
        return 1;
    else if (lhs.isFloating)
        return 2;

    const lhsSArray = lhs.isTypeSArray !is null, rhsSArray = rhs.isTypeSArray !is null;
    if (lhsSArray && rhsSArray)
        return 3;
    else if (lhsSArray)
        return 4;
    else if (rhsSArray)
        return 5;

    if (lhs.isTypeDArray || rhs.isTypeDArray)
        return 6;
    else if (lhs.ty == Taarray && rhs.ty == Taarray)
        return 7;
    else if (isTypePointer(lhs))
        return 8;
    else
        return 0;
}

DFAScope* findScopeHeadOfLabelStatement(DFACommon* dfaCommon, Identifier label)
{
    bool walkExpression(Expression e)
    {
        if (auto de = e.isDeclarationExp)
        {
            return de.declaration.isVarDeclaration !is null;
        }
        else if (auto be = e.isBinExp)
            return walkExpression(be.e1) || walkExpression(be.e2);
        else if (auto ue = e.isUnaExp)
            return walkExpression(ue.e1);
        else
            return false;
    }

    bool walkStatement(Statement s)
    {
        if (s is null)
            return false;

        with (STMT)
        {
            final switch (s.stmt)
            {
                // could prevent it
            case Exp:
                auto s2 = s.isExpStatement;
                return walkExpression(s2.exp);

                // could be this
            case Label:
                auto s2 = s.isLabelStatement;
                if (s2.ident is label)
                    return true;
                else
                    return walkStatement(s2.statement);

                // can be in this
            case Debug:
                auto s2 = s.isDebugStatement;
                return walkStatement(s2.statement);
            case Default:
                auto s2 = s.isDefaultStatement;
                return walkStatement(s2.statement);
            case CaseRange:
                auto s2 = s.isCaseRangeStatement;
                return walkStatement(s2.statement);
            case Case:
                auto s2 = s.isCaseStatement;
                return walkStatement(s2.statement);
            case Peel:
                auto s2 = s.isPeelStatement;
                return walkStatement(s2.s);
            case Forwarding:
                auto s2 = s.isForwardingStatement;
                return walkStatement(s2.statement);
            case If:
                auto s2 = s.isIfStatement;
                return walkStatement(s2.ifbody) || walkStatement(s2.elsebody);
            case Do:
                auto s2 = s.isDoStatement;
                return walkStatement(s2._body);
            case For:
                auto s2 = s.isForStatement;
                return walkStatement(s2._body);
            case Switch:
                auto s2 = s.isSwitchStatement;
                if (s2.cases !is null)
                {
                    foreach (c; *s2.cases)
                    {
                        if (walkStatement(c))
                            return true;
                    }
                }
                return false;
            case UnrolledLoop:
                auto s2 = s.isUnrolledLoopStatement;
                if (s2.statements !is null)
                {
                    foreach (s3; *s2.statements)
                    {
                        if (walkStatement(s3))
                            return true;
                    }
                }
                return false;
            case Scope:
                auto s2 = s.isScopeStatement;
                return walkStatement(s2.statement);
            case Compound:
            case CompoundDeclaration:
                auto s2 = s.isCompoundStatement;
                if (s2.statements !is null)
                {
                    foreach (s3; *s2.statements)
                    {
                        if (walkStatement(s3))
                            return true;
                    }
                }
                return false;

                // can't be in this
            case Error:
            case DtorExp:
            case Mixin:
            case CompoundAsm:
            case Synchronized:
            case With:
            case TryCatch:
            case TryFinally:
            case ScopeGuard:
            case While:
            case Conditional:
            case ForeachRange:
            case Foreach:
            case StaticForeach:
            case Pragma:
            case StaticAssert:
            case GotoDefault:
            case GotoCase:
            case SwitchError:
            case Return:
            case Break:
            case Continue:
            case Throw:
            case Goto:
            case Asm:
            case InlineAsm:
            case GccAsm:
            case Import:
                return false;
            }
        }
    }

    DFAScope* current = dfaCommon.currentDFAScope;

    while (current !is null)
    {
        if (current.compoundStatement !is null)
        {
            foreach (s; (*current.compoundStatement.statements)[current.inProgressCompoundStatement
                    .. $])
            {
                if (walkStatement(s))
                    return current;
            }
        }

        current = current.parent;
    }

    return null;
}

void meetConsequence(DFAConsequence* result, DFAConsequence* c1,
        DFAConsequence* c2, bool couldScopeNotHaveRan = false)
{
    void doOne(DFAConsequence* c)
    {
        version (DebugJoinMeetOp)
        {
            printf("meet one c1 %p %d %d %d\n", c.var, c.truthiness,
                    c.nullable, c.writeOnVarAtThisPoint);
            fflush(stdout);
        }

        result.invertedOnce = c.invertedOnce;
        result.writeOnVarAtThisPoint = c.writeOnVarAtThisPoint;
        result.truthiness = couldScopeNotHaveRan ? Truthiness.Unknown : c.truthiness;
        result.nullable = couldScopeNotHaveRan ? Nullable.Unknown : c.nullable;
    }

    void doMulti()
    {
        version (DebugJoinMeetOp)
        {
            printf("meet multi c1 %p %d %d %d\n", c1.var, c1.truthiness,
                    c1.nullable, c1.writeOnVarAtThisPoint);
            printf("meet multi c2 %p %d %d %d\n", c2.var, c2.truthiness,
                    c2.nullable, c2.writeOnVarAtThisPoint);
            fflush(stdout);
        }

        result.writeOnVarAtThisPoint = c1.writeOnVarAtThisPoint > c2.writeOnVarAtThisPoint
            ? c1.writeOnVarAtThisPoint : c2.writeOnVarAtThisPoint;

        result.truthiness = c2.truthiness == c1.truthiness ? c2.truthiness : Truthiness.Unknown;
        result.invertedOnce = result.truthiness == Truthiness.Unknown
            ? false : (c1.invertedOnce || c2.invertedOnce);

        result.truthiness = c1.truthiness < c2.truthiness ? c1.truthiness : c2.truthiness;
        if (result.truthiness == Truthiness.Maybe)
            result.truthiness = Truthiness.Unknown;
        result.nullable = c1.nullable < c2.nullable ? c1.nullable : c2.nullable;
    }

    const writeCount = result.var.writeCount;

    version (DebugJoinMeetOp)
    {
        printf("meet consequence %p %p %d %d\n", c1 !is null ? c1.var : null,
                c2 !is null ? c2.var : null, writeCount, couldScopeNotHaveRan);
        fflush(stdout);
    }

    if (c2 is null || c2.writeOnVarAtThisPoint < writeCount)
        doOne(c1);
    else
        doMulti;
}

// result and c1 may be the same consequence
void joinConsequence(DFAConsequence* result, DFAConsequence* c1, DFAConsequence* c2,
        DFAConsequence* rhsCtx, bool isC1Context, bool ignoreWriteCount = false,
        bool unknownAware = false)
{
    void doOne(DFAConsequence* c)
    {
        version (DebugJoinMeetOp)
        {
            printf("join one c1 %p %d %d %d\n", c.var, c.truthiness,
                    c.nullable, c.writeOnVarAtThisPoint);
            fflush(stdout);
        }

        result.invertedOnce = c.invertedOnce;
        result.truthiness = c.truthiness;
        result.nullable = c.nullable;
        result.writeOnVarAtThisPoint = c.writeOnVarAtThisPoint;

        result.maybe = c.maybe;
    }

    void doMulti(DFAConsequence* c2)
    {
        version (DebugJoinMeetOp)
        {
            printf("join multi c1 %p %d %d %d\n", c1.var, c1.truthiness,
                    c1.nullable, c1.writeOnVarAtThisPoint);
            printf("join multi c2 %p %d %d %d\n", c2.var, c2.truthiness,
                    c2.nullable, c2.writeOnVarAtThisPoint);
            fflush(stdout);
        }

        result.invertedOnce = c1.invertedOnce || c2.invertedOnce;
        result.writeOnVarAtThisPoint = c1.writeOnVarAtThisPoint < c2.writeOnVarAtThisPoint
            ? c2.writeOnVarAtThisPoint : c1.writeOnVarAtThisPoint;

        if (unknownAware && c1.truthiness == Truthiness.Unknown
                || c2.truthiness == Truthiness.Unknown)
            result.truthiness = Truthiness.Unknown;
        else
            result.truthiness = c1.truthiness < c2.truthiness ? c2.truthiness : c1.truthiness;

        if (unknownAware && c1.nullable == Nullable.Unknown || c2.nullable == Nullable.Unknown)
            result.nullable = Nullable.Unknown;
        else
            result.nullable = c1.nullable < c2.nullable ? c2.nullable : c1.nullable;

        result.maybe = c2.maybe;
    }

    const writeCount = result.var.writeCount;

    version (DebugJoinMeetOp)
    {
        printf("join consequence c1=%p, c2=%p, rhsCtx=%p, isC1Context=%d, writeCount=%d, ignoreWriteCount=%d\n",
                c1 !is null ? c1.var : null, c2 !is null ? c2.var : null, rhsCtx !is null
                ? rhsCtx.var : null, isC1Context, writeCount, ignoreWriteCount);
        fflush(stdout);
    }

    if (ignoreWriteCount)
    {
        if (c2 !is null)
            doMulti(c2);
        else
            doOne(c1);
    }
    else if (c2 !is null && c2.writeOnVarAtThisPoint >= writeCount)
    {
        if (c2.writeOnVarAtThisPoint < c1.writeOnVarAtThisPoint)
            doMulti(c2);
        else
            doOne(c2);
    }
    else
    {
        if (isC1Context && rhsCtx !is null && rhsCtx.writeOnVarAtThisPoint == writeCount
                && (rhsCtx.var is null || rhsCtx.var is c1.var))
        {
            if (rhsCtx.writeOnVarAtThisPoint < c1.writeOnVarAtThisPoint)
                doMulti(rhsCtx);
        }
        else
            doOne(c1);
    }
}

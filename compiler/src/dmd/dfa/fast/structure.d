/**
 * Structure and representation of the fast Data Flow Analysis engine.
 *
 * Copyright: Copyright (C) 1999-2026 by The D Language Foundation, All Rights Reserved
 * Authors:   $(LINK2 https://cattermole.co.nz, Richard (Rikki) Andrew Cattermole)
 * License:   $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/dfa/fast/structure.d, dfa/fast/structure.d)
 * Documentation: https://dlang.org/phobos/dmd_dfa_fast_structure.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/dfa/fast/structure.d
 */
module dmd.dfa.fast.structure;
import dmd.dfa.utils;
import dmd.common.outbuffer;
import dmd.declaration;
import dmd.statement;
import dmd.func;
import dmd.mtype;
import dmd.typesem;
import dmd.identifier;
import dmd.globals : dinteger_t;
import dmd.dsymbol;
import dmd.location;
import dmd.expression;
import dmd.astenums;
import dmd.id;
import core.stdc.stdio;

package static immutable PrintPipeText = "||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||";

void appendLoc(ref OutBuffer ob, ref const(Loc) loc)
{
    writeSourceLoc(ob, SourceLoc(loc), true, Loc.messageStyle);
}

alias PrintPrefixType = void delegate(const(char)*);

// Old compiler versions have bugs with their copy constructors.
// Don't try to save memory by using moving to cleanup.
// Only relevant for bootstrapping purposes.
// We also require that GC.inFinalizer to exist.
enum DFACleanup = __VERSION__ >= 2102;

//version = DebugJoinMeetOp;

/***********************************************************
 * The central context for a DFA run.
 *
 * This structure manages the memory allocator, holds references to global
 * variables (like return values), and tracks the current scope being analyzed.
 *
 * Performance Note:
 * It uses a custom `DFAAllocator` (bump-pointer allocator) to avoid the overhead
 * of the GC or standard `malloc` for the thousands of tiny nodes created during analysis.
 */
struct DFACommon
{
    DFAAllocator allocator;
    DFAScope* currentDFAScope;
    DFAScope* lastLoopyLabel;
    DFAScope* lastCatch;

    int sdepth, edepth;
    FuncDeclaration currentFunction;
    bool isCurrentFunctionClassConstructor;

    // Making these enum's instead of fields allows for significant performance gains
    enum debugIt = false;
    //enum debugIt = true;
    enum debugStructure = false;
    //enum debugStructure = true;
    enum debugUnknownAST = false;
    //enum debugUnknownAST = true;
    enum debugVerify = false; // Disable to improve performance

    private
    {
        DFAVar*[16] vars;
        DFAVar*[16] varPairs; // do not change, 16 is hardcoded in usage
        DFAObject*[16] objects;
        DFAObject*[16] objectPairs;
        DFAVar* returnVar;
        DFAVar* infiniteLifetimeVar;
        DFAVar* unknownVar;

        DFALabelState*[16] forwardLabels;
        DFACaseState*[16] caseEntries;
    }

    void printIfStructure(scope void delegate(ref OutBuffer ob,
            scope void delegate(const(char)*) prefix) del)
    {
        static if (debugStructure)
        {
            OutBuffer ob;

            void prefix(const(char)* pre)
            {
                printPrefix(ob, pre, sdepth, edepth);
            }

            del(ob, &prefix);

            if (ob.length > 0)
                printf(ob.peekChars);

            fflush(stdout);
        }
    }

    void printStructureln(const(char)[] text)
    {
        printStructure((ref OutBuffer ob, scope PrintPrefixType prefix) {
            ob.writestring(text);
            ob.writestring("\n");
        });
    }

    void printStructure(scope void delegate(ref OutBuffer ob,
            scope void delegate(const(char)*) prefix) del)
    {
        static if (debugStructure)
        {
            OutBuffer ob;

            void prefix(const(char)* pre)
            {
                printPrefix(ob, pre, sdepth, edepth);
            }

            prefix("");
            const prefixLength = ob.length;

            del(ob, &prefix);

            if (ob.length > prefixLength)
                printf(ob.peekChars);

            fflush(stdout);
        }
    }

    void printIfState(scope void delegate(ref OutBuffer ob, scope PrintPrefixType prefix) del)
    {
        static if (debugIt)
        {
            OutBuffer ob;

            void prefix(const(char)* pre)
            {
                printPrefix(ob, pre, sdepth, edepth);
            }

            del(ob, &prefix);

            if (ob.length > 0)
                printf(ob.peekChars);

            fflush(stdout);
        }
    }

    void printStateln(const(char)[] text)
    {
        printState((ref OutBuffer ob, scope PrintPrefixType prefix) {
            ob.writestring(text);
            ob.writestring("\n");
        });
    }

    void printState(scope void delegate(ref OutBuffer ob, scope PrintPrefixType prefix) del)
    {
        static if (debugIt)
        {
            OutBuffer ob;

            void prefix(const(char)* pre)
            {
                printPrefix(ob, pre, sdepth, edepth);
            }

            prefix("");
            const prefixLength = ob.length;

            del(ob, &prefix);

            if (ob.length > prefixLength)
                printf(ob.peekChars);

            fflush(stdout);
        }
    }

    void pushScope()
    {
        DFAScope* oldScope = currentDFAScope;
        currentDFAScope = allocator.makeScope(&this, oldScope);

        assert(currentDFAScope.parent !is currentDFAScope);
        assert(currentDFAScope.parent is oldScope);

        if (oldScope !is null)
        {
            oldScope.child = currentDFAScope;
            currentDFAScope.depth = oldScope.depth + 1;
            currentDFAScope.inConditional = oldScope.inConditional;
        }
        else
        {
            currentDFAScope.depth = 1;
        }
    }

    DFAScopeRef popScope()
    {
        DFAScopeRef ret;
        ret.sc = currentDFAScope;

        if (lastLoopyLabel is currentDFAScope)
            lastLoopyLabel = lastLoopyLabel.previousLoopyLabel;
        if (lastCatch is currentDFAScope)
            lastCatch = lastCatch.previousCatch;

        currentDFAScope = currentDFAScope.parent;
        ret.sc.parent = null;

        if (currentDFAScope !is null)
            currentDFAScope.child = null;
        return ret;
    }

    void setScopeAsLoopyLabel()
    {
        this.currentDFAScope.isLoopyLabel = true;
        this.currentDFAScope.previousLoopyLabel = this.lastLoopyLabel;
        lastLoopyLabel = this.currentDFAScope;
    }

    void setScopeAsCatch()
    {
        this.currentDFAScope.previousCatch = this.lastCatch;
        lastCatch = this.currentDFAScope;
    }

    DFAVar* findVariable(VarDeclaration vd, DFAVar* childOf = null)
    {
        if (vd is null)
            return null;

        DFAVar* ret;

        if (childOf is null)
        {
            DFAVar** bucket = &vars[(cast(size_t) cast(void*) vd) % vars.length];

            while (*bucket !is null && cast(void*)(*bucket).var < cast(void*) vd)
            {
                bucket = &(*bucket).next;
            }

            if (*bucket !is null && (*bucket).var is vd)
                return *bucket;

            ret = allocator.makeVar(vd);
            ret.next = *bucket;
            *bucket = ret;
        }
        else
            ret = allocator.makeVar(vd, childOf);

        if (vd.ident is Id.dollar)
        {
            // __dollar creates problems because it isn't a real variable
            // https://issues.dlang.org/show_bug.cgi?id=3326

            ret.unmodellable = true;
        }

        return ret;
    }

    DFAVar* findVariablePair(DFAVar* a, DFAVar* b)
    {
        if (a is null)
            return b;
        else if (b is null)
            return a;
        else if (a is b)
            return a;

        if (a > b)
        {
            DFAVar* temp = a;
            a = b;
            b = temp;
        }

        const a1 = (cast(size_t) a) % 0xF, b1 = (cast(size_t) b) % 0xF;
        const ab1 = (b1 << 4) | a1;
        const ab2 = ab1 % 16;

        DFAVar** bucket = &varPairs[ab2];

        while (*bucket !is null && cast(size_t)(*bucket).base1 < cast(size_t) a)
        {
            bucket = &(*bucket).next;
        }

        if (*bucket is a)
        {
            while ((*bucket).base1 is a && cast(size_t)(*bucket).base2 < cast(size_t) b)
            {
                bucket = &(*bucket).next;
            }
        }

        if (*bucket is null || (*bucket).base1 !is a || (*bucket).base2 !is b)
        {
            DFAVar* next = *bucket;
            *bucket = allocator.makeVar(null, null);
            (*bucket).haveInfiniteLifetime = a.haveInfiniteLifetime && b.haveInfiniteLifetime;
            (*bucket).mayBeGlobal = a.mayBeGlobal || b.mayBeGlobal;
            (*bucket).next = next;
        }

        return *bucket;
    }

    DFAVar* findDereferenceVar(DFAVar* childOf)
    {
        if (childOf is null)
            return null;

        if (childOf.dereferenceVar is null)
        {
            childOf.dereferenceVar = allocator.makeVar(null);
            childOf.dereferenceVar.base1 = childOf;
            childOf.dereferenceVar.haveInfiniteLifetime = childOf.haveInfiniteLifetime;
            childOf.dereferenceVar.mayBeGlobal = childOf.mayBeGlobal;
        }

        return childOf.dereferenceVar;
    }

    DFAVar* findIndexVar(DFAVar* childOf)
    {
        if (childOf is null)
            return null;

        if (childOf.indexVar is null)
        {
            childOf.indexVar = allocator.makeVar(null);
            childOf.indexVar.base1 = childOf;
            childOf.indexVar.isAnIndex = true;
            childOf.indexVar.haveInfiniteLifetime = childOf.haveInfiniteLifetime;
            childOf.indexVar.mayBeGlobal = childOf.mayBeGlobal;
        }

        return childOf.indexVar;
    }

    DFAVar* findAsSliceVar(DFAVar* childOf)
    {
        if (childOf is null)
            return null;

        if (childOf.asSliceVar is null)
        {
            childOf.asSliceVar = allocator.makeVar(null);
            childOf.asSliceVar.base1 = childOf;
            childOf.asSliceVar.haveInfiniteLifetime = childOf.haveInfiniteLifetime;
            childOf.asSliceVar.mayBeGlobal = childOf.mayBeGlobal;
        }

        return childOf.asSliceVar;
    }

    DFAVar* findSliceLengthVar(DFAVar* childOf)
    {
        if (childOf is null)
            return null;

        if (childOf.lengthVar is null)
        {
            childOf.lengthVar = allocator.makeVar(null);
            childOf.lengthVar.base1 = childOf;
            childOf.lengthVar.isTruthy = true;
            childOf.lengthVar.isLength = true;
            childOf.lengthVar.haveInfiniteLifetime = childOf.haveInfiniteLifetime;
            childOf.lengthVar.mayBeGlobal = childOf.mayBeGlobal;
        }

        return childOf.lengthVar;
    }

    DFAVar* findOffsetVar(dinteger_t offset, DFAVar* childOf)
    {
        if (childOf is null)
            return null;

        DFAVar** bucket = &childOf.childOffsetVars;

        while (*bucket !is null && (*bucket).offsetFromBase < offset)
        {
            bucket = &(*bucket).next;
        }

        if (*bucket !is null && (*bucket).offsetFromBase == offset)
            return *bucket;

        DFAVar* ret = allocator.makeVar(null);
        ret.base1 = childOf;
        ret.offsetFromBase = offset;
        ret.haveInfiniteLifetime = childOf.haveInfiniteLifetime;
        ret.mayBeGlobal = childOf.mayBeGlobal;

        ret.next = *bucket;
        *bucket = ret;
        return ret;
    }

    DFAVar* findAddressOfVar(DFAVar* childOf)
    {
        if (childOf is null)
            return null;

        if (childOf.addressOfVar is null)
        {
            childOf.addressOfVar = allocator.makeVar(null);
            childOf.addressOfVar.base1 = childOf;
            childOf.addressOfVar.haveInfiniteLifetime = childOf.haveInfiniteLifetime;
            childOf.addressOfVar.mayBeGlobal = childOf.mayBeGlobal;
        }

        return childOf.addressOfVar;
    }

    DFAScope* findScopeForControlStatement(Statement st)
    {
        DFAScope* current = this.currentDFAScope;

        while (current !is null && current.controlStatement !is st)
        {
            current = current.parent;
        }

        return current;
    }

    DFAScope* findScopeHeadOfLabelStatement(Identifier label)
    {
        bool walkExpression(Expression e)
        {
            if (auto de = e.isDeclarationExp)
            {
                if (auto ad = de.declaration.isAttribDeclaration)
                {
                    // ImportC wraps their declarations

                    if (ad.decl !is null)
                    {
                        foreach (symbol; *ad.decl)
                        {
                            if (symbol.isVarDeclaration !is null)
                                return true;
                        }
                    }

                    return false;
                }
                else
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

        DFAScope* current = this.currentDFAScope;

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

    SwitchStatement findSwitchGivenCase(CaseStatement cs, out DFAScope* target)
    {
        DFAScope* current = this.currentDFAScope;

        while (current !is null)
        {
            if (current.controlStatement !is null)
            {
                auto sw = current.controlStatement.isSwitchStatement;

                if (sw !is null && sw.cases !is null)
                {
                    foreach (cs2; *sw.cases)
                    {
                        if (cs2 is cs)
                        {
                            target = current;
                            return sw;
                        }
                    }
                }
            }

            current = current.parent;
        }

        return null;
    }

    DFAVar* getReturnVariable()
    {
        if (this.returnVar is null)
            this.returnVar = allocator.makeVar(null);
        return this.returnVar;
    }

    DFAVar* getInfiniteLifetimeVariable()
    {
        if (this.infiniteLifetimeVar is null)
        {
            this.infiniteLifetimeVar = allocator.makeVar(null);
            this.infiniteLifetimeVar.haveInfiniteLifetime = true;
            this.infiniteLifetimeVar.isTruthy = true;
            this.infiniteLifetimeVar.isNullable = true;
        }

        return this.infiniteLifetimeVar;
    }

    DFAVar* getUnknownVar()
    {
        if (this.unknownVar is null)
        {
            this.unknownVar = allocator.makeVar(null);
            this.unknownVar.unmodellable = true;
        }

        return this.unknownVar;
    }

    DFAScope* getSideEffectScope()
    {
        DFAScope* current = this.currentDFAScope;

        while (current.sideEffectFree)
        {
            current = current.parent;
        }

        return current;
    }

    DFAObject* makeObject(DFAVar* storageForVar)
    {
        if (storageForVar is null)
            return null;
        else if (storageForVar.storageFor !is null)
            return storageForVar.storageFor;

        DFAObject* ret = allocator.makeObject;
        ret.storageFor = storageForVar;
        ret.minimumDeclaredAtDepth = storageForVar.oldestLifeTimeAllowedDepth;

        if (storageForVar.var is null
                || (storageForVar.var.storage_class & (
                    STC.static_ | STC.tls | STC.shared_ | STC.gshared)) == 0)
            ret.onTheStack = storageForVar.oldestLifeTimeAllowedDepth > 0;

        storageForVar.storageFor = ret;
        return ret;
    }

    DFAObject* makeObject(DFAObject* base1 = null, DFAObject* base2 = null)
    {
        if (base2 !is null && base1 is null)
        {
            base1 = base2;
            base2 = null;
        }

        DFAObject* ret = allocator.makeObject;
        ret.base1 = base1;
        ret.base2 = base2;

        ret.onTheStack = (base1 !is null && base1.onTheStack) || (base2 !is null && base2
                .onTheStack);

        ret.minimumDeclaredAtDepth = -1;
        if (base1 !is null && base1.minimumDeclaredAtDepth > -1)
            ret.minimumDeclaredAtDepth = base1.minimumDeclaredAtDepth;
        if (base2 !is null && base2.minimumDeclaredAtDepth > -1 && (ret.minimumDeclaredAtDepth == -1
                || ret.minimumDeclaredAtDepth > base2.minimumDeclaredAtDepth))
            ret.minimumDeclaredAtDepth = base2.minimumDeclaredAtDepth;

        return ret;
    }

    DFAObject* makeInCellObject(DFAObject* cell)
    {
        DFAObject* ret = allocator.makeObject;

        ret.inCell = cell;
        ret.mayNotBeExactPointer = true;
        ret.minimumDeclaredAtDepth = -1;

        if (cell !is null)
        {
            ret.onTheStack = cell.onTheStack;

            if (cell.minimumDeclaredAtDepth > -1)
                ret.minimumDeclaredAtDepth = cell.minimumDeclaredAtDepth;
        }
        return ret;
    }

    DFAArgumentListRef makeArgumentListRef(size_t countArgs)
    {
        assert(countArgs >= 0);

        const neededLists = (countArgs + 31) / 32;
        DFAArgumentListRef ret;
        DFAArgumentList* current;

        foreach (_; 0 .. neededLists)
        {
            if (current is null)
            {
                current = allocator.makeArgumentList(&this);
                ret.list = current;
            }
            else
            {
                current.listnext = allocator.makeArgumentList(&this);
                current = current.listnext;
            }

            current.count = countArgs > 32 ? 32 : cast(ubyte) countArgs;
            countArgs -= 32;
        }

        return ret;
    }

    DFALatticeRef makeLatticeRef()
    {
        DFALatticeRef ret;
        ret.lattice = allocator.makeLattice(&this);
        ret.check;
        return ret;
    }

    DFAScopeVar* swapLattice(DFAVar* contextVar, scope DFALatticeRef delegate(DFALatticeRef) dg)
    {
        if (contextVar is null || this.currentDFAScope.depth < contextVar
                .oldestLifeTimeAllowedDepth)
            return null;

        DFAScopeVar* scv = this.acquireScopeVar(contextVar);

        if (scv.lr.isNull)
        {
            scv.lr = this.makeLatticeRef;
            scv.lr.setContext(contextVar);
        }

        DFALatticeRef got = dg(scv.lr);

        if (!got.isNull)
        {
            if (got.getContextVar !is contextVar)
                scv.lr.setContext(contextVar);

            scv.lr = got;
        }

        scv.lr.check;
        return scv;
    }

    bool haveForwardLabelState(Identifier ident)
    {
        DFALabelState** bucket = &this.forwardLabels[(
                    cast(size_t) cast(void*) ident) % this.forwardLabels.length];

        while (*bucket !is null && cast(void*)(*bucket).ident < cast(void*) ident)
        {
            bucket = &(*bucket).next;
        }

        return *bucket !is null && (*bucket).ident is ident;
    }

    void swapForwardLabelScope(Identifier ident, scope DFAScopeRef delegate(DFAScopeRef) del)
    {
        DFALabelState** bucket = &this.forwardLabels[(
                    cast(size_t) cast(void*) ident) % this.forwardLabels.length];

        while (*bucket !is null && cast(void*)(*bucket).ident < cast(void*) ident)
        {
            bucket = &(*bucket).next;
        }

        if (*bucket is null || (*bucket).ident !is ident)
        {
            DFALabelState* temp = allocator.makeLabelState(ident);
            temp.next = *bucket;
            *bucket = temp;
        }

        (*bucket).scr = del((*bucket).scr);
    }

    DFACaseState* acquireCaseState(Statement caseStatement)
    {
        DFACaseState** bucket = &this.caseEntries[(
                    cast(size_t) cast(void*) caseStatement) % this.caseEntries.length];

        while (*bucket !is null && cast(void*)(*bucket).caseStatement < cast(void*) caseStatement)
        {
            bucket = &(*bucket).next;
        }

        if (*bucket is null || (*bucket).caseStatement !is caseStatement)
        {
            DFACaseState* temp = allocator.makeCaseState(caseStatement);
            temp.next = *bucket;
            *bucket = temp;
        }

        return *bucket;
    }

    DFALatticeRef acquireLattice(DFAVar* var)
    {
        DFAScopeVar* scv = this.acquireScopeVar(var);
        if (scv is null)
            return DFALatticeRef.init;

        return scv.lr.copy;
    }

    DFAScopeVar* acquireScopeVar(DFAVar* var)
    {
        if (var is null || this.currentDFAScope.depth < var.oldestLifeTimeAllowedDepth)
            return null;

        DFAScope* sc;
        sc = this.currentDFAScope;
        DFAScopeVar* scv, ret;

        while (sc !is null && sc.depth >= var.oldestLifeTimeAllowedDepth)
        {
            if ((scv = sc.findScopeVar(var)) !is null)
                break;

            sc = sc.parent;
        }

        assert(scv is null || scv.var is var);
        DFAConsequence* c;

        if (scv is null)
        {
            // init new state
            sc = this.currentDFAScope;
            ret = sc.getScopeVar(var);

            c = ret.lr.getContext;
            assert(ret.var is var);
            assert(c !is null);
            assert(c.var is var);

            return ret;
        }
        else
        {
            assert(!scv.lr.isNull);
            c = scv.lr.getContext;
            assert(c !is null);
            assert(c.var is var);
        }

        sc = sc.child;
        ret = scv;

        while (sc !is null)
        {
            ret = sc.getScopeVar(var);
            assert(ret.var is var);
            // if we had state that we wanted copied, we'd do it here

            ret.lr = scv.lr.copy;
            ret.mergable = scv.mergable;

            c = ret.lr.getContext;
            assert(c !is null);
            assert(c.var is var);

            sc = sc.child;
        }

        assert(ret !is null);
        return ret;
    }

    DFAScope* findScopeGivenLabel(Identifier ident)
    {
        DFAScope* current = this.currentDFAScope;

        if (ident is null)
        {
            while (current.parent !is null && current.controlStatement is null)
            {
                current = current.parent;
            }
        }
        else
        {
            while (current.parent !is null && (current.label is null || current
                    .label.ident !is ident))
            {
                current = current.parent;
            }
        }

        return (current !is null && ((current.label !is null
                && current.label.ident is ident) || current.controlStatement !is null)) ? current
            : null;
    }

    void allocatedVariablesAllUnmodellable()
    {
        // If we're calling this, that means we have literally no idea what state these variables are in.
        // Its anything after this point in the AST walk.

        DFAVar* current = allocator.allocatedlistvar;

        while (current !is null)
        {
            current.unmodellable = true;
            current = current.listnext;
        }
    }

    void print()
    {
        DFAScope* sc = this.currentDFAScope;

        while (sc !is null)
        {
            printf("- scope %p\n", sc);

            foreach (i; 0 .. sc.buckets.length)
            {
                printf("    - bucket %zd:\n", i);

                DFAScopeVar* bucket = sc.buckets[i];
                while (bucket !is null)
                {
                    printf("        - scope var %p for var %p\n", bucket, bucket.var);
                    DFAConsequence* cctx = bucket.lr.getContext;
                    printf("          cctx.var %p\n", cctx !is null ? cctx.var : null);
                    bucket = bucket.next;
                }
            }

            sc = sc.parent;
        }

        fflush(stdout);
    }

    void check()
    {
        static if (DFACommon.debugVerify)
        {
            DFAScope* sc = this.currentDFAScope;

            while (sc !is null)
            {
                foreach (var, l, scv; *sc)
                {
                    assert(l !is null);

                    DFAConsequence* cctx = l.context;
                    assert(cctx !is null);

                    if (cctx.var !is var)
                    {
                        printf("check scv var %p !is %p\n", cctx.var, var);
                        fflush(stdout);
                    }

                    assert(cctx.var is var);
                }

                sc = sc.parent;
            }
        }
    }
}

struct DFAAllocator
{
    package(dmd.dfa)
    {
        DFACommon* dfaCommon;
    }

    private
    {
        static struct Region
        {
        align(1):
            Region* previous;
            Region* next;
            size_t length;
        }

        // 8kb for regions of memory
        //enum RegionAllocationStep = 8_192;
        // 128kb for regions of memory
        enum RegionAllocationStep = 131_072;
        // 256kb for regions of memory
        //enum RegionAllocationStep = 262_144;
        // 1mb for regions of memory
        //enum RegionAllocationStep = 1_048_576;

        DFAVar* allocatedlistvar, allocatedlistlastvar, allocatedlistStackVar;
        DFAObject* allocatedlistobject;

        // We use free lists to reuse memory, during our operation.
        DFALabelState* freelistlabel;
        DFACaseState* freelistcase;
        DFAVar* freelistvar;
        DFAScopeVar* freelistscopevar;
        DFAObject* freelistobject;
        DFAScope* freelistscope;
        DFAArgumentList* freelistarglist;
        DFALattice* freelistlattice;
        DFAConsequence* freelistconsequence;

        Region* currentRegion;
        size_t regionUsed;

        __gshared
        {
            Region* lastRegion;
            void[RegionAllocationStep] staticRegion = void;
        }
    }

    static void deinitialize()
    {
        import dmd.root.rmem;

        while (lastRegion !is null)
        {
            void* toFree;
            if (lastRegion.previous !is null)
                toFree = cast(void*) lastRegion;
            lastRegion = lastRegion.previous;

            assert(toFree !is staticRegion.ptr);
            if (toFree !is null)
                Mem.xfree(toFree);
        }
    }

    static void checkfreelist()
    {
        version (none)
        {
            DFAVar* v = freelistvar;
            DFAScopeVar* scv = freelistscopevar;
            DFAScope* sc = freelistscope;
            DFALattice* l = freelistlattice;
            DFAConsequence* c = freelistconsequence;

            while (v !is null)
            {
                v = v.listnext;
            }

            while (scv !is null)
            {
                scv = scv.listnext;
            }

            while (sc !is null)
            {
                sc = sc.listnext;
            }

            while (l !is null)
            {
                l = l.listnext;
            }

            while (c !is null)
            {
                c = c.listnext;
            }
        }
    }

    DFAVar* makeVar(VarDeclaration vd, DFAVar* childOf = null)
    {
        DFAVar** bucket;

        if (childOf !is null)
        {
            bucket = &childOf.childVars[(cast(size_t) cast(void*) vd) % childOf.childVars.length];

            while (*bucket !is null && cast(void*)(*bucket).var < cast(void*) vd)
            {
                bucket = &(*bucket).next;
            }

            if (*bucket !is null && (*bucket).var is vd)
                return *bucket;
        }

        DFAVar* ret = allocInternal!DFAVar(freelistvar);
        ret.var = vd;
        ret.base1 = childOf;
        ret.offsetFromBase = -1;

        if (vd !is null)
        {
            applyType(ret, vd);

            if (childOf is null)
            {
                ret.stacklistnext = allocatedlistStackVar;
                allocatedlistStackVar = ret;
            }
        }

        if (childOf !is null)
        {
            ret.haveInfiniteLifetime = childOf.haveInfiniteLifetime;
            ret.offsetFromBase = vd.offset;

            ret.next = *bucket;
            *bucket = ret;
        }

        if (this.allocatedlistlastvar is null)
        {
            this.allocatedlistlastvar = ret;
            this.allocatedlistvar = ret;
        }
        else
        {
            ret.listnext = this.allocatedlistvar;
            this.allocatedlistvar = ret;
        }

        return ret;
    }

    DFAScopeVar* makeScopeVar(DFACommon* dfaCommon, DFAVar* var)
    {
        DFAScopeVar* ret = allocInternal!DFAScopeVar(freelistscopevar);
        ret.var = var;
        return ret;
    }

    DFAScope* makeScope(DFACommon* dfaCommon, DFAScope* parent)
    {
        DFAScope* ret = allocInternal!DFAScope(freelistscope);
        ret.dfaCommon = dfaCommon;
        ret.parent = parent;
        return ret;
    }

    DFAObject* makeObject()
    {
        DFAObject* ret = allocInternal!DFAObject(freelistobject);

        ret.listnext = this.allocatedlistobject;
        this.allocatedlistobject = ret;
        return ret;
    }

    DFAArgumentList* makeArgumentList(DFACommon* dfaCommon)
    {
        DFAArgumentList* ret = allocInternal!DFAArgumentList(freelistarglist);
        ret.dfaCommon = dfaCommon;
        return ret;
    }

    DFALattice* makeLattice(DFACommon* dfaCommon)
    {
        DFALattice* ret = allocInternal!DFALattice(freelistlattice);
        ret.dfaCommon = dfaCommon;
        return ret;
    }

    DFAConsequence* makeConsequence(DFAVar* var, DFAConsequence* copyFrom = null)
    {
        DFAConsequence* ret = allocInternal!DFAConsequence(freelistconsequence);
        ret.dfaCommon = dfaCommon;
        ret.var = var;

        if (copyFrom !is null)
        {
            ret.copyFrom(copyFrom);

            if (var !is null)
            {
                if (!var.isTruthy)
                    ret.truthiness = Truthiness.Unknown;
                if (!var.isNullable)
                    ret.nullable = Nullable.Unknown;
            }
        }

        ret.var = var;
        return ret;
    }

    DFALabelState* makeLabelState(Identifier ident)
    {
        DFALabelState* ret = allocInternal!DFALabelState(freelistlabel);
        ret.ident = ident;
        return ret;
    }

    DFACaseState* makeCaseState(Statement caseStatement)
    {
        DFACaseState* ret = allocInternal!DFACaseState(freelistcase);
        ret.caseStatement = caseStatement;
        return ret;
    }

    void free(DFAScopeVar* s)
    {
        s.lr = DFALatticeRef.init;
        s.lrGatePredicate = DFALatticeRef.init;
        s.lrGateNegatedPredicate = DFALatticeRef.init;
        s.var = null;
        s.next = null;

        s.listnext = freelistscopevar;
        freelistscopevar = s;
    }

    void free(DFAScope* s)
    {
        static if (DFACommon.debugVerify)
        {
            DFAScope* current = s.dfaCommon.currentDFAScope;

            while (current !is null)
            {
                assert(current !is s);
                current = current.parent;
            }
        }

        s.parent = null;
        s.child = null;
        s.previousLoopyLabel = null;
        s.previousCatch = null;

        s.controlStatement = null;
        s.compoundStatement = null;
        s.tryFinallyStatement = null;

        s.beforeScopeState = DFAScopeRef.init;
        s.afterScopeState = DFAScopeRef.init;

        foreach (ref bucket; s.buckets)
        {
            DFAScopeVar* next;

            while (bucket !is null)
            {
                next = bucket.next;
                this.free(bucket);
                bucket = next;
            }
        }

        s.listnext = freelistscope;
        freelistscope = s;
    }

    void free(DFAArgumentList* list)
    {
        foreach (i; 0 .. list.count)
        {
            list.each[i].lr = DFALatticeRef.init;
            list.each[i].paramInfo = null;
        }

        list.listnext = freelistarglist;
        freelistarglist = list;
    }

    void free(DFALattice* l)
    {

        l.firstInSequence = null;
        l.lastInSequence = null;
        l.constant = null;
        l.context = null;

        l.listnext = freelistlattice;
        freelistlattice = l;
    }

    void free(DFAConsequence* c)
    {
        c.listnext = freelistconsequence;
        freelistconsequence = c;
    }

    void allObjects(scope void delegate(DFAObject* obj) del)
    {
        DFAObject* current = allocatedlistobject;

        while (current !is null)
        {
            del(current);
            current = current.listnext;
        }
    }

    void allVariables(scope void delegate(DFAVar* obj) del)
    {
        DFAVar* current = allocatedlistvar;

        while (current !is null)
        {
            del(current);
            current = current.listnext;
        }
    }

    void allStackVariables(scope void delegate(DFAVar* obj) del)
    {
        DFAVar* current = allocatedlistStackVar;

        while (current !is null)
        {
            del(current);
            current = current.stacklistnext;
        }
    }

private:
    T* allocInternal(T)(ref T* freelist)
    {
        import core.stdc.string;
        import dmd.root.rmem;

        T* ret = freelist;

        if (ret !is null)
        {
            freelist = freelist.listnext;
        }
        else
        {
            if (currentRegion is null)
            {
                Region* got = cast(Region*) staticRegion.ptr;

                if (lastRegion is null)
                    *got = Region(null, null, RegionAllocationStep);

                currentRegion = got;
                regionUsed = Region.sizeof;
            }
            else if (regionUsed + T.sizeof >= currentRegion.length)
            {
                if (currentRegion.next !is null)
                {
                    currentRegion = currentRegion.next;
                    regionUsed = Region.sizeof;
                }
                else
                {
                    // Acquire the next block of memory to allocate from
                    Region* got = cast(Region*) Mem.xmalloc(RegionAllocationStep);
                    assert(got !is null);

                    *got = Region(currentRegion, null, RegionAllocationStep);
                    currentRegion.next = got;
                    currentRegion = got;

                    lastRegion = got;
                    regionUsed = Region.sizeof;
                }
            }

            assert(currentRegion !is null);
            assert(regionUsed + T.sizeof <= currentRegion.length);

            void* pos = cast(void*) currentRegion + regionUsed;
            ret = cast(T*) pos;
            regionUsed += T.sizeof;
        }

        // Initialize it to the right type
        // Note: D has changed its behavior surrounding getting the init value over many years.
        // A variable like this, is guaranteed good for all of them.
        __gshared immutable(T) valInit;
        memcpy(ret, cast(void*)&valInit, T.sizeof);

        assert(ret !is null);
        return ret;
    }
}

struct DFALabelState
{
    private
    {
        DFALabelState* listnext;
        DFALabelState* next;
    }

    Identifier ident;
    DFAScopeRef scr;
}

struct DFACaseState
{
    private
    {
        DFACaseState* listnext;
        DFACaseState* next;
    }

    Statement caseStatement; // default case or case
    DFAScopeRef containing;
    DFAScopeRef jumpedTo; // When its jumped to this case, this is the meet'd state
}

/***********************************************************
 * Represents the identity of a variable being tracked.
 *
 * This does NOT store the current value of the variable (that changes depending on
 * where you are in the code). Instead, it stores immutable properties like:
 * - Is it a boolean? (`isBoolean`)
 * - Can it be null? (`isNullable`)
 * - Is it a reference to another variable? (`base1`, `indexVar`)
 *
 * Think of this as the "Key" in a map, where the "Value" is the DFALattice.
 */
struct DFAVar
{
    private
    {
        DFAVar* listnext;
        DFAVar* stacklistnext;
        DFAVar* next;
        DFAVar*[16] childVars;
        DFAVar* childOffsetVars;
    }

    DFAVar* base1;
    DFAVar* base2;

    DFAVar* indexVar;
    DFAVar* lengthVar;
    DFAVar* asSliceVar;
    DFAVar* addressOfVar;
    DFAVar* dereferenceVar; // child var

    VarDeclaration var;
    dinteger_t offsetFromBase; // -1 if its not an offset

    bool isAnIndex; // base1[index] = this
    bool isLength; // T[].length

    bool isTruthy;
    bool isNullable;

    bool isBoolean;
    bool isStaticArray;
    bool isFloatingPoint;
    bool isAA;
    bool isByRef;
    bool isScope;

    bool haveInfiniteLifetime;
    bool wasDefaultInitialized; // may not be accurate for all variables
    bool mayBeGlobal; // Var may map to one or more global variable declarations
    bool isStackVar; // If this is a stack variable or something else
    bool mayEscapeInitialValue; // The pointer may have escaped, cannot be allocated on stack.
    bool mayEscapeWithoutIndirection; // Will this object directly escape?
    bool mayEscapeWithIndirection; // Will a child pointer in this object escape?

    int oldestLifeTimeAllowedDepth; // Where destructors and storage are inherently limited
    int youngestLifeTimeAllowedDepth; // Where the variable is actually defined

    int writeCount;

    bool unmodellable; // DO NOT REPORT!!!!
    bool doNotInferNonNull; // i.e. was the rhs of >
    int assertedCount;

    ParameterDFAInfo* param;

    DFAObject* storageFor;

    bool haveBase()
    {
        return this.base1 !is null;
    }

    void markUnmodellable()
    {
        version (none)
        {
            if (this.var !is null)
            {
                if (this.var.ident.toString == "buf")
                    assert(0);
            }
        }

        this.unmodellable = true;
    }

    /// Finds the root variables for this one, where base1 is null
    void walkRoots(scope void delegate(DFAVar* var) del)
    {
        void handle(DFAVar* temp)
        {
            while (temp.base1 !is null && temp.base2 is null)
            {
                temp = temp.base1;
            }

            if (temp.base2 !is null)
            {
                handle(temp.base1);
                handle(temp.base2);
            }
            else
                del(temp);
        }

        handle(&this);
    }

    /// Walk all variables that end up at a root
    void walkToRoot(scope void delegate(DFAVar* var) del)
    {
        void handle(DFAVar* temp)
        {
            while (temp.base1 !is null && temp.base2 is null)
            {
                del(temp);
                temp = temp.base1;
            }

            if (temp.base2 !is null)
            {
                handle(temp.base1);
                handle(temp.base2);
            }
            else
                del(temp);
        }

        handle(&this);
    }

    /// Visit the base1 and base2 if present
    void visitFirstBase(scope void delegate(DFAVar* var) del)
    {
        if (this.base1 is null)
            return;

        del(this.base1);

        if (this.base2 !is null)
            del(this.base2);
    }

    /// If this variable is a reference to another variable, visit the base variable.
    void visitIfReferenceToAnotherVar(scope void delegate(DFAVar* var) del)
    {
        void handle(DFAVar* var, int refed)
        {
            while (var.base2 is null && var.base1 !is null)
            {
                if (var.offsetFromBase != -1)
                    refed++;
                else if (var.base1.dereferenceVar is var)
                    refed++;
                else if (var.base1.indexVar is var)
                    refed++;
                else
                    break;

                var = var.base1;
            }

            if (var.base2 !is null)
            {
                handle(var.base1, refed);
                handle(var.base2, refed);
            }
            else if (refed != 0)
                del(var);
        }

        handle(&this, 0);
    }

    /// If this variable is a reference to another, takes into account dereferencing.
    void visitIfReadOfReferenceToAnotherVar(scope void delegate(DFAVar* var) resolvedIndirection)
    {
        void handle(DFAVar* var, int refed)
        {
            if (!(var.base1 !is null || var.base2 !is null || refed != 0))
                return;

            while (var.base2 is null && var.base1 !is null)
            {
                if (var.offsetFromBase != -1 && var.var is null)
                    refed++;
                else if (var.base1.dereferenceVar is var)
                    refed--;
                else if (var.base1.indexVar is var)
                    refed++;
                else if (var.base1.lengthVar is var && var.base1.isStaticArray
                        && !var.base1.haveBase)
                    return; // Statically known length, base doesn't matter as it won't be read
                else if (var.base1.asSliceVar is var && !var.base1.haveBase && refed == 0)
                    return; // base1[] is a slice this does not inherently make it a read
                else
                    break;

                var = var.base1;
            }

            if (var.base2 !is null)
            {
                handle(var.base1, refed);
                handle(var.base2, refed);
            }
            else if (refed < 0)
                resolvedIndirection(var);
        }

        handle(&this, 0);
    }

    void visitIndirectSources(scope void delegate(DFAVar* var, bool hadAnIndirection, bool hadAnOuterDeref,
            bool takenAddressOf, bool hadFields, bool isOffsetOfStorage, ref bool unknown) del)
    {
        //&( base T
        //   storage            = storage
        //&( base T*
        //   obj1               = storage
        //&( base T[]
        //   storage            = storage
        //&( base T*[]
        //   obj1               = obj1
        //&( base T  . field T
        //   storage   storage  = storage
        //&( base T  . field T[]
        //   storage   storage  = storage
        //&( base T* . field T
        //   obj1      obj1     = obj1
        //&( base T* . field T[]
        //   obj1      obj1     = obj1
        //&( base T* . field T*
        //   obj1      obj2     = obj1
        //&( base T* . field T*[]
        //   obj1      obj2     = obj2
        //&( base T* . field T* . field T
        //   obj1      obj2       obj2       = obj2

        bool unknown;

        void findStorage(DFAVar* var, int derefCount, int indirectCount,
                bool takenAddressOf, int fieldResolve, int isOffsetOfStorage)
        {
            if (unknown)
                return;

            while (var !is null)
            {
                version (none)
                {
                    printf("finding storage for %p\n", var);
                }

                if (var.offsetFromBase != -1)
                {
                    if (var.isNullable)
                    {
                        indirectCount++;
                        isOffsetOfStorage = 0;
                    }

                    if (indirectCount == 0)
                        fieldResolve++;
                    else if (indirectCount == 0)
                        isOffsetOfStorage++;
                }

                if (var.base1 !is null)
                {
                    if (var.base1.indexVar is var && indirectCount == 0)
                        isOffsetOfStorage++;
                    else if (var.base1 !is null && (var.base1.addressOfVar is var
                            || var.base1.asSliceVar is var))
                    {
                        // a.b[] is equivalent to &a.b so we want to find storage of a.b aka a
                        takenAddressOf = true;
                    }
                }

                if (var.base2 !is null)
                {
                    findStorage(var.base2, derefCount, indirectCount,
                            takenAddressOf, fieldResolve, isOffsetOfStorage);
                    findStorage(var.base1, derefCount, indirectCount,
                            takenAddressOf, fieldResolve, isOffsetOfStorage);
                    return;
                }

                if (var.base1 is null)
                    break;
                var = var.base1;
            }

            // If we've reached here, we have skipped over any combiners base1+base2,
            //  and we've got ourselves a real variable/offset on to one.

            if (var is null)
                return;

            version (none)
            {
                printf("Found a storage var %p\n", var);
            }

            del(var, indirectCount > 0, derefCount > 0, takenAddressOf,
                    fieldResolve > 0, isOffsetOfStorage > 0, unknown);
        }

        void findOffset(DFAVar* var, int derefCount, int fieldResolve, int isOffsetOfStorage)
        {
            bool foundTakeAddressOf;

            while (var !is null)
            {
                version (none)
                {
                    printf("seeing offset var %p offsetFromBase %lld isNullable %d\n",
                            var, var.offsetFromBase, var.isNullable);

                    if (var.base1 !is null)
                        printf("    base1 %p, asSliceVar=%p/%d, indexVar=%p/%d\n", var.base1, var.base1.asSliceVar,
                                var.base1.asSliceVar is var, var.base1.indexVar,
                                var.base1.indexVar is var);
                    if (var.var !is null)
                        printf("    var ident %s\n", var.var.ident !is null
                                ? var.var.ident.toChars : null);
                }

                if (var.offsetFromBase != -1)
                {
                    fieldResolve++;

                    if (var.isNullable)
                    {
                        // found some kind of offset that is an indirection i.e.
                        //&( base T* . field T*
                        //   obj1      obj2     = obj1
                        var = var.base1;
                        isOffsetOfStorage = 0;
                        break;
                    }
                    else if (var.offsetFromBase > 0)
                        isOffsetOfStorage++;
                }

                if (var.base1 !is null)
                {
                    if (var.base1.indexVar is var)
                    {
                        // var[0] is equivalent to doing *var
                        isOffsetOfStorage++;
                        derefCount++;
                        break;
                    }
                    else if (var.base1.dereferenceVar is var)
                    {
                        derefCount++;
                        break;
                    }
                    else if (var.base1 !is null && (var.base1.addressOfVar is var
                            || var.base1.asSliceVar is var))
                    {
                        // a.b[] is equivalent to &a.b so we want to find storage of a.b aka a
                        foundTakeAddressOf = true;
                        var = var.base1;
                        break;
                    }
                }

                if (var.base2 !is null)
                {
                    findOffset(var.base2, derefCount, fieldResolve, isOffsetOfStorage);
                    findOffset(var.base1, derefCount, fieldResolve, isOffsetOfStorage);
                    return;
                }

                if (var.base1 is null)
                    break;
                var = var.base1;
            }

            // If we've reached here, we have skipped over any combiners base1+base2,
            //  and we've got ourselves a real variable/offset on to one.

            if (var is null)
                return;

            version (none)
            {
                printf("got offset var %p foundTakenAddressOf %d fieldResolve %d\n",
                        var, foundTakeAddressOf, fieldResolve);
            }

            findStorage(var, derefCount, 0, foundTakeAddressOf, fieldResolve, isOffsetOfStorage);
        }

        findOffset(&this, 0, 0, 0);
    }

    bool isModellable()
    {
        bool ret = true;

        void handle(DFAVar* var)
        {
            if (var.base1 is null)
            {
                if (var.unmodellable)
                    ret = false;
            }
            else
            {
                handle(var.base1);
                if (ret && var.base2 !is null)
                    handle(var.base2);
            }
        }

        handle(&this);
        return ret;
    }

}

struct DFAScopeVar
{
    private
    {
        DFAScopeVar* listnext;
        DFAScopeVar* next;
    }

    DFAVar* var;
    DFALatticeRef lr;

    int gatePredicateWriteCount;
    DFALatticeRef lrGatePredicate;
    DFALatticeRef lrGateNegatedPredicate;

    int derefDepth;
    int derefAssertedDepth;

    int assignDepth;
    int assertDepth, assertTrueDepth, assertFalseDepth;

    DFAScopeVarMergable mergable;
}

struct DFAScopeVarMergable
{
    int nullAssignWriteCount;
    int nullAssignAssertedCount;

    void merge(DFAScopeVarMergable other)
    {
        if (other.nullAssignWriteCount > this.nullAssignWriteCount)
            this.nullAssignWriteCount = other.nullAssignWriteCount;
        if (other.nullAssignAssertedCount > this.nullAssignAssertedCount)
            this.nullAssignAssertedCount = other.nullAssignAssertedCount;
    }
}

struct DFAObject
{
    private
    {
        DFAObject* listnext;
    }

    DFAVar* storageFor;

    // The scope variable that applied minimumDeclaredAtDepth
    // onTheStack stores if its the cell lifetime, otherwise its probably for a parameter.
    DFAVar* constrainedBy;

    // This object is derived from a pointer, specifically foo in: &foo.bar.dar
    DFAObject* derivedFrom;

    // This is in the following cell i.e. pointer to array member or pointer to variable
    DFAObject* inCell;

    // Having a base means it could be one of these.
    // We do not know which one object specifically this will have at runtime.
    DFAObject* base1;
    DFAObject* base2;

    // Helper, stores the minimum derivedAtDepth value between the bases, derivedFrom and storageFor, -1 for not set
    int minimumDeclaredAtDepth;

    // Pointer arithmetic may mean this object isn't 1:1 with the object start.
    bool mayNotBeExactPointer;

    // If we were allocated just to be able to track a variable
    bool defaultTrackObj;

    // Do we point to one or more stack variables storages
    bool onTheStack;

    // The user understands the lifetime requirements for this object.
    // Delay errors in case they actually don't.
    bool lifeTimeUnderstood;

    // This object has escaped, but we're going to delay any error until it has been read.
    bool delayOnReadErrorOfEscape;

    void walkRoots(scope void delegate(DFAObject* root) del)
    {
        DFAObject* obj = &this;

        while (obj.base1 !is null)
        {
            if (obj.base2 !is null)
                obj.base2.walkRoots(del);

            obj = obj.base1;
        }

        del(obj);
    }

    void walk(scope bool delegate(DFAObject* root) del)
    {
        DFAObject* obj = &this;

        while (obj.base1 !is null)
        {
            if (!del(obj))
                return;

            if (obj.base2 !is null)
                obj.base2.walk(del);

            obj = obj.base1;
        }

        del(obj);
    }

    void walkIndirection(scope void delegate(DFAObject* root, bool hadAnIndirection, bool haveConstraintOnLifeTime,
            bool inCell) findRootsDel, scope void delegate(DFAObject* constrained,
            bool hadAnIndirection, bool haveConstraintOnLifeTime) findConstraintsDel)
    {
        void findRoots(DFAObject* current, int indirectCount,
                int constrainedMinimumLifetime, bool inCell)
        {
            while (current.base1 !is null || current.derivedFrom !is null)
            {
                if (current.constrainedBy !is null
                        && current.constrainedBy.oldestLifeTimeAllowedDepth
                        > constrainedMinimumLifetime)
                    constrainedMinimumLifetime = current.constrainedBy.oldestLifeTimeAllowedDepth;

                if (current.derivedFrom !is null)
                {
                    if (current.base1 !is null)
                        findRoots(current.derivedFrom, indirectCount + 1,
                                constrainedMinimumLifetime, inCell);
                    else
                    {
                        current = current.derivedFrom;
                        indirectCount++;
                        continue;
                    }
                }

                if (current.inCell !is null)
                    findRoots(current.inCell, 0, constrainedMinimumLifetime, true);

                if (current.base2 !is null)
                    findRoots(current.base2, indirectCount, constrainedMinimumLifetime, inCell);

                current = current.base1;
            }

            if (current.inCell !is null)
                findRoots(current.inCell, 0, constrainedMinimumLifetime, true);
            else
                findRootsDel(current, indirectCount > 0,
                        constrainedMinimumLifetime >= 0, inCell && indirectCount == 0);
        }

        void findConstraints(DFAObject* current, int indirectCount, int constrainedMinimumLifetime)
        {
            while (current.base1 !is null || current.derivedFrom !is null)
            {
                if (current.constrainedBy !is null)
                {
                    findConstraintsDel(current, indirectCount > 0, constrainedMinimumLifetime >= 0);

                    if (
                        current.constrainedBy.oldestLifeTimeAllowedDepth
                            > constrainedMinimumLifetime)
                        constrainedMinimumLifetime = current.constrainedBy
                            .oldestLifeTimeAllowedDepth;
                }

                if (current.derivedFrom !is null)
                {
                    if (current.base1 !is null)
                        findConstraints(current.derivedFrom, indirectCount + 1,
                                constrainedMinimumLifetime);
                    else
                    {
                        current = current.derivedFrom;
                        indirectCount++;
                        continue;
                    }
                }

                if (current.inCell !is null)
                    findConstraints(current.inCell, 0, constrainedMinimumLifetime);

                if (current.base2 !is null)
                    findConstraints(current.base2, indirectCount, constrainedMinimumLifetime);

                current = current.base1;
            }
        }

        if (findRootsDel !is null)
            findRoots(&this, 0, -1, false);
        if (findConstraintsDel !is null)
            findConstraints(&this, 0, -1);
    }
}

struct DFAScopeRef
{
    package DFAScope* sc;

    static if (DFACleanup)
    {
        this(ref DFAScopeRef other)
        {
            this.sc = other.sc;
            other.sc = null;
        }

        ~this()
        {
            if (sc is null)
                return;

            sc.dfaCommon.allocator.free(sc);
            sc = null;
        }
    }

    bool isNull()
    {
        return sc is null;
    }

    uint controlFlowJumped()
    {
        if (isNull)
            return 0;
        return sc.controlFlow & DFAScope.ControlFlow.HaveJumped;
    }

    uint controlFlowReturned()
    {
        if (isNull)
            return 0;
        return sc.controlFlow & DFAScope.ControlFlow.HaveReturned;
    }

    DFAScopeVar* findScopeVar(DFAVar* contextVar)
    {
        if (sc is null)
            return null;

        return sc.findScopeVar(contextVar);
    }

    DFAScopeVar* getScopeVar(DFAVar* contextVar)
    {
        if (sc is null)
            return null;

        return this.sc.getScopeVar(contextVar);
    }

    DFALatticeRef consumeNext(out DFAVar* contextVar, out DFAScopeVarMergable mergable)
    {
        if (sc is null)
            return DFALatticeRef.init;

        foreach (ref bucket; sc.buckets)
        {
            if (bucket is null)
                continue;

            DFAScopeVar* scv = bucket;
            contextVar = scv.var;
            mergable = scv.mergable;
            bucket = scv.next;

            DFALatticeRef lr = scv.lr;
            sc.dfaCommon.allocator.free(scv);
            return lr;
        }

        return DFALatticeRef.init;
    }

    DFALatticeRef consumeVar(DFAVar* contextVar, out DFAScopeVarMergable mergable)
    {
        if (sc is null)
            return DFALatticeRef.init;

        DFAScopeVar** bucket = &sc.buckets[cast(size_t) contextVar % sc.buckets.length];

        while (*bucket !is null && (*bucket).var < contextVar)
            bucket = &(*bucket).next;

        if (*bucket is null || (*bucket).var !is contextVar)
            return DFALatticeRef.init;

        DFAScopeVar* scv = *bucket;
        mergable = scv.mergable;
        DFALatticeRef lr = scv.lr;

        *bucket = scv.next;
        sc.dfaCommon.allocator.free(scv);
        return lr;
    }

    DFAScopeVar* assignLattice(DFAVar* contextVar, DFALatticeRef lr)
    {
        if (this.isNull)
            return null;
        this.check;

        DFAScopeVar* ret = sc.assignLattice(contextVar, lr);

        this.check;
        return ret;
    }

    void printStructure(const(char)* prefix = "", int sdepth = 0, int depth = 0)
    {
        if (this.isNull)
            return;

        this.sc.printStructure(prefix, sdepth, depth);
    }

    void printState(const(char)* prefix = "", int sdepth = 0, int depth = 0)
    {
        if (this.isNull)
            return;

        this.sc.printState(prefix, sdepth, depth);
    }

    void printActual(const(char)* prefix = "", int sdepth = 0, int depth = 0)
    {
        if (this.isNull)
            return;

        this.sc.printActual(prefix, sdepth, depth);
    }

    int opApply(scope int delegate(DFALattice*) dg)
    {
        if (this.sc is null)
            return 0;

        return this.sc.opApply(dg);
    }

    int opApply(scope int delegate(DFAVar*, DFALattice*) dg)
    {
        if (this.sc is null)
            return 0;

        return this.sc.opApply(dg);
    }

    int opApply(scope int delegate(DFAVar*, DFALattice*, DFAScopeVar*) dg)
    {
        if (this.sc is null)
            return 0;

        return this.sc.opApply(dg);
    }

    DFAScopeRef copy()
    {
        if (this.isNull)
            return DFAScopeRef.init;

        return this.sc.copy;
    }

    void check()
    {
        if (!this.isNull)
            this.sc.check;
    }
}

/***********************************************************
 * Represents a specific region of code execution (a scope).
 *
 * As the DFA walks through the code, it pushes and pops scopes.
 * Each scope holds a table (`buckets`) of the current state of variables
 * within that block.
 *
 * When the analysis branches (e.g., inside an `if`), a new child scope is
 * created to track the state changes specific to that branch.
 */
struct DFAScope
{
    private
    {
        DFACommon* dfaCommon;
        DFAScope* listnext;
        DFAScope* previousLoopyLabel;
        DFAScope* previousCatch;
    }

    DFAScope* parent, child;
    DFAScopeVar*[16] buckets;
    int depth;

    uint controlFlow;
    bool isLoopyLabel; // Is a loop or label
    bool isLoopyLabelKnownToHaveRun; // was the loopy label guaranteed to have at least one iteration?
    bool inConditional;
    bool sideEffectFree; // No side effects should be stored in this scope use a parent instead.

    Statement controlStatement; // needed to apply on iteration for continue, loops switch statements ext.
    LabelStatement label;

    CompoundStatement compoundStatement;
    size_t inProgressCompoundStatement;

    TryFinallyStatement tryFinallyStatement;

    DFAScopeRef beforeScopeState, afterScopeState;

    /// What control flow has occured on this scope
    enum ControlFlow : uint
    {
        Unknown = 0x00,
        Thrown = 0x01,
        Goto = 0x02,
        Break = 0x04,
        Continue = 0x08,
        Return = 0x10,
        EndOfFunction = 0x20,
        NoReturn = 0x40,

        HaveJumped = Thrown | Goto | Break | Continue | Return | EndOfFunction | NoReturn,
        HaveReturned = Thrown | Return | EndOfFunction | NoReturn,
    }

    bool controlFlowReturned()
    {
        return (this.controlFlow & ControlFlow.HaveReturned) > 0;
    }

    bool controlFlowJumped()
    {
        return (this.controlFlow & ControlFlow.HaveJumped) > 0;
    }

    DFALattice* findLattice(DFAVar* contextVar)
    {
        assert(contextVar !is null); // if this is null idk what is going on!

        DFAScopeVar** bucket = &this.buckets[cast(size_t) contextVar % this.buckets.length];

        while (*bucket !is null && (*bucket).var < contextVar)
        {
            bucket = &(*bucket).next;
        }

        if (*bucket is null || (*bucket).var !is contextVar)
            return null;

        DFAConsequence* cctx = (*bucket).lr.getContext;
        if (cctx !is null)
        {
            assert(cctx.var is contextVar);
        }

        return (*bucket).lr.lattice;
    }

    DFAScopeVar* findScopeVar(DFAVar* contextVar)
    {
        assert(contextVar !is null); // if this is null idk what is going on!

        DFAScopeVar** bucket = &this.buckets[cast(size_t) contextVar % this.buckets.length];

        DFAVar* lastVar;

        while (*bucket !is null && (*bucket).var < contextVar && lastVar < (*bucket).var)
        {
            lastVar = (*bucket).var;
            bucket = &(*bucket).next;
        }

        if (*bucket is null || (*bucket).var !is contextVar)
            return null;
        return *bucket;
    }

    DFAScopeVar* getScopeVar(DFAVar* contextVar)
    {
        if (contextVar is null)
            return null;

        this.check;
        DFAScopeVar** bucket = &buckets[cast(size_t) contextVar % buckets.length];

        while (*bucket !is null && (*bucket).var < contextVar)
            bucket = &(*bucket).next;

        DFAScopeVar* scv = *bucket;

        if (scv is null || scv.var !is contextVar)
        {
            scv = dfaCommon.allocator.makeScopeVar(dfaCommon, contextVar);

            DFALatticeRef temp = dfaCommon.makeLatticeRef;
            temp.setContext(contextVar);
            scv.lr = temp;

            scv.next = *bucket;
            *bucket = scv;
        }

        this.check;
        return scv;
    }

    DFAScopeVar* createAndInheritLattice(DFAVar* contextVar, DFALattice* copyFrom)
    {
        assert(contextVar !is null); // if this is null idk what is going on!

        DFAScopeVar** bucket = &this.buckets[cast(size_t) contextVar % this.buckets.length];

        while (*bucket !is null && (*bucket).var < contextVar)
            bucket = &(*bucket).next;

        DFAScopeVar* scv = *bucket;

        if (scv is null || scv.var !is contextVar)
        {
            scv = dfaCommon.allocator.makeScopeVar(dfaCommon, contextVar);
            scv.next = *bucket;
            *bucket = scv;
        }

        if (scv.lr.isNull)
        {
            scv.lr = copyFrom !is null ? copyFrom.copy : dfaCommon.makeLatticeRef;
            scv.lr.setContext(contextVar);
        }

        return scv;
    }

    DFAScopeVar* assignLattice(DFAVar* contextVar, DFALatticeRef lr)
    {
        DFAScopeVar** bucket = &this.buckets[cast(size_t) contextVar % this.buckets.length];

        while (*bucket !is null && (*bucket).var < contextVar)
            bucket = &(*bucket).next;

        DFAScopeVar* scv = *bucket;

        if (scv is null || scv.var !is contextVar)
        {
            scv = dfaCommon.allocator.makeScopeVar(this.dfaCommon, contextVar);
            scv.next = *bucket;
            *bucket = scv;
        }

        lr.setContext(contextVar);
        scv.lr = lr;
        scv.lr.check;

        return scv;
    }

    void printStructure(const(char)* prefix = "", int sdepth = 0, int depth = 0)
    {
        static if (!this.dfaCommon.debugStructure)
            return;
        else
            printActual(prefix, sdepth, depth);
    }

    void printState(const(char)* prefix = "", int sdepth = 0, int depth = 0)
    {
        static if (!this.dfaCommon.debugIt)
            return;
        else
            printActual(prefix, sdepth, depth);
    }

    void printActual(const(char)* prefix = "", int sdepth = 0, int depth = 0)
    {
        printPrefix("%s Scope", sdepth, depth, prefix);
        printf(" %p depth=%d", &this, this.depth);

        {
            printf(", controlFlow=(");

            uint printedCFI;
            foreach (cf; __traits(allMembers, ControlFlow))
            {
                if ((__traits(getMember, ControlFlow, cf) & this.controlFlow) > 0)
                {
                    if (printedCFI++ == 0)
                        printf("%s", cf.ptr);
                    else
                        printf(" %s", cf.ptr);
                }
            }

            printf(")");
        }

        if (this.label !is null)
            printf(", label=`%s`\n", this.label.ident.toChars);
        else
            printf("\n");

        if (!this.beforeScopeState.isNull)
        {
            printPrefix("%s before scope state:\n", sdepth, depth, prefix);
            this.beforeScopeState.sc.printActual(prefix, sdepth, depth + 1);
        }

        if (!this.afterScopeState.isNull)
        {
            printPrefix("%s after scope state:\n", sdepth, depth, prefix);
            this.afterScopeState.sc.printActual(prefix, sdepth, depth + 1);
        }

        printPrefix("%s scv's:\n", sdepth, depth, prefix);
        foreach (contextVar, l, scv; this)
        {
            printPrefix("%s on %p", sdepth, depth + 1, prefix, contextVar);

            if (contextVar !is null)
            {
                printf(";%d<%d", contextVar.oldestLifeTimeAllowedDepth,
                        contextVar.youngestLifeTimeAllowedDepth);

                if (contextVar.base1 !is null)
                    printf(":%p", contextVar.base1);
                if (contextVar.base2 !is null)
                    printf(":%p", contextVar.base2);

                if (contextVar.var !is null)
                    printf("@%p=`%s`", contextVar.var, contextVar.var.toChars);

                printf(", unmodel=%d, write=%d", contextVar.unmodellable, contextVar.writeCount);
                printf(", deref=%d:%d", scv.derefDepth, scv.derefAssertedDepth);
                printf(", assign=%d, assert=%d/%d/%d", scv.assignDepth,
                        scv.assertDepth, scv.assertTrueDepth, scv.assertFalseDepth);
            }

            printf(", nullassign=%d\n", scv.mergable.nullAssignWriteCount);

            if (this.isLoopyLabel)
            {
                printPrefix("%s  predicate:\n", sdepth, depth, prefix);
                scv.lrGatePredicate.printActual(prefix, sdepth, depth + 1);
                printPrefix("%s !predicate:\n", sdepth, depth, prefix);
                scv.lrGateNegatedPredicate.printActual(prefix, sdepth, depth + 1);
            }

            printPrefix("%s lattice:\n", sdepth, depth, prefix);
            l.printActual(prefix, sdepth, depth + 1);
        }
    }

    DFAScopeRef copy()
    {
        DFAScopeRef ret;
        ret.sc = dfaCommon.allocator.makeScope(this.dfaCommon, this.parent);
        ret.sc.depth = this.depth;

        // not everything is copied over as it isn't important

        foreach (var, lr, scv; this)
        {
            ret.sc.createAndInheritLattice(var, lr);
        }

        ret.check;
        return ret;
    }

    void check()
    {
        static if (DFACommon.debugVerify)
        {
            foreach (scv; this.buckets)
            {
                while (scv !is null)
                {
                    assert(scv.lr.lattice !is null);

                    if (scv.next !is null)
                        assert(scv.next.var > scv.var);

                    scv.lr.check;
                    scv = scv.next;
                }
            }
        }
    }

    int opApply(scope int delegate(DFALattice*) dg)
    {
        int ret;

        foreach (scv; this.buckets)
        {
            while (scv !is null)
            {
                ret = dg(scv.lr.lattice);
                if (ret)
                    return ret;

                scv = scv.next;
            }
        }

        return ret;
    }

    int opApply(scope int delegate(DFAVar*, DFALattice*) dg)
    {
        int ret;

        foreach (scv; this.buckets)
        {
            while (scv !is null)
            {
                ret = dg(scv.var, scv.lr.lattice);
                if (ret)
                    return ret;

                scv = scv.next;
            }
        }

        return ret;
    }

    int opApply(scope int delegate(DFAVar*, DFALattice*, DFAScopeVar*) dg)
    {
        int ret;

        foreach (scv; this.buckets)
        {
            while (scv !is null)
            {
                ret = dg(scv.var, scv.lr.lattice, scv);
                if (ret)
                    return ret;

                scv = scv.next;
            }
        }

        return ret;
    }
}

struct DFAArgumentListRef
{
    package DFAArgumentList* list;

    static if (DFACleanup)
    {
        this(ref DFAArgumentListRef other)
        {
            this.list = other.list;
            other.list = null;
        }

        ~this()
        {
            DFAArgumentList* current;

            while (this.list !is null)
            {
                current = this.list;
                this.list = current.listnext;

                current.dfaCommon.allocator.free(current);
            }
        }
    }

    bool isNull()
    {
        return list is null;
    }

    DFAArgumentList.Each* opIndex(size_t i)
    {
        DFAArgumentList* current = this.list;

        while (current !is null)
        {
            if (i < current.count)
                return &current.each[i];

            i -= current.count;
            current = current.listnext;
        }

        return null;
    }

    int opApply(scope int delegate(ubyte, DFAArgumentList*) del)
    {
        DFAArgumentList* current = this.list;

        while (current !is null)
        {
            foreach (i; 0 .. current.count)
            {
                const got = del(cast(ubyte) i, current);
                if (got)
                    return got;
            }

            current = current.listnext;
        }

        return 0;
    }
}

struct DFAArgumentList
{
    DFAArgumentList* listnext;
    DFACommon* dfaCommon;

    Each[32] each;
    ParameterDFAInfo[32] infoBuffer;

    ubyte count;

    struct Each
    {
        DFALatticeRef lr;
        ParameterDFAInfo* paramInfo;
    }
}

struct DFALatticeRef
{
    package DFALattice* lattice;

    static if (DFACleanup)
    {
        this(ref DFALatticeRef other)
        {
            this.lattice = other.lattice;
            other.lattice = null;
        }

        ~this()
        {
            if (isNull)
                return;

            DFAConsequence* c = lattice.lastInSequence;

            while (c !is null)
            {
                DFAConsequence* next = c.next;
                assert(next !is c);

                lattice.dfaCommon.allocator.free(c);
                c = next;
            }

            lattice.lastInSequence = null;

            if (lattice.constant !is null)
            {
                lattice.dfaCommon.allocator.free(lattice.constant);
                lattice.constant = null;
            }

            lattice.dfaCommon.allocator.free(lattice);
        }
    }

    bool isNull()
    {
        return lattice is null;
    }

    bool haveNonContext()
    {
        if (isNull)
            return false;

        DFAConsequence* cctx = this.getContext;

        foreach (c; this)
        {
            if (c !is cctx)
                return true;
        }

        return false;
    }

    bool isModellable()
    {
        bool ret = true;

        bool walker(DFAConsequence* c)
        {
            if (c.var !is null && !c.var.isModellable)
            {
                ret = false;
                return false;
            }

            return true;
        }

        this.walkMaybeTops(&walker);
        return ret;
    }

    DFAConsequence* findConsequence(DFAVar* var)
    {
        if (isNull)
            return null;

        return lattice.findConsequence(var);
    }

    DFAConsequence* addConsequence(DFAVar* var, DFAConsequence* copyFrom = null)
    {
        if (this.isNull)
            return null;

        return this.lattice.addConsequence(var, copyFrom);
    }

    DFAConsequence* getContext()
    {
        if (this.isNull)
            return null;

        return this.lattice.context;
    }

    DFAConsequence* getContext(out DFAVar* var)
    {
        if (this.isNull || this.lattice.context is null)
            return null;

        var = this.lattice.context.var;
        return this.lattice.context;
    }

    DFAVar* getContextVar()
    {
        if (this.isNull || this.lattice.context is null)
            return null;
        return this.lattice.context.var;
    }

    DFAObject* getContextObject()
    {
        if (isNull)
            return null;
        else
            return lattice.context.obj;
    }

    DFAConsequence* setContext(DFAConsequence* c)
    {
        if (c is null)
            return null;

        this.lattice.context = c;
        return c;
    }

    DFAConsequence* setContext(DFAVar* var)
    {
        if (isNull)
            return null;

        DFAConsequence* ret = this.addConsequence(var);
        this.lattice.context = ret;
        return ret;
    }

    DFAConsequence* getGateConsequence()
    {
        if (isNull || lattice.context is null)
            return null;
        else if (lattice.context.var !is null && lattice.context.maybe is null)
            return lattice.context;
        else if (lattice.context.var is null && lattice.context.maybe !is null)
        {
            if (DFAConsequence* c = this.findConsequence(lattice.context.maybe))
                return c.maybe is null ? c : null;
        }

        return null;
    }

    DFAVar* getGateConsequenceVariable()
    {
        if (isNull || lattice.context is null)
            return null;
        else if (lattice.context.var !is null && lattice.context.maybe is null)
            return lattice.context.var;
        else if (lattice.context.var is null && lattice.context.maybe !is null)
        {
            if (DFAConsequence* c = this.findConsequence(lattice.context.maybe))
                return c.maybe is null ? c.var : null;
        }

        return null;
    }

    DFAConsequence* acquireConstantAsContext()
    {
        assert(!isNull);
        return this.lattice.acquireConstantAsContext;
    }

    DFAConsequence* acquireConstantAsContext(Truthiness truthiness,
            Nullable nullable, DFAObject* obj)
    {
        assert(!isNull);

        DFAConsequence* ret = this.addConsequence(cast(DFAVar*) null);
        this.setContext(ret);

        ret.truthiness = truthiness;
        ret.nullable = nullable;
        ret.obj = obj;
        return ret;
    }

    /// DFAConsequence.maybeTopSeen will be set on the DFAConsequence if it was visited
    void walkMaybeTops(scope bool delegate(DFAConsequence*) del)
    {
        if (isNull || del is null)
            return;

        this.lattice.walkMaybeTops(del);
    }

    void cleanupConstant(DFAVar* contextVar)
    {
        if (!isNull)
            this.lattice.cleanupConstant(contextVar);
    }

    int opApply(scope int delegate(DFAConsequence* consequence) dg)
    {
        if (isNull)
            return 0;

        return this.lattice.opApply(dg);
    }

    void printStructure(const(char)* prefix = "", int sdepth = 0, int depth = 0)
    {
        if (this.isNull)
            return;
        this.lattice.printStructure(prefix, sdepth, depth);
    }

    void printState(const(char)* prefix = "", int sdepth = 0, int depth = 0)
    {
        if (this.isNull)
            return;
        this.lattice.printState(prefix, sdepth, depth);
    }

    void printActual(const(char)* prefix = "", int sdepth = 0, int depth = 0)
    {
        if (this.isNull)
            return;
        this.lattice.printActual(prefix, sdepth, depth);
    }

    DFALatticeRef copy()
    {
        if (this.lattice is null)
            return DFALatticeRef.init;
        return this.lattice.copy();
    }

    DFALatticeRef copyWithoutInfiniteLifetime()
    {
        if (this.lattice is null)
            return DFALatticeRef.init;
        return this.lattice.copyWithoutInfiniteLifetime();
    }

    void check()
    {
        if (!isNull)
            this.lattice.check;
    }
}

/***********************************************************
 * The collection of values and facts known about a variable.
 *
 * A DFALattice contains one or more `DFAConsequence` nodes.
 * Each `DFAConsequence` represents the state of a variable at the current
 * point in time.
 */
struct DFALattice
{
    private
    {
        DFALattice* listnext;

        DFACommon* dfaCommon;
        DFAConsequence* firstInSequence, lastInSequence;
        DFAConsequence*[16] buckets;

        DFAConsequence* constant;
    }

    DFAConsequence* context;

    DFAConsequence* findConsequence(DFAVar* var)
    {
        if (var is null)
            return this.constant;

        DFAConsequence** bucket = this.findBucketForVar(var);
        if (*bucket !is null && (*bucket).var is var)
            return *bucket;
        else
            return null;
    }

    DFAConsequence* addConsequence(DFAVar* var, DFAConsequence* copyFrom = null)
    {
        DFAConsequence* ret;

        if (var is null)
        {
            if (this.constant is null)
            {
                ret = dfaCommon.allocator.makeConsequence(var, copyFrom);
            }
            else
                ret = this.constant;

            this.constant = ret;
        }
        else
        {
            DFAConsequence** bucket = this.findBucketForVar(var);
            if (*bucket !is null && (*bucket).var is var)
                return *bucket;

            ret = dfaCommon.allocator.makeConsequence(var, copyFrom);

            if (this.lastInSequence !is null)
                this.lastInSequence.previous = ret;
            if (this.firstInSequence is null)
                this.firstInSequence = ret;

            ret.next = this.lastInSequence;
            this.lastInSequence = ret;

            if (copyFrom is null)
            {
                ret.writeOnVarAtThisPoint = var.writeCount;
            }

            ret.bucketNext = *bucket;
            *bucket = ret;
        }

        assert(ret !is ret.next);
        return ret;
    }

    DFAConsequence** findBucketForVar(DFAVar* var)
    {
        DFAConsequence** bucket = &buckets[cast(size_t) var % buckets.length];

        while (*bucket !is null && (*bucket).var < var)
        {
            bucket = &(*bucket).bucketNext;
        }

        return bucket;
    }

    DFAConsequence* acquireConstantAsContext()
    {
        DFAConsequence* ret = this.addConsequence(cast(DFAVar*) null);
        this.context = ret;

        ret.truthiness = Truthiness.Unknown;
        ret.nullable = Nullable.Unknown;
        return ret;
    }

    /// DFAConsequence.maybeTopSeen will be set on the DFAConsequence if it was visited
    void walkMaybeTops(scope bool delegate(DFAConsequence*) del)
    {
        bool handle(DFAConsequence* c)
        {
            if (c is null || c.maybeTopSeen)
                return true;

            c.maybeTopSeen = true;
            if (!del(c))
                return false;

            if (handle(this.findConsequence(c.maybe)))
                return true;
            return false;
        }

        foreach (c; this)
        {
            c.maybeTopSeen = false;
        }

        if (DFAConsequence* c = this.context)
        {
            if (c.var !is null && c.maybe is null)
                handle(c);
        }

        foreach (c; this)
        {
            if (c.maybeTopSeen)
                continue;

            if (c.maybe !is null)
            {
                if (!handle(c))
                    break;
            }
        }
    }

    void printStructure(const(char)* prefix = "", int sdepth = 0, int depth = 0)
    {
        static if (!dfaCommon.debugStructure)
            return;
        else
            printActual(prefix, sdepth, depth);
    }

    void printState(const(char)* prefix = "", int sdepth = 0, int depth = 0)
    {
        static if (!dfaCommon.debugIt)
            return;
        else
            printActual(prefix, sdepth, depth);
    }

    private void printActual(const(char)* prefix = "", int sdepth = 0, int depth = 0)
    {
        bool gotOne;

        foreach (consequence; this)
        {
            consequence.print(prefix, sdepth, depth, consequence is this.context);
            gotOne = true;
        }

        if (!gotOne)
            printPrefix("%s Lattice empty\n", sdepth, depth, prefix);
    }

    int opApply(scope int delegate(DFAConsequence* consequence) dg)
    {
        DFAConsequence* c = this.lastInSequence;
        int i;

        while (c !is null)
        {
            i = dg(c);
            if (i)
                return i;

            assert(c !is c.next);
            c = c.next;
        }

        if (this.constant !is null)
            return dg(this.constant);
        else
            return 0;
    }

    DFALatticeRef copy()
    {
        DFALatticeRef ret = dfaCommon.makeLatticeRef;

        if (this.constant !is null)
        {
            DFAConsequence* newC = ret.addConsequence(null, this.constant);

            if (this.context is this.constant)
                ret.setContext(newC);
        }

        DFAConsequence* oldC = this.firstInSequence;

        while (oldC !is null)
        {
            DFAConsequence* newC = ret.addConsequence(oldC.var, oldC);

            if (this.context is oldC)
                ret.setContext(newC);

            oldC = oldC.previous;
        }

        ret.check;
        return ret;
    }

    DFALatticeRef copyWithoutInfiniteLifetime()
    {
        DFALatticeRef ret = dfaCommon.makeLatticeRef;

        if (this.constant !is null)
        {
            DFAConsequence* newC = ret.addConsequence(null, this.constant);

            if (this.context is this.constant)
                ret.setContext(newC);
        }

        DFAConsequence* oldC = this.firstInSequence;

        while (oldC !is null)
        {
            if (!oldC.var.haveInfiniteLifetime)
            {
                DFAConsequence* newC = ret.addConsequence(oldC.var, oldC);

                if (this.context is oldC)
                    ret.setContext(newC);

            }
            oldC = oldC.previous;
        }

        if (ret.getContext is null)
            ret.acquireConstantAsContext;

        ret.check;
        return ret;
    }

    /// Remove constant if not context
    void cleanupConstant(DFAVar* contextVar)
    {
        if (contextVar is null)
            return;

        if (this.constant !is null)
        {
            dfaCommon.allocator.free(this.constant);

            if (this.context is this.constant)
                this.context = this.addConsequence(contextVar);

            this.constant = null;
        }
    }

    void check()
    {
        static if (DFACommon.debugVerify)
        {
            assert((this.firstInSequence is null && this.constant is null) || this.context !is null);

            foreach (c1; this)
            {
                size_t countFind, countPrevious;
                bool foundOurPrevious = c1.previous is null;

                foreach (c2; this)
                {
                    if (c1.var is c2.var)
                        countFind++;
                    if (c2.previous is c1)
                        countPrevious++;
                    if (c1.previous !is null && c1.previous is c2)
                        foundOurPrevious = true;
                }

                if (firstInSequence is c1)
                    countPrevious++;

                assert(countFind == 1);
                assert(countPrevious <= 1);
                assert(foundOurPrevious);
            }

            {
                DFAConsequence* temp = lastInSequence;

                while (temp !is null)
                {
                    assert(temp.listnext is null);
                    temp = temp.next;
                }
            }

            {
                DFAConsequence* temp = firstInSequence;

                while (temp !is null)
                {
                    assert(temp.listnext is null);
                    temp = temp.previous;
                }
            }
        }
    }
}

enum Truthiness : ubyte
{
    Unknown, // unmodelled
    Maybe, // if assert'd non-constant consequences apply in true branch
    False, // if false branch of if statement will be taken
    True, // if true branch of if statement will be taken
}

enum Nullable : ubyte
{
    Unknown,
    Null,
    NonNull
}

enum PAMathOp : ubyte
{
    add,
    sub,
    mul,
    div,
    mod,
    and,
    or,
    xor,
    pow,
    leftShift,
    rightShiftSigned,
    rightShiftUnsigned,

    postInc,
    postDec
}

// Point analysis, tracking of integral values such as a slice length or an integer typed variable/constant.
// Note that the math op functions here may not be correct.
// They'll just have to be fixed once a test case appears.
struct DFAPAValue
{
    enum Unknown = DFAPAValue(DFAPAValue.Kind.Unknown);

    Kind kind;

    // We use long to represent the VRP value, however this cuts off long.max .. ulong.max, represent this with UnknownUpperPositive.
    // By doing long we can ignore signedness and lower negative long.min .. int.min, making things simpler.
    long value;

    enum Kind : ubyte
    {
        Unknown,
        UnknownUpperPositive,
        Lower, // VRP lower inclusive
        Upper, // VRP upper inclusive
        Concrete
    }

    this(Kind kind)
    {
        this.kind = kind;
    }

    this(long value)
    {
        this.kind = Kind.Concrete;
        this.value = value;
    }

    int opCmp(const ref DFAPAValue other) const
    {
        if (this.kind != other.kind)
        {
            const difference = cast(int) this.kind - cast(int) other.kind;
            return difference < 0 ? -1 : 1;
        }
        else if (this.kind == Kind.Concrete && other.kind == Kind.Concrete)
            return this.value < other.value ? -1 : (this.value == other.value ? 0 : 1);
        else
            return 0;
    }

    DFAPAValue meet(DFAPAValue other)
    {
        if (this.kind != other.kind || this.kind != Kind.Concrete || this.value != other.value)
            return Unknown;
        else
            return this;
    }

    DFAPAValue join(DFAPAValue other)
    {
        if (this > other)
            return this;
        else
            return other;
    }

    Truthiness truthiness()
    {
        if (this.kind == Kind.UnknownUpperPositive)
            return Truthiness.True;
        else if (this.kind == Kind.Concrete || this.kind == Kind.Lower)
            return this.value > 0 ? Truthiness.True : Truthiness.False;
        else
            return Truthiness.Unknown;
    }

    bool canFitIn(Type type)
    {
        if (this.kind < Kind.Lower)
            return false;

        switch (type.ty)
        {
        case TY.Tint8:
            return byte.min <= this.value && this.value <= byte.max;

        case TY.Tuns8:
            return 0 <= this.value && this.value <= ubyte.max;

        case TY.Tint16:
            return short.min <= this.value && this.value <= short.max;

        case TY.Tuns16:
            return 0 <= this.value && this.value <= ushort.max;

        case TY.Tint32:
            return int.min <= this.value && this.value <= int.max;

        case TY.Tuns32:
            return 0 <= this.value && this.value <= uint.max;

        case TY.Tuns64:
        case TY.Tuns128:
            return 0 <= this.value;

        case TY.Tint64:
        case TY.Tint128:
            return true;

        default:
            return false;
        }
    }

    Truthiness compareEqual(ref DFAPAValue other)
    {
        if (this.kind == DFAPAValue.Kind.Unknown || other.kind == DFAPAValue.Kind.Unknown)
            return Truthiness.Unknown;

        const lhsConcrete = this.kind == DFAPAValue.Kind.Concrete;
        const rhsConcrete = other.kind == DFAPAValue.Kind.Concrete;

        if (lhsConcrete && rhsConcrete)
            return this.value == other.value ? Truthiness.True : Truthiness.False;
        else if ((lhsConcrete || rhsConcrete) && (this.kind == DFAPAValue.Kind.UnknownUpperPositive
                || other.kind == DFAPAValue.Kind.UnknownUpperPositive))
            return Truthiness.False;

        return Truthiness.Maybe;
    }

    Truthiness compareNotEqual(ref DFAPAValue other)
    {
        if (this.kind == DFAPAValue.Kind.Unknown || other.kind == DFAPAValue.Kind.Unknown)
            return Truthiness.Unknown;
        else if (this.kind < DFAPAValue.Kind.Concrete || other.kind < DFAPAValue.Kind.Concrete)
            return Truthiness.Maybe; // we can't know the value at this time of development but it could be equal

        if (this.kind == DFAPAValue.Kind.Concrete && other.kind == DFAPAValue.Kind.Concrete)
            return (this.value == other.value) ? Truthiness.False : Truthiness.True;

        return Truthiness.Maybe;
    }

    Truthiness greaterThan(ref DFAPAValue other)
    {
        Truthiness ret = Truthiness.Maybe;

        if (this.kind == DFAPAValue.Kind.Concrete && other.kind == DFAPAValue.Kind.Concrete)
            ret = this.value > other.value ? Truthiness.True : Truthiness.False;
        else if (this.kind == DFAPAValue.Kind.Concrete
                && other.kind == DFAPAValue.Kind.UnknownUpperPositive)
            ret = Truthiness.False;

        if (ret == Truthiness.False)
        {
            this = Unknown;
            other = Unknown;
        }
        else
        {
            DFAPAValue temp = other;

            if (temp.kind == DFAPAValue.Kind.Concrete)
            {
                if (temp.value < long.max)
                    temp.value++;
                else
                    temp.kind = DFAPAValue.Kind.UnknownUpperPositive;
            }

            other = other.meet(this);
            this = this.join(temp);

            if (other.kind > Kind.Lower)
                other.kind = Kind.Upper;
            if (this.kind >= Kind.Lower)
                this.kind = Kind.Lower;
        }

        return ret;
    }

    Truthiness greaterThanOrEqual(ref DFAPAValue other)
    {
        Truthiness ret = Truthiness.Maybe;

        if (this.kind == DFAPAValue.Kind.Concrete && other.kind == DFAPAValue.Kind.Concrete)
            ret = this.value >= other.value ? Truthiness.True : Truthiness.False;
        else if (this.kind == DFAPAValue.Kind.Concrete
                && other.kind == DFAPAValue.Kind.UnknownUpperPositive)
            ret = Truthiness.False;

        if (ret == Truthiness.False)
        {
            this = Unknown;
            other = Unknown;
        }
        else
        {
            other = other.meet(this);
            this = this.join(other);

            if (other.kind > Kind.Lower)
                other.kind = Kind.Upper;
            if (this.kind >= Kind.Lower)
                this.kind = Kind.Lower;
        }

        return ret;
    }

    void negate(Type type)
    {
        if (this.kind != Kind.Concrete || type is null)
        {
            this.kind = Kind.Unknown;
            return;
        }

        switch (type.ty)
        {
        case TY.Tint8:
            this.value = -cast(int)(cast(byte) this.value);
            break;
        case TY.Tint16:
            this.value = -cast(int)(cast(short) this.value);
            break;
        case TY.Tint32:
            this.value = -cast(int) this.value;
            break;
        case TY.Tint64:
        case TY.Tint128:
            this.value = -this.value;
            break;

        case TY.Tuns8:
            this.value = -cast(int)(cast(ubyte) this.value);
            break;
        case TY.Tuns16:
            this.value = -cast(int)(cast(ushort) this.value);
            break;
        case TY.Tuns32:
            this.value = -cast(uint) this.value;
            break;
        case TY.Tuns64:
        case TY.Tuns128:
            this.value = -this.value;
            break;

        default:
            this.kind = Kind.Unknown;
            break;
        }
    }

    void addFrom(DFAPAValue other, Type type)
    {
        if (this.kind != Kind.Concrete || other.kind != Kind.Concrete)
        {
            this.kind = Kind.Unknown;
            return;
        }

        if (type.isUnsigned)
        {
            if (this.value > 0 && other.value > 0 && this.value > (long.max - other.value))
            {
                // long.max .. ulong.max
                this.kind = Kind.UnknownUpperPositive;
                return;
            }
        }

        switch (type.ty)
        {
        case TY.Tint8:
            this.value = cast(byte) this.value + cast(byte) other.value;
            break;
        case TY.Tint16:
            this.value = cast(short) this.value + cast(short) other.value;
            break;
        case TY.Tint32:
            this.value = cast(int) this.value + cast(int) other.value;
            break;
        case TY.Tint64:
        case TY.Tint128:
            this.value = this.value + other.value;
            break;

        case TY.Tuns8:
            this.value = cast(ubyte) this.value + cast(ubyte) other.value;
            break;
        case TY.Tuns16:
            this.value = cast(ushort) this.value + cast(ushort) other.value;
            break;
        case TY.Tuns32:
            this.value = cast(uint) this.value + cast(uint) other.value;
            break;
        case TY.Tuns64:
        case TY.Tuns128:
            this.value = this.value + other.value;
            break;

        default:
            this.kind = Kind.Unknown;
            break;
        }
    }

    void subtractFrom(DFAPAValue other, Type type)
    {
        if (this.kind != Kind.Concrete || other.kind != Kind.Concrete)
        {
            this.kind = Kind.Unknown;
            return;
        }

        if (type.isUnsigned)
        {
            if (other.value > this.value)
            {
                this.kind = Kind.Unknown;
                return;
            }
        }

        switch (type.ty)
        {
        case TY.Tint8:
            this.value = cast(byte) this.value - cast(byte) other.value;
            break;
        case TY.Tint16:
            this.value = cast(short) this.value - cast(short) other.value;
            break;
        case TY.Tint32:
            this.value = cast(int) this.value - cast(int) other.value;
            break;
        case TY.Tint64:
        case TY.Tint128:
            this.value = this.value - other.value;
            break;

        case TY.Tuns8:
            this.value = cast(ubyte) this.value - cast(ubyte) other.value;
            break;
        case TY.Tuns16:
            this.value = cast(ushort) this.value - cast(ushort) other.value;
            break;
        case TY.Tuns32:
            this.value = cast(uint) this.value - cast(uint) other.value;
            break;
        case TY.Tuns64:
        case TY.Tuns128:
            this.value = this.value - other.value;
            break;

        default:
            this.kind = Kind.Unknown;
            break;
        }
    }

    void multiplyFrom(DFAPAValue other, Type type)
    {
        if (this.kind != Kind.Concrete || other.kind != Kind.Concrete)
        {
            this.kind = Kind.Unknown;
            return;
        }

        if (type.isUnsigned)
        {
            if (this.value > 1 && other.value > 1 && this.value > (long.max / other.value))
            {
                this.kind = Kind.UnknownUpperPositive;
                return;
            }
        }

        switch (type.ty)
        {
        case TY.Tint8:
            this.value = cast(byte) this.value * cast(byte) other.value;
            break;
        case TY.Tint16:
            this.value = cast(short) this.value * cast(short) other.value;
            break;
        case TY.Tint32:
            this.value = cast(int) this.value * cast(int) other.value;
            break;
        case TY.Tint64:
        case TY.Tint128:
            this.value = this.value * other.value;
            break;

        case TY.Tuns8:
            this.value = cast(ubyte) this.value * cast(ubyte) other.value;
            break;
        case TY.Tuns16:
            this.value = cast(ushort) this.value * cast(ushort) other.value;
            break;
        case TY.Tuns32:
            this.value = cast(uint) this.value * cast(uint) other.value;
            break;
        case TY.Tuns64:
        case TY.Tuns128:
            this.value = this.value * other.value;
            break;

        default:
            this.kind = Kind.Unknown;
            break;
        }
    }

    void divideFrom(DFAPAValue other, Type type)
    {
        if (this.kind != Kind.Concrete || other.kind != Kind.Concrete)
        {
            this.kind = Kind.Unknown;
            return;
        }

        this.kind = Kind.Unknown;

        if (!type.isUnsigned && this.value == long.min && other.value == -1)
        {
            return;
        }

        switch (type.ty)
        {
        case TY.Tint8:
            if (cast(byte) other.value == 0)
                return;
            this.value = cast(byte) this.value / cast(byte) other.value;
            break;
        case TY.Tint16:
            if (cast(short) other.value == 0)
                return;
            this.value = cast(short) this.value / cast(short) other.value;
            break;
        case TY.Tint32:
            if (cast(int) other.value == 0)
                return;
            this.value = cast(int) this.value / cast(int) other.value;
            break;
        case TY.Tint64:
        case TY.Tint128:
            if (other.value == 0)
                return;
            this.value = this.value / other.value;
            break;

        case TY.Tuns8:
            if (cast(ubyte) other.value == 0)
                return;
            this.value = cast(ubyte) this.value / cast(ubyte) other.value;
            break;
        case TY.Tuns16:
            if (cast(ushort) other.value == 0)
                return;
            this.value = cast(ushort) this.value / cast(ushort) other.value;
            break;
        case TY.Tuns32:
            if (cast(uint) other.value == 0)
                return;
            this.value = cast(uint) this.value / cast(uint) other.value;
            break;
        case TY.Tuns64:
        case TY.Tuns128:
            if (cast(ulong) other.value == 0)
                return;
            // Must cast to ulong to perform correct unsigned 64-bit division before final assignment.
            this.value = cast(long)(cast(ulong) this.value / cast(ulong) other.value);
            break;

        default:
            return;
        }

        this.kind = Kind.Concrete;
    }

    void modulasFrom(DFAPAValue other, Type type)
    {
        if (this.kind != Kind.Concrete || other.kind != Kind.Concrete || other.value == 0)
        {
            this.kind = Kind.Unknown;
            return;
        }

        if (!type.isUnsigned)
        {
            if (this.value == long.min && other.value == -1)
            {
                this.kind = Kind.Unknown;
                return;
            }
        }

        switch (type.ty)
        {
        case TY.Tint8:
            this.value = cast(byte) this.value % cast(byte) other.value;
            break;
        case TY.Tint16:
            this.value = cast(short) this.value % cast(short) other.value;
            break;
        case TY.Tint32:
            this.value = cast(int) this.value % cast(int) other.value;
            break;
        case TY.Tint64:
        case TY.Tint128:
            this.value = this.value % other.value;
            break;

        case TY.Tuns8:
            this.value = cast(ubyte) this.value % cast(ubyte) other.value;
            break;
        case TY.Tuns16:
            this.value = cast(ushort) this.value % cast(ushort) other.value;
            break;
        case TY.Tuns32:
            this.value = cast(uint) this.value % cast(uint) other.value;
            break;
        case TY.Tuns64:
        case TY.Tuns128:
            this.value = cast(long)(cast(ulong) this.value % cast(ulong) other.value);
            break;

        default:
            this.kind = Kind.Unknown;
            break;
        }
    }

    void leftShiftBy(DFAPAValue other, Type type)
    {
        if (this.kind != Kind.Concrete || other.kind != Kind.Concrete || other.value < 0)
        {
            this.kind = Kind.Unknown;
            return;
        }

        switch (type.ty)
        {
        case TY.Tint8:
            this.value = cast(byte) this.value << cast(byte) other.value;
            break;
        case TY.Tint16:
            this.value = cast(short) this.value << cast(short) other.value;
            break;
        case TY.Tint32:
            this.value = cast(int) this.value << cast(int) other.value;
            break;
        case TY.Tint64:
        case TY.Tint128:
            this.value = this.value << other.value;
            break;

        case TY.Tuns8:
            this.value = cast(ubyte) this.value << cast(ubyte) other.value;
            break;
        case TY.Tuns16:
            this.value = cast(ushort) this.value << cast(ushort) other.value;
            break;
        case TY.Tuns32:
            this.value = cast(uint) this.value << cast(uint) other.value;
            break;
        case TY.Tuns64:
        case TY.Tuns128:
            this.value = cast(ulong) this.value << cast(ulong) other.value;
            break;

        default:
            this.kind = Kind.Unknown;
            break;
        }
    }

    void rightShiftSignedBy(DFAPAValue other, Type type)
    {
        if (this.kind != Kind.Concrete || other.kind != Kind.Concrete || other.value < 0)
        {
            this.kind = Kind.Unknown;
            return;
        }

        switch (type.ty)
        {
        case TY.Tint8:
            this.value = cast(byte) this.value >> cast(byte) other.value;
            break;
        case TY.Tint16:
            this.value = cast(short) this.value >> cast(short) other.value;
            break;
        case TY.Tint32:
            this.value = cast(int) this.value >> cast(int) other.value;
            break;
        case TY.Tint64:
        case TY.Tint128:
            this.value = this.value >> other.value;
            break;

        case TY.Tuns8:
            this.value = cast(ubyte) this.value >>> cast(ubyte) other.value;
            break;
        case TY.Tuns16:
            this.value = cast(ushort) this.value >>> cast(ushort) other.value;
            break;
        case TY.Tuns32:
            this.value = cast(uint) this.value >>> cast(uint) other.value;
            break;
        case TY.Tuns64:
        case TY.Tuns128:
            this.value = cast(ulong) this.value >>> cast(ulong) other.value;
            break;

        default:
            this.kind = Kind.Unknown;
            break;
        }
    }

    void rightShiftUnsignedBy(DFAPAValue other, Type type)
    {
        if (this.kind != Kind.Concrete || other.kind != Kind.Concrete || other.value < 0)
        {
            this.kind = Kind.Unknown;
            return;
        }

        switch (type.ty)
        {
            // We cast to the unsigned equivalent of the target size (ubyte, ushort, uint)
            // to force the logical shift behavior (zero-filling).
        case TY.Tint8:
        case TY.Tuns8:
            this.value = cast(ubyte) this.value >>> cast(ubyte) other.value;
            break;
        case TY.Tint16:
        case TY.Tuns16:
            this.value = cast(ushort) this.value >>> cast(ushort) other.value;
            break;
        case TY.Tint32:
        case TY.Tuns32:
            this.value = cast(uint) this.value >>> cast(uint) other.value;
            break;
        case TY.Tint64:
        case TY.Tuns64:
        case TY.Tint128:
        case TY.Tuns128:
            // For 64-bit, we use ulong to perform the logical shift before casting back to long.
            this.value = cast(ulong) this.value >>> cast(ulong) other.value;
            break;

        default:
            this.kind = Kind.Unknown;
            break;
        }
    }

    void powerBy(DFAPAValue other, Type type)
    {
        const exponent = other.value;
        const base = this.value;

        if (this.kind != Kind.Concrete || other.kind != Kind.Concrete || exponent < 0)
        {
            this.kind = Kind.Unknown;
            return;
        }
        else if (exponent == 0)
        {
            // base ^^ 0
            this.value = 1;
            return;
        }
        else if (base == 0)
        {
            // 0 ^^ exponent
            this.value = 0;
            return;
        }
        else if (exponent == 1)
        {
            // base ^^ 1
            return;
        }

        const temp = cast(ulong) base ^^ cast(ulong) exponent;

        if (temp > long.max)
        {
            this.kind = Kind.UnknownUpperPositive;
            return;
        }

        switch (type.ty)
        {
        case TY.Tint8:
            this.value = cast(byte) temp;
            break;
        case TY.Tint16:
            this.value = cast(short) temp;
            break;
        case TY.Tint32:
            this.value = cast(int) temp;
            break;
        case TY.Tint64:
        case TY.Tint128:
            this.value = cast(long) temp;
            break;

        case TY.Tuns8:
            this.value = cast(ubyte) temp;
            break;
        case TY.Tuns16:
            this.value = cast(ushort) temp;
            break;
        case TY.Tuns32:
            this.value = cast(uint) temp;
            break;
        case TY.Tuns64:
        case TY.Tuns128:
            this.value = temp;
            break;

        default:
            this.kind = Kind.Unknown;
            break;
        }
    }

    void bitwiseAndBy(DFAPAValue other, Type type)
    {
        if (this.kind != Kind.Concrete || other.kind != Kind.Concrete)
        {
            this.kind = Kind.Unknown;
            return;
        }

        switch (type.ty)
        {
        case TY.Tint8:
            this.value = cast(byte) this.value & cast(byte) other.value;
            break;
        case TY.Tint16:
            this.value = cast(short) this.value & cast(short) other.value;
            break;
        case TY.Tint32:
            this.value = cast(int) this.value & cast(int) other.value;
            break;
        case TY.Tint64:
        case TY.Tint128:
            this.value = this.value & other.value;
            break;

        case TY.Tuns8:
            this.value = cast(ubyte) this.value & cast(ubyte) other.value;
            break;
        case TY.Tuns16:
            this.value = cast(ushort) this.value & cast(ushort) other.value;
            break;
        case TY.Tuns32:
            this.value = cast(uint) this.value & cast(uint) other.value;
            break;
        case TY.Tuns64:
        case TY.Tuns128:
            this.value = cast(ulong) this.value & cast(ulong) other.value;
            break;

        default:
            this.kind = Kind.Unknown;
            break;
        }
    }

    void bitwiseOrBy(DFAPAValue other, Type type)
    {
        if (this.kind != Kind.Concrete || other.kind != Kind.Concrete)
        {
            this.kind = Kind.Unknown;
            return;
        }

        switch (type.ty)
        {
        case TY.Tint8:
            this.value = cast(byte) this.value | cast(byte) other.value;
            break;
        case TY.Tint16:
            this.value = cast(short) this.value | cast(short) other.value;
            break;
        case TY.Tint32:
            this.value = cast(int) this.value | cast(int) other.value;
            break;
        case TY.Tint64:
        case TY.Tint128:
            this.value = this.value | other.value;
            break;

        case TY.Tuns8:
            this.value = cast(ubyte) this.value | cast(ubyte) other.value;
            break;
        case TY.Tuns16:
            this.value = cast(ushort) this.value | cast(ushort) other.value;
            break;
        case TY.Tuns32:
            this.value = cast(uint) this.value | cast(uint) other.value;
            break;
        case TY.Tuns64:
        case TY.Tuns128:
            this.value = cast(ulong) this.value | cast(ulong) other.value;
            break;

        default:
            this.kind = Kind.Unknown;
            break;
        }
    }

    void bitwiseXorBy(DFAPAValue other, Type type)
    {
        if (this.kind != Kind.Concrete || other.kind != Kind.Concrete)
        {
            this.kind = Kind.Unknown;
            return;
        }

        switch (type.ty)
        {
        case TY.Tint8:
            this.value = cast(byte) this.value ^ cast(byte) other.value;
            break;
        case TY.Tint16:
            this.value = cast(short) this.value ^ cast(short) other.value;
            break;
        case TY.Tint32:
            this.value = cast(int) this.value ^ cast(int) other.value;
            break;
        case TY.Tint64:
        case TY.Tint128:
            this.value = this.value ^ other.value;
            break;

        case TY.Tuns8:
            this.value = cast(ubyte) this.value ^ cast(ubyte) other.value;
            break;
        case TY.Tuns16:
            this.value = cast(ushort) this.value ^ cast(ushort) other.value;
            break;
        case TY.Tuns32:
            this.value = cast(uint) this.value ^ cast(uint) other.value;
            break;
        case TY.Tuns64:
        case TY.Tuns128:
            this.value = cast(ulong) this.value ^ cast(ulong) other.value;
            break;

        default:
            this.kind = Kind.Unknown;
            break;
        }
    }

    void bitwiseInvert(Type type)
    {
        if (this.kind != Kind.Concrete)
        {
            this.kind = Kind.Unknown;
            return;
        }

        switch (type.ty)
        {
        case TY.Tint8:
            this.value = ~cast(int)(cast(byte) this.value);
            break;
        case TY.Tint16:
            this.value = ~cast(int)(cast(short) this.value);
            break;
        case TY.Tint32:
            this.value = ~cast(int) this.value;
            break;
        case TY.Tint64:
        case TY.Tint128:
            this.value = ~this.value;
            break;

        case TY.Tuns8:
            this.value = ~cast(int)(cast(ubyte) this.value);
            break;
        case TY.Tuns16:
            this.value = ~cast(int)(cast(ushort) this.value);
            break;
        case TY.Tuns32:
            this.value = ~cast(uint) this.value;
            break;
        case TY.Tuns64:
        case TY.Tuns128:
            this.value = ~this.value;
            break;

        default:
            this.kind = Kind.Unknown;
            break;
        }
    }
}

/***********************************************************
 * A specific fact known about a variable at the current point in time.
 *
 * Examples of consequences:
 * - "This variable is definitely not null" (`nullable == NonNull`)
 * - "This variable is True" (`truthiness == True`)
 * - "This variable has the integer value 5" (`pa` - Point Analysis)
 */
struct DFAConsequence
{
    private
    {
        DFACommon* dfaCommon;
        DFAConsequence* listnext;
        DFAConsequence* previous, next, bucketNext;
    }

    // This will be null if it is a constant or effect
    DFAVar* var;
    // only valid when var.writeCount == writeOnVarAtThisPoint
    uint writeOnVarAtThisPoint;

    // Must be asserted to be true, at which point a join takes place
    Truthiness truthiness;
    // Ditto
    Nullable nullable;
    // Boolean logic can be inverted once,
    //  thanks to or and equality expressions we won't be tracking it beyond that one invert.
    bool invertedOnce;
    // Protect else bodies assertion of the condition from introducing unknowable things
    bool protectElseNegate;
    // When the context is maybe, look at this instead
    DFAVar* maybe;
    bool maybeTopSeen;
    // Point analysis value, tracking of integral/length values
    DFAPAValue pa;
    // The object that this is if its non-null
    DFAObject* obj;

    void copyFrom(DFAConsequence* other)
    {
        if (other is null)
            return;

        if (this.var is other.var)
            this.writeOnVarAtThisPoint = other.writeOnVarAtThisPoint;

        this.truthiness = other.truthiness;
        this.nullable = other.nullable;
        this.invertedOnce = other.invertedOnce;
        this.maybe = other.maybe;
        this.protectElseNegate = other.protectElseNegate;
        this.pa = other.pa;
        this.obj = other.obj;
    }

    void meetConsequence(DFAConsequence* c1, DFAConsequence* c2,
            bool couldScopeNotHaveRan = false, bool ignoreWriteCount = false,
            bool preferUnknown = false)
    {
        void doOne(DFAConsequence* c)
        {
            version (DebugJoinMeetOp)
            {
                printf("meet one c1 %p %d %d %d\n", c.var, c.truthiness,
                        c.nullable, c.writeOnVarAtThisPoint);
                fflush(stdout);
            }

            this.invertedOnce = c.invertedOnce;
            this.writeOnVarAtThisPoint = c.writeOnVarAtThisPoint;
            this.pa = couldScopeNotHaveRan ? DFAPAValue.Unknown : c.pa;
            this.obj = couldScopeNotHaveRan ? dfaCommon.makeObject(c.obj) : c.obj;

            if (this.var is null || this.var.isTruthy)
                this.truthiness = couldScopeNotHaveRan ? Truthiness.Unknown : c.truthiness;
            if (this.var is null || this.var.isNullable)
                this.nullable = couldScopeNotHaveRan ? Nullable.Unknown : c.nullable;
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

            this.writeOnVarAtThisPoint = c1.writeOnVarAtThisPoint > c2.writeOnVarAtThisPoint
                ? c1.writeOnVarAtThisPoint : c2.writeOnVarAtThisPoint;

            this.invertedOnce = this.truthiness == Truthiness.Unknown
                ? false : (c1.invertedOnce || c2.invertedOnce);

            this.pa = couldScopeNotHaveRan ? DFAPAValue.Unknown : c1.pa.meet(c2.pa);

            if (this.var is null || this.var.isNullable)
            {
                if (preferUnknown)
                    this.nullable = (c1.nullable != c2.nullable) ? Nullable.Unknown : c1.nullable;
                else
                    this.nullable = (couldScopeNotHaveRan && c1.nullable != c2.nullable)
                        ? Nullable.Unknown : (c1.nullable < c2.nullable ? c1.nullable : c2.nullable);

                if (c1.obj !is null || c2.obj !is null)
                {
                    if (c1.obj !is c2.obj)
                        this.obj = dfaCommon.makeObject(c1.obj, c2.obj);
                    else
                        this.obj = c1.obj !is null ? c1.obj : c2.obj;
                }
            }

            if (this.var is null || this.var.isBoolean)
            {
                if (preferUnknown)
                    this.truthiness = (c1.truthiness != c2.truthiness)
                        ? Truthiness.Unknown : c1.truthiness;
                else
                    this.truthiness = (couldScopeNotHaveRan && c1.truthiness != c2.truthiness)
                        ? Truthiness.Unknown : (c1.truthiness < c2.truthiness
                                ? c1.truthiness : c2.truthiness);

                if (this.truthiness == Truthiness.Maybe)
                    this.truthiness = Truthiness.Unknown;
            }
            else if (this.var.isNullable)
                this.truthiness = this.nullable == Nullable.NonNull ? Truthiness.True
                    : (this.nullable == Nullable.Null ? Truthiness.False : Truthiness.Unknown);
            else if (this.var.isTruthy)
                this.truthiness = this.pa.truthiness;
        }

        const writeCount = this.var.writeCount;

        version (DebugJoinMeetOp)
        {
            printf("meet consequence c1=%p, c2=%p\n", c1, c2);
            printf("            vars c1=%p, c2=%p\n", c1 !is null ? c1.var : null,
                    c2 !is null ? c2.var : null);
            printf("  writeCount=%d/%d:%d\n", writeCount,
                    c1.writeOnVarAtThisPoint, c2 !is null ? c2.writeOnVarAtThisPoint : -1);
            printf("  couldScopeNotHaveRan=%d, ignoreWriteCount=%d, preferUnknown=%d\n",
                    couldScopeNotHaveRan, ignoreWriteCount, preferUnknown);
            fflush(stdout);
        }

        if (c2 is null || (!ignoreWriteCount && c2.writeOnVarAtThisPoint < writeCount))
            doOne(c1);
        else
            doMulti;
    }

    // c1 may be the same consequence as this
    void joinConsequence(DFAConsequence* c1, DFAConsequence* c2, DFAConsequence* rhsCtx,
            bool isC1Context, bool ignoreWriteCount = false, bool unknownAware = false)
    {
        void doOne(DFAConsequence* c)
        {
            version (DebugJoinMeetOp)
            {
                printf("join one c %p %d %d %d, isC1=%d, isC2=%d\n", c.var,
                        c.truthiness, c.nullable, c.writeOnVarAtThisPoint, c is c1, c is c2);
                fflush(stdout);
            }

            this.invertedOnce = c.invertedOnce;
            this.writeOnVarAtThisPoint = c.writeOnVarAtThisPoint;
            this.maybe = c.maybe;
            this.pa = c.pa;
            this.obj = c.obj;

            if (this.var is null || this.var.isTruthy)
                this.truthiness = c.truthiness;
            if (this.var is null || this.var.isNullable)
                this.nullable = c.nullable;
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

            this.invertedOnce = c1.invertedOnce || c2.invertedOnce;
            this.writeOnVarAtThisPoint = c1.writeOnVarAtThisPoint < c2.writeOnVarAtThisPoint
                ? c2.writeOnVarAtThisPoint : c1.writeOnVarAtThisPoint;
            this.pa = c1.pa.join(c2.pa);

            if (this.var is null || this.var.isTruthy)
            {
                if (unknownAware && c1.truthiness == Truthiness.Unknown
                        || c2.truthiness == Truthiness.Unknown)
                    this.truthiness = Truthiness.Unknown;
                else
                    this.truthiness = c1.truthiness < c2.truthiness ? c2.truthiness : c1.truthiness;
            }

            if (this.var is null || this.var.isNullable)
            {
                if (unknownAware && c1.nullable == Nullable.Unknown
                        || c2.nullable == Nullable.Unknown)
                    this.nullable = Nullable.Unknown;
                else
                    this.nullable = c1.nullable < c2.nullable ? c2.nullable : c1.nullable;

                if (c1.obj !is null || c2.obj !is null)
                {
                    if (c1.obj !is c2.obj)
                        this.obj = dfaCommon.makeObject(c1.obj, c2.obj);
                    else
                        this.obj = c1.obj !is null ? c1.obj : c2.obj;
                }
            }

            this.maybe = c2.maybe;

            version (DebugJoinMeetOp)
            {
                printf("  result %d %d\n", this.truthiness, this.nullable);
                fflush(stdout);
            }
        }

        const writeCount = this.var.writeCount;

        version (DebugJoinMeetOp)
        {
            printf("join consequence c1=%p, c2=%p, rhsCtx=%p, this=%p\n", c1, c2, rhsCtx, &this);
            printf("            vars c1=%p, c2=%p, rhsCtx=%p, this=%p\n", c1 !is null
                    ? c1.var : null, c2 !is null ? c2.var : null, rhsCtx !is null
                    ? rhsCtx.var : null, this.var);
            printf("  writeCount=%d/%d:%d\n", writeCount,
                    c1.writeOnVarAtThisPoint, c2 !is null ? c2.writeOnVarAtThisPoint : -1);
            printf("  isC1Context=%d, unknownAware=%d, ignoreWriteCount=%d\n",
                    isC1Context, unknownAware, ignoreWriteCount);
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

    void print(const(char)* prefix = "", int sdepth = 0, int depth = 0, bool context = false)
    {
        static immutable TruthinessStr = [
            "unkno".ptr, "maybe".ptr, "false".ptr, " true".ptr
        ];
        static immutable NullableStr = ["unkno".ptr, " null".ptr, "!null".ptr];

        printPrefix(" %s%s ", sdepth, depth, context ? "+".ptr : " ".ptr, prefix);
        printf("%08p: ", this.var);
        printf("truthiness=%s, nullable=%s, write=%d, ", TruthinessStr[this.truthiness],
                NullableStr[this.nullable], this.writeOnVarAtThisPoint);
        printf("maybe=%p:%d, protectElseNegate=%d, invertedOnce=%d ", maybe,
                maybeTopSeen, protectElseNegate, invertedOnce);
        printf("previous=%p, next=%p, pa=%03d/%lld, obj=%p ", this.previous,
                this.next, this.pa.kind, this.pa.value, this.obj);

        if (this.var !is null)
        {
            printf("=%d:%lld:b/%p/%p", this.var.assertedCount,
                    this.var.offsetFromBase, this.var.base1, this.var.base2);

            if (this.var !is null && this.var.var !is null)
                printf("@%p=`%s`", this.var.var, this.var.var.toChars);
        }

        printf("\n", this.var);
    }
}

private:
void applyType(DFAVar* var, VarDeclaration vd)
{
    var.isNullable = vd.isRef || isTypeNullable(vd.type);
    var.isTruthy = isTypeTruthy(vd.type);

    var.isStaticArray = vd.type.isTypeSArray !is null;
    var.isBoolean = vd.type.ty == Tbool;
    var.isFloatingPoint = vd.type.isTypeBasic !is null
        && (vd.type.isTypeBasic.flags & TFlags.floating) != 0;
    var.isAA = vd.type.ty == Taarray;

    // don't trust DIP1000's scope infering on variables, we'll do our own equivalent behavior that is more dynamic.
    var.isScope = (vd.storage_class & STC.scope_) != 0 && (vd.storage_class & STC.scopeinferred) == 0;

    var.isByRef = (vd.storage_class & STC.ref_) == STC.ref_;

    // Unfortunately isDataseg can have very undesirable side effects that kill compilation,
    //  even if it shouldn't when this is ran.
    if (vd.parent !is null && vd.parent.isFuncDeclaration)
    {
        // Make sure the parent of this variable is a function, if it isn't then we can't model it.
        var.isStackVar = vd.canTakeAddressOf
            && (vd.storage_class & (STC.static_ | STC.extern_ | STC.gshared)) == 0;
    }
    else
        var.isStackVar = false;

    var.unmodellable = !var.isStackVar;
}

void printPrefix(Args...)(ref OutBuffer ob, const(char)* prefix, int sdepth, int edepth, Args args)
{
    ob.printf("%.*s", sdepth, PrintPipeText.ptr);

    if (edepth == 0)
        ob.write(">");
    else
        ob.printf(";%.*s>", edepth, PrintPipeText.ptr);

    ob.printf(prefix, args);
}

void printPrefix(Args...)(const(char)* prefix, int sdepth, int edepth, Args args)
{
    printf("%.*s", sdepth, PrintPipeText.ptr);

    if (edepth == 0)
        printf(">");
    else
        printf(";%.*s>", edepth, PrintPipeText.ptr);

    printf(prefix, args);
}

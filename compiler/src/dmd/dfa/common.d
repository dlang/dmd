module dmd.dfa.common;
import dmd.dfa.utils;
import dmd.declaration;
import dmd.statement;
import dmd.func;
import dmd.mtype;
import dmd.identifier;
import dmd.globals;
import dmd.dsymbol;
import core.stdc.stdio;

package static immutable PrintPipeText = "||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||";

// Old compiler versions have bugs with their copy constructors.
// Don't try to save memory by using moving to cleanup.
// Only relevant for bootstrapping purposes.
static if (__VERSION__ >= 2100)
{
    version = DFACleanup;
}

struct DFACommon
{
    DFAAllocator allocator;
    DFAScope* currentDFAScope;
    DFAScope* lastLoopyLabel;

    // Making these enum's instead of fields allows for significant performance gains
    enum debugIt = false;
    //enum debugIt = true;
    enum debugStructure = false;
    //enum debugStructure = true;
    enum debugUnknownAST = false;
    //enum debugUnknownAST = true;

    private
    {
        DFAVar*[16] vars;
        DFAVar*[16] varPairs;
        DFAVar* returnVar;
        DFAVar* infiniteLifetimeVar;

        DFALabelState*[16] forwardLabels;
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

    DFAVar* findVariable(VarDeclaration vd, DFAVar* childOf = null)
    {
        if (vd is null)
            return null;

        if (childOf is null)
        {
            DFAVar** bucket = &vars[(cast(size_t) cast(void*) vd) % vars.length];

            while (*bucket !is null && cast(void*)(*bucket).var < cast(void*) vd)
            {
                bucket = &(*bucket).next;
            }

            if (*bucket !is null && (*bucket).var is vd)
                return *bucket;

            DFAVar* ret = allocator.makeVar(vd);
            ret.next = *bucket;
            *bucket = ret;
            return ret;
        }
        else
            return allocator.makeVar(vd, childOf);
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
        }

        return childOf.indexVar;
    }

    DFAVar* findSliceLengthVar(DFAVar* childOf)
    {
        if (childOf is null)
            return null;

        if (childOf.lengthVar is null)
        {
            childOf.lengthVar = allocator.makeVar(null);
            childOf.lengthVar.base1 = childOf;
            childOf.lengthVar.isLength = true;
            childOf.lengthVar.haveInfiniteLifetime = childOf.haveInfiniteLifetime;
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

        ret.next = *bucket;
        *bucket = ret;
        return ret;
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

    SwitchStatement findSwitchGivenCase(CaseStatement cs, out DFAScope* target)
    {
        DFAScope* current = this.currentDFAScope;

        while (current !is null)
        {

            if (current.controlStatement !is null)
            {
                if (auto sw = current.controlStatement.isSwitchStatement)
                {
                    if (sw.cases !is null)
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
        }

        return this.infiniteLifetimeVar;
    }

    DFALatticeRef makeLatticeRef()
    {
        DFALatticeRef ret;
        ret.lattice = allocator.makeLattice(&this);
        ret.check;
        return ret;
    }

    void swapLattice(DFAVar* contextVar, scope DFALatticeRef delegate(DFALatticeRef) dg)
    {
        assert(contextVar !is null); // if this is null idk what is going on!

        if (this.currentDFAScope.depth < contextVar.declaredAtDepth)
            return;

        DFAScopeVar** bucket = &currentDFAScope.buckets[cast(
                    size_t) contextVar % currentDFAScope.buckets.length];

        while (*bucket !is null && (*bucket).var < contextVar)
            bucket = &(*bucket).next;

        if (*bucket is null || (*bucket).var !is contextVar)
            *bucket = allocator.makeScopeVar(&this, contextVar);

        if ((*bucket).lr.isNull)
        {
            (*bucket).lr = this.makeLatticeRef;
            (*bucket).lr.setContext(contextVar);
        }

        DFALatticeRef got = dg((*bucket).lr);

        if (!got.isNull)
        {
            (*bucket).lr = got;

            if ((*bucket).lr.isNull)
            {
                (*bucket).lr = this.makeLatticeRef();
                (*bucket).lr.setContext(contextVar);
            }
        }

        (*bucket).lr.check;
    }

    DFALatticeRef acquireLattice(DFAVar* var)
    {
        assert(var !is null);

        DFAScope* sc = this.currentDFAScope;
        DFALattice* l;

        while (sc !is null && (l = sc.findLattice(var)) is null)
        {
            assert(sc !is sc.parent);
            sc = sc.parent;
        }

        DFALatticeRef ret;

        if (sc is null)
        {
            ret = this.makeLatticeRef;
            ret.setContext(var);

            this.currentDFAScope.createAndInheritLattice(&this, var, ret.lattice);
        }
        else
        {
            sc = sc.child;

            while (sc !is null)
            {
                sc.createAndInheritLattice(&this, var, l);
                sc = sc.child;
            }

            ret = l.copy;
        }

        return ret;

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

    DFAScopeVar* acquireScopeVar(DFAVar* var)
    {
        if (this.currentDFAScope.depth < var.declaredAtDepth)
            return null;

        DFAScopeRef scr;
        scr.sc = this.currentDFAScope;
        scope (exit)
            scr.sc = null;

        DFAScopeVar* scv, ret;

        while (!scr.isNull && (scv = scr.findScopeVar(var)) is null
                && scr.sc.depth < var.declaredAtDepth)
        {
            scr.sc = scr.sc.parent;
        }

        assert(scv is null || scv.var is var);

        DFAConsequence* c;

        if (scv is null)
        {
            // init new state
            scr.sc = this.currentDFAScope;
            ret = scr.getScopeVar(var);

            c = ret.lr.getContext;
            assert(ret.var is var);
            assert(c !is null);
            assert(c.var is var);

            return ret;
        }
        else
        {
            c = scv.lr.getContext;
            assert(c !is null);
            assert(c.var is var);
        }

        scr.sc = scr.sc.child;
        ret = scv;

        while (!scr.isNull)
        {
            ret = scr.getScopeVar(var);
            assert(ret.var is var);
            // if we had state that we wanted copied, we'd do it here

            ret.lr = scv.lr.copy;

            c = ret.lr.getContext;
            assert(c !is null);
            assert(c.var is var);

            scr.sc = scr.sc.child;
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
            while (current.parent !is null && current.label !is ident)
            {
                current = current.parent;
            }
        }

        return (current !is null && (current.label is ident || current.controlStatement !is null)) ? current
            : null;
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
        debug
        {
            DFAScope* sc = this.currentDFAScope;

            while (sc !is null)
            {
                foreach (var, l, scv; *sc)
                {
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
    private
    {
        __gshared
        {
            DFAVar* freelistvar;
            DFAScopeVar* freelistscopevar;
            DFAScope* freelistscope;
            DFALattice* freelistlattice;
            DFAConsequence* freelistconsequence;
        }

        DFAVar* allocatedlistvar, allocatedlistlastvar;
    }

    ~this()
    {
        if (allocatedlistvar !is null)
        {
            allocatedlistlastvar.listnext = freelistvar;
            freelistvar = allocatedlistvar;
        }
    }

    static void deinitialize()
    {
        freelistvar = null;
        freelistscopevar = null;
        freelistscope = null;
        freelistlattice = null;
        freelistconsequence = null;
    }

    DFAVar* makeVar(VarDeclaration vd, DFAVar* childOf = null)
    {
        DFAVar* ret;
        DFAVar** bucket;

        if (childOf !is null)
        {
            bucket = &childOf.childVars[(cast(size_t) cast(void*) vd) % childOf.childVars.length];

            while (*bucket !is null && cast(void*)(*bucket).next < cast(void*) vd)
            {
                bucket = &(*bucket).next;
            }

            if (*bucket !is null && (*bucket).var is vd)
                return *bucket;
        }

        if (freelistvar is null)
            ret = new DFAVar;
        else
        {
            ret = freelistvar;
            freelistvar = freelistvar.listnext;
        }

        *ret = DFAVar.init;
        ret.var = vd;
        ret.base1 = childOf;
        ret.offsetFromBase = -1;

        if (vd !is null)
            applyType(ret, vd);

        if (childOf !is null)
        {
            ret.haveInfiniteLifetime = childOf.haveInfiniteLifetime;
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
        DFAScopeVar* ret;

        if (freelistscopevar is null)
            ret = new DFAScopeVar;
        else
        {
            ret = freelistscopevar;
            freelistscopevar = freelistscopevar.freelistnext;
        }

        *ret = DFAScopeVar(null, null, var);
        return ret;
    }

    DFAScope* makeScope(DFACommon* dfaCommon, DFAScope* parent)
    {
        DFAScope* ret;

        if (freelistscope is null)
            ret = new DFAScope;
        else
        {
            ret = freelistscope;
            freelistscope = freelistscope.freelistnext;
        }

        *ret = DFAScope(dfaCommon, null);
        ret.parent = parent;
        return ret;
    }

    DFALattice* makeLattice(DFACommon* dfaCommon)
    {
        DFALattice* ret;

        if (freelistlattice is null)
            ret = new DFALattice;
        else
        {
            ret = freelistlattice;
            freelistlattice = freelistlattice.freelistnext;
        }

        *ret = DFALattice.init;
        ret.dfaCommon = dfaCommon;
        return ret;
    }

    DFAConsequence* makeConsequence(DFAVar* var, DFAConsequence* copyFrom = null)
    {
        DFAConsequence* ret;

        if (freelistconsequence is null)
            ret = new DFAConsequence;
        else
        {
            ret = freelistconsequence;
            freelistconsequence = freelistconsequence.freelistnext;
        }

        if (copyFrom is null)
        {
            *ret = DFAConsequence.init;
            ret.var = var;
        }
        else
        {
            *ret = *copyFrom;
            ret.previous = null;
            ret.next = null;
        }
        return ret;
    }

    DFALabelState* makeLabelState(Identifier ident)
    {
        DFALabelState* ret = new DFALabelState;
        ret.ident = ident;
        return ret;
    }

    void free(DFAScopeVar* s)
    {
        s.freelistnext = freelistscopevar;
        freelistscopevar = s;
    }

    void free(DFAScope* s)
    {
        version (none)
        {
            DFAScope* current = s.dfaCommon.currentDFAScope;

            while (current !is null)
            {
                assert(current !is s);
                current = current.parent;
            }
        }

        s.beforeScopeState = DFAScopeRef.init;
        s.afterScopeState = DFAScopeRef.init;

        s.freelistnext = freelistscope;
        freelistscope = s;
    }

    void free(DFALattice* s)
    {
        s.freelistnext = freelistlattice;
        freelistlattice = s;
    }

    void free(DFAConsequence* s)
    {
        s.freelistnext = freelistconsequence;
        freelistconsequence = s;
    }
}

struct DFALabelState
{
    private DFALabelState* next;

    Identifier ident;
    DFAScopeRef scr;
}

struct DFAVar
{
    private
    {
        DFAVar* listnext;
        DFAVar* next;
        DFAVar*[16] childVars;
        DFAVar* childOffsetVars;
        DFAVar* indexVar;
        DFAVar* lengthVar;
    }

    DFAVar* base1;
    DFAVar* base2;

    VarDeclaration var;
    dinteger_t offsetFromBase; // -1 if its not an offset

    bool isAnIndex; // base1[index] = this
    bool isLength; // T[].length

    bool isAPointer;
    bool isStaticArray;
    bool isByRef;

    bool haveInfiniteLifetime;

    int declaredAtDepth;
    int writeCount;

    DFAVar* dereferenceVar; // child var

    bool unmodellable; // DO NOT REPORT!!!!
    bool hasBeenAsserted;

    ParameterDFAInfo* param;

    bool haveBase()
    {
        return this.base1 !is null;
    }

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

    void visitFirstBase(scope void delegate(DFAVar* var) del)
    {
        if (this.base1 is null)
            return;

        del(this.base1);

        if (this.base2 !is null)
            del(this.base2);
    }

    void visitDereferenceBases(scope void delegate(DFAVar* var) del)
    {
        void handle(DFAVar* var)
        {
            while (var.base2 is null && var.base1 !is null
                    && (var.base1.dereferenceVar is var
                        || (var.offsetFromBase != -1 && var.var is null)))
            {
                var = var.base1;
            }

            if (var.base2 !is null)
            {
                handle(var.base1);
                handle(var.base2);
            }
            else
                del(var);
        }

        handle(&this);
    }

    void visitIfReferenceToAnotherVar(scope void delegate(DFAVar* var) del)
    {
        void handle(DFAVar* var, int refed)
        {
            while (var.base2 is null && var.base1 !is null)
            {
                if (var.offsetFromBase != -1 && var.var is null)
                    refed++;
                else if (var.base1.dereferenceVar is var)
                    refed--;
                else
                    break;

                var = var.base1;
            }

            if (var.base2 !is null)
            {
                handle(var.base1, refed);
                handle(var.base2, refed);
            }
            else if (refed > 0)
                del(var);
        }

        handle(&this, 0);
    }

    bool isModellable()
    {

        DFAVar* temp = &this;
        while (temp !is null)
        {
            if (temp.unmodellable)
                return false;
            temp = temp.base1;
        }

        return true;
    }

}

struct DFAScopeVar
{
    private
    {
        DFAScopeVar* freelistnext;
        DFAScopeVar* next;
    }

    DFAVar* var;
    DFALatticeRef lr;

    int derefDepth;
    int derefAssertedDepth;

    int assignDepth;
    int assertDepth;
}

struct DFAScopeRef
{
    package DFAScope* sc;

    version (DFACleanup)
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
        }
    }

    bool isNull()
    {
        return sc is null;
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
        this.check;

        DFAScopeVar** bucket = &sc.buckets[cast(size_t) contextVar % sc.buckets.length];

        while (*bucket !is null && (*bucket).var < contextVar)
            bucket = &(*bucket).next;

        DFAScopeVar* scv = *bucket;

        if (scv is null || scv.var !is contextVar)
        {
            scv = sc.dfaCommon.allocator.makeScopeVar(sc.dfaCommon, contextVar);
            scv.lr = this.sc.dfaCommon.makeLatticeRef;
            scv.lr.setContext(contextVar);

            scv.next = *bucket;
            *bucket = scv;
        }

        this.check;
        return scv;
    }

    DFALatticeRef consumeNext(out DFAVar* contextVar)
    {
        if (sc is null)
            return DFALatticeRef.init;

        foreach (ref bucket; sc.buckets)
        {
            if (bucket is null)
                continue;

            DFAScopeVar* scv = bucket;
            contextVar = scv.var;
            bucket = scv.next;

            DFALatticeRef lr = scv.lr;
            sc.dfaCommon.allocator.free(scv);
            return lr;
        }

        return DFALatticeRef.init;
    }

    DFALatticeRef consumeVar(DFAVar* contextVar)
    {
        if (sc is null)
            return DFALatticeRef.init;

        DFAScopeVar** bucket = &sc.buckets[cast(size_t) contextVar % sc.buckets.length];

        while (*bucket !is null && (*bucket).var < contextVar)
            bucket = &(*bucket).next;

        if (*bucket is null || (*bucket).var !is contextVar)
            return DFALatticeRef.init;

        DFAScopeVar* scv = *bucket;
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

    void print(const(char)* prefix = "", int sdepth = 0,
            FuncDeclaration currentFunction = null, int depth = 0)
    {
        if (this.isNull)
            return;

        this.sc.print(prefix, sdepth, currentFunction, depth);
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

        DFAScopeRef ret;
        ret.sc = sc.dfaCommon.allocator.makeScope(this.sc.dfaCommon, this.sc.parent);
        ret.sc.depth = sc.depth;

        // not everything is copied over as it isn't important

        foreach (var, lr, scv; this)
        {
            ret.sc.createAndInheritLattice(sc.dfaCommon, var, lr);
        }

        ret.check;
        return ret;
    }

    void check()
    {
        if (!this.isNull)
            this.sc.check;
    }
}

struct DFAScope
{
    private
    {
        DFACommon* dfaCommon;
        DFAScope* freelistnext;
        DFAScope* previousLoopyLabel;
    }

    DFAScope* parent, child;
    DFAScopeVar*[16] buckets;
    int depth;

    bool haveJumped; // thrown, goto, break, continue, return
    bool haveReturned;
    bool isLoopyLabel; // Is a loop or label
    bool isLoopyLabelKnownToHaveRun; // was the loopy label guaranteed to have at least one iteration?

    Statement controlStatement; // needed to apply on iteration for continue, loops switch statements ext.
    Identifier label;

    CompoundStatement compoundStatement;
    size_t inProgressCompoundStatement;

    TryFinallyStatement tryFinallyStatement;

    DFAScopeRef beforeScopeState, afterScopeState;

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

        while (*bucket !is null && (*bucket).var < contextVar)
            bucket = &(*bucket).next;

        if (*bucket is null || (*bucket).var !is contextVar)
            return null;
        return *bucket;
    }

    DFAScopeVar* createAndInheritLattice(DFACommon* dfaCommon,
            DFAVar* contextVar, DFALattice* copyFrom)
    {
        assert(contextVar !is null); // if this is null idk what is going on!

        DFAScopeVar** bucket = &this.buckets[cast(size_t) contextVar % this.buckets.length];

        while (*bucket !is null && (*bucket).var < contextVar)
            bucket = &(*bucket).next;

        if (*bucket is null || (*bucket).var !is contextVar)
        {
            DFAScopeVar* scv = dfaCommon.allocator.makeScopeVar(dfaCommon, contextVar);
            scv.next = *bucket;
            *bucket = scv;
        }

        if ((*bucket).lr.isNull)
        {
            (*bucket).lr = copyFrom !is null ? copyFrom.copy : dfaCommon.makeLatticeRef;
            (*bucket).lr.setContext(contextVar);
        }

        return *bucket;
    }

    DFAScopeVar* assignLattice(DFAVar* contextVar, DFALatticeRef lr)
    {
        if (lr.isNull)
            return null;

        DFAScopeVar** bucket = &this.buckets[cast(size_t) contextVar % this.buckets.length];

        while (*bucket !is null && (*bucket).var < contextVar)
            bucket = &(*bucket).next;

        DFAScopeVar* scv = *bucket;

        if (scv is null || scv.var !is contextVar)
        {
            scv = this.dfaCommon.allocator.makeScopeVar(this.dfaCommon, contextVar);
            scv.next = *bucket;
            *bucket = scv;
        }

        lr.setContext(contextVar);
        scv.lr = lr;
        scv.lr.check;

        return scv;
    }

    void print(const(char)* prefix = "", int sdepth = 0,
            FuncDeclaration currentFunction = null, int depth = 0)
    {
        if (!this.dfaCommon.debugIt)
            return;
        else
        {
            printPrefix("%s Scope", sdepth, currentFunction, depth, prefix);
            printf(" %p depth=%d, completed=%d:%d", &this, this.depth,
                    this.haveReturned, this.haveJumped);

            if (this.label !is null)
                printf(", label=`%s`\n", this.label.toChars);
            else
                printf("\n");

            if (!this.beforeScopeState.isNull || !this.afterScopeState.isNull)
            {
                printPrefix("%s before scope state:\n", sdepth, currentFunction, depth, prefix);
                this.beforeScopeState.print(prefix, sdepth, currentFunction, depth);

                printPrefix("%s after scope state:\n", sdepth, currentFunction, depth, prefix);
                this.afterScopeState.print(prefix, sdepth, currentFunction, depth);
            }

            DFALatticeRef lr;

            foreach (contextVar, l, scv; this)
            {
                lr.lattice = l;

                printPrefix("%s on %p", sdepth, currentFunction, depth + 1, prefix, contextVar);

                if (contextVar !is null)
                {
                    printf(";%d", contextVar.declaredAtDepth);

                    if (contextVar.base1 !is null)
                        printf(":%p", contextVar.base1);
                    if (contextVar.base2 !is null)
                        printf(":%p", contextVar.base2);

                    if (contextVar.var !is null)
                        printf("@%p=`%s`", contextVar.var, contextVar.var.toChars);

                    printf(", deref=%d:%d", scv.derefDepth, scv.derefAssertedDepth);
                    printf(", assign=%d, assert=%d", scv.assignDepth, scv.assertDepth);
                }

                printf(", write=%d:\n", contextVar.writeCount);
                lr.print(prefix, sdepth, currentFunction, depth + 1);
            }

            lr.lattice = null;
        }
    }

    void check()
    {
        debug
        {
            foreach (contextVar1, l1; this)
            {
                assert(l1 !is null);

                DFALatticeRef lr1;
                lr1.lattice = l1;

                size_t count;

                foreach (contextVar2, l2; this)
                {
                    if (contextVar1 is contextVar2)
                        count++;
                }

                assert(count == 1);
                lr1.check;

                lr1.lattice = null;
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

struct DFALatticeRef
{
    package DFALattice* lattice;

    version (DFACleanup)
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

        if (var is null)
            return lattice.constant;

        foreach (c; this)
        {
            if (c.var is var)
                return c;
        }

        return null;
    }

    DFAConsequence* addConsequence(DFAVar* var, DFAConsequence* copyFrom = null)
    {
        if (this.isNull)
            return null;

        if (DFAConsequence* c = this.findConsequence(var))
            return c;

        DFAConsequence* ret = lattice.dfaCommon.allocator.makeConsequence(var, copyFrom);

        if (var !is null)
        {
            if (lattice.lastInSequence !is null)
                lattice.lastInSequence.previous = ret;
            if (lattice.firstInSequence is null)
                lattice.firstInSequence = ret;

            ret.next = lattice.lastInSequence;
            lattice.lastInSequence = ret;

            if (copyFrom !is null)
            {
                ret.invertedOnce = copyFrom.invertedOnce;
                ret.protectElseNegate = copyFrom.protectElseNegate;
                ret.writeOnVarAtThisPoint = copyFrom.writeOnVarAtThisPoint;
            }
            else
            {
                ret.writeOnVarAtThisPoint = var.writeCount;
            }
        }
        else
        {
            lattice.constant = ret;
        }

        assert(ret !is ret.next);
        return ret;
    }

    DFAConsequence* getContext()
    {
        if (this.isNull)
            return null;

        return this.lattice.context;
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

    DFAConsequence* acquireConstantAsContext()
    {
        assert(!isNull);

        DFAConsequence* ret = this.addConsequence(cast(DFAVar*) null);
        this.setContext(ret);

        ret.truthiness = Truthiness.Unknown;
        ret.nullable = Nullable.Unknown;
        return ret;
    }

    DFAConsequence* acquireConstantAsContext(Truthiness truthiness, Nullable nullable)
    {
        assert(!isNull);

        DFAConsequence* ret = this.addConsequence(cast(DFAVar*) null);
        this.setContext(ret);

        ret.truthiness = truthiness;
        ret.nullable = nullable;
        return ret;
    }

    /// DFAConsequence.maybeTopSeen will be set on the DFAConsequence if it was visited
    void walkMaybeTops(scope bool delegate(DFAConsequence*) del)
    {
        if (isNull || del is null)
            return;

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

        if (DFAConsequence* c = this.getContext)
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

    int opApply(scope int delegate(DFAConsequence* consequence) dg)
    {
        if (isNull)
            return 0;

        return this.lattice.opApply(dg);
    }

    void print(const(char)* prefix = "", int sdepth = 0,
            FuncDeclaration currentFunction = null, int depth = 0)
    {
        if (this.isNull)
            return;
        this.lattice.print(prefix, sdepth, currentFunction, depth);
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

struct DFALattice
{
    private
    {
        DFALattice* freelistnext;

        DFACommon* dfaCommon;
        DFAConsequence* firstInSequence, lastInSequence;

        DFAConsequence* constant;
    }

    DFAConsequence* context;

    void print(const(char)* prefix = "", int sdepth = 0,
            FuncDeclaration currentFunction = null, int depth = 0)
    {
        if (!dfaCommon.debugIt)
            return;
        else
        {
            printPrefix("%s Lattice:\n", sdepth, currentFunction, depth, prefix);

            foreach (consequence; this)
            {
                consequence.print(prefix, sdepth, currentFunction, depth,
                        consequence is this.context);
            }
        }
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

    void check()
    {
        debug
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

struct DFAConsequence
{
    private
    {
        DFAConsequence* freelistnext;
        DFAConsequence* previous, next;
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

    void print(const(char)* prefix = "", int sdepth = 0,
            FuncDeclaration currentFunction = null, int depth = 0, bool context = false)
    {
        static immutable TruthinessStr = [
            "unkno".ptr, "maybe".ptr, "false".ptr, " true".ptr
        ];
        static immutable NullableStr = ["unkno".ptr, " null".ptr, "!null".ptr];

        printPrefix(" %s%s ", sdepth, currentFunction, depth, context ? "+".ptr : " ".ptr, prefix);
        printf("%p: ", &this);
        printf("truthiness=%s, nullable=%s, write=%d, ", TruthinessStr[this.truthiness],
                NullableStr[this.nullable], this.writeOnVarAtThisPoint);
        printf("maybe=%p:%d, protectElseNegate=%d, invertedOnce=%d ", maybe,
                maybeTopSeen, protectElseNegate, invertedOnce);
        printf("previous=%p, next=%p ", this.previous, this.next);

        printf("%p", this.var);
        if (this.var !is null)
        {
            printf("=%d:%lld:b/%p/%p", this.var.hasBeenAsserted,
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
    var.isAPointer = vd.isRef || isTypePointer(vd.type);
    var.isStaticArray = vd.type.isTypeSArray !is null;
    var.unmodellable = vd.semanticRun < PASS.semantic2 || vd.isDataseg;
}

void printPrefix(Args...)(const(char)* prefix, int sdepth,
        FuncDeclaration currentFunction, int depth, Args args)
{
    printf("%.*s[%p];%.*s>", sdepth, PrintPipeText.ptr, currentFunction, depth, PrintPipeText.ptr);
    printf(prefix, args);
}

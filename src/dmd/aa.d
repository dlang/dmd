module dmd.aa;
import dmd.arraytypes;
import dmd.astenums;
import dmd.declaration;
import dmd.dscope;
import dmd.dsymbolsem;
import dmd.expression;
import dmd.func;
import dmd.globals;
import dmd.errors;
import dmd.identifier;
import dmd.mtype;
import dmd.semantic2;
import dmd.statement;
import dmd.target;
import dmd.expression;
import dmd.root.rmem;
import core.stdc.string;

/// Describes the layout of an entry in the array
/// it's essentailly struct { KeyType key; ValueType val };
/// needs to be in sync with druntime
@("druntime", "abi")
extern (C++) struct AALayout
{
    /// number of inital buckts
    /// (also the final number since it's immutable)
    const uint init_size;

    /// sizeof keyType
    const uint keysz;
    /// sizeof valueType
    const uint valsz;
    /// align requirement of valueType
    const uint valalign;
    /// offset of the value from the beginning of the entry
    const uint valoff;
    /// padding between value and key, if any.
    const uint padSize;
    /// size of the entry. padding included
    const uint entrySize;
}

@("druntime", "abi")
private AALayout computeAALayout(Type keyType, Type valueType, size_t length)
{
    // from aaA.d
    @("druntime", "abi")
    static size_t nextpow2(const size_t n) pure nothrow @nogc
    {
        import core.bitop : bsr;

        if (!n)
            return 1;
        const isPowerOf2 = !((n - 1) & n);
        return 1 << (bsr(n) + !isPowerOf2);
    }

    // from aaA.d
    @("druntime", "abi")
    static uint talign(uint tsize, uint algn) @safe pure nothrow @nogc
    {
        immutable mask = algn - 1;
        assert(!(mask & algn));
        return (tsize + mask) & ~mask;
    }

    assert(length <= uint.max, "aa literal length must not be greater than uint.max");

    @("druntime", "abi") enum GROW_NUM = 4;
    @("druntime", "abi") enum GROW_DEN = 5;
    // shrink threshold
    @("druntime", "abi") enum SHRINK_NUM = 1;
    @("druntime", "abi") enum SHRINK_DEN = 8;
    // grow factor
    @("druntime", "abi") enum GROW_FAC = 4;
    // growing the AA doubles it's size, so the shrink threshold must be
    // smaller than half the grow threshold to have a hysteresis
    static assert(GROW_FAC * SHRINK_NUM * GROW_DEN < GROW_NUM * SHRINK_DEN);
    // initial load factor (for literals), mean of both thresholds
    @("druntime", "abi") enum INIT_NUM = (GROW_DEN * SHRINK_NUM + GROW_NUM * SHRINK_DEN) / 2;
    @("druntime", "abi") enum INIT_DEN = SHRINK_DEN * GROW_DEN;

    const valsz    = cast(uint)valueType.size(Loc.initial);
    const valalign = cast(uint)valueType.alignsize();
    const keysz    = cast(uint)  keyType.size(Loc.initial);
    const valoff   = cast(uint)talign(keysz, valalign);

    AALayout aaLayout =
    {
        init_size : cast(uint)nextpow2(INIT_DEN * length / INIT_NUM),
        keysz     : keysz,
        valsz     : valsz,
        valalign  : valalign,
        valoff    : valoff,
        padSize   : cast(uint)(keysz - valoff),
        entrySize : valoff + valsz,
    };

    return aaLayout;
}

/// this piece of code has to be kept in line with druntime
/// look for mix
@("druntime", "abi")
static ulong hashFinalize(ulong hash, uint targetPtrsize) @nogc nothrow pure @safe
{
    // -------- copy and paste from druntime beg ----------
    static ulong mix(ulong h_in, uint targetPtrsize) nothrow @nogc pure @safe
    {
        // final mix function of MurmurHash2
        enum m = 0x5bd1e995;
        if (targetPtrsize == 4)
        {
            uint h = cast(uint) h_in;
            h ^= h >> 13;
            h *= m;
            h ^= h >> 15;
            h_in = h;
        }
        else
        {
            ulong h = h_in;
            h ^= h >> 13;
            h *= m;
            h ^= h >> 15;
            h_in = h;
        }
        return h_in;
    }

    const HASH_FILLED_MARK = (ulong(1) << 8 * targetPtrsize - 1);

    return mix(hash, targetPtrsize) | HASH_FILLED_MARK;
    // -------- copy and paste from druntime end ----------

}

extern (C++) struct AABucket
{
    ulong hash;
    uint elementIndex;
}
private
static bool evalHash(scope Expression key, scope Type keyType, scope out Expression hash_result)
{
    scope Expression call;
    // need to get the key-type hash function.
    FuncDeclaration fd_tohash = null;

    // if it's a struct search for the toHash()
    // this is an optimisation as it means cheap expressionSemantic
    if (auto st = keyType.isTypeStruct())
    {
        import dmd.id;
        auto keyTypeStructDecl = st.sym;
        assert(keyTypeStructDecl);
        auto toHash = keyTypeStructDecl.search(key.loc, Id.tohash);
        fd_tohash  = toHash ? toHash.isFuncDeclaration() : null;
    }

    if (fd_tohash)
    {
        scope dotvar = new DotVarExp(key.loc, key, fd_tohash);
        call = new CallExp(key.loc, dotvar);
    }
    else
    {
        // didn't find a to-hash let's use hashOf from druntime.internal.hash
        auto loadCoreInternalHash()
        {
            // TODO factor this with expressionsem.d into load runtime module
            import dmd.dmodule;
            import dmd.dimport;
            import dmd.id;
            import dmd.identifier;
            import dmd.dsymbolsem;
            __gshared Import impCoreInternalHash = null;
            __gshared Identifier[2] coreInternalID;
            if (!impCoreInternalHash)
            {
                coreInternalID[0] = Id.core;
                coreInternalID[1] = Identifier.idPool("internal");
                auto s = new Import(key.loc, coreInternalID[], Identifier.idPool("hash"), null, false);
                // Module.load will call fatal() if there's no std.math available.
                // Gag the error here, pushing the error handling to the caller.
                uint errors = global.startGagging();
                s.load(null);
                if (s.mod)
                {
                    s.mod.importAll(null);
                    s.mod.dsymbolSemantic(null);
                }
                global.endGagging(errors);
                impCoreInternalHash = s;
            }
            return impCoreInternalHash.mod;
        }

        auto se = new ScopeExp(key.loc, loadCoreInternalHash());
        import dmd.identifier;
        scope dotid = new DotIdExp(key.loc, se, Identifier.idPool("hashOf"));
        call = new CallExp(key.loc, dotid, key);
    }
    {
        import dmd.expressionsem;
        import dmd.dinterpret;

        import dmd.dscope;
        scope Scope* _scope = new Scope();
        call.expressionSemantic(_scope);
        hash_result = call.ctfeInterpret();
    }

    import dmd.ctfeexpr : exceptionOrCantInterpret;

    if (!hash_result || hash_result.exceptionOrCantInterpret())
    {
        key.loc.errorSupplemental("Only types with CTFEable toHash are supported as AA initializers");
        if (fd_tohash)
        {
            key.loc.errorSupplemental("`%s.toHash` errored during CTFE or didn't compile", keyType.toPrettyChars());
        }
        else
        {
            key.loc.errorSupplemental("hashOf(`%s`) didn't compile or errored during CTFE", keyType.toPrettyChars());
        }

        return false;
    }
    return true;
}


// returns false if the evaulation of the hash_function failed.
private
bool hashKeys(Expressions* keys, Type keyType, ref ulong[] key_hashes, ref size_t hash_counter)
{
    const length = keys.length;
    assert(key_hashes.length == length);
    auto ptrSize = target.ptrsize;
    scope Expression key;
    foreach(i; 0 .. length)
    {
        key = (*keys)[i];

        scope Expression hash_result;
        if (evalHash(key, keyType, hash_result))
        {
            ulong hash = hash_result.toUInteger();
            hash = hashFinalize(hash, ptrSize);
            key_hashes[i] = hash;
            // now we increment the count
            hash_counter++;
        }
        else
        {
            return false;
        }
    }

    return true;
}
struct BucketUsageInfo
{
    uint used;
    uint first_used;
    uint last_used;
}

/// after calling computeBucketOrder will reorder the buckets such that they are the order that they will be in the AA.
/// please use computeAALayout to find out how many buckets to allocate
private
BucketUsageInfo computeBucketOrder(return ref AABucket[] buckets,
                                   ref in AALayout aaLayout,
                                   ref in ulong[] key_hashes,
                                   in Expressions* keys,
                                   ref size_t hash_counter)
{
    assert(buckets.length == aaLayout.init_size);
    const length = keys.length;

    BucketUsageInfo bucketUsage =
    {
        first_used : uint.max,
        last_used : 0,
        used : 0,
    };

    uint min (uint a, uint b) { auto min = a; if (a > b) min = b; return min; }
    uint max (uint a, uint b) { auto max = a; if (a < b) max = b; return max; }

    memset(buckets.ptr, 0xFF, buckets.length * buckets[0].sizeof);

    // this is the meat ... computing which element(Index) goes into which bucket
    const size_t mask = (aaLayout.init_size - 1);

    foreach (i; 0 .. length)
    {
        // this is why the init_size has to be a power of 2
        // otherwise we couldn't optimize % to &
        while(hash_counter < i)
        {
            // busy wait ... so sue me!
        }
        // we have to make sure the hash_counter doesn't signal error
        if (hash_counter == -1)
        {
            // hashing errored
            // we can recognize the error outside because of the hash_counter
            // there's nothing more to do here
            return BucketUsageInfo.init;
        }
        uint elementIndex = cast(uint)i;
        const hash = key_hashes[i];

        scope key = (*keys)[elementIndex];
        // inlined find lookup slot if it's empty we insert ourselves here
        for(size_t idx = hash & mask, j = 1;;++j)
        {
            auto bucket = buckets[idx];
            if (bucket.hash == ulong.max
                && bucket.elementIndex == uint.max)
            {
                buckets[idx].hash = hash;
                buckets[idx].elementIndex = elementIndex;
                bucketUsage.first_used = min(bucketUsage.first_used, cast(uint)idx);
                bucketUsage.last_used = max(bucketUsage.last_used, cast(uint)idx);
                bucketUsage.used++;
                break;
            }
            else if (bucket.hash == hash)
                //hashes equal are we overriding an element
            {
                // it seems like we deduplicate the AssocArrayLiteral somewhere.
                // so this code-path is not strictly needed ...
                // let's leave it in just to be safe
                auto key2 = (*keys)[bucket.elementIndex];
                import dmd.ctfeexpr;
                import dmd.tokens : TOK;
                scope fakeLoc = Loc.init;
                scope isSame = ctfeIdentity(fakeLoc, TOK.identity, cast()key, cast()key2);
                if (isSame)
                {
                    // if they're the same we override.
                    buckets[idx].elementIndex = elementIndex;
                    break;
                }
            }
            idx = (idx + j) & mask;
            // we look for the next slot and continue
        }
        // insertion of elementIndex complete
    }

    return bucketUsage;
}

/// call this first to know how many buckets to allocate
extern (C++)
AALayout computeLayout(AssocArrayLiteralExp aale)
{
    scope TypeAArray aaType = aale.type.isTypeAArray();
    assert(aaType);

    scope length = aale.keys.length;
    scope valueType = aaType.nextOf().toBasetype();
    scope keyType = aaType.index;

    return computeAALayout(keyType, valueType, length);
}

/// After you have called `computeLayout` we expect you to give a pointer to a
/// bucket arrray which you have allocated. it needs to have enough memory for
/// aaLayout.init_size number of buckets
/// we will return you a BucketUsageInfo which gives you information you have to
/// write into the Literal
/// we will also write a valid bucket_array into the memory
/// from which you can know in the order in which we wish the buckets to be written
/// we expect you to write this structure
/// struct AAImplEntries
///{
///    size_t buckets_length;
///    dt_t* buckets_ptr;
///    uint used;
///    uint deleted;
///    void* fakeTIEntry;
///    uint first_used;
///    uint keysz;
///    uint valsz;
///    uint valoff;
///    ubyte flags;
///}
///Where buckets_ptr needs to point to an array of
/// struct { hash_t hash, struct Elem* elem }
/// this array needs have a length of initial_size
/// You also have to emit pointer to an elemStruct whenever the elementIndex is not ulong.max
/// Elem looks like: struct { KeyType key, ubyte[padSize] pad; ValueType value; }
///a Return value of BucketUsageInfo.init implies that hashing failed
extern (C++)
BucketUsageInfo MakeAALiteralInfo(AssocArrayLiteralExp aale, AALayout aaLayout, AABucket* bucketMem)
{
    // kick off the hashing;
    scope TypeAArray aaType = aale.type.isTypeAArray();

    scope valueType = aaType.nextOf().toBasetype();
    scope keyType = aaType.index;

    const length = aale.keys.length;

    ulong[] key_hashes = (cast(ulong*)mem.xmalloc(length * ulong.sizeof))[0 .. length];
    scope(exit) mem.xfree(key_hashes.ptr);

    align(16) size_t hash_ready_counter;

    if (!hashKeys(aale.keys, keyType, key_hashes, hash_ready_counter))
    {
        return BucketUsageInfo.init;
    }

    AABucket[] buckets = (cast(AABucket*)bucketMem)[0 .. aaLayout.init_size];
    memset(buckets.ptr, 0xFF, aaLayout.init_size * AABucket.sizeof);
    // new we order the buckets as we need to
    auto bucketUsage = computeBucketOrder(buckets, aaLayout, key_hashes, aale.keys, hash_ready_counter);

    // after we are done the hash_ready_counter should be the length of keys
    assert(aale.keys.length == hash_ready_counter);

    return bucketUsage;
}

/+
It would be nice if this worked but for now we don't know howto inject the auto-generated hasher properly
+/
version (none)
{
FuncDeclaration makeHasher(scope Type keyType, Scope* sc)
{
    import dmd.dmodule;
    auto mod = Module.create("__generated__"[], Identifier.idPool("__generated__"), 0, 0);
    Loc declLoc;
    auto parameters = new Parameters(1);
    (*parameters)[0] = (new Parameter(STC.const_, keyType.arrayOf, Identifier.idPool("in_keys"), null, null));
    auto tf = new TypeFunction(ParameterList(parameters), Type.thash_t.arrayOf(), LINK.d, STC.nothrow_ | STC.trusted);
    Identifier id = Identifier.generateAnonymousId("hasher");
    auto hasher = new FuncDeclaration(declLoc, declLoc, id, STC.static_, tf);
    hasher.generated = true;

    const(char)[] code = q{
        import core.internal.hash;
        hash_t[] result = new hash_t[](in_keys.length);
        {
            size_t kIdx = 0;
            for (; kIdx < in_keys.length; kIdx++)
            {
                result[kIdx] = hashOf(in_keys[kIdx]);
            }
        }
        return result;
    };

    hasher.fbody = new CompileStatement(declLoc, new StringExp(declLoc, code));
    Scope* sc2 = sc.push();
    sc2.stc = 0;
    sc2.linkage = LINK.d;
    hasher.dsymbolSemantic(sc2);
    hasher.semantic2(sc2);
    sc2.pop();

    return hasher;
}


static void evalHashs(scope Expressions* keys, scope Type keyType, scope ref ulong[] hash_results, scope Scope* sc, Loc loc = Loc.init)
{
    import dmd.ctfe.bc_common;
    assert(keys.length == hash_results.length, "keys.length: " ~ itos(cast(uint)keys.length)  ~ "  hash_results.length: " ~ itos(cast(uint)hash_results.length)) ;
    scope in_keys = new ArrayLiteralExp(loc, keyType.arrayOf.constOf(), keys);
    scope CallExp call;

    import dmd.expressionsem;
    call = cast(CallExp)call.expressionSemantic(sc);
    scope ArrayLiteralExp ale = (call.ctfeInterpret()).isArrayLiteralExp();

    assert(ale);
    foreach(i, ref hash_result; hash_results)
    {
        auto hash = (*ale.elements)[i].toUInteger();
        hash_results[i] = hashFinalize(hash, target.ptrsize);
    }

    return ;
}
}

// test EH
void throwException()
{
    throw new Exception(null);
}

Exception collectException(void delegate() dg)
{
    try
        dg();
    catch (Exception e)
        return e;
    return null;
}

// test GC
__gshared Object root;
void alloc() { root = new Object(); }
void access() { assert(root.toString() !is null); } // vtbl call will fail if finalized
void free() { root = null; }

Object tls_root;
void tls_alloc() { tls_root = new Object(); }
void tls_access() { assert(tls_root.toString() !is null); } // vtbl call will fail if finalized
void tls_free() { tls_root = null; }

// test Init
shared uint shared_static_ctor, shared_static_dtor, static_ctor, static_dtor;
shared static this() { ++shared_static_ctor; }
shared static ~this() { ++shared_static_dtor; }
static this() { ++static_ctor; }
static ~this() { ++static_dtor; }

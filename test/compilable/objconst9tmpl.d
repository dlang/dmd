
// Template matching

template a(T : Object) {
    enum a = 1;
}

static assert(a!(Object));
static assert(!is(typeof(a!(const(Object))))); // no match
static assert(!is(typeof(a!(const(Object)ref)))); // no match
static assert(!is(typeof(a!(immutable(Object))))); // no match
static assert(!is(typeof(a!(immutable(Object)ref)))); // no match
static assert(!is(typeof(a!(shared(Object))))); // no match
static assert(!is(typeof(a!(shared(Object)ref)))); // no match

template ap(T : int*) {
    enum ap = 1;
}

static assert(ap!(int*));
static assert(ap!(const(int*))); // FIXME: should not match
static assert(ap!(const(int)*)); // FIXME: should not match
static assert(ap!(immutable(int*))); // FIXME: should not match
static assert(ap!(immutable(int)*)); // FIXME: should not match
static assert(ap!(shared(int*))); // FIXME: should not match
static assert(ap!(shared(int)*)); // FIXME: should not match


template b(T : const(Object)) {
    enum b = 1;
}

static assert(b!(Object));
static assert(b!(const(Object)));
static assert(b!(const(Object)ref));
static assert(b!(immutable(Object)));
static assert(b!(immutable(Object)ref));
static assert(!is(typeof(b!(shared(Object))))); // no match
static assert(!is(typeof(b!(shared(Object)ref)))); // no match

template bp(T : const(int*)) {
    enum bp = 1;
}

static assert(bp!(int*));
static assert(bp!(const(int*)));
static assert(bp!(const(int)*));
static assert(bp!(immutable(int*)));
static assert(bp!(immutable(int)*));
static assert(bp!(shared(int*))); // FIXME: should not match
static assert(bp!(shared(int)*)); // FIXME: should not match


template c(T : const(Object)ref) {
    enum c = 1;
}

static assert(c!(Object));
static assert(c!(const(Object))); // FIXME: should not match (const ref)
static assert(c!(const(Object)ref));
static assert(c!(immutable(Object))); // FIXME: should not match (immutable ref)
static assert(c!(immutable(Object)ref));
static assert(!is(typeof(c!(shared(Object))))); // no match
static assert(!is(typeof(c!(shared(Object)ref)))); // no match

template cp(T : const(int)*) {
    enum cp = 1;
}

static assert(cp!(int*));
static assert(cp!(const(int*))); // FIXME: should not match (const ptr)
static assert(cp!(const(int)*));
static assert(cp!(immutable(int*))); // FIXME: should not match (immutable ptr)
static assert(cp!(immutable(int)*));
static assert(cp!(shared(int*))); // FIXME: should not match
static assert(cp!(shared(int)*)); // FIXME: should not match


// Type deduction

template d(T : U ref, U) {
    alias U d;
}

static assert(is(d!(Object) == Object));
static assert(!is(d!(const(Object)))); // no match (const ref)
static assert(is(d!(const(Object)ref) == const(Object)ref));
static assert(!is(d!(immutable(Object)))); // no match (immutable ref)
static assert(is(d!(immutable(Object)ref) == immutable(Object)ref));
static assert(!is(d!(shared(Object)))); // no match (shared ref)
static assert(is(d!(shared(Object)ref) == shared(Object)ref));

static assert(!is(d!(int))); // no match: 'ref' prevents matching non-class

template dp(T : U*, U) {
    alias U dp;
}

static assert(is(dp!(int*) == int));
static assert(is(dp!(const(int*)) == const(int))); // FIXME: should not match (const ptr)
static assert(is(dp!(const(int)*) == const(int)));
static assert(is(dp!(immutable(int*)) == immutable(int))); // FIXME: should not match (immutable ptr)
static assert(is(dp!(immutable(int)*) == immutable(int)));
static assert(is(dp!(shared(int*)) == shared(int))); // FIXME: should not match (shared ptr)
static assert(is(dp!(shared(int)*) == shared(int)));


template e(T : const(U), U) {
    alias U e;
}

static assert(is(e!(Object) == Object));
static assert(is(e!(const(Object)) == const(Object)ref)); // FIXME: should == Object
static assert(is(e!(const(Object)ref) == const(Object)ref)); // FIXME: should == Object
static assert(is(e!(immutable(Object)) == immutable(Object)ref)); // FIXME: should == Object
static assert(is(e!(immutable(Object)ref) == immutable(Object)ref)); // FIXME: should == Object
static assert(!is(e!(shared(Object)))); // no match
static assert(!is(e!(shared(Object)ref))); // no match

template ep(T : const(U*), U) {
    alias U ep;
}

static assert(is(ep!(int*) == int));
static assert(is(ep!(const(int*)) == int));
static assert(is(ep!(const(int)*) == int));
static assert(is(ep!(immutable(int*)) == int));
static assert(is(ep!(immutable(int)*) == int));
static assert(!is(ep!(shared(int*)))); // no match
static assert(!is(ep!(shared(int)*))); // no match


template f(T : const(U)ref, U) {
    alias U f;
}

static assert(is(f!(Object) == Object));
static assert(!is(f!(const(Object)))); // no match (const ref)
static assert(is(f!(const(Object)ref) == const(Object)ref)); // FIXME: should == Object
static assert(!is(f!(immutable(Object)))); // no match (immutable ref)
static assert(is(f!(immutable(Object)ref) == immutable(Object)ref)); // FIXME: should == Object
static assert(!is(f!(shared(Object)))); // no match
static assert(!is(f!(shared(Object)ref))); // no match

template fp(T : const(U)*, U) {
    alias U fp;
}

static assert(is(fp!(int*) == int));
static assert(is(fp!(const(int*)) == int)); // FIXME: should not match (const ptr)
static assert(is(fp!(const(int)*) == int));
static assert(is(fp!(immutable(int*)) == int)); // FIXME: should not match (immutable ref)
static assert(is(fp!(immutable(int)*) == int));
static assert(!is(fp!(shared(int*)))); // no match
static assert(!is(fp!(shared(int)*))); // no match


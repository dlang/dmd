
// Mangling with no 'ref' suffix is be preserved
static assert((shared(Object)).mangleof == "OC6Object");
static assert((const(Object)).mangleof == "xC6Object");
static assert((immutable(Object)).mangleof == "yC6Object");
static assert((shared(const(Object))).mangleof == "OxC6Object");
static assert((inout(Object)).mangleof == "NgC6Object");
static assert((shared(inout(Object))).mangleof == "ONgC6Object");

// Mangling with 'ref' suffix: the 'X' represents the suffix and is only present
// when the reference's modifiers is different from those of the class.
static assert((const(Object)ref).mangleof == "XxC6Object");
static assert((const(immutable(Object)ref)).mangleof == "xXyC6Object");
static assert((shared(inout(Object)ref)).mangleof == "OXOxC6Object");

// Reference suffix is not mangled when it has the same modifiers
static assert((const(Object ref)).mangleof == "xC6Object");
static assert((inout(Object ref)).mangleof == "NgC6Object");


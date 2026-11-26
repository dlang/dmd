static assert(is(typeof(0b1f) == float));
static assert(is(typeof(0b1F) == float));
static assert(0b1f == 1f);
static assert(0b1F == 1F);

static assert(0b1 == 1);
static assert(1f == 1.0f);
static assert(0x1p0 == 1.0);

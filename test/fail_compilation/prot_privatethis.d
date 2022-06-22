/*
REQUIRED_ARGS: -preview=privateThis
TEST_OUTPUT:
---
fail_compilation/prot_privatethis.d(35): Error: no property `secret` for type `prot_privatethis.C.Nested`
fail_compilation/prot_privatethis.d(56): Error: no property `secret` for type `prot_privatethis.C`
fail_compilation/prot_privatethis.d(57): Error: no property `internalFunc` for type `prot_privatethis.C`
fail_compilation/prot_privatethis.d(58): Error: no property `mixedInSecret` for type `prot_privatethis.C`
fail_compilation/prot_privatethis.d(61): Error: no property `secret` for type `prot_privatethis.U`
---
*/

mixin template MT()
{
    private(this) string mixedInSecret;
    void accessSecret() { secret++; }
}

class C
{
    private(this) int secret;
    mixin MT!();

    struct Nested
    {
        private(this) int secret;
        void setSecret(int secret) { this.secret = secret; }
    }

    Nested nested;

    this(int secret)
    {
        this.secret = secret;
        nested.secret = 3; // no access
        nested.setSecret(3); // access
        mixedInSecret = "s"; // access
        internalFunc(); // access
        accessSecret(); // access
    }

    private(this) void internalFunc() { }
}

static assert(__traits(getVisibility, C.secret) == "private(this)");

union U
{
    private(this) int secret;
    private int butNotReally;
}

void main()
{
    C c = new C(2);
    assert(c.secret == 2); // no access
    c.internalFunc(); // no access
    c.mixedInSecret = ""; // no access

    U u;
    u.secret = 3; // no access
    u.butNotReally = 4; // access
}

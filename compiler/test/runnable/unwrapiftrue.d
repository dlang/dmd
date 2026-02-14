module unwrapiftrue;
import core.attribute : mustuse;

@mustuse // not required, part of nominal usage.
struct Optional(Type) {
    private {
        // Do not do any clever tricks to prevent destructor being called when haveValue is false.
        Type value;
        bool haveValue;
    }

    this(Type value) {
        this.value = value;
        this.haveValue = true;
    }

    bool opCast(T:bool)() => haveValue;

    Type opUnwrapIfTrue() {
        assert(haveValue);
        return value;
    }
}

void main() {
    auto oi = Optional!int(2);
    auto oip = new Optional!int(52);

    if (int i = oi) {
        // got a value!
        assert(i == 2);
    } else {
        assert(0); // error, there is meant to be a value
    }

    if (auto i = oi) {
        // got a value!
        static assert(is(typeof(i) == int));
        assert(i == 2);
    } else {
        assert(0); // error, there is meant to be a value
    }

    if (int i = *oip) {
        // got a value!
        assert(i == 52);
    } else {
        assert(0); // error, there is meant to be a value
    }

    if (auto i = *oip) {
        // got a value!
        static assert(is(typeof(i) == int));
        assert(i == 52);
    } else {
        assert(0); // error, there is meant to be a value
    }

    checkDestructor();
}

int hadDestructor;

struct Destructor {
    ~this() {
        hadDestructor++;
    }
}

void checkDestructor() {
    auto od = Optional!Destructor(Destructor());

    assert(hadDestructor == 1);

    {
        if (Destructor d = od) {
            // got a value!
        } else {
            assert(0); // error, there is meant to be a value
        }

        assert(hadDestructor == 3);
    }

    {
        try {
            if (Destructor d = od) {
                // got a value!
                throw new Exception("");
            } else {
                assert(0); // error, there is meant to be a value
            }

        } catch (Exception e) {
        }

        assert(hadDestructor == 5);
    }

    {
        od = typeof(od).init;
        assert(hadDestructor == 6);

        // Verify that the pinned value that holds result type will get destroyed on false path as well.
        if (Destructor d = od) {
            // got a value!
            assert(0); // error, there is no value
        } else {
            // ok, no value!
        }

        assert(hadDestructor == 7);
    }
}

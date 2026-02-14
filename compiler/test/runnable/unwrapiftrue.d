module unwrapiftrue;
import core.attribute : mustuse;

@mustuse
struct Optional(Type) {
    private {
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
}


string getMixin (TArg..., int i = 0) () {
    return ``;
}

class Thing (TArg...) {
    mixin(getMixin!(TArg)());
}

public Thing!() stuff;


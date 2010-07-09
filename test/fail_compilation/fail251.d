bool foo() {
        foreach (x; xs) {}
        return true;
}

static assert(foo());

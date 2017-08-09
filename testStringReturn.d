string fn(bool v)
{
    return v ? "true" : "false";
}

static assert(fn(true) == "true");
static assert(fn(false) == "false");


enum union Value
{
    case None(),
}

struct Payload {}

static assert(is(Value == enum union));
static assert(!is(int == enum union));
static assert(!is(Payload == enum union));
// REQUIRED_ARGS: -g

struct Bug7127a {
    const(Bug7127a)* self;
}

struct Bug7127b {
    void function(const(Bug7127b) self) foo;
}

void main() {
    Bug7127a a;
    Bug7127b b;
}

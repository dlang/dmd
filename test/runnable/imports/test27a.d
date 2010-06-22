module imports.test27a;

import std.boxer;

class myClass(T) {
public:
    void func(T v) {
        Box b = std.boxer.box(v);
    }
}


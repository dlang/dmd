void main() {
    auto f1 = function() body { }; // fine
    auto f2 = function() in { } body { }; // fine
    auto f3 = function() out { } body { }; // error
    auto f4 = function() in { } out { } body { }; // error
/+
    auto d1 = delegate() body { }; // fine
    delegate() in { } body { }; // fine
    delegate() out { } body { }; // error
    delegate() in { } out { } body { }; // error
+/
}

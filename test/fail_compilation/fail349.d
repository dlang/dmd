// Error: bug6109throwing is not nothrow
// Error: function fail349.bug6109noThrow 'bug6109noThrow' is nothrow yet may throw

int bug6109throwing() {
    throw new Exception("throws");
}
int bug6109noThrow() nothrow {
    auto g = [4][0 .. bug6109throwing()];
    return 0;
}


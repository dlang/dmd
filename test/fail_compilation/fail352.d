
struct Range {
    bool empty;
    int front() { return 0; }
    void popFront() { empty = true; }
}

void main() {
    // no index for range foreach
    foreach(i, v; Range()) {}
}

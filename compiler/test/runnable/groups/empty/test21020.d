// https://github.com/dlang/dmd/issues/21020

shared struct Queue {
    int[int] map;
}

shared static this() {
    auto queue = Queue();
    (cast(int[int]) queue.map)[1] = 2;
    assert(queue.map[1] == 2);
}

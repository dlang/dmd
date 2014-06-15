void main() {
    ubyte[256] data;
    foreach (immutable i; 0..256)
        data[i] = i;
    foreach (const i; 0..256)
        data[i] = i;
    foreach (immutable i, x; data)
        data[i] = i;
    foreach (const i, x; data)
        data[i] = i;
    foreach_reverse (immutable i; 0..256)
        data[i] = i;
    foreach_reverse (const i; 0..256)
        data[i] = i;
    foreach_reverse (immutable i, x; data)
        data[i] = i;
    foreach_reverse (const i, x; data)
        data[i] = i;
}

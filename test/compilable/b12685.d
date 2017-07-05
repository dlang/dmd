void foo() {
    ubyte[2 ^^ 8] data1;
    foreach (ubyte i, x; data1) {}
    ushort[2 ^^ 16] data2;
    foreach (ushort i, x; data2) {}
}

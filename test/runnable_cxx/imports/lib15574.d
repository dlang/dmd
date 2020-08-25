module imports.lib15574;

extern(C) nothrow {
    int square (int x);
}

bool testSquare() {
    return square(2) == 4 && square(5) == 25;
}

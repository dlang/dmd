// reduced from the bug report
struct Bar {
    void opIndexAssign( int value, size_t index ) {}
}
@property auto bar( ) {
    return Bar( );
}
void main( ) {
    bar[3] = 42;
}

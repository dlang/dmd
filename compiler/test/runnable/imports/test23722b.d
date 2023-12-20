struct A {
    import core.stdc.stdio;
    alias x = () {
        printf("x\n");
    };
    alias y = () {
        printf("y\n");
    };
}

// do_x should call A.x (and print "x")
void do_x() {
    A.x();
}

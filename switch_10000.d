void test(int x) {
    Lswitch: switch(x)
    {
        static foreach(i; 0 .. 10000)
            case i: break Lswitch;

        default: break;
    }
}

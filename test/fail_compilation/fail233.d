void bug1176(){
/*
Error: void does not have a default initializer
Error: integral constant must be scalar type, not void
Error: cannot implicitly convert expression (0) of type int to const(void[])
Error: cannot cast int to const(void[])
Error: integral constant must be scalar type, not const(void[])
*/
        void[1] v;
}

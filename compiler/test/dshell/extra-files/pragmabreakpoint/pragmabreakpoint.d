module pragmabreakpoint.pragmabreakpoint;

struct T(size_t x){
    static if(x == 0){
        enum done = true;
        //additional arguments are passed to pragma(msg), so they work the same way
        pragma(breakpoint, "done ", T);
    } else {
        pragma(breakpoint, "static else, before expanding the dependent template");
        T!(x - 1) nested;

    }
}


void main(){

    T!3 t3;
    static if(is(t3.done)){
        pragma(msg, "instantiated");
    }
    pragma(breakpoint, "main");
}

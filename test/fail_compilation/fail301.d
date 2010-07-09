struct bug3305(alias X = 0) {
    auto guard = bug3305b!(0).guard;
}

struct bug3305b(alias X = 0){
    bug3305!(X) goo; 
    auto guard = 0;
}

void test(){
    bug3305!(0) a;
}



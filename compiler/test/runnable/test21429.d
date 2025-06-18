mixin template OD(string s){

    string opDispatch(string name)() if(name == s){
        return name;
    }
}

struct T {
    mixin OD!"x";
    mixin OD!"y";
}

//struct U {
//    mixin OD!"z";
//}


void main(){

    T t;
    string s = t.x(); //error!
    assert(s == "x");
    assert(t.y == "y");

    //TODO opDispatch with assignment/parameters

    //t.opDispatch!"x";
    //t.opDispatch!"y";

    //U u;
    //u.z(); //OK
}

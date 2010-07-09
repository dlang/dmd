template Foo(alias b){
    int a() {
       return b;
    }
 }

 void test(){
    mixin Foo!(y) y;
 }


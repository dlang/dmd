template Tuple(T...){
    alias T Tuple;
}

void foo()(){
   undefined x;
   foreach( i ; Tuple!(2) ){
        static assert( true);
   }
}

void main(){
    foo!()();
}


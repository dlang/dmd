// this code causes a compiler GPF

template fn( T ) {
     void fn() {
     }
}

template fn( T ) {
     void fn( T val ) {
     }
}

void main() {
     fn!(int)( 1 );
}


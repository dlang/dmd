struct Tuple( TList... ){
        mixin .Tuple!((TList[1 .. $])) tail;
}
mixin Tuple!(int);

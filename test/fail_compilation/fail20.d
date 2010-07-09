struct FOO{}
void main(){
    FOO one;
    FOO two;
    if (one < two){} // This should tell me that there
                     // is no opCmp() defined instead 
                     // of crashing.
}


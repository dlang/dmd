void main() {
    asm { inc [; }
}

// 1144 mixin_34_A.  Segfault  D1 only
char[] testHelper(A ...)(){
 	    char[] result;
 	    foreach(t; a){
 	        result ~= "int " ~ t ~ ";\n";
 	    }
 	    return result;
 	} 	
void main(){
 	    mixin( testHelper!( "hello", "world" )() );
 	}

template T(){
 	    this(){}  // 14G ICE
 	    ~this() {}  // 14H ICE
} 	
void test(){
	    mixin T!();
}


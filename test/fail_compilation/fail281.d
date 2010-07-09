 template foo(size_t i){
 	    static if(i > 0){
 	        const size_t bar = foo!(i-1).bar;
 	    }else{
 	        const size_t bar = 1;
 	    }
 	}
 	
 	int main(){
 	    return foo!(size_t.max).bar;
	}

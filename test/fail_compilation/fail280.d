  template t(int i){
 	    const int x = t!(i+1).x;
 	}
 	
 	void main(){
 	    int i = t!(0).x;
 	}

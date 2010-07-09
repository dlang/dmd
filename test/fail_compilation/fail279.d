template Template(int i) {
 	    mixin Template!(i+1);
} 	
mixin Template!(0);

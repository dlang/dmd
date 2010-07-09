  //template_class_09.
	template Template(int i) {
 	    class Class : Template!(i+1).Class{
 	    }
 	}
 	
 	alias Template!(0).Class Class0;

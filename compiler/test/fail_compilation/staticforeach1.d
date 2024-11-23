/*
TEST_OUTPUT:
---
fail_compilation/staticforeach1.d(12): Error: must use labeled `break` within `static foreach`
			break;
   ^
---
*/
void main(){
	for(;;){
		static foreach(i;0..1){
			break;
		}
	}
}

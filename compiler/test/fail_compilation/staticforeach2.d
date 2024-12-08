/*
TEST_OUTPUT:
---
fail_compilation/staticforeach2.d(12): Error: must use labeled `continue` within `static foreach`
			continue;
   ^
---
*/
void main(){
	for(;;){
		static foreach(i;0..1){
			continue;
		}
	}
}

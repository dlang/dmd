/*
REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
---
*/

// naming scheme: return by Value/Ref, parameter Value/Ref, return parameter value/address, return? scope?
// https://issues.dlang.org/show_bug.cgi?id=21868

/*
TEST_OUTPUT:
---
fail_compilation/retscope_matrix.d(1000): Error: returning `&this.x` escapes a reference to parameter `this`
fail_compilation/retscope_matrix.d(1000):        perhaps annotate the function with `return`
fail_compilation/retscope_matrix.d(1004): Error: returning `&this.x` escapes a reference to parameter `this`
fail_compilation/retscope_matrix.d(1004):        note that `return` applies to the value of `this`, not its address
fail_compilation/retscope_matrix.d(1006): Error: returning `&this.x` escapes a reference to parameter `this`
fail_compilation/retscope_matrix.d(1007): Error: scope parameter `this` may not be returned
fail_compilation/retscope_matrix.d(1007):        perhaps annotate the function with `return`
fail_compilation/retscope_matrix.d(1008): Error: returning `this.x` escapes a reference to parameter `this`
fail_compilation/retscope_matrix.d(1008):        perhaps annotate the function with `return`
fail_compilation/retscope_matrix.d(1013): Error: scope parameter `this` may not be returned
fail_compilation/retscope_matrix.d(1013):        note that `return` applies to `ref`, not the value
fail_compilation/retscope_matrix.d(1014): Error: returning `this.x` escapes a reference to parameter `this`
fail_compilation/retscope_matrix.d(1014):        perhaps annotate the function with `return`
fail_compilation/retscope_matrix.d(1015): Error: scope parameter `this` may not be returned
---
*/

struct Node
{
    private int x;
    private Node* next;
#line 1000
/*1000*/     int* vt_adr_  ()              {return &this.x;     } // X
/*1001*/     int* vt_val_  ()              {return &this.next.x;} // V
/*1002*/     int* vt_adr_r () return       {return &this.x;     } // V
/*1003*/     int* vt_val_r () return       {return &this.next.x;} // V
/*1004*/     int* vt_adr_rs() return scope {return &this.x;     } // X ACCEPTS_INVALID
/*1005*/     int* vt_val_rs() return scope {return &this.next.x;} // V
/*1006*/     int* vt_adr_s ()        scope {return &this.x;     } // X
/*1007*/     int* vt_val_s ()        scope {return &this.next.x;} // X
/*1008*/ ref int  rt_adr_  ()              {return  this.x;     } // X
/*1009*/ ref int  rt_val_  ()              {return  this.next.x;} // V
/*1010*/ ref int  rt_adr_r () return       {return  this.x;     } // V
/*1011*/ ref int  rt_val_r () return       {return  this.next.x;} // V
/*1012*/ ref int  rt_adr_rs() return scope {return  this.x;     } // V
/*1013*/ ref int  rt_val_rs() return scope {return  this.next.x;} // X ACCEPTS_INVALID
/*1014*/ ref int  rt_adr_s ()        scope {return  this.x;     } // X
/*1015*/ ref int  rt_val_s ()        scope {return  this.next.x;} // X
}

/*
TEST_OUTPUT:
---
fail_compilation/retscope_matrix.d(1100): Error: returning `&node.x` escapes a reference to parameter `node`
fail_compilation/retscope_matrix.d(1100):        perhaps annotate the parameter with `return`
fail_compilation/retscope_matrix.d(1104): Error: returning `&node.x` escapes a reference to parameter `node`
fail_compilation/retscope_matrix.d(1104):        note that `return` applies to the value of `node`, not its address
fail_compilation/retscope_matrix.d(1106): Error: returning `&node.x` escapes a reference to parameter `node`
fail_compilation/retscope_matrix.d(1107): Error: scope parameter `node` may not be returned
fail_compilation/retscope_matrix.d(1107):        perhaps annotate the parameter with `return`
fail_compilation/retscope_matrix.d(1108): Error: returning `node.x` escapes a reference to parameter `node`
fail_compilation/retscope_matrix.d(1108):        perhaps annotate the parameter with `return`
fail_compilation/retscope_matrix.d(1113): Error: scope parameter `node` may not be returned
fail_compilation/retscope_matrix.d(1113):        note that `return` applies to `ref`, not the value
fail_compilation/retscope_matrix.d(1114): Error: returning `node.x` escapes a reference to parameter `node`
fail_compilation/retscope_matrix.d(1114):        perhaps annotate the parameter with `return`
fail_compilation/retscope_matrix.d(1115): Error: scope parameter `node` may not be returned
---
*/
#line 1100
/*1100*/     int* vr_adr_  (ref              Node node) {return &node.x;     } // X
/*1101*/     int* vr_val_  (ref              Node node) {return &node.next.x;} // V
/*1102*/     int* vr_adr_r (ref return       Node node) {return &node.x;     } // V
/*1103*/     int* vr_val_r (ref return       Node node) {return &node.next.x;} // V
/*1104*/     int* vr_adr_rs(ref return scope Node node) {return &node.x;     } // X ACCEPTS_INVALID
/*1105*/     int* vr_val_rs(ref return scope Node node) {return &node.next.x;} // V
/*1106*/     int* vr_adr_s (ref        scope Node node) {return &node.x;     } // X
/*1107*/     int* vr_val_s (ref        scope Node node) {return &node.next.x;} // X
/*1108*/ ref int  rr_adr_  (ref              Node node) {return  node.x;     } // X
/*1109*/ ref int  rr_val_  (ref              Node node) {return  node.next.x;} // V
/*1110*/ ref int  rr_adr_r (ref return       Node node) {return  node.x;     } // V
/*1111*/ ref int  rr_val_r (ref return       Node node) {return  node.next.x;} // V
/*1112*/ ref int  rr_adr_rs(ref return scope Node node) {return  node.x;     } // V
/*1113*/ ref int  rr_val_rs(ref return scope Node node) {return  node.next.x;} // X ACCEPTS_INVALID
/*1114*/ ref int  rr_adr_s (ref        scope Node node) {return  node.x;     } // X
/*1115*/ ref int  rr_val_s (ref        scope Node node) {return  node.next.x;} // X

/*
TEST_OUTPUT:
---
fail_compilation/retscope_matrix.d(1200): Error: returning `&node.x` escapes a reference to parameter `node`
fail_compilation/retscope_matrix.d(1202): Error: returning `&node.x` escapes a reference to parameter `node`
fail_compilation/retscope_matrix.d(1202):        note that `return` applies to the value of `node`, not its address
fail_compilation/retscope_matrix.d(1204): Error: returning `&node.x` escapes a reference to parameter `node`
fail_compilation/retscope_matrix.d(1204):        note that `return` applies to the value of `node`, not its address
fail_compilation/retscope_matrix.d(1206): Error: returning `&node.x` escapes a reference to parameter `node`
fail_compilation/retscope_matrix.d(1207): Error: scope parameter `node` may not be returned
fail_compilation/retscope_matrix.d(1207):        perhaps annotate the parameter with `return`
fail_compilation/retscope_matrix.d(1208): Error: returning `node.x` escapes a reference to parameter `node`
fail_compilation/retscope_matrix.d(1210): Error: returning `node.x` escapes a reference to parameter `node`
fail_compilation/retscope_matrix.d(1210):        note that `return` applies to the value of `node`, not its address
fail_compilation/retscope_matrix.d(1212): Error: returning `node.x` escapes a reference to parameter `node`
fail_compilation/retscope_matrix.d(1212):        note that `return` applies to the value of `node`, not its address
fail_compilation/retscope_matrix.d(1214): Error: returning `node.x` escapes a reference to parameter `node`
fail_compilation/retscope_matrix.d(1215): Error: scope parameter `node` may not be returned
fail_compilation/retscope_matrix.d(1215):        perhaps annotate the parameter with `return`
---
*/
#line 1200
/*1200*/     int* vv_adr_  (                 Node node) {return &node.x;     } // X WRONG_ERROR
/*1201*/     int* vv_val_  (                 Node node) {return &node.next.x;} // V
/*1202*/     int* vv_adr_r (    return       Node node) {return &node.x;     } // X
/*1203*/     int* vv_val_r (    return       Node node) {return &node.next.x;} // V
/*1204*/     int* vv_adr_rs(    return scope Node node) {return &node.x;     } // X
/*1205*/     int* vv_val_rs(    return scope Node node) {return &node.next.x;} // V
/*1206*/     int* vv_adr_s (           scope Node node) {return &node.x;     } // X
/*1207*/     int* vv_val_s (           scope Node node) {return &node.next.x;} // X
/*1208*/ ref int  rv_adr_  (                 Node node) {return  node.x;     } // X
/*1209*/ ref int  rv_val_  (                 Node node) {return  node.next.x;} // V
/*1210*/ ref int  rv_adr_r (    return       Node node) {return  node.x;     } // X
/*1211*/ ref int  rv_val_r (    return       Node node) {return  node.next.x;} // V
/*1212*/ ref int  rv_adr_rs(    return scope Node node) {return  node.x;     } // X
/*1213*/ ref int  rv_val_rs(    return scope Node node) {return  node.next.x;} // V
/*1214*/ ref int  rv_adr_s (           scope Node node) {return  node.x;     } // X
/*1215*/ ref int  rv_val_s (           scope Node node) {return  node.next.x;} // X

/*
TEST_OUTPUT:
---
fail_compilation/retscope_matrix.d(1304): Error: returning `node.x` escapes a reference to parameter `node`
fail_compilation/retscope_matrix.d(1306): Error: returning `&node.x` escapes a reference to parameter `node`
---
*/
void infer() {
#line 1300
/*1300*/ ref int  rr_adr_i(ref Node node) @safe {return  node.x;     } // V
/*1301*/ ref int  rr_val_i(ref Node node) @safe {return  node.next.x;} // V
/*1302*/     int* vr_adr_i(ref Node node) @safe {return &node.x;     } // V
/*1303*/     int* vr_val_i(ref Node node) @safe {return &node.next.x;} // V
/*1304*/ ref int  rv_adr_i(    Node node) @safe {return  node.x;     } // X - WRONG_ERROR
/*1305*/ ref int  rv_val_i(    Node node) @safe {return  node.next.x;} // V
/*1306*/     int* vv_adr_i(    Node node) @safe {return &node.x;     } // X - WRONG_ERROR
/*1307*/     int* vv_val_i(    Node node) @safe {return &node.next.x;} // V
}

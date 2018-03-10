version (D_SIMD)
{
import core.simd;

void check(void16 a) {
    foreach (x; (cast(ushort8)a).array) {
	assert(x == 1);
    }
}

void make(ushort x) {
    ushort8 v = ushort8(x);
    check(v);
}

void main(){	
    make(1);
}
}

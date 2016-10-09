struct F {
    float f;
}
struct D {
    double d;
};

void main() {
    F fx = F.init;
    D dx = D.init;
    assert(fx is fx.init);
    assert(fx.f is float.init);
    assert(dx is dx.init);
    assert(dx.d is double.init);

    F fy;
    D dy;
    assert(fy is fy.init);
    assert(fy.f is float.init);
    assert(dy is dy.init);
    assert(dy.d is double.init);
};

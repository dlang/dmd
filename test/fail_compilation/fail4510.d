// https://issues.dlang.org/show_bug.cgi?id=4510

void main()
{
    float[] arr = [1.0, 2.5, 4.0];
    foreach (ref double elem; arr) {
        //elem /= 2;
    }
}

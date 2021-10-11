import std.stdio;
import std.complex;

void main()
{
    alias T = Complex!float;

    T iV = complex(1.0f, 1.0f);
    T[] arr = [iV, 2 * iV, 3 * iV, 4 * iV, 5 * iV, 6 * iV];
    Complex!float[] result = new T[arr.length];
    
    result[] = arr[] + iV;
    result[] = iV + arr[];
    
    result[] = arr[] - iV;
    result[] = iV - arr[];
    
    result[] = arr[] * iV;
    result[] = iV * arr[];
    
    result[] = arr[] / iV;
    result[] = iV / arr[];
    
    result[] = arr[] ^^ iV;
    result[] = iV ^^ arr[];
}
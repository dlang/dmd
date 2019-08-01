import core.stdcpp.vector;

unittest
{
    // test vector a bit
    vector!int vec = vector!int(5);
    assert(vec[] == [0, 0, 0, 0, 0]);
    assert(vec.size == 5);
    assert(vec.length == 5);
    assert(vec.empty == false);

    vec[] = [1, 2, 3, 4, 5];
    assert(sumOfElements_val(vec) == 45);
    assert(sumOfElements_ref(vec) == 15);

    vec.push_back(6);
    vec.push_back(7);
    vec ~= 8;
    vec ~= [9, 10];
    assert(vec.size == 10 && vec[5 .. $] == [6, 7, 8, 9, 10]);

    vec.pop_back();
    assert(vec.size == 9 && vec.back == 9);

    vec.resize(10);
    assert(vec[9] == 0);
    vec.resize(12, 10);
    assert(vec[10 .. 12] == [10, 10]);
    vec.resize(5);
    assert(vec.length == 5);
    vec.clear();
    assert(vec.empty);

    // test default construction
    vector!int vec2 = vector!int(Default);
    assert(vec2.size == 0);
    assert(vec2.length == 0);
    assert(vec2.empty == true);
    assert(vec2[] == []);

    vec = vector!int([1, 2, 3, 4]);
    vec2 = vec;
    assert(vec2[] == [1, 2, 3, 4]);
    vec = [1, 2, 3];
    assert(vec[] == [1, 2, 3]);
    vec[] = 0;
    assert(vec[] == [0, 0, 0]);

    vec2.emplace(1, 10);
    vec2.emplace(3, 0);
    vec2[3] = 20;
    vec2[4 .. 6] = [8, 9];
    vec2[1] *= 10;
    vec2[4 .. 6] *= 10;
    vec2[3 .. 5] *= [10, 100];
    vec2[] *= 2;
    vec2[] *= [10, 1, 10, 1, 1, 2];
    assert(vec2[] == [20, 200, 40, 400, 16000, 360]);

    // test local instantiations...
    // there's no vector<float> instantiation in C++
    vector!CustomInit vec3 = vector!CustomInit(1);
    vec3.push_back(CustomInit(1));
    assert(vec3[0].x == 10 && vec3[1].x == 1);

    // test out a non-pod type...
    {
        auto vec4 = vector!NotPOD(2, NotPOD(2));
        vec4.push_back(NotPOD(3));
        assert(nonPod_val(vec4) == 1);
    }
    assert(vectorTest_numAllocated == 0);
}

struct CustomInit
{
    int x = 10;
}


extern(C++):

__gshared int vectorTest_numAllocated = 0;

struct NotPOD
{
    this() @disable;
    this(int a)
    {
        x[] = [a+1, a+2, a+3, a+4, a+5];
        wasInit = true;
        ++vectorTest_numAllocated;
    }
    this(this)
    {
        if (wasInit)
            ++vectorTest_numAllocated;
    }
    ~this()
    {
        if (wasInit)
            --vectorTest_numAllocated;
    }

    int[5] x = [1, 2, 3, 4, 5];
    bool wasInit;
}

// test the ABI for calls to C++
int sumOfElements_val(vector!int vec);
int sumOfElements_ref(ref const(vector!int) vec);
int nonPod_val(vector!NotPOD vec);


// test the ABI for calls from C++
int fromC_val(vector!int vec)
{
    assert(vec[] == [1, 2, 3, 4, 5]);
    assert(vec.front == 1);
    assert(vec.back == 5);

    int r;
    foreach (e; vec[])
        r += e;

    assert(r == 15);
    return r;
}

int fromC_ref(ref const(vector!int) vec)
{
    int r;
    foreach (e; vec[])
        r += e;
    return r;
}

int fromC_nonPod_val(vector!NotPOD vec)
{
    return vec.size() == 3 && vec[1].x[4] == 7;
}

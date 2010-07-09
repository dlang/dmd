// 142

template A(alias T) {
        void A(T) { T=2; }
}

void main()
{
        int i;
        A(i);
        assert(i==2);
}


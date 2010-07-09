template t(int t)
{
}

int main()
{
    return t!(main() + 8);
}

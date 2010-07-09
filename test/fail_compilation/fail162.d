template testHelper( A ... )
{
        char []testHelper()
        {
                char []result;
                foreach(  t; a )
                {
                        result ~= "int " ~ t ~ ";\r\n";
                }
                return result;
        }
}

template test( A ... )
{
        const char []test = testHelper( A );
}

int main( char [][]args )
{
        mixin( test!( "hello", "world" ) );
        return 0;
}



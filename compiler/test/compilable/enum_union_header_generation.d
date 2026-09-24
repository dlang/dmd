// REQUIRED_ARGS: -o- -Hf${RESULTS_DIR}/compilable/enum_union_header_generation.di
module enum_union_header_generation;

enum union Shape
{
    case Circle(double radius);
    case Point();
}

enum union Option(T)
{
    case Some(T);
    case None();
}

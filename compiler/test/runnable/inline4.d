// REQUIRED_ARGS: -inline

import imports.inline4a;

size_t i;

void main()
{
    foreach (d; Data("string"))
    {
        i = d.length();
    }
}

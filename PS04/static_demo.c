#include <stdio.h>

static void example_func(void)
{
    static int static_v = 5;
    int auto_v = 3;

    static_v++;
    auto_v++;
    printf("static variable = %d, auto variable = %d\n", static_v, auto_v);
}

int main(void)
{
    example_func();
    example_func();
    return 0;
}

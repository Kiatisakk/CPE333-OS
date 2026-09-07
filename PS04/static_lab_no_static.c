#include <stdio.h>

int main(void)
{
    auto int x = 3;

    while (x > 0)
    {
        int y = 5;
        y++;

        printf("The value of y is %d\n", y);
        printf("The address of y is %p\n\n", (void *)&y);

        x--;
    }

    return 0;
}

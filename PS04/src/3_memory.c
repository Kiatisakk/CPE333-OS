#include <stdio.h>
#include <stdlib.h>

int main(void)
{
    int *a;
    float *b;
    int c[10];

    printf("\nAddress of Pointer\n");
    printf(">>%p\n", (void *)&a);
    printf(">>%p\n", (void *)&b);

    printf("\nEffective Address\n");
    printf(">>%p\n", (void *)a);
    printf(">>%p\n", (void *)b);

    a = malloc(10 * sizeof(int));
    printf("\nAfter malloc Pointer a\n");
    printf(">>%p\n", (void *)a);
    printf(">>%p\n", (void *)&a[0]);
    printf(">>%p\n", (void *)&a[9]);

    printf("\nArray c\n");
    printf(">>%p\n", (void *)c);
    printf(">>%p\n", (void *)&c[0]);
    printf(">>%p\n", (void *)&c[9]);

    a = realloc(a, 1000 * sizeof(int));
    printf("\nAfter realloc Pointer a\n");
    printf(">>%p\n", (void *)a);
    printf(">>%p\n", (void *)&a[0]);
    printf(">>%p\n", (void *)&a[9]);
    printf(">>%p\n", (void *)&a[999]);

    free(a);
    return 0;
}

#include <stdio.h>

int x = 20;

static void display(void)
{
    extern int x;
    printf("Display value of x: %d\n", x);
    printf("Address of x (in display function): %p\n\n", (void *)&x);
}

int main(void)
{
    int x;
    printf("Print value of x: %d\n", x);
    printf("Address of x (in main function): %p\n\n", (void *)&x);
    display();
    return 0;
}

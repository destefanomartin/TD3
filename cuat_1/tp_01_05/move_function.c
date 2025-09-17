#include <stdint.h>

void move(uint32_t* ,uint32_t* , uint32_t );

__attribute__((section("boot"))) void move(uint32_t *origen, uint32_t *destino, uint32_t count)
{
    for(uint32_t i = 0; i<count; i++)
    {
        *(destino+i)= *(origen+i);
    }
    return;
}



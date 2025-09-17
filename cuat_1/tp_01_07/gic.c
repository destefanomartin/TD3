#include "gic.h"

__attribute__((section(".text"))) void __gic_init()
    {
        _gicc_t* const GICC0 = (_gicc_t*)GICC0_ADDR;
        _gicd_t* const GICD0 = (_gicd_t*)GICD0_ADDR;


        GICC0->PMR  = 0x000000F0;
        GICD0->ISENABLER[1] |= 0x00000010;
        GICC0->CTLR         = 0x00000001;
        GICD0->CTLR         = 0x00000001;


    }

//el ISENABLER[1] tiene del bit 32 al 63

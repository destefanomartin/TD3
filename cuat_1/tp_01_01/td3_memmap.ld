/* 
    Definiciones necesarias: formato de salida, arquitectura y punto de entrada
*/
OUTPUT_FORMAT("elf32-littlearm")
OUTPUT_ARCH(arm)
ENTRY(_start)


/* 
    Definiciones de simbolos necesarios
*/
_PUBLIC_RAM_INIT = 0x70010000;
_PUBLIC_STACK_INIT = 0x70020000;
_EJECUTABLE = 0x70030000;

/* 
    Definición del mapa de memoria
*/
MEMORY
{
    public_ram	: org = _PUBLIC_RAM_INIT, len = 0x1000
    public_stack : org = _PUBLIC_STACK_INIT, len = 0x2000 /* 8kb pila */
    ejecutable_ram : org =_EJECUTABLE, len = 0x10000
}

/* 
    Definición de las secciones

    .text -> SALIDA 
    *-> todos los .o (.text*) -> ENTRADA

    Inicio y final de VMA 
            __text_start__ = .; 
        *(.text*)
        __text_end__ = .;  

    __text_LMA=LOADADDR(.text); Consigo direccion de LMA 

        .text : { 
        __text_start__ = .; 
        *(.text*)
        __text_end__ = .;  
        } > ejecutable_ram
     lo mando donde quiero en la VMA
 

     } > public_ram at > public_ram
DEFINO EN EL ROM LA LMA Porque es el de inicio 

*/
SECTIONS
{
    
    boot : {
        *(boot*)
    } > public_ram AT > public_ram
    
    
    .text : { 
        __text_start = .; 
        *(.text*)
        __text_end = .;  
        } > ejecutable_ram AT > public_ram
    
    __text_LMA = LOADADDR(.text); 

    .data : { *(.data*) } > public_ram
    .bss : {
        . = ALIGN(4);
        __bss_start__ = .;
        *(.bss*)
        __bss_end__ = .;
        } > public_ram
}


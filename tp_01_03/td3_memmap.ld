/* 
    Definiciones necesarias: formato de salida, arquitectura y punto de entrada
*/
OUTPUT_FORMAT("elf32-littlearm")
OUTPUT_ARCH(arm)
ENTRY(_start)


/* 
    Definiciones de simbolos necesarios
*/

/* 
+------------------------+------------------+------------------+
|       Contenido        |       LMA        |       VMA        |
+------------------------+------------------+------------------+
| Vector de reset        | 0x00000000       | 0x00000000       |
| Inicializacion         | 0x70100000       | 0x70010000       |
| Aplicacion (kernel)    | A continuacion   | 0x70060000       |
| Datos inicializados    | A continuacion   | 0x70050000       |
| Pila                   | -                | 0x70030000       |
| Datos no inicializados | -                | 0x70040000       |
+------------------------+------------------+------------------+
*/

/* VMA */
_VECTOR_RESET_INIT = 0x00000000;
_BOOTLOADER_INIT = 0x70010000;
_APPLICATION_INIT = 0x70060000;
_DATA_INIT = 0x70050000;
_STACK_INIT = 0x70030000; 
_BSS_INIT = 0x70040000;



/* 
    Definición del mapa de memoria
*/
MEMORY
{
    reset_mem_rom	: org = _VECTOR_RESET_INIT, len = 0x1000
    boot_mem_rom : org = _BOOTLOADER_INIT, len = 0x1000
    application_mem_ram : org = _APPLICATION_INIT, len = 0x1000
    data_mem_ram : org = _DATA_INIT, len = 0x1000
    stack_mem_ram : org = _STACK_INIT, len = 0x1000
    bss_mem_ram : org = _BSS_INIT, len = 0x1000
}


/* STACK Y BSS NO ESTAN INICIALIZADOS POR LO TANTO NO SE MANDAN AL LMA */
SECTIONS
{

    boot : {
        *(boot*)
    } > boot_mem_rom AT > boot_mem_rom
    
    .text : { 
        __text_start = .; 
        *(.text*)
        __text_end = .;  
    } > application_mem_ram AT > boot_mem_rom
    
    __text_LMA = LOADADDR(.text); 

    .data : {
        . = ALIGN(4);
        __data_start = .;
         *(.data*)
        __data_end = .;
        } > data_mem_ram AT > boot_mem_rom

    __data_LMA = LOADADDR(.data);
    
    .stack : {
        __stack_start = .;
        *(.stack*)
        __stack_bottom = .; 
    } > stack_mem_ram 

    .bss : {
        . = ALIGN(4);
        __bss_start__ = .;
        *(.bss*)
        __bss_end__ = .;
        } > bss_mem_ram 
}

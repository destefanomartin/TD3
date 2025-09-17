/* 
    Definiciones necesarias: formato de salida, arquitectura y punto de entrada
*/
OUTPUT_FORMAT("elf32-littlearm")
OUTPUT_ARCH(arm)
ENTRY(_start)


/* 
    Definiciones de simbolos necesarios
*/


/* VMA */
_VECTOR_RESET_INIT = 0x70000000; 
_BOOTLOADER_INIT = 0x70010000; 
_KERNEL_INIT = 0x70030000; 
_BSS_KERNEL_INIT = 0x70022000;
_STACK_KERNEL_INIT = 0x70020000;
_PUBLIC_STACK_INIT = 0x70021000; 
_DATA_KERNEL_INIT = 0x70031000;




/* 
    Definición del mapa de memoria
*/
MEMORY
{
    reset_mem_rom	: org = _VECTOR_RESET_INIT, len = 0x1000
    boot_mem_rom : org = _BOOTLOADER_INIT, len = 0x1000
    application_mem_ram : org = _KERNEL_INIT, len = 0x1000
    data_mem_ram : org = _DATA_KERNEL_INIT, len = 0x1000
    stack_mem_ram : org = _STACK_KERNEL_INIT, len = 0x1000
    public_stack_mem_ram : org = _PUBLIC_STACK_INIT, len = 0x1000
    bss_mem_ram : org = _BSS_KERNEL_INIT, len = 0x8000
}


/* STACK Y BSS NO ESTAN INICIALIZADOS POR LO TANTO NO SE MANDAN AL LMA */
SECTIONS
{

    boot : {
        *(boot*)
    } > boot_mem_rom AT > boot_mem_rom

    reset_vector : {
        __reset_start = .; 
        *(reset_vector) 
        __reset_end = .; 
    } > reset_mem_rom AT > boot_mem_rom
    
    __reset_LMA = LOADADDR(reset_vector);
    
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
     __stack_start__ = .;
        . += 0x80;
        . = ALIGN(4);
        __stack_irq = .;

        . += 0x80;
        . = ALIGN(4);
        __stack_fiq = .;

        . += 0x80;
        . = ALIGN(4);
        __stack_svc = .;

        . += 0x80;
        . = ALIGN(4);
        __stack_abt = .;

        . += 0x80;
        . = ALIGN(4);
        __stack_undef = .;
 

        __stack_bottom = .;
    } > stack_mem_ram 

    .bss : {
        . = ALIGN(4);
        __bss_start__ = .;
        *(.bss*)
        __bss_end__ = .;
        } > bss_mem_ram 
}

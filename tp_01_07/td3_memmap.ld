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
_VECTOR_RESET_INIT = 0x7000000
_BOOTLOADER_INIT = 0x70010000
_KERNEL_INIT = 0x70030000
_DATA_KERNEL_INIT = 0x81000000
_BSS_KERNEL_INIT = 0x82000000
_PUBLIC_STACK_INIT = 0x70020000


/* Tarea 1 

_TASK_INIT = 0x70040000
_DATA_TASK_INIT = 0x700A0000
_BSS_TASK_INIT = 0x70100000
_TASK_STACK_INIT = 0x7006000

TASK_STACK_SIZE = 0x1000;


/* 
    Definición del mapa de memoria
*/
MEMORY
{
    reset_mem_rom: org = _VECTOR_RESET_INIT, len = 0x1000
    boot_mem_rom : org = _BOOTLOADER_INIT, len = 0x1000
    application_mem_ram : org = _KERNEL_INIT, len = 0x1000
    data_mem_ram : org = _DATA_KERNEL_INIT, len = 0x1000
    public_stack_mem_ram : org = _PUBLIC_STACK_INIT, len = 0x1000
    bss_mem_ram : org = _BSS_KERNEL_INIT, len = 0x1000
    task_mem_rom : org = _TASK_INIT, len = 0x1000
    task_data_mem_rom: org = _DATA_TASK_INIT, len = 8192K 
    task_bss_mem_rom: org = _BSS_TASK_INIT, len = 0x2000 
    task_stack_mem_ram: org = _TASK_STACK_INIT, len = 0x1000
}


/* STACK Y BSS NO ESTAN INICIALIZADOS POR LO TANTO NO SE MANDAN AL LMA */
SECTIONS
{
    reset_vector : {
        __reset_start__ = .; 
        *(reset_vector) 
        __reset_end__ = .; 
    } > reset_mem_rom AT > boot_mem_rom
    
    __reset_LMA = LOADADDR(reset_vector);

    . = _BOOTLOADER_INIT; 
    boot : {
        *(boot*)
    } > boot_mem_rom AT > boot_mem_rom
    
    . = 
    .text : { 
        __text_start__ = .; 
        *(.text*)
        __text_end__ = .;  
    } > application_mem_ram AT > boot_mem_rom
    
    __text_LMA = LOADADDR(.text); 

    .data : {
        . = ALIGN(4);
        __data_start__ = .;
         *(.data*)
        __data_end__ = .;
        } > data_mem_ram AT > boot_mem_rom

    __data_LMA = LOADADDR(.data);

    .bss : {
        . = ALIGN(4);
        __bss_start__ = .;
        *(.bss*)
        __bss_end__ = .;
        } > bss_mem_ram 
    
    . = _PUBLIC_STACK_INIT; 
    .stack : {
        . = ALIGN(8);
        __stack_start = .;

        __stack_irq = .;
        . = . + 0x80;

        __stack_fiq = .;
        . = . + 0x80;

        __stack_abt = .;
        . = . + 0x80;

        __stack_undef = .;
        . = . + 0x80;      

        __stack_svc = .;
        . = . + 0x80;      

        __stack_bottom = .;
    } > stack_mem_ram 

    .= _TASK_INIT; 
    .task_text : { 
        __text_task_start__ = .;
        *(.t1_text*) 
        __text_task_end__ = .;
    }  > task_mem_rom AT > boot_mem_rom

    .task_data : { 
        __data_task_start__ = .;
        *(.task_data*) 
        __data_task_end__ = .;
    } > task_data_mem_rom AT > boot_mem_rom

    .task_bss (NOLOAD): {
        __bss_task_start__ = .;
        *(.task_bss*)
        __bss_task_end__ = .;
    } > task_bss_mem_rom

    . = _TASK_STACK_INIT; 
    .task_stack : ALIGN(4)
    {
        /* pila de tarea 1 */
        __stack_task1_start = .;            
        . = . + TASK_STACK_SIZE;
        __stack_task1_end = .;             

        /* pila de tarea 2 */
        __stack_task2_start = .;
        . = . + TASK_STACK_SIZE;
        __stack_task2_end = .;

        
    }  > task_stack_mem_ram
}

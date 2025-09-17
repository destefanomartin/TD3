.global _start
.extern __text_start
.extern __text_LMA
.extern __text_end
.extern _DATA_INIT
/* 
R1 -> Puntero al origen 
R0 -> Puntero al destino 
R2 -> Cant bytes
*/


/*Va en inicializacion porque es lo que mueve el codigo para su ejecucion */
.section boot,"ax"@progbits  
_start:
    LDR SP, =_DATA_INIT
    LDR R0, =__text_start     // destino
    LDR R1, =__text_LMA       // origen
    LDR R2, =__text_end
    SUB R2, R2, R0            // tamaño de la copia

byte_copy:
    LDRB R3, [R1], #1
    STRB R3, [R0], #1
    SUBS R2, R2, #1
    BNE byte_copy// Verifica flag 

    LDR R4, =code
    BX R4 


.section .text // Donde va la aplicacion 
code:
    b .

.section .data 
    value: .word 0x000000010

.section .bss
    value_b: .word


.section stack,"ax"@nobits

.end


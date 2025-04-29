.global _start
.extern __text_start
.extern __text_LMA
.extern __text_end
.extern _PUBLIC_STACK_INIT
/* 
R1 -> Puntero al origen 
R0 -> Puntero al destino 
R2 -> Cant bytes
*/



.section boot,"ax"@progbits 
_start:
    LDR SP, =_PUBLIC_STACK_INIT
    LDR R5, =0x70020000
    LDR R6, =0xAA55AA55
    STR R6, [R0]
    LDR R7, [R0]
    
    
    
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

.section .text
code:
    b .

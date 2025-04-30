.global _start
// TEXT
.extern __text_start
.extern __text_LMA
.extern __text_end
// DATA
.extern __data_start
.extern __data_LMA
.extern __data_end

.extern move

/* 
R1 -> Puntero al origen 
R0 -> Puntero al destino 
R2 -> Cant bytes
*/


/*Va en inicializacion porque es lo que mueve el codigo para su ejecucion */
.section boot,"ax"@progbits  
_start:
    LDR SP, =_DATA_INIT         // Inicializo la pila 
data_copy: 
    LDR R1, =__data_start     // destino
    LDR R0, =__data_LMA       // origen
    LDR R2, =__data_end
    SUB R2, R2, R1            // tamaño de la copia
    LDR R10, =move
    BLX R10
text_copy:
    LDR R1, =__text_start     // destino
    LDR R0, =__text_LMA       // origen
    LDR R2, =__text_end
    SUB R2, R2, R1            // tamaño de la copia
    LDR R10, =move
    BLX R10
    LDR R4, =code
    BLX R4
    
 

.section .text // Donde va la aplicacion 
code:
    b .

.section .data 
    value_a: .word 0x000000010 // La primer direccion deberia tener ete valor

.section .bss
    value_b: .word

.section .stack, "aw", %nobits
    .space 1024   // 1 KB de stack

.end


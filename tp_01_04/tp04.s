
.global undef_handler
.global svc_handler
// TEXT
.extern __text_start
.extern __text_LMA
.extern __text_end
// DATA
.extern __data_start
.extern __data_LMA
.extern __data_end
.extern move

.extern __stack_undef
.extern __stack_svc
.extern __stack_app

/* 
R1 -> Puntero al origen 
R0 -> Puntero al destino 
R2 -> Cant bytes
*/

.section .vector, "a"
.global _start
_start:
    B reset_handler         // 0x00
    B undef_handler         // 0x04
    B svc_handler           // 0x08
    /* 
    B prefetch_abort_handler // 0x0C
    B data_abort_handler    // 0x10
    B reserved_handler      // 0x14
    B irq_handler          // 0x18
    B fiq_handler          // 0x1C
    */


/*Va en inicializacion porque es lo que mueve el codigo para su ejecucion */
.section boot,"ax"@progbits  
reset_handler:

    // Configurar pila para modo UNDEF
    CPS #0x1B            // Cambiar a modo UNDEF
    LDR sp, =__stack_undef

    // Configurar pila para modo SVC
    CPS #0x13            // Cambiar a modo SVC
    LDR sp, =__stack_svc

    // Luego pasar a modo SYS o modo de aplicación
    CPS #0x1F            // Cambiar a modo SYS (modo usuario con privilegios)
    LDR sp, =__stack_app // (si usás una pila para el main/app)

    .word 0x00000000       // Esto dispara la excepción UNDEF

    B .                    // Por si no se lanza (sólo seguridad)
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

undef_handler:
    PUSH {R0-R12, LR}
    b .
    SUB LR, LR, #4              // Volver a la instrucción que causó el fallo
    LDR R1, =0xE0000000         // Dirección donde ocurrió el fallo (simulada)
    LDR R2, =0x00000000         // Código de operación del andeq r0, r0, r0
    STR R2, [R1]                // Sobrescribe la instrucción fallida
    POP {R0-R12, LR} // Retorno de la excepcion
    MOVS PC, LR

@ svc_handler:
@     SUB lr, lr, #4             // Volver a la instrucción SVC
@     LDR r1, [lr]               // Cargar instrucción SVC
@     AND r1, r1, #0xFF          // Extraer el campo inmediato (número de servicio)

@     CMP r1, #0
@     BEQ do_add
@     CMP r1, #1
@     BEQ do_sub

@     B end_svc

@ do_add:
@     ADD r0, r0, r1
@     B end_svc

@ do_sub:
@     SUB r0, r0, r1
@     B end_svc

@ end_svc:
@     MOVS pc, lr                // Regreso del handler


.section .data 
    value_a: .word 0x000000010

.section .bss
    value_b: .word

.section .stack, "aw", %nobits
    .space 1024   // 1 KB de stack

.end


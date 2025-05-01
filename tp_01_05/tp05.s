.global _start
.global reset_handler
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
// RESET 
.extern __reset_start
.extern __reset_end
.extern __reset_LMA
// STACK
.extern __stack_undef
.extern __stack_svc
.extern __stack_app

// TIMER0
.equ TIMER0_BASE,      0x10011000
.equ TIMER0_LOAD,      TIMER0_BASE + 0x00
.equ TIMER0_CTRL,      TIMER0_BASE + 0x08
.equ TIMER0_INTCLR,    TIMER0_BASE + 0x0C
.equ TIMER0_MIS,       TIMER0_BASE + 0x14
.equ TIMER0_IRQ_ID,    36



.section reset_vector, "ax"@progbits 
    LDR PC, jump_reset         // 0x00
    LDR PC, jump_undef_handler      // 0x04
    LDR PC, jump_svc_handler        // 0x08
    LDR PC, jump_prefetch_abort_handler // 0x0C
    LDR PC, jump_data_abort_handler // 0x10
    LDR PC, jump_reserved_handler   // 0x14
    LDR PC, jump_irq_handler       // 0x18
    LDR PC, jump_fiq_handler       // 0x1C
    
jump_reset:
    .word reset_handler
jump_undef_handler:
    .word undef_handler
jump_svc_handler:
    .word svc_handler
jump_prefetch_abort_handler:
    .word prefetch_abort_handler
jump_data_abort_handler:
    .word data_abort_handler
jump_reserved_handler:
    .word reserved_handler
jump_irq_handler:
    .word irq_handler
jump_fiq_handler:
    .word fiq_handler
/*Va en inicializacion porque es lo que mueve el codigo para su ejecucion */
.section boot,"ax"@progbits  
_start:

    // Configurar pila para modo UNDEF
    CPS #0x1B            // Cambiar a modo UNDEF
    LDR SP, =__stack_undef

    // Configurar pila para modo SVC
    CPS #0x13            // Cambiar a modo SVC
    LDR SP, =__stack_svc

    // Luego pasar a modo SYS o modo de aplicación
    CPS #0x1F            // Cambiar a modo SYS (modo usuario con privilegios)
    LDR SP, =__stack_app // (si usás una pila para el main/app)

reset_copy: 
    LDR R1, =__reset_start   // destino
    LDR R0, =__reset_LMA     // origen
    LDR R2, =__reset_end
    SUB R2, R2, R1           // tamaño de la copia
    LDR R10, =move
    BLX R10

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
    .word 0xE7FFFFFF
    MOV R0, #0x08

    SWI 0

    MOV R0, #0x04

    SWI 1

    MOV R0, #0x02

    BL init_timer0


    b .


init_timer0:
    // Cargar valor para 10ms (10.000 ticks a 1 MHz)
    LDR     R0, =0xF42
    LDR     R1, =TIMER0_LOAD
    STR     R0, [R1]

    LDR     R1, =TIMER0_CTRL
    MOV     R0, #0xEA
    STR     R0, [R1]


    LDR     R1, =TIMER0_INTCLR
    MOV     R0, #1
    STR     R0, [R1]

    BX      LR




undef_handler:
    SUB LR, LR, #4              // Volver a la instrucción que causó el fallo
    PUSH {R0-R12, LR}
    MOV R1, LR                  // Dirección donde ocurrió el fallo 
    LDR R2, =0x00000000         // Código de operación del andeq r0, r0, r0
    STR R2, [R1]                // Sobrescribe la instrucción fallida
    POP {R0-R12, LR} // Retorno de la excepcion
    MOVS PC, LR

svc_handler:
    PUSH {R2-R12, LR}          // Guardar registros menos con los que retornamos
    SUB LR, LR, #4             // Volver a la instrucción SVC
    LDR R0, [LR]               // Carga la instrucción SVC completa (32 bits)
    BIC R1, R0, #0xFF000000    
    AND R1, R1, #0xFF          // Extrae el número del SVC (último byte)
    CMP R1, #0
    BEQ suma
    CMP R1, #1
    BEQ resta

    B end_svc

suma:
    MOV R0, #0xFFFFFFFF    // parte baja A
    MOV R1, #0x00000001    // parte alta A
    MOV R2, #0x00000001    // parte baja B
    MOV R3, #0x00000000    // parte alta B
    ADDS R0, R0, R2     // Parte baja, actualiza carry
    ADC  R1, R1, R3     // Parte alta + carry
    B end_svc

resta:
    @ MOV R0, #0xFFFFFFFE   // parte baja A
    @ MOV R1, #0x00000001    // parte alta A
    @ MOV R2, #0x00000001    // parte baja B
    @ MOV R3, #0x00000000    // parte alta B
    MOV R0, #0              
    MOV R1, #1              
    MOV R2, #1              
    MOV R3, #0              
    SUBS R0, R0, R2     // actualiza flags (incluye borrow)
    SBC  R1, R1, R3     
    B end_svc

end_svc:
    POP {R2-R12, LR}            // Restaurar registros menos con los que retornamos
    MOVS PC, LR                // Regreso del handler

prefetch_abort_handler:
    

data_abort_handler:

reserved_handler:

irq_handler:
fiq_handler:
reset_handler:
    b .
.section .data 
    value_a: .word 0x000000010

.section .bss
    value_b: .word

.section .stack, "aw", %nobits
    .space 4000   // 1 KB de stack

.end


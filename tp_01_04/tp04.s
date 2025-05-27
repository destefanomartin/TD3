.global _start
.global reset_handler
.global undef_handler
.global svc_handler
@ TEXT
.extern __text_start
.extern __text_LMA
.extern __text_end
@ DATA
.extern __data_start
.extern __data_LMA
.extern __data_end
.extern move
@ RESET 
.extern __reset_start
.extern __reset_end

.extern __stack_undef
.extern __stack_svc
.extern __stack_app

/* 
R1 -> Puntero al origen 
R0 -> Puntero al destino 
R2 -> Cant bytes
*/

.section reset_vector, "ax"@progbits 
    LDR PC, jump_reset         @ 0x00
    LDR PC, jump_undef_handler      @ 0x04
    LDR PC, jump_svc_handler        @ 0x08
    LDR PC, jump_prefetch_abort_handler @ 0x0C
    LDR PC, jump_data_abort_handler @ 0x10
    LDR PC, jump_reserved_handler   @ 0x14
    LDR PC, jump_irq_handler       @ 0x18
    LDR PC, jump_fiq_handler       @ 0x1C
    
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

    @ Configurar pila para modo UNDEF
    CPS #0x1B            @ Cambiar a modo UNDEF
    LDR SP, =__stack_undef

    @ Configurar pila para modo SVC
    CPS #0x13            @ Cambiar a modo SVC
    LDR SP, =__stack_svc

    @ Luego pasar a modo SYS o modo de aplicación
    CPS #0x1F            @ Cambiar a modo SYS 
    LDR SP, =__stack_app @ (si usás una pila para el app)

reset_copy: 
    LDR R1, =__reset_start   @ destino
    LDR R0, =__reset_LMA     @ origen
    LDR R2, =__reset_end
    SUB R2, R2, R1           @ tamaño de la copia
    LDR R10, =move
    BLX R10

data_copy: 
    LDR R1, =__data_start     @ destino
    LDR R0, =__data_LMA       @ origen
    LDR R2, =__data_end
    SUB R2, R2, R1            @ tamaño de la copia
    LDR R10, =move
    BLX R10
text_copy:
    LDR R1, =__text_start     @ destino
    LDR R0, =__text_LMA       @ origen
    LDR R2, =__text_end
    SUB R2, R2, R1            @ tamaño de la copia
    LDR R10, =move
    BLX R10
    LDR R4, =code
    BLX R4
    
 

.section .text @ Donde va la aplicacion 
code:
    .word 0xE7FFFFFF
    MOV R0, #0x08

    SWI 0

    MOV R0, #0x04

    SWI 1

    b .

undef_handler:
    SUB LR, LR, #4              @ Volver a la instrucción que causó el fallo
    PUSH {R0-R12, LR}
    MOV R1, LR                  @ Dirección donde ocurrió el fallo 
    LDR R2, =0x00000000         @ Código de operación del andeq r0, r0, r0
    STR R2, [R1]                
    POP {R0-R12, LR}            @ Retorno de la excepcion
    MOVS PC, LR

svc_handler:
    PUSH {R2-R12, LR}          @ Guardar registros menos con los que retornamos
    SUB LR, LR, #4             @ Volver a la instrucción SVC
    LDR R0, [LR]               
    BIC R1, R0, #0xFF000000    
    AND R1, R1, #0xFF          @ Extrae el número del SVC 
    CMP R1, #0
    BEQ suma
    CMP R1, #1
    BEQ resta

    B end_svc

suma:
    MOV R0, #0xFFFFFFFF    
    MOV R1, #0x00000001    
    MOV R2, #0x00000001    
    MOV R3, #0x00000000    
    ADDS R0, R0, R2     @ Parte baja, actualiza carry
    ADC  R1, R1, R3     @ Parte alta + carry
    B end_svc

resta:  
    MOV R0, #0              
    MOV R1, #1              
    MOV R2, #1              
    MOV R3, #0              
    SUBS R0, R0, R2     @ actualiza flags (incluye borrow)
    SBC  R1, R1, R3     
    B end_svc

end_svc:
    POP {R2-R12, LR}            @ Restaurar registros menos con los que retornamos
    MOVS PC, LR                

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
    .space 4000   @ 1 KB de stack

.end


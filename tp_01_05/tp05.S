.global _start


@ HANDLERS
.global reset_handler
.global undef_handler
.global svc_handler


@ DEFINICION DE SECCIONES 

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
.extern __reset_LMA
@ STACK
.extern __stack_undef
.extern __stack_svc
.extern __stack_app



@ GIC ADDRESS
.equ GICC0_ADDR, 0x1E000000
.equ GICD0_ADDR, 0x1E001000


@ TIMER0
.equ TIMER0_BASE,      0x10011000
.equ TIMER0_LOAD,      TIMER0_BASE + 0x00
.equ TIMER0_CTRL,      TIMER0_BASE + 0x08
.equ TIMER0_INTCLR,    TIMER0_BASE + 0x0C
.equ TIMER0_MIS,       TIMER0_BASE + 0x14
.equ TIMER0_IRQ_ID,    36



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

    @ Modo Abort
    CPS #0x17            @ Cambiar a modo ABORT
    LDR SP, =__stack_abt

    @ Modo FIQ
    CPS #0x11            @ Cambiar a modo FIQ
    LDR SP, =__stack_fiq

    @ Modo IRQ
    CPS #0x12            @ Cambiar a modo IRQ
    LDR SP, =__stack_irq

    @ Luego pasar a modo SYS o modo de aplicación
    CPS #0x1F            @ Cambiar a modo SYS 
    LDR SP, =__stack_app @ (si usás una pila para app)



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
    MOV R10, #0x00

    SWI 0

    MOV R0, #0x04

    SWI 1

    MOV R0, #0x02

    BL init_timer0


    @ Esto seria con codigo en C
    @ LDR R10, =__gic_init
    @ MOV LR, PC
    @ BX R10

    BL gic_init


    @ No me funciona el IFDEF, pero se que deberia ser asi 
    @ #ifdef GEN_EXCEPTION
    
    @ .global conditional

    @ conditional:
    @ BL make_inv_exception     @ Llama a función que genera instrucción inválida

    @ @ BL make_mem_exception     @ Llama a función que genera acceso inválido (No funciona sin MMU)
    @ #endif 

    CPSIE i



    MOV R0, #0x02

    BL loop




loop: 
    WFI
    B loop


gic_init: 

    LDR R0, =GICC0_ADDR
    MOV R1, #0xF0
    STR R1, [R0, #0x04]

    LDR R2, =GICD0_ADDR
    LDR R3, [R2, #0x104] 
    ORR R3, R3 , #0x10
    STR R3, [R2, #0x104]

    @ Asignar prioridad maxima IRQ 36
    MOV R3, #0x00
    LDR R1, =0x424              // 0x400 + 36 
    STRB R3, [R2, R1]


    MOV R1, #0x01
    STR R1, [R0]
    STR R1, [R2]

    BX LR
    

make_mem_exception:
    LDR R0, =0xFFFFFFFF     @ Dirección inválida
    LDR R1, =0x12345    
    STR R1, [R0]            @ Provoca el Data Abort al intentar escribir

make_inv_exception:
    .word 0xE7F000F0          @ Instrucción inválida
    BX lr






init_timer0:
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


irq_handler:
    SUB LR, LR, #4
    PUSH {R0-R3, LR}

    @ Comprobacion que fue el TIMER 
    LDR R0, =TIMER0_MIS      
    LDR R1, [R0]             
    CMP R1, #1               
    BNE not_timer_irq        

    ADD R10, R10, #1

    @ Limpiar la interrupción (acknowledge)
    LDR R0, =TIMER0_INTCLR
    MOV R1, #1
    STR R1, [R0]

not_timer_irq:
    POP {R0-R3, LR}
    SUBS PC, LR, #0          @ Retorna de la IRQ
    

undef_handler:
    @ SUB LR, LR, #4              @ Volver a la instrucción que causó el error
    PUSH {R0-R9, LR}
    /* Codigo de ejercicio anterior 
    MOV R1, LR                  @ Dirección donde ocurrió el error
    LDR R2, =0x00000000         @ Código de operación del andeq r0, r0, r0
   
    STR R2, [R1]                @ Sobrescribe la instrucción 
     */
    /* Ejercicio 5 */
    LDR R10, =0x494E56        @ "INV" en ASCII
    POP {R0-R9, LR} @ Retorno de la excepcion
    @SUBS LR, LR, #8 @ Volver a la instrucción SIGUIENTE a la que causo el fallo
    MOVS PC, LR

data_abort_handler:
    PUSH {R0-R12, LR}
    LDR R10, =0x4D454D        @ "MEM" en ASCII
    POP {R0-R12, LR}            @ Retorno de la excepcion
    SUB LR, LR, #8            @ Volver a instrucción siguiente
    MOVS PC, LR               



svc_handler:
    PUSH {R2-R12, LR}          @ Guardar registros menos con los que retornamos
    SUB LR, LR, #4             @ Volver a la instrucción SVC
    LDR R0, [LR]               @ Carga la instrucción SVC completa (32 bits)
    BIC R1, R0, #0xFF000000    
    AND R1, R1, #0xFF          @ Extrae el número del SVC (último byte)
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
    MOVS PC, LR                @ Regreso del handler

prefetch_abort_handler:
    PUSH {R0-R9, LR}
    LDR R10, =0x4D454D        @ "MEM" en ASCII
    POP {R0-R9, LR} @ Retorno de la excepcion
    MOVS PC, LR    


reserved_handler:

fiq_handler:
reset_handler:
@ ldr PC,=_start
   B _start


.section .data 
    value_a: .word 0x000000010

.section .bss
    value_b: .word


.section .stack, "aw", %nobits
    .space 4000   @ 1 KB de stack

.end


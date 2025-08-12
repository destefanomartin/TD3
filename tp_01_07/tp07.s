.global _start

.extern _PUBLIC_STACK_INIT

.extern __stack_undef
.extern __stack_svc
.extern __stack_abt
.extern __stack_fiq
.extern __stack_irq 

.extern __reset_start__
.extern __reset_end__
.extern __reset_LMA

.extern __text_start__
.extern __text_end__
.extern __text_LMA

.extern __data_start__
.extern __data_end__
.extern __data_LMA

.extern __t1_text_start__
.extern __t1_text_end__
.extern __t1_text_LMA
.extern __t2_text_end__
.extern __t2_text_LMA
.extern __t2_text_start__

.extern __data_task_start__
.extern __data_task_end__
.extern __data_task_LMA

.extern __stack_task1_end
.extern __stack_task2_end
.extern __public_stack_end

.extern __public_stack_end
.extern __public_stack_start
.extern STACK_SIZE

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


@ PAGINACION 

@ KERNEL

.equ tabla_primer_nivelK, 0x82000000
.equ tabla_segundo_nivel1, tabla_primer_nivelK + 0x4000
.equ tabla_segundo_nivel2, tabla_segundo_nivel1 + 0x400
.equ tabla_segundo_nivel3, tabla_segundo_nivel2 + 0x400
.equ tabla_segundo_nivel4, tabla_segundo_nivel3 + 0x400
.equ tabla_segundo_nivel5, tabla_segundo_nivel4 + 0x400

.equ tabla_primer_nivel_tarea1, 0x82008000
.equ tabla_segundo_nivel_tarea1, tabla_primer_nivel_tarea1 + 0x4000
.equ tabla_segundo_nivel_tarea1_1, tabla_segundo_nivel_tarea1 + 0x400
.equ tabla_segundo_nivel_tarea1_2, tabla_segundo_nivel_tarea1_1 + 0x400
.equ tabla_segundo_nivel_tarea1_3, tabla_segundo_nivel_tarea1_2 + 0x400
.equ tabla_segundo_nivel_tarea1_4, tabla_segundo_nivel_tarea1_3 + 0x400
.equ tabla_segundo_nivel_tarea1_5, tabla_segundo_nivel_tarea1_4 + 0x400 

.equ tabla_primer_nivel_tarea2, 0x82010000
.equ tabla_segundo_nivel_tarea2, tabla_primer_nivel_tarea2 + 0x4000
.equ tabla_segundo_nivel_tarea2_1, tabla_segundo_nivel_tarea2 + 0x400
.equ tabla_segundo_nivel_tarea2_2, tabla_segundo_nivel_tarea2_1 + 0x400
.equ tabla_segundo_nivel_tarea2_3, tabla_segundo_nivel_tarea2_2 + 0x400
.equ tabla_segundo_nivel_tarea2_4, tabla_segundo_nivel_tarea2_3 + 0x400
.equ tabla_segundo_nivel_tarea2_5, tabla_segundo_nivel_tarea2_4 + 0x400

@ Direcciones fisicas

.equ RESET_ADDR, 0x70000000
.equ INIT_ADDR, 0x70010000
.equ KIDLE_ADDR, 0x70030000
.equ T1_ADDR, 0x80010000
.equ T2_ADDR, 0x80020000
.equ STACK_ADDR, 0x80100000
.equ DATA_T1_ADDR, 0x80200000
.equ DATA_T2_ADDR, 0x80210000 // otros privilegios
.equ DATA_KERNEL_ADDR, 0x81000000
.equ BSS_T1_ADDR, 0x8030000 // otros privilegios
.equ BSS_T2_ADDR, 0x80310000 // otros privilegios
.equ BSS_KERNEL_ADDR, 0x82000000
.equ READAREA_T1, 0x70A00000
.equ READAREA_T2, 0x70A10000


.equ longitud_tablas, 0x4000*6


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


@ Va en inicializacion porque es lo que mueve el codigo para su ejecucion */
.section boot,"ax"@progbits  
_start:    

//inicializo SP0
    LDR R0,=_PUBLIC_STACK_INIT
    LDR R1,=STACK_SIZE



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
    LDR SP, =_PUBLIC_STACK_INIT
reset_copy: 
    LDR R0, =__reset_start__   @ destino
    LDR R1, =__reset_LMA     @ origen
    LDR R2, =__reset_end__
    SUB R2, R2, R0           @ tamaño de la copia

byte_copy:
    LDRB R3, [R1], #1
    STRB R3, [R0], #1
    SUBS R2, R2, #1
    BNE byte_copy// Verifica flag 

data_copy: 
    LDR R0, =__data_start__    @ destino
    LDR R1, =__data_LMA       @ origen
    LDR R2, =__data_end__
    SUB R2, R2, R0            @ tamaño de la copia

byte_copy1:
    LDRB R3, [R1], #1
    STRB R3, [R0], #1
    SUBS R2, R2, #1
    BNE byte_copy1// Verifica flag 

text_copy:
    LDR R0, =__text_start__    @ destino
    LDR R1, =__text_LMA       @ origen
    LDR R2, =__text_end__
    SUB R2, R2, R0            @ tamaño de la copia

byte_copy2:
    LDRB R3, [R1], #1
    STRB R3, [R0], #1
    SUBS R2, R2, #1
    BNE byte_copy2// Verifica flag 
    
task1_copy: 
    LDR R0, =T1_ADDR    @ destino
    LDR R1, =__t1_text_LMA       @ origen
    LDR R2, =__t1_text_end__
    LDR R3, =__t1_text_start__
    SUB R2, R2, R3            @ tamaño de la copia

byte_copy3:
    LDRB R4, [R1], #1
    STRB R4, [R0], #1
    SUBS R2, R2, #1
    BNE byte_copy3// Verifica flag 

task2_copy: 
    LDR R0, =T2_ADDR   @ destino
    LDR R1, =__t2_text_LMA       @ origen
    LDR R2, =__t2_text_end__
    LDR R3, =__t2_text_start__
    SUB R2, R2, R3            @ tamaño de la copia

byte_copy4:
    LDRB R4, [R1], #1
    STRB R4, [R0], #1
    SUBS R2, R2, #1
    BNE byte_copy4// Verifica flag

    LDR R1, =tabla_primer_nivelK
    LDR R2, =longitud_tablas
    MOV R0, #0
ciclo_borrado:
    STRB R0, [R1], #1
    SUBS R2, #1
    BNE ciclo_borrado

    @ Paginacion Kernel

    LDR R0, =tabla_primer_nivelK + 0x700*4
    LDR R1, =tabla_segundo_nivel1 + 1
    STR R1, [R0]

    LDR R0, =tabla_primer_nivelK + 0x810*4
    LDR R1, =tabla_segundo_nivel2 + 1
    STR R1, [R0]

    LDR R0, =tabla_primer_nivelK + 0x820*4
    LDR R1, =tabla_segundo_nivel3 + 1
    STR R1, [R0]

    LDR R0, =tabla_primer_nivelK + 0x1E0*4
    LDR R1, =tabla_segundo_nivel4 + 1
    STR R1, [R0]   

    LDR R0, =tabla_primer_nivelK + 0x100*4
    LDR R1, =tabla_segundo_nivel5 + 1
    STR R1, [R0]

    @ Paginacion Kernel - Direcciones Fisicas

    LDR R0, =tabla_segundo_nivel1 + 0x10*4
    LDR R1, =INIT_ADDR + 0x32
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel1 + 0x30*4
    LDR R1, =KIDLE_ADDR + 0x32
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel1 + 0x00*4
    LDR R1, =RESET_ADDR + 0x32
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel1 + 0x60*4
    LDR R1, =STACK_ADDR + 0x32
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel1 + 0x61*4
    LDR R1, =STACK_ADDR + 0x32
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel1 + 0x62*4
    LDR R1, =STACK_ADDR + 0x32
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel1 + 0x63*4
    LDR R1, =STACK_ADDR + 0x32
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel2 + 0x00*4
    LDR R1, =DATA_KERNEL_ADDR + 0x32
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel3 + 0x00*4
    LDR R1, =BSS_KERNEL_ADDR + 0x31
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel3 + 0x01*4
    LDR R1, =BSS_KERNEL_ADDR + 0x31
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel4 + 0x00*4
    LDR R1, =GICC0_ADDR + 0x32
    STR R1, [R0, #0]


    LDR R0, =tabla_segundo_nivel4 + 0x01*4
    LDR R1, =GICD0_ADDR + 0x32
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel5 + 0x11*4
    LDR R1, =TIMER0_BASE + 0x32
    STR R1, [R0, #0]


    @ Paginacion Tarea 1

    LDR R0, =tabla_primer_nivel_tarea1 + 0x700*4
    LDR R1, =tabla_segundo_nivel_tarea1 + 1
    STR R1, [R0]    

    LDR R0, =tabla_primer_nivel_tarea1 + 0x701*4
    LDR R1, =tabla_segundo_nivel_tarea1_1 + 1
    STR R1, [R0]

    LDR R0, =tabla_primer_nivel_tarea1 + 0x70A*4
    LDR R1, =tabla_segundo_nivel_tarea1_2 + 1
    STR R1, [R0]

    @ Paginacion Tarea 1 - Direcciones Fisicas

    LDR R0, =tabla_segundo_nivel_tarea1 + 0x00*4
    LDR R1, =RESET_ADDR + 0x32
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea1 + 0x40*4
    LDR R1, =T1_ADDR + 0x32
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea1 + 0x60*4
    LDR R1, =STACK_ADDR + 0x32
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea1 + 0x61*4
    LDR R1, =STACK_ADDR + 0x32
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea1 + 0x62*4
    LDR R1, =STACK_ADDR + 0x32
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea1 + 0x63*4
    LDR R1, =STACK_ADDR + 0x32
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea1 + 0xA0*4
    LDR R1, =DATA_T1_ADDR + 0x32
    STR R1, [R0, #0]


    LDR R0, =tabla_segundo_nivel_tarea1_1 + 0x00*4
    LDR R1, =BSS_T1_ADDR + 0x32
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea1_2 + 0x00*4
    LDR R1, =READAREA_T1 + 0x31
    MOV R4, #16    // Cantidad de descriptores.
ciclo_escritura_descriptores_64KB_1:
    STR R1, [R0], #4
    SUBS R4, #1
    BNE ciclo_escritura_descriptores_64KB_1


    @ Paginacion Tarea 2

    LDR R0, =tabla_primer_nivel_tarea2 + 0x700*4
    LDR R1, =tabla_segundo_nivel_tarea2 + 1
    STR R1, [R0]

    LDR R0, =tabla_primer_nivel_tarea2 + 0x701*4
    LDR R1, =tabla_segundo_nivel_tarea2_1 + 1
    STR R1, [R0]  

    LDR R0, =tabla_primer_nivel_tarea2 + 0x70A*4
    LDR R1, =tabla_segundo_nivel_tarea2_2 + 1
    STR R1, [R0]

    @ Paginacion Tarea 2 - Direcciones Fisicas    

    LDR R0, =tabla_segundo_nivel_tarea2 + 0x00*4
    LDR R1, =RESET_ADDR + 0x32
    STR R1, [R0, #0]
    
    LDR R0, =tabla_segundo_nivel_tarea2 + 0x40*4
    LDR R1, =T2_ADDR + 0x32
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea2 + 0x60*4
    LDR R1, =STACK_ADDR + 0x32
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea2 + 0x61*4
    LDR R1, =STACK_ADDR + 0x32
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea2 + 0x62*4
    LDR R1, =STACK_ADDR + 0x32
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea2 + 0x63*4
    LDR R1, =STACK_ADDR + 0x32
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea2 + 0xA0*4
    LDR R1, =DATA_T2_ADDR + 0x32
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea2_1 + 0x00*4
    LDR R1, =BSS_T2_ADDR + 0x32
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea2_2 + 0x01*4
    LDR R1, =READAREA_T2 + 0x31
    MOV R4, #16    // Cantidad de descriptores.
ciclo_escritura_descriptores_64KB_2:
    STR R1, [R0], #4
    SUBS R4, #1
    BNE ciclo_escritura_descriptores_64KB_2

    BL init_vms

    // Habilitar MMU
    MRC p15, 0,R1, c1, c0, 0    // Leer reg. control.
    ORR R1, R1, #0x1            // Bit 0 es habilitación de MMU.
    MCR p15, 0, R1, c1, c0, 0   // Escribir reg. control.    

    LDR     R0, =0x70000000  
    MCR     p15, 0, R0, c12, c0, 0   // Write to VBAR
    ISB                              // Asegurar sincronización

    MRC     p15, 0, R0, c2, c0, 0     @ Leer TTBR0
    LDR     R1, =0x70060100
    LSR     R2, R1, #20               @ índice 1er nivel
    LSL     R2, R2, #2                 @ multiplicar por tamaño de entrada
    ADD     R0, R0, R2                 @ dirección de la entrada
    LDR     R3, [R0]                   @ leer entrada




    BL init_timer0

    BL gic_init

    CPSIE i

    BL loop

.section .text, "ax"
loop: 
    WFI
    B loop



init_vms: 

    LDR R0, =0x55555555
    MCR p15, 0, R0, c3, c0, 0 @ ok 

    MRC     p15, 0, R0, c1, c0, 0    @ Leer SCTLR
    ORR     R0, R0, #0x20000000       @ Establecer bit AFE (bit 29)
    MCR     p15, 0, R0, c1, c0, 0    @ Escribir SCTLR

    MRC     p15, 0, R0, c2, c0, 2    @ Leer TTBCR
    ORR     R0, R0, #0x00       
    MCR     p15, 0, R0, c2, c0, 2    @ Escribir TTBCR

    LDR R0,= tabla_primer_nivelK
    MCR p15, 0, R0, c2, c0, 0

    

    BX LR 

gic_init: 

    LDR R0, =GICC0_ADDR
    MOV R1, #0xF0
    STR R1, [R0, #0x04]

    LDR R2, =GICD0_ADDR
    LDR R3, [R2, #0x104] 
    ORR R3, R3 , #0x10
    STR R3, [R2, #0x104]

    @ Asignar prioridad maxima IRQ 36
    @ MOV R3, #0x00
    @ LDR R1, =0x424              // 0x400 + 36 
    @ STRB R3, [R2, R1]

    MOV R1, #0x01
    STR R1, [R0]
    STR R1, [R2]

    BX LR


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

error_init:
    B error_init

@ irq_handler:

@     @ SUB LR, LR, #4
@     @ PUSH {R0-R12, LR}   
@     @ MRS R0, SPSR
@     @ PUSH {R0}                         
@     @ LDR R0, =TIMER0_INTCLR
@     @ MOV R1, #1
@     @ STR R1, [R0]



@     @ //LDR R1, =task_order
@     @ CMP R1, #0 
@     @ BEQ task1
@     @ CMP R1, #1
@     @ BEQ task2
irq_handler:
    SUB     LR, LR, #4
    PUSH    {LR}
    PUSH    {R0-R12}
    MRS     R0, SPSR
    PUSH    {R0}
    
    LDR R0, =TIMER0_INTCLR
    MOV R1, #1
    STR R1, [R0]

    LDR     R0, =task
    LDR     R1, [R0]           
    CMP     R1, #0
    BEQ     run_task1
    CMP     R1, #1
    BEQ     run_task2
    

run_kernel:
    BL      loop       
    B       update_phase

run_task1:

    LDR     R5, =__public_stack_end
    LDR     SP, [R5]
    LDR     R0, =tabla_primer_nivel_tarea1
    LDR     R3, =__stack_task1_end
    MOV     R5, #1
    MCR     P15, 0, R0, C2, C0, 0
    ISB


    BL      task1

    @ RESTAURAR KERNEL
    LDR     R2, =tabla_primer_nivelK
    MCR     P15, 0, R2, C2, C0, 0
    ISB

    LDR     R3, =__public_stack_end
    LDR     SP, [R3]
    B       update_phase

run_task2:
    LDR     R2, =tabla_primer_nivel_tarea2
    MCR     P15, 0, R2, C2, C0, 0
    ISB

    LDR     R3, =__stack_task2_end
    LDR     SP, [R3]

    BL      task2

    @ RESTAURAR KERNEL
    LDR     R2, =tabla_primer_nivelK
    MCR     P15, 0, R2, C2, C0, 0
    ISB

    LDR     R3, =__public_stack_end
    LDR     SP, [R3]

update_phase:
    @ --- INCREMENTAR FASE Y VOLVER A 0 CUANDO LLEGUE A 10 ---
    LDR     R0, =IRQ_PHASE
    LDR     R1, [R0]
    ADD     R1, R1, #1
    CMP     R1, #10
    MOVEQ   R1, #0
    STR     R1, [R0]

    @ ----- EPILOGUE (IRQ) -----
    POP     {R0-R12}
    POP     {LR}
    ISB 
    DSB
    MOVS    PC, LR    
reset_handler: 
    B reset_handler

fiq_handler: 
    B fiq_handler
    
undef_handler: 
    B undef_handler

svc_handler: 
    B svc_handler

prefetch_abort_handler: 
    B prefetch_abort_handler

data_abort_handler:
    SUB     lr, lr, #8          // Ajuste típico de LR en aborts

    MRC     p15, 0, r0, c6, c0, 0   // r0 = DFAR
    MRC     p15, 0, r1, c5, c0, 0   // r1 = DFSR

    LDR     r2, =debug_dfar
    STR     r0, [r2]

    LDR     r2, =debug_dfsr
    STR     r1, [r2]
    B data_abort_handler

reserved_handler: 
    B reserved_handler  



.section .data 
    task: .word 0
    SP0: .space 4 
    task: .space 4
    debug_dfar:  .word 0
    debug_dfsr:  .word 0
    .global SP0
    .global task


    

.section .bss
    tabla_primer_nivel_tarea1: .space 16384
    tabla_primer_nivel_tarea2: .space 16384
    tabla_primer_nivelK: .space 16384
    


.section .stack, "aw", %nobits   

.end

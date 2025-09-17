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

.extern _TASK_INIT
.extern _SHARED_MEM_INIT_

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

.equ tabla_primer_nivel_tarea2, 0x82010000
.equ tabla_segundo_nivel_tarea2, tabla_primer_nivel_tarea2 + 0x4000
.equ tabla_segundo_nivel_tarea2_1, tabla_segundo_nivel_tarea2 + 0x400
.equ tabla_segundo_nivel_tarea2_2, tabla_segundo_nivel_tarea2_1 + 0x400
.equ tabla_segundo_nivel_tarea2_3, tabla_segundo_nivel_tarea2_2 + 0x400
.equ tabla_segundo_nivel_tarea2_4, tabla_segundo_nivel_tarea2_3 + 0x400

@ Direcciones fisicas

.equ RESET_ADDR, 0x70000000
.equ INIT_ADDR, 0x70010000
.equ KIDLE_ADDR, 0x70030000
.equ T1_ADDR, 0x80010000
.equ T2_ADDR, 0x80020000
.equ STACK_ADDR, 0x80100000
.equ DATA_T1_ADDR, 0x80200000
.equ DATA_T2_ADDR, 0x80210000 
.equ DATA_KERNEL_ADDR, 0x81000000
.equ BSS_T1_ADDR, 0x80300000 
.equ BSS_T2_ADDR, 0x80310000 
.equ BSS_KERNEL_ADDR, 0x82000000
.equ READAREA_T1, 0x70A00000
.equ READAREA_T2, 0x70A10000



.equ longitud_tablas, 0x4000*6




.section boot,"ax"@progbits  
_start:    

    LDR     R0, =STACK_ADDR + 0x2300  
    
    // Preparo pilas 
    
    ADD     R0, R0, #4
    MOV     R2, #0x10               
    STR     R2, [R0]

 
    MOV     R2, #0
    MOV     R3, #12             
init_regs_loop:
    ADD     R0, R0, #4
    STR     R2, [R0]
    SUBS    R3, R3, #1
    BNE     init_regs_loop

    ADD     R0, R0, #4
    LDR     R2, =_TASK_INIT
    STR     R2, [R0]


    LDR     R0, =STACK_ADDR + 0x3300  
    
    ADD     R0, R0, #4
    MOV     R2, #0x10               
    STR     R2, [R0]

 
    MOV     R2, #0
    MOV     R3, #12             
init_regs_loop_t2:
    ADD     R0, R0, #4
    STR     R2, [R0]
    SUBS    R3, R3, #1
    BNE     init_regs_loop_t2

    ADD     R0, R0, #4
    LDR     R2, =_TASK_INIT
    STR     R2, [R0]

    LDR     R0, =STACK_ADDR + 0x1300
    
    // SPSR inicial
    ADD     R0, R0, #4
    MOV     R2, #0x10               
    STR     R2, [R0]

 
    MOV     R2, #0
    MOV     R3, #12             
init_regs_loopk:
    ADD     R0, R0, #4
    STR     R2, [R0]
    SUBS    R3, R3, #1
    BNE     init_regs_loopk

    ADD     R0, R0, #4
    LDR     R2, =loop
    STR     R2, [R0]




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
    LDR SP, =__stack_sys



    LDR R0, =__reset_start__
    LDR R1, =__reset_LMA
    LDR R2, =__reset_end__
    SUB R2, R2, R0
    BL copy_section

 
    LDR R0, =__data_start__
    LDR R1, =__data_LMA
    LDR R2, =__data_end__
    SUB R2, R2, R0
    BL copy_section


    LDR R0, =__text_start__
    LDR R1, =__text_LMA
    LDR R2, =__text_end__
    SUB R2, R2, R0
    BL copy_section


    LDR R0, =T1_ADDR
    LDR R1, =__t1_text_LMA
    LDR R2, =__t1_text_end__
    LDR R3, =__t1_text_start__
    SUB R2, R2, R3
    BL copy_section


    LDR R0, =T2_ADDR
    LDR R1, =__t2_text_LMA
    LDR R2, =__t2_text_end__
    LDR R3, =__t2_text_start__
    SUB R2, R2, R3
    BL copy_section


    LDR R0, =DATA_T1_ADDR
    LDR R1, =__data_task1_LMA
    LDR R2, =__data_task1_end__
    LDR R3, =__data_task1_start__
    SUB R2, R2, R3
    BL copy_section


    LDR R0, =DATA_T2_ADDR
    LDR R1, =__data_task2_LMA
    LDR R2, =__data_task2_end__
    LDR R3, =__data_task2_start__
    SUB R2, R2, R3
    BL copy_section

copy_section:
    CMP     R2, #0
    BEQ     copy_done
copy_loop:
    LDRB    R3, [R1], #1
    STRB    R3, [R0], #1
    SUBS    R2, R2, #1
    BNE     copy_loop
copy_done:
    BX      LR
 
paginacion:

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
    LDR R1, =INIT_ADDR + 0x12
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel1 + 0x20*4
    LDR R1, =_SHARED_MEM_INIT_ + 0x32
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel1 + 0x30*4
    LDR R1, =KIDLE_ADDR + 0xA22 
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel1 + 0x00*4
    LDR R1, =RESET_ADDR + 0x212
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel1 + 0x60*4
    LDR R1, =STACK_ADDR + 0x32
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel1 + 0x61*4
    LDR R1, =STACK_ADDR + 0x1032
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel1 + 0x62*4
    LDR R1, =STACK_ADDR + 0x2032
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel1 + 0x63*4
    LDR R1, =STACK_ADDR + 0x3032
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel2 + 0x00*4
    LDR R1, =DATA_KERNEL_ADDR + 0x32
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel3 + 0x00*4
    LDR R1, =BSS_KERNEL_ADDR + 0x11 // RW PL1
    MOV R4, #32    // Cantidad de descriptores.
ciclo_escritura_descriptores_64KB:
    STR R1, [R0], #4
    SUBS R4, #1
    BNE ciclo_escritura_descriptores_64KB

    LDR R0, =tabla_segundo_nivel4 + 0x00*4 //RW PL1 
    LDR R1, =GICC0_ADDR + 0x12
    STR R1, [R0, #0]


    LDR R0, =tabla_segundo_nivel4 + 0x01*4 //RW PL1 
    LDR R1, =GICD0_ADDR + 0x12
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel5 + 0x11*4 //RW PL1 
    LDR R1, =TIMER0_BASE + 0x12
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

    LDR R0, =tabla_primer_nivel_tarea1 + 0x1E0*4
    LDR R1, =tabla_segundo_nivel_tarea1_3 + 1
    STR R1, [R0]

    LDR R0, =tabla_primer_nivel_tarea1 + 0x100*4
    LDR R1, =tabla_segundo_nivel_tarea1_4 + 1
    STR R1, [R0]

    @ Paginacion Tarea 1 - Direcciones Fisicas

    LDR R0, =tabla_segundo_nivel_tarea1 + 0x00*4
    LDR R1, =RESET_ADDR + 0x212
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea1 + 0x20*4
    LDR R1, =_SHARED_MEM_INIT_ + 0x12
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea1 + 0x40*4
    LDR R1, =T1_ADDR + 0xA22
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea1 + 0x60*4
    LDR R1, =STACK_ADDR + 0x32
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea1 + 0x61*4
    LDR R1, =STACK_ADDR + 0x1032
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea1 + 0x62*4
    LDR R1, =STACK_ADDR + 0x2032
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea1 + 0x63*4
    LDR R1, =STACK_ADDR + 0x3032
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea1 + 0xA0*4
    LDR R1, =DATA_T1_ADDR + 0x832
    STR R1, [R0, #0]


    LDR R0, =tabla_segundo_nivel_tarea1_1 + 0x00*4
    LDR R1, =BSS_T1_ADDR + 0x832
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea1_2 + 0x00*4
    LDR R1, =READAREA_T1 + 0x831
    MOV R4, #16    
ciclo_escritura_descriptores_64KB_1:
    STR R1, [R0], #4
    SUBS R4, #1
    BNE ciclo_escritura_descriptores_64KB_1

    LDR R0, =tabla_segundo_nivel_tarea1_3 + 0x00*4
    LDR R1, =GICC0_ADDR + 0x12
    STR R1, [R0, #0]


    LDR R0, =tabla_segundo_nivel_tarea1_3 + 0x01*4
    LDR R1, =GICD0_ADDR + 0x12
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea1_4 + 0x11*4
    LDR R1, =TIMER0_BASE + 0x12
    STR R1, [R0, #0]



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

    LDR R0, =tabla_primer_nivel_tarea2 + 0x1E0*4
    LDR R1, =tabla_segundo_nivel_tarea2_3 + 1
    STR R1, [R0]

    LDR R0, =tabla_primer_nivel_tarea2 + 0x100*4
    LDR R1, =tabla_segundo_nivel_tarea2_4 + 1
    STR R1, [R0]

    @ Paginacion Tarea 2 - Direcciones Fisicas    

    LDR R0, =tabla_segundo_nivel_tarea2 + 0x00*4
    LDR R1, =RESET_ADDR + 0x212
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea2 + 0x20*4
    LDR R1, =_SHARED_MEM_INIT_ + 0x12
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea2 + 0x40*4
    LDR R1, =T2_ADDR + 0xA22
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea2 + 0x60*4
    LDR R1, =STACK_ADDR + 0x32
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea2 + 0x61*4
    LDR R1, =STACK_ADDR + 0x1032
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea2 + 0x62*4
    LDR R1, =STACK_ADDR + 0x2032
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea2 + 0x63*4
    LDR R1, =STACK_ADDR + 0x3032
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea2 + 0xA0*4
    LDR R1, =DATA_T2_ADDR + 0x832
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea2_1 + 0x00*4
    LDR R1, =BSS_T2_ADDR + 0x832
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea2_2 + 0x10*4
    LDR R1, =READAREA_T2 + 0x831
    MOV R4, #16    
ciclo_escritura_descriptores_64KB_2:
    STR R1, [R0], #4
    SUBS R4, #1
    BNE ciclo_escritura_descriptores_64KB_2

    LDR R0, =tabla_segundo_nivel_tarea2_3 + 0x00*4
    LDR R1, =GICC0_ADDR + 0x12
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea2_3 + 0x01*4
    LDR R1, =GICD0_ADDR + 0x12
    STR R1, [R0, #0]

    LDR R0, =tabla_segundo_nivel_tarea2_4 + 0x11*4
    LDR R1, =TIMER0_BASE + 0x12
    STR R1, [R0, #0]


    BL init_vms

  // Activo MMU
    MRC p15, 0,R1, c1, c0, 0    
    ORR R1, R1, #0x1           
    MCR p15, 0, R1, c1, c0, 0   
    ISB  

    LDR     R0, =0x70000000  
    MCR     p15, 0, R0, c12, c0, 0   
    ISB                              

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

// Bit AFE = 0 para usar tabla permisos AP
    @ MRC     p15, 0, R0, c1, c0, 0    @ Leer SCTLR
    @ ORR     R0, R0, #0x20000000       @ Establecer bit AFE (bit 29)
    @ MCR     p15, 0, R0, c1, c0, 0    @ Escribir SCTLR

    MRC     p15, 0, R0, c2, c0, 2    @ Leer TTBCR
    ORR     R0, R0, #0x00       
    MCR     p15, 0, R0, c2, c0, 2    @ Escribir TTBCR

    LDR R0,= tabla_primer_nivelK
    MCR p15, 0, R0, c2, c0, 0

    MOV   R0, #0
    MCR   p15, 0, R0, c13, c0, 1    // ContextIDR := 0
    ISB
    
    MOV   R0, #0
    MCR   p15, 0, R0, c8, c7, 0     // TLBIALL (unified)
    DSB
    ISB

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




irq_handler:
    SUB     LR, LR, #4
    PUSH    {LR}
    PUSH    {R0-R12}
    MRS     R0, SPSR
    PUSH    {R0}
    
    LDR R0, =TIMER0_INTCLR
    MOV R1, #1
    STR R1, [R0]
// Selecciono siguiente tarea
    LDR     R2, =task
    LDR     R0, [R2]           
    CMP     R0, #0
    BEQ     run_task1
    CMP     R0, #1
    BEQ     run_task2
    LDR     R0, =tabla_primer_nivelK
    LDR     R3, =__public_stack_end
    MOV     R4, #3
    MOV     R5, #0
    STR     R5, [R2]
    BL      timer80ms
    B       change_ttbr0

run_task1:
    LDR     R0, =tabla_primer_nivel_tarea1
    LDR     R3, =__stack_task1_end
    MOV     R4, #1
    MOV     R5, #1
    STR     R5, [R2]
    BL      timer10ms
    B       change_ttbr0
run_task2:
    LDR     R0, =tabla_primer_nivel_tarea2
    LDR     R3, =__stack_task2_end
    MOV     R4, #2
    MOV     R5, #3
    STR     R5, [R2]
    BL      timer10ms

change_ttbr0: 
    DSB
    MCR     P15, 0, R0, C2, C0, 0
    ISB
    MCR     P15, 0, R4, C13, C0, 1
    ISB                              
    
    MOV     SP, R3

    POP {R0}
    MSR SPSR,R0
    POP {R0-R12}
    POP {LR}
    DSB
    ISB    
    MOVS PC,LR 


timer10ms: 
    LDR     R6, =0xF42
    LDR     R1, =TIMER0_LOAD
    STR     R6, [R1]
    BX      LR

timer80ms: 
    LDR     R6, =0x7A12
    LDR     R1, =TIMER0_LOAD
    STR     R6, [R1]
    BX      LR


reset_handler: 
    B reset_handler

fiq_handler: 
    B fiq_handler
    
undef_handler: 
    B undef_handler

svc_handler: 
    B svc_handler

prefetch_abort_handler: 
    MRC     p15, 0, R0, c6, c0, 2    @ R0 = IFAR (VA que falló)

    MRC     p15, 0, R1, c5, c0, 1    @ R1 = IFSR

    AND     R2, R1, #0xF             
    MOV     R3, R1, LSR #10
    AND     R3, R3, #1              
    LSL     R3, R3, #4               
    ORR     R2, R2, R3               

    LDR     R4, =debug_ifar
    STR     R0, [R4]
    LDR     R4, =debug_ifsr_fs
    STR     R2, [R4]

    LDR     R4, =debug_ifsr_raw
    STR     R1, [R4]

handler_loop:  B       handler_loop

data_abort_handler:
    SUB     LR, LR, #8          
    MRC     p15, 0, R0, c6, c0, 0  
    MRC     p15, 0, R1, c5, c0, 0   

    LDR     R2, =debug_dfar
    STR     R0, [R2]

    LDR     R2, =debug_dfsr
    STR     R1, [R2]
    B data_abort_handler

reserved_handler: 
    B reserved_handler  



.section .data 
    debug_dfar:  .word 0
    debug_dfsr:  .word 0
    debug_ifar:        .word 0
    debug_ifsr_fs:     .word 0
    debug_ifsr_raw:    .word 0


.section .shared_mem, "aw"
    .global task
    task: .word 0


.section .bss, "aw", %nobits


.section .stack, "aw", %nobits   

.end

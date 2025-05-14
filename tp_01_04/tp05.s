# 0 "tp05.S"
# 0 "<built-in>"
# 0 "<command-line>"
# 1 "/usr/include/stdc-predef.h" 1 3 4
# 0 "<command-line>" 2
# 1 "tp05.S"
.global _start
.global reset_handler
.global undef_handler
.global svc_handler

.extern __text_start
.extern __text_LMA
.extern __text_end

.extern __data_start
.extern __data_LMA
.extern __data_end
.extern move

.extern __reset_start
.extern __reset_end
.extern __reset_LMA

.extern __stack_undef
.extern __stack_svc
.extern __stack_app



.equ TIMER0_BASE, 0x10011000
.equ TIMER0_LOAD, TIMER0_BASE + 0x00
.equ TIMER0_CTRL, TIMER0_BASE + 0x08
.equ TIMER0_INTCLR, TIMER0_BASE + 0x0C
.equ TIMER0_MIS, TIMER0_BASE + 0x14
.equ TIMER0_IRQ_ID, 36



.section reset_vector, "ax"@progbits
    LDR PC, jump_reset
    LDR PC, jump_undef_handler
    LDR PC, jump_svc_handler
    LDR PC, jump_prefetch_abort_handler
    LDR PC, jump_data_abort_handler
    LDR PC, jump_reserved_handler
    LDR PC, jump_irq_handler
    LDR PC, jump_fiq_handler

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

.section boot,"ax"@progbits
_start:




    CPS #0x1B
    LDR SP, =__stack_undef


    CPS #0x13
    LDR SP, =__stack_svc


    CPS #0x17
    LDR SP, =__stack_abt


    CPS #0x11
    LDR SP, =__stack_fiq


    CPS #0x12
    LDR SP, =__stack_irq


    CPS #0x1F
    LDR SP, =__stack_app



reset_copy:
    LDR R1, =__reset_start
    LDR R0, =__reset_LMA
    LDR R2, =__reset_end
    SUB R2, R2, R1
    LDR R10, =move
    BLX R10

data_copy:
    LDR R1, =__data_start
    LDR R0, =__data_LMA
    LDR R2, =__data_end
    SUB R2, R2, R1
    LDR R10, =move
    BLX R10
text_copy:
    LDR R1, =__text_start
    LDR R0, =__text_LMA
    LDR R2, =__text_end
    SUB R2, R2, R1
    LDR R10, =move
    BLX R10
    LDR R4, =code
    BLX R4



.section .text
code:
    MOV R0, #0x08

    SWI 0

    MOV R0, #0x04

    SWI 1

    MOV R0, #0x02

    BL init_timer0

    LDR R10, =__gic_init
    MOV LR, PC
    BX R10







    CPSIE i



    MOV R0, #0x02

    BL loop

loop:
    WFI
    B loop


make_mem_exception:
    LDR R0, =0xFFFFFFFF
    LDR R1, =0x12345
    STR R1, [R0]

make_inv_exception:
    .word 0xE7F000F0
    BX lr






init_timer0:
    LDR R0, =0xF42
    LDR R1, =TIMER0_LOAD
    STR R0, [R1]

    LDR R1, =TIMER0_CTRL
    MOV R0, #0xEA
    STR R0, [R1]


    LDR R1, =TIMER0_INTCLR
    MOV R0, #1
    STR R0, [R1]

    BX LR


irq_handler:
    SUB LR, LR, #4
    PUSH {R0-R3, LR}

    LDR R0, =TIMER0_MIS
    LDR R1, [R0]
    CMP R1, #1
    BNE not_timer_irq

    ADD R10, R10, #1


    LDR R0, =TIMER0_INTCLR
    MOV R1, #1
    STR R1, [R0]

not_timer_irq:
    POP {R0-R3, LR}
    SUBS PC, LR, #0


undef_handler:

    PUSH {R0-R9, LR}







    LDR R10, =0x494E56
    POP {R0-R9, LR}

    MOVS PC, LR

data_abort_handler:
    PUSH {R0-R12, LR}
    LDR R10, =0x4D454D
    POP {R0-R12, LR}
    SUB LR, LR, #8
    MOVS PC, LR




svc_handler:
    PUSH {R2-R12, LR}
    SUB LR, LR, #4
    LDR R0, [LR]
    BIC R1, R0, #0xFF000000
    AND R1, R1, #0xFF
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
    ADDS R0, R0, R2
    ADC R1, R1, R3
    B end_svc

resta:
    MOV R0, #0
    MOV R1, #1
    MOV R2, #1
    MOV R3, #0
    SUBS R0, R0, R2
    SBC R1, R1, R3
    B end_svc

end_svc:
    POP {R2-R12, LR}
    MOVS PC, LR

prefetch_abort_handler:
    PUSH {R0-R9, LR}
    LDR R10, =0x4D454D
    POP {R0-R9, LR}
    MOVS PC, LR


reserved_handler:

fiq_handler:
reset_handler:
    b .
.section .data
    value_a: .word 0x000000010

.section .bss
    value_b: .word


.section .stack, "aw", %nobits
    .space 4000

.end

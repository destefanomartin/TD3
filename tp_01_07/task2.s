.global task2
.global init_t2

.equ addr_start, 0x70A10000
.equ addr_end, 0x70A1FFFF

.section .t2_text, "ax"
task2: 
    LDR R0, =addr_start
    LDR R1, =addr_end

loop:     
    LDR R2, [R0]
    MVN R3, R2
    STR R3, [R0]
    ADD R0, R0, #4
    CMP R0, R1
    BLT loop    
    BLX LR


.section .task2_data, "wa"
    SP2: .space 4 
    .global SP2


.section .task1_bss, "wa"

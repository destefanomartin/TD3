.equ addr_start 0x70A10000
.equ addr_end 0x70A1FFFF

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
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


@ PAGINACION 

.equ tabla_primer_nivel, 0x70024000
.equ tabla_segundo_nivel1, 0x70022000
.equ tabla_segundo_nivel2, 0x70022400
.equ tabla_segundo_nivel3, 0x70022800
.equ DIR_FISICA1, 0x70031000
.equ DIR_FISICA2, 0x70030000
.equ DIR_FISICA3, 0x70022000
.equ DIR_FISICA4, 0x70020000
.equ DIR_FISICA5, 0x70010000
.equ DIR_FISICA6, 0x70000000
.equ DIR_FISICA7, GICC0_ADDR
.equ DIR_FISICA8, GICD0_ADDR
.equ DIR_FISICA9, TIMER0_BASE
.equ longitud_tablas, tabla_primer_nivel + 0x10000 - tabla_primer_nivel
@ .equ tabala_dos_segundo_nivel 



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

    @ Se puede hacer como     MSR cpsr_c,#(UND_MODE | I_BIT |F_BIT) - LDR SP,=__und_stack_top__    

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



    @ Inicio paginacion 


    
 

.section .text @ Donde va la aplicacion 
code:
    MOV R10, #0x00

    SWI 0

    MOV R0, #0x04

    SWI 1

    MOV R0, #0x02

@    BL init_timer0


    @ Esto seria con codigo en C
    @ LDR R10, =__gic_init
    @ MOV LR, PC
    @ BX R10

@    BL gic_init


    @ No me funciona el IFDEF, pero se que deberia ser asi 
    @ #ifdef GEN_EXCEPTION
    
    @ .global conditional

    @ conditional:
    @ BL make_inv_exception     @ Llama a función que genera instrucción inválida

    @ @ BL make_mem_exception     @ Llama a función que genera acceso inválido (No funciona sin MMU)
    @ #endif 

@    CPSIE i


// Para probar la paginación, escribir 0x12345678 en la
// dirección física 0x70804564. Luego de la habilitación
// de la MMU, deberíamos leer este valor en la dirección
// 0x80004564.
      LDR R0, =DIR_FISICA1 + 0x4564
      LDR R1, =0x12345678
      STR R1, [R0]

// Borrar las tablas de paginación.
      LDR R1, =tabla_primer_nivel
      LDR R2, =longitud_tablas
      MOV R0, #0
ciclo_borrado:
      STRB R0, [R1], #1
      SUBS R2, #1
      BNE ciclo_borrado

// Inicializar ambas entradas de la tabla de primer nivel.
// Índice 0x700 apunta a tabla de páginas.
      LDR R0, =tabla_primer_nivel + 0x700*4
      // Bits 31-10: BADDR (dirección base tabla nivel 2)
      // 9: No usado
      // 8-5: dominio
      // 4: cero,
      // 3: NS (no seguro),
      // 2: PXN (no ejecución)
      // 1: cero,
      // 0: uno.
      LDR R1, =tabla_segundo_nivel1 + 1
      STR R1, [R0]

      LDR R0, =tabla_primer_nivel + 0x1E0*4
      // Bits 31-10: BADDR (dirección base tabla nivel 2)
      // 9: No usado
      // 8-5: dominio
      // 4: cero,
      // 3: NS (no seguro),
      // 2: PXN (no ejecución)
      // 1: cero,
      // 0: uno.
      LDR R1, =tabla_segundo_nivel2 + 1
      STR R1, [R0]

      LDR R0, =tabla_primer_nivel + 0x100*4
      // Bits 31-10: BADDR (dirección base tabla nivel 2)
      // 9: No usado
      // 8-5: dominio
      // 4: cero,
      // 3: NS (no seguro),
      // 2: PXN (no ejecución)
      // 1: cero,
      // 0: uno.
      LDR R1, =tabla_segundo_nivel3 + 1
      STR R1, [R0]


// Segundo nivel

      LDR R0, =tabla_segundo_nivel1 + 0x31*4
      // Bits 31-12: BADDR (dirección base)
      // 11: nG (no global),
      // 10: S (memoria compartida)
      // 9: AP2 (bits de permisos)
      // 8-6: TEX (atributos de la región de memoria)
      // 5-4: AP1, AP0 (bits de permisos)
      // 3: C (atributos de la región de memoria)
      // 2: B (atributos de la región de memoria)
      // 1: uno
      // 0: XN (la página no se puede ejecutar).
      LDR R1, =DIR_FISICA1 + 0x12
      STR R1, [R0, #0]

      LDR R0, =tabla_segundo_nivel1 + 0x30*4
      // Bits 31-12: BADDR (dirección base)
      // 11: nG (no global),
      // 10: S (memoria compartida)
      // 9: AP2 (bits de permisos)
      // 8-6: TEX (atributos de la región de memoria)
      // 5-4: AP1, AP0 (bits de permisos)
      // 3: C (atributos de la región de memoria)
      // 2: B (atributos de la región de memoria)
      // 1: uno
      // 0: XN (la página no se puede ejecutar).
      LDR R1, =DIR_FISICA2 + 0x12
      STR R1, [R0, #0]

      LDR R0, =tabla_segundo_nivel1 + 0x22*4
      // Bits 31-12: BADDR (dirección base)
      // 11: nG (no global),
      // 10: S (memoria compartida)
      // 9: AP2 (bits de permisos)
      // 8-6: TEX (atributos de la región de memoria)
      // 5-4: AP1, AP0 (bits de permisos)
      // 3: C (atributos de la región de memoria)
      // 2: B (atributos de la región de memoria)
      // 1: uno
      // 0: XN (la página no se puede ejecutar).
      LDR R1, =DIR_FISICA3 + 0x12
      STR R1, [R0, #0]


      LDR R0, =tabla_segundo_nivel1 + 0x20*4
      // Bits 31-12: BADDR (dirección base)
      // 11: nG (no global),
      // 10: S (memoria compartida)
      // 9: AP2 (bits de permisos)
      // 8-6: TEX (atributos de la región de memoria)
      // 5-4: AP1, AP0 (bits de permisos)
      // 3: C (atributos de la región de memoria)
      // 2: B (atributos de la región de memoria)
      // 1: uno
      // 0: XN (la página no se puede ejecutar).
      LDR R1, =DIR_FISICA4 + 0x12
      STR R1, [R0, #0]

      LDR R0, =tabla_segundo_nivel1 + 0x10*4
      // Bits 31-12: BADDR (dirección base)
      // 11: nG (no global),
      // 10: S (memoria compartida)
      // 9: AP2 (bits de permisos)
      // 8-6: TEX (atributos de la región de memoria)
      // 5-4: AP1, AP0 (bits de permisos)
      // 3: C (atributos de la región de memoria)
      // 2: B (atributos de la región de memoria)
      // 1: uno
      // 0: XN (la página no se puede ejecutar).
      LDR R1, =DIR_FISICA5 + 0x12
      STR R1, [R0, #0]


      LDR R0, =tabla_segundo_nivel1 + 0x00*4
      // Bits 31-12: BADDR (dirección base)
      // 11: nG (no global),
      // 10: S (memoria compartida)
      // 9: AP2 (bits de permisos)
      // 8-6: TEX (atributos de la región de memoria)
      // 5-4: AP1, AP0 (bits de permisos)
      // 3: C (atributos de la región de memoria)
      // 2: B (atributos de la región de memoria)
      // 1: uno
      // 0: XN (la página no se puede ejecutar).
      LDR R1, =DIR_FISICA6 + 0x12
      STR R1, [R0, #0]

      LDR R0, =tabla_segundo_nivel2 + 0x00*4
      // Bits 31-12: BADDR (dirección base)
      // 11: nG (no global),
      // 10: S (memoria compartida)
      // 9: AP2 (bits de permisos)
      // 8-6: TEX (atributos de la región de memoria)
      // 5-4: AP1, AP0 (bits de permisos)
      // 3: C (atributos de la región de memoria)
      // 2: B (atributos de la región de memoria)
      // 1: uno
      // 0: XN (la página no se puede ejecutar).
      LDR R1, =DIR_FISICA7 + 0x12
      STR R1, [R0, #0]

      LDR R0, =tabla_segundo_nivel2 + 0x01*4
      // Bits 31-12: BADDR (dirección base)
      // 11: nG (no global),
      // 10: S (memoria compartida)
      // 9: AP2 (bits de permisos)
      // 8-6: TEX (atributos de la región de memoria)
      // 5-4: AP1, AP0 (bits de permisos)
      // 3: C (atributos de la región de memoria)
      // 2: B (atributos de la región de memoria)
      // 1: uno
      // 0: XN (la página no se puede ejecutar).
      LDR R1, =DIR_FISICA8 + 0x12
      STR R1, [R0, #0]

      LDR R0, =tabla_segundo_nivel2 + 0x11*4
      // Bits 31-12: BADDR (dirección base)
      // 11: nG (no global),
      // 10: S (memoria compartida)
      // 9: AP2 (bits de permisos)
      // 8-6: TEX (atributos de la región de memoria)
      // 5-4: AP1, AP0 (bits de permisos)
      // 3: C (atributos de la región de memoria)
      // 2: B (atributos de la región de memoria)
      // 1: uno
      // 0: XN (la página no se puede ejecutar).
      LDR R1, =DIR_FISICA9 + 0x12
      STR R1, [R0, #0]      

    @ Fin inicialización de tablas de paginación

    BL init_vms

    // Habilitar MMU
    MRC p15, 0,R1, c1, c0, 0    // Leer reg. control.
    ORR R1, R1, #0x1            // Bit 0 es habilitación de MMU.
    MCR p15, 0, R1, c1, c0, 0   // Escribir reg. control.    


    MOV R0, #0x02

    BL loop




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

    LDR R0,= tabla_primer_nivel
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


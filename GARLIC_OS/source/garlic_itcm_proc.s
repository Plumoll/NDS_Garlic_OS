@;==============================================================================
@;
@;  by Guillem Frisach Pedrola (guillem.frisach@estudiants.urv.cat/guillemfri@gmail.com)
@;  by Mag’ Tell (magi.tell@estudiants.urv.cat/mtellb@gmail.com)
@;  on 2018, Universitat Rovira i Virgili, Tarragona, Catalunya.
@;
@;	"garlic_itcm_proc.s":	código de las rutinas de control de procesos (2.0)
@;						(ver "garlic_system.h" para descripción de funciones)
@;
@;==============================================================================
.bss 
		.align 2
	_gd_res: .space 4			@; modul per a la RSI del timer 0
	_gd_str: .space 4		@; string per a la RSI del timer 0	
.section .itcm,"ax",%progbits

	.arm
	.align 2
	
	.global _gp_WaitForVBlank
	@; rutina para pausar el procesador mientras no se produzca una interrupción
	@; de retrazado vertical (VBL); es un sustituto de la "swi #5", que evita
	@; la necesidad de cambiar a modo supervisor en los procesos GARLIC
_gp_WaitForVBlank:
	push {r0-r1, lr}
	ldr r0, =__irq_flags
.Lwait_espera:
	mcr p15, 0, lr, c7, c0, 4	@; HALT (suspender hasta nueva interrupción)
	ldr r1, [r0]			@; R1 = [__irq_flags]
	tst r1, #1				@; comprobar flag IRQ_VBL
	beq .Lwait_espera		@; repetir bucle mientras no exista IRQ_VBL
	bic r1, #1
	str r1, [r0]			@; poner a cero el flag IRQ_VBL
	pop {r0-r1, pc}


	.global _gp_IntrMain
	@; Manejador principal de interrupciones del sistema Garlic
_gp_IntrMain:
	mov	r12, #0x4000000
	add	r12, r12, #0x208	@; R12 = base registros de control de interrupciones	
	ldr	r2, [r12, #0x08]	@; R2 = REG_IE (máscara de bits con int. permitidas)
	ldr	r1, [r12, #0x0C]	@; R1 = REG_IF (máscara de bits con int. activas)
	and r1, r1, r2			@; filtrar int. activas con int. permitidas
	ldr	r2, =irqTable
.Lintr_find:				@; buscar manejadores de interrupciones específicos
	ldr r0, [r2, #4]		@; R0 = máscara de int. del manejador indexado
	cmp	r0, #0				@; si máscara = cero, fin de vector de manejadores
	beq	.Lintr_setflags		@; (abandonar bucle de búsqueda de manejador)
	ands r0, r0, r1			@; determinar si el manejador indexado atiende a una
	beq	.Lintr_cont1		@; de las interrupciones activas
	ldr	r3, [r2]			@; R3 = dirección de salto del manejador indexado
	cmp	r3, #0
	beq	.Lintr_ret			@; abandonar si dirección = 0
	mov r2, lr				@; guardar dirección de retorno
	blx	r3					@; invocar el manejador indexado
	mov lr, r2				@; recuperar dirección de retorno
	b .Lintr_ret			@; salir del bucle de búsqueda
.Lintr_cont1:	
	add	r2, r2, #8			@; pasar al siguiente índice del vector de
	b	.Lintr_find			@; manejadores de interrupciones específicas
.Lintr_ret:
	mov r1, r0				@; indica qué interrupción se ha servido
.Lintr_setflags:
	str	r1, [r12, #0x0C]	@; REG_IF = R1 (comunica interrupción servida)
	ldr	r0, =__irq_flags	@; R0 = dirección flags IRQ para gestión IntrWait
	ldr	r3, [r0]
	orr	r3, r3, r1			@; activar el flag correspondiente a la interrupción
	str	r3, [r0]			@; servida (todas si no se ha encontrado el maneja-
							@; dor correspondiente)
	mov	pc,lr				@; retornar al gestor de la excepción IRQ de la BIOS


	.global _gp_rsiVBL
	@; Manejador de interrupciones VBL (Vertical BLank) de Garlic:
	@; se encarga de actualizar los tics, intercambiar procesos, etc.
_gp_rsiVBL:
	push {r4-r7, lr}
	
	ldr r4,=_gd_tickCount 	@;Carregar la direccio de la variable global "Contador de ticks" a r4
	ldr r5,[r4]				@;Carregar el contingut de r4 amb el contador de ticks a r5
	add r5,#1				@;Augmentar el nombre de ticks en 1, (r5+1)
	str r5,[r4]				@;Actualitzem el valor del contador de ticks
	
	bl _gp_actualizarDelay
	
	ldr r4,=_gd_pidz
	ldr r5, [r4]			@;Guardem el valor del PIDZ
	and r5, #0x0000000F		@;N'agafem el socol
	ldr r4, =_gd_pcbs		@;Carreguem la adreça del _gd_pcbs
	mov r6, #6*4			@;Calculem la mida de cada taula (6 ints*4)
	mul r7, r6, r5			@;Calculem l'offset
	add r7, r7, r4
	ldr r4, [r7, #20]		@;Carreguem els workticks
	add r4, #1				@;Augmentem el nombre de workticks en +1
	str r4, [r7, #20]		@;Guardem la variable actualitzada
	
	ldr r4,=_gd_nReady	 	@;Carregar la direccio de la variable global "cua de ready" a r4
	ldr r5, [r4]			@;Carregar el contingut de r4 amb la cua de ready a r5
	cmp r5,#0				@;Mira si hi ha algun proces a READY
	beq .Lfinal_rsi			@;Si es igual a zero es que no hi ha cap proces a la cua esperant
	
	ldr r4,=_gd_pidz		@;Carreguem la direccio de la variable global del PID (28 primers bites PID, 4 ultims bites socol)
	ldr r5,[r4]				@;Carregar el contingut de r4 amb el PID a r5
	cmp r5,#0				@;Mira si es zero (si ho es, es del SO/ Si no ho es, es de l'usuari)
	beq .Lsalvar_context	@;Si es igual a zero, es del SO i fa el salt a salvar el context
	
	
	@;Si arribes aqui es perque no es el SO pero el PID es zero, per tant el proces ha acabat
	@; Per tant passes a restaurar el seguent de la cua de ready
	@; El que farem serà comprovar que tots els 28 bits alts de la variable _gd_pidz estiguin a zero
	@; Per fer-ho farem un tst i després un beq (voldra dir que tots son zero)
	mov r4, #0xfffffff0	
	tst r5,r4				@;Mira si el PID es o no igual a zero
	beq .Lrestaurar_context
	
	
	
.Lsalvar_context:
	
	ldr r4,=_gd_nReady	 	@;Carregar la direccio de la variable global "cua de ready" a r4
	ldr r5,[r4]				@;Carregar el contingut de r4 amb el numero de processos en cua de ready a r5
	ldr r6,=_gd_pidz		@;Carreguem la direccio de la variable global del PID (28 primers bites PID, 4 ultims bites socol)
	bl _gp_salvarProc		@;Cridem a la funcio que salva el context del proces
	str r5, [r4]
	
.Lrestaurar_context:

	ldr r4,=_gd_nReady		@;Carregar la direccio de la variable global "cua de ready" a r4
	ldr r5,[r4]				@;Carregar el contingut de r4 amb el numero de processos en cua de ready a r5
	ldr r6,=_gd_pidz		@;Carregar el contingut de r4 amb el numero de processos en cua de ready a r5
	bl _gp_restaurarProc	@;Cridem a la funcio que restaura el context del proces
.Lfinal_rsi:

	pop {r4-r7, pc}


	@; Rutina para salvar el estado del proceso interrumpido en la entrada
	@; correspondiente del vector _gd_pcbs
	@;Parámetros
	@; R4: dirección _gd_nReady
	@; R5: número de procesos en READY
	@; R6: dirección _gd_pidz
	@;Resultado
	@; R5: nuevo número de procesos en READY (+1)
	
_gp_salvarProc:
push {r8-r11, lr}
	ldr r8, =_gd_qReady 	@;Carregar la direccio de la variable 
	
	ldr r9, [r6]			@;Valor del pid de _gd_pidz (proces actual R6)

	mov r11, #0x80000000
	tst r9, r11
	bne .LnoRDY				@; no guardo en la cola de READY
	
	and r9, #0xf			@;Valor del socol
	
	strb r9, [r8,r5]		@;Socol a la ultima loc qReady
	add r5, #1				@;Augmentem el numero de processos encuats a Ready
	str r5, [r4]
	
.LnoRDY:
	and r9, #0xf			@;Valor del socol

	mov r10,#6*4			@;Posem 24 a r11 perque es el que ocupa cada taula garlicPCB
	ldr r8,=_gd_pcbs		@;Carreguem _gd_pcbs[16]
	mul r10,r9				@;Multipliquem els 24 pel numero de socol per a saber en quina posicio li toca dins de _gd_pcbs[16]
	add r10,r8				@;Sumem el valor de la posicio de _gd_pcbs amb la de l'adreça base de _gd_pcbs
	
	mov r11, sp
	ldr r8,[r11,#60]		@;Prenem el valor de PC, que esta a la sp_irq en l'ultim lloc, la +60
	str r8,[r10,#4]			@;Guardem el PC, a la posicio que li toca del _gd_pcbs +4, ja que es el segon int de la taula
	
	mrs r8, SPSR			@;Carreguem el CPSR ubicat al SPSR del IRQ
	str r8, [r10, #12]		@;Guardem el CPSR, a la posicio que li toca del _gd_pcbs +12, ja que es el quart int de la taula
	
	
	
	@;CANVI D'ESTAT IRQ-->SYSTEM
	mrs r8, CPSR			@;Carreguem a R11 el CPSR
	bic r8,#0x1f			@;Posem a 0 els 5 ultims bits
	orr r8, #0x1f			@;Posem el mode que volem, el sistema (1F)
	msr CPSR, r8			@;Guardem el CPSR amb el seu nou mode
	
	
	push {r14}				@;Salvem R14
	ldr r9,[r11,#56]		@;Carreguem R12
	push {r9}
	ldr r9,[r11,#12]		@;Carreguem R11
	push {r9}
	ldr r9,[r11,#8]			@;Carreguem R10
	push {r9}
	ldr r9,[r11,#4]			@;Carreguem R9
	push {r9}
	ldr r9,[r11]			@;Carreguem R8
	push {r9}
	ldr r9,[r11,#32]		@;Carreguem R7
	push {r9}
	ldr r9,[r11,#28]		@;Carreguem R6
	push {r9}
	ldr r9,[r11,#24]		@;Carreguem R5
	push {r9}
	ldr r9,[r11,#20]		@;Carreguem R4
	push {r9}
	ldr r9,[r11,#52]		@;Carreguem R3
	push {r9}
	ldr r9,[r11,#48]		@;Carreguem R2
	push {r9}
	ldr r9,[r11,#44]		@;Carreguem R1
	push {r9}
	ldr r9,[r11,#40]		@;Carreguem R0
	push {r9}
	
	str r13, [r10, #8]		@; Guardem el SP en el camp del _gd_pcbs.SP
	
	
	
	@;CANVI D'ESTAT SYSTEM-->IRQ
	mrs r11, CPSR			@;Carreguem a R11 el CPSR
	bic r11,#0x1f			@;Posem a 0 els 5 ultims bits
	orr r11, #0x12			@;Posem el mode que volem, el sistema (12)
	msr CPSR, r11			@;Guardem el CPSR amb el seu nou mode
	
	pop {r8-r11, pc}

	@; Rutina para restaurar el estado del siguiente proceso en la cola de READY
	@;Parámetros
	@; R4: dirección _gd_nReady
	@; R5: número de procesos en READY
	@; R6: dirección _gd_pidz
_gp_restaurarProc:
	push {r8-r11, lr}
	
	sub r5,#1				@;Decrementem el numero de processos a la cua de Ready
	str r5, [r4]		@;Guardem a la rsi_vBlank perque aqui no podem accedir a R4
							
	mov r8,r5				@;Gurardem a R11, R5 que es el numero de processos a la cua de Ready despres de restaurar
	
	ldr r9,=_gd_qReady
	ldrb r10,[r9]			@;Numero de socol del proces a restaurar
	
.LdesplacarVector:
	
	cmp r8,#0				@;Comparem centinella amb 0
	beq .Lfi_bucle	@;Si no es igual a zero tornem a fer el bucle. Si ho es, seguim
	
	sub r8,#1				@;Restem 1 al centinella	
	ldrb r11,[r9,#1]		@;Carreguem el numero de socol a moure, posicio actual + 1 offset
	strb r11,[r9]			@;Fem store del socol de la posicio actual+1 offset a la posicio actual
	add r9,#1				@;Actualitzam la posicio actual +1
	b .LdesplacarVector	@;Si no es igual a zero tornem a fer el bucle. Si ho es, seguim
	
.Lfi_bucle:
	ldr r9,=_gd_pcbs		@;Adreça base del _gd_pcbs
	mov r8,#24				@;Posem 24 a r8 perque es el que ocupa cada taula garlicPCB
	mul r8,r10				@;Multipliquem els 24 pel numero de socol per a saber en quina posicio li toca dins de _gd_pcbs[16]
	add r8, r9	
	ldr r11,[r8]			@;A l'adreça base del _gd_pcbs li apliquem un offset, que es la posicio que li toca dins de la taula
							@;Com que el que volem es el PID i esta al primer lloc de la taula es tal qual R11 (sense +4s)
	lsl r11,#4				@;Desplacem el PID dels 28 bits baixos als 28 bits alts 
							@;(0000xxxxxxxxxxxxxxxxxxxxxxxxxxxx --> xxxxxxxxxxxxxxxxxxxxxxxxxxxx0000) i els deixem lliures pel socol
	orr r11,r10				@;Amb la ORR posem el socol als 4 bits baixos i passem a tenir el "pidz"
	str r11,[r6]			@;Guardem el nou valor del pidz a _gd_pidz
	
	
	ldr r11, [r8, #4]		@;Recuperem el valor del PC del proces a restaurar del _gd_pcbs amb la posicio base +4
	str r11, [r13, #60]		@;El copiem a la posicio de la pila IRQ [+60]

	ldr r11, [r8, #12]		@;Recuperem el valor del PC del proces a restaurar del _gd_pcbs amb la posicio base +4
	msr SPSR,r11			@;Guardem el valor en el SPSR
	mov r9, r13				@;Guardem SP(R13) a R8
	
	@;CANVI D'ESTAT IRQ-->SYSTEM
	mrs r11, CPSR			@;Carreguem a R11 el CPSR
	bic r11,#0x1F			@;Posem a 0 els 5 ultims bits
	orr r11, #0x1F			@;Posem el mode que volem, el sistema (1F)
	msr CPSR, r11			@;Guardem el CPSR amb el seu nou mode
	
	ldr r13, [r8, #8 ]
	
	pop {r10}				@;Recuperem R0	
	str r10,[r9,#40]		@;Copiem al lloc corresponent de la pila de la IRQ R0
	pop {r10}				@;Recuperem R0	
	str r10,[r9,#44]		@;Copiem al lloc corresponent de la pila de la IRQ R1
	pop {r10}				@;Recuperem R0	
	str r10,[r9,#48]		@;Copiem al lloc corresponent de la pila de la IRQ R2
	pop {r10}				@;Recuperem R0	
	str r10,[r9,#52]		@;Copiem al lloc corresponent de la pila de la IRQ R3
	pop {r10}				@;Recuperem R0	
	str r10,[r9,#20]		@;Copiem al lloc corresponent de la pila de la IRQ R4
	pop {r10}				@;Recuperem R0	
	str r10,[r9,#24]		@;Copiem al lloc corresponent de la pila de la IRQ R5
	pop {r10}				@;Recuperem R0	
	str r10,[r9,#28]		@;Copiem al lloc corresponent de la pila de la IRQ R6
	pop {r10}				@;Recuperem R0	
	str r10,[r9,#32]		@;Copiem al lloc corresponent de la pila de la IRQ R7
	pop {r10}				@;Recuperem R0	
	str r10,[r9]			@;Copiem al lloc corresponent de la pila de la IRQ R8
	pop {r10}				@;Recuperem R0	
	str r10,[r9,#4]			@;Copiem al lloc corresponent de la pila de la IRQ R9
	pop {r10}				@;Recuperem R0	
	str r10,[r9,#8]			@;Copiem al lloc corresponent de la pila de la IRQ R10
	pop {r10}				@;Recuperem R0	
	str r10,[r9,#12]		@;Copiem al lloc corresponent de la pila de la IRQ R11
	pop {r10}				@;Recuperem R0	
	str r10,[r9,#56]		@;Copiem al lloc corresponent de la pila de la IRQ R12
	pop {lr}				@;Recuperem R14
	
		@;CANVI D'ESTAT SYSTEM-->IRQ
	mrs r11, CPSR			@;Carreguem a R11 el CPSR
	bic r11,#0x1f			@;Posem a 0 els 5 ultims bits
	orr r11, #0x12			@;Posem el mode que volem, el sistema (12)
	msr CPSR, r11			@;Guardem el CPSR amb el seu nou mode

	pop {r8-r11, pc}


	@; Rutina para actualizar la cola de procesos retardados, poniendo en
	@; cola de READY aquellos cuyo número de tics de retardo sea 0
_gp_actualizarDelay:
	push {r0-r10,lr}
	
	
	ldr r0, =_gd_nDelay			@;Carreguem la @ de _gd_nDelay
	ldr r1, [r0]				@;Carreguem el valor de _gd_nDelay
	cmp r1, #0					@;Mirem si es zero, si ho es...
	beq .Lf_ActuDelay			@;...acabem d'acualitzar perque no hi han elements
	
	
	ldr r2,=_gd_qDelay			@;Carreguem la @ de _gd_qDelay
	ldr r4,=_gd_nReady			@;Carreguem la @ de _gd_nReady
	ldr r5,[r4]					@;Carreguem el valor de _gd_nReady
	ldr r6,=_gd_qReady			@;Carreguem la @ de _gd_qReady
	
	mov r3, #0					@;Inicialitzem l'iterador
	
.Li_BucleTicks:					
	cmp r3,r1 					@;Mirem si es igual al nombre de procssos a delay
	bhs .Lf_ActuDelay			@;Si es mes gran, acabem
	
	ldr r7, [r2, r3, lsl #2]	@;Multiplicant per 4 el desplaçament arribem a la posicio que ens marca l'iterador
	sub r7, #1					@;Restem en 1 el nombre de ticks
	ldr r8, =0x0000ffff			@;Carreguem 0x0000ffff a r8 per a fer la mascara
	and r8, r7, r8				@;Prenem els buts baixos (workTicks)
	cmp r8, #0					@;Mirem si es zero
	beq .L_encuarRDY			@;Si ho es ha acabat el temps d'espera i pot passar a RDY		
	str r7, [r2, r3, lsl #2]	@;Si no, guardem el valor altre cop al seu lloc
	b .Lc_keepOnGoing				
	

.L_encuarRDY:
	
	mov r7,r7,lsr #24			@;Agafem el numero de socol de l'element a qDelay
	strb r7, [r6,r5]			@;Ho guardem a qReady amb desplaçament nReady
	add r5, #1					@;Actualitzem el nou valor de la cua de nReady
	str r5, [r4] 				@;Guardem el valor actualitzat
	
	sub r1, #1					@;Guardem el valor a l'ultim lloc de la cua de RDY
	str r1, [r0]				@;Hem restat 1 per que l'element n esta a la posicio n-1
	
	mov r9, r3					@;Guardem la posicio en la que hem trobat l'element expulsat de BLK
	
.Li_reordenarBLK:
	cmp r9, r1					@;Mirem si estem al maxim de procesos a delay
	bhi .Lc_keepOnGoing			@;Si si, acabem la reordenacio i anem al seguent element a delay a veure els workTicks
	add r9, #1					@;Si no, augmentem en 1 l'iterador	
	ldr r10, [r2, r9, lsl #2]	@;Amb el desplacament arribem a l'int que ens interessa i el carreguem
	sub r9, #1					@;Ens movem un lloc enrrera
	str r10, [r2, r9, lsl  #2]	@;Amb el desplacament arribem a l'int que ens interessa i el guardem	
	add r9, #1					@;Avancem una posicio	
	b .Li_reordenarBLK			@;Tornem al principi del bucle
 
 .Lc_keepOnGoing:
	add r3, #1					@;Augmentem en 1 la posicio de qDelay que estem tractant
	b .Li_BucleTicks			@;
	
.Lf_ActuDelay:

	pop {r0-r10,pc}


	.global _gp_numProc
	@;Resultado
	@; R0: número de procesos total
_gp_numProc:
	push {r1-r2, lr}
	mov r0, #1				@; contar siempre 1 proceso en RUN
	ldr r1, =_gd_nReady
	ldr r2, [r1]			@; R2 = número de procesos en cola de READY
	add r0, r2				@; añadir procesos en READY
	ldr r1, =_gd_nDelay
	ldr r2, [r1]			@; R2 = número de procesos en cola de DELAY
	add r0, r2				@; añadir procesos retardados
	pop {r1-r2, pc}


	.global _gp_crearProc
	@; prepara un proceso para ser ejecutado, creando su entorno de ejecución y
	@; colocándolo en la cola de READY
	@;Parámetros
	@; R0: intFunc funcion,
	@; R1: int zocalo,
	@; R2: char *nombre
	@; R3: int arg
	@;Resultado
	@; R0: 0 si no hay problema, >0 si no se puede crear el proceso
_gp_crearProc:
	push {r1-r11, lr}
	
	cmp r1, #0				@;Mirem si el socol es zero
	beq .Lfinal_proc_error	@;Si el socol es zero, finalitzem amb error. En cas contrari, procedim.
	
	mov r4, #6*4			@;Movem a r4 24 que és el que ocupa cada taula de pcbs a la llista de taules pcbs
	ldr r5, =_gd_pcbs		@;Carreguem la posicio de memoria de _gd_pcbs
	mul r6, r4, r1			@;Multipliquem el numero de socol per la mida de cada taula per a saber en quina posicio accedir dins de _gd_pcbs
	add r6, r6, r5			@;Afegim aquest desplaçament a l'adreça base de _gd_pcbs
	ldr r7, [r6]			@;Carreguem el PID
	
	cmp r7, #0				@;Comparem el PID amb zero per tal de saber si esta ocupat o no.
	bne .Lfinal_proc_error	@;Si esta ocupat, acabem amb error. En cas contrari seguim executant.
	
	ldr r5, =_gd_pidCount	@;Carreguem l'adreça del _gd_pidCount
	ldr r4, [r5]			@;Carreguem el valor del _gd_pidCount a r4
	add r4, #1				@;Sumem +1 al valor del _gd_pidCount per tal d'obtenir un nou valor de PID per al nou proces
	
	str r4, [r6]			@;Guardem el PID a la primera posicio del socol. Per aixo no tenim offset.
	str r4, [r5]			@;Actualitzem el valor de _gd_pidCount amb el nou valor de r4
	
	add r0, #4				@;Fem una suma de +4 a r0, que conte la rutina incial ja que quan es restauri per primera vegada sofrira un decrement de -4
	str r0, [r6, #4]		@;Desem aquest valor a PC que, dins del socol esta a la posicio amb offset +4 (2n lloc)
	
	ldr r5, [r2]			@;Carreguem a r5 el nom del programa -> "keyName"
	str r5, [r6, #16]		@;Desem aquest valor al socol corresponent, aquest es la posicio 5 amb offset +16.
	
	ldr r5,=_gd_stacks		@;Carreguem la posicio de memoria a _gd_stacks
	mov r7, #128*4			@;Cada taula dins de _gd_stacks ocupa 128 bits, i n'hi han cuatre, per tant en total s'ocupa 128*4=512
	mul r8, r7, r1			@;Multipliquem el numero de socol per la mida de cada taula
	add r8, r8, r5			@;I al resultat li sumem l'adreça base de _gd_stacks.
	
	sub r8, #4				@;Disminuim aquest valor per tal de posar-nos al top de la pila del socol+1
	
	ldr r7, =_gp_terminarProc	@;Carreguem la direccio de memoria de _gp_terminarProc
	str r7, [r8]			@;Guardem al final de la pila (al cul) la direccio de _gp_terminarProc
	
	mov r10, #0				@;Centinella del bucle			
	mov r11, #0				@;Registre que omplim en zero per tal d'escriure'l a r1-r12
	
.Lposar_zeros_inici:		@;Bucle per tal de colocar zero en els registres del r1 al r12
	sub r8, #4				@;Ens movem per la pila
	str r11, [r8]			@;Desem un zero a la posició actualitzada de la pila
	add r10, #1				@;Afegim +1 al centinella
	cmp r10, #12			@;Mirem si el centinella es correspon al nombre max. d'iteracions que hem de fer
	bhs .Lposar_zeros_fi	@;Si es igual o superior, acabem el "posar zeros"
	b .Lposar_zeros_inici	@;Si no, seguim posant zero als registres restants
	
.Lposar_zeros_fi:
	sub r8, #4				@;Ens movem per la pila un lloc
	str r3, [r8]			@;Hi posem el valor de r0 que es la funcio, aquesta sera al TOP
	str r8, [r6, #8]		@;Guardem al socol i a la posicio que li correspon (SP) el valor del top de la pila
	
	
	mov r5, #0x1f			@;Guardem a r5 0x1f que es el valor que ha de prendre el CPRS per tal d'entrar en mode SYS
	str r5, [r6, #12]		@;Preparem el camp status per a entrar en mode SYS
	
	mov r5, #0				@;Guardem a r5 un zero
	str r5, [r6, #20]		@;Aquest valor zero a r5 ens permet incialitzar la variable que ens queda per inicialitzar, el workTicks
							@;i la guardem a l'ultim lloc del socol amb un offset de +20
	bl _gp_inhibirIRQs
	
	ldr r9, =_gd_nReady		@;Carreguem la direcció de _gd_nReady
	ldr r4, [r9]			@;Carreguem el valor de _gd_nReady
	ldr r5, =_gd_qReady		@;Carreguem la direcció de _gd_qReady
	strb r1, [r5, r4]		@;Desem el numero de socol a la ultima posicio de la cua de ready, ja que fem @base + n. de socols
	
	add r4, #1				@;Incrementem en +1 el numero de processos a ready.
	str r4, [r9]			@;Actualitzem el valor dels processos a la cua _gd_qReady
	
	bl _gp_desinhibirIRQs
	
	mov r0, #0				@;En cas de no haver error, retornem 0 a r0
	b .Lfinal_proc_creat	@;Saltem al final de la rutina
	
.Lfinal_proc_error:
	mov r0, #1				@;En cas d'haver error, retornem 1 a r0
	
.Lfinal_proc_creat:
	
	pop {r1-r11, pc}


	@; Rutina para terminar un proceso de usuario:
	@; pone a 0 el campo PID del PCB del zócalo actual, para indicar que esa
	@; entrada del vector _gd_pcbs está libre; también pone a 0 el PID de la
	@; variable _gd_pidz (sin modificar el número de zócalo), para que el código
	@; de multiplexación de procesos no salve el estado del proceso terminado.
_gp_terminarProc:
	ldr r0, =_gd_pidz
	ldr r1, [r0]			@; R1 = valor actual de PID + zócalo
	and r1, r1, #0xf		@; R1 = zócalo del proceso desbancado
	bl _gp_inhibirIRQs
	str r1, [r0]			@; guardar zócalo con PID = 0, para no salvar estado			
	ldr r2, =_gd_pcbs
	mov r10, #24
	mul r11, r1, r10
	add r2, r11				@; R2 = dirección base _gd_pcbs[zocalo]
	mov r3, #0
	str r3, [r2]			@; pone a 0 el campo PID del PCB del proceso
	str r3, [r2, #20]		@; borrar porcentaje de USO de la CPU
	ldr r0, =_gd_sincMain
	ldr r2, [r0]			@; R2 = valor actual de la variable de sincronismo
	mov r3, #1
	mov r3, r3, lsl r1		@; R3 = máscara con bit correspondiente al zócalo
	orr r2, r3
	str r2, [r0]			@; actualizar variable de sincronismo
	bl _gp_desinhibirIRQs
.LterminarProc_inf:
	bl _gp_WaitForVBlank	@; pausar procesador
	b .LterminarProc_inf	@; hasta asegurar el cambio de contexto


	.global _gp_matarProc
	@; Rutina para destruir un proceso de usuario:
	@; borra el PID del PCB del zócalo referenciado por parámetro, para indicar
	@; que esa entrada del vector _gd_pcbs está libre; elimina el índice de
	@; zócalo de la cola de READY o de la cola de DELAY, esté donde esté;
	@; Parámetros:
	@;	R0:	zócalo del proceso a matar (entre 1 y 15).
_gp_matarProc:

	push {r1-r6,lr} 
	
	bl _gp_inhibirIRQs			@;Desactivem les interrupcions
	ldr r1, =_gd_pcbs			@;Carreguem la @ de _gd_pcbs
	mov r2, #6*4				@;Calculem la mida de les taules del pcbs que son 6 ints * 4
	mul r2, r0, r2				@;Calculem l'offset a aplicar
	
	mov r3, #0					@;Guardem un zero a r3 que ens servira per subtituir el PID
	str r3,[r1, r2]				@;Posem el PID a zero indicant que ha acabat
	
	ldr r1, =_gd_qReady			@;Carreguem la @ de _gd_qReady
	ldr r2, =_gd_nReady			@;Carreguem la @ de _gd_nReady
	ldr r3, [r2]				@;Carreguem el valor de _gd_nReady
	cmp r3, #0					@;Mirem si es zero, aixo voldra dir que no tenim elements a ready
	beq .Li_cercaDelayPrep		@;Si no en tenim passem a buscar a blocked
	mov r4, #0					@;En cas contrari iniciem l'iterador a 0
	
.Li_cercaReady:
	cmp r4, r3 					@;Mirem si l'iterador es igual al nombre de processos
	bhs .Li_cercaDelayPrep		@;Si es mes gran, hem acabat a RDY busquem a BLK
	
	ldrb r5, [r1, r4]			@;Carreguem el socol
	cmp r5,r0					@;Mirem si el socol es igual al que busquem
	beq .Lf_cercaReady			@;Si ho es, acabem la cerca passem a reordenacio
	add r4, #1					@;Si no, iterador+1
	b .Li_cercaReady			

.Li_cercaDelayPrep:				@;Preparem els parametres per a la cerca a delay

	ldr r1, =_gd_qDelay			@;Carreguem la @ de _gd_qDelay
	ldr r2, =_gd_nDelay			@;Carreguem la @ de _gd_nDelay
	ldr r3, [r2]				@;Carreguem el valor de _gd_nDelay
	cmp r3, #0 					@;Mirem si es zero, aixo voldra dir que no tenim elements a delay
	beq .Lfinal					@;Si no en tenim, acabem
	mov r4, #0					@;En cas contrari iniciem l'iterador a 0
	
.Li_cercaDelay:
	cmp r4, r3 					@;Mirem si l'iterador es igual al nombre de processos
	bhs .Lfinal					@;Si es mes gran, hem acabat a BLK, acabem les cerques
	ldr r5, [r1, r4, lsl #2]	@;Carreguem el valor dels elements a delay
	mov r5, r5, lsr	#24			@;Agafem els bits alts que es on esta contingut el socol
	cmp r5, r0					@;Mirem si el socol es igual al que busquem
	beq .Lf_cercaDelay			@;Si ho es anem a reordenar la cua de BLK
	add r4, #1					@;Si no, afegim +1 a les iteracions
	b .Li_cercaDelay			
	
.Lf_cercaReady:
	sub r3, #1					@;Reduim el nombre de procesos ara per tal de no passarnos de llarg
	str r3,[r2]					@;Guardem el nou valor
	
.Lf_reordenarReady:

	add r5, r4, #1				@;Guardem a r5, el valor del lloc on hem trobat el socol +1	
	
	ldrb r6, [r1, r5]			@;Carreguem el valor de la cua de RDY on hem trobat el socol +1	
	strb r6, [r1, r4]			@;Guardem el valor de la cua de RDY on hem trobat el socol +1 a la posicio anterior
	add r4, #1					@;Sumem 1 per avancar per la cua	
	cmp r4, r3					@;Mirem que no haguem assolit el maxim
	blo .Lf_reordenarReady		@;Si es mes petit, seguim reordenant
		
	b .Lfinal					@;Si no, finalitzem
	
.Lf_cercaDelay:
	sub r3, #1					@;Reduim el nombre de procesos ara per tal de no passarnos de llarg
	str r3,[r2]					@;Guardem el nou valor
	
.Lf_reordenarDelay:
	add r5, r4, #1				@;Guardem a r5, el valor del lloc on hem trobat el socol +1	
	
	ldr r6, [r1, r5, lsl #2]	@;Carreguem el valor de la cua de RDY on hem trobat el socol +1	i hi apliquem el lsl per que son ints
	str r6, [r1, r4, lsl #2]	@;Guardem el valor de la cua de RDY on hem trobat el socol +1 a la posicio anterior	i hi apliquem el lsl per que son ints
	add r4, #1					@;Sumem 1 per avancar per la cua
	cmp r4, r3					@;Mirem que no haguem assolit el maxim
	blo .Lf_reordenarDelay		@;Si es mes petit, seguim reordenant
		
	b .Lfinal					@;Si no, finalitzem
	
.Lfinal:

	bl _gp_desinhibirIRQs		@;Reactivem les interrupcions
	pop {r1-r6,pc}

	
	.global _gp_retardarProc
	@; retarda la ejecución de un proceso durante cierto número de segundos,
	@; colocándolo en la cola de DELAY
	@;Parámetros
	@; R0: int nsec
_gp_retardarProc:
	push {r1-r5,lr}
	
	mov r1, #60					@;La frequencia del processador es 60Hz
	mul r2, r0, r1				@;Multipliquem la frequencia pel numero de segons que volem fer el delay i obtenim el n de ticks
	
	ldr r1 ,=_gd_pidz			@;Carreguem @pidz a r1
	ldr r3, [r1]				@;Carreguem el valor de pdiz a r3
	orr r3, r3, #0x80000000		@;Posem el bit mes alt a 1
	str r3, [r1]				@;Guardem el nou valor
	
	and r1, r3, #0xf			@;Obtenim el socol que es troba als 4 bits de menys pes
	mov r1, r1, lsl #24			@;Movem el socol als bits alts
	@;add r1, r1, r2				@;Hi afegim als bits de menys pes, el numero de ticks a realitzar
	Orr r1, r1, r2
	
	bl _gp_inhibirIRQs
	
	
	ldr r2, =_gd_nDelay			@;Carreguem la @ de nDelay a r2
	ldr r3, [r2]				@;Nombre d'elements a la cua de BLK a r3
	ldr r4, =_gd_qDelay			@;Carreguem la @ de la qDelay que es la cua de BLK
	mov r5, #4					@;Guardem a r5 4, ja que es el que ocupa un int, aixi podrem calcular l'offset
	mul r5, r3, r5				@;Calculem l'offset de la cua BLK (nelem * midaelem)
	str r1, [r4,r5]				@;Guardem a l'ultim lloc de la cua l'element que hem generat
	add r3, #1					@;Augmentem en +1 el nombre d'elements a BLK
	str r3, [r2]				@;Guardem el valor actualitzat
	bl _gp_desinhibirIRQs		
		
	bl _gp_WaitForVBlank		@;Forcem a que es cedeixi la cpu

	pop {r1-r5, pc}


	.global _gp_inihibirIRQs
	@; pone el bit IME (Interrupt Master Enable) a 0, para inhibir todas
	@; las IRQs y evitar así posibles problemas debidos al cambio de contexto
_gp_inhibirIRQs:
	push {r0-r1,lr}
	ldr r0, =0x04000208			@;Carreguem la @ de l'IME
	ldrh r1, [r0]				@;Carreguem els 16 bits baixos del registre
	bic r1, #0x1				@;Posem l'ultim bit a zero, desactivant aixi les interrupcions
	strh r1, [r0]				@;Actualitzem el valor
	pop {r0-r1,pc}



	.global _gp_desinihibirIRQs
	@; pone el bit IME (Interrupt Master Enable) a 1, para desinhibir todas
	@; las IRQs
_gp_desinhibirIRQs:
	push {r0-r1,lr}
	ldr r0, =0x04000208			@;Carreguem la @ de l'IME
	ldrh r1, [r0]				@;Carreguem els 16 bits baixos del registre
	orr r1, #0x1				@;Posem l'ultim bit a u, activant aixi les interrupcions
	strh r1, [r0]				@;Guardem de nou el valor

	pop {r0-r1,pc}


	.global _gp_rsiTIMER0
	@; Rutina de Servicio de Interrupción (RSI) para contabilizar los tics
	@; de trabajo de cada proceso: suma los tics de todos los procesos y calcula
	@; el porcentaje de uso de la CPU, que se guarda en los 8 bits altos de la
	@; entrada _gd_pcbs[z].workTicks de cada proceso (z) y, si el procesador
	@; gráfico secundario está correctamente configurado, se imprime en la
	@; columna correspondiente de la tabla de procesos.
	
	@;_gs_escribirStringSub => r0:str, r1:fila, r2:col, r3:color
	@;_ga_divmod => r0: num, r1: denom, r2: quocient, r3:residu
	@;_gs_num2str_dec => r0:str, r1:mida, r2:elem
_gp_rsiTIMER0:

push {r0-r11, lr}
		
		ldr r4, =_gd_pcbs 		@;Carreguem la @ de _gd_pcbs
		mov r5, #6*4 			@;La mida de cada element de la taula pcbs
		ldr r1, [r4, #20] 		@;Carreguem el valor de workTicks del Sistema Operatiu
		and r1, #0x00ffffff 	@;Total de ticks
		mov r6, #1 				@;Situem 1 que es el que ens fara de marca del iterador (socol)
	
	.Li_bucleContaTicks:
		mul r7, r6, r5			@;Calculem el valor de l'offset de cada iteracio
		add r7, r7, r4
		ldr r8, [r7] 			@;Carreguem el pidz de l'offset que toca
		cmp r8, #0 				@;Mira si esta en us o el socol esta lliure
		beq .Li_segContaTicks	@;En cas de que si, avancem un socol
		ldr r9, [r7, #20] 		@;Carreguem el camp "workTicks" que te un offset de +20 dins del pcb del socol
		and r9, #0x00ffffff 	@;Agafem els 24 bits baixos (8 bits alts %CPU, 24 bits baixos workTicks)
		add r1, r9  			@;workTicks totals + els del SO
	
	.Li_segContaTicks:
		add r6, #1				@;Augmentem en +1 el socol (iterador)
		cmp r6, #15				@;Mirem si estem al maxim de processos possibles
		ble .Li_bucleContaTicks 			
		
		mov r11, #100 			@;Marca que ens servira de percentatge
		
		ldr r0, [r4, #20] 		@;workTicks del sistema operatiu
		and r0, #0x00ffffff 	@;24 bits baixos del sistema operatiu
		mul r0, r11		
		add r2, r4, #20 		@;@ dels workticks del sistema operatiu
		ldr r3, =_gd_res 		@;Carreguem la @ de la variable global res
		bl _ga_divmod			@;Executem la funcio divmod
		mov r6, #0 				@;Reiniciem l'iterador per al nou bucle
		mov r10, r1 			@;Sumem el total de workTicks
		b .Li_buclePercent		@;Saltem un cop calculats els workTicks a calcular els percentatges
		
	.Li_calculaTicks:
		mul r7, r5, r6			@;Calculem el valor de l'offset de cada iteracio
		add r7, r7, r4
		ldr r8, [r7] 			@;Carreguem el pidz de l'offset que toca
		cmp r8, #0 				@;Mira si esta en us o el socol esta lliure
		beq .Li_segCalculaTicks	@;En cas de que si, avancem un socol
		ldr r0, [r7, #20] 		@;Carreguem els workTicks del socol en iteracio
		and r0, #0x00ffffff 	@;Agafem els 24 bits baixos dels workTicks
		mul r0, r11 			@;Ho multipliquem per 100 per tal de poder dividir
		mov r1, r10 			@;Afegim els owrkticks al total
		add r2, r7, #20 		@;Passem la @ dels workticks del sistema operatiu pq es guardi automaticament
		ldr r3, =_gd_res 		@;El residu l'enmgatzemem a la variable global
		bl _ga_divmod 			@;Executem la funcio divmod
		
	.Li_buclePercent:
		ldr r0, =_gd_str 		@;Carreguem la @ de la variable global
		mov r1, #4 				@;4 que es la llargada d'un int
		ldr r3, [r2]			@;Agafem el percentatge d'us de la cpu
		mov r7, r3, lsl #24 	@;El movem als 8 bits alts
		str r7, [r2] 			@;Guardem el valor al camp workTicks
		mov r2, r3 				
		bl _gs_num2str_dec
		ldr r0, =_gd_str 		@;Assignem la variable d'string a r0
		add r1, r6, #4 			@;La fila en que volem escriure
		mov r2, #28				@;Situem la columna a escriure
		mov r3, #0				@;El color que volem a r3
		bl _gs_escribirStringSub
		
	.Li_segCalculaTicks:
		add r6, #1
		cmp r6, #15
		ble .Li_calculaTicks 	
		
		ldr r0, =_gd_sincMain	@;Carreguem la @_gd_sincMain
		ldr r1, [r0]			@;Carreguem el valor de _gd_sincMain
		orr r1, #1				@;Posem el bit baix a 1
		str r1, [r0]			@;Guardem el valor
	pop {r0-r11, pc}

	
.end
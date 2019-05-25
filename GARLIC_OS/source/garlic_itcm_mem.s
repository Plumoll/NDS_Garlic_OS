@;==============================================================================
@;
@;  by Guillem Frisach Pedrola (guillem.frisach@estudiants.urv.cat/guillemfri@gmail.com)
@;  by Magí Tell (magi.tell@estudiants.urv.cat/mtellb@gmail.com)
@;  on 2018, Universitat Rovira i Virgili, Tarragona, Catalunya.
@;
@;	"garlic_itcm_mem.s":	código de rutinas de soporte a la carga de
@;							programas en memoria (version 2.0)
@;
@;==============================================================================

NUM_FRANJAS = 768
INI_MEM_PROC = 0x01002000
MAX_COL = 32
COL_BARRA = 23
COL_LLETRA = 26


.section .dtcm,"wa",%progbits
	.align 2

	.global _gm_zocMem
_gm_zocMem:	.space NUM_FRANJAS			@; vector de ocupación de franjas mem.
quo: .space 4
res: .space 4



.section .itcm,"ax",%progbits

	.arm
	.align 2


	.global _gm_reubicar
	@; Rutina de soporte a _gm_cargarPrograma(), que interpreta los 'relocs'
	@; de un fichero ELF, contenido en un buffer *fileBuf, y ajustar las
	@; direcciones de memoria correspondientes a las referencias de tipo
	@; R_ARM_ABS32, a partir de las direcciones de memoria destino de código
	@; (dest_code) y datos (dest_data), y según el valor de las direcciones de
	@; las referencias a reubicar y de las direcciones de inicio de los
	@; segmentos de código (pAddr_code) y datos (pAddr_data)
	@;Parámetros:
	@; R0: dirección inicial del buffer de fichero (char *fileBuf)
	@; R1: dirección de inicio de segmento de código (unsigned int pAddr_code)
	@; R2: dirección de destino en la memoria (unsigned int *dest_code)
	@; R3: dirección de inicio de segmento de datos (unsigned int pAddr_data)
	@; (pila): dirección de destino en la memoria (unsigned int *dest_data)
	@;Resultado:
	@; cambio de las direcciones de memoria que se tienen que ajustar
_gm_reubicar:
	push {r0-r12, lr}
		
		@; Agafar direcció de destí en la memòria
		ldr r4, [r13,#56]		@; 13*4
		
		@; Carregar addreça de la taula de seccions
		ldr r5, [r0, #32]	@; Carreguem l'offset de la taula de seccions (4 bytes)
		add r5, r0, r5 		@; Direcció base + offset = direcció taula de seccions
		
		@; Carregar mida de seccions
		ldrh r6, [r0, #46]	@; Carreguem 2 bytes
		
		@; Carregar número de seccions
		ldrh r7, [r0, #48]	@; Carreguem 2 bytes
		
		
	.Linici_seccio:	
		cmp r7, #0			@; Si el número de seccions és 0
		beq .Lfi			@; ja hem acabat
		
		@; Mirar tipus de secció que és
		ldr r8, [r5, #4]	@; Carreguem 4 bytes
		
		cmp r8, #9
		beq .Lseccio_rel
		
		sub r7, r7, #1		@; Restem el número de seccions restants
		add r5, r5, r6		@; Ens col·loquem a la següent secció

		b .Linici_seccio
		
		
		@; Secció del tipus REL
	.Lseccio_rel:
		@; Agafar la mida de secció
		ldr r9, [r5, #20]	@; Carreguem 4 bytes
		
		@; Agafar offset secció
		ldr r10, [r5, #16]	@; Carreguem 4 bytes
		add r10, r0			@; Ens col·loquem a l'adreça de la secció
		
		sub r7, r7, #1
		add r5, r5, r6
		
		
		@; Estem dins a un reubicador
	.Linici:
		cmp r9, #0			@; Anem restant fins que la mida de la secció és 0
		beq .Linici_seccio	@; Ja no queden mes reubicadors
		
		@; Agafar adreça sobre la que sd'ha d'aplicar la reubicació	
		ldr r11, [r10]		@; Com l'adreça es trobra a partir del byte 0, no cal afegir desplaçament (add r11, r11, #0)
		
		@; Agafar informació reubicador
		ldr r8, [r10, #4]	@; Carreguem 4 bytes
		and r8, #0xFF 		@; Agafar 8 bits baixos
		
		cmp r8, #2
		beq .LR_ARM_ABS32
		
		sub r9, r9, #8		@; Restem el número de reubicadors restants
		add r10, r10, #8	@; Ens col·loquem al següent reubicador
		
		b .Linici
		
		
		@; Estem a un reubicador del tipus LR_ARM_ABS32
	.LR_ARM_ABS32:
		sub r9, r9, #8		@; Restem el número de reubicadors restants
		add r10, r10, #8	@; Ens col·loquem al següent reubicador
		
		
		@; Aplicar la reubicació
		sub r11, r1			@; Restem la direcció d'inici de segment
		add r11, r2			@; Sumem la direcció de destí en la memòria
		
		ldr r8, [r11]		@; Carreguem el contingut
		
		cmp r3, #0			@; Si no hi ha segment de dades
		beq .Lsegment_codi	@; és un segment de codi
		
		cmp r8, r3			@; Comprovem si està al segment de codi o de dades
		blo .Lsegment_codi	@; Si és més menut que l'inici de segment de dades, és del segment de codi
		
		
		@; Segment de dades
		sub r8, r3			@; Restem la direcció d'inici de segment
		add r8, r4			@; Sumem la direcció de destí en la memòria
		str r8, [r11]		@; Guardem el nou valor
		b .Linici
		
		
		@; Segment de codi
	.Lsegment_codi:
		sub r8, r1			@; Restem la direcció d'inici de segment
		add r8, r2			@; Sumem la direcció de destí en la memòria
		str r8, [r11]		@; Guardem el nou valor
		b .Linici
		
	.Lfi:
		
	pop {r0-r12, pc}


	.global _gm_reservarMem
	@; Rutina para reservar un conjunto de franjas de memoria libres
	@; consecutivas que proporcionen un espacio suficiente para albergar
	@; el tamaño de un segmento de código o datos del proceso (según indique
	@; tipo_seg), asignado al número de zócalo que se pasa por parámetro;
	@; también se encargará de invocar a la rutina _gm_pintarFranjas(), para
	@; representar gráficamente la ocupación de la memoria de procesos;
	@; la rutina devuelve la primera dirección del espacio reservado; 
	@; en el caso de que no quede un espacio de memoria consecutivo del
	@; tamaño requerido, devuelve cero.
	@;Parámetros:
	@;	R0: el número de zócalo que reserva la memoria
	@;	R1: el tamaño en bytes que se quiere reservar
	@;	R2: el tipo de segmento reservado (0 -> código, 1 -> datos)
	@;Resultado:
	@;	R0: dirección inicial de memoria reservada (0 si no es posible)
_gm_reservarMem:
	push {r1-r12, lr}

	@; Càlcul del número de franges que haurem de reservar
		@; Guardem r0 i r2 per despres
		mov r4, r0
		mov r5, r2

		mov r0, r1		@;r0 = num
		mov r1, #32		@;r1 = den
		ldr r2, =quo	@;r2 = quo
		ldr r3, =res	@;r3 = mod
		bl _ga_divmod	@;cridar la funcio _ga_divmod

		mov r0, r4		@;restaurar r0
		ldr r4, [r2]	@;r4 = quo
		mov r2, r5		@;restaurar r2
		ldr r5, [r3]	@;r5 = residu
		cmp r5, #0		@;si hi ha algu de residu (si la divisio no es perfecte)
		beq .LcomprovacioEspaisLliures
		add r4, #1		@;nFranges + 1
		
	.LcomprovacioEspaisLliures:
		ldr r5, =_gm_zocMem		@; Vector de zócalos		
		mov r6, #0				@; Número de franges analitzades
		mov r7, #0				@; Número de franges seguides lliures
		mov r11, r4				@; Número de franges a pintar
		
	.Lseguent_posicio:
		cmp r6, #NUM_FRANJAS	@; Comprovem si hem recorregut totes les franges
		beq .Lno_espai			@; Hem acabat i no hem trobat cap espai
		
		ldrb r8, [r5]
		cmp r8, #0				@; Comprovem si aquell espai està lliure
		bne .Lespai_no_lliure
		
		cmp r7, #0				@; Si és la primera posició que està lliure (l'anterior no ho estava)
		bne .Lespai_lliure		@; Si no ho és continuem amb normalitat
		mov r9, r5				@; Agafem la posició (primera posició lliure)
		mov r10, r6				@; Backup de la posició del vector per al càlcul final de la direcció
		
		
		@; Si està lliure
	.Lespai_lliure:
		add r7, #1				@; Incrementem el contador de franges lliures
		cmp r7, r4				@; Comprovem si ja tenim les franges que necessitàvem
		beq .Lreservar_espai
		
		add r5, #1				@; Avancem a la següent posició
		add r6, #1
		b .Lseguent_posicio
		
		
		@; Si no està lliure
	.Lespai_no_lliure:
		mov r7, #0				@; Reiniciem el contador de franges lliures
		add r5, #1				@; Avancem a la següent posició
		add r6, #1
		b .Lseguent_posicio
		
		
		@; Tenim l'espai que necessitàvem, reservem
	.Lreservar_espai:
		strb r0, [r9]			@; Col·loquem el número de zócalo
		add r9, #1				@; Avancem a la següent posició
		sub r4, #1				@; Restem 1 posició a les que necessitem
		cmp r4, #0				@; Si ja tenim les posicions que necessitàvem
		bhi .Lreservar_espai	@; Continuem reservant si encara queden posicions
		
		
		@; Crida a la funció de pintar franges
		mov r3, r2				@; Tipo de segment reservat
		mov r2, r11				@; Número de franges a pintar
		mov r1, r10
		bl _gm_pintarFranjas
		
		ldr r0, =INI_MEM_PROC	@; Preparem la primera direcció de memòria a partir d'on es calcularà la direcció de retorn
		mov r12, #0				@; Contador de franges
		
		
		@; Càlcul de la direcció de memòria a retornar
	.Lcalcul_direccio:

		lsl r10, #5
		add r0, r10
		b .LfiReservar
		
		
		@; No hem trobat cap espai lliure
	.Lno_espai:
		mov r0, #0				@; Retornem 0 si no hi ha espai
		
	.LfiReservar:
		
	pop {r1-r12, pc}



	.global _gm_liberarMem
	@; Rutina para liberar todas las franjas de memoria asignadas al proceso
	@; del zócalo indicado por parámetro; también se encargará de invocar a la
	@; rutina _gm_pintarFranjas(), para actualizar la representación gráfica
	@; de la ocupación de la memoria de procesos.
	@;Parámetros:
	@;	R0: el número de zócalo que libera la memoria
_gm_liberarMem:
	push {r0-r6, lr}

		ldr r4, =_gm_zocMem		@; Vector de zócalos
		
		mov r6, r0				@; Número de zócalo que volem alliberar
		
		mov r0, #0				@; Nou número de zócalo (0 per alliberar)
		mov r1, #0				@; Índex inicial de les franges
		mov r2, #0				@; Número de franges borrades
		mov r3, #0				@; Tipo de segment (0 per defecte)
		
	.Lseguent_posicio2:
		ldrb r5, [r4]
		cmp r5, r6				@; Sí el contingut d'aquest espai és igual al número de zócalo
		bne .Laugmentar_posicio
		add r2, #1				@; Franges a borrar+1
		@; Borrar
		strb r0, [r4]			@; Fiquem un 0 per marcar la posició lliure
		
	.Laugmentar_posicio:
		cmp r2, #0
		beq .Lfi_Treure_Pintat
		bl _gm_pintarFranjas	@; Esborrem les franjes pintades
		mov r2, #0

	.Lfi_Treure_Pintat:
		add r4, #1				@; Avancem a la següent posició
		add r1, #1				@; Augmentem una posició
		cmp r1, #NUM_FRANJAS	@; Sí no hem acabat de recorrer
		bne .Lseguent_posicio2
		
	pop {r0-r6, pc}



	.global _gm_pintarFranjas
	@; Rutina para para pintar las franjas verticales correspondientes a un
	@; conjunto de franjas consecutivas de memoria asignadas a un segmento
	@; (de código o datos) del zócalo indicado por parámetro.
	@;Parámetros:
	@;	R0: el número de zócalo que reserva la memoria (0 para borrar)
	@;	R1: el índice inicial de las franjas
	@;	R2: el número de franjas a pintar
	@;	R3: el tipo de segmento reservado (0 -> código, 1 -> datos)
_gm_pintarFranjas:
	_gm_pintarFranjas:
	push {r0-r11, lr}
		
		@; Adreça base baldoses
		mov r4, #0x06200000
		add r4, #0xC000
		add r4, #16				@; Primer píxel a pintar
		
		@; Triar color
		ldr r5, =_gs_colZoc		@; Carreguem vector de colors
		mov r6, r0				@; R6 = Índex auxiliar del vector color
		
		.Ltriar_color:
		cmp r6, #0
		beq .Lcarregar_color
		
		add r5, #1				@; Avancem una posició dins del vector de colors
		sub r6, #1				@; Queda una posició menys per a recorrer dins del vector
		b .Ltriar_color
		
	.Lcarregar_color:
		ldrb r5, [r5]			@; Carreguem el color
		
		mov r10, r1				@; R10 = Índex de franja inicial
		
		@; Ens col·loquem a la baldosa inicial
	.Lbaldosa_inicial:
		cmp r10, #8				@; Si l'índex de la franja és igual o major que 8, ens hem de desplaçar per les baldoses
		blo .Lpintar
		
		add r4, #64				@; Avancem una baldosa (64 Bytes)
		sub r10, #8				@; Restem 8 franges per cada baldosa que avancem
		b .Lbaldosa_inicial
		
		
		@; Procedim a pintar les franges
	.Lpintar:
		add r4, r10				@; Sumem columna inicial
		mov r6, #0				@; R6 = Franjes pintades
		
	.LpintarFranja:
		cmp r6, r2				@; Si no queden franges per a pintar
		beq .LfiPintar
		
		cmp r3, #0				@; Comprovem si pintem segment de codi o de dades
		bne .LpintarPixelsEscacs
		
		@; Pintar de manera normal, tots els píxels uniformement
	.LpintarPixelsNormal:
		and r11, r10, #1		@; Comprovem si estem a una franja parell o imparell
		cmp r11, #1
		bne .LfranjaParellNormal
		
		@; .LfranjaImparellNormal:
		ldrh r8, [r4]			@; Procés per a pintar sense esborrar les dades dels costats
		and r8, #0xff
		lsl r9, r5, #8			@; Els bits baixos són del píxel que ja hi havia (esquerra)
		add r7, r9, r8			@; i els alts són de l'actual (dreta)
		strh r7, [r4]			@; Pintem la franja (4 píxels)
		strh r7, [r4, #8]
		strh r7, [r4, #16]
		strh r7, [r4, #24]
		b .LseguentFranja
		
	.LfranjaParellNormal:
		ldrh r8, [r4]			@; Procés per a pintar sense esborrar les dades dels costats
		and r8, #0xff00			@; Els bits alts són del píxel que ja hi havia (dreta)
		add r7, r5, r8			@; i els baixos són de l'actual (esquerra)
		strh r7, [r4]			@; Pintem la franja (4 píxels)
		strh r7, [r4, #8]
		strh r7, [r4, #16]
		strh r7, [r4, #24]
		b .LseguentFranja
		
		@; Pintar les franges amb un patró "d'escacs"
	.LpintarPixelsEscacs:
		and r11, r10, #1		@; Comprovem si estem a una franja parell o imparell
		cmp r11, #1
		bne .LfranjaParellEscacs
		
		@; .LfranjaImparellEscacs:
		ldrh r8, [r4, #8]		@; Procés per a pintar sense esborrar les dades dels costats
		and r8, #0xff
		lsl r9, r5, #8			@; Els bits baixos són del píxel que ja hi havia (esquerra)
		add r7, r9, r8			@; i els alts són de l'actual (dreta)
		strh r7, [r4, #8]		@; Pintem la franja (Píxels 1 i 3)
		strh r7, [r4, #24]
		b .LseguentFranja
		
	.LfranjaParellEscacs:
		ldrh r8, [r4]			@; Procés per a pintar sense esborrar les dades dels costats
		and r8, #0xff00			@; Els bits alts són del píxel que ja hi havia (dreta)
		add r7, r5, r8			@; i els baixos són de l'actual (esquerra)
		strh r7, [r4]			@; Pintem la franja (Píxels 0 i 2)
		strh r7, [r4, #16]
		
	.LseguentFranja:
		add r4, #1
		add r6, #1				@; Incrementem el contador de franges pintades
		add r10, #1				@; Número de franja dins de la baldosa (0-7)
		
		cmp r10, #8				@; Si encara estem dins de la baldosa, continuem
		blo .LpintarFranja
		
		mov r10, #0				@; Sinó, iniciem el contador a 0 per a una baldosa nova
		add r4, #56				@; Avancem fins la següent baldosa
		
		b .LpintarFranja
		
	.LfiPintar:
	
	pop {r0-r11, pc}


	.global _gm_rsiTIMER1
	@; Rutina de Servicio de Interrupción (RSI) para actualizar la representa-
	@; ción de la pila y el estado de los procesos activos.
_gm_rsiTIMER1:
	push {r0-r11, lr}
	
		@; Proces RUN
		ldr r4, =_gd_pidz			@; Carreguem el proces que esta a run
		ldr r4, [r4]
		and r4, #0xF				@; Apliquem una mascara per agafar el zocalo
	
		add r1, r4, #4				@; r1 = zocalo + 4

		mov r7, #MAX_COL
		mul r7, r1
		lsl r7, #1					@; MAX_COL*fila*2
		
		mov r8, #COL_LLETRA
		lsl r8, #1					@; columna*2
		
		mov r9, #0x6200000			@; Base del mapa
		add r7, r8					@; MAX_COL*fila*2 + columna*2
		add r9, r7					@; Base mapa + offset posició a dibuixar
		
		mov r8, #178				@; r8 = R blava
		strh r8, [r9]
		bl _gm_calcularBaldosa


		@; PROCESSOS RDY
		ldr r4, =_gd_nReady			@; r4 = numero de processos a la cua de RDY
		ldrb r4, [r4]
		ldr r5, =_gd_qReady			@; r5 = punter a la cua de RDY
		
		mov r6, #0					
	.LbucleReady:
		cmp r6, r4					@; si ja ha acabat
		beq .LiniBlocked
		
		mov r0, #57					@; r0 = Y blanca
		
		ldrb r1, [r5, r6]			@; r1 = zocalo
		mov r10, r1
		add r1, #4					@; r1 = zocalo + 4
		
		mov r7, #MAX_COL
		mul r7, r1
		lsl r7, #1					@; MAX_COL*fila*2
		
		mov r8, #COL_LLETRA
		lsl r8, #1					@; columna*2
		
		mov r9, #0x6200000			@; Base del mapa
		add r7, r8					@; MAX_COL*fila*2 + columna*2
		add r9, r7					@; Base mapa + offset posició a dibuixar

		strh r0, [r9]
		mov r11, r4
		mov r4, r10
		bl _gm_calcularBaldosa
		mov r4, r11
		add r6, #1					@; nProcRDY++
		
		b .LbucleReady
		
	.LiniBlocked:

		@; PROCESSOS BLOCK
		ldr r4, =_gd_nDelay			@; r4 = numero de processos a la cua de BLOCK
		ldrb r4, [r4]
		ldr r5, =_gd_qDelay			@; r5 = punter a la cua de BLOCK
		
		mov r6, #0					
	.LbucleBlocked:
		cmp r6, r4					
		beq .LfinBucleBlocked
		
		ldr r1, [r5, r6, lsl #2]	@; r1 = zocalo
		and r1, #0xFF000000
		mov r1, r1, lsr #24
		mov r10, r1
		add r1, #4					@; r1 = zocalo + 4
		
		mov r7, #MAX_COL
		mul r7, r1
		lsl r7, #1					@; MAX_COL*fila*2
		
		mov r8, #COL_LLETRA
		lsl r8, #1					@; columna*2
		
		mov r9, #0x6200000			@; Base del mapa
		add r7, r8					@; MAX_COL*fila*2 + columna*2
		add r9, r7					@; Base mapa + offset posició a dibuixar

		mov r0, #34					@; r0 = B blanca
		mov r11, r4
		mov r4, r10
		strh r0, [r9]
		mov r4, r11
		add r6, #1					@; nProcBLOCK++
	
		b .LbucleBlocked
		
	.LfinBucleBlocked:
	
	pop {r0-r11, pc}





_gm_calcularBaldosa:
	@; Rutina que dibuixa les baldosas de la representació de la pila del proces
	@; In:
	@; r4 = zocalo

	push {r1-r5, lr}

	cmp r4, #0
	beq .LprocesSO
	
	ldr r0, =_gd_pcbs			@; inici vector PCBS
	mov r1, #24					@; sizeof(garlicPCB) = 6 int * 4 bytes
	mla r0, r1, r4, r0			@; r0 = 24*zocalo+iniciVectorPCBS
	ldr r0, [r0, #8]			@; R0 = top del SP del zocalo en RUN
	
	sub r4, #1
	ldr r1, =_gd_stacks			@; direccio de la pila dels processos actius
	mov r2, #512				@; mida de la pila = 128 words * 4 bytes = 512
	mla r1, r2, r4, r1			@; r1 = 512*(zocalo-1)+_gd_stacks
	add r4, #1					@; afegim el que haviem restat anteriorment
	sub r1, #4					@; Ens coloquem en el bottom del SP del zocalo en RUN
	b .LcalcularPila
	
.LprocesSO:		@; si el socul es 0 (si es el SO)
	mov r0, sp					@; system stack top pointer 
	ldr r1, =#0x0B003D00		@; bottom system stack

.LcalcularPila:
	sub r3, r0, r1				@; Restem les 2 direccions = mida de la pila
	mov r3, r3, lsr #2			@; Dividim entre 4 per saber el numero de words de la pila
	
	mov r0, r3, lsr #1			@; Dividim entre 2 perque hi ha 2 baldoses
	mov r1, r0, lsl #1			@; Mirem el resultat
	sub r1, r3, r1
	
	mov r3, #119				@; r3 = Index de baldosa buida
	
	mov r0, r0, lsr #3			@; Dividim entre 8 perque tenim 8 baldosas diferents
	add r0, r3					@; Calculem la baldosa corresponent
	mov r1, r1, lsr #3			
	add r1, r3
	
	ldr r3, =0x6200000			@; Base del mapa
	add r4, #4					@; Afegim 4 a la pila

	mov r5, #MAX_COL
	mul r5, r4
	lsl r5, #1					@; MAX_COL*fila*2
	add r3, r5

	mov r2, #COL_BARRA			
	add r3, r2, lsl #1			@; zona de memoria de la baldosa corresponent


	strh r0, [r3]				@; Guardem la 1a baldosa		
	strh r1, [r3, #2]			@; Guardem la 2a baldosa

	pop {r1-r5, pc}
	
.end

	.arch armv5te
	.eabi_attribute 23, 1
	.eabi_attribute 24, 1
	.eabi_attribute 25, 1
	.eabi_attribute 26, 1
	.eabi_attribute 30, 6
	.eabi_attribute 34, 0
	.eabi_attribute 18, 4
	.file	"SQRT.c"
	.section	.rodata
	.align	2
.LC0:
	.ascii	"-- SQRT() PER TANTEIG  -  PID (%d) --\012\000"
	.align	2
.LC1:
	.ascii	"(%d)\011S'ha provat amb %d\012\000"
	.align	2
.LC2:
	.ascii	"\011L'arrel de %d,%d es aprox.\000"
	.align	2
.LC3:
	.ascii	" %d,%d\012\000"
	.text
	.align	2
	.global	_start
	.syntax unified
	.arm
	.fpu softvfp
	.type	_start, %function
_start:
	@ args = 0, pretend = 0, frame = 48
	@ frame_needed = 0, uses_anonymous_args = 0
	str	lr, [sp, #-4]!
	sub	sp, sp, #52
	str	r0, [sp, #4]
	mov	r3, #0
	str	r3, [sp, #16]
	mov	r3, #0
	str	r3, [sp, #12]
	mov	r3, #0
	str	r3, [sp, #20]
	mov	r3, #0
	str	r3, [sp, #32]
	mov	r3, #0
	str	r3, [sp, #44]
	mov	r3, #1
	str	r3, [sp, #36]
	mov	r3, #0
	str	r3, [sp, #40]
	ldr	r3, [sp, #4]
	cmp	r3, #0
	bge	.L2
	mov	r3, #0
	str	r3, [sp, #4]
	b	.L3
.L2:
	ldr	r3, [sp, #4]
	cmp	r3, #3
	ble	.L3
	mov	r3, #3
	str	r3, [sp, #4]
.L3:
	bl	GARLIC_pid
	mov	r3, r0
	mov	r1, r3
	ldr	r0, .L12
	bl	GARLIC_printf
	mov	r3, #0
	str	r3, [sp, #16]
	mov	r3, #0
	str	r3, [sp, #8]
	bl	GARLIC_random
	mov	r2, r0
	ldr	r3, [sp, #4]
	add	r1, r3, #1
	mul	r3, r2, r1
	mov	r0, r3
	add	r3, sp, #8
	add	r2, sp, #16
	ldr	r1, .L12+4
	bl	GARLIC_divmod
	ldr	r3, [sp, #8]
	str	r3, [sp, #40]
	ldr	r3, [sp, #40]
	str	r3, [sp, #28]
	b	.L4
.L10:
	ldr	r2, [sp, #36]
	ldr	r3, [sp, #40]
	add	r3, r2, r3
	lsr	r3, r3, #1
	str	r3, [sp, #44]
	bl	GARLIC_pid
	mov	r3, r0
	ldr	r2, [sp, #44]
	mov	r1, r3
	ldr	r0, .L12+8
	bl	GARLIC_printf
	ldr	r3, [sp, #44]
	ldr	r2, [sp, #44]
	mul	r1, r2, r3
	ldr	r2, [sp, #28]
	cmp	r2, r1
	bne	.L5
	mov	r3, #1
	str	r3, [sp, #32]
	b	.L6
.L5:
	ldr	r3, [sp, #44]
	ldr	r2, [sp, #44]
	mul	r1, r2, r3
	ldr	r2, [sp, #28]
	cmp	r2, r1
	bcs	.L7
	ldr	r3, [sp, #44]
	sub	r1, r3, #1
	ldr	r2, [sp, #44]
	sub	r2, r2, #1
	mul	r3, r2, r1
	ldr	r2, [sp, #28]
	cmp	r2, r3
	bls	.L8
	mov	r3, #1
	str	r3, [sp, #32]
.L8:
	ldr	r3, [sp, #44]
	str	r3, [sp, #40]
	ldr	r2, [sp, #36]
	ldr	r3, [sp, #40]
	add	r3, r2, r3
	lsr	r3, r3, #1
	str	r3, [sp, #44]
	b	.L6
.L7:
	ldr	r3, [sp, #44]
	ldr	r2, [sp, #44]
	mul	r1, r2, r3
	ldr	r2, [sp, #28]
	cmp	r2, r1
	bls	.L6
	ldr	r3, [sp, #44]
	add	r1, r3, #1
	ldr	r2, [sp, #44]
	add	r2, r2, #1
	mul	r3, r2, r1
	ldr	r2, [sp, #28]
	cmp	r2, r3
	bcs	.L9
	ldr	r3, [sp, #44]
	add	r3, r3, #1
	str	r3, [sp, #44]
	mov	r3, #1
	str	r3, [sp, #32]
.L9:
	ldr	r3, [sp, #44]
	str	r3, [sp, #36]
	ldr	r2, [sp, #36]
	ldr	r3, [sp, #40]
	add	r3, r2, r3
	lsr	r3, r3, #1
	str	r3, [sp, #44]
.L6:
	ldr	r3, [sp, #4]
	mov	r0, r3
	bl	GARLIC_delay
.L4:
	ldr	r3, [sp, #32]
	cmp	r3, #0
	beq	.L10
	add	r3, sp, #24
	add	r2, sp, #20
	mov	r1, #10
	ldr	r0, [sp, #44]
	bl	GARLIC_divmod
	ldr	r0, [sp, #8]
	add	r3, sp, #12
	add	r2, sp, #16
	mov	r1, #100
	bl	GARLIC_divmod
	ldr	r3, [sp, #16]
	ldr	r2, [sp, #12]
	mov	r1, r3
	ldr	r0, .L12+12
	bl	GARLIC_printf
	ldr	r3, [sp, #20]
	ldr	r2, [sp, #24]
	mov	r1, r3
	ldr	r0, .L12+16
	bl	GARLIC_printf
	mov	r3, #0
	mov	r0, r3
	add	sp, sp, #52
	@ sp needed
	ldr	pc, [sp], #4
.L13:
	.align	2
.L12:
	.word	.LC0
	.word	10000
	.word	.LC1
	.word	.LC2
	.word	.LC3
	.size	_start, .-_start
	.ident	"GCC: (devkitARM release 47) 7.1.0"

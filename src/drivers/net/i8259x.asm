; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2024 Return Infinity -- see LICENSE.TXT
;
; Intel i8259x Driver
; =============================================================================


; -----------------------------------------------------------------------------
; Initialize an Intel 8259x NIC
;  IN:	RDX = Packed Bus address (as per syscalls/bus.asm)
net_i8259x_init:
	push rsi
	push rdx
	push rcx
	push rax

	; Grab the Base I/O Address of the device
	xor ebx, ebx
	mov dl, 0x04			; Read register 4 for BAR0
	call os_bus_read
	xchg eax, ebx			; Exchange the result to EBX (low 32 bits of base)
	bt ebx, 0			; Bit 0 will be 0 if it is an MMIO space
	jc net_i8259x_init_error
	bt ebx, 2			; Bit 2 will be 1 if it is a 64-bit MMIO space
	jnc net_i8259x_init_32bit_bar
	mov dl, 0x05			; Read register 5 for BAR1 (Upper 32-bits of BAR0)
	call os_bus_read
	shl rax, 32			; Shift the bits to the upper 32
net_i8259x_init_32bit_bar:
	and ebx, 0xFFFFFFF0		; Clear the low four bits
	add rax, rbx			; Add the upper 32 and lower 32 together
	mov [os_NetIOBaseMem], rax	; Save it as the base

	; Grab the IRQ of the device
	mov dl, 0x0F				; Get device's IRQ number from Bus Register 15 (IRQ is bits 7-0)
	call os_bus_read
	mov [os_NetIRQ], al			; AL holds the IRQ

	; Enable PCI Bus Mastering
	mov dl, 0x01				; Get Status/Command
	call os_bus_read
	bts eax, 2
	call os_bus_write

	; Grab the MAC address
	mov rsi, [os_NetIOBaseMem]
	mov eax, [rsi+I8259X_RAL]		; RAL
	mov [os_NetMAC], al
	shr eax, 8
	mov [os_NetMAC+1], al
	shr eax, 8
	mov [os_NetMAC+2], al
	shr eax, 8
	mov [os_NetMAC+3], al
	mov eax, [rsi+I8259X_RAH]		; RAH
	mov [os_NetMAC+4], al
	shr eax, 8
	mov [os_NetMAC+5], al

	; Reset the device
	call net_i8259x_reset

net_i8259x_init_error:

	pop rax
	pop rcx
	pop rdx
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_i8259x_reset - Reset an Intel 8259x NIC
;  IN:	Nothing
; OUT:	Nothing, all registers preserved
net_i8259x_reset:
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_i8259x_transmit - Transmit a packet via an Intel 8259x NIC
;  IN:	RSI = Location of packet
;	RCX = Length of packet
; OUT:	Nothing
net_i8259x_transmit:
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_i8259x_poll - Polls the Intel 8259x NIC for a received packet
;  IN:	RDI = Location to store packet
; OUT:	RCX = Length of packet
net_i8259x_poll:
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_i8259x_ack_int - Acknowledge an internal interrupt of the Intel 8259x NIC
;  IN:	Nothing
; OUT:	RAX = Ethernet status
net_i8259x_ack_int:
	ret
; -----------------------------------------------------------------------------


; Maximum packet size
I8259X_MAX_PKT_SIZE	equ 16384

; Register list
I8259X_CTRL		equ 0x00000
I8259X_STATUS		equ 0x00008
I8259X_CTRL_EXT		equ 0x00018
I8259X_ESDP		equ 0x00020
I8259X_EODSDP		equ 0x00028
I8259X_I2CCTL_82599	equ 0x00028
I8259X_I2CCTL		equ I8259X_I2CCTL_82599
I8259X_I2CCTL_X540	equ I8259X_I2CCTL_82599
I8259X_I2CCTL_X550	equ 0x15F5C
I8259X_I2CCTL_X550EM_x	equ I8259X_I2CCTL_X550
I8259x_I2CCTL_X550EM_a	equ I8259X_I2CCTL_X550
;I8259x_I2CCTL_BY_MAC
I8259x_PHY_GPIO		equ 0x00028
I8259x_MAC_GPIO		equ 0x00030
I8259x_PHYINT_STATUS0	equ 0x00100
I8259x_PHYINT_STATUS1	equ 0x00104
I8259x_PHYINT_STATUS2	equ 0x00108
I8259x_LEDCTL		equ 0x00200
I8259x_FRTIMER		equ 0x00048
I8259x_TCPTIMER		equ 0x0004C
I8259x_CORESPARE	equ 0x00600
I8259X_RAL		equ 0x05400
I8259X_RAH		equ 0x05404
I8259x_EXVET		equ 0x05078

; =============================================================================
; EOF

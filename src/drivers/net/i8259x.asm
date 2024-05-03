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

	; Read BAR4, If BAR4 is all zeros then we are using 32-bit addresses

	; Grab the Base I/O Address of the device
	mov dl, 0x04				; BAR0
	call os_bus_read
	and eax, 0xFFFFFFF0			; EAX now holds the Base Memory IO Address (clear the low 4 bits)
	mov dword [os_NetIOBaseMem], eax

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
	cmp eax, 0x00000000
	je net_i8259x_init_get_MAC_via_EPROM
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
	jmp net_i8259x_init_done_MAC

net_i8259x_init_get_MAC_via_EPROM:
	mov rsi, [os_NetIOBaseMem]
	mov eax, 0x00000001
	mov [rsi+0x14], eax
	mov eax, [rsi+0x14]
	shr eax, 16
	mov [os_NetMAC], al
	shr eax, 8
	mov [os_NetMAC+1], al
	mov eax, 0x00000101
	mov [rsi+0x14], eax
	mov eax, [rsi+0x14]
	shr eax, 16
	mov [os_NetMAC+2], al
	shr eax, 8
	mov [os_NetMAC+3], al
	mov eax, 0x00000201
	mov [rsi+0x14], eax
	mov eax, [rsi+0x14]
	shr eax, 16
	mov [os_NetMAC+4], al
	shr eax, 8
	mov [os_NetMAC+5], al
net_i8259x_init_done_MAC:

	; Reset the device
	call net_i8259x_reset

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
; Note:	This driver uses the "legacy format" so TDESC.DEXT is set to 0
;	Descriptor Format:
;	Bytes 7:0 - Buffer Address
;	Bytes 9:8 - Length
;	Bytes 13:10 - Flags
;	Bytes 15:14 - Special
net_i8259x_transmit:
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_i8259x_poll - Polls the Intel 8259x NIC for a received packet
;  IN:	RDI = Location to store packet
; OUT:	RCX = Length of packet
; Note:	Descriptor Format:
;	Bytes 7:0 - Buffer Address
;	Bytes 9:8 - Length
;	Bytes 13:10 - Flags
;	Bytes 15:14 - Special
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

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

	; Enable PCI Bus Mastering and Memory Space
	mov dl, 0x01				; Get Status/Command
	call os_bus_read
	bts eax, 2				; Bus Master
	bts eax, 1				; Memory Space
	call os_bus_write

;	mov rsi, [os_NetIOBaseMem]
;
;	; Disable Interrupts (4.6.3.1)
;	xor eax, eax
;	mov [rsi+i8259x_EIMS], eax
;	mov eax, i8259x_IRQ_CLEAR_MASK
;	mov [rsi+i8259x_EIMC], eax
;	mov eax, [rsi+i8259x_EICR]
;
;	; Issue a global reset (4.6.3.2)
;	mov eax, i8259x_CTRL_RST_MASK		; Load the mask for a software reset and link reset
;	mov [rsi+i8259x_CTRL], eax
;	mov eax, [rsi+i8259x_CTRL]
;	; wait for it to be cleared
;	; wait 10ns
;
;	; Disable Interrupts again (4.6.3.1)
;	xor eax, eax
;	mov [rsi+i8259x_EIMS], eax
;	mov eax, i8259x_IRQ_CLEAR_MASK
;	mov [rsi+i8259x_EIMC], eax
;	mov eax, [rsi+i8259x_EICR]
;
;	; Wait for EEPROM auto read completion (4.6.3)
;	mov eax, i8259x_EEC_ARD
;	mov [rsi+i8259x_EEC], eax
;
;	; Wait for DMA initialization done (4.6.3)
;	mov eax, i8259x_RDRXCTL_DMAIDONE
;	mov [rsi+i8259x_RDRXCTL], eax
;
;	; Set up the PHY and the link (4.6.4)
;
;	; Initialize all statistical counters (4.6.5)
;	; These registers are cleared after they are read
;	mov eax, [rsi+i8259x_GPRC]		; RX packets
;	mov eax, [rsi+i8259x_GPTC]		; TX packets
;	xor eax, eax
;	mov eax, [rsi+i8259x_GORCL]
;	mov ebx, [rsi+i8259x_GORCH]
;	shl rbx, 32
;	add rax, rbx				; RX bytes
;	xor eax, eax
;	mov eax, [rsi+i8259x_GOTCL]
;	mov ebx, [rsi+i8259x_GOTCH]
;	shl rbx, 32
;	add rax, rbx				; TX bytes
;
;	; Initialize receive (4.6.7)
;
;	; Initialize transmit (4.6.8)
;
;	; Enable interrupts (4.6.3.1)
;	mov eax, VALUE_HERE
;	mov [rsi+i8259x_EIMS], eax


	; Grab the MAC address
	mov rsi, [os_NetIOBaseMem]
	mov rax, [rsi+i8259x_RAL]
	mov [os_NetMAC], al
	shr rax, 8
	mov [os_NetMAC+1], al
	shr rax, 8
	mov [os_NetMAC+2], al
	shr rax, 8
	mov [os_NetMAC+3], al
	shr rax, 8
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
i8259x_MAX_PKT_SIZE	equ 16384

; Register list
i8259x_CTRL		equ 0x00000
i8259x_STATUS		equ 0x00008
i8259x_CTRL_EXT		equ 0x00018
i8259x_ESDP		equ 0x00020
i8259x_EODSDP		equ 0x00028
i8259x_I2CCTL_82599	equ 0x00028
i8259x_I2CCTL		equ i8259x_I2CCTL_82599
i8259x_I2CCTL_X540	equ i8259x_I2CCTL_82599
i8259x_I2CCTL_X550	equ 0x15F5C
i8259x_I2CCTL_X550EM_x	equ i8259x_I2CCTL_X550
i8259x_I2CCTL_X550EM_a	equ i8259x_I2CCTL_X550
;i8259x_I2CCTL_BY_MAC
i8259x_PHY_GPIO		equ 0x00028
i8259x_MAC_GPIO		equ 0x00030
i8259x_PHYINT_STATUS0	equ 0x00100
i8259x_PHYINT_STATUS1	equ 0x00104
i8259x_PHYINT_STATUS2	equ 0x00108
i8259x_LEDCTL		equ 0x00200
i8259x_FRTIMER		equ 0x00048
i8259x_TCPTIMER		equ 0x0004C
i8259x_CORESPARE	equ 0x00600
i8259x_EICR		equ 0x00800 ; Extended Interrupt Cause Register
i8259x_EICS		equ 0x00808 ; Extended Interrupt Cause Set Register
i8259x_EIMS		equ 0x00880 ; Extended Interrupt Mask Set / Read Register
i8259x_EIMC		equ 0x00888 ; Extended Interrupt Mask Clear Register
i8259x_EIAC		equ 0x00810 ; Extended Interrupt Auto Clear Register
i8259x_EIAM		equ 0x00890 ; Extended Interrupt Auto Mask Enable Register
i8259x_RDRXCTL		equ 0x02F00
i8259x_GPRC		equ 0x04074
i8259x_BPRC		equ 0x04078
i8259x_MPRC		equ 0x0407C
i8259x_GPTC		equ 0x04080
i8259x_GORCL		equ 0x04088
i8259x_GORCH		equ 0x0408C
i8259x_GOTCL		equ 0x04090
i8259x_GOTCH		equ 0x04094
i8259x_EXVET		equ 0x05078
i8259x_RAL		equ 0x05400
i8259x_RAH		equ 0x05404
i8259x_EEC		equ 0x10010

; CTRL Bit Masks
i8259x_CTRL_GIO_DIS	equ 0x00000004 ; Global IO Master Disable bit
i8259x_CTRL_LNK_RST	equ 0x00000008 ; Link Reset. Resets everything.
i8259x_CTRL_RST		equ 0x04000000 ; Reset (SW)
i8259x_CTRL_RST_MASK	equ i8259x_CTRL_LNK_RST | i8259x_CTRL_RST

; EEC Bit Masks
i8259x_EEC_ARD		equ 0x00000200 ; EEPROM Auto Read Done

; RDRXCTL Bit Masks
i8259x_RDRXCTL_DMAIDONE	equ 0x00000008 ; DMA init cycle done

i8259x_IRQ_CLEAR_MASK	equ 0xFFFFFFFF

; =============================================================================
; EOF

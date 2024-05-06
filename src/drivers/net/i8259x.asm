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

	; Grab the MAC address
	mov rsi, [os_NetIOBaseMem]
	mov eax, [rsi+i8259x_RAL]
	mov [os_NetMAC], al
	shr rax, 8
	mov [os_NetMAC+1], al
	shr rax, 8
	mov [os_NetMAC+2], al
	shr rax, 8
	mov [os_NetMAC+3], al
	mov eax, [rsi+i8259x_RAH]
	mov [os_NetMAC+4], al
	shr eax, 8
	mov [os_NetMAC+5], al

;	The following code will be moved to net_i8259x_reset

	mov rsi, [os_NetIOBaseMem]

	; Disable Interrupts (4.6.3.1)
	xor eax, eax
	mov [rsi+i8259x_EIMS], eax
	mov eax, i8259x_IRQ_CLEAR_MASK
	mov [rsi+i8259x_EIMC], eax
	mov eax, [rsi+i8259x_EICR]

	; Issue a global reset (4.6.3.2)
	mov eax, i8259x_CTRL_RST_MASK		; Load the mask for a software reset and link reset
	mov [rsi+i8259x_CTRL], eax		; Write the reset value
net_i8259x_init_reset_wait:
	mov eax, [rsi+i8259x_CTRL]		; Read CTRL
	jnz net_i8259x_init_reset_wait		; Wait for it to read back as 0x0

	; Wait 10ns

	; Disable Interrupts again (4.6.3.1)
	xor eax, eax
	mov [rsi+i8259x_EIMS], eax
	mov eax, i8259x_IRQ_CLEAR_MASK
	mov [rsi+i8259x_EIMC], eax
	mov eax, [rsi+i8259x_EICR]

	; Wait for EEPROM auto read completion (4.6.3)
	mov eax, [rsi+i8259x_EEC]		; Read current value
	bts eax, 9				; i8259x_EEC_ARD
	mov [rsi+i8259x_EEC], eax		; Write the new value
net_i8259x_init_eeprom_wait:
	mov eax, [rsi+i8259x_EEC]		; Read current value
	bt eax, 9
	jnc net_i8259x_init_eeprom_wait		; If not equal, keep waiting

	; Wait for DMA initialization done (4.6.3)
	mov eax, [rsi+i8259x_RDRXCTL]		; Read current value
	bts eax, 3				; i8259x_RDRXCTL_DMAIDONE
	mov [rsi+i8259x_RDRXCTL], eax		; Write the new value
net_i8259x_init_dma_wait:
	mov eax, [rsi+i8259x_RDRXCTL]		; Read current value
	bt eax, 3
	jnc net_i8259x_init_dma_wait		; If not equal, keep waiting

	; Set up the PHY and the link (4.6.4)

	; Initialize all statistical counters (4.6.5)
	; These registers are cleared by the device after they are read
	mov eax, [rsi+i8259x_GPRC]		; RX packets
	mov eax, [rsi+i8259x_GPTC]		; TX packets
	xor eax, eax
	mov eax, [rsi+i8259x_GORCL]
	mov ebx, [rsi+i8259x_GORCH]
	shl rbx, 32
	add rax, rbx				; RX bytes
	xor eax, eax
	mov eax, [rsi+i8259x_GOTCL]
	mov ebx, [rsi+i8259x_GOTCH]
	shl rbx, 32
	add rax, rbx				; TX bytes

	; Initialize receive (4.6.7)

	; Initialize transmit (4.6.8)

	; Enable interrupts (4.6.3.1)
;	mov eax, VALUE_HERE
;	mov [rsi+i8259x_EIMS], eax

;	; Reset the device
;	call net_i8259x_reset

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

; Register list (All registers should be accessed as 32-bit values)

; General Control Registers
i8259x_CTRL		equ 0x00000 ; Device Control Register
i8259x_CTRL_Legacy	equ 0x00004 ; Copy of Device Control Register
i8259x_STATUS		equ 0x00008 ; Device Status Register
i8259x_CTRL_EXT		equ 0x00018 ; Extended Device Control Register
i8259x_ESDP		equ 0x00020 ; Extended SDP Control
i8259x_I2CCTL		equ 0x00028 ; I2C Control
i8259x_LEDCTL		equ 0x00200 ; LED Control
i8259x_EXVET		equ 0x05078 ; Extended VLAN Ether Type

; EEPROM / Flash Registers
i8259x_EEC		equ 0x10010 ; EEPROM/Flash Control Register
i8259x_EERD		equ 0x10014 ; EEPROM Read Register
i8259x_FLA		equ 0x1001C ; Flash Access Register
i8259x_EEMNGDATA	equ 0x10114 ; Manageability EEPROM Read/ Write Data
i8259x_FLMNGCTL		equ 0x10118 ; Manageability Flash Control Register
i8259x_FLMNGDATA	equ 0x1011C ; Manageability Flash Read Data
i8259x_FLOP		equ 0x1013C ; Flash Opcode Register
i8259x_GRC		equ 0x10200 ; General Receive Control

; Flow Control Registers

; PCIe Registers
i8259x_GCR		equ 0x11000 ; PCIe Control Register
i8259x_GSCL_0		equ 0x11020 ; PCIe Statistic Control Register #0
i8259x_GSCL_1		equ 0x11010 ; PCIe Statistic Control Register #1
i8259x_GSCL_2		equ 0x11014 ; PCIe Statistic Control Register #2
;i8259x_GSCL_3
;i8259x_GSCL_4
i8259x_GSCL_5		equ 0x11030 ; PCIe Statistic Control Register #5
;i8259x_GSCL_6
;i8259x_GSCL_7
;i8259x_GSCL_8
i8259x_FACTPS		equ 0x10150 ; Function Active and Power State to Manageability
i8259x_PCIEPHYADR	equ 0x11040 ; PCIe PHY Address Register
i8259x_PCIEPHYDAT	equ 0x11044 ; PCIe PHY Data Register

; Interrupt Registers
i8259x_EICR		equ 0x00800 ; Extended Interrupt Cause Register
i8259x_EICS		equ 0x00808 ; Extended Interrupt Cause Set Register
i8259x_EIMS		equ 0x00880 ; Extended Interrupt Mask Set / Read Register
i8259x_EIMC		equ 0x00888 ; Extended Interrupt Mask Clear Register
i8259x_EIAC		equ 0x00810 ; Extended Interrupt Auto Clear Register
i8259x_EIAM		equ 0x00890 ; Extended Interrupt Auto Mask Enable Register

; MSI-X Table Registers

; Receive Registers
i8259x_RAL		equ 0x05400 ; Receive Address Low (0x0A200?)
i8259x_RAH		equ 0x05404 ; Receive Address High (0x0A204?)

; Receive DMA Registers

; Transmit Registers

; DCB Registers

; DCA Registers

; Security Registers

; LinkSec Registers

; IPsec Registers

; Timers Registers

; FCoE Registers

; Flow Director Registers

; Global Status / Statistics Registers

; Flow Programming Registers

; MAC Registers

; Statistic Registers
i8259x_GPRC		equ 0x04074 ; Good Packets Received Count
i8259x_BPRC		equ 0x04078 ; Broadcast Packets Received Count
i8259x_MPRC		equ 0x0407C ; Multicast Packets Received Count
i8259x_GPTC		equ 0x04080 ; Good Packets Transmitted Count
i8259x_GORCL		equ 0x04088 ; Good Octets Received Count Low
i8259x_GORCH		equ 0x0408C ; Good Octets Received Count High
i8259x_GOTCL		equ 0x04090 ; Good Octets Transmitted Count Low
i8259x_GOTCH		equ 0x04094 ; Good Octets Transmitted Count High

; Wake-Up Control Registers

; Management Filters Registers

; Time Sync (IEEE 1588) Registers

; Virtualization PF Registers


;i8259x_EODSDP		equ 0x00028
;i8259x_I2CCTL_82599	equ 0x00028
;i8259x_I2CCTL		equ i8259x_I2CCTL_82599
;i8259x_I2CCTL_X540	equ i8259x_I2CCTL_82599
;i8259x_I2CCTL_X550	equ 0x15F5C
;i8259x_I2CCTL_X550EM_x	equ i8259x_I2CCTL_X550
;i8259x_I2CCTL_X550EM_a	equ i8259x_I2CCTL_X550
;i8259x_I2CCTL_BY_MAC
i8259x_PHY_GPIO		equ 0x00028
i8259x_MAC_GPIO		equ 0x00030
i8259x_PHYINT_STATUS0	equ 0x00100
i8259x_PHYINT_STATUS1	equ 0x00104
i8259x_PHYINT_STATUS2	equ 0x00108

i8259x_FRTIMER		equ 0x00048
i8259x_TCPTIMER		equ 0x0004C
i8259x_CORESPARE	equ 0x00600
i8259x_RDRXCTL		equ 0x02F00

i8259x_EXVET		equ 0x05078 ; Extended VLAN Ether Type


; CTRL Bit Masks
i8259x_CTRL_GIO_DIS	equ 2 ; PCIe Master Disable
i8259x_CTRL_LNK_RST	equ 3 ; Link Reset
i8259x_CTRL_RST		equ 26 ; Device Reset
; All other bits are reserved and should be written as 0
i8259x_CTRL_RST_MASK	equ 1 << i8259x_CTRL_LNK_RST | 1 << i8259x_CTRL_RST

; STATUS Bit Masks
i8259x_STATUS_LINKUP	equ 7 ; Linkup Status Indication
i8259x_STATUS_MASEN	equ 19 ; This is a status bit of the appropriate CTRL.PCIe Master Disable bit.
; All other bits are reserved and should be written as 0

; TODO Change bit masks to actual bits
; EEC Bit Masks
i8259x_EEC_SK		equ 0x00000001 ; EEPROM Clock
i8259x_EEC_CS		equ 0x00000002 ; EEPROM Chip Select
i8259x_EEC_DI		equ 0x00000004 ; EEPROM Data In
i8259x_EEC_DO		equ 0x00000008 ; EEPROM Data Out
i8259x_EEC_FWE_MASK	equ 0x00000030 ; FLASH Write Enable
i8259x_EEC_FWE_DIS	equ 0x00000010 ; Disable FLASH writes
i8259x_EEC_FWE_EN	equ 0x00000020 ; Enable FLASH writes
i8259x_EEC_FWE_SHIFT	equ 4
i8259x_EEC_REQ		equ 0x00000040 ; EEPROM Access Request
i8259x_EEC_GNT		equ 0x00000080 ; EEPROM Access Grant
i8259x_EEC_PRES		equ 0x00000100 ; EEPROM Present
i8259x_EEC_ARD		equ 0x00000200 ; EEPROM Auto Read Done
i8259x_EEC_FLUP		equ 0x00800000 ; Flash update command
i8259x_EEC_SEC1VAL	equ 0x02000000 ; Sector 1 Valid
i8259x_EEC_FLUDONE	equ 0x04000000 ; Flash update done

; EEC Misc
; EEPROM Addressing bits based on type (0-small, 1-large)
i8259x_EEC_ADDR_SIZE	equ 0x00000400
i8259x_EEC_SIZE		equ 0x00007800 ; EEPROM Size
i8259x_EERD_MAX_ADDR	equ 0x00003FFF ; EERD allows 14 bits for addr

; RDRXCTL Bit Masks
i8259x_RDRXCTL_DMAIDONE	equ 0x00000008 ; DMA init cycle done

i8259x_IRQ_CLEAR_MASK	equ 0xFFFFFFFF

; =============================================================================
; EOF

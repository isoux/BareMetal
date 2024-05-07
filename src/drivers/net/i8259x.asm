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
	bt eax, 9				; i8259x_EEC_ARD
	jnc net_i8259x_init_eeprom_wait		; If not equal, keep waiting

	; Wait for DMA initialization done (4.6.3)
	mov eax, [rsi+i8259x_RDRXCTL]		; Read current value
	bts eax, 3				; i8259x_RDRXCTL_DMAIDONE
	mov [rsi+i8259x_RDRXCTL], eax		; Write the new value
net_i8259x_init_dma_wait:
	mov eax, [rsi+i8259x_RDRXCTL]		; Read current value
	bt eax, 3				; i8259x_RDRXCTL_DMAIDONE
	jnc net_i8259x_init_dma_wait		; If not equal, keep waiting

	; Set up the PHY and the link (4.6.4)
;	mov eax, [rsi+i8259x_AUTOC]
;	or eax, 0x0000E000			; Set LMS (bits 15:13) for KX/KX4/KR auto-negotiation enable
;	mov [rsi+i8259x_AUTOC], eax
;	mov eax, [rsi+i8259x_AUTOC]
;						; Set 10G_PMA_PMD_PARALLEL (bits 8:7)
;	mov [rsi+i8259x_AUTOC], eax
	mov eax, [rsi+i8259x_AUTOC]
	bts eax, 12				; Restart_AN
	mov [rsi+i8259x_AUTOC], eax

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
	xor eax, eax				; RXEN = 0
	mov [rsi+i8259x_RXCTRL], eax		; Disable receive
	; i8259x_RXPBSIZE
	; i8259x_HLREG0
	; i8259x_HLREG0_RXCRCSTRP
	; i8259x_RDRXCTL
	; i8259x_RDRXCTL_CRCSTRIP
	mov eax, [rsi+i8259x_FCTRL]
	or eax, i8259x_FCTRL_BAM		; Accept broadcast packets
	mov [rsi+i8259x_FCTRL], eax
	; i8259x_SRRCTL
	mov rax, os_rx_desc
	mov [rsi+i8259x_RDBAL], eax
	shr rax, 32
	mov [rsi+i8259x_RDBAH], eax
	mov eax, 32768
	mov [rsi+i8259x_RDLEN], eax
	xor eax, eax
	mov [rsi+i8259x_RDH], eax
	mov [rsi+i8259x_RDT], eax
	; i8259x_CTRL_EXT
	; i8259x_DCA_RXCTRL
;	mov eax, 1				; RXEN = 1
;	mov [rsi+i8259x_RXCTRL], eax		; Enable receive

	; Initialize transmit (4.6.8)
	mov eax, [rsi+i8259x_HLREG0]		; Enable CRC offload and small packet padding
	or eax, 1 << i8259x_HLREG0_TXCRCEN | 1 << i8259x_HLREG0_TXPADEN
	mov [rsi+i8259x_HLREG0], eax
	mov eax, 32768
	mov [rsi+i8259x_TXPBSIZE], eax
	mov eax, 0x0000FFFF
	mov [rsi+i8259x_DTXMXSZRQ], eax
	mov eax, [rsi+i8259x_RTTDCS]
	btc eax, 6				; ARBDIS
	mov [rsi+i8259x_RTTDCS], eax
	mov rax, os_tx_desc
	mov [rsi+i8259x_TDBAL], eax
	shr rax, 32
	mov [rsi+i8259x_TDBAH], eax
	mov eax, 32768
	mov [rsi+i8259x_TDLEN], eax
	xor eax, eax
	mov [rsi+i8259x_TDH], eax
	mov [rsi+i8259x_TDT], eax
	mov eax, [rsi+i8259x_DMATXCTL]
	or eax, 1				; Transmit Enable, bit 0 TE
	mov [rsi+i8259x_DMATXCTL], eax
;	mov eax, [rsi+i8259x_TXDCTL]
	mov eax, 0x2040824 ;0x27F7F7F		; bit 25 ENABLE
	mov [rsi+i8259x_TXDCTL], eax
net_i8259x_init_tx_enable_wait:
	mov eax, [rsi+i8259x_TXDCTL]
	bt eax, 25
	jnc net_i8259x_init_tx_enable_wait

; DEBUG - Enable Promiscuous mode
;	mov eax, [rsi+i8259x_FCTRL]
;	or eax, 1 << i8259x_FCTRL_MPE | 1 << i8259x_FCTRL_UPE
;	mov [rsi+i8259x_FCTRL], eax

	; Enable interrupts (4.6.3.1)
;	mov eax, VALUE_HERE
;	mov [rsi+i8259x_EIMS], eax

	; Set Driver Loaded bit
	mov eax, [rsi+i8259x_CTRL_EXT]
	or eax, 1 << i8259x_CTRL_EXT_DRVLOAD
	mov [rsi+i8259x_CTRL_EXT], eax

;	; Reset the device
;	call net_i8259x_reset

; Debug
	mov rsi, testpacket
	mov rcx, 42
	call net_i8259x_transmit

net_i8259x_init_error:

	pop rax
	pop rcx
	pop rdx
	pop rsi
	ret
; -----------------------------------------------------------------------------

testpacket:
db 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF	; Dest
db 0x98, 0xB7, 0x85, 0x1E, 0x92, 0x4E	; Source
db 0x08, 0x06	; ARP
db 0x00, 0x01	; Ethernet
db 0x08, 0x00	; Proto
db 0x06		; Hardware size
db 0x04		; Protocol size
db 0x00, 0x01	; Opcode
db 0x98, 0xB7, 0x85, 0x1E, 0x92, 0x4E	; My MAC
db 0x0A, 0x00, 0x00, 0x01	; My IP
db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00	; Target MAC
db 0x0A, 0x00, 0x00, 0x02	; Target IP

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
; Note:	Descriptor Format:
;	Bytes 7:0 - Buffer Address
;	Bytes 11:8 - Command / Type / Length
;	Bytes 16:12 - Status
net_i8259x_transmit:
	push rdi
	push rax

	mov rdi, os_tx_desc			; Transmit Descriptor Base Address

	mov rax, rsi
	stosq					; Store the data location

	mov rax, rcx				; The packet size is in CX
	;	IXGBE_ADVTXD_DCMD_EOP -> 0x01000000 /* End of Packet */
	;	IXGBE_ADVTXD_DCMD_RS -> 0x08000000 /* Report Status */
	;	IXGBE_ADVTXD_DCMD_IFCS -> 0x02000000 /* Insert FCS (Ethernet CRC) */
	;	IXGBE_ADVTXD_DCMD_DEXT -> 0x20000000 /* Desc extension (0 = legacy) */
	;	IXGBE_ADVTXD_DTYP_DATA 0x00300000
	or eax, 0x2B000000
	stosd

	mov rax, rcx
	shl eax, 14 ;IXGBE_ADVTXD_PAYLEN_SHIFT
	stosd

	mov rdi, [os_NetIOBaseMem]
	xor eax, eax
	mov [rdi+i8259x_TDH], eax		; TDH - Transmit Descriptor Head
	inc eax
	mov [rdi+i8259x_TDT], eax		; TDL - Transmit Descriptor Tail

	pop rax
	pop rdi
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
i8259x_PBACL		equ 0x110C0 ; MSI-X PBA Clear

; Receive Registers
i8259x_FCTRL		equ 0x05080 ; Filter Control Register
i8259x_RAL		equ 0x0A200 ; Receive Address Low (Lower 32-bits of 48-bit address)
i8259x_RAH		equ 0x0A204 ; Receive Address High (Upper 16-bits of 48-bit address). Bit 31 should be set for Address Valid

; Receive DMA Registers
i8259x_RDBAL		equ 0x01000 ; Receive Descriptor Base Address Low
i8259x_RDBAH		equ 0x01004 ; Receive Descriptor Base Address High
i8259x_RDLEN		equ 0x01008 ; Receive Descriptor Length
i8259x_RDH		equ 0x01010 ; Receive Descriptor Head
i8259x_RDT		equ 0x01018 ; Receive Descriptor Tail
i8259x_RXCTRL		equ 0x01028 ; Receive Descriptor Control
i8259x_RDRXCTL		equ 0x02F00 ; Receive DMA Control Register
i8259x_SRRCTL		equ 0x01014 ; Split Receive Control Registers
i8259x_RXPBSIZE		equ 0x03C00 ; Receive Packet Buffer Size

; Transmit Registers
i8259x_DMATXCTL		equ 0x04A80 ; DMA Tx Control
i8259x_TDBAL		equ 0x06000 ; Transmit Descriptor Base Address Low
i8259x_TDBAH		equ 0x06004 ; Transmit Descriptor Base Address High
i8259x_TDLEN		equ 0x06008 ; Transmit Descriptor Length (Bits 19:0 in bytes)
i8259x_TDH		equ 0x06010 ; Transmit Descriptor Head (Bits 15:0)
i8259x_TDT		equ 0x06018 ; Transmit Descriptor Tail (Bits 15:0)
i8259x_TXDCTL		equ 0x06028 ; Transmit Descriptor Control (Bit 25 - Enable)
i8259x_DTXMXSZRQ	equ 0x08100 ; DMA Tx TCP Max Allow Size Requests
i8259x_TXPBSIZE		equ 0x0CC00 ; Transmit Packet Buffer Size

; DCB Registers
i8259x_RTTDCS		equ 0x04900 ; DCB Transmit Descriptor Plane Control and Status

; DCA Registers
i8259x_DCA_RXCTRL	equ 0x0100C ; Rx DCA Control Register

; Security Registers

; LinkSec Registers

; IPsec Registers

; Timers Registers

; FCoE Registers

; Flow Director Registers

; Global Status / Statistics Registers

; Flow Programming Registers

; MAC Registers
i8259x_HLREG0		equ 0x04240 ; MAC Core Control 0 Register
i8259x_HLREG1		equ 0x04244 ; MAC Core Status 1 Register
i8259x_AUTOC		equ 0x042A0 ; Auto-Negotiation Control Register
i8259x_AUTOC2		equ 0x042A8 ; Auto-Negotiation Control Register 2
i8259x_LINKS		equ 0x042A4 ; Link Status Register
i8259x_LINKS2		equ 0x04324 ; Link Status Register 2

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




; CTRL (Device Control Register; 0x00000 / 0x00004; RW) Bit Masks
i8259x_CTRL_MSTR_DIS	equ 2 ; PCIe Master Disable
i8259x_CTRL_LRST	equ 3 ; Link Reset
i8259x_CTRL_RST		equ 26 ; Device Reset
; All other bits are reserved and should be written as 0
i8259x_CTRL_RST_MASK	equ 1 << i8259x_CTRL_LRST | 1 << i8259x_CTRL_RST

; STATUS (Device Status Register; 0x00008; RO) Bit Masks
i8259x_STATUS_LINKUP	equ 7 ; Linkup Status Indication
i8259x_STATUS_MASEN	equ 19 ; This is a status bit of the appropriate CTRL.PCIe Master Disable bit.
; All other bits are reserved and should be written as 0

; CTRL_EXT (Extended Device Control Register; 0x00018; RW)
i8259x_CTRL_EXT_DRVLOAD	equ 28 ; Driver loaded and the corresponding network interface is enabled

; RXCTRL (Receive Control Register; 0x03000; RW) Bit Masks
i8259x_RXCTRL_RXEN	equ 0 ; Receive Enable
; All other bits are reserved and should be written as 0

; HLREG0 (MAC Core Control 0 Register; 0x04240; RW) Bit Masks
i8259x_HLREG0_TXCRCEN	equ 0 ; Tx CRC Enable
i8259x_HLREG0_JUMBOEN	equ 2 ; Jumbo Frame Enable - size is defined by MAXFRS
i8259x_HLREG0_TXPADEN	equ 10 ; Tx Pad Frame Enable (pads to at least 64 bytes)
i8259x_HLREG0_LPBK	equ 16 ; Loopback Enable

; LINKS (Link Status Register; 0x042A4; RO)
i8259x_LINKS_LinkStatus	equ 7 ; 1 - Link is up
i8259x_LINKS_LINK_SPEED	equ 28 ; 0 - 1GbE, 1 - 10GbE - Bit 29 must be 1 for this to be valid
i8259x_LINKS_Link_Up	equ 30 ; 1 - Link is up

; FCTRL (Filter Control Register; 0x05080; RW) Bit Masks
i8259x_FCTRL_SBP	equ 1 ; Store Bad Packets
i8259x_FCTRL_MPE	equ 8 ; Multicast Promiscuous Enable
i8259x_FCTRL_UPE	equ 9 ; Unicast Promiscuous Enable
i8259x_FCTRL_BAM	equ 10 ; Broadcast Accept Mode

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
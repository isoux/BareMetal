; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2023 Return Infinity -- see LICENSE.TXT
;
; VMware SVGA II Adapter Driver
; =============================================================================


; -----------------------------------------------------------------------------
init_vmware:
	; Enable PCI Bus Mastering
	mov dl, 0x01			; Get Status/Command
	call os_pci_read
	or eax, 7
	call os_pci_write

	; Get the base I/O address of the device
	mov dl, 4			; Register 4 for BAR0
	xor eax, eax
	call os_pci_read		; This returns I/O BASE+1
	mov edx, eax			; Save for port access

	; Disable video
;	mov eax, SVGA_REG_ENABLE
;	dec dx				; Port value is initially pointed to VALUE
;	out dx, eax			; SVGA_INDEX
;	mov eax, 0
;	inc dx				; SVGA_VALUE
;	out dx, eax

	; Set spec ID
	mov eax, SVGA_REG_ID
	dec dx
	out dx, eax
	mov eax, 0x90000002
	inc dx
	out dx, eax

	; Read spec ID
	mov eax, SVGA_REG_ID
	dec dx
	out dx, eax
	inc dx
	in eax, dx
	cmp eax, 0x90000002
	jne init_vmware_fail
;	call os_debug_dump_eax
;	jmp $


	; Get FrameBuffer address
	mov eax, SVGA_REG_FB_START
	dec dx
	out dx, eax
	inc dx
	in eax, dx
	mov rbx, rax

	; Set X	
	mov eax, SVGA_REG_WIDTH
	dec dx
	out dx, eax
	mov ax, screen_x
	inc dx
	out dx, eax

	; Set Y
	mov eax, SVGA_REG_HEIGHT
	dec dx
	out dx, eax
	mov ax, screen_y
	inc dx
	out dx, eax

	; Set BPP
	mov eax, SVGA_REG_BPP
	dec dx
	out dx, eax
	mov ax, screen_bpp
	inc dx
	out dx, eax

	; Get FrameBuffer offset
	mov eax, SVGA_REG_FB_OFFSET
	dec dx
	out dx, eax
	inc dx
	in eax, dx
	call os_debug_dump_eax

	; Enable video
	mov eax, SVGA_REG_ENABLE
	dec dx
	out dx, eax
	mov eax, 1
	inc dx
	out dx, eax

	; Set kernel values
	mov qword [os_screen_lfb], rbx
	mov word [os_screen_x], screen_x
	mov word [os_screen_y], screen_y
	mov byte [os_screen_bpp], screen_bpp

init_vmware_fail:
	ret
; -----------------------------------------------------------------------------


; VMware Registers
SVGA_REG_ID				equ 0x00	; register used to negotiate specification ID
SVGA_REG_ENABLE				equ 0x01	; flag set by the driver when the device should enter SVGA mode
SVGA_REG_WIDTH				equ 0x02	; current screen width
SVGA_REG_HEIGHT				equ 0x03	; current screen height
SVGA_REG_MAX_WIDTH			equ 0x04	; maximum supported screen width
SVGA_REG_MAX_HEIGHT			equ 0x05	; maximum supported screen height
SVGA_REG_BPP				equ 0x07	; current screen bits per pixel
SVGA_REG_FB_START			equ 0x13	; address in system memory of the frame buffer
SVGA_REG_FB_OFFSET			equ 0x14	; offset in the frame buffer to the visible pixel data
SVGA_REG_VRAM_SIZE			equ 0x15	; size of the video RAM
SVGA_REG_FB_SIZE			equ 0x16	; size of the frame buffer
SVGA_REG_CAPABILITIES			equ 0x17	; device capabilities
SVGA_REG_FIFO_START			equ 0x18	; address in system memory of the FIFO
SVGA_REG_FIFO_SIZE			equ 0x19	; FIFO size
SVGA_REG_CONFIG_DONE			equ 0x20	; flag to enable FIFO operation
SVGA_REG_SYNC				equ 0x21	; flag set by the driver to flush FIFO changes
SVGA_REG_BUSY				equ 0x22	; flag set by the FIFO when it's processed


; BGA Values
VBE_DISPI_DISABLED			equ 0x00
VBE_DISPI_ENABLED			equ 0x01
VBE_DISPI_GETCAPS			equ 0x02	; For returning max when reading XRES, YRES, and BPP
VBE_DISPI_8BIT_DAC			equ 0x20
VBE_DISPI_LFB_ENABLED			equ 0x40
VBE_DISPI_NOCLEARMEM			equ 0x80


; =============================================================================
; EOF

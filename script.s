; Define PPU Registers
PPU_CONTROL = $2000 ; PPU Control Register 1 (Write)
PPU_MASK = $2001 ; PPU Control Register 2 (Write)
PPU_STATUS = $2002; PPU Status Register (Read)
PPU_SPRRAM_ADDRESS = $2003 ; PPU SPR-RAM Address Register (Write)
PPU_SPRRAM_IO = $2004 ; PPU SPR-RAM I/O Register (Write)
PPU_VRAM_ADDRESS1 = $2005 ; PPU VRAM Address Register 1 (Write)
PPU_VRAM_ADDRESS2 = $2006 ; PPU VRAM Address Register 2 (Write)
PPU_VRAM_IO = $2007 ; VRAM I/O Register (Read/Write)
SPRITE_DMA = $4014 ; Sprite DMA Register

; Define APU Registers
APU_DM_CONTROL = $4010 ; APU Delta Modulation Control Register (Write)
APU_CLOCK = $4015 ; APU Sound/Vertical Clock Signal Register (Read/Write)

; Joystick/Controller values
JOYPAD1 = $4016 ; Joypad 1 (Read/Write)
JOYPAD2 = $4017 ; Joypad 2 (Read/Write)

; Gamepad bit values
PAD_A      = $01
PAD_B      = $02
PAD_SELECT = $04
PAD_START  = $08
PAD_U      = $10
PAD_D      = $20
PAD_L      = $40
PAD_R      = $80

.segment "HEADER"
INES_MAPPER = 0 ; 0 = NROM
INES_MIRROR = 0 ; 0 = horizontal mirroring, 1 = vertical mirroring
INES_SRAM   = 0 ; 1 = battery backed SRAM at $6000-7FFF

.byte 'N', 'E', 'S', $1A ; ID 
.byte $02 ; 16k PRG bank count
.byte $01 ; 8k CHR bank count
.byte INES_MIRROR | (INES_SRAM << 1) | ((INES_MAPPER & $f) << 4)
.byte (INES_MAPPER & %11110000)
.byte $0, $0, $0, $0, $0, $0, $0, $0 ; padding

.segment "TILES"
.incbin "texture.chr"

.segment "ZEROPAGE"
nmi_ready:		.res 1 ; set to 1 to push a PPU frame update, 
					   ;        2 to turn rendering off next NMI
gamepad:		.res 1 ; stores the current gamepad values

d_x:			.res 1 ; x velocity of ball
d_y:			.res 1 ; y velocity of ball


.segment "VECTORS" ; Book up segments
.word nmi ; Not able to disable interupt. Its connected to the ppu
.word reset ; On start (When the reset button is pressed on the nes)
.word irq ; Request an interupt which we just disable.

.segment "OAM"
oam: .res 256

.segment "BSS"
palette: .res 32


.segment "CODE"
.proc nmi
    pha ; Push A X Y on the stack. Not P?
	txa
	pha
	tya
	pha

    lda nmi_ready
    bne continue
    jmp ppu_update_end

    ; Copy stuff in the ppu? Doesn;t really tell me what
continue:
    cmp #2
    bne cont_render
    lda #%00000000
    sta PPU_MASK
    ldx #0
    stx nmi_ready
    jmp ppu_update_end
cont_render:
    ldx #0
    stx PPU_SPRRAM_ADDRESS
    lda #>oam
    sta SPRITE_DMA

    lda #%10001000
    sta PPU_CONTROL
    lda PPU_STATUS
    lda #$3F
    sta PPU_VRAM_ADDRESS2
    stx PPU_VRAM_ADDRESS2
    ldx #0

loop:
    lda palette, x
    sta PPU_VRAM_IO
    inx
    cpx #32
    bcc loop

    lda #%00011110
    sta PPU_MASK
    ldx #0
    stx nmi_ready
ppu_update_end:
    pla
    tay
    pla
    tax
    pla
    rti
.endproc

.proc irq
    rti
.endproc


.proc reset
    sei ; disable interrupt BUT we never enable???
    lda #0 
    sta PPU_CONTROL ; Disable NMI? 
    sta PPU_MASK
    sta APU_DM_CONTROL ; Turns off the ppu and apu
    lda #$40
    sta JOYPAD2 ; Set up for the second controller port?

    cld ; clear decimal mode
    ldx #$FF
    tsx ; Dont know why we set the stack pointer to FF here?

wait_vblank:
	bit PPU_STATUS
	bpl wait_vblank

    ; Clear all the ram
    lda #0
    ldx #0
    clear_ram:
    sta $0000,x
    sta $0100,x ; Are we clearing the stack?
    sta $0200,x
    sta $0300,x
    sta $0400,x
    sta $0500,x
    sta $0600,x
    sta $0700,x
    inx ; does this change the negative flag???
    bne clear_ram

    lda #255
    ldx #0
    clear_oam:
    sta oam,x
    inx
    inx
    inx
    inx ; every 4 bytes we change something
    bne clear_oam


    ; We do anything wait check?
wait_vblank2:
    bit PPU_STATUS
    bpl wait_vblank2


    lda #%10001000
    sta PPU_CONTROL ; Enable NMI
    jmp main
.endproc

.proc main

    ldx #0
paletteloop:
    lda default_palette, x
    sta palette, x
    inx
    cpx #32
    bcc paletteloop
    jsr clear_nametable

    lda PPU_STATUS
    lda #$20
    sta PPU_VRAM_ADDRESS2
    lda #$8A
    sta PPU_VRAM_ADDRESS2

    ; ldx #0
    ; textloop:
    ; lda welcome_txt, x
    ; sta PPU_VRAM_IO
    ; inx
    ; cmp #0
    ; beq :+
    ; jmp textloop
    ; :

    lda #180
    sta oam
    lda #120
    sta oam + 3
    lda #1
    sta oam + 1
    lda #0
    sta oam + 2

    lda #1
    sta d_x
    sta d_y

    jsr ppu_update

mainloop:
 	; skip reading controls if and change has not been drawn
 	lda nmi_ready
 	cmp #0
 	bne mainloop

    jsr gamepad_poll


    lda gamepad
    and #PAD_L
    beq NOT_GAMEPAD_LEFT
        lda oam + 3
        cmp #0
        beq NOT_GAMEPAD_LEFT
        sec
        sbc #1
        sta oam + 3

NOT_GAMEPAD_LEFT:
    lda gamepad
    and #PAD_R
    beq NOT_GAMEPAD_RIGHT
        lda oam + 3
        ; cmp #248
        ; beq NOT_GAMEPAD_RIGHT ; FREE OVERFLOW
        clc
        adc #1
        sta oam + 3
NOT_GAMEPAD_RIGHT:
    lda gamepad
    and #PAD_U
    beq NOT_GAMEPAD_UP
        lda oam
        cmp #0
        beq NOT_GAMEPAD_UP
        sec
        sbc #1
        sta oam
NOT_GAMEPAD_UP:

    lda gamepad
    and #PAD_D
    beq NOT_GAMEPAD_DOWN
        lda oam
        cmp #230
        beq NOT_GAMEPAD_DOWN
        clc
        adc #1
        sta oam
NOT_GAMEPAD_DOWN:


 	; ensure our changes are rendered
 	lda #1
 	sta nmi_ready
 	jmp mainloop

.endproc

; ppu_update: waits until next NMI and turns rendering on (if not already)
.proc ppu_update
    lda #1
    sta nmi_ready
    loop:
    lda nmi_ready
    bne loop
    rts
.endproc

; Dont we need also an function to turn it back on?
.proc ppu_off
    lda #2
    sta nmi_ready
    loop:
    lda nmi_ready
    bne loop
    rts
.endproc

; No clue what this does
.proc clear_nametable
 	lda PPU_STATUS ; reset address latch
 	lda #$20 ; set PPU address to $2000
 	sta PPU_VRAM_ADDRESS2
 	lda #$00
 	sta PPU_VRAM_ADDRESS2

 	; empty nametable
 	lda #0
 	ldy #30 ; clear 30 rows
 	rowloop:
 		ldx #32 ; 32 columns
 		columnloop:
 			sta PPU_VRAM_IO
 			dex
 			bne columnloop
 		dey
 		bne rowloop

 	; empty attribute table
 	ldx #64 ; attribute table is 64 bytes
 	loop:
 		sta PPU_VRAM_IO
 		dex
 		bne loop
 	rts
.endproc

.proc gamepad_poll
    lda #1
    sta JOYPAD1
    lda #0
    sta JOYPAD1
    ldx #8
    loop:
    pha
    lda JOYPAD1
    and #%00000011
    cmp #%00000001
    pla
    ror
    dex
    bne loop
    sta gamepad
    rts
.endproc


.segment "RODATA"
default_palette:
.byte $0F,$15,$26,$37 ; bg0 purple/pink
.byte $0F,$09,$19,$29 ; bg1 green
.byte $0F,$01,$11,$21 ; bg2 blue
.byte $0F,$00,$10,$30 ; bg3 greyscale
.byte $0F,$18,$28,$38 ; sp0 yellow
.byte $0F,$14,$24,$34 ; sp1 purple
.byte $0F,$1B,$2B,$3B ; sp2 teal
.byte $0F,$12,$22,$32 ; sp3 marine

welcome_txt:
.byte 'W','E','L','C', 'O', 'M', 'E', 0
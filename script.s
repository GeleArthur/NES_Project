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
.byte $0

.segment "VECTORS"
.word nmi
.word reset
.word irq

.segment "OAM"
oam: .res 256

.segment "BSS"
palette: .res 32


.segment "CODE"
.proc nmi
    rti
.endproc

.proc irq
    rti
.endproc

COUNTER = $0A

.proc reset

    lda #%00001010
    and #%00000111
    sta COUNTER
    asl A
    sta COUNTER+1

    sec
    bcc reset
    clc
    BCS reset
    bit COUNTER+1
    BEQ reset

    lda #$00
    BMI reset
    BNE reset
    lda #$FF
    BPL reset

    lda #%01000000
    sta $00
    bit $00
    BVC reset
    CLV
    BVS reset

    sed
    cld ; Clear decimal

    SEI
    cli

    INX
    DEX
    INY
    DEY

    jmp jumpToMe
    CPX $0
    CPY $0
    DEC $00
    EOR $FF
    RTS

jumpToMe:
    LSR A
    NOP
    NOP
    NOP
    NOP
    ORA $FF

    PHA
    PHP
    PLP
    PLA

    ROL A
    ROR A
    SBC $55
    
    stx $05
    sty $07

    TAX
    TAY
    TSX
    TXA
    TXS
    TYA
    
    jsr Add10


    BRK
.endproc

.proc Add10
    lda COUNTER, X
    clc
    adc #20
    sta COUNTER, X
    inx
    txa
    CMP #10
    bmi Add10
    rts
.endproc
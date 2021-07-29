; BASIC loader
* = $0801
                BYTE $0E, $08, $0A, $00, $9E, $20, $28,  $34, $30, $39, $36, $29, $00, $00, $00

; Check for key press
defm            check_key
                lda $cb  ; Current key pressed
                cmp #/1
                bne @not_pressed
                lda #1
                jmp @check_key_done
@not_pressed    lda #0
@check_key_done nop
endm

; Compare a 16 bit number for equality to another 16 bit number
defm            compare_numbers
                ; Check MSBs first
                lda /2
                cmp /4
                bcs @eq_gt1
                ; MSB 1 < MSB 2
                lda #2
                jmp @check_done
@eq_gt1         bne @gt
                ; MSBs are equal, now compare LSBs
                lda /1
                cmp /3
                bcs @eq_gt2
                ; MSB 1 = MSB 2, LSB 1 < LSB 2
                lda #2
                jmp @check_done
@eq_gt2         bne @gt
                ; MSBs and LSBs are equal
                lda #0
                jmp @check_done
@gt             lda #1
@check_done     nop
endm

; Decrement a 16 bit number
defm            decrement_number
                lda /1
                bne @skip
                dec /1 + 1
@skip           dec /1
endm

; Increment a 16 bit number
defm            increment_number
                lda /1
                cmp #255
                bne @skip
                inc /1 + 1
@skip           inc /1
endm

; Update X display
defm            update_x_disp
                ldx #0    ; row
                ldy #0    ; column
                clc       ; clc = update position, sec = get position
                jsr POSCURS
                ldx player_x
                lda player_x + 1
                jsr NUMOUT
endm

; Update Y display
defm            update_y_disp
                ldx #0    ; row
                ldy #6    ; column
                clc       ; clc = update position, sec = get position
                jsr POSCURS
                ldx player_y
                lda player_y + 1
                jsr NUMOUT
endm

; Program starts at $1000
* = $1000

; KERNAL functions
NUMOUT = $bdcd
CHROUT = $ffd2
POSCURS = $fff0
KERNAL_ISR = $ea31

; Constants
MAP_X_MAX_LO = 255
MAP_X_MAX_HI = 3
MAP_Y_MAX_LO = 255
MAP_Y_MAX_HI = 3
VIEWPORT_L = 14
VIEWPORT_R = 15
VIEWPORT_U = 10
VIEWPORT_D = 11

; Configure screen colors and clear screen, display initial position
                lda #0
                sta $d020
                sta $d021
                lda #$93
                jsr CHROUT
                update_x_disp
                update_y_disp

; Setup raster line-based interrupt structure
                lda #$7f
                sta $dc0d
                lda $dc0d
                sei
                lda #1
                sta $d01a
                lda #60
                sta $d012
                lda $d011
                and #$7f
                sta $d011
                lda #<mainloop
                sta $0314
                lda #>mainloop
                sta $0315
                cli
setup_done      jmp setup_done

; Main loop (raster line-based interrupt handler)
mainloop
                inc $d019 ; ACK interrupt
                inc int_counter
                lda int_counter
                cmp #3
                beq our_isr
                jmp KERNAL_ISR

our_isr         inc $d020 ; Change border color to show time spent in loop
                lda #0    ; Reset int_counter
                sta int_counter

                ; Process key presses
check_w         check_key 9
                cmp #1
                bne check_s
                compare_numbers player_y, player_y + 1, #0, #0
                cmp #0
                beq check_s
                decrement_number player_y
                jsr reset_y_disp
                update_y_disp
                jmp calc_viewport

check_s         check_key 13
                cmp #1
                bne check_a
                compare_numbers player_y, player_y + 1, #MAP_Y_MAX_LO, #MAP_Y_MAX_HI
                cmp #0
                beq check_a
                increment_number player_y
                update_y_disp
                jmp calc_viewport

check_a         check_key 10
                cmp #1
                bne check_d
                compare_numbers player_x, player_x + 1, #0, #0
                cmp #0
                beq check_d
                decrement_number player_x
                jsr reset_x_disp
                update_x_disp
                jmp calc_viewport

check_d         check_key 18
                cmp #1
                bne calc_viewport
                compare_numbers player_x, player_x + 1, #MAP_X_MAX_LO, #MAP_X_MAX_HI
                cmp #0
                beq calc_viewport
                increment_number player_x
                update_x_disp

                ; Calculate viewport coordinates
calc_viewport   compare_numbers player_x, player_x + 1, #VIEWPORT_L, #0
                cmp #1
                beq @x_gt
                cmp #2
                beq @x_lt
                ; Equal
                lda #69
                ldx #2
                ldy #0
                jsr print_char
                jmp done_calc_vp
@x_gt           lda #71
                ldx #2
                ldy #0
                jsr print_char
                jmp done_calc_vp
@x_lt           lda #76
                ldx #2
                ldy #0
                jsr print_char
done_calc_vp

                ; Bottom of main loop
                dec $d020
                jmp KERNAL_ISR ; Regular interrupt handling

player_x        BYTE 0, 0
player_y        BYTE 0, 0

viewport_x1     BYTE 0, 0
viewport_y1     BYTE 0, 0
viewport_x2     BYTE 0, 0
viewport_y2     BYTE 0, 0

temp            BYTE 0, 0, 0

int_counter     BYTE 0

; Print a character (X = row, Y = col, A = character)
print_char      clc ; clc = update position, sec = get position
                sta temp + 0
                stx temp + 1
                sty temp + 2
                jsr POSCURS
                lda temp + 0
                ldx temp + 1
                ldy temp + 2
                jsr CHROUT
                lda temp + 0
                ldx temp + 1
                ldy temp + 2
                rts

; Reset X display
reset_x_disp    lda #32
                ldx #0
                ldy #0
                jsr print_char
                iny
                jsr print_char
                iny
                jsr print_char
                iny
                jsr print_char
                rts

; Reset Y display
reset_y_disp    lda #32
                ldx #0
                ldy #6
                jsr print_char
                iny
                jsr print_char
                iny
                jsr print_char
                iny
                jsr print_char
                rts
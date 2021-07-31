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
                lda #$01
                sta $286
                lda #$93
                jsr CHROUT
                update_x_disp
                update_y_disp
                jsr update_x_vp
                jsr update_y_vp

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
                jsr move_vp_up
                jmp mainloop_end

check_s         check_key 13
                cmp #1
                bne check_a
                compare_numbers player_y, player_y + 1, #MAP_Y_MAX_LO, #MAP_Y_MAX_HI
                cmp #0
                beq check_a
                increment_number player_y
                update_y_disp
                jsr move_vp_down
                jmp mainloop_end

check_a         check_key 10
                cmp #1
                bne check_d
                compare_numbers player_x, player_x + 1, #0, #0
                cmp #0
                beq check_d
                decrement_number player_x
                jsr reset_x_disp
                update_x_disp
                jsr move_vp_left
                jmp mainloop_end

check_d         check_key 18
                cmp #1
                bne mainloop_end
                compare_numbers player_x, player_x + 1, #MAP_X_MAX_LO, #MAP_X_MAX_HI
                cmp #0
                beq mainloop_end
                increment_number player_x
                update_x_disp
                jsr move_vp_right

                ; Bottom of main loop
mainloop_end    dec $d020
                jmp KERNAL_ISR ; Regular interrupt handling

player_x        BYTE 50, 0
player_y        BYTE 50, 0

viewport_x1     BYTE 50 - VIEWPORT_L, 0
viewport_y1     BYTE 50 - VIEWPORT_U, 0
viewport_x2     BYTE 50 + VIEWPORT_R, 0
viewport_y2     BYTE 50 + VIEWPORT_D, 0

temp            BYTE 0, 0, 0

int_counter     BYTE 0

inclusive       BYTE 0

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

; Are we in the far left side of the screen?
check_far_left  compare_numbers player_x, player_x + 1, #VIEWPORT_L, #0
                cmp #1
                beq @x_gt
                cmp #2
                beq @x_lt
                ; Equal
                lda inclusive ; Whether or not in far left side of screen is contextual
                rts
@x_gt           lda #0 ; Not in far left side of screen
                rts
@x_lt           lda #1 ; In far left side of screen
                rts

; Are we in the far right side of the screen?
check_far_right compare_numbers player_x, player_x + 1, #MAP_X_MAX_LO-VIEWPORT_R, #MAP_X_MAX_HI
                cmp #1
                beq @x_gt
                cmp #2
                beq @x_lt
                ; Equal
                lda inclusive ; Whether or not in far right side of screen is contextual
                rts
@x_gt           lda #1 ; In far right side of screen
                rts
@x_lt           lda #0 ; Not in far right side of screen
                rts

; Are we in the far top side of the screen?
check_far_top   compare_numbers player_y, player_y + 1, #VIEWPORT_U, #0
                cmp #1
                beq @y_gt
                cmp #2
                beq @y_lt
                ; Equal
                lda inclusive ; Whether or not in far upper side of screen is contextual
                rts
@y_gt           lda #0 ; Not in far upper side of screen
                rts
@y_lt           lda #1 ; In far upper side of screen
                rts

; Are we in the far bottom side of the screen?
check_far_btm   compare_numbers player_y, player_y + 1, #MAP_Y_MAX_LO-VIEWPORT_D, #MAP_Y_MAX_HI
                cmp #1
                beq @y_gt
                cmp #2
                beq @y_lt
                ; Equal
                lda inclusive ; Whether or not in far bottom side of screen is contextual
                rts
@y_gt           lda #1 ; In far bottom side of screen
                rts
@y_lt           lda #0 ; Not in far bottom side of screen
                rts

; Move viewport left
move_vp_left    lda #0
                sta inclusive
                jsr check_far_left
                bne @nomove
                lda #1
                sta inclusive
                jsr check_far_right
                bne @nomove
@move           lda viewport_x1
                bne @skip1
                dec viewport_x1 + 1
@skip1          dec viewport_x1
                lda viewport_x2
                bne @skip2
                dec viewport_x2 + 1
@skip2          dec viewport_x2
                jsr update_x_vp
@nomove         rts

; Move viewport right
move_vp_right   lda #1
                sta inclusive
                jsr check_far_left
                bne @nomove
                lda #0
                sta inclusive
                jsr check_far_right
                bne @nomove
@move           lda viewport_x1
                cmp #255
                bne @skip1
                inc viewport_x1 + 1
@skip1          inc viewport_x1
                lda viewport_x2
                cmp #255
                bne @skip2
                inc viewport_x2 + 1
@skip2          inc viewport_x2
                jsr update_x_vp
@nomove         rts

; Move viewport up
move_vp_up      lda #0
                sta inclusive
                jsr check_far_top
                bne @nomove
                lda #1
                sta inclusive
                jsr check_far_btm
                bne @nomove
@move           lda viewport_y1
                bne @skip1
                dec viewport_y1 + 1
@skip1          dec viewport_y1
                lda viewport_y2
                bne @skip2
                dec viewport_y2 + 1
@skip2          dec viewport_y2
                jsr update_y_vp
@nomove         rts

; Move viewport down
move_vp_down    lda #1
                sta inclusive
                jsr check_far_top
                bne @nomove
                lda #0
                sta inclusive
                jsr check_far_btm
                bne @nomove
@move           lda viewport_y1
                cmp #255
                bne @skip1
                inc viewport_y1 + 1
@skip1          inc viewport_y1
                lda viewport_y2
                cmp #255
                bne @skip2
                inc viewport_y2 + 1
@skip2          inc viewport_y2
                jsr update_y_vp
@nomove         rts

; Update X viewport display
update_x_vp     ; Reset display
                lda #32
                ldx #2 ; Row
                ldy #0 ; Col
                jsr print_char
                iny
                jsr print_char
                iny
                jsr print_char
                iny
                jsr print_char
                ldx #3 ; Row
                ldy #0 ; Col
                jsr print_char
                iny
                jsr print_char
                iny
                jsr print_char
                iny
                jsr print_char
                ; Update display
                ldx #2    ; row
                ldy #0    ; column
                clc       ; clc = update position, sec = get position
                jsr POSCURS
                ldx viewport_x1
                lda viewport_x1 + 1
                jsr NUMOUT
                ldx #3    ; row
                ldy #0    ; column
                clc       ; clc = update position, sec = get position
                jsr POSCURS
                ldx viewport_x2
                lda viewport_x2 + 1
                jsr NUMOUT
                rts

; Update Y viewport display
update_y_vp     ; Reset display
                lda #32
                ldx #2 ; Row
                ldy #6 ; Col
                jsr print_char
                iny
                jsr print_char
                iny
                jsr print_char
                iny
                jsr print_char
                ldx #3 ; Row
                ldy #6 ; Col
                jsr print_char
                iny
                jsr print_char
                iny
                jsr print_char
                iny
                jsr print_char
                ; Update display
                ldx #2    ; row
                ldy #6    ; column
                clc       ; clc = update position, sec = get position
                jsr POSCURS
                ldx viewport_y1
                lda viewport_y1 + 1
                jsr NUMOUT
                ldx #3    ; row
                ldy #6    ; column
                clc       ; clc = update position, sec = get position
                jsr POSCURS
                ldx viewport_y2
                lda viewport_y2 + 1
                jsr NUMOUT
                rts
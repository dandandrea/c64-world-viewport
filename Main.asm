; BASIC loader
* = $0801
                BYTE $0E, $08, $0A, $00, $9E, $20, $28,  $34, $30, $39, $36, $29, $00, $00, $00

; Check for key press
defm            check_key
                lda $00cb  ; Current key pressed
                cmp #/1
                bne @not_pressed
                lda #1
                jmp @check_key_done
@not_pressed    lda #0
@check_key_done sta /2
endm

; Check a 16 bit number for equality to another 16 bit number
defm            compare_numbers
                lda /1
                cmp #/2
                bne @not_equal
                lda /1 + 1
                cmp #/3
                bne @not_equal
                lda #1
                jmp @check_done
@not_equal      lda #0
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

; Busy wait
defm            busy_wait
                ldx #/1
@main           ldy #0
@yloop          dey
                bne @yloop
                dex
                bne @main
endm

; Print a character at a given row and column
defm            print_char
                ldx #/1
                ldy #/2
                clc       ; clc = update position, sec = get position
                jsr $fff0 ; "Position cursor" KERNAL function
                lda #/3
                jsr CHROUT
endm

; Update X display
defm            update_x_disp
                ldx #0    ; row
                ldy #0    ; column
                clc       ; clc = update position, sec = get position
                jsr $fff0 ; "Position cursor" KERNAL function
                ldx player_x
                lda player_x + 1
                jsr NUMOUT
endm

; Update Y display
defm            update_y_disp
                ldx #0    ; row
                ldy #6    ; column
                clc       ; clc = update position, sec = get position
                jsr $fff0 ; "Position cursor" KERNAL function
                ldx player_y
                lda player_y + 1
                jsr NUMOUT
endm

; Program starts at $1000
* = $1000

MAP_X_MAX_LO = 255
MAP_X_MAX_HI = 3
MAP_Y_MAX_LO = 255
MAP_Y_MAX_HI = 3
NUMOUT = $bdcd
CHROUT = $ffd2

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
                inc $d020 ; Change border color to show time spent in loop

                ; Check for key presses
                check_key 9,  w_pressed
                check_key 10, a_pressed
                check_key 13, s_pressed
                check_key 18, d_pressed

                ; Process key presses
check_w         lda w_pressed
                cmp #1
                bne check_s
                compare_numbers player_y, 0, 0
                cmp #1
                beq check_s
                decrement_number player_y
                print_char 0, 6, 32
                print_char 0, 7, 32
                print_char 0, 8, 32
                print_char 0, 9, 32
                update_y_disp
                ; busy_wait 250

check_s         lda s_pressed
                cmp #1
                bne check_a
                compare_numbers player_y, MAP_Y_MAX_LO, MAP_Y_MAX_HI
                cmp #1
                beq check_a
                increment_number player_y
                update_y_disp
                ; busy_wait 250

check_a         lda a_pressed
                cmp #1
                bne check_d
                compare_numbers player_x, 0, 0
                cmp #1
                beq check_d
                decrement_number player_x
                print_char 0, 0, 32
                print_char 0, 1, 32
                print_char 0, 2, 32
                print_char 0, 3, 32
                update_x_disp
                ; busy_wait 250

check_d         lda d_pressed
                cmp #1
                bne done_checking
                compare_numbers player_x, MAP_X_MAX_LO, MAP_X_MAX_HI
                cmp #1
                beq done_checking
                increment_number player_x
                update_x_disp
                ; busy_wait 250

                ; Bottom of main loop
done_checking   dec $d020
                jmp $ea31 ; Regular interrupt handling

player_x        BYTE 0, 0
player_y        BYTE 0, 0

w_pressed       BYTE 0
a_pressed       BYTE 0
s_pressed       BYTE 0
d_pressed       BYTE 0
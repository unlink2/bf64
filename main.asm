.define BSOUT $FFD2 ; prints A to screen
.define BASIN $FFCF ; reads one char to A
.define BASIC_MEMORY $0801 ; start of basic memory

.define DATA_AREA $C000 ; bf data area

.enum $FB ; start of ok to use zero page addresses
inst_ptr 2
data_ptr 2
next_inst 1 ; next instruction to parse, if 00 terminate
loop_depth 1 ; how many loops deep are we? used for search of ] or [
temp 2 ; temp storage
repl_flag 1 ; repl flag set to 00 to start repl, do not move!
.ende

.db #<BASIC_MEMORY, #>BASIC_MEMORY ; ptr to next basic line
.org BASIC_MEMORY

; a very simple basic program that jumps to the start of machine code
.db $0c, $08, $00, $00, $9e ; 10 sys
.db "2063", $00, $00, $00 ; the actual address in petscii


.org $080D ; address after basic
bfcode_ptr: ; do not move this label!
.db #<bfcode, #>bfcode ; start address of code, can be poked

init:
    cld ; not decimal mode

    ldy #$FF
    lda #$00
@clear_loop:
    sta DATA_AREA, y
    sta DATA_AREA+$FF, y
    sta DATA_AREA+$1FF, y
    dey
    cpy #$FF
    bne @clear_loop

    ; init ptr to data
    lda #<DATA_AREA
    sta data_ptr
    lda #>DATA_AREA
    sta data_ptr+1

    lda bfcode_ptr
    sta inst_ptr
    lda bfcode_ptr+1
    sta inst_ptr+1

    lda #$00
    sta loop_depth ; 0 loop depth

    lda repl_flag  ; repl mode if 0
    beq @repl

    jsr parse_loop
    rts ; exit back to basic
@repl:
    jsr repl
    rts ; back to basic

; loops through inst_ptr until $00 is reached
; inputs:
;   set up inst_ptr and data_ptr
; side effects:
;   executes bf program
parse_loop:
    ldy #$00
    lda (inst_ptr), y ; next instruction
    sta next_inst
    beq @done ; if next is 0 we exit

    lda repl_flag ; output debug if flag is set
    and #%10000000
    beq @no_out
    lda next_inst
    jsr BSOUT
@no_out:

    jsr parse_inst
    ; next instruction
    lda #$01
    jsr inc_inst_ptr
    jmp parse_loop ; next
@done:
    rts

; if repl mode is chosen user input is code
repl:
    ldy #$00
    jsr BASIN ; get next
    sta next_inst
    sta (inst_ptr), y
    beq @done
    cmp #'E'
    beq @done

    ; jsr parse_inst
    ; next instruction
    lda #$01
    jsr inc_inst_ptr
    jmp repl
@done:
    ; set last byte to 0
    lda #$00
    sta (inst_ptr), y
    rts

; increments isntruction ptr by a
inc_inst_ptr:
    sta temp
    lda inst_ptr
    clc
    adc temp
    sta inst_ptr
    lda inst_ptr+1
    adc #$00
    sta inst_ptr+1
    rts

; decrements instruction ptr by a
dec_inst_ptr:
    sta temp
    lda inst_ptr
    sec
    sbc temp
    sta inst_ptr
    lda inst_ptr+1
    sbc #$00
    sta inst_ptr+1
    rts

; increments data ptr by a
; inputs:
;   a
; side effects:
;   increments data ptr
inc_data_ptr:
    sta temp
    lda data_ptr
    clc
    adc temp
    sta data_ptr
    lda data_ptr+1
    adc #$00
    sta data_ptr+1
    rts

; decrements data ptr by a
; inputs:
;   a
; side effects:
;   decrements data ptr
dec_data_ptr:
    sta temp
    lda data_ptr
    sec
    sbc temp
    sta data_ptr
    lda data_ptr+1
    sbc #$00
    sta data_ptr+1
    rts

; reads a value from data ptr
; returns:
;   value in a
; side effects:
;   uses a and y
read_data_ptr:
    ldy #$00
    lda (data_ptr), y
    rts

; stores value in data ptr
; inputs:
;   a -> value to stroe
; side effects:
;   overwrites data_ptr
write_data_ptr:
    ldy #$00
    sta (data_ptr), y
    rts

; open loop statement [
; side effects:
;   uses x, y and a
;   modifies inst_ptr if required
open_loop:
    ldy #$00
    ldx #$00 ; depth counter
    lda (data_ptr), y
    bne @done ; if not 0 do nothing

    inx ; 1 loop depth

@find_closed:
    ; if 0 find exit statement
    lda #$01
    jsr inc_inst_ptr
    lda (inst_ptr), y

    cmp #'['
    bne @not_open ; did not open antother loop
    ; if did open a loop inc loop depth
    inx ; +1 depth
@not_open:

    cmp #']' ; close symbol
    bne @not_closed
    dex ; -1 depth
@not_closed:
    ; is loop depth zero?
    cpx #$00
    bne @find_closed

@done:
    rts

; close loop statement ]
; side effects:
;   uses x, y and a
;   modifies inst_ptr if required
close_loop:
    ldy #$00
    ldx #$00 ; depth counter
    lda (data_ptr), y
    beq @done ; if 0 do nothing

    inx ; 1 loop depth

@find_open:
    lda #$01
    jsr dec_inst_ptr
    lda (inst_ptr), y

    cmp #']' ; another close
    bne @not_closed
    inx ; depth +1
@not_closed:

    cmp #'[' ; open?
    bne @not_open
    dex ; depth -1
@not_open:
    ; is loop depth zero?
    cpx #$00
    bne @find_open

@done:
    rts

; parse a single bf instruction, ignore all invalid characters
; inputs:
;   next_inst -> instruction
; side effects:
;   executes instruction
parse_inst:
    ; simple switch case
    lda next_inst
    cmp #'>'
    bne @not_inc_data_ptr
    lda #$01
    jsr inc_data_ptr
    rts

@not_inc_data_ptr:
    cmp #'<'
    bne @not_dec_data_ptr
    lda #$01
    jsr dec_data_ptr
    rts

@not_dec_data_ptr:

    cmp #'+'
    bne @not_inc_data
    jsr read_data_ptr
    clc
    adc #$01
    jsr write_data_ptr
    rts

@not_inc_data:

    cmp #'-'
    bne @not_dec_data
    jsr read_data_ptr
    sec
    sbc #$01
    jsr write_data_ptr
    rts

@not_dec_data:

    cmp #'.'
    bne @not_out

    jsr read_data_ptr
    jsr BSOUT
    rts

@not_out:
    cmp #','
    bne @not_in

    jsr BASIN
    jsr write_data_ptr
    rts

@not_in:

    cmp #'['
    bne @not_loop_open
    jsr open_loop
    rts

@not_loop_open:
    cmp #']'
    bne @not_loop_close
    jsr close_loop
    rts 

@not_loop_close:
    rts 

bfcode:
.incbin "./test.bf"
.db #$00 ; terminate bf program with \0

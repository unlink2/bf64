.define BSOUT $FFD2 ; prints A to screen
.define BASIN $FFCF ; reads one char to A
.define BASIC_MEMORY $0801 ; start of basic memory

; file commands
.define CLOSE $F291 ; close file
.define OPEN $F34A ; open file
.define SETLFS $FE00 ; set file parameters
.define SETNAME $FDF9 ; set file name
.define CHKIN $F20E ; set file as stdin
.define CHKOUT $F250 ; set file as stdout
.define CLRCHN $F333 ; close file and restore stdin/stdout to keyboard/screen

.define DATA_AREA $C000 ; bf data area
.define FILE_NAME_LEN 8

.enum $02
temp_ptr 2 ; used as pointer to anything useful
.ende

.enum $FB ; start of ok to use zero page addresses
inst_ptr 2
data_ptr 2
next_inst 1 ; next instruction to parse, if 00 terminate
loop_depth 1 ; how many loops deep are we? used for search of ] or [
temp 2 ; temp storage
; repl flag
; possible values:
;   00 -> code input mode
;   7th bit = 1 -> output current instruction during execution
;   6th bit = 1 -> ouput program
;
;
;   the following file commands requires the user to set up file_name, flogical, fsecondary and fdevice
;   5th bit = 1 -> set file as input
;   4th bit = 1 -> set file as output
;   3rd bit = 1 -> load prg from file to bfcode_ptr
;   2nd bit = 1 -> save bfcode_ptr contents to file until \0
;
;   1st bit -> execute code
repl_flag 1 ; repl flag set to 00 to start repl, do not move!
file_name FILE_NAME_LEN ; current filename
flogical 1 ; logical number
fdevice 1  ; device number
fsecondary 1 ; secondary address
.ende

.db #<BASIC_MEMORY, #>BASIC_MEMORY ; ptr to next basic line
.org BASIC_MEMORY

; a very simple basic program that jumps to the start of machine code
.db $0c, $08, $00, $00, $9e ; 10 sys
.db "2065", $00, $00, $00 ; the actual address in petscii


.org $080D ; address after basic
bfcode_ptr: ; do not move this label!
.db #<bfcode, #>bfcode ; start address of code, can be poked
bfdata_ptr: ; do not move this label!
.db #<DATA_AREA, #>DATA_AREA

init:
    cld ; not decimal mode

    ; init ptr to data
    lda bfdata_ptr
    sta data_ptr
    lda bfdata_ptr+1
    sta data_ptr+1

    ldy #$FF
    lda #$00
@clear_loop:
    sta (data_ptr), y
    sta DATA_AREA, y
    sta DATA_AREA+$FF, y
    sta DATA_AREA+$1FF, y
    dey
    cpy #$FF
    bne @clear_loop


    lda bfcode_ptr
    sta inst_ptr
    lda bfcode_ptr+1
    sta inst_ptr+1

    lda #$00
    sta loop_depth ; 0 loop depth

    ; check if stdin/stdout are to be redirected
    lda repl_flag
    and #%000100000
    beq @not_stdin
    jsr open_file_read
@not_stdin:
    lda repl_flag
    and #%00001000
    beq @not_stdout
    jsr open_file_write
@not_stdout:

    lda repl_flag  ; repl mode if 0
    beq @repl
    and #%00000001 ; exec check
    bne @exec
    lda repl_flag
    and #%01000000 ; print check
    bne @put_prg

    lda repl_flag
    and #%00000100 ; load file
    bne @load_prg

    lda repl_flag
    and #%00000010 ; save prg
    bne @save_prg

@exec:
    jsr parse_loop
    jmp clean_up

@repl:
    jsr repl
    jmp clean_up

@put_prg:
    jsr put_prg
    jmp clean_up

@load_prg:
    ldx #<loading_str
    ldy #>loading_str
    jsr put_str

    jsr open_file_read
    jsr load_prg
    jmp clean_up

@save_prg:
    ldx #<saving_str
    ldy #>saving_str
    jsr put_str

    jsr open_file_write
    jsr save_prg

clean_up:
    ; restore stdin/stdout
    jsr close_file
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

; outputs the program stored at inst_ptr until \0 is reached
put_prg:
    ldx #$00 ; counter for input wait
@loop:
    ldy #$00
    lda (inst_ptr), y
    beq @done

    jsr BSOUT

    lda #$01
    jsr inc_inst_ptr

    inx ;
    cpx #$FF
    bne @no_wait
    JSR BASIN ; wait for input
    ldx #$00
@no_wait:
    jmp @loop
@done:
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

; sets up a file
; inputs:
;   file_name, fdevice, flogical, fsecondary
setup_file:
    lda flogical
    ldx fdevice
    ldy fsecondary
    jsr SETLFS ; set file parameters

    lda #FILE_NAME_LEN
    ldx #<file_name
    ldy #>file_name
    jsr SETNAME

    rts

; this sub routine computes the lenght of a program pointed to by
; bfcode_ptr
; returns:
;   x -> bytes lo
;   y -> bytes hi
prg_len:
    lda bfcode_ptr
    sta temp_ptr
    lda bfcode_ptr+1
    sta temp_ptr
    ldy #$00
    sty temp ; zero out counter
    sty temp+1
@calc_loop:
    lda (temp_ptr), y
    beq @done
    ; inc counter
    lda temp
    clc
    adc #$01
    sta temp
    lda temp+1
    adc #$00
    sta temp+1

    ; inc ptr
    lda temp_ptr
    clc
    adc #$01
    sta temp_ptr
    lda temp_ptr+1
    adc #$00
    sta temp_ptr+1

    jmp @calc_loop
@done:
    ldx temp ; return values
    ldy temp+1
    rts

; this sub routine opens a file for reading
; and sets it as stdin
; inputs:
;   file_name, fdevice, flogical, fsecondary
open_file_read:
    jsr setup_file
    ldx flogical
    jsr CHKIN
    rts

; this sub rotuine opens a file for writing
; and sets it as stdout
; inputs:
;   file_name, fdevice, flogical, fsecondary
open_file_write:
    jsr setup_file
    ldx flogical
    jsr CHKOUT
    rts 

; closes a file that was set as stdin/stdout
; inputs:
;   flogical
close_file:
    jsr CLRCHN

    rts

; this sub rotuine reads
; bytes from a file until it reads 0
; stores read values in bfcode_ptr
load_prg:
    lda bfcode_ptr
    sta temp_ptr
    lda bfcode_ptr+1
    sta temp_ptr+1

@loop:
    jsr BASIN ; read next byte
    cmp #$00
    beq @done

    ldy #$00
    sta (temp_ptr), y

    ; next ptr address
    lda temp_ptr
    clc
    adc #$01
    sta temp_ptr
    lda temp_ptr+1
    adc #$00
    sta temp_ptr+1

    jmp @loop
@done:
    ldy #$00
    sta (temp_ptr), y ; a is 0, store it now
    rts

; this sub routine writes
; a program to stdou
; a program to stdoutt
save_prg:
    lda inst_ptr
    pha
    lda inst_ptr+1
    pha
    jsr put_prg
    pla
    sta inst_ptr+1
    pla
    sta inst_ptr
    rts

; prints a string that is \0 terminated
; inputs:
;   x/y ptr to string
put_str:
    stx temp_ptr
    sty temp_ptr+1
    ldy #$00
@loop:
    lda (temp_ptr), y
    beq @done
    jsr BSOUT
    jmp @loop
@done:
    rts 

loading_str:
.db "Loading..."
saving_str:
.db "Saving..."

bfcode:
.incbin "./test.bf"
.db #$00 ; terminate bf program with \0

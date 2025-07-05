; Important Concepts
; ------------------
; This example extends the 005-copper-colour-table with an animation.
;
; The Copper list (or parts of it) can be generated in code.
;
; Introduces the concept of a subroutine that can be reused.
; 
; Introduced the concept of using a sine table for animating data offsets.
;
; Additional Notes
; ----------------
; The colour table is exended to be three times the size so that the colours can be
; scrolled up and down using the sine table offsets.
;
; e.g.
;
;  colour_table:
;                    +--------------------+  <-- Offset = -64
;                    |                    |
;                    |                    |
;  sintable offset-> +--------------------+  <-- Offset = 0
;                    |  Displayed Colours |
;                    |                    |
;                    +--------------------+  <-- Offset = +64
;                    |                    |
;                    |                    |
;                    +--------------------+
;
; The colour table is a table of 16 bit values (word value = 2 bytes)
; The value from the Sin Table must be multiplied by 2 to give the correct index in to the colour table.
; The multiplication must be signed (muls).
; The byte value must be sign-extended from a byte to a word before the multiplcation is done.
;  - i.e. a negative byte has bit 8 set to true. this must be extended to 16 bits for the multiplication.
;
; This multiplication could be avoided each frame by modifying the sine table (pre multipication)
; This code in not intended to be optimal.
;

                section main,code_c                     ; define this code section with the name 'main', force it to require chip memory 'code_c'

                incdir  'include/'                      ; set the 'include' folder as part of ther default search path for include files (save having to enter full paths)
                include 'hw.i'                          ; include amiga custom chip register equates (i.e. CUSTOM, INTENA, DMACON, INTREQ used below)


                ; ---------------- disable the operating system -----------------
start           lea     CUSTOM,a6                               ; set address register to the base address of the custom chips $dff000
                move.w  #$7fff,INTENA(a6)                       ; disable all interrupts.
                move.w  #$7fff,DMACON(a6)                       ; disable all DMA.
                move.w  #$7fff,INTREQ(a6)                       ; clear all previous interrupt requests.

                ; Set up a Vertical Blank interrupt Handler
                lea     vertb_interrupt_handler(pc),a0          ; address of the code to run during the vertical blank interrupt
                move.l  a0,$6c.w                                ; set the 68000's level 3 interrupt vector address.
                move.w  #$c020,INTENA(a6)                       ; enable the VERTB interrupt (bit 15 SET/CLR = 1, bit 14 INTEN = 1 ,bit 5 VERTB = 1)

                ; initialise the colour bars
                jsr     generate_colour_bars                    ; call sub routine to write the copper instructions in code.

                ; Set up the Copper List
                lea     copper_list(pc),a0                      ; set a0 = address of copper list
                move.l  a0,COP1LC(a6)                           ; set the copper list start address
                move.w  #$8280,DMACON(a6)                       ; enable the copper DMA (bit 15 SET/CLR = 1, bit 9 DMAEN = 1, bit 7 COPEN = 1)



                ; loop forever
.loop           jmp     .loop                                   ; loop in back and do it again.





                ; ----------------------------------------------------------
                ; Generate colour bars in the copperlist by using the
                ; processor to write the copper list instructions into
                ; a block of memory reserved in the copper list.
                ;-----------------------------------------------------------
sintable_index  dc.w    0                                       ; current index into the sine table (360 entries)

generate_colour_bars

                ; manage index into the sine table (wrap back to start if reach end of the table)
                add.w   #$01,sintable_index                     ; increase the index into the sine table
                cmp.w   #360,sintable_index                     ; test index against length of the sine table
                blt.s   .continue
                move.w  #0,sintable_index                       ; reset sine table index to 0 if > 359 (end of sine table)
.continue

                ; get colour table offset from sine table
                ; have to multiply the sine table value by 2 to get 16 bit offset into the colour table.
                moveq.l #0,d6                                   ; initialise d6 to zero (will be used to hold the colout table offset)
                lea     sine_table,a0                           ; a0 = address of sine table data
                move.w  sintable_index,d0                       ; d0 = index into sine table data
                move.b  (a0,d0.w),d6                            ; d6 = byte value from sine table at offset in d0.
                ext.w   d6                                      ; need to sign extend the sine value to 16 bits for the multiplication below.
                muls    #2,d6                                   ; multiple sine value by 2 (to get 16 bit index into the colour table)

                ; d6 = offset into the colour table
                lea     colour_bars,a0                          ; get the address of the reserved block of memory in the copper list.
                lea     colour_table,a1                         ; get the address of the colour table that contains a colour for each raster line.
                lea     (a1,d6.w),a1                            ; set a1 = to colour table + offset from sine table.

                move.w  #$4001,d0                               ; $4001 will be the start copper wait value, set data register d0 to the value
                move.w  #64-1,d7                                ; loop counter -1 (the height of the colour lines to generate in the copper list)
                                                                ; needs to equal the space reserved in the copper list.
.generate_list
                move.w  d0,(a0)+                                ; set the 1st word for the copper wait value
                move.w  #$fffe,(a0)+                            ; set the 2nd word for the copper wait value (the wait mask)
                move.w  #COLOR00,(a0)+                          ; set the 3rd word for the copper move instruction (background colour register $dff180)
                move.w  (a1)+,(a0)+                             ; set the 4th word for the copper move instruction (background colour value)

                add.w   #$0100,d0                               ; increment the vertical wait value to the next raster line (copper wait)

                dbf.w   d7,.generate_list                       ; loop for next iteration until d7 = -1

                rts                                             ; return from subroutine.


                ; ------------------------------------------------------
                ; 64 colour entries for each row of the copper list
                ;-------------------------------------------------------
    
                dc.w    $fff
                ; first copy of colout table
                dc.w    $000,$222,$444,$666,$888,$aaa,$ccc,$eee,$fff,$eee,$ccc,$aaa,$888,$666,$444,$222     ; grey colour bar (16 entries)
                dc.w    $000,$002,$004,$006,$008,$00a,$00c,$00e,$00f,$00e,$00c,$00a,$008,$006,$004,$002     ; blue colour bar (16 entries)
                dc.w    $000,$020,$040,$060,$080,$0a0,$0c0,$0e0,$0f0,$0e0,$0c0,$0a0,$080,$060,$040,$020     ; green colour bar (16 entries)
                dc.w    $000,$200,$400,$600,$800,$a00,$c00,$e00,$f00,$e00,$c00,$a00,$800,$600,$400,$200     ; red colour bar (16 entries)
                ; second copy of colour table
colour_table    dc.w    $000,$222,$444,$666,$888,$aaa,$ccc,$eee,$fff,$eee,$ccc,$aaa,$888,$666,$444,$222     ; grey colour bar (16 entries)
                dc.w    $000,$002,$004,$006,$008,$00a,$00c,$00e,$00f,$00e,$00c,$00a,$008,$006,$004,$002     ; blue colour bar (16 entries)
                dc.w    $000,$020,$040,$060,$080,$0a0,$0c0,$0e0,$0f0,$0e0,$0c0,$0a0,$080,$060,$040,$020     ; green colour bar (16 entries)
                dc.w    $000,$200,$400,$600,$800,$a00,$c00,$e00,$f00,$e00,$c00,$a00,$800,$600,$400,$200     ; red colour bar (16 entries)
                ; third copy of colour table
                dc.w    $000,$222,$444,$666,$888,$aaa,$ccc,$eee,$fff,$eee,$ccc,$aaa,$888,$666,$444,$222     ; grey colour bar (16 entries)
                dc.w    $000,$002,$004,$006,$008,$00a,$00c,$00e,$00f,$00e,$00c,$00a,$008,$006,$004,$002     ; blue colour bar (16 entries)
                dc.w    $000,$020,$040,$060,$080,$0a0,$0c0,$0e0,$0f0,$0e0,$0c0,$0a0,$080,$060,$040,$020     ; green colour bar (16 entries)
                dc.w    $000,$200,$400,$600,$800,$a00,$c00,$e00,$f00,$e00,$c00,$a00,$800,$600,$400,$200     ; red colour bar (16 entries)

                dc.w    $fff

                ; 360 entries sine table rangine from -64 to +64
sine_table      dc.b    0,1,2,3,4,5,6,7,8,10,11,12,13,14,15,16,17,18,19,20
                dc.b    21,22,23,25,26,27,28,29,30,31,31,32,33,34,35,36,37
                dc.b    38,39,40,41,41,42,43,44,45,46,46,47,48,49,49,50,51
                dc.b    51,52,53,53,54,54,55,55,56,57,57,58,58,58,59,59,60
                dc.b    60,60,61,61,61,62,62,62,62,63,63,63,63,63,63,63,63
                dc.b    63,63,64,63,63,63,63,63,63,63,63,63,63,62,62,62,62
                dc.b    61,61,61,60,60,60,59,59,58,58,58,57,57,56,55,55,54
                dc.b    54,53,53,52,51,51,50,49,49,48,47,46,46,45,44,43,42
                dc.b    41,41,40,39,38,37,36,35,34,33,32,31,31,30,29,28,27
                dc.b    26,25,23,22,21,20,19,18,17,16,15,14,13,12,11,10,8
                dc.b    7,6,5,4,3,2,1,0,-1,-2,-3,-4,-5,-6,-7,-8,-10,-11,-12
                dc.b    -13,-14,-15,-16,-17,-18,-19,-20,-21,-22,-23,-25,-26
                dc.b    -27,-28,-29,-30,-31,-32,-32,-33,-34,-35,-36,-37,-38
                dc.b    -39,-40,-41,-41,-42,-43,-44,-45,-46,-46,-47,-48,-49
                dc.b    -49,-50,-51,-51,-52,-53,-53,-54,-54,-55,-55,-56,-57
                dc.b    -57,-58,-58,-58,-59,-59,-60,-60,-60,-61,-61,-61,-62
                dc.b    -62,-62,-62,-63,-63,-63,-63,-63,-63,-63,-63,-63,-63
                dc.b    -64,-63,-63,-63,-63,-63,-63,-63,-63,-63,-63,-62,-62
                dc.b    -62,-62,-61,-61,-61,-60,-60,-60,-59,-59,-58,-58,-58
                dc.b    -57,-57,-56,-55,-55,-54,-54,-53,-53,-52,-51,-51,-50
                dc.b    -49,-49,-48,-47,-46,-46,-45,-44,-43,-42,-41,-41,-40
                dc.b    -39,-38,-37,-36,-35,-34,-33,-32,-32,-31,-30,-29,-28
                dc.b    -27,-26,-25,-23,-22,-21,-20,-19,-18,-17,-16,-15,-14
                dc.b    -13,-12,-11,-10,-8,-7,-6,-5,-4,-3,-2,-1



                ; ------------------------------------------------------------------------------------------------------
                ; Vertical Blank Interrupt Handler Code
                ; 1) saves processor registers to the stack
                ; 2) check this is a VERTB interrupt
                ; 3) perform own code
                ; 4) clear VERTB interrupt request flag
                ; 5) restore processor registers from the stack
                ; 6) exit the interrupt handler
vertb_interrupt_handler
                movem.l d0-d7/a0-a6,-(a7)           ; save all processor registers to the stack

                ; check if this is a VERTB interrupt
                lea     CUSTOM,a6
                move.w  INTREQR(a6),d0
                and.w   #$0020,d0
                beq.s   not_vertb


                ; Own Interrupt Handler Code goes here...
                bsr     generate_colour_bars        ; regenerate the colour bars each vertical blank (animation)


                ; clear VERTB interrupt reques flag
                move.w  #$0020,INTREQ(a6)           ; clear VERTB (bit 15 SET/CLR = 0, bit 5 VERTB = 1)               
not_vertb       movem.l (a7)+,d0-d7/a0-a6           ; restore processor registers from the stack
                rte                                 ; return from exception, restore status bits and program counter from the stack








                ; ------------------------------------------------------------------------------------------------------
                ; Copper list instructions
                ;
                ; Wait Instruction Format
                ;   - waits for a screen position.
                ;   - consists of two 16 bit words.
                ;   - 1st word is the position to wait for (vertical,horizontal)
                ;       - bit 0 must be set to 1 (i.e. always an odd value for the horizontal wait)
                ;   - 2nd word is a mask for the wait position
                ;       - unless doing something out of the ordinary then normally set to $fffe 
                ;       - bit 0 must be set to 0 (i.e. always an even value for the bit mask)
                ;
                ; Move Instruction Format
                ;   - moves a 16bit value into a Custom Chip Register (base address always assumed to be $dff000)
                ;   - consists of two 16 bit words.
                ;   - 1st word is the Custom Chip Register to set.
                ;   - 2nd word is the 16 bit value to move into the register.
                ;
                ; The copper list below waits for horizontal screen positions and then sets the background
                ; colour to different values down the screen.
                ; This is a common effect in games and demos.
                ;------------------------------------------------------------------------------------------------------
                
                even                                    ; make the copper list 16 bit aligned in memory

copper_list     dc.w    $2c01,$fffe                     ; wait for vertical position $2c. horizontal position 01 (top of standard PAL display)
                dc.w    COLOR00,$000                  ; set the back ground colour to black RGB (bits: Red 11-8, Green 7-4, Blue 0-3) 
                
                ; section of the copper list generated by code
                ;  - repeating blocks of the following instruction
                ;       dc.w $xx01,$fffe        - wait for vertical position where xx will be vertical line to wait 
                ;       dc.w COLOR00,$xxxx      - set the back ground colour for the raster line
colour_bars     dcb.w   4*64,$0000              ; reserve a block of 16 bit words, size = 4*64 (256 words), which is the same as 512 bytes
                                                ; 4 words required to wait for and set the colour of each vertical line
                                                ; we'll set 64 vertical lines of colour.

                ; reset backgound colour to black
                dc.w   COLOR00,$0000                ; set the background colour back to blank at the end.

                ; End of copper list - wait for location that will never be reached
                ; two copper ends as per the hardware reference manual.
                dc.w    $ffff,$fffe
                dc.l    $ffff,$fffe





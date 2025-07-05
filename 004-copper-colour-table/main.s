; Important Concepts
; ------------------
; This example extends the 002-vertical-blank-interrupt with a vertical blank interrupt.
;
; The Copper list (or parts of it) can be generated in code.
;
; Introduces the concept of a subroutine that can be reused.
; 
;
; Additional Notes
; ----------------
; A block of memory can be reserved with the dcb.(x) assembler directive.
;
;   dcb.b   $400,$0     ; reserves a block of 1024 bytes ($400 hex) initialised to the value $0
;   dcb.w   $400,$0     ; reserves a block of 2048 bytes (1024 words) initialised to the value $0
;   dcb.l   $400,$0     ; reserves a block of 4096 bytes (1024 longs) initialised to the value $0
;
; The blocks can be labeled so that they can be accessed by the code.
;
;   myblock     dc.b    $400,$0     ; reserve a block of 1024 bytes with the label 'myblock'
;
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
generate_colour_bars
                lea     colour_bars,a0                          ; get the address of the reserved block of memory in the copper list.
                lea     colour_table,a1                         ; get the address of the colour table that contains a colour for each raster line.

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
colour_table    dc.w    $000,$222,$444,$666,$888,$aaa,$ccc,$eee,$fff,$eee,$ccc,$aaa,$888,$666,$444,$222     ; grey colour bar (16 entries)
                dc.w    $000,$002,$004,$006,$008,$00a,$00c,$00e,$00f,$00e,$00c,$00a,$008,$006,$004,$002     ; blue colour bar (16 entries)
                dc.w    $000,$020,$040,$060,$080,$0a0,$0c0,$0e0,$0f0,$0e0,$0c0,$0a0,$080,$060,$040,$020     ; green colour bar (16 entries)
                dc.w    $000,$200,$400,$600,$800,$a00,$c00,$e00,$f00,$e00,$c00,$a00,$800,$600,$400,$200     ; red colour bar (16 entries)



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





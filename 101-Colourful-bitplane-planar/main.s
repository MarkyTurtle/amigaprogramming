; Important Concepts
; ------------------
;
; 1) Display a 5 bitplane (32 colour logo on the screen)
; 2) The graphins are stored in a planar format 
;       - i.e. each bitplane is stored as a block of data 40 bytes wide by 320 pixels high, consecutively in memory.
;
;       +-------------+
;       |             |
;       |  Bitplane 1 |
;       |             |
;       +-------------+
;       +-------------+
;       |             |
;       |  Bitplane 2 |
;       |             |
;       +-------------+
;       ...
;       +-------------+
;       |             |
;       |  Bitplane 5 |
;       |             |
;       +-------------+
;
; 3) The colour data is held in a table of 32 16bit values.
;
; 4) The copper list is initialed by the processor at the start of the program.
;
; 5) There are no animations or further effects run by the interrupt or main program.
;
; You will see that when a bitplane display has been configured by the copper list, then the copper will
; continue to display the image with no further input required by the 68000 processor.
;
; The processor is free to continue with other tasks in parallel.
; NB: The copper and bitplane DMA use cycles during the display frame preventing the processor running
; code stored in CHIP RAM at full speed.
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

                ; Set up Copper Bitplane Ptrs
                bsr     init_bitplanes
                bsr     init_colour_palette

                ; Set up the Copper List
                lea     copper_list(pc),a0                      ; set a0 = address of copper list
                move.l  a0,COP1LC(a6)                           ; set the copper list start address

                ; enable DMA
                move.w  #$8380,DMACON(a6)                       ; enable the copper DMA & Bitplane DMA (bit 15 SET/CLR = 1, bit 9 DMAEN = 1, bit 8 = BPLEN, bit 7 COPEN = 1)



                ; loop forever
.loop           jmp     .loop                                   ; loop in back and do it again.



            ; -------------------------------------------------------------------
            ; Initialise copper bitplane pointers.
            ; Create copper move instructions to set up the bitplane pointers
            ; for 5 bitplanes for the image to display.
            ;
            ; a0 = area in copper list to set move instructions for bitplane ptrs
            ;       - NB there are two moves for each 32 bit address, the copper
            ;            has to move the low half and high half of the 32 bit
            ;            address pointer using two separate move instructions.
            ; d0 = address of the graphics to display in planar format.
            ; d1 = used to store the first bitplane regsiter value $e0 (BPL1PTH)
            ;       - this takes the high 16 bits of the bitplane address.
            ; d7 = used as a loop counter (5 bitplanes to set)
            ;
            ; The loop creates the following set of move instructions in the copper
            ; list for each bitplane:
            ;   dc.w    BPL(x)PTH,<high 16 bits of address>
            ;   dc.w    BPL(x)PTL,<low 16 bits of address>
            ;
            ; The swap instruction is used to 'swap' the high and low 16bits
            ; of the data register holding the address of the bitplane.
            ;
            ; The d1 data register is incremented as each bitplane ptr is
            ; sequential in the custom register memory space.
            ;   e.g.       BPL1PTH = $e0
            ;              BPL1PTL = $e2
            ;              BPL2PTH = $e4
            ;              BPL2PTL = $e6
            ;              ... and so on...
            ;
            ; At the end of each loop iteration, then the bitplane size
            ; is added to the d0 data register to set the next bitplane's
            ; potiners.
            ;
            ; -------------------------------------------------------------------
init_bitplanes
                lea     copper_bitplanes,a0         ; memory address for setting 5 bitplane ptrs in the copper list
                move.l  #image_gfx,d0               ; start of graphics in memory (see include at bottom of the file)
                moveq.l #4,d7                       ; loop counter = 5-1 (number of bitplanes for 32 colour image)
                move.w  #BPL1PTH,d1                 ; value for bitplane ptr register ($dff0e0)
.loop
                move.w  d1,(a0)+                
                add.w   #2,d1
                swap    d0                          ; first entry is the high ptr 
                move.w  d0,(a0)+                    ; set data for copper move instruction (high 16 bits of the address)
                swap    d0                          ; second entry is the low ptr
                move.w  d1,(a0)+    
                add.w   #2,d1
                move.w  d0,(a0)+                    ; set data value for copper move instruction (low 16 bits of the address)

                Add.w   #40*256,d0                  ; add bitplane size to the bitplane address ptr (next bitplane)

                dbf     d7,.loop                    ; loop to set next bitplane ptr.

                rts




            ;---------------------------------------------------------------
            ; Initialise Colour Palette
            ; Create a list of copper move instructions to set up the
            ; image's display palette. Sets 32 colour registers.
            ;
            ; a0 = address of the image's colour palette table (32 colours)
            ; a1 = address of ares in copper list to create move instructions.
            ; d0 = values of first hardware colour register COLOUR00 ($dff180).
            ;       There are 32 chardware colour registers (OCS/ECS amigas)
            ;       The register addresses are sequential in the custom address
            ;       register memory space.
            ;       The first colour register starts at address $dff180.
            ; d7 = loop counter 32-1
            ;
            ; Each loop iteration inserts a move instruction to move a colour
            ; value into a colour register: - 
            ;       dc.w    Colour(xx),colour value
            ;
            ; at the end of each loop iteration the next colour register is
            ; selected by incrementing the value of the d0 register by 2.
            ;
init_colour_palette
                lea     image_palette,a0            ; colour palette table address (see include at end of file)
                lea     copper_colour_palette,a1    ; memory address for setting 32 colour registers in the copper list
                move.w  #COLOR00,d0                 ; d1 = value of 1st colour register ($dff180)
                moveq   #31,d7                      ; loop counter = 32-1 (number of colours)
.loop
                move.w  d0,(a1)+                    ; set colour register for copper move instruction
                move.w  (a0)+,(a1)+                 ; copy colour palette value to the copper move instruction
                add.w   #2,d0                       ; increment colour register to next colour value

                dbra    d7,.loop

                rts




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
                
                even                                  ; make the copper list 16 bit aligned in memory

copper_list     dc.w    FMODE,$0000                   ; Clear AGA specific fmode value (OCS/ECS fetch mode) 
                dc.w    COLOR00,$0000               ; set the background colour to black
                dc.w    COLOR01,$0fff               ; set the bitplane colour to white
                dc.w    $2b01,$fffe                   ; wait for raster line before the display starts ($2c)

                ; set display window properties
                dc.w    DDFSTRT,$0038
                dc.w    DDFSTOP,$00d0
                dc.w    DIWSTRT,$2c81
                dc.w    DIWSTOP,$2cc1

                ; set display modulo properties
                dc.w    BPL1MOD,$0000
                dc.w    BPL2MOD,$0000                   ; unused in this example 

                ; set bitplane pointers
copper_bitplanes
                dcb.w   4*5                             ; declare block for defining bitplane ptrs (move instructions in to high and low bitplane pointer registers)

                ; set display control parameters
                dc.w    BPLCON0,$5200                   ; 5 bitplane lo-res display, enable colour burst on composite video output.
                dc.w    BPLCON1,$0000                   ; clear soft scroll values
                dc.w    BPLCON2,$0000                   ; unused in this example (clear to reset values)
                dc.w    BPLCON3,$0000                   ; unused in this example (clear to reset values)
                dc.w    BPLCON4,$0000                   ; unused AGA values (clear to reset values)

copper_colour_palette
                dcb.w   2*32                            ; declare block for defining 32 colour palette (move instructions into colour registers)

                ; End of copper list - wait for location that will never be reached
                ; two copper ends as per the hardware reference manual.
                dc.w    $ffff,$fffe
                dc.l    $ffff,$fffe



            ; --------------------------------------------------------------
            ; IMAGE GFX
            ;---------------------------------------------------------------
                even                                ; make the buffer align on a 16bit (word boundary in memory) - the hardware/DMA does not like odd addresses.

                incdir  "gfx/"
image_gfx       include "gfx.s"

image_palette   include "palette.s"

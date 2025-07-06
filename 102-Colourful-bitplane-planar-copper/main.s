; Important Concepts
; ------------------
;
; 1) Display a 5 bitplane (32 colour logo on the screen)
;       This bitplane is actually wider than the screen 384x256 instead of the standard 320x256
;       This means than it is 48 bytes wide instead of 40 bytes wide.
;       So for the image to display correctly on a 40 byte wide display, 8 bytes must be skipped at the end of each line.
;       In order to do this I set the MODULO values to $0008 in the copper list.
;
; 2) The graphics are stored in a planar format 
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


COPPER_BARS_SIZE    EQU     64*3            ; display size of copper bars


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

                ; Set up Copper Colour Bars
                bsr     generate_colour_bars

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
                move.l  #image_gfx+4,d0               ; start of graphics in memory (see include at bottom of the file)
                moveq.l #4,d7                       ; loop counter = 4-1 (number of bitplanes for 32 colour image)
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

                Add.w   #48*256,d0                  ; add bitplane size to the bitplane address ptr (next bitplane)

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

                move.w  #$4801,d0                               ; $4001 will be the start copper wait value, set data register d0 to the value
                move.w  #COPPER_BARS_SIZE-1,d7                  ; loop counter -1 (the height of the colour lines to generate in the copper list)
                                                                ; needs to equal the space reserved in the copper list.
.generate_list
                move.w  d0,(a0)+                                ; set the 1st word for the copper wait value
                move.w  #$fffe,(a0)+                            ; set the 2nd word for the copper wait value (the wait mask)
                ;move.w  #COLOR15,(a0)+                          ; - Set Logo Colour - set the 3rd word for the copper move instruction
                move.w  #COLOR00,(a0)+                          ;  - Set Background Colour - set the 3rd word for the copper move instruction (background colour register $dff180)
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
                ; fourth copy of colour table
                dc.w    $000,$222,$444,$666,$888,$aaa,$ccc,$eee,$fff,$eee,$ccc,$aaa,$888,$666,$444,$222     ; grey colour bar (16 entries)
                dc.w    $000,$002,$004,$006,$008,$00a,$00c,$00e,$00f,$00e,$00c,$00a,$008,$006,$004,$002     ; blue colour bar (16 entries)
                dc.w    $000,$020,$040,$060,$080,$0a0,$0c0,$0e0,$0f0,$0e0,$0c0,$0a0,$080,$060,$040,$020     ; green colour bar (16 entries)
                dc.w    $000,$200,$400,$600,$800,$a00,$c00,$e00,$f00,$e00,$c00,$a00,$800,$600,$400,$200     ; red colour bar (16 entries)
                ; fifth copy of colour table
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
                bsr     generate_colour_bars


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
                dc.w    BPL1MOD,$0008
                dc.w    BPL2MOD,$0008                  ; unused in this example 

                ; set bitplane pointers
copper_bitplanes
                dcb.w   5*4                             ; declare block for defining bitplane ptrs (move instructions in to high and low bitplane pointer registers)

                ; set display control parameters
                dc.w    BPLCON0,$4200                   ; 5 bitplane lo-res display, enable colour burst on composite video output.
                dc.w    BPLCON1,$0000                   ; clear soft scroll values
                dc.w    BPLCON2,$0000                   ; unused in this example (clear to reset values)
                dc.w    BPLCON3,$0000                   ; unused in this example (clear to reset values)
                dc.w    BPLCON4,$0000                   ; unused AGA values (clear to reset values)

copper_colour_palette
                dcb.w   2*32                            ; declare block for defining 32 colour palette (move instructions into colour registers)

                ; section of the copper list generated by code
                ;  - repeating blocks of the following instruction
                ;       dc.w $xx01,$fffe        - wait for vertical position where xx will be vertical line to wait 
                ;       dc.w COLOR00,$xxxx      - set the back ground colour for the raster line
colour_bars     dcb.w   4*COPPER_BARS_SIZE,$0000        ; reserve a block of 16 bit words, size = 4*64 (256 words), which is the same as 512 bytes
                                                        ; 4 words required to wait for and set the colour of each vertical line
                                                        ; we'll set 64 vertical lines of colour.

                ; reset backgound colour to black
                dc.w   COLOR00,$0000                ; set the background colour back to blank at the end.


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

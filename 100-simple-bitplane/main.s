; Important Concepts
; ------------------
;
; Use a simple copper list to set up the display of a simple 1 bitplane screen.
;
; A standard PAL lo-res screen is 320x256 pixels in size
;   - 40 bytes wide by 256 lines high. 
;   - 10240 bytes in size per bitplane.
;
; The Copper List sets the Bitplane Address Pointers during every screen refresh, along with other dispaly parameters.
; This means that the 68000 processor does not have to be concerned with the display settings in general and can get on with
; other business.
;
; Setting the Display Buffer Addresses
;  - The Bitplane Ponters set the area of memory for display
;       - (of which there are 6 on the OCS/ECS amigas and 8 on the AGA amigas)
;  - The Bitplane data must be located in CHIP RAM.
;  - The Bitplane data must be aligned on a 16bit boundary for an OCS/ECS amiga (maybe 32 or 64 bit aligned for AGA depending on the FMODE)
;
; Setting the Display Window
;  - The Display Fetch Start/Stop registers are used to tell the hardware DMA when to begin reading the display data.
;  - The Display Window Start/Stop registers are used to tell the hardware when to set the display window on the screen (pixel values)
;  - These registers work together to ensure that the bitplane data display set on the monitor as intended.  
;
; Bitplane Control Registers are used to set display properties
;  - The BitPlane Control Register 0 ($dff100) is used to set the number of bitplanes and the display resolution.
;  - The Bitplane Control Register 1 ($dff102) is used to set the pixel scroll value of the display (0-15 pixels), called the delay value
;  - The Bitplane COntrol Register 2 ($dff104) is used for more advanced control of playfield priorities (dual playfield)
;  - The Bitplane Control Register 3 ($dff106) is used for more advances features for Genlock and AGA.
;  - The Bitplane Control Register 4 ($dff10c) is used for AGA features only
;
; A one bitplane screen can only display 2 colours.
;  - the background colour ($dff180) (where a bit is not set in the bitplane)
;  - color01 ($dff182) (where a bit is set in the bitplane)
;
; Display Modulos
;  - The Display modulo is a value to add to the bitplane pointers at the end of each raster line displayed.
;       - These can be used to display images wider than the screen,
;       - Or to repeat display data,
;       - Or to skip display data.
;
;  - Can be used to aid scolling displays or add interesting effectsd to the disply with little processor involvement.
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

                ; Set up Copper Bitplane Ptrs
                bsr     init_bitplanes

                ; Set up the Copper List
                lea     copper_list(pc),a0                      ; set a0 = address of copper list
                move.l  a0,COP1LC(a6)                           ; set the copper list start address

                ; enable DMA
                move.w  #$8380,DMACON(a6)                       ; enable the copper DMA & Bitplane DMA (bit 15 SET/CLR = 1, bit 9 DMAEN = 1, bit 8 = BPLEN, bit 7 COPEN = 1)



                ; loop forever
.loop           jmp     .loop                                   ; loop in back and do it again.



            ; -------------------------------------------------------------------
            ; Initialise copper bitplane pointers.
            ; 1) get the address of the bitplane buffer
            ; 2) set the low 16 bits of the address to the low bitplane ptr
            ; 3) swap the high and low 16 bits of the address
            ; 4) set the high 16bit of the address to the high bitplane ptr
            ;
            ; The copper can only set 16 bits in each move instruction,
            ; so 32 bit addresses set by the copper list have to use two
            ; move instructions.
            ; each move instruction sets half of the address pointer address.
            ; -------------------------------------------------------------------
init_bitplanes
                move.l  #bitplane_buffer,d0
                move.w  d0,bpl1ptl                  ; set data for copper move instruction (low 16 bits of the address)
                swap    d0
                move.w  d0,bpl1pth                  ; set data value for copper move instruction (high 16 bits of the address)
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
                dc.w    BPL1PTH
bpl1pth         dc.w    $0000                           ; set in code 
                dc.w    BPL1PTL
bpl1ptl         dc.w    $0000                           ; set in code

                ; set display control parameters
                dc.w    BPLCON0,$1200                   ; 1 bitplane lo-res display, enable colour burst on composite video output.
                dc.w    BPLCON1,$0000                   ; clear soft scroll values
                dc.w    BPLCON2,$0000                   ; unused in this example (clear to reset values)
                dc.w    BPLCON3,$0000                   ; unused in this example (clear to reset values)
                dc.w    BPLCON4,$0000                   ; unused AGA values (clear to reset values)

                ; End of copper list - wait for location that will never be reached
                ; two copper ends as per the hardware reference manual.
                dc.w    $ffff,$fffe
                dc.l    $ffff,$fffe



                    even                                ; make the buffer align on a 16bit (word boundary in memory) - the hardware/DMA does not like odd addresses.
bitplane_buffer     dcb.b   10240,$f0                   ; allocate memory for a single bitplane containing the pattern $f0



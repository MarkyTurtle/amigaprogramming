; Important Concepts
; ------------------
;
; Use a Copper List to set up a 1 bitplane screen (blank)
;
; Use a Copper List to set up 1 sprite for display.
;   - other 7 sprites set to NULL (not displayed)
;
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

                ; Set up Copper Bitplane ptrs
                bsr     init_bitplanes
                
                ; Set up Copper Sprite ptrs
                bsr     init_sprites

                ; Set up the Copper List
                lea     copper_list(pc),a0                      ; set a0 = address of copper list
                move.l  a0,COP1LC(a6)                           ; set the copper list start address

                ; enable DMA
                move.w  #$83a0,DMACON(a6)                       ; enable the copper DMA & Bitplane DMA (bit 15 SET/CLR = 1, bit 9 DMAEN = 1, bit 8 = BPLEN, bit 5 = SPREN, bit 7 COPEN = 1)



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



            ; -----------------------------------------------------------------
            ; Initialise Sprites
            ; 1) Set Sprite 1 to the address of the sprite1 structure
            ; 2) set remaining 7 sprites to NULL pointers
            ;------------------------------------------------------------------
init_sprites
                move.l  #sprite1,d0
                lea     copper_sprites,a0
                move.w  #SPR0PTH,d1

                ; set up sprite 0
                move.w  d1,(a0)+                ; SPR0PTH
                add.w   #2,d1
                swap    d0
                move.w  d0,(a0)+
                move.w  d1,(a0)+                ; SPR0PTL
                add.w   #2,d1
                swap    d0
                move.w  d0,(a0)+

                ; null remaining sprites (1 to 7)
                move.w  #6,d7                   ; loop counter 7-1 (remaining sprite count)
                move.l  #null_sprite,d0
.loop
                move.w  d1,(a0)+                ; SPR(x)PTH
                add.w   #2,d1
                swap    d0
                move.w  d0,(a0)+
                move.w  d1,(a0)+                ; SPR(x)PTL
                add.w   #2,d1
                swap    d0
                move.w  d0,(a0)+
                
                dbra    d7,.loop

                rts

                even 
sprite1         dc.w    $6060,$6900                             ; Sprite Pos & Control word (9 raster lines high - not including the control words)
                dc.w    %0000000000000000,%0000000100000000     ; second word is least significant
                dc.w    %0000000000000000,%0000000100000000
                dc.w    %0000000100000000,%0000000000000000
                dc.w    %0000001110000000,%0000010101000000
                dc.w    %0000011111000000,%0011101110111000
                dc.w    %0000001110000000,%0000010101000000
                dc.w    %0000000100000000,%0000000000000000
                dc.w    %0000000000000000,%0000000100000000                                   
                dc.w    %0000000000000000,%0000000100000000                                   
                dc.w    $0,$0                                   ; end of sprite (or next control word if multiple sprites used - this line is not counted in sprite height)

null_sprite     dc.w    $0000,$0000


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
                lea     sprite1,a0
                ;add.b   #1,1(a0)                    ; increase sprite X value


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

                ; set sprite DMA pointers (8 sprites)
                ;   dc.w  SPRxPTH,high 16 bits of sprite address ptr
                ;   dc.w  SPRxPTL,low 16 bits of sprite address ptr
copper_sprites
                dcb.w   4*8                             ; allocate memory for settings sprite ptrs


                ; set sprite colours (colour 16 is sprite 1 transparency colour)
                dc.w    COLOR17,$068
                dc.w    COLOR18,$aef
                dc.w    COLOR18,$033

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
bitplane_buffer     dcb.b   10240,$00                   ; allocate memory for a single bitplane containing the pattern $f0



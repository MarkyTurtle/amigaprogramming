; This example contains a simple 'copper list' program.
;
; Important Concepts
; ------------------
; This example extends the simple copper example and adds a vertical blank interrupt to the code.
; The interrupt code regularly updates part of the background colour by modifying a value in the copper-list.
;
; The vertical blank interrupt allows the video display to interrupt the 68000 program and
; allow you to run code after the display has been drawn.
;
; This is convenient if you want to run code to prepare the next screen for display or perform other functions on a regular, repeating time span.
;   e.g. scroll the screen
;        play music
;        move sprites
;        read the player input
;        etc.
;
; It is important to save the processor state on the stack when an interrupt occurrs and restore the state when existing the interrupt code.
;
; It is important that the vertical blank interrupt code is fast and doesn't take more than the time taken to draw the next screen display,
; otherwise you'll end up missing interrupts or the next interrupt interrupting your current interrupt. All sorts of issues.
;
; The 68000 processor has 7 different interrupt levels/priorities.
; There are 7 locations in memory used to store the addresses of handlers for these interrupts
; $6c   - Long Word (32 bit address) for the Level 3 Interrupt Vector.  
;
; Additional Notes
; ----------------
; Variables can be definied using the dc.(x) instruction as follows:-
;
;   dc.b  $0            - declare a byte (8 bit value ) with the initial value of $00
;   dc.w  $0            - declare a word (16 bit value) with the initial value of $0000
;   dc.l  $0            - declare a long (32 bit value) with the initial value of $00000000
;
; Variables can be labled so that they can be easily accessed by instructions in the code:
;
;   myvariable      dc.w $0000      - declare a 16 bit variable with the label 'myvariable'
;
;
; The interrupt handler uses a 16 bit variable 'colour_variable', which in incremented in the interrupt handler routine.
; The interrupt handler modifies a background colour stored in the copper list to change part of the screen colour. 
; The background colour is changed on a regular interval during the 'vertical blank' creating a smooth effect synchrinised with the screen display.
;


                section main,code_c                     ; define this code section with the name 'main', force it to require chip memory 'code_c'

                incdir  'include/'                      ; set the 'include' folder as part of ther default search path for include files (save having to enter full paths)
                include 'hw.i'                          ; include amiga custom chip register equates (i.e. CUSTOM, INTENA, DMACON, INTREQ used below)


                ; ---------------- disable the operating system -----------------
                ; This is a simple, but sledge hammer system take-over.
                ; It disables system interrupts and all system DMA.
                ; After this is done you can no-longer use any operating system
                ; functions for accessing the system resources such as
                ; disk, screen, sound, blitter, sprites etc.
                ; you now have to code everything yourself.
                ;
                ; NB: There are better OS friendlier ways of taking over the 
                ; system if you still want to use OS functions, we'll 
                ; discuss those later.
                ;
                ; NB: If you want to start an exe from the workbench you
                ; will also need additional code. (discuss this later)
                ;----------------------------------------------------------------
start           lea     CUSTOM,a6                       ; set address register to the base address of the custom chips $dff000
                move.w  #$7fff,INTENA(a6)               ; disable all interrupts.
                move.w  #$7fff,DMACON(a6)               ; disable all DMA.
                move.w  #$7fff,INTREQ(a6)               ; clear all previous interrupt requests.

                ; Set up a Vertical Blank interrupt Handler
                lea     vertb_interrupt_handler(pc),a0   ; address of the code to run during the vertical blank interrupt
                move.l  a0,$6c.w                        ; set the 68000's level 3 interrupt vector address.
                move.w  #$c020,INTENA(a6)               ; enable the VERTB interrupt (bit 15 SET/CLR = 1, bit 14 INTEN = 1 ,bit 5 VERTB = 1)
                                                        ; bit 15 SET/CLR
                                                        ; bit 14 INTEN = Master Interrupt enable bit
                                                        ; bit 5  VERTB = Vertical Blank enable bit (Level 3 interrupt on 68000)

                ; Set up the Copper List
                lea     copper_list(pc),a0                  ; set a0 = address of copper list
                move.l  a0,COP1LC(a6)                   ; set the copper list start address
                move.w  #$8280,DMACON(a6)               ; enable the copper DMA (bit 15 SET/CLR = 1, bit 9 DMAEN = 1, bit 7 COPEN = 1)



                ; loop forever
.loop           jmp     .loop                           ; loop in back and do it again.



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
                Add.w   #1,colour_variable
                move.w  colour_variable,copper_colour


                ; clear VERTB interrupt reques flag
                move.w  #$0020,INTREQ(a6)           ; clear VERTB (bit 15 SET/CLR = 0, bit 5 VERTB = 1)               
not_vertb       movem.l (a7)+,d0-d7/a0-a6           ; restore processor registers from the stack
                rte                                 ; return from exception, restore status bits and program counter from the stack



colour_variable dc.w    $0000                       ; reserve a 16 value for incrementing the background colour




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
                
                ; create colour bar (grey scale)
                dc.w    $3001,$fffe                     ; vertical screen position $30
                dc.w    COLOR00,$222
                dc.w    $3101,$fffe                     ; vertical screen position $31
                dc.w    COLOR00,$444
                dc.w    $3201,$fffe                     ; vertical screen position $32
                dc.w    COLOR00,$666
                dc.w    $3301,$fffe                     ; vertical screen position $33
                dc.w    COLOR00,$888
                dc.w    $3401,$fffe                     ; vertical screen position $34
                dc.w    COLOR00,$aaa
                dc.w    $3501,$fffe                     ; vertical screen position $35
                dc.w    COLOR00,$ccc
                dc.w    $3601,$fffe                     ; vertical screen position $36
                dc.w    COLOR00,$eee
                dc.w    $3701,$fffe                     ; vertical screen position $37
                dc.w    COLOR00,$ccc
                dc.w    $3801,$fffe                     ; vertical screen position $38                     
                dc.w    COLOR00,$aaa
                dc.w    $3901,$fffe                     ; vertical screen position $39
                dc.w    COLOR00,$888
                dc.w    $3a01,$fffe                     ; vertical screen position $3a
                dc.w    COLOR00,$666
                dc.w    $3b01,$fffe                     ; vertical screen position $3b
                dc.w    COLOR00,$444
                dc.w    $3c01,$fffe                     ; vertical screen position $3c
                dc.w    COLOR00,$222
                dc.w    $3d01,$fffe                     ; vertical screen position $3d
                dc.w    COLOR00,$000

                ; back-ground colour updated by VERTB interrupt handler
                dc.w    $4501,$fffe
                dc.w    COLOR00
copper_colour   dc.w    $0000

                ; set background back to black
                dc.w    $5001,$fffe
                dc.w    COLOR00,$000

                ; End of copper list - wait for location that will never be reached
                ; two copper ends as per the hardware reference manual.
                dc.w    $ffff,$fffe
                dc.l    $ffff,$fffe





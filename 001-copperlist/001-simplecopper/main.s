; This example contains a simple 'copper list' program.
;
; Important Concepts
; ------------------
;
; The 'Copper' is a display co-processor that is synchronised with the video screen display (i.e the raster beam as it draws the screen from top to bottom, left to right).
;
; The Copper only has 3 different types of instruction:
;   - wait (allows wait for a screen position)
;   - move (allows update of a custom register value)
;   - skip (allows an instruction to be skipped if the raster is at or passed beyond a screen position)
;
; The copper list is the list of instructions executed by the Copper.
; The list of instructions must be located in CHIP-RAM.
; The list of instructions must be aligned in memory at an even address (i.e. on a 16 bit word boundary)
;      - This alignment is a common requirement when dealing with Amiga DMA and Custom Chip resources.
;
; The Copper uses DMA (Direct Memory Access) to load and execute its instructions.
;
; The Copper runs is program independently of the processor, allowing the processor to continue running
; its own program in parallel with the copper list.
;
; Additional Notes
; ----------------
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

                ; Set up the Copper List
                lea     copper_list,a0                  ; set a0 = address of copper list
                move.l  a0,COP1LC(a6)                   ; set the copper list start address
                move.w  #$8280,DMACON(a6)               ; enable the copper DMA

                ; loop forever
.loop           jmp     .loop                           ; loop in back and do it again.





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

                ; End of copper list - wait for location that will never be reached
                ; two copper ends as per the hardware reference manual.
                dc.w    $ffff,$fffe
                dc.l    $ffff,$fffe





                section main,code_c                     ; define this code section with the name 'main', force it to require chip memory 'code_c'

                incdir  'include/'                      ; set the 'include' folder as part of ther default search path for include files (save having to enter full paths)
                include 'hw.i'                          ; include amiga custom chip register equates (i.e. CUSTOM, INTENA, DMACON, INTREQ used below)


start           lea     CUSTOM,a6                       ; set address register to the base address of the custom chips $dff000
                move.w  #$7fff,INTENA(a6)               ; disable all interrupts.
                move.w  #$7fff,DMACON(a6)               ; disable all DMA.
                move.w  #$7fff,INTREQ(a6)               ; clear all previous interrupt requests.

.loop           move.w  VHPOSR(a6),COLOR00(a6)          ; move the current postition of the raster into the background colour custom register $dff180
                jmp     .loop                           ; loop in back and do it again.


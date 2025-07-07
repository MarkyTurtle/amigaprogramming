# 201 - multiplexed sprites (reused sprites)

![Screenshot](./gfx/Screenshot.png)

This example displays a simple 1 bitplane screen at 320x256 resolution (PAL)

The reused/multiplexed sprites are used to create a simple scrolling star-field effect.

It uses the information learned in the Copper examples and extends it to display a standard lo-res 320x256 PAL bitplane screen.

The Amiga uses the Copper to set the memory address of the bitplane and sprite DMA pointers everytime the display is refreshed.
(i.e. 50 times per second on a PAL machine, 60 times per second on an NTSC machine)

The sprite x co-ords are updated in the vertical blank interrupt routine.



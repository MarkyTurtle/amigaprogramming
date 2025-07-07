# 200 - Simple Sprite

![Screenshot](./gfx/Screenshot.png)

This example displays a simple 1 bitplane sprite on a 1 bitplane 320x256 screen.

It uses the information learned in the Copper examples and extends it to display a standard lo-res 320x256 PAL bitplane screen.

The Amiga uses the Copper to set the memory address of the bitplane & sprite DMA pointers everytime the display is refreshed.
(i.e. 50 times per second on a PAL machine, 60 times per second on an NTSC machine)




# 002 - Vertical Blank Interrupt

![Screenshot](./gfx/Screenshot.png)

This example extends 001-CopperList and adds a vertical blank interrupt handler to the code.

The vertical blank interrupt handler is executed once per frame. 
When the screen is finished drawing and the raster beam starts moving back to the top of the screen to draw the next frame, this interrupt is generated by the display hardware.

It can be used to perform actions in synchonisation with the screen display.
 e.g. changing display parameters for the next screen to allow smooth animations etc in sync with the screen display.

 



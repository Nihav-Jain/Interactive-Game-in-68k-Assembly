*-----------------------------------------------------------
* Program Number: 3
* Written by    : Nihav Jain
* Date Created  : 10/01/2015
* Description   : Interactive Game
*-----------------------------------------------------------

ALL_REGS            REG     D0-D7/A0
        
*-------------------
* MAIN
*-------------------
START   ORG     $1000

        * resize output window 
        clr.l   d1
        move.w  #STAGE_WIDTH, d1
        swap    d1
        move.w  #STAGE_HEIGHT, d1
        move.b  #CMD_OUTPUT_RES, d0
        TRAP    #15
        
        * display loading text
        lea     LoadingText, a1
        move.w  #STAGE_WIDTH/2-60, d1
        move.w  #STAGE_HEIGHT/2, d2
        move.b  #CMD_DRAW_STRING, d0
        TRAP    #15
        
        * turn on double buffering drawing mode
        move.b  #DBL_BUFFER_ON, d1
        move.b  #CMD_DBL_BUFFER, d0
        TRAP    #15 
        
        JSR     PROCESS_BACKGROUND_BITMAP
        * draw background in buffer
        move.l  #0, -(sp)
        move.l  #0, -(sp)
        move.l  #640, -(sp)
        move.l  #480, -(sp)
        JSR     SR_DRAW_CLIP_RECTANGLE
        add.l   #16, sp
        
        * repaint buffer on main screen
        move.b  #CMD_REPAINT, d0
        TRAP    #15

        move.b  $9,d0
        TRAP    #15

        STOP #$F000
        

*-------------------
* Subroutine : Draws the specified clipping rectangle
* Parameteres: (LONG) top-left-x, (LONG) top-left-y, (LONG) bottom-right-x, (LONG) bottom-right-y (order to push onto stack)
*              52(sp), 48(sp), 44(sp), 40(sp)
*-------------------
*-------------------
* a0 : address of image data
* d0 : trap code
* d1 : trap code requirements
* d2 : Y coordinate
* d3 : X coordinate
* d4 : byte offset of current row in image data
* d5 : number of bytes per row
* d6 : pixel offset
* d7 : offset of the number of bytes in a row
*-------------------
SR_DRAW_CLIP_RECTANGLE:

        movem.l ALL_REGS, -(sp)         ; store the register values in stack

        move.l  BG_ImageData, a0
        
        move.l  52(sp), d3              ; top-left-x to d3
        move.l  48(sp), d2              ; top-left-y to d2
        
        move.l  BG_Height, d2
        sub.l   48(sp), d2
        subi.l  #1, d2
        
        move.l  BG_WIDTH, d5
        
        move.l  d3, d7
        add.l   d3, d7
        add.l   d3, d7
        
        move.l  d5, d4
        mulu    d2, d4                  ; y offset (row offset)
        move.l  d4, d6      
        add.l   d7, d6                  ; offset (in bytes) of pixel to be drawn from the image data
        move.l  48(sp), d2

    CONTINUE_ROW:
        clr.l   d1
        
        move.b  (a0, d6.l), d1          ; #$000000BB
        swap    d1                      ; #$00BB0000
        move.b  1(a0, d6.l), d1         ; #$00BB00GG
        lsl.w   #8, d1                  ; #$00BBGG00
        move.b  2(a0, d6.l), d1         ; #$00BBGGRR
        
        move.l  #CMD_PEN_COLOR, d0
        TRAP    #15
        
        move.l  d3, d1
        move.l  #CMD_DRAW_PIXEL, d0
        TRAP    #15
        
        addi.l  #1, d3                  ; increment X coordinate
        addi.l  #3, d6
        
        cmp.l   44(sp), d3
        blt     CONTINUE_ROW
        
        sub.l   d5, d4                  ; update row pointer to to previous row (current = current - NumBytesPerRow)
        move.l  d4, d6                  
        add.l   d7, d6
        move.l  52(sp), d3              ; reset X coordinate
        addi.l  #1, d2
        cmp.l   40(sp), d2
        blt     CONTINUE_ROW

        movem.l (sp)+, ALL_REGS
        RTS

*-------------------
* Subroutine: Copies the double buffer to the main screen
*-------------------
PROCESS_BACKGROUND_BITMAP:

        move.l  ImageDataOffset, d5
        JSR     SR_SWAP_LONG
        lea     BitmapData, a0
        adda.l  d5, a0                  ; adding image data offset to bitmap data start address, a0 now points to the image data
        move.l  a0, BG_ImageData
        
        move.l  ImageHeight, d5
        JSR     SR_SWAP_LONG
        move.l  d5, BG_Height
        
        move.l  ImageWidth, d5
        JSR     SR_SWAP_LONG        
        mulu    #BitsPerPixel, d5
        addi.l  #31, d5
        lsr.l   #5, d5                  ; d5 = d5 / 32
        lsl.l   #2, d5                  ; d5 = d5 * 4
        move.l  d5, BG_Width
        RTS
        
*-------------------
* Subroutine: Copies the double buffer to the main screen
*-------------------
REPAINT:
        move.b  #CMD_REPAINT, d0
        TRAP    #15
        RTS

*-------------------
* Subroutine: Swaps the bytes of the lower word in d5
*-------------------
SR_SWAP_WORD:
        movem.l d6, -(sp)
        clr.w   d6
        move.b  d5, d6
        lsr.w   #8, d5
        lsl.w   #8, d6
        or.w    d6, d5
        movem.l (sp)+, d6
        RTS
        
        
*-------------------
* Subroutine: Swaps the bytes of the long word in d5
*-------------------
SR_SWAP_LONG:
        JSR     SR_SWAP_WORD
        swap    d5
        JSR     SR_SWAP_WORD
        RTS

        
*----------------------------------------------------------*
*----------------------------------------------------------*


*-------------------
* STAGE related constants
*-------------------
STAGE_WIDTH         EQU     640
STAGE_HEIGHT        EQU     480
LoadingText         dc.b    'Loading...', 0

*-------------------
* Trap codes
*-------------------
CMD_PEN_COLOR       EQU     80
CMD_DRAW_PIXEL      EQU     82
CMD_OUTPUT_RES      EQU     33
CMD_CLEAR_SCREEN    EQU     11
CMD_DRAW_STRING     EQU     95
CMD_DBL_BUFFER      EQU     92
CMD_REPAINT         EQU     94

DBL_BUFFER_ON       EQU     17
DBL_BUFFER_OFF      EQU     16

*-------------------
* Background Bitmap file descriptors
*-------------------
LifeSaver01         ds.l    0
BitmapData          INCBIN  "images/inside-a-factory.bmp"
BG_ImageData        ds.l    1
BG_Height           ds.l    1
BG_Width            ds.l    1   ; corresponds to number of bytes per row
ImageDataOffset     EQU     (BitmapData+10)      ; LONG
ImageWidth          EQU     (ImageDataOffset+8)  ; LONG
ImageHeight         EQU     (ImageWidth+4)       ; LONG
BitsPerPixel        EQU     24                   ; WORD

*-------------------
* Character Bitmap file descriptors
*-------------------
LifeSaver02         ds.l    0
CharBitmapData      INCBIN  "images/alien.bmp"
CharImageDataOffset EQU     (CharBitmapData+10)      ; LONG
CharImageWidth      EQU     (CharImageDataOffset+8)  ; LONG
CharImageHeight     EQU     (CharImageWidth+4)       ; LONG
        
        END     START
        

        












*~Font name~Courier New~
*~Font size~14~
*~Tab type~1~
*~Tab size~4~

*-----------------------------------------------------------
* Program Number: 3
* Written by    : Nihav Jain
* Date Created  : 10/01/2015
* Description   : Interactive Game
*-----------------------------------------------------------

ALL_REGS            REG     D0-D7/A0-A6
ALL_BMP_DRAW_REGS   REG     D0-D7/A0
*-------------------
* MAIN
*-------------------
START   ORG     $1000

        * resize output window 
        move.w  #STAGE_WIDTH, d1
        swap    d1
        move.w  #STAGE_HEIGHT, d1
        move.b  #CMD_OUTPUT_RES, d0
        TRAP    #15
        
        * TODO: add start button
        
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
        
        
        JSR     PROCESS_CHARACTER_BITMAP
        move.l  #Char_StartX, d4
        move.l  #Char_StartY, d5
        move.l  #Char_StartY+32, d7
        
        move.l  d4, -(sp)
        move.l  d5, -(sp)
        JSR     DRAW_CHARACTER
        add.l   #8, sp        

        * repaint buffer on main screen
        move.b  #CMD_REPAINT, d0
        TRAP    #15
        
        move.b  #CMD_GET_TIME, d0
        TRAP    #15
        move.l  d0, d2
        
        JSR     GET_TIME_DIFF
* d0: trap codes
* d1: trap code requirements
* d2: time difference
* d3: previous time
* d4: character.x
* d5: character.y
* d6: 
* d7: character.y + character.height
GAME_LOOP:
        JSR     GET_TIME_DIFF

        clr.l   d6
        move.l  #KEY_COMBO, d1
        move.b  #CMD_KEY_DOWN_EVENT, d0
        TRAP    #15
        
    CHECK_RIGHT_KEY:
        andi.b  #$FF, d1
        beq     CHECK_LEFT_KEY
        addi.l  #Char_XVelocity, d6        
    CHECK_LEFT_KEY:
        andi.w  #$FF00, d1
        beq     MOVE_RIGHT
        addi.l  #Char_XVelocity, d6
        beq     GAME_LOOP

    MOVE_LEFT:
        mulu    d6, d2
        asr.l   #8, d2
        
        move.l  d4, d1
        add.l   Char_ActualWidth, d1
        move.l  d1, -12(sp)
        move.l  d7, -16(sp)
        sub.l   d2, d1
        move.l  d1, -(sp)
        move.l  d5, -(sp)
        sub.l   #8, sp
        JSR     SR_DRAW_CLIP_RECTANGLE
        add.l   #16, sp
        sub.l   d2, d4
        bra     REDRAW_CHARACTER  
    MOVE_RIGHT:
        mulu    d6, d2
        asr.l   #8, d2
        
        move.l  d4, -(sp)
        move.l  d5, -(sp)        
        add.l   d2, d4
        move.l  d4, -(sp)
        move.l  d7, -(sp)
        JSR     SR_DRAW_CLIP_RECTANGLE
        add.l   #16, sp
        
    REDRAW_CHARACTER:
        move.l  d4, -(sp)
        move.l  d5, -(sp)
        JSR     DRAW_CHARACTER
        add.l   #8, sp        
        
        * repaint buffer on main screen
        move.b  #CMD_REPAINT, d0
        TRAP    #15
        
        *cmp.w   #Char_XMAX, d4
        *blt     GAME_LOOP
        bra GAME_LOOP
        
        move.b  $9,d0
        TRAP    #15

        STOP #$F000
        

GET_TIME_DIFF:
        move.b  #CMD_GET_TIME, d0
        TRAP    #15
        
        move.l  d3, d2      ; previous time to d2
        move.l  d1, d3      ; current time to previous time
        sub.l   d1, d2      ; subtract current time from previous time
        neg.l   d2          ; get absolute value of time difference
*        move.l  #30, d2
        RTS

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

        movem.l ALL_BMP_DRAW_REGS, -(sp)         ; store the register values in stack

        move.l  BG_ImageData, a0
                
        move.l  BG_Height, d2
        sub.l   48(sp), d2
        subi.l  #1, d2
        
        move.l  BG_WIDTH, d5
        
        move.l  52(sp), d3              ; top-left-x to d3
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

        movem.l (sp)+, ALL_BMP_DRAW_REGS
        RTS

*-------------------
* Subroutine : Draws the character at given offset
* Parameteres: (LONG) top-left-x, (LONG) top-left-y (order to push onto stack)
*              44(sp), 40(sp)
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
DRAW_CHARACTER:
        movem.l ALL_BMP_DRAW_REGS, -(sp)         ; store the register values in stack

        move.l  Char_ImageData, a0
                
        move.l  Char_Height, d2
        subi.l  #1, d2
        
        move.l  Char_Width, d5
        
        move.l  d5, d6
        mulu    d2, d6
        move.l  44(sp), d3              ; top-left-x to d3
        move.l  40(sp), d2              ; top-left-y to d2
        move.l  d3, d4
        add.l   Char_ActualWidth, d4
        move.l  d2, d7
        add.l   Char_ActualWidth, d7
        add.l   d5, d5                  
        
    CONTINUE_CHAR_ROW:
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
        
        cmp.l   d4, d3
        blt     CONTINUE_CHAR_ROW
        
        sub.l   d5, d6                  ; update row pointer to to previous row (current = current - NumBytesPerRow)
        move.l  44(sp), d3              ; reset X coordinate
        addi.l  #1, d2
        cmp.l   d7, d2                  ; char width = char height
        blt     CONTINUE_CHAR_ROW
        
        movem.l (sp)+, ALL_BMP_DRAW_REGS
        RTS

*-------------------
* Subroutine: Processes the header of the background image bitmap and saves the required data in memory
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
* Subroutine: Processes the header of the character image bitmap and saves the required data in memory
*-------------------
PROCESS_CHARACTER_BITMAP:

        move.l  CharImageDataOffset, d5
        JSR     SR_SWAP_LONG
        lea     CharBitmapData, a0
        adda.l  d5, a0                  ; adding image data offset to bitmap data start address, a0 now points to the image data
        move.l  a0, Char_ImageData
        
        move.l  CharImageHeight, d5
        JSR     SR_SWAP_LONG
        move.l  d5, Char_Height
        
        move.l  CharImageWidth, d5
        JSR     SR_SWAP_LONG        
        mulu    #BitsPerPixel, d5
        addi.l  #31, d5
        lsr.l   #5, d5                  ; d5 = d5 / 32
        lsl.l   #2, d5                  ; d5 = d5 * 4
        move.l  d5, Char_Width
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
CMD_KEY_DOWN_EVENT  EQU     19
CMD_GET_TIME        EQU     8

DBL_BUFFER_ON       EQU     17
DBL_BUFFER_OFF      EQU     16

*-------------------
* Key codes
*-------------------
KEY_LEFT_ARROW      EQU     $25
KEY_UP_ARROW        EQU     $26
KEY_RIGHT_ARROW     EQU     $27
KEY_SPACEBAR        EQU     $20
KEY_COMBO           EQU     $2527

*-------------------
* Background Bitmap file descriptors
*-------------------
LifeSaver01         ds.l    0
BitmapData          INCBIN  "images/inside-a-factory.bmp"

ImageDataOffset     EQU     (BitmapData+10)      ; LONG
ImageWidth          EQU     (ImageDataOffset+8)  ; LONG
ImageHeight         EQU     (ImageWidth+4)       ; LONG
BitsPerPixel        EQU     24                   ; WORD

BG_ImageData        ds.l    1
BG_Height           ds.l    1
BG_Width            ds.l    1   ; corresponds to number of bytes per row

*-------------------
* Character Bitmap file descriptors
*-------------------
LifeSaver02         ds.l    0
CharBitmapData      INCBIN  "images/alien.bmp"

CharImageDataOffset EQU     (CharBitmapData+10)      ; LONG
CharImageWidth      EQU     (CharImageDataOffset+8)  ; LONG
CharImageHeight     EQU     (CharImageWidth+4)       ; LONG
Char_StartX         EQU     100
Char_StartY         EQU     400
Char_XMAX           EQU     (STAGE_WIDTH-32)
Char_XVelocity      EQU     1000

Char_ImageData      ds.l    1
Char_Height         ds.l    1
Char_Width          ds.l    1   ; corresponds to number of bytes per row
Char_ActualWidth    dc.l    32

*-------------------
* Physics
*-------------------
MAP_ROWS            EQU     20
MAP_COLS            EQU     15
Map                 ds.w    300

*-------------------
* Graphics pipeline
*-------------------
CharacterTrailRedraw    ds.l    2
        
        END     START
        

        















*~Font name~Courier New~
*~Font size~14~
*~Tab type~1~
*~Tab size~4~

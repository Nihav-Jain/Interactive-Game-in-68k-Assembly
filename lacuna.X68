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
        
        JSR     PROCESS_BOX_BITMAP
        
        JSR     PROCESS_CHARACTER_BITMAP
        move.l  #Char_StartX, d4
        move.l  #Char_StartY, d5
        
        move.l  d4, -(sp)
        move.l  d5, -(sp)
        move.l  Char_ImageData, -(sp)
        JSR     DRAW_CHARACTER
        add.l   #12, sp
        
        * repaint buffer on main screen
        move.b  #CMD_REPAINT, d0
        TRAP    #15
        
        move.b  #CMD_GET_TIME, d0
        TRAP    #15
        JSR     SEED_RANDOM_NUMBER
        move.l  d0, d2
        JSR     GET_TIME_DIFF
* d0: trap codes
* d1: trap code requirements
* d2: time difference
* d3: previous time
* d4: character.x
* d5: character.y
* d6: net x-velocity
* d7: copy of input keys status
GAME_LOOP:
        move.l  d4, Char_OldX
        move.l  d5, Char_OldY
        
        JSR     GET_TIME_DIFF
        move.l  d2, CurTimeDiff
    ADD_NEW_BOX:
        add.l   d2, BoxGenerationTimer
        cmpi.l  #200, BoxGenerationTimer
        blt     GET_INPUT
        JSR     ADD_BOX
        move.l  #0, BoxGenerationTimer
    GET_INPUT:
        clr.l   d6
        move.l  #KEY_COMBO, d1
        move.b  #CMD_KEY_DOWN_EVENT, d0
        TRAP    #15
    CHECK_UP_KEY:
        move.l  d1, d7
        andi.l  #$00FF0000, d1
        beq     CHECK_RIGHT_KEY
    JUMP:
        move.l  d3, CopyOfPrevTime
        move.l  d4, -(sp)
        move.l  d5, -(sp)
        move.l  #IsFalling, -(sp)
        JSR     IS_FALLING
        add.l   #12, sp
        move.l  CopyOfPrevTime, d3
        cmpi.b  #1, IsFalling
        beq     UPDATE
        move.l  #2000, Char_YVelocity
        move.b  #1, IsJumping
    CHECK_RIGHT_KEY:
        move.l  d7, d1
        andi.b  #$FF, d1                ; copy in d7
        beq     CHECK_LEFT_KEY
        addi.l  #Char_XVelocity, d6
    CHECK_LEFT_KEY:
        move.l  d7, d1
        andi.w  #$FF00, d1
        beq     MOVE_RIGHT
        addi.l  #Char_XVelocity, d6
        
    MOVE_LEFT:
        mulu    d6, d2
        asr.l   #8, d2

        JSR     CAN_MOVE_LEFT
        cmpi.b  #0, CanMove
        beq     UPDATE
        sub.l   d2, d4
        bra     UPDATE
    MOVE_RIGHT:
        mulu    d6, d2
        asr.l   #8, d2

        JSR     CAN_MOVE_RIGHT
        cmpi.b  #0, CanMove
        beq     UPDATE
        add.l   d2, d4
        
    UPDATE:
        move.l  CurTimeDiff, d2
        
        lea     AllBoxes, a1
    APPLY_GRAVITY_ON_BOXES:
        cmpa.l  LastBox, a1
        bge     APPLY_GRAVITY_ON_CHARACTER
        move.l  (a1), 8(a1)         ; move curX into oldX
        move.l  4(a1), 12(a1)       ; move curY into oldY
        move.l  (a1), -(sp)       ; pointer to curX
        add.l   #16, a1
        move.l  a1, -(sp)
        add.l   #4, a1
        move.l  a1, -(sp)
        sub.l   #16, a1
        move.l  a1, -(sp)
        sub.l   #4, a1
        JSR     APPLY_GRAVITY
        add.l   #12, sp
        
        move.l  8(a1), d6
        cmp.l   (a1), d6
        bne     REDRAW_BACKGROUND_FOR_BOX
        move.l  12(a1), d6
        cmp.l   4(a1), d6
        beq     NEXT_BOX
    REDRAW_BACKGROUND_FOR_BOX:
        move.l  a1, -(sp)
        JSR     UPDATE_MAP
        add.l   #4, sp
        
        move.l  8(a1), -(sp)
        move.l  12(a1), -(sp)
        add.l   #GRID_WIDTH, 8(a1)
        add.l   #GRID_HEIGHT, 12(a1)
        move.l  8(a1), -(sp)
        move.l  12(a1), -(sp)
        JSR     SR_DRAW_CLIP_RECTANGLE      ; change subroutine to accept only top-left x and y and draw to GRID_WIDTH and GRID_HEIGHT
        add.l   #16, sp
    REDRAW_BOX:
        move.l  (a1), -(sp)
        move.l  4(a1), -(sp)
        move.l  Box_ImageData, -(sp)
        JSR     DRAW_CHARACTER
        add.l   #12, sp        
    NEXT_BOX:
        add.l   #BOX_OBJ_SIZE, a1
        bra     APPLY_GRAVITY_ON_BOXES
        
    APPLY_GRAVITY_ON_CHARACTER:    
        move.l  d5, Char_CurY
        move.l  d4, Char_CurX
        move.l  d4, -(sp)
        move.l  #Char_YVelocity, -(sp)
        move.l  #IsFalling, -(sp)
        move.l  #Char_CurY, -(sp)
        JSR     APPLY_GRAVITY
        add.l   #12, sp
        move.l  Char_CurY, d5
    REDRAW_BACKGROUND_FOR_CHARACTER:        
        move.l  Char_OldX, -(sp)
        move.l  Char_OldY, -(sp)
        add.l   #GRID_WIDTH, Char_OldX
        add.l   #GRID_HEIGHT, Char_OldY
        move.l  Char_OldX, -(sp)
        move.l  Char_OldY, -(sp)
        JSR     SR_DRAW_CLIP_RECTANGLE      ; change subroutine to accept only top-left x and y and draw to GRID_WIDTH and GRID_HEIGHT
        add.l   #16, sp
        
    REDRAW_CHARACTER:
        move.l  d4, -(sp)
        move.l  d5, -(sp)
        move.l  Char_ImageData, -(sp)
        JSR     DRAW_CHARACTER
        add.l   #12, sp
                
    REPAINT_FRAME:        
        * repaint buffer on main screen
        move.b  #CMD_REPAINT, d0
        TRAP    #15
        
        bra GAME_LOOP
        
        move.b  $9,d0
        TRAP    #15

        STOP #$F000
        
*----------------------------------------------------------*
*----------------------------------------------------------*
        
        
*********************************************************************
*                   PHYSICS SUBROUTINES                             *
*********************************************************************

CAN_MOVE_LEFT:
        movem.l d4/a5, -(sp)       ; TODO: compare with adding / subtracting the value back
        move.b  #0, CanMove
        sub.l   d2, d4
        cmpi.l  #0, d4
        blt     CANT_MOVE_LEFT
        move.l  d4, -(sp)
        move.l  d5, -(sp)
        JSR     GET_MAP_STATUS
        add.l   #8, sp
        lea     GameMap, a5
        add.l   d3, a5
        cmpi.l  #0, (a5)
        bne     CANT_MOVE_LEFT
        move.b  #1, CanMove
    CANT_MOVE_LEFT:
        movem.l (sp)+, d4/a5
        RTS
        
CAN_MOVE_RIGHT:
        movem.l d4/a5, -(sp)
        move.b  #0, CanMove
        add.l   d2, d4
        addi.l  #GRID_WIDTH, d4
        cmpi.l  #STAGE_WIDTH, d4
        bgt     CANT_MOVE_RIGHT
        move.l  d4, -(sp)
        move.l  d5, -(sp)
        JSR     GET_MAP_STATUS
        add.l   #8, sp
        subi.l  #GRID_WIDTH, d4
        lea     GameMap, a5
        add.l   d3, a5
        cmpi.l  #0, (a5)
        bne     CANT_MOVE_RIGHT
        move.b  #1, CanMove
    CANT_MOVE_RIGHT:
        movem.l (sp)+, d4/a5
        RTS
        
*-------------------
* Subroutine : Applies gravity to falling / jumping physics bodies
* Parameteres: (LONG) curX, (LONG) pointer to Y-Velocity of body, (LONG) pointer to IsFalling, (LONG) pointer to curY
*              40(sp), 36(sp), 32(sp), 28(sp)
*-------------------
APPLY_GRAVITY:
        movem.l d2-d3/d5/a1-a3, -(sp)
        
        move.l  28(sp), a3
        move.l  36(sp), a1
        move.l  32(sp), a2
        move.l  (a1), d3
        mulu    d2, d3

        mulu    #(GRAVITY/2), d2
        cmpa.l  #Char_YVelocity, a1
        bne     ADD_SPEED
        cmpi.b  #1, IsJumping
        beq     DECREASE_SPEED
    ADD_SPEED:
        add.l   d2, (a1)
        bra     CALC_DISTANCE
    DECREASE_SPEED:
        sub.l   d2, (a1)
    CALC_DISTANCE:
        mulu    d2, d2
        lsr.l   #8, d2
        lsr.l   #4, d2
        add.l   d3, d2
        asr.l   #8, d2
        
        cmpa.l  #Char_YVelocity, a1
        bne     ADD_DISTANCE
        cmpi.b  #0, IsJumping
        beq     ADD_DISTANCE
        sub.l   d2, (a3)
        cmp.l   #0, (a1)
        bgt     CHECK_IF_FALLING
        move.b  #0, IsJumping
        bra     CHECK_IF_FALLING
    ADD_DISTANCE:
        add.l   d2, (a3)
        
    CHECK_IF_FALLING:
        move.l  40(sp), d3
        move.l  d3, -(sp)   ; x into sp
        move.l  (a3), -(sp)
        move.l  a2, -(sp)
        JSR     IS_FALLING
        add.l   #12, sp
        cmpi.b  #1, (a2)
        beq     CHARACTER_IS_FALLING
        move.l  d3, (a3)
        move.l  #0, (a1)
        movem.l (sp)+, d2-d3/d5/a1-a3
        RTS
    CHARACTER_IS_FALLING:
        movem.l (sp)+, d2-d3/d5/a1-a3
        RTS
        
*-------------------
* Subroutine : Checks whether the given physics body is falling or not, return max Y value in d3
* Parameteres: (LONG) top-left-x, (LONG) top-left-y, (LONG) pointer to IsFalling
*              20(sp), 16(sp), 12(sp)
*-------------------
IS_FALLING:
        movem.l d4/d5/a6, -(sp)
        move.l  16(sp), a6
        move.l  20(sp), d5
        move.l  24(sp), d3
        lsr.l   #5, d3
        move.l  d3, -(sp)
        move.l  d5, -(sp)
        JSR     GET_TOP_BOX_OF_COLUMN
        add.l   #8, sp
        move.b  #0, (a6)
        cmp.l   d3, d5
        bge     NOT_FALLING_AT_ALL
    NOT_FALLING_IN_CUR_COL:
        move.l  24(sp), d4
        divu    #GRID_WIDTH, d4
        swap    d4
        cmpi.w  #0, d4
        beq     MARK_FALLING
        move.l  24(sp), d3
        lsr.l   #5, d3
        addi.l  #1, d3
        move.l  d3, -(sp)
        move.l  d5, -(sp)
        JSR     GET_TOP_BOX_OF_COLUMN
        add.l   #8, sp
        cmp.l   d3, d5
        bge     NOT_FALLING_AT_ALL
    MARK_FALLING:
        move.b  #1, (a6)
    NOT_FALLING_AT_ALL:
        movem.l (sp)+, d4/d5/a6
        RTS

GET_TIME_DIFF:
*        move.b  #CMD_GET_TIME, d0
*        TRAP    #15
*        
*        move.l  d3, d2      ; previous time to d2
*        move.l  d1, d3      ; current time to previous time
*        sub.l   d1, d2      ; subtract current time from previous time
*        neg.l   d2          ; get absolute value of time difference
        move.l  #1, d2
        RTS
        
*********************************************************************
*                   GRAPHICS SUBROUTINES                            *
*********************************************************************

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
* Parameteres: (LONG) top-left-x, (LONG) top-left-y, (LONG) address of image data to draw (order to push onto stack)
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

        move.l  BMP_TO_DRAW(sp), a0
                
        move.l  Char_Height, d2
        subi.l  #1, d2
        
        move.l  Char_Width, d5
        
        move.l  d5, d6
        mulu    d2, d6
        move.l  LEFT_X_PARAM(sp), d3              ; top-left-x to d3
        move.l  TOP_Y_PARAM(sp), d2              ; top-left-y to d2
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
        move.l  LEFT_X_PARAM(sp), d3              ; reset X coordinate
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
* Subroutine: Processes the header of the box image bitmap and saves the required data in memory
*-------------------
PROCESS_BOX_BITMAP:

        move.l  BoxImageDataOffset, d5
        JSR     SR_SWAP_LONG
        lea     BoxBitmapData, a0
        adda.l  d5, a0                  ; adding image data offset to bitmap data start address, a0 now points to the image data
        move.l  a0, Box_ImageData
        
        move.l  BoxImageHeight, d5
        JSR     SR_SWAP_LONG
        move.l  d5, Box_Height
        
        move.l  BoxImageWidth, d5
        JSR     SR_SWAP_LONG        
        mulu    #BitsPerPixel, d5
        addi.l  #31, d5
        lsr.l   #5, d5                  ; d5 = d5 / 32
        lsl.l   #2, d5                  ; d5 = d5 * 4
        move.l  d5, Box_Width
        RTS
        
*-------------------
* Subroutine: Copies the double buffer to the main screen
*-------------------
REPAINT:
        move.b  #CMD_REPAINT, d0
        TRAP    #15
        RTS
        
*********************************************************************
*                   GAMEPLAY SUBROUTINES                            *
*********************************************************************

* pointer to box object
UPDATE_MAP:
        movem.l d3-d4/a1-a2, -(sp)
        lea     GameMap, a1
        move.l  20(sp), a2
        move.l  8(a2), -(sp)
        move.l  12(a2), -(sp)
        JSR     GET_MAP_STATUS
        add.l   #8, sp
        move.l  #0, (a1, d3)
        
        move.l  (a2), -(sp)
        move.l  4(a2), -(sp)
        JSR     GET_MAP_STATUS
        add.l   #8, sp        
        move.l  a2, (a1, d3)
        movem.l (sp)+, d3-d4/a1-a2
        RTS

* Return offset to to map location for coordinates (x, y) in d3
GET_MAP_STATUS:
        move.l  8(sp), d3
        move.l  4(sp), d4
        lsr.l   #5, d3
        lsr.l   #5, d4
        mulu    #MAP_ROWS, d4
        add.l   d4, d3
        lsl.l   #2, d3
        RTS
        
* get column number (0-19) in d3 and Y value and return max possible Y value (Y-GridHeight)
GET_TOP_BOX_OF_COLUMN:
        movem.l a0, -(sp)
        move.l  12(sp), d3
        lsl.l   #2, d3      ; ///right shift by 5 to divide by 32, then left shift by 2 to multiply by 4
        lea     GameMap, a0
        add.l   d3, a0
        move.l  8(sp), d3
        lsr.l   #5, d3
        addi.l  #1, d3
        move.l  d3, 8(sp)
        mulu    #ROW_SIZE_IN_BYTES, d3
        add.l   d3, a0
        move.l  8(sp), d3
    TEST_NEXT_ROW:
        cmp.l   #CurTimeDiff, a0
        bge     GOT_TOP
        cmp.l   #0, (a0)
        bne     GOT_TOP
        add.l   #ROW_SIZE_IN_BYTES, a0
        addi.l  #1, d3
        bra     TEST_NEXT_ROW
    GOT_TOP:
        lsl.l   #5, d3
        subi.l  #GRID_HEIGHT, d3
        movem.l (sp)+, a0
        RTS
        
* TODO: add bias to column generator 
ADD_BOX:
        cmpi.w  #MAX_BOXES, NumBoxes
        bge     NO_MORE_BOXES
        movem.l d0-d1/a0, -(sp)
        move.l  LastBox, a0
        JSR     GENERATE_RANDOM_MOD_20
        move.l  RandomColumn, d0
        lsl.w   #5, d0
        move.l  d0, (a0)+       ; current X
        move.l  #0, (a0)+       ; current Y
        move.l  d0, (a0)+       ; old X
        move.l  #0, (a0)+       ; old Y
        move.l  #0, (a0)+       ; Y velocity
        move.b  #0, (a0)+       ; isFalling
        move.b  #0, (a0)+       ; isPickedUp
        move.l  a0, LastBox
        addi.w  #1, NumBoxes
        movem.l (sp)+, d0-d1/a0
    NO_MORE_BOXES:
        RTS

*********************************************************************
*                   UTILITY SUBROUTINES                             *
*********************************************************************

SEED_RANDOM_NUMBER:
        movem.l d6, -(sp)
        move.l  d1, d6
        mulu    #RANDOM_LARGE, d6
        move.l  d6, RandomNumber
        movem.l (sp)+, d6
        RTS
        
GENERATE_RANDOM_MOD_20:
        movem.l d0/d1, -(sp)
        move.l  RandomNumber, d6
        mulu    #RANDOM_LARGE, d6
        move.l  #CMD_GET_CYCLES, d0
        TRAP    #15
        mulu    d1, d6
        bcs     NO_RANDOM_CARRY
        add.l   #1, d6
    NO_RANDOM_CARRY:
        move.l  d6, RandomNumber
        divu    #20, d6
        clr.w   d6
        swap    d6
        cmpi.l  #20, d6
        blt     RETURN_FROM_HERE
        divu    #20, d6
        clr.w   d6
        swap    d6
        move.l  d6, RandomColumn
    RETURN_FROM_HERE:
        movem.l (sp)+, d0/d1
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
GRID_WIDTH          EQU     32
GRID_HEIGHT         EQU     32
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
CMD_GET_CYCLES      EQU     31

DBL_BUFFER_ON       EQU     17
DBL_BUFFER_OFF      EQU     16

*-------------------
* Key codes
*-------------------
KEY_LEFT_ARROW      EQU     $25
KEY_UP_ARROW        EQU     $26
KEY_RIGHT_ARROW     EQU     $27
KEY_SPACEBAR        EQU     $20
KEY_COMBO           EQU     $00262527

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
Char_StartX         EQU     96
Char_StartY         EQU     100
Char_XMAX           EQU     (STAGE_WIDTH-32)
Char_XVelocity      EQU     1000
Char_JumpVelocity   EQU     4000
Char_MaxYVelocity   EQU     1000

Char_ImageData      ds.l    1
Char_Height         ds.l    1
Char_Width          ds.l    1   ; corresponds to number of bytes per row
Char_ActualWidth    dc.l    32

*-------------------
* Box Bitmap file descriptors
*-------------------
LifeSaver03         ds.l    0
BoxBitmapData       INCBIN  "images/crate.bmp"

BoxImageDataOffset  EQU     (BoxBitmapData+10)      ; LONG
BoxImageWidth       EQU     (BoxImageDataOffset+8)  ; LONG
BoxImageHeight      EQU     (BoxImageWidth+4)       ; LONG

Box_ImageData       ds.l    1
Box_Height          ds.l    1
Box_Width           ds.l    1   ; corresponds to number of bytes per row
Box_ActualWidth     dc.l    32
        
MAX_BOXES           EQU     280
BOX_OBJ_SIZE        EQU     22
LifeSaver04         ds.l    0
AllBoxes            ds.b    BOX_OBJ_SIZE*MAX_BOXES    ; curX, curY, oldX, oldY, yVelocity, isFalling, isPickedUp
NumBoxes            dc.w    0
LastBox             dc.l    AllBoxes
BoxGenerationTimer  dc.l    0

*-------------------
* Physics
*-------------------
MAP_ROWS            EQU     20
MAP_COLS            EQU     15
ROW_SIZE_IN_BYTES   EQU     20*4
GRAVITY             EQU     100
RANDOM_LARGE        EQU     $5678
RANDOM_SMALL        EQU     $1231

GameMap             dcb.l   300,$00    
CurTimeDiff         dc.l    0
CanMove             dc.b    0
IsFalling           dc.b    0
IsJumping           dc.b    0
Char_YVelocity      dc.l    0
RandomNumber        dc.l    RANDOM_SMALL
RandomColumn        dc.l    0
CopyOfPrevTime      dc.l    0
*-------------------
* Graphics pipeline
*-------------------
LEFT_X_PARAM            EQU     48
TOP_Y_PARAM             EQU     44
BMP_TO_DRAW             EQU     40

Char_CurX               dc.l    Char_StartX
Char_CurY               dc.l    Char_StartY
Char_OldX               dc.l    Char_StartX
Char_OldY               dc.l    Char_StartY
BLOCKS_TO_REDRAW        ds.l    10

        
        END     START
        

        

















*~Font name~Courier New~
*~Font size~14~
*~Tab type~1~
*~Tab size~4~

*-----------------------------------------------------------
* Program Number: 3
* Written by    : Nihav Jain
* Date Created  : 10/01/2015 - 10/15/2015
* Title         : Avoid and Evade
* Description   : Avoid the falling blocks
*-----------------------------------------------------------

*-------------------
* Registers
*-------------------
ALL_REGS            REG     D0-D7/A0-A6
REG_DRAW_BMP        REG     D0-D7/A0

REG_DRAW_SCORE      REG     d0-d4/d6-d7
REG_DRAW_DIGIT      REG     d0-d7/a3-a5
REG_DRAW_SEGMENT    REG     d0-d4

REG_GENERATE_RANDOM REG     d0/d1

REG_ADD_BOX         REG     d0-d1/d3/a0
REG_UPDATE_MAP      REG     d3-d4/a1-a2

REG_IS_FALLING      REG     d4/d5/a6
REG_APPLY_GRAVITY   REG     d2-d3/d5/a1-a3
REG_CAN_MOVE        REG     d3/d4/d5/a5
*-------------------
* MAIN
*-------------------
START   ORG     $1000
        
        JSR     RESIZE_OUTPUT_WINDOW
        JSR     INTRODUCTION
        JSR     INITIALIZE
        
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
        JSR     TIME_FOR_NEW_BOX
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
        add.l   #SIZE_OF_IS_FALLING_PARAMS, sp
        
        move.l  CopyOfPrevTime, d3
        cmpi.b  #1, IsFalling                               ; if character is in air, dont allow new jump
        beq     UPDATE
        move.l  #Char_JumpVelocity, Char_YVelocity
        move.b  #1, IsJumping
    CHECK_RIGHT_KEY:
        move.l  d7, d1
        andi.b  #$FF, d1
        beq     CHECK_LEFT_KEY
        addi.l  #Char_XVelocity, d6
        JSR     MOVE_RIGHT
        bra     UPDATE
    CHECK_LEFT_KEY:
        move.l  d7, d1
        andi.w  #$FF00, d1
        beq     UPDATE
        addi.l  #Char_XVelocity, d6
        JSR     MOVE_LEFT


    UPDATE:
        move.l  CurTimeDiff, d2
        move.l  d5, Char_CurY
        move.l  d4, Char_CurX
        
        cmpi.w  #MAX_BOXES, NumBoxes        ; game is over once the limit for boxes is reached
        bge     GAME_OVER
        
        JSR     UPDATE_BOXES
        cmpi.b  #0, Char_Alive
        beq     EXIT_GAME_LOOP
        
        JSR     UPDATE_CHARACTER
        JSR     REPAINT
        bra GAME_LOOP
    *GAME LOOP ENDS*
    
    EXIT_GAME_LOOP:
        JSR     GAME_OVER
        
        move.b  $9,d0
        TRAP    #15

        STOP #$F000
        
*----------------------------------------------------------*
*----------------------------------------------------------*
        
        
*********************************************************************
*                   PHYSICS SUBROUTINES                             *
*********************************************************************

*-------------------
* Checks if character can move left for the given displacement
*-------------------
CAN_MOVE_LEFT:
        movem.l REG_CAN_MOVE, -(sp)
        move.b  #0, CanMove        
        sub.l   d2, d4                  ; subtract displacement to current X

        cmpi.l  #0, d4                  ; check left wall
        blt     CANT_MOVE_LEFT

        * get status of grid with updated coordinates
        move.l  d4, -(sp)
        move.l  d5, -(sp)
        JSR     GET_MAP_STATUS
        add.l   #SIZE_OF_GET_MAP_STATUS_PARAMS, sp

        lea     GameMap, a5
        add.l   d3, a5                  ; add cell offset to GameMap pointer
        cmpi.l  #0, (a5)                ; check if cell is empty
        bne     CANT_MOVE_LEFT
        
        move.l  d5, d3
        divu    #GRID_HEIGHT, d3
        andi.l  #$FFFF0000, d3
        beq     UPDATE_MOVE_LEFT_FLAG
        lsr.l   #5, d5
        addi.l  #1, d5
        lsl.l   #5, d5
        * get status of grid with updated coordinates
        move.l  d4, -(sp)
        move.l  d5, -(sp)
        JSR     GET_MAP_STATUS
        add.l   #SIZE_OF_GET_MAP_STATUS_PARAMS, sp
        lea     GameMap, a5
        add.l   d3, a5                  ; add cell offset to GameMap pointer
        cmpi.l  #0, (a5)                ; check if cell is empty
        bne     CANT_MOVE_LEFT
    UPDATE_MOVE_LEFT_FLAG:
        move.b  #1, CanMove
    CANT_MOVE_LEFT:
        movem.l (sp)+, REG_CAN_MOVE
        RTS
        
*-------------------
* Checks if character can move right for the given displacement
*-------------------
CAN_MOVE_RIGHT:
        movem.l REG_CAN_MOVE, -(sp)
        move.b  #0, CanMove
        add.l   d2, d4                  ; add displacement to current X
        addi.l  #GRID_WIDTH, d4         ; get rightX of character
        
        cmpi.l  #STAGE_WIDTH, d4        ; check right wall
        bgt     CANT_MOVE_RIGHT
        
        * get status of grid with updated coordinates
        move.l  d4, -(sp)
        move.l  d5, -(sp)
        JSR     GET_MAP_STATUS
        add.l   #SIZE_OF_GET_MAP_STATUS_PARAMS, sp
        
        *subi.l  #GRID_WIDTH, d4
        lea     GameMap, a5
        add.l   d3, a5                  ; add cell offset to GameMap pointer
        cmpi.l  #0, (a5)                ; check if cell is empty
        bne     CANT_MOVE_RIGHT
        
        move.l  d5, d3
        divu    #GRID_HEIGHT, d3
        andi.l  #$FFFF0000, d3
        beq     UPDATE_MOVE_LEFT_FLAG
        lsr.l   #5, d5
        addi.l  #1, d5
        lsl.l   #5, d5
        * get status of grid with updated coordinates
        move.l  d4, -(sp)
        move.l  d5, -(sp)
        JSR     GET_MAP_STATUS
        add.l   #SIZE_OF_GET_MAP_STATUS_PARAMS, sp
        lea     GameMap, a5
        add.l   d3, a5                  ; add cell offset to GameMap pointer
        cmpi.l  #0, (a5)                ; check if cell is empty
        bne     CANT_MOVE_RIGHT
    UPDATE_MOVE_RIGHT_FLAG:
        move.b  #1, CanMove
    CANT_MOVE_RIGHT:
        movem.l (sp)+, REG_CAN_MOVE
        RTS
        
*-------------------
* Applies gravity to falling / jumping physics bodies
* Parameteres: (LONG) curX, (LONG) pointer to Y-Velocity of body, (LONG) pointer to IsFalling, (LONG) pointer to curY
*-------------------
APPLY_GRAVITY:
        movem.l REG_APPLY_GRAVITY, -(sp)
        
        move.l  PARAM_GRAV_PTR_Y(sp), a3
        move.l  PARAM_GRAV_PTR_YVEL(sp), a1
        move.l  PARAM_GRAV_PTR_FALLING(sp), a2
        move.l  (a1), d3
        mulu    d2, d3                      ; velocity * time difference = displacement

        mulu    #(GRAVITY/2), d2            ; for v = u + at (taken a/2 here to reduce number of calculations)
        
        cmpa.l  #Char_YVelocity, a1         ; are we applying gravity to character?
        bne     ADD_SPEED
        cmpi.b  #1, IsJumping               ; is character jumping?
        beq     DECREASE_SPEED
    ADD_SPEED:
        add.l   d2, (a1)                    ; v = u + at
        bra     CALC_DISTANCE
    DECREASE_SPEED:
        sub.l   d2, (a1)                    ; decrease velocity if jumping (negative acceleration) -> v = u - at
        bpl     CALC_DISTANCE
        neg.l   (a1)                        ; if velocity becomes negative, that means body will travel downwards from next frame
    * for S = ut + a(t^2) / 2
    CALC_DISTANCE:
        mulu    d2, d2                      ; (at)^2
        lsr.l   #8, d2                      ; fixed point value conversion to actual base 10 (divide by 2^12)
        lsr.l   #4, d2
        add.l   d3, d2                      ; u + a(t^2) / 2
        asr.l   #8, d2
        
        cmpa.l  #Char_YVelocity, a1         ; are we applying gravity to character?
        bne     ADD_DISTANCE
        cmpi.b  #0, IsJumping
        beq     ADD_DISTANCE
        sub.l   d2, (a3)                    ; subtract the calculated displacement if character is jumping
        cmp.l   #0, (a1)                    ; if Y velocity is now 0, check if character is in air or on a surface
        bgt     CHECK_IF_FALLING
        move.b  #0, IsJumping               ; reset jumping flag
        bra     CHECK_IF_FALLING
    ADD_DISTANCE:
        add.l   d2, (a3)
        
    CHECK_IF_FALLING:
        move.l  PARAM_GRAV_X(sp), d3
        move.l  d3, -(sp)
        move.l  (a3), -(sp)
        move.l  a2, -(sp)
        JSR     IS_FALLING
        add.l   #SIZE_OF_IS_FALLING_PARAMS, sp
        
        cmpi.b  #1, (a2)
        beq     CHARACTER_IS_FALLING
        move.l  d3, (a3)                    ; stick to floor if not falling
        move.l  #0, (a1)                    ; mark not falling
    CHARACTER_IS_FALLING:
        movem.l (sp)+, REG_APPLY_GRAVITY
        RTS
        
*-------------------
* Checks whether the given physics body is falling or not, returns max possible Y value to which this body can fall in d3
* Parameteres: (LONG) top-left-x, (LONG) top-left-y, (LONG) pointer to IsFalling
*-------------------
IS_FALLING:
        movem.l REG_IS_FALLING, -(sp)
        
        move.l  PARAM_FALLING_PTR(sp), a6
        move.l  PARAM_FALLING_Y(sp), d5
        move.l  PARAM_FALLING_X(sp), d3
        
        lsr.l   #5, d3                              ; get column number
        move.l  d3, -(sp)
        move.l  d5, -(sp)
        JSR     GET_TOP_BOX_OF_COLUMN
        add.l   #SIZE_OF_GET_TOP_BOX_PARAMS, sp
        
        move.b  #0, (a6)                            ; reset IsFalling for this body
        cmp.l   d3, d5                              ; if current Y is more than or equal to max possible Y, then body is not falling
        bge     NOT_FALLING_AT_ALL
        
    * if character is not aligned with the grids, then check for next cell as well (current column + 1)
    NOT_FALLING_IN_CUR_COL:
        move.l  PARAM_FALLING_X(sp), d4
        divu    #GRID_WIDTH, d4
        swap    d4                                  ; get remainder in lower word of d4
        cmpi.w  #0, d4                              ; check if body is aligned to a grid or not
        beq     MARK_FALLING                        ; if 0, then body is aligned to a grid
        
        move.l  PARAM_FALLING_X(sp), d3
        lsr.l   #5, d3                              ; get current column
        addi.l  #1, d3                              ; incrememt current column value by 1
        move.l  d3, -(sp)
        move.l  d5, -(sp)
        JSR     GET_TOP_BOX_OF_COLUMN
        add.l   #SIZE_OF_GET_TOP_BOX_PARAMS, sp
        cmp.l   d3, d5                              ; if current Y is more than or equal to max possible Y of thislumn, then body is not falling
        bge     NOT_FALLING_AT_ALL
    MARK_FALLING:
        move.b  #1, (a6)                            ; mark body to be falling
    NOT_FALLING_AT_ALL:
        movem.l (sp)+, REG_IS_FALLING
        RTS

*-------------------
* Gets the time difference since last frame into d2
*-------------------
GET_TIME_DIFF:
        move.b  #CMD_GET_TIME, d0
        TRAP    #15
        
        move.l  d3, d2      ; previous time to d2
        move.l  d1, d3      ; current time to previous time
        sub.l   d1, d2      ; subtract current time from previous time
        neg.l   d2          ; get absolute value of time difference
*        move.l  #1, d2
        RTS
        
*********************************************************************
*                   GRAPHICS SUBROUTINES                            *
*********************************************************************

*-------------------
* Draws the specified clipping rectangle
* Parameteres: (LONG) top-left-x, (LONG) top-left-y, (LONG) bottom-right-x, (LONG) bottom-right-y
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
DRAW_CLIP_RECTANGLE:

        movem.l REG_DRAW_BMP, -(sp)         ; store the register values in stack

        move.l  BG_ImageData, a0
                
        move.l  BG_Height, d2
        sub.l   PARAM_BMP_UY(sp), d2
        subi.l  #1, d2
        
        move.l  BG_WIDTH, d5
        
        move.l  PARAM_BMP_LX(sp), d3              ; top-left-x to d3
        move.l  d3, d7
        add.l   d3, d7
        add.l   d3, d7
        
        move.l  d5, d4
        mulu    d2, d4                  ; y offset (row offset)
        move.l  d4, d6      
        add.l   d7, d6                  ; offset (in bytes) of pixel to be drawn from the image data
        move.l  PARAM_BMP_UY(sp), d2

    CONTINUE_ROW:
        clr.l   d1
        
        move.b  (a0, d6.l), d1          ; #$000000BB
        swap    d1                      ; #$00BB0000
        move.b  1(a0, d6.l), d1         ; #$00BB00GG
        lsl.w   #8, d1                  ; #$00BBGG00
        move.b  2(a0, d6.l), d1         ; #$00BBGGRR
        
        move.l  #CMD_SET_PEN_COLOR, d0
        TRAP    #15
        
        move.l  d3, d1
        move.l  #CMD_DRAW_PIXEL, d0
        TRAP    #15
        
        addi.l  #1, d3                  ; increment X coordinate
        addi.l  #3, d6
        
        cmp.l   PARAM_BMP_RX(sp), d3
        blt     CONTINUE_ROW
        
        sub.l   d5, d4                  ; update row pointer to to previous row (current = current - NumBytesPerRow)
        move.l  d4, d6                  
        add.l   d7, d6
        move.l  PARAM_BMP_LX(sp), d3              ; reset X coordinate
        addi.l  #1, d2
        cmp.l   PARAM_BMP_LY(sp), d2
        blt     CONTINUE_ROW

        movem.l (sp)+, REG_DRAW_BMP
        RTS

*-------------------
* Draws the physics bodies (box and character) at given offset
* Parameteres: (LONG) top-left-x, (LONG) top-left-y, (LONG) address of image data to draw
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
DRAW_PHYSICS_BODY:
        movem.l REG_DRAW_BMP, -(sp)         ; store the register values in stack

        move.l  PARAM_BMP_TO_DRAW(sp), a0
                
        move.l  Char_Height, d2
        subi.l  #1, d2
        
        move.l  Char_Width, d5
        
        move.l  d5, d6
        mulu    d2, d6
        move.l  PARAM_BMP_LEFT_X(sp), d3    ; top-left-x to d3
        move.l  PARAM_BMP_TOP_Y(sp), d2     ; top-left-y to d2
        move.l  d3, d4
        add.l   Char_ActualWidth, d4
        move.l  d2, d7
        add.l   Char_ActualWidth, d7
        add.l   d5, d5                  
        
    CONTINUE_BODY_ROW:
        clr.l   d1
        
        move.b  (a0, d6.l), d1              ; #$000000BB
        swap    d1                          ; #$00BB0000
        move.b  1(a0, d6.l), d1             ; #$00BB00GG
        lsl.w   #8, d1                      ; #$00BBGG00
        move.b  2(a0, d6.l), d1             ; #$00BBGGRR
        
        cmp.l   #$00FFFFFF, d1
        beq     INCREMENT_INDEX
        move.l  #CMD_SET_PEN_COLOR, d0
        TRAP    #15
        
        move.l  d3, d1
        move.l  #CMD_DRAW_PIXEL, d0
        TRAP    #15
    INCREMENT_INDEX:
        addi.l  #1, d3                      ; increment X coordinate
        addi.l  #3, d6
        
        cmp.l   d4, d3
        blt     CONTINUE_BODY_ROW
        
        sub.l   d5, d6                      ; update row pointer to to previous row (current = current - NumBytesPerRow)
        move.l  PARAM_BMP_LEFT_X(sp), d3    ; reset X coordinate
        addi.l  #1, d2
        cmp.l   d7, d2                      ; char width = char height
        blt     CONTINUE_BODY_ROW
        
        movem.l (sp)+, REG_DRAW_BMP
        RTS

*-------------------
* Processes the header of the background image bitmap and saves the required data in memory
*-------------------
PROCESS_BACKGROUND_BITMAP:

        move.l  ImageDataOffset, d5
        JSR     SWAP_LONG
        lea     BitmapData, a0
        adda.l  d5, a0                  ; adding image data offset to bitmap data start address, a0 now points to the image data
        move.l  a0, BG_ImageData
        
        move.l  ImageHeight, d5
        JSR     SWAP_LONG
        move.l  d5, BG_Height
        
        move.l  ImageWidth, d5
        JSR     SWAP_LONG
        
        * calculating number of bytes per row
        mulu    #BitsPerPixel, d5
        addi.l  #31, d5
        lsr.l   #5, d5                  ; d5 = d5 / 32
        lsl.l   #2, d5                  ; d5 = d5 * 4
        move.l  d5, BG_Width
        RTS

*-------------------
* Processes the header of the character image bitmap and saves the required data in memory
*-------------------
PROCESS_CHARACTER_BITMAP:

        move.l  CharImageDataOffset, d5
        JSR     SWAP_LONG
        lea     CharBitmapData, a0
        adda.l  d5, a0                  ; adding image data offset to bitmap data start address, a0 now points to the image data
        move.l  a0, Char_ImageData
        
        move.l  CharImageHeight, d5
        JSR     SWAP_LONG
        move.l  d5, Char_Height
        
        move.l  CharImageWidth, d5
        JSR     SWAP_LONG
        
        * calculating number of bytes per row
        mulu    #BitsPerPixel, d5
        addi.l  #31, d5
        lsr.l   #5, d5                  ; d5 = d5 / 32
        lsl.l   #2, d5                  ; d5 = d5 * 4
        move.l  d5, Char_Width
        RTS
        
*-------------------
* Processes the header of the box image bitmap and saves the required data in memory
*-------------------
PROCESS_BOX_BITMAP:

        move.l  BoxImageDataOffset, d5
        JSR     SWAP_LONG
        lea     BoxBitmapData, a0
        adda.l  d5, a0                  ; adding image data offset to bitmap data start address, a0 now points to the image data
        move.l  a0, Box_ImageData
        
        move.l  BoxImageHeight, d5
        JSR     SWAP_LONG
        move.l  d5, Box_Height
        
        move.l  BoxImageWidth, d5
        JSR     SWAP_LONG
        
        * calculating number of bytes per row
        mulu    #BitsPerPixel, d5
        addi.l  #31, d5                 
        lsr.l   #5, d5                  ; d5 = d5 / 32
        lsl.l   #2, d5                  ; d5 = d5 * 4
        move.l  d5, Box_Width
        RTS
        
*-------------------
* Copies the double buffer to the main screen
*-------------------
REPAINT:
        move.b  #CMD_REPAINT, d0
        TRAP    #15
        RTS
        
*-------------------
* Removes all graphics from the screen
*-------------------        
CLEAR_SCREEN:
        move.w  #$FF00, d1
        move.b  #CMD_CLEAR_SCREEN, d0
        TRAP    #15
        RTS
        
*********************************************************************
*                   GAMEPLAY SUBROUTINES                            *
*********************************************************************

*-------------------
* Updates map with pointer of given box
* Parameters: (LONG) pointer to box object
*-------------------
UPDATE_MAP:
        movem.l REG_UPDATE_MAP, -(sp)
        lea     GameMap, a1
        
        move.l  PARAM_PTR_BOX_OBJ(sp), a2
        move.l  BOX_OLD_X(a2), -(sp)
        move.l  BOX_OLD_Y(a2), -(sp)
        JSR     GET_MAP_STATUS
        add.l   #SIZE_OF_GET_MAP_STATUS_PARAMS, sp
        move.l  #0, (a1, d3)                        ; reset old cell of box to 0
        
        move.l  (a2), -(sp)
        move.l  BOX_CUR_Y(a2), -(sp)
        JSR     GET_MAP_STATUS
        add.l   #SIZE_OF_GET_MAP_STATUS_PARAMS, sp
        move.l  a2, (a1, d3)                        ; set pointer of box to current cell
        
        movem.l (sp)+, REG_UPDATE_MAP
        RTS

*-------------------
* Return in d3 the offset to to map location for coordinates (x, y)
* Parameters: (LONG) X, (LONG) Y
*-------------------
GET_MAP_STATUS:
        move.l  PARAM_GET_MAP_STATUS_X(sp), d3
        move.l  PARAM_GET_MAP_STATUS_Y(sp), d4
        lsr.l   #5, d3              ; get column number
        lsr.l   #5, d4              ; get row number
        mulu    #MAP_ROWS, d4
        add.l   d4, d3
        lsl.l   #2, d3
        RTS
        
*-------------------
* Returns the maximum possible Y value, greater than given Y, to which a body (box or character) can fall in the given column
* Parameters: (LONG) column number, (LONG) min Y value to consider
*-------------------
GET_TOP_BOX_OF_COLUMN:
        movem.l a0, -(sp)
        
        move.l  PARAM_COLUMN_NUMBER(sp), d3
        lsl.l   #2, d3                  ; multiply by 4 to get offset in GameMap
        lea     GameMap, a0
        add.l   d3, a0
        move.l  PARAM_MIN_Y(sp), d3
        lsr.l   #5, d3                  ; divide by 32 i.e. GRID_HEIGHT to get row number
        addi.l  #1, d3                  ; increment current row number by 1 to start checking
        move.l  d3, PARAM_MIN_Y(sp)     ; keep a copy of row number
        mulu    #ROW_SIZE_IN_BYTES, d3  
        add.l   d3, a0
        move.l  PARAM_MIN_Y(sp), d3
    TEST_NEXT_ROW:
        cmp.l   #CurTimeDiff, a0        ; if end of GameMap reached
        bge     GOT_TOP
        cmp.l   #0, (a0)
        bne     GOT_TOP
        add.l   #ROW_SIZE_IN_BYTES, a0
        addi.l  #1, d3
        bra     TEST_NEXT_ROW
    GOT_TOP:
        lsl.l   #5, d3                  ; multiply column number by 32 to get max possible y value for fall
        subi.l  #GRID_HEIGHT, d3
        
        movem.l (sp)+, a0
        RTS
        
TIME_FOR_NEW_BOX:
        add.l   d2, BoxGenerationTimer
        cmpi.l  #200, BoxGenerationTimer          ; add a new box every 2 seconds
        blt     RTS_FROM_NEW_BOX
        JSR     ADD_BOX
        move.l  #0, BoxGenerationTimer
    RTS_FROM_NEW_BOX:
        RTS
*-------------------
* Adds a new box (if possible) to the stage
*-------------------
ADD_BOX:
        cmpi.w  #MAX_BOXES, NumBoxes
        bge     NO_MORE_BOXES
        
        movem.l REG_ADD_BOX, -(sp)
        
        move.l  LastBox, a0
        JSR     GENERATE_RANDOM_MOD_20      ; generate a random column number to add the box to
        move.l  RandomColumn, d0
        
    CHECK_IF_COL_IS_FULL:                   ; if that column is already stacked full with boxes, goto next column until you find an empty slot
        move.l  d0, -(sp)
        move.l  #0, -(sp)
        JSR     GET_TOP_BOX_OF_COLUMN
        add.l   #SIZE_OF_GET_TOP_BOX_PARAMS, sp
        
        cmpi.l  #MIN_STACKED_BOX_Y, d3
        bgt     ADD_TO_CURRENT_COL
        addi.b  #1, d0
        
        cmpi.b  #MAP_ROWS, d0
        blt     CHECK_IF_COL_IS_FULL
        move.b  #0, d0
        bra     CHECK_IF_COL_IS_FULL
    
    ADD_TO_CURRENT_COL:
        lsl.w   #5, d0                      ; multiply column with 32 i.e. GRID_WIDTH
        move.l  d0, (a0)+                   ; current X
        move.l  #0, (a0)+                   ; current Y
        move.l  d0, (a0)+                   ; old X
        move.l  #0, (a0)+                   ; old Y
        move.l  #0, (a0)+                   ; Y velocity
        move.b  #0, (a0)+                   ; isFalling
        move.b  #0, (a0)+                   ; isPickedUp
        
        move.l  a0, LastBox
        addi.w  #1, NumBoxes
        
        move.w  #0, -(sp)                   ; padding to make an even boundary in stack
        move.w  NumBoxes, -(sp)
        JSR     DRAW_SCORE
        add.l   #SIZE_OF_DRAW_SCORE_PARAMS, sp
        
        movem.l (sp)+, REG_ADD_BOX
    NO_MORE_BOXES:
        RTS
        
        
RESIZE_OUTPUT_WINDOW:
        * resize output window 
        move.w  #SCREEN_WIDTH, d1
        swap    d1
        move.w  #SCREEN_HEIGHT, d1
        move.b  #CMD_OUTPUT_RES, d0
        TRAP    #15
        RTS        
        
INTRODUCTION:
       * display game title
        lea     GameTitle, a1
        move.w  #STAGE_WIDTH/2-60, d1
        move.w  #STAGE_HEIGHT/2, d2
        move.b  #CMD_DRAW_STRING, d0
        TRAP    #15

        * display start game text
        lea     StartGameText, a1
        move.w  #STAGE_WIDTH/2-200, d1
        move.w  #STAGE_HEIGHT/2+40, d2
        move.b  #CMD_DRAW_STRING, d0
        TRAP    #15

        move.b  #CMD_KEY_DOWN_EVENT, d0
    PRESS_TO_START:
        move.l  #KEY_SPACEBAR, d1
        TRAP    #15
        andi.b  #$FF, d1
        beq     PRESS_TO_START
        
        RTS
        
INITIALIZE:
        JSR     CLEAR_SCREEN

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
        JSR     PROCESS_BOX_BITMAP
        JSR     PROCESS_CHARACTER_BITMAP
        
        * draw background in buffer
        move.l  #0, -(sp)
        move.l  #0, -(sp)
        move.l  #STAGE_WIDTH, -(sp)
        move.l  #STAGE_HEIGHT, -(sp)
        JSR     DRAW_CLIP_RECTANGLE
        add.l   #SIZE_OF_DRAW_CLIP_RECT_PARAMS, sp
        
        * initialize character position
        move.l  #Char_StartX, d4
        move.l  #Char_StartY, d5
        
        * draw character
        move.l  d4, -(sp)
        move.l  d5, -(sp)
        move.l  Char_ImageData, -(sp)
        JSR     DRAW_PHYSICS_BODY
        add.l   #SIZE_OF_DRAW_BODY_PARAMS, sp

        * display game description
        lea     GameDescription, a1
        move.w  #200, d1
        move.w  #500, d2
        move.b  #CMD_DRAW_STRING, d0
        TRAP    #15

        * display score
        move.w  #0, -(sp)               ; padding to make even
        move.w  #0, -(sp)
        JSR     DRAW_SCORE
        add.l   #SIZE_OF_DRAW_SCORE_PARAMS, sp
        
        * repaint buffer on main screen
        JSR     REPAINT
        RTS
                
UPDATE_CHARACTER:
        JSR     UPDATE_CHARACTER_PHYSICS
        JSR     UPDATE_CHARACTER_GRAPHICS
        RTS
        
UPDATE_CHARACTER_PHYSICS:
        move.l  Char_CurX, d4
        move.l  Char_CurY, d5
        
        move.l  d4, -(sp)
        move.l  #Char_YVelocity, -(sp)
        move.l  #IsFalling, -(sp)
        move.l  #Char_CurY, -(sp)
        JSR     APPLY_GRAVITY
        add.l   #SIZE_OF_APPLY_GRAV_PARAMS, sp
        
        move.l  Char_CurY, d5
        RTS
        
UPDATE_CHARACTER_GRAPHICS:

    REDRAW_BACKGROUND_FOR_CHARACTER:        
        move.l  Char_OldX, -(sp)
        move.l  Char_OldY, -(sp)
        add.l   #GRID_WIDTH, Char_OldX
        add.l   #GRID_HEIGHT, Char_OldY
        move.l  Char_OldX, -(sp)
        move.l  Char_OldY, -(sp)
        JSR     DRAW_CLIP_RECTANGLE
        add.l   #SIZE_OF_DRAW_CLIP_RECT_PARAMS, sp
        
    REDRAW_CHARACTER:
        move.l  d4, -(sp)
        move.l  d5, -(sp)
        move.l  Char_ImageData, -(sp)
        JSR     DRAW_PHYSICS_BODY
        add.l   #SIZE_OF_DRAW_BODY_PARAMS, sp
        
        RTS

MOVE_LEFT:
        mulu    d6, d2                  ; displacement = velocity * time
        asr.l   #8, d2                  ; arithmetic shift to account for multiplication of fixed point values

        JSR     CAN_MOVE_LEFT
        cmpi.b  #0, CanMove
        beq     SNAP_TO_LEFT            ; if character cant move left, snap to current grid
        sub.l   d2, d4                  ; newX = OldX - displacement
        bra     RTS_FROM_MOVE_LEFT
    SNAP_TO_LEFT:
        lsr.l   #5, d4                  ; get current column
        lsl.l   #5, d4                  ; snap to extreme left of column
    RTS_FROM_MOVE_LEFT:        
        RTS
        
MOVE_RIGHT:
        mulu    d6, d2
        asr.l   #8, d2

        JSR     CAN_MOVE_RIGHT
        cmpi.b  #0, CanMove
        bne     ADD_DISPLACEMENT
    SNAP_TO_RIGHT:
        move.l  d4, d1
        divu    #32, d1
        andi.l  #$FFFF0000, d1
        beq     RTS_FROM_MOVE_RIGHT
        lsr.l   #5, d4
        addi.b  #1, d4
        lsl.l   #5, d4
        bra     RTS_FROM_MOVE_RIGHT
    ADD_DISPLACEMENT:
        add.l   d2, d4
    RTS_FROM_MOVE_RIGHT:
        RTS
        
UPDATE_BOXES:
        lea     AllBoxes, a1
    APPLY_GRAVITY_ON_BOXES:
        cmpa.l  LastBox, a1
        bge     RTS_FROM_UPDATE_BOXES
        JSR     UPDATE_BOX_PHYSICS
        
        move.l  BOX_OLD_X(a1), d6
        cmp.l   BOX_CUR_X(a1), d6
        bne     BOX_GRAPHICS_UPDATE
        move.l  BOX_OLD_Y(a1), d6
        cmp.l   BOX_CUR_Y(a1), d6
        beq     NEXT_BOX
    BOX_GRAPHICS_UPDATE:
        JSR     UPDATE_BOX_GRAPHICS
        
    CHECK_DEATH:
        move.l  Char_CurX, d4
        move.l  Char_CurY, d5
        sub.l   BOX_CUR_X(a1), d4
        cmpi.l  #-GRID_WIDTH, d4
        ble     NEXT_BOX
        cmpi.l  #GRID_WIDTH, d4
        bge     NEXT_BOX
        sub.l   BOX_CUR_Y(a1), d5
        cmpi.l  #0, d5
        blt     NEXT_BOX
        cmpi.l  #GRID_HEIGHT, d5
        blt     CHARACTER_DIED
    NEXT_BOX:
        add.l   #BOX_OBJ_SIZE, a1
        bra     APPLY_GRAVITY_ON_BOXES
    CHARACTER_DIED:
        move.b  #0, Char_Alive
    RTS_FROM_UPDATE_BOXES:
        RTS       
        
UPDATE_BOX_PHYSICS:
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
        add.l   #16, sp
        RTS        
        
UPDATE_BOX_GRAPHICS:
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
        JSR     DRAW_CLIP_RECTANGLE      ; change subroutine to accept only top-left x and y and draw to GRID_WIDTH and GRID_HEIGHT
        add.l   #16, sp
    REDRAW_BOX:
        move.l  (a1), -(sp)
        move.l  4(a1), -(sp)
        move.l  Box_ImageData, -(sp)
        JSR     DRAW_PHYSICS_BODY
        add.l   #12, sp
        RTS

GAME_OVER:
*        move.w  #$FF00, d1
*        move.b  #CMD_CLEAR_SCREEN, d0
*        TRAP    #15

        * display game over text
        lea     GameOverText, a1
        move.w  #STAGE_WIDTH/2-200, d1
        move.w  #STAGE_HEIGHT-20, d2
        move.b  #CMD_DRAW_STRING, d0
        TRAP    #15
        
*        move.w  #0, -(sp)               ; padding to make even
*        move.w  NumBoxes, -(sp)
*        JSR     DRAW_SCORE
*        add.l   #SIZE_OF_DRAW_SCORE_PARAMS, sp
        
        JSR     REPAINT
        RTS

*********************************************************************
*                   UTILITY SUBROUTINES                             *
*********************************************************************

*-------------------
* Seeds the random number generato
*-------------------
SEED_RANDOM_NUMBER:
        movem.l d6, -(sp)
        move.l  d1, d6              ; d1 = current time
        mulu    #RANDOM_LARGE, d6
        move.l  d6, RandomNumber
        movem.l (sp)+, d6
        RTS

*-------------------
* Generates a random number modulo 20 (to get column number for newly added box)
*-------------------
GENERATE_RANDOM_MOD_20:
        movem.l REG_GENERATE_RANDOM, -(sp)
        move.l  RandomNumber, d6
        mulu    #RANDOM_LARGE, d6
        move.l  #CMD_GET_CYCLES, d0
        TRAP    #15
        mulu    d1, d6
        bcs     NO_RANDOM_CARRY
        add.l   #1, d6
    NO_RANDOM_CARRY:
        move.l  d6, RandomNumber
        divu    #MAP_ROWS, d6
        clr.w   d6
        swap    d6
        cmpi.l  #MAP_ROWS, d6
        blt     RETURN_FROM_HERE
        divu    #MAP_ROWS, d6
        clr.w   d6
        swap    d6
        move.l  d6, RandomColumn
    RETURN_FROM_HERE:
        movem.l (sp)+, REG_GENERATE_RANDOM
        RTS    
        
*-------------------
* Swaps the bytes of the lower word in d5
*-------------------
SWAP_WORD:
        movem.l d6, -(sp)
        clr.w   d6
        move.b  d5, d6
        lsr.w   #8, d5
        lsl.w   #8, d6
        or.w    d6, d5
        movem.l (sp)+, d6
        RTS
        
        
*-------------------
* Swaps the bytes of the long word in d5
*-------------------
SWAP_LONG:
        JSR     SWAP_WORD
        swap    d5
        JSR     SWAP_WORD
        RTS

*********************************************************************
*                   SCOREBOARD SUBROUTINES                          *
*********************************************************************

*------------------------
* Draws the current score (number of boxes in the game till now) as a 7 segment LED
* Parameters: (WORD) score
*------------------------
DRAW_SCORE:
        movem.l REG_DRAW_SCORE, -(sp)
        
        move.l  #SCOREBOARD_FILL_COLOR, d1  ; fill color for scorecard background
        move.b  #CMD_SET_FILL_COLOR, d0
        TRAP    #15
        
        move.w  #SCOREBOARD_LX, d1
        move.w  #SCOREBOARD_UY, d2
        move.w  #SCOREBOARD_RX, d3
        move.w  #SCOREBOARD_LY, d4
        move.b  #CMD_DRAW_RECT, d0          ; draw scorecard background
        TRAP    #15
                
        move.l  #SCOREBOARD_PEN_COLOR, d1   ; pen color for LED segments
        move.b  #CMD_SET_PEN_COLOR, d0
        TRAP    #15
        
        clr.l   d7
        clr.l   d6
        move.w  PARAM_SCORE_TO_DRAW(sp), d7

        move.w  d7, d6
        divu    #100, d6                    ; get Hundreds digit
        move.w  #0, -(sp)                   ; padding to have even boundary in stack
        move.w  d6, -(sp)
        move.w  #HUNDREDS_DIGIT_X, -(sp)
        move.w  #HUNDREDS_DIGIT_Y, -(sp)
        JSR     DRAW_DIGIT
        add.l   #SIZE_OF_DRAW_DIGIT_PARAMS, sp
        
        clr.w   d6
        swap    d6                          ; remainder from last division is now used to get remaining digits
        divu    #10, d6                     ; get Tens digit
        move.w  #0, -(sp)
        move.w  d6, -(sp)
        move.w  #TENS_DIGIT_X, -(sp)
        move.w  #TENS_DIGIT_Y, -(sp)
        JSR     DRAW_DIGIT
        add.l   #SIZE_OF_DRAW_DIGIT_PARAMS, sp
        
        clr.w   d6
        swap    d6                          ; remainder from last division is the units digit
        move.w  #0, -(sp)
        move.w  d6, -(sp)
        move.w  #UNITS_DIGIT_X, -(sp)
        move.w  #UNITS_DIGIT_Y, -(sp)
        JSR     DRAW_DIGIT
        add.l   #SIZE_OF_DRAW_DIGIT_PARAMS, sp
        
        movem.l (sp)+, REG_DRAW_SCORE
        RTS

*------------------------
* Draws the given digit as a 7 segment LED at the given (x, y) offset on the screen
* Parameters: (WORD) digit, (WORD) X, (WORD) Y
*------------------------
DRAW_DIGIT:
        movem.l REG_DRAW_DIGIT, -(sp)
        lea     DigitToSegments, a3                         ; contains info about which segments are to be drawn for each digit
        lea     PowersOf2, a4                               ; list of powers of 2 for and-ing (determining which segmenmt to draw)
        move.w  PARAM_DIGIT_TO_DRAW(sp), d5                 ; digit to draw
        move.b  (a3,d5), d6                                 ; which segments to draw
        clr.b   d7
        clr.l   d2
    CHECK_SEGMENT:        
        move.b  d6, d4                                      ; copy of which segments to draw
        move.b  (a4, d7), d3                                ; get 2^d7 for and-ing
        and.b   d3, d4                                      ; check if current segment is to be drawn
        beq     DONT_DRAW
        lea     DrawLEDSegments, a5                         ; list of funtion pointers of segment drawing functions
        move.b  d7, d2
        lsl.b   #2, d2                                      ; addresses are LONG in size
        add.l   d2, a5
        move.w  PARAM_DIGIT_X_OFFSET(sp), d0
        move.w  PARAM_DIGIT_Y_OFFSET(sp), d1
        move.w  d0, -(sp)
        move.w  d1, -(sp)
        move.l  (a5), d1
        move.l  d1, a5
        JSR     (a5)                                        ; call the function to draw segment represented by d7th bit
        add.l   #SIZE_OF_DRAW_SEGMENT_PARAMS, sp
    DONT_DRAW:
        addi.b  #1, d7
        cmpi.b  #NUM_SEGMENTS, d7                           ; check if all segment bits have been checked (7 in number)
        blt     CHECK_SEGMENT
        
        movem.l (sp)+, REG_DRAW_DIGIT
        RTS

*------------------------
* Draws segment A of a 7 segment LED set, relative to the given (x, y) offset on the screen
* (x, y) -> (x+L, y)
* Parameters: (WORD) X, (WORD) Y
*------------------------
DRAW_SEGMENT_A:
        movem.l REG_DRAW_SEGMENT, -(sp)
        move.w  PARAM_SEGMENT_X_OFFSET(sp), d1
        move.w  PARAM_SEGMENT_Y_OFFSET(sp), d2
        move.w  d1, d3
        addi.w  #SEGMENT_LENGTH, d3
        move.w  d2, d4
        move.b  #CMD_DRAW_LINE, d0
        TRAP    #15
        movem.l (sp)+, REG_DRAW_SEGMENT
        RTS

*------------------------
* Draws segment A of a 7 segment LED set, relative to the given (x, y) offset on the screen
* (x+L, y) -> (x+L, y+L)
* Parameters: (WORD) X, (WORD) Y
*------------------------
DRAW_SEGMENT_B:
        movem.l REG_DRAW_SEGMENT, -(sp)
        move.w  PARAM_SEGMENT_X_OFFSET(sp), d1
        move.w  PARAM_SEGMENT_Y_OFFSET(sp), d2
        addi.w  #SEGMENT_LENGTH, d1
        move.w  d1, d3
        move.w  d2, d4
        addi.w  #SEGMENT_LENGTH, d4
        move.b  #CMD_DRAW_LINE, d0
        TRAP    #15
        movem.l (sp)+, REG_DRAW_SEGMENT
        RTS
        
*------------------------
* Draws segment A of a 7 segment LED set, relative to the given (x, y) offset on the screen
* (x+L, y+L) -> (x+L, y+2L)
* Parameters: (WORD) X, (WORD) Y
*------------------------
DRAW_SEGMENT_C:
        movem.l REG_DRAW_SEGMENT, -(sp)
        move.w  PARAM_SEGMENT_X_OFFSET(sp), d1
        move.w  PARAM_SEGMENT_Y_OFFSET(sp), d2
        addi.w  #SEGMENT_LENGTH, d1
        addi.w  #SEGMENT_LENGTH, d2
        move.w  d1, d3        
        move.w  d2, d4
        addi.w  #SEGMENT_LENGTH, d4
        move.b  #CMD_DRAW_LINE, d0
        TRAP    #15
        movem.l (sp)+, REG_DRAW_SEGMENT
        RTS

*------------------------
* Draws segment A of a 7 segment LED set, relative to the given (x, y) offset on the screen
* (x, y+2L) -> (x+L, y+2L)
* Parameters: (WORD) X, (WORD) Y
*------------------------
DRAW_SEGMENT_D:
        movem.l REG_DRAW_SEGMENT, -(sp)
        move.w  PARAM_SEGMENT_X_OFFSET(sp), d1
        move.w  PARAM_SEGMENT_Y_OFFSET(sp), d2
        addi.w  #(2*SEGMENT_LENGTH), d2
        move.w  d1, d3
        addi.w  #SEGMENT_LENGTH, d3
        move.w  d2, d4
        move.b  #CMD_DRAW_LINE, d0
        TRAP    #15
        movem.l (sp)+, REG_DRAW_SEGMENT
        RTS
        
*------------------------
* Draws segment A of a 7 segment LED set, relative to the given (x, y) offset on the screen
* (x, y+L) -> (x, y+2L)
* Parameters: (WORD) X, (WORD) Y
*------------------------
DRAW_SEGMENT_E:
        movem.l REG_DRAW_SEGMENT, -(sp)
        move.w  PARAM_SEGMENT_X_OFFSET(sp), d1
        move.w  PARAM_SEGMENT_Y_OFFSET(sp), d2
        move.w  d1, d3
        addi.w  #SEGMENT_LENGTH, d2
        move.w  d2, d4
        addi.w  #SEGMENT_LENGTH, d4
        move.b  #CMD_DRAW_LINE, d0
        TRAP    #15
        movem.l (sp)+, REG_DRAW_SEGMENT
        RTS
        
*------------------------
* Draws segment A of a 7 segment LED set, relative to the given (x, y) offset on the screen
* (x, y) -> (x, y+L)        
* Parameters: (WORD) X, (WORD) Y
*------------------------
DRAW_SEGMENT_F:
        movem.l REG_DRAW_SEGMENT, -(sp)
        move.w  PARAM_SEGMENT_X_OFFSET(sp), d1
        move.w  PARAM_SEGMENT_Y_OFFSET(sp), d2
        move.w  d1, d3
        move.w  d2, d4
        addi.w  #SEGMENT_LENGTH, d4
        move.b  #CMD_DRAW_LINE, d0
        TRAP    #15
        movem.l (sp)+, REG_DRAW_SEGMENT
        RTS
        
*------------------------
* Draws segment A of a 7 segment LED set, relative to the given (x, y) offset on the screen
* (x, y+L) -> (x+L, y+L)
* Parameters: (WORD) X, (WORD) Y
*------------------------
DRAW_SEGMENT_G:
        movem.l REG_DRAW_SEGMENT, -(sp)
        move.w  PARAM_SEGMENT_X_OFFSET(sp), d1
        move.w  PARAM_SEGMENT_Y_OFFSET(sp), d2
        addi.w  #SEGMENT_LENGTH, d2
        move.w  d1, d3
        addi.w  #SEGMENT_LENGTH, d3
        move.w  d2, d4
        move.b  #CMD_DRAW_LINE, d0
        TRAP    #15
        movem.l (sp)+, REG_DRAW_SEGMENT
        RTS
        
*SCOREBOARD  INCLUDE "scoreboard.x68"
*----------------------------------------------------------*
*----------------------------------------------------------*


*-------------------
* STAGE related constants
*-------------------
SCREEN_WIDTH        EQU     640
SCREEN_HEIGHT       EQU     540
STAGE_WIDTH         EQU     640
STAGE_HEIGHT        EQU     480
GRID_WIDTH          EQU     32
GRID_HEIGHT         EQU     32
GameTitle           dc.b    'Avoid and Evade',0
StartGameText       dc.b    'Press Space To Start, use Arrow Keys to control player',0
LoadingText         dc.b    'Loading...', 0
GameOverText        dc.b    'Game Over, Your Score is in the bottom right corner',0
GameDescription     dc.b    'Avoid the falling blocks, use Arrow Keys to navigate',0

*-------------------
* Trap codes
*-------------------
CMD_SET_PEN_COLOR       EQU     80
CMD_SET_FILL_COLOR      EQU     81
CMD_DRAW_PIXEL          EQU     82
CMD_DRAW_LINE           EQU     84
CMD_DRAW_RECT           EQU     87
CMD_OUTPUT_RES          EQU     33
CMD_CLEAR_SCREEN        EQU     11
CMD_DRAW_STRING         EQU     95
CMD_DBL_BUFFER          EQU     92
CMD_REPAINT             EQU     94
CMD_KEY_DOWN_EVENT      EQU     19
CMD_GET_TIME            EQU     8
CMD_GET_CYCLES          EQU     31

DBL_BUFFER_ON           EQU     17

*-------------------
* Key codes
*-------------------
KEY_LEFT_ARROW          EQU     $25
KEY_UP_ARROW            EQU     $26
KEY_RIGHT_ARROW         EQU     $27
KEY_SPACEBAR            EQU     $20
KEY_COMBO               EQU     $00262527

*-------------------
* Background Bitmap file descriptors
*-------------------
LifeSaver01         ds.l    0
BitmapData          INCBIN  "factory.bmp"

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
CharBitmapData      INCBIN  "alien.bmp"

CharImageDataOffset EQU     (CharBitmapData+10)      ; LONG
CharImageWidth      EQU     (CharImageDataOffset+8)  ; LONG
CharImageHeight     EQU     (CharImageWidth+4)       ; LONG
Char_StartX         EQU     96
Char_StartY         EQU     100
Char_XMAX           EQU     (STAGE_WIDTH-32)
Char_XVelocity      EQU     1000
Char_JumpVelocity   EQU     2000
Char_MaxYVelocity   EQU     1000

Char_ImageData      ds.l    1
Char_Height         ds.l    1
Char_Width          ds.l    1   ; corresponds to number of bytes per row
Char_ActualWidth    dc.l    32
Char_CurX           dc.l    Char_StartX
Char_CurY           dc.l    Char_StartY
Char_OldX           dc.l    Char_StartX
Char_OldY           dc.l    Char_StartY
Char_Alive          dc.b    1

*-------------------
* Box Bitmap file descriptors
*-------------------
LifeSaver03         ds.l    0
BoxBitmapData       INCBIN  "crate2.bmp"

BoxImageDataOffset  EQU     (BoxBitmapData+10)      ; LONG
BoxImageWidth       EQU     (BoxImageDataOffset+8)  ; LONG
BoxImageHeight      EQU     (BoxImageWidth+4)       ; LONG

Box_ImageData       ds.l    1
Box_Height          ds.l    1
Box_Width           ds.l    1   ; corresponds to number of bytes per row
Box_ActualWidth     dc.l    32
        
MAX_BOXES           EQU     240
MIN_STACKED_BOX_Y   EQU     128

BOX_OBJ_SIZE        EQU     22   ; (LONG)curX, (LONG)curY, (LONG)oldX, (LONG)oldY, (LONG)yVelocity, (BYTE)isFalling, (BYTE)isPickedUp
BOX_CUR_X           EQU     0
BOX_CUR_Y           EQU     4
BOX_OLD_X           EQU     8
BOX_OLD_Y           EQU     12
BOX_Y_VELOCITY      EQU     16
BOX_IS_FALLING      EQU     20
BOX_IS_PICKED       EQU     21

LifeSaver04         ds.l    0
AllBoxes            ds.b    BOX_OBJ_SIZE*MAX_BOXES
NumBoxes            dc.w    0
LastBox             dc.l    AllBoxes
BoxGenerationTimer  dc.l    0

*-------------------
* Gameplay
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
* 7 segment LED
*-------------------
SCOREBOARD_FILL_COLOR   EQU     $00000000
SCOREBOARD_PEN_COLOR    EQU     $00FFFFFF

SCOREBOARD_LX           EQU     10
SCOREBOARD_UY           EQU     490
SCOREBOARD_RX           EQU     70
SCOREBOARD_LY           EQU     530
 
SEGMENT_LENGTH          EQU     10
NUM_SEGMENTS            EQU     7
        
HUNDREDS_DIGIT_X        EQU     20
HUNDREDS_DIGIT_Y        EQU     500

TENS_DIGIT_X            EQU     35
TENS_DIGIT_Y            EQU     500

UNITS_DIGIT_X           EQU     50
UNITS_DIGIT_Y           EQU     500

DigitToSegments         dc.b    %01111110   ; 0
                        dc.b    %00110000   ; 1
                        dc.b    %01101101   ; 2
                        dc.b    %01111001   ; 3
                        dc.b    %00110011   ; 4
                        dc.b    %01011011   ; 5
                        dc.b    %01011111   ; 6
                        dc.b    %01110000   ; 7
                        dc.b    %01111111   ; 8
                        dc.b    %01111011   ; 9
PowersOf2               dc.b    1, 2, 4, 8, 16, 32, 64
DrawLEDSegments         dc.l    DRAW_SEGMENT_G
                        dc.l    DRAW_SEGMENT_F
                        dc.l    DRAW_SEGMENT_E
                        dc.l    DRAW_SEGMENT_D
                        dc.l    DRAW_SEGMENT_C
                        dc.l    DRAW_SEGMENT_B
                        dc.l    DRAW_SEGMENT_A
                        
*-------------------
* Parameter Offsets
*-------------------
PARAM_SCORE_TO_DRAW     EQU     32

PARAM_DIGIT_TO_DRAW     EQU     52
PARAM_DIGIT_X_OFFSET    EQU     50
PARAM_DIGIT_Y_OFFSET    EQU     48

PARAM_SEGMENT_X_OFFSET  EQU     26
PARAM_SEGMENT_Y_OFFSET  EQU     24

PARAM_COLUMN_NUMBER     EQU     12
PARAM_MIN_Y             EQU     8

PARAM_GET_MAP_STATUS_X  EQU     8
PARAM_GET_MAP_STATUS_Y  EQU     4

PARAM_PTR_BOX_OBJ       EQU     20

PARAM_BMP_LEFT_X        EQU     48
PARAM_BMP_TOP_Y         EQU     44
PARAM_BMP_TO_DRAW       EQU     40

PARAM_BMP_LX            EQU     52
PARAM_BMP_UY            EQU     48
PARAM_BMP_RX            EQU     44
PARAM_BMP_LY            EQU     40

PARAM_FALLING_X         EQU     24
PARAM_FALLING_Y         EQU     20
PARAM_FALLING_PTR       EQU     16

PARAM_GRAV_X            EQU     40
PARAM_GRAV_PTR_YVEL     EQU     36
PARAM_GRAV_PTR_FALLING  EQU     32
PARAM_GRAV_PTR_Y        EQU     28

*-------------------
* Size of Paramerters of a Subroutine
*-------------------
SIZE_OF_DRAW_SCORE_PARAMS       EQU     4
SIZE_OF_DRAW_DIGIT_PARAMS       EQU     8
SIZE_OF_DRAW_SEGMENT_PARAMS     EQU     4

SIZE_OF_GET_TOP_BOX_PARAMS      EQU     8
SIZE_OF_GET_MAP_STATUS_PARAMS   EQU     8
SIZE_OF_UPDATE_MAP_PARAMS       EQU     4

SIZE_OF_IS_FALLING_PARAMS       EQU     12
SIZE_OF_APPLY_GRAV_PARAMS       EQU     16

SIZE_OF_DRAW_BODY_PARAMS        EQU     12
SIZE_OF_DRAW_CLIP_RECT_PARAMS   EQU     16

        END     START
        

        























*~Font name~Courier New~
*~Font size~14~
*~Tab type~1~
*~Tab size~4~

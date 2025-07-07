
; pvong for the casio pv-1000
; joe kennedy 2025

ball_deflect_left:
	.dw 0x0170, -0x0170
	.dw 0x0200, -0x0100
	.dw 0x0270, -0x0070
	.dw 0x0300, 0x0000
	.dw 0x0300, 0x0000
	.dw 0x0270, 0x0070
	.dw 0x0200, 0x0100
	.dw 0x0170, 0x0170

ball_deflect_right:
	.dw -0x0170, -0x0170
	.dw -0x0200, -0x0100
	.dw -0x0270, -0x0070
	.dw -0x0300, 0x0000
	.dw -0x0300, 0x0000
	.dw -0x0270, 0x0070
	.dw -0x0200, 0x0100
	.dw -0x0170, 0x0170

update_ball:

	; add ball_dx to ball_x
	ld hl, (ball_x)
	ld de, (ball_dx)
	add hl, de

	; check if the x boundaries have been hit
	ld a, h
	cp a, 24
	jr c, up_ball_x_oob_left
	cp a, 192
	jr nc, up_ball_x_oob_right
	jr up_ball_x_done

	; out of bounds on left hand (p1) side
	up_ball_x_oob_left:

		; has it hit the left hand paddle?
		ld a, (ball_y + 1)
		ld c, a
		ld a, (p1_y)
		ld b, a

		; ball_y < paddle_y + paddle_h ?
		add a, PADDLE_H
		sub a, c
		jr c, up_ball_p2_score

		; ball_y + 8 > paddle_y ?
		ld a, c
		add a, 8
		sub a, b
		jr c, up_ball_p2_score

		; paddle was hit
		jr up_ball_x_bounce_left

		; player scored
		up_ball_p2_score:

			ld a, 2
			ld (scored), a
			call ball_reset

			ret

	; out of bounds on right hand (p2) side
	up_ball_x_oob_right:

		; has it hit the right hand paddle?
		ld a, (ball_y + 1)
		ld c, a
		ld a, (p2_y)
		ld b, a

		; ball_y < paddle_y + paddle_h ?
		add a, PADDLE_H
		sub a, c
		jr c, up_ball_p1_score

		; ball_y + 8 > paddle_y ?
		ld a, c
		add a, 8
		sub a, b
		jr c, up_ball_p1_score

		; paddle was hit
		jr up_ball_x_bounce_right

		; player scored
		up_ball_p1_score:

			ld a, 1
			ld (scored), a
			call ball_reset

			ret

	; ball has hit a paddle
	up_ball_x_bounce_left:

		push hl
		ld hl, ball_deflect_left
		ld a, (p1_y)

		jr up_ball_x_bounce_continue

	up_ball_x_bounce_right:

		push hl
		ld hl, ball_deflect_right
		ld a, (p2_y)

	up_ball_x_bounce_continue:

		; c = paddle y
		ld c, a

		; a = ball_y - paddle_y
		ld a, (ball_y + 1)
		sub a, c

		; ensure the result is positive
		jr nc, +

			xor a, a
		+:

		; ensure the result is < paddle height
		cp a, PADDLE_H
		jr c, +

			ld a, PADDLE_H - 1

		+:

		; diff/2 * 4
		and a, 0x1e
		sla a

		; index into ball deflect table
		add a, l
		ld l, a
		adc a, h
		sub a, l
		ld h, a

		; copy dx and dy from table
		ld de, ball_dx
		ldi
		ldi

		ld de, ball_dy
		ldi
		ldi

		; restore ball_x into hl
		pop hl

		; move ball_x back by ball_dx
		ld de, (ball_dx)
		add hl, de

		; mark as collided
		ld a, 1
		ld (ball_collided), a

	up_ball_x_done:

	; store new ball position
	ld (ball_x), hl

	; add ball_dy to ball_y
	ld hl, (ball_y)
	ld de, (ball_dy)
	add hl, de

	; check if the y boundaries have been hit
	ld a, h
	cp a, 8
	jr c, up_ball_y_oob_top
	cp a, 152
	jr nc, up_ball_y_oob_bottom
	jr up_ball_y_done

	up_ball_y_oob_top:
	up_ball_y_oob_bottom:

		ld a, 1
		ld (ball_collided), a

		; invert ball_dy
		ex de, hl
		ld b, h
		ld c, l
		sbc hl, bc
		sbc hl, bc
		ex de, hl

		ld (ball_dy), de

		; move ball_y back by ball_dy
		add hl, de
		add hl, de

	up_ball_y_done:
	
	; store new ball position
	ld (ball_y), hl

	ret

ball_reset:

	ld a, BALL_HOLD_TIME
	ld (ball_hold_timer), a

	ld hl, 0x7000
	ld (ball_x), hl
	ld hl, 0x6000
	ld (ball_y), hl

	; randomly send ball up-left or down-right
	ld a, (tic)
	and a, 0x1
	jr nz, +

		ld hl, 0x0170
		ld (ball_dx), hl
		ld (ball_dy), hl

		ret

	+:

		ld hl, -0x0170
		ld (ball_dx), hl
		ld (ball_dy), hl

		ret

clear_ball:

	ld a, (old_ball_y)
	call get_tilemap_row_offset

	; a = (ball_x/4) & 31
	ld a, (old_ball_x)
	rrca
	rrca
	rrca
	and a, 0x1f

	; combine with row
	or a, e
	ld e, a

	; get offset into tilemap
	ld hl, TILEMAP
	add hl, de

	; clear top row of ball
	ld a, TILES_EMPTY
	ld (hl), a
	inc hl
	ld (hl), a

	; clear bottom row of ball
	ld de, 32
	add hl, de

	ld (hl), a
	dec hl
	ld (hl), a

	ret

draw_ball:

	ld a, (ball_y + 1)
	call get_tilemap_row_offset

	; a = (ball_x/4) & 31
	ld a, (ball_x + 1)
	rrca
	rrca
	rrca
	and a, 0x1f

	; combine with row
	or a, e
	ld e, a

	; get offset into tilemap
	ld hl, TILEMAP
	add hl, de

	; check for ball position where y_coord % 8 == 0
	ld a, (ball_y + 1)
	or a, a
	jr z, db_single_line

		; this ball position requires 2x2 tiles 
		ld a, TILES_BALL
		ld (hl), a
		
		inc hl
		inc a
		ld (hl), a

		; move to next row down
		inc a
		ld de, 31
		add hl, de
		ld (hl), a

		inc a
		inc hl
		ld (hl), a

		ret

	db_single_line:

		; this ball position requires 2x1 tiles
		ld a, TILES_BALL
		ld (hl), a
		
		inc hl
		inc a
		ld (hl), a

		ret

init_ball_tile_patterns:

	ld hl, TILES_RAM_ADDRESS(TILES_BALL)
	ld b, 32 * 4

	xor a, a

	-:
		ld (hl), a
		inc hl
		djnz -

	ret

; clear green channel of the ball tiles
clear_ball_tile_patterns:

	ld hl, 0

	ld (TILES_RAM_ADDRESS(TILES_BALL) + 0  + 16 + 0), hl
	ld (TILES_RAM_ADDRESS(TILES_BALL) + 0  + 16 + 2), hl
	ld (TILES_RAM_ADDRESS(TILES_BALL) + 0  + 16 + 4), hl
	ld (TILES_RAM_ADDRESS(TILES_BALL) + 0  + 16 + 6), hl

	ld (TILES_RAM_ADDRESS(TILES_BALL) + 32 + 16 + 0), hl
	ld (TILES_RAM_ADDRESS(TILES_BALL) + 32 + 16 + 2), hl
	ld (TILES_RAM_ADDRESS(TILES_BALL) + 32 + 16 + 4), hl
	ld (TILES_RAM_ADDRESS(TILES_BALL) + 32 + 16 + 6), hl

	ld (TILES_RAM_ADDRESS(TILES_BALL) + 64 + 16 + 0), hl
	ld (TILES_RAM_ADDRESS(TILES_BALL) + 64 + 16 + 2), hl
	ld (TILES_RAM_ADDRESS(TILES_BALL) + 64 + 16 + 4), hl
	ld (TILES_RAM_ADDRESS(TILES_BALL) + 64 + 16 + 6), hl

	ld (TILES_RAM_ADDRESS(TILES_BALL) + 96 + 16 + 0), hl
	ld (TILES_RAM_ADDRESS(TILES_BALL) + 96 + 16 + 2), hl
	ld (TILES_RAM_ADDRESS(TILES_BALL) + 96 + 16 + 4), hl
	ld (TILES_RAM_ADDRESS(TILES_BALL) + 96 + 16 + 6), hl

	ret

update_ball_tile_patterns:

	ld hl, TILES_RAM_ADDRESS(TILES_BALL) + 16

	; check how many top rows are empty
	ld a, (ball_y + 1)
	and a, 0x7
	jr z, ubt_no_empty_top_rows

		; skip empty rows at top
		ld b, a

		add a, l
		ld l, a
		adc a, h
		sub a, l
		ld h, a

	ubt_no_empty_top_rows:

	ld a, (tic)
	and a, 0x1

	ld a, (ball_anim)
	jr nz, ubt_no_ball_anim_update

		; update ball animation frame
		add a, 8
		cp a, 160
		jr nz, +
			xor a, a
		+:

		ld (ball_anim), a

	ubt_no_ball_anim_update:

	; multiply by 8 and add to tile data address
	add a, <ball_anim_1bit
	ld e, a
	adc a, >ball_anim_1bit
	sub a, e
	ld d, a

	; work out number of tile rows in the upper tiles
	ld a, (ball_y + 1)
	and a, 0x7
	neg
	add a, 8
	ld b, a

	; different cases for whether x is 0 or not
	ld a, (ball_x + 1)
	and a, 0x7
	jr nz, ubt_tiles_upper_x_is_not_zero

		ubt_tiles_upper_x_is_zero:

			; special case for ball_x % 8 == 0
			ld a, (de)
			ld (hl), a

			; move to right hand tile
			set 5, l

			; right hand tile
			xor a, a
			ld (hl), a
			
			; move back to left hand tile
			res 5, l

			; move onto next rows
			inc hl
			inc de

			djnz ubt_tiles_upper_x_is_zero
			jr ubt_tiles_upper_loop_done

		ubt_tiles_upper_x_is_not_zero:

			push af
			push bc

			ld b, a

			ld a, (de)
			ld c, 0

			-:
				srl a
				rr c
				djnz -

			ld (hl), a

			; move to right hand tile
			set 5, l

			ld (hl), c
			
			; move back to left hand tile but on the next row
			res 5, l

			inc hl
			inc de

			pop bc
			pop af

			djnz ubt_tiles_upper_x_is_not_zero

		ubt_tiles_upper_loop_done:

	; move to lower tiles
	ld a, l
	and a, 0xf0
	or a, 64
	ld l, a

	; work out number of tile rows in the lower tiles
	ld a, (ball_y + 1)
	and a, 0x7
	jr z, ubt_no_lower_tile_rows

		ld b, a

		; different cases for whether x is 0 or not
		ld a, (ball_x + 1)
		and a, 0x7
		jr nz, ubt_tiles_lower_x_is_not_zero

			ubt_tiles_lower_x_is_zero:

				; special case for ball_x % 8 == 0
				ld a, (de)
				ld (hl), a

				; move to right hand tile
				set 5, l

				; right hand tile
				xor a, a
				ld (hl), a
				
				; move back to left hand tile
				res 5, l

				; move onto next rows
				inc hl
				inc de

				djnz ubt_tiles_lower_x_is_zero
				jr ubt_tiles_lower_loop_done

			ubt_tiles_lower_x_is_not_zero:

				push af
				push bc

				ld b, a

				ld a, (de)
				ld c, 0

				-:
					srl a
					rr c
					djnz -

				ld (hl), a

				; move to right hand tile
				set 5, l

				ld (hl), c
				
				; move back to left hand tile but on the next row
				res 5, l

				inc hl
				inc de

				pop bc
				pop af

				djnz ubt_tiles_lower_x_is_not_zero

			ubt_tiles_lower_loop_done:

	ubt_no_lower_tile_rows:

	ret
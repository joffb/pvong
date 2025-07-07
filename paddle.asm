
; pvong for the casio pv-1000
; joe kennedy 2025

; c: up/down byte with down in bit 0 and up in bit 1
; a: current y value
move_paddle:

	; move down?
	bit 0, c
	jr z, mp_check_up

		; return if already at bottom 
		cp a, 144
		ret z

			; move paddle
			add a, 2
			ret

	; move up
	mp_check_up:
	bit 1, c
	ret z

		; return if already at top
		cp a, 8
		ret z

			; move paddle
			sub a, 2
			ret


; a: paddle y
; hl: pointer to paddle column in tilemap
clear_paddle:

	; preserve paddle y in c
	ld c, a

	; get tilemap offset for this row
	call get_tilemap_row_offset

	; add to hl
	add hl, de

	; clear top tile
	ld (hl), TILES_EMPTY

	; clear bottom tiles
	ld de, 32
	add hl, de

	ld (hl), TILES_EMPTY

	; don't need to clear this further below tile
	; if (paddle_y % 8 == 0) 
	ld a, c
	and a, 0x7
	jr z, clear_paddle_no_last

		ld de, 32
		add hl, de

		ld (hl), TILES_EMPTY

	clear_paddle_no_last:

	ret

; a: paddle y
; hl: pointer to paddle column in tilemap
draw_paddle:

	; preserve paddle y in c
	ld c, a

	; get tilemap offset for this row
	call get_tilemap_row_offset

	; add to hl
	add hl, de

	; get first tile and write it to the tilemap
	ld a, c
	and a, 0x7
	add a, TILES_PADDLE_TOP
	ld (hl), a

	; write body tiles
	ld de, 32
	add hl, de
	ld (hl), TILES_PADDLE_MIDDLE

	; don't need to draw this further below tile
	; if (paddle_y % 8 == 0) 
	ld a, c
	and a, 0x7
	jr z, draw_paddle_not_last

		; write last tile
		add hl, de
		add a, TILES_PADDLE_BOTTOM
		ld (hl), a

	draw_paddle_not_last:

	ret
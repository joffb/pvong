
; pvong for the casio pv-1000
; joe kennedy 2025

.include "../pvbanjo/music_driver/banjo_defines_wladx.inc"

.define IO_SQUARE_1				0xf8
.define IO_SQUARE_2				0xf9
.define IO_SQUARE_3				0xfa
.define IO_SND_CTRL				0xfb
.define IO_IRQ_ENABLE 			0xfc
.define IO_IRQ_STATUS			0xfc
.define IO_IRQ_ACK	 			0xfd
.define IO_JOYSTICK 			0xfd
.define IO_TILE_PATTERN_ADDRS	0xfe
.define IO_DISPLAY				0xff

.define IRQ_ENABLE_PRERENDER	0x01
.define IRQ_ENABLE_MATRIX		0x02

.define TILEMAP 0xb802
.define TILEMAP_W				28
.define TILEMAP_H				24
.define TILEMAP_ROW_SIZE		32

.function TILEMAP_ADDR_XY(TILE_X, TILE_Y) (TILEMAP + TILE_X + (TILE_Y * TILEMAP_ROW_SIZE))
.function TILES_RAM_ADDRESS(TILE_N)		0xbc00 + ((TILE_N - 0xe0) * 32)

.define TILES_START 0xB0

.define TILES_PADDLE_TOP 		TILES_START + 0
.define TILES_PADDLE_MIDDLE 	TILES_START + 0
.define TILES_PADDLE_BOTTOM 	TILES_START + 8
.define TILES_EMPTY 			TILES_START + 8
.define TILES_NUMBERS 			TILES_START + 16

.define TILES_BALL				0xf0

.define PADDLE_H 16
.define BALL_HOLD_TIME 30

.MEMORYMAP

	DEFAULTSLOT 0

	SLOTSIZE $8000
	
	SLOT 0 $0000			; ROM slot 0.

	SLOTSIZE $800
	SLOT 1 $8000			; RAM
	SLOT 2 $8800			; RAM
	SLOT 3 $9000			; RAM
	SLOT 4 $9800			; RAM
	SLOT 5 $a000			; RAM
	SLOT 6 $a800			; RAM
	SLOT 7 $b000			; RAM
	SLOT 8 $b800			; RAM

	SLOTSIZE $4000

	SLOT 9 $C000			; Open

.ENDME

.ROMBANKMAP
	BANKSTOTAL 1
	BANKSIZE $2000
	BANKS 1
.ENDRO

.org 0x0000
jp init

.RAMSECTION "Main Vars" bank 0 slot 8

	; ram starts at 0xb800

	; interleaving game variables with the visible tilemap tiles
	; 2 bytes before and two bytes after each 28 byte row are not rendered
	; e.g.
	; 0xb800 free 2 bytes
	; 0xb802 tilemap 28 bytes
	; 0xb81e free 2 bytes

	joy_updown: db
	game_state: db

		tilemap_row_0: ds 28

	p1_score: db
	p2_score: db
	p1_y: db
	p2_y: db

		tilemap_row_1: ds 28

	scored: db
	ball_hold_timer: db
	tic: db
	last_winner: db

		tilemap_row_2: ds 28

	ball_x: dw
	ball_y: dw

		tilemap_row_3: ds 28

	ball_dx: dw
	ball_dy: dw

	tilemap_remaining: ds 20 * TILEMAP_ROW_SIZE

	irq_status: db
	ball_collided: db
	ball_anim: db

	old_p1_y: db
	old_p2_y: db

	old_ball_x: db
	old_ball_y: db

	; state and channel data for song
	song_playing: db
	song_state: INSTANCEOF music_state
	song_channels: INSTANCEOF channel (3)
	
	sfx_playing: db
	sfx_state: INSTANCEOF music_state
	sfx_channel: INSTANCEOF channel

.ENDS

.org 0x0038

	push af
	exx
	
	; check irq type 
	in a, (IO_IRQ_STATUS)
	bit 0, a
	jr z, +

		; prerender interrupt
		ld (hl), 1

		; enable matrix interrupts
		out (c), d

		; acknowledge prerender and matrix interrupts
		in a, (IO_IRQ_ACK)
		out (IO_IRQ_ACK), a		

		exx
		pop af

		ei
		ret

	+:
		
		; matrix interrupt
		set 1, (hl)

		; disable further matrix interrupts
		out (c), e

		; acknowledge matrix interrupts
		in a, (IO_IRQ_ACK)
			
		exx
		pop af

		ei
		ret


.org 0x0066
	retn
	

init:
	di
	im 1

	ld sp, 0xbfff

	ld a, IRQ_ENABLE_PRERENDER
	out (IO_IRQ_ENABLE), a

	ld a, 0x00
	out (IO_DISPLAY), a

	ld a, 0xb8
	out (IO_TILE_PATTERN_ADDRS), a

	; set up alternate registers
	exx
	ld c, IO_IRQ_ENABLE
	ld d, IRQ_ENABLE_PRERENDER | IRQ_ENABLE_MATRIX
	ld e, IRQ_ENABLE_PRERENDER
	ld hl, irq_status
	exx

	; clear irq_status
	xor a, a
	ld (irq_status), a

	call banjo_init

	ld hl, p1_theme
	call banjo_play_song

	call init_ball_tile_patterns

	call reset_game_state
	call draw_playfield
	call draw_scores

	ei

	wait_vblank:
	
		; wait for interrupt
		halt

		; wait for both prerender and matrix interrupts to be flagged
		ld a, (irq_status)
		cp a, 0x3
		jr nz, wait_vblank

		; clear irq flags
		xor a, a
		ld (irq_status), a

		; update tic
		ld a, (tic)
		inc a
		ld (tic), a

		; check which state the game is in
		ld a, (game_state)
		or a, a
		jr z, game_state_playing

		game_state_won:

			; check for start presses
			ld a, 0x1
			out (IO_JOYSTICK), a

			push hl
			pop hl
			push hl
			pop hl

			; get start presses
			in a, (IO_JOYSTICK)

			; p1 or p2 start pressed?
			and a, 0x6
			jr z, gsw_no_start_press

				; different songs depending on who won the last game
				ld a, (last_winner)
				dec a
				jr nz, gsw_p2_song

					ld hl, p1_theme
					call banjo_play_song

					jr gsw_song_done

				gsw_p2_song:

					ld hl, p2_theme
					call banjo_play_song

				gsw_song_done:

				; restart game
				call draw_playfield
				call reset_game_state
				call draw_scores

			gsw_no_start_press:

			; keep the music going
			call banjo_update_song

			jr wait_vblank

		game_state_playing:

			; frontload all the drawing to try to fit it into vblank

			; clear ball tiles
			call clear_ball

			; clear paddle tiles
			ld a, (old_p1_y)
			ld hl, TILEMAP_ADDR_XY(2, 0)
			call clear_paddle

			ld a, (old_p2_y)
			ld hl, TILEMAP_ADDR_XY(25, 0)
			call clear_paddle

			; redraw the ball
			call clear_ball_tile_patterns
			call update_ball_tile_patterns
			call draw_ball

			; redraw paddles
			ld a, (p1_y)
			ld hl, TILEMAP_ADDR_XY(2, 0)
			call draw_paddle

			ld a, (p2_y)
			ld hl, TILEMAP_ADDR_XY(25, 0)
			call draw_paddle

			; check for up/down presses
			ld a, 0x6
			out (IO_JOYSTICK), a

			push hl
			pop hl
			push hl
			pop hl

			; keep old paddle positions for clearing them next frame
			ld a, (p1_y)
			ld (old_p1_y), a
			ld a, (p2_y)
			ld (old_p2_y), a

			; get up/down presses and keep in variable and in c
			in a, (IO_JOYSTICK)
			ld (joy_updown), a
			ld c, a

			; get p1_y and apply movement
			ld a, (p1_y)
			call move_paddle
			ld (p1_y), a

			; shift p2 bits into position
			rr c
			rr c

			; get p2_y and apply movement
			ld a, (p2_y)
			call move_paddle
			ld (p2_y), a

			; timer which holds the ball in position after scoring
			ld a, (ball_hold_timer)
			or a, a
			jr z, ball_no_hold

				; hold ball
				dec a
				ld (ball_hold_timer), a
				jr ball_hold_done

			ball_no_hold:
				
				; keep old ball position for clearing it next frame
				ld a, (ball_x + 1)
				ld (old_ball_x), a
				ld a, (ball_y + 1)
				ld (old_ball_y), a

				; update ball position
				call update_ball

			ball_hold_done:

			; player scored?
			ld a, (scored)
			or a, a
			call nz, player_scored

			; check if the ball hit something
			ld a, (ball_collided)
			or a, a
			jr z, +

				xor a, a
				ld (ball_collided), a

				call banjo_sfx_stop

				ld hl, paddle_hit_sfx
				call banjo_play_sfx
			+:

			; keep the music going
			call banjo_update_song
			call banjo_update_sfx

			jp wait_vblank


reset_game_state:

	; init state to playing
	xor a, a
	ld (game_state), a
	ld (ball_anim), a
	ld (ball_collided), a

	; init ball timer
	ld a, BALL_HOLD_TIME
	ld (ball_hold_timer), a

	; initialise paddles
	ld a, 64
	ld (p1_y), a
	ld (p2_y), a
	ld (old_p1_y), a
	ld (old_p2_y), a

	; initialise ball
	ld hl, 0x6000
	ld (ball_x), hl
	ld (ball_y), hl

	ld a, h
	ld (old_ball_x), a
	ld a, h
	ld (old_ball_y), a

	ld hl, -0x0170
	ld (ball_dx), hl
	ld (ball_dy), hl

	; init scores
	xor a, a
	ld (scored), a
	ld (p1_score), a
	ld (p2_score), a

	ret


; a: row
; returns row offset in de
get_tilemap_row_offset:

	; a * 4 (simplifying (a/8) * 32)
	; 0h111111 >> 3 = 0000h111
	; 0000h111 << 5 = 1110000h
	rlca
	rlca
	ld d, a
	
	; lower byte
	and a, 0xe0
	ld e, a

	; upper byte
	ld a, d
	and a, 0x3
	ld d, a

	ret


player_scored:

	; play scored sfx
	call banjo_sfx_stop
	ld hl, scored_sfx
	call banjo_play_sfx

	; check which player scored
	ld a, (scored)
	dec a
	jr nz, ps_p2_scored

		; player 1 scored
		ld a, (p1_score)
		inc a
		ld (p1_score), a

		; has this player won?
		cp a, 7
		call z, game_won

		jr ps_done

	ps_p2_scored:

		; player 2 scored
		ld a, (p2_score)
		inc a
		ld (p2_score), a

		; has this player won?
		cp a, 7
		call z, game_won

	ps_done:
	
	xor a, a
	ld (scored), a

	call draw_scores

	ret

draw_scores:

	; draw p1 score
	ld a, (p1_score)
	add a, TILES_NUMBERS
	ld hl, TILEMAP_ADDR_XY(4, 22)
	ld (hl), a

	; draw p2 score
	ld a, (p2_score)
	add a, TILES_NUMBERS
	ld hl, TILEMAP_ADDR_XY(24, 22)
	ld (hl), a

	ret

game_won:

	ld a, 1
	ld (game_state), a

	; check which player won
	ld a, (scored)
	dec a

	jr nz, gw_p2_win

		ld a, 1
		ld (last_winner), a

		ld de, p1_win_string
		jr gw_write

	gw_p2_win:

		ld a, 2
		ld (last_winner), a

		ld de, p2_win_string
	
	gw_write:

	ld b, _sizeof_p1_win_string
	ld hl, TILEMAP_ADDR_XY(10, 10)

	game_won_text_loop:

		ld a, (de)
		add a, TILES_START
		ld (hl), a
		inc de
		inc hl

		djnz game_won_text_loop

	; stop any currently playing sfx
	call banjo_sfx_stop

	; play win song
	ld hl, win
	call banjo_play_song

	ret

draw_playfield:

	; initialise tilemap

	; top solid row
	ld hl, TILEMAP_ADDR_XY(0, 0)
	ld b, TILEMAP_W
	ld d, TILES_PADDLE_MIDDLE

	-:
		ld (hl), d
		inc hl
		djnz -

	; empty middle
	ld hl, TILEMAP_ADDR_XY(0, 1)
	ld c, 19
	ld d, TILES_EMPTY
	
	--:

		ld b, TILEMAP_W

		-:
			ld (hl), d

			inc hl
			djnz -

		inc hl
		inc hl
		inc hl
		inc hl

		dec c
		jr nz, --

	; bottom solid row
	ld hl, TILEMAP_ADDR_XY(0, 20)
	ld b, TILEMAP_W
	ld d, TILES_PADDLE_MIDDLE

	-:
		ld (hl), d
		inc hl
		djnz -

	ld b, TILEMAP_ROW_SIZE * 3
	ld d, TILES_EMPTY
	-:
		ld (hl), d
		inc hl
		djnz -

	; name text
	ld hl, TILEMAP_ADDR_XY(9, 22)
	ld b, _sizeof_game_name_string
	ld de, game_name_string
	-:
		ld a, (de)
		add a, TILES_START
		ld (hl), a
		inc hl
		inc de
		djnz -

	; credit text
	ld hl, TILEMAP_ADDR_XY(9, 23)
	ld b, _sizeof_credit_string
	ld de, credit_string
	-:
		ld a, (de)
		add a, TILES_START
		ld (hl), a
		inc hl
		inc de
		djnz -

	ret


.include "ball.asm"
.include "paddle.asm"

; strings
.stringmaptable script "stringmap.tbl"

p1_win_string:
.stringmap script "P1 WINS!"

p2_win_string:
.stringmap script "P2 WINS!"

game_name_string:
.stringmap script "PV0NG"

credit_string:
.stringmap script "J0E K 2025"

strings_done:

; songs
song_data_start:
.include "music_asm/p1_theme.asm"
.include "music_asm/p2_theme.asm"
.include "music_asm/win.asm"

sfx_data_start:
.include "music_asm/paddle_hit_sfx.asm"
.include "music_asm/scored_sfx.asm"

ball_anim_1bit:
.incbin "gfx_bin/ball_anim.bin"

.org TILES_START * 32
.incbin "gfx_bin/tiles.bin"
.incbin "gfx_bin/numbers.bin"

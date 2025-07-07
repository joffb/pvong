
python3 png2pv1000.py gfx_png/pongtiles.png gfx_bin/tiles.bin
python3 png2pv1000.py gfx_png/numbers.png gfx_bin/numbers.bin
python3 png2pv1000.py --green gfx_png/ball_anim.png gfx_bin/ball_anim.bin

python3 ../pvbanjo/furnace2json.py -o music_asm/scored_sfx.json music_fur/scored.fur
python3 ../pvbanjo/json2sms.py -s 2 -o music_asm/scored_sfx.asm -i scored_sfx music_asm/scored_sfx.json 

python3 ../pvbanjo/furnace2json.py -o music_asm/paddle_hit_sfx.json music_fur/paddle_hit.fur
python3 ../pvbanjo/json2sms.py -s 2 -o music_asm/paddle_hit_sfx.asm -i paddle_hit_sfx music_asm/paddle_hit_sfx.json 

python3 ../pvbanjo/furnace2json.py -o music_asm/p1_theme.json music_fur/p1_theme.fur
python3 ../pvbanjo/json2sms.py -o music_asm/p1_theme.asm -i p1_theme music_asm/p1_theme.json 

python3 ../pvbanjo/furnace2json.py -o music_asm/p2_theme.json music_fur/p2_theme.fur
python3 ../pvbanjo/json2sms.py -o music_asm/p2_theme.asm -i p2_theme music_asm/p2_theme.json 

python3 ../pvbanjo/furnace2json.py -o music_asm/win.json music_fur/win.fur
python3 ../pvbanjo/json2sms.py -o music_asm/win.asm -i win music_asm/win.json

wla-z80 main.asm
wlalink -v -s -r linkfile.txt "pvong.bin"

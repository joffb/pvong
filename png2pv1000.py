
import os, sys
from pathlib import Path
from PIL import Image
from optparse import OptionParser

print("png2pv1000 - Joe Kennedy 2025")

parser = OptionParser("Usage: png2pv1000.py [options] input_filename.png output_filename.bin")
parser.add_option("-r", '--red',        action="store_true", dest='include_red',     help='include red channel data')
parser.add_option("-g", '--green',        action="store_true", dest='include_green',     help='include green channel data')
parser.add_option("-b", '--blue',        action="store_true", dest='include_blue',     help='include blue channel data')

(options, args) = parser.parse_args()

if (len(args) < 2):
    parser.print_help()
    parser.error("Input and output file names required\n")

infile = Path(args[0])
outfile = Path(args[1])

selected_components = True if (options.include_red or options.include_green or options.include_blue) else False

tdata = []

with Image.open(infile) as im:
    
    w, h = im.size

    print("image w,h = " + str(w) + ", " + str(h))
    print("mode = " + im.mode)

    if w % 8 != 0:

        print("image width is not a multiple of 8 pixels")
        sys.exit()

    for y in range(0, h, 8):

        for x in range(0, w, 8):
            
            rdata = []
            gdata = []
            bdata = []
            
            # go through all 8 rows of each tile
            for r in range (0, 8):

                new_r = 0
                new_g = 0
                new_b = 0

                # go through all 8 pixels of each row
                for i in range(0, 8):

                    new_bit = 1 << (7 - i)

                    # source image is in rgb colour mode
                    if im.mode == "RGB":

                        colour = im.getpixel((x + i, y + r))

                        if colour[0] >= 128:
                            new_r |= new_bit

                        if colour[1] >= 128:
                            new_g |= new_bit

                        if colour[2] >= 128:
                            new_b |= new_bit
                    
                    # source image is in paletted colour mode
                    elif im.mode == "P":

                        p = im.getpixel((x + i, y + r))

                        if p & 0x1:
                            new_r |= new_bit

                        if p & 0x2:
                            new_g |= new_bit

                        if p & 0x4:
                            new_b |= new_bit

                rdata.append(new_r)
                gdata.append(new_g)
                bdata.append(new_b)
                
            if selected_components == False:
                
                # write full tile data to main array
                tdata.append([0,0,0,0,0,0,0,0])
                tdata.append(rdata)
                tdata.append(gdata)
                tdata.append(bdata)

            else:

                # write selected colour components to main array
                if options.include_red:
                    tdata.append(rdata)

                if options.include_green:
                    tdata.append(gdata)

                if options.include_blue:
                    tdata.append(bdata)           

    with open(outfile, "wb") as bfile:

        for i, a in enumerate(tdata):
            bfile.write(bytes(a))
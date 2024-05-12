import sys
sys.stdout.reconfigure(encoding='ascii')

with open('test.hack', 'rb') as file:
    lines = file.readlines()
    addr = 0
    out_shell = open("test.bin", 'w', encoding='ascii')
    out_inc = open("init_rom.inc", 'w', encoding='ascii')
  #defparam ROM.INIT_1 = 256'h8888ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    init_block_count = 0
    init_row_count = 0
    init_row =["0000"]*16
    def write_init():
        out_inc.write(f"defparam ROM.INIT_{init_row_count} = 256'h")
        out_inc.write("".join(init_row))
        out_inc.write(";\n")
    for line in lines:
        num = int(line, 2)
        init_row[15-init_block_count ] = "{0:04x}".format(num)
        if init_block_count == 15:
            write_init()
            init_row_count = init_row_count + 1
        
            init_block_count = 0
            init_row =["0000"]*16
        else:
            init_block_count = init_block_count + 1
        print("wr {0:04x} {1:04x}\r".format(addr, num  ))
        out_shell.write("wr {0:04x} {1:04x}\r".format(addr, num  ))
        addr = addr+1
    write_init()

    
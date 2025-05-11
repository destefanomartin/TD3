#CHAIN=arm-none-eabi
CHAIN=arm-linux-gnueabihf
CFLAGS=-std=gnu99 -Wall -mcpu=cortex-a8

all: tp05.bin tp05.elf

tp05.bin: tp05.elf
	$(CHAIN)-objcopy -O binary $< $@


tp05.elf: tp05.o move_function.o gic.o
	$(CHAIN)-ld -g -T td3_memmap.ld *.o -o tp05.elf -Map $(LST)tp05.map
	$(CHAIN)-objdump -D tp05.elf > tp05.lst

tp05.o: tp05.s
	$(CHAIN)-as tp05.s -g -o tp05.o -a > $(LST)tp05.lst

move_function.o: move_function.c
	$(CHAIN)-gcc -g -O0 $(CFLAGS) -c move_function.c -o move_function.o

gic.o: gic.c
	$(CHAIN)-gcc -g -O0 $(CFLAGS) -c gic.c -o gic.o

clean:
	rm -rf *.o *.elf *.bin $(LST)*.lst $(LST)*.txt $(LST)*.map

run:
	qemu-system-arm -M realview-pb-a8 -m 32M -no-reboot -nographic -monitor telnet:127.0.0.1:1234,server,nowait -S -gdb tcp::2159 -kernel .//tp05.bin

debug:
	ddd --debugger gdb-multiarch tp05.elf

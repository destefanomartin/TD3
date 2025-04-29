#CHAIN=arm-none-eabi
CHAIN=arm-linux-gnueabihf
CFLAGS=-std=gnu99 -Wall -mcpu=cortex-a8

all: tp03.bin tp03.elf

tp03.bin: tp03.elf
	$(CHAIN)-objcopy -O binary $< $@


tp03.elf: tp03.o move_function.o
	$(CHAIN)-ld -g -T td3_memmap.ld *.o -o tp03.elf -Map $(LST)tp03.map
	$(CHAIN)-objdump -D tp03.elf > tp03.lst

tp03.o: tp03.s
	$(CHAIN)-as tp03.s -g -o tp03.o -a > $(LST)tp03.lst

move_function.o: move_function.c
	$(CHAIN)-gcc -g -O0 $(CFLAGS) -c move_function.c -o move_function.o

clean:
	rm -rf *.o *.elf *.bin $(LST)*.lst $(LST)*.txt $(LST)*.map

run:
	qemu-system-arm -M realview-pb-a8 -m 32M -no-reboot -nographic -monitor telnet:127.0.0.1:1234,server,nowait -S -gdb tcp::2159 -kernel .//tp03.bin

debug:
	ddd --debugger gdb-multiarch tp03.elf

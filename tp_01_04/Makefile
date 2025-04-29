#CHAIN=arm-none-eabi
CHAIN=arm-linux-gnueabihf
CFLAGS=-std=gnu99 -Wall -mcpu=cortex-a8

all: tp04.bin tp04.elf

tp04.bin: tp04.elf
	$(CHAIN)-objcopy -O binary $< $@


tp04.elf: tp04.o move_function.o
	$(CHAIN)-ld -g -T td3_memmap.ld *.o -o tp04.elf -Map $(LST)tp04.map
	$(CHAIN)-objdump -D tp04.elf > tp04.lst

tp04.o: tp04.s
	$(CHAIN)-as tp04.s -g -o tp04.o -a > $(LST)tp04.lst

move_function.o: move_function.c
	$(CHAIN)-gcc -g -O0 $(CFLAGS) -c move_function.c -o move_function.o

clean:
	rm -rf *.o *.elf *.bin $(LST)*.lst $(LST)*.txt $(LST)*.map

run:
	qemu-system-arm -M realview-pb-a8 -m 32M -no-reboot -nographic -monitor telnet:127.0.0.1:1234,server,nowait -S -gdb tcp::2159 -kernel .//tp04.bin

debug:
	ddd --debugger gdb-multiarch tp04.elf

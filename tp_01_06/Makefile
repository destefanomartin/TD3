#CHAIN=arm-none-eabi
CHAIN=arm-linux-gnueabihf
CFLAGS=-std=gnu99 -Wall -mcpu=cortex-a8


all: tp06.bin tp06.elf

tp06.bin: tp06.elf
	$(CHAIN)-objcopy -O binary $< $@


tp06.elf: tp06.o move_function.o gic.o
	$(CHAIN)-ld -g -T td3_memmap.ld *.o -o tp06.elf -Map $(LST)tp06.map
	$(CHAIN)-objdump -D tp06.elf > tp06.lst


tp06.o: tp06.S
	$(CHAIN)-as tp06.S -g -o tp06.o -a > $(LST)tp06.lst

move_function.o: move_function.c
	$(CHAIN)-gcc -g -O0 $(CFLAGS) -c move_function.c -o move_function.o

gic.o: gic.c
	$(CHAIN)-gcc -g -O0 $(CFLAGS) -c gic.c -o gic.o 

exceptions: 
	$(CHAIN)-as tp06.S -g -Wall -DGEN_EXCEPTION -o tp06.o -a  > $(LST)tp06.lst 
	$(CHAIN)-gcc -g -O0 $(CFLAGS) -c move_function.c -o move_function.o
	$(CHAIN)-gcc -g -O0 $(CFLAGS) -c gic.c -o gic.o
	$(CHAIN)-ld -g -T td3_memmap.ld *.o -o tp06.elf -Map $(LST)tp06.map
	$(CHAIN)-objdump -D tp06.elf > tp06.lst

clean:
	rm -rf *.o *.elf *.bin $(LST)*.lst $(LST)*.txt $(LST)*.map

run:
	qemu-system-arm -M realview-pb-a8 -m 32M -no-reboot -nographic -monitor telnet:127.0.0.1:1234,server,nowait -S -gdb tcp::2159 -kernel .//tp06.bin

debug:
	ddd --debugger gdb-multiarch tp06.elf

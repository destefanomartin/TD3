#CHAIN=arm-none-eabi
CHAIN=arm-linux-gnueabihf
CFLAGS=-std=gnu99 -Wall -mcpu=cortex-a8


all: tp07.bin tp07.elf

tp07.bin: tp07.elf
	$(CHAIN)-objcopy -O binary $< $@


tp07.elf: tp07.o task1.o task2.o 
	$(CHAIN)-ld -g -T td3_memmap.ld *.o -o tp07.elf -Map $(LST)tp07.map
	$(CHAIN)-objdump -D tp07.elf > tp07.lst


tp07.o: tp07.s
	$(CHAIN)-as tp07.s -g -o tp07.o -a > $(LST)tp07.lst

task1.o: task1.s
	$(CHAIN)-as task1.s -g -o task1.o -a > $(LST)task1.lst

task2.o: task2.s
	$(CHAIN)-as task2.s -g -o task2.o -a > $(LST)task2.lst

exceptions: 
	$(CHAIN)-as tp07.S -g -Wall -DGEN_EXCEPTION -o tp07.o -a  > $(LST)tp07.lst 
	$(CHAIN)-gcc -g -O0 $(CFLAGS) -c move_function.c -o move_function.o
	$(CHAIN)-gcc -g -O0 $(CFLAGS) -c gic.c -o gic.o
	$(CHAIN)-ld -g -T td3_memmap.ld *.o -o tp07.elf -Map $(LST)tp07.map
	$(CHAIN)-objdump -D tp07.elf > tp07.lst

clean:
	rm -rf *.o *.elf *.bin $(LST)*.lst $(LST)*.txt $(LST)*.map

run:
	qemu-system-arm -M realview-pb-a8 -m 512M -no-reboot -nographic -monitor telnet:127.0.0.1:1234,server,nowait -S -gdb tcp::2159 -kernel .//tp07.bin

debug:
	ddd --debugger gdb-multiarch tp07.elf

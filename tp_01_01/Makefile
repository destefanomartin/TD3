all:
	arm-linux-gnueabihf-as -g -o tp01.o tp01.s
	arm-linux-gnueabihf-ld -g -o tp01.elf tp01.o -Map tp01.map -T td3_memmap.ld
	arm-linux-gnueabihf-objdump -g tp01.elf > tp01.lst
	arm-linux-gnueabihf-objcopy -g -O binary tp01.elf tp01.bin
run:
	qemu-system-arm -M realview-pb-a8 -m 32M -no-reboot -nographic -monitor telnet:127.0.0.1:1234,server,nowait -S -gdb tcp::2159 -kernel tp01.bin

debug:
	ddd --debugger gdb-multiarch tp01.elf

clean:
	rm -f *.o *.lst *.elf *.map *.bin

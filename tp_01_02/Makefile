all:
	arm-linux-gnueabihf-as -g -o tp02.o tp02.s
	arm-linux-gnueabihf-ld -g -o tp02.elf tp02.o -Map tp02.map -T td3_memmap.ld
	arm-linux-gnueabihf-objdump -g tp02.elf > tp02.lst
	arm-linux-gnueabihf-objcopy -g -O binary tp02.elf tp02.bin
run:
	qemu-system-arm -M realview-pb-a8 -m 32M -no-reboot -nographic -monitor telnet:127.0.0.1:1234,server,nowait -S -gdb tcp::2159 -kernel tp02.bin

debug:
	ddd --debugger gdb-multiarch tp02.elf

clean:
	rm -f *.o *.lst *.elf *.map *.bin

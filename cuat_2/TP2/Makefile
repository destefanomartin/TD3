obj-m := driver.o
KERNELDIR := /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

all: driver server

driver:
	make -C $(KERNELDIR) M=$(PWD)

server:
	gcc -o server server.c -pthread

clean:
	rm -rf *.o core .depend .*.cmd *.mod.c *.mod *.ko .tmp_versions modules.* Module* *.dwo
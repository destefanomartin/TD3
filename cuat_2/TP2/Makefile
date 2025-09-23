obj-m := driver.o
KERNELDIR := /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

all:
	make -C $(KERNELDIR) M=$(PWD)

clean:
	rm -rf *.o core .depend .*.cmd *.mod.c *.mod *.ko .tmp_versions modules.* Module* *.dwo
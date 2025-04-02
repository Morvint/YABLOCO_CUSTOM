#переменные
GDB=gdb
OBJCOPY=objcopy
CAT=cat

#Настройки для Windows
ifeq ($(OS),Windows_NT)
	CAT=type
else
	OS=$(shell uname -s)
endif

#Настройи для MacOS
ifeq ($(OS),Darwin)
AS=x86_64-elf-as
LD=x86_64-elf-ld
CC=x86_64-elf-gcc
GDB=x86_64-elf-gdb
OBJCOPY=x86_64-elf-objcopy
endif

#флаги компиляции
CFLAGS = -fno-pic -ffreestanding -static -fno-builtin -fno-strict-aliasing \
		 -mno-sse \
		 -I. \
		 -Wall -ggdb -m32 -Werror -fno-omit-frame-pointer
CFLAGS += $(shell $(CC) -fno-stack-protector -E -x c /dev/null >/dev/null 2>&1 && echo -fno-stack-protector)
#флаги ассемблера
ASMFLAGS = -m32 -ffreestanding -c -g -I.

#настройки для LLVM
ifeq ($(LLVM),on)

ifeq ($(OS),Darwin)
	LD=PATH=/usr/local/opt/llvm/bin:"$(PATH)" ld.lld
else
	LD=ld.lld
endif

CC=clang
CFLAGS += -target elf-i386
ASMFLAGS += -target elf-i386
LDKERNELFLAGS = --script=script.ld
endif

#список объектных файлов
OBJECTS = ./kernel/kstart.o ./kernel.o ./console.o ./drivers/vga.o ./drivers/uart.o ./drivers/keyboard.o \
	./cpu/idt.o ./cpu/gdt.o ./cpu/swtch.o ./cpu/vectors.o ./kernel/mem.o ./proc.o ./lib/string.o \
	./fs/fs.o ./drivers/ata.o ./lib/string.o ./proc.o ./drivers/pit.o ./kernel/vm.o ./drivers/timer.o

#запуск qemu с графическим интерфейсом
run: image.bin
	qemu-system-i386 -drive format=raw,file=$< -serial mon:stdio

#запуск qemu без графического интерфейса
run-nox: image.bin
	qemu-system-i386 -nographic -drive format=raw,file=$< -serial mon:stdio

#скрипт для ejudge
ejudge.sh: image.bin
	echo >$@ "#!/bin/sh"
	echo >>$@ "base64 -d <<===EOF | gunzip >image.bin"
	gzip <$^ | base64 >>$@
	echo >>$@ "===EOF"
	echo >>$@ "exec qemu-system-i386 -nographic -drive format=raw,file=image.bin -serial mon:stdio"
	chmod +x $@

#диагностика окружения
diag:
	-$(UNAME) -a
	-$(CC) --version
	-$(LD) -v
	-gcc --version
	-ld -v

#отладка загрузчика
debug-boot-nox: image.bin mbr.elf
	qemu-system-i386 -nographic -drive format=raw,file=$< -s -S &
	$(GDB) mbr.elf \
		-ex "set architecture i8086" \
		-ex "target remote localhost:1234" \
		-ex "break *0x7c00" \
		-ex "continue"

debug-boot: image.bin mbr.elf
	qemu-system-i386 -drive format=raw,file=$< -s -S &
	$(GDB) mbr.elf \
		-ex "set architecture i8086" \
		-ex "target remote localhost:1234" \
		-ex "break *0x7c00" \
		-ex "continue"

#отладка qemu
debug-server: image.bin
	qemu-system-i386 -drive format=raw,file=$< -s -S

debug-server-nox: image.bin
	qemu-system-i386 -nographic -drive format=raw,file=$< -s -S

#отладка ядра
debug: image.bin
	qemu-system-i386 -drive format=raw,file=$< -s -S &
	$(GDB) kernel.bin \
		-ex "target remote localhost:1234" \
		-ex "break kmain" \
		-ex "continue"

debug-nox: image.bin
	qemu-system-i386 -nographic -drive format=raw,file=$< -s -S &
	$(GDB) kernel.bin \
		-ex "target remote localhost:1234" \
		-ex "break _start" \
		-ex "continue"

#сборка файловой системы
fs.img: ./kernel.bin ./tools/mkfs ./user/false ./user/greet ./user/div0 ./user/shout
	./tools/mkfs $@ $< ./user/false ./user/greet ./user/div0 ./user/shout

LDFLAGS=-m elf_i386

#сборка пользовательский программ
user/%: user/%.o user/crt.o
	$(LD) $(LDFLAGS) -o $@ -Ttext 0x401000 $^

#сборка ядра
kernel.bin: $(OBJECTS)
	$(LD) $(LDFLAGS) $(LDKERNELFLAGS) -o $@ -Ttext 0x80009000 $^

#компиляция исходников
bootmain.o: bootmain.c
	$(CC) $(CFLAGS) -Os -c $< -o $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.S
	$(CC) $(ASMFLAGS) $^ -o $@

#генерация образа диска
image.bin: mbr.elf tools/mbrpad fs.img
	$(OBJCOPY) -S -O binary -j .text $< $@
	tools/mbrpad $@ fs.img

#сборка загрузчика
mbr.raw: mbr.o bootmain.o
	$(LD) -N -m elf_i386 -Ttext=0x7c00 --oformat=binary $^ -o $@

mbr.elf: mbr.o bootmain.o
	$(LD) -N -m elf_i386 -Ttext=0x7c00 $^ -o $@

clean:
	rm -f *.elf *.img *.bin *.raw *.o */*.o tools/mkfs ejudge.sh

tools/%: tools/%.c
	gcc -Wall -Werror -g $^ -o $@

#include "keyboard.h"
#include "cpu/isr.h"
#include "cpu/memlayout.h"
#include "console.h"
#include "port.h"
#include "kernel/mem.h"



//таблица преобразования скан-кодов
static const char sc_ascii_layer0[] = {'?', 
    '?', 
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', '\b', 
    '?', 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', '\n',
    '?', 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'',
    '`', '?', '\\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', '?', 
    '?', '?', ' ',
};

static const char sc_ascii_layer1[] = {'?', 
    '?', 
    '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', '\b', 
    '?', 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', '\n',
    '?', 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"',
    '~', '?', '|', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', '?', 
    '?', '?', ' ',
};

static int Layer = 0;

//Максимальный размер буфера клавиатуры и константы
enum { 
    kbd_buf_capacity = PGSIZE,
    RShiftD = 0x2A,
    RShiftU = 0xAA,
    LShiftD = 0x36,
    LShiftU = 0xB6,
};

//Обработчик клавиатуры
static void interrupt_handler(registers_t *r) {
    uint8_t scancode = port_byte_in(0x60);                      //считывание сканкода
    if(scancode == RShiftD || scancode == LShiftD){
        Layer = 1;
        return;
    }
    if(scancode == RShiftU || scancode == LShiftU){
        Layer = 0;
        return;
    }

    if (scancode < sizeof(sc_ascii_layer0)) {                   //только те символы, которые есть в таблице
        char c;
        if(Layer == 0){
            c = sc_ascii_layer0[scancode];                      //символ и таблицы
        }else{
            c = sc_ascii_layer1[scancode];
        }

        if (c == '\b' && kbd_buf_size < 1){                     //игнорирование стирания, когда буфер не заполнен
            return;
        } else if (c == '\b'){
            kbd_buf_size--;
        } else if (kbd_buf_size < kbd_buf_capacity) {           //проверка наличия места в буффере и сохранение в нем символа
            kbd_buf[kbd_buf_size++] = c;
        }
        
        char string[] = {c, '\0'};                              //временная строка
        printk(string);                                         //вывод в консоль
    }
}

char* kbd_buf;                                                  //указатель на буффер
unsigned kbd_buf_size;                                          //размер буффера

//Инициализация обработчика клавиатуры
void init_keyboard() {
    kbd_buf = kalloc();

    register_interrupt_handler(IRQ1, interrupt_handler);
}

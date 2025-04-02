#include "pit.h"
#include "vga.h"
#include "console.h"
volatile unsigned long timer_ticks = 0;

int count_digits(unsigned long num){
    int digits = 0;
    do {
        digits++;
        num /= 10;
    } while (num  > 0);
    return digits;    
}

int ulong_to_str(unsigned long num, char *buffer){
    if (num == 0){
        buffer[0] = '0';
        buffer[1] = '\0';
        return 1;
    }

    int digits = count_digits(num);
    int pos = digits;
    buffer[pos] = '\0';

    while (num > 0){
        buffer[--pos] = (num % 10) + '0';
        num /= 10;
    }

    return digits;
}

unsigned long get_ticks(){
    char str[20];
    int digits = ulong_to_str(ticks, str);
    for (int i = 0; i < digits; i++){
        char string[] = {str[i], '\0'};
        printk(string);
    }
    return timer_ticks;
}
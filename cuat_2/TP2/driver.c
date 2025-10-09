#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/platform_device.h>
#include <linux/gpio.h>
#include <linux/fs.h>
#include <linux/errno.h>
#include <asm/uaccess.h>
#include <linux/uaccess.h>
#include <linux/version.h>
#include <linux/types.h>
#include <linux/kdev_t.h>
#include <linux/device.h>
#include <linux/cdev.h>
#include <linux/sched.h>
#include <linux/io.h>
#include <linux/delay.h>
#include <linux/jiffies.h>

struct arguments {
    u8 command;
    u8 millis;   /* tens of milliseconds (i.e. 20 => 200 ms) */
};

/* Comandos */
enum {
    CMD_FORBIDDEN = 0,
    CMD_BEEP = 1,
    CMD_GREEN_LED = 2,
    CMD_RED_LED   = 3,
    CMD_ORANGE_LED = 4
};



#define GPIO2_REGISTER 0x481AC000
#define CM_PER_REGISTER 0x44E00000 
#define CM_REGISTER 0x44E10000

#define GPIO2_SIZE 0x1000
#define CM_PER_SIZE 0x400
#define CM_SIZE 0x20000


/* OFFSET GPIO2 REGISTER */

#define GPIO_REVISION           0x000
#define GPIO_SYSCONFIG          0x010
#define GPIO_EOI                0x020
#define GPIO_IRQSTATUS_RAW_0    0x024
#define GPIO_IRQSTATUS_RAW_1    0x028
#define GPIO_IRQSTATUS_0        0x02C
#define GPIO_IRQSTATUS_1        0x030
#define GPIO_IRQSTATUS_SET_0    0x034
#define GPIO_IRQSTATUS_SET_1    0x038
#define GPIO_IRQSTATUS_CLR_0    0x03C
#define GPIO_IRQSTATUS_CLR_1    0x040
#define GPIO_IRQWAKEN_0         0x044
#define GPIO_IRQWAKEN_1         0x048
#define GPIO_SYSSTATUS          0x114
#define GPIO_CTRL               0x130
#define GPIO_OE                 0x134
#define GPIO_DATAIN             0x138
#define GPIO_DATAOUT            0x13C
#define GPIO_LEVELDETECT0       0x140
#define GPIO_LEVELDETECT1       0x144
#define GPIO_RISINGDETECT       0x148
#define GPIO_FALLINGDETECT      0x14C
#define GPIO_DEBOUNCENABLE      0x150
#define GPIO_DEBOUNCINGTIME     0x154
#define GPIO_CLEARDATAOUT       0x190
#define GPIO_SETDATAOUT         0x194

/* OFFSET CM_PER FOR GPIO2 */
#define GPIO2_CLK_OFFSET 0xB0

/* OFFSET FOR PINS */

// KEYBOARD 

#define C1_OFFSET 0x8C4 // SALIDA C1 P8_38 2_15
#define C1_PIN 79
#define C2_OFFSET 0x8C0 // SALIDA C2 P8_37 2_14
#define C2_PIN 78
#define C3_OFFSET 0x8A8 // SALIDA C3 P8_43 2_8
#define C3_PIN 72
#define F1_OFFSET 0x8AC // ENTRADA F1 P8_44 2_9
#define F2_OFFSET 0x8B0 // ENTRADA F2 P8_41 2_10
#define F3_OFFSET 0x8B4 // ENTRADA F3 P8_42 2_11
#define F4_OFFSET 0x8B8 // ENTRADA F4 P8_39 2_12


static const u32 col_pins[3] = { (1 << 15) , (1 << 14), (1 << 8) };

// BUZZER 
#define BUZZER_OFFSET 0x88C // SALIDA P8_18 2_1
#define BUZZER_PIN (1 << 1)


// LEDS three provisional
#define GLED_OFFSET 0x890 // SALIDA P8_7 2_2
#define GLED_PIN (1 << 2)
#define RLED_OFFSET 0x894 // SALIDA P8_8 2_3
#define RLED_PIN (1 << 3)
#define BLED_OFFSET 0x898 // SALIDA P8_10 2_4
#define BLED_PIN (1 << 4)


// Valores para pines 

#define GPIO_INPUT 0x77 // (1110111)
#define GPIO_OUTPUT 0x5F
#define OE_CONFIG_INPUT 0x1E00
#define OE_CONFIG_OUTPUT 0xC11E
#define DEBOUNCE_ENABLE 0x1E00
#define DEBOUNCE_TIME 0x285
#define IRQ_ENABLE 0x1E00
#define LOW_LEVEL_DETECT 0x1E00
#define CLEAR_IRQ 0x1E00
#define FALLING_DETECT 0x1E00
#define CLK_GPIO2_CONFIG 0x40002 // Enable + Optional features for deboucing

#define COL_MASK (BUZZER_PIN | GLED_PIN | RLED_PIN  | (1 << 8) | (1 << 15 ) | (1 << 14))   // 0x0000C100
#define ROW_MASK ( (1<<9) | (1<<10) | (1<<11) | (1<<12) ) // 0x1E00

static DECLARE_WAIT_QUEUE_HEAD(wait_queue); 
static int code_ready = 0; 
static char prev_scan_key = 0;         /* última tecla leída por kb_read() */
static char last_processed_key = 0;    /* última tecla ya procesada (evita repeticiones mientras se mantiene) */
static int stable_count = 0;           /* cuantas lecturas consecutivas igual a prev_scan_key */
#define STABLE_REQUIRED 2              /* requerir 2 lecturas iguales para considerar estable */
static int col = 0; 
// Jiffies 

static struct timer_list kbread_timer; 
static struct timer_list led_timer; 
static struct timer_list long_buzzer_timer; 
static struct timer_list short_buzzer_timer; 

// Lectura y escritura 

static const char keyboard_mapping[4][3] = {
    {'1', '2', '3'},
    {'4', '5', '6'},
    {'7', '8', '9'},
    {'*', '0', '#'}
};


MODULE_LICENSE("Dual BSD/GPL"); // Requerido
MODULE_AUTHOR("Martin Destefano");
MODULE_DESCRIPTION("");

static ssize_t td3driver_read(struct file *, char __user *, size_t, loff_t *);
static ssize_t td3driver_write(struct file *, const char __user *, size_t, loff_t *);
static int my_dev_uevent(struct device *, struct kobj_uevent_env *);

static char buffer[5]; 
static char aux_buffer[5];
static int char_count = 0; 

static void __iomem *gpio2_base; 
static void __iomem *cm_base; 
static void __iomem *cm_per_base; 

static dev_t dev; // Todo estatico para que no se meta dentro del Kernel
static struct class *cl; 

struct file_operations td3driver_fops =
{
  .owner = THIS_MODULE, 
  .read = td3driver_read,
  .write = td3driver_write,      
};
static struct cdev td3driver_cdev;


static char kb_read(void)
{
    int row,c; 
    char key=0; 
    
    for(c = 0; c < 3; c++)
    {
        iowrite32(col_pins[c], gpio2_base + GPIO_SETDATAOUT);
    }

    iowrite32(col_pins[col], gpio2_base + GPIO_CLEARDATAOUT);
    udelay(10);

    for(row = 9; row < 13; row++)
      {
        if((ioread32(gpio2_base + GPIO_DATAIN) & (1u << row)) == 0) 
        {
          printk(KERN_INFO "columna %d y fila %d\n", col, row);
          key = keyboard_mapping[row-9][col]; 
          iowrite32(1u << col_pins[col], gpio2_base + GPIO_SETDATAOUT);
          col = 0; 
          return key;  
        }
    }
    col++; 
    if(col == 3) col = 0;  
    
    return key; 
}


static void process_key(char key) {
    if (key == '*') {
        if (char_count == 4) {
            buffer[char_count] = '\0';
            printk(KERN_INFO "Codigo ingresado: %s\n", buffer);
            code_ready = 1;
            aux_buffer[0] = '\0';
            memcpy(aux_buffer, buffer, 5);
            wake_up_interruptible(&wait_queue);
            char_count = 0;
            buffer[0] = '\0';
        } else {
            char_count = 0;
            buffer[0] = '\0';
            printk(KERN_INFO "Asterisco prematuro -> reinicio trama\n");
        }
    } else {
        if (char_count < (int)sizeof(buffer) - 1) {
            buffer[char_count++] = key;
            buffer[char_count] = '\0';
            printk(KERN_INFO "Tecla aceptada: %c  buffer: %s\n", key, buffer);
        } else {
            printk(KERN_INFO "Buffer overflow -> reinicio\n");
            char_count = 0;
            buffer[0] = '\0';
        }
    }
}

static void kbread_timer_callback(struct timer_list *t)
{
    char key = kb_read(); 
    mod_timer(&kbread_timer, jiffies + msecs_to_jiffies(60));

    if (key == 0) {
        stable_count++;
    } else {
        process_key(key);

    }

}


static void led_timer_callback(struct timer_list *t)
{
    // Logica apagado ( no se renueva, se activa cuando se ingresa un codigo correcto, erroneo o nuevo)
    iowrite32(RLED_PIN, gpio2_base + GPIO_CLEARDATAOUT); 
    iowrite32(GLED_PIN, gpio2_base + GPIO_CLEARDATAOUT);
    iowrite32(BLED_PIN, gpio2_base + GPIO_CLEARDATAOUT);
}

static void long_buzzer_timer_callback(struct timer_list *t)
{
    // Logica apagado ( no se renueva timer, se activa cuando se recibe un codigo nuevo )
    iowrite32(BUZZER_PIN, gpio2_base + GPIO_CLEARDATAOUT);

}

static void short_buzzer_timer_callback(struct timer_list *t)
{
    // Logica apagado ( no se renueva, se activa con codigo correcto u erroneo )
    iowrite32(BUZZER_PIN, gpio2_base + GPIO_CLEARDATAOUT);

}



static int td3_probe(struct platform_device *pdev) // Aca hay que hacer lo de las direcciones de memoria, etc. Por ahora asegurar que lo llama 
{ 
    printk(KERN_INFO "td3driver: probe() llamado\n");


    /* Mapeo los tres registros que necesito, el de GPIO, CM para controlar la func. del pin
    y CM_PER_BASE para los timers del GPIO2 */
    cm_base = ioremap(CM_REGISTER, CM_SIZE); 
    if(cm_base == NULL)
      {
        return -1;
      }  

    iowrite32(GPIO_OUTPUT, cm_base + C1_OFFSET ); 
    iowrite32(GPIO_OUTPUT, cm_base + C2_OFFSET ); 
    iowrite32(GPIO_OUTPUT, cm_base + C3_OFFSET ); 
    iowrite32(GPIO_INPUT, cm_base + F1_OFFSET ); 
    iowrite32(GPIO_INPUT, cm_base + F2_OFFSET ); 
    iowrite32(GPIO_INPUT, cm_base + F3_OFFSET ); 
    iowrite32(GPIO_INPUT, cm_base + F4_OFFSET ); 

    iowrite32(GPIO_OUTPUT, cm_base + RLED_OFFSET ); 
    iowrite32(GPIO_OUTPUT, cm_base + GLED_OFFSET ); 
    iowrite32(GPIO_OUTPUT, cm_base + BLED_OFFSET ); 

    iowrite32(GPIO_OUTPUT, cm_base + BUZZER_OFFSET ); 

    u32 cmconfig;

    cmconfig = ioread32(cm_base + RLED_OFFSET);

    cm_per_base = ioremap(CM_PER_REGISTER, CM_PER_SIZE);    
    if(cm_per_base == NULL)
    {
      iounmap(cm_base);
      return -1;
    }  

    // Configuracion de CLK GPIO2
    iowrite32(CLK_GPIO2_CONFIG, cm_per_base + GPIO2_CLK_OFFSET); 

    u32 clkconfig; 
    clkconfig = ioread32(cm_per_base + GPIO2_CLK_OFFSET); 
    printk(KERN_INFO "clkonfig RLED = 0x%08x\n", clkconfig);



    gpio2_base = ioremap(GPIO2_REGISTER, GPIO2_SIZE); 
    if(gpio2_base == NULL)
    {
      iounmap(cm_per_base);
      iounmap(cm_base);
      return -1;
    }  

    if (!(ioread32(gpio2_base + GPIO_SYSSTATUS) & 0x1)) {
    printk(KERN_ERR "GPIO2 no salió de reset, abortando probe\n");
    iounmap(gpio2_base);
    iounmap(cm_per_base);
    iounmap(cm_base);
    return -ENODEV;
    }

    // Configurar E/S
    u32 oe = ioread32(gpio2_base + GPIO_OE); 
    
/* columnas = salidas -> poner a 0 esos bits */
    oe &= ~COL_MASK;

/* filas = entradas -> poner a 1 esos bits */
    oe |= ROW_MASK;

    iowrite32(oe, gpio2_base + GPIO_OE);

/* verificar leyendo de vuelta */
    printk(KERN_INFO "OE after write = 0x%08x\n", ioread32(gpio2_base + GPIO_OE));


    // Activar debounce 
    iowrite32(DEBOUNCE_ENABLE, gpio2_base + GPIO_DEBOUNCENABLE); 

    // Tiempo de debounce 
    iowrite32(DEBOUNCE_TIME, gpio2_base + GPIO_DEBOUNCINGTIME); 

    // // Activar IRQ en las entradas 
    // iowrite32(IRQ_ENABLE, gpio2_base + GPIO_IRQSTATUS_SET_0); 

    // // Limpiar interrupciones por las dudas 
    // iowrite32(CLEAR_IRQ, gpio2_base + GPIO_IRQSTATUS_CLR_0);

    // // Desactivar high level y activar low level (se hace solo x reset)
    // iowrite32(LOW_LEVEL_DETECT, gpio2_base + GPIO_LEVELDETECT0); 

    // // Falling edge detect 
    // iowrite32(FALLING_DETECT, gpio2_base + GPIO_FALLINGDETECT); 

    init_waitqueue_head(&wait_queue);
    code_ready = 0;

    timer_setup(&kbread_timer, kbread_timer_callback, 0); 
    mod_timer(&kbread_timer, jiffies + msecs_to_jiffies(60)); 

    timer_setup(&led_timer, led_timer_callback, 0);
    timer_setup(&long_buzzer_timer, long_buzzer_timer_callback, 0);
    timer_setup(&short_buzzer_timer, short_buzzer_timer_callback, 0);




    return 0;
}

static int td3_remove(struct platform_device *pdev)
{
    printk(KERN_INFO "td3driver: remove() llamado\n");
    return 0;
}

static const struct of_device_id td3_device[] = {
    { .compatible = "td3,destefano" },
    {}
};
MODULE_DEVICE_TABLE(of, td3_device);






static struct platform_driver td3_platform_driver = {
    .probe  = td3_probe,
    .remove = td3_remove,
    .driver = {
        .name           = "td3driver",
        .of_match_table = td3_device,
    },
};

static int my_dev_uevent(struct device *dev, struct kobj_uevent_env *env)
{
    add_uevent_var(env, "DEVMODE=%#o", 0666);
    return 0;
}



static int td3driver_init( void )
{
  int registration_return; 

  if (alloc_chrdev_region( &dev, 0, 1, "td3driver" ) < 0)
  {  
    printk( KERN_ALERT "No se puede ubicar la region\n" );
    return -1;
  }
  cl = class_create(THIS_MODULE, "chardev" );
  if ( cl == NULL )
  {
    printk( KERN_ALERT "No se puede crear la clase\n" );
    // Borrar lo asignado para no tener memory leak en kernel
    unregister_chrdev_region( dev, 1 ); // IMPORTANTE!
    return -1;
  }
  // Asignar el callback que pone los permisos en /dev/td3driver
  cl -> dev_uevent = my_dev_uevent;
  if( device_create( cl, NULL, dev, NULL, "td3driver" ) == NULL )
  {
    printk( KERN_ALERT "No se puede crear el device driver\n" );
    // Borrar lo asignado para no tener memory leak en kernel
    class_destroy(cl);
    unregister_chrdev_region( dev, 1 );
    return -1;
  }
  cdev_init(&td3driver_cdev, &td3driver_fops); // td3driver fops apunta a las operaciones read, write, etc.
  td3driver_cdev.owner = THIS_MODULE;
  td3driver_cdev.ops = &td3driver_fops;
  if (cdev_add(&td3driver_cdev, dev, 1) == -1)
  {
    printk( KERN_ALERT "No se pudo agregar el device driver al kernel\n" );
    // Borrar lo asignado para no tener memory leak en kernel
    device_destroy( cl, dev );
    class_destroy( cl );
    unregister_chrdev_region( dev, 1 );
    return -1;
  }
  printk(KERN_ALERT "Driver instalado con numero mayor %d y numero menor %d\n",
	 MAJOR(dev), MINOR(dev));

  registration_return = platform_driver_register(&td3_platform_driver); 
  if(registration_return < 0)
  {
    printk(KERN_ALERT "NO SE REGISTRO EL PLATFORM DRIVER"); 
    cdev_del(&td3driver_cdev);
    device_destroy( cl, dev );
    class_destroy( cl );
    unregister_chrdev_region(dev, 1);
    return registration_return; 
  }

  printk(KERN_INFO "DRIVER REGISTRADO CON EXITO\n"); // Va a saltar probe() primero si lo encuentra 
  return 0; 
}



static void td3driver_exit( void )
{
    // Borrar lo asignado para no tener memory leak en kernel
  del_timer(&short_buzzer_timer); 
  del_timer(&long_buzzer_timer); 
  del_timer(&led_timer); 
  del_timer(&kbread_timer); 
  iounmap(gpio2_base); 
  iounmap(cm_per_base);
  iounmap(cm_base); 
  platform_driver_unregister(&td3_platform_driver);
  cdev_del(&td3driver_cdev);
  device_destroy( cl, dev );
  class_destroy( cl );
  unregister_chrdev_region(dev, 1);
  printk(KERN_ALERT "Driver td3 desinstalado.\n");
}

static ssize_t td3driver_read(struct file *filp, char __user *buf,
                              size_t count, loff_t *f_pos)
{
    wait_event_interruptible(wait_queue, code_ready == 1); // bloquea hasta que haya código
    printk(KERN_INFO "SE VA A MANDAR CODIGO\n");
    if(copy_to_user(buf, aux_buffer, 5)) { return -1; }
    code_ready = 0;
    aux_buffer[0] = '\0';
    return 5;
}

static ssize_t td3driver_write(struct file *filp, const char __user *buf,
                               size_t count, loff_t *f_pos)
{
    struct arguments args;

    if (count < sizeof(args))
        return -EINVAL;

    if (copy_from_user(&args, buf, sizeof(args)))
        return -EFAULT;

    /* Interpretar comando */
    switch (args.command) {
    case CMD_BEEP:
        iowrite32(BUZZER_PIN, gpio2_base + GPIO_SETDATAOUT);
        mod_timer(&short_buzzer_timer, jiffies + msecs_to_jiffies(args.millis * 10));
        break;

    case CMD_GREEN_LED:
        iowrite32(GLED_PIN, gpio2_base + GPIO_SETDATAOUT);
        mod_timer(&led_timer, jiffies + msecs_to_jiffies(args.millis * 10));
        break;

    case CMD_RED_LED:
        iowrite32(RLED_PIN, gpio2_base + GPIO_SETDATAOUT);
        mod_timer(&led_timer, jiffies + msecs_to_jiffies(args.millis * 10));
        break;

    case CMD_ORANGE_LED:
        iowrite32(RLED_PIN | GLED_PIN, gpio2_base + GPIO_SETDATAOUT);
        mod_timer(&led_timer, jiffies + msecs_to_jiffies(args.millis * 10));
        break;

    default:
        return -EINVAL;
    }

    return sizeof(args); /* bytes consumidos */ 
}


module_init(td3driver_init); // Rutinas a ejecutarse dentro para instalar
module_exit(td3driver_exit);

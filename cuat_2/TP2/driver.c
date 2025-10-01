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

// KEYBOARD eight pins provisional

#define C1_OFFSET 0x8A0 // SALIDA C1 P8_45 2_6 
#define C1_PIN (1 << 6)
#define C2_OFFSET 0x8A4 // SALIDA C2 P8_46 2_7
#define C2_PIN (1 << 7)
#define C3_OFFSET 0x8A8 // SALIDA C3 P8_43 2_8
#define C3_PIN (1 << 8)
#define F1_OFFSET 0x8AC // ENTRADA F1 P8_44 2_9
#define F2_OFFSET 0x8B0 // ENTRADA F2 P8_41 2_10
#define F3_OFFSET 0x8B4 // ENTRADA F3 P8_42 2_11
#define F4_OFFSET 0x8B8 // ENTRADA F4 P8_39 2_12

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
#define GPIO_OUTPUT 0x7F
#define OE_CONFIG_INPUT 0x1E00
#define OE_CONFIG_OUTPUT 0x01DE
#define DEBOUNCE_ENABLE 0x1E00
#define DEBOUNCE_TIME 0x284
#define IRQ_ENABLE 0x1E00
#define LOW_LEVEL_DETECT 0x1E00
#define CLEAR_IRQ 0x1E00
#define FALLING_DETECT 0x1E00
#define CLK_GPIO2_CONFIG 0x4002 // Enable + Optional features for deboucing


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
    {'#', '0', '*'}
};


MODULE_LICENSE("Dual BSD/GPL"); // Requerido
MODULE_AUTHOR("Martin Destefano");
MODULE_DESCRIPTION("");

static ssize_t td3driver_read(struct file *, char __user *, size_t, loff_t *);
static ssize_t td3driver_write(struct file *, const char __user *, size_t, loff_t *);
static int my_dev_uevent(struct device *, struct kobj_uevent_env *);

static char buffer[4]; 
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
    int col, row; 
    char key; 
    for(col = 0; col < 3; col++)
    {
      iowrite32(C1_PIN, gpio2_base + GPIO_DATAOUT);
      iowrite32(C2_PIN, gpio2_base + GPIO_DATAOUT); 
      iowrite32(C3_PIN, gpio2_base + GPIO_DATAOUT); 
      
      if(col == 0) iowrite32(C1_PIN, gpio2_base + GPIO_CLEARDATAOUT);
      if(col == 1) iowrite32(C2_PIN, gpio2_base + GPIO_CLEARDATAOUT);
      if(col == 2) iowrite32(C3_PIN, gpio2_base + GPIO_CLEARDATAOUT);

      for(row = 9; row < 13; row++)
      {
        if((ioread32(gpio2_base + GPIO_DATAIN) << row) == 0) 
        {
          key = keyboard_mapping[col][row-9]; 
          return key;  
        }
      }
    }

    return key; 

}



static void kbread_timer_callback(struct timer_list *t)
{
    char key = kb_read();
    if(key == 0) // buffer vacio
    {
      buffer[0] = '\0';
      char_count = 0; 
    } 
    if(key == '*') 
    // reiniciar buffer 
    {
      buffer[0] = '\0';
      char_count = 0;
    }
    else { 
      buffer[char_count] = key; 
      char_count++; 
    } 
    mod_timer(&kbread_timer, jiffies + msecs_to_jiffies(20));
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


    gpio2_base = ioremap(GPIO2_REGISTER, GPIO2_SIZE); 
    if(gpio2_base == NULL)
    {
      iounmap(cm_base);
      iounmap(cm_per_base);
      return -1;
    }  

    // Verificar estado de reset
    if(ioread32(gpio2_base + GPIO_SYSSTATUS)) printk("Reset realizado\n"); 
    else printk("Reset no realizado\n"); 

    // Configurar E/S
    u32 oe_register = ioread32(gpio2_base + GPIO_OE); 
    oe_register &= ~OE_CONFIG_OUTPUT; 
    oe_register |= OE_CONFIG_INPUT; 
    printk(KERN_INFO "GPIO_OE = 0x%08x\n", oe_register);

    iowrite32(oe_register, gpio2_base + GPIO_OE); 

    // Activar debounce 
    iowrite32(DEBOUNCE_ENABLE, gpio2_base + GPIO_DEBOUNCENABLE); 

    // Tiempo de debounce 
    iowrite32(DEBOUNCE_TIME, gpio2_base + GPIO_DEBOUNCINGTIME); 

    // Activar IRQ en las entradas 
    iowrite32(IRQ_ENABLE, gpio2_base + GPIO_IRQSTATUS_SET_0); 

    // Limpiar interrupciones por las dudas 
    iowrite32(CLEAR_IRQ, gpio2_base + GPIO_IRQSTATUS_CLR_0);

    // Desactivar high level y activar low level (se hace solo x reset)
    iowrite32(LOW_LEVEL_DETECT, gpio2_base + GPIO_LEVELDETECT0); 

    // Falling edge detect 
    iowrite32(FALLING_DETECT, gpio2_base + GPIO_FALLINGDETECT); 

    iowrite32(1 << 3, gpio2_base + GPIO_SETDATAOUT); 
    printk(KERN_INFO "LED rojo encendido\n");
    ioread32(gpio2_base + GPIO_DATAOUT); 
    printk(KERN_INFO "cmconfig RLED = 0x%08x\n", cmconfig);


    msleep(10000);

    iowrite32(1 << 3, gpio2_base + GPIO_CLEARDATAOUT); 
    printk(KERN_INFO "LED rojo apagado\n");

    timer_setup(&kbread_timer, kbread_timer_callback, 0); 
    mod_timer(&kbread_timer, jiffies + msecs_to_jiffies(20)); 

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
  iounmap(cm_base); 
  iounmap(cm_per_base);
  iounmap(gpio2_base); 
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
    printk(KERN_INFO "td3driver: read()\n");
    return 0; 
}

static ssize_t td3driver_write(struct file *filp, const char __user *buf,
                               size_t count, loff_t *f_pos)
{



    // TODO: switch case para buzzer, long buzzer, red led, green led and orange led 


    printk(KERN_INFO "td3driver: write()\n");
    return count; 
}


module_init(td3driver_init); // Rutinas a ejecutarse dentro para instalar
module_exit(td3driver_exit);

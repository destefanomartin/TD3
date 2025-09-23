// Hecho por Dario Alpern

// Escribir un caracter al device driver.
// Luego en las siguientes lecturas el device driver
// genera caracteres con codigo ASCII creciente.

// Adicionalmente el driver genera el nodo /dev/letras
// durante la instalacion (insmod) con permisos 0666 sin
// necesidad del comando mknod ni chmod. El nodo se borra
// automaticamente al desinstalar (rmmod) el device driver.

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/platform_device.h>
#include <linux/gpio.h>
#include <linux/fs.h>
#include <linux/errno.h>
#include <asm/uaccess.h>
#include <linux/version.h>
#include <linux/types.h>
#include <linux/kdev_t.h>
#include <linux/device.h>
#include <linux/cdev.h>
#include <linux/sched.h>

MODULE_LICENSE("Dual BSD/GPL"); // Requerido
MODULE_AUTHOR("Dario Alpern");
MODULE_DESCRIPTION("Escribir un caracter al device driver. Luego en las siguientes lecturas el device driver genera caracteres con codigo ASCII creciente");

static dev_t dev; // Todo estatico para que no se meta dentro del Kernel
static struct class *cl; 
static char siguienteLetra;
static wait_queue_head_t letras_waitqueue;
static ssize_t letras_read(struct file *file, char *buf,
	                size_t count, loff_t *nose) // NO SE PUEDE TOCAR BUF DIRECTAMENTE (viene de user)
{
  char buffer[500];
  int i;
  int bytesNoCopiados;
  int totalcount = count;                       // Si la cantidad de bytes a leer
  if (totalcount > sizeof(buffer))              // es muy elevada, truncar a la
  {                                             // longitud del buffer interno.
    totalcount = sizeof(buffer);
  }
  while (siguienteLetra == 'a')                 // Esperar hasta que otro proceso
  {					      // cambie la siguiente letra.
    if (wait_event_interruptible(letras_waitqueue, (siguienteLetra != 'a')))
    {
      return -ERESTARTSYS;                     // Vino una señal.
    }
  }
  for (i=0; i<totalcount; i++)	               // Por cada caracter pedido desde la
  {					      // aplicacion
    *(buffer+i) = siguienteLetra;              // Generar carácter.
    if (++siguienteLetra > 'Z')                // Cambiar a la siguiente letra.
    {
      siguienteLetra = 'A';
    }
  }
  bytesNoCopiados = __copy_to_user(buf, buffer, totalcount);    // Copiar al buffer de la aplicacion.
  return totalcount - bytesNoCopiados;                          // Indicar cantidad de bytes leidos.
}
	
static ssize_t letras_write(struct file *file, const char *buf,
	                    size_t count, loff_t *nose)
{
  char letraAnterior = siguienteLetra;
          // Obtener carácter de la aplicacion.
  int bytesNoCopiados = __copy_from_user(&siguienteLetra, buf, 1);
  if (letraAnterior == 'a' && siguienteLetra != 'a')
  {
    wake_up_interruptible(&letras_waitqueue); // Despertar proceso que lee.
  }
  return count;                               // Indicar cantidad de bytes escritos.
}

struct file_operations letras_fops =
{
  read: letras_read,
  write: letras_write      
};
static struct cdev letras_cdev;

static int my_dev_uevent(const struct device *dev, struct kobj_uevent_env *env)
{
  add_uevent_var(env, "DEVMODE=%#o", 0666);
  return 0;
}

static int letras_init( void )
{
  MODULE_LICENSE("GPL");
  if (alloc_chrdev_region( &dev, 0, 1, "letras" ) < 0)
  {  
    printk( KERN_ALERT "No se puede ubicar la region\n" );
    return -1;
  }
  cl = class_create("chardev" );
  if ( cl == NULL )
  {
    printk( KERN_ALERT "No se puede crear la clase\n" );
    // Borrar lo asignado para no tener memory leak en kernel
    unregister_chrdev_region( dev, 1 ); // IMPORTANTE!
    return -1;
  }
  // Asignar el callback que pone los permisos en /dev/letras
  cl -> dev_uevent = my_dev_uevent;
  if( device_create( cl, NULL, dev, NULL, "letras" ) == NULL )
  {
    printk( KERN_ALERT "No se puede crear el device driver\n" );
    // Borrar lo asignado para no tener memory leak en kernel
    class_destroy(cl);
    unregister_chrdev_region( dev, 1 );
    return -1;
  }
  cdev_init(&letras_cdev, &letras_fops); // Letras fops apunta a las operaciones read, write, etc.
  letras_cdev.owner = THIS_MODULE;
  letras_cdev.ops = &letras_fops;
  if (cdev_add(&letras_cdev, dev, 1) == -1)
  {
    printk( KERN_ALERT "No se pudo agregar el device driver al kernel\n" );
    // Borrar lo asignado para no tener memory leak en kernel
    device_destroy( cl, dev );
    class_destroy( cl );
    unregister_chrdev_region( dev, 1 );
    return -1;
  }
  siguienteLetra = 'A';
  init_waitqueue_head(&letras_waitqueue);
  printk(KERN_ALERT "Driver LETRAS instalado con numero mayor %d y numero menor %d\n",
	 MAJOR(dev), MINOR(dev));
  return 0;
}

static void letras_exit( void )
{
    // Borrar lo asignado para no tener memory leak en kernel
  cdev_del(&letras_cdev);
  device_destroy( cl, dev );
  class_destroy( cl );
  unregister_chrdev_region(dev, 1);
  printk(KERN_ALERT "Driver LETRAS desinstalado.\n");
}

module_init(letras_init); // Rutinas a ejecutarse dentro para instalar
module_exit(letras_exit);

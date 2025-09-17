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
MODULE_AUTHOR("Martin Destefano");
MODULE_DESCRIPTION("");

static int td3driver_init( void )
{
  MODULE_LICENSE("GPL");
  if (alloc_chrdev_region( &dev, 0, 1, "td3driver" ) < 0)
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
  if( device_create( cl, NULL, dev, NULL, "td3driver" ) == NULL )
  {
    printk( KERN_ALERT "No se puede crear el device driver\n" );
    // Borrar lo asignado para no tener memory leak en kernel
    class_destroy(cl);
    unregister_chrdev_region( dev, 1 );
    return -1;
  }
  cdev_init(&td3driver_cdev, &td3driver_fops); // Letras fops apunta a las operaciones read, write, etc.
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
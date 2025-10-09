#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <errno.h>
#include <signal.h>
#include <time.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <semaphore.h>
#include <fcntl.h>
#include <sys/wait.h>


#define MAX_CONN 1 //Nro maximo de conexiones en espera
#define SEM_NAME "/shared_sem"
#define SHM_KEY 0x1234
#define MAX_CODES 100
#define MAX_LOGS 100
static int created_shm;
static int created_sem;


struct arguments {
    unsigned char command;
    unsigned char millis;
};

// Enum para usar los mismos valores que el driver
enum {
    CMD_FORBIDDEN = 0,
    CMD_BEEP = 1,
    CMD_GREEN_LED,
    CMD_RED_LED,
    CMD_ORANGE_LED
};


typedef struct {
    char code[5];  
} CodeEntry;

typedef struct {
    char datetime[20]; // "YYYY-MM-DD HH:MM:SS"
    char code[5];
    int valid; // 1 válido, 0 inválido
} LogEntry;

typedef struct {
    int num_codes;
    int num_logs;
    CodeEntry codes[MAX_CODES];
    LogEntry logs[MAX_LOGS];
} SharedData;


void Remote_Access_Control ();
int check_code(const char *code, SharedData *shared, sem_t *sem);
void build_page(char *html, SharedData *shared, sem_t *sem);
void register_log(const char *code,int result);
void cleanup();
void cleanup_and_kill_all(void);
void sigint_handler(int sig);
void ProcesarCliente(int fd_cliente, struct sockaddr_in *pDireccionCliente,
                     int puerto);

SharedData *shared = NULL;
sem_t *sem = NULL;
int shmid = -1;

volatile int child_count = 0; 


void sigchld_handler (int sig) {
    int status;
    pid_t pid;
    // reap all dead children
    while ((pid = waitpid(-1, &status, WNOHANG)) > 0) {
        if (child_count > 0) child_count--;
        // opcional: logear pid y estado
        // printf("Child %d terminated\n", pid);
}
}







int main(int argc, char *argv[])
{
    int fd_server, pid_kb;
    struct sockaddr_in datosServidor;
    socklen_t longDirec;
    struct sigaction sa;
    sa.sa_handler = sigchld_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_RESTART;
    sigaction(SIGCHLD, &sa, NULL);


    shmid = shmget(SHM_KEY, sizeof(SharedData), IPC_CREAT | IPC_EXCL | 0660);
    if (shmid < 0) {
        if (errno == EEXIST) {
            shmid = shmget(SHM_KEY, sizeof(SharedData), 0660);
            if (shmid < 0) { perror("shmget existing"); exit(1); }
        } else {
            perror("Error creando memoria compartida");
            exit(1);
        }
    } else {
        created_shm = 1;
    }

    shared = (SharedData *)shmat(shmid, NULL, 0);
    if (shared == (void *)-1) {
        perror("Error mapeando memoria compartida");
        exit(1);
    }

    /* Limpiar siempre */
    memset(shared, 0, sizeof(SharedData));

    /* ----- Inicializar semáforo y detectar si fue creado ----- */
    sem = sem_open(SEM_NAME, O_CREAT | O_EXCL, 0666, 1);
    if (sem == SEM_FAILED) {
        if (errno == EEXIST) {
            sem = sem_open(SEM_NAME, 0);
            if (sem == SEM_FAILED) { perror("sem_open existing"); exit(1); }
        } else {
            perror("sem_open");
            exit(1);
        }
    } else {
        created_sem = 1;
    }



    fd_server = socket(AF_INET, SOCK_STREAM,0);
    if (fd_server == -1)
    {
        printf("ERROR: El socket no se ha creado correctamente!\n");
        exit(1);
    }


    // Asigna el puerto indicado y una IP de la maquina
    datosServidor.sin_family = AF_INET;
    datosServidor.sin_port = htons(8080);
    datosServidor.sin_addr.s_addr = htonl(INADDR_ANY);    

    // Obtiene el puerto para este proceso.
    if( bind(fd_server, (struct sockaddr*)&datosServidor,
            sizeof(datosServidor)) == -1)
    {
        printf("ERROR: este proceso no puede tomar el puerto %s\n",
            argv[1]);
        exit(1);
    }

      if (listen(fd_server, MAX_CONN) < 0)
    {
        perror("Error en listen");
        close(fd_server);
        exit(1);
    }
    if (setpgid(0, 0) != 0) {
    perror("setpgid");
    // no fatal, pero conviene continuar
    }
    pid_kb = fork(); 
    if(pid_kb < 0)
    {
        perror("No se puede crear un nuevo proceso \n"); 
        exit(1); 
    }
    if(pid_kb == 0)
    {
        Remote_Access_Control(); 
        exit(0); 
    }

    signal(SIGCHLD, sigchld_handler);
    signal(SIGINT, sigint_handler);
    // Permite atender a multiples usuarios
    while (1)
    {
        int pid, fd_cliente;
        struct sockaddr_in datosCliente;
        longDirec = sizeof(datosCliente);

        if(child_count >= 0) { // Limit connection to 1 client once
            fd_cliente = accept(fd_server, (struct sockaddr*) &datosCliente, &longDirec);
            if (fd_cliente < 0)
            {
                perror("Accept error"); // Checks error on accept
                close(fd_cliente); 
                exit(1); 
            }
        }
        pid = fork();
        if (pid < 0)
        {
        perror("No se puede crear un nuevo proceso mediante fork");
        close(fd_cliente);
        exit(1);
        }
        if (pid == 0)
        {       // Proceso hijo.

        ProcesarCliente(fd_cliente, &datosCliente, 8080);
        exit(0);
        }
        child_count++;   // padre incrementa
        close(fd_cliente);


    }
        cleanup(); // Si llega al final normalmente
        return 0;
}



void ProcesarCliente(int fd_cliente, struct sockaddr_in *pDireccionCliente, int puerto)
{
    char bufferComunic[4096];
    char ipAddr[20];
    int Port;
    int indiceEntrada;
    char HTML[4096];

    int n = read(fd_cliente, bufferComunic, sizeof(bufferComunic)-1);
    if (n <= 0) {
        close(fd_cliente);
        return;
    }
    bufferComunic[n] = '\0'; // asegurar string

    if (strncmp(bufferComunic, "GET", 3) == 0) {
        char html[16384];
        build_page(html, shared, sem);

        char header[512];
        sprintf(header,
            "HTTP/1.1 200 OK\r\n"
            "Content-Type: text/html; charset=UTF-8\r\n"
            "Cache-Control: no-store, no-cache, must-revalidate\r\n"
            "Pragma: no-cache\r\n"
            "Expires: 0\r\n"
            "Content-Length: %zu\r\n"
            "Connection: close\r\n\r\n",
            strlen(html));

        write(fd_cliente, header, strlen(header));
        write(fd_cliente, html, strlen(html));
        close(fd_cliente);
    }

else if (strncmp(bufferComunic, "POST", 4) == 0) {
    // Parse Content-Length
    char *cl = strcasestr(bufferComunic, "Content-Length:");
    int content_length = 0;
    if (cl) sscanf(cl, "Content-Length: %d", &content_length);

    // Obtener cuerpo
    char *body = strstr(bufferComunic, "\r\n\r\n");
    if (!body) { close(fd_cliente); return; }
    body += 4;

    int body_len = strlen(body);
    while (body_len < content_length) {
        int r = read(fd_cliente, body + body_len, content_length - body_len);
        if (r <= 0) break;
        body_len += r;
    }
    body[body_len] = '\0';

    char codigo[5] = {0};
    sscanf(body, "codigo=%4s", codigo); // <= 4 chars
    if (strstr(bufferComunic, "POST /agregar") != NULL) {
        sem_wait(sem);
        if (shared->num_codes < MAX_CODES) {
            strcpy(shared->codes[shared->num_codes].code, codigo);
            shared->num_codes++;
            // fd_driver = open("/dev/td3driver", O_RDWR);
            // if(fd_driver < 0)
            // {   
            //     perror("No se pudo abrir el driver\n"); 
            //     exit(1); 
            // }
            // arg_sv.command = CMD_ORANGE_LED;
            // arg_sv.millis = 100; // 200 ms
            // write(fd_driver, &arg_sv, sizeof(arg_sv));

            // arg_sv.command = CMD_BEEP; 
            // arg_sv.millis = 20; // 200 ms
            // write(fd_driver, &arg_sv, sizeof(arg_sv));
        }
        sem_post(sem);
    }
    else if (strstr(bufferComunic, "POST /eliminar") != NULL) {
        sem_wait(sem);
        for (int i = 0; i < shared->num_codes; i++) {
            if (strcmp(shared->codes[i].code, codigo) == 0) {
                for (int j = i; j < shared->num_codes - 1; j++)
                    shared->codes[j] = shared->codes[j + 1];
                shared->num_codes--;
                break;
            }
        }
        sem_post(sem);
    }

    char html[16384];
    build_page(html, shared, sem);

    char header[256];
    sprintf(header,
        "HTTP/1.1 200 OK\r\n"
        "Content-Type: text/html; charset=UTF-8\r\n"
        "Cache-Control: no-store, no-cache, must-revalidate\r\n"
        "Pragma: no-cache\r\n"
        "Expires: 0\r\n"
        "Content-Length: %zu\r\n"
        "Connection: close\r\n\r\n",
        strlen(html));

    write(fd_cliente, header, strlen(header));
    write(fd_cliente, html, strlen(html));

    
    close(fd_cliente);

}

}


void Remote_Access_Control ()
{
    int fd_driver; 
    char code[5] = {0}; 
    struct arguments args; 

    fd_driver = open("/dev/td3driver", O_RDWR); 
    if(fd_driver < 0)
    {   
        perror("No se pudo abrir el driver\n"); 
        exit(1); 
    }
    while(1){
        int n = read(fd_driver, code, 5);
        if (n < 0) {
            perror("Error leyendo del driver");
            code[4] = '\0';
            continue;
        } else if (n != 5) {
            fprintf(stderr, "Leí %d bytes, se esperaban 5\n", n);
            code[4] = '\0';
            continue;
        }
        code[4] = '\0';


        printf("Codigo recibido: %s\n", code);

        if (check_code(code, shared, sem))        
        {
            printf("codigo ingreso valido\n");  // boton verde
            register_log(code, 1);
            args.command = CMD_GREEN_LED;
            args.millis = 100; // 200 ms
            write(fd_driver, &args, sizeof(args));

            args.command = CMD_BEEP;
            args.millis = 10; // 100 ms
            write(fd_driver, &args, sizeof(args));
        } 
        else 
        {
            printf("codigo ingreso invalido\n"); // boton rojo
            register_log(code, 0);
            args.command = CMD_RED_LED;
            args.millis = 100; // 200 ms
            write(fd_driver, &args, sizeof(args));

            args.command = CMD_BEEP;
            args.millis = 10; // 100 ms
            write(fd_driver, &args, sizeof(args));
        }
    }
    close(fd_driver);

}

void register_log(const char *code, int result) {
    sem_wait(sem);

    if (shared->num_logs < MAX_LOGS) {
        time_t now = time(NULL);
        struct tm *tm_info = localtime(&now);
        printf("Registrando log: '%s', resultado=%d\n", code, result);
        strftime(shared->logs[shared->num_logs].datetime, sizeof(shared->logs[0].datetime), "%Y-%m-%d %H:%M:%S", tm_info);
        // Copiar los primeros 5 caracteres y asegurar '\0'
        strncpy(shared->logs[shared->num_logs].code, code, 5);
        shared->logs[shared->num_logs].code[4] = '\0';

        shared->logs[shared->num_logs].valid = result;
        shared->num_logs++;
    }

    sem_post(sem);
}

int check_code(const char *code, SharedData *shared, sem_t *sem) {
    int found = 0;
    sem_wait(sem);
    for (int i = 0; i < shared->num_codes; i++) {
        // Comparar siempre los primeros 4 caracteres
        if (strncmp(shared->codes[i].code, code, 4) == 0) {
            printf("Código encontrado: %s\n", code);
            found = 1;
            break;
        }
    }
    sem_post(sem);
    return found;
}




void build_page(char *html, SharedData *shared, sem_t *sem) {
    FILE *tpl = fopen("index.html", "r");
    if (!tpl) {
        strcpy(html, "<h1>Error: no se encuentra index.html</h1>");
        return;
    }

    char line[1024];
    html[0] = '\0';

    sem_wait(sem);
    while (fgets(line, sizeof(line), tpl)) {
        if (strstr(line, "<!--CODES-->")) {
            for (int i = 0; i < shared->num_codes; i++) {
                char row[64];
                sprintf(row, "<tr><td>%s</td></tr>\n", shared->codes[i].code);
                strcat(html, row);
            }
        } else if (strstr(line, "<!--LOG-->")) {
            for (int i = 0; i < shared->num_logs; i++) {
                char row[128];
                sprintf(row,
                    "<tr><td>%s</td><td>%s</td><td>%s</td></tr>\n",
                    shared->logs[i].datetime,
                    shared->logs[i].code,
                    shared->logs[i].valid ? "Válido" : "Inválido");
                strcat(html, row);
            }
        } else {
            strcat(html, line);
        }
    }
    sem_post(sem);
    fclose(tpl);
}

void cleanup() {
    if (shared != NULL) {
        shmdt(shared);
        shared = NULL;
    }
    if (shmid > 0 && created_shm) {
        shmctl(shmid, IPC_RMID, NULL);
        shmid = -1;
    }
    if (sem != NULL) {
        sem_close(sem);
        sem = NULL;
    }
    if (created_sem) {
        sem_unlink(SEM_NAME);
    }
    printf("Recursos liberados correctamente.\n");
}

void sigint_handler(int sig) {
    printf("\nCerrando servidor (SIGINT/SIGTERM)...\n");
    cleanup_and_kill_all();
    // After kill, exit
    _exit(0);
}

void cleanup_and_kill_all(void) {
    pid_t pgid = getpgrp(); // PGID del grupo del proceso actual
    // enviar SIGTERM a todo el grupo de procesos (incluye a este proceso)
    if (killpg(pgid, SIGTERM) == -1) {
        perror("killpg");
    }
    // esperar un momento que los procesos terminen (opcional)
    sleep(1);

    // limpieza de recursos compartidos y semáforo
    if (shared != NULL) {
        shmdt(shared);
        shared = NULL;
    }
    if (shmid > 0 && created_shm) {
        shmctl(shmid, IPC_RMID, NULL);
        shmid = -1;
    }

    if (sem != NULL) {
        sem_close(sem);
        sem = NULL;
    }
    if (created_sem) {
        sem_unlink(SEM_NAME);
    }

    printf("Recursos liberados.\n");
}
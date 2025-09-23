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

#define MAX_CONN 1 //Nro maximo de conexiones en espera

volatile int child_count = 0; 
void sigchld_handler (int sig) {
    int status; 
    pid_t pid_handler = waitpid(-1, &status, WNOHANG); 
    if(pid_handler > 0){
        child_count = 0; 
    }
}
void ProcesarCliente(int fd_cliente, struct sockaddr_in *pDireccionCliente,
                     int puerto);





int main(int argc, char *argv[])
{
    int fd_server, pid_kb;
    struct sockaddr_in datosServidor;
    socklen_t longDirec;


    // if (argc != 2)
    // {
    //     printf("\n\nLinea de comandos: webserver Puerto\n\n");
    //     exit(1);
    // }
    // Creamos el socket
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

    // Permite atender a multiples usuarios
    while (1)
    {
        int pid, fd_cliente;
        struct sockaddr_in datosCliente;
        longDirec = sizeof(datosCliente);

        if(child_count == 0) { // Limit connection to 1 client once
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
        child_count++; 
        ProcesarCliente(fd_cliente, &datosCliente, 8080);
        exit(0);
        }
        close(fd_cliente);  // El proceso padre debe cerrar el socket
                    // que usa el hijo.
    }
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

    if (strncmp(bufferComunic, "GET", 3) == 0) { // Metodo para cuando se solicita la pagina 
    // Es un GET
    printf("Se recibió GET\n");
    strcpy(ipAddr, inet_ntoa(pDireccionCliente->sin_addr));
    Port = ntohs(pDireccionCliente->sin_port);

    // Generar página HTML completa
    char html[16384];
    build_page(html);

    // Enviar respuesta HTTP
    char header[256];
    sprintf(header,
            "HTTP/1.1 200 OK\r\n"
            "Content-Type: text/html; charset=UTF-8\r\n"
            "Content-Length: %zu\r\n"
            "Connection: close\r\n\r\n",
            strlen(html));

    write(fd_cliente, header, strlen(header));
    write(fd_cliente, html, strlen(html));
    sleep(10);
  // Cierra la conexion con el cliente actual
    close(fd_cliente);    
}
else if (strncmp(bufferComunic, "POST", 4) == 0) {
    char *cl = strcasestr(bufferComunic, "Content-Length:");
    int content_length = 0;
    if (cl) sscanf(cl, "Content-Length: %d", &content_length);

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

    char codigo[32] = {0};
    sscanf(body, "codigo=%31s", codigo);

    if (strstr(bufferComunic, "POST /agregar") != NULL) {
        FILE *fa = fopen("allowed.txt", "a");
        if (fa) {
            fprintf(fa, "%s\n", codigo);
            fclose(fa);
        }
        printf("Agregado: %s\n", codigo);
    }
    else if (strstr(bufferComunic, "POST /eliminar") != NULL) {
        char line[64];
        FILE *fa = fopen("allowed.txt", "r");
        FILE *tmp = fopen("allowed.tmp", "w");
        if (fa && tmp) {
            while (fgets(line, sizeof(line), fa)) {
                line[strcspn(line, "\n")] = 0;
                if (strcmp(line, codigo) != 0) {
                    fprintf(tmp, "%s\n", line);
                }
            }
        }
        if (fa) fclose(fa);
        if (tmp) fclose(tmp);
        if (remove("allowed.txt") != 0) perror("remove");
        if (rename("allowed.tmp", "allowed.txt") != 0) perror("rename");
        printf("Eliminado: %s\n", codigo);
    }

    char html[16384];
    build_page(html);

    char header[256];
    sprintf(header,
            "HTTP/1.1 200 OK\r\n"
            "Content-Type: text/html; charset=UTF-8\r\n"
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
    char code[4] = "5555"; 
    while(1){
        if(check_code(code))
        {
            printf("codigo ingreso valido\n");  // boton verde
            register_log(code, 1);
        } 
        else 
        {
            printf("codigo invalido\n"); 
            register_log(code, 0); 
        }
    }
    exit(0);

}

void register_log(int code,int result) // funciones q me sirven despues 
{
    FILE *access_file; 
    if(access_file= fopen("access.log", "a")==1)
    {
        time_t now = time(NULL); 
        struct tm *tm_info = localtime(&now);
        char timebuf[64]; 
        strftime(timebuf, sizeof(timebuf), "%Y-%m-%d %H:%M:%S", tm_info);
        
        fprintf(access_file, "[%s] Codigo %s -> %s\n",
            timebuf, code, result ? "VALIDO" : "INVALIDO");
        fclose(access_file);  
        return 0;  
    }
    else return 1; 
    
}

int check_code(const char* code) // funciones q me sirven despues 
{
    FILE *allowed_file = fopen("allowed.txt", "r"); 
    if(!allowed_file) return 0; 
    char line[64];
    while (fgets(line, sizeof(line), allowed_file)) {
        line[strcspn(line, "\n")] = 0;
        if (strcmp(line, code) == 0) {
            fclose(allowed_file);
            return 1;
        }
    }
    fclose(allowed_file);
    return 0;
}


void build_page(char *html){
        FILE *tpl = fopen("index.html", "r");
    if (!tpl) {
        strcpy(html, "<h1>Error: no se encuentra index.html</h1>");
        return;
    }

    char line[1024];
    html[0] = '\0';
    int id = 1;

    while (fgets(line, sizeof(line), tpl)) {
        if (strstr(line, "<!--CODES-->")) {
            FILE *fa = fopen("allowed.txt", "r");
            if (fa) {
                char code[16];
                while (fgets(code, sizeof(code), fa)) {
                    code[strcspn(code, "\n")] = 0; // sacar \n
                    char row[64];
                    sprintf(row, "<tr><td>%d</td><td>%s</td></tr>\n", id++, code);
                    strcat(html, row);
                }
                fclose(fa);
            }
        } else if (strstr(line, "<!--LOG-->")) {
            FILE *fl = fopen("access.log", "r");
            if (fl) {
                char entry[128];
                while (fgets(entry, sizeof(entry), fl)) {
                    strcat(html, entry);
                }
                fclose(fl);
            }
        } else {
            strcat(html, line);
        }
    }
    fclose(tpl);
}
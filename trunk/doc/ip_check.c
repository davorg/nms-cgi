#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <stdio.h>

main(int argc, char **argv)
{
   struct in_addr foo;
   

   inet_aton(argv[1],&foo);
   if ( strcmp(argv[1],inet_ntoa(foo)))
      printf("%s\n",inet_ntoa(foo));
   else
      printf("OK\n");
}

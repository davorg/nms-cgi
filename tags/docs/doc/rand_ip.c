#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <stdio.h>

main(int argc, char **argv)
{
   struct in_addr foo;
   
   int i;
       srand(time());

   for(i = 0; i < 20; i++)
     {
       foo.s_addr = rand();
       printf("%s\n",inet_ntoa(foo));
     }
}

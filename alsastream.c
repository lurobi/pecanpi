#include <stdio.h>
#include <stdlib.h>

#include <zmq.h>

#include "alsa_pcm_simple.h"

int main()
{
  void *hpcm;
  int fs,nbuf;
  short *buf;
  
  fs = 8000;
  nbuf = fs/4;
  buf = malloc(sizeof(short)*nbuf);

  create_recorder(fs,"hw:2,0",&hpcm);

  void *context = zmq_ctx_new ();
  void *publisher = zmq_socket (context, ZMQ_PUB);
  zmq_bind (publisher, "tcp://0.0.0.0:5563");

  printf("Sending data... Ctrl-C to quit\n");
  for (int nloop=0; 1 ;nloop++)
    {
      printf("."); fflush(stdout);
      if(nloop % 40 == 0) printf("\n");
      get_sample_buffer(&hpcm,buf,nbuf);
      for (int j=0;j<nbuf;j++) {
	buf[j] = rand()%10;
      }
      //printf("[%d] Buf: %d %d %d %d\n",nloop,buf[0],buf[1],buf[2],buf[3]);
      zmq_send(publisher,"audio",5,ZMQ_SNDMORE);
      zmq_send(publisher,buf,nbuf*sizeof(short),0);
      //sleep(1);

    }
  //close_device(&hpcm);
  printf("Finished\n");
}

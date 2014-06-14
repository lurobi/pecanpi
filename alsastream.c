#include <stdio.h>
#include <stdlib.h>

#include <zmq.h>

int main()
{
  void *hpcm;
  int fs,nbuf;
  short *buf;
  
  fs = 8000;
  nbuf = fs/4;
  buf = malloc(sizeof(short)*nbuf);

  //create_recorder(fs,"hw:1,0",&hpcm);

  void *context = zmq_ctx_new ();
  void *publisher = zmq_socket (context, ZMQ_PUB);
  zmq_bind (publisher, "tcp://192.168.0.10:5563");

  for (int nloop=0;nloop<10;nloop++)
    {
      //get_sample_buffer(&hpcm,&buf,nbuf);
      for (int j=0;j<nbuf;j++) {
	buf[j] = j + rand()%10;
      }
      zmq_send(publisher,"audio",5,ZMQ_SNDMORE);
      zmq_send(publisher,buf,nbuf*sizeof(short),0);
      printf("Sent some data\n");
      sleep(1);

    }
  //close_device(&hpcm);
  printf("Finished\n");
}

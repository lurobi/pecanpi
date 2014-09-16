#include <stdio.h>
#include <stdlib.h>

#include <zmq.h>

#if ZMQ_VERSION_MAJOR < 3
#error "zmq version 3.2 required"
#else
#if ZMQ_VERSION_MINOR<2
#error "zmq version 3.2 required"
#endif
#endif

#include "alsa_pcm_simple.h"

int main(int argc,char* argv[])
{
  void *hpcm;
  const char* audio_dev_str;
  int fs,nbuf;
  short *buf;
  int ii_random;
  
  fs = 8000;
  nbuf = fs/4;
  if( argc <= 1 ) {
    printf("Usage: alsastream <hwX:X>|rand\n");
    printf("\n");
    printf("Use alsa device <hwX:X> (see \"arecord -l\" for a list)\n");
    printf("or if \"rand\" is supplied, generate random numbers.\n");
    exit(1);
  }

  if( strcmp(argv[1],"rand") == 0 ) {
    printf("Generating random data.\n");
    ii_random=1;
  }
  else { 
    ii_random=0;
    audio_dev_str = argv[1];
  }

  buf = malloc(sizeof(short)*nbuf);

  if ( ! ii_random ) {
      create_recorder(fs,audio_dev_str,&hpcm);
  }

  //void *context = zmq_ctx_new ();
  void *context = zmq_init(2);
  void *publisher = zmq_socket(context, ZMQ_PUB);
  zmq_bind (publisher, "tcp://0.0.0.0:5563");

  printf("Sending data... Ctrl-C to quit\n");
  for (int nloop=0; 1 ;nloop++) {
    printf("."); fflush(stdout);
    if(nloop % 40 == 0) printf("\n");

    if( ii_random ) {
      for (int j=0;j<nbuf;j++) {
	buf[j] = rand()%10;
      }
    }
    else {
      get_sample_buffer(&hpcm,buf,nbuf);
    }
    //printf("[%d] Buf: %d %d %d %d\n",nloop,buf[0],buf[1],buf[2],buf[3]);
    zmq_send(publisher,"audio",5,ZMQ_SNDMORE);
    zmq_send(publisher,buf,nbuf*sizeof(short),0);
    if (ii_random) { sleep(1); }

  }
  //close_device(&hpcm);
  printf("Finished\n");
}

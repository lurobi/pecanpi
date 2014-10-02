#include <math.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <zmq.h>

#include "alsa_pcm_simple.h"

typedef struct {
    float fs;
    float freq;
    short *buf;
    int nbuf;
    int ipport;
    char ipaddr[24];
} sysStruct;

/******************************************************************************
 *  Function:    getmem
 *  Descript:    calloc memory and check for errors
 ******************************************************************************/
void *getmem(int size,char *errmsg)
{
    void *m=NULL;

    m = (void *)calloc(size,1);
    if(m==NULL){
        fprintf(stderr,"%s",errmsg);
        exit(1);
    }
    return(m);
}

/******************************************************************************
 *  Function:    usage
 ******************************************************************************/
int usage()
{
    printf("Usage: alsastream [options]\n");
    printf("       -freq <freqHz>\n");
    exit(0);
}
/******************************************************************************
 *  Function:    main
 *  Descript:    mainline return
 ******************************************************************************/
int main(int argc, char *argv[])
{
  void *hpcm;
  sysStruct *sys=NULL;
  int dorandom=0;
  int ix=0;
  int a=1;
  float pi=3.141592653589793;

  sys=(sysStruct *)getmem(sizeof(sysStruct),"No memory for sysStruct\n");

  // Defaults
  sys->fs=8000;
  sys->freq=347.1;
  sys->nbuf=sys->fs/4;
  sys->buf = (short *)getmem(sizeof(short)*sys->nbuf,"No memory for buffer\n");

  // Parse args
  while(a<argc) {   /* Process command line arguments */
      if(argv[a][0] != '-') {  
          usage();
      }
      else 
      {
          switch(argv[a++][1]) {   /* Auto increment to parameters if any */
              case 'f':
                  if(strncmp(argv[a-1],"-freq",5)==0) {
                      if(argc>a) sys->freq = atof(argv[a++]);
                  }
                  break;
              default:
                      usage();
          }
      }
  }

  printf("Setting freq to %.1f Hz\n",sys->freq);
  //create_recorder(fs,"hw:2,0",&hpcm);
  create_recorder(sys->fs,"default",&hpcm);

  void *context = zmq_ctx_new ();
  void *publisher = zmq_socket (context, ZMQ_PUB);
  zmq_bind (publisher, "tcp://0.0.0.0:5563");

  printf("Sending data... Ctrl-C to quit\n");
  for (unsigned int nloop=0; 1 ;nloop++)
    {
      printf("."); fflush(stdout);
      if(nloop % 40 == 0) printf("\n");
      get_sample_buffer(&hpcm,sys->buf,sys->nbuf);
      if (dorandom) {
          for (int j=0;j<sys->nbuf;j++) {
              sys->buf[j] = rand()%1000;
          }
      }
      else {
          for (int j=0;j<sys->nbuf;j++) {
              sys->buf[j]=16384*cos(2*pi*sys->freq*ix/sys->fs);
              ix+=1;
          }
      }
      //printf("[%d] Buf: %d %d %d %d\n",nloop,buf[0],buf[1],buf[2],buf[3]);
      zmq_send(publisher,"audio",5,ZMQ_SNDMORE);
      zmq_send(publisher,&nloop,sizeof(nloop),ZMQ_SNDMORE);
      zmq_send(publisher,sys->buf,sys->nbuf*sizeof(short),0);
      //sleep(1);

    }
  //close_device(&hpcm);
  printf("Finished\n");
}

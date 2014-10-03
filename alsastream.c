/******************************************************************************
 *  @file:       alsastream.c
 *  @brief:      Provide a zmq source for audio data
 *  @author:     Luke Robison
 *  
 *  Vers 1.0.2 - rwr - 3 Oct 2014
 *      Added more cmdline args, restructure a bit
 *  Vers  1.0.1 - lar - 15 Sep 2014
 *      Added basic cmdline args
 *  Vers  1.0.0 - lar - 7 Sep 2014
 ******************************************************************************/
#include <math.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <zmq.h>
// Check for zmq > 3.2 because.... ?
#if ZMQ_VERSION_MAJOR < 3
#error "zmq version 3.2 required"
#else
#if ZMQ_VERSION_MAJOR==3
#if ZMQ_VERSION_MINOR<2
#error "zmq version 3.2 required"
#endif
#endif
#endif

#include "alsa_pcm_simple.h"

/**************************************************************************************/
#define MAX_ALSA_NAME 32
#define PROG_VERSION "1.0.2"

typedef enum {eAlsa,eSinusoid,eRandom} enumModes;
typedef struct {
    enumModes mode;
    float fs;
    float freq;
    short *buf;
    int nbuf;
    int ipport;
    char ipaddr[24];
    char alsadev[MAX_ALSA_NAME+1];
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
    printf("alsastream v%s - built %s\n",PROG_VERSION,__DATE__);
    printf("Usage: alsastream <options>\n");
    printf("    Options can specify one of the following modes:\n");
    printf("       -dev <hwX:X> ......specify \"default\" or  alsa device <hwX:X> (see \"arecord -l\" for a list)\n");
    printf("       -freq <freqHz> ....Generate sinusoid at this freq\n");
    printf("       -rand  ............Generate random numbers\n");
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
  strncpy(sys->alsadev,"default",MAX_ALSA_NAME);
  sys->mode=eRandom;
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
              case 'd':
                  if(strncmp(argv[a-1],"-dev",4)==0) {
                      if(argc>a) strncpy(sys->alsadev,argv[a++],MAX_ALSA_NAME);
                      sys->mode=eAlsa;
                  }
                  break;
              case 'r':
                  if(strncmp(argv[a-1],"-rand",5)==0) {
                      sys->mode=eRandom;
                  }
                  break;
              case 'f':
                  if(strncmp(argv[a-1],"-freq",5)==0) {
                      if(argc>a) sys->freq = atof(argv[a++]);
                      sys->mode=eSinusoid;
                  }
                  break;
              default:
                  usage();
          }
      }
  }

  if (sys->mode == eSinusoid)
      printf("Setting freq to %.1f Hz\n",sys->freq);
  else if (sys->mode == eAlsa) 
  {
      //create_recorder(fs,"hw:2,0",&hpcm);
      create_recorder(sys->fs,sys->alsadev,&hpcm);
  }
  void *context = zmq_ctx_new ();
  void *publisher = zmq_socket (context, ZMQ_PUB);
  zmq_bind (publisher, "tcp://0.0.0.0:5563");

  printf("Sending data... Ctrl-C to quit\n");
  for (unsigned int nloop=0; 1 ;nloop++)
    {
      printf("."); fflush(stdout);
      if(nloop % 40 == 0) printf("\n");
      switch (sys->mode) {
              case eAlsa:
                  get_sample_buffer(&hpcm,sys->buf,sys->nbuf);
                  break;
              case eRandom:
                  for (int j=0;j<sys->nbuf;j++) {
                      sys->buf[j] = rand()%1000;
                  }
                  sleep(1);
                  break;
              case eSinusoid:
                  for (int j=0;j<sys->nbuf;j++) {
                      sys->buf[j]=16384*cos(2*pi*sys->freq*ix/sys->fs);
                      ix+=1;
                  }
                  break;
          }
      //printf("[%d] Buf: %d %d %d %d\n",nloop,buf[0],buf[1],buf[2],buf[3]);
      zmq_send(publisher,"audio",5,ZMQ_SNDMORE);
      zmq_send(publisher,&nloop,sizeof(nloop),ZMQ_SNDMORE);
      zmq_send(publisher,sys->buf,sys->nbuf*sizeof(short),0);
    }  // End forever loop
  if (sys->mode == eAlsa)
      close_device(&hpcm);
  printf("Finished\n");
}  // End main

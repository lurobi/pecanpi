/******************************************************************************
 *  @file:       alsastream.c
 *  @brief:      Provide a zmq source for audio data
 *  @author:     Luke Robison, Bob Robison
 *  
 *  Vers 1.0.3 - lar - 14 Feb, 2015
 *      Added channels and fixed sample-rate support for ALSA
 *  Vers 1.0.2 - rwr - 3 Oct 2014
 *      Added more cmdline args, restructure a bit
 *  Vers  1.0.1 - lar - 15 Sep 2014
 *      Added basic cmdline args
 *  Vers  1.0.0 - lar - 7 Sep 2014
 ******************************************************************************/
#include <math.h>
#include <time.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <zmq.h>
// Check for zmq >= 3.2 because of API change.
#if ZMQ_VERSION_MAJOR < 3
#error "zmq version 3.2+ required (a)"
#elseif ZMQ_VERSION_MAJOR == 3
#if ZMQ_VERSION_MINOR<2
#error "zmq version 3.2+ required (b)"
#endif
#endif

#include <alsa/asoundlib.h>


#include "pecanpi.h"

/****************************************************************************/
#define MAX_ALSA_NAME 32
#define PROG_VERSION "1.0.2"

typedef enum {eAlsa,eSinusoid,eRandom} enumModes;
typedef struct {
    enumModes mode;
    float fs;
    float freq;
    short *buf;
    int nchan;
    int nbuf; // number of values in the buffer
    int nframes; // number of frames, each with nchan many values (interleaved)
    int ipport;
    char ipaddr[25];
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

void wait4(float tsecs)
{
    struct timespec slptime,remtime;
    int stat=0;
    
    slptime.tv_sec=0;
    slptime.tv_nsec=(long)(250e6);     // 0.25 sec
    while (nanosleep(&slptime,&remtime) == EINTR )  // If interrupted continue
    {
        slptime=remtime;
    }
}
/******************************************************************************
 *  Function:    usage
 ******************************************************************************/
int usage()
{
    printf("alsastream v%s - built %s\n",PROG_VERSION,__DATE__);
    printf("Usage: alsastream <options>\n");
    printf("    Options:\n");
    printf("       -serv <ipaddr:port> ...... specify server ip/port, can leave off either one\n");
    printf("    Options can also specify one of the following modes:\n");
    printf("       -dev <hw:X,X> .....specify \"default\" or  alsa device <hwX:X> (see \"arecord -l\" for a list)\n");
    printf("       -c <nchans> .......number of channels to record (1 or 2)\n");
    printf("       -r <fs> ...........rate at which to sample (try 8000, 44100, 48000)\n");
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
    //  void *hpcm;
  snd_pcm_t *pcm;
  snd_pcm_sframes_t frames;
  sysStruct *sys=NULL;
  int dorandom=0;
  int ix=0;
  int a=1;
  int err;
  float pi=3.141592653589793;

  pecanpi_audio_hdr ppi_audio_hdr;

  sys=(sysStruct *)getmem(sizeof(sysStruct),"No memory for sysStruct\n");

  // Defaults
  strncpy(sys->alsadev,"default",MAX_ALSA_NAME);
  sys->mode=eRandom;
  sys->fs=48000;
  sys->freq=347.1;
  // each frame has nchan number of interleaved samples
  sys->nframes = 256;
  sys->ipport = 5563;
  sys->nchan = 1;
  strncpy(sys->ipaddr,"0.0.0.0",24);

  // Parse args
  while(a<argc) {   /* Process command line arguments */
      if(argv[a][0] != '-') {  
          usage();
      }
      else 
      {
          switch(argv[a++][1]) {   /* Auto increment to parameters if any */
              case 'c':
                  if(strcmp(argv[a-1],"-c")==0) {
		    if(argc>a) sys->nchan = atoi(argv[a++]);
		    else usage();
                  }
                  break;
              case 'd':
                  if(strncmp(argv[a-1],"-dev",4)==0) {
                      if(argc>a) strncpy(sys->alsadev,argv[a++],MAX_ALSA_NAME);
                      else usage();
                      sys->mode=eAlsa;
                  }
                  break;
              case 'r':
                  if(strcmp(argv[a-1],"-rand")==0) {
                      sys->mode=eRandom;
                  }
                  if(strcmp(argv[a-1],"-r")==0) {
		    if(argc>a) sys->fs = atoi(argv[a++]);
		    else usage();
                  }
                  break;
              case 's':
                  if(strncmp(argv[a-1],"-serv",5)==0) {
                      if (argc > a) {
                          char *thearg=(char *) argv[a++];
                          char *colptr=strchr(thearg,':');
                          if (colptr == NULL ) // IP Addr only
                          {
                              strncpy(sys->ipaddr,thearg,24);
                          }
                          else if (thearg[0]==':') 
                          {
                              sys->ipport = atoi(thearg+1);
                          }
                          else
                          {
                              strncpy(sys->ipaddr,thearg,(int)(colptr - thearg));
                              sys->ipport=atoi(colptr+1);
                          }
                      }
                      else usage();
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
  // make sure nbuf is an integer multiple of nchan
  sys->nbuf = sys->nframes*sys->nchan;
  sys->buf = (short *)getmem(sizeof(short)*sys->nbuf,"No memory for buffer\n");
  sys->nframes = sys->nbuf/sys->nchan;

  if (sys->mode == eSinusoid)
      printf("Setting freq to %.1f Hz\n",sys->freq);
  else if (sys->mode == eAlsa) 
  {

      //      create_recorder(sys->fs,sys->alsadev,sys->nchan,&hpcm);
      printf("Opening ALSA device %s\n",sys->alsadev);
      if ((err = snd_pcm_open(&pcm, sys->alsadev, SND_PCM_STREAM_CAPTURE, 0)) < 0) {
	  printf("Error opening device for capture: %s\n", snd_strerror(err));
	  exit(EXIT_FAILURE);
      }
      if ((err = snd_pcm_set_params(pcm,
				    SND_PCM_FORMAT_S16_LE,
				    SND_PCM_ACCESS_RW_INTERLEAVED,
				    sys->nchan,
				    sys->fs,
				    0, /* soft resample */
				    500000)) < 0) {   /* 0.5sec latency*/
	  printf("Playback open error: %s\n", snd_strerror(err));
	  exit(EXIT_FAILURE);
      }

      
      //create_recorder(fs,"hw:2,0",&hpcm);
      //      create_recorder(sys->fs,sys->alsadev,sys->nchan,&hpcm);
  }
  else if (sys->mode == eRandom)
  {
      printf("Starting Random playback.\n");
  }
  void *context = zmq_ctx_new ();
  void *publisher = zmq_socket (context, ZMQ_PUB);
  char tcpspec[128];
  snprintf(tcpspec,127,"tcp://%s:%d",sys->ipaddr,sys->ipport);
  zmq_bind (publisher, tcpspec);

  printf("Sending data... Ctrl-C to quit\n");
  
  ppi_audio_hdr.data_packet_bytes= sys->nchan * sys->nframes * 2 * 1;
  ppi_audio_hdr.num_samples = sys->nframes;
  ppi_audio_hdr.frame_num = 0;
  ppi_audio_hdr.fs = sys->fs;
  ppi_audio_hdr.frame_time = 0.0;
  ppi_audio_hdr.f_bb = 0.0;
  ppi_audio_hdr.nchan = sys->nchan;
  ppi_audio_hdr.sample_type = 3; // int16
  ppi_audio_hdr.packet_type = 1; // time-series

  
  for (unsigned int nloop=0; 1 ;nloop++) {
      if(nloop % 40 == 0) {
	  printf("."); fflush(stdout);
	  if (nloop % (40*40) == 0) printf("\n");
      }
      ppi_audio_hdr.frame_num = nloop;
      switch (sys->mode) {
              case eAlsa:
		  frames = snd_pcm_readi(pcm, sys->buf, sys->nframes);
		  if (frames < 0)
		      frames = snd_pcm_recover(pcm, frames, 0);
		  if (frames < 0) {
		      printf("snd_pcm_readi failed: %s\n", snd_strerror(err));
		      break;
		  }
                  break;
              case eRandom:
                  for (int j=0;j<sys->nbuf;j++) {
                      sys->buf[j] = rand()%1000;
                  }
                  wait4(0.25);
                  break;
              case eSinusoid:
                  for (int j=0;j<sys->nbuf;j++) {
                      sys->buf[j]=16384*cos(2*pi*sys->freq*ix/sys->fs);
                      ix+=1;
                  }
                  wait4(0.25);
                  break;
          }
      //printf("[%d] Buf: %d %d %d %d\n",nloop,buf[0],buf[1],buf[2],buf[3]);

      ppi_audio_hdr.frame_time += sys->nframes/sys->fs;

      zmq_send(publisher,"audio",5,ZMQ_SNDMORE);
      zmq_send(publisher,&ppi_audio_hdr,sizeof(ppi_audio_hdr),ZMQ_SNDMORE);
      zmq_send(publisher,sys->buf,sys->nbuf*sizeof(short),0);
    }  // End forever loop
  if (sys->mode == eAlsa)
      //close_device(&hpcm);
      snd_pcm_close(pcm);
  printf("Finished\n");
}  // End main

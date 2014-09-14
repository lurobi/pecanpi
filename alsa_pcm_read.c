#include <stdio.h>
#include <stdlib.h>
#include <alsa/asoundlib.h>
      
int main (int argc, char *argv[])
{
  int i;
  int err;
  short *buf;
  snd_pcm_t *capture_handle;
  snd_pcm_hw_params_t *hw_params;
  
  if ((err = snd_pcm_open (&capture_handle, argv[1], SND_PCM_STREAM_CAPTURE, 0)) < 0) {
    fprintf (stderr, "cannot open audio device %s (%s)\n", 
	     argv[1],
	     snd_strerror (err));
    fprintf (stderr, "Use 'arecord -l' to list valid recording devices.\n");
    exit (1);
  }
     
  if ((err = snd_pcm_hw_params_malloc (&hw_params)) < 0) {
    fprintf (stderr, "cannot allocate hardware parameter structure (%s)\n",
	     snd_strerror (err));
    exit (1);
  }
   
  if ((err = snd_pcm_hw_params_any (capture_handle, hw_params)) < 0) {
    fprintf (stderr, "cannot initialize hardware parameter structure (%s)\n",
	     snd_strerror (err));
    exit (1);
  }
  
  if ((err = snd_pcm_hw_params_set_access (capture_handle,
       hw_params, SND_PCM_ACCESS_RW_INTERLEAVED)) < 0) {
    fprintf (stderr, "cannot set access type (%s)\n",
	     snd_strerror (err));
    exit (1);
  }
  
  if ((err = snd_pcm_hw_params_set_format (capture_handle,
       hw_params, SND_PCM_FORMAT_S16_LE)) < 0) {
    fprintf (stderr, "cannot set sample format (%s)\n",
	     snd_strerror (err));
    exit (1);
  }

  if ((err = snd_pcm_hw_params_set_rate_resample(capture_handle,hw_params, 0)) < 0) {
    fprintf(stderr, "failed attempting to prevent ALSA resampling. (%s)",
	    snd_strerror(err));
    exit (1);
  }
  
  int dir = 0;
  unsigned int val = 8000;
  if ((err = snd_pcm_hw_params_set_rate_near (capture_handle,
       hw_params, &val, &dir)) < 0) {
    fprintf (stderr, "cannot set sample rate (%s)\n",
	     snd_strerror (err));
    exit (1);
  }
  
  if ((err = snd_pcm_hw_params_set_channels (capture_handle, hw_params, 1)) < 0) {
    fprintf (stderr, "cannot set channel count (%s)\n",
	     snd_strerror (err));
    exit (1);
  }
  
  if ((err = snd_pcm_hw_params (capture_handle, hw_params)) < 0) {
    fprintf (stderr, "cannot set parameters (%s)\n",
	     snd_strerror (err));
    exit (1);
  }
  
  snd_pcm_hw_params_free (hw_params);
  
  if ((err = snd_pcm_prepare (capture_handle)) < 0) {
    fprintf (stderr, "cannot prepare audio interface for use (%s)\n",
	     snd_strerror (err));
    exit (1);
  }

  int nbuf = 8000;
  buf = (short*)malloc(sizeof(short)*nbuf);
  
  for (i = 0; i < 10; ++i) {
    if ((err = snd_pcm_readi (capture_handle, buf, nbuf)) != nbuf) {
      fprintf (stderr, "read from audio interface failed (%s)\n",
	       snd_strerror (err));
      exit (1);
    }
  }
  
  snd_pcm_close (capture_handle);
  exit (0);

  return 0;
}

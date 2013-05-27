
GCC := gcc
CFLAGS :=

alsa_pcm_read: alsa_pcm_read.c
	$(GCC) -o $@ $< $(CFLAGS) -lasound
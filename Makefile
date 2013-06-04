
FC  := gfortran
CC  := gcc
CFLAGS := 
FCFLAGS := -g -fcheck=all -I/usr/include
FLFLAGS := -L/usr/lib

all: alsa_pcm_read fort_test

clean:
	rm -f *.o *.mod *~
	rm -f alsa_pcm_read fort_test

alsa_pcm_read: alsa_pcm_read.o
	$(CC) -o $@ $^ $(CFLAGS) -lasound
fort_test: fort_alsa_read.o alsa_pcm_read_simple.o fort_test.o hdf_io.o
	$(FC) -o $@ $^ $(FCFLAGS) -lasound -lhdf5_fortran

fort_test.o: fort_alsa_read.o alsa_pcm_read_simple.o hdf_io.o

%.o: %.f90
	$(FC) -c $(FCFLAGS) $< -o $@
%.o: %.c
	$(CC) -c $(CFLAGS) $< -o $@



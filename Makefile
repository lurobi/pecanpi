
FC  := gfortran
CC  := gcc
CFLAGS := 
FCFLAGS := -g -fcheck=all -I/usr/include
FLFLAGS := -L/usr/lib

OBJECTS := fort_alsa_read.o alsa_pcm_read_simple.o \
	   fort_test.o hdf_io.o compat_fft.o spec_module.o \
           ini_file_module.o

all: alsa_pcm_read fort_test

clean:
	rm -f *.o *.mod *~
	rm -f alsa_pcm_read fort_test

alsa_pcm_read: alsa_pcm_read.o
	$(CC) -o $@ $^ $(CFLAGS) -lasound
fort_test: $(OBJECTS)
	$(FC) -o $@ $^ $(FCFLAGS) $(FLFLAGS) -lasound -lhdf5hl_fortran -lhdf5_fortran -lhdf5 -lfftw3f -lm

test_ini_file: ini_file_module.f90
	$(FC) -o $@ $^ $(FCFLAGS) $(FLFLAGS)

fort_test.o: $(OBJECTS)
#fort_test.o: fort_alsa_read.o hdf_io.o compat_fft.o	\
#             spec_module.o ini_file_module.o
spec_module.mod: hdf_io.o compat_fft.o

%.o: %.f90
	$(FC) -c $(FCFLAGS) $< -o $@
%.o: %.c
	$(CC) -c $(CFLAGS) $< -o $@



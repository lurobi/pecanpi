#!/usr/bin/env python
import h5py
from pylab import *
f = h5py.File('pecanpi.h5')
spectrum = f.get('spectrum')
fax = f.get('spectrumFreqAx')
tax = f.get('spectrumTimeAx')
ntime = spectrum.shape[0]
print "Spectrum.shape:",spectrum.shape
spectrum_extent=[fax[0],fax[-1],tax[ntime],tax[0]]
fig = imshow(spectrum,aspect='auto',extent=spectrum_extent,interpolation='nearest')
show(fig)

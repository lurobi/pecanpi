#!/usr/bin/env python
import h5py
from pylab import *
f = h5py.File('pecanpi.h5')
audio = f.get('audio')
plot(audio)
show()

#!/usr/bin/env python
import math
import numpy as np
import pecanpi_common as ppi

def main():
    datsrc = ppi.ZMQAudioRead()
    datsrc.connect(address="tcp://127.0.0.1:5563")
    print "Starting!"

    fp = None
    while True:
        frame = datsrc.get_frame()
        audio_data = np.float32(frame.data)
        rms = 10*np.log10((audio_data**2).mean())
        if frame.frame_num % 25==0:
            print "%s: New Frame %f: %d samples: %.2f dB"%(frame.frame_num,frame.frame_time,len(audio_data),rms)
        if fp == None:
            fp = open("rec.zwav","w")

        fp.write(frame.data.tostring())

main()

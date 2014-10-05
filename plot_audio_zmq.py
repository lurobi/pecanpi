#!/usr/bin/env python
import zmq
import array
import pylab
import matplotlib.animation as animation
import time
import threading
import numpy as np


class ZMQAudioRead:
    def __init__(self,address="tcp://192.168.0.10:5563"):
        self.context = zmq.Context()
        self.socket = self.context.socket(zmq.SUB)
        self.socket.connect(address)

        self.data_filter = "audio"
        self.socket.setsockopt_string(zmq.SUBSCRIBE,
            self.data_filter.decode('ascii'))

    def read_more(self):
        dat_str = True
        dtbuf = np.dtype('h')
        dtfc  = np.dtype('I')
        while dat_str:
            #print "reading..."
            mpart = self.socket.recv_multipart()
            dat_hdr = mpart[0]
            dat_framenum = mpart[1]
            dat_str = mpart[2]
            audio = np.frombuffer(dat_str,dtype=dtbuf)
            frame = np.frombuffer(dat_framenum,dtype=dtfc)
            
            yield (audio,frame[0])
        print "done reading"
            

class AudioPlotter:
    def __init__(self):
        self.datsrc = ZMQAudioRead()
        self.fig,self.ax = pylab.subplots()
        self.line, = self.ax.plot([],[],lw=2)
        self.datgen = self.datsrc.read_more()
        self.audio = np.zeros(8000,dtype=np.dtype('h'))
        self.frame_counter = 0

        self.thread = threading.Thread(target=self.update_data)

    def update_data(self):
        while True:
            (new_audio,self.frame_counter) = self.datgen.next()
            self.audio = np.roll(self.audio, -len(new_audio))
            start = len(self.audio) - len(new_audio)
            stop = len(self.audio)
            self.audio.put(np.arange(start,stop), new_audio)
    
    def update_screen(self):
        self.line.set_data(range(0,len(self.audio)),self.audio)
        old_lim = self.ax.get_ylim()
        old_lim = max(old_lim)*1.25
        data_lim = abs(self.audio).max()
        new_lim = 2*np.mean([0.7*old_lim, 0.3*data_lim])
        new_lim = max([1, new_lim])
        #if self.frame_counter%100 == 1:
        self.ax.set_xlim(0,len(self.audio))
        self.ax.set_ylim(-new_lim,new_lim)
            #print "min/max: %d/%d"%(min(self.audio),max(self.audio))
        return self.line

    def main(self):
        # start getting data
        self.thread.start()

        
        while True:
            self.update_screen()
            pylab.draw()
            pylab.show()
            pylab.pause(0.01)
            #print "draw loop done!"

    
#    from multiprocessing import Process
#    pylab.ion() # go interactive.
#    p = Process(target=get_data)
#    p.start()
#    while True:
#        pylab.pause(1)
#    p.join()
#    exit(0)
#    get_data()

pylab.ion() # go interactive.
ap = AudioPlotter()
ap.main()


#!/usr/bin/env python
import zmq
import array
import matplotlib
matplotlib.use('gtkagg')

import pylab
import matplotlib.animation as animation
import time
import threading
import numpy as np

import pecanpi_common as ppi

tt = ppi.TicToc()
tt.tic("notdraw")

class AudioPlotter:
    def __init__(self,ax):
        self.ii_run = True
        self.datsrc = ppi.ZMQAudioRead()
        self.datsrc.connect()
#        self.fig,self.ax = pylab.subplots()
        self.ax = ax
        self.line, = self.ax.plot([],[],lw=2)
        self.audio = np.zeros(1*44100,dtype=np.float32)
        self.frame_counter = 0
        self.thread = None
        self.lock = threading.RLock()
        print "done init"

    def run_start(self):
        self.thread = threading.Thread(target=self.update_data)
        self.thread.start()

    def run_stop(self):
        print "trying to join thread1"
        with self.lock:
            self.ii_run = False
        print "trying to join thread2"
        self.thread.join()
        print "done joining"

    def __del__(self):
        self.run_stop()
        

    def update_data(self):
        print "update_data: started"
        while self.ii_run:
            tt.tic("update_data")
            frame = self.datsrc.get_frame()
            new_audio = np.float32(frame.data)
            start = len(self.audio) - len(new_audio)
            stop = len(self.audio)
            with self.lock:
                self.audio = np.roll(self.audio, -len(new_audio))
                self.audio.put(np.arange(start,stop), new_audio)
            tt.toc("update_data")


    def draw(self, framedata):
        tt.toc("notdraw")
        tt.tic("draw")
        with self.lock:
            dat = self.audio
        self.line.set_data(range(0,len(dat)),dat)
        old_lim = self.ax.get_ylim()
        old_lim = max(old_lim)*1.25
        data_lim = abs(dat).max()
        new_lim = 2*np.mean([0.7*old_lim, 0.3*data_lim])
        new_lim = max([1, new_lim])
        #if self.frame_counter%100 == 1:
        self.ax.set_xlim(0,len(dat))
        self.ax.set_ylim(-new_lim,new_lim)
        #print "min/max: %d/%d"%(min(dat),max(dat))
        tt.toc("draw")
        tt.tic("notdraw")
        return (self.line,)
    
if True:
    fig = pylab.figure()
    ax = pylab.axes()
    ap = AudioPlotter(ax)
    ap.run_start()
    ani = animation.FuncAnimation(fig, ap.draw, interval=50, blit=False)
    #line_ani.save('lines.mp4')
    pylab.show()
    print "pylab.show() has finished"
    ap.ii_run = False
    del ap
    
elif 1==0:
    pylab.ion() # go interactive.
    ap = AudioPlotter()
    ap.main()
elif 2==0:

    datsrc = ZMQAudioRead(address="tcp://127.0.0.1:5563")
    print "Starting!"

    for (new_audio,frame_counter) in datsrc.read_more():
        #xx = datsrc.read_more
        #(new_audio,frame_counter) = datsrc.read_more
        #print len(xx)
        print "New Frame %d",frame_counter
    

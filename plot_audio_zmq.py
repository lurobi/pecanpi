#!/usr/bin/env python
import zmq
import array
import pylab
import matplotlib.animation as animation
import time
import threading


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
        while dat_str:
            print "reading..."
            mpart = self.socket.recv_multipart()
            dat_hdr = mpart[0]
            dat_str = mpart[1]
            audio = array.array('H',dat_str)
            yield audio
        print "done reading"
            

class AudioPlotter:
    def __init__(self):
        self.datsrc = ZMQAudioRead()
        self.fig,self.ax = pylab.subplots()
        self.line, = self.ax.plot([],[],lw=2)
        self.datgen = self.datsrc.read_more()
        self.audio = []

        self.thread = threading.Thread(target=self.update_data)

    def update_data(self):
        while True:
            self.audio = self.datgen.next()
    
    def update_screen(self):
        self.line.set_data(range(0,len(self.audio)),self.audio)
        self.ax.set_xlim(0,len(self.audio))
        self.ax.set_ylim(min(self.audio),max(self.audio))
        return self.line

    def main(self):
        # start getting data
        self.thread.start()

        while not self.audio:
            print "waiting for first data..."
            time.sleep(0.25)
        print "got data! (mainloop)"
        while True:
            self.update_screen()
            pylab.draw()
            pylab.show()
            pylab.pause(0.25)
            print "draw loop done!"

    
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


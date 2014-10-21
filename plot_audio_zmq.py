#!/usr/bin/env python
import zmq
import array
import pylab
import matplotlib.animation as animation
import time
import threading
import numpy as np
import numpy.fft as fft


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
        self.fig = pylab.figure()
        self.ax = pylab.subplot(3,1,1)
        self.fft_ax = pylab.subplot(3,1,2)
        self.spec_ax = pylab.subplot(3,1,3)
        self.line, = self.ax.plot([],[],lw=2)
        self.fft_line, = self.fft_ax.plot([],[],lw=2)
        dummy = np.zeros((1,1))
        self.spec_gram = self.spec_ax.imshow(dummy)
        self.datgen = self.datsrc.read_more()
        
        self.audio = None
        self.audio_tax = None
        self.spectrum = None
        self.spec_gram_data = None
        
        self.frame_counter = 0

        self.thread = threading.Thread(target=self.update_data)
        
    def init_buffers(self,nsamp_frame,fs):
        fs = float(fs)
        seconds_of_hist = 2.
        T_frame = nsamp_frame/fs
        
        nframes_hist = round(seconds_of_hist/T_frame)
        nsamps_hist = nframes_hist*nsamp_frame
        seconds_of_hist = nsamps_hist/fs
        nfft_keep = np.ceil(nsamp_frame/2)
        self.spec_gram_data = np.zeros( (nframes_hist,nfft_keep), np.float32, order='F')
        self.audio  = np.zeros(nsamps_hist,dtype=np.dtype('h'))
        self.spectrum = np.zeros(np.ceil(nsamp_frame/2),dtype=np.float32)
        
        self.audio_tax = np.linspace(-seconds_of_hist + 1/fs,0,nsamps_hist)
        
        dF = fs/nsamp_frame
        self.spectrum_fax = np.arange(0,(fs/2),dF)
        
        dF = fs/nsamp_frame
        tup = nsamp_frame/fs
        self.spec_gram_fax = np.arange(0,(fs/2),dF)
        self.spec_gram_tax = np.arange(0,-(tup*nframes_hist),-tup)
        
        

    def update_data(self):
        while True:
            (new_audio,src_fc) = self.datgen.next()
            new_fft = 10*np.log10(abs(fft.fft(new_audio)))
            new_fft = new_fft[0: np.ceil(new_fft.size/2)]
            #print self.frame_counter
            if self.frame_counter == 0:
                self.init_buffers(new_audio.size,8000)
                
            self.audio = np.roll(self.audio, -new_audio.size)
            start = (self.audio.size) - new_audio.size
            stop = self.audio.size
            #print "start,stop",start,stop
            self.audio.put(np.arange(start,stop), new_audio)
            
            self.spectrum = new_fft
            
            self.spec_gram_data = np.roll(self.spec_gram_data,1,1)
            self.spec_gram_data[-1,:] = new_fft
            
            self.frame_counter += 1
            
            
    
    def update_screen(self):
        if self.frame_counter == 0: return
        #print "audio:",self.audio_tax.shape,self.audio.shape
        
        self.line.set_data(self.audio_tax,self.audio)
        old_lim = self.ax.get_ylim()
        old_lim = max(old_lim)*1.25
        data_lim = abs(self.audio).max()
        new_lim = 2*np.mean([0.7*old_lim, 0.3*data_lim])
        new_lim = max([1, new_lim])
        #if self.frame_counter%100 == 1:
        
        self.ax.set_xlim(self.audio_tax[0],self.audio_tax[-1])
        self.ax.set_ylim(-new_lim,new_lim)
            #print "min/max: %d/%d"%(min(self.audio),max(self.audio))
        
        #print "fft_line:",self.spectrum_fax.shape,self.spectrum.shape
        self.fft_line.set_data(self.spectrum_fax,self.spectrum)
        self.fft_ax.set_xlim(self.spectrum_fax[0],self.spectrum_fax[-1])
        self.fft_ax.set_ylim(self.spectrum.min(),self.spectrum.max())
        
        

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


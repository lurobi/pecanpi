import numpy as np
import struct
import zmq
import time

class ZMQAudioFrame:
    def __init__(self):
        self.hdr_fmt = 'iiifffbbb5c'
        self.data_packet_bytes = 0
        self.num_samples = 0
        self.frame_num = 0
        self.f_bb = 0
        self.nchan = 0
        self.sample_type = 0
        self.packet_type = 0
        self.reserved = range(0,5)
        
    def header_from_str(self,hdr_str):
        out = struct.unpack(self.hdr_fmt,hdr_str)
        self.data_packet_bytes = out[0]
        self.num_samples = out[1]
        self.frame_num = out[2]
        self.fs = out[3]
        self.frame_time = out[4]
        self.f_bb = out[5]
        self.nchan = out[6]
        self.sample_type = out[7]
        self.packet_type = out[8]

        self.np_type = np.int16
    def header_to_str(self):
        hdr = (self.data_packet_bytes,
               self.num_samples,
               self.frame_num,
               self.fs,
               self.frame_time,
               self.f_bb,
               self.nchan,
               self.sample_type,
               self.packet_type,
               [0,0,0,0,0] )
        return struct.pack(self.hdr_fmt,hdr)

    def set_np_type(self):
        if self.sample_type==1:
            self.np_type=np.float32
        elif self.sample_type==2:
            self.np_type=np.float64
        elif self.sample_type==3:
            self.np_type=np.int16
        elif self.sample_type==4:
            self.np_type=np.int32
        elif self.sample_type==4:
            self.np_type=np.int64
        else:
            raise Exception('Sample type not defined!')

    def data_from_str(self,data_str):
        self.set_np_type()
        self.data = np.fromstring(data_str, dtype=self.np_type)
    def data_to_str(self):
        self.set_np_type()
        return self.np_type(self.data).tostring()

class ZMQAudioRead:
    def __init__(self):
        self.context = zmq.Context()
        self.socket = None
        
    def connect(self,address="tcp://127.0.0.1:5563"):
        self.socket = self.context.socket(zmq.SUB)
        self.socket.connect(address)

        self.data_filter = "audio"
        self.socket.setsockopt_string(zmq.SUBSCRIBE,
            self.data_filter.decode('ascii'))

    def get_frame(self):
        #print "reading..."
        frame = ZMQAudioFrame()
        mpart = self.socket.recv_multipart()
        dat_hdr = mpart[0] # "audio"
        frame.header_from_str(mpart[1])
        frame.data_from_str(mpart[2])
        #print "got buffer!"
        #print "frame %d: (%d)"%(frame[0],len(audio))
        #print "--min/max: %d/%d"%(min(audio),max(audio))
        return frame


class TicToc:
    def __init__(self):
        self.timers = dict()
        self.cumtime = dict()
        self.ntimes = dict()
        self.reporttime = 5
    def tic(self,key):
        self.timers[key] = time.time()
    def toc(self,key):
        t2 = time.time()
        t1 = self.timers.get(key,None)
        if t1 == None:
            raise Exception("No tic for this toc!")
        self.cumtime[key] = self.cumtime.get(key,0) + (t2-t1)
        self.ntimes[key] = self.ntimes.get(key,0) + 1

        if self.cumtime[key] > self.reporttime:
            print "%s: %.2f seconds in %d calls, %.2f per call" % \
                (key, self.cumtime[key], self.ntimes[key],
                 float(self.cumtime[key])/float(self.ntimes[key]))
            self.ntimes[key] = 0
            self.cumtime[key] = 0
        self.timers[key] = None


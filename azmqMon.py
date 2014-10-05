#!/usr/bin/env python
# -*- coding: utf-8 -*-
###############################################################################
# @file   azmqMon.py
# @brief  Monitor audio stream sent via ZMQ
# @author Bob Robison
###############################################################################
#   DESCRIPTION: 
'''
  A program to monitor audio data sent via ZMQ
'''
###############################################################################
import re, sys, os,time,commands, string
from PyCmdApp import *
import zmq,array,struct,threading,math
import numpy.fft as npfft
import numpy
import curses

VERSION = '1.0.0'
VERSDATE = '30 Sep 2014'
############################################################################
## ZMQAudioRead
############################################################################
def dB20(lin_val):
  if lin_val==0: return -numpy.inf
  else: return 20*math.log10(abs(lin_val))

class ZMQAudioRead:
    def __init__(self,address="tcp://192.168.0.10:5563",parent=None):
        self.parent=parent
        self.context = zmq.Context()
        self.socket = self.context.socket(zmq.SUB)
        self.socket.connect(address)

        self.data_filter = "audio".decode('ascii')
        # Only subscribe to messages starting with self.data_filter
        self.socket.setsockopt_string(zmq.SUBSCRIBE,self.data_filter)

    def read_more(self):
        dat_str = True
        while dat_str and not self.parent.done:
            #print "reading..."
            mpart = self.socket.recv_multipart()
            dat_hdr = mpart[0]
            count = struct.unpack("I",mpart[1])[0]
            dat_str = mpart[2]
            audio = array.array('h',dat_str)
            #print "Header: %s"%dat_hdr
            #print "Count: %d"%dat_idx
            yield (count,audio)
        #print "done reading"

############################################################################
## App class
##   Top-level application, based on SigExpCmdApp
############################################################################
class App(PyCmdApp):
  def __init__(self):
    # Initialize Basic Class Application
    PyCmdApp.__init__(self,"azmqMon",VERSION,VERSDATE)
    self.debug=0
    self.count=0
    self.done=False
    self.logfile=None
    self.fs=8000
    self.ipaddr="127.0.0.1"
    self.ipport=5563

    self.postInit()

  ############################################################################
  ## usage()
  ############################################################################
  def usage(self):
    print "%s  - Version %s, %s"%(self.basename,VERSION,VERSDATE)
    print "Usage: %s [options] "%self.basename
    print "       -h ................... shows this help"
    print "       -cfg <cfgfile> ....... specify config file(def=%s)"%self.cfgfile
    print "       -tcp <ipaddr:port> ... specify IP and port for src(def=%s:%d)"%(self.ipaddr,self.ipport)
    sys.exit()

  def initCurses( self ):
    self.stdscr = curses.initscr()
    curses.noecho()
    self.stdscr.keypad(1)
    curses.cbreak()
    curses.start_color()
    curses.curs_set(False)
    self.stdscr.clear()
    self.stdscr.refresh()

    # register colors    foreground          background
    curses.init_pair( 1, curses.COLOR_WHITE, curses.COLOR_BLACK )
    curses.init_pair( 4, curses.COLOR_GREEN, curses.COLOR_BLACK )
    curses.init_pair( 5, curses.COLOR_BLUE,  curses.COLOR_BLACK )
    curses.init_pair( 6, curses.COLOR_BLACK, curses.COLOR_YELLOW )
    curses.init_pair( 7, curses.COLOR_BLACK, curses.COLOR_BLUE )
    curses.init_pair( 8, curses.COLOR_BLACK, curses.COLOR_GREEN )
    curses.init_pair( 9, curses.COLOR_BLACK, curses.COLOR_RED )
    
    ( maxy, maxx ) = self.stdscr.getmaxyx() # current screen size
    self.maxy=maxy
    self.maxx=maxx
    yAxisWidth = 5 # width of y axis
    logWinHeight=10
    self.titlewin = curses.newwin( 1, maxx-yAxisWidth, 0, 0 )
    self.logwin = curses.newwin( logWinHeight, maxx, maxy-logWinHeight, 0 )
    self.specwin = curses.newwin( maxy-logWinHeight-3, maxx-yAxisWidth, 1, yAxisWidth )
    self.yaxiswin  = curses.newwin( maxy-logWinHeight-3, yAxisWidth, 1, 0 )
    self.xaxiswin = curses.newwin( 1, maxx-yAxisWidth, maxy-logWinHeight-2, yAxisWidth  )
    self.curwin = curses.newwin( 1, maxx-yAxisWidth, maxy-logWinHeight-1, yAxisWidth  )
    self.statstr=""
    self.curPos=(maxx/2)
    self.curPoskHz=self.fs/4e3
    self.lastzoom=1.0
    self.zoom=1.0
    self.drawXAxis()

  def setTitleString(self, title_str, color_pair=0):
    self.titlewin.clear()
    (maxy, maxx) = self.titlewin.getmaxyx()
    self.titlewin.addstr(0, maxx/2-len(title_str)/2, title_str, color_pair)
    self.titlewin.refresh()

  def updateCursor(self):
    (maxy, maxx) = self.curwin.getmaxyx()
    try:
      #self.curwin.addstr(maxy,0,"-"*maxx)
      #self.curwin.addnstr(0,0,"-"*(maxx-1),maxx-1)
      self.curwin.addstr(0,0,"-"*(maxx-2))
      self.curwin.addstr(0,self.curPos,"^",7)
      if self.lastzoom != self.zoom:  # Redo scale
        self.lastzoom=self.zoom
        self.loXkHz = (self.curPoskHz - self.fs/(2e3*self.zoom)) 
        self.hiXkHz = (self.curPoskHz + self.fs/(2e3*self.zoom)) 
        if self.loXkHz < 0:
          self.loXkHz = 0
        if self.hiXkHz > self.fs/2e3:
          self.hiXkHz = self.fs/2e3
      self.curwin.noutrefresh()
    except Exception,ex:
      self.logMsg( "Got exception: %s\n"%ex)
      self.OnExit()
  def drawXAxis(self):
    (maxy, maxx) = self.xaxiswin.getmaxyx()
    self.xaxiswin.clear()
    xstart_str = '%gkHz'%(self.loXkHz)
    xstop_str = '%gkHz'%(self.hiXkHz)
    xhalf_str = '%gkHz'%((self.hiXkHz+self.loXkHz)/2.0)
    x1quar_str  = '%gkHz'%((self.hiXkHz-self.loXkHz)/4.0 + self.loXkHz)
    x3quar_str = '%gkHz'%(3.0*(self.hiXkHz-self.loXkHz)/4.0 + self.loXkHz)
    self.xaxiswin.addstr(0, 0,xstart_str)
    self.xaxiswin.addstr(0, maxx/4-len(x1quar_str)/2,x1quar_str)
    self.xaxiswin.addstr(0, maxx/2-len(xhalf_str)/2,xhalf_str)
    self.xaxiswin.addstr(0, maxx/4*3-len(x3quar_str)/2,x3quar_str)
    self.xaxiswin.addstr(0, maxx-len(xstop_str)-1,xstop_str)
    self.xaxiswin.noutrefresh()
    
  def drawSpec(self,mag):
    (maxy, maxx) = self.specwin.getmaxyx()
    self.debugLogMsg("Drawing Spec: %d x %d,zoom=%s\n"%(maxy,maxx,self.zoom))
    self.specwin.clear()
    pcolor=0
    bingroup=len(mag)/(float(maxx)*2*self.zoom)
    bingroup=bingroup
    for ix in range(0,maxx):
      lobin=int(ix*bingroup)
      hibin=int((ix+1)*bingroup)
      binval=-9999
      for grpx in range(lobin,hibin):
        if grpx < len(mag):
          if mag[grpx]>binval:
            binval=mag[grpx]
      # Now have the value to plot in this column
      loEnd=-50.0
      hiEnd=+5.0
      if binval >= hiEnd:
        yval=0
      elif binval <= loEnd:
        yval=maxy
      else:
        yval = int(maxy - ((binval-loEnd)/(hiEnd-loEnd) * maxy))
      self.verboseLogMsg("Bin [%d-%d] %d => %.1f => %d\n"%(lobin,hibin,ix,binval,yval))
      for yx in range(yval,maxy-1):
        self.specwin.addstr(yx,ix,'#',pcolor)
    if not self.done:
      self.specwin.refresh()
  def analyze(self):
    if len(self.audio)>0:
      obuf=npfft.fft(self.audio,2048)
      mag=map(lambda x: dB20(x) - 147,obuf)
      maxmag=max(mag[1:])
      maxidx=mag.index(maxmag)
      fs=8000
      frqval=float(maxidx)*fs/len(obuf)
      self.statstr="Count: %d, min: %5d, max: %5d, obuf: %.1f @ %.1f Hz        "%\
        (self.count,self.audio[0]+min(self.audio),max(self.audio),maxmag,frqval)
      self.drawSpec(mag)
  def getCursorInfo(self):
    rval="Zoom: %.1f, curPos: %d, curPoskHz: %.3f, lofreq: %.3f kHz, hifreq= %.3f kHz"%\
      (self.zoom,self.curPos,self.curPoskHz,self.loXkHz,self.hiXkHz)
    return rval
  def updateStatView(self):
    self.analyze()
    if not self.done:
      self.logwin.addnstr(2,0,self.getCursorInfo(),self.maxx)
      self.logwin.addnstr(3,0,self.statstr,self.maxx)
      self.logwin.refresh()
  def update_data(self):
    while not self.done:
      (self.count,self.audio) = self.datgen.next()
      self.updateStatView()
  ############################################################################
  ## main()
  ############################################################################
  def main(self):
    self.orgargv=sys.argv[:]

    try:
        ipval=self.processArg("-tcp","string",default="%s:%s"%(self.ipaddr,self.ipport))
        fields=ipval.split(':')
        if len(fields)==1:
            self.ipaddr=fields[0]
        else:
            self.ipport=int(fields[1])
            if len(fields[0])!=0:
                self.ipaddr=fields[0]
    except:
        print "Poorly formed tcp spec"
        self.usage()
    self.fs=8000
    self.loXkHz=0
    self.hiXkHz=self.fs/2e3
    self.initCurses()
    self.datsrc = ZMQAudioRead("tcp://%s:%d"%(self.ipaddr,self.ipport),self)
    self.datgen = self.datsrc.read_more()
    self.audio = []
    self.logfile="/tmp/azmq.log"
    self.thread = threading.Thread(target=self.update_data)
    # start getting data
    self.thread.start()
    self.done=False

    self.cursor_color = curses.color_pair(4)
    self.setTitleString("azmqMon [ %s:%d]"%(self.ipaddr,self.ipport))
    (maxy,maxx) = self.curwin.getmaxyx()
    try:
      self.curwin.clear()
      # set a little help dialog for users
      self.curwin.addnstr(0,0, 'Left/right arrow keys and space bar to zoom ',
                          maxx-1, self.cursor_color);
      self.curwin.refresh()

      self.stdscr.timeout(1000)
      while True:
         # wait and listen for keyboard input from user
         event = self.stdscr.getch()
         (maxy,maxx) = self.curwin.getmaxyx()

         # -1 means no key was found during this polling period
         if (event == -1 ):
              # do nothing
            pass
         elif(event == ord('q')): # q means quit!
             break  # quit
         elif(event == ord('c')): # draw cursor
              self.updateCursor()
         elif(event == 32): # space
             self.logwin.addnstr(0,0,"Starting data now: maxx:%s, maxy:%s"%(maxx,maxy),maxx)
             self.logwin.addnstr(3,0,"Bottom",maxx)
             self.logwin.noutrefresh()
         elif(event == 260): # left arrow
             self.curPos-=1 # move cursor to the left
             self.curPos=max(0,self.curPos)
             self.curPoskHz= (self.curPos/float(maxx))* (self.hiXkHz - self.loXkHz) + self.loXkHz
         elif(event == 261): # right arrow
             self.curPos+=1 # move cursor to the right
             self.curPos=min(maxx,self.curPos)
             self.curPoskHz= (self.curPos/float(maxx))* (self.hiXkHz - self.loXkHz) + self.loXkHz
         elif(event == 259): # up arrow
           self.zoom = self.zoom*0.8
           if self.zoom<1.0:
             self.zoom=1.0
         elif(event == 258): # down arrow
           self.zoom = self.zoom*1.2
           if self.zoom>50:
             self.zoom=50
         self.updateCursor()
	 curses.doupdate()
         # shows over, tear down
      self.OnExit()
    except KeyboardInterrupt, kiex:
       # Ctrl-C shows over, tear down
       self.OnExit()
    except Exception, e:
       # Exception, tear down
       self.OnExit()
       raise e

  def OnExit( self ):
    self.done=True
    curses.nocbreak()
    self.stdscr.keypad(0)
    curses.echo()
    curses.endwin()

##############################################################################
# This allows .py file to be imported, or run directly
##############################################################################
if __name__ == '__main__':
  app=App()
  app.main()

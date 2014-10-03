#!/usr/bin/env python
# -*- coding: utf-8 -*-
###############################################################################
#   @file:      PyCmdApp.py
#   @author:    Bob Robison
#   @brief:     Convenience class for cmdline apps
'''
  This module defines a base class used for cmdline apps
'''
###############################################################################
# Ver 1.0.0 - 30 Sep 2014
###############################################################################
import re, sys, os,time,commands, string, shutil
from threading import Thread,Event
from Queue import Queue,Empty

_PYCMD_BASEVERSION='1.0.0'
# Define a few logging levels:
_gLogError   = (1 << 0)
_gLogWarn    = (1 << 1)
_gLogInfo    = (1 << 2)
_gLogDebug   = (1 << 3)
_gLogVerbose = (1 << 4)

###################################################################
# Just setup an empty class to hold attributes
class CfgInfo:
    def __init__(self,cfgname):
      self.cfgkeys=[]
      self.cfgname=cfgname
############################################################################
## LoggerThread class
##    A separate thread to handle all log messages
############################################################################
class LoggerThread(Thread):
  def __init__(self,app,que=None):
    self.app=app
    if que:
      self.logQue=que
    else:
      self.logQue=Queue()
    Thread.__init__(self)
  ###########################################################################
  def run(self):
    done=False
    self.app.logMsg("LoggerThread starting up\n")
    while not done:
      newmsg=self.logQue.get()
      self.app.logMsg(newmsg,plain=True)

##############################################################################
# class PyLogger
#   The Base Class that provides the logging capability
##############################################################################
class PyLogger:
  def __init__(self,cfg,useque=None):
    self.LogQue=useque
    self.logfile=None
    self.logsbak=5
    self.logsize=1e6
    self.debug=3
    self.stdout=False  # Include stdout by default
    self.logprefix=''  # No default prefix
    self.setLogInfo(cfg)  # Read logging config info from ref point
  def setLogFile(self,logfile):
    self.logfile=logfile
  def setLogsBack(self,logsbak):
    self.logsbak=logsbak
  def setLogSize(self,logsize):
    self.logsize=logsize
  def setDebug(self,debug):
    self.debug=debug
  def setLogPrefix(self,pref):
    self.logprefix=pref
  # Configure key logging params from specified config
  def setLogInfo(self,cfg):
    if 'logfile' in dir(cfg):
      self.logfile=cfg.logfile
    if 'logsbak' in dir(cfg):
      self.logsbak=cfg.logsbak
    if 'logsize' in dir(cfg):
      self.logsize=cfg.logsize
    if 'debug' in dir(cfg):
      self.debug=cfg.debug
    if 'stdout' in dir(cfg):
      self.stdout=cfg.stdout
    if 'logprefix' in dir(cfg):
      self.logprefix=cfg.logprefix
  ##################################################################
  def logMsg(self,msg,stdout=0,plain=False):
    if plain:
      fmtmsg=msg
    else:
      msec=int(time.time()%1*1000)
      fmtmsg=time.strftime('%Y-%j/%T')+'.%03d '%msec
      fmtmsg += self.logprefix
      fmtmsg += msg
    if stdout or self.logfile==None or self.stdout:
      sys.stdout.write(fmtmsg)
    if self.LogQue is not None:
      self.LogQue.put(fmtmsg)
      return
    elif self.logfile==None:
      return
    #Rotate the log, if so configured
    if (os.path.exists(self.logfile) and
        os.path.getsize(self.logfile) >= self.logsize):
        for i in range(self.logsbak,1,-1):
            try:    shutil.move('%s.%d'%(self.logfile,i-1),
                                '%s.%d'%(self.logfile,i))
            except: continue
        try:    shutil.move(self.logfile,'%s.%d'%(self.logfile,1))
        except: pass
    try:
      fd=open(self.logfile,'a')
      fd.write(fmtmsg)
      fd.close()
    except Exception,ex:
      sys.stderr.write("Exception: %s\n"%ex)
      sys.stderr.write("Error logging msg %s to %s\n"%(msg,self.logfile))
  ##################################################################
  # Add new level-specific LogMsg calls, based on self.debug value
  ############################################################################
  ## log-checks
  ############################################################################
  def chkErrLvl(self):
    return self.debug & _gLogError
  def chkWarnLvl(self):
    return self.debug & _gLogWarn
  def chkInfoLvl(self):
    return self.debug & _gLogInfo
  def chkDebugLvl(self):
    return self.debug & _gLogDebug
  def chkVerboseLvl(self):
    return self.debug & _gLogVerbose
  # Add new level-specific LogMsg calls, based on self.debug value
  ############################################################################
  def errorLogMsg(self,msg,stdout=0):
    if self.chkErrLvl():
      self.logMsg(msg,stdout)
  def warnLogMsg(self,msg,stdout=0):
    if self.chkWarnLvl():
      self.logMsg(msg,stdout)
  def infoLogMsg(self,msg,stdout=0):
    if self.chkInfoLvl():
      self.logMsg(msg,stdout)
  def debugLogMsg(self,msg,stdout=0):
    if self.chkDebugLvl():
      self.logMsg(msg,stdout)
  def verboseLogMsg(self,msg,stdout=0):
    if self.chkVerboseLvl():
      self.logMsg(msg,stdout)

##############################################################################
# class PyCmdApp
#   The Base Class that provides standard cmdline application utilities:
#   Typical usage would be to derive your main app from this, and initialize
#   as follows:
#   class MyMain(PyCmdApp):
#     def __init__(self,desc,vers):
#        PyCmdApp.__init__(self)
#        self.DESCRIPTION= desc
#        self.VERSDATE = "11 Sep 2001"
#        self.VERSION = vers
##############################################################################
class PyCmdApp(PyLogger):
  def __init__(self,desc,vers,cmdate):
    self.DESCRIPTION = desc
    self.PYCMD_BASEVERSION = _PYCMD_BASEVERSION
    self.VERSION = vers
    self.VERSDATE = "30 Sep 2014"
    self.basename=os.path.basename(sys.argv[0])
    self.usageHdr="%s  - Version %s, %s"%\
        (self.basename,self.VERSION,self.VERSDATE)
    self.orgargv=sys.argv[:]
    self.appname=re.sub('.py','',self.basename)
    self.cfgfile='./%s.cfg'%self.appname
    self.cfgfile=self.processArg("-cfg","string",default=self.cfgfile)
    self.debug=0
    self.dummy=[]
    self.cfgkeys=[]
    self.cfgsects=[]
    self.logfile='./%s.log'%self.appname
    self.logsize=1e6
    self.logsbak=3
    self.envPush=True
    PyLogger.__init__(self,self)
    self.abc='123'
    self.cfgkeys.append('abc')

  #################################################################
  # postInit is called after basic initialization to handle usage,
  #    dumpconfig, and any other standard arguments
  #    Added allowCaps parm, to be passed to handleConfig
  #################################################################
  def postInit(self,allowCaps=False):
    if "-h" in sys.argv or "-v" in sys.argv:
      self.usage()
    self.cfgfile=self.processArg("-cfg","string",default=self.cfgfile)
    self.logfile=self.processArg("-log","string",default=self.logfile)
    self.debug=self.processArg("-debug",default=self.debug)
    self.handleConfig(allowCaps=allowCaps)
    if "-dumpconfig" in sys.argv:
      self.dumpConfig()

  ############################################################################
  ## processArg()
  ## Look for a particular argument, get the next value and remove
  ## both from sys.argv.  If arg not found, do nothing
  ##############################################################################
  def processArg(self,aval,type=None,default=False,count=1):
    if aval not in sys.argv:
      return default
    tstart=sys.argv.index(aval)
    # If aval in list, and type requested is none,
    #   remove arg and return true
    if type==None:
      sys.argv.remove(aval)
      return True
    # If type not none, make sure another arg follows
    try:
      if count>1:
        listval=[]
        for c in range(0,count):
          rval=sys.argv[tstart+1]
          listval.append(rval)
          sys.argv.remove(rval)
        return listval
      else:
          rval=sys.argv[tstart+1]
          sys.argv.remove(rval)
    except:
      if count>1:
        rval=[]
        print "Expected value of len %d following %s"%(count,aval)
      else:
        rval=None
        print "Expected value of type %s following %s"%(type,aval)
      raise SystemExit
    sys.argv.remove(aval)
    if type=='int':
      return int(rval)
    elif type=='float':
      return float(rval)
    if type=='hex':
      return(int(rval,16))
    else:
      return rval

  #######################################################################
  # exp_env -- Expand any environment variables
  #   To get a real $ escape it with backslash
  #   v 1.1.0 - rwr - 2 Oct 2013 -- added support for ${Var} format
  #######################################################################
  def exp_env(self,s):
    sout=s
    # Define regular expression to match dollar-sign
    #    followed by alphanumeric (and underscore)
    # First handle curly-brace version
    curlyobj=re.compile('(\${[^}]*})')
    list=curlyobj.findall(s)    # Find all matches
    for x in list:
      var=x[2:-1]  # This skips '${' at beginning, and '}' at end
      rep=os.getenv(var)
      if not rep:
        rep=''  # Use empty string if env not found
      sout=re.sub('\\'+x,rep,sout)  # Need to escape the $

    # Then normal env vars
    obj=re.compile('(\$[\w_]*)')
    list=obj.findall(sout)    # Find all matches
    for x in list:
      var=x[1:]  # This skips '$' at beginning
      rep=os.getenv(var)
      if not rep:
        rep=''  # Use empty string if env not found
      sout=re.sub('\\'+x,rep,sout)  # Need to escape the $
    return sout
  ############################################################################
  ## usage()
  ############################################################################
  def usage(self):
    if (self.logfile): deflog = self.logfile
    else:              deflog = 'stdout'
    print "%s  - Version %s, %s"%(self.basename,self.VERSION,self.VERSDATE)
    print "Usage: %s [options] "%self.basename
    print "       -h ............... shows this help"
    print "       -cfg <cfgfile> ... specify config file(def=%s)"%self.cfgfile
    print "       -log <logfile> ... specify log file(def=%s)"%deflog
    print "       -debug ........... enable debug level logging"
    sys.exit()
  ############################################################################
  ## handleConfig()
  ## 
  ## Setup any defaults at top of routine.
  ## Read in and Handle parsing of Config file
  ## Attributes are set based on Config key names, So for example:
  ## a file like:
  ## [Main]
  ## abc = 7.123   # This is a value
  ## port=9898 
  ## [Aux1]
  ## color=blue
  ## myval=0x14    # Should be set to an int = decimal 20
  ##
  ## Results in the following assignments:
  ## self.main.abc=7.123
  ## self.main.port=9898
  ## self.aux1.color='blue'
  ## self.aux1.myval=20
  ##
  ############################################################################
  def handleConfig(self,allowCaps=False):
    if self.cfgfile=='' or self.cfgfile==None:
      return
    if not os.path.exists(self.cfgfile):
      self.cfgfile=''
      return
    # Open/read config file
    try:
      fp=open(self.cfgfile)
      # Handle backslash at end of line as continuation
      rbuf=fp.read()
      buf=re.sub('\\\\\n','',rbuf)
      fp.close()
    except Exception,ex:
      print "Exception %s"%ex
      return
    lines=buf.split('\n')
    cursec=''  # Start with no section
    for el in lines:
      # Check for new section:
      sre=re.match('\[(.*)\]',el)
      if sre:
        if allowCaps:
          cursec=sre.groups()[0].strip()
        else:
          cursec=sre.groups()[0].strip().lower()
        self.cfgsects.append(cursec)
        setattr(self,cursec,CfgInfo(cursec))  # Start with empty class
      elif el.find('=')>0:  # Only look at lines with assignments
        # Remove comments:
        nc=el.split('#')[0]
        xval=re.search('(^.*?)=(.*)',nc)
        if xval is None:  # Ignore problem lines
          continue
        if cursec=='':
          sec=self
        else:
          sec=getattr(self,cursec) 
        val=xval.groups()[1].strip()
        if allowCaps:
          x=xval.groups()[0].strip()
        else:
          x=xval.groups()[0].strip().lower()

        # Expand any environment variables on right side
        newval=self.exp_env(val)
        # Attempt to convert to numeric or other python type
        try: newval = int(newval)
        except:
          # Adding try as hex, because python 2.4 converts 0xf to float!!
          try: newval = int(newval,16)
          except:
            try: newval = float(newval)
            except:
              try: newval = eval(newval)
              except:
                if newval.lower() == 'true': newval = True
                elif newval.lower() == 'false': newval = False
        # Store the newval in the current section with name x
        setattr(sec,x,newval)
        getattr(sec,"cfgkeys").append(x)
        # Add this to store top-level configs in environment
        #  (I hope this doesn't break anything.... -- rwr )
        if self.envPush and sec==self:
          if type(newval) != type('string'):
            os.environ[x]=str(newval)
          else:
            os.environ[x]=newval
    self.setLogInfo(self)

  ############################################################################
  ## dumpConfig()
  ##    Just display results of cmdline args and config file, then exit
  ############################################################################
  def dumpConfig(self):
    print "Dumping Config from run:\n   %s"%string.join(self.orgargv,' ')
    print "------------------------------------"
    print "self.cfgfile         = %s"%self.cfgfile
    print "self.logfile         = %s"%self.logfile
    print "------------------------------------"
    print "ConfigKeys: %s"%self.cfgkeys
    print "------------------------------------"
    for k in self.cfgkeys:
      print "%s = %s"%(k,getattr(self,k))
    print ""
    print "------------------------------------"
    print "ConfigSects: %s"%self.cfgsects
    print "------------------------------------"
    for s in self.cfgsects:
      if s in dir(self):
        sec=getattr(self,s)
        print "Section %s: "%s
        for k in getattr(sec,"cfgkeys"):
          print "   %s=%s"%(k,getattr(sec,k))
    sys.exit()

  ############################################################################
  ## main()
  ## Mainline code -- really simple...
  ############################################################################
  def main(self):
    print "This is the main routine from the PyCmdApp Base Class"
    print "It is expected to be overriden by your derived class"
      
############################################################################
############################################################################

############################################################################
## ExamplePyCmdApp class
##   This shows an example of how to use the above Class
############################################################################
class ExamplePyCmdApp(PyCmdApp):
  def __init__(self):
    # Initialize Basic Class Application
    PyCmdApp.__init__(self,'exampleApp','1.0.0',"11 Sep 2001")

    # Now define application-specific configs and args
    self.cfgfile=self.exp_env('$HOME/config/example.cfg')
    self.hexArg=self.processArg("-hexArg","hex",default=None)
    self.boolArg=self.processArg("-boolArg")

    # Now call postInit to complete initialization
    self.postInit()  # Handle basic config checks, etc.


  ############################################################################
  ## usage()
  ##   The usage function should be overridden in the derived class
  ############################################################################
  def usage(self):
    print self.usageHdr
    print "NOTE: This is an EXAMPLE App using PyCmdApp"
    print "Usage: %s [options] "%self.basename
    print "       -h ............... shows this help"
    print "       -cfg <cfgfile> ... specify config file(def=%s)"%self.cfgfile
    print "       -hexArg <hex> .... Provide a cmdvalue in hex"
    print "       -boolArg ......... Check a simple boolean flag"
    sys.exit()

  ############################################################################
  ## main()
  ##   The mainline function should be overridden in the derived class
  ############################################################################
  def main(self):
    if self.hexArg != None:
      print "Got hexArg with a value of 0x%0x"%self.hexArg
    if self.boolArg:
      print "boolArg was set"
    else:
      print "boolArg was not set"

##############################################################################
# This allows .py file to be imported, or run directly
##############################################################################
if __name__ == '__main__':
  app=ExamplePyCmdApp()
  app.main()

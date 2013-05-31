program fort_test

  use fort_alsa_read
  use iso_c_binding

  type(alsa_reader) :: ALSA
  integer :: f0
  integer(kind=c_int32_t) :: nbuf
  integer(kind=c_int16_t),allocatable :: buf(:)

  f0 = 8000  
  nbuf = f0
  allocate(buf(nbuf))


  buf = 0
  call alsa_create_recorder(f0,'hw:1,0',ALSA%capture_handle)
  call alsa_get_buffer(ALSA%capture_handle,buf,size(buf))
  print *,'Got buffer'
  call alsa_close_recorder(ALSA%capture_handle)
  print *,'Buffer: ',buf(1:100)

end program fort_test




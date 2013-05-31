module fort_alsa_read

use iso_c_binding

interface
   subroutine alsa_create_recorder(rate,device,handle) bind(C, name='create_recorder')
     use iso_c_binding
     integer(kind=c_int32_t), value :: rate
     character(kind=c_char) :: device
     type(c_ptr) :: handle
   end subroutine alsa_create_recorder

   subroutine alsa_get_buffer(handle, buf, nbuf) bind(C, name='get_sample_buffer')
     use iso_c_binding
     integer(kind=c_int32_t),value :: nbuf
     integer(kind=c_int16_t) :: buf(nbuf)
     type(c_ptr) :: handle
   end subroutine alsa_get_buffer
   
   subroutine alsa_close_recorder(handle) bind(C, name='close_device')
     use iso_c_binding
     type(c_ptr) :: handle
   end subroutine alsa_close_recorder
end interface

type alsa_reader
   type(c_ptr) :: capture_handle
   integer :: buf_size
end type alsa_reader

end module fort_alsa_read

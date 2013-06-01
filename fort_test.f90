

program fort_test

  use fort_alsa_read
  use iso_c_binding
  use hdf5

  implicit none

  type(alsa_reader) :: ALSA
  integer :: f0
  integer(kind=c_int32_t) :: nbuf
  integer(kind=c_int16_t),allocatable :: buf(:)
  integer,allocatable,target :: hdf5_buf(:)

  character(len=*), parameter :: filename = "dsetf.h5"
  character(len=*), parameter :: dsetname = "audio"
  integer(HID_T) :: file_id,dset_id,dspace_id,error_code
  integer :: rank
  integer(HSIZE_T) :: data_dims(2)
  TYPE(C_PTR) :: data_ptr


  f0 = 8000  
  nbuf = f0
  allocate(buf(nbuf))
  allocate(hdf5_buf(nbuf))
  data_ptr = C_LOC(hdf5_buf(1))


  buf = 0
  call alsa_create_recorder(f0,'hw:1,0',ALSA%capture_handle)
  call alsa_get_buffer(ALSA%capture_handle,buf,size(buf))
  print *,'Got buffer'
  call alsa_close_recorder(ALSA%capture_handle)
  print *,'Buffer: ',buf(1:100)

  data_dims(1) = size(buf)
  hdf5_buf(:) = buf(:)
  rank = 1


  call h5open_f(error_code)
  call h5fcreate_f(filename, H5F_ACC_TRUNC_F, file_id, error_code)
  ! to open an existing file:
  !call h5fopen_f(filename, H5F_ACC_RDONLY_F, file_id, error_code)

  call h5screate_simple_f(rank, data_dims, dspace_id, error_code)
  call h5dcreate_f(file_id, "audio", H5T_NATIVE_INTEGER, &
       dspace_id, dset_id, error_code)
  ! dont need this when creating...
  !call h5dopen_f(file_id, dset_name, error_code)
  call h5dwrite_integer_4(dset_id, H5T_NATIVE_INTEGER, hdf5_buf, data_dims, error_code)
  call h5dclose_f(dset_id, error_code)
  call h5sclose_f(dspace_id, error_code)
  call h5fclose_f(file_id, error_code)
  call h5close_f(error_code)

end program fort_test




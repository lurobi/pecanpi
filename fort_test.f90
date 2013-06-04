

program fort_test

  use fort_alsa_read
  use iso_c_binding
  use hdf5
  use hdf_io

  implicit none

  type(alsa_reader) :: ALSA
  integer :: f0
  integer(kind=c_int32_t) :: nbuf
  integer :: jchunk,nchunk
  integer(kind=c_int16_t),allocatable :: buf(:)
  integer,allocatable :: hdf5_buf(:)

  character(len=*), parameter :: filename = "dsetf.h5"
  character(len=*), parameter :: dsetname = "audio"
  integer(HID_T) :: file_id,dset_id,hdferr,crp_list
  integer(HID_T) :: filespace_id,memspace_id
  integer :: rank
  integer(HSIZE_T) :: data_dims(1),max_dims(1),file_dims(1)
  integer(HSIZE_T) :: offset(1), count(1)

  call h5open_f(hdferr)
  f0 = 8000  
  nbuf = f0/2
  allocate(buf(nbuf),hdf5_buf(nbuf))
  buf = 0

  !max_dims(1) = HUGE(max_dims(1)) ! this does... make sure we chunk it!!
  max_dims(1) = 65536*1024

  data_dims(1) = size(hdf5_buf)
  file_dims(1) = 0
  rank = 1

  call hdf_io_create_file(filename, file_id,hdferr)
  call hdf_io_create_dataset(dsetname,file_id,H5T_IEEE_F32LE,rank,max_dims)
  ! get the dataset ID to our dataset
  call h5dopen_f(file_id, dsetname, dset_id, hdferr)
  call h5dget_space_f(dset_id, filespace_id, hdferr)

  ! open a memory dataspace which describes our buffer
  call h5screate_simple_f(rank,data_dims, memspace_id,hdferr)
  

  call alsa_create_recorder(f0,'hw:1,0',ALSA%capture_handle)

  nchunk=10
  do jchunk=1,nchunk
     call alsa_get_buffer(ALSA%capture_handle,buf,size(buf))
     print *,'Got Buffer'
     hdf5_buf(:) = buf(:)
     hdf5_buf(1) = 100000+jchunk
     call hdf_io_append_start(memspace_id,dset_id,filespace_id)
     call h5dwrite_integer_4(dset_id, H5T_NATIVE_INTEGER, hdf5_buf, &
          data_dims, hdferr, memspace_id, filespace_id )
     print *,'Wrote Buffer'
  end do

  call alsa_close_recorder(ALSA%capture_handle)

  call h5dclose_f(dset_id, hdferr)
  call h5sclose_f(memspace_id, hdferr)
  call h5sclose_f(filespace_id, hdferr)
  call h5fclose_f(file_id, hdferr)
  call h5close_f(hdferr)

end program fort_test




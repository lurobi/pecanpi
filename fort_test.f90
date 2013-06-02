

program fort_test

  use fort_alsa_read
  use iso_c_binding
  use hdf5

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
  integer(HSIZE_T) :: data_dims(1),chunk_dims(1),max_dims(1),file_dims(1)
  integer(HSIZE_T) :: offset(1), count(1)


  f0 = 8000  
  nbuf = f0/2
  allocate(buf(nbuf),hdf5_buf(nbuf))
  buf = 0

  max_dims(1) = H5S_UNLIMITED_F ! this doesnt work.. why?
  max_dims(1) = HUGE(max_dims(1)) ! this does... make sure we chunk it!!
  data_dims(1) = size(hdf5_buf)
  file_dims(1) = 0
  chunk_dims(1) = size(buf)/2
  rank = 1

  call h5open_f(hdferr)
  call h5fcreate_f(filename, H5F_ACC_TRUNC_F, file_id, hdferr)
  ! to open an existing file:
  !call h5fopen_f(filename, H5F_ACC_RDONLY_F, file_id, hdferr)

  call h5screate_f(H5S_SIMPLE_F, filespace_id, hdferr)
  call h5sset_extent_simple_f(filespace_id, rank, file_dims, max_dims, hdferr)
  !call h5screate_simple_f(rank, file_dims, dspace_id, hdferr, max_dims)
  ! enable chunking
  call h5pcreate_f(H5P_DATASET_CREATE_F,crp_list, hdferr)
  call h5pset_chunk_f(crp_list, rank, chunk_dims, hdferr)

  call h5dcreate_f(file_id, "audio", H5T_NATIVE_INTEGER, &
       filespace_id, dset_id, hdferr, crp_list)
  ! dont need this when creating...
  !call h5dopen_f(file_id, dset_name, hdferr)

  ! close the dataspace we used to create the file (with unlimited
  ! dimension)
  call h5sclose_f(filespace_id, hdferr)
  ! open a memory dataspace which describes our buffer
  call h5screate_simple_f(rank, data_dims, memspace_id, hdferr)

  call alsa_create_recorder(f0,'hw:1,0',ALSA%capture_handle)

  nchunk=10
  do jchunk=1,nchunk
     call alsa_get_buffer(ALSA%capture_handle,buf,size(buf))
     print *,'Got Buffer'
     hdf5_buf(:) = buf(:)
     hdf5_buf(1) = 100000+jchunk
     count = size(buf)
     offset = file_dims(1)
     file_dims(1) = file_dims(1) + size(buf)
     ! increase the file size
     print *,'Growing HDF file:',file_dims,max_dims
     print *,'Writing hyperslab (offset,count)=',offset,count
     call h5dset_extent_f(dset_id, file_dims, hdferr)
     call h5dget_space_f(dset_id, filespace_id, hdferr)
     call h5sselect_hyperslab_f(filespace_id, H5S_SELECT_SET_F, &
          offset, count, hdferr )
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






program fort_test

  use fort_alsa_read
  use iso_c_binding
  use hdf5
  use hdf_io
  use compat_fft

  implicit none

  type(alsa_reader) :: ALSA
  integer :: f0
  integer(kind=c_int32_t) :: nbuf
  integer :: jchunk,nchunk
  integer(kind=c_int16_t),allocatable :: buf(:)
  integer,allocatable :: hdf5_buf(:)

  character(len=*), parameter :: filename = "dsetf.h5"
  character(len=*), parameter :: dsetname = "audio"
  integer(HID_T) :: file_id,audio_dset_id,spectrum_dset_id,hdferr,crp_list
  integer(HID_T) :: audio_filespace_id,audio_memspace_id
  integer(HID_T) :: spectrum_filespace_id,spectrum_memspace_id
  integer :: rank
  integer(HSIZE_T) :: audio_dims(1),spectrum_dims(2),max_dims(2),file_dims(2)
  integer(HSIZE_T) :: offset(1), count(1)

  type(fft_handle) :: fft

  call h5open_f(hdferr)
  f0 = 8000  
  nbuf = f0/2
  allocate(buf(nbuf),hdf5_buf(nbuf))
  buf = 0

  !max_dims(1) = HUGE(max_dims(1)) ! this does... make sure we chunk it!!
  max_dims = 65536*1024

  spectrum_dims(1) = nbuf
  file_dims(1) = 0
  rank = 1

  call hdf_io_create_file(filename, file_id,hdferr)
  call hdf_io_create_dataset("audio",file_id,H5T_IEEE_F32LE,1,max_dims)
  max_dims(1) = nbuf
  call hdf_io_create_dataset("spectrum",file_id,H5T_IEEE_F32LE,2,max_dims)
  ! get the dataset ID to our dataset
  call h5dopen_f(file_id, "audio", audio_dset_id, hdferr)
  call h5dget_space_f(audio_dset_id, audio_filespace_id, hdferr)
  call h5dopen_f(file_id, "spectrum", spectrum_dset_id, hdferr)
  call h5dget_space_f(spectrum_dset_id, spectrum_filespace_id, hdferr)

  audio_dims(1) = size(hdf5_buf)
  spectrum_dims(1) = nbuf
  ! open a memory dataspace which describes our buffer
  call h5screate_simple_f(1,audio_dims, audio_memspace_id,hdferr)
  call h5screate_simple_f(1,spectrum_dims, spectrum_memspace_id,hdferr)
  

  call fft_plan(fft,size(buf),'forward')

  call alsa_create_recorder(f0,'hw:1,0',ALSA%capture_handle)

  nchunk=10
  do jchunk=1,nchunk
     call alsa_get_buffer(ALSA%capture_handle,buf,size(buf))
     print *,'Got Buffer'
     fft%in = buf
     call fft_execute(fft)
     print *,'FFTd buffer'
     hdf5_buf(:) = buf(:)
     hdf5_buf(1) = 100000+jchunk
     call hdf_io_append_start(audio_memspace_id,audio_dset_id,audio_filespace_id)
     call h5dwrite_integer_4(audio_dset_id, H5T_NATIVE_INTEGER, hdf5_buf, &
          audio_dims, hdferr, audio_memspace_id, audio_filespace_id )

     call hdf_io_append_start(spectrum_memspace_id,spectrum_dset_id,spectrum_filespace_id)
     call h5dwrite_real_4(spectrum_dset_id, H5T_NATIVE_REAL, 10*log(abs(fft%out)), &
          spectrum_dims, hdferr, spectrum_memspace_id, spectrum_filespace_id )
     print *,'Wrote Buffer'
  end do

  call alsa_close_recorder(ALSA%capture_handle)
  call fft_finish(fft)

  call h5dclose_f(audio_dset_id, hdferr)
  call h5dclose_f(spectrum_dset_id, hdferr)
  call h5sclose_f(audio_memspace_id, hdferr)
  call h5sclose_f(spectrum_memspace_id, hdferr)
  call h5sclose_f(audio_filespace_id, hdferr)
  call h5sclose_f(spectrum_filespace_id, hdferr)
  call h5fclose_f(file_id, hdferr)
  call h5close_f(hdferr)

end program fort_test




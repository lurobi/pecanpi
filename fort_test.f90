module pecanpi_input_module

  contains

    subroutine pecanpi_read_input(SPEC,configfile)
      use ini_file_module
      use spec_module
      type(SPEC_struct) :: SPEC
      character(len=128) :: configfile

      type(ini_file_struct) :: INI

      call ini_file_open(INI,configfile)
      SPEC%f0 = ini_read_int(INI,'f0',default=8000)
      SPEC%fft_sec = ini_read_real(INI,'fft_sec',default=0.12)
      print *,'Read fft_sec:',fft_sec
      SPEC%overlap_pct = ini_read_real(INI,'overlap_pct',default=0.0)
      ! handle either [.00 - 1.00] or [01 - 100]
      if(SPEC%overlap_pct .gt. 1.0) SPEC%overlap_pct = SPEC%overlap_pct / 100.0
      SPEC%f_low = ini_read_real(INI,'f_low',default=0.0)
      SPEC%f_high = ini_read_real(INI,'f_high',default=(SPEC%f0/2))
      SPEC%ii_pow_2 = 0 .ne. ini_read_int(INI,'ii_pow_2',default=1)
      call ini_file_close(INI)

    end subroutine pecanpi_read_input

end module pecanpi_input_module

program fort_test

  use fort_alsa_read
  use iso_c_binding
  use hdf5
  use hdf_io
  use compat_fft
  use spec_module
  use pecanpi_input_module

  implicit none

  type(alsa_reader) :: ALSA
  type(SPEC_struct) :: SPEC
  integer :: f0
  integer(kind=c_int32_t) :: nbuf
  integer :: jchunk,nchunk
  integer(kind=c_int16_t),allocatable :: buf(:)
  integer,allocatable :: hdf5_buf(:)

  integer(HID_T) :: file_id,audio_dset_id,hdferr,crp_list
  integer(HID_T) :: audio_filespace_id,audio_memspace_id
  integer :: rank
  integer(HSIZE_T) :: audio_dims(1),max_dims(1),file_dims(1)

  character(len=128) :: configfile,hdffile  

  if( command_argument_count() .ne. 1 ) then
     print *,'Usage: pecanpi config.ini'
     stop
  end if
  call get_command_argument(1,configfile)
  call pecanpi_read_input(SPEC,configfile)

  call h5open_f(hdferr)
  f0 = SPEC%f0
  nbuf = f0/4
  nchunk=nint(10.0/(real(nbuf)/f0))
  print *,'nchunk',nchunk
  allocate(buf(nbuf),hdf5_buf(nbuf))
  buf = 0

  !max_dims(1) = HUGE(max_dims(1)) ! this does... make sure we chunk it!!
  max_dims = nchunk*nbuf

  file_dims(1) = 0
  rank = 1

  call hdf_io_create_file("pecanpi.h5", file_id,hdferr)
  call hdf_io_create_dataset("audio",file_id,H5T_STD_I16LE,1,max_dims)
  !max_dims(1) = nbuf/2
  !call hdf_io_create_dataset("spectrum",file_id,H5T_IEEE_F32LE,2,max_dims)
  ! get the dataset ID to our dataset
  call h5dopen_f(file_id, "audio", audio_dset_id, hdferr)
  call h5dget_space_f(audio_dset_id, audio_filespace_id, hdferr)

  audio_dims(1) = size(hdf5_buf)

  call SPEC_init(SPEC)

  ! open a memory dataspace which describes our buffer
  call h5screate_simple_f(1,audio_dims, audio_memspace_id,hdferr)


  call alsa_create_recorder(f0,'hw:1,0',ALSA%capture_handle)

  do jchunk=1,nchunk
     call alsa_get_buffer(ALSA%capture_handle,buf,size(buf))
     hdf5_buf(:) = buf(:)
     call hdf_io_append_start(audio_memspace_id,audio_dset_id,audio_filespace_id)
     call h5dwrite_integer_4(audio_dset_id, H5T_NATIVE_INTEGER, hdf5_buf, &
          audio_dims, hdferr, audio_memspace_id, audio_filespace_id )

     call SPEC_add_data(SPEC,buf)
  end do

  call alsa_close_recorder(ALSA%capture_handle)

  call h5dclose_f(audio_dset_id, hdferr)
  call h5sclose_f(audio_memspace_id, hdferr)
  call h5sclose_f(audio_filespace_id, hdferr)
  call h5fclose_f(file_id, hdferr)
  call h5close_f(hdferr)

end program fort_test




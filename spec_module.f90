module SPEC_module

  use hdf_io
  use hdf5
  use compat_fft

  type SPEC_struct

     integer :: nsamp_overlap, nsamp_fft, nsamp_new_per_chunk, nsamp_old_per_chunk
     real :: overlap_sec, dT_chunk, dF, f0, fft_sec, overlap_pct, keep_sec
     real :: f_low,f_high

     logical :: ii_pow_2=.true.

     integer :: jchunk0
     integer :: nfreq_keep, nchunk_keep, jf_low, jf_high
     real,allocatable :: spec_data(:,:)
     real,allocatable :: next_fft(:)

     integer :: fft_buf_filled

     type(fft_handle) :: DFT
     type(HDF_io_struct) :: HDF
  end type SPEC_struct

  contains

    subroutine SPEC_init(SPEC)
      implicit none
      type(SPEC_struct) :: SPEC
      integer :: nsamp_to_add

      print *,'Begining SPEC_init'
      ! these should be read from config file
      !SPEC%f0 = 8000
      !SPEC%fft_sec = 0.120
      SPEC%nsamp_fft = nint(SPEC%fft_sec*SPEC%f0)
      !SPEC%overlap_pct = 0.0
      SPEC%keep_sec = 2*60
      !SPEC%f_low = 0.0
      !SPEC%f_high = SPEC%f0/2


      ! adjust fft size to be power of two
      if(SPEC%ii_pow_2) then
         print *,'Changing fft length from ',SPEC%nsamp_fft
         SPEC%nsamp_fft = SPEC%fft_sec * SPEC%f0
         SPEC%nsamp_fft = 2**floor( log2(real(SPEC%nsamp_fft)) + 1 )
         SPEC%fft_sec = SPEC%nsamp_fft / SPEC%f0
         print *,'to ',SPEC%nsamp_fft,SPEC%fft_sec
         !SPEC%overlap_pct = SPEC%nsamp_overlap / SPEC%nsamp_fft
      end if
      ! note: computing overlap after adjusting fft_size... is this what we want?
      SPEC%nsamp_overlap = SPEC%overlap_pct * SPEC%nsamp_fft
      print *,'SPEC%nsamp_overlap',SPEC%nsamp_overlap

      SPEC%nsamp_new_per_chunk = SPEC%nsamp_fft * (1 - SPEC%overlap_pct)
      SPEC%nsamp_old_per_chunk = SPEC%nsamp_fft - SPEC%nsamp_new_per_chunk
      SPEC%dT_chunk = SPEC%nsamp_new_per_chunk / SPEC%f0
      SPEC%nchunk_keep = ceiling(SPEC%keep_sec/SPEC%dT_chunk)
      SPEC%dF = SPEC%f0/SPEC%nsamp_fft

      SPEC%jf_low  = 1 + nint(SPEC%f_low/SPEC%dF)
      SPEC%jf_high = 1 + nint(SPEC%f_high/SPEC%dF)
      SPEC%nfreq_keep = 1 + SPEC%jf_high - SPEC%jf_low

      ! SPEC%spec_data(nfreq_keep, nchunk_keep) will be our data
      ! buffer.  The chunks are different ffts, and adjacent chunks
      ! have dT_chunk seconds between them.  New fft scans are always
      ! added at the end of the array, and old chunks are moved to the
      ! left until they fall off the begining.  jchunk0 is the index
      ! of the last chunk we've processed.  Illustration below shows
      ! the array's window moving forward in time.
      !
      !                    +--jchunk0 (the last processed chunk)
      !  [old0 old1 old2 old3 new4 new5 ]            | previous spec_data(freq,time)
      !       [old1 old2 old3 new4 new5 new6 ]       | new spec data
      !    +--old0 falls off the spec_data array, while new6 is added at the end
      SPEC%jchunk0 = SPEC%nchunk_keep

      !print *,'Allocating spec_data: ',SPEC%nfreq_keep,SPEC%nchunk_keep
      allocate(SPEC%spec_data(SPEC%nfreq_keep,SPEC%nchunk_keep))
      allocate(SPEC%next_fft(SPEC%nsamp_overlap))

      print *,'Planning fft: ',SPEC%nsamp_fft
      call fft_plan(SPEC%DFT,SPEC%nsamp_fft,'forward')
      SPEC%fft_buf_filled = 0
      call SPEC_hdf_init(SPEC)
      print *,'DOne SPEC_init'
      
    end subroutine SPEC_init

    subroutine SPEC_add_data(SPEC,data_in)
      implicit none
      type(SPEC_struct) :: SPEC
      integer(kind=2) :: data_in(:)
      integer :: nsamp_in,nsamp_processed,nsamp_to_add

      nsamp_in = size(data_in)
      nsamp_processed = 0

      print *,'Begining SPEC_add_data',nsamp_in,SPEC%fft_buf_filled,SPEC%nsamp_fft

      do while ( nsamp_processed .lt. nsamp_in )
         nsamp_to_add = min(SPEC%nsamp_fft - SPEC%fft_buf_filled, nsamp_in - nsamp_processed)
         print *,'SPEC_Add_data: adding samples',nsamp_to_add
         SPEC%DFT%in( (SPEC%fft_buf_filled+1) : (SPEC%fft_buf_filled+nsamp_to_add) ) = &
              data_in(nsamp_processed+1 : nsamp_processed+nsamp_to_add)
         nsamp_processed     = nsamp_processed     + nsamp_to_add
         SPEC%fft_buf_filled = SPEC%fft_buf_filled + nsamp_to_add
         print *,'proc fft?',SPEC%fft_buf_filled,SPEC%nsamp_fft
         if(SPEC%fft_buf_filled .eq. SPEC%nsamp_fft) then
            ! we have enough to fft
            
            ! save the overlap data first
            SPEC%next_fft = SPEC%DFT%in(SPEC%nsamp_fft-SPEC%nsamp_overlap:SPEC%nsamp_fft)

            ! slide off our old data
            SPEC%spec_data(:,1:SPEC%nchunk_keep-1) = SPEC%spec_data(:,2:SPEC%nchunk_keep)
            SPEC%jchunk0 = max(SPEC%jchunk0 - 1, 1)
            ! fft the new data
            call fft_execute(SPEC%DFT)
            ! save the spectrum
            SPEC%spec_data(:,SPEC%nchunk_keep) = 20*log10(abs(SPEC%DFT%out(SPEC%jf_low:SPEC%jf_high)))
            ! move the overlap back to our DFT%in buffer
            SPEC%DFT%in(1:SPEC%nsamp_overlap) = SPEC%next_fft(1:SPEC%nsamp_overlap)
            ! reset counters
            SPEC%fft_buf_filled = SPEC%nsamp_overlap
         end if
      end do
      print *,'FFTs processed'
         
      call SPEC_hdf_out(SPEC)
      call SPEC_process_new_chunks(SPEC)

    end subroutine SPEC_add_data

    subroutine SPEC_process_new_chunks(SPEC)
      implicit none
      type(SPEC_struct) :: SPEC
      ! do jchunk=SPEC%jchunk0, SPEC%nchunk_keep
      ! end do
      SPEC%jchunk0 = SPEC%nchunk_keep
    end subroutine SPEC_process_new_chunks

    subroutine SPEC_hdf_init(SPEC)
      use h5lt
      use h5ds
      
      implicit none
      type(SPEC_struct) :: SPEC
      integer(HID_T) :: hdferr,scale_id
      integer(HSIZE_T) :: time_dims(1),freq_dims(1)
      integer :: jF,jT,ntime_keep
      real, allocatable :: freq_ax(:),time_ax(:)
      integer :: step
      
      SPEC%hdf%rank = 2
      allocate(SPEC%hdf%max_dims(SPEC%hdf%rank))
      allocate(SPEC%hdf%mem_dims(SPEC%hdf%rank))
      allocate(SPEC%hdf%file_dims(SPEC%hdf%rank))
      SPEC%hdf%file_dims = (/ SPEC%nfreq_keep, 0 /)
      SPEC%hdf%mem_dims  = (/ SPEC%nfreq_keep, SPEC%nchunk_keep /)
      SPEC%hdf%max_dims  = (/ SPEC%nfreq_keep, nint(3600.0/SPEC%dT_chunk) /) ! one hour max

      step = 1

      ! open the file
      call h5fopen_f( "pecanpi.h5", H5F_ACC_RDWR_F, SPEC%hdf%file_id, hdferr)
      if(hdferr .ne. 0 )goto 20
      step = step + 1

      ! create the dataset
      call hdf_io_create_dataset( "spectrum", SPEC%hdf%file_id, H5T_IEEE_F32LE, &
           SPEC%hdf%rank, SPEC%hdf%max_dims )
      if(hdferr .ne. 0 )goto 20
      step = step + 1

      ! open the data set
      call h5dopen_f( SPEC%hdf%file_id, "spectrum", SPEC%hdf%dset_id, hdferr)
      if(hdferr .ne. 0 )goto 20
      step = step + 1

      ! get the file space
      call h5dget_space_f(SPEC%hdf%dset_id, SPEC%hdf%filespace_id, hdferr)
      if(hdferr .ne. 0 )goto 20
      step = step + 1

      ! create a memory space
      call h5screate_simple_f(SPEC%hdf%rank, SPEC%hdf%mem_dims, SPEC%hdf%memspace_id, hdferr)
      if(hdferr .ne. 0 )goto 20
      step = step + 1

      ! create the scales
      allocate(freq_ax(SPEC%nfreq_keep))
      ntime_keep=3600.0/SPEC%dT_chunk
      allocate(time_ax(ntime_keep))
      freq_ax = (/ (SPEC%dF*(jF-1), jF=SPEC%jf_low,SPEC%jf_high) /)
      time_ax = (/ (SPEC%dT_chunk*(jT-1),jT=1,ntime_keep) /)

      freq_dims = (/SPEC%nfreq_keep/)
      time_dims = (/ntime_keep/)
      print *,'Creating the freq axis',freq_dims
      call h5LTmake_dataset_float_f(SPEC%hdf%file_id,"spectrumFreqAx",&
           1,freq_dims,freq_ax,hdferr)
      if(hdferr .ne. 0 )goto 20
      step = step + 1
      print *,'Creating the time axis',time_dims
      call h5LTmake_dataset_float_f(SPEC%hdf%file_id,"spectrumTimeAx",&
           1,time_dims,time_ax,hdferr)
      if(hdferr .ne. 0 )goto 20
      step = step + 1

      ! attach freq axis
      print *,'Attaching the freq axis'
      call h5Dopen_f(SPEC%hdf%file_id,"spectrumFreqAx",scale_id,hdferr)
      if(hdferr .ne. 0 )goto 20
      step = step + 1
      print *,'Opened'
      call h5DSattach_scale_f(SPEC%hdf%filespace_id,scale_id,1,hdferr)
      if(hdferr .ne. 0 )goto 20
      step = step + 1
      print *,'Attached'
      call h5DSset_label_f(scale_id, 1, "Frequency - Hz",hdferr)
      if(hdferr .ne. 0 )goto 20
      step = step + 1
      print *,'Labeled'
      call h5Dclose_f(scale_id,hdferr)
      if(hdferr .ne. 0 )goto 20
      step = step + 1

      ! attach time axis
      print *,'Attaching the freq axis'
      call h5Dopen_f(SPEC%hdf%file_id,"spectrumTimeAx",scale_id,hdferr)
      if(hdferr .ne. 0 )goto 20
      step = step + 1
      call h5DSattach_scale_f(SPEC%hdf%filespace_id,scale_id,1,hdferr)
      if(hdferr .ne. 0 )goto 20
      step = step + 1
      call h5DSset_label_f(scale_id, 1, "Time - Seconds",hdferr)
      if(hdferr .ne. 0 )goto 20
      step = step + 1
      call h5Dclose_f(scale_id,hdferr)
      if(hdferr .ne. 0 )goto 20
      step = step + 1

      return
      20 continue
      print *,'SPEC_hdf_init: hdf call failed on call num ',step

    end subroutine SPEC_hdf_init

    subroutine SPEC_hdf_out(SPEC)
      implicit none
      type(SPEC_struct) :: SPEC
      integer(HSIZE_T) :: foffset(2),fcount(2)
      integer(HSIZE_T) :: moffset(2),mcount(2)
      integer :: hdferr,nchunk_new,step

      step =1
      nchunk_new = SPEC%nchunk_keep - SPEC%jchunk0
      if(nchunk_new .le. 0) return

      foffset = (/ 0, int(SPEC%hdf%file_dims(2)) /)
      fcount  = (/ SPEC%nfreq_keep, nchunk_new /)

      ! resize the file to include the new data
      SPEC%hdf%file_dims(2) = nchunk_new + SPEC%hdf%file_dims(2)
      call h5dset_extent_f(SPEC%hdf%dset_id, SPEC%hdf%file_dims, hdferr)
      if(hdferr .ne. 0 )goto 20
      step = step + 1
      ! NOTE: we *must* re-get the filespace after set_extent
      call h5dget_space_f(SPEC%hdf%dset_id, SPEC%hdf%filespace_id, hdferr)
      if(hdferr .ne. 0 )goto 20
      step = step + 1

      ! select the new data in the file
      print *,'SPEC: filespace select:',foffset,fcount
      call h5sselect_hyperslab_f(SPEC%hdf%filespace_id, H5S_SELECT_SET_F, &
           foffset, fcount, hdferr )
      if(hdferr .ne. 0 )goto 20
      step = step + 1

      ! select the new data in memory
      moffset = (/ 0, SPEC%jchunk0 /)
      mcount  = (/ SPEC%nfreq_keep, nchunk_new /)
      print *,'SPEC: memspace select:',moffset,mcount
      call h5sselect_hyperslab_f(SPEC%hdf%memspace_id, H5S_SELECT_SET_F, &
           moffset, mcount, hdferr )
      if(hdferr .ne. 0 )goto 20
      step = step + 1

      ! write the memory data to the file
      call h5dwrite_real_4(SPEC%hdf%dset_id, H5T_NATIVE_REAL, SPEC%spec_data, &
           SPEC%hdf%mem_dims, hdferr, SPEC%hdf%memspace_id, SPEC%hdf%filespace_id )
      if(hdferr .ne. 0 )goto 20
      step = step + 1

      return
      20 continue
      print *,'SPEC_hdf_out: hdf call failed on call num ',step

    end subroutine SPEC_hdf_out

    pure elemental function log2(x)
      implicit none
      real,intent(in) :: x
      real :: log2
      log2 = log(x)/log(2.0)
    end function log2

    pure elemental function log10(x)
      implicit none
      real,intent(in) :: x
      real :: log10
      log10 = log(x)/log(10.0)
    end function log10

end module

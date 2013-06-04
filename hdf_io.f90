module hdf_io

use hdf5

logical :: is_hdf_started = .false.

contains
  subroutine hdf_io_create_file(filename, file_id, hdferr)
    implicit none
    character(len=*) :: filename
    integer(HID_T) :: file_id
    integer(HID_T),optional :: hdferr

    call h5fcreate_f(filename, H5F_ACC_TRUNC_F, file_id, hdferr)
  end subroutine hdf_io_create_file

  subroutine hdf_io_create_dataset(dset_name,file_id,data_type,rank,max_dims)
    ! inputs:
    implicit none
    character(len=*) :: dset_name
    integer(HID_T)   :: file_id
    integer(HID_T)   :: data_type
    integer :: rank
    integer(HSIZE_T) :: max_dims(rank)

    integer(HSIZE_T) :: file_dims(rank)
    integer(HSIZE_T) :: chunk_dims(rank)
    integer(HID_T)   :: cprop_list
    integer(HID_T)   :: dset_id,filespace_id,hdferr


    ! create a dataspace (filespace_id)
    call h5screate_f(H5S_SIMPLE_F, filespace_id, hdferr)

    file_dims(:) = 0

    ! specify the rank and dims of the sapce
    call h5sset_extent_simple_f(filespace_id, rank, file_dims, max_dims, hdferr)

    ! enable chunking properties
    call hdf_io_smart_chunking(rank,file_dims,cprop_list)

    ! create the data-set using our dataspace
    call h5dcreate_f(file_id, dset_name, data_type, &
         filespace_id, dset_id, hdferr, cprop_list)

    ! close the dataspace.
    call h5sclose_f(filespace_id, hdferr)

  end subroutine hdf_io_create_dataset

  ! memspace is the INPUT created with h5screate_simple(), which
  ! describes the layout of your data in memory.
  !
  ! dataset_id is the INPUT which identifies the dataset you are about
  ! to write into.
  !
  ! filespace_id is an IN/OUT, and should be provided to h5dwrite_*()
  !
  ! This routine resizes the file, and selects the space in the file
  ! using a hyperslab for the following h5dwrite
  ! ASSUMPTIONS:
  !   -> ALL of memspace is valid data.
  !   Either:
  !     - memspace has one less dimension than filespace, in which
  !       case the last dimension will be added to.
  !       (e.g., mem=(5,10), file=(5,10,10000000) ).
  !    OR
  !     - memspace and filespace have equal rank, but only one of the
  !       dimensions are not equal.
  !       (e.g., mem=(2,3,4,5), file=(2,3,100,5) so 3rd dim is appended to)
  subroutine hdf_io_append_start(memspace,dataset_id, filespace)

    implicit none
    integer(HID_T) :: memspace,dataset_id,filespace
    integer(HSIZE_T) :: rank
    integer(HSIZE_T), allocatable :: memdims(:),memdims_max(:)
    integer(HSIZE_T), allocatable :: filedims(:),filedims_max(:)
    integer(HSIZE_T), allocatable :: foffset(:), fcount(:)
    integer :: append_dim,filerank,memrank
    integer(HID_T) :: hdferr

    ! get the filespace from the dataset.
    !call h5dget_space_f(dataset_id, filespace, hdferr)

    ! determine user's memory space
    call h5sget_simple_extent_ndims_f(memspace,memrank,hdferr)
    allocate(memdims(memrank),memdims_max(memrank))
    call h5sget_simple_extent_dims_f(memspace,memdims,memdims_max,hdferr)

    ! determine the file's space
    call h5sget_simple_extent_ndims_f(filespace,filerank,hdferr)
    allocate(filedims(filerank),filedims_max(filerank))
    allocate(foffset(filerank),fcount(filerank))
    call h5sget_simple_extent_dims_f(filespace,filedims,filedims_max,hdferr)

    print *,'Filedims original: ',filedims

    foffset(:) = 0
    fcount(1:memrank) = memdims(:)
    if (memrank .eq. filerank-1 ) then
       ! assume memory doesn't have last dimension
       foffset(filerank) = filedims(filerank)
       fcount(filerank)  = 1
       filedims(filerank) = filedims(filerank) + 1
    else if (memrank .eq. filerank) then
       if (product(filedims) .eq. 0) then
          ! first time written to the file
          filedims(:) = memdims(:)
       else
          if (count((memdims-filedims) .ne. 0) .gt. 1) then
             print *,'hdf_io: Expected only one dimension not to match!'
             print *,'filedims:',filedims
             print *,'memdims: ',memdims
             stop
          end if
          append_dim = maxloc(abs(memdims-filedims),dim=1)
          foffset(append_dim) = filedims(append_dim)
          filedims(append_dim) = filedims(append_dim) + memdims(append_dim)
       end if
    else
       print *,'hdf_io: Expected memrank .eq. filerank or memrank .eq. filerank-1.'
       print *,'memrank,filerank: ',memrank,filerank
       stop
    end if
    foffset = foffset

    ! resize the file to include the new data
    print *,'Growing fileset to',filedims
    call h5dset_extent_f(dataset_id, filedims, hdferr)
    ! NOTE: we *must* re-get the filespace after set_extent
    call h5dget_space_f(dataset_id, filespace, hdferr)
    ! select the new data.
    print *,'Selecting hyperslab: '
    print *,'foffset: ',foffset
    print *,'fcount: ',fcount
    call h5sselect_hyperslab_f(filespace, H5S_SELECT_SET_F, &
         foffset, fcount, hdferr )

    ! now the user calls:
    !call h5dwrite_integer_4(dset_id, H5T_NATIVE_INTEGER, hdf5_buf, &
    !     data_dims, hdferr, memspace_id, filespace )

  end subroutine hdf_io_append_start

  subroutine hdf_io_smart_chunking(rank, file_dims, crp_list)
    implicit none
    ! input
    integer :: rank
    integer(HSIZE_T) :: file_dims(rank)
    ! output
    integer(HID_T) :: crp_list

    integer, parameter :: max_single_dim = 32768
    integer, parameter :: max_block_size = 65536
    integer, parameter :: min_block_size = 512
    integer(HSIZE_T) :: chunk_dims(rank)
    integer(HID_T) :: hdferr
    integer :: jmax,jmin

    ! start with the file dims
    chunk_dims(:) = file_dims(:)
    ! assume data will grow in the last dimension, so chunk those one at
    ! a time.
    chunk_dims(rank) = 1
    ! assume these dimensions are essentially infinite, so chunk them
    ! one at a time (really, only chunk_dims(rank) is expected to be
    ! this big)
    where (chunk_dims .gt. max_single_dim) chunk_dims=1
    print *,'File DIMS:       ',file_dims
    print *,'1st chunk_dims:  ',chunk_dims
    ! try to fit our chunks in reasonably sized blocks.  if the current
    ! chunk is too big to fit, reduce the chunking in the maximum
    ! dimension by two and try again.
    do while (product(chunk_dims) .lt. min_block_size)
       jmin = minloc(chunk_dims,DIM=1)
       print *,'Growing dim',jmin,chunk_dims(jmin)
       chunk_dims(jmin) = chunk_dims(jmin)*2
    end do
    do while (product(chunk_dims) .gt. max_block_size)
       jmax = maxloc(chunk_dims,DIM=1)
       print *,'Reducing dim',jmax,chunk_dims(jmax)
       chunk_dims(jmax) = chunk_dims(jmax)/2
    end do
    print *,'final chunk_dims:',chunk_dims

    ! finally, create a property list and set the chunking size.
    call h5pcreate_f(H5P_DATASET_CREATE_F,crp_list, hdferr)
    call h5pset_chunk_f(crp_list, rank, chunk_dims, hdferr)
  end subroutine hdf_io_smart_chunking
end module hdf_io

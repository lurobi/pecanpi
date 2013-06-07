module compat_fft

use :: iso_c_binding
include 'fftw3.f03'

type FFT_HANDLE
   type(C_PTR) :: plan ! for fftw
   real(C_FLOAT),allocatable :: in(:)
   complex(C_FLOAT_COMPLEX),allocatable :: out(:)
   integer :: nfft
   logical :: ii_forward
end type FFT_HANDLE

contains
subroutine fft_plan(handle,nfft,direction)
  implicit none
  type(FFT_HANDLE) :: handle
  integer :: fftwdir
  character(len=*) :: direction
  integer :: nfft

  handle%nfft = nfft
  allocate(handle%in(nfft),handle%out(nfft))
  

  if(direction .eq. 'forward') then
     handle%ii_forward=.true.
     fftwdir = FFTW_FORWARD
  else if(direction .eq. 'backward') then
     handle%ii_forward=.false.
     fftwdir=FFTW_BACKWARD
  else
     print *,'compat_fft: direction unrecognized.'
     stop
  end if

  print *,'Planning... '
  handle%plan = fftwf_plan_dft_r2c_1d(nfft, handle%in, handle%out, FFTW_ESTIMATE)
  print *,'Plan complete'
!  call fftw_destroy_plan(handle%plan)
end subroutine

subroutine fft_execute(handle)
  implicit none
  type(FFT_HANDLE) :: handle
  call fftwf_execute_dft_r2c(handle%plan, handle%in, handle%out)
end subroutine fft_execute

subroutine fft_finish(handle)
  implicit none
  type(FFT_HANDLE) :: handle
  call fftwf_destroy_plan(handle%plan)
end subroutine fft_finish
end module compat_fft

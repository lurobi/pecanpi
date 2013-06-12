module ini_file_module

  type ini_file_struct
     integer :: num_lines,num_values
     character(len=1024), dimension(:),allocatable :: names,values
  end type ini_file_struct

  contains

    subroutine ini_file_open(INI,filename)
      implicit none
      type(ini_file_struct) :: INI
      character(len=*) :: filename
      character(len=1024) :: line,var_name,var_value
      integer :: fp,errno,jline,jvar

      INI%num_lines=0
      if(allocated(INI%names)) deallocate(INI%names,INI%values)

      open(newunit=fp,file=filename,ACTION='READ')
      do
         read(fp,"(A)",end=90), line
         INI%num_lines = INI%num_lines + 1
      end do
      90 continue
      rewind(fp)

      allocate(INI%names(INI%num_lines),INI%values(INI%num_lines))
      jline=0
      jvar=0
      do
         read(fp,"(A)",end=100), line
         jline = jline+1
         ! skip comments
         if (line(1:1) .eq. '!') cycle
         if( line(1:1) .eq. '#') cycle
         if (len_trim(line) .eq. 0) cycle
         call str_split(line,'=',var_name,var_value)
         if (len_trim(var_name) .eq. 0) then
            print "(A,I3,A,A)","Warning: Bad INI syntax on line ",jline," of ",trim(filename)
            print *,"Expected: <var> = <val>"
            print *,"Found: ",trim(line)
            cycle
         end if
         jvar = jvar+1
         INI%names(jvar) = var_name
         INI%values(jvar) = var_value
         INI%num_values = jvar
      end do
      100 continue
      close(fp)

      print "(A,I3,A,I3,A,A)","Read ",jvar," Items in ",jline," lines from ",trim(filename)
      
    end subroutine ini_file_open

    function ini_read_int(INI,name,default,found)
      implicit none
      type(ini_file_struct),intent(in) :: INI
      character(len=*),intent(in) :: name
      integer,intent(in), optional :: default
      logical,intent(out),optional :: found
      integer :: ini_read_int
      integer :: jvar,ioerr
      if(present(found)) found = .false.
      do jvar=1,INI%num_values
         if(INI%names(jvar) .eq. name) then
            read (INI%values(jvar),"(I8)",err=100,iostat=ioerr),ini_read_int
            if(present(found)) found = .true.
            return
         end if
      end do
      100 continue
      if(ioerr .ne. 0) then
         print *,'Error reading integer from value: ',name
      end if
      ini_read_int = 0
      if(present(default)) ini_read_int = default
    end function ini_read_int

    subroutine str_split(in,substr,outleft,outright)
      implicit none
      character(len=*) :: in,substr,outleft,outright
      intent(in) :: in,substr
      intent(out) :: outleft,outright

      integer :: pos

      pos = index(in,substr)
      if ( pos .eq. 0 ) then
         outleft = ""
         outright = ""
         return
      end if
      outleft = trim(in(1:pos-1))
      outright = trim(adjustl(in(pos+len_trim(substr):len_trim(in))))

    end subroutine str_split

end module


program test_ini_file
  use ini_file_module
  integer :: tmp
  type(ini_file_struct) :: INI
  call ini_file_open(INI,"test.ini")
  print *,'Done opening'
  tmp = ini_read_int(INI,"freq_low")
  print *,"Read freq_low: ",tmp
  print *,"Read freq_high: ",ini_read_int(INI,"freq_high")
  print *,"Read xxxxx: ",ini_read_int(INI,"spectrum_path")
end program

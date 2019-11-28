module mod_param
  implicit none 
  
  integer, parameter, private :: line_max = 200
  
  type param
     private
     character(len=line_max) :: param_file
     double precision :: fmin, fmax, df
     double precision :: cmin, cmax, dc
     character(len=line_max) :: vmodel_file
   contains
     procedure :: read_file => param_read_file
     procedure :: read_line => param_read_line
     procedure :: read_value => param_read_value
     procedure :: get_fmin => param_get_fmin
     procedure :: get_fmax => param_get_fmax
     procedure :: get_df => param_get_df
     procedure :: get_cmin => param_get_cmin
     procedure :: get_cmax => param_get_cmax
     procedure :: get_dc => param_get_dc
  end type param
  
  interface param
     module procedure init_param
  end interface param



contains
  
  !---------------------------------------------------------------------
  
  type(param) function init_param(param_file) 
    character(len=*), intent(in) :: param_file
 
    init_param%param_file = param_file
    call init_param%read_file()
    
    return 
  end function init_param

  !---------------------------------------------------------------------
    
  subroutine param_read_file(self)
    class(param), intent(inout) :: self
    character(len=line_max) :: line
    integer :: ierr, io

    write(*,*)"Reading parameters from ", trim(self%param_file)

    open(newunit = io, file = self%param_file, &
         & status = 'old', iostat = ierr)
    if (ierr /= 0) then
       write(0,*) "ERROR: cannot open ", trim(self%param_file)
       write(0,*) "     : (param_read_file)"
       stop
    end if
    

    do 
       read(io, '(a)', iostat=ierr) line
       call self%read_line(line)
       if (ierr /= 0) then
          exit
       end if
    end do
    close(io)
    
    return 
  end subroutine param_read_file

  !---------------------------------------------------------------------

  subroutine param_read_line(self, line)
    class(param), intent(inout) :: self
    character(len=line_max), intent(in) :: line
    integer :: i, nlen, j

    nlen = len_trim(line)
    i = 1
    j = index(line(i:nlen), "=")
    if (j == 0) then
       return
    end if
    do while (i <= nlen)
       if (line(i:i) == " ") then
          i = i + 1
          cycle
       end if
       j = index(line(i:nlen), " ")
       if (j /= 0) then
          call self%read_value(line(i:i+j-2))
          i = i + j - 1
       else
          call self%read_value(line(i:nlen))
          return
       end if
    end do

    return 
  end subroutine param_read_line

  !---------------------------------------------------------------------

  subroutine param_read_value(self, str)
    class(param), intent(inout) :: self
    character(len=*), intent(in) :: str
    character(len=line_max) :: name, var
    integer :: nlen, j, itmp
    double precision :: rtmp
    
    
    nlen = len(str)
    j = index(str, "=")
    if (j == 0 .or. j == 1 .or. j == nlen) then
       write(0,*)"ERROR: invalid parameter in ", trim(self%param_file)
       write(0,*)"     : ", str, "   (?)"
       stop
    end if
    
    name = str(1:j-1)
    var = str(j+1:nlen)
    write(*,*)trim(name), " <- ", trim(var)
    if (name == "fmin") then
       read(var, *) rtmp
       self%fmin = rtmp
    else if (name == "fmax") then
       read(var, *) rtmp
       self%fmax = rtmp
    else if (name == "df") then
       read(var, *) rtmp
       self%df = rtmp
    else if (name == "cmin") then
       read(var, *) rtmp
       self%cmin = rtmp
    else if (name == "cmax") then
       read(var, *) rtmp
       self%cmax = rtmp
    else if (name == "dc") then
       read(var, *) rtmp
       self%dc = rtmp
    else if (name == "vmodel_file") then
       self%vmodel_file = var
    else
       write(0,*)"Warnings: Invalid parameter name"
       write(0,*)"        : ", name, "  (?)"
    end if
    return 
  end subroutine param_read_value

  !---------------------------------------------------------------------

  double precision function param_get_fmin(self) result(fmin)
    class(param), intent(inout) :: self

    fmin = self%fmin

    return
  end function param_get_fmin
  
  !---------------------------------------------------------------------

  double precision function param_get_fmax(self) result(fmax)
    class(param), intent(inout) :: self

    fmax = self%fmax

    return
  end function param_get_fmax
  !---------------------------------------------------------------------

  double precision function param_get_df(self) result(df)
    class(param), intent(inout) :: self

    df = self%df

    return
  end function param_get_df
  
  !---------------------------------------------------------------------

  double precision function param_get_cmin(self) result(cmin)
    class(param), intent(inout) :: self

    cmin = self%cmin

    return
  end function param_get_cmin
  
  !---------------------------------------------------------------------

  double precision function param_get_cmax(self) result(cmax)
    class(param), intent(inout) :: self

    cmax = self%cmax

    return
  end function param_get_cmax
  !---------------------------------------------------------------------

  double precision function param_get_dc(self) result(dc)
    class(param), intent(inout) :: self

    dc = self%dc

    return
  end function param_get_dc

  !---------------------------------------------------------------------
  

end module mod_param

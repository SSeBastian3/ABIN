
module mod_water 
   implicit none
   private
   public  :: watpot, check_water
   integer :: watpot=1
   save
   contains
   subroutine check_water(natom, names)
   use mod_utils, only: abinerror
   integer, intent(in)  :: natom
   character(len=2)     :: names(:)
   integer              :: error, iat

   error = 0

   if (modulo(natom,3).ne.0)then
      write(*,*)"Error: Number of atoms is not divisible by 3."
      error=1
   end if

   do iat=1,natom,3
      if(names(iat).ne.'O'.or.names(iat+1).ne.'H'.or.names(iat+2).ne.'H')then
         error=1
         write(*,*)'Bad element type.'
         write(*,*)'Water atoms must be ordered as "O H H" '
      end if
   end do

   if(error.eq.1)then
      write(*,*)'This is not pure water. Exiting...'
      call abinerror('check_water')
   end if

   if (watpot.lt.1.or.watpot.gt.4)then
      ! TODO: Print out what the various option means!
      ! (different water force fields)
      write(*,*)'Error: parameter watpot must be 0,1,2,3 or 4.'
      call abinerror('check_water')
   end if

   end subroutine check_water

end module mod_water


! initial version                         P. Slavicek a kol., Mar 25, 2009
!
!--------------------------------------------------------------------------
module mod_kinetic
   use mod_const, ONLY: DP
   implicit none
   private
   public :: temperature, ekin_v, ekin_p, est_temp_cumul, entot_cumul
   real(DP) :: est_temp_cumul=0.0d0,entot_cumul=0.0d0
   save
   contains
   subroutine temperature(px, py, pz, amt, eclas)
      use mod_const, ONLY:AUtoFS,AUtoK
      use mod_general
      use mod_system,ONLY: dime, f, conatom
      use mod_files, ONLY: UTEMPER, UENERGY
      use mod_nhc,   ONLY: inose,nhcham,calc_nhcham
      use mod_gle,   ONLY: langham
      use mod_shake, only: nshake
      implicit none
      integer :: iw,iat
      real(DP),intent(in)  :: px(:,:),py(:,:),pz(:,:)
      real(DP),intent(in)  :: amt(:,:)
      real(DP),intent(in)  :: eclas
      real(DP)  :: est_temp,temp1,ekin_mom
      real(DP)  :: it2
      
      it2=it/ncalc
      ekin_mom=0.0d0
      do iw=1,nwalk
       do iat=1,natom
        temp1=px(iat,iw)**2+py(iat,iw)**2+pz(iat,iw)**2
        temp1=0.5d0*temp1/amt(iat,iw)
        ekin_mom=ekin_mom+temp1
       enddo
      enddo

      est_temp=2*ekin_mom/(dime*natom*nwalk-nshake-f-dime*conatom)
      if(inormalmodes.eq.1.or.inose.eq.2) est_temp = est_temp / nwalk
      est_temp_cumul=est_temp_cumul+est_temp

      if(ipimd.eq.0)then
       entot_cumul=entot_cumul+eclas+ekin_mom
      endif

      if(modulo(it,nwrite).eq.0)then

         ! Temperature and conserved quantities of thermostats
         write(UTEMPER,'(F15.2,F10.2)',advance="no")sim_time*AUtoFS,est_temp*autok
         if(ipimd.ne.2) write(UTEMPER,'(F10.2)',advance="no")est_temp_cumul*autok/it2

         if(inose.eq.1)then
            call calc_nhcham()
            write(UTEMPER,'(E20.10)',advance="no")nhcham+ekin_mom+eclas
         else if (inose.eq.2.or.inose.eq.3)then
            write(UTEMPER,'(E20.10)',advance="no")langham+ekin_mom+eclas
         end if

         write(UTEMPER,*)

         if (ipimd.ne.1)then
            ! Printing to file energies.dat
            write(UENERGY,'(F15.2,3E20.10)', advance='no')sim_time*AUtoFS,eclas,ekin_mom,eclas+ekin_mom
            if (ipimd.eq.0) write(UENERGY,'(E20.10)',advance="no")entot_cumul/it2
            write(UENERGY,*)
         end if

      endif

      RETURN
   end subroutine temperature


   real(DP) function ekin_v (vx,vy,vz)
      use mod_general, ONLY: nwalk, natom
      use mod_system, ONLY:am
      implicit none
      real(DP),intent(in)  :: vx(:,:),vy(:,:),vz(:,:)
      real(DP)  :: temp1,ekin_mom 
      integer :: iw,iat

      ekin_mom=0.0d0

      do iw=1,nwalk
       do iat=1,natom
        temp1=vx(iat,iw)**2+vy(iat,iw)**2+vz(iat,iw)**2
        temp1=0.5d0*temp1*am(iat)
        ekin_mom=ekin_mom+temp1
       enddo
      enddo

      ekin_v=ekin_mom

      RETURN
      END function ekin_v
!
      real(DP) function ekin_p (px,py,pz)
      use mod_general, ONLY: nwalk, natom
      use mod_system, ONLY:am
      implicit none
      real(DP),intent(in)  :: px(:,:),py(:,:),pz(:,:)
      real(DP)  :: temp1,ekin_mom 
      integer :: iw,iat

      ekin_mom=0.0d0

      do iw=1,nwalk
       do iat=1,natom
        temp1=px(iat,iw)**2+py(iat,iw)**2+pz(iat,iw)**2
        temp1=0.5d0*temp1/am(iat)
        ekin_mom=ekin_mom+temp1
       enddo
      enddo

      ekin_p=ekin_mom

      RETURN
      END function ekin_p

end module mod_kinetic

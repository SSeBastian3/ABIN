!-File with core modules                            created by Daniel Hollas,9.2.2012

! We are using modules to initialize some variables and
! for passing global variables to different subroutines.
!------------------------------------------------------------------------------------

! Exact values for ANG,AUTOKCAL and AUTODEBYE,me,AUTOM,AUTOFS,AMU: 
! Mohr, Taylor, Newell, Rev. Mod. Phys. 80 (2008) 633-730
! and using the thermochemical calorie (1 cal = 4.184 J):'

! TODO: Update physical constant according to the latest data
! https://physics.nist.gov/cuu/Constants/bibliography.html

! ABIN uses atomic units internally
module mod_const
   implicit none
   ! TODO; Separate DP to its own module, mod_kinds
   ! and rename mod_const to mod_phys_const
   INTEGER, PARAMETER  :: DP = KIND(1.0d0)
   ! Exact values of Planck and Avogadro constants according
   ! to the SI redefinition of kilogram in 2019.
   ! TODO: Define all other constants based on base SI units.
   real(DP), parameter :: AVOGADRO = 6.02214076D23
   real(DP), parameter :: PLANCK = 6.626070150D-23
   ! Hartree to Joul converstion according to
   ! https://physics.nist.gov/cuu/Constants/Table/allascii.txt
   real(DP), parameter :: AUTOJ = 4.3597447222071D-18 ! hartree -> J
   real(DP), parameter :: AMU=1822.888484264545d0 ! atomic mass unit 
   real(DP), parameter :: ANG = 1.889726132873D0   ! Angstroms -> Bohrs
   real(DP), parameter :: AUTOFS=0.02418884326505d0 !atomic units to femtosecs
   real(DP), parameter :: PI=3.14159265358979323846d0
   real(DP), parameter :: AUTOK=3.1577464d5 ! temperature in a.u. to Kelvins
   real(DP), parameter :: ME=9.10938215d-31 ! electron mass
   real(DP), parameter :: AUTOM=5.2917720859d-11 ! atomic length
   real(DP), parameter :: AUTOCM=2.1947463d5 ! atomic units to cm-1
   real(DP), parameter :: AUTOKCAL = 6.2750946943D2 ! Ha -> kcal/mol
   real(DP), parameter :: CALTOJ = 4.184D0
   real(DP), parameter :: AUTOKK=3.1577322D5
   real(DP), parameter :: AUTOEV=27.21138386d0
   real(DP), parameter :: AUTODEBYE = 2.54174623d0
   ! Boltzmann constant in a.u., assumed to be 1.0d0 in the program
   real(DP), parameter :: KBinAU = 0.9999999748284666d0
   save
end module mod_const

! mod_array_size contains various array limits.
! Modify here if you need larger arrays.
! Most of the other arrays are allocated dynamically.
module mod_array_size
   use mod_const, only: DP 
   implicit none
   integer,parameter   :: MAXCHAIN=10, MAXTYPES = 10
   integer,parameter   :: NBINMAX=2000, NDISTMAX=30
   integer,parameter   :: NSTMAX=50, NTRAJMAX=1
   save
end module  mod_array_size

! General simulation parameters      
module mod_general
   use mod_const, only: DP
   implicit none
   ! Current time step
   integer :: it = 0
   ! Denotes integrator for equations of motion, see init.F90
   integer :: md = 1
   ! The main switch for the type of dynamics (Clasical MD, PIMD, SH...)
   integer :: ipimd=0
   ! PIMD parameters, staging transformation, number of beads, NM transform
   integer :: istage=0, nwalk=1, inormalmodes=0
   ! Ab-initio potential
   character(len=15) :: pot='none'
   ! Ab initio potential for a reference in Multile time step propagator
   character(len=15) :: pot_ref='none'
   ! imini keyword is mostly deprecated
   integer :: imini = 0
   ! number of time steps (length of simulation)
   integer :: nstep = 1
   ! denotes number of internal steps in RESPA algorithm, see mdstep.f90
   integer :: nabin = 50, nstep_ref = 1
   ! output controls (write the propery every nwriteX step):
   ! general output
   integer :: nwrite = 1
   ! output for XYZ coordinates, velocities and forces (Molden format)
   integer :: nwritex = 1, nwritev = 0, nwritef = 0
   integer :: ncalc = 1
   ! How often do we print restart file and how often do we archive it
   integer :: nrest = 1, narchive = 10000
   ! Restart switch
   integer :: irest = 0
   integer :: icv = 0, anal_ext = 0, idebug = 0
   integer :: ihess
   ! Random number seed
   ! TODO: Default should be set from urandom see:
   ! https://linux.die.net/man/4/urandom
   integer :: irandom = 156873
   ! Number of atoms, taken from XYZ geometry
   integer :: natom = 0
   ! Switch for internal QM/MM, experimental!!
   integer :: iqmmm = 0
   ! Switch for Replica Exchange MD
   integer :: iremd = 0
   ! Internal MPI variables
   integer :: my_rank = 0, mpi_world_size = 1
   ! If you want to set use some exotic settings that we do not normally allow,
   ! set iknow = 1
   integer :: iknow = 0
   ! Linux Process ID, populated automatically for the current ABIN process
   integer :: pid
   ! Future variables for adaptive timestep in SH
   real(DP) :: dt0, sim_time = 0.0d0
   ! Energy restrain MD by Jiri Suchan
   integer  :: en_restraint = 0
   save
end module
      
! Some information about simulated system, especially for distributions and shake
module mod_system
   use mod_const, only: DP
   ! cannot use this
!   use mod_utils, only: abinerror
   implicit none
   ! TODO: move more stuff into Properties derived type
   ! https://kiwi.atmos.colostate.edu/fortran/docs/fortran2012.key-8.pdf
   ! TODO: We should probably move this outside of the modules.f90

   ! Extra electronic properties (not mandatory)
   type Bead_Extra_Properties
      ! PRIVATE ! probably cannot encapsulate due to MPI TC interface
      real(DP), allocatable :: QMcharges(:)
      real(DP), allocatable :: MMcharges(:)
      real(DP), allocatable :: dipole_moment(:,:) ! second argument should be 4
      real(DP), allocatable :: transdipole_moment(:,:) ! second argument should be 4
      real(DP), allocatable :: user_defined(:)    ! let user track anything here
                                                  ! need to specify dimension in
                                                  ! input.in. Output file should
                                                  ! be called magic_property.dat
   end type Bead_Extra_Properties

   type Traj_Properties
      ! Allocate based on number of nwalk
      type(Bead_Extra_Properties), allocatable :: bead_prop(:)
   end type Traj_Properties
   type(Traj_Properties) :: traj_prop, traj_prop_prev

   real(DP), allocatable :: am(:)
   character(len=2), allocatable :: names(:)
   integer, allocatable  :: inames(:)
   integer               :: dime=3 ! dimension of the system 
   integer               :: f = 3  ! number of constants of motion 
                                   ! (for calculating kinetic temperature)
                                   ! sensitive to the type of thermostat
                                   ! currently prob. not implemented correctly
   integer               :: conatom=0 ! number of constrained atoms
   save
   CONTAINS

   ! We should loop over this function over different beads
   !subroutine read_properties(traj_prop)
   ! use mod_general, only: nwalk, natom
   !type(Traj_Properties), intent(inout) :: traj_prop(:)
   !integer :: iw

   ! we should make some generalized reading function in utils
   ! i.e. dipole moments and transition dipolo moments can reuse
   ! (e.g. simply read..) but where should we open the unit? 
   ! but maybe not, these things might be rather different?

   !do iw = 1, nwalk

   !end do

   !end subroutine read_properties

   !subroutine write_properties(traj_prop)
   !type(Traj_Properties), intent(inout) :: traj_prop

   ! should introduce nwriteprop
   ! by default should equal nwritex
   !end subroutine write_properties

   subroutine clean_prop_tempfiles

   call system("rm -f temp_dip.*.dat temp_tdip.*.dat")

   end subroutine clean_prop_tempfiles

   subroutine mass_init(masses, massnames)
   use mod_const,    only: AMU
   use mod_general,  only: natom, my_rank
   real(DP) :: masses(:)
   character(len=2) :: massnames(:)
   integer  :: i
   ! Accurate values for H1 and H2 taken from: 
   ! Mohr, Taylor, Newell, Rev. Mod. Phys. 80 (2008) 633-730
   ! Other atomic weights taken from Handbook of Chemistry and Physics, 2013
   ! Original citation: Wieser, M. E., et al., Pure Appl. Chem. 85, 1047, 2013
   allocate( am(natom) )
   am=-1.0d0
   do i=1,natom
      if(names(i).eq.'H')then
       am(i)=1.008d0
      else if(names(i).eq.'H1')then
       am(i)=1.00782503207d0 
      else if(names(i).eq.'H2'.or.names(i).eq.'D')then
       am(i)=2.01410177785d0
      else if(names(i).eq.'O')then
       am(i)=15.999d0
      else if (names(i).eq.'S')then
       am(i)=32.06d0
      else if (names(i).eq.'SE')then
       am(i)=78.971d0
      else if (names(i).eq.'TE')then
       am(i)=127.60d0
      else if (names(i).eq.'N')then
       am(i)=14.007d0
      else if (names(i).eq.'P')then
       am(i)=30.973761998d0
      else if (names(i).eq.'AS')then
       am(i)=74.921595d0
      else if (names(i).eq.'SB')then
       am(i)=121.760d0
      else if (names(i).eq.'BI')then
       am(i)=208.98040d0
      else if (names(i).eq.'F')then
       am(i)=18.998403163d0
      else if (names(i).eq.'CL')then
       am(i)=35.45d0
      else if (names(i).eq.'BR')then
       am(i)=79.904d0
      else if (names(i).eq.'I')then
       am(i)=126.90447d0
      else if (names(i).eq.'LI')then
       am(i)=6.94d0
      else if (names(i).eq.'NA')then
       am(i)=22.98976928d0
      else if (names(i).eq.'K')then
       am(i)=39.0983d0
      else if (names(i).eq.'BE')then
       am(i)=9.0121831d0
      else if (names(i).eq.'MG')then
       am(i)=24.305d0
      else if (names(i).eq.'CA')then
       am(i)=40.078d0
      else if (names(i).eq.'B')then
       am(i)=10.81d0
      else if (names(i).eq.'AL')then
       am(i)=26.9815385d0
      else if (names(i).eq.'C')then
       am(i)=12.0110d0
      else if (names(i).eq.'SI')then
       am(i)=28.085d0
      else if (names(i).eq.'GE')then
       am(i)=72.630d0
      else if (names(i).eq.'SN')then
       am(i)=118.710d0
      else if (names(i).eq.'PB')then
       am(i)=207.2d0
      else if (names(i).eq.'HE')then
       am(i)=4.002602d0
      else if (names(i).eq.'NE')then
       am(i)=20.1797d0
      else if (names(i).eq.'AR')then
       am(i)=39.948d0
      else if (names(i).eq.'KR')then
       am(i)=83.798d0
      else if (names(i).eq.'XE')then
       am(i)=131.293d0
      else if (names(i).eq.'FE')then
       am(i)=55.845d0
      else if (names(i).eq.'TI')then
       am(i)=47.867d0
      else if (names(i).eq.'V')then
       am(i)=50.9415d0
      else if (names(i).eq.'CR')then
       am(i)=51.9961d0
      else if (names(i).eq.'MN')then
       am(i)=54.938044d0
      else if (names(i).eq.'CO')then
       am(i)=58.933194d0
      else if (names(i).eq.'NI')then
       am(i)=58.6934d0
      else if (names(i).eq.'CU')then
       am(i)=63.546d0
      else if (names(i).eq.'ZN')then
       am(i)=65.38d0
      else if (names(i).eq.'AG')then
       am(i)=107.8682d0
      else if (names(i).eq.'AU')then
       am(i)=196.966569d0
      else if (names(i).eq.'PT')then
       am(i)=195.084d0
      else if (names(i).eq.'CD')then
       am(i)=112.414d0
      else if (names(i).eq.'HG')then
       am(i)=200.592d0
      else if (names(i).eq.'U')then
       am(i)=238.02891d0
      else if (names(i).eq.'TL')then
       am(i)=204.38d0
      else if (names(i).eq.'BA')then
       am(i)=137.327d0
      else if (names(i).eq.'CE')then
       am(i)=140.116d0
      else if (names(i).eq.'CS')then
       am(i)=132.90545196d0
      else if (names(i).eq.'DY')then
       am(i)=162.500d0
      else if (names(i).eq.'ER')then
       am(i)=167.259d0
      else if (names(i).eq.'EU')then
       am(i)=151.964d0
      else if (names(i).eq.'GD')then
       am(i)=157.25d0
      else if (names(i).eq.'GA')then
       am(i)=69.723d0
      else if (names(i).eq.'HF')then
       am(i)=178.49d0
      else if (names(i).eq.'HO')then
       am(i)=164.93033d0
      else if (names(i).eq.'IN')then
       am(i)=114.818d0
      else if (names(i).eq.'IR')then
       am(i)=192.217d0
      else if (names(i).eq.'LA')then
       am(i)=138.90547d0
      else if (names(i).eq.'LU')then
       am(i)=174.9668d0
      else if (names(i).eq.'MO')then
       am(i)=95.95d0
      else if (names(i).eq.'ND')then
       am(i)=144.242d0
      else if (names(i).eq.'NB')then
       am(i)=92.90637d0
      else if (names(i).eq.'OS')then
       am(i)=190.23d0
      else if (names(i).eq.'PD')then
       am(i)=106.42d0
      else if (names(i).eq.'PR')then
       am(i)=140.90766d0
      else if (names(i).eq.'PA')then
       am(i)=231.03588d0
      else if (names(i).eq.'RE')then
       am(i)=186.207d0
      else if (names(i).eq.'RH')then
       am(i)=102.90550d0
      else if (names(i).eq.'RB')then
       am(i)=85.4678d0
      else if (names(i).eq.'RU')then
       am(i)=101.07d0
      else if (names(i).eq.'SM')then
       am(i)=150.36d0
      else if (names(i).eq.'SC')then
       am(i)=44.955908d0
      else if (names(i).eq.'SR')then
       am(i)=87.62d0
      else if (names(i).eq.'TA')then
       am(i)=180.94788d0
      else if (names(i).eq.'TB')then
       am(i)=158.92535d0
      else if (names(i).eq.'TH')then
       am(i)=232.0377d0
      else if (names(i).eq.'TM')then
       am(i)=168.93422d0
      else if (names(i).eq.'W')then
       am(i)=183.84d0
      else if (names(i).eq.'YB')then
       am(i)=173.054d0
      else if (names(i).eq.'Y')then
       am(i)=88.90584d0
      else if (names(i).eq.'ZR')then
       am(i)=91.224d0
      else 
         print *,'Atom name ',names(i),' was not found in the library.'
         print *,'I hope you specified the mass in namelist "system"'
      endif
   enddo

   call init_usermass()

   do i=1,natom
     if(am(i).le.0)then
        write(*,*)'ERROR: Some masses were not specified. Exiting...'
        call finish(1)
        stop 1
     end if
   end do

   if (natom.le.100.and.my_rank.eq.0)then
      print *,''
      print *,'-------------------ATOMIC MASSES----------------------------'
      do i=1,natom
         write(*,'(A2, A1)',advance='no')names(i),' '
      end do
      write(*,*)
      print *,'The corresponding relative atomic masses are:'
      write(*,*)(am(i),i=1,natom)
      print *,'------------------------------------------------------------'
   end if

   ! Finally, convert masses to atomic units
   am = am * AMU

   CONTAINS

   subroutine init_usermass()
   integer :: iat, j
      
   do i=1,size(massnames)
      do j=i+1,size(massnames)
         if (massnames(i).eq.massnames(j))then
            if((masses(i).gt.0.or.masses(j).gt.0))then
               write(*,*)'ERROR: ambiguous user input for masses.'
               write(*,*)'Please, take a hard look at the input arrays "masses" and "massnames"'
               call finish(1)
            end if
         end if
       end do
   end do

   do iat=1,natom
      do j=1,size(massnames)
      if (names(iat).eq.massnames(j))then

         if (masses(j)>0)then
            write(*,*)'Defining new atom ',names(iat),' with mass=',masses(j)
            am(iat)=masses(j)
         else
            write(*,*)'Mass cannot be negative. Please, fix arrays "masses" or "mass_names" in your input.'
         end if

      end if
      end do
   end do

   end subroutine init_usermass

   end subroutine mass_init


end module mod_system

! module for permanent file handling
module mod_files
   implicit none
   public
   private            :: CHFILES
   ! Defines maximum number of units available for permanently opened files
   integer, parameter :: MAXUNITS=50, MAXFILENAME=50 
   character(len=MAXFILENAME)  :: CHFILES(MAXUNITS)

   ! UNIT 1 is reserved for CP2K!!!
   integer, parameter :: UMOVIE=10, UVELOC=2, UFORCE=15
   integer, parameter :: UENERGY=3, UTEMPER=4
   integer, parameter :: URADIUS=11
   ! PIMD stuff
   integer, parameter :: UESTENERGY=12, UCV=13, UCVDCV=14
   ! Surface hopping stuff
   integer, parameter :: UPOP=20, UPROB=21, UPES=22
   integer, parameter :: UDOTPROD=23, UNACME=24, UWFCOEF=25
   integer, parameter :: UPHASE=26, UBKL=27
   ! So far only for TeraChem
   integer, parameter :: UDOTPRODCI=31, UCHARGES=32
   integer, parameter :: UDIP = 33, UTDIP = 34
   integer, parameter :: UWFN = 35 ! this one is not permanently opened
   ! Analysis output
   integer, parameter :: UDIST = 36, UANG = 37, UDIH = 38
   save

   CONTAINS

   SUBROUTINE files_init(isbc, phase, ndist, nang, ndih)
   use mod_general
   use mod_system, only: names
   integer, intent(in)  :: isbc, phase, ndist, nang, ndih
   character(len=10)    :: chaccess
   integer              :: i

   do i=1, MAXUNITS
      chfiles(i)=''
   end do

   chfiles(UVELOC)='velocities.xyz'
   chfiles(UFORCE)='forces.xyz'
   chfiles(UENERGY)='energies.dat'
   chfiles(UTEMPER)='temper.dat'

!  radius for spherical boundary conditions
   chfiles(URADIUS)='radius.dat'

!  Files for PIMD estimators
   chfiles(UESTENERGY)='est_energy.dat'
   chfiles(UCV)='cv.dat'
!  file for advanced cv estimator
   chfiles(UCVDCV)='cv_dcv.dat'

!  Files for Surface Hopping
   chfiles(UPOP)='pop.dat'
   chfiles(UPROB)='prob.dat'
   chfiles(UPES)='PES.dat'
   chfiles(UDOTPROD)='dotprod.dat'
   chfiles(UNACME)='nacm_all.dat'
   chfiles(UWFCOEF)='wfcoef.dat'
   chfiles(UPHASE)='phase.dat'
   chfiles(UBKL)='bkl.dat'
!  Files for TeraChem SH interface
   chfiles(UCHARGES)='charges.dat'
   chfiles(UDIP)='dipoles.dat'
   chfiles(UTDIP)='trans_dipoles.dat'
   chfiles(UDOTPRODCI)='dotprodci.dat'

!  Geometry analysis output
   chfiles(UDIST)='distances.dat'
   chfiles(UANG)='angles.dat'
   chfiles(UDIH)='dihedrals.dat'

   ! Here we ensure, that previous files are deleted
   if(irest.eq.0)then
      chaccess='SEQUENTIAL'
   else
      chaccess='APPEND'
   endif

   chfiles(UMOVIE)='movie.xyz'

   if(iremd.eq.1)then
      do i=1, MAXUNITS
         write(chfiles(i),'(A,I2.2)')trim(chfiles(i))//'.', my_rank
      end do
   end if

!  OPEN trajectory file
!  Trajectory file is opened later in output function trajout
!  to prevent creating empty movie.xyz and then failing
!  We still open when using CP2K interface, since otherwise 
!  strangely more MPI ranks can write to this file if not opened here...
!   if(pot.eq.'_cp2k_')then
!      open(UMOVIE,file=chfiles(UMOVIE),access=chaccess,action='write')
!   end if

   if (nwritev.gt.0)then
!      if(iremd.eq.1)then
!         write(chout,'(A,I2.2)')'vel.dat.',my_rank
!      else
!         chout='vel.dat'
!      end if
      open(UVELOC,file=chfiles(UVELOC),access=chaccess,action='write')
   endif

   if (nwritef.gt.0) open(UFORCE,file=chfiles(UFORCE),access=chaccess,action='write')


   if (ipimd.ne.1)then
      open(UENERGY,file=chfiles(UENERGY),access=chaccess,action='write')
      write(UENERGY,*)'#        Time[fs] E-potential           E-kinetic     E-Total    E-Total-Avg'
   end if

   if(ipimd.eq.1)then
      open(UESTENERGY,file=chfiles(UESTENERGY),access=chaccess,action='write')
      write(UESTENERGY,*)'#     Time[fs] E-potential  E-primitive   E-virial  CumulAvg_prim  CumulAvg_vir'
   endif

   open(UTEMPER,file=chfiles(UTEMPER), access=chaccess, action='write')
   write(UTEMPER,*)'#      Time[fs] Temperature T-Average Conserved_quantity_of_thermostat'

   if(ipimd.eq.5)then
      open(UPES,file=chfiles(UPES),access=chaccess,action='write')
      write(UPES,*)'#    Time[fs] Potential energies (singlets, triplets)'
      open(UPOP,file=chfiles(UPOP),access=chaccess,action='write')
      write(UPOP,*)'#    Time[fs] CurrentState   Populations Sum-of-Populations'
   endif

   if(ipimd.eq.2)then
      open(UPOP,file=chfiles(UPOP),access=chaccess,action='write')
      write(UPOP,*)'#    Time[fs] CurrentState   Populations Sum-of-Populations'
      open(UPROB,file=chfiles(UPROB),access=chaccess,action='write')
      write(UPROB,*)'#    Time[fs] CurrentState   Probabilities'
      open(UPES,file=chfiles(UPES),access=chaccess,action='write')
      write(UPES,*)'#    Time[fs] Potential energies'
      open(UNACME,file=chfiles(UNACME),access=chaccess,action='write')
      open(UDOTPROD,file=chfiles(UDOTPROD),access=chaccess,action='write')
      write(UDOTPROD,*)'#    Time[fs] dotproduct(i,j) [i=1,nstate-1;j=i+1,nstate]'
      if(idebug.gt.1)then
         open(UBKL,file=chfiles(UBKL),access=chaccess,action='write')
         write(UBKL,*)'# Hopping probabilities - bkl(i) [i=1,nstate]'
         open(UWFCOEF,file=chfiles(UWFCOEF),access=chaccess,action='write', recl=250)
         write(UWFCOEF,*)'# WF coefficients c_real(i),i=1,nstate c_imag(i),i=1,nstate'
         if(phase.eq.1)then
            open(UPHASE,file=chfiles(UPHASE),access=chaccess,action='write')
            write(UPHASE,*)'# Lower triangular matrix of gamma (phase)  gamma(i,j) [i=1,nstate ;j=1,i-1]'
         end if
      endif

      if(pot.eq.'_tera_')then
         open(UCHARGES,file=chfiles(UCHARGES),access=chaccess,action='write')
         write(UCHARGES,*)'# Atomic charges from current electronic state'
         write(UCHARGES,*)'# Time  st ',(names(i),i=1,natom)
         open(UDOTPRODCI,file=chfiles(UDOTPRODCI),access=chaccess,action='write')
         write(UDOTPRODCI,*)'# Dot products between current and previous CI vectors.'
         write(UDOTPRODCI,*)'# Time  cidotprod1  cidotprod2 ... '
         open(UDIP,file=chfiles(UDIP),access=chaccess,action='write')
         write(UDIP,*)'# Time  dip_tot.1 dip_tot.2 ... dip_x.1 dip_y.1 dip_z.1 dip_x.2 dip_y.2 dip_z.2.'
         open(UTDIP,file=chfiles(UTDIP),access=chaccess,action='write')
         write(UTDIP,*)'# Time  st  tdip_tot.1 tdip_tot.2 ... tdip_x.1 tdip_y.1 tdip_z.1 tdip_x.2 tdip_y.2 tdip_z.2.'
      end if
   endif

   if(isbc.eq.1)then
      open(URADIUS,file=chfiles(URADIUS),access=chaccess,action='write')
      write(URADIUS,*)'#TimeStep     Radius[ANG]   approximate density[kg.m^3]'
   endif

   if(icv.eq.1)then
      open(UCV,file=chfiles(UCV),access=chaccess,action='write')
      write(UCV,*)'#         Time[fs]  Cv-prim   Cv-vir  Cv_cumul_prim  Cv_cumul_vir'
      if(ihess.eq.1)then
         open(UCVDCV,file=chfiles(UCVDCV),access=chaccess,action='write')
         write(UCVDCV,*)'#         Time[fs]  Cv-DCV   Cv_cumul_DCV'
      endif
   endif

   ! Analysis
   if(ndist.gt.0)then
      open(UDIST, file=chfiles(UDIST), access=chaccess, action='write')
      write(UDIST,'(A)')"# Distances [Angstrom]"
   end if
   if(nang.gt.0)then
      open(UANG, file=chfiles(UANG), access=chaccess, action='write')
      write(UANG,'(A)')"# Angles [Degree]"
   end if
   if(ndih.gt.0)then
      open(UDIH, file=chfiles(UDIH), access=chaccess, action='write')
      write(UDIH,'(A)')"# Dihedral Angles [Degree]"
   end if

   end subroutine files_init


end module mod_files

module mod_chars
   character(len=*),parameter :: chknow='If you know what you are doing, &
    &set iknow=1 (namelist general) to proceed.'

end module mod_chars

# Super simple Makefile for ABIN

# The user-defined variables are included from file "make.vars',
# which is not under version control
# No user modification to this Makefile file should be necessary.

# Simply type "make" and you should get the binary named $BIN
# Before recompiling, it is wise to clean up by "make clean"

# WARNING: dependecies on *.mod files are not properly resolved here!
# If you change modules, you should recompile the whole thing by running
# $ make clean && make

# For compilation with static system libraries, see:
# https://gcc.gnu.org/bugzilla/show_bug.cgi?id=46539

# Some defaults, likely to be overwritten by make.vars
# By default run all tests in TESTS/
TEST=all
# ABIN binary name
BIN=abin
# Optional compilation parameters
# Some functionality will not work without them
MPI=FALSE
FFTW=FALSE
CP2K=FALSE
PLUMED=FALSE

# Export all vars into submake commands
export
# User-defined compilation parameters are in make.vars
# and should override defaults defined above
include make.vars

export SHELL=/bin/bash
export DATE=`date +"%X %x"`

# TODO: Make this ifeq less stupid,
# We should not presume that Git is available
# and if it is, we need to actually verify we're in a Git repo
ifeq ($(shell git --version|cut -b -3),git)
export COMMIT=`git log -1 --pretty=format:"commit %H"`
endif

F_OBJS := arrays.o transform.o potentials.o estimators.o gle.o ekin.o vinit.o plumed.o \
          force_bound.o water.o force_cp2k.o sh_integ.o surfacehop.o landau_zener.o\
          force_tera.o force_terash.o force_abin.o en_restraint.o analyze_ext_template.o density.o analysis.o \
          minimizer.o mdstep.o forces.o

# TODO: Rename libttm.a to libwater.a
STATIC_LIBS = WATERMODELS/libttm.a

ifeq ($(strip $(FFTW)),TRUE)
  ifneq ($(CP2K),TRUE)
   LIBS := -lfftw3 ${LIBS}
  endif
  DFLAGS += -DUSEFFTW
  F_OBJS := fftw_interface.o ${F_OBJS}
endif

ifeq ($(strip $(CP2K)),TRUE)
  DFLAGS += -DCP2K 
  FFLAGS += -fno-underscoring 
  # OpenMP does not work with -fno-underscoring
  FFLAGS += -fno-openmp
  # The following variables should be the same that were used to compile CP2K.
  # Also, be carefull with FFTW clashes
  LIBS += -L${CP2K_PATH} -lcp2k ${CP2K_LIBS} 
ifeq ($(strip $(FFTW)),TRUE)
   $(info "!!!!!-------------WARNING---------------!!!!!!!")
   $(info "Using FFTW flag with CP2K may lead to troubles!")
   $(info "!!!!!-------------WARNING---------------!!!!!!!")
   $(info "")
endif
endif

ifeq ($(strip $(PLUMED)),TRUE)
 include ${PLUMED_LINK}
 # TODO: Rename to USEPLUMED
 DFLAGS += -DPLUM
 STATIC_LIBS += ${PLUMED_STATIC_LOAD}
endif

ifeq  ($(strip $(MPI)),TRUE) 
  # TODO: Rename to USEMPI
  DFLAGS += -DMPI
  INC    += $(MPI_INC)
  LIBS   += $(MPI_LIBS)
  F_OBJS := remd.o ${F_OBJS}
endif

LDLIBS = -lm -lstdc++ ${LIBS}
# The following line does not seem to work
#LDLIBS = ${LIBS} -static-libgfortran -Wl,-Bstatic -lstdc++ -lm -Wl,-Bdynamic  

# Adding rest of the Fortran objects
# This hack is needed for force_tera.o and fftw_interface.o
F_OBJS := modules.o utils.o fortran_interfaces.o io.o force_mm.o random.o shake.o nosehoover.o  ${F_OBJS}

ifneq ($(strip $(CP2K)),TRUE)
   F_OBJS := ${F_OBJS} WATERMODELS/water_interface.o
endif

# This is the default target
# TODO: Make abin.o the default target, and put the compile info module there?
${BIN} : init.o
	# TODO: Separate this step and do it properly (via libttm.a dependency)
	$(MAKE) -C WATERMODELS all
	# TODO: Once abin.o is the default target, remove it from line below
	${FC} ${FFLAGS} ${F_OBJS} ${STATIC_LIBS} abin.o $< ${LDLIBS} -o $@
	# Build Unit Tests if pFUnit library is available
	# (run install_pfunit.sh to install it)
ifneq ($(strip $(PFUNIT_PATH)),)
	ar cru libabin.a init.o $(F_OBJS) && ranlib libabin.a
	$(MAKE) -C unit_tests all
endif

# Build and run Unit tests
unittest : ${BIN}
	$(MAKE) -C unit_tests all
	$(MAKE) -C unit_tests test

# Always recompile init.F90 to get current date and commit
# TODO: Figure out a cleaner way to do this
# TODO: We should move this into abin.F90
init.o : init.F90 ${F_OBJS} abin.o
	$(FC) $(FFLAGS) $(DFLAGS) $(INC) -DCOMPILE_DATE="'${DATE}'" -DGIT_COMMIT="'${COMMIT}'" -c init.F90

clean :
	$(MAKE) -C WATERMODELS clean
	/bin/rm -f *.o *.mod libabin.a $(BIN)
ifneq ($(strip $(PFUNIT_PATH)),)
	$(MAKE) -C unit_tests clean
endif

# Run the test suite
# TODO: Pass MPI_PATH as well
# TODO: This invocation of TESTS/test.sh is extremely brittle, because
# it relies that all pamaraters (e.g. FFTW) are defined and not empty
# For now, we define defaults for them at the top, before including make.vars
test : ${BIN}
ifneq ($(strip $(PFUNIT_PATH)),)
	$(MAKE) -C unit_tests test
endif
	/bin/bash TESTS/test.sh ${BIN} $(TEST) ${MPI} ${FFTW} ${PLUMED} ${CP2K}

# Clean all test folders.
testclean :
	/bin/bash TESTS/test.sh ${BIN} clean ${MPI} ${FFTW} $(PLUMED) ${CP2K}

# This will automatically generate new reference data for tests
makeref :
	/bin/bash TESTS/test.sh ${BIN} $(TEST) ${MPI} ${FFTW} $(PLUMED) ${CP2K} makeref

# Dummy target for debugging purposes
debug :
	echo ${LIBS}
	echo ${INC}
	echo ${DFLAGS}
	echo ${CFLAGS}
	echo ${FFLAGS}

.PHONY: clean test testclean makeref debug unittest

.SUFFIXES: .F90 .f90 .f95 .f03 .F03

# TODO: Use only .F90
.F90.o:
	$(FC) $(FFLAGS) $(DFLAGS) $(INC) -c $<

.f90.o:
	$(FC) $(FFLAGS) $(DFLAGS) $(INC) -c $<

.f95.o:
	$(FC) $(FFLAGS) $(DFLAGS) $(INC) -c $<

.f03.o:
	$(FC) $(FFLAGS) $(DFLAGS) $(INC) -c $<

.F03.o:
	$(FC) $(FFLAGS) $(DFLAGS) $(INC) -c $<


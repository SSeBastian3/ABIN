#!/bin/bash

#---------------------------------------------------------------------------------
#  Create_Trajectories                   Daniel Hollas, Ondrej Svoboda 2014

# This script generates and executes a set of dynamical trajectories using ABIN.
# It accepts EITHER:
# i)  Initial conditions from Wigner distribution generated by script wigner_sampling.sh.
#     This mode assumes irest=1 in input.in!
# ii) Initial geometries from a XYZ movie file (taken sequentially)
#     This mode assumes irest=0 in input.in!
#     You can also provide initial velocities (taken sequentially from input file).

# The script is designed both for surface hopping and adiabatic AIMD.

# The trajectories are executed and stored in $folder.

# Files needed in this folder:
#	$INPUTDIR : template directory with ABIN input files (mainly input.in and r.abin)
#	make_restart : if you need initial conditions from Wigner
# 	abin-randomint program should be in your $PATH.
#---------------------------------------------------------------------------------

#######-----SETUP---#############
irandom0=-1          # random seed, set negative for random seed based on time
mode="movie"         # ="wigner"  - take initial conditions from Wigner distributions.  (irest=1)
                     # ="movie"   - take initial geometries sequentially from XYZ movie.
movie=geoms.xyz      # PATH TO a XYZ movie with initial geometries
veloc=velocs.dat     # leave blank if you do not have velocities
PATHTOWIGNER=""      # path to wigner "trajectories"
isample=1	     # initial number of traj
nsample=100	     # number of trajectories
INPUTDIR=TRAJS-TEMPLATE-QCHEM   # Directory with input files for ABIN
abin_input=$INPUTDIR/input.in   # main input file for ABIN
launch_script=$INPUTDIR/r.abin	# this is the file that is submitted by qsub

# Following variables can be determined automatically from input for SurfHop simulations
# For adiabatic AIMD, set initialstate and nstate equal to 1
initialstate=$(awk -F"[! ,=]+" '{if($1=="istate_init")print $2}' $abin_input) #initial state for SH
nstate=$(awk -F"[! ,=]+" '{if($1=="nstate")print $2}' $abin_input)   #total number of electronic states
natom=$(awk -F"[! ,=]+" '{if($1=="natom")print $2}' $abin_input) #number of atoms


folder=MP2           # Name of the folder with trajectories
molname=waterdimer   # Name of the job in the queue
abinexe=/home/hollas/PHOTOX/bin/abin      # path to abin binary
submit="qsub -q nq -cwd  " # -q sq-* "    # comment this line if you don't want to submit to queue yet
rewrite=0            # if =1 -> rewrite trajectories that already exist
jobs=29              # number of batch jobs to submit. Trajectories will be distributed accordingly.



## If you need to process the input via cut_sphere, adjust the following command
# cut="cut_sphere -u 4 -v 3" # cut command, velocity file is handled automatically if needed
# (Do not provide file names.)
##########END OF SETUP##########


function Folder_not_found {
   echo "Error: Folder $1 does not exists!"
   exit 1
}

function File_not_found {
   echo "Error: File $1 does not exists!"
   exit 1
}

function Error {
   echo "Error from command $1. Exiting!"
   exit 1
}

if [[ "$mode" = "wigner" ]] && [[ ! -d "$PATHTOWIGNER" ]];then
   Folder_not_found $PATHTOWIGNER
fi

if [[ ! -d $INPUTDIR ]];then
   Folder_not_found $INPUTDIR
fi

if [[ "$mode" = "movie" ]] && [[ ! -f "$movie" ]];then
   File_not_found $movie
fi

if [[ ! -z "$veloc" ]] && [[ "$mode" = "movie" ]] && [[ ! -f "$veloc" ]];then
   File_not_found $veloc
fi

if [[ ! -e $abinexe ]];then
   File_not_found $abinexe
fi

if [[ ! -e $abin_input ]];then
   File_not_found $abin_input
fi

if [[ ! -e "make_restart" && "$mode" = "wigner" ]];then
   File_not_found "make_restart"
fi

if [[ ! -e "$launch_script" ]];then
   File_not_found "$launch_script"
fi

if [[ -e "mini.dat" ]] || [[ -e "restart.xyz" ]];then
   echo "Error: Files mini.dat and/or restart.xyz were found here."
   echo "Please remove them."
   exit 1
fi

#----------------------------------------------------------------------------------------
#   This is where the magic happens.

echo "Number of atoms = $natom"
if [[ ! -z $initialstate ]];then
   echo "Initial electronic state for SH simulations = $initialstate"
fi
if [[ ! -z $nstate ]];then
   echo "Number of electronic states in SH simulations = $nstate"
fi

if [[ -e $folder/$molname$isample.*.sh ]];then
   echo  "Error: File $folder/$molname$isample.*.sh already exists!"
   exit 1
fi

# determine number of ABIN simulations per job
let nsimul=nsample-isample+1
if [[ $nsimul -le $jobs ]];then
   remainder=0
   injob=1
   jobs=nsimul
else
   let injob=nsimul/jobs  #number of simulations per job
   #determine the remainder and distribute it evenly between jobs
   let remainder=nsimul-injob*jobs
fi

pwd=$(pwd)

j=1
i=$isample

let natom2=natom+2
let natom1=natom+1

#--------------------generation of random numbers--------------------------------
echo "Generating $nsample random integers."
abin-randomint $irandom0 $nsample > iran.dat
if [[ $? -ne "0" ]];then
   Error "abin-randomint"
fi

#--------------------------------------------------------------------------------

mkdir -p $folder
cp iseed0 "$abin_input" $folder

let offset=natom2*isample-natom2
let offsetvel=natom1*isample-natom1
while [[ $i -le "$nsample" ]];do

   let offset=offset+natom2   # for mode=movie
   let offsetvel=offsetvel+natom1   # for mode=movieveloc

   if [[ -e "$folder/TRAJ.$i" ]];then
      if [[ "$rewrite" -eq "1" ]];then

         rm -r $folder/TRAJ.$i ; mkdir $folder/TRAJ.$i

      else

         echo "Trajectory number $i already exists!"
         echo "Exiting..."
         exit 1

      fi

   else

      mkdir $folder/TRAJ.$i

   fi

   cp -r $INPUTDIR/* $folder/TRAJ.$i


#--- Now prepare mini.dat (and possibly restart.xyz)

   if [[ $mode = "movie" ]];then
      head -$offset $movie | tail -$natom2 > geom
      if [[ ! -z "$veloc" ]];then
         head -$offsetvel $veloc | tail -$natom1 > veloc.in
      fi
#--- Perform cutting, if needed.
      if [[  ! -z "$cut" ]];then
         if [[ ! -z "$veloc" ]];then
            $cut -vel veloc.in < geom
         else
            $cut
         fi
         if [[ $? -ne "0" ]];then
            Error "$cut"
         fi

      cp cut_qm.xyz geom
      cp veloc.out veloc.in
      fi

      mv geom $folder/TRAJ.$i/mini.dat

      if [[ ! -z "$veloc" ]];then
         mv veloc.in $folder/TRAJ.$i/
      fi

   elif [[ "$mode" = "wigner" ]];then
      ./make_restart -wig $PATHTOWIGNER/FMSINPOUT/Geometry.dat $PATHTOWIGNER/FMSTRAJS/Traj.$i $nstate $initialstate
      if [[ $? -ne "0" ]];then
         Error "make_restart"
      fi

      mv mini.dat restart.xyz $folder/TRAJ.$i/

   else

      echo "Wrong parameter $mode! Exiting..."
      exit 1

   fi

## Now prepare input.in and r.abin
   irandom=`head -$i iran.dat |tail -1`

   sed -r "s/irandom *= *[0-9]+/irandom=$irandom/" $abin_input > $folder/TRAJ.$i/input.in 

   cat > $folder/TRAJ.$i/r.$molname.$i << EOF
#!/bin/bash
ABINEXE=$abinexe
JOBNAME=ABIN.$molname.${i}_$$_\${JOB_ID}
INPUTPARAM=input.in
INPUTGEOM=mini.dat
OUTPUT=output
EOF
   if [[ ! -z $veloc ]];then
      echo "INPUTVELOC=veloc.in" >> $folder/TRAJ.$i/r.$molname.$i
   fi
   grep -v -e '/bin/bash' -e 'ABINEXE=' -e "JOBNAME=" -e "INPUTPARAM=" -e "INPUTGEOM=" -e "INPUTVELOC=" $launch_script >> $folder/TRAJ.$i/r.$molname.$i
   chmod 755 $folder/TRAJ.$i/r.$molname.$i


   echo "cd TRAJ.$i" >> $folder/$molname.$isample.$j.sh
   echo "./r.$molname.$i" >> $folder/$molname.$isample.$j.sh
   echo "cd $pwd/$folder" >> $folder/$molname.$isample.$j.sh

#--Distribute calculations evenly between jobs for queue
   if [[ $remainder -le 0 ]];then
      let ncalc=injob
   else
      let ncalc=injob+1 
   fi
   if [[ `expr \( $i - $first + 1 \) % $ncalc` -eq 0 ]] && [[ $j -lt $jobs ]]; then
      let j++
      let remainder--
   fi
#---------------------------------------------------------------------------

   let i++

done

if [[ ! -z "$submit" ]];then
   cd $folder
   while [[ $k -le $j ]]
   do
      if [[ -f $molname.$isample.$k.sh ]];then
         $submit -V -cwd $molname.$isample.$k.sh
      fi
      let k++
   done
fi


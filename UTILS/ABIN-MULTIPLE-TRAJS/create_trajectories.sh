#!/bin/bash

# TODO:  make more general cut_sphere, and then expect it in the PATH
# lepe vyresit tvorbu input.in, pouzit sed

#---------------------------------------------------------------------------------
#  Create_Trajectories                   Daniel Hollas, Ondrej Svoboda 2014

#-This script generates and executes a set of dynamical trajectories using ABIN.
#-It accepts EITHER:
# i)  Initial conditions from Wigner distribution generated by script wigner_sampling.sh.
#     This mode assumes irest=1 in input.in!
# ii) Initial geometries from a XYZ movie file (taken sequentially)
#     This mode assumes irest=0 in input.in!
#     Also, you can provide initial velocities (taken sequentially from one file).

#-It is designed both for surface hopping and normal ab initio MD.
#-( for simple AIMD, just set 'nstate=1' below)

#-The trajectories are executed and stored in $folder.

# Files needed in this folder: r.abin, input.in, make_restart
# MyIRandom utility should be in your $PATH.
# Also folder $pot (e.g. MOLPRO) is needed.
#---------------------------------------------------------------------------------

#######-----SETUP---#############
mode="movie"    # ="wigner"  - take initial conditions from Wigner distributions.  (irest=1)
                # ="movie"   - take initial geometries sequentially from XYZ movie.
movie="../movie.xyz"       # PATH TO a XYZ movie with initial geometries
veloc=""                   # leave blank if you do not have velocities
#PATHTOWIGNER="./WIGNER"  # path to wigner "trajectories"
input=input.in.shorter          
pot="QCHEM"            # folder with ab initio bash script

# Following variables can be determined automatically from input for SH runs
# for classical AIMD, set initialstate and nstate equal to 1
# initialstate=$(awk -F"[,=]" '{if($1=="istate_init")print $2}' $input) #initial state for SH
# nstate=$(awk -F"[,=]" '{if($1=="nstate")print $2}' $input)   #total number of electronic states
#natom=$(awk -F"[,=]" '{if($1=="natom")print $2}' $input) #number of atoms
natom=13
initialstate=1
nstate=1

isample=1 	        # initial number of traj
nsample=100	        # number of trajectories
folder=MP2.$initialstate  # name of the directory
molname=nh3             # for the name of the job in the queue
irandom0=10061989       # random seed, set negative for random seed based on time
abinexe=/home/$USER/bin/abin.v1  # path to abin binary
#submit="qsub -q aq"    # comment this line if you don't want to submit to queue yet
rewrite=0               # if =1 -> rewrite trajectories that already exist

## If you need to process the input via cut_sphere, adjust the following command
# (Do not provide file names.)
#cut="./cut_sphere_veloc -u 4 -v 3" # cut command
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

if [[ ! -d $pot ]];then
   Folder_not_found $pot
fi

if [[ "$mode" != "wigner" ]] && [[ ! -e "$movie" ]];then
   File_not_found $movie
fi

if [[ ! -z "$veloc" ]] && [[ "$mode" == "movie" ]] && [[ ! -e "$veloc" ]];then
   File_not_found $veloc
fi

if [[ ! -e $abinexe ]];then
   File_not_found $abinexe
fi

if [[ ! -e $input ]];then
   File_not_found $input
fi

if [[ ! -e "make_restart" ]];then
   File_not_found "make_restart"
fi

if [[ ! -e "r.abin" ]];then
   File_not_found "r.abin"
fi

if [[ -e "mini.dat" ]] || [[ -e "restart.xyz" ]];then
   echo "Error: Files mini.dat or restart.xyz were found here."
   echo "Please remove them."
   exit 1
fi

#----------------------------------------------------------------------------------------
#   Here the magic happens.

echo "initial_state nstate natom"
echo $initialstate $nstate $natom

#- NO MORE MODIFICATION USUALLY NEEDED
i=$isample
inputcheck=$(awk '{if($1=="&general"){print NR;exit 0}}' $input)
if [[ $inputcheck -ne 1 ]];then
	echo "First line in file $input must be \"&general\"!"
	echo "Exiting now..."
	exit 1
fi

let natom2=natom+2
let natom1=natom+1

#--------------------generation of random numbers--------------------------------
echo "Generating $nsample random integers."
MyIRandom $irandom0 $nsample > iran.dat
if [[ $? -ne "0" ]];then
   Error "MyIrandom"
fi

#--------------------------------------------------------------------------------

mkdir -p $folder
cp iseed0 "$input" $folder

offset=0
offsetvel=0
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

cp -r $pot $folder/TRAJ.$i

#--- Now prepare mini.dat (and restart.xyz)

if [[ $mode = "movie" ]];then
   head -$offset $movie | tail -$natom2 > geom
   if [[ ! -z "$veloc" ]];then
      head -$offsetvel $veloc | tail -$natom1 > veloc.in
   fi
#--- Perform cutting, if needed.
# TODO: make cut_sphere to take files as parameters

   if [[  ! -z "$cut" ]];then
      if [[ ! $($cut < geom) ]];then
         Error "$cut"
      fi
   cp cut_qm.xyz geom
   cp veloc.out veloc.in
   fi
fi


if [[ "$mode" = "wigner" ]];then
   ./make_restart -wig $PATHTOWIGNER/FMSINPOUT/Geometry.dat $PATHTOWIGNER/FMSTRAJS/Traj.$i $nstate $initialstate
   if [[ $? -ne "0" ]];then
      Error "make_restart"
   fi

   mv mini.dat restart.xyz $folder/TRAJ.$i/

elif [[ "$mode" = "movie" && -z "$veloc" ]];then

   mv geom $folder/TRAJ.$i/mini.dat

elif [[ "$mode" = "movie" && ! -z "$veloc" ]];then

   ./make_restart -mov geom veloc.in $nstate $initialstate 
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

echo '&general' > $folder/TRAJ.$i/input.in
echo "irandom=$irandom,         ! random seed">>$folder/TRAJ.$i/input.in
grep -v -e irandom -e '&general' $input >> $folder/TRAJ.$i/input.in

cd $folder/TRAJ.$i/

cat > r.$molname.$initialstate.$i << EOF
#!/bin/bash
ABINEXE=$abinexe
JOBNAME=ABIN.$molname.$initialstate.$i
INPUTPARAM=input.in
INPUTGEOM=mini.dat
OUTPUT=output
EOF
grep -v -e 'ABINEXE=' -e "JOBNAME=" -e "INPUTPARAM=" -e "INPUTGEOM=" ../../r.abin >>r.$molname.$initialstate.$i

#---------------------------------------------------------------------------
if [[ ! -z "$submit" ]];then
   $submit -cwd r.$molname.$initialstate.$i
fi

cd ../..
let i++

done

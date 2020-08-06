#!/bin/bash
#
# === OilspillLauncher.sh ===
# 
# Required parameters are:
# - the queryID (through -i)
# - the submission string (through -s)
# - the callback url (through -c)
#
# Code refactoring for Zeus performed on: 2020/08/03


####################################################
#
# Initial setup
#
####################################################

APPNAME=$0


####################################################
#
# send_to_callback
#
####################################################

function send_to_callback {
        f_outcode=$1
        f_callback=$2
        curl -F "outcode=${f_outcode}" ${f_callback}
        ret_value=$?
        if [ $ret_value -eq 6 ]; then
                #DNS error
                counter=1
                while [ $counter -lt 4 ]; do
                        sleep 2
                        echo -e "[$APPNAME] -- `date`\tERROR\tDNS error; attempt #${counter}" 1>&2
			if [[ $test == 0 ]] ; then
                            curl -F "outcode=${f_outcode}" ${f_callback}
			fi
                        ret_value=$?
                        if [ $ret_value -ne 6 ]; then
                                break;
                        fi
                        let counter=counter+1
                done
                if [ $counter -eq 4 ]; then
                        echo -e "[$APPNAME] -- `date`\tERROR\tDNS error; unable to contact ${f_callback}" 1>&2
                fi
        fi
        return $ret_value
}


####################################################
#
# main
#
####################################################

queryID=''
subm_string=''
callback_url=''
start_time=`date +'%F %T'`
userName=`whoami`

# set test to 0 to run out of a test environment
test=1

# parse command line arguments
echo "[$APPNAME] -- Parsing command line arguments"
while getopts  "i:s:c:" flag
do
  case "$flag" in
        i) queryID=$OPTARG
           ;;
        s) subm_string=$OPTARG
           ;;
        c) callback_url=$OPTARG
           ;;
        :) exit 1
           ;;
        ?) exit 1
           ;;
  esac
done

# Parse submission string.. Values can contain also :., and -
echo "[$APPNAME] -- Parsing submission string"
subm_string=$(echo "${subm_string}" | sed 's/[^A-Za-z0-9_:.,;=\^§-]//g')

# Check if callback url is valid
if [ "$callback_url" == "" ]; then
        message=$(echo -e "[$APPNAME] -- `date`\tERROR\tError in retrieving callback URL")
        end_time=`date +'%F %T'`
        echo -e $message
        exit 1
fi

# Check if the query ID is valid
if [ "$queryID" == "" ]; then
        message=$(echo -e "[$APPNAME] -- `date`\tERROR\tError in retrieving queryID")
        end_time=`date +'%F %T'`
        echo -e $message
	if [[ $test == 0 ]] ; then	    
	    send_to_callback -1 ${callback_url}
	fi
        exit 2
fi

# Check if the submission string is valid
if [ "$subm_string" == "" ]; then
        message=$(echo -e "[$APPNAME] -- `date`\tERROR\tError in retrieving submission string")
        end_time=`date +'%F %T'`
        echo -e $message
	if [[ $test == 0 ]] ; then
	    send_to_callback -1 ${callback_url}
	fi
        exit 3
fi

# Set work variables
export Id_Dir=$queryID
export HOME_MEDSLIK=/work/opa/${userName}/OILSPILL_DA/out/${Id_Dir}
export MEDSLIK=$HOME_MEDSLIK/witoil
export NCARG_USRRESFILE=$HOME_MEDSLIK/.hluresfile
export BASE_MEDSLIK_HOME_SANIFS=/users_home/opa/${userName}/witoil-sanifs
export BASE_MEDSLIK_HOME_MED=/users_home/opa/${userName}/witoil-med
export BASE_MEDSLIK_DATA_SANIFS=/work/opa/witoil-dev/witoil-sanifs-DATA
export BASE_MEDSLIK_DATA_MED=/work/opa/witoil-dev/witoil-med-DATA

# Load modules
echo "[$APPNAME] -- Loading modules"
module load intel19.5/19.5.281 intel19.5/szip/2.1.1 intel19.5/hdf5/1.10.5 intel19.5/netcdf/C_4.7.2-F_4.5.2_CXX_4.3.1

# Clean medslik home before starting
echo "[$APPNAME] -- Creating for $HOME_MEDSLIK"
if [ -d  $HOME_MEDSLIK ];then
  echo "[$APPNAME] -- An old dir already exist I'm deleting old files inside it!"
  rm -rf ${HOME_MEDSLIK}/*
fi
mkdir -p ${HOME_MEDSLIK}

# Read the model requested by the simulation
MODEL=$(echo $subm_string | grep -e "model=[a-zA-Z]*" -o | cut -d "=" -f 2)
if [ $MODEL == "SANIFS" ]; then
    export BASE_MEDSLIK_HOME=$BASE_MEDSLIK_HOME_SANIFS
    export BASE_MEDSLIK_DATA=$BASE_MEDSLIK_DATA_SANIFS
elif [ $MODEL == "MED" ]; then
    export BASE_MEDSLIK_HOME=$BASE_MEDSLIK_HOME_MED
    export BASE_MEDSLIK_DATA=$BASE_MEDSLIK_DATA_MED
    ln -s $BASE_MEDSLIK_DATA_MED $HOME_MEDSLIK/witoil/DATA
else
    echo "[$APPNAME] -- Model $MODEL not supported! Exiting..."
    exit
fi

# Create a copy of medslik folder and create its configuration file
echo "[$APPNAME] -- Requested a simulation with model $MODEL"
cp -r $BASE_MEDSLIK_HOME ${HOME_MEDSLIK}/witoil
echo "MEDSLIK_BASEDIR=$HOME_MEDSLIK/witoil" > $HOME_MEDSLIK/witoil/EXE/mdk2.conf
echo "MEDSLIK_DATA=\${MEDSLIK_BASEDIR}/DATA" >> $HOME_MEDSLIK/witoil/EXE/mdk2.conf
echo "MEDSLIK_EXE=\${MEDSLIK_BASEDIR}/EXE" >> $HOME_MEDSLIK/witoil/EXE/mdk2.conf

# Create a directory for data and link .nc files in it
mkdir $HOME_MEDSLIK/witoil/DATA/fcst_data/SK1 -p
mkdir $HOME_MEDSLIK/witoil/DATA/fcst_data/H3k

for NCFILE in $(ls $BASE_MEDSLIK_DATA/fcst_data/H3k/*.nc) ; do
    ln -s $NCFILE $HOME_MEDSLIK/witoil/DATA/fcst_data/H3k/
done

for NCFILE in $BASE_MEDSLIK_DATA/fcst_data/SK1/*.nc ; do
    ln -s $NCFILE $HOME_MEDSLIK/witoil/DATA/fcst_data/SK1/
done

# Invoking jsonToInput to parse the input
echo "[$APPNAME] -- Invoking jsonToInput.sh..."
./jsonToInput.sh ${subm_string}

cd $HOME_MEDSLIK
echo "[$APPNAME] -- \$OPTARG value is: $OPTARG"

# Start the simulation
echo "[$APPNAME] -- Starting the simulation..."
cd $HOME_MEDSLIK/witoil/EXE
sh run_crop_bsub.sh mdk$queryID

# Copying output file spill_properties.nc
echo "[$APPNAME] -- Copying spill_properties.nc"
cp $HOME_MEDSLIK/witoil/EXE/output/final/spill_properties.nc $HOME_MEDSLIK

# Get the information required to build conf.ini file
echo "[$APPNAME] -- Generating conf.ini"
LON_MIN=$(cat $HOME_MEDSIK/witoil/EXE/output/final/medslik.tmp | grep Longitudes | tr -s " " | cut -f 2 -d " ")
LON_MAX=$(cat $HOME_MEDSIK/witoil/EXE/output/final/medslik.tmp | grep Longitudes | tr -s " " | cut -f 3 -d " ")
LAT_MIN=$(cat $HOME_MEDSIK/witoil/EXE/output/final/medslik.tmp | grep Latitudes | tr -s " " | cut -f 2 -d " ")
LAT_MAX=$(cat $HOME_MEDSIK/witoil/EXE/output/final/medslik.tmp | grep Latitudes | tr -s " " | cut -f 3 -d " ")
DURATION=$(cat $HOME_MEDSLIK/witoil/EXE/output/final/medslik_inputfile.txt | grep -e "length=[0-9]\{4\}" -o | cut -d "=" -f 2)
MODEL=$(echo $subm_string | grep -e "model=[a-zA-Z]*" -o | cut -f 2 -d "=")
DAY=$(grep Date medslik5.inp | tr -s " " | cut -d " " -f 1)
MONTH=$(grep Date medslik5.inp | tr -s " " | cut -d " " -f 2)
YEAR=$(grep Date medslik5.inp | tr -s " " | cut -d " " -f 3)
HOUR=$(grep "Hour of Spill" medslik5.inp | tr -s " " | cut -f 1 -d " ")
PROD_DATE="$YEAR/$MONTH/$DATE"
START_DATETIME="$YEAR/$MONTH/$DAY ${HOUR:0:2}:00"

# Generating output file conf.ini
echo "###Configuration File" > $HOME_MEDSLIK/conf.ini
echo "[GENERAL]" >> $HOME_MEDSLIK/conf.ini
echo "dss=witoil" >> $HOME_MEDSLIK/conf.ini
echo "user=witoil-dev" >> $HOME_MEDSLIK/conf.ini
echo "host=$(hostname)" >> $HOME_MEDSLIK/conf.ini
echo "model=$MODEL" >> $HOME_MEDSLIK/conf.ini
echo "production_date=$PROD_DATE" >> $HOME_MEDSLIK/conf.ini
echo "start_date_time=$START_DATETIME" >> $HOME_MEDSLIK/conf.ini
echo "duration=$DURATION" >> $HOME_MEDSLIK/conf.ini
echo "" >> $HOME_MEDSLIK/conf.ini
echo "[WITOIL_BOUNDING_BOX] # mandatory for WITOIL" >> $HOME_MEDSLIK/conf.ini
echo "bbox_lat_min=$LAT_MIN" >> $HOME_MEDSLIK/conf.ini
echo "bbox_lon_min=$LON_MIN" >> $HOME_MEDSLIK/conf.ini
echo "bbox_lat_max=$LAT_MAX" >> $HOME_MEDSLIK/conf.ini
echo "bbox_lon_max=$LON_MAX" >> $HOME_MEDSLIK/conf.ini

# finalize
if [[ $test == 0 ]] ; then
    # invoke the finalize script to send files
    python finalize.py -s $queryID
    
    # contact the callback url
    send_to_callback 0 $callback_url
fi

# clean
rm -rf $HOME_MEDSLIK/witoil

# exit gracefully
echo "[$APPNAME] -- Elaboration completed!"
exit 0

#!/bin/bash
#
# === jsonToInput.sh ===
#
# This file take in input a json string and create two files: 
# "medslik_inputfile.txt" and "medslik5.par" to run medslik_II
#
# Code refactoring performed on: 2020/08/03


####################################################
#
# Set variables and exit codes for error management
#
####################################################

APPNAME=$0
userName=`whoami`
export homeDir="/users/home/tessa_gpfs1/${userName}"
workDir=/work/tessa_gpfs2/${userName}/OILSPILL_DA/out
export E_BADARGS="1"
export INP_BADARGS="-1"   # code: 255
export Curr_BADARGS="-2"  # code: 254
export Wind_BADARGS="-3"  # code: 253
export SIM_DUR_ARGS="-4"  # code: 252


####################################################
#
# Read and check command line arguments
#
####################################################

# Check for the number of parameters otherwise exit
if [ $# -ne 1 ] ; then
   echo -e "[$APPNAME] -- `date ` There must be one input parameter as a string \n "
   echo -e "[$APPNAME] -- Usage: ./`basename $0` 'sim_name=simname;model=MYO1h;wind=ECMWF05;sim_length=0024;day=15;month=10;year=13;hour=08;minutes=00;lat_degree=42;lat_mintes=22.28;lon_degree=10;lon_minutes=55.50;duration=0036;spillrate=00006.80;oil=API;oiltype=17;var_2=1;var_3=0.00;var_10=2.0;var_14=90000;var_19=0.0000033;var_29=0.000008;var_39=150' \n"
   exit $INP_BADARGS
fi
inputString=$1
idDir=`echo ${inputString} | awk -F';' '{for(i = 1;i <= NF;i++){printf "%s\n", $i}}' | awk 'BEGIN{FS="="} ($1 == "id") {print $2}'`
inputString=${inputString//\`/xxx}
workingDir=${workDir}/${idDir}/witoil
cd ${workingDir}
echo "[$APPNAME] -- I'm in directory ${workingDir}"
echo $1 > infile.txt

####################################################
#
# parse input string
#
####################################################

echo "[$APPNAME] -- Parsing input string..."
echo "${inputString}" | awk -F';' '{for(i = 1;i <= NF;i++){printf "%s\n", $i}}' | while read LINE; do # >>${workingDir}/file.txt # | while read LINE; do 
	case $LINE in
		"selector="*)
                        SELECTOR=`echo $LINE | awk -F'=' '{printf $2}'`
                        echo "export SELECTOR=${SELECTOR}" >> selector.sh
		;;
		"hex="*)
			hex=`echo $LINE | awk -F'=' '{printf $2}'`
                        echo "export hex=${hex}" >> selector.sh
		;;
		"uncert_radius="*)
			uncert_radius=`echo $LINE | awk -F'=' '{printf $2}'`
                        echo "export uncert_radius=${uncert_radius}" >> selector.sh
		;;
                "uncert_type="*)
                        uncert_type=`echo $LINE | awk -F'=' '{printf $2}'`
                        echo "export uncert_type=${uncert_type}" >> selector.sh
                ;;
		"id="*)
			id=`echo $LINE | awk -F'=' '{printf $2}'`
			echo "export id=$id" >> env.sh
		;;
		"sim_name"*)
			SIM_NAME=`echo $LINE | awk -F'=' '{printf $2}'`
                        echo "export SIM_NAME=$SIM_NAME" >> env.sh
		;;
                "wind"*)
                        WIND=`echo $LINE | awk -F'=' '{printf $2}'`
			if [ $WIND == "ECMWF025" ];then
			  WIND=ECMWF012
			fi
			echo "export WIND=$WIND" >> env.sh
                ;;
                "spillrate"*)
                        SPILL_RATE=`echo $LINE | awk -F'=' '{printf $2}'`
			echo "export SPILL_RATE=$SPILL_RATE" >> env.sh
                ;;
                "model"*)
                        MODEL=`echo $LINE | awk -F'=' '{printf $2}'`
			echo "export MODEL=$MODEL" >> env.sh
                ;;
                "minutes"*)
                        MINUTES_TIME=`echo $LINE | awk -F'=' '{printf $2}'`
			echo "export MINUTES_TIME=$MINUTES_TIME" >> env.sh
                ;;
                "sim_length"*)
                        SIM_LENGTH=`echo $LINE | awk -F'=' '{printf $2}'`
			echo "export SIM_LENGTH=$SIM_LENGTH" >> env.sh
			echo "export SIM_LENGTH=$SIM_LENGTH" > hour_step.sh
                ;;
                "lon_min"*)
                        LON_MINUTES=`echo $LINE | awk -F'=' '{printf $2}'`
			echo "export LON_MINUTES=$LON_MINUTES" >> env.sh
                ;;
                "hour"*)
                        HOUR=`echo $LINE | awk -F'=' '{printf $2}'`
			echo "export HOUR=$HOUR" >> env.sh
                ;;
                "lon_deg"*)
                        LON_DEGREE=`echo $LINE | awk -F'=' '{printf $2}'`
			echo "export LON_DEGREE=$LON_DEGREE" >> env.sh
                ;;
                "lat_deg"*)
                        LAT_DEGREE=`echo $LINE | awk -F'=' '{printf $2}'`
			echo "export LAT_DEGREE=$LAT_DEGREE" >> env.sh
                ;;
                "oil="*)
                        OIL=`echo $LINE | awk -F'=' '{printf $2}'`
			echo "export OIL=\"$OIL\"" >> env.sh
                ;;
                "duration"*)
                        DURATION=`echo $LINE | awk -F'=' '{printf $2}'`
			echo "export DURATION=$DURATION" >> env.sh
                ;;
                "oiltype"*)
                        OIL_TYPE=`echo $LINE | awk -F'=' '{printf $2}'`
			echo "export OIL_TYPE=\"$OIL_TYPE\"" >> env.sh
                ;;
                "month"*)
                        MONTH=`echo $LINE | awk -F'=' '{printf $2}'`
			echo "export MONTH=$MONTH" >> env.sh
                ;;
                "year"*)
                        YEAR=`echo $LINE | awk -F'=' '{printf $2}'`
			echo "export YEAR=$YEAR" >> env.sh
                ;;
                "day"*)
                        DAY=`echo $LINE | awk -F'=' '{printf $2}'`
                        echo "export DAY=$DAY" >> env.sh
                ;;
                "lat_min"*)
                        LAT_MINUTES=`echo $LINE | awk -F'=' '{printf $2}'`
			echo "export LAT_MINUTES=$LAT_MINUTES" >> env.sh
                ;;
		"var_"*)
			lineNum=`echo $LINE | awk -F'=' '{printf $1}' | awk -F'_' '{printf $2}'`
			echo $lineNum
			Content=`echo $LINE | awk -F'=' '{printf $2}'`
			sed -e "${lineNum}s/.*/${Content}/" medslik5.par > medslik5.par.tmp
			mv medslik5.par.tmp medslik5.par
		;;
		"start_lon"*)
			START_LON=`echo $LINE | awk -F'=' '{printf $2}'`
                        echo "export START_LON=${START_LON}" >> env.sh
                        echo "export START_LON=${START_LON}" >> selector.sh
		;;
                "start_lat"*)
                        START_LAT=`echo $LINE | awk -F'=' '{printf $2}'`
                        echo "export START_LAT=${START_LAT}" >> env.sh
                        echo "export START_LAT=${START_LAT}" >> selector.sh
                ;;
		"plotStep"*)
			lineNum=23
			echo $lineNum
			Content=`echo $LINE | awk -F'=' '{printf $2}'`
			sed -e "${lineNum}s/.*/HOUR_STEP  = ${Content}/" medslik_plots/default_medslik_plots.ncl > medslik_plots/default_medslik_plots.ncl.tmp
			mv medslik_plots/default_medslik_plots.ncl.tmp medslik_plots/default_medslik_plots.ncl 
			echo "export HOUR_STEP=${Content}" >> hour_step.sh
		;;
                *)
			echo "[$APPNAME] -- $LINE Input parameter not known"
                ;;
	esac
done
echo "export uncert_type=position" >> selector.sh


####################################################
#
# Set default values
#
####################################################

AGE=0  ##AGE_TMP                    # if the oil has been released from long time and ithas evaporated for example
GRID_SIZE=150.0 ##GRID_SIZE_TMP         # spatial resolution (m) of the oil tracer grid.
SAT_DATA=NO #SAT_DATA_TMP        # for Point Source choose NO, for slick from satellite data choose YES
CONTOUR_SLICK=NO  #CONTOUR_SLICK_TMP      # for Point Source choose NO, for manually slick contour insertion choose YES
N_OS=1 #N_OS_TMP   # write the number of the slick to be simulated


####################################################
#
# Set permissions
#
####################################################

chmod 755 env.sh
source env.sh
chmod 755 selector.sh
chmod 755 hour_step.sh


####################################################
#
# Check the oil type
#
####################################################

if [ $OIL == "NAME" ];then
	OIL_TYPE=${OIL_TYPE//_/ }
	OIL_TYPE=${OIL_TYPE//§/\&}
	OIL_TYPE=${OIL_TYPE//^/\/}
fi


####################################################
#
# Generate medslik_inputfile.txt
#
####################################################

echo "[$APPNAME] -- Generating medslik_inputfile.txt..."
sed -e "s|SIM_NAME_TMP|$SIM_NAME|g"\
    -e "s|MODEL_TMP|${MODEL}|g"\
    -e "s|WIND_TMP|${WIND}|g"\
    -e "s|SIM_LENGTH_TMP|$SIM_LENGTH|g"\
    -e "s|DAY_TMP|$DAY|g"\
    -e "s|MONTH_TMP|$MONTH|g"\
    -e "s|YEAR_TMP|$YEAR|g"\
    -e "s|HOUR_TMP|$HOUR|g"\
    -e "s|MINUTES_TIME_TMP|$MINUTES_TIME|g"\
    -e "s|LAT_DEGREE_TMP|$LAT_DEGREE|g"\
    -e "s|LAT_MINUTES_TMP|$LAT_MINUTES|g"\
    -e "s|DURATION_TMP|$DURATION|g"\
    -e "s|SPILL_RATE_TMP|$SPILL_RATE|g"\
    -e "s|OIL_TMP|$OIL|g"\
    -e "s|OIL_TYPE_TMP|\"$OIL_TYPE\"|g"\
    -e "s|AGE_TMP|${AGE}|g"\
    -e "s|GRID_SIZE_TMP|$GRID_SIZE|g"\
    -e "s|SAT_DATA_TMP|$SAT_DATA|g"\
    -e "s|CONTOUR_SLICK_TMP|$CONTOUR_SLICK|g"\
    -e "s|N_OS_TMP|$N_OS|g"\
     medslik_inputfile.txt.tmp > medslik_inputfile.txt.tmp1

if (( $(bc <<< "$START_LON > 0") == 1 ));then
    sed -e "s|LON_DEGREE_TMP|$LON_DEGREE|g"\
        -e "s|LON_MINUTES_TMP|$LON_MINUTES|g"\
        medslik_inputfile.txt.tmp1 > medslik_inputfile.txt
else
    sed -e "s|LON_DEGREE_TMP|-$LON_DEGREE|g"\
        -e "s|LON_MINUTES_TMP|-$LON_MINUTES|g"\
        medslik_inputfile.txt.tmp1 > medslik_inputfile.txt
    lineNum=`cat env.sh |grep -n "LON_DEGREE=" | awk 'BEGIN {FS=":"} {print $1}'`
    echo "[$APPNAME] -- export LON_DEGREE=$LON_DEGREE" 
    Content=`echo "export LON_DEGREE=-$LON_DEGREE"`
    sed -e "${lineNum}s/.*/${Content}/" env.sh > env.sh.tmp
    lineNum=`cat env.sh |grep -n "LON_MINUTES=" | awk 'BEGIN {FS=":"} {print $1}'`
    echo "[$APPNAME] -- export LON_MINUTES=$LON_MINUTES" 
    Content=`echo "export LON_MINUTES=-$LON_MINUTES"`
    sed -e "${lineNum}s/.*/${Content}/" env.sh.tmp > env.sh
    rm env.sh.tmp
    chmod 750 env.sh
fi
  
####################################################
#
# exit gracefully
#
####################################################

echo "[$APPNAME] -- Elaboration completed!"
exit 0

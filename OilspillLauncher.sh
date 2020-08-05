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
# send_files_to_callback
#
####################################################

function send_files_to_callback {
        f_OutputDir=$1
        f_queryID=$2
        f_callback=$3
	if [[ $test == 0 ]] ; then
            curl -F "outcode=0" -F "data1=@$f_OutputDir/result.json;type=text/csv" ${f_callback}
	fi
        ret_value=$?
        if [ $ret_value -eq 6 ]; then
                #DNS error
                counter=1
                while [ $counter -lt 4 ]; do
                        sleep 2
                        echo -e "[$APPNAME] -- `date`\tERROR\tDNS error; attempt #${counter}" 1>&2
			if [[ $test == 0 ]] ; then			   
        		    curl -F "outcode=0" -F "data1=@$f_OutputDir/result.json;type=text/csv" ${f_callback}
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
export BASE_MEDSLIK_HOME=/work/opa/${userName}/witoil

# Load modules
echo "[$APPNAME] -- Loading modules"
module load intel19.5/19.5.281 intel19.5/szip/2.1.1 intel19.5/hdf5/1.10.5 intel19.5/netcdf/C_4.7.2-F_4.5.2_CXX_4.3.1

# Clean medslik home before starting
echo "[$APPNAME] -- Looking for $HOME_MEDSLIK"
if [ -d  $HOME_MEDSLIK ];then
  echo "[$APPNAME] -- An old dir already exist I'm deleting old files inside it!"
  rm -rf ${HOME_MEDSLIK}/*
fi
mkdir -p ${HOME_MEDSLIK}

# Create a copy of medslik folder and parse JSON file
cp -r $BASE_MEDSLIK_HOME ${HOME_MEDSLIK}/
./jsonToInput.sh ${subm_string}
cd $HOME_MEDSLIK
cp ${MEDSLIK}/oilsp_vs_uncert.sh .
ls
echo "[$APPNAME] -- $OPTARG"

# Invoke oilspill_vs_uncert.sh
./oilsp_vs_uncert.sh $queryID > select.out 2>select.err
excode=$?
echo -e "[$APPNAME] -- srun EXIT CODE: $excode"

# Check the exit code of oilspill_vs_uncert
if [ $excode -ne 0 ]; then

    # job cancelled
    if [ $excode -eq 15 ]; then
        message=$(echo -e "[$APPNAME] -- `date`\tERROR\tJob has been cancelled")
        end_time=`date +'%F %T'`
        echo -e $message
	if [[ $test == 0 ]] ; then
            send_to_callback ${excode} ${callback_url}
	fi
        exit 7

    # errors in algorithm execution
    elif [ $excode -gt 50 ];then
        excode=51
	message=$(echo -e "[$APPNAME] -- `date`\tERROR\t `cat medslik_II.error`")
        end_time=`date +'%F %T'`
        echo -e $message
	if [[ $test == 0 ]] ; then	   
            send_to_callback ${excode} ${callback_url}
	fi
        exit $excode
    elif [ $excode -gt 40 ];then
	excode=41
	message=$(echo -e "[$APPNAME] -- `date`\tERROR\t `cat medslik_II.error`")
        end_time=`date +'%F %T'`
        echo -e $message
	if [[ $test == 0 ]] ; then
            send_to_callback ${excode} ${callback_url}
	fi
        exit $excode
    elif [ $excode -gt 30 ];then
	excode=31
	message=$(echo -e "[$APPNAME] -- `date`\tERROR\t `cat medslik_II.error`")
        end_time=`date +'%F %T'`
        echo -e $message
	if [[ $test == 0 ]] ; then
            send_to_callback ${excode} ${callback_url}
	fi
        exit $excode
    elif [ $excode -gt 20 ];then
	excode=21
	message=$(echo -e "[$APPNAME] -- `date`\tERROR\t `cat medslik_II.error`")
        end_time=`date +'%F %T'`
        echo -e $message
	if [[ $test == 0 ]] ; then	   
            send_to_callback ${excode} ${callback_url}
	fi
        exit $excode
    else
        message=$(echo -e "[$APPNAME] -- `date`\tERROR\tError in algorithm execution")
        end_time=`date +'%F %T'`
        echo -e $message
	if [[ $test == 0 ]] ; then	   
            send_to_callback ${excode} ${callback_url}
	fi
        exit 6
    fi
fi

# Preparing for the callback...
OutputDir=${MEDSLIK}/output/json
cd $OutputDir
cp ${MEDSLIK}/infile.txt ${Id_Dir}/
cp $Id_Dir/*.json .

# Create a single json file for all the output files
touch $Id_Dir/index.html
chmod 754 $Id_Dir/index.html
zip -j ${Id_Dir}.zip ${Id_Dir}/*
mv ${Id_Dir}.zip ${Id_Dir}/

if [[ $test == 0 ]] ; then
    scp -r $Id_Dir ${userName}@193.204.199.175:/var/www/html/${userName}/
fi
    
if [ $? -ne 0 ]; then
        message=$(echo -e "[$APPNAME] -- `date`\tERROR\tError in sending the tiles")
        end_time=`date +'%F %T'`
        echo -e $message
	if [[ $test == 0 ]] ; then
	    send_to_callback -3 ${callback_url}
	fi
        exit 8
fi
echo -e "{\n\t\"files\": [">result.json; for i in $(ls scorners.json); do echo -e "\t\t{ \"name\": \"$i\"," >> result.json; echo -e "\t\t $(cat $i)" >> result.json; echo -e "\t\t},\n" >> result.json;  echo $i; done; for i in $(ls palette.json); do echo -e "\t\t{ \"name\": \"$i\"," >> result.json; echo -e "\t\t $(cat $i)" >> result.json; echo -e "\t\t},\n" >> result.json;  echo $i; done; for i in $(ls out*|grep -v srf); do echo -e "\t\t{ \"name\": \"$i\"," >> result.json; echo -e "\t\t\"output\": \"$(cat $i)\"" >> result.json; echo -e "\t\t},\n" >> result.json;  echo $i; done; for i in $(ls medslik.fte); do echo -e "\t\t{ \"name\": \"$i\"," >> result.json; echo -e "\t\t\"output\": \"$(cat $i)\"" >> result.json; echo -e "\t\t}\n" >> result.json;  echo $i; done;   echo -e "\t]\n}" >> result.json;

# invoking send_files_to_callback
send_files_to_callback $OutputDir $queryID ${callback_url}
if [ $? -ne 0 ]; then
        message=$(echo -e "[$APPNAME] -- `date`\tERROR\tError in sending the output files")
	end_time=`date +'%F %T'`
        echo -e $message
	if [[ $test == 0 ]] ; then	   
	    send_to_callback -3 ${callback_url}
	fi
        exit 7
fi

# exit gracefully
echo "[$APPNAME] -- Elaboration completed!"
exit 0

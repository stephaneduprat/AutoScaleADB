#!/bin/sh
# #####################################################################
# $Header: scale-adb.sh 08-Apr-2019 sduprat_es $
#
# scale-adb.sh <adb-name>
#
# Copyright (c) 2019, Oracle Pre-Sales (Spain).  All rights reserved.
#
#    NAME
#     scale-adb.sh
#
#    DESCRIPTION
#      Monitors and scale up and down an autonomous database !!!
#
#    NOTES
#     Dependencies:
#        list-compute.txt: a file listing ADB, which format must be:
#  bench-adw;ADW;ocid1.autonomousdatabase.oc1.eu-frankfurt-1.abtheljsm4ovlhbomyxq7v4t5k4pqhdukmotlysbz4r5e3zpuyk5opbkwmtq
#  bench-atp;ATP;ocid1.autonomousdatabase.oc1.eu-frankfurt-1.abtheljsl47zsgj2l273bxpbkgtmxlz77fnxlru6x7bi23kyhrrsqatwbalq
#
#        status-compute.sh: gets status of ADB from oci-cli
#        scale-cpu-adb.sh : scales ADB up or down        
#        monitor.adw.sql: SQL query monitoring ADB
#
#
#    VERSION            MODIFIED        (MM/DD/YY)
#                       sduprat_es      04/08/19   - Creation and mastermind
#                       sduprat_es      25/03/20   - Add notifications to OCI - Add external profile.ini to allow hot changes
# 
# #####################################################################

ORACLE_HOME=/home/opc/instantclient_18_3
LD_LIBRARY_PATH=/home/opc/instantclient_18_3
PATH=$ORACLE_HOME:$PATH
TNS_ADMIN=$ORACLE_HOME/network/admin


export ORACLE_HOME LD_LIBRARY_PATH PATH
name=$1
homedir=/home/opc/admin
logdir=${homedir}/log
ficlog=${logdir}/$$.log
prf=${homedir}/profile.ini
upcount=0  ### Number of consecutive UP results !!!
downcount=0 ### Number of consecutive DOWN results !!!


#Iniciamos el fchero de los para que de error
echo  >$ficlog

ScaleAdb()
{
name=$1
updown=$2
cpucount=$3
runqueue=$4
cpupct=$5

if [ $updown == "UP" ]
then ## Scale up !!!
   if [ "$cpucount" -lt "$cpufloor" ]
   then
     newcpu=$cpufloor
   else
     newcpu=$( echo $cpucount"+"$cpuupinc | bc -l)
     if [ "$newcpu" -gt "$cpuceil" ]
     then
       newcpu=$cpuceil
       ${homedir}/notify.topic.sh ${cpucount} ${runqueue} ${cpupct}
     fi
   fi
else ### Scale down !!!
   newcpu=$( echo $cpucount"-"$cpudowninc | bc -l)
   if [ "$newcpu" -lt "$cpufloor" ]
   then
     newcpu=$cpufloor
   fi
fi
echo "Now Scaling "$updown" to "$newcpu" OCPUs"
${homedir}/scale-cpu-adb.sh ${name} $newcpu
}

GetStatus()
{
name=$1
status=$(${homedir}/status-compute.sh ${name} | awk '{ print $NF }')
echo "status is "$status
if [ ${status} == "AVAILABLE" ]
then
    return 1
else
    return 0
fi
}

poll()
{
adb=$1
rqcoef=$2
GetStatus $adb
status=$?
if [ "${status}" -eq "1" ]
then
   echo "start "${homedir}"/monitor.adw.sql" | $ORACLE_HOME/sqlplus -s ${StringConnect} > $ficlog
   sleep 3 
   date 
  if [ -e $ficlog ]
    then
     cpucount=$(grep "CPUCOUNT=" $ficlog | cut -f3 -d";" | awk -F "=" '{ print $NF }')
     runqueue=$(grep "RUNQUEUE=" $ficlog| cut -f2 -d";"| awk -F "=" '{ print $NF }')
     cpupct=$(grep "CPUPCT=" $ficlog | cut -f1 -d";"| awk -F "=" '{ print $NF }')
     else 
      echo "Fichero $ficlog no existe" 
     fi 

   echo "CPUCOUNT="$cpucount
   echo "RUNQUEUE="$runqueue
   echo "CPUPCT="$cpupct

   rqmax=$(echo $cpucount"*"$rqcoef | bc -l)
   echo "Max RQ allowed="$rqmax

   if [ "$cpupct" -gt "$cpumax" -o "$runqueue" -gt "$rqmax" ]
   then
      if [ "$cpucount" -eq "$cpuceil" ]
      then
          echo "Max allowed CPUs reached ("$cpuceil")"
          ${homedir}/notify.topic.sh ${cpucount} ${runqueue} ${cpupct}
          return 0 ### Return 0 for "OK" !!!
      else
          return 1 ### Return 1 for UP !!!
      fi
   else 
      if [ "$cpupct" -lt "$cpumin" ]
      then
         ### Potentially scale down, unless num cpus equals cpufloor !!!
         if [ "$cpucount" -eq "$cpufloor" ]
         then
            echo "Min allowed CPUs reached ("$cpufloor")"
            return 0 ### Return 0 for "OK" !!!
         else
            return 2 ### Return 2 for "DOWN" !!!
         fi
      else
         return 0 ### Return 0 for "OK" !!!
      fi
   fi
else ### Not available: STOPPED or SCALING !!!
   return 0 ### Return 0 for "OK" !!!
fi
}

while true
do
   . ${prf}
   poll $name $rqcoef
   res=$?
   cpucount=$(grep "CPUCOUNT=" $ficlog | cut -f3 -d";" | awk -F "=" '{ print $NF }')
   runqueue=$(grep "RUNQUEUE=" $ficlog| cut -f2 -d";"| awk -F "=" '{ print $NF }')
   cpupct=$(grep "CPUPCT=" $ficlog | cut -f1 -d";"| awk -F "=" '{ print $NF }')
   echo "Poll result="$res

   ### If the current number of CPU is less than cpufloor, scale-up NOW to cpufloor !!!
   ### If I'm in that situation, it's because cpufloor has been modified on the flight in profile.ini
   ### Hence I do an emergency scale-up to cpufloor, and nothing else matters !!!
   echo "CPUCOUNT="$cpucount
   echo "CPUFLOOR="$cpufloor
   if [ "$cpucount" -lt "$cpufloor" ]
   then
      if ! [ "$res" -eq "0" ] ### If ADB is stopped or yet scaling, do nothing !!!
      then
        ### Immediate scale-up to cpufloor !!!
        echo "--> Immediate scale-up from "$cpucount" to "$cpufloor" !!!"
        ScaleAdb $name "UP" $cpucount $runqueue $cpupct
        upcount=0
        downcount=0
      else
        echo "Everything fine, going to sleep "$sleepinterval" seconds"
        sleep ${sleepinterval}
        upcount=0
        downcount=0
      fi
  else
   ##
   ##
   if [ "$res" -eq "1" ]
   then
      upcount=$(echo $upcount"+"1 | bc -l)
      echo "--> Claiming for scale-up "$upcount"/"$uplimit
      downcount=0
      if [ "$upcount" -lt "$uplimit" ]
      then
          echo "Going to sleep "$spininterval" seconds before next check"
          sleep ${spininterval}
      fi
   elif [ "$res" -eq "2" ]
   then
      downcount=$(echo $downcount"+"1 | bc -l)
      echo "--> Claiming for scale-down "$downcount"/"$downlimit
      upcount=0
      if [ "$downcount" -lt "$downlimit" ]
      then
          echo "Going to sleep "$spininterval" seconds before next check"
          sleep ${spininterval}
      fi
   else
      downcount=0
      upcount=0
      echo "Everything fine, going to sleep "$sleepinterval" seconds"
      sleep ${sleepinterval}
   fi  
   ##
   if [ "$upcount" -eq "$uplimit" ]
   then
      ### I got $upcount consecutive times UP => Scale-up !!!
      echo "Starting scale-up"

      ScaleAdb $name "UP" $cpucount $runqueue $cpupct
      upcount=0
      downcount=0
   elif [ "$downcount" -eq "$downlimit" ]
   then
      ### I got $downcount consecutive times DOWN => scale-down !!!  
      echo "Starting scale-down"

      ScaleAdb $name "DOWN" $cpucount $runqueue $cpupct
      upcount=0
      downcount=0
   else
      ### Nothing to do !!!
      echo " "
   fi
  fi
done

exit 0

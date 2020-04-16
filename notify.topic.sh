#!/bin/sh

### Script to notify a topic !!!
### Usage: notify-topic.sh ${cpucount} ${runqueue} ${cpupct}

DATE=`date +%Y%m%d%H%M%S`
PRETTYDATE=`date +%d/%m/%Y-%Hh%Mmn%Ss`
homedir=/home/opc/admin
prf=${homedir}/profile.ini
ficlog=/home/opc/admin/log/${DATE}.notify-topic.log
bodyfile=/home/opc/admin/log/${DATE}.notify-topic.bodyfile.txt

. ${prf}

if [ "${notifytopic}" == "1" ]
then
   #### Generate body file !!!
   echo " " > ${bodyfile}
   echo "As of "${PRETTYDATE}", a scale-up claim was issued whereas maximum number of allowed OCPU had been already reached," >> ${bodyfile}
   echo "or the last scale-up operation gave a result above your limit." >> ${bodyfile}
   echo " " >> ${bodyfile}
   echo "Consider allowing more OCPU as a high limit, and modifying the cpuceil parameter in your profile.ini to do so." >> ${bodyfile}
   echo " " >> ${bodyfile}
   echo "Current high limit = "${cpuceil} >> ${bodyfile}
   echo "Current cpu count = "$1 >> ${bodyfile}
   echo "Current run queue = "$2 >> ${bodyfile}
   echo "Current CPU utilization = "$3 >> ${bodyfile}
   echo " " >> ${bodyfile}
   echo "Kind regards," >> ${bodyfile}
   /home/opc/bin/oci ons message publish --topic-id ${topicocid} --body "$(cat ${bodyfile})" --defaults-file /home/opc/.oci/mydefaults.txt 1>${ficlog} 2>&1
else
   echo "Topic notifications are turned to "${notifytopic}". Put 1 for parameter notifytopic in profile.ini to turn them on." > ${ficlog}
fi

exit 0



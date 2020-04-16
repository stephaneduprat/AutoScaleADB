#!/bin/bash

### Script de arranque de un compute
### $1 = nombre del compute

name=$1
numcpu=$2
DATE=`date +%Y%m%d%H%M%S`
ocid=$(grep $name /home/opc/admin/list-compute.txt | awk -F";" '{ print $3 }')
targettype=$(grep $name /home/opc/admin/list-compute.txt | awk -F";" '{ print $2 }')
ficlog=/home/opc/admin/log/${DATE}.scale-cpu-adb.${name}.log

if [ ${targettype} == "ADW" ]
then
    /home/opc/bin/oci db autonomous-data-warehouse update --autonomous-data-warehouse-id ${ocid} --cpu-core-count $numcpu --defaults-file /home/opc/.oci/mydefaults.txt 1>${ficlog} 2>&1
elif [ ${targettype} == "ATP" ]
then
    /home/opc/bin/oci db autonomous-database update --autonomous-database-id ${ocid} --cpu-core-count $numcpu --defaults-file /home/opc/.oci/mydefaults.txt 1>${ficlog} 2>&1
else
  echo "Not an ADB"
fi

exit 0

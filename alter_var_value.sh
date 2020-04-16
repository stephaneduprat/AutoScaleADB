#!/bin/sh

### Script to modify profile.ini
### Usage: alter_var_value.sh <variable name> <new value>

homedir=/home/opc/admin
prf=${homedir}/profile.ini
var=$1
newvalue=$2

num=$(cat ${prf} | grep ${var}"=" | wc -l)

if [ $num -eq 1 ]
then
   str=$(cat ${prf} | grep ${var}"=" | awk '{ print $1 }')
   sed '1,$ s/'${str}'/'${var}'='${newvalue}'/' ${prf} > /tmp/t
   mv /tmp/t ${prf}
fi 

exit 0


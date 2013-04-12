 #!/bin/sh
 # Compare two lists of installed yum packages on CentOS|Fedora|RHEL.
 # INPUT :  Two text files, output from "yum list installed > FILE
 # INPREP:  Strip versions and repository info, keep package names.
 # OUTPUT: diff -y --suppress-common-lines *sum
 diffpar="-y --ignore-blank-lines --suppress-common-lines"
 prog=$0
 if [ $# -lt 2 ]; then
     echo "---------------------------------------------------------"
     echo "  Name     : ${prog}"
     echo "  Synopsis : ${prog} OLDLIST NEWLIST"
     echo "           : Compare two lists of YUM installed packages"
     echo "  Arguments: OLDLIST NEWLIST (from \"yum list installed\")"
     echo "  Process 1: cut -d' ' -f1 OLDLIST > TMPF1"
     echo "  Process 2: cut -d' ' -f1 NEWLIST > TMPF2"
     echo "  Process 3: diff ${diffpar} TMPF1 TMPF2"
     echo "  Process 4: rm -f TMPF1 TMPF2"
     echo "  Output   : Package names in NEWLIST not in OLDLIST"
     echo "  Use case : List packages to install on OLDLIST PC."
     echo "---------------------------------------------------------"
     exit 99
 fi
 list1="list1-${$}-${1}"
 list2="list2-${$}-${2}"
 if [ -f ${list1} ]; then rm -f ${list1}; fi
 if [ -f ${list2} ]; then rm -f ${list2}; fi
 cut -d' ' -f1 ${1} > ${list1}
 cut -d' ' -f1 ${2} > ${list2}
 echo "Compare \"${1}\" left and \"${2}\" right"
 echo "-------------------------------------------------------------"
 diff ${diffpar} ${list1} ${list2} | sed 's/^[\t ]*//g' | grep -v '<'
 echo "-------------------------------------------------------------"
 rm -f ${list1} ${list2}
 echo "END"
 exit 0
 # END

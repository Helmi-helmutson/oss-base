#!/bin/bash
#
# Copyright (c) 2017 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
#

FROM=""
TO=""
PROJECT=""
CLEANUP=""

while getopts f:t:p:c:d:h name
do
    case $name in
    f)
       FROM="$OPTARG";;
    t)
       TO="$OPTARG";;
    p)
       PROJECT="$OPTARG";;
    c)
       CLEANUP="$OPTARG";;
    d)
       SORTDIR="$OPTARG";;
    h)
       usage
       exit 0;;
    ?)
       usage
       exit 2;;
    esac
done

. /etc/sysconfig/schoolserver

IMPORTS="$( oss_get_home.sh ${TO} )/Import/"
if [ $SORTDIR = "y" ]; then
    TARGET="${IMPORTS}/${PROJECT}/$FROM"
else
    TARGET="${IMPORTS}/${PROJECT}"
fi
mkdir -p -m 700 $TARGET

EXPORTS="$( oss_get_home.sh ${FROM} )/Export/"

if [ ! -d $EXPORTS ]; then
    echo "The export directory '$EXPORTS' does not exists." 1>&2
fi

if [ "$SORTDIR" = "y" ]; then
    cp $EXPORTS/* $TARGET/ 
else
    IFS=$'\n'
    for i in $EXPORTS/*
    do
       j=$( basename $i )
       cp $i "${TARGET}/${FROM}-${j}"
    done
fi

chown -R $TO "${IMPORTS}/${PROJECT}"

if [ "$CLEANUP" = 'y' ]; then
    rm -rf $EXPORTS/*
fi

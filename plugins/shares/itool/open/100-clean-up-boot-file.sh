#!/bin/bash

U=$1
I=$2
a=$3
m=$4
R=$5

crx_api.sh DELETE clonetool/devicesByIP/${I}/cloning

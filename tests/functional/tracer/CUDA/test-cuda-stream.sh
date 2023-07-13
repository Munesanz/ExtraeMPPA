#!/bin/bash

TOP_BUILDDIR=../../../../
RET_VALUE=""

function isNumber() {
    local str=$1
    if [[ "$str" =~ ^[0-9]+$ ]]; then
        return true
    else
        return false
    fi
}

function getEventType() {
    RET_VALUE=""
    local string=$1
    local file=${2/prv/pcf}
    local output=$(awk -v string="$string" '{ if(match($0,string)){ print $2 } } ' $file)
    RET_VALUE=$output
}

function getEventValueForType() {
    RET_VALUE=""
    local evt_type=$1
    local value_string=$2
    local file=${3/prv/pcf}
    local output=$(awk -v value_string="$value_string" -v evt_type="$evt_type" 'BEGIN {interest=0} { if(match($0,evt_type)){ interest=1 }; if(interest==1 && match($0,value_string)){print $1; interest=0} } ' $file)
    RET_VALUE=$output
}

function checkInTrace() {
    RET_VALUE=""
    local evt_type=$1
    local evt_value=$2
    local prvFile=${3/pcf/prv}
    local pcfFile=${3/prv/pcf}
    getEventType "$evt_type$" "$pcfFile"
    num_evt_type=$RET_VALUE
    getEventValueForType "$evt_type$" "$evt_value$" "$prvFile"
    num_evt_value=$RET_VALUE
    echo -n "Grep \"$evt_type\" : \"$evt_value\" -> $num_evt_type:$num_evt_value $prvFile - "
    grep -m 1 "$num_evt_type:$num_evt_value" $prvFile > /dev/null
    local RES=$?
    if [ $RES == 0 ]; then
        echo "OK"
    else
        echo "KO"
        exit -1
    fi
}

function checkInPCF() {
    local string=$1
    local file=$2
    echo -n "Grep $string to $file - "
    grep $string $file > /dev/null
    local RES=$?
    if [ $RES == 0 ]; then
        echo "OK"
    else
        echo "KO"
        exit -1
    fi
}

# The compilation part of the check is inserted here due to the difficulties of change the compiler to nvcc

# Try first with -cudart shared (recent nvcc compilers requires this)
nvcc -g -cudart shared stream.cu -o stream
if [[ ! -x stream ]]; then
	nvcc -g stream.cu -o stream
fi

./trace.sh ./stream
${TOP_BUILDDIR}/src/merger/mpi2prv -f TRACE.mpits -o stream.prv

# Check tests
getEventType "Flushing Traces" stream.prv
checkInPCF "CUDA" stream.pcf 
checkInPCF "cudaLaunch" stream.pcf 
checkInPCF "cudaConfigureCall" stream.pcf 
checkInPCF "cudaMemcpyAsync" stream.pcf 
checkInPCF "cudaThreadSynchronize" stream.pcf 
#checkInPCF "cudaStreamSynchronize" stream.pcf 
checkInPCF "helloStream" stream.pcf 
checkInPCF "cudaStreamCreate" stream.pcf
checkInPCF "cudaStreamDestroy" stream.pcf

checkInTrace "CUDA kernel" helloStream stream.prv
checkInTrace "CUDA library call" cudaThreadSynchronize stream.prv

exit 0

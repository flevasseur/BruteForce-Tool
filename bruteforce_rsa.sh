#!/bin/bash

if [ $# -eq 0 ]
    usage: `basename $0` < passwd file >
    exit 0
fi

PASSFILE=$1

n=0
while read line
do
    openssl rsa -in ca.key -passin pass:$line 2>/dev/null
    if [ $? -eq 0 ]; then
        echo $line
        n=$(($n+1))
        openssl rsa -in ca.key -passin pass:$line -out decrypted.key.$n
    fi
done < $PASSFILE

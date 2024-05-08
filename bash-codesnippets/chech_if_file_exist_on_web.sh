#!/bin/bash
wget -nv --method HEAD https://github.com/HEnquist/camilladsp/releases/download/v2.0.2/camilladsp-linux-aarch64.tar.gz 2>&1 | grep -q '200 OK'

if [ $? -eq 0 ]; then
   echo OK;
else
   echo FAIL;
fi

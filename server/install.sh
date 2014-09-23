#!/bin/bash
#Install alarm server
#Author:jcsong2
#Date:2014-09-17

echo "Installing thrift-0.9.1..."
echo "============================"
cd thrift-0.9.1/ 
python setup.py install
cd ..
echo "============================"
echo "Done"

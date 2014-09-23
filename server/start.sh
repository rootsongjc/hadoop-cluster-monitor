#!/bin/bash
#start alarm server

python AlarmServer.py >> server.log 2>&1 &

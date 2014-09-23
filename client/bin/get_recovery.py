#!/usr/bin/env python
# -*- coding:utf-8 -*-

import os
import StringIO
import sys

deadlast = sys.argv[1].split(" ")
deadnow = sys.argv[2].split(" ")

for i in range(0,len(deadlast)):
    if deadlast[i] not in deadnow:
	print deadlast[i]


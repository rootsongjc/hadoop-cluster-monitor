#!/usr/bin/env python
# -*- coding:utf-8 -*-

import os
import json
import StringIO
import urllib
import pycurl
import sys

url = sys.argv[1]
deadnode = sys.argv[2].split(',')
#url = 'http://vortex-pro.hadoop0001.hf.voicecloud.cn:50070/jmx?qry=hadoop:service=NameNode,name=NameNodeInfo'
c = pycurl.Curl()
c.setopt(pycurl.URL, url)
c.setopt(pycurl.HTTPHEADER, ["Accept:"])
b = StringIO.StringIO()
c.setopt(pycurl.WRITEFUNCTION, b.write)
c.setopt(pycurl.FOLLOWLOCATION, 1)
c.setopt(pycurl.MAXREDIRS, 5)
try:
    c.perform()
except Exception,ex:
#    print Exception,":",ex
     print "DOWN"
     quit()
data = b.getvalue()
value = json.loads(data)['beans'][0]['DeadNodes']
result = eval(value).keys()
#print result
#print c.getinfo(pycurl.HTTP_CODE), c.getinfo(pycurl.EFFECTIVE_URL)
status = {
    'value': value,
    'code': c.getinfo(pycurl.HTTP_CODE),
    'url': c.getinfo(pycurl.EFFECTIVE_URL),
}
for i in range(0,len(result)):
    if result[i] not in deadnode:
        print result[i]

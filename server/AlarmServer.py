# -*- coding: utf-8 -*-
__author__ = 'tsli'
import socket
import MySQLdb
import time
import os
from thrift.transport import TSocket
from thrift.transport import TTransport
from thrift.protocol import TBinaryProtocol
from thrift.server import TServer

from notice_service import NoticeMessageService

sms_server_ip = '192.168.72.179'
sms_server_port = 23667

mysql_host = '172.16.60.103'
mysql_user = 'AlarmServer'
mysql_pass = 'AlarmServer'
mysql_db = 'AlarmServer'


class AlarmServer(object):
    def __init__(self):
        self.sms_server_ip = sms_server_ip
        self.sms_server_port = sms_server_port
        self.mysql_host = mysql_host
        self.mysql_user = mysql_user
        self.mysql_pass = mysql_pass
        self.mysql_db = mysql_db

    def check_the_status(self, msg):
        try:
            mysqlconn = MySQLdb.connect(host=self.mysql_host,
                                        user=self.mysql_user,
                                        passwd=self.mysql_pass,
                                        db=self.mysql_db)
        except Exception:
            print 'Error in connection to Mysql!'

	#SMS config
        ip = msg.ip
        appid = msg.appid
        suffix = msg.suffix
        status = msg.status
        cursor = mysqlconn.cursor()
        now = time.time()
        if not status == 'OK':
            sql = "delete from sms_alarm_status where ip=%s and appid=%s and status=%s and suffix=%s"
            param = (ip, appid, 'OK', suffix)
            n = cursor.execute(sql, param)
            mysqlconn.commit()
            sql = 'select time from sms_alarm_status where ip=%s and appid=%s and status=%s and suffix=%s'
            param = (ip, appid, status, suffix)
            n = cursor.execute(sql, param)
            if n == 0:
                print 'insert the sms'
                sql = "insert into sms_alarm_status(ip,appid,status,suffix,time) values(%s,%s,%s,%s,%s)"
                param = (ip, appid, status, suffix, time.time())
                n2 = cursor.execute(sql, param)
                mysqlconn.commit()
                cursor.close()
                mysqlconn.close() 
                return True
            else:
                for row in cursor.fetchall():
                    for r in row:
                        print float(now) - float(r)
                        if float(now) - float(r) > 600:
                            sql = "update sms_alarm_status set time=%s where ip=%s and appid=%s and status=%s and suffix=%s"
                            param = (now, ip, appid, status, suffix)
                            n2 = cursor.execute(sql, param)
                            mysqlconn.commit()
                            cursor.close()
                            mysqlconn.close()
                            return True
        else:
            sql = 'select time from sms_alarm_status where ip=%s and appid=%s and status=%s and suffix=%s'
            param = (ip, appid, status, suffix)
            n = cursor.execute(sql, param)
            if n == 0:
                sql = "delete from sms_alarm_status where ip=%s and appid=%s and suffix=%s"
                param = (ip, appid, suffix)
                n2 = cursor.execute(sql, param)
                mysqlconn.commit()
                sql = "insert into sms_alarm_status(ip,appid,status,suffix,time) values(%s,%s,%s,%s,%s)"
                param = (ip, appid, status, suffix, time.time())
                n2 = cursor.execute(sql, param)
                mysqlconn.commit()
                cursor.close()
                mysqlconn.close()
                return True 
        cursor.close()
        mysqlconn.close()
        return False

    def sendSMS(self, msg, phone):
        now = time.ctime()
        print msg.body + '--' + msg.appid + '--' + msg.ip + '--' + msg.suffix + '--' + str(now)
        if not self.check_the_status(msg):
            print 'too many'
            return
        s = '<?xml version="1.0" encoding = "UTF-8"?>'
        s += '<atpacket domain="web" type="event"><cmd id="send_sm" node="%s">' % msg.ip
        s += '<para name="appid" value=\'%s\' />' % msg.appid
        s += '<para name="src" value=\'\' /><para name="dst" value=\'%s\' />' % ','.join(phone)
        s += '<para name="context" value=\'%s\' /></cmd></atpacket>' % ('【' + msg.suffix + '】' + msg.ip + '--' + msg.body)
	s = s.decode('utf-8').encode('gbk');
        head = len(s)
        head_s = '%08x' % head
        message = '0x' + head_s + s
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect((self.sms_server_ip, self.sms_server_port))
        sock.send(message)
        sock.close()

    def sendMail(self, mail):
        now = time.ctime()
        print mail.sender + '--' + mail.topic + '--' + mail.receiver + '--' + mail.server + '--' + mail.content + '--' + str(now)
	    result = os.popen('perl sendEmail -f ' + mail.sender + ' -t ' + mail.receiver + ' -s ' +  mail.server + ' -u ' + mail.topic + ' -m ' + mail.content + ' -xu ' + mail.name + ' -xp ' + mail.passwd + ' -o message-content-type=html -o message-charset=utf-8').read()
	    print result


handler = AlarmServer()
processor = NoticeMessageService.Processor(handler)
transport = TSocket.TServerSocket('0.0.0.0', 9093)
tfactory = TTransport.TBufferedTransportFactory()
pfactory = TBinaryProtocol.TBinaryProtocolFactory()

server = TServer.TSimpleServer(processor, transport, tfactory, pfactory)

print 'Starting the server...'
server.serve()
print 'Done.'

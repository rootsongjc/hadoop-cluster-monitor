from notice_service import NoticeMessageService
from notice_service.ttypes import *
from notice_service.constants import *

from thrift import Thrift
from thrift.transport import TSocket
from thrift.transport import TTransport
from thrift.protocol import TBinaryProtocol

import argparse
import os
import sys

service_ip = '172.16.60.218'
service_port = 9093 


def send_sms(args):
    try:
        transport = TSocket.TSocket(service_ip, service_port)
        transport = TTransport.TBufferedTransport(transport)
        protocol = TBinaryProtocol.TBinaryProtocol(transport)
        client = NoticeMessageService.Client(protocol)

        transport.open()
        sms = NoticeSMSMessage(body=args.body,
                               suffix=args.suffix, ip=args.ip, appid=args.appid, status=args.status)
        try:
            client.sendSMS(sms, args.phone)
        except NoticeRPCException:
            print 'Error! error no.%d: %s' % (NoticeRPCException.errno,
                                              NoticeRPCException.msg)
        else:
            print 'done!'
        transport.close()
    except Thrift.TException:
	pass


def send_mail(args):
    try:
        transport = TSocket.TSocket(service_ip, service_port)
        transport = TTransport.TBufferedTransport(transport)
        protocol = TBinaryProtocol.TBinaryProtocol(transport)
        client = NoticeMessageService.Client(protocol)
        transport.open()
        print args.topic
        mail = NoticeEmailMessage(sender=args.sender, receiver=args.receiver, server=args.server, topic=args.topic, content=args.body,name=args.name,passwd=args.passwd)
        try:
            client.sendMail(mail)
        except NoticeRPCException:
            print 'Error! error no.%d: %s' % (NoticeRPCException.errno,
                                              NoticeRPCException.msg)
        else:
            print 'done!'
        transport.close()
    except Thrift.TException:
	pass


parser = argparse.ArgumentParser(prog='alarm')

subparsers = parser.add_subparsers(help='sub-command help')
parser_message = subparsers.add_parser('message', help='send sms')
parser_message.add_argument(
    '-b', '--body', required=True, type=str, help='sms body')
parser_message.add_argument(
    '-s', '--suffix', required=True, type=str, help='sms suffix')
parser_message.add_argument(
    '-a', '--appid', required=True, type=str, help='appid')
parser_message.add_argument(
    '-p', '--phone', required=True, nargs='+', type=str, help='phone numbers')
parser_message.add_argument(
    '-u', '--status', required=True, type=str, help='status')
parser_message.add_argument(
    '-i', '--ip', required=True, type=str, help='ip')
parser_message.set_defaults(func=send_sms)
parser_mail = subparsers.add_parser('mail', help='send mail')
parser_mail.add_argument('-t', '--topic', required=True, type=str, help='mail topic')
parser_mail.add_argument('-b', '--body', required=True, type=str, help='mail body')
parser_mail.add_argument('-s', '--sender',required=True, type=str, help='mail sender')
parser_mail.add_argument('-e', '--server',required=True, type=str, help='mail server')
parser_mail.add_argument('-n', '--name', required=True, type=str, help='sender name')
parser_mail.add_argument('-r', '--receiver', required=True, type=str, help='mail receiver')
parser_mail.add_argument('-p', '--passwd', required=True, type=str, help='mail sender password')
parser_mail.set_defaults(func=send_mail)
args = parser.parse_args(sys.argv[1:])
print args.body

args.func(args)

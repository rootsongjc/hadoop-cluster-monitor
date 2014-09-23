struct NoticeSMSMessage{
1:string body;
2:string suffix;
3:string ip;
4:string status;
5:string appid;
}
struct NoticeEmailMessage{
1:string sender;
2:string receiver;
3:string server;
4:string topic;
5:string content;
6:string name;
7:string passwd;
}
exception NoticeRPCException{
1:i32 errno;
2:string msg;
}
service NoticeMessageService{
	string sendSMS(1:NoticeSMSMessage msg,2:list<string> phones) throws(1:NoticeRPCException rpcException)
	string sendMail(1:NoticeEmailMessage mail) throws(1:NoticeRPCException rpcException)
}
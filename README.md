# Hadoop cluster monitor
该程序为CS端程序。实现hadoop集群的监控和告警。

## 功能

监控hadoop集群整体情况，若namenode无法访问（通过访问namenode网页判断）则发送短信和邮件给指定人。

## 客户端

### 配置项

**client/conf/conf.ini**

*	interval：监控程序运行的时间间隔，单位秒，默认10分钟
*	phones：发送告警给哪些手机
*	appid：发送短信时候使用的appid
*	receiver：短信接收者
*	sender：发送者的邮箱
*	name：发送者的邮箱用户名
*	password：发送者的邮箱密码
*	server：邮箱server
*	deadnode excluded：排除的deadnode，这些节点dead将不会发送告警
*	三地的jmx请求URL

### 启动监控
./monitor start

### 停止监控

./monitor stop

## 服务端

./start.sh

2014-09-19


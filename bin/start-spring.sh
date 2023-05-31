#!/bin/sh
#该脚本为 Linux 下启动 java 程序的通用脚本。既可以作为开机自启动 service 脚本被调用，
#也可以作为启动 java 程序的独立脚本来使用。
#
#警告!!!：该脚本 stop 部分使用系统 kill 命令来强制终止指定的 java 程序进程。
#在杀死进程前，未作任何条件检查。在某些情况下，如程序正在进行文件或数据库写操作，
#可能会造成数据丢失或数据不完整。如果必须要考虑到这类情况，则需要改写此脚本，
#增加在执行 kill 命令前的一系列检查。
#
#
###################################
#环境变量及程序执行参数
#需要根据实际环境以及 Java 程序名称来修改这些参数
###################################
# JDK 所在路径
JAVA_HOME="/root/.sdkman/candidates/java/current/"

# 执行程序启动所使用的系统用户，考虑到安全，推荐不使用 root 帐号
RUNNING_USER=root

# Java 程序所在的目录（classes 的上一级目录）
APP_HOME=/data1/opt/dataease-v1.18.6/
APP_JAR=dataease-v1.18.6.jar
APP_MAIN_OPTIONS="--spring.profiles.active=test"
# java 虚拟机启动参数
JAVA_OPTS="-Xms256M -Xmx1G"

# TODO 暂不设置 拼凑完整的 classpath 参数，包括指定 lib 目录下所有的 jar
CLASSPATH=$APP_HOME/classes
for i in "$APP_HOME"/lib/*.jar; do
   CLASSPATH="$CLASSPATH":"$i"
done

###################################
#(函数) 判断程序是否已启动
#
#说明：
#使用 JDK 自带的 JPS 命令及 grep 命令组合，准确查找 pid
#jps 加 l 参数，表示显示 java 的完整包路径
#使用 awk，分割出 pid ($1 部分)，及 Java 程序名称 ($2 部分)
###################################
#初始化 psid 变量（全局）
psid=0

checkpid() {
   javaps=`$JAVA_HOME/bin/jps -l | grep $APP_JAR`

   if [ -n "$javaps" ]; then
      psid=`echo $javaps | awk '{print $1}'`
   else
      psid=0
   fi
}

###################################
#(函数) 启动程序
#
#说明：
#1. 首先调用 checkpid 函数，刷新$psid 全局变量
#2. 如果程序已经启动（$psid 不等于 0），则提示程序已启动
#3. 如果程序没有被启动，则执行启动命令行
#4. 启动命令执行后，再次调用 checkpid 函数
#5. 如果步骤 4 的结果能够确认程序的 pid,则打印[OK]，否则打印[Failed]
#注意：echo -n 表示打印字符后，不换行
#注意: "nohup 某命令 >/dev/null 2>&1 &" 的用法
###################################
start() {
   checkpid

   if [ $psid -ne 0 ]; then
      echo "================================"
      echo "warn: $APP_MAIN already started! (pid=$psid)"
      echo "================================"
   else
      echo "Starting $APP_MAIN ..."
      JAVA_CMD="nohup $JAVA_HOME/bin/java -jar $JAVA_OPTS $APP_HOME$APP_JAR $APP_MAIN_OPTIONS >/dev/null2>&1 &"
      echo "exec: $JAVA_CMD"
      su - $RUNNING_USER -c "$JAVA_CMD"
      checkpid
      if [ $psid -ne 0 ]; then
         echo "(pid=$psid) [OK]"
      else
         echo "[Failed]"
      fi
   fi
}

###################################
#(函数) 停止程序
#
#说明：
#1. 首先调用 checkpid 函数，刷新$psid 全局变量
#2. 如果程序已经启动（$psid 不等于 0），则开始执行停止，否则，提示程序未运行
#3. 使用 kill -9 pid 命令进行强制杀死进程
#4. 执行 kill 命令行紧接其后，马上查看上一句命令的返回值: $?
#5. 如果步骤 4 的结果$?等于 0,则打印[OK]，否则打印[Failed]
#6. 为了防止 java 程序被启动多次，这里增加反复检查进程，反复杀死的处理（递归调用 stop）。
#注意：echo -n 表示打印字符后，不换行
#注意: 在 shell 编程中，"$?" 表示上一句命令或者一个函数的返回值
###################################
stop() {
   checkpid

   if [ $psid -ne 0 ]; then
      echo -n "Stopping $APP_MAIN ...(pid=$psid) "
      su - $RUNNING_USER -c "kill -9 $psid"
      if [ $? -eq 0 ]; then
         echo "[OK]"
      else
         echo "[Failed]"
      fi

      checkpid
      if [ $psid -ne 0 ]; then
         stop
      fi
   else
      echo "================================"
      echo "warn: $APP_MAIN is not running"
      echo "================================"
   fi
}

###################################
#(函数) 检查程序运行状态
#
#说明：
#1. 首先调用 checkpid 函数，刷新$psid 全局变量
#2. 如果程序已经启动（$psid 不等于 0），则提示正在运行并表示出 pid
#3. 否则，提示程序未运行
###################################
status() {
   checkpid

   if [ $psid -ne 0 ];  then
      echo "$APP_JAR is running! (pid=$psid)"
   else
      echo "$APP_JAR is not running"
   fi
}

###################################
#(函数) 打印系统环境参数
###################################
info() {
   echo "System Information:"
   echo "****************************"
   echo `head -n 1 /etc/issue`
   echo `uname -a`
   echo
   echo "JAVA_HOME=$JAVA_HOME"
   echo `$JAVA_HOME/bin/java -version`
   echo
   echo "APP_HOME=$APP_HOME"
   echo "APP_JAR=$APP_JAR"
   echo "****************************"
}

###################################
#读取脚本的第一个参数 ($1)，进行判断
#参数取值范围：{start|stop|restart|status|info}
#如参数不在指定范围之内，则打印帮助信息
###################################
case "$1" in
   'start')
      start
      ;;
   'stop')
     stop
     ;;
   'restart')
     stop
     start
     ;;
   'status')
     status
     ;;
   'info')
     info
     ;;
esac
     echo "Usage: $0 {start|stop|restart|status|info}"
     exit 1

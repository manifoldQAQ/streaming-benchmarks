#!/bin/bash
set -o pipefail
set -o errtrace
set -o nounset
set -o errexit

#################
# CONFIGURATION #
#################

# TODO what is lein?
LEIN=${LEIN:-lein}
MVN=${MVN:-mvn}
GIT=${GIT:-git}
MAKE=${MAKE:-make}

ZK_VERSION=${ZK_VERSION:-"3.4.10"}
KAFKA_VERSION=${KAFKA_VERSION:-"1.0.0"}
REDIS_VERSION=${REDIS_VERSION:-"4.0.8"}
SCALA_BIN_VERSION=${SCALA_BIN_VERSION:-"2.11"}
SCALA_SUB_VERSION=${SCALA_SUB_VERSION:-"11"}
STORM_VERSION=${STORM_VERSION:-"1.2.1"}
FLINK_VERSION=${FLINK_VERSION:-"1.4.1"}
SPARK_VERSION=${SPARK_VERSION:-"2.2.1"}

INSTALL_ROOT="/state/partition1/ysma"
ZK_DIR="$INSTALL_ROOT/zookeeper-$ZK_VERSION"
STORM_DIR="$INSTALL_ROOT/apache-storm-$STORM_VERSION"
REDIS_DIR="$INSTALL_ROOT/redis-$REDIS_VERSION"
KAFKA_DIR="$INSTALL_ROOT/kafka_$SCALA_BIN_VERSION-$KAFKA_VERSION"
FLINK_DIR="$INSTALL_ROOT/flink-$FLINK_VERSION"
SPARK_DIR="$INSTALL_ROOT/spark-$SPARK_VERSION-bin-hadoop2.7"

ZK_HOST="dell-01.epcc"
ZK_PORT="5215"
ZK_CONNECTIONS="$ZK_HOST:$ZK_PORT"

TOPIC=${TOPIC:-"ad-events"}
PARTITIONS=${PARTITIONS:-2}
LOAD=${LOAD:-1000}
CONF_FILE=./conf/epccConf.yaml
TEST_TIME=${TEST_TIME:-240}


create_kafka_topic() {
    local count=`${KAFKA_DIR}/bin/kafka-topics.sh --describe --zookeeper "$ZK_CONNECTIONS" --topic ${TOPIC} 2>/dev/null | grep -c ${TOPIC}`
    if [[ "$count" = "0" ]];
    then
        ${KAFKA_DIR}/bin/kafka-topics.sh --create --zookeeper "$ZK_CONNECTIONS" --replication-factor 1 --partitions ${PARTITIONS} --topic ${TOPIC}
    else
        echo "Kafka topic $TOPIC already exists"
    fi
}


run() {
    if [ $1 = "CREATE_KAFKA_TOPIC" ]; then
        create_kafka_topic
    elif [ $1 = "SPARK_TEST" ]; then
        run "START_REDIS"
        run "START_KAFKA"
        run "START_SPARK_PROCESSING"
        run "START_LOAD"
        sleep ${TEST_TIME}
        run "STOP_LOAD"
        run "STOP_SPARK_PROCESSING"
        run "STOP_KAFKA"
        run "STOP_REDIS"
    elif [ $1 = "STORM_TEST" ]; then
        run "START_REDIS"
        run "START_KAFKA"
        run "START_STORM_PROCESSING"
        run "START_LOAD"
        sleep ${TEST_TIME}
        run "STOP_LOAD"
        run "STOP_STORM_PROCESSING"
        run "STOP_KAFKA"
        run "STOP_REDIS"
    elif [ $1 = "FLINK_TEST" ]; then
        run "START_REDIS"
        run "START_KAFKA"
        run "START_FLINK_PROCESSING"
        run "START_LOAD"
        sleep ${TEST_TIME}
        run "STOP_LOAD"
        run "STOP_FLINK_PROCESSING"
        run "STOP_KAFKA"
        run "STOP_REDIS"
    elif [ $1 = "START_ZK"    ]; then     # Start zookeeper
        start_if_needed QuorumPeerMain Zookeeper 10  "$ZK_DIR/bin/zkServer.sh start"
    elif [ $1 = "STOP_ZK"     ]; then     # Stop zookeeper
        stop_if_needed QuorumPeerMain Zookeeper
        # might need to remove zk data dir
    elif [ $1 = "START_REDIS" ]; then     # Start Redis
        ssh dell-08.epcc " "
    fi
}



pid_match() {
   local VAL=`ps -aef | grep "$1" | grep -v grep | awk '{print $2}'`
   echo ${VAL}
}

start_if_needed() {
  local match="$1"
  shift
  local name="$1"
  shift
  local sleep_time="$1"
  shift
  local PID=`pid_match "$match"`

  if [[ "$PID" -ne "" ]];
  then
    echo "$name is already running..."
  else
    "$@" &
    sleep ${sleep_time}
  fi
}

stop_if_needed() {
  local match="$1"
  local name="$2"
  local PID=`pid_match "$match"`
  if [[ "$PID" -ne "" ]];
  then
    kill "$PID"
    sleep 1
    local CHECK_AGAIN=`pid_match "$match"`
    if [[ "$CHECK_AGAIN" -ne "" ]];
    then
      kill -9 "$CHECK_AGAIN"
    fi
  else
    echo "No $name instance found to stop"
  fi
}

run $1

#!/bin/bash
set -o pipefail
set -o errtrace
set -o nounset
set -o errexit

source ./epcc-env.sh
source ./util.sh


create_kafka_topic() {
    local count=`${KAFKA_HOME}/bin/kafka-topics.sh --describe --zookeeper "$ZK_CONNECTIONS" --topic ${TOPIC} 2>/dev/null | grep -c ${TOPIC}`
    if [[ "$count" = "0" ]];
    then
        ${KAFKA_HOME}/bin/kafka-topics.sh --create --zookeeper "$ZK_CONNECTIONS" --replication-factor 1 --partitions ${PARTITIONS} --topic ${TOPIC}
    else
        echo "Kafka topic $TOPIC already exists"
    fi
}


run() {
    if [ $1 = "CREATE_KAFKA_TOPIC" ]; then
        create_kafka_topic
    elif [ $1 = "START_ZK"    ]; then       # Zookeeper
        start_if_needed QuorumPeerMain Zookeeper 10  "$ZK_HOME/bin/zkServer.sh start"
    elif [ $1 = "STOP_ZK"     ]; then
        stop_if_needed QuorumPeerMain Zookeeper
    elif [ $1 = "START_REDIS" ]; then       # Redis
        ssh ${REDIS_HOST} "redis-server ${REDIS_HOME}/redis.conf --daemonize yes" &
    elif [ $1 = "STOP_REDIS"  ]; then
        ssh ${REDIS_HOST} "redis-cli shutdown" &
    elif [ $1 = "START_KAFKA" ]; then       # Kafka
        for slave in ${SLAVES[*]}; do
            ssh ${slave} "${KAFKA_HOME}/bin/kafka-server-start.sh -daemon ${KAFKA_HOME}/config/server.properties"
        done
    elif [ $1 = "STOP_KAFKA"  ]; then
        for slave in ${SLAVES[*]}; do
            ssh ${slave} "${KAFKA_HOME}/bin/kafka-server-stop.sh"
        done
    elif [ $1 = "START_SPARK" ]; then       # Spark
        ${SPARK_HOME}/sbin/start-all.sh &
        sleep 5
    elif [ $1 = "STOP_SPARK"  ]; then
        ${SPARK_HOME}/sbin/stop-all.sh &
    elif [ $1 = "START_STORM" ]; then       # Storm
        ${STORM_HOME}/bin/storm nimbus &
        for slave in ${SLAVES[*]}; do
            ssh ${slave} "${STORM_HOME}/bin/storm supervisor" &
        done
        sleep 5
    elif [ $1 = "STOP_STORM"  ]; then
        jps | grep nimbus | cut -d' ' -f1 | xargs kill -9
        for slave in ${SLAVES[*]}; do
            ssh ${slave} "jps | grep supervisor | cut -d' ' -f1 | xargs kill -9"
        done
        sleep 1
    elif [ $1 = "START_FLINK" ]; then
        ${FLINK_HOME}/bin/start-cluster.sh &
        sleep 5
    elif [ $1 = "STOP_FLINK"  ]; then
        ${FLINK_HOME}/bin/stop-cluster.sh &
        sleep 5
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
    fi
}




echo ${SLAVES}

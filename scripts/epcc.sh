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
    echo "===== " $1 "======="
    if [ $1 = "CREATE_KAFKA_TOPIC" ]; then
        create_kafka_topic
    elif [ $1 = "START_ZK"    ]; then       # Zookeeper
        start_if_needed QuorumPeerMain Zookeeper 10  "$ZK_HOME/bin/zkServer.sh start"
    elif [ $1 = "STOP_ZK"     ]; then
        stop_if_needed QuorumPeerMain Zookeeper
    elif [ $1 = "START_REDIS" ]; then       # Redis: PASSING
        ssh ${REDIS_HOST} "${INSTALL_ROOT}/bin/redis-server ${REDIS_HOME}/redis.conf --daemonize yes"
        # TODO emit init data to it
    elif [ $1 = "STOP_REDIS"  ]; then
        ssh ${REDIS_HOST} "${INSTALL_ROOT}/bin/redis-cli shutdown"
        # TODO remove the dumped database
    elif [ $1 = "START_KAFKA" ]; then       # Kafka
        for slave in ${SLAVES[*]}; do
            ssh ${slave} "${KAFKA_HOME}/bin/kafka-server-start.sh -daemon ${KAFKA_HOME}/config/server.properties"
        done
    elif [ $1 = "STOP_KAFKA"  ]; then
        for slave in ${SLAVES[*]}; do
            ssh ${slave} "${KAFKA_HOME}/bin/kafka-server-stop.sh"
        done
    elif [ $1 = "START_SPARK" ]; then       # Spark PASSING
        ${SPARK_HOME}/sbin/start-all.sh
    elif [ $1 = "STOP_SPARK"  ]; then
        ${SPARK_HOME}/sbin/stop-all.sh
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
    elif [ $1 = "START_FLINK" ]; then       # Flink
        ${FLINK_HOME}/bin/start-cluster.sh &
        sleep 5
    elif [ $1 = "STOP_FLINK"  ]; then
        ${FLINK_HOME}/bin/stop-cluster.sh &
        sleep 5
    elif [ $1 = "START_LOAD"  ]; then       # Data load
        cd ../data
        start_if_needed leiningen.core.main "Load Generation" 1 \
            ${LEIN} run -r -t ${LOAD} --configPath ../${CONF_FILE}
        cd ../scripts
    elif [ $1 = "STOP_LOAD"   ]; then
        stop_if_needed leiningen.core.main "Load Generation"
        cd ../data
        ${LEIN} run -g --configPath ../${CONF_FILE} || true
        cd ../scripts
    elif [ $1 = "START_SPARK_PROCESSING" ]; then # Spark submit
        ${SPARK_HOME}/bin/spark-submit \
            --master spark://dell-01.epcc:7078 \
            --class KafkaRedisAdvertisingStream \
            ../spark-benchmarks/target/spark-benchmarks-0.1.0.jar ../${CONF_FILE} &
        sleep 5
    elif [ $1 = "STOP_SPARK_PROCESSING"  ]; then
        stop_if_needed spark.benchmark.KafkaRedisAdvertisingStream "Spark Client Process"
    elif [ $1 = "START_STORM_PROCESSING" ]; then # Storm submit
        ${STORM_HOME}/bin/storm jar \
            ../storm-benchmarks/target/storm-benchmarks-0.1.0.jar storm.benchmark.AdvertisingTopology test-topo -conf ../${CONF_FILE}
        sleep 15
    elif [ $1 = "STOP_STORM_PROCESSING"  ]; then
        ${STORM_HOME}/bin/storm kill -w 0 test-topo || true
        sleep 10
    elif [ $1 = "START_FLINK_PROCESSING" ]; then # Flink submit
        ${FLINK_HOME} run ../flink-benchmarks/target/flink-benchmarks-0.1.0.jar --confPath ../${CONF_FILE} &
        sleep 3
    elif [ $1 = "STOP_FLINK_PROCESSING"  ]; then
        FLINK_ID=`"$FLINK_HOME/bin/flink" list | grep 'Flink Streaming Job' | awk '{print $4}'; true`
        if [ "$FLINK_ID" == "" ]; then
            echo "Could not find streaming job to kill"
        else
          "$FLINK_HOME/bin/flink" cancel $FLINK_ID
            sleep 3
        fi
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


if [ $# -lt 1 ]; then
    run "HELP"
else
  while [ $# -gt 0 ];
  do
    run "$1"
    shift
  done
fi

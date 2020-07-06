
### Kafka JDBC (MySQL) connector on Docker
1. Make sure Docker and VirtualBox are installed locally 
**Install [Docker Machine](https://docs.docker.com/toolbox/toolbox_install_mac/) instead of Docker Desktop**

2. Open terminal: 
`docker-machine create --driver virtualbox --virtualbox-memory 6000 confluent`
Config terminal window to attach it to new docker machine: 
	`eval $(docker-machine env confluent)`
  
 3. Start up ZooKeeper, Kafka, and Schema Registry. (This will set up a single node in docker): 
To run ZooKeeper:`docker run -d \
    --net=host \
    --name=zookeeper \
    -e ZOOKEEPER_CLIENT_PORT=32181 \
    -e ZOOKEEPER_TICK_TIME=2000 \
    confluentinc/cp-zookeeper:5.0.0
`
To run Kafka:  `docker run -d \
    --net=host \
    --name=kafka \
    -e KAFKA_ZOOKEEPER_CONNECT=localhost:32181 \
    -e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://localhost:29092 \
    -e KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1 \
    confluentinc/cp-kafka:5.0.0
`
To run Schema Registry: `docker run -d \
  --net=host \
  --name=schema-registry \
  -e SCHEMA_REGISTRY_KAFKASTORE_CONNECTION_URL=localhost:32181 \
  -e SCHEMA_REGISTRY_HOST_NAME=localhost \
  -e SCHEMA_REGISTRY_LISTENERS=http://localhost:8081 \
  confluentinc/cp-schema-registry:5.0.0
`

**Any time when you want to check if these three services:**
**run:** 

    docker  logs  kafka

4. After getting all the services running, we can go ahead and start up Kafka Connect. 
Connect stores config, status, and offsets of the connectors in Kafka topics. We will create these topics now using the Kafka broker we created above.
Create topic: `docker run \
  --net=host \
  --rm \
  confluentinc/cp-kafka:5.0.0 \
  kafka-topics --create --topic quickstart-avro-offsets --partitions 1 --replication-factor 1 --if-not-exists --zookeeper localhost:32181`
Create topic: `docker run \
  --net=host \
  --rm \
  confluentinc/cp-kafka:5.0.0 \
  kafka-topics --create --topic quickstart-avro-config --partitions 1 --replication-factor 1 --if-not-exists --zookeeper localhost:32181`
 Create topic: `docker run \
  --net=host \
  --rm \
  confluentinc/cp-kafka:5.0.0 \
  kafka-topics --create --topic quickstart-avro-status --partitions 1 --replication-factor 1 --if-not-exists --zookeeper localhost:32181`
5. Before moving on, verify that the topics are created:
`docker run \
   --net=host \
   --rm \
   confluentinc/cp-kafka:5.0.0 \
   kafka-topics --describe --zookeeper localhost:32181`

6. Start a new window and SSH into the docker machine by doing: 
`docker-machine ssh confluent`
Now we are going to download the latest MySQL JDBC driver and copy it to the `jars` folder.
`mkdir -p /tmp/quickstart/jars`
Then in the ssh window, do: 
`wget "https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.20/mysql-connector-java-8.0.20.jar"`
**Please check MySQL version matches mysql-connector version, this is very important**
Since MySQL is version  is 8.0.20, so i'm also using 8.0.20 mysql-connector
7. Go back to local terminal window and start a connect worker with Avro support
`docker run -d \
  --name=kafka-connect-avro \
  --net=host \
  -e CONNECT_BOOTSTRAP_SERVERS=localhost:29092 \
  -e CONNECT_REST_PORT=28083 \
  -e CONNECT_GROUP_ID="quickstart-avro" \
  -e CONNECT_CONFIG_STORAGE_TOPIC="quickstart-avro-config" \
  -e CONNECT_OFFSET_STORAGE_TOPIC="quickstart-avro-offsets" \
  -e CONNECT_STATUS_STORAGE_TOPIC="quickstart-avro-status" \
  -e CONNECT_CONFIG_STORAGE_REPLICATION_FACTOR=1 \
  -e CONNECT_OFFSET_STORAGE_REPLICATION_FACTOR=1 \
  -e CONNECT_STATUS_STORAGE_REPLICATION_FACTOR=1 \
  -e CONNECT_KEY_CONVERTER="io.confluent.connect.avro.AvroConverter" \
  -e CONNECT_VALUE_CONVERTER="io.confluent.connect.avro.AvroConverter" \
  -e CONNECT_KEY_CONVERTER_SCHEMA_REGISTRY_URL="http://localhost:8081" \
  -e CONNECT_VALUE_CONVERTER_SCHEMA_REGISTRY_URL="http://localhost:8081" \
  -e CONNECT_INTERNAL_KEY_CONVERTER="org.apache.kafka.connect.json.JsonConverter" \
  -e CONNECT_INTERNAL_VALUE_CONVERTER="org.apache.kafka.connect.json.JsonConverter" \
  -e CONNECT_REST_ADVERTISED_HOST_NAME="localhost" \
  -e CONNECT_LOG4J_ROOT_LOGLEVEL=DEBUG \
  -e CONNECT_PLUGIN_PATH=/usr/share/java,/etc/kafka-connect/jars \
  -v /tmp/quickstart/file:/tmp/quickstart \
  -v /tmp/quickstart/jars:/etc/kafka-connect/jars \
  confluentinc/cp-kafka-connect:latest`
 **Before next step,  make sure that the connect worker is healthy by doing:**
 `docker logs kafka-connect-avro | grep started`
8. Launch a MYSQL database.
- First, launch the database container: 
 `docker run -d \
  --name=quickstart-mysql \
  --net=host \
  -e MYSQL_ROOT_PASSWORD=confluent \
  -e MYSQL_USER=confluent \
  -e MYSQL_PASSWORD=confluent \
  -e MYSQL_DATABASE=connect_test \
  mysql`
 - Next, Create databases and tables. You’ll need to exec into the Docker container to create the databases: 
`docker exec -it quickstart-mysql bash` 
- On the bash prompt, create a MySQL shell: 
`mysql -u confluent -pconfluent` 
- Execute the SQL statements to create table: 
`CREATE DATABASE IF NOT EXISTS connect_test;
USE connect_test;
DROP TABLE IF EXISTS test;
CREATE TABLE IF NOT EXISTS test (
  id serial NOT NULL PRIMARY KEY,
  name varchar(100),
  email varchar(200),
  department varchar(200),
  modified timestamp default CURRENT_TIMESTAMP NOT NULL,
  INDEX `modified_index` (`modified`)
);
INSERT INTO test (name, email, department) VALUES ('alice', 'alice@abc.com', 'engineering');
INSERT INTO test (name, email, department) VALUES ('bob', 'bob@abc.com', 'sales');
INSERT INTO test (name, email, department) VALUES ('bob', 'bob@abc.com', 'sales');
INSERT INTO test (name, email, department) VALUES ('bob', 'bob@abc.com', 'sales');
INSERT INTO test (name, email, department) VALUES ('bob', 'bob@abc.com', 'sales');
INSERT INTO test (name, email, department) VALUES ('bob', 'bob@abc.com', 'sales');
INSERT INTO test (name, email, department) VALUES ('bob', 'bob@abc.com', 'sales');
INSERT INTO test (name, email, department) VALUES ('bob', 'bob@abc.com', 'sales');
INSERT INTO test (name, email, department) VALUES ('bob', 'bob@abc.com', 'sales');
INSERT INTO test (name, email, department) VALUES ('bob', 'bob@abc.com', 'sales');` 
- Then exit bash and root@confluent by doing `exit`
9. Then, go to SSH window(in docker machine), create our JDBC Source connector using the Connect REST API. (You’ll need to have curl installed): 
  `export CONNECT_HOST=192.168.99.100`
  and then: 
   `curl -X POST \
  -H "Content-Type: application/json" \
  --data '{ "name": "quickstart-jdbc-source", "config": { "connector.class": "io.confluent.connect.jdbc.JdbcSourceConnector", "tasks.max": 1, "connection.url": "jdbc:mysql://127.0.0.1:3306/connect_test?user=root&password=confluent", "mode": "incrementing", "incrementing.column.name": "id", "timestamp.column.name": "modified", "topic.prefix": "quickstart-jdbc-", "poll.interval.ms": 1000 } }' \
  http://$CONNECT_HOST:28083/connectors`
 the output will look like this if JDBC connector is running well: 

> {"name":"quickstart-jdbc-source","config":{"connector.class":"io.confluent.connect.jdbc.JdbcSourceConnector","tasks.max":"1","connection.url":"jdbc:mysql://127.0.0.1:3306/connect_test?user=root&password=confluent","mode":"incrementing","incrementing.column.name":"id","timestamp.column.name":"modified","topic.prefix":"quickstart-jdbc-","poll.interval.ms":"1000","name":"quickstart-jdbc-source"},"tasks":[]}
> 
Check the status of the connector using curl as follows:
 `curl -s -X GET http://$CONNECT_HOST:28083/connectors/quickstart-jdbc-source/status`
 You should see: 
>  ."connector" :{"state":"RUNNING","worker_id":"localhost:28083"}..

The JDBC sink create intermediate topics for storing data. We should see a `quickstart-jdbc-test` topic: 
`docker run \
   --net=host \
   --rm \
   confluentinc/cp-kafka:5.0.0 \
   kafka-topics --describe --zookeeper localhost:32181`
You should see : 

> {"id":1,"name":{"string":"alice"},"email":{"string":"alice@abc.com"},"department":{"string":"engineering"},"modified":1472153437000}
{"id":2,"name":{"string":"bob"},"email":{"string":"bob@abc.com"},"department":{"string":"sales"},"modified":1472153437000}
....
{"id":10,"name":{"string":"bob"},"email":{"string":"bob@abc.com"},"department":{"string":"sales"},"modified":1472153439000}
Processed a total of 10 messages

10. You will now launch a File Sink to read from this topic and write to an output file.
`curl -X POST -H "Content-Type: application/json" \
  --data '{"name": "quickstart-avro-file-sink", "config": {"connector.class":"org.apache.kafka.connect.file.FileStreamSinkConnector", "tasks.max":"1", "topics":"quickstart-jdbc-test", "file": "/tmp/quickstart/jdbc-output.txt"}}' \
  http://$CONNECT_HOST:28083/connectors`
Check the status of the connector by running the following curl command:
`curl -s -X GET http://$CONNECT_HOST:28083/connectors/quickstart-avro-file-sink/status`
Now check the file to see if the data is present. You will need to SSH into the VM if you are running Docker Machine. 
`cat /tmp/quickstart/file/jdbc-output.txt | wc -l`

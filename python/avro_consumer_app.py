#!/usr/bin/env python3
"""
avro_consumer_app.py

A Python consumer application that:
  1. Connects to Confluent Cloud Kafka (SASL_SSL, PLAIN).
  2. Connects to Confluent Cloud Schema Registry to deserialize Avro messages.
  3. Subscribes to a specified topic and continuously polls for records.
  4. Prints out Avro-deserialized records in the console.

Prerequisites:
  - Install dependencies:
      - pip install "confluent-kafka[avro]" "python-dotenv"
  - Ensure you have a Confluent Cloud Kafka cluster with appropriate permissions:
      - API Key/Secret with consume access to the Kafka cluster.
      - Schema Registry API Key/Secret with READ permissions.
  - Required environment variables (set in `.env`, `east.env`, or `west.env`):
      - `BOOTSTRAP_SERVER` → Kafka cluster bootstrap URL
      - `SASL_USERNAME` → Kafka API key (username)
      - `SASL_PASSWORD` → Kafka API secret (password)
      - `TOPIC_NAME` → Kafka topic to consume messages from
      - `SCHEMA_REGISTRY_URL` → Schema Registry endpoint URL
      - `SCHEMA_REGISTRY_API_KEY` → Schema Registry API key
      - `SCHEMA_REGISTRY_API_SECRET` → Schema Registry API secret
  - Optional environment variables:
      - `CONSUMER_GROUP` → Consumer group ID (default provided in `.env`)

Usage:
  1. Optionally, specify "east" or "west" as a command-line argument to load
     the corresponding environment file (east.env or west.env). Otherwise,
     it defaults to .env.
  2. Ensure that BOOTSTRAP_SERVER, SASL_USERNAME, SASL_PASSWORD, TOPIC_NAME,
     SCHEMA_REGISTRY_URL, SCHEMA_REGISTRY_API_KEY, SCHEMA_REGISTRY_API_SECRET,
     and optionally CONSUMER_GROUP are set.
  3. Run python avro_consumer_app.py [east|west].
  4. Observe consumed messages in the console.

Press Ctrl+C or send SIGTERM to exit gracefully.
"""

import os
import sys
import time
import signal
from dotenv import load_dotenv
from confluent_kafka import DeserializingConsumer, KafkaError
from confluent_kafka.serialization import StringDeserializer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroDeserializer

# =============================================================================
# Load Environment Variables
# =============================================================================
def load_environment_file():
    """
    Loads the environment variables from an .env file or an environment-specific file.
    If a command-line argument is given (east|west), it loads 'east.env' or 'west.env'.
    Otherwise defaults to '.env'.
    """
    env_file = ".env"  # Default
    if len(sys.argv) > 1:
        env_arg = sys.argv[1].lower()
        if env_arg in ["east", "west"]:
            env_file = f"{env_arg}.env"
        else:
            print(f"[ERROR] Invalid environment argument: {env_arg}")
            print("[INFO] Valid options: 'east', 'west'")
            sys.exit(1)

    if os.path.exists(env_file):
        load_dotenv(env_file)
        print(f"[INFO] Loaded environment from {env_file}")
    else:
        print(f"[ERROR] {env_file} does not exist. Please generate or provide it.")
        sys.exit(1)

# Invoke environment loading as soon as the script starts
load_environment_file()

# =============================================================================
# Environment-Based Configurations
# =============================================================================
BOOTSTRAP_SERVER = os.getenv("BOOTSTRAP_SERVER")
SASL_USERNAME = os.getenv("SASL_USERNAME")
SASL_PASSWORD = os.getenv("SASL_PASSWORD")
TOPIC_NAME = os.getenv("TOPIC_NAME")
CONSUMER_GROUP = os.getenv("CONSUMER_GROUP")

SCHEMA_REGISTRY_URL = os.getenv("SCHEMA_REGISTRY_URL")
SCHEMA_REGISTRY_API_KEY = os.getenv("SCHEMA_REGISTRY_API_KEY")
SCHEMA_REGISTRY_API_SECRET = os.getenv("SCHEMA_REGISTRY_API_SECRET")

# Check for required variables
required_vars = [
    "BOOTSTRAP_SERVER", "SASL_USERNAME", "SASL_PASSWORD",
    "TOPIC_NAME", "SCHEMA_REGISTRY_URL",
    "SCHEMA_REGISTRY_API_KEY", "SCHEMA_REGISTRY_API_SECRET"
]
missing_vars = [v for v in required_vars if not os.getenv(v)]
if missing_vars:
    print(f"[ERROR] Missing environment variables: {', '.join(missing_vars)}")
    sys.exit(1)

# If CONSUMER_GROUP is not set, use this default value
if not CONSUMER_GROUP:
    CONSUMER_GROUP = "demo-dr-consumer-group"
    print(f"[WARN] 'CONSUMER_GROUP' is not set. Using default: {CONSUMER_GROUP}")

# =============================================================================
# Configure Schema Registry
# =============================================================================
schema_registry_conf = {
    "url": SCHEMA_REGISTRY_URL,
    "basic.auth.user.info": f"{SCHEMA_REGISTRY_API_KEY}:{SCHEMA_REGISTRY_API_SECRET}"
}
schema_registry_client = SchemaRegistryClient(schema_registry_conf)

# AvroDeserializer with no explicit schema => it fetches from SR using the record's schema ID
avro_deserializer = AvroDeserializer(schema_registry_client, None)

# =============================================================================
# Configure the Consumer
# =============================================================================
consumer_conf = {
    "bootstrap.servers": BOOTSTRAP_SERVER,
    "security.protocol": "SASL_SSL",
    "sasl.mechanism": "PLAIN",
    "sasl.username": SASL_USERNAME,
    "sasl.password": SASL_PASSWORD,
    "key.deserializer": StringDeserializer('utf_8'),
    "value.deserializer": avro_deserializer,
    "group.id": CONSUMER_GROUP,  # Keep consistent across regions for offset sync if needed
    "auto.offset.reset": "earliest"  # or "latest", depending on your use case
}

consumer = DeserializingConsumer(consumer_conf)

# =============================================================================
# Graceful Shutdown Handling
# =============================================================================
def handle_shutdown(sig, frame):
    """
    On SIGINT or SIGTERM, close the consumer gracefully and exit.
    """
    print("\n[INFO] Shutdown signal received. Closing consumer.")
    consumer.close()
    sys.exit(0)

signal.signal(signal.SIGINT, handle_shutdown)
signal.signal(signal.SIGTERM, handle_shutdown)

# =============================================================================
# Main Consumer Loop
# =============================================================================
def main():
    """
    Subscribes to the specified Kafka topic and continuously polls for records.
    Deserializes Avro messages, then prints them to the console.
    """
    print(f"[INFO] Starting Avro consumer for topic: {TOPIC_NAME}")
    print(f"[INFO] Kafka Bootstrap: {BOOTSTRAP_SERVER}")
    print(f"[INFO] Consumer Group: {CONSUMER_GROUP}")
    print(f"[INFO] Schema Registry: {SCHEMA_REGISTRY_URL}")

    consumer.subscribe([TOPIC_NAME])
    print("[INFO] Press Ctrl+C to exit.\n")

    while True:
        # Poll for messages (1.0 sec timeout)
        msg = consumer.poll(timeout=1.0)
        if msg is None:
            continue  # No new messages

        if msg.error():
            # If it's just partition EOF, keep going
            if msg.error().code() == KafkaError._PARTITION_EOF:
                continue
            else:
                # Log any other error
                print(f"[ERROR] {msg.error()}")
                continue
        
        # Successful message
        record_value = msg.value()
        partition = msg.partition()
        offset = msg.offset()

        # Log the consumed record
        print(f"[INFO] Consumed record @ offset {offset}, partition {partition}: {record_value}")

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
avro_producer_app.py

A Python producer application that:
  1. Connects to Confluent Cloud Kafka (SASL_SSL, PLAIN).
  2. Connects to Confluent Cloud Schema Registry to serialize Avro messages.
  3. Automatically registers or references a simple Avro schema for messages.
  4. Generates random data adhering to that Avro schema every 'MESSAGE_INTERVAL'
     seconds (by default, 1 second).
  5. Publishes those messages to a specified Kafka topic.

Prerequisites:
  - Install dependencies:
      - pip install "confluent-kafka[avro]" "python-dotenv"
  - Ensure you have a Confluent Cloud Kafka cluster with appropriate permissions:
      - API Key/Secret with produce access to the Kafka cluster.
      - Schema Registry API Key/Secret with READWRITE permissions.
  - Required environment variables (set in `.env`, `east.env`, or `west.env`):
      - `BOOTSTRAP_SERVER` → Kafka cluster bootstrap URL
      - `SASL_USERNAME` → Kafka API key (username)
      - `SASL_PASSWORD` → Kafka API secret (password)
      - `TOPIC_NAME` → Kafka topic to produce messages
      - `SCHEMA_REGISTRY_URL` → Schema Registry endpoint URL
      - `SCHEMA_REGISTRY_API_KEY` → Schema Registry API key
      - `SCHEMA_REGISTRY_API_SECRET` → Schema Registry API secret
  - Optional environment variables:
      - `MESSAGE_INTERVAL` → Time interval in seconds between producing messages (default: `1.0`)


Usage:
  1. Optionally, specify "east" or "west" as a command-line argument to load
     the corresponding environment file (east.env or west.env). Otherwise,
     it defaults to .env.
  2. Ensure that BOOTSTRAP_SERVER, SASL_USERNAME, SASL_PASSWORD, TOPIC_NAME,
     SCHEMA_REGISTRY_URL, SCHEMA_REGISTRY_API_KEY, and SCHEMA_REGISTRY_API_SECRET 
     are set in the environment file.
  3. Run `python avro_producer_app.py [east|west]`.
  4. Observe the produced messages in your Kafka topic and verify the schema
     in Confluent Cloud's Schema Registry UI or via CLI.

Press Ctrl+C (SIGINT) to exit gracefully.
"""

import os
import sys
import time
import random
import string
import signal
from dotenv import load_dotenv
from confluent_kafka import SerializingProducer
from confluent_kafka.serialization import StringSerializer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer
from confluent_kafka.serialization import SerializationContext, MessageField

# =============================================================================
# Load Environment Variables from .env File
# =============================================================================
def load_environment_file():
    """
    Loads the environment variables from an .env file.
    If a command-line argument is provided (east|west),
    then it loads the corresponding east.env or west.env.
    Otherwise defaults to .env.
    """
    # Default env file
    env_file = ".env"

    # If there's a CLI argument
    if len(sys.argv) > 1:
        env_arg = sys.argv[1].lower()
        if env_arg in ["east", "west"]:
            env_file = f"{env_arg}.env"
        else:
            print(f"[ERROR] Invalid environment argument: {env_arg}")
            print("[INFO] Valid options: 'east', 'west'")
            sys.exit(1)

    # Load the dotenv file
    if os.path.exists(env_file):
        load_dotenv(env_file)
        print(f"[INFO] Loaded environment from {env_file}")
    else:
        print(f"[ERROR] {env_file} does not exist. Please generate or provide it.")
        sys.exit(1)

# =============================================================================
# Avro Schema Definition
# =============================================================================
TRANSACTION_SCHEMA_STR = """
{
  "type": "record",
  "name": "Transaction",
  "namespace": "com.example",
  "fields": [
    {
      "name": "transaction_id",
      "type": "string"
    },
    {
      "name": "customer_id",
      "type": "string"
    },
    {
      "name": "amount",
      "type": "float"
    },
    {
      "name": "timestamp_ms",
      "type": "long"
    }
  ]
}
"""

def transaction_to_avro(transaction, ctx):
    return {
        "transaction_id": transaction['transaction_id'],
        "customer_id": transaction['customer_id'],
        "amount": transaction['amount'],
        "timestamp_ms": transaction['timestamp_ms']
    }

# =============================================================================
# 3. Configuration
# =============================================================================
load_environment_file()

BOOTSTRAP_SERVER = os.getenv("BOOTSTRAP_SERVER")
SASL_USERNAME = os.getenv("SASL_USERNAME")
SASL_PASSWORD = os.getenv("SASL_PASSWORD")
TOPIC_NAME = os.getenv("TOPIC_NAME")

SCHEMA_REGISTRY_URL = os.getenv("SCHEMA_REGISTRY_URL")
SCHEMA_REGISTRY_API_KEY = os.getenv("SCHEMA_REGISTRY_API_KEY")
SCHEMA_REGISTRY_API_SECRET = os.getenv("SCHEMA_REGISTRY_API_SECRET")

# Optional configurations
MESSAGE_INTERVAL = float(os.getenv("MESSAGE_INTERVAL", "1.0"))  # seconds

# Validate that all required environment variables are set
required_vars = [
    "BOOTSTRAP_SERVER",
    "SASL_USERNAME",
    "SASL_PASSWORD",
    "TOPIC_NAME",
    "SCHEMA_REGISTRY_URL",
    "SCHEMA_REGISTRY_API_KEY",
    "SCHEMA_REGISTRY_API_SECRET"
]

missing_vars = [var for var in required_vars if os.getenv(var) is None]
if missing_vars:
    print(f"[ERROR] Missing required environment variables: {', '.join(missing_vars)}")
    sys.exit(1)

# Schema Registry Client Configuration
schema_registry_conf = {
    'url': SCHEMA_REGISTRY_URL,
    'basic.auth.user.info': f"{SCHEMA_REGISTRY_API_KEY}:{SCHEMA_REGISTRY_API_SECRET}"
}
schema_registry_client = SchemaRegistryClient(schema_registry_conf)

# Avro Serializer
avro_serializer = AvroSerializer(
    schema_registry_client,
    TRANSACTION_SCHEMA_STR,
    transaction_to_avro
)

# =============================================================================
# Producer Configuration
# =============================================================================
producer_conf = {
    "bootstrap.servers": BOOTSTRAP_SERVER,
    "security.protocol": "SASL_SSL",
    "sasl.mechanism": "PLAIN",
    "sasl.username": SASL_USERNAME,
    "sasl.password": SASL_PASSWORD,
    "key.serializer": StringSerializer('utf_8'),
    "value.serializer": avro_serializer
}

producer = SerializingProducer(producer_conf)

# =============================================================================
# Graceful Shutdown Handler
# =============================================================================
def handle_shutdown(signal_received, frame):
    """
    Called when a termination signal (SIGINT, SIGTERM) is received.
    Flush pending messages and exit the process.
    """
    print("\n[INFO] Shutdown signal received. Flushing producer.")
    producer.flush(timeout=10)
    sys.exit(0)

# Capture Ctrl+C and other termination signals
signal.signal(signal.SIGINT, handle_shutdown)
signal.signal(signal.SIGTERM, handle_shutdown)

# =============================================================================
# Random Data Generation
# =============================================================================
def generate_random_transaction():
    """
    Generate a random transaction record matching the Avro schema defined above.
    Returns a Python dictionary that will be Avro-serialized by AvroSerializer.
    """
    transaction_id = "".join(random.choices(string.ascii_uppercase + string.digits, k=8))
    customer_id = "".join(random.choices(string.ascii_lowercase, k=6))
    amount = round(random.uniform(1.0, 1000.0), 2)
    timestamp_ms = int(time.time() * 1000)

    return {
        "transaction_id": transaction_id,
        "customer_id": customer_id,
        "amount": amount,
        "timestamp_ms": timestamp_ms
    }

# =============================================================================
# Delivery Callback
# =============================================================================
def delivery_callback(err, msg):
    if err:
        print(f"[ERROR] Message failed delivery: {err}")
    else:
        print(f"[INFO] Message delivered to {msg.topic()} [{msg.partition()}] at offset {msg.offset()}")

# =============================================================================
# Main Producer Loop
# =============================================================================
def main():
    """
    Produce random Avro-serialized messages to the specified topic at
    a specified interval.
    """
    print("[INFO] Starting Avro producer for Confluent Cloud...")
    print(f"[INFO] Kafka Bootstrap: {BOOTSTRAP_SERVER}")
    print(f"[INFO] Topic: {TOPIC_NAME}")
    print(f"[INFO] Schema Registry: {SCHEMA_REGISTRY_URL}")
    print(f"[INFO] Producing a message every {MESSAGE_INTERVAL} seconds.\n")
    print("[INFO] Press Ctrl+C to exit.")

    while True:
        try:
            # Generate random data that matches the Avro schema
            transaction_record = generate_random_transaction()

            # Produce the message to Kafka
            producer.produce(
                topic=TOPIC_NAME,
                value=transaction_record,
                key=None,  # or define your Avro key data if using
                on_delivery=delivery_callback
            )

            # Poll to handle delivery reports
            producer.poll(0)

            # Simple logging
            print(f"[INFO] Produced record: {transaction_record}")

            # Sleep for the configured interval
            time.sleep(MESSAGE_INTERVAL)

        except Exception as err:
            # In production, implement more robust error handling
            print(f"[ERROR] Exception while producing message: {err}")

if __name__ == "__main__":
    main()

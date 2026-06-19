import json
import os
import signal
from datetime import datetime, timezone

import psycopg
from confluent_kafka import Consumer
from dotenv import load_dotenv

load_dotenv()

BOOTSTRAP_SERVERS = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092")
TOPIC = os.getenv("KAFKA_TOPIC", "machine_events")
GROUP_ID = os.getenv("KAFKA_CONSUMER_GROUP", "postgres-writer")

POSTGRES_DSN = (
    f"host={os.getenv('POSTGRES_HOST', 'localhost')} "
    f"port={os.getenv('POSTGRES_PORT', '5432')} "
    f"dbname={os.getenv('POSTGRES_DB', 'machine_monitoring')} "
    f"user={os.getenv('POSTGRES_USER', 'monitoring_user')} "
    f"password={os.getenv('POSTGRES_PASSWORD', 'monitoring_password')}"
)

running = True


def stop(_signum, _frame):
    global running
    running = False


def parse_timestamp(value):
    if not value:
        return datetime.now(timezone.utc)
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def insert_event(conn, event):
    required_fields = ["event_id", "machine_id", "event_type", "status"]
    missing_fields = [field for field in required_fields if not event.get(field)]
    if missing_fields:
        print(f"skipping invalid event, missing fields: {', '.join(missing_fields)}")
        return False

    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO machine_events_raw (
                event_id,
                machine_id,
                line_id,
                event_type,
                status,
                error_code,
                temperature,
                speed,
                batch_id,
                qr_code_id,
                product_code,
                event_time,
                payload
            )
            VALUES (
                %(event_id)s,
                %(machine_id)s,
                %(line_id)s,
                %(event_type)s,
                %(status)s,
                %(error_code)s,
                %(temperature)s,
                %(speed)s,
                %(batch_id)s,
                %(qr_code_id)s,
                %(product_code)s,
                %(event_time)s,
                %(payload)s
            )
            ON CONFLICT (event_id) DO NOTHING;
            """,
            {
                "event_id": event["event_id"],
                "machine_id": event.get("machine_id"),
                "line_id": event.get("line_id"),
                "event_type": event.get("event_type"),
                "status": event.get("status"),
                "error_code": event.get("error_code"),
                "temperature": event.get("temperature"),
                "speed": event.get("speed"),
                "batch_id": event.get("batch_id"),
                "qr_code_id": event.get("qr_code_id"),
                "product_code": event.get("product_code"),
                "event_time": parse_timestamp(event.get("event_time")),
                "payload": json.dumps(event),
            },
        )
    conn.commit()
    return True


def main():
    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)

    consumer = Consumer(
        {
            "bootstrap.servers": BOOTSTRAP_SERVERS,
            "group.id": GROUP_ID,
            "auto.offset.reset": "earliest",
            "enable.auto.commit": False,
        }
    )
    consumer.subscribe([TOPIC])

    print(f"consuming {TOPIC} from {BOOTSTRAP_SERVERS}")
    with psycopg.connect(POSTGRES_DSN) as conn:
        while running:
            msg = consumer.poll(1.0)
            if msg is None:
                continue
            if msg.error():
                print(f"consumer error: {msg.error()}")
                continue

            event = json.loads(msg.value().decode("utf-8"))
            stored = insert_event(conn, event)
            consumer.commit(msg)
            if stored:
                print(f"stored {event['event_id']} {event.get('event_type')} {event.get('status')}")

    consumer.close()
    print("consumer stopped")


if __name__ == "__main__":
    main()

import json
import os
import random
import signal
import time
import uuid
from datetime import datetime, timezone

from confluent_kafka import Producer
from dotenv import load_dotenv

load_dotenv()

BOOTSTRAP_SERVERS = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092")
TOPIC = os.getenv("KAFKA_TOPIC", "machine_events")
EVENT_INTERVAL_SECONDS = float(os.getenv("PRODUCER_EVENT_INTERVAL_SECONDS", "60"))
EVENTS_PER_BATCH = int(os.getenv("PRODUCER_EVENTS_PER_BATCH", "10"))
MAX_BATCHES = os.getenv("PRODUCER_MAX_BATCHES")
MAX_BATCHES = int(MAX_BATCHES) if MAX_BATCHES else None

MACHINES = ["M001", "M002", "M003"]
LINES = ["L01", "L02"]
PRODUCTS = ["BEV-QR-250ML", "BEV-QR-500ML", "BEV-QR-1L"]
ERROR_CODES = ["QR_BLUR", "LOW_INK", "TEMP_HIGH", "SENSOR_MISREAD", "LINE_JAM"]

running = True


def stop(_signum, _frame):
    global running
    running = False


def delivery_report(err, msg):
    if err is not None:
        print(f"delivery failed: {err}")
        return
    print(f"sent {msg.topic()} [{msg.partition()}] offset {msg.offset()}")


def choose_event_type():
    return random.choices(
        ["print_completed", "print_failed", "machine_warning", "temperature_reading", "production_counter"],
        weights=[70, 8, 7, 10, 5],
        k=1,
    )[0]


def build_event():
    event_type = choose_event_type()
    is_failure = event_type == "print_failed"
    is_warning = event_type == "machine_warning"
    machine_id = random.choice(MACHINES)

    temperature = round(random.normalvariate(62, 6), 2)
    if is_warning:
        temperature = round(random.normalvariate(82, 4), 2)

    return {
        "event_id": str(uuid.uuid4()),
        "machine_id": machine_id,
        "line_id": random.choice(LINES),
        "event_type": event_type,
        "status": "failed" if is_failure else "warning" if is_warning else "success",
        "error_code": random.choice(ERROR_CODES) if is_failure or is_warning else None,
        "temperature": temperature,
        "speed": round(random.normalvariate(118, 12), 2),
        "batch_id": f"B{datetime.now(timezone.utc).strftime('%Y%m%d')}",
        "qr_code_id": f"QR-{machine_id}-{random.randint(100000, 999999)}",
        "product_code": random.choice(PRODUCTS),
        "event_time": datetime.now(timezone.utc).isoformat(),
    }


def main():
    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)

    producer = Producer({"bootstrap.servers": BOOTSTRAP_SERVERS})
    print(
        f"producing {EVENTS_PER_BATCH} event(s) every {EVENT_INTERVAL_SECONDS:g}s "
        f"to {TOPIC} on {BOOTSTRAP_SERVERS}"
    )

    batch_count = 0
    while running:
        for _ in range(EVENTS_PER_BATCH):
            event = build_event()
            producer.produce(
                TOPIC,
                key=event["machine_id"],
                value=json.dumps(event),
                callback=delivery_report,
            )
        producer.poll(0)
        producer.flush(10)

        batch_count += 1
        if MAX_BATCHES is not None and batch_count >= MAX_BATCHES:
            break

        time.sleep(EVENT_INTERVAL_SECONDS)

    producer.flush(10)
    print("producer stopped")


if __name__ == "__main__":
    main()

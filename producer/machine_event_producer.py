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
SEED_EVENTS = os.getenv("PRODUCER_SEED_EVENTS", "true").lower() == "true"

LINE_ID = "LINE_01"
MACHINE_ID = "QR_PRINTER_01"
PLANNED_SPEED_CPM = 850
PRODUCT_SKUS = ["BEER_330_CAN", "BEER_500_CAN", "SODA_330_CAN"]
FAULTS = {
    "INK_LOW": "Ink level below threshold",
    "VISION_DIRTY_LENS": "Vision camera lens requires cleaning",
    "PRINTHEAD_TEMP_HIGH": "Printhead temperature above normal band",
    "ENCODER_SIGNAL_LOSS": "Conveyor encoder signal unstable",
    "REJECT_GATE_JAM": "Reject gate did not complete movement",
}

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
        ["PRINT_EVENT", "MACHINE_TELEMETRY", "MACHINE_LOG"],
        weights=[75, 20, 5],
        k=1,
    )[0]


def base_event(event_type):
    now = datetime.now(timezone.utc)
    return {
        "event_id": str(uuid.uuid4()),
        "event_time": now.isoformat(),
        "event_timestamp": now.isoformat(),
        "line_id": LINE_ID,
        "machine_id": MACHINE_ID,
        "event_type": event_type,
        "batch_id": f"B{now:%Y%m%d}{now.hour // 4 + 1}",
    }


def build_print_event():
    event = base_event("PRINT_EVENT")
    missing_code = random.random() < 0.015
    duplicate_code = random.random() < 0.008
    position_error = round(random.normalvariate(0.15, 0.08), 3)
    vision_fail = missing_code or duplicate_code or abs(position_error) > 0.45 or random.random() < 0.06
    print_success = not missing_code and random.random() > 0.03
    reject_flag = (not print_success) or vision_fail

    event.update(
        {
            "product_sku": random.choice(PRODUCT_SKUS),
            "product_code": None,
            "qr_code": None if missing_code else f"{event['batch_id']}-{LINE_ID}-{random.randint(100000, 999999)}",
            "qr_code_id": None if missing_code else f"{event['batch_id']}-{LINE_ID}-{random.randint(100000, 999999)}",
            "print_result": "SUCCESS" if print_success else "FAILED",
            "vision_result": "FAIL" if vision_fail else "PASS",
            "reject_flag": reject_flag,
            "reject_reason": (
                "MISSING_CODE"
                if missing_code
                else "DUPLICATE_CODE"
                if duplicate_code
                else "VISION_FAIL"
                if vision_fail
                else None
            ),
            "position_error_mm": position_error,
            "grade_score": None if missing_code else round(max(0, min(100, random.normalvariate(94, 4) - abs(position_error) * 20)), 2),
            "status": "FAILED" if reject_flag else "SUCCESS",
        }
    )
    return event


def build_telemetry_event():
    event = base_event("MACHINE_TELEMETRY")
    machine_status = random.choices(["RUNNING", "FAULTED", "PLANNED_STOP"], weights=[92, 6, 2], k=1)[0]
    actual_speed = 0 if machine_status != "RUNNING" else random.randint(700, 850)
    fault_code = random.choice(list(FAULTS)) if machine_status == "FAULTED" else None

    event.update(
        {
            "machine_status": machine_status,
            "planned_speed_cpm": PLANNED_SPEED_CPM,
            "actual_speed_cpm": actual_speed,
            "speed": actual_speed,
            "printhead_temp_c": round(random.normalvariate(41, 2.8), 2),
            "temperature": round(random.normalvariate(41, 2.8), 2),
            "ink_level_pct": round(random.uniform(40, 98), 2),
            "ink_consumed_ml": round(actual_speed * 0.0032, 3),
            "vibration_mm_s": round(max(0.4, random.normalvariate(1.8, 0.45) + (0.5 if fault_code else 0)), 3),
            "air_pressure_bar": round(random.normalvariate(5.8, 0.15), 2),
            "items_processed": actual_speed,
            "downtime_seconds": 60 if machine_status in {"FAULTED", "PLANNED_STOP"} else 0,
            "fault_code": fault_code,
            "error_code": fault_code,
            "status": machine_status,
        }
    )
    return event


def build_log_event():
    event = base_event("MACHINE_LOG")
    fault_code = random.choice(list(FAULTS))
    event.update(
        {
            "log_id": f"LOG-{LINE_ID}-{datetime.now(timezone.utc):%Y%m%d%H%M}-{fault_code}",
            "log_timestamp": event["event_time"],
            "fault_code": fault_code,
            "error_code": fault_code,
            "fault_description": FAULTS[fault_code],
            "severity": "HIGH" if fault_code in {"REJECT_GATE_JAM", "ENCODER_SIGNAL_LOSS"} else "MEDIUM",
            "state_from": "RUNNING",
            "state_to": "FAULTED",
            "duration_seconds": 60,
            "operator_id": f"OP{random.randint(1, 6):03d}",
            "machine_status": "FAULTED",
            "status": "FAULTED",
        }
    )
    return event


def build_seed_events():
    events = []

    for product_sku in PRODUCT_SKUS:
        event = build_print_event()
        event.update(
            {
                "product_sku": product_sku,
                "print_result": "SUCCESS",
                "vision_result": "PASS",
                "reject_flag": False,
                "reject_reason": None,
                "status": "SUCCESS",
            }
        )
        events.append(event)

    for reject_reason in ["MISSING_CODE", "DUPLICATE_CODE", "VISION_FAIL"]:
        event = build_print_event()
        event.update(
            {
                "print_result": "FAILED",
                "vision_result": "FAIL",
                "reject_flag": True,
                "reject_reason": reject_reason,
                "status": "FAILED",
            }
        )
        if reject_reason == "MISSING_CODE":
            event.update({"qr_code": None, "qr_code_id": None, "grade_score": None})
        events.append(event)

    for machine_status in ["RUNNING", "PLANNED_STOP"]:
        event = build_telemetry_event()
        event.update(
            {
                "machine_status": machine_status,
                "actual_speed_cpm": 0 if machine_status == "PLANNED_STOP" else PLANNED_SPEED_CPM,
                "speed": 0 if machine_status == "PLANNED_STOP" else PLANNED_SPEED_CPM,
                "downtime_seconds": 60 if machine_status == "PLANNED_STOP" else 0,
                "fault_code": None,
                "error_code": None,
                "status": machine_status,
            }
        )
        events.append(event)

    for fault_code in FAULTS:
        telemetry = build_telemetry_event()
        telemetry.update(
            {
                "machine_status": "FAULTED",
                "actual_speed_cpm": 0,
                "speed": 0,
                "downtime_seconds": 60,
                "fault_code": fault_code,
                "error_code": fault_code,
                "status": "FAULTED",
            }
        )
        events.append(telemetry)

        log_event = build_log_event()
        log_event.update(
            {
                "fault_code": fault_code,
                "error_code": fault_code,
                "fault_description": FAULTS[fault_code],
                "severity": "HIGH" if fault_code in {"REJECT_GATE_JAM", "ENCODER_SIGNAL_LOSS"} else "MEDIUM",
            }
        )
        events.append(log_event)

    return events


def build_event():
    event_type = choose_event_type()
    if event_type == "PRINT_EVENT":
        return build_print_event()
    if event_type == "MACHINE_TELEMETRY":
        return build_telemetry_event()
    return build_log_event()


def main():
    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)

    producer = Producer({"bootstrap.servers": BOOTSTRAP_SERVERS})
    print(
        f"producing {EVENTS_PER_BATCH} event(s) every {EVENT_INTERVAL_SECONDS:g}s "
        f"to {TOPIC} on {BOOTSTRAP_SERVERS}"
    )

    if SEED_EVENTS:
        for event in build_seed_events():
            producer.produce(
                TOPIC,
                key=event["machine_id"],
                value=json.dumps(event),
                callback=delivery_report,
            )
        producer.poll(0)
        producer.flush(10)

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

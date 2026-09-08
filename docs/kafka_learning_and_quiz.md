# Kafka Monitoring Quiz Bank

This is a local-only personal study file. Do not upload it to GitHub unless explicitly approved.

Format:

```text
8 sections
15 multiple-choice questions per section
Answer shown after each question
```

The goal is to learn by answering questions, not by duplicating the project documentation.

## Section 1: Business Context and Requirements

1. What business scenario does this project simulate?
   - A. Online retail checkout fraud
   - B. QR-printing or manufacturing machine monitoring
   - C. Social media engagement tracking
   - D. Monthly accounting close
   - Answer: B. The project models QR-printing/manufacturing machine events.

2. What is the main operational question this project answers?
   - A. Which customer bought the most products this year?
   - B. Are machines and production lines healthy right now?
   - C. Which employee submitted the most reports?
   - D. Which Git branch is newest?
   - Answer: B. The dashboard and alerts focus on current plant health.

3. Why is this project operational monitoring first?
   - A. It only stores annual summary reports
   - B. It focuses on current status, freshness, failures, warnings, and alerts
   - C. It avoids dashboards
   - D. It does not use data
   - Answer: B. The control-room design is about what needs attention now.

4. Which user group is the alert message mainly written for?
   - A. Only database administrators
   - B. Operations supervisors and responsible technicians
   - C. Social media users
   - D. Legal reviewers only
   - Answer: B. The wording is intentionally operations-friendly.

5. Why does the project include both dashboard and alerts?
   - A. Dashboard is for current visibility; alerts are for urgent action
   - B. They are duplicates with no different purpose
   - C. Alerts replace all dashboards
   - D. Dashboards only exist for billing
   - Answer: A. Dashboard supports monitoring, alerts support response.

6. What does `CRITICAL` represent in business terms?
   - A. The repo has many markdown files
   - B. Recent production monitoring has crossed a serious threshold
   - C. The VM is always deleted
   - D. Gmail is disabled
   - Answer: B. `CRITICAL` means immediate operational attention is needed.

7. Why is the alert action plan written in plain language?
   - A. To hide the incident details
   - B. To make it usable by operations users, not only engineers
   - C. To make alerts longer for no reason
   - D. To avoid using Grafana
   - Answer: B. The target reader may be a technician or supervisor.

8. What is the value of a public Grafana dashboard for this portfolio?
   - A. It proves the project has a visible operational interface
   - B. It replaces the codebase
   - C. It removes the need for Kafka
   - D. It makes PostgreSQL public
   - Answer: A. It helps reviewers see a working monitoring surface.

9. Why is the business story reused from earlier projects?
   - A. To avoid learning a new domain while focusing on architecture
   - B. Because Kafka only supports QR printing
   - C. Because Grafana requires QR codes
   - D. Because PostgreSQL cannot store other data
   - Answer: A. Reusing the story lets the learning focus stay on architecture.

10. Which metric best represents production quality pressure?
    - A. Failure rate percentage
    - B. Git commit count
    - C. Number of markdown headings
    - D. Docker image size only
    - Answer: A. Failure rate is directly tied to quality issues.

11. Which metric best represents data freshness risk?
    - A. Latest ingest lag seconds
    - B. Number of README links
    - C. Browser tab count
    - D. GitHub star count
    - Answer: A. Ingest lag shows whether the dashboard may be stale.

12. Why is machine-level status useful?
    - A. It identifies which machine needs attention first
    - B. It hides the line and machine ID
    - C. It only checks GitHub
    - D. It deletes normal events
    - Answer: A. Operations users need to know where to act.

13. Why does the project keep an alert feed?
    - A. To list recent events that deserve human attention
    - B. To store Docker passwords
    - C. To replace every SQL view
    - D. To track browser history
    - Answer: A. The alert feed gives incident context.

14. What is the strongest portfolio message of this project?
    - A. It is only a static dashboard
    - B. It shows streaming, serving, monitoring, alerting, cloud deployment, and cost control
    - C. It only sends email
    - D. It only runs a database
    - Answer: B. The project demonstrates a realistic monitoring architecture.

15. Why is cost control part of the business story?
    - A. Cloud demos can create unnecessary cost if left running
    - B. Cost does not matter in cloud projects
    - C. Kafka cannot run unless billing is high
    - D. Grafana requires maximum VM size
    - Answer: A. Stopping or sizing resources correctly is part of responsible operations.

## Section 2: End-to-End Architecture

1. What is the main data flow?
   - A. Grafana -> Kafka -> Producer -> Gmail
   - B. Producer -> Kafka -> Consumer -> PostgreSQL -> Grafana
   - C. PostgreSQL -> Producer -> Browser -> Kafka
   - D. Gmail -> LINE -> Kafka -> PostgreSQL
   - Answer: B. This is the core project architecture.

2. What does the producer do?
   - A. Creates simulated machine events
   - B. Stores Grafana dashboards
   - C. Sends SQL queries to Text editor
   - D. Hosts LINE
   - Answer: A. The producer emits the event stream.

3. What does Kafka do in this architecture?
   - A. Provides an event backbone and buffer
   - B. Draws dashboard panels
   - C. Sends Gmail directly
   - D. Stores SQL views
   - Answer: A. Kafka decouples producers and consumers.

4. What does the consumer do?
   - A. Reads Kafka messages and writes valid rows to PostgreSQL
   - B. Creates the GCP VM
   - C. Edits the README
   - D. Sends all browser traffic
   - Answer: A. The consumer moves events into the serving database.

5. What is PostgreSQL's main architectural role?
   - A. Operational serving database for Grafana and SQL validation
   - B. Replacement for Kafka
   - C. LINE chat application
   - D. Docker image registry
   - Answer: A. PostgreSQL gives Grafana a stable query layer.

6. Why does Grafana read PostgreSQL instead of Kafka directly?
   - A. PostgreSQL provides SQL views, current state, filters, and dashboard-friendly queries
   - B. Kafka cannot store any messages
   - C. Grafana cannot display dashboards
   - D. PostgreSQL is only decorative
   - Answer: A. Kafka is streaming infrastructure, not the serving layer here.

7. What is the architecture's main separation of concerns?
   - A. Event generation, buffering, storage, monitoring, alerting
   - B. Only markdown writing
   - C. Only VM billing
   - D. Only browser bookmarks
   - Answer: A. Each component has a focused job.

8. Why use Docker Compose locally?
   - A. To run Kafka, PostgreSQL, Grafana, producer, consumer, and bridge together
   - B. To replace all project code
   - C. To create a Google account
   - D. To make SQL impossible
   - Answer: A. Compose keeps the stack reproducible.

9. What is the purpose of running the same stack on the GCP VM?
   - A. To show a cloud-hosted demo path using the same containers
   - B. To delete local development
   - C. To avoid Docker entirely
   - D. To replace Grafana with Gmail
   - Answer: A. The VM makes the demo accessible outside the Windows workstation.

10. Why is this architecture better than a single script writing directly to Grafana?
    - A. It demonstrates realistic streaming and serving boundaries
    - B. It is always cheaper in every case
    - C. It removes all complexity
    - D. It avoids storage
    - Answer: A. The project is meant to show real-world architecture.

11. What layer creates durable queryable operational data?
    - A. PostgreSQL
    - B. Browser tabs
    - C. Gmail app
    - D. Git remote
    - Answer: A. PostgreSQL stores valid machine events and exposes views.

12. What layer is responsible for visual monitoring?
    - A. Grafana
    - B. Kafka topic
    - C. Python virtual environment
    - D. LINE token
    - Answer: A. Grafana is the dashboard and alerting UI.

13. What layer is responsible for fast mobile alert response?
    - A. LINE through the alert bridge
    - B. Text editor
    - C. GitHub README
    - D. PostgreSQL indexes only
    - Answer: A. LINE is used for quick mobile notification.

14. What layer is responsible for official searchable alert history?
    - A. Gmail
    - B. Kafka topic
    - C. VM disk only
    - D. Docker build cache
    - Answer: A. Gmail is used as the official alert record.

15. What would be the main risk of removing PostgreSQL?
    - A. Grafana would lose the SQL serving layer and control-room views
    - B. Kafka would become faster
    - C. Alerts would be clearer
    - D. The VM would automatically stop
    - Answer: A. PostgreSQL is central to dashboard and validation logic.

## Section 3: Kafka, Producer, and Consumer

1. What is the Kafka topic name used by the project?
   - A. `machine_events`
   - B. `grafana_alerts`
   - C. `gmail_messages`
   - D. `vm_logs`
   - Answer: A. `machine_events` is the current event stream.

2. Why is Kafka useful here?
   - A. It buffers events and decouples producer from consumer
   - B. It sends HTML emails
   - C. It replaces Docker
   - D. It creates Grafana panels
   - Answer: A. Kafka provides streaming decoupling.

3. What is the default producer cadence?
   - A. 10 events every 60 seconds
   - B. 1 event per month
   - C. 1000 events every millisecond
   - D. Only when Gmail opens
   - Answer: A. The default cadence keeps the demo live but low-volume.

4. What is a producer in Kafka terms?
   - A. A process that sends messages to a topic
   - B. A PostgreSQL view
   - C. A Grafana panel
   - D. A Cloud Run billing rule
   - Answer: A. Producers publish messages.

5. What is a consumer in Kafka terms?
   - A. A process that reads messages from a topic
   - B. A dashboard user only
   - C. A Gmail inbox
   - D. A VM firewall rule
   - Answer: A. Consumers subscribe and read messages.

6. Why is the producer separate from the consumer?
   - A. To decouple event creation from event storage
   - B. To make all events invalid
   - C. To remove Kafka
   - D. To disable PostgreSQL
   - Answer: A. Decoupling is a key streaming pattern.

7. What happens if the consumer is down while the producer sends events?
   - A. Kafka can still hold messages for later consumption
   - B. Grafana sends the producer code
   - C. PostgreSQL creates messages automatically
   - D. Gmail becomes the Kafka topic
   - Answer: A. Kafka provides buffering.

8. What does the consumer do with invalid smoke-test messages?
   - A. It may skip them if required machine-event fields are missing
   - B. It turns them into dashboards
   - C. It creates a GCP VM
   - D. It deletes the Kafka topic
   - Answer: A. The consumer expects the machine event contract.

9. Which fields are required for a valid raw event?
   - A. `event_id`, `machine_id`, `event_type`, `status`, `event_time`
   - B. `gmail_subject`, `line_token`, `git_branch`
   - C. `dashboard_color`, `browser_tab`, `repo_owner`
   - D. `cloud_run_url`, `invoice_id`, `mouse_position`
   - Answer: A. These are required event fields.

10. Why is a consumer group used?
    - A. To identify the consumer subscription group
    - B. To define Gmail recipients
    - C. To style Grafana colors
    - D. To create VM firewall rules
    - Answer: A. Consumer groups are how Kafka coordinates consumption.

11. What is KRaft mode in this project?
    - A. Kafka running without Zookeeper
    - B. PostgreSQL backup mode
    - C. Grafana alert mode
    - D. Gmail authentication mode
    - Answer: A. The Kafka container uses single-node KRaft.

12. Why does the project start with one topic?
    - A. It is easier to demo and debug
    - B. Kafka cannot support more than one topic
    - C. PostgreSQL requires exactly one topic forever
    - D. LINE cannot receive alerts from multiple topics
    - Answer: A. One topic keeps the first architecture focused.

13. What would be a future reason to split topics?
    - A. Separate production events, telemetry, and alert events by domain
    - B. Delete the consumer
    - C. Remove all schemas
    - D. Avoid monitoring
    - Answer: A. Domain-specific topics can add architecture depth later.

14. Which service writes rows into PostgreSQL?
    - A. `kafka_vm_consumer`
    - B. `kafka_vm_grafana`
    - C. `kafka_vm_line_alert_bridge`
    - D. `gmail_contact_point`
    - Answer: A. The consumer inserts valid events.

15. What is a good first check if no rows appear in PostgreSQL?
    - A. Check producer and consumer logs
    - B. Change the README title
    - C. Reissue the LINE token first
    - D. Delete Grafana
    - Answer: A. Logs show whether events are being produced and consumed.

## Section 4: PostgreSQL Serving Layer and Data Model

1. What is the main raw table?
   - A. `machine_events_raw`
   - B. `gmail_alerts_raw`
   - C. `cloud_run_logs`
   - D. `github_commits`
   - Answer: A. Valid Kafka events are stored in `machine_events_raw`.

2. Why keep raw events?
   - A. For validation, replay-style inspection, and troubleshooting
   - B. To hide all event details
   - C. To avoid SQL
   - D. To replace Kafka messages with screenshots
   - Answer: A. Raw storage keeps evidence.

3. What is a PostgreSQL view in this project?
   - A. Saved SQL logic used by Grafana or validation queries
   - B. A Docker image
   - C. A Gmail app password
   - D. A VM machine type
   - Answer: A. Views expose monitoring-friendly logic.

4. Which view returns the current plant status?
   - A. `control_room_current_status`
   - B. `production_events`
   - C. `machine_events_raw`
   - D. `monitoring_rules`
   - Answer: A. It returns `NORMAL`, `WARNING`, `CRITICAL`, or `NO_DATA`.

5. Which view shows machine-level status?
   - A. `control_room_machine_status`
   - B. `dashboard_realtime_summary`
   - C. `production_events`
   - D. `monitoring_rules`
   - Answer: A. It ranks individual machines.

6. Which view is best for recent problem events?
   - A. `control_room_alert_feed`
   - B. `machine_events_raw` only
   - C. `production_events` only
   - D. `.env.example`
   - Answer: A. The alert feed shows recent attention-worthy events.

7. Which view summarizes the current 15-minute monitoring window?
   - A. `control_room_window_15m`
   - B. `grafana_contact_points`
   - C. `line_broadcasts`
   - D. `docker_services`
   - Answer: A. It calculates the monitoring window metrics.

8. Why is `event_time` important?
   - A. It represents when the machine event happened
   - B. It stores the Gmail sender
   - C. It is the VM zone
   - D. It is the LINE channel ID
   - Answer: A. Event time is business/event occurrence time.

9. Why is `ingest_time` important?
   - A. It represents when PostgreSQL received the event
   - B. It stores the dashboard URL
   - C. It chooses the Kafka topic
   - D. It creates the Docker image
   - Answer: A. Ingest time supports lag calculations.

10. How is ingest lag calculated conceptually?
    - A. Difference between ingest time and event time
    - B. Difference between Git commits
    - C. Difference between Gmail labels
    - D. Difference between VM regions
    - Answer: A. Lag shows pipeline delay.

11. Why does Grafana query views instead of only raw rows?
    - A. Views package business logic into stable query objects
    - B. Raw rows are always empty
    - C. Views remove all data
    - D. Grafana cannot query PostgreSQL
    - Answer: A. Views keep the dashboard simpler and more reliable.

12. What does `monitoring_rules` store?
    - A. Rule metadata and thresholds
    - B. Gmail messages
    - C. Docker passwords
    - D. Browser tabs
    - Answer: A. It records monitoring rule definitions.

13. Which column can identify a production line?
    - A. `line_id`
    - B. `git_status`
    - C. `smtp_host`
    - D. `cloud_region_name_only`
    - Answer: A. `line_id` supports line-level monitoring.

14. Which column can identify a machine?
    - A. `machine_id`
    - B. `repository_id`
    - C. `gmail_thread`
    - D. `browser_title`
    - Answer: A. `machine_id` identifies the machine.

15. How can SQL cross-check the cloud dashboard?
    - A. Use psql inside the running VM to inspect PostgreSQL tables and views
    - B. It sends LINE messages
    - C. It creates Kafka topics
    - D. It provisions Grafana dashboards
    - Answer: A. SQL helps validate the database state behind the dashboard.

## Section 5: Monitoring Logic and Grafana Dashboard

1. What does `NO_DATA` mean?
   - A. No events exist in the current monitoring window
   - B. All machines are perfect
   - C. Gmail failed
   - D. LINE is disabled
   - Answer: A. `NO_DATA` means the window has no events.

2. What failure rate triggers `CRITICAL` by default?
   - A. At least 10 percent
   - B. At least 1 percent
   - C. At least 100 percent only
   - D. Exactly 0 percent
   - Answer: A. The critical failure threshold is 10 percent.

3. What failure rate triggers `WARNING` by default?
   - A. At least 5 percent
   - B. At least 50 percent
   - C. At least 0.1 percent
   - D. Only 100 percent
   - Answer: A. The warning threshold is 5 percent.

4. What average temperature triggers `CRITICAL` by default?
   - A. At least 85 C
   - B. At least 25 C
   - C. At least 45 C
   - D. Exactly 0 C
   - Answer: A. 85 C is the critical temperature threshold.

5. What ingest lag triggers `CRITICAL` by default?
   - A. At least 300 seconds
   - B. At least 3 seconds
   - C. At least 30 minutes only
   - D. Any positive lag
   - Answer: A. 300 seconds is the critical ingest-lag threshold.

6. What is the pending period for the current Grafana rules?
   - A. 60 seconds
   - B. 1 hour
   - C. 1 day
   - D. No pending period ever
   - Answer: A. The rule must remain true for 60 seconds.

7. What is the alert rule evaluation interval?
   - A. 30 seconds
   - B. 30 minutes
   - C. 24 hours
   - D. Only when manually clicked
   - Answer: A. The rule group evaluates every 30 seconds.

8. Which Grafana rule detects severe plant state?
   - A. `Plant State Critical`
   - B. `GitHub Push Complete`
   - C. `LINE Token Created`
   - D. `VM Billing Closed`
   - Answer: A. `Plant State Critical` monitors critical operating state.

9. Which Grafana rule detects delayed ingestion?
   - A. `Ingest Lag Above 300s`
   - B. `Gmail Inbox Full`
   - C. `Kafka Topic Deleted`
   - D. `Docker Image Built`
   - Answer: A. It monitors lag above 300 seconds.

10. Why does `noDataState: OK` make sense for this demo?
    - A. Empty demo windows should not create noise
    - B. No data always means disaster
    - C. It sends LINE every second
    - D. It deletes the dashboard
    - Answer: A. No demo data should not constantly page the user.

11. Why does `execErrState: Error` make sense?
    - A. Query/runtime errors should still be visible
    - B. Errors should be hidden
    - C. It disables PostgreSQL
    - D. It pauses the VM
    - Answer: A. Query failures are operationally important.

12. What does the plant state panel summarize?
    - A. Overall current control-room status
    - B. GitHub branch state only
    - C. Gmail labels only
    - D. Docker image history only
    - Answer: A. It shows the current plant state.

13. What does the machine status board help answer?
    - A. Which machine needs attention first
    - B. Which markdown file is longest
    - C. Which browser tab is active
    - D. Which email address is sender
    - Answer: A. It supports machine-level response.

14. Why is the public dashboard URL used in alert messages?
    - A. Operations users cannot access the owner's Windows workstation localhost
    - B. Public URLs are always free
    - C. It hides the VM
    - D. It removes Grafana authentication from all systems
    - Answer: A. Alert links must point to a reachable dashboard.

15. What should a user check first when an alert fires?
    - A. Open Grafana and confirm plant state plus alert feed
    - B. Delete PostgreSQL
    - C. Recreate the VM immediately
    - D. Change the Git remote
    - Answer: A. The action plan starts with dashboard confirmation.

## Section 6: Gmail, LINE, and Alert Routing

1. What is Gmail used for in the alerting design?
   - A. Official searchable alert history
   - B. Kafka topic storage
   - C. PostgreSQL indexing
   - D. Docker networking
   - Answer: A. Gmail keeps the alert record easy to search.

2. What is LINE used for in the alerting design?
   - A. Fast mobile response for critical incidents
   - B. SQL query execution
   - C. VM disk storage
   - D. Kafka message retention
   - Answer: A. LINE is for quick attention.

3. Why use both Gmail and LINE?
   - A. Gmail is good for history; LINE is good for immediate response
   - B. They do exactly the same thing with no benefit
   - C. Kafka requires both
   - D. PostgreSQL cannot work without both
   - Answer: A. The two channels serve different operational needs.

4. Which contact point sends email?
   - A. `kafka-gmail-email`
   - B. `kafka-line-webhook`
   - C. `machine_events`
   - D. `control_room_alert_feed`
   - Answer: A. `kafka-gmail-email` is the Gmail contact point.

5. Which contact point sends critical alerts to the LINE bridge?
   - A. `kafka-line-webhook`
   - B. `kafka-gmail-email`
   - C. `postgres-writer`
   - D. `kafka_vm_postgres`
   - Answer: A. It posts Grafana webhook payloads to the bridge.

6. Why does the Gmail route use `continue: true`?
   - A. So matching critical alerts can continue to the LINE route too
   - B. So Gmail stops receiving alerts
   - C. So Kafka restarts
   - D. So PostgreSQL ignores rows
   - Answer: A. It enables dual delivery for critical alerts.

7. Which alerts are routed to LINE first?
   - A. Critical project alerts
   - B. Every warning and resolved alert
   - C. Only Git commits
   - D. Only successful events
   - Answer: A. LINE is intentionally critical-only for low noise.

8. What is the current LINE send mode?
   - A. `broadcast`
   - B. `push` only
   - C. `smtp`
   - D. `kafka`
   - Answer: A. Broadcast sends to LINE Official Account friends.

9. What does future `push` mode require?
   - A. `LINE_TO_ID` such as a userId, groupId, or roomId
   - B. Gmail App Password only
   - C. PostgreSQL username only
   - D. Grafana admin password only
   - Answer: A. Push mode needs a target ID.

10. Where does the current LINE bridge run?
    - A. As a Docker Compose container in the project stack
    - B. As Cloud Run
    - C. As a browser plugin
    - D. As a PostgreSQL trigger
    - Answer: A. The current bridge is a Compose service.

11. Does the project currently use Cloud Run for alerting?
    - A. No
    - B. Yes, all alerts go through Cloud Run
    - C. Yes, Kafka is Cloud Run
    - D. Yes, Gmail requires Cloud Run
    - Answer: A. Cloud Run is only a future option.

12. Why avoid Cloud Run right now?
    - A. The in-stack bridge works and avoids extra service cost
    - B. Cloud Run cannot run HTTP services
    - C. LINE requires Cloud Run to be disabled
    - D. Gmail cannot work without Cloud Run
    - Answer: A. The current setup is simpler and cheaper.

13. When might Cloud Run become useful later?
    - A. Public webhook endpoint, retries, routing, audit logging, multi-channel integration
    - B. To replace all monitoring
    - C. To make Kafka impossible
    - D. To delete Gmail
    - Answer: A. Cloud Run can professionalize the alert bridge later.

14. What does the LINE bridge `/grafana` endpoint receive?
    - A. Grafana webhook payloads
    - B. PostgreSQL raw rows directly
    - C. Browser screenshots
    - D. Git commits
    - Answer: A. Grafana posts alert notifications there.

15. What verified the full Grafana-to-LINE route?
    - A. A `POST /grafana` HTTP 200 in the LINE bridge logs after triggering a critical alert
    - B. A README edit only
    - C. A Git branch name
    - D. A Docker image label only
    - Answer: A. The bridge log confirmed Grafana reached the LINE bridge.

## Section 7: GCP VM, Docker, and Cost Control

1. What is the current GCP VM name?
   - A. `kafka-postgres-bi-sg`
   - B. `databricks-sql-prod`
   - C. `line-cloud-run-only`
   - D. `grafana-email-vm-us`
   - Answer: A. The Singapore VM is `kafka-postgres-bi-sg`.

2. Which zone is used?
   - A. `asia-southeast1-a`
   - B. `us-central1-a`
   - C. `europe-west1-b`
   - D. `australia-southeast1-c`
   - Answer: A. The VM is in Singapore zone `asia-southeast1-a`.

3. What machine type is currently used?
   - A. `e2-small`
   - B. `n2-highmem-64`
   - C. `f1-micro`
   - D. `a3-highgpu`
   - Answer: A. `e2-small` is the current low-cost demo VM.

4. Why not use `e2-micro` for the full stack?
   - A. Kafka, PostgreSQL, Grafana, producer, consumer, and bridge can be memory-sensitive
   - B. It cannot run Linux
   - C. It only supports Gmail
   - D. It requires Cloud Run
   - Answer: A. The full stack needs more room than `e2-micro`.

5. What is the upgrade path if `e2-small` becomes unstable?
   - A. `e2-medium`
   - B. Delete the project
   - C. Replace PostgreSQL with Gmail
   - D. Use a GPU VM
   - Answer: A. `e2-medium` gives more memory.

6. What is the most important cost-control action?
   - A. Use the Compute Engine instance schedule instead of running the VM 24/7
   - B. Keep every service running forever
   - C. Use maximum VM size
   - D. Send alerts every second
   - Answer: A. The schedule starts the VM for UAT and stops it afterward.

7. What does Docker Compose run in this project?
   - A. Kafka, PostgreSQL, Grafana, producer, consumer, and LINE bridge
   - B. Only Gmail
   - C. Only a markdown renderer
   - D. Only GitHub
   - Answer: A. Compose orchestrates the project services.

8. Which service exposes Grafana locally?
   - A. `kafka_vm_grafana`
   - B. `kafka_vm_kafka`
   - C. `kafka_vm_consumer`
   - D. `kafka_vm_line_alert_bridge`
   - Answer: A. Grafana is exposed on port 3000.

9. Which service exposes the LINE bridge locally?
   - A. `kafka_vm_line_alert_bridge`
   - B. `kafka_vm_postgres`
   - C. `kafka_vm_kafka`
   - D. `kafka_vm_producer`
   - Answer: A. The bridge listens on port 8080.

10. What is the public Grafana base URL used in alert links?
    - A. `http://136.110.54.120:3000`
    - B. `http://localhost:5432`
    - C. `https://gmail.com`
    - D. `https://line.me`
    - Answer: A. Alert links use the VM public Grafana base URL.

11. Why is `localhost` wrong for operations-team email links?
    - A. It points to the owner's machine, not a public/reachable dashboard for others
    - B. It always points to Gmail
    - C. It is more expensive
    - D. It creates Kafka topics
    - Answer: A. External users cannot open the owner's localhost.

12. Why does the VM export PostgreSQL snapshots to GCS before shutdown?
    - A. So data can be reviewed later even if the Windows workstation was offline during the VM window
    - B. To replace Kafka entirely
    - C. To send Gmail passwords to Cloud Storage
    - D. To make Grafana unavailable
    - Answer: A. GCS becomes the small staging layer for offline review.

13. Which files are exported for offline review?
    - A. Compressed CSV snapshots plus a manifest
    - B. Only screenshots
    - C. Only Docker images
    - D. Only Gmail messages
    - Answer: A. The export writes `.csv.gz` files and `manifest.json`.

14. What should be done before pushing public repo changes?
    - A. Ensure `.env` secrets are not committed
    - B. Paste tokens into README
    - C. Commit Gmail App Password
    - D. Add LINE token to markdown
    - Answer: A. Secrets must stay out of GitHub.

15. What starts the Docker Compose stack after the scheduled VM start?
    - A. VM metadata startup script `scripts/gcp_vm_startup.sh`
    - B. GitHub Actions
    - C. Cloud Run
    - D. A cron job inside the stopped VM
    - Answer: A. The startup script runs automatically when the VM starts.

## Section 8: Troubleshooting and Architecture Trade-Offs

1. Grafana shows no data. What should you check first?
   - A. Whether recent rows exist in PostgreSQL and producer/consumer are running
   - B. Whether the README has screenshots
   - C. Whether Gmail has labels
   - D. Whether Cloud Run exists
   - Answer: A. No data usually starts with pipeline/database checks.

2. Consumer is running but no rows appear. What is a likely cause?
   - A. Producer is not sending valid machine-event messages
   - B. Grafana title is wrong
   - C. Gmail password is too short
   - D. LINE broadcast is disabled
   - Answer: A. The consumer skips invalid message shapes.

3. Alert email not sent. What should you check?
   - A. SMTP settings, Gmail App Password, contact point, notification policy, Grafana logs
   - B. Kafka heap only
   - C. Browser zoom
   - D. VM region name only
   - Answer: A. Email delivery depends on SMTP and Grafana alerting configuration.

4. LINE alert not sent. What should you check?
   - A. Bridge health, `LINE_CHANNEL_ACCESS_TOKEN`, send mode, Grafana route, bridge logs
   - B. Editor theme
   - C. GitHub stars
   - D. PostgreSQL password only
   - Answer: A. LINE depends on bridge + token + route.

5. Public Grafana URL does not open. What is a likely explanation?
   - A. VM is stopped or Grafana/firewall is not reachable
   - B. Kafka topic is too short
   - C. Gmail deleted the dashboard
   - D. LINE token expired immediately
   - Answer: A. Public access depends on VM/runtime/network state.

6. Why not build Kafka -> Grafana direct as the main path?
   - A. Grafana needs queryable monitoring state and SQL-friendly views
   - B. Kafka cannot send any messages
   - C. PostgreSQL is required by Gmail
   - D. LINE cannot work with Grafana
   - Answer: A. PostgreSQL is the serving layer.

7. Why not use only log files instead of PostgreSQL?
   - A. Logs are weaker for dashboard state, SQL checks, alert views, and validation
   - B. Log files are always impossible to read
   - C. Grafana cannot show any logs ever
   - D. Kafka requires log files to be deleted
   - Answer: A. PostgreSQL is more reliable for this control-room layer.

8. Why not use Cloud Run now?
   - A. The in-stack bridge already works and keeps the design cheaper
   - B. Cloud Run cannot receive HTTP
   - C. GCP does not support Cloud Run
   - D. LINE blocks Cloud Run
   - Answer: A. Cloud Run is optional future professionalization.

9. Why not use cron inside the VM for VM start/stop orchestration?
   - A. A stopped VM cannot run its own cron job to start itself
   - B. Cron can only send Gmail
   - C. Cron requires Cloud Run
   - D. Cron deletes Docker Compose
   - Answer: A. Startup must be controlled outside the stopped VM.

10. What is the current architecture trade-off?
    - A. Scheduled VM runtime plus GCS export for cost control vs 24/7 real-time availability
    - B. No alerts vs no dashboard
    - C. No database vs no events
    - D. No Docker vs no repo
    - Answer: A. The project prioritizes a controlled UAT/demo window and retained snapshots over always-on runtime.

11. What should you say if asked why PostgreSQL is used?
    - A. It is the operational serving layer for Grafana, SQL views, validation, and alerts
    - B. It is only there because Kafka cannot run
    - C. It sends LINE messages directly
    - D. It replaces Docker
    - Answer: A. This is the clean interview explanation.

12. What should you say if asked why Kafka is used?
    - A. It decouples event producers and consumers and models real-time streaming
    - B. It is the email server
    - C. It is the dashboard engine
    - D. It is the Git hosting service
    - Answer: A. Kafka is the streaming backbone.

13. What should you say if asked why Gmail and LINE are both used?
    - A. Gmail is for history and audit; LINE is for fast response
    - B. They are required by PostgreSQL
    - C. They replace Grafana
    - D. They are both databases
    - Answer: A. This explains the two-channel design clearly.

14. What should you say if asked how cost is controlled?
    - A. Small VM, low event rate, scheduled start/stop, short-retention GCS export, avoid Cloud Run until needed
    - B. Always use the biggest VM
    - C. Keep every service running forever
    - D. Send alerts to every possible channel
    - Answer: A. These are the main cost-control choices.

15. What is the best 60-second architecture explanation?
    - A. Scheduled VM starts the Docker stack; simulated machines publish events to Kafka; a consumer stores valid events in PostgreSQL; SQL views calculate plant status; Grafana visualizes and alerts; Gmail records alerts; LINE sends fast critical notifications; before shutdown, PostgreSQL snapshots are exported to GCS for later review.
    - B. Gmail sends Kafka to GitHub and Docker reads screenshots.
    - C. PostgreSQL creates QR codes and LINE stores VM disks.
    - D. Cloud Run is required for every alert even though it is not built.
    - Answer: A. This summarizes the project accurately.

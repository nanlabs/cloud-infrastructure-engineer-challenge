environment = "dev"
region      = "us-east-1"
owner       = "supermavster"

# A short window keeps dev create/destroy cycles from piling up scheduled keys.
kms_deletion_window_in_days = 7

# One shared NAT gateway keeps dev cheap; its zone is a single point of failure.
nat_gateway_mode        = "single"
flow_log_retention_days = 7

# Dev is disposable: no standby, and no snapshot or protection to block teardown.
db_multi_az              = false
db_backup_retention_days = 7
db_deletion_protection   = false
db_skip_final_snapshot   = true
db_apply_immediately     = true
log_retention_days       = 7

# Low limits protect a small database: at 5 requests/s a 5 s database stall
# means about 25 concurrent connections, well under its limit.
api_throttling_rate_limit  = 5
api_throttling_burst_limit = 10

# Set to your account ID so a wrong AWS profile fails fast:
# allowed_account_ids = ["<AWS_ACCOUNT_ID>"]

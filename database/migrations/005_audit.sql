-- Every payment, refund, handover and vendor action is logged here (build guide: safety and reliability).
CREATE TABLE audit_log (
  audit_id      BIGINT AUTO_INCREMENT PRIMARY KEY,
  actor_user_id INT NULL,     -- NULL = the system (webhook, background job)
  role          VARCHAR(20) NOT NULL,
  action        VARCHAR(60) NOT NULL,
  table_name    VARCHAR(40) NOT NULL,
  record_id     INT NOT NULL,
  old_value     JSON NULL,
  new_value     JSON NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_audit_record (table_name, record_id),
  KEY idx_audit_created (created_at)
);

-- =====================================================================
--  ATIL — baza sxemasi (DDL)
--  AVTOMATIK YARATILGAN:    |   Manba: existing-atil-ddl   |   Jadvallar: 794
--
--  Chatbot bazani AYNAN shu ma'lumot orqali "ko'radi": model shundan SQL
--  yozadi, SQL tekshiruvchisi ham jadval/ustun/qiymatlarni shunga qarab
--  tekshiradi. QO'LDA TAHRIRLAMANG — baza o'zgarganda qayta yarating:
--      python -m atil_chatbot.tools.generate_ddl
--  Domen izohlari (`-- ` qatorlari jadval ustida) atil_chatbot/app/domain.py
--  da yoziladi; ularni o'zgartirgach:  ... generate_ddl --render-only
--
--  Belgilar:
--    RUXSAT: …        — CHECK bo'yicha ruxsat etilgan qiymatlar
--    BAZADA: 'X' N    — bazada haqiqatda uchraydigan qiymat va soni
--    ISHLATILMAGAN: … — ruxsat etilgan, lekin bazada YO'Q (filtr doim 0 beradi)
--    [har doim NULL]  — ustun bo'sh, ishlatmang
--    oraliq: A … B    — sana ustunidagi eng kichik va eng katta qiymat
-- =====================================================================

-- TABLE: accepted_service_allocation  (satrlar: noma'lum)
CREATE TABLE accepted_service_allocation (
    leg_id uuid NOT NULL,
    accepted_leg_version bigint NOT NULL,
    branch_id uuid NOT NULL,
    confirmed_at timestamptz NOT NULL,
    confirmed_by uuid NOT NULL,
    contract_id uuid NOT NULL,
    customer_id uuid NOT NULL,
    department_id uuid NOT NULL,
    reason varchar(2000) NOT NULL,
    version bigint NOT NULL,
    PRIMARY KEY (leg_id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (confirmed_by) REFERENCES app_user(id),
    FOREIGN KEY (contract_id) REFERENCES service_contract(id),
    FOREIGN KEY (customer_id) REFERENCES customer(id),
    FOREIGN KEY (department_id) REFERENCES reference_data(id),
    FOREIGN KEY (leg_id) REFERENCES transport_execution_leg(id)
);

-- TABLE: accepted_service_allocation_event  (satrlar: noma'lum)
CREATE TABLE accepted_service_allocation_event (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    allocation_json text NOT NULL,  -- [JSON matn]
    leg_id uuid NOT NULL,
    performed_at timestamptz NOT NULL,
    reason varchar(2000) NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (leg_id) REFERENCES transport_execution_leg(id)
);

-- TABLE: ai_extraction_closed  (satrlar: noma'lum)
CREATE TABLE ai_extraction_closed (
    operation_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    reason text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK (((length(reason) >= 1) and (length(reason) <= 1000)))
);

-- TABLE: ai_extraction_command  (satrlar: noma'lum)
CREATE TABLE ai_extraction_command (
    operation_id uuid NOT NULL,
    draft_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    revision bigint NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (draft_id) REFERENCES ai_extraction_draft(draft_id)
);

-- TABLE: ai_extraction_draft  (satrlar: 0 — BO`SH)
CREATE TABLE ai_extraction_draft (
    draft_id uuid NOT NULL,
    operation_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    kind text NOT NULL,  -- RUXSAT: 'DRIVING_LICENSE', 'VEHICLE_PASSPORT', 'VOICE'
    policy_id uuid NOT NULL,
    policy_revision bigint NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    state text NOT NULL,  -- RUXSAT: 'IN_PROGRESS', 'OUTCOME_UNKNOWN', 'DRAFT', 'REVIEWED_DRAFT', 'REJECTED'
    outcome_reason text NOT NULL,
    fields jsonb NOT NULL,  -- [JSON matn]
    revision bigint NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (draft_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK ((jsonb_typeof(fields) = 'array')),
    CHECK (kind in ('DRIVING_LICENSE', 'VEHICLE_PASSPORT', 'VOICE')),
    CHECK ((revision >= 0)),
    CHECK (((jsonb_typeof(sources) = 'array') and ((jsonb_array_length(sources) >= 1) and (jsonb_array_length(sources) <= 2)))),
    CHECK (state in ('IN_PROGRESS', 'OUTCOME_UNKNOWN', 'DRAFT', 'REVIEWED_DRAFT', 'REJECTED'))
);

-- TABLE: ai_extraction_review_closed  (satrlar: noma'lum)
CREATE TABLE ai_extraction_review_closed (
    operation_id uuid NOT NULL,
    draft_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    reason text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (draft_id) REFERENCES ai_extraction_draft(draft_id),
    CHECK (((length(reason) >= 1) and (length(reason) <= 1000)))
);

-- TABLE: ai_extraction_revision  (satrlar: 0 — BO`SH)
CREATE TABLE ai_extraction_revision (
    draft_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'DRAFT', 'REVIEWED_DRAFT', 'REJECTED'
    fields jsonb NOT NULL,  -- [JSON matn]
    actor_id uuid NOT NULL,
    reason text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (draft_id, revision),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (draft_id) REFERENCES ai_extraction_draft(draft_id),
    CHECK (((length(reason) >= 1) and (length(reason) <= 1000))),
    CHECK ((revision > 0)),
    CHECK (state in ('DRAFT', 'REVIEWED_DRAFT', 'REJECTED'))
);

-- TABLE: ai_provider_session  (satrlar: noma'lum)
CREATE TABLE ai_provider_session (
    actor_id uuid NOT NULL,
    provider_origin text NOT NULL,
    session_hash text NOT NULL,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (provider_origin, session_hash),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK ((length(session_hash) = 64))
);

-- TABLE: ai_transfer_audit  (satrlar: 0 — BO`SH)
CREATE TABLE ai_transfer_audit (
    id bigint NOT NULL,
    operation_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    kind text NOT NULL,  -- RUXSAT: 'DRIVING_LICENSE', 'VEHICLE_PASSPORT', 'VOICE', 'CHAT'
    policy_id uuid NOT NULL,
    policy_revision bigint NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'REQUESTED', 'RESPONSE_RECEIVED', 'OUTCOME_UNKNOWN', 'SESSION_DELETED'
    transferred_bytes bigint NOT NULL,
    data_categories jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK (kind in ('DRIVING_LICENSE', 'VEHICLE_PASSPORT', 'VOICE', 'CHAT')),
    CHECK ((length(reason) <= 100)),
    CHECK (state in ('REQUESTED', 'RESPONSE_RECEIVED', 'OUTCOME_UNKNOWN', 'SESSION_DELETED')),
    CHECK ((transferred_bytes >= 0))
);

-- TABLE: ai_transfer_policy  (satrlar: 0 — BO`SH)
CREATE TABLE ai_transfer_policy (
    operation_id uuid NOT NULL,
    policy_id uuid NOT NULL,
    revision bigint NOT NULL,
    actor_id uuid NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'DRAFT', 'APPROVED', 'REVOKED'
    original jsonb NOT NULL,  -- [JSON matn]
    payload jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK ((revision > 0)),
    CHECK (state in ('DRAFT', 'APPROVED', 'REVOKED'))
);

-- TABLE: ai_transfer_policy_attempt  (satrlar: noma'lum)
CREATE TABLE ai_transfer_policy_attempt (
    operation_id uuid NOT NULL,
    policy_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK ((jsonb_typeof(original) = 'object'))
);

-- TABLE: ai_transfer_policy_closed  (satrlar: noma'lum)
CREATE TABLE ai_transfer_policy_closed (
    operation_id uuid NOT NULL,
    policy_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    reason text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 1000)))
);

-- TABLE: app_user  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Tizim foydalanuvchilari (login, parol hash, email, F.I.Sh., faollik holati).
-- TIZIMGA KIRUVCHI BARCHA FOYDALANUVCHILAR SHU JADVALDA. Rollar alohida
-- user_role jadvalida (bitta foydalanuvchida bir nechta rol bo'lishi mumkin).
-- app_user ishlatiladi.
-- ---------------------------------------------------------------------
CREATE TABLE app_user (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    email varchar(128) NOT NULL,
    enabled boolean NOT NULL,
    full_name varchar(256) NOT NULL,
    password varchar(255) NOT NULL,  -- [MAXFIY — o'qish taqiqlangan]
    updated_at timestamptz NOT NULL,
    username varchar(128) NOT NULL,
    branch_id uuid,
    PRIMARY KEY (id)
);

-- TABLE: arm_repair_numbering  (satrlar: noma'lum)
CREATE TABLE arm_repair_numbering (
    id uuid NOT NULL,
    business_date date NOT NULL,
    next_sequence bigint NOT NULL,
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: assignment_decision  (satrlar: noma'lum)
CREATE TABLE assignment_decision (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    decision_json text NOT NULL,  -- [JSON matn]
    origin varchar(64) NOT NULL,
    policy_id uuid,
    policy_version bigint NOT NULL,
    recorded_at timestamptz NOT NULL,
    selection_json text NOT NULL,  -- [JSON matn]
    work_id uuid NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (policy_id) REFERENCES assignment_policy_revision(id)
);

-- TABLE: assignment_policy_head  (satrlar: noma'lum)
CREATE TABLE assignment_policy_head (
    branch_id uuid NOT NULL,
    revision_id uuid NOT NULL,
    version bigint NOT NULL,
    PRIMARY KEY (branch_id),
    FOREIGN KEY (revision_id) REFERENCES assignment_policy_revision(id)
);

-- TABLE: assignment_policy_revision  (satrlar: noma'lum)
CREATE TABLE assignment_policy_revision (
    id uuid NOT NULL,
    basis varchar(2000) NOT NULL,
    branch_id uuid NOT NULL,
    configured boolean NOT NULL,
    payload_hash varchar(64) NOT NULL,
    recorded_at timestamptz NOT NULL,
    recorded_by uuid NOT NULL,
    settings_json text NOT NULL,  -- [JSON matn]
    version bigint NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (recorded_by) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: atil_deploy_migration  (satrlar: noma'lum)
CREATE TABLE atil_deploy_migration (
    id text NOT NULL,
    sha256 text NOT NULL,
    installed_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    CHECK ((length(sha256) = 64))
);

-- TABLE: atil_release_schema_history  (satrlar: noma'lum)
CREATE TABLE atil_release_schema_history (
    release_id text NOT NULL,
    bundle_sha varchar(64) NOT NULL,
    applied_at timestamptz NOT NULL,
    applied_by name NOT NULL,
    PRIMARY KEY (release_id)
);

-- TABLE: atil_transport_payroll_source  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
CREATE TABLE atil_transport_payroll_source (
    leg_id uuid,
    request_id uuid,
    requirement_id uuid,
    trip_id uuid,
    vehicle_id uuid,
    leg_version bigint,
    assignment_segment_id uuid,
    driver_id uuid,
    allocation_event_id uuid,
    department_id uuid,
    branch_id uuid,
    from_instant timestamptz,
    to_instant timestamptz,
    accepted_km text,
    accepted_engine_hours text,
    state text,
    reason text,
    trip_count_claim_id text,
    source_hash text
);

-- TABLE: atil_ui_cycle_release  (satrlar: noma'lum)
CREATE TABLE atil_ui_cycle_release (
    release_id text NOT NULL,
    bundle_sha text NOT NULL,
    applied_at timestamptz NOT NULL,
    applied_by text NOT NULL,
    PRIMARY KEY (release_id)
);

-- TABLE: atil_ui_schema_release  (satrlar: noma'lum)
CREATE TABLE atil_ui_schema_release (
    bundle_sha256 varchar(64) NOT NULL,
    release_commit varchar(40) NOT NULL,
    application_revision varchar(40) NOT NULL,
    applied_by text NOT NULL,
    applied_at timestamptz NOT NULL,
    PRIMARY KEY (bundle_sha256),
    CHECK (((application_revision) ~ '^[a-f0-9]{40}$')),
    CHECK (((bundle_sha256) ~ '^[a-f0-9]{64}$')),
    CHECK (((release_commit) ~ '^[a-f0-9]{40}$'))
);

-- TABLE: attachment  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Yuklangan fayllarning umumiy reyestri (nom, MIME turi, hajmi, URL).
-- FAYLNING O'ZI SHU JADVALDA, LEKIN U QAYSI OBYEKTGA TEGISHLILIGI ALOHIDA
-- BOG'LOVCHI JADVALLARDA: vehicle_photo, vehicle_accident_attachment,
-- vehicle_technical_inspection_photo.
-- ---------------------------------------------------------------------
CREATE TABLE attachment (
    id uuid NOT NULL,
    content_type varchar(255),
    created_at timestamptz,
    created_by varchar(255),
    file_name varchar(255),
    original_name varchar(255),
    size_bytes bigint,
    url varchar(255),
    PRIMARY KEY (id)
);

-- TABLE: audit_event  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Muhim biznes amallarining audit izi: guvohnoma berish/bekor qilish, yoqilg'i
-- limiti o'zgarishi, yoqilg'i ruxsatnomasi tasdiqlash/rad etish, ish haqi
-- tariflarini o'zgartirish. before_snapshot va after_snapshot da o'zgarishdan
-- oldingi va keyingi holat JSON ko'rinishida turadi.
-- KIM NIMANI QACHON O'ZGARTIRGANI SO'RALSA SHU JADVALDAN OLINADI.
-- ---------------------------------------------------------------------
CREATE TABLE audit_event (
    id uuid NOT NULL,
    actor varchar(128),
    after_snapshot text,
    before_snapshot text,
    entity_id uuid,
    entity_type varchar(64),
    event_type varchar(48) NOT NULL,  -- RUXSAT: 'CREDENTIAL_ISSUED', 'CREDENTIAL_REVOKED', 'FUEL_LIMIT_CREATED', 'FUEL_LIMIT_UPDATED', 'FUEL_LIMIT_DEACTIVATED', 'FUEL_AUTHORIZATION_APPROVED', 'FUEL_AUTHORIZATION_REJECTED', 'FUEL_AUTHORIZATION_COMPLETED', 'FUEL_AUTHORIZATION_CANCELLED', 'PAYROLL_RATES_UPDATED', 'FUEL_NORM_UPDATED', 'TRAILER_COMBINATION_UPDATED', 'TECHNICAL_INSPECTION_UPDATED', 'WAYBILL_RELEASE_CORRECTED', 'TRIP_ASSIGNMENT_UPDATED', 'TRAILER_CREATED', 'TRAILER_UPDATED', 'TRAILER_DEACTIVATED'; BAZADA: 'TECHNICAL_INSPECTION_UPDATED' 1350, 'CREDENTIAL_ISSUED' 25, 'FUEL_NORM_UPDATED' 19, 'TRAILER_CREATED' 1, 'WAYBILL_RELEASE_CORRECTED' 1; ISHLATILMAGAN: CREDENTIAL_REVOKED, FUEL_LIMIT_CREATED, FUEL_LIMIT_UPDATED, FUEL_LIMIT_DEACTIVATED, FUEL_AUTHORIZATION_APPROVED, FUEL_AUTHORIZATION_REJECTED, FUEL_AUTHORIZATION_COMPLETED, FUEL_AUTHORIZATION_CANCELLED, PAYROLL_RATES_UPDATED, TRAILER_COMBINATION_UPDATED, TRIP_ASSIGNMENT_UPDATED, TRAILER_UPDATED, TRAILER_DEACTIVATED
    occurred_at timestamptz NOT NULL,
    subject_driver_id uuid,
    subject_vehicle_id uuid,
    summary varchar(512),
    PRIMARY KEY (id),
    CHECK (event_type in ('CREDENTIAL_ISSUED', 'CREDENTIAL_REVOKED', 'FUEL_LIMIT_CREATED', 'FUEL_LIMIT_UPDATED', 'FUEL_LIMIT_DEACTIVATED', 'FUEL_AUTHORIZATION_APPROVED', 'FUEL_AUTHORIZATION_REJECTED', 'FUEL_AUTHORIZATION_COMPLETED', 'FUEL_AUTHORIZATION_CANCELLED', 'PAYROLL_RATES_UPDATED', 'FUEL_NORM_UPDATED', 'TRAILER_COMBINATION_UPDATED', 'TECHNICAL_INSPECTION_UPDATED', 'WAYBILL_RELEASE_CORRECTED', 'TRIP_ASSIGNMENT_UPDATED', 'TRAILER_CREATED', 'TRAILER_UPDATED', 'TRAILER_DEACTIVATED'))
);

-- TABLE: audit_retention_access  (satrlar: 0 — BO`SH)
CREATE TABLE audit_retention_access (
    access_id uuid NOT NULL,
    archive_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    access_kind text NOT NULL,  -- RUXSAT: 'MANIFEST', 'PROOF', 'EVENT'
    event_id uuid,
    reason text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (access_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (archive_id) REFERENCES audit_retention_manifest(archive_id),
    CHECK (access_kind in ('MANIFEST', 'PROOF', 'EVENT')),
    CHECK (((length(btrim(reason)) >= 1) and (length(btrim(reason)) <= 2000)))
);

-- TABLE: audit_retention_archive  (satrlar: noma'lum)
CREATE TABLE audit_retention_archive (
    archive_id uuid NOT NULL,
    event_id uuid NOT NULL,
    payload jsonb NOT NULL,  -- [JSON matn]
    payload_hash text NOT NULL,
    PRIMARY KEY (archive_id, event_id)
);

-- TABLE: audit_retention_cleanup  (satrlar: 0 — BO`SH)
CREATE TABLE audit_retention_cleanup (
    cleanup_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'REQUESTED', 'APPROVED', 'EXECUTED', 'CANCELLED'
    target text NOT NULL,  -- RUXSAT: 'ONLINE', 'ARCHIVE'
    archive_id uuid NOT NULL,
    event_type text NOT NULL,
    policy_revision bigint NOT NULL,
    policy_hash text NOT NULL,
    manifest_hash text NOT NULL,
    actor_id uuid NOT NULL,
    requester_id uuid NOT NULL,
    operation_id uuid NOT NULL,
    authorization_reference text NOT NULL,
    reason text NOT NULL,
    event_count integer NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (cleanup_id, revision),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (archive_id) REFERENCES audit_retention_manifest(archive_id),
    FOREIGN KEY (operation_id) REFERENCES audit_retention_operation(operation_id),
    FOREIGN KEY (requester_id) REFERENCES app_user(id),
    CHECK (((length(btrim(authorization_reference)) >= 1) and (length(btrim(authorization_reference)) <= 2000))),
    CHECK (((state <> 'approved') or (actor_id <> requester_id))),
    CHECK ((event_count > 0)),
    CHECK ((revision > 0)),
    CHECK (state in ('REQUESTED', 'APPROVED', 'EXECUTED', 'CANCELLED')),
    CHECK (target in ('ONLINE', 'ARCHIVE'))
);

-- TABLE: audit_retention_hold  (satrlar: 0 — BO`SH)
CREATE TABLE audit_retention_hold (
    hold_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'ACTIVE', 'RELEASED'
    event_type text NOT NULL,
    entity_type text,
    entity_id uuid,
    operation_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    author_id uuid NOT NULL,
    legal_reference text NOT NULL,
    reason text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (hold_id, revision),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (author_id) REFERENCES app_user(id),
    FOREIGN KEY (operation_id) REFERENCES audit_retention_operation(operation_id),
    CHECK (((entity_id is null) or (entity_type is not null))),
    CHECK (((state <> 'released') or (actor_id <> author_id))),
    CHECK (((length(btrim(legal_reference)) >= 1) and (length(btrim(legal_reference)) <= 2000))),
    CHECK ((revision > 0)),
    CHECK (state in ('ACTIVE', 'RELEASED'))
);

-- TABLE: audit_retention_manifest  (satrlar: noma'lum)
CREATE TABLE audit_retention_manifest (
    archive_id uuid NOT NULL,
    event_type text NOT NULL,
    policy_revision bigint NOT NULL,
    policy_hash text NOT NULL,
    actor_id uuid NOT NULL,
    operation_id uuid NOT NULL,
    event_count integer NOT NULL,
    manifest_hash text NOT NULL,
    archived_at timestamptz NOT NULL,
    reason text NOT NULL,
    PRIMARY KEY (archive_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (operation_id) REFERENCES audit_retention_operation(operation_id),
    CHECK ((event_count > 0)),
    CHECK ((manifest_hash ~ '^[a-f0-9]{64}$'))
);

-- TABLE: audit_retention_operation  (satrlar: 0 — BO`SH)
CREATE TABLE audit_retention_operation (
    operation_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    state text NOT NULL,  -- RUXSAT: 'APPLIED', 'NOT_EXECUTED'
    result jsonb,  -- [JSON matn]
    reason text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK (((state = 'applied') = (result is not null))),
    CHECK (state in ('APPLIED', 'NOT_EXECUTED'))
);

-- TABLE: audit_retention_policy  (satrlar: 0 — BO`SH)
CREATE TABLE audit_retention_policy (
    event_type text NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'DRAFT', 'APPROVED', 'REVOKED'
    operation_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    author_id uuid NOT NULL,
    online_retention_days integer NOT NULL,
    archive_retention_days integer,
    valid_from timestamptz NOT NULL,
    valid_until timestamptz NOT NULL,
    applicability_reference text NOT NULL,
    approval_reference text,
    reason text NOT NULL,
    policy_hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (event_type, revision),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (author_id) REFERENCES app_user(id),
    FOREIGN KEY (operation_id) REFERENCES audit_retention_operation(operation_id),
    CHECK (((length(btrim(applicability_reference)) >= 1) and (length(btrim(applicability_reference)) <= 2000))),
    CHECK (((archive_retention_days >= 1) and (archive_retention_days <= 365250))),
    CHECK ((valid_until > valid_from)),
    CHECK (((state <> 'approved') or ((actor_id <> author_id) and ((coalesce(length(btrim(approval_reference)), 0) >= 1) and (coalesce(length(btrim(approval_reference)), 0) <= 2000))))),
    CHECK (((online_retention_days >= 1) and (online_retention_days <= 365250))),
    CHECK ((policy_hash ~ '^[a-f0-9]{64}$')),
    CHECK (((length(btrim(reason)) >= 1) and (length(btrim(reason)) <= 2000))),
    CHECK ((revision > 0)),
    CHECK (state in ('DRAFT', 'APPROVED', 'REVOKED'))
);

-- TABLE: audit_retention_proof  (satrlar: 0 — BO`SH)
CREATE TABLE audit_retention_proof (
    archive_id uuid NOT NULL,
    event_id uuid NOT NULL,
    source_table text NOT NULL,  -- RUXSAT: 'AUDIT_EVENT', 'CRITICAL_AUDIT_EVENT'
    event_type text NOT NULL,
    entity_type text,
    entity_id uuid,
    occurred_at timestamptz NOT NULL,
    payload_hash text NOT NULL,
    PRIMARY KEY (archive_id, event_id),
    FOREIGN KEY (archive_id) REFERENCES audit_retention_manifest(archive_id),
    CHECK ((payload_hash ~ '^[a-f0-9]{64}$')),
    CHECK (source_table in ('AUDIT_EVENT', 'CRITICAL_AUDIT_EVENT'))
);

-- TABLE: audit_retention_source  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
CREATE TABLE audit_retention_source (
    id uuid,
    source_table text,
    event_type text,
    entity_type varchar(64),
    entity_id uuid,
    occurred_at timestamptz,
    payload jsonb  -- [JSON matn]
);

-- TABLE: auth_jwt_session  (satrlar: noma'lum)
CREATE TABLE auth_jwt_session (
    jti uuid NOT NULL,
    user_id uuid NOT NULL,
    session_family uuid NOT NULL,
    token_sha256 text NOT NULL,  -- [MAXFIY — o'qish taqiqlangan]
    credential_sha256 text NOT NULL,  -- [MAXFIY — o'qish taqiqlangan]
    issued_at timestamptz NOT NULL,
    expires_at timestamptz NOT NULL,
    revoked_at timestamptz,
    revocation_reason text,
    PRIMARY KEY (jti),
    FOREIGN KEY (user_id) REFERENCES app_user(id),
    CHECK ((expires_at > issued_at)),
    CHECK ((((revoked_at is null) and (revocation_reason is null)) or ((revoked_at is not null) and (revocation_reason = any (array['logout', 'credential_change']))))),
    CHECK ((credential_sha256 ~ '^[a-f0-9]{64}$')),
    CHECK ((token_sha256 ~ '^[a-f0-9]{64}$'))
);

-- TABLE: authorized_recipient  (satrlar: noma'lum)
CREATE TABLE authorized_recipient (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    created_by varchar(128),
    full_name varchar(256) NOT NULL,
    phone varchar(32) NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: canonical_inspection_repair_basis  (satrlar: 0 — BO`SH)
CREATE TABLE canonical_inspection_repair_basis (
    revision_id uuid NOT NULL,
    inspection_id uuid NOT NULL,
    source_version bigint NOT NULL,
    source_hash text NOT NULL,
    vehicle_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    driver_id uuid NOT NULL,
    trailer_id uuid,
    trip_id uuid,
    waybill_id uuid,
    inspection_type text NOT NULL,  -- RUXSAT: 'PRE_TRIP', 'POST_TRIP'
    actor_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    inspected_at timestamptz NOT NULL,
    basis_created_at timestamptz NOT NULL,
    PRIMARY KEY (revision_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (driver_id) REFERENCES driver(id),
    FOREIGN KEY (revision_id) REFERENCES safety_technical_inspection_revision(id),
    FOREIGN KEY (trailer_id) REFERENCES trailers(id),
    FOREIGN KEY (trip_id) REFERENCES trip(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id),
    FOREIGN KEY (waybill_id) REFERENCES waybill(id),
    CHECK (inspection_type in ('PRE_TRIP', 'POST_TRIP')),
    CHECK ((source_hash ~ '^[0-9a-f]{64}$')),
    CHECK ((source_version > 0))
);

-- TABLE: canonical_inspection_repair_link  (satrlar: noma'lum)
CREATE TABLE canonical_inspection_repair_link (
    revision_id uuid NOT NULL,
    defect_id uuid NOT NULL,
    repair_id uuid NOT NULL,
    operation_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (revision_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (defect_id) REFERENCES fleet_defect(defect_id),
    FOREIGN KEY (repair_id) REFERENCES vehicle_repair(id),
    FOREIGN KEY (revision_id) REFERENCES canonical_inspection_repair_basis(revision_id)
);

-- TABLE: carrier  (satrlar: noma'lum)
CREATE TABLE carrier (
    id uuid NOT NULL,
    contact_email varchar(128),
    contact_person varchar(128),
    contact_phone varchar(64),
    created_at timestamptz NOT NULL,
    inn varchar(32),
    kind varchar(32),
    name varchar(256) NOT NULL,
    status varchar(32),  -- BAZADA (eng ko'p uchraydiganlari): 'INACTIVE' 1
    supports_hazard boolean,
    updated_at timestamptz,
    PRIMARY KEY (id)
);

-- TABLE: carrier_admission_context  (satrlar: noma'lum)
CREATE TABLE carrier_admission_context (
    revision_id uuid NOT NULL,
    kind varchar(16) NOT NULL,
    subject_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    previous_head_id uuid,
    previous_revision_id uuid,
    previous_revision bigint,
    tx_id bigint NOT NULL,
    PRIMARY KEY (revision_id)
);

-- TABLE: carrier_admission_head  (satrlar: 0 — BO`SH)
CREATE TABLE carrier_admission_head (
    id uuid NOT NULL,
    branch_id uuid NOT NULL,
    carrier_id uuid,
    current_revision_id uuid NOT NULL,
    kind varchar(16) NOT NULL,  -- RUXSAT: 'SOURCE', 'POLICY', 'AGREEMENT'
    revision bigint NOT NULL,
    subject_id uuid NOT NULL,
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    CHECK (kind in ('SOURCE', 'POLICY', 'AGREEMENT'))
);

-- TABLE: carrier_admission_operation  (satrlar: 0 — BO`SH)
CREATE TABLE carrier_admission_operation (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    kind varchar(16) NOT NULL,  -- RUXSAT: 'SOURCE', 'POLICY', 'AGREEMENT'
    original_json text NOT NULL,  -- [JSON matn]
    payload_hash varchar(64) NOT NULL,
    recorded_at timestamptz NOT NULL,
    result_json text NOT NULL,  -- [JSON matn]
    revision_id uuid NOT NULL,
    subject_id uuid NOT NULL,
    tx_id bigint NOT NULL,
    PRIMARY KEY (id),
    CHECK (kind in ('SOURCE', 'POLICY', 'AGREEMENT'))
);

-- TABLE: carrier_admission_revision  (satrlar: 0 — BO`SH)
CREATE TABLE carrier_admission_revision (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    actor_name varchar(256) NOT NULL,
    branch_id uuid NOT NULL,
    carrier_id uuid,
    data_json text NOT NULL,  -- [JSON matn]
    kind varchar(16) NOT NULL,  -- RUXSAT: 'SOURCE', 'POLICY', 'AGREEMENT'
    operation_id uuid NOT NULL,
    previous_revision_id uuid,
    review_reason varchar(2000) NOT NULL,
    review_reference varchar(256) NOT NULL,
    reviewed_at timestamptz NOT NULL,
    revision bigint NOT NULL,
    subject_id uuid NOT NULL,
    PRIMARY KEY (id),
    CHECK (kind in ('SOURCE', 'POLICY', 'AGREEMENT'))
);

-- TABLE: carrier_admission_transition  (satrlar: noma'lum)
CREATE TABLE carrier_admission_transition (
    revision_id uuid NOT NULL,
    head_id uuid NOT NULL,
    tx_id bigint NOT NULL,
    PRIMARY KEY (revision_id)
);

-- TABLE: carrier_erp_identity_operation  (satrlar: 0 — BO`SH)
CREATE TABLE carrier_erp_identity_operation (
    operation_id uuid NOT NULL,
    carrier_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    state varchar(16) NOT NULL,  -- RUXSAT: 'APPLIED', 'NOT_EXECUTED'
    original_json text NOT NULL,  -- [JSON matn]
    result_json text,  -- [JSON matn]
    reason text,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (carrier_id) REFERENCES carrier(id),
    CHECK (((((state) = 'applied') and (result_json is not null) and (reason is null)) or (((state) = 'not_executed') and (result_json is null) and (length(trim(both from reason)) > 0)))),
    CHECK (state in ('APPLIED', 'NOT_EXECUTED'))
);

-- TABLE: carrier_erp_identity_revision  (satrlar: 0 — BO`SH)
CREATE TABLE carrier_erp_identity_revision (
    id uuid NOT NULL,
    mapping_id uuid NOT NULL,
    carrier_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    revision bigint NOT NULL,
    state varchar(16) NOT NULL,  -- RUXSAT: 'ASSERTED', 'APPROVED', 'REVOKED'
    actor_id uuid NOT NULL,
    author_id uuid NOT NULL,
    source_system varchar(128) NOT NULL,
    external_id varchar(256) NOT NULL,
    identity_hash varchar(64) NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    result_json text NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (author_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (carrier_id) REFERENCES carrier(id),
    CHECK ((revision > 0)),
    CHECK (state in ('ASSERTED', 'APPROVED', 'REVOKED'))
);

-- TABLE: carrier_erp_identity_source  (satrlar: noma'lum)
CREATE TABLE carrier_erp_identity_source (
    source_system varchar(128) NOT NULL,
    external_id varchar(256) NOT NULL,
    carrier_id uuid NOT NULL,
    PRIMARY KEY (source_system, external_id),
    FOREIGN KEY (carrier_id) REFERENCES carrier(id)
);

-- TABLE: carrier_external_execution_closed  (satrlar: noma'lum)
CREATE TABLE carrier_external_execution_closed (
    operation_id uuid NOT NULL,
    kind varchar(16) NOT NULL,
    order_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    close_reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    result_json text NOT NULL,  -- [JSON matn]
    tx_id bigint NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (order_id) REFERENCES carrier_order(id)
);

-- TABLE: carrier_external_execution_record  (satrlar: 0 — BO`SH)
CREATE TABLE carrier_external_execution_record (
    operation_id uuid NOT NULL,
    kind varchar(16) NOT NULL,  -- RUXSAT: 'POLICY', 'TARIFF', 'REPORT', 'DECISION', 'REVERSAL'
    subject_id uuid NOT NULL,
    order_id uuid,
    branch_id uuid NOT NULL,
    revision bigint NOT NULL,
    actor_id uuid NOT NULL,
    actor_name text NOT NULL,
    recorded_at timestamptz NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    payload_json text NOT NULL,  -- [JSON matn]
    content_hash varchar(64) NOT NULL,
    tx_id bigint NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (order_id) REFERENCES carrier_order(id),
    CHECK (kind in ('POLICY', 'TARIFF', 'REPORT', 'DECISION', 'REVERSAL')),
    CHECK ((revision > 0))
);

-- TABLE: carrier_external_qualification  (satrlar: 0 — BO`SH)
CREATE TABLE carrier_external_qualification (
    operation_id uuid NOT NULL,
    kind text NOT NULL,  -- RUXSAT: 'POLICY', 'PACKAGE', 'DECISION', 'REVOCATION', 'BINDING'
    subject_id uuid NOT NULL,
    order_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    revision bigint NOT NULL,
    actor_id uuid NOT NULL,
    actor_name text NOT NULL,
    recorded_at timestamptz NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    payload_json text NOT NULL,  -- [JSON matn]
    content_hash text NOT NULL,
    tx_id bigint NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (order_id) REFERENCES carrier_order(id),
    CHECK (kind in ('POLICY', 'PACKAGE', 'DECISION', 'REVOCATION', 'BINDING')),
    CHECK ((revision > 0))
);

-- TABLE: carrier_external_qualification_closed  (satrlar: noma'lum)
CREATE TABLE carrier_external_qualification_closed (
    operation_id uuid NOT NULL,
    kind text NOT NULL,
    order_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    tx_id bigint NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (order_id) REFERENCES carrier_order(id)
);

-- TABLE: carrier_invoice  (satrlar: 0 — BO`SH)
CREATE TABLE carrier_invoice (
    id uuid NOT NULL,
    billed_total numeric(16,2) NOT NULL,
    comment varchar(2000),
    created_at timestamptz NOT NULL,
    currency varchar(8) NOT NULL,
    due_at date,
    expected_total numeric(16,2) NOT NULL,
    invoice_number varchar(64) NOT NULL,
    issued_at date NOT NULL,
    status varchar(32) NOT NULL,  -- RUXSAT: 'RECEIVED', 'UNDER_REVIEW', 'MATCHED', 'DISCREPANCY', 'APPROVED', 'REJECTED', 'PAID'
    updated_at timestamptz NOT NULL,
    variance_percent numeric(10,4) NOT NULL,
    variance_total numeric(16,2) NOT NULL,
    version bigint NOT NULL,
    carrier_id uuid,
    PRIMARY KEY (id),
    FOREIGN KEY (carrier_id) REFERENCES carrier(id),
    CHECK (status in ('RECEIVED', 'UNDER_REVIEW', 'MATCHED', 'DISCREPANCY', 'APPROVED', 'REJECTED', 'PAID'))
);

-- TABLE: carrier_invoice_allocation_closed_operation  (satrlar: noma'lum)
CREATE TABLE carrier_invoice_allocation_closed_operation (
    operation_id uuid NOT NULL,
    invoice_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (invoice_id) REFERENCES carrier_invoice(id)
);

-- TABLE: carrier_invoice_approval_closed_operation  (satrlar: 0 — BO`SH)
CREATE TABLE carrier_invoice_approval_closed_operation (
    kind text NOT NULL,  -- RUXSAT: 'POLICY', 'DECISION'
    operation_id uuid NOT NULL,
    invoice_id uuid,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    closure_reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (kind, operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (invoice_id) REFERENCES carrier_invoice(id),
    CHECK ((((kind = 'policy') and (invoice_id is null)) or ((kind = 'decision') and (invoice_id is not null)))),
    CHECK (kind in ('POLICY', 'DECISION'))
);

-- TABLE: carrier_invoice_approval_policy  (satrlar: noma'lum)
CREATE TABLE carrier_invoice_approval_policy (
    operation_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    expected_version bigint NOT NULL,
    revision bigint NOT NULL,
    previous_hash text NOT NULL,
    policy_hash text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: carrier_invoice_document_closed_operation  (satrlar: noma'lum)
CREATE TABLE carrier_invoice_document_closed_operation (
    operation_id uuid NOT NULL,
    invoice_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    closure_reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (invoice_id) REFERENCES carrier_invoice(id)
);

-- TABLE: carrier_invoice_document_revision  (satrlar: noma'lum)
CREATE TABLE carrier_invoice_document_revision (
    operation_id uuid NOT NULL,
    invoice_id uuid NOT NULL,
    carrier_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    expected_version bigint NOT NULL,
    revision bigint NOT NULL,
    previous_hash text NOT NULL,
    expected_review_revision bigint NOT NULL,
    snapshot jsonb NOT NULL,  -- [JSON matn]
    snapshot_hash text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (carrier_id) REFERENCES carrier(id),
    FOREIGN KEY (invoice_id) REFERENCES carrier_invoice(id)
);

-- TABLE: carrier_invoice_erp_cancellation  (satrlar: noma'lum)
CREATE TABLE carrier_invoice_erp_cancellation (
    operation_id uuid NOT NULL,
    event_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (event_id) REFERENCES carrier_invoice_erp_outbox(event_id)
);

-- TABLE: carrier_invoice_erp_closed  (satrlar: noma'lum)
CREATE TABLE carrier_invoice_erp_closed (
    operation_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    kind text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: carrier_invoice_erp_delivery  (satrlar: noma'lum)
CREATE TABLE carrier_invoice_erp_delivery (
    event_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,
    attempt integer NOT NULL,
    detail text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (event_id, revision),
    FOREIGN KEY (event_id) REFERENCES carrier_invoice_erp_outbox(event_id)
);

-- TABLE: carrier_invoice_erp_dispatch  (satrlar: noma'lum)
CREATE TABLE carrier_invoice_erp_dispatch (
    operation_id uuid NOT NULL,
    event_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    attempt integer NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (event_id) REFERENCES carrier_invoice_erp_outbox(event_id)
);

-- TABLE: carrier_invoice_erp_outbox  (satrlar: noma'lum)
CREATE TABLE carrier_invoice_erp_outbox (
    event_id uuid NOT NULL,
    invoice_id uuid NOT NULL,
    invoice_revision bigint NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    approval_id uuid NOT NULL,
    policy_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    payload jsonb NOT NULL,  -- [JSON matn]
    wire_payload text NOT NULL,
    payload_hash text NOT NULL,
    idempotency_key text NOT NULL,
    destination_hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (event_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (approval_id) REFERENCES carrier_invoice_financial_decision(operation_id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (invoice_id) REFERENCES carrier_invoice(id),
    FOREIGN KEY (policy_id) REFERENCES carrier_invoice_erp_policy(operation_id)
);

-- TABLE: carrier_invoice_erp_policy  (satrlar: noma'lum)
CREATE TABLE carrier_invoice_erp_policy (
    operation_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: carrier_invoice_erp_receipt  (satrlar: noma'lum)
CREATE TABLE carrier_invoice_erp_receipt (
    event_id uuid NOT NULL,
    provider text NOT NULL,
    receipt_id text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    received_at timestamptz NOT NULL,
    PRIMARY KEY (event_id),
    FOREIGN KEY (event_id) REFERENCES carrier_invoice_erp_outbox(event_id)
);

-- TABLE: carrier_invoice_execution_allocation  (satrlar: noma'lum)
CREATE TABLE carrier_invoice_execution_allocation (
    operation_id uuid NOT NULL,
    invoice_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    previous_hash text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    snapshot jsonb NOT NULL,  -- [JSON matn]
    snapshot_hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (invoice_id) REFERENCES carrier_invoice(id)
);

-- TABLE: carrier_invoice_financial_closed_operation  (satrlar: noma'lum)
CREATE TABLE carrier_invoice_financial_closed_operation (
    operation_id uuid NOT NULL,
    invoice_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    closure_reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (invoice_id) REFERENCES carrier_invoice(id)
);

-- TABLE: carrier_invoice_financial_decision  (satrlar: noma'lum)
CREATE TABLE carrier_invoice_financial_decision (
    operation_id uuid NOT NULL,
    invoice_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    expected_version bigint NOT NULL,
    revision bigint NOT NULL,
    previous_hash text NOT NULL,
    decision_hash text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    state text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (invoice_id) REFERENCES carrier_invoice(id)
);

-- TABLE: carrier_invoice_financial_review  (satrlar: noma'lum)
CREATE TABLE carrier_invoice_financial_review (
    operation_id uuid NOT NULL,
    invoice_id uuid NOT NULL,
    carrier_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    expected_version bigint NOT NULL,
    revision bigint NOT NULL,
    previous_hash text NOT NULL,
    snapshot jsonb NOT NULL,  -- [JSON matn]
    snapshot_hash text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (carrier_id) REFERENCES carrier(id),
    FOREIGN KEY (invoice_id) REFERENCES carrier_invoice(id)
);

-- TABLE: carrier_invoice_line  (satrlar: noma'lum)
CREATE TABLE carrier_invoice_line (
    invoice_id uuid NOT NULL,
    billed_amount numeric(16,2) NOT NULL,
    description varchar(500) NOT NULL,
    expected_amount numeric(16,2),
    leg_id uuid,
    matched boolean NOT NULL,
    shipment_id uuid,
    variance_amount numeric(16,2) NOT NULL,
    variance_percent numeric(10,4) NOT NULL,
    line_index integer NOT NULL,
    PRIMARY KEY (invoice_id, line_index),
    FOREIGN KEY (invoice_id) REFERENCES carrier_invoice(id)
);

-- TABLE: carrier_invoice_review_closed_operation  (satrlar: noma'lum)
CREATE TABLE carrier_invoice_review_closed_operation (
    operation_id uuid NOT NULL,
    invoice_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    action text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    closure_reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (invoice_id) REFERENCES carrier_invoice(id)
);

-- TABLE: carrier_invoice_review_event  (satrlar: noma'lum)
CREATE TABLE carrier_invoice_review_event (
    operation_id uuid NOT NULL,
    invoice_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    expected_version bigint NOT NULL,
    revision bigint NOT NULL,
    action text NOT NULL,
    state text NOT NULL,
    reason text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (invoice_id) REFERENCES carrier_invoice(id)
);

-- TABLE: carrier_order  (satrlar: noma'lum)
CREATE TABLE carrier_order (
    id uuid NOT NULL,
    agreement_id uuid NOT NULL,
    award_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    carrier_id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    snapshot_hash varchar(64) NOT NULL,
    snapshot_json text NOT NULL,  -- [JSON matn]
    state varchar(32) NOT NULL,
    tender_id uuid NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: carrier_order_response  (satrlar: noma'lum)
CREATE TABLE carrier_order_response (
    operation_id uuid NOT NULL,
    order_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    policy_id uuid NOT NULL,
    outcome text NOT NULL,
    received_at timestamptz NOT NULL,
    recorded_at timestamptz NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    result_json text NOT NULL,  -- [JSON matn]
    document_bytes bytea NOT NULL,
    document_hash text NOT NULL,
    tx_id bigint NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (order_id) REFERENCES carrier_order(id),
    FOREIGN KEY (policy_id) REFERENCES carrier_tender_process_policy_revision(id)
);

-- TABLE: carrier_order_response_closed_operation  (satrlar: noma'lum)
CREATE TABLE carrier_order_response_closed_operation (
    operation_id uuid NOT NULL,
    order_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    result_json text NOT NULL,  -- [JSON matn]
    close_reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    tx_id bigint NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (order_id) REFERENCES carrier_order(id)
);

-- TABLE: carrier_order_response_correction  (satrlar: noma'lum)
CREATE TABLE carrier_order_response_correction (
    id uuid NOT NULL,
    order_id uuid NOT NULL,
    operation_id uuid NOT NULL,
    previous_response_operation_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    result_json text NOT NULL,  -- [JSON matn]
    response_json text NOT NULL,  -- [JSON matn]
    document_bytes bytea NOT NULL,
    document_hash varchar(64) NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (order_id) REFERENCES carrier_order(id)
);

-- TABLE: carrier_order_response_correction_closed  (satrlar: noma'lum)
CREATE TABLE carrier_order_response_correction_closed (
    operation_id uuid NOT NULL,
    order_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    result_json text NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id)
);

-- TABLE: carrier_tender  (satrlar: 0 — BO`SH)
CREATE TABLE carrier_tender (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    description varchar(1000),
    expires_at timestamptz,
    shipment_id uuid NOT NULL,
    status varchar(16) NOT NULL,  -- RUXSAT: 'OPEN', 'CLOSED', 'CANCELLED'
    tender_number varchar(64) NOT NULL,
    title varchar(256) NOT NULL,
    updated_at timestamptz,
    version bigint NOT NULL,
    PRIMARY KEY (id),
    CHECK (status in ('OPEN', 'CLOSED', 'CANCELLED'))
);

-- TABLE: carrier_tender_award  (satrlar: noma'lum)
CREATE TABLE carrier_tender_award (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    agreement_id uuid NOT NULL,
    awarded_at timestamptz NOT NULL,
    bid_id uuid NOT NULL,
    bid_revision_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    carrier_id uuid NOT NULL,
    previous_tender_version bigint NOT NULL,
    snapshot_hash varchar(64) NOT NULL,
    snapshot_json text NOT NULL,  -- [JSON matn]
    tender_id uuid NOT NULL,
    tender_version bigint NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: carrier_tender_award_context  (satrlar: noma'lum)
CREATE TABLE carrier_tender_award_context (
    award_id uuid NOT NULL,
    tender_id uuid NOT NULL,
    tx_id bigint NOT NULL,
    row_snapshot jsonb NOT NULL,  -- [JSON matn]
    PRIMARY KEY (award_id)
);

-- TABLE: carrier_tender_award_operation  (satrlar: noma'lum)
CREATE TABLE carrier_tender_award_operation (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    award_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    order_id uuid NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    payload_hash varchar(64) NOT NULL,
    recorded_at timestamptz NOT NULL,
    result_json text NOT NULL,  -- [JSON matn]
    tender_id uuid NOT NULL,
    tx_id bigint NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: carrier_tender_award_transition  (satrlar: noma'lum)
CREATE TABLE carrier_tender_award_transition (
    award_id uuid NOT NULL,
    tender_id uuid NOT NULL,
    tx_id bigint NOT NULL,
    row_snapshot jsonb NOT NULL,  -- [JSON matn]
    PRIMARY KEY (award_id)
);

-- TABLE: carrier_tender_bid_context  (satrlar: noma'lum)
CREATE TABLE carrier_tender_bid_context (
    revision_id uuid NOT NULL,
    bid_id uuid NOT NULL,
    previous_revision_id uuid,
    previous_revision bigint,
    tx_id bigint NOT NULL,
    PRIMARY KEY (revision_id)
);

-- TABLE: carrier_tender_bid_head  (satrlar: noma'lum)
CREATE TABLE carrier_tender_bid_head (
    bid_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    carrier_id uuid NOT NULL,
    current_revision_id uuid NOT NULL,
    revision bigint NOT NULL,
    tender_id uuid NOT NULL,
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (bid_id)
);

-- TABLE: carrier_tender_bid_operation  (satrlar: noma'lum)
CREATE TABLE carrier_tender_bid_operation (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    bid_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    payload_hash varchar(64) NOT NULL,
    recorded_at timestamptz NOT NULL,
    result_json text NOT NULL,  -- [JSON matn]
    revision_id uuid NOT NULL,
    tender_id uuid NOT NULL,
    tx_id bigint NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: carrier_tender_bid_revision  (satrlar: noma'lum)
CREATE TABLE carrier_tender_bid_revision (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    bid_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    carrier_id uuid NOT NULL,
    operation_id uuid NOT NULL,
    previous_revision_id uuid,
    revision bigint NOT NULL,
    snapshot_hash varchar(64) NOT NULL,
    snapshot_json text NOT NULL,  -- [JSON matn]
    submitted_at timestamptz NOT NULL,
    tender_id uuid NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: carrier_tender_bid_transition  (satrlar: noma'lum)
CREATE TABLE carrier_tender_bid_transition (
    revision_id uuid NOT NULL,
    bid_id uuid NOT NULL,
    tx_id bigint NOT NULL,
    PRIMARY KEY (revision_id)
);

-- TABLE: carrier_tender_creation_context  (satrlar: noma'lum)
CREATE TABLE carrier_tender_creation_context (
    tender_id uuid NOT NULL,
    tx_id bigint NOT NULL,
    row_snapshot jsonb NOT NULL,  -- [JSON matn]
    PRIMARY KEY (tender_id)
);

-- TABLE: carrier_tender_process_policy_context  (satrlar: noma'lum)
CREATE TABLE carrier_tender_process_policy_context (
    revision_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    previous_revision_id uuid,
    previous_revision bigint,
    tx_id bigint NOT NULL,
    PRIMARY KEY (revision_id)
);

-- TABLE: carrier_tender_process_policy_head  (satrlar: noma'lum)
CREATE TABLE carrier_tender_process_policy_head (
    branch_id uuid NOT NULL,
    current_revision_id uuid NOT NULL,
    revision bigint NOT NULL,
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (branch_id)
);

-- TABLE: carrier_tender_process_policy_operation  (satrlar: noma'lum)
CREATE TABLE carrier_tender_process_policy_operation (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    payload_hash varchar(64) NOT NULL,
    recorded_at timestamptz NOT NULL,
    result_json text NOT NULL,  -- [JSON matn]
    revision_id uuid NOT NULL,
    tx_id bigint NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: carrier_tender_process_policy_revision  (satrlar: noma'lum)
CREATE TABLE carrier_tender_process_policy_revision (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    actor_name varchar(256) NOT NULL,
    branch_id uuid NOT NULL,
    data_json text NOT NULL,  -- [JSON matn]
    operation_id uuid NOT NULL,
    previous_revision_id uuid,
    review_reason varchar(2000) NOT NULL,
    review_reference varchar(256) NOT NULL,
    reviewed_at timestamptz NOT NULL,
    revision bigint NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: carrier_tender_process_policy_transition  (satrlar: noma'lum)
CREATE TABLE carrier_tender_process_policy_transition (
    revision_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    tx_id bigint NOT NULL,
    PRIMARY KEY (revision_id)
);

-- TABLE: carrier_tender_source  (satrlar: noma'lum)
CREATE TABLE carrier_tender_source (
    tender_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    operation_id uuid NOT NULL,
    plan_revision_id uuid NOT NULL,
    process_policy_id uuid NOT NULL,
    reason varchar(2000) NOT NULL,
    shipment_id uuid NOT NULL,
    shipment_source_operation_id uuid NOT NULL,
    shipment_version bigint NOT NULL,
    snapshot_hash varchar(64) NOT NULL,
    snapshot_json text NOT NULL,  -- [JSON matn]
    PRIMARY KEY (tender_id)
);

-- TABLE: carrier_tender_workflow_operation  (satrlar: noma'lum)
CREATE TABLE carrier_tender_workflow_operation (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    kind varchar(32) NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    payload_hash varchar(64) NOT NULL,
    recorded_at timestamptz NOT NULL,
    result_json text NOT NULL,  -- [JSON matn]
    tender_id uuid NOT NULL,
    tx_id bigint NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: chemical_authority_operation  (satrlar: 0 — BO`SH)
CREATE TABLE chemical_authority_operation (
    operation_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    action text NOT NULL,  -- RUXSAT: 'WRITE', 'APPROVE', 'REVOKE'
    source_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    payload_hash text NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'APPLIED', 'NOT_EXECUTED'
    result jsonb,  -- [JSON matn]
    closure_reason text,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    CHECK (action in ('WRITE', 'APPROVE', 'REVOKE')),
    CHECK ((((state = 'applied') and (result is not null) and (jsonb_typeof(result) = 'object') and (closure_reason is null)) or ((state = 'not_executed') and (result is null) and (closure_reason is not null) and ((length(btrim(closure_reason)) >= 1) and (length(btrim(closure_reason)) <= 1000))))),
    CHECK ((jsonb_typeof(original) = 'object')),
    CHECK ((payload_hash ~ '^[a-f0-9]{64}$')),
    CHECK (state in ('APPLIED', 'NOT_EXECUTED'))
);

-- TABLE: chemical_quality_batch  (satrlar: 0 — BO`SH)
CREATE TABLE chemical_quality_batch (
    id uuid NOT NULL,
    branch_id uuid NOT NULL,
    product_id uuid NOT NULL,
    reference text NOT NULL,
    external_system text,  -- RUXSAT: 'ERP', 'WMS', 'LIMS'
    external_batch_key text,
    produced_at timestamptz,
    actor_id uuid NOT NULL,
    reason text NOT NULL,
    created_at timestamptz NOT NULL,
    operation_id uuid,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    CHECK (((external_system is null) = (external_batch_key is null))),
    CHECK (((external_batch_key is null) or ((length(trim(both from external_batch_key)) >= 1) and (length(trim(both from external_batch_key)) <= 512)))),
    CHECK (external_system in ('ERP', 'WMS', 'LIMS')),
    CHECK (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 1000))),
    CHECK (((length(trim(both from reference)) >= 1) and (length(trim(both from reference)) <= 512)))
);

-- TABLE: chemical_quality_load_binding  (satrlar: 0 — BO`SH)
CREATE TABLE chemical_quality_load_binding (
    target_type text NOT NULL,  -- RUXSAT: 'ROUTE', 'TRIP', 'WAYBILL'
    target_id uuid NOT NULL,
    allocation_id uuid NOT NULL,
    version bigint NOT NULL,
    branch_id uuid NOT NULL,
    batch_id uuid NOT NULL,
    release_version bigint NOT NULL,
    passport_id uuid NOT NULL,
    passport_version bigint NOT NULL,
    policy_id uuid NOT NULL,
    policy_version bigint NOT NULL,
    context_id uuid NOT NULL,
    context_version bigint NOT NULL,
    load_ref_kind text NOT NULL,  -- RUXSAT: 'MANIFEST_ALLOCATION', 'REQUEST_POSITION'
    load_proof jsonb NOT NULL,  -- [JSON matn]
    shipment_id uuid,
    site_id uuid,
    work_snapshot jsonb NOT NULL,  -- [JSON matn]
    actor_id uuid NOT NULL,
    reason text NOT NULL,
    created_at timestamptz NOT NULL,
    operation_id uuid,
    PRIMARY KEY (target_type, target_id, allocation_id, version),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (shipment_id) REFERENCES shipment(id),
    FOREIGN KEY (site_id) REFERENCES yard_site(id),
    CHECK (load_ref_kind in ('MANIFEST_ALLOCATION', 'REQUEST_POSITION')),
    CHECK (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 1000))),
    CHECK (target_type in ('ROUTE', 'TRIP', 'WAYBILL')),
    CHECK ((version >= 0))
);

-- TABLE: chemical_quality_load_current  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
CREATE TABLE chemical_quality_load_current (
    target_type text,
    target_id uuid,
    allocation_id uuid,
    version bigint,
    branch_id uuid,
    batch_id uuid,
    release_version bigint,
    passport_id uuid,
    passport_version bigint,
    policy_id uuid,
    policy_version bigint,
    context_id uuid,
    context_version bigint,
    load_ref_kind text,
    load_proof jsonb,  -- [JSON matn]
    shipment_id uuid,
    site_id uuid,
    work_snapshot jsonb,  -- [JSON matn]
    actor_id uuid,
    reason text,
    created_at timestamptz,
    operation_id uuid
);

-- TABLE: chemical_quality_message  (satrlar: noma'lum)
CREATE TABLE chemical_quality_message (
    source_system text NOT NULL,
    source_reference text NOT NULL,
    source_version bigint NOT NULL,
    batch_id uuid NOT NULL,
    release_version bigint NOT NULL,
    payload jsonb NOT NULL,  -- [JSON matn]
    created_at timestamptz NOT NULL,
    PRIMARY KEY (source_system, source_reference, source_version)
);

-- TABLE: chemical_quality_notice  (satrlar: noma'lum)
CREATE TABLE chemical_quality_notice (
    id uuid NOT NULL,
    target_type text NOT NULL,
    target_id uuid NOT NULL,
    batch_id uuid NOT NULL,
    source_kind text NOT NULL,
    source_id uuid NOT NULL,
    source_version bigint NOT NULL,
    reason text NOT NULL,
    occurred_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (batch_id) REFERENCES chemical_quality_batch(id)
);

-- TABLE: chemical_quality_notice_review  (satrlar: noma'lum)
CREATE TABLE chemical_quality_notice_review (
    notice_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    reason text NOT NULL,
    reviewed_at timestamptz NOT NULL,
    operation_id uuid,
    PRIMARY KEY (notice_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (notice_id) REFERENCES chemical_quality_notice(id),
    CHECK (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 1000)))
);

-- TABLE: chemical_quality_notification_delivery  (satrlar: noma'lum)
CREATE TABLE chemical_quality_notification_delivery (
    notice_id uuid NOT NULL,
    delivered_at timestamptz NOT NULL,
    PRIMARY KEY (notice_id),
    FOREIGN KEY (notice_id) REFERENCES chemical_quality_notice(id)
);

-- TABLE: chemical_quality_passport  (satrlar: 0 — BO`SH)
CREATE TABLE chemical_quality_passport (
    id uuid NOT NULL,
    version bigint NOT NULL,
    batch_id uuid NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'DRAFT', 'APPROVED', 'WITHDRAWN'
    revision_label text NOT NULL,
    laboratory_reference text NOT NULL,
    measured_at timestamptz NOT NULL,
    measurements jsonb NOT NULL,  -- [JSON matn]
    document_id uuid NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_to timestamptz NOT NULL,
    policy_id uuid NOT NULL,
    policy_version bigint NOT NULL,
    author_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    reason text NOT NULL,
    created_at timestamptz NOT NULL,
    operation_id uuid,
    PRIMARY KEY (id, version),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (author_id) REFERENCES app_user(id),
    FOREIGN KEY (batch_id) REFERENCES chemical_quality_batch(id),
    FOREIGN KEY (document_id) REFERENCES chemical_safety_document(id),
    CHECK ((valid_from < valid_to)),
    CHECK (((length(trim(both from laboratory_reference)) >= 1) and (length(trim(both from laboratory_reference)) <= 512))),
    CHECK ((jsonb_typeof(measurements) = 'object')),
    CHECK (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 1000))),
    CHECK (((length(trim(both from revision_label)) >= 1) and (length(trim(both from revision_label)) <= 128))),
    CHECK (state in ('DRAFT', 'APPROVED', 'WITHDRAWN')),
    CHECK ((version >= 0))
);

-- TABLE: chemical_quality_passport_current  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
CREATE TABLE chemical_quality_passport_current (
    id uuid,
    version bigint,
    batch_id uuid,
    state text,
    revision_label text,
    laboratory_reference text,
    measured_at timestamptz,
    measurements jsonb,  -- [JSON matn]
    document_id uuid,
    valid_from timestamptz,
    valid_to timestamptz,
    policy_id uuid,
    policy_version bigint,
    author_id uuid,
    actor_id uuid,
    reason text,
    created_at timestamptz,
    operation_id uuid
);

-- TABLE: chemical_quality_policy_binding  (satrlar: noma'lum)
CREATE TABLE chemical_quality_policy_binding (
    branch_id uuid NOT NULL,
    product_id uuid NOT NULL,
    version bigint NOT NULL,
    policy_id uuid NOT NULL,
    policy_version bigint NOT NULL,
    actor_id uuid NOT NULL,
    reason text NOT NULL,
    created_at timestamptz NOT NULL,
    operation_id uuid,
    PRIMARY KEY (branch_id, product_id, version),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 1000))),
    CHECK ((version >= 0))
);

-- TABLE: chemical_quality_release  (satrlar: 0 — BO`SH)
CREATE TABLE chemical_quality_release (
    batch_id uuid NOT NULL,
    version bigint NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'PENDING_REVIEW', 'APPROVED', 'WITHDRAWN'
    disposition text NOT NULL,  -- RUXSAT: 'RELEASED', 'HOLD', 'REJECTED', 'REVOKED', 'UNKNOWN'
    passport_id uuid NOT NULL,
    passport_version bigint NOT NULL,
    policy_id uuid NOT NULL,
    policy_version bigint NOT NULL,
    origin text NOT NULL,  -- RUXSAT: 'MANUAL', 'DOCUMENTED_EXTERNAL'
    source_system text NOT NULL,  -- RUXSAT: 'ERP', 'WMS', 'LIMS', 'MANUAL'
    source_reference text NOT NULL,
    source_version bigint NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_to timestamptz NOT NULL,
    document_id uuid NOT NULL,
    author_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    reason text NOT NULL,
    created_at timestamptz NOT NULL,
    operation_id uuid,
    PRIMARY KEY (batch_id, version),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (author_id) REFERENCES app_user(id),
    FOREIGN KEY (batch_id) REFERENCES chemical_quality_batch(id),
    FOREIGN KEY (document_id) REFERENCES chemical_safety_document(id),
    CHECK ((valid_from < valid_to)),
    CHECK (((origin = 'manual') = (source_system = 'manual'))),
    CHECK (disposition in ('RELEASED', 'HOLD', 'REJECTED', 'REVOKED', 'UNKNOWN')),
    CHECK (origin in ('MANUAL', 'DOCUMENTED_EXTERNAL')),
    CHECK (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 1000))),
    CHECK (((length(trim(both from source_reference)) >= 1) and (length(trim(both from source_reference)) <= 512))),
    CHECK (source_system in ('ERP', 'WMS', 'LIMS', 'MANUAL')),
    CHECK ((source_version >= 0)),
    CHECK (state in ('PENDING_REVIEW', 'APPROVED', 'WITHDRAWN')),
    CHECK ((version >= 0))
);

-- TABLE: chemical_quality_release_current  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
CREATE TABLE chemical_quality_release_current (
    batch_id uuid,
    version bigint,
    state text,
    disposition text,
    passport_id uuid,
    passport_version bigint,
    policy_id uuid,
    policy_version bigint,
    origin text,
    source_system text,
    source_reference text,
    source_version bigint,
    valid_from timestamptz,
    valid_to timestamptz,
    document_id uuid,
    author_id uuid,
    actor_id uuid,
    reason text,
    created_at timestamptz,
    operation_id uuid
);

-- TABLE: chemical_quality_rule  (satrlar: 0 — BO`SH)
CREATE TABLE chemical_quality_rule (
    id uuid NOT NULL,
    version bigint NOT NULL,
    kind text NOT NULL,  -- RUXSAT: 'POLICY', 'AUTHORITY'
    state text NOT NULL,  -- RUXSAT: 'DRAFT', 'APPROVED', 'WITHDRAWN'
    branch_id uuid NOT NULL,
    product_id uuid NOT NULL,
    body jsonb NOT NULL,  -- [JSON matn]
    document_id uuid NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_to timestamptz NOT NULL,
    author_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    reason text NOT NULL,
    created_at timestamptz NOT NULL,
    operation_id uuid,
    PRIMARY KEY (id, version),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (author_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (document_id) REFERENCES chemical_safety_document(id),
    CHECK ((valid_from < valid_to)),
    CHECK (kind in ('POLICY', 'AUTHORITY')),
    CHECK (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 1000))),
    CHECK (state in ('DRAFT', 'APPROVED', 'WITHDRAWN')),
    CHECK ((version >= 0))
);

-- TABLE: chemical_quality_rule_current  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
CREATE TABLE chemical_quality_rule_current (
    id uuid,
    version bigint,
    kind text,
    state text,
    branch_id uuid,
    product_id uuid,
    body jsonb,  -- [JSON matn]
    document_id uuid,
    valid_from timestamptz,
    valid_to timestamptz,
    author_id uuid,
    actor_id uuid,
    reason text,
    created_at timestamptz,
    operation_id uuid
);

-- TABLE: chemical_safety_acknowledgement  (satrlar: noma'lum)
CREATE TABLE chemical_safety_acknowledgement (
    id uuid NOT NULL,
    source_id uuid NOT NULL,
    source_version bigint NOT NULL,
    context_id uuid NOT NULL,
    context_version bigint NOT NULL,
    participant_id uuid NOT NULL,
    participant_role text NOT NULL,
    occurred_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (participant_id) REFERENCES app_user(id)
);

-- TABLE: chemical_safety_authority  (satrlar: 0 — BO`SH)
CREATE TABLE chemical_safety_authority (
    id uuid NOT NULL,
    version bigint NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'DRAFT', 'APPROVED', 'REVOKED'
    branch_id uuid NOT NULL,
    participant_id uuid NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_to timestamptz NOT NULL,
    document_id uuid NOT NULL,
    source_reference text NOT NULL,
    body jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    actor_id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    operation_id uuid,
    PRIMARY KEY (id, version),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (document_id) REFERENCES chemical_safety_document(id),
    FOREIGN KEY (participant_id) REFERENCES app_user(id),
    CHECK ((valid_from < valid_to)),
    CHECK (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 1000))),
    CHECK (((length(trim(both from source_reference)) >= 1) and (length(trim(both from source_reference)) <= 512))),
    CHECK (state in ('DRAFT', 'APPROVED', 'REVOKED')),
    CHECK ((version >= 0))
);

-- TABLE: chemical_safety_authority_current  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
CREATE TABLE chemical_safety_authority_current (
    id uuid,
    version bigint,
    state text,
    branch_id uuid,
    participant_id uuid,
    valid_from timestamptz,
    valid_to timestamptz,
    document_id uuid,
    source_reference text,
    body jsonb,  -- [JSON matn]
    reason text,
    actor_id uuid,
    created_at timestamptz,
    operation_id uuid
);

-- TABLE: chemical_safety_context_binding  (satrlar: 0 — BO`SH)
CREATE TABLE chemical_safety_context_binding (
    target_type text NOT NULL,  -- RUXSAT: 'ROUTE', 'TRIP', 'WAYBILL'
    target_id uuid NOT NULL,
    version bigint NOT NULL,
    source_id uuid NOT NULL,
    source_version bigint NOT NULL,
    actor_id uuid NOT NULL,
    reason text NOT NULL,
    created_at timestamptz NOT NULL,
    operation_id uuid,
    PRIMARY KEY (target_type, target_id, version),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK (target_type in ('ROUTE', 'TRIP', 'WAYBILL'))
);

-- TABLE: chemical_safety_current  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
CREATE TABLE chemical_safety_current (
    id uuid,
    version bigint,
    kind text,
    state text,
    branch_id uuid,
    source_reference text,
    valid_from timestamptz,
    valid_to timestamptz,
    body jsonb,  -- [JSON matn]
    reason text,
    actor_id uuid,
    created_at timestamptz,
    operation_id uuid
);

-- TABLE: chemical_safety_document  (satrlar: noma'lum)
CREATE TABLE chemical_safety_document (
    id uuid NOT NULL,
    branch_id uuid NOT NULL,
    file_name text NOT NULL,
    mime_type text NOT NULL,
    storage_url text NOT NULL,
    size_bytes bigint NOT NULL,
    sha256 text NOT NULL,
    actor_id uuid NOT NULL,
    reason text NOT NULL,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    CHECK (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 1000))),
    CHECK ((sha256 ~ '^[0-9a-f]{64}$')),
    CHECK (((size_bytes > 0) and (size_bytes <= 10485760)))
);

-- TABLE: chemical_safety_document_content  (satrlar: noma'lum)
CREATE TABLE chemical_safety_document_content (
    document_id uuid NOT NULL,
    content bytea NOT NULL,
    PRIMARY KEY (document_id),
    FOREIGN KEY (document_id) REFERENCES chemical_safety_document(id),
    CHECK (((octet_length(content) > 0) and (octet_length(content) <= 10485760)))
);

-- TABLE: chemical_safety_document_read  (satrlar: noma'lum)
CREATE TABLE chemical_safety_document_read (
    id uuid NOT NULL,
    document_id uuid NOT NULL,
    participant_id uuid NOT NULL,
    sha256 text NOT NULL,
    occurred_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (document_id) REFERENCES chemical_safety_document(id),
    FOREIGN KEY (participant_id) REFERENCES app_user(id)
);

-- TABLE: chemical_safety_manifest_preparation  (satrlar: noma'lum)
CREATE TABLE chemical_safety_manifest_preparation (
    id uuid NOT NULL,
    operation_id uuid NOT NULL,
    route_id uuid NOT NULL,
    manifest_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    request_versions jsonb NOT NULL,  -- [JSON matn]
    proof_json text NOT NULL,  -- [JSON matn]
    assessment_basis_json text NOT NULL,  -- [JSON matn]
    assessment_hash text NOT NULL,
    work_snapshot jsonb NOT NULL,  -- [JSON matn]
    planning_interval jsonb NOT NULL,  -- [JSON matn]
    actor_id uuid NOT NULL,
    reason text NOT NULL,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id),
    CHECK ((assessment_hash ~ '^[a-f0-9]{64}$')),
    CHECK (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 1000)))
);

-- TABLE: chemical_safety_permit  (satrlar: noma'lum)
CREATE TABLE chemical_safety_permit (
    id uuid NOT NULL,
    qualification_permit_id uuid NOT NULL,
    target_type text NOT NULL,
    target_id uuid NOT NULL,
    target_version bigint NOT NULL,
    action text NOT NULL,
    proof jsonb NOT NULL,  -- [JSON matn]
    proof_hash text NOT NULL,
    actor_id uuid NOT NULL,
    occurred_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (qualification_permit_id) REFERENCES driver_qualification_permit(id),
    CHECK ((proof_hash ~ '^[0-9a-f]{64}$'))
);

-- TABLE: chemical_safety_policy_binding  (satrlar: noma'lum)
CREATE TABLE chemical_safety_policy_binding (
    branch_id uuid NOT NULL,
    version bigint NOT NULL,
    source_id uuid NOT NULL,
    source_version bigint NOT NULL,
    actor_id uuid NOT NULL,
    reason text NOT NULL,
    created_at timestamptz NOT NULL,
    operation_id uuid,
    PRIMARY KEY (branch_id, version),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: chemical_safety_reassessment  (satrlar: noma'lum)
CREATE TABLE chemical_safety_reassessment (
    id uuid NOT NULL,
    target_type text NOT NULL,
    target_id uuid NOT NULL,
    source_id uuid NOT NULL,
    source_version bigint NOT NULL,
    reason text NOT NULL,
    occurred_at timestamptz NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: chemical_safety_reassessment_publication  (satrlar: noma'lum)
CREATE TABLE chemical_safety_reassessment_publication (
    reassessment_id uuid NOT NULL,
    context_id uuid NOT NULL,
    context_version bigint NOT NULL,
    published_at timestamptz NOT NULL,
    PRIMARY KEY (reassessment_id),
    FOREIGN KEY (reassessment_id) REFERENCES chemical_safety_reassessment(id)
);

-- TABLE: chemical_safety_review_decision  (satrlar: noma'lum)
CREATE TABLE chemical_safety_review_decision (
    id uuid NOT NULL,
    context_id uuid NOT NULL,
    context_version bigint NOT NULL,
    proof jsonb NOT NULL,  -- [JSON matn]
    proof_hash text NOT NULL,
    actor_id uuid NOT NULL,
    reason text NOT NULL,
    occurred_at timestamptz NOT NULL,
    operation_id uuid,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK ((proof_hash ~ '^[a-f0-9]{64}$')),
    CHECK (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 1000)))
);

-- TABLE: chemical_safety_source  (satrlar: 0 — BO`SH)
CREATE TABLE chemical_safety_source (
    id uuid NOT NULL,
    version bigint NOT NULL,
    kind text NOT NULL,  -- RUXSAT: 'POLICY', 'PRODUCT', 'CREDENTIAL', 'SDS', 'INSTRUCTIONS', 'TANK', 'COMPATIBILITY', 'CARGO_HISTORY', 'CLEANING', 'CLEANING_EXCEPTION', 'PERMIT', 'INSURANCE', 'CONTEXT'
    state text NOT NULL,  -- RUXSAT: 'DRAFT', 'APPROVED', 'REVOKED'
    branch_id uuid NOT NULL,
    source_reference text NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_to timestamptz NOT NULL,
    body jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    actor_id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    operation_id uuid,
    PRIMARY KEY (id, version),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    CHECK ((valid_from < valid_to)),
    CHECK (kind in ('POLICY', 'PRODUCT', 'CREDENTIAL', 'SDS', 'INSTRUCTIONS', 'TANK', 'COMPATIBILITY', 'CARGO_HISTORY', 'CLEANING', 'CLEANING_EXCEPTION', 'PERMIT', 'INSURANCE', 'CONTEXT')),
    CHECK (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 1000))),
    CHECK (((length(trim(both from source_reference)) >= 1) and (length(trim(both from source_reference)) <= 512))),
    CHECK (state in ('DRAFT', 'APPROVED', 'REVOKED')),
    CHECK ((version >= 0))
);

-- TABLE: chemical_safety_yard_permission  (satrlar: 0 — BO`SH)
CREATE TABLE chemical_safety_yard_permission (
    id uuid NOT NULL,
    trip_id uuid NOT NULL,
    site_id uuid NOT NULL,
    operation text NOT NULL,  -- RUXSAT: 'ENTER', 'LOAD', 'UNLOAD'
    proof jsonb NOT NULL,  -- [JSON matn]
    actor_id uuid NOT NULL,
    occurred_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (site_id) REFERENCES yard_site(id),
    FOREIGN KEY (trip_id) REFERENCES trip(id),
    CHECK (operation in ('ENTER', 'LOAD', 'UNLOAD'))
);

-- TABLE: chemical_source_operation_original  (satrlar: 0 — BO`SH)
CREATE TABLE chemical_source_operation_original (
    operation_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    action text NOT NULL,  -- RUXSAT: 'SOURCE_WRITE', 'SOURCE_APPROVE', 'SOURCE_REVOKE', 'POLICY_BIND', 'CONTEXT_BIND_TRIP', 'CONTEXT_BIND_ROUTE', 'CONTEXT_BIND_WAYBILL', 'SOURCE_REASSESS', 'QUALITY_RULE_WRITE', 'QUALITY_RULE_APPROVE', 'QUALITY_RULE_WITHDRAW', 'QUALITY_POLICY_BIND', 'QUALITY_BATCH_REGISTER', 'QUALITY_PASSPORT_WRITE', 'QUALITY_PASSPORT_APPROVE', 'QUALITY_PASSPORT_WITHDRAW', 'QUALITY_RELEASE_RECORD', 'QUALITY_RELEASE_APPROVE', 'QUALITY_RELEASE_WITHDRAW', 'QUALITY_LOAD_BIND_ROUTE', 'QUALITY_LOAD_BIND_TRIP', 'QUALITY_LOAD_BIND_WAYBILL', 'QUALITY_NOTICE_REVIEW'
    object_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    payload_hash text NOT NULL,
    closure_only boolean NOT NULL,
    registered_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    CHECK (action in ('SOURCE_WRITE', 'SOURCE_APPROVE', 'SOURCE_REVOKE', 'POLICY_BIND', 'CONTEXT_BIND_TRIP', 'CONTEXT_BIND_ROUTE', 'CONTEXT_BIND_WAYBILL', 'SOURCE_REASSESS', 'QUALITY_RULE_WRITE', 'QUALITY_RULE_APPROVE', 'QUALITY_RULE_WITHDRAW', 'QUALITY_POLICY_BIND', 'QUALITY_BATCH_REGISTER', 'QUALITY_PASSPORT_WRITE', 'QUALITY_PASSPORT_APPROVE', 'QUALITY_PASSPORT_WITHDRAW', 'QUALITY_RELEASE_RECORD', 'QUALITY_RELEASE_APPROVE', 'QUALITY_RELEASE_WITHDRAW', 'QUALITY_LOAD_BIND_ROUTE', 'QUALITY_LOAD_BIND_TRIP', 'QUALITY_LOAD_BIND_WAYBILL', 'QUALITY_NOTICE_REVIEW')),
    CHECK ((jsonb_typeof(original) = 'object')),
    CHECK ((payload_hash ~ '^[a-f0-9]{64}$'))
);

-- TABLE: chemical_source_operation_receipt  (satrlar: 0 — BO`SH)
CREATE TABLE chemical_source_operation_receipt (
    operation_id uuid NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'APPLIED', 'NOT_EXECUTED'
    result jsonb,  -- [JSON matn]
    closure_reason text,
    actor_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (operation_id) REFERENCES chemical_source_operation_original(operation_id),
    CHECK ((((state = 'applied') and (result is not null) and (jsonb_typeof(result) = 'object') and (closure_reason is null)) or ((state = 'not_executed') and (result is null) and (closure_reason is not null) and ((length(btrim(closure_reason)) >= 1) and (length(btrim(closure_reason)) <= 1000))))),
    CHECK (state in ('APPLIED', 'NOT_EXECUTED'))
);

-- TABLE: critical_action_grant  (satrlar: 0 — BO`SH)
CREATE TABLE critical_action_grant (
    id uuid NOT NULL,
    policy_version bigint NOT NULL,
    action varchar(64) NOT NULL,
    role varchar(64),
    user_id uuid,
    branch_id uuid,
    site_id uuid,
    all_branches boolean NOT NULL,
    own_object_only boolean NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    authority_reference text NOT NULL,
    state varchar(16) NOT NULL,  -- RUXSAT: 'DRAFT', 'APPROVED', 'REVOKED'
    created_by uuid NOT NULL,
    approved_by uuid,
    approved_at timestamptz,
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    CHECK (((role is null) <> (user_id is null))),
    CHECK ((all_branches or (branch_id is not null))),
    CHECK (((valid_until is null) or (valid_until > valid_from))),
    CHECK ((((state) <> 'approved') or ((approved_by is not null) and (approved_by <> created_by) and (approved_by is distinct from user_id)))),
    CHECK ((policy_version > 0)),
    CHECK (state in ('DRAFT', 'APPROVED', 'REVOKED'))
);

-- TABLE: critical_action_grant_revision  (satrlar: noma'lum)
CREATE TABLE critical_action_grant_revision (
    id uuid NOT NULL,
    grant_id uuid NOT NULL,
    version bigint NOT NULL,
    action varchar(64) NOT NULL,
    actor_id uuid NOT NULL,
    reason text NOT NULL,
    occurred_at timestamptz NOT NULL,
    snapshot jsonb NOT NULL,  -- [JSON matn]
    PRIMARY KEY (id),
    FOREIGN KEY (grant_id) REFERENCES critical_action_grant(id),
    CHECK ((length(trim(both from reason)) > 0))
);

-- TABLE: critical_audit_event  (satrlar: noma'lum)
CREATE TABLE critical_audit_event (
    id uuid NOT NULL,
    actor_id varchar(128) NOT NULL,
    actor_kind varchar(16) NOT NULL,  -- RUXSAT: 'HUMAN', 'MACHINE', 'SYSTEM'
    action varchar(64) NOT NULL,
    object_type varchar(64) NOT NULL,
    object_id uuid,
    object_version bigint,
    branch_id uuid,
    site_id uuid,
    operation_id uuid,
    correlation_id varchar(128) NOT NULL,
    policy_version bigint NOT NULL,
    outcome varchar(32) NOT NULL,  -- RUXSAT: 'ALLOWED', 'DENIED', 'HTTP_ACCEPTED', 'HTTP_REJECTED'; BAZADA: 'ALLOWED' 2338, 'HTTP_ACCEPTED' 2268, 'HTTP_REJECTED' 542, 'DENIED' 22
    reason_code varchar(128) NOT NULL,
    before_json jsonb NOT NULL,  -- [JSON matn]
    after_json jsonb NOT NULL,  -- [JSON matn]
    rule_versions_json jsonb NOT NULL,  -- [JSON matn]
    occurred_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    CHECK (actor_kind in ('HUMAN', 'MACHINE', 'SYSTEM')),
    CHECK (outcome in ('ALLOWED', 'DENIED', 'HTTP_ACCEPTED', 'HTTP_REJECTED'))
);

-- TABLE: critical_authorization_operation  (satrlar: 0 — BO`SH)
CREATE TABLE critical_authorization_operation (
    operation_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    grant_id uuid NOT NULL,
    request_hash varchar(64) NOT NULL,
    response_json jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    state varchar(16) NOT NULL,  -- RUXSAT: 'APPLIED', 'NOT_EXECUTED'
    original_json jsonb NOT NULL,  -- [JSON matn]
    closure_reason text,
    PRIMARY KEY (operation_id),
    CHECK ((((state) <> 'not_executed') or (length(trim(both from closure_reason)) > 0))),
    CHECK (state in ('APPLIED', 'NOT_EXECUTED'))
);

-- TABLE: customer  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Mijozlar (buyurtmachilar) ma'lumotlari: nomi, INN, bank hisobi, aloqa shaxsi.
-- kind — mijoz turi: EXTERNAL (tashqi), INTERNAL (ichki bo'lim), B2C, GOV.
-- ---------------------------------------------------------------------
CREATE TABLE customer (
    id uuid NOT NULL,
    active boolean NOT NULL,
    address varchar(1000),
    bank_account varchar(64),
    contact_email varchar(255),
    contact_person varchar(255),
    contact_phone varchar(64),
    created_at timestamptz NOT NULL,
    inn varchar(32),
    kind varchar(32) NOT NULL,  -- RUXSAT: 'EXTERNAL', 'INTERNAL', 'B2C', 'GOV'
    name varchar(255) NOT NULL,
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    CHECK (kind in ('EXTERNAL', 'INTERNAL', 'B2C', 'GOV'))
);

-- TABLE: customer_settlement_act  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Mijoz bilan davr uchun hisob-kitob akti: qancha reys, qancha km, qancha tonna,
-- qancha soat va umumiy summa. period_from/period_to davrni, tariff_id qaysi tarif
-- qo'llanganini ko'rsatadi.
-- MIJOZGA QANCHA HISOBLANGANI SO'RALSA SHU JADVALDAN OLINADI.
-- ---------------------------------------------------------------------
CREATE TABLE customer_settlement_act (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    created_by varchar(128),
    currency varchar(8) NOT NULL,
    customer_id uuid NOT NULL,
    payload_json text,  -- [JSON matn]
    period_from date NOT NULL,
    period_to date NOT NULL,
    tariff_id uuid NOT NULL,
    total_amount numeric(14,2) NOT NULL,
    total_hours numeric(14,3) NOT NULL,
    total_km numeric(14,3) NOT NULL,
    total_weight_tons numeric(14,3) NOT NULL,
    trip_count integer NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: daily_exploitation_plan  (satrlar: noma'lum)
CREATE TABLE daily_exploitation_plan (
    id uuid NOT NULL,
    branch_id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    created_by varchar(128),
    notes varchar(1024),
    plan_date date NOT NULL,
    sent_by varchar(128),
    sent_to_dispatcher_at timestamptz,
    status varchar(32) NOT NULL,  -- RUXSAT: 'DRAFT', 'READY_FOR_DISPATCH', 'FINALIZED'; BAZADA: 'READY_FOR_DISPATCH' 1; ISHLATILMAGAN: DRAFT, FINALIZED
    total_vehicles integer,
    updated_at timestamptz NOT NULL,
    updated_by varchar(128),
    PRIMARY KEY (id),
    CHECK (status in ('DRAFT', 'READY_FOR_DISPATCH', 'FINALIZED'))
);

-- TABLE: daily_exploitation_plan_item  (satrlar: noma'lum)
CREATE TABLE daily_exploitation_plan_item (
    id uuid NOT NULL,
    assigned_trip_id uuid,
    branch_id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    notes varchar(1024),
    planned_metric_type varchar(32) NOT NULL,  -- RUXSAT: 'KM', 'MOTOSOAT', 'KM_AND_MOTOSOAT'
    planned_value numeric(12,2),
    status varchar(32) NOT NULL,  -- RUXSAT: 'READY', 'ASSIGNED_TO_TRIP', 'CANCELLED'
    updated_at timestamptz NOT NULL,
    vehicle_id uuid NOT NULL,
    workshop_code varchar(64),
    workshop_name varchar(128),
    plan_id uuid NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (plan_id) REFERENCES daily_exploitation_plan(id),
    CHECK (planned_metric_type in ('KM', 'MOTOSOAT', 'KM_AND_MOTOSOAT')),
    CHECK (status in ('READY', 'ASSIGNED_TO_TRIP', 'CANCELLED'))
);

-- TABLE: default_material_warehouse_backfill  (satrlar: noma'lum)
CREATE TABLE default_material_warehouse_backfill (
    entity_type varchar(32) NOT NULL,
    entity_id uuid NOT NULL,
    warehouse_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    recorded_by text NOT NULL,
    PRIMARY KEY (entity_type, entity_id)
);

-- TABLE: delivery_otp  (satrlar: 0 — BO`SH)
CREATE TABLE delivery_otp (
    id uuid NOT NULL,
    attempt_count integer NOT NULL,
    code_hash varchar(64) NOT NULL,
    created_at timestamptz NOT NULL,
    expires_at timestamptz NOT NULL,
    max_attempts integer NOT NULL,
    recipient_full_name varchar(256) NOT NULL,
    recipient_phone varchar(32) NOT NULL,
    requested_by varchar(128),
    status varchar(16) NOT NULL,  -- RUXSAT: 'PENDING', 'VERIFIED', 'EXPIRED', 'FAILED'
    telegram_chat_id bigint NOT NULL,
    trip_id uuid NOT NULL,
    verified_at timestamptz,
    PRIMARY KEY (id),
    CHECK (status in ('PENDING', 'VERIFIED', 'EXPIRED', 'FAILED'))
);

-- TABLE: demurrage  (satrlar: 0 — BO`SH)
CREATE TABLE demurrage (
    id uuid NOT NULL,
    allowance_hours numeric(10,2),
    amount numeric(14,2),
    carrier_id uuid,
    created_at timestamptz NOT NULL,
    currency varchar(8),
    delay_hours numeric(10,2),
    ended_at timestamptz,
    hourly_rate numeric(14,2),
    kind varchar(32),
    location_id uuid,
    reason varchar(1000),
    shipment_id uuid,
    started_at timestamptz,
    status varchar(16) NOT NULL,  -- RUXSAT: 'PENDING', 'APPROVED', 'REJECTED', 'PAID', 'CHARGED'
    trip_id uuid NOT NULL,
    updated_at timestamptz,
    vehicle_id uuid NOT NULL,
    PRIMARY KEY (id),
    CHECK (status in ('PENDING', 'APPROVED', 'REJECTED', 'PAID', 'CHARGED'))
);

-- TABLE: department_manager  (satrlar: noma'lum)
CREATE TABLE department_manager (
    id uuid NOT NULL,
    active boolean NOT NULL,
    created_at timestamptz NOT NULL,
    created_by varchar(128),
    department_id uuid NOT NULL,
    full_name varchar(256) NOT NULL,
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: dock  (satrlar: 0 — BO`SH)
CREATE TABLE dock (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    location_id uuid,
    name varchar(128) NOT NULL,
    status varchar(32),
    updated_at timestamptz,
    allowed_operations_json text,  -- [JSON matn]
    allowed_product_codes_json text,  -- [JSON matn]
    branch_id uuid,
    calendar_json text,  -- [JSON matn]
    capacity integer,
    config_valid_from timestamptz,
    config_valid_to timestamptz,
    kind varchar(16),
    regulation_reference varchar(512),
    site_id uuid,
    updated_by uuid,
    object_version bigint NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: dock_booking  (satrlar: 0 — BO`SH)
CREATE TABLE dock_booking (
    id uuid NOT NULL,
    actual_end_at timestamptz,
    actual_start_at timestamptz,
    arrived_at timestamptz,
    branch_id uuid NOT NULL,
    carrier_id uuid,
    composition_identity varchar(128) NOT NULL,
    created_at timestamptz NOT NULL,
    created_by uuid NOT NULL,
    directed_at timestamptz,
    dock_id uuid NOT NULL,
    end_at timestamptz NOT NULL,
    gate_pass_id uuid,
    notes varchar(1000),
    operation_type varchar(16),
    shipment_id uuid,
    site_id uuid NOT NULL,
    start_at timestamptz NOT NULL,
    status varchar(32) NOT NULL,
    trip_id uuid NOT NULL,
    updated_at timestamptz NOT NULL,
    object_version bigint NOT NULL,
    waiting_at timestamptz,
    PRIMARY KEY (id),
    FOREIGN KEY (dock_id) REFERENCES dock(id),
    FOREIGN KEY (gate_pass_id) REFERENCES gate_pass(id),
    FOREIGN KEY (site_id) REFERENCES yard_site(id),
    FOREIGN KEY (trip_id) REFERENCES trip(id)
);

-- TABLE: dock_slot  (satrlar: 0 — BO`SH)
CREATE TABLE dock_slot (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    location_id uuid,
    name varchar(128) NOT NULL,
    notes varchar(1000),
    status varchar(16) NOT NULL,  -- RUXSAT: 'AVAILABLE', 'OCCUPIED', 'MAINTENANCE'
    updated_at timestamptz,
    current_vehicle_id uuid,
    PRIMARY KEY (id),
    FOREIGN KEY (current_vehicle_id) REFERENCES transport_vehicle(id),
    CHECK (status in ('AVAILABLE', 'OCCUPIED', 'MAINTENANCE'))
);

-- TABLE: document_audit  (satrlar: 0 — BO`SH)
-- ---------------------------------------------------------------------
-- HUJJAT AUDITI — hujjat ustidagi amallar tarixi.
-- action (amal), actor (kim bajargan), occurred_at (qachon),
-- details (tafsilot), document_id (qaysi hujjat).
-- DIQQAT: bu YAGONA hujjat audit jadvali. Ilgari `document_audit_entry`
-- degan ikkinchi jadval bor edi — u bazadan o'chirilgan.
-- ---------------------------------------------------------------------
CREATE TABLE document_audit (
    id uuid NOT NULL,
    action varchar(64) NOT NULL,  -- RUXSAT: 'GENERATED', 'UPDATED', 'DELIVERY_CONFIRMED', 'STATUS_CHANGED', 'SIGNED', 'TEMPLATE_CREATED', 'TEMPLATE_UPDATED', 'WEIGHING_ACT_ACCEPTED'
    actor varchar(128) NOT NULL,
    details varchar(2000),
    occurred_at timestamptz NOT NULL,
    document_id uuid NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (document_id) REFERENCES transport_document(id),
    CHECK (action in ('GENERATED', 'UPDATED', 'DELIVERY_CONFIRMED', 'STATUS_CHANGED', 'SIGNED', 'TEMPLATE_CREATED', 'TEMPLATE_UPDATED', 'WEIGHING_ACT_ACCEPTED'))
);

-- TABLE: document_template  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Hujjat shablonlari (yo'l varaqasi, TTN, marshrut varaqasi, transport akti,
-- yetkazish tasdig'i). body_template — shablon matni, template_version — versiya.
-- Faol shablonlar active=true.
-- ---------------------------------------------------------------------
CREATE TABLE document_template (
    id uuid NOT NULL,
    active boolean NOT NULL,
    body_template varchar(10000) NOT NULL,
    code varchar(64) NOT NULL,
    created_at timestamptz NOT NULL,
    created_by varchar(128) NOT NULL,
    document_type varchar(64) NOT NULL,  -- RUXSAT: 'WAYBILL', 'TTN', 'ROUTE_SHEET', 'TRANSPORT_ACT', 'DELIVERY_CONFIRMATION', 'WEIGHING_ACT'
    name varchar(255) NOT NULL,
    template_version integer NOT NULL,
    updated_at timestamptz NOT NULL,
    updated_by varchar(128) NOT NULL,
    PRIMARY KEY (id),
    CHECK (document_type in ('WAYBILL', 'TTN', 'ROUTE_SHEET', 'TRANSPORT_ACT', 'DELIVERY_CONFIRMATION', 'WEIGHING_ACT'))
);

-- TABLE: document_version  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Transport hujjatining har bir versiyasi: fayl nomi, hajmi, SHA-256 checksum,
-- saqlash kaliti (storage_key) va payload JSON. Bitta hujjatda bir nechta versiya
-- bo'lishi mumkin — version_number bo'yicha tartiblanadi.
-- HUJJATNING OXIRGI VERSIYASI KERAK BO'LSA version_number MAX bo'yicha olinadi.
-- ---------------------------------------------------------------------
CREATE TABLE document_version (
    id uuid NOT NULL,
    checksum_sha256 varchar(128) NOT NULL,
    created_at timestamptz NOT NULL,
    created_by varchar(128) NOT NULL,
    file_name varchar(255) NOT NULL,
    file_size_bytes bigint NOT NULL,
    mime_type varchar(128) NOT NULL,
    payload_json varchar(10000),  -- [JSON matn]
    storage_key varchar(1024) NOT NULL,
    version_number integer NOT NULL,
    document_id uuid NOT NULL,
    weighing_pair_id uuid,
    source_kind varchar(64),
    source_digest varchar(64),
    PRIMARY KEY (id),
    FOREIGN KEY (weighing_pair_id) REFERENCES yard_weighing_pair(id),
    FOREIGN KEY (document_id) REFERENCES transport_document(id),
    CHECK ((((weighing_pair_id is null) and (source_kind is null) and (source_digest is null)) or ((weighing_pair_id is not null) and ((source_kind) = 'yard_weighing_pair_v1') and ((source_digest) ~ '^[a-f0-9]{64}$'))))
);

-- TABLE: driver  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- HAYDOVCHILAR BO'YICHA ASOSIY JADVAL — BARCHA HAYDOVCHI MA'LUMOTLARI SHU
-- JADVALDAN OLINADI. F.I.Sh., tabel raqami (employee_id), telefon, lavozim,
-- guvohnoma raqami va muddati (license_valid_until), tibbiy ko'rik muddati
-- (medical_certificate_valid_until), biriktirilgan mashina (transport_vehicle.assigned_driver_id orqali; ko'p-ko'pga esa vehicle_assigned_drivers jadvali),
-- va bo'lim.
-- DIQQAT: medical_cleared_today ustuni nomiga QARAMANG — u HAR KUNI
-- TOZALANMAYDI. 02.09.2026 o'lchovi: 206 aktiv haydovchidan 128 tasida
-- u `true`, holbuki o'sha kuni ATIGI 1 kishi ko'rikdan o'tgan (qolganlari
-- 3 kun oldin). "Bugun ko'rikdan o'tganmi" degan savolga BU USTUNDAN
-- javob berilmaydi — medical_inspection dan shift_date + status olinadi.
-- driver_availability_status — bandligi: AVAILABLE, RESERVED_FOR_TRIP, ON_TRIP,
-- REST_REQUIRED, SICK_LEAVE, BLOCKED, UNAVAILABLE.
-- employment_status — mehnat holati: ACTIVE, ON_LEAVE, SUSPENDED, TERMINATED.
-- ---------------------------------------------------------------------
CREATE TABLE driver (
    id uuid NOT NULL,
    birth_date date,
    created_at timestamptz NOT NULL,
    department_id uuid,
    driver_availability_status varchar(32) NOT NULL,  -- RUXSAT: 'AVAILABLE', 'RESERVED_FOR_TRIP', 'ON_TRIP', 'REST_REQUIRED', 'SICK_LEAVE', 'BLOCKED', 'UNAVAILABLE'; BAZADA: 'AVAILABLE' 263; ISHLATILMAGAN: RESERVED_FOR_TRIP, ON_TRIP, REST_REQUIRED, SICK_LEAVE, BLOCKED, UNAVAILABLE
    driver_license_number varchar(64) NOT NULL,
    employee_id varchar(64),
    employment_status varchar(32) NOT NULL,  -- RUXSAT: 'ACTIVE', 'ON_LEAVE', 'SUSPENDED', 'TERMINATED'
    erp_employee_id uuid,
    full_name varchar(256) NOT NULL,
    license_given_address varchar(512),
    license_valid_until date,
    medical_certificate_valid_until date,
    medical_cleared_today boolean NOT NULL,
    passport_given_address varchar(512),
    phone varchar(32) NOT NULL,
    pinfl varchar(32),
    position varchar(128) NOT NULL,
    table_number varchar(64),
    updated_at timestamptz NOT NULL,
    user_id uuid,
    branch_id uuid,
    deleted_at timestamptz,
    PRIMARY KEY (id),
    CHECK (driver_availability_status in ('AVAILABLE', 'RESERVED_FOR_TRIP', 'ON_TRIP', 'REST_REQUIRED', 'SICK_LEAVE', 'BLOCKED', 'UNAVAILABLE')),
    CHECK (employment_status in ('ACTIVE', 'ON_LEAVE', 'SUSPENDED', 'TERMINATED'))
);

-- TABLE: driver_assigned_vehicles  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Haydovchiga biriktirilgan mashinalar ro'yxati (bitta haydovchida bir nechta
-- mashina bo'lishi mumkin). Asosiy mashina driver.transport_vehicle.assigned_driver_id da.
-- ---------------------------------------------------------------------
CREATE TABLE driver_assigned_vehicles (
    driver_id uuid NOT NULL,
    vehicle_id uuid,
    FOREIGN KEY (driver_id) REFERENCES driver(id)
);

-- TABLE: driver_command_applied_receipt  (satrlar: noma'lum)
CREATE TABLE driver_command_applied_receipt (
    operation_id uuid NOT NULL,
    trip_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    command_hash varchar(64) NOT NULL,
    action varchar(16) NOT NULL,  -- RUXSAT: 'START', 'WAIT', 'RESUME', 'EXTEND', 'RETURN', 'COMPLETE', 'ISSUE'; BAZADA: 'RETURN' 1, 'START' 1, 'RESUME' 1, 'WAIT' 1; ISHLATILMAGAN: EXTEND, COMPLETE, ISSUE
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (operation_id) REFERENCES driver_command_operation_key(operation_id),
    CHECK (action in ('START', 'WAIT', 'RESUME', 'EXTEND', 'RETURN', 'COMPLETE', 'ISSUE')),
    CHECK (((command_hash) ~ '^[0-9a-f]{64}$'))
);

-- TABLE: driver_command_closure  (satrlar: 0 — BO`SH)
CREATE TABLE driver_command_closure (
    operation_id uuid NOT NULL,
    trip_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    command_hash varchar(64) NOT NULL,
    action varchar(16) NOT NULL,  -- RUXSAT: 'START', 'WAIT', 'RESUME', 'EXTEND', 'RETURN', 'COMPLETE', 'ISSUE'
    original_version bigint NOT NULL,
    reason varchar(1024) NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (operation_id) REFERENCES driver_command_operation_key(operation_id),
    CHECK (action in ('START', 'WAIT', 'RESUME', 'EXTEND', 'RETURN', 'COMPLETE', 'ISSUE')),
    CHECK (((command_hash) ~ '^[0-9a-f]{64}$')),
    CHECK ((original_version >= 0)),
    CHECK ((length(btrim((reason))) > 0))
);

-- TABLE: driver_command_operation_key  (satrlar: noma'lum)
CREATE TABLE driver_command_operation_key (
    operation_id uuid NOT NULL,
    kind varchar(16) NOT NULL,  -- RUXSAT: 'EVENT', 'CLOSED'
    PRIMARY KEY (operation_id),
    CHECK (kind in ('EVENT', 'CLOSED'))
);

-- TABLE: driver_completed_trip  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Haydovchi yakunlagan reyslarning qisqa tarixi (reys raqami, mashina, yakunlangan
-- vaqt). HAYDOVCHI QANCHA REYS BAJARGANI SO'RALSA SHU JADVALDAN TEZ OLINADI,
-- to'liq reys ma'lumoti esa trip jadvalida.
-- ---------------------------------------------------------------------
CREATE TABLE driver_completed_trip (
    id uuid NOT NULL,
    completed_at timestamptz NOT NULL,
    notes varchar(1024),
    trip_id uuid NOT NULL,
    trip_number varchar(64) NOT NULL,
    vehicle_id uuid,
    driver_id uuid NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (driver_id) REFERENCES driver(id)
);

-- TABLE: driver_credential  (satrlar: 0 — BO`SH)
-- ---------------------------------------------------------------------
-- Haydovchining identifikatsiya vositalari: RFID karta yoki QR kod. Yoqilg'i
-- quyish shoxobchasida haydovchini tanish uchun ishlatiladi. token_hash — kalitning
-- hash'i, active/revoked_at — faollik holati, expires_at — muddati.
-- YOQILG'I RUXSATNOMASI (fuel_authorization) SHU CREDENTIAL ORQALI BERILADI.
-- ---------------------------------------------------------------------
CREATE TABLE driver_credential (
    id uuid NOT NULL,
    active boolean NOT NULL,
    created_at timestamptz NOT NULL,
    credential_type varchar(16) NOT NULL,  -- [MAXFIY — o'qish taqiqlangan]; RUXSAT: 'RFID', 'QR_CODE'
    driver_id uuid NOT NULL,
    expires_at timestamptz,
    issued_at timestamptz NOT NULL,
    issued_by varchar(128),
    label varchar(128),
    revoked_at timestamptz,
    token_hash varchar(128) NOT NULL,  -- [MAXFIY — o'qish taqiqlangan]
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    CHECK (credential_type in ('RFID', 'QR_CODE'))
);

-- TABLE: driver_document  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Haydovchi hujjatlarining skanlari: guvohnoma, passport, tibbiy sertifikat va
-- boshqalar. s3_url — faylning manzili. Hujjat MUDDATLARI bu jadvalda emas,
-- driver jadvalida (license_valid_until, medical_certificate_valid_until).
-- ---------------------------------------------------------------------
CREATE TABLE driver_document (
    id uuid NOT NULL,
    file_name varchar(256) NOT NULL,
    kind varchar(32) NOT NULL,  -- RUXSAT: 'DRIVER_LICENSE_SCAN', 'PASSPORT_SCAN', 'MEDICAL_CERTIFICATE_SCAN', 'OTHER'; BAZADA: 'DRIVER_LICENSE_SCAN' 288; ISHLATILMAGAN: PASSPORT_SCAN, MEDICAL_CERTIFICATE_SCAN, OTHER
    mime_type varchar(128) NOT NULL,
    s3_url varchar(1024) NOT NULL,
    size_bytes bigint NOT NULL,
    uploaded_at timestamptz NOT NULL,
    driver_id uuid NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (driver_id) REFERENCES driver(id),
    CHECK (kind in ('DRIVER_LICENSE_SCAN', 'PASSPORT_SCAN', 'MEDICAL_CERTIFICATE_SCAN', 'OTHER'))
);

-- TABLE: driver_license_category  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Haydovchining haydovchilik guvohnomasi toifalari: A, B, BE, C, CE, D, DE.
-- BITTA HAYDOVCHIDA BIR NECHTA TOIFA BO'LADI. Marshrut talab qilgan toifa
-- route.required_driver_category da — mos haydovchi tanlashda shu jadval bilan
-- JOIN qilinadi.
-- ---------------------------------------------------------------------
CREATE TABLE driver_license_category (
    driver_id uuid NOT NULL,
    license_category varchar(8) NOT NULL,  -- RUXSAT: 'A', 'B', 'BE', 'C', 'CE', 'D', 'DE', 'E'; BAZADA: 'B' 243, 'C' 238, 'D' 126, 'CE' 87, 'BE' 74, 'A' 69, 'DE' 61, 'E' 43
    PRIMARY KEY (driver_id, license_category),
    FOREIGN KEY (driver_id) REFERENCES driver(id),
    CHECK (license_category in ('A', 'B', 'BE', 'C', 'CE', 'D', 'DE', 'E'))
);

-- TABLE: driver_qualification_document_event  (satrlar: noma'lum)
CREATE TABLE driver_qualification_document_event (
    id uuid NOT NULL,
    document_id uuid NOT NULL,
    driver_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    occurred_at timestamptz NOT NULL,
    reason varchar(1000) NOT NULL,
    sha256 varchar(64) NOT NULL,
    document_snapshot jsonb NOT NULL,  -- [JSON matn]
    PRIMARY KEY (id),
    CHECK ((btrim((reason)) <> '')),
    CHECK (((sha256) ~ '^[0-9a-f]{64}$'))
);

-- TABLE: driver_qualification_permit  (satrlar: noma'lum)
CREATE TABLE driver_qualification_permit (
    id uuid NOT NULL,
    target_type varchar(24) NOT NULL,
    target_id uuid NOT NULL,
    target_version bigint NOT NULL,
    action varchar(24) NOT NULL,
    proof_json text NOT NULL,  -- [JSON matn]
    proof_hash varchar(64) NOT NULL,
    actor_id uuid NOT NULL,
    occurred_at timestamptz NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: driver_qualification_revision  (satrlar: noma'lum)
CREATE TABLE driver_qualification_revision (
    id uuid NOT NULL,
    source_id uuid NOT NULL,
    version_after bigint NOT NULL,
    action varchar(24) NOT NULL,
    before_json jsonb,  -- [JSON matn]
    after_json jsonb NOT NULL,  -- [JSON matn]
    actor_id uuid NOT NULL,
    occurred_at timestamptz NOT NULL,
    reason varchar(1000) NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (source_id) REFERENCES driver_qualification_source(id)
);

-- TABLE: driver_qualification_source  (satrlar: noma'lum)
CREATE TABLE driver_qualification_source (
    id uuid NOT NULL,
    kind varchar(24) NOT NULL,
    driver_id uuid,
    branch_id uuid NOT NULL,
    vehicle_id uuid,
    trailer_id uuid,
    version bigint NOT NULL,
    state varchar(24) NOT NULL,
    document_id uuid,
    issuer varchar(256),
    source_reference varchar(512),
    valid_from timestamptz,
    valid_to timestamptz,
    categories text[],
    availability varchar(24),
    updated_by uuid NOT NULL,
    updated_at timestamptz NOT NULL,
    document_snapshot jsonb,  -- [JSON matn]
    composition_snapshot jsonb,  -- [JSON matn]
    PRIMARY KEY (id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (driver_id) REFERENCES driver(id)
);

-- TABLE: driver_shift  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Haydovchi smenalari: reja va amaldagi boshlanish/tugash vaqti, ishlangan soat,
-- tungi soat (night_hours), qo'shimcha soat (overtime_hours).
-- shift_type: DAY, NIGHT, SPLIT, STANDBY, DAY_OFF, VACATION, SICK_LEAVE.
-- status: PLANNED, CONFIRMED, COMPLETED, CANCELLED.
-- HAYDOVCHI ISH VAQTI VA QO'SHIMCHA SOATLAR SO'RALSA SHU JADVALDAN OLINADI —
-- ish haqi hisobi payroll_rate bilan birga qilinadi.
-- ---------------------------------------------------------------------
CREATE TABLE driver_shift (
    id uuid NOT NULL,
    actual_end_at timestamptz,
    actual_hours numeric(8,2),
    actual_start_at timestamptz,
    created_at timestamptz NOT NULL,
    driver_id uuid NOT NULL,
    driver_name varchar(256) NOT NULL,
    night_hours numeric(8,2),
    notes varchar(1024),
    overtime_hours numeric(8,2),
    planned_end_at timestamptz,
    planned_hours numeric(8,2) NOT NULL,
    planned_start_at timestamptz,
    shift_date date NOT NULL,
    shift_type varchar(32) NOT NULL,  -- RUXSAT: 'DAY', 'NIGHT', 'SPLIT', 'STANDBY', 'DAY_OFF', 'VACATION', 'SICK_LEAVE'
    status varchar(32) NOT NULL,  -- RUXSAT: 'PLANNED', 'CONFIRMED', 'COMPLETED', 'CANCELLED'; BAZADA: 'CONFIRMED' 4; ISHLATILMAGAN: PLANNED, COMPLETED, CANCELLED
    updated_at timestamptz NOT NULL,
    version bigint NOT NULL,
    actual_start_source_json text,  -- [JSON matn]
    actual_end_source_json text,  -- [JSON matn]
    PRIMARY KEY (id),
    CHECK (shift_type in ('DAY', 'NIGHT', 'SPLIT', 'STANDBY', 'DAY_OFF', 'VACATION', 'SICK_LEAVE')),
    CHECK (status in ('PLANNED', 'CONFIRMED', 'COMPLETED', 'CANCELLED'))
);

-- TABLE: eimzo_signature  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Elektron raqamli imzo (E-IMZO) sertifikati ma'lumotlari: STIR/PINFL, tashkilot
-- yoki jismoniy shaxs nomi, sertifikat seriya raqami, imzo natijasi (success,
-- error_code). app_user ga bog'langan.
-- HUJJATNI KIM IMZOLAGANI transport_document.signature_* ustunlarida.
-- (Ilgari `eimzo` deb atalardi — sxema ko'chirishda nomi o'zgargan.)
-- ---------------------------------------------------------------------
CREATE TABLE eimzo_signature (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    data varchar(20000),
    director_name varchar(256),
    director_pinfl varchar(32),
    error_code integer,
    error_message varchar(512),
    is_individual_entrepreneur boolean NOT NULL,
    is_legal boolean NOT NULL,
    name varchar(256),
    pinfl varchar(32),
    secret_key varchar(32) NOT NULL,  -- [MAXFIY — o'qish taqiqlangan]
    serial_number varchar(128),
    success boolean NOT NULL,
    timestamp varchar(128),
    tin varchar(32),
    tin_pinfl varchar(32),
    updated_at timestamptz NOT NULL,
    user_id uuid,
    PRIMARY KEY (id),
    FOREIGN KEY (user_id) REFERENCES app_user(id)
);

-- TABLE: emergency_medical_case  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- SMENA DAVOMIDAGI SHOSHILINCH TIBBIY HOLAT (haydovchi yo'lda kasal
-- bo'lib qolgani). Kasallik turi (illness_type), sodir bo'lgan vaqt
-- (incident_at), ko'rsatilgan yordam (emergency_aid_description),
-- mutaxassisga yo'llanma, qaror vaqti va ishga qaytishni to'suvchi
-- muddat (blocking_ends_at). Haydovchi, mashina va reysga bog'lanadi.
-- "Shoshilinch tibbiy holat", "haydovchi kasal bo'ldi" degan savol
-- SHU JADVALDAN olinadi — waybill.emergency_dispatch dan EMAS, u
-- butunlay boshqa narsa (shoshilinch jo'natma).
-- ---------------------------------------------------------------------
CREATE TABLE emergency_medical_case (
    id uuid NOT NULL,
    blocking_ends_at timestamptz,
    branch_id uuid NOT NULL,
    cancellation_reason text,
    created_at timestamptz NOT NULL,
    created_by uuid NOT NULL,
    decision_at timestamptz,
    decision_comment text,
    department_id uuid,
    department_name varchar(256),
    driver_full_name varchar(256) NOT NULL,
    driver_id uuid NOT NULL,
    emergency_aid_description text NOT NULL,
    illness_type varchar(512) NOT NULL,
    incident_at timestamptz NOT NULL,
    medical_inspection_id uuid,
    observation_started_at timestamptz NOT NULL,
    resolved_at timestamptz,
    shift_id uuid,
    specialist_referral_note text,
    status varchar(32) NOT NULL,  -- RUXSAT: 'OBSERVATION_REQUIRED', 'REFERRED_TO_SPECIALIST', 'WORK_SUSPENDED', 'WORK_ALLOWED', 'CANCELLED'; BAZADA: 'WORK_ALLOWED' 5, 'REFERRED_TO_SPECIALIST' 1; ISHLATILMAGAN: OBSERVATION_REQUIRED, WORK_SUSPENDED, CANCELLED
    trip_id uuid,
    updated_at timestamptz NOT NULL,
    updated_by uuid,
    vehicle_id uuid,
    vehicle_number varchar(32),
    version bigint NOT NULL,
    medical_inspection_version bigint,
    return_proof_json text,  -- [JSON matn]
    PRIMARY KEY (id),
    CHECK (status in ('OBSERVATION_REQUIRED', 'REFERRED_TO_SPECIALIST', 'WORK_SUSPENDED', 'WORK_ALLOWED', 'CANCELLED'))
);

-- TABLE: emergency_medical_case_branch_repair  (satrlar: noma'lum)
CREATE TABLE emergency_medical_case_branch_repair (
    case_id uuid NOT NULL,
    old_branch_id uuid NOT NULL,
    new_branch_id uuid NOT NULL,
    evidence_inspection_id uuid NOT NULL,
    repaired_at timestamptz NOT NULL,
    repaired_by text NOT NULL,
    reason text NOT NULL,
    PRIMARY KEY (case_id),
    FOREIGN KEY (evidence_inspection_id) REFERENCES medical_inspection(id),
    FOREIGN KEY (case_id) REFERENCES emergency_medical_case(id),
    FOREIGN KEY (new_branch_id) REFERENCES reference_data(id)
);

-- TABLE: emergency_medical_status_history  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Shoshilinch tibbiy holat (emergency_medical_case) holatining
-- O'ZGARISHLAR TARIXI: qaysi holatdan qaysi holatga (from_status ->
-- to_status), qachon va kim o'zgartirgani, izoh bilan.
-- ---------------------------------------------------------------------
CREATE TABLE emergency_medical_status_history (
    id uuid NOT NULL,
    changed_at timestamptz NOT NULL,
    changed_by uuid NOT NULL,
    changed_by_name varchar(256) NOT NULL,
    comment text,
    emergency_medical_case_id uuid NOT NULL,
    from_status varchar(32),  -- RUXSAT: 'OBSERVATION_REQUIRED', 'REFERRED_TO_SPECIALIST', 'WORK_SUSPENDED', 'WORK_ALLOWED', 'CANCELLED'; BAZADA: 'OBSERVATION_REQUIRED' 7, 'REFERRED_TO_SPECIALIST' 2; ISHLATILMAGAN: WORK_SUSPENDED, WORK_ALLOWED, CANCELLED
    to_status varchar(32) NOT NULL,  -- RUXSAT: 'OBSERVATION_REQUIRED', 'REFERRED_TO_SPECIALIST', 'WORK_SUSPENDED', 'WORK_ALLOWED', 'CANCELLED'; BAZADA: 'OBSERVATION_REQUIRED' 7, 'WORK_ALLOWED' 5, 'REFERRED_TO_SPECIALIST' 3, 'CANCELLED' 1, 'WORK_SUSPENDED' 1
    action varchar(16),
    after_json text,  -- [JSON matn]
    before_json text,  -- [JSON matn]
    case_version bigint,
    recorded_at timestamptz,
    PRIMARY KEY (id),
    CHECK (from_status in ('OBSERVATION_REQUIRED', 'REFERRED_TO_SPECIALIST', 'WORK_SUSPENDED', 'WORK_ALLOWED', 'CANCELLED')),
    CHECK (to_status in ('OBSERVATION_REQUIRED', 'REFERRED_TO_SPECIALIST', 'WORK_SUSPENDED', 'WORK_ALLOWED', 'CANCELLED'))
);

-- TABLE: emergency_operational_response  (satrlar: noma'lum)
CREATE TABLE emergency_operational_response (
    id uuid NOT NULL,
    case_id uuid NOT NULL,
    case_version bigint NOT NULL,
    trip_id uuid,
    branch_id uuid NOT NULL,
    operation_id varchar(128) NOT NULL,
    actual_at timestamptz NOT NULL,
    reference text NOT NULL,
    reason text NOT NULL,
    actor_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (case_id) REFERENCES emergency_medical_case(id),
    FOREIGN KEY (trip_id) REFERENCES trip(id),
    CHECK ((actual_at <= recorded_at)),
    CHECK (((btrim(reference) <> '') and (btrim(reason) <> '')))
);

-- TABLE: erp_trip_outbox  (satrlar: 0 — BO`SH)
-- ---------------------------------------------------------------------
-- Reys ma'lumotini tashqi ERP tizimiga yuborish navbati (outbox pattern).
-- status, attempt_count, last_error, next_attempt_at — yuborish holati.
-- ERP GA REYS KETMAGANI YOKI XATO BERGANI SO'RALSA SHU JADVALDAN OLINADI
-- (status <> yuborilgan yoki last_error to'ldirilgan qatorlar).
-- ---------------------------------------------------------------------
CREATE TABLE erp_trip_outbox (
    id uuid NOT NULL,
    attempt_count integer NOT NULL,
    created_at timestamptz NOT NULL,
    dispatched_at timestamptz,
    event_id varchar(36) NOT NULL,
    last_error varchar(1000),
    next_attempt_at timestamptz NOT NULL,
    payload_json text NOT NULL,  -- [JSON matn]
    status varchar(16) NOT NULL,
    trip_id uuid NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: erp_vehicle_outbox  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Mashina ma'lumotini tashqi ERP tizimiga yuborish navbati. Ishlash tartibi
-- erp_trip_outbox bilan bir xil.
-- ---------------------------------------------------------------------
CREATE TABLE erp_vehicle_outbox (
    id uuid NOT NULL,
    attempt_count integer NOT NULL,
    created_at timestamptz NOT NULL,
    dispatched_at timestamptz,
    event_id varchar(36) NOT NULL,
    last_error varchar(1000),
    next_attempt_at timestamptz NOT NULL,
    payload_json text NOT NULL,  -- [JSON matn]
    status varchar(16) NOT NULL,  -- BAZADA (eng ko'p uchraydiganlari): 'EXCHANGE_QUEUED' 59
    vehicle_id uuid NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: exploitation_batch_operation  (satrlar: noma'lum)
CREATE TABLE exploitation_batch_operation (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    payload_hash varchar(64) NOT NULL,
    performed_at timestamptz NOT NULL,
    result_json text NOT NULL,  -- [JSON matn]
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id)
);

-- TABLE: file_document  (satrlar: noma'lum)
CREATE TABLE file_document (
    id uuid NOT NULL,
    original_name varchar(512) NOT NULL,
    display_name varchar(512) NOT NULL,
    storage_key varchar(512) NOT NULL,
    mime_type varchar(128) NOT NULL,
    extension varchar(32) NOT NULL,
    size_bytes bigint NOT NULL,
    category varchar(64) NOT NULL,
    description varchar(2048),
    access_type varchar(32) NOT NULL,
    uploaded_by_id uuid NOT NULL,
    uploaded_by_name varchar(256),
    branch_id uuid,
    branch_name varchar(256),
    department_id uuid,
    department_name varchar(256),
    checksum varchar(64) NOT NULL,
    deleted boolean NOT NULL,
    deleted_at timestamptz,
    deleted_by_id uuid,
    deleted_by_name varchar(256),
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: finance_analytics_closed_operation  (satrlar: noma'lum)
CREATE TABLE finance_analytics_closed_operation (
    operation_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: finance_analytics_report_snapshot  (satrlar: noma'lum)
CREATE TABLE finance_analytics_report_snapshot (
    id uuid NOT NULL,
    branch_id uuid NOT NULL,
    department_id uuid,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    payload jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    captured_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: finance_analytics_revision  (satrlar: noma'lum)
CREATE TABLE finance_analytics_revision (
    operation_id uuid NOT NULL,
    series_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    kind text NOT NULL,  -- RUXSAT: 'PLAN', 'ENERGY_METHOD', 'ENERGY_FACT', 'FUEL_DEPARTMENT', 'CENSUS', 'EXCEPTION'
    revision bigint NOT NULL,
    action text NOT NULL,  -- RUXSAT: 'SAVE', 'APPROVE', 'REVOKE'
    state text NOT NULL,  -- RUXSAT: 'DRAFT', 'APPROVED', 'REVOKED'
    original jsonb NOT NULL,  -- [JSON matn]
    payload jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    CHECK (action in ('SAVE', 'APPROVE', 'REVOKE')),
    CHECK (kind in ('PLAN', 'ENERGY_METHOD', 'ENERGY_FACT', 'FUEL_DEPARTMENT', 'CENSUS', 'EXCEPTION')),
    CHECK ((revision > 0)),
    CHECK (state in ('DRAFT', 'APPROVED', 'REVOKED'))
);

-- TABLE: finance_capacity_allocation  (satrlar: noma'lum)
CREATE TABLE finance_capacity_allocation (
    id uuid NOT NULL,
    entry_id uuid NOT NULL,
    rule_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    source_json jsonb NOT NULL,  -- [JSON matn]
    source_hash text NOT NULL,
    shares jsonb NOT NULL,  -- [JSON matn]
    posted_by uuid NOT NULL,
    posted_at timestamptz NOT NULL,
    reason text NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (entry_id) REFERENCES transport_cost_entry(id),
    FOREIGN KEY (posted_by) REFERENCES app_user(id),
    FOREIGN KEY (rule_id) REFERENCES transport_cost_rule_head(id),
    CHECK ((jsonb_typeof(shares) = 'array'))
);

-- TABLE: finance_capacity_allocation_release  (satrlar: noma'lum)
CREATE TABLE finance_capacity_allocation_release (
    id uuid NOT NULL,
    allocation_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    released_by uuid NOT NULL,
    released_at timestamptz NOT NULL,
    reason text NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (allocation_id) REFERENCES finance_capacity_allocation(id),
    FOREIGN KEY (released_by) REFERENCES app_user(id)
);

-- TABLE: finance_cost_accounting_cancellation  (satrlar: noma'lum)
CREATE TABLE finance_cost_accounting_cancellation (
    id uuid NOT NULL,
    entry_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    owner text NOT NULL,
    owner_epoch bigint NOT NULL,
    provider text NOT NULL,
    document_id text NOT NULL,
    document_revision bigint NOT NULL,
    document_line_id text NOT NULL,
    confirmed_at timestamptz NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    payload_hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (entry_id) REFERENCES transport_cost_entry(id),
    CHECK ((payload_hash = encode(sha256(convert_to(original_json, 'utf8'::name)), 'hex')))
);

-- TABLE: finance_cost_command  (satrlar: noma'lum)
CREATE TABLE finance_cost_command (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    kind text NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    payload_hash text NOT NULL,
    state text NOT NULL,
    result_json jsonb,  -- [JSON matn]
    closure_reason text,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK ((payload_hash = encode(sha256(convert_to(original_json, 'utf8'::name)), 'hex'))),
    CHECK ((((state = 'applied') and (result_json is not null) and (closure_reason is null)) or ((state = 'not_executed') and (result_json is null) and (length(closure_reason) > 0))))
);

-- TABLE: finance_erp_cost_primary_census  (satrlar: 0 — BO`SH)
CREATE TABLE finance_erp_cost_primary_census (
    id uuid NOT NULL,
    branch_id uuid NOT NULL,
    owner text NOT NULL,  -- RUXSAT: 'SAP', 'ONE_C'
    owner_epoch bigint NOT NULL,
    provider text NOT NULL,
    from_at timestamptz NOT NULL,
    to_at timestamptz NOT NULL,
    document_reference text NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    payload_hash text NOT NULL,
    received_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    CHECK ((to_at > from_at)),
    CHECK (((to_at - from_at) <= '366 days'::interval)),
    CHECK ((payload_hash = encode(sha256(convert_to(original_json, 'utf8'::name)), 'hex'))),
    CHECK (owner in ('SAP', 'ONE_C')),
    CHECK ((owner_epoch > 0))
);

-- TABLE: finance_period  (satrlar: 0 — BO`SH)
CREATE TABLE finance_period (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    month date NOT NULL,
    time_zone text NOT NULL,
    from_at timestamptz NOT NULL,
    to_at timestamptz NOT NULL,
    version bigint NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'OPEN', 'CLOSED'
    current_close_id uuid,
    PRIMARY KEY (id),
    CHECK ((to_at > from_at)),
    CHECK ((month = (date_trunc('month', (month)::timestamp with time zone))::date)),
    CHECK (state in ('OPEN', 'CLOSED')),
    CHECK ((version >= 0))
);

-- TABLE: finance_period_close  (satrlar: noma'lum)
CREATE TABLE finance_period_close (
    id uuid NOT NULL,
    period_id uuid NOT NULL,
    period_version bigint NOT NULL,
    policy_id uuid NOT NULL,
    monthly_snapshot_id uuid,
    calculation_version text NOT NULL,
    snapshot_json text NOT NULL,  -- [JSON matn]
    snapshot_hash text NOT NULL,
    blockers_json jsonb NOT NULL,  -- [JSON matn]
    approved_by uuid NOT NULL,
    approved_at timestamptz NOT NULL,
    reason text NOT NULL,
    analytics_snapshot_id uuid,
    PRIMARY KEY (id),
    FOREIGN KEY (analytics_snapshot_id) REFERENCES finance_analytics_report_snapshot(id),
    FOREIGN KEY (approved_by) REFERENCES app_user(id),
    FOREIGN KEY (monthly_snapshot_id) REFERENCES monthly_statement_approval(id),
    FOREIGN KEY (period_id) REFERENCES finance_period(id),
    FOREIGN KEY (policy_id) REFERENCES finance_period_policy(id),
    CHECK ((num_nonnulls(monthly_snapshot_id, analytics_snapshot_id) = 1)),
    CHECK ((snapshot_hash = encode(sha256(convert_to(snapshot_json, 'utf8'::name)), 'hex')))
);

-- TABLE: finance_period_command  (satrlar: noma'lum)
CREATE TABLE finance_period_command (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    kind text NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    payload_hash text NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'APPLIED', 'NOT_EXECUTED'
    result_json text,  -- [JSON matn]
    closure_reason text,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK ((payload_hash = encode(sha256(convert_to(original_json, 'utf8'::name)), 'hex'))),
    CHECK ((((state = 'applied') and (result_json is not null) and (closure_reason is null)) or ((state = 'not_executed') and (result_json is null) and (length(closure_reason) > 0)))),
    CHECK (state in ('APPLIED', 'NOT_EXECUTED'))
);

-- TABLE: finance_period_correction_use  (satrlar: noma'lum)
CREATE TABLE finance_period_correction_use (
    correction_id uuid NOT NULL,
    period_id uuid NOT NULL,
    fact_hash text NOT NULL,
    domain text NOT NULL,
    source text NOT NULL,
    transaction_id bigint NOT NULL,
    used_at timestamptz NOT NULL,
    PRIMARY KEY (correction_id),
    FOREIGN KEY (correction_id) REFERENCES finance_period_request(id),
    FOREIGN KEY (period_id) REFERENCES finance_period(id)
);

-- TABLE: finance_period_decision  (satrlar: 0 — BO`SH)
CREATE TABLE finance_period_decision (
    id uuid NOT NULL,
    request_id uuid NOT NULL,
    period_id uuid NOT NULL,
    resulting_version bigint NOT NULL,
    decision text NOT NULL,  -- RUXSAT: 'APPROVE', 'REJECT'
    approved_by uuid NOT NULL,
    approved_at timestamptz NOT NULL,
    reason text NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (approved_by) REFERENCES app_user(id),
    FOREIGN KEY (period_id) REFERENCES finance_period(id),
    FOREIGN KEY (request_id) REFERENCES finance_period_request(id),
    CHECK (decision in ('APPROVE', 'REJECT'))
);

-- TABLE: finance_period_late_fact  (satrlar: noma'lum)
CREATE TABLE finance_period_late_fact (
    id uuid NOT NULL,
    period_id uuid NOT NULL,
    period_version bigint NOT NULL,
    branch_id uuid NOT NULL,
    occurred_at timestamptz NOT NULL,
    domain text NOT NULL,
    source text NOT NULL,
    fact_json text NOT NULL,  -- [JSON matn]
    fact_hash text NOT NULL,
    provider text NOT NULL,
    receipt_key text NOT NULL,
    received_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (period_id) REFERENCES finance_period(id),
    CHECK ((fact_hash = encode(sha256(convert_to(fact_json, 'utf8'::name)), 'hex')))
);

-- TABLE: finance_period_late_resolution  (satrlar: noma'lum)
CREATE TABLE finance_period_late_resolution (
    id uuid NOT NULL,
    late_fact_id uuid NOT NULL,
    evidence_domain text NOT NULL,
    evidence_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (late_fact_id) REFERENCES finance_period_late_fact(id)
);

-- TABLE: finance_period_policy  (satrlar: noma'lum)
CREATE TABLE finance_period_policy (
    id uuid NOT NULL,
    branch_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    organization_reference text NOT NULL,
    organization_name text NOT NULL,
    time_zone text NOT NULL,
    basis_document text NOT NULL,
    close_roles text[] NOT NULL,
    reopen_roles text[] NOT NULL,
    correction_roles text[] NOT NULL,
    created_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (created_by) REFERENCES app_user(id),
    CHECK (((length(basis_document) >= 1) and (length(basis_document) <= 1000))),
    CHECK ((cardinality(close_roles) > 0)),
    CHECK ((cardinality(correction_roles) > 0)),
    CHECK ((cardinality(reopen_roles) > 0))
);

-- TABLE: finance_period_policy_approval  (satrlar: noma'lum)
CREATE TABLE finance_period_policy_approval (
    id uuid NOT NULL,
    policy_id uuid NOT NULL,
    approved_by uuid NOT NULL,
    approved_at timestamptz NOT NULL,
    reason text NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (approved_by) REFERENCES app_user(id),
    FOREIGN KEY (policy_id) REFERENCES finance_period_policy(id)
);

-- TABLE: finance_period_request  (satrlar: 0 — BO`SH)
CREATE TABLE finance_period_request (
    id uuid NOT NULL,
    period_id uuid NOT NULL,
    period_version bigint NOT NULL,
    kind text NOT NULL,  -- RUXSAT: 'REOPEN', 'CORRECTION', 'DISMISS'
    domain text,
    source text,
    fact_hash text,
    late_fact_id uuid,
    document_reference text NOT NULL,
    reason text NOT NULL,
    proposed_by uuid NOT NULL,
    proposed_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (late_fact_id) REFERENCES finance_period_late_fact(id),
    FOREIGN KEY (period_id) REFERENCES finance_period(id),
    FOREIGN KEY (proposed_by) REFERENCES app_user(id),
    CHECK (((kind = 'reopen') or ((domain is not null) and (source is not null) and (fact_hash ~ '^[0-9a-f]{64}$')))),
    CHECK (kind in ('REOPEN', 'CORRECTION', 'DISMISS'))
);

-- TABLE: finance_repair_accounting_link  (satrlar: 0 — BO`SH)
CREATE TABLE finance_repair_accounting_link (
    id uuid NOT NULL,
    entry_id uuid NOT NULL,
    repair_source_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    nature text NOT NULL,  -- RUXSAT: 'WARRANTY_REIMBURSEMENT', 'ACCOUNTING_ADJUSTMENT', 'CONTRACTOR_COST'
    basis_document text NOT NULL,
    authored_by uuid NOT NULL,
    authored_at timestamptz NOT NULL,
    reason text NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (authored_by) REFERENCES app_user(id),
    FOREIGN KEY (entry_id) REFERENCES transport_cost_entry(id),
    FOREIGN KEY (repair_source_id) REFERENCES repair_cost_acceptance(id),
    CHECK (nature in ('WARRANTY_REIMBURSEMENT', 'ACCOUNTING_ADJUSTMENT', 'CONTRACTOR_COST'))
);

-- TABLE: finance_repair_accounting_review  (satrlar: noma'lum)
CREATE TABLE finance_repair_accounting_review (
    id uuid NOT NULL,
    link_id uuid NOT NULL,
    approved_by uuid NOT NULL,
    approved_at timestamptz NOT NULL,
    reason text NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (approved_by) REFERENCES app_user(id),
    FOREIGN KEY (link_id) REFERENCES finance_repair_accounting_link(id)
);

-- TABLE: finance_service_evidence  (satrlar: 0 — BO`SH)
CREATE TABLE finance_service_evidence (
    operation_id uuid NOT NULL,
    leg_id uuid NOT NULL,
    tariff_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    action text NOT NULL,  -- RUXSAT: 'SAVE', 'APPROVE', 'REVOKE'
    state text NOT NULL,  -- RUXSAT: 'DRAFT', 'APPROVED', 'REVOKED'
    original jsonb NOT NULL,  -- [JSON matn]
    snapshot jsonb NOT NULL,  -- [JSON matn]
    snapshot_hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (leg_id) REFERENCES transport_execution_leg(id),
    FOREIGN KEY (tariff_id) REFERENCES tariff(id),
    CHECK (action in ('SAVE', 'APPROVE', 'REVOKE')),
    CHECK ((revision > 0)),
    CHECK ((snapshot_hash ~ '^[0-9a-f]{64}$')),
    CHECK (state in ('DRAFT', 'APPROVED', 'REVOKED'))
);

-- TABLE: finance_service_evidence_closed  (satrlar: noma'lum)
CREATE TABLE finance_service_evidence_closed (
    operation_id uuid NOT NULL,
    leg_id uuid NOT NULL,
    tariff_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    CHECK (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 2000)))
);

-- TABLE: finance_shipment_cost_link  (satrlar: noma'lum)
CREATE TABLE finance_shipment_cost_link (
    id uuid NOT NULL,
    shipment_id uuid NOT NULL,
    graph_leg_id uuid NOT NULL,
    graph_revision_id uuid NOT NULL,
    execution_leg_id uuid NOT NULL,
    allocation_id uuid NOT NULL,
    entry_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    amount numeric(38,6) NOT NULL,
    currency text NOT NULL,
    money_scale integer NOT NULL,
    source_json jsonb NOT NULL,  -- [JSON matn]
    source_hash text NOT NULL,
    actor_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    reason text NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (allocation_id) REFERENCES transport_cost_allocation_record(id),
    FOREIGN KEY (entry_id) REFERENCES transport_cost_entry(id),
    FOREIGN KEY (execution_leg_id) REFERENCES transport_execution_leg(id),
    FOREIGN KEY (graph_revision_id) REFERENCES shipment_graph_leg_revision(id),
    FOREIGN KEY (shipment_id) REFERENCES shipment(id),
    CHECK ((amount >= (0))),
    CHECK ((amount = round(amount, money_scale)))
);

-- TABLE: finance_shipment_invoice_closed  (satrlar: noma'lum)
CREATE TABLE finance_shipment_invoice_closed (
    operation_id uuid NOT NULL,
    invoice_id uuid NOT NULL,
    shipment_id uuid NOT NULL,
    graph_leg_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (invoice_id) REFERENCES carrier_invoice(id),
    FOREIGN KEY (shipment_id) REFERENCES shipment(id)
);

-- TABLE: finance_shipment_invoice_link  (satrlar: noma'lum)
CREATE TABLE finance_shipment_invoice_link (
    operation_id uuid NOT NULL,
    invoice_id uuid NOT NULL,
    shipment_id uuid NOT NULL,
    graph_leg_id uuid NOT NULL,
    part_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    source_json jsonb NOT NULL,  -- [JSON matn]
    source_hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (invoice_id) REFERENCES carrier_invoice(id),
    FOREIGN KEY (shipment_id) REFERENCES shipment(id),
    CHECK ((source_hash ~ '^[a-f0-9]{64}$'))
);

-- TABLE: fine  (satrlar: 0 — BO`SH)
-- ---------------------------------------------------------------------
-- Jarimalar: tezlik oshirish, marshrutdan chiqish, bekor turish, YHXB jarimasi,
-- yoqilg'idan noto'g'ri foydalanish, zarar. Summasi (amount), holati
-- (OPEN, UNDER_REVIEW, CONFIRMED, DISMISSED, PAID), sodir bo'lgan vaqti.
-- trip, transport_vehicle jadvallariga bog'langan; haydovchi(lar) esa fine_driver
-- bog'lovchi jadvali orqali (bitta jarimada bir nechta haydovchi bo'lishi mumkin).
-- source_violation_id — jarima speed_violation dan avtomatik yaratilgan bo'lsa.
-- ---------------------------------------------------------------------
CREATE TABLE fine (
    id uuid NOT NULL,
    amount numeric(14,2) NOT NULL,
    created_at timestamptz NOT NULL,
    currency varchar(8) NOT NULL,
    description varchar(2000),
    external_reference varchar(255),
    fine_number varchar(32) NOT NULL,
    kind varchar(32) NOT NULL,  -- RUXSAT: 'SPEEDING', 'ROUTE_DEVIATION', 'IDLE_VIOLATION', 'TRAFFIC_POLICE', 'FUEL_MISUSE', 'DAMAGE', 'OTHER'
    occurred_at timestamptz NOT NULL,
    source_violation_id uuid,
    status varchar(32) NOT NULL,  -- RUXSAT: 'OPEN', 'UNDER_REVIEW', 'CONFIRMED', 'DISMISSED', 'PAID'
    status_comment varchar(2000),
    updated_at timestamptz NOT NULL,
    version bigint NOT NULL,
    trip_id uuid,
    vehicle_id uuid NOT NULL,
    basis varchar(2000),
    branch_id uuid,
    created_actor_kind varchar(32),
    created_by uuid,
    payment_evidence_id uuid,
    policy_id uuid,
    source_event_key varchar(512),
    source_kind varchar(32) NOT NULL,
    source_reference varchar(512),
    PRIMARY KEY (id),
    FOREIGN KEY (trip_id) REFERENCES trip(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id),
    CHECK (kind in ('SPEEDING', 'ROUTE_DEVIATION', 'IDLE_VIOLATION', 'TRAFFIC_POLICE', 'FUEL_MISUSE', 'DAMAGE', 'OTHER')),
    CHECK (status in ('OPEN', 'UNDER_REVIEW', 'CONFIRMED', 'DISMISSED', 'PAID'))
);

-- TABLE: fine_driver  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Jarima va haydovchi o'rtasidagi bog'lovchi jadval. HAYDOVCHINING JARIMALARI
-- SO'RALSA fine JADVALI SHU JADVAL ORQALI JOIN QILINADI.
-- ---------------------------------------------------------------------
CREATE TABLE fine_driver (
    fine_id uuid NOT NULL,
    driver_id uuid NOT NULL,
    FOREIGN KEY (driver_id) REFERENCES driver(id),
    FOREIGN KEY (fine_id) REFERENCES fine(id)
);

-- TABLE: fleet_aggregate_negative_closure  (satrlar: noma'lum)
CREATE TABLE fleet_aggregate_negative_closure (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    basis varchar(2000) NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (id) REFERENCES fleet_aggregate_original_command(id),
    CHECK ((btrim((basis)) <> ''))
);

-- TABLE: fleet_aggregate_original_command  (satrlar: 0 — BO`SH)
CREATE TABLE fleet_aggregate_original_command (
    id uuid NOT NULL,
    action varchar(16) NOT NULL,  -- RUXSAT: 'INSTALL', 'REMOVE', 'ACCEPT', 'REUSE', 'OPENING'
    part_id uuid NOT NULL,
    payload_json jsonb NOT NULL,  -- [JSON matn]
    payload_text text NOT NULL,
    domain_identity text NOT NULL,
    scope_json jsonb NOT NULL,  -- [JSON matn]
    actor_id uuid NOT NULL,
    actor varchar(255) NOT NULL,
    retained_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (part_id) REFERENCES vehicle_part(id),
    CHECK (action in ('INSTALL', 'REMOVE', 'ACCEPT', 'REUSE', 'OPENING')),
    CHECK ((jsonb_typeof(payload_json) = 'object'))
);

-- TABLE: fleet_aggregate_passport_revision  (satrlar: 0 — BO`SH)
CREATE TABLE fleet_aggregate_passport_revision (
    id uuid NOT NULL,
    part_id uuid NOT NULL,
    previous_revision_id uuid,
    revision bigint NOT NULL,
    canonical_serial_key varchar(400) NOT NULL,
    model varchar(255) NOT NULL,
    manufacturer varchar(255) NOT NULL,
    criticality varchar(32) NOT NULL,  -- RUXSAT: 'CRITICAL', 'NONCRITICAL', 'UNKNOWN'
    warranty_provider_reference varchar(255),
    warranty_document varchar(255),
    warranty_from timestamptz,
    warranty_to timestamptz,
    document varchar(255) NOT NULL,
    basis varchar(2000) NOT NULL,
    actor_id uuid NOT NULL,
    actor varchar(255) NOT NULL,
    recorded_at timestamptz NOT NULL,
    payload_identity varchar(64) NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (part_id) REFERENCES vehicle_part(id),
    FOREIGN KEY (previous_revision_id) REFERENCES fleet_aggregate_passport_revision(id),
    CHECK ((btrim((basis)) <> '')),
    CHECK ((((warranty_provider_reference is null) and (warranty_document is null) and (warranty_from is null) and (warranty_to is null)) or ((btrim((warranty_provider_reference)) <> '') and (btrim((warranty_document)) <> '') and (warranty_from is not null) and (warranty_to > warranty_from)))),
    CHECK (criticality in ('CRITICAL', 'NONCRITICAL', 'UNKNOWN')),
    CHECK ((btrim((document)) <> '')),
    CHECK ((btrim((manufacturer)) <> '')),
    CHECK ((btrim((model)) <> '')),
    CHECK ((revision > 0))
);

-- TABLE: fleet_calendar_closed_operation  (satrlar: noma'lum)
CREATE TABLE fleet_calendar_closed_operation (
    operation_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    kind text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id)
);

-- TABLE: fleet_capacity_calendar  (satrlar: noma'lum)
CREATE TABLE fleet_capacity_calendar (
    id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    starts_at timestamptz NOT NULL,
    ends_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id),
    CHECK ((ends_at > starts_at))
);

-- TABLE: fleet_capacity_revision  (satrlar: 0 — BO`SH)
CREATE TABLE fleet_capacity_revision (
    operation_id uuid NOT NULL,
    calendar_id uuid NOT NULL,
    version bigint NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'DRAFT', 'APPROVED', 'REVOKED'
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    intervals jsonb NOT NULL,  -- [JSON matn]
    source_snapshot jsonb NOT NULL,  -- [JSON matn]
    source_hash text NOT NULL,
    evidence_through timestamptz NOT NULL,
    as_of timestamptz NOT NULL,
    document_reference text NOT NULL,
    reason text NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (calendar_id) REFERENCES fleet_capacity_calendar(id),
    CHECK (state in ('DRAFT', 'APPROVED', 'REVOKED')),
    CHECK ((version > 0))
);

-- TABLE: fleet_census  (satrlar: noma'lum)
CREATE TABLE fleet_census (
    operation_id uuid NOT NULL,
    series_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    action text NOT NULL,
    state text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    calendar jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fleet_census_closed_operation  (satrlar: noma'lum)
CREATE TABLE fleet_census_closed_operation (
    operation_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    kind text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fleet_counter_intake_outcome  (satrlar: 0 — BO`SH)
CREATE TABLE fleet_counter_intake_outcome (
    id uuid NOT NULL,
    raw_id uuid NOT NULL,
    sequence bigint NOT NULL,
    state varchar(32) NOT NULL,  -- RUXSAT: 'UNCONFIGURED', 'REJECTED', 'UNKNOWN', 'POSTED', 'QUARANTINED', 'POSTED_REPLAY', 'QUARANTINED_REPLAY'
    reason varchar(120) NOT NULL,
    reading_id uuid,
    mapping_id uuid,
    binding_id uuid,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (binding_id) REFERENCES vehicle_gps(id),
    FOREIGN KEY (mapping_id) REFERENCES fleet_counter_mapping(id),
    FOREIGN KEY (raw_id) REFERENCES fleet_counter_intake_raw(id),
    FOREIGN KEY (reading_id) REFERENCES vehicle_usage_reading(id),
    CHECK (((reason) ~ '^[a-z0-9_]{1,120}$')),
    CHECK (state in ('UNCONFIGURED', 'REJECTED', 'UNKNOWN', 'POSTED', 'QUARANTINED', 'POSTED_REPLAY', 'QUARANTINED_REPLAY'))
);

-- TABLE: fleet_counter_intake_raw  (satrlar: noma'lum)
CREATE TABLE fleet_counter_intake_raw (
    id uuid NOT NULL,
    machine_id varchar(255) NOT NULL,
    delivery_key varchar(200) NOT NULL,
    raw_body bytea NOT NULL,
    raw_sha varchar(64) NOT NULL,
    received_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    CHECK (((raw_sha) = encode(sha256(raw_body), 'hex'))),
    CHECK ((btrim((delivery_key)) <> '')),
    CHECK (((octet_length(raw_body) >= 1) and (octet_length(raw_body) <= 1000000)))
);

-- TABLE: fleet_counter_machine_source_witness  (satrlar: noma'lum)
CREATE TABLE fleet_counter_machine_source_witness (
    raw_id uuid NOT NULL,
    reading_id uuid NOT NULL,
    mapping_id uuid NOT NULL,
    mapping_revision bigint NOT NULL,
    approval_id uuid NOT NULL,
    mapping_hash varchar(64) NOT NULL,
    binding_id uuid NOT NULL,
    binding_version bigint NOT NULL,
    ownership_hash varchar(64) NOT NULL,
    vehicle_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    machine_id varchar(255) NOT NULL,
    source_hash varchar(64) NOT NULL,
    PRIMARY KEY (raw_id),
    FOREIGN KEY (approval_id) REFERENCES fleet_counter_mapping_decision(id),
    FOREIGN KEY (binding_id) REFERENCES vehicle_gps(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (mapping_id) REFERENCES fleet_counter_mapping(id),
    FOREIGN KEY (raw_id) REFERENCES fleet_counter_intake_raw(id),
    FOREIGN KEY (reading_id) REFERENCES vehicle_usage_reading(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id)
);

-- TABLE: fleet_counter_mapping  (satrlar: noma'lum)
CREATE TABLE fleet_counter_mapping (
    id uuid NOT NULL,
    previous_mapping_id uuid,
    revision bigint NOT NULL,
    branch_id uuid NOT NULL,
    provider_connection varchar(32) NOT NULL,
    organization_reference varchar(255) NOT NULL,
    machine_id varchar(255) NOT NULL,
    metric_key varchar(100) NOT NULL,
    payload_json jsonb NOT NULL,  -- [JSON matn]
    payload_text text NOT NULL,
    payload_identity varchar(64) NOT NULL,
    actor_id uuid NOT NULL,
    actor varchar(255) NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (previous_mapping_id) REFERENCES fleet_counter_mapping(id),
    CHECK ((revision > 0))
);

-- TABLE: fleet_counter_mapping_decision  (satrlar: 0 — BO`SH)
CREATE TABLE fleet_counter_mapping_decision (
    id uuid NOT NULL,
    mapping_id uuid NOT NULL,
    action varchar(16) NOT NULL,  -- RUXSAT: 'APPROVE', 'REVOKE'
    reviewed_hash varchar(64) NOT NULL,
    document varchar(255) NOT NULL,
    basis varchar(2000) NOT NULL,
    actor_id uuid NOT NULL,
    actor varchar(255) NOT NULL,
    recorded_at timestamptz NOT NULL,
    payload_json jsonb NOT NULL,  -- [JSON matn]
    payload_text text NOT NULL,
    payload_identity varchar(64) NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (mapping_id) REFERENCES fleet_counter_mapping(id),
    CHECK (action in ('APPROVE', 'REVOKE')),
    CHECK ((btrim((basis)) <> '')),
    CHECK ((btrim((document)) <> ''))
);

-- TABLE: fleet_counter_negative_closure  (satrlar: noma'lum)
CREATE TABLE fleet_counter_negative_closure (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    basis varchar(2000) NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (id) REFERENCES fleet_counter_original_command(id),
    CHECK ((btrim((basis)) <> ''))
);

-- TABLE: fleet_counter_original_command  (satrlar: 0 — BO`SH)
CREATE TABLE fleet_counter_original_command (
    id uuid NOT NULL,
    namespace varchar(16) NOT NULL,  -- RUXSAT: 'MAPPING', 'DECISION'
    branch_id uuid NOT NULL,
    payload_json jsonb NOT NULL,  -- [JSON matn]
    payload_text text NOT NULL,
    payload_identity varchar(64) NOT NULL,
    actor_id uuid NOT NULL,
    actor varchar(255) NOT NULL,
    retained_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    CHECK (namespace in ('MAPPING', 'DECISION'))
);

-- TABLE: fleet_counter_posted_source  (satrlar: 0 — BO`SH)
CREATE TABLE fleet_counter_posted_source (
    id uuid NOT NULL,
    raw_id uuid NOT NULL,
    raw_sha varchar(64) NOT NULL,
    mapping_id uuid NOT NULL,
    binding_id uuid NOT NULL,
    binding_version bigint NOT NULL,
    ownership_hash varchar(64) NOT NULL,
    vehicle_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    provider_connection varchar(32) NOT NULL,
    organization_reference varchar(255) NOT NULL,
    provider_device_id bigint NOT NULL,
    external_event_id varchar(200) NOT NULL,
    metric_key varchar(100) NOT NULL,
    counter varchar(32) NOT NULL,  -- RUXSAT: 'ODOMETER_KM', 'ENGINE_HOURS'
    input_value numeric NOT NULL,
    input_unit varchar(32) NOT NULL,
    converted_value numeric(20,3) NOT NULL,
    reading_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (binding_id) REFERENCES vehicle_gps(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (mapping_id) REFERENCES fleet_counter_mapping(id),
    FOREIGN KEY (raw_id) REFERENCES fleet_counter_intake_raw(id),
    FOREIGN KEY (reading_id) REFERENCES vehicle_usage_reading(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id),
    CHECK ((converted_value >= (0))),
    CHECK (counter in ('ODOMETER_KM', 'ENGINE_HOURS')),
    CHECK ((input_value >= (0))),
    CHECK ((provider_device_id > 0))
);

-- TABLE: fleet_defect  (satrlar: noma'lum)
CREATE TABLE fleet_defect (
    defect_id uuid NOT NULL,
    object_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    source_type text NOT NULL,
    source_reference text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    repair_id uuid,
    version bigint NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'OPEN', 'MERGED', 'CANCELLED', 'RESOLVED'
    merged_into uuid,
    actor_id uuid NOT NULL,
    detected_at timestamptz NOT NULL,
    PRIMARY KEY (defect_id),
    FOREIGN KEY (merged_into) REFERENCES fleet_defect(defect_id),
    FOREIGN KEY (repair_id) REFERENCES vehicle_repair(id),
    CHECK (state in ('OPEN', 'MERGED', 'CANCELLED', 'RESOLVED')),
    CHECK ((version >= 1))
);

-- TABLE: fleet_defect_event  (satrlar: noma'lum)
CREATE TABLE fleet_defect_event (
    operation_id uuid NOT NULL,
    defect_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    result jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (defect_id) REFERENCES fleet_defect(defect_id)
);

-- TABLE: fleet_failure_closed_operation  (satrlar: noma'lum)
CREATE TABLE fleet_failure_closed_operation (
    operation_id uuid NOT NULL,
    failure_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    kind text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id)
);

-- TABLE: fleet_failure_event  (satrlar: noma'lum)
CREATE TABLE fleet_failure_event (
    operation_id uuid NOT NULL,
    failure_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    action text NOT NULL,
    state text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    failure jsonb NOT NULL,  -- [JSON matn]
    failure_document jsonb NOT NULL,  -- [JSON matn]
    restoration_document jsonb,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id)
);

-- TABLE: fleet_material_negative_closure  (satrlar: noma'lum)
CREATE TABLE fleet_material_negative_closure (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    basis varchar(2000) NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (id) REFERENCES fleet_material_original_command(id),
    CHECK ((btrim((basis)) <> ''))
);

-- TABLE: fleet_material_original_command  (satrlar: noma'lum)
CREATE TABLE fleet_material_original_command (
    id uuid NOT NULL,
    namespace varchar(40) NOT NULL,
    target varchar(500) NOT NULL,
    stock_ids jsonb NOT NULL,  -- [JSON matn]
    payload_json jsonb NOT NULL,  -- [JSON matn]
    payload_text text NOT NULL,
    payload_identity varchar(64) NOT NULL,
    actor_id uuid NOT NULL,
    actor varchar(255) NOT NULL,
    retained_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK (((jsonb_typeof(stock_ids) = 'array') and (((namespace) = any ((array['warranty', 'condition'])[])) or (jsonb_array_length(stock_ids) > 0)))),
    CHECK (((payload_text)::jsonb = payload_json)),
    CHECK ((jsonb_typeof(payload_json) = 'object'))
);

-- TABLE: fleet_material_return_receipt_allocation  (satrlar: noma'lum)
CREATE TABLE fleet_material_return_receipt_allocation (
    receipt_operation_id uuid NOT NULL,
    request_operation_id uuid NOT NULL,
    quantity numeric(16,3) NOT NULL,
    serial_part_ids text,
    PRIMARY KEY (receipt_operation_id, request_operation_id),
    FOREIGN KEY (receipt_operation_id) REFERENCES material_operation(id),
    FOREIGN KEY (request_operation_id) REFERENCES material_operation(id),
    CHECK ((quantity > (0)))
);

-- TABLE: fleet_membership  (satrlar: noma'lum)
CREATE TABLE fleet_membership (
    operation_id uuid NOT NULL,
    series_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    action text NOT NULL,
    state text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    calendar jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id)
);

-- TABLE: fleet_membership_closed_operation  (satrlar: noma'lum)
CREATE TABLE fleet_membership_closed_operation (
    operation_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    kind text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id)
);

-- TABLE: fleet_observation  (satrlar: noma'lum)
CREATE TABLE fleet_observation (
    operation_id uuid NOT NULL,
    series_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    action text NOT NULL,
    state text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    calendar jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id)
);

-- TABLE: fleet_observation_closed_operation  (satrlar: noma'lum)
CREATE TABLE fleet_observation_closed_operation (
    operation_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    kind text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id)
);

-- TABLE: fleet_operation  (satrlar: noma'lum)
CREATE TABLE fleet_operation (
    operation_id uuid NOT NULL,
    object_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    state text NOT NULL,  -- RUXSAT: 'IN_FLIGHT', 'RECORDED', 'NOT_EXECUTED'; BAZADA: 'RECORDED' 12; ISHLATILMAGAN: IN_FLIGHT, NOT_EXECUTED
    result jsonb,  -- [JSON matn]
    closure_reason text,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    CHECK (state in ('IN_FLIGHT', 'RECORDED', 'NOT_EXECUTED'))
);

-- TABLE: fleet_passport_admission_fact  (satrlar: noma'lum)
CREATE TABLE fleet_passport_admission_fact (
    admission_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    trailer_id uuid,
    branch_id uuid NOT NULL,
    starts_at timestamptz NOT NULL,
    ends_at timestamptz NOT NULL,
    actor_id uuid NOT NULL,
    proof jsonb NOT NULL,  -- [JSON matn]
    created_at timestamptz NOT NULL,
    PRIMARY KEY (admission_id),
    CHECK ((ends_at > starts_at))
);

-- TABLE: fleet_passport_assignment_mutation  (satrlar: 0 — BO`SH)
CREATE TABLE fleet_passport_assignment_mutation (
    operation_id uuid NOT NULL,
    event_id uuid NOT NULL,
    source_operation_id uuid NOT NULL,
    admission_id uuid NOT NULL,
    object_kind text NOT NULL,  -- RUXSAT: 'VEHICLE', 'TRAILER'
    object_id uuid NOT NULL,
    assignment_type text NOT NULL,  -- RUXSAT: 'TRIP', 'WAYBILL'
    assignment_reference text NOT NULL,
    trip_id uuid NOT NULL,
    trip_version bigint NOT NULL,
    effective_at timestamptz NOT NULL,
    starts_at timestamptz NOT NULL,
    ends_at timestamptz NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (admission_id) REFERENCES fleet_passport_admission_fact(admission_id),
    FOREIGN KEY (event_id) REFERENCES transport_assignment_event(id),
    FOREIGN KEY (operation_id) REFERENCES fleet_passport_assignment_snapshot(operation_id),
    FOREIGN KEY (source_operation_id) REFERENCES transport_assignment_command(operation_id),
    FOREIGN KEY (trip_id) REFERENCES trip(id),
    CHECK (assignment_type in ('TRIP', 'WAYBILL')),
    CHECK (((ends_at > starts_at) and (effective_at < ends_at))),
    CHECK (object_kind in ('VEHICLE', 'TRAILER')),
    CHECK ((trip_version >= 0))
);

-- TABLE: fleet_passport_assignment_snapshot  (satrlar: 0 — BO`SH)
CREATE TABLE fleet_passport_assignment_snapshot (
    operation_id uuid NOT NULL,
    object_id uuid NOT NULL,
    assignment_type text NOT NULL,  -- RUXSAT: 'TRIP', 'WAYBILL', 'RESOURCE_REQUEST'
    assignment_reference text NOT NULL,
    starts_at timestamptz NOT NULL,
    ends_at timestamptz NOT NULL,
    snapshot jsonb NOT NULL,  -- [JSON matn]
    actor_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (operation_id) REFERENCES fleet_passport_command(operation_id),
    CHECK (assignment_type in ('TRIP', 'WAYBILL', 'RESOURCE_REQUEST')),
    CHECK ((ends_at > starts_at))
);

-- TABLE: fleet_passport_command  (satrlar: noma'lum)
CREATE TABLE fleet_passport_command (
    operation_id uuid NOT NULL,
    object_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    action text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    result jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (object_id) REFERENCES fleet_passport_object(object_id)
);

-- TABLE: fleet_passport_coupling  (satrlar: noma'lum)
CREATE TABLE fleet_passport_coupling (
    operation_id uuid NOT NULL,
    tractor_id uuid NOT NULL,
    trailer_id uuid NOT NULL,
    starts_at timestamptz NOT NULL,
    ends_at timestamptz NOT NULL,
    snapshot jsonb NOT NULL,  -- [JSON matn]
    actor_id uuid NOT NULL,
    cancelled_by uuid,
    cancellation_reference text,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (operation_id) REFERENCES fleet_passport_command(operation_id),
    CHECK ((ends_at > starts_at))
);

-- TABLE: fleet_passport_erp_attempt  (satrlar: noma'lum)
CREATE TABLE fleet_passport_erp_attempt (
    operation_id uuid NOT NULL,
    event_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (event_id) REFERENCES fleet_passport_erp_delivery(event_id)
);

-- TABLE: fleet_passport_erp_delivery  (satrlar: noma'lum)
CREATE TABLE fleet_passport_erp_delivery (
    event_id uuid NOT NULL,
    object_id uuid NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'PENDING', 'FAILED', 'CONFIRMED'
    attempts bigint NOT NULL,
    erp_asset_reference text,
    receipt_reference text,
    last_error text,
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (event_id),
    FOREIGN KEY (event_id) REFERENCES fleet_passport_lifecycle(operation_id),
    CHECK (state in ('PENDING', 'FAILED', 'CONFIRMED'))
);

-- TABLE: fleet_passport_lifecycle  (satrlar: noma'lum)
CREATE TABLE fleet_passport_lifecycle (
    operation_id uuid NOT NULL,
    object_id uuid NOT NULL,
    version bigint NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'RECEIVED', 'COMMISSIONED', 'CONSERVED', 'WITHDRAWN'; BAZADA: 'COMMISSIONED' 2; ISHLATILMAGAN: RECEIVED, CONSERVED, WITHDRAWN
    action text NOT NULL,
    effective_at timestamptz NOT NULL,
    branch_id uuid NOT NULL,
    reason text NOT NULL,
    document_reference text NOT NULL,
    actor_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (object_id) REFERENCES fleet_passport_object(object_id),
    FOREIGN KEY (operation_id) REFERENCES fleet_passport_command(operation_id),
    CHECK (state in ('RECEIVED', 'COMMISSIONED', 'CONSERVED', 'WITHDRAWN')),
    CHECK ((version > 0))
);

-- TABLE: fleet_passport_object  (satrlar: noma'lum)
CREATE TABLE fleet_passport_object (
    object_id uuid NOT NULL,
    kind text NOT NULL,  -- RUXSAT: 'VEHICLE', 'TRAILER'
    branch_id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (object_id),
    CHECK (kind in ('VEHICLE', 'TRAILER'))
);

-- TABLE: fleet_passport_profile  (satrlar: noma'lum)
CREATE TABLE fleet_passport_profile (
    operation_id uuid NOT NULL,
    object_id uuid NOT NULL,
    version bigint NOT NULL,
    effective_from timestamptz NOT NULL,
    effective_to timestamptz,
    profile jsonb NOT NULL,  -- [JSON matn]
    actor_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (object_id) REFERENCES fleet_passport_object(object_id),
    FOREIGN KEY (operation_id) REFERENCES fleet_passport_command(operation_id),
    CHECK (((effective_to is null) or (effective_to > effective_from))),
    CHECK ((version > 0))
);

-- TABLE: fleet_passport_task  (satrlar: 0 — BO`SH)
CREATE TABLE fleet_passport_task (
    task_id uuid NOT NULL,
    object_id uuid NOT NULL,
    kind text NOT NULL,  -- RUXSAT: 'MAINTENANCE', 'REPAIR', 'EQUIPMENT'
    title text NOT NULL,
    due_at timestamptz,
    blocking boolean NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'OPEN', 'WORK_DONE', 'AWAITING_ACCEPTANCE', 'FAILED', 'PASSED', 'CANCELLED'
    created_by uuid NOT NULL,
    last_actor uuid NOT NULL,
    version bigint NOT NULL,
    data jsonb NOT NULL,  -- [JSON matn]
    PRIMARY KEY (task_id),
    CHECK (kind in ('MAINTENANCE', 'REPAIR', 'EQUIPMENT')),
    CHECK (state in ('OPEN', 'WORK_DONE', 'AWAITING_ACCEPTANCE', 'FAILED', 'PASSED', 'CANCELLED'))
);

-- TABLE: fleet_passport_usage  (satrlar: noma'lum)
CREATE TABLE fleet_passport_usage (
    operation_id uuid NOT NULL,
    object_id uuid NOT NULL,
    observed_at timestamptz NOT NULL,
    km numeric,
    hours numeric,
    source_reference text NOT NULL,
    actor_id uuid NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (operation_id) REFERENCES fleet_passport_command(operation_id),
    CHECK (((km is not null) or (hours is not null))),
    CHECK (((hours is null) or (hours >= (0)))),
    CHECK (((km is null) or (km >= (0))))
);

-- TABLE: fleet_repair_acceptance  (satrlar: 0 — BO`SH)
CREATE TABLE fleet_repair_acceptance (
    operation_id uuid NOT NULL,
    repair_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    result text NOT NULL,  -- RUXSAT: 'PASSED', 'FAILED'
    accepted_at timestamptz NOT NULL,
    checked_operations jsonb NOT NULL,  -- [JSON matn]
    authority_reference text NOT NULL,
    evidence_reference text NOT NULL,
    snapshot jsonb NOT NULL,  -- [JSON matn]
    PRIMARY KEY (operation_id),
    FOREIGN KEY (repair_id) REFERENCES vehicle_repair(id),
    CHECK (result in ('PASSED', 'FAILED'))
);

-- TABLE: fleet_repair_late_original  (satrlar: 0 — BO`SH)
CREATE TABLE fleet_repair_late_original (
    id uuid NOT NULL,
    domain text NOT NULL,  -- RUXSAT: 'FLEET_REPAIR', 'FLEET_REPAIR_ADJUSTMENT'
    repair_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    raw_sha text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (repair_id) REFERENCES vehicle_repair(id),
    CHECK ((raw_sha = encode(sha256(convert_to(original_json, 'utf8'::name)), 'hex'))),
    CHECK (((((original_json)::jsonb ->> 'repairid') = (repair_id)) and (((original_json)::jsonb ->> 'actorid') = (actor_id)) and (((original_json)::jsonb #>> '{request,commandid}'[]) = (id)))),
    CHECK (domain in ('FLEET_REPAIR', 'FLEET_REPAIR_ADJUSTMENT'))
);

-- TABLE: fleet_repair_work  (satrlar: noma'lum)
CREATE TABLE fleet_repair_work (
    repair_id uuid NOT NULL,
    work_id text NOT NULL,
    title text NOT NULL,
    required boolean NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'ASSIGNED', 'DONE', 'WAIVED'
    assigned_user_id uuid NOT NULL,
    performer_id uuid,
    starts_at timestamptz,
    ends_at timestamptz,
    labor_hours numeric,
    evidence_reference text,
    waiver_reference text,
    last_operation_id uuid NOT NULL,
    PRIMARY KEY (repair_id, work_id),
    FOREIGN KEY (repair_id) REFERENCES vehicle_repair(id),
    CHECK (((ends_at is null) or (ends_at > starts_at))),
    CHECK (((labor_hours is null) or (labor_hours >= (0)))),
    CHECK (state in ('ASSIGNED', 'DONE', 'WAIVED'))
);

-- TABLE: fleet_repair_work_event  (satrlar: noma'lum)
CREATE TABLE fleet_repair_work_event (
    operation_id uuid NOT NULL,
    repair_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    result jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (repair_id) REFERENCES vehicle_repair(id)
);

-- TABLE: fleet_resource_calendar  (satrlar: noma'lum)
CREATE TABLE fleet_resource_calendar (
    operation_id uuid NOT NULL,
    series_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    action text NOT NULL,
    state text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    calendar jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id)
);

-- TABLE: fleet_serial_command  (satrlar: 0 — BO`SH)
CREATE TABLE fleet_serial_command (
    id uuid NOT NULL,
    action varchar(32) NOT NULL,  -- RUXSAT: 'TRANSFER_OUT', 'TRANSFER_IN', 'RECEIVE_REMOVED', 'COUNT', 'INVENTORY_FOUND', 'APPLY_QUALITY', 'RETURN_SUPPLIER'
    stock_id uuid NOT NULL,
    target_stock_id uuid,
    document varchar(255) NOT NULL,
    basis varchar(2000) NOT NULL,
    occurred_at timestamptz NOT NULL,
    actor_id uuid NOT NULL,
    actor varchar(255) NOT NULL,
    payload_json jsonb NOT NULL,  -- [JSON matn]
    payload_identity varchar(64) NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (stock_id) REFERENCES inventory_stock(id),
    FOREIGN KEY (target_stock_id) REFERENCES inventory_stock(id),
    CHECK (action in ('TRANSFER_OUT', 'TRANSFER_IN', 'RECEIVE_REMOVED', 'COUNT', 'INVENTORY_FOUND', 'APPLY_QUALITY', 'RETURN_SUPPLIER')),
    CHECK ((btrim((basis)) <> '')),
    CHECK ((btrim((document)) <> ''))
);

-- TABLE: fleet_serial_event  (satrlar: 0 — BO`SH)
CREATE TABLE fleet_serial_event (
    id uuid NOT NULL,
    command_id uuid NOT NULL,
    part_id uuid NOT NULL,
    previous_event_id uuid,
    revision bigint NOT NULL,
    stock_id uuid NOT NULL,
    branch_id uuid,
    state varchar(32) NOT NULL,  -- RUXSAT: 'USABLE', 'QUARANTINE', 'STORAGE', 'REPAIR', 'IN_TRANSIT', 'LOST', 'SUPPLIER_RETURNED'
    disposition varchar(32) NOT NULL,  -- RUXSAT: 'USABLE', 'QUARANTINE'
    stock_accounted boolean NOT NULL,
    removal_installation_id uuid,
    occurred_at timestamptz NOT NULL,
    actor_id uuid NOT NULL,
    actor varchar(255) NOT NULL,
    document varchar(255) NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (command_id) REFERENCES fleet_serial_command(id),
    FOREIGN KEY (part_id) REFERENCES vehicle_part(id),
    FOREIGN KEY (previous_event_id) REFERENCES fleet_serial_event(id),
    FOREIGN KEY (removal_installation_id) REFERENCES part_installation(id),
    FOREIGN KEY (stock_id) REFERENCES inventory_stock(id),
    CHECK ((stock_accounted or (removal_installation_id is not null))),
    CHECK (disposition in ('USABLE', 'QUARANTINE')),
    CHECK ((revision > 0)),
    CHECK (state in ('USABLE', 'QUARANTINE', 'STORAGE', 'REPAIR', 'IN_TRANSIT', 'LOST', 'SUPPLIER_RETURNED'))
);

-- TABLE: fleet_serial_quality_approval  (satrlar: noma'lum)
CREATE TABLE fleet_serial_quality_approval (
    id uuid NOT NULL,
    decision_id uuid NOT NULL,
    source_hash varchar(64) NOT NULL,
    document varchar(255) NOT NULL,
    basis varchar(2000) NOT NULL,
    actor_id uuid NOT NULL,
    actor varchar(255) NOT NULL,
    recorded_at timestamptz NOT NULL,
    payload_identity varchar(64) NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (decision_id) REFERENCES fleet_serial_quality_decision(id),
    CHECK ((btrim((basis)) <> '')),
    CHECK ((btrim((document)) <> ''))
);

-- TABLE: fleet_serial_quality_decision  (satrlar: 0 — BO`SH)
CREATE TABLE fleet_serial_quality_decision (
    id uuid NOT NULL,
    part_id uuid NOT NULL,
    stock_id uuid NOT NULL,
    previous_event_id uuid,
    passport_version bigint NOT NULL,
    condition_evaluation_id uuid,
    disposition varchar(32) NOT NULL,  -- RUXSAT: 'RELEASE_USABLE', 'REPAIR', 'RETURN_SUPPLIER', 'KEEP_QUARANTINE'
    supplier_reference varchar(255),
    document varchar(255) NOT NULL,
    basis varchar(2000) NOT NULL,
    actor_id uuid NOT NULL,
    actor varchar(255) NOT NULL,
    recorded_at timestamptz NOT NULL,
    payload_identity varchar(64) NOT NULL,
    source_hash varchar(64) NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (condition_evaluation_id) REFERENCES part_condition_evaluation(id),
    FOREIGN KEY (part_id) REFERENCES vehicle_part(id),
    FOREIGN KEY (previous_event_id) REFERENCES fleet_serial_event(id),
    FOREIGN KEY (stock_id) REFERENCES inventory_stock(id),
    CHECK ((btrim((basis)) <> '')),
    CHECK (((((disposition) = 'return_supplier') and (supplier_reference is not null) and (btrim((supplier_reference)) <> '')) or (((disposition) <> 'return_supplier') and (supplier_reference is null)))),
    CHECK (disposition in ('RELEASE_USABLE', 'REPAIR', 'RETURN_SUPPLIER', 'KEEP_QUARANTINE')),
    CHECK ((btrim((document)) <> ''))
);

-- TABLE: fleet_serial_warehouse_policy  (satrlar: noma'lum)
CREATE TABLE fleet_serial_warehouse_policy (
    id uuid NOT NULL,
    warehouse_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    previous_policy_id uuid,
    document varchar(255) NOT NULL,
    basis varchar(2000) NOT NULL,
    actor_id uuid NOT NULL,
    actor varchar(255) NOT NULL,
    recorded_at timestamptz NOT NULL,
    payload_identity varchar(64) NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (previous_policy_id) REFERENCES fleet_serial_warehouse_policy(id),
    FOREIGN KEY (warehouse_id) REFERENCES reference_data(id),
    CHECK ((btrim((basis)) <> '')),
    CHECK ((btrim((document)) <> ''))
);

-- TABLE: fleet_usage_policy  (satrlar: 0 — BO`SH)
CREATE TABLE fleet_usage_policy (
    operation_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'DRAFT', 'APPROVED', 'REVOKED'
    original jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    CHECK (state in ('DRAFT', 'APPROVED', 'REVOKED'))
);

-- TABLE: fleet_usage_policy_closed  (satrlar: noma'lum)
CREATE TABLE fleet_usage_policy_closed (
    operation_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fleet_warranty_claim  (satrlar: noma'lum)
CREATE TABLE fleet_warranty_claim (
    id uuid NOT NULL,
    repair_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    repair_version bigint NOT NULL,
    part_id uuid NOT NULL,
    installation_id uuid NOT NULL,
    aggregate_revision_id uuid NOT NULL,
    incident_at timestamptz NOT NULL,
    supplier_reference varchar(255) NOT NULL,
    contract_reference varchar(255) NOT NULL,
    claim_document varchar(255) NOT NULL,
    description varchar(2000) NOT NULL,
    claimed_amount numeric(24,6),
    currency varchar(3),
    basis varchar(2000) NOT NULL,
    actor_id uuid NOT NULL,
    actor varchar(255) NOT NULL,
    recorded_at timestamptz NOT NULL,
    payload_json jsonb NOT NULL,  -- [JSON matn]
    payload_identity varchar(64) NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (aggregate_revision_id) REFERENCES fleet_aggregate_passport_revision(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (installation_id) REFERENCES part_installation(id),
    FOREIGN KEY (part_id) REFERENCES vehicle_part(id),
    FOREIGN KEY (repair_id) REFERENCES vehicle_repair(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id),
    CHECK ((btrim((basis)) <> '')),
    CHECK (((claimed_amount is null) = (currency is null))),
    CHECK ((btrim((claim_document)) <> '')),
    CHECK ((claimed_amount >= (0))),
    CHECK ((btrim((contract_reference)) <> '')),
    CHECK (((currency is null) or ((currency) ~ '^[a-z]{3}$'))),
    CHECK ((btrim((description)) <> '')),
    CHECK ((btrim((supplier_reference)) <> ''))
);

-- TABLE: fleet_warranty_event  (satrlar: 0 — BO`SH)
CREATE TABLE fleet_warranty_event (
    id uuid NOT NULL,
    claim_id uuid NOT NULL,
    previous_event_id uuid,
    revision bigint NOT NULL,
    action varchar(32) NOT NULL,  -- RUXSAT: 'SUBMIT', 'ACCEPT_CLAIM', 'REJECT_CLAIM', 'REGISTER_RECEIPT', 'ACCEPT_RECEIPT', 'CANCEL_RECEIPT'
    receipt_event_id uuid,
    occurred_at timestamptz NOT NULL,
    actual_amount numeric(24,6),
    currency varchar(3),
    issuer_reference varchar(255) NOT NULL,
    document_reference varchar(255) NOT NULL,
    line_reference varchar(128) NOT NULL,
    source_hash varchar(64),
    basis varchar(2000) NOT NULL,
    actor_id uuid NOT NULL,
    actor varchar(255) NOT NULL,
    recorded_at timestamptz NOT NULL,
    payload_json jsonb NOT NULL,  -- [JSON matn]
    payload_identity varchar(64) NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (claim_id) REFERENCES fleet_warranty_claim(id),
    FOREIGN KEY (previous_event_id) REFERENCES fleet_warranty_event(id),
    FOREIGN KEY (receipt_event_id) REFERENCES fleet_warranty_event(id),
    CHECK (action in ('SUBMIT', 'ACCEPT_CLAIM', 'REJECT_CLAIM', 'REGISTER_RECEIPT', 'ACCEPT_RECEIPT', 'CANCEL_RECEIPT')),
    CHECK ((actual_amount > (0))),
    CHECK ((btrim((basis)) <> '')),
    CHECK (action in ('REGISTER_RECEIPT', 'ACCEPT_RECEIPT', 'CANCEL_RECEIPT')),
    CHECK (action in ('ACCEPT_RECEIPT', 'CANCEL_RECEIPT')),
    CHECK (((currency is null) or ((currency) ~ '^[a-z]{3}$'))),
    CHECK ((btrim((document_reference)) <> '')),
    CHECK ((btrim((issuer_reference)) <> '')),
    CHECK ((btrim((line_reference)) <> '')),
    CHECK ((revision > 0))
);

-- TABLE: fuel_authorization  (satrlar: 0 — BO`SH)
-- ---------------------------------------------------------------------
-- Yoqilg'i quyishga berilgan ruxsatnoma: so'ralgan (requested_liters), tasdiqlangan
-- (approved_liters) va amalda quyilgan (dispensed_liters) litr.
-- status: APPROVED, REJECTED, COMPLETED, CANCELLED. rejection_reason — rad etish
-- sababi. credential_id — haydovchi qaysi karta/QR bilan tanilgani.
-- RUXSAT BERILGAN LEKIN QUYILMAGAN yoki ORTIQCHA QUYILGAN holatlar
-- approved_liters va dispensed_liters ni solishtirib topiladi.
-- ---------------------------------------------------------------------
CREATE TABLE fuel_authorization (
    id uuid NOT NULL,
    actor_id varchar(128),
    amount numeric(18,2),
    approved_liters numeric(14,3),
    cancelled_at timestamptz,
    completed_at timestamptz,
    created_at timestamptz NOT NULL,
    credential_id uuid,  -- [MAXFIY — o'qish taqiqlangan]
    currency varchar(8),
    dispensed_liters numeric(14,3),
    driver_id uuid,
    fuel_record_id uuid,
    fuel_type varchar(32) NOT NULL,
    rejection_reason varchar(256),
    requested_liters numeric(14,3),
    status varchar(16) NOT NULL,  -- RUXSAT: 'APPROVED', 'REJECTED', 'COMPLETED', 'CANCELLED'
    vehicle_id uuid NOT NULL,
    warehouse_id uuid,
    PRIMARY KEY (id),
    CHECK (status in ('APPROVED', 'REJECTED', 'COMPLETED', 'CANCELLED'))
);

-- TABLE: fuel_card_current_financial_revision  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
CREATE TABLE fuel_card_current_financial_revision (
    operation_id uuid,
    row_id uuid,
    previous_row_id uuid,
    hardware_operation_id uuid,
    physical_fact_id uuid,
    fuel_record_id uuid,
    provider text,
    organization text,
    transaction_id text,
    revision bigint,
    actor_id uuid,
    branch_id uuid,
    original jsonb,  -- [JSON matn]
    sources jsonb,  -- [JSON matn]
    source_hash text,
    document jsonb,  -- [JSON matn]
    financial_amount numeric,
    currency text,
    physical_quantity numeric,
    unit text,
    state text,
    recorded_at timestamptz
);

-- TABLE: fuel_card_financial_correction  (satrlar: 0 — BO`SH)
CREATE TABLE fuel_card_financial_correction (
    operation_id uuid NOT NULL,
    row_id uuid NOT NULL,
    previous_row_id uuid NOT NULL,
    hardware_operation_id uuid NOT NULL,
    physical_fact_id uuid NOT NULL,
    fuel_record_id uuid,
    provider text NOT NULL,
    organization text NOT NULL,
    transaction_id text NOT NULL,
    revision bigint NOT NULL,
    actor_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    source_hash text NOT NULL,
    document jsonb NOT NULL,  -- [JSON matn]
    financial_amount numeric NOT NULL,
    currency text NOT NULL,
    physical_quantity numeric NOT NULL,
    unit text NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'CORRECTED_FINANCIAL', 'CANCELLED_FINANCIAL'
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (fuel_record_id) REFERENCES fuel_record(id),
    FOREIGN KEY (hardware_operation_id) REFERENCES fuel_hardware_operation(id),
    FOREIGN KEY (physical_fact_id) REFERENCES fuel_hardware_fact(id),
    FOREIGN KEY (previous_row_id) REFERENCES fuel_hardware_card_row(id),
    FOREIGN KEY (row_id) REFERENCES fuel_hardware_card_row(id),
    CHECK ((financial_amount >= (0))),
    CHECK ((physical_quantity > (0))),
    CHECK ((revision > 0)),
    CHECK ((source_hash ~ '^[a-f0-9]{64}$')),
    CHECK (state in ('CORRECTED_FINANCIAL', 'CANCELLED_FINANCIAL'))
);

-- TABLE: fuel_card_transaction  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Yoqilg'i kartasi tranzaksiyalari (tashqi provayderdan import qilinadi): litr,
-- summa, shoxobcha nomi, karta raqami, tashqi tranzaksiya id.
-- CHEK BO'YICHA QUYILGAN YOQILG'I SHU JADVALDA. Sensor ko'rsatkichi bilan
-- solishtirish uchun fuel_sensor_reading ishlatiladi.
-- ---------------------------------------------------------------------
CREATE TABLE fuel_card_transaction (
    id uuid NOT NULL,
    amount numeric(14,2) NOT NULL,
    card_number varchar(255) NOT NULL,
    currency varchar(8) NOT NULL,
    driver_id uuid,
    external_transaction_id varchar(255) NOT NULL,
    fuel_type varchar(32) NOT NULL,
    imported_at timestamptz NOT NULL,
    liters numeric(12,3) NOT NULL,
    merchant_name varchar(255) NOT NULL,
    raw_payload varchar(4000),
    transacted_at timestamptz NOT NULL,
    trip_id uuid,
    vehicle_id uuid NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: fuel_consumption_interval  (satrlar: noma'lum)
CREATE TABLE fuel_consumption_interval (
    operation_id uuid NOT NULL,
    interval_id uuid NOT NULL,
    account_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    review_document jsonb,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id)
);

-- TABLE: fuel_consumption_interval_closed  (satrlar: noma'lum)
CREATE TABLE fuel_consumption_interval_closed (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_consumption_issue_attribution  (satrlar: noma'lum)
CREATE TABLE fuel_consumption_issue_attribution (
    operation_id uuid NOT NULL,
    interval_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    review_document jsonb,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_consumption_issue_attribution_closed  (satrlar: noma'lum)
CREATE TABLE fuel_consumption_issue_attribution_closed (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_consumption_observation  (satrlar: noma'lum)
CREATE TABLE fuel_consumption_observation (
    operation_id uuid NOT NULL,
    observation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    review_document jsonb,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id)
);

-- TABLE: fuel_consumption_observation_closed  (satrlar: noma'lum)
CREATE TABLE fuel_consumption_observation_closed (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_consumption_policy  (satrlar: noma'lum)
CREATE TABLE fuel_consumption_policy (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_consumption_policy_closed  (satrlar: noma'lum)
CREATE TABLE fuel_consumption_policy_closed (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_forecast_closed  (satrlar: noma'lum)
CREATE TABLE fuel_forecast_closed (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id)
);

-- TABLE: fuel_forecast_erp_demand  (satrlar: noma'lum)
CREATE TABLE fuel_forecast_erp_demand (
    operation_id uuid NOT NULL,
    forecast_id uuid NOT NULL,
    account_id uuid NOT NULL,
    forecast_revision bigint NOT NULL,
    actor_id uuid NOT NULL,
    state text NOT NULL,
    payload jsonb NOT NULL,  -- [JSON matn]
    payload_hash text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id)
);

-- TABLE: fuel_forecast_erp_exchange  (satrlar: noma'lum)
CREATE TABLE fuel_forecast_erp_exchange (
    operation_id uuid NOT NULL,
    demand_id uuid NOT NULL,
    account_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    provider_id text NOT NULL,
    provider_revision bigint NOT NULL,
    exchange_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (demand_id) REFERENCES fuel_forecast_erp_demand(operation_id)
);

-- TABLE: fuel_forecast_erp_exchange_closed  (satrlar: noma'lum)
CREATE TABLE fuel_forecast_erp_exchange_closed (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id)
);

-- TABLE: fuel_forecast_revision  (satrlar: noma'lum)
CREATE TABLE fuel_forecast_revision (
    operation_id uuid NOT NULL,
    forecast_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    calculation jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    review_document jsonb,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id)
);

-- TABLE: fuel_hardware_aggregate  (satrlar: noma'lum)
CREATE TABLE fuel_hardware_aggregate (
    id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    observed_at timestamptz NOT NULL,
    payload jsonb NOT NULL,  -- [JSON matn]
    identity text NOT NULL,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: fuel_hardware_asset  (satrlar: noma'lum)
CREATE TABLE fuel_hardware_asset (
    id uuid NOT NULL,
    branch_id uuid NOT NULL,
    account_id uuid,
    kind text NOT NULL,  -- RUXSAT: 'TANK', 'DISPENSER', 'METER', 'DUT'; BAZADA: 'TANK' 3; ISHLATILMAGAN: DISPENSER, METER, DUT
    serial_number text NOT NULL,
    tank_id uuid,
    payload jsonb NOT NULL,  -- [JSON matn]
    active boolean NOT NULL,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (tank_id) REFERENCES fuel_hardware_asset(id),
    CHECK (kind in ('TANK', 'DISPENSER', 'METER', 'DUT'))
);

-- TABLE: fuel_hardware_attempt  (satrlar: noma'lum)
CREATE TABLE fuel_hardware_attempt (
    id uuid NOT NULL,
    operation_id uuid NOT NULL,
    kind text NOT NULL,
    state text NOT NULL,
    request jsonb NOT NULL,  -- [JSON matn]
    response jsonb,  -- [JSON matn]
    error text,
    created_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    finished_at timestamptz,
    PRIMARY KEY (id),
    FOREIGN KEY (operation_id) REFERENCES fuel_hardware_operation(id)
);

-- TABLE: fuel_hardware_binding  (satrlar: noma'lum)
CREATE TABLE fuel_hardware_binding (
    id uuid NOT NULL,
    sensor_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_to timestamptz,
    payload jsonb NOT NULL,  -- [JSON matn]
    created_by uuid NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (sensor_id) REFERENCES fuel_hardware_asset(id),
    CHECK (((valid_to is null) or (valid_to > valid_from)))
);

-- TABLE: fuel_hardware_calibration  (satrlar: noma'lum)
CREATE TABLE fuel_hardware_calibration (
    id uuid NOT NULL,
    asset_id uuid NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_to timestamptz,
    verified_until timestamptz NOT NULL,
    payload jsonb NOT NULL,  -- [JSON matn]
    created_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (asset_id) REFERENCES fuel_hardware_asset(id),
    CHECK (((valid_to is null) or (valid_to > valid_from)))
);

-- TABLE: fuel_hardware_candidate  (satrlar: noma'lum)
CREATE TABLE fuel_hardware_candidate (
    id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    event_key text NOT NULL,
    from_at timestamptz NOT NULL,
    to_at timestamptz NOT NULL,
    payload jsonb NOT NULL,  -- [JSON matn]
    state text NOT NULL,
    created_at timestamptz NOT NULL,
    version bigint NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: fuel_hardware_candidate_decision  (satrlar: noma'lum)
CREATE TABLE fuel_hardware_candidate_decision (
    id uuid NOT NULL,
    candidate_id uuid NOT NULL,
    payload jsonb NOT NULL,  -- [JSON matn]
    identity text NOT NULL,
    created_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (candidate_id) REFERENCES fuel_hardware_candidate(id)
);

-- TABLE: fuel_hardware_card_cursor  (satrlar: noma'lum)
CREATE TABLE fuel_hardware_card_cursor (
    provider text NOT NULL,
    organization text NOT NULL,
    cursor text,
    batch_id uuid NOT NULL,
    receipt_reference text NOT NULL,
    PRIMARY KEY (provider, organization)
);

-- TABLE: fuel_hardware_card_decision  (satrlar: noma'lum)
CREATE TABLE fuel_hardware_card_decision (
    id uuid NOT NULL,
    row_id uuid NOT NULL,
    payload jsonb NOT NULL,  -- [JSON matn]
    identity text NOT NULL,
    created_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (row_id) REFERENCES fuel_hardware_card_row(id)
);

-- TABLE: fuel_hardware_card_row  (satrlar: noma'lum)
CREATE TABLE fuel_hardware_card_row (
    id uuid NOT NULL,
    batch_id uuid NOT NULL,
    provider text,
    organization text,
    transaction_id text,
    revision text,
    payload jsonb NOT NULL,  -- [JSON matn]
    identity text NOT NULL,
    state text NOT NULL,
    reason text,
    fact_id uuid,
    fuel_record_id uuid,
    previous_row_id uuid,
    received_at timestamptz NOT NULL,
    version bigint NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (previous_row_id) REFERENCES fuel_hardware_card_row(id)
);

-- TABLE: fuel_hardware_detector_policy  (satrlar: noma'lum)
CREATE TABLE fuel_hardware_detector_policy (
    id uuid NOT NULL,
    branch_id uuid NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_to timestamptz,
    payload jsonb NOT NULL,  -- [JSON matn]
    created_by uuid NOT NULL,
    PRIMARY KEY (id),
    CHECK (((valid_to is null) or (valid_to > valid_from)))
);

-- TABLE: fuel_hardware_fact  (satrlar: noma'lum)
CREATE TABLE fuel_hardware_fact (
    id uuid NOT NULL,
    branch_id uuid NOT NULL,
    operation_id uuid,
    provider text NOT NULL,
    organization text NOT NULL,
    original_id text NOT NULL,
    vehicle_id uuid NOT NULL,
    driver_id uuid NOT NULL,
    waybill_id uuid NOT NULL,
    fuel_type text NOT NULL,
    unit text NOT NULL,
    quantity numeric NOT NULL,
    amount numeric NOT NULL,
    quantity_delta numeric,
    amount_delta numeric,
    currency text NOT NULL,
    occurred_at timestamptz NOT NULL,
    kind text NOT NULL,
    related_fact_id uuid,
    fuel_record_id uuid,
    stock_issue_event_id uuid,
    payload jsonb NOT NULL,  -- [JSON matn]
    created_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (related_fact_id) REFERENCES fuel_hardware_fact(id),
    CHECK ((amount >= (0))),
    CHECK ((quantity >= (0)))
);

-- TABLE: fuel_hardware_interval_close  (satrlar: noma'lum)
CREATE TABLE fuel_hardware_interval_close (
    id uuid NOT NULL,
    table_kind text NOT NULL,
    target_id uuid NOT NULL,
    valid_to timestamptz NOT NULL,
    payload jsonb NOT NULL,  -- [JSON matn]
    identity text NOT NULL,
    created_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: fuel_hardware_limit  (satrlar: noma'lum)
CREATE TABLE fuel_hardware_limit (
    id uuid NOT NULL,
    branch_id uuid NOT NULL,
    subject_type text NOT NULL,  -- RUXSAT: 'DRIVER', 'VEHICLE'
    subject_id uuid NOT NULL,
    fuel_type text NOT NULL,
    unit text NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_to timestamptz,
    payload jsonb NOT NULL,  -- [JSON matn]
    created_by uuid NOT NULL,
    PRIMARY KEY (id),
    CHECK (((valid_to is null) or (valid_to > valid_from))),
    CHECK (subject_type in ('DRIVER', 'VEHICLE'))
);

-- TABLE: fuel_hardware_measurement  (satrlar: noma'lum)
CREATE TABLE fuel_hardware_measurement (
    id uuid NOT NULL,
    asset_id uuid NOT NULL,
    provider text NOT NULL,
    organization text NOT NULL,
    original_id text NOT NULL,
    observed_at timestamptz NOT NULL,
    received_at timestamptz NOT NULL,
    payload jsonb NOT NULL,  -- [JSON matn]
    identity text NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (asset_id) REFERENCES fuel_hardware_asset(id)
);

-- TABLE: fuel_hardware_operation  (satrlar: noma'lum)
CREATE TABLE fuel_hardware_operation (
    id uuid NOT NULL,
    branch_id uuid NOT NULL,
    account_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    driver_id uuid NOT NULL,
    waybill_id uuid NOT NULL,
    provider text NOT NULL,
    organization text NOT NULL,
    original_command_id text NOT NULL,
    state text NOT NULL,
    payload jsonb NOT NULL,  -- [JSON matn]
    physical_gate jsonb NOT NULL,  -- [JSON matn]
    identity text NOT NULL,
    reservation_event_id uuid,
    stock_issue_event_id uuid,
    fact_id uuid,
    result jsonb,  -- [JSON matn]
    result_identity text,
    discrepancy text,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    version bigint NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: fuel_hardware_outbox  (satrlar: noma'lum)
CREATE TABLE fuel_hardware_outbox (
    id uuid NOT NULL,
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    owner text NOT NULL,
    payload jsonb NOT NULL,  -- [JSON matn]
    state text NOT NULL,
    receipt jsonb,  -- [JSON matn]
    created_at timestamptz NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: fuel_hardware_owner_balance  (satrlar: noma'lum)
CREATE TABLE fuel_hardware_owner_balance (
    account_id uuid NOT NULL,
    unit text NOT NULL,
    quantity numeric NOT NULL,
    as_of timestamptz NOT NULL,
    receipt_id uuid NOT NULL,
    PRIMARY KEY (account_id),
    FOREIGN KEY (receipt_id) REFERENCES fuel_hardware_owner_receipt(id),
    CHECK ((quantity >= (0)))
);

-- TABLE: fuel_hardware_owner_receipt  (satrlar: noma'lum)
CREATE TABLE fuel_hardware_owner_receipt (
    id uuid NOT NULL,
    provider text NOT NULL,
    organization text NOT NULL,
    original_id text NOT NULL,
    account_id uuid NOT NULL,
    operation_id uuid,
    payload jsonb NOT NULL,  -- [JSON matn]
    identity text NOT NULL,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: fuel_hardware_provider  (satrlar: noma'lum)
CREATE TABLE fuel_hardware_provider (
    provider text NOT NULL,
    organization text NOT NULL,
    branch_id uuid NOT NULL,
    payload jsonb NOT NULL,  -- [JSON matn]
    enabled boolean NOT NULL,
    last_received_at timestamptz,
    last_business_receipt_at timestamptz,
    PRIMARY KEY (provider, organization)
);

-- TABLE: fuel_hardware_receipt_decision  (satrlar: noma'lum)
CREATE TABLE fuel_hardware_receipt_decision (
    id uuid NOT NULL,
    source_document_id uuid NOT NULL,
    tank_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    payload jsonb NOT NULL,  -- [JSON matn]
    identity text NOT NULL,
    created_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: fuel_hardware_recovery  (satrlar: noma'lum)
CREATE TABLE fuel_hardware_recovery (
    id uuid NOT NULL,
    kind text NOT NULL,  -- RUXSAT: 'AUTHORIZE', 'CARD_BATCH', 'CARD_MAP', 'DUT_RECONCILE'
    branch_id uuid NOT NULL,
    target_id uuid,
    actor_id uuid NOT NULL,
    original jsonb,  -- [JSON matn]
    original_hash text NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'REGISTERED', 'RECORDED', 'NOT_EXECUTED'; BAZADA: 'NOT_EXECUTED' 2; ISHLATILMAGAN: REGISTERED, RECORDED
    result jsonb,  -- [JSON matn]
    reason text,
    registered_at timestamptz NOT NULL,
    finished_at timestamptz,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    CHECK (kind in ('AUTHORIZE', 'CARD_BATCH', 'CARD_MAP', 'DUT_RECONCILE')),
    CHECK ((original_hash ~ '^[a-f0-9]{64}$')),
    CHECK (state in ('REGISTERED', 'RECORDED', 'NOT_EXECUTED'))
);

-- TABLE: fuel_hardware_recovery_effect  (satrlar: noma'lum)
CREATE TABLE fuel_hardware_recovery_effect (
    recovery_id uuid NOT NULL,
    row_index integer NOT NULL,
    row_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (recovery_id, row_index),
    FOREIGN KEY (recovery_id) REFERENCES fuel_hardware_recovery(id),
    FOREIGN KEY (row_id) REFERENCES fuel_hardware_card_row(id),
    CHECK ((row_index >= 0))
);

-- TABLE: fuel_inventory_document  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Yoqilg'i ombori hujjatlari: kirim, chiqim, inventarizatsiya.
-- book_balance_liters (kitob bo'yicha qoldiq), actual_balance_liters (amaldagi
-- qoldiq) va delta_liters (tafovut) — INVENTARIZATSIYA TAFOVUTI SHU JADVALDAN
-- OLINADI. status: DRAFT, CONFIRMED, CANCELLED.
-- ---------------------------------------------------------------------
CREATE TABLE fuel_inventory_document (
    id uuid NOT NULL,
    actual_balance_liters numeric(12,3),
    amount numeric(14,2),
    book_balance_liters numeric(12,3),
    counterparty_name varchar(255),
    created_at timestamptz NOT NULL,
    created_by varchar(255) NOT NULL,
    currency varchar(8) NOT NULL,
    delta_liters numeric(12,3),
    document_number varchar(64) NOT NULL,
    document_type varchar(32) NOT NULL,
    fuel_type varchar(32) NOT NULL,
    liters numeric(24,6),
    notes varchar(1024),
    occurred_at timestamptz NOT NULL,
    reason varchar(512),
    status varchar(16) NOT NULL,  -- RUXSAT: 'DRAFT', 'CONFIRMED', 'CANCELLED'; BAZADA: 'CONFIRMED' 9, 'DRAFT' 1, 'CANCELLED' 1
    updated_at timestamptz NOT NULL,
    confirmed_at timestamptz,
    confirmed_by varchar(128),
    warehouse_id uuid,
    warehouse_name varchar(256),
    canonical_source_identity varchar(64),
    counterparty_warehouse_id uuid,
    evidence_reference varchar(512),
    related_operation_id uuid,
    waybill_id uuid,
    physical_quantity numeric(24,6),
    physical_unit varchar(8),
    PRIMARY KEY (id),
    CHECK (status in ('DRAFT', 'CONFIRMED', 'CANCELLED')),
    CHECK ( case when (physical_unit is null) then ((physical_quantity is null) and (liters is not null)) when ((physical_unit) = 'kg') then ((physical_quantity is not null) and (liters is null) and (physical_quantity > (0)) and (physical_quantity < ('1000000000000000000')) and ((physical_quantity) <> all (array['nan', 'infinity', '-infinity'])) and ((document_type) = any ((array['quality_release', 'reservation', 'issue', 'release'])[]))) else false end)
);

-- TABLE: fuel_limit  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Yoqilg'i limitlari: haydovchi yoki mashina uchun kunlik/oylik maksimal litr va
-- summa. subject_type — DRIVER yoki VEHICLE, window_type — DAY yoki MONTH.
-- Bitta subyekt + yoqilg'i turi + davr uchun bitta faol limit bo'ladi.
-- LIMIT OSHGANI notification jadvalida FUEL_LIMIT_EXCEEDED sifatida qayd etiladi.
-- ---------------------------------------------------------------------
CREATE TABLE fuel_limit (
    id uuid NOT NULL,
    active boolean NOT NULL,
    created_at timestamptz NOT NULL,
    currency varchar(8),
    fuel_type varchar(32),
    max_amount numeric(18,2),
    max_liters numeric(14,3),
    note varchar(256),
    subject_id uuid NOT NULL,
    subject_type varchar(16) NOT NULL,  -- RUXSAT: 'DRIVER', 'VEHICLE'
    updated_at timestamptz NOT NULL,
    window_type varchar(16) NOT NULL,  -- RUXSAT: 'DAY', 'MONTH'
    PRIMARY KEY (id),
    CHECK (subject_type in ('DRIVER', 'VEHICLE')),
    CHECK (window_type in ('DAY', 'MONTH'))
);

-- TABLE: fuel_lot_allocation  (satrlar: noma'lum)
CREATE TABLE fuel_lot_allocation (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    event_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (event_id) REFERENCES fuel_stock_event(id)
);

-- TABLE: fuel_lot_allocation_closed  (satrlar: noma'lum)
CREATE TABLE fuel_lot_allocation_closed (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_lot_allocation_effective  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
CREATE TABLE fuel_lot_allocation_effective (
    operation_id uuid,
    account_id uuid,
    event_id uuid,
    branch_id uuid,
    actor_id uuid,
    original jsonb,  -- [JSON matn]
    sources jsonb,  -- [JSON matn]
    document jsonb,  -- [JSON matn]
    hash text,
    recorded_at timestamptz
);

-- TABLE: fuel_lot_composition  (satrlar: noma'lum)
CREATE TABLE fuel_lot_composition (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    event_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (event_id) REFERENCES fuel_stock_event(id)
);

-- TABLE: fuel_lot_composition_closed  (satrlar: noma'lum)
CREATE TABLE fuel_lot_composition_closed (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_lot_composition_effective  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
CREATE TABLE fuel_lot_composition_effective (
    operation_id uuid,
    account_id uuid,
    event_id uuid,
    branch_id uuid,
    actor_id uuid,
    original jsonb,  -- [JSON matn]
    sources jsonb,  -- [JSON matn]
    document jsonb,  -- [JSON matn]
    hash text,
    recorded_at timestamptz
);

-- TABLE: fuel_lot_correction  (satrlar: noma'lum)
CREATE TABLE fuel_lot_correction (
    operation_id uuid NOT NULL,
    ordinal bigint NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_lot_correction_closed  (satrlar: noma'lum)
CREATE TABLE fuel_lot_correction_closed (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_lot_correction_entry  (satrlar: noma'lum)
CREATE TABLE fuel_lot_correction_entry (
    operation_id uuid NOT NULL,
    journal_operation_id uuid NOT NULL,
    kind text NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    event_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (event_id) REFERENCES fuel_stock_event(id),
    FOREIGN KEY (journal_operation_id) REFERENCES fuel_lot_correction(operation_id)
);

-- TABLE: fuel_lot_correction_impact  (satrlar: noma'lum)
CREATE TABLE fuel_lot_correction_impact (
    journal_operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    lot_id uuid NOT NULL,
    bucket text NOT NULL,
    PRIMARY KEY (journal_operation_id, account_id, lot_id, bucket),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (journal_operation_id) REFERENCES fuel_lot_correction(operation_id)
);

-- TABLE: fuel_lot_distribution_part  (satrlar: noma'lum)
CREATE TABLE fuel_lot_distribution_part (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    event_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (event_id) REFERENCES fuel_stock_event(id)
);

-- TABLE: fuel_lot_distribution_part_closed  (satrlar: noma'lum)
CREATE TABLE fuel_lot_distribution_part_closed (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_mixing  (satrlar: noma'lum)
CREATE TABLE fuel_mixing (
    operation_id uuid NOT NULL,
    mixing_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    compatibility_document jsonb NOT NULL,  -- [JSON matn]
    physical_document jsonb,  -- [JSON matn]
    review_document jsonb,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_mixing_closed  (satrlar: noma'lum)
CREATE TABLE fuel_mixing_closed (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_monthly_closed  (satrlar: noma'lum)
CREATE TABLE fuel_monthly_closed (
    operation_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id)
);

-- TABLE: fuel_monthly_revision  (satrlar: 0 — BO`SH)
CREATE TABLE fuel_monthly_revision (
    operation_id uuid NOT NULL,
    report_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    month date NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'DRAFT', 'APPROVED', 'REVOKED', 'DISMISSED'
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    calculation jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    review_document jsonb,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    CHECK ((revision > 0)),
    CHECK (state in ('DRAFT', 'APPROVED', 'REVOKED', 'DISMISSED'))
);

-- TABLE: fuel_norm  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Mashinaning yoqilg'i sarf normasi: 100 km ga qancha litr (liters_per100km) va
-- ruxsat etilgan chetlanish foizi (tolerance_percent). effective_from/effective_to
-- — norma qaysi davrda amal qilgani.
-- NORMA HAR BIR MASHINA UCHUN ALOHIDA belgilanadi (vehicle_id).
-- ---------------------------------------------------------------------
CREATE TABLE fuel_norm (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    effective_from date NOT NULL,
    effective_to date,
    fuel_type varchar(32) NOT NULL,
    liters_per100km numeric(12,3) NOT NULL,
    tolerance_percent numeric(8,2) NOT NULL,
    updated_at timestamptz NOT NULL,
    vehicle_id uuid NOT NULL,
    liters_per_engine_hour numeric(12,3),
    updated_by varchar(128),
    PRIMARY KEY (id)
);

-- TABLE: fuel_norm_calculation_snapshot  (satrlar: noma'lum)
CREATE TABLE fuel_norm_calculation_snapshot (
    id uuid NOT NULL,
    branch_id uuid NOT NULL,
    norm_revision_id uuid,
    previous_snapshot_id uuid,
    recorded_at timestamptz NOT NULL,
    recorded_by_id uuid NOT NULL,
    revision bigint NOT NULL,
    snapshot_identity varchar(64) NOT NULL,
    snapshot_json text NOT NULL,  -- [JSON matn]
    source_closed_at timestamptz NOT NULL,
    source_version bigint NOT NULL,
    vehicle_id uuid NOT NULL,
    waybill_id uuid NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: fuel_norm_revision  (satrlar: noma'lum)
CREATE TABLE fuel_norm_revision (
    id uuid NOT NULL,
    approved_at timestamptz NOT NULL,
    approved_by_id uuid NOT NULL,
    approved_by_name varchar(256) NOT NULL,
    basis varchar(2000) NOT NULL,
    branch_id uuid NOT NULL,
    combination_key varchar(40) NOT NULL,
    document_reference varchar(255) NOT NULL,
    effective_from date NOT NULL,
    fuel_type varchar(32) NOT NULL,
    payload_identity varchar(64) NOT NULL,
    payload_json text NOT NULL,  -- [JSON matn]
    previous_revision_id uuid,
    revision bigint NOT NULL,
    spec_json text NOT NULL,  -- [JSON matn]
    trailer_id uuid,
    vehicle_id uuid NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: fuel_owner_current_receipt  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
CREATE TABLE fuel_owner_current_receipt (
    account_id uuid,
    unit text,
    quantity numeric,
    as_of timestamptz,
    receipt_id uuid,
    provider text,
    organization text,
    original_id text,
    identity text,
    received_at timestamptz
);

-- TABLE: fuel_owner_movement  (satrlar: noma'lum)
CREATE TABLE fuel_owner_movement (
    id uuid NOT NULL,
    provider text NOT NULL,
    organization text NOT NULL,
    original_key text NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    source_document_id uuid NOT NULL,
    request_json jsonb NOT NULL,  -- [JSON matn]
    command_json jsonb NOT NULL,  -- [JSON matn]
    command_hash text NOT NULL,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (source_document_id) REFERENCES fuel_inventory_document(id),
    CHECK ((command_hash ~ '^[a-f0-9]{64}$'))
);

-- TABLE: fuel_owner_movement_balance  (satrlar: noma'lum)
CREATE TABLE fuel_owner_movement_balance (
    account_id uuid NOT NULL,
    unit text NOT NULL,
    quantity numeric NOT NULL,
    as_of timestamptz NOT NULL,
    receipt_id uuid NOT NULL,
    PRIMARY KEY (account_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (receipt_id) REFERENCES fuel_owner_movement_receipt(id),
    CHECK ((quantity >= (0)))
);

-- TABLE: fuel_owner_movement_outbox  (satrlar: 0 — BO`SH)
CREATE TABLE fuel_owner_movement_outbox (
    operation_id uuid NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'PENDING', 'UNKNOWN', 'ACCEPTED', 'REJECTED', 'CANCELLED'
    attempted_at timestamptz,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (operation_id) REFERENCES fuel_owner_movement(id),
    CHECK (state in ('PENDING', 'UNKNOWN', 'ACCEPTED', 'REJECTED', 'CANCELLED'))
);

-- TABLE: fuel_owner_movement_receipt  (satrlar: 0 — BO`SH)
CREATE TABLE fuel_owner_movement_receipt (
    id uuid NOT NULL,
    operation_id uuid NOT NULL,
    provider text NOT NULL,
    organization text NOT NULL,
    original_id text NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'ACCEPTED', 'REJECTED', 'WAITING', 'UNKNOWN'
    payload jsonb NOT NULL,  -- [JSON matn]
    identity text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (operation_id) REFERENCES fuel_owner_movement(id),
    CHECK ((identity ~ '^[a-f0-9]{64}$')),
    CHECK (state in ('ACCEPTED', 'REJECTED', 'WAITING', 'UNKNOWN'))
);

-- TABLE: fuel_owner_quality_receipt  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
CREATE TABLE fuel_owner_quality_receipt (
    account_id uuid,
    unit text,
    quantity numeric,
    as_of timestamptz,
    receipt_id uuid,
    provider text,
    organization text,
    original_id text,
    identity text,
    received_at timestamptz,
    quality_proof jsonb  -- [JSON matn]
);

-- TABLE: fuel_owner_source_original  (satrlar: noma'lum)
CREATE TABLE fuel_owner_source_original (
    source_document_id uuid NOT NULL,
    account_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    identity text NOT NULL,
    PRIMARY KEY (source_document_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (source_document_id) REFERENCES fuel_inventory_document(id),
    CHECK ((identity ~ '^[a-f0-9]{64}$'))
);

-- TABLE: fuel_physical_correction  (satrlar: noma'lum)
CREATE TABLE fuel_physical_correction (
    operation_id uuid NOT NULL,
    correction_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    physical_document jsonb NOT NULL,  -- [JSON matn]
    counterparty_document jsonb,  -- [JSON matn]
    review_document jsonb,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_physical_correction_closed  (satrlar: noma'lum)
CREATE TABLE fuel_physical_correction_closed (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_primary_balance_closed  (satrlar: noma'lum)
CREATE TABLE fuel_primary_balance_closed (
    operation_id uuid NOT NULL,
    waybill_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id)
);

-- TABLE: fuel_primary_balance_revision  (satrlar: 0 — BO`SH)
CREATE TABLE fuel_primary_balance_revision (
    operation_id uuid NOT NULL,
    waybill_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'DRAFT', 'APPROVED', 'REVOKED', 'DISMISSED'
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    review_document jsonb,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (waybill_id) REFERENCES waybill(id),
    CHECK ((revision > 0)),
    CHECK (state in ('DRAFT', 'APPROVED', 'REVOKED', 'DISMISSED'))
);

-- TABLE: fuel_quality_admission  (satrlar: noma'lum)
CREATE TABLE fuel_quality_admission (
    event_id uuid NOT NULL,
    account_id uuid NOT NULL,
    evidence jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (event_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (event_id) REFERENCES fuel_stock_event(id)
);

-- TABLE: fuel_quality_batch  (satrlar: noma'lum)
CREATE TABLE fuel_quality_batch (
    operation_id uuid NOT NULL,
    batch_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    receipt_operation_id uuid NOT NULL,
    revision bigint NOT NULL,
    action text NOT NULL,
    state text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    batch jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    proofs jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_quality_batch_standard  (satrlar: noma'lum)
CREATE TABLE fuel_quality_batch_standard (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    standard_operation_id uuid NOT NULL,
    assessment jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (operation_id) REFERENCES fuel_quality_batch(operation_id),
    FOREIGN KEY (standard_operation_id) REFERENCES fuel_quality_standard(operation_id)
);

-- TABLE: fuel_quality_closed_operation  (satrlar: noma'lum)
CREATE TABLE fuel_quality_closed_operation (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    kind text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_quality_cutover  (satrlar: noma'lum)
CREATE TABLE fuel_quality_cutover (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_quality_cutover_closed  (satrlar: noma'lum)
CREATE TABLE fuel_quality_cutover_closed (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_quality_decision  (satrlar: noma'lum)
CREATE TABLE fuel_quality_decision (
    operation_id uuid NOT NULL,
    batch_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_quality_decision_closed  (satrlar: noma'lum)
CREATE TABLE fuel_quality_decision_closed (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_quality_opening_admission  (satrlar: noma'lum)
CREATE TABLE fuel_quality_opening_admission (
    opening_id uuid NOT NULL,
    account_id uuid NOT NULL,
    evidence jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (opening_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (opening_id) REFERENCES fuel_stock_opening(id)
);

-- TABLE: fuel_quality_policy  (satrlar: noma'lum)
CREATE TABLE fuel_quality_policy (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_quality_policy_closed  (satrlar: noma'lum)
CREATE TABLE fuel_quality_policy_closed (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_quality_standard  (satrlar: noma'lum)
CREATE TABLE fuel_quality_standard (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_quality_standard_closed  (satrlar: noma'lum)
CREATE TABLE fuel_quality_standard_closed (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_recall  (satrlar: noma'lum)
CREATE TABLE fuel_recall (
    operation_id uuid NOT NULL,
    recall_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    lot_id uuid NOT NULL,
    bucket text NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_recall_attention_delivery  (satrlar: noma'lum)
CREATE TABLE fuel_recall_attention_delivery (
    id uuid NOT NULL,
    event_id uuid NOT NULL,
    observation_revision bigint NOT NULL,
    policy_id uuid NOT NULL,
    target_id uuid NOT NULL,
    target_hash text NOT NULL,
    stage text NOT NULL,
    state text NOT NULL,
    notification_id uuid,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (event_id) REFERENCES fuel_recall_attention_event(id),
    FOREIGN KEY (notification_id) REFERENCES notification(id),
    FOREIGN KEY (policy_id) REFERENCES fuel_recall_attention_policy(operation_id)
);

-- TABLE: fuel_recall_attention_event  (satrlar: noma'lum)
CREATE TABLE fuel_recall_attention_event (
    id uuid NOT NULL,
    source_kind text NOT NULL,
    source_id uuid NOT NULL,
    source_revision bigint NOT NULL,
    source_hash text NOT NULL,
    account_id uuid NOT NULL,
    recall_id uuid NOT NULL,
    subject_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    kind text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id)
);

-- TABLE: fuel_recall_attention_observation  (satrlar: noma'lum)
CREATE TABLE fuel_recall_attention_observation (
    event_id uuid NOT NULL,
    revision bigint NOT NULL,
    proof jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (event_id, revision),
    FOREIGN KEY (event_id) REFERENCES fuel_recall_attention_event(id)
);

-- TABLE: fuel_recall_attention_policy  (satrlar: noma'lum)
CREATE TABLE fuel_recall_attention_policy (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    owner_epoch bigint NOT NULL,
    kind text NOT NULL,
    revision bigint NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_recall_attention_policy_closed  (satrlar: noma'lum)
CREATE TABLE fuel_recall_attention_policy_closed (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_recall_attention_scan  (satrlar: noma'lum)
CREATE TABLE fuel_recall_attention_scan (
    event_id uuid NOT NULL,
    last_scanned_at timestamptz,
    next_scan_at timestamptz NOT NULL,
    failures integer NOT NULL,
    last_error_code text,
    PRIMARY KEY (event_id),
    FOREIGN KEY (event_id) REFERENCES fuel_recall_attention_event(id),
    CHECK ((failures >= 0))
);

-- TABLE: fuel_recall_closed  (satrlar: noma'lum)
CREATE TABLE fuel_recall_closed (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_recall_completion  (satrlar: noma'lum)
CREATE TABLE fuel_recall_completion (
    operation_id uuid NOT NULL,
    recall_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    review_document jsonb,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_recall_completion_closed  (satrlar: noma'lum)
CREATE TABLE fuel_recall_completion_closed (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_recall_consumed_clearance  (satrlar: noma'lum)
CREATE TABLE fuel_recall_consumed_clearance (
    operation_id uuid NOT NULL,
    recall_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    review_document jsonb,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id)
);

-- TABLE: fuel_recall_consumed_clearance_closed  (satrlar: noma'lum)
CREATE TABLE fuel_recall_consumed_clearance_closed (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_recall_disposal  (satrlar: noma'lum)
CREATE TABLE fuel_recall_disposal (
    operation_id uuid NOT NULL,
    disposal_id uuid NOT NULL,
    recall_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    review_document jsonb,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_recall_disposal_closed  (satrlar: noma'lum)
CREATE TABLE fuel_recall_disposal_closed (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_recall_hold  (satrlar: noma'lum)
CREATE TABLE fuel_recall_hold (
    operation_id uuid NOT NULL,
    recall_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_recall_hold_closed  (satrlar: noma'lum)
CREATE TABLE fuel_recall_hold_closed (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_recall_recovery  (satrlar: noma'lum)
CREATE TABLE fuel_recall_recovery (
    operation_id uuid NOT NULL,
    recall_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_recall_recovery_closed  (satrlar: noma'lum)
CREATE TABLE fuel_recall_recovery_closed (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_recall_supplier_return  (satrlar: noma'lum)
CREATE TABLE fuel_recall_supplier_return (
    operation_id uuid NOT NULL,
    return_id uuid NOT NULL,
    recall_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    action_document jsonb,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_recall_supplier_return_closed  (satrlar: noma'lum)
CREATE TABLE fuel_recall_supplier_return_closed (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_recall_vehicle_clearance  (satrlar: noma'lum)
CREATE TABLE fuel_recall_vehicle_clearance (
    operation_id uuid NOT NULL,
    recall_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    review_document jsonb,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id)
);

-- TABLE: fuel_recall_vehicle_clearance_closed  (satrlar: noma'lum)
CREATE TABLE fuel_recall_vehicle_clearance_closed (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_record  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- YOQILG'I SARFI BO'YICHA ASOSIY JADVAL — QUYISH VA SARF YOZUVLARI SHU JADVALDAN
-- OLINADI. Litr, summa, amaldagi sarf (actual_consumption_per100km), norma
-- (norm_liters_per100km) va ulardan chetlanish foizi (deviation_percent).
-- severity — chetlanish darajasi: NONE, WARNING, CRITICAL.
-- YOQILG'I ANOMALIYASI SO'RALSA severity <> 'NONE' bo'yicha olinadi, batafsil
-- sabab esa fuel_record_risk_flag jadvalida.
-- ---------------------------------------------------------------------
CREATE TABLE fuel_record (
    id uuid NOT NULL,
    actual_consumption_per100km numeric(12,3),
    actual_distance_km numeric(12,3),
    amount numeric(14,2) NOT NULL,
    created_at timestamptz NOT NULL,
    currency varchar(8) NOT NULL,
    deviation_percent numeric(10,2),
    driver_id uuid,
    fuel_type varchar(32) NOT NULL,
    liters numeric(24,6),
    norm_liters_per100km numeric(12,3),
    occurred_at timestamptz NOT NULL,
    severity varchar(16) NOT NULL,  -- RUXSAT: 'NONE', 'WARNING', 'CRITICAL'
    source_reference varchar(255),
    source_type varchar(32) NOT NULL,
    trip_id uuid,
    updated_at timestamptz NOT NULL,
    vehicle_id uuid NOT NULL,
    actual_engine_hours numeric(12,3),
    expected_fuel_liters numeric(12,3),
    norm_liters_per_engine_hour numeric(12,3),
    physical_quantity numeric(24,6),
    physical_unit varchar(8),
    PRIMARY KEY (id),
    CHECK (severity in ('NONE', 'WARNING', 'CRITICAL')),
    CHECK ( case when (physical_unit is null) then ((physical_quantity is null) and (liters is not null)) when ((physical_unit) = 'kg') then ((physical_quantity is not null) and (liters is null) and (physical_quantity > (0)) and (physical_quantity < ('1000000000000000000')) and ((physical_quantity) <> all (array['nan', 'infinity', '-infinity'])) and ((source_type) = 'hardware')) else false end)
);

-- TABLE: fuel_refuel_import_input  (satrlar: noma'lum)
CREATE TABLE fuel_refuel_import_input (
    external_id varchar(255) NOT NULL,
    transaction_id uuid NOT NULL,
    record_id uuid,
    actor_id uuid,
    branch_id uuid,
    input_text text,
    input_hash varchar(64),
    recorded_at timestamptz NOT NULL,
    captured_at timestamptz,
    source_xid xid8 NOT NULL,
    state varchar(16) NOT NULL,
    PRIMARY KEY (external_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (record_id) REFERENCES fuel_record(id),
    FOREIGN KEY (transaction_id) REFERENCES fuel_card_transaction(id),
    CHECK (((((state) = 'pending') and (actor_id is null) and (branch_id is null) and (input_text is null) and (input_hash is null) and (captured_at is null)) or (((state) = 'captured') and (record_id is not null) and (actor_id is not null) and (branch_id is not null) and (input_text is not null) and (input_hash is not null) and (captured_at is not null)))),
    CHECK (((input_hash) ~ '^[0-9a-f]{64}$'))
);

-- TABLE: fuel_sensor  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Yoqilg'i sathi sensorlarining reyestri: ishlab chiqaruvchi, model, seriya raqami,
-- sensor kodi, bak hajmi. Mashinaga o'rnatilishi
-- vehicle_fuel_sensor_installation jadvali orqali.
-- ---------------------------------------------------------------------
CREATE TABLE fuel_sensor (
    id uuid NOT NULL,
    active boolean NOT NULL,
    created_at timestamptz NOT NULL,
    created_by varchar(256) NOT NULL,
    manufacturer varchar(128) NOT NULL,
    model varchar(128) NOT NULL,
    notes varchar(512),
    sensor_code varchar(64) NOT NULL,
    serial_number varchar(128),
    tank_capacity_liters numeric(12,3),
    updated_at timestamptz NOT NULL,
    updated_by varchar(256) NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: fuel_sensor_reading  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Sensor ko'rsatkichlari: bakdagi yoqilg'i litr va foizda, koordinata,
-- harorat, kuchlanish, o'lchov vaqti (recorded_at).
-- CHEK VA SENSOR TAFOVUTINI TOPISH UCHUN fuel_card_transaction BILAN vaqt va
-- mashina bo'yicha solishtiriladi (yoqilg'i o'g'irligini aniqlash).
-- ---------------------------------------------------------------------
CREATE TABLE fuel_sensor_reading (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    device_id varchar(128) NOT NULL,
    fuel_level_liters numeric(12,3) NOT NULL,
    fuel_level_percent numeric(8,3),
    latitude numeric(10,7),
    longitude numeric(10,7),
    raw_value numeric(16,6),
    recorded_at timestamptz NOT NULL,
    sensor_id uuid NOT NULL,
    telematics_event_id uuid,
    temperature_c numeric(8,3),
    vehicle_id uuid NOT NULL,
    voltage numeric(8,3),
    PRIMARY KEY (id)
);

-- TABLE: fuel_stock_account  (satrlar: noma'lum)
CREATE TABLE fuel_stock_account (
    id uuid NOT NULL,
    basis varchar(2000) NOT NULL,
    branch_id uuid NOT NULL,
    configured_at timestamptz NOT NULL,
    configured_by_id uuid NOT NULL,
    document_reference varchar(255) NOT NULL,
    fuel_type varchar(32) NOT NULL,
    owner varchar(20) NOT NULL,  -- RUXSAT: 'UNCONFIGURED', 'ATIL', 'ERP_WMS'
    owner_epoch bigint NOT NULL,
    payload_identity varchar(64) NOT NULL,
    payload_json text NOT NULL,  -- [JSON matn]
    unit varchar(8) NOT NULL,  -- RUXSAT: 'L', 'M3', 'KG', 'KWH'
    warehouse_id uuid NOT NULL,
    PRIMARY KEY (id),
    CHECK (owner in ('UNCONFIGURED', 'ATIL', 'ERP_WMS')),
    CHECK (unit in ('L', 'M3', 'KG', 'KWH'))
);

-- TABLE: fuel_stock_command_cancel  (satrlar: noma'lum)
CREATE TABLE fuel_stock_command_cancel (
    id uuid NOT NULL,
    account_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    payload_json text NOT NULL,  -- [JSON matn]
    payload_identity varchar(64) NOT NULL,
    cancelled_at timestamptz NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: fuel_stock_event  (satrlar: noma'lum)
CREATE TABLE fuel_stock_event (
    id uuid NOT NULL,
    accepted_by_id uuid NOT NULL,
    account_id uuid NOT NULL,
    bucket varchar(16) NOT NULL,  -- RUXSAT: 'USABLE', 'QUARANTINE'; BAZADA: 'USABLE' 2, 'QUARANTINE' 2
    counterpart_warehouse_id uuid,
    document_reference varchar(255) NOT NULL,
    driver_id uuid,
    effective_at timestamptz NOT NULL,
    expected_version bigint NOT NULL,
    held_delta numeric NOT NULL,
    kind varchar(32) NOT NULL,
    owner_epoch bigint NOT NULL,
    payload_identity varchar(64) NOT NULL,
    payload_json text NOT NULL,  -- [JSON matn]
    quantity numeric NOT NULL,
    quarantine_delta numeric NOT NULL,
    recorded_at timestamptz NOT NULL,
    related_operation_id uuid,
    sequence_number bigint NOT NULL,
    source_document_id uuid NOT NULL,
    source_hash varchar(64) NOT NULL,
    source_json text NOT NULL,  -- [JSON matn]
    unit varchar(8) NOT NULL,  -- RUXSAT: 'L', 'M3', 'KG', 'KWH'
    usable_delta numeric NOT NULL,
    vehicle_id uuid,
    waybill_id uuid,
    PRIMARY KEY (id),
    CHECK (bucket in ('USABLE', 'QUARANTINE')),
    CHECK (unit in ('L', 'M3', 'KG', 'KWH'))
);

-- TABLE: fuel_stock_opening  (satrlar: noma'lum)
CREATE TABLE fuel_stock_opening (
    id uuid NOT NULL,
    account_id uuid NOT NULL,
    basis varchar(2000) NOT NULL,
    document_reference varchar(255) NOT NULL,
    evidence_json text NOT NULL,  -- [JSON matn]
    inventory_observed_at timestamptz NOT NULL,
    opened_at timestamptz NOT NULL,
    opened_by_id uuid NOT NULL,
    owner_epoch bigint NOT NULL,
    payload_identity varchar(64) NOT NULL,
    payload_json text NOT NULL,  -- [JSON matn]
    preview_hash varchar(64) NOT NULL,
    quarantine_quantity numeric NOT NULL,
    sequence_number bigint NOT NULL,
    unit varchar(8) NOT NULL,  -- RUXSAT: 'L', 'M3', 'KG', 'KWH'
    usable_quantity numeric NOT NULL,
    PRIMARY KEY (id),
    CHECK (unit in ('L', 'M3', 'KG', 'KWH'))
);

-- TABLE: fuel_stock_projection  (satrlar: noma'lum)
CREATE TABLE fuel_stock_projection (
    account_id uuid NOT NULL,
    held_quantity numeric NOT NULL,
    opening_id uuid NOT NULL,
    owner_epoch bigint NOT NULL,
    quarantine_quantity numeric NOT NULL,
    unit varchar(8) NOT NULL,  -- RUXSAT: 'L', 'M3', 'KG', 'KWH'
    usable_quantity numeric NOT NULL,
    version bigint NOT NULL,
    PRIMARY KEY (account_id),
    CHECK (unit in ('L', 'M3', 'KG', 'KWH'))
);

-- TABLE: fuel_stock_source_cancel  (satrlar: noma'lum)
CREATE TABLE fuel_stock_source_cancel (
    id uuid NOT NULL,
    account_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    payload_json text NOT NULL,  -- [JSON matn]
    payload_identity varchar(64) NOT NULL,
    cancelled_at timestamptz NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: fuel_stock_transaction  (satrlar: noma'lum)
CREATE TABLE fuel_stock_transaction (
    id uuid NOT NULL,
    actor varchar(128),
    balance_after_liters numeric(14,3) NOT NULL,
    balance_before_liters numeric(14,3) NOT NULL,
    created_at timestamptz NOT NULL,
    fuel_type varchar(32) NOT NULL,
    notes varchar(512),
    quantity_liters numeric(14,3) NOT NULL,
    reference_id uuid,
    reference_number varchar(64),
    reference_type varchar(32),
    transaction_type varchar(32) NOT NULL,
    warehouse_id uuid NOT NULL,
    warehouse_name varchar(256),
    PRIMARY KEY (id)
);

-- TABLE: fuel_storage_weather  (satrlar: noma'lum)
CREATE TABLE fuel_storage_weather (
    warehouse_id uuid NOT NULL,
    fetched_at timestamptz,
    forecast_date date,
    latitude float8 NOT NULL,
    longitude float8 NOT NULL,
    max_temperaturec float8 NOT NULL,
    mean_temperaturec float8 NOT NULL,
    min_temperaturec float8 NOT NULL,
    max_temperature_c float8,
    mean_temperature_c float8,
    min_temperature_c float8,
    PRIMARY KEY (warehouse_id)
);

-- TABLE: fuel_tank_provenance  (satrlar: noma'lum)
CREATE TABLE fuel_tank_provenance (
    operation_id uuid NOT NULL,
    interval_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    review_document jsonb,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_tank_provenance_closed  (satrlar: noma'lum)
CREATE TABLE fuel_tank_provenance_closed (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (account_id) REFERENCES fuel_stock_account(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: fuel_type  (satrlar: 0 — BO`SH)
-- ---------------------------------------------------------------------
-- Yoqilg'i turlari katalogi (kod va nomi). Mashina qaysi yoqilg'i bilan
-- ishlashini vehicle_reference_data_fuel_type bog'lovchi jadvali ko'rsatadi.
-- ---------------------------------------------------------------------
CREATE TABLE fuel_type (
    id uuid NOT NULL,
    code varchar(32) NOT NULL,
    label varchar(64) NOT NULL,
    status boolean,
    subtitle varchar(255),
    PRIMARY KEY (id)
);

-- TABLE: fuel_unit_consumption_closed  (satrlar: noma'lum)
CREATE TABLE fuel_unit_consumption_closed (
    operation_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id)
);

-- TABLE: fuel_unit_consumption_revision  (satrlar: 0 — BO`SH)
CREATE TABLE fuel_unit_consumption_revision (
    operation_id uuid NOT NULL,
    interval_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'DRAFT', 'APPROVED', 'REVOKED', 'DISMISSED'
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    calculation jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    review_document jsonb,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    CHECK ((revision > 0)),
    CHECK (state in ('DRAFT', 'APPROVED', 'REVOKED', 'DISMISSED'))
);

-- TABLE: fuel_warehouse_stock  (satrlar: noma'lum)
CREATE TABLE fuel_warehouse_stock (
    id uuid NOT NULL,
    capacity_liters numeric(14,3),
    created_at timestamptz NOT NULL,
    current_balance_liters numeric(14,3) NOT NULL,
    fuel_type varchar(32) NOT NULL,
    updated_at timestamptz NOT NULL,
    warehouse_id uuid NOT NULL,
    warehouse_name varchar(256),
    PRIMARY KEY (id)
);

-- TABLE: fuel_work_distribution  (satrlar: noma'lum)
CREATE TABLE fuel_work_distribution (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    interval_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    calculation jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    review_document jsonb,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id)
);

-- TABLE: fuel_work_distribution_closed  (satrlar: noma'lum)
CREATE TABLE fuel_work_distribution_closed (
    operation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id)
);

-- TABLE: gate_pass  (satrlar: 0 — BO`SH)
CREATE TABLE gate_pass (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    created_by uuid,
    expires_at timestamptz,
    issued_at timestamptz NOT NULL,
    notes varchar(1000),
    pass_number varchar(64) NOT NULL,
    status varchar(16) NOT NULL,  -- RUXSAT: 'ISSUED', 'USED', 'CANCELLED', 'AT_GATE'
    updated_at timestamptz,
    used_at timestamptz,
    driver_id uuid,
    trip_id uuid,
    vehicle_id uuid,
    branch_id uuid,
    carrier_id uuid,
    composition_identity varchar(128),
    entered_at timestamptz,
    exited_at timestamptz,
    kind varchar(16),
    shipment_id uuid,
    site_id uuid,
    valid_from timestamptz,
    object_version bigint NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id),
    FOREIGN KEY (trip_id) REFERENCES trip(id),
    FOREIGN KEY (driver_id) REFERENCES driver(id),
    CHECK (status in ('ISSUED', 'USED', 'CANCELLED', 'AT_GATE'))
);

-- TABLE: gps_archive_coverage  (satrlar: noma'lum)
CREATE TABLE gps_archive_coverage (
    binding_id uuid NOT NULL,
    window_from timestamptz NOT NULL,
    window_until timestamptz NOT NULL,
    completed_at timestamptz NOT NULL,
    PRIMARY KEY (binding_id, window_from, window_until),
    FOREIGN KEY (binding_id) REFERENCES vehicle_gps(id),
    CHECK ((window_from < window_until))
);

-- TABLE: gps_archive_cursor  (satrlar: noma'lum)
CREATE TABLE gps_archive_cursor (
    binding_id uuid NOT NULL,
    lane varchar(16) NOT NULL,  -- RUXSAT: 'RECENT', 'BACKFILL'; BAZADA: 'BACKFILL' 70, 'RECENT' 70
    next_from timestamptz NOT NULL,
    window_from timestamptz,
    window_until timestamptz,
    watermark bigint,
    after_id bigint NOT NULL,
    lease_token uuid,  -- [MAXFIY — o'qish taqiqlangan]
    lease_until timestamptz,
    retry_at timestamptz,
    error_code varchar(64),
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (binding_id, lane),
    FOREIGN KEY (binding_id) REFERENCES vehicle_gps(id),
    CHECK ((after_id >= 0)),
    CHECK ((((window_from is null) and (window_until is null) and (watermark is null) and (after_id = 0)) or ((window_from is not null) and (window_until is not null) and (window_from < window_until)))),
    CHECK (((watermark is null) or (watermark >= after_id))),
    CHECK (((lease_token is null) = (lease_until is null))),
    CHECK (lane in ('RECENT', 'BACKFILL'))
);

-- TABLE: gps_archive_point  (satrlar: noma'lum)
CREATE TABLE gps_archive_point (
    binding_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    provider_device_id bigint NOT NULL,
    provider_point_id bigint NOT NULL,
    fix_time timestamptz NOT NULL,
    received_at timestamptz NOT NULL,
    payload text NOT NULL,
    payload_hash varchar(64) NOT NULL,
    PRIMARY KEY (binding_id, provider_point_id),
    FOREIGN KEY (binding_id) REFERENCES vehicle_gps(id),
    CHECK (((payload_hash) = encode(sha256(convert_to(payload, 'utf8'::name)), 'hex'))),
    CHECK ((jsonb_typeof((payload)::jsonb) = 'object')),
    CHECK ((provider_device_id > 0)),
    CHECK ((provider_point_id > 0))
);

-- TABLE: gps_configuration  (satrlar: noma'lum)
CREATE TABLE gps_configuration (
    id uuid NOT NULL,
    actor_id uuid,
    applied_version bigint,
    binding_id uuid,
    binding_version bigint NOT NULL,
    created_at timestamptz,
    desired_version bigint NOT NULL,
    host varchar(255),
    model_id varchar(255),
    payload_encrypted text,
    port integer NOT NULL,
    state varchar(255),
    PRIMARY KEY (id),
    FOREIGN KEY (binding_id) REFERENCES vehicle_gps(id)
);

-- TABLE: gps_control_request  (satrlar: noma'lum)
CREATE TABLE gps_control_request (
    id uuid NOT NULL,
    actor_id uuid,
    created_at timestamptz,
    idempotency_key varchar(255),
    payload_hash varchar(255),
    response_encrypted text,
    PRIMARY KEY (id)
);

-- TABLE: gps_device_credential  (satrlar: noma'lum)
CREATE TABLE gps_device_credential (
    id uuid NOT NULL,
    actor_id uuid,
    binding_id uuid,
    binding_version bigint NOT NULL,
    created_at timestamptz,
    generation bigint NOT NULL,
    idempotency_key varchar(255),
    rate_count integer NOT NULL,
    rate_window timestamptz,
    revoked_at timestamptz,
    token_hash varchar(255),  -- [MAXFIY — o'qish taqiqlangan]
    PRIMARY KEY (id),
    FOREIGN KEY (binding_id) REFERENCES vehicle_gps(id)
);

-- TABLE: gps_event_command  (satrlar: 0 — BO`SH)
CREATE TABLE gps_event_command (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    action varchar(32) NOT NULL,  -- RUXSAT: 'SAVE_POLICY', 'SAVE_ZONE', 'DECIDE', 'EVALUATE', 'REVIEW'
    request_hash char(64) NOT NULL,
    state varchar(32) NOT NULL,  -- RUXSAT: 'APPLIED', 'NOT_EXECUTED'
    response jsonb NOT NULL,  -- [JSON matn]
    closure_basis varchar(2000),
    created_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    CHECK (action in ('SAVE_POLICY', 'SAVE_ZONE', 'DECIDE', 'EVALUATE', 'REVIEW')),
    CHECK (((((state) = 'not_executed') and (closure_basis is not null) and (length(btrim((closure_basis))) > 0) and (response = 'null'::jsonb)) or (((state) = 'applied') and (closure_basis is null)))),
    CHECK ((request_hash ~ '^[a-f0-9]{64}$')),
    CHECK (state in ('APPLIED', 'NOT_EXECUTED'))
);

-- TABLE: gps_event_definition_decision  (satrlar: 0 — BO`SH)
CREATE TABLE gps_event_definition_decision (
    id uuid NOT NULL,
    branch_id uuid NOT NULL,
    kind varchar(16) NOT NULL,  -- RUXSAT: 'POLICY', 'ZONE'
    definition_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    action varchar(16) NOT NULL,  -- RUXSAT: 'APPROVE', 'REVOKE'
    basis varchar(2000) NOT NULL,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    CHECK (action in ('APPROVE', 'REVOKE')),
    CHECK ((length(btrim((basis))) > 0)),
    CHECK (kind in ('POLICY', 'ZONE'))
);

-- TABLE: gps_event_evaluation  (satrlar: noma'lum)
CREATE TABLE gps_event_evaluation (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    trip_id uuid,
    revision integer NOT NULL,
    previous_id uuid,
    selection_id uuid NOT NULL,
    policy_id uuid NOT NULL,
    source_hash char(64) NOT NULL,
    from_at timestamptz NOT NULL,
    to_at timestamptz NOT NULL,
    body jsonb NOT NULL,  -- [JSON matn]
    source_body jsonb NOT NULL,  -- [JSON matn]
    created_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (policy_id) REFERENCES gps_event_policy(id),
    FOREIGN KEY (previous_id) REFERENCES gps_event_evaluation(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id),
    CHECK ((to_at > from_at)),
    CHECK ((revision > 0))
);

-- TABLE: gps_event_evidence_review  (satrlar: noma'lum)
CREATE TABLE gps_event_evidence_review (
    id uuid NOT NULL,
    evaluation_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    body jsonb NOT NULL,  -- [JSON matn]
    created_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (evaluation_id) REFERENCES gps_event_evaluation(id)
);

-- TABLE: gps_event_policy  (satrlar: noma'lum)
CREATE TABLE gps_event_policy (
    id uuid NOT NULL,
    branch_id uuid NOT NULL,
    author_id uuid NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_to timestamptz NOT NULL,
    body jsonb NOT NULL,  -- [JSON matn]
    created_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (author_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    CHECK ((valid_to > valid_from))
);

-- TABLE: gps_event_zone  (satrlar: noma'lum)
CREATE TABLE gps_event_zone (
    id uuid NOT NULL,
    zone_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    author_id uuid NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_to timestamptz NOT NULL,
    body jsonb NOT NULL,  -- [JSON matn]
    created_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (author_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    CHECK ((valid_to > valid_from))
);

-- TABLE: gps_ingest_event  (satrlar: noma'lum)
CREATE TABLE gps_ingest_event (
    id uuid NOT NULL,
    attempts integer NOT NULL,
    binding_id uuid,
    created_at timestamptz,
    device_id bigint NOT NULL,
    error_code varchar(255),
    event_id uuid,
    lease_token uuid,  -- [MAXFIY — o'qish taqiqlangan]
    lease_until timestamptz,
    payload text,
    payload_hash varchar(255),
    retry_at timestamptz,
    state varchar(255),
    unique_id varchar(255),
    PRIMARY KEY (id),
    FOREIGN KEY (binding_id) REFERENCES vehicle_gps(id)
);

-- TABLE: gps_ingest_receipt  (satrlar: noma'lum)
CREATE TABLE gps_ingest_receipt (
    id uuid NOT NULL,
    accepted_count integer NOT NULL,
    created_at timestamptz,
    credential_id uuid,  -- [MAXFIY — o'qish taqiqlangan]
    device_id bigint NOT NULL,
    duplicate_count integer NOT NULL,
    event_ids text,
    PRIMARY KEY (id),
    FOREIGN KEY (credential_id) REFERENCES gps_device_credential(id)
);

-- TABLE: gps_operation  (satrlar: noma'lum)
CREATE TABLE gps_operation (
    id uuid NOT NULL,
    actor_context varchar(1024) NOT NULL,
    actor_id uuid NOT NULL,
    binding_id uuid,
    created_at timestamptz NOT NULL,
    error_code varchar(128),
    expected_version bigint,
    gps_contact_driver_id uuid,
    idempotency_key varchar(128) NOT NULL,
    kind varchar(32) NOT NULL,  -- RUXSAT: 'CREATE_ATTACH', 'ATTACH', 'UPDATE', 'REBIND', 'DETACH', 'DELETE_PROVIDER', 'VERIFY_OWNERSHIP', 'APPLY_CONFIGURATION', 'VERIFY_CONFIGURATION'; BAZADA: 'CREATE_ATTACH' 13; ISHLATILMAGAN: ATTACH, UPDATE, REBIND, DETACH, DELETE_PROVIDER, VERIFY_OWNERSHIP, APPLY_CONFIGURATION, VERIFY_CONFIGURATION
    lease_token uuid,  -- [MAXFIY — o'qish taqiqlangan]
    lease_until timestamptz,
    mutation_started_at timestamptz,
    payload_hash varchar(64) NOT NULL,
    provider_device_id bigint,
    readback_attempts integer NOT NULL,
    retry_at timestamptz,
    scope_context varchar(1024),
    state varchar(32) NOT NULL,  -- RUXSAT: 'PENDING', 'PROCESSING', 'RECONCILING', 'SUCCEEDED', 'FAILED', 'NEEDS_REVIEW'; BAZADA: 'FAILED' 9; ISHLATILMAGAN: PENDING, PROCESSING, RECONCILING, SUCCEEDED, NEEDS_REVIEW
    target_vehicle_id uuid,
    unique_id varchar(64),
    updated_at timestamptz NOT NULL,
    vehicle_id uuid NOT NULL,
    version bigint NOT NULL,
    desired_version bigint,
    ownership_basis varchar(2000),
    ownership_verified_at timestamptz,
    PRIMARY KEY (id),
    CHECK (kind in ('CREATE_ATTACH', 'ATTACH', 'UPDATE', 'REBIND', 'DETACH', 'DELETE_PROVIDER', 'VERIFY_OWNERSHIP', 'APPLY_CONFIGURATION', 'VERIFY_CONFIGURATION')),
    CHECK (state in ('PENDING', 'PROCESSING', 'RECONCILING', 'SUCCEEDED', 'FAILED', 'NEEDS_REVIEW'))
);

-- TABLE: gps_operation_review  (satrlar: 0 — BO`SH)
CREATE TABLE gps_operation_review (
    id uuid NOT NULL,
    action varchar(32) NOT NULL,  -- RUXSAT: 'RECHECK_PROVIDER', 'ABORT_UNSTARTED'
    actor_id uuid NOT NULL,
    basis varchar(2000) NOT NULL,
    expected_version bigint NOT NULL,
    occurred_at timestamptz NOT NULL,
    operation_id uuid NOT NULL,
    payload_hash varchar(64) NOT NULL,
    resulting_state varchar(32) NOT NULL,  -- RUXSAT: 'PENDING', 'PROCESSING', 'RECONCILING', 'SUCCEEDED', 'FAILED', 'NEEDS_REVIEW'
    PRIMARY KEY (id),
    FOREIGN KEY (operation_id) REFERENCES gps_operation(id),
    CHECK (action in ('RECHECK_PROVIDER', 'ABORT_UNSTARTED')),
    CHECK (resulting_state in ('PENDING', 'PROCESSING', 'RECONCILING', 'SUCCEEDED', 'FAILED', 'NEEDS_REVIEW'))
);

-- TABLE: gps_provider_diagnostic  (satrlar: 0 — BO`SH)
CREATE TABLE gps_provider_diagnostic (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    availability varchar(32) NOT NULL,  -- RUXSAT: 'AVAILABLE', 'UNCONFIGURED', 'UNAUTHORIZED', 'NETWORK_ERROR', 'INVALID_RESPONSE', 'PROVIDER_ERROR'
    checked_at timestamptz NOT NULL,
    device_count integer,
    latency_millis bigint,
    PRIMARY KEY (id),
    CHECK (availability in ('AVAILABLE', 'UNCONFIGURED', 'UNAUTHORIZED', 'NETWORK_ERROR', 'INVALID_RESPONSE', 'PROVIDER_ERROR'))
);

-- TABLE: gps_provider_settings  (satrlar: noma'lum)
CREATE TABLE gps_provider_settings (
    id bigint NOT NULL,
    base_url varchar(255),
    fmb920_enabled boolean,
    http_enabled boolean NOT NULL,
    ingress_host varchar(255),
    integration_key_encrypted text,
    password_encrypted text,  -- [MAXFIY — o'qish taqiqlangan]
    teltonika_port integer NOT NULL,
    username varchar(255),
    version bigint NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: hazard_profile  (satrlar: noma'lum)
CREATE TABLE hazard_profile (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    emergency_code varchar(64),
    hazard_class varchar(32),
    notes varchar(1000),
    official_name varchar(256) NOT NULL,
    packing_group varchar(32),
    requires_adr boolean,
    requires_placards boolean,
    requires_special_tank boolean,
    un_number varchar(32) NOT NULL,
    updated_at timestamptz,
    PRIMARY KEY (id)
);

-- TABLE: incident  (satrlar: 0 — BO`SH)
-- ---------------------------------------------------------------------
-- Hodisalar (telematika va nazorat asosida): tezlik buzilishi, yoqilg'i
-- tafovuti, marshrutdan chiqish, ruxsatsiz to'xtash, qattiq tormozlash, keskin
-- tezlashish, uzoq bekor turish, geozonadan chiqish, texnik xizmat muddati,
-- avariya, o'g'irlik.
-- severity: LOW, MEDIUM, HIGH, CRITICAL. status: OPEN, IN_PROGRESS, RESOLVED,
-- CLOSED, DISMISSED. Kim aniqlagan (created_by) va kim hal qilgan (resolved_by)
-- app_user ga bog'langan.
-- HAL QILINMAGAN HODISALAR status IN ('OPEN','IN_PROGRESS') bo'yicha olinadi.
-- ---------------------------------------------------------------------
CREATE TABLE incident (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    description varchar(1000),
    incident_type varchar(255) NOT NULL,  -- RUXSAT: 'SPEED_VIOLATION', 'FUEL_DEVIATION', 'ROUTE_DEVIATION', 'UNAUTHORIZED_STOP', 'HARD_BRAKING', 'RAPID_ACCELERATION', 'IDLE_EXCESSIVE', 'GEOFENCE_VIOLATION', 'MAINTENANCE_DUE', 'ACCIDENT', 'THEFT', 'OTHER'
    latitude numeric(10,7),
    longitude numeric(10,7),
    occurred_at timestamptz NOT NULL,
    resolution_notes varchar(1000),
    resolved_at timestamptz,
    severity varchar(255) NOT NULL,  -- RUXSAT: 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'
    status varchar(255) NOT NULL,  -- RUXSAT: 'OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED', 'DISMISSED'
    created_by uuid NOT NULL,
    driver_id uuid,
    resolved_by uuid,
    trip_id uuid,
    vehicle_id uuid NOT NULL,
    assignee_user_id uuid,
    batch_reference varchar(512),
    branch_id uuid,
    location varchar(512),
    policy_id uuid,
    root_cause varchar(4000),
    site_id uuid,
    updated_at timestamptz,
    version bigint NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (trip_id) REFERENCES trip(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id),
    FOREIGN KEY (driver_id) REFERENCES driver(id),
    FOREIGN KEY (created_by) REFERENCES app_user(id),
    FOREIGN KEY (resolved_by) REFERENCES app_user(id),
    CHECK (incident_type in ('SPEED_VIOLATION', 'FUEL_DEVIATION', 'ROUTE_DEVIATION', 'UNAUTHORIZED_STOP', 'HARD_BRAKING', 'RAPID_ACCELERATION', 'IDLE_EXCESSIVE', 'GEOFENCE_VIOLATION', 'MAINTENANCE_DUE', 'ACCIDENT', 'THEFT', 'OTHER')),
    CHECK (severity in ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    CHECK (status in ('OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED', 'DISMISSED'))
);

-- TABLE: insurance_policy  (satrlar: 0 — BO`SH)
-- ---------------------------------------------------------------------
-- Sug'urta polislari: OSAGO, KASKO, CARGO, LIABILITY, PASSENGER. Polis raqami,
-- sug'urta kompaniyasi, sug'urta summasi, mukofot (premium), amal qilish muddati
-- (valid_from, valid_to).
-- status: ACTIVE, EXPIRING_SOON, EXPIRED, CANCELLED.
-- MUDDATI TUGAYOTGAN SUG'URTALAR valid_to bo'yicha yoki status='EXPIRING_SOON'
-- bilan olinadi.
-- ---------------------------------------------------------------------
CREATE TABLE insurance_policy (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    currency varchar(8) NOT NULL,
    insured_amount numeric(16,2) NOT NULL,
    insurer_name varchar(255) NOT NULL,
    kind varchar(16) NOT NULL,  -- RUXSAT: 'OSAGO', 'KASKO', 'CARGO', 'LIABILITY', 'PASSENGER'
    notes varchar(2000),
    policy_number varchar(64) NOT NULL,
    premium numeric(14,2) NOT NULL,
    status varchar(16) NOT NULL,  -- RUXSAT: 'ACTIVE', 'EXPIRING_SOON', 'EXPIRED', 'CANCELLED'
    updated_at timestamptz NOT NULL,
    valid_from date NOT NULL,
    valid_to date NOT NULL,
    vehicle_id uuid,
    version bigint NOT NULL,
    PRIMARY KEY (id),
    CHECK (kind in ('OSAGO', 'KASKO', 'CARGO', 'LIABILITY', 'PASSENGER')),
    CHECK (status in ('ACTIVE', 'EXPIRING_SOON', 'EXPIRED', 'CANCELLED'))
);

-- TABLE: integration_batch_quality_receipt  (satrlar: 0 — BO`SH)
CREATE TABLE integration_batch_quality_receipt (
    event_id uuid NOT NULL,
    source_id text NOT NULL,
    source_contract_revision bigint NOT NULL,
    branch_id uuid NOT NULL,
    site_id uuid NOT NULL,
    product_id uuid NOT NULL,
    batch_id uuid NOT NULL,
    decision_id uuid NOT NULL,
    source_revision bigint NOT NULL,
    schema_version text NOT NULL,
    idempotency_key text NOT NULL,
    status text NOT NULL,  -- RUXSAT: 'ACCEPTED', 'STALE', 'SOURCE_NOT_CURRENT'
    reason text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    payload_hash text NOT NULL,
    received_at timestamptz NOT NULL,
    PRIMARY KEY (event_id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (site_id) REFERENCES yard_site(id),
    CHECK ((payload_hash ~ '^[0-9a-f]{64}$')),
    CHECK ((source_revision >= 0)),
    CHECK (status in ('ACCEPTED', 'STALE', 'SOURCE_NOT_CURRENT'))
);

-- TABLE: integration_document_command  (satrlar: noma'lum)
CREATE TABLE integration_document_command (
    operation_id uuid NOT NULL,
    document_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    kind varchar(32) NOT NULL,
    original_json jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (document_id) REFERENCES transport_document(id)
);

-- TABLE: integration_document_intent  (satrlar: 0 — BO`SH)
CREATE TABLE integration_document_intent (
    operation_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    path text NOT NULL,
    original_json jsonb NOT NULL,  -- [JSON matn]
    state varchar(32) NOT NULL,  -- RUXSAT: 'APPLIED', 'NOT_EXECUTED'
    reason text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK (state in ('APPLIED', 'NOT_EXECUTED'))
);

-- TABLE: integration_document_signature  (satrlar: 0 — BO`SH)
CREATE TABLE integration_document_signature (
    id uuid NOT NULL,
    document_id uuid NOT NULL,
    version_id uuid NOT NULL,
    version_number integer NOT NULL,
    content_sha256 varchar(128) NOT NULL,
    state varchar(32) NOT NULL,  -- RUXSAT: 'VERIFIED', 'LEGACY_UNVERIFIED'
    certificate_sha256 varchar(64),
    certificate_serial varchar(128),
    signer_name varchar(512),
    actor_id uuid,
    signed_at timestamptz,
    certificate_valid_until timestamptz,
    authority_id uuid,
    authority_revision bigint,
    policy_id uuid,
    policy_revision bigint,
    provider varchar(64),
    signature_data text,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (document_id) REFERENCES transport_document(id),
    FOREIGN KEY (policy_id) REFERENCES integration_signature_policy(id),
    FOREIGN KEY (version_id) REFERENCES document_version(id),
    CHECK ((((state) <> 'verified') or (((certificate_sha256) ~ '^[a-f0-9]{64}$') and (actor_id is not null) and (signed_at is not null) and (authority_id is not null) and (policy_id is not null) and (signature_data is not null)))),
    CHECK (state in ('VERIFIED', 'LEGACY_UNVERIFIED'))
);

-- TABLE: integration_edo_correction  (satrlar: noma'lum)
CREATE TABLE integration_edo_correction (
    id uuid NOT NULL,
    document_id uuid NOT NULL,
    rejected_submission_id uuid NOT NULL,
    prior_version_id uuid NOT NULL,
    new_version_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    reason text NOT NULL,
    original_json jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (document_id) REFERENCES transport_document(id),
    FOREIGN KEY (new_version_id) REFERENCES document_version(id),
    FOREIGN KEY (prior_version_id) REFERENCES document_version(id),
    FOREIGN KEY (rejected_submission_id) REFERENCES integration_edo_submission(id)
);

-- TABLE: integration_edo_gate_policy  (satrlar: 0 — BO`SH)
CREATE TABLE integration_edo_gate_policy (
    id uuid NOT NULL,
    revision bigint NOT NULL,
    operation_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    site_id uuid NOT NULL,
    operation varchar(16) NOT NULL,  -- RUXSAT: 'ENTER', 'EXIT', 'LOAD', 'UNLOAD'
    configuration jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id, revision),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK (operation in ('ENTER', 'EXIT', 'LOAD', 'UNLOAD')),
    CHECK ((revision > 0))
);

-- TABLE: integration_edo_party  (satrlar: noma'lum)
CREATE TABLE integration_edo_party (
    id uuid NOT NULL,
    revision bigint NOT NULL,
    operation_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    card jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id, revision),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK ((revision > 0))
);

-- TABLE: integration_edo_protocol  (satrlar: noma'lum)
CREATE TABLE integration_edo_protocol (
    id uuid NOT NULL,
    provider_id varchar(64) NOT NULL,
    revision bigint NOT NULL,
    operation_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    contract jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK ((revision > 0))
);

-- TABLE: integration_edo_submission  (satrlar: noma'lum)
CREATE TABLE integration_edo_submission (
    id uuid NOT NULL,
    document_id uuid NOT NULL,
    version_id uuid NOT NULL,
    version_number integer NOT NULL,
    evidence_id uuid NOT NULL,
    provider_id varchar(64) NOT NULL,
    exchange_id uuid NOT NULL,
    sender_id uuid NOT NULL,
    sender_revision bigint NOT NULL,
    recipient_id uuid NOT NULL,
    recipient_revision bigint NOT NULL,
    corrects_submission_id uuid,
    reason text NOT NULL,
    actor_id uuid NOT NULL,
    original_json jsonb NOT NULL,  -- [JSON matn]
    protocol_id uuid NOT NULL,
    protocol_revision bigint NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (corrects_submission_id) REFERENCES integration_edo_submission(id),
    FOREIGN KEY (document_id) REFERENCES transport_document(id),
    FOREIGN KEY (evidence_id) REFERENCES integration_document_signature(id),
    FOREIGN KEY (exchange_id) REFERENCES integration_exchange_event(id),
    FOREIGN KEY (protocol_id) REFERENCES integration_edo_protocol(id),
    FOREIGN KEY (version_id) REFERENCES document_version(id)
);

-- TABLE: integration_exchange_closed_operation  (satrlar: noma'lum)
CREATE TABLE integration_exchange_closed_operation (
    operation_id uuid NOT NULL,
    kind varchar(32) NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason varchar(2000) NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id)
);

-- TABLE: integration_exchange_event  (satrlar: noma'lum)
CREATE TABLE integration_exchange_event (
    id uuid NOT NULL,
    provider_id varchar(64) NOT NULL,
    channel varchar(64) NOT NULL,
    aggregate_type varchar(128) NOT NULL,
    aggregate_id uuid NOT NULL,
    branch_id uuid,
    aggregate_version bigint NOT NULL,
    schema_version varchar(64) NOT NULL,
    idempotency_key varchar(512) NOT NULL,
    payload_hash varchar(64) NOT NULL,
    payload jsonb NOT NULL,  -- [JSON matn]
    wire_payload text NOT NULL,
    dependency uuid,
    provider_revision bigint NOT NULL,
    state varchar(64) NOT NULL,
    attempts integer NOT NULL,
    next_attempt_at timestamptz NOT NULL,
    lease_token uuid,  -- [MAXFIY — o'qish taqiqlangan]
    lease_until timestamptz,
    manual_requested boolean NOT NULL,
    detail varchar(2000) NOT NULL,
    created_at timestamptz NOT NULL,
    correlation_id varchar(128),
    PRIMARY KEY (id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (dependency) REFERENCES integration_exchange_event(id),
    CHECK (((correlation_id is null) or (((correlation_id) collate "c") ~ '^[a-za-z0-9._-]{1,128}$'))),
    CHECK ((aggregate_version >= 0)),
    CHECK ((dependency is distinct from id)),
    CHECK (((payload_hash) ~ '^[a-f0-9]{64}$'))
);

-- TABLE: integration_exchange_history  (satrlar: noma'lum)
CREATE TABLE integration_exchange_history (
    sequence bigint NOT NULL,
    event_id uuid NOT NULL,
    state varchar(64) NOT NULL,
    attempt integer NOT NULL,
    detail varchar(2000) NOT NULL,
    actor_id uuid,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (sequence),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (event_id) REFERENCES integration_exchange_event(id)
);

-- TABLE: integration_exchange_operation  (satrlar: noma'lum)
CREATE TABLE integration_exchange_operation (
    operation_id uuid NOT NULL,
    kind varchar(32) NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    result jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id)
);

-- TABLE: integration_exchange_provider  (satrlar: noma'lum)
CREATE TABLE integration_exchange_provider (
    provider_id varchar(64) NOT NULL,
    revision bigint NOT NULL,
    operation_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    contract jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (provider_id, revision),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK ((revision > 0))
);

-- TABLE: integration_exchange_receipt  (satrlar: 0 — BO`SH)
CREATE TABLE integration_exchange_receipt (
    id uuid NOT NULL,
    provider_id varchar(64) NOT NULL,
    receipt_id varchar(256) NOT NULL,
    event_id uuid NOT NULL,
    stage varchar(64) NOT NULL,  -- RUXSAT: 'VALIDATED', 'BUSINESS_ACCEPTED', 'DELIVERED', 'RECIPIENT_SIGNED', 'BUSINESS_REJECTED'
    external_document_id varchar(512),
    reason varchar(2000) NOT NULL,
    confirmed_at timestamptz NOT NULL,
    received_at timestamptz NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    PRIMARY KEY (provider_id, receipt_id),
    FOREIGN KEY (event_id) REFERENCES integration_exchange_event(id),
    CHECK (stage in ('VALIDATED', 'BUSINESS_ACCEPTED', 'DELIVERED', 'RECIPIENT_SIGNED', 'BUSINESS_REJECTED'))
);

-- TABLE: integration_exchange_receipt_machine_witness  (satrlar: noma'lum)
CREATE TABLE integration_exchange_receipt_machine_witness (
    id uuid NOT NULL,
    receipt_id uuid NOT NULL,
    machine_id varchar(64) NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (receipt_id) REFERENCES integration_exchange_receipt(id)
);

-- TABLE: integration_exchange_wire_artifact  (satrlar: noma'lum)
CREATE TABLE integration_exchange_wire_artifact (
    event_id uuid NOT NULL,
    provider_revision bigint NOT NULL,
    source_payload_hash varchar(64) NOT NULL,
    wire_sha256 varchar(64) NOT NULL,
    wire_payload text NOT NULL,
    prepared_at timestamptz NOT NULL,
    PRIMARY KEY (event_id),
    FOREIGN KEY (event_id) REFERENCES integration_exchange_event(id)
);

-- TABLE: integration_fleet_passport_exchange  (satrlar: noma'lum)
CREATE TABLE integration_fleet_passport_exchange (
    source_event_id uuid NOT NULL,
    exchange_event_id uuid NOT NULL,
    captured_at timestamptz NOT NULL,
    PRIMARY KEY (source_event_id),
    FOREIGN KEY (exchange_event_id) REFERENCES integration_exchange_event(id),
    FOREIGN KEY (source_event_id) REFERENCES fleet_passport_lifecycle(operation_id)
);

-- TABLE: integration_inbound_control_operation  (satrlar: 0 — BO`SH)
CREATE TABLE integration_inbound_control_operation (
    operation_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    kind text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    state text NOT NULL,  -- RUXSAT: 'APPLIED', 'NOT_EXECUTED'
    result jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK (state in ('APPLIED', 'NOT_EXECUTED'))
);

-- TABLE: integration_inbound_source  (satrlar: noma'lum)
CREATE TABLE integration_inbound_source (
    source_id text NOT NULL,
    revision bigint NOT NULL,
    operation_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    contract jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (source_id, revision),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK (((contract ->> 'sourceid') = source_id)),
    CHECK ((((contract ->> 'expectedrevision')) = (revision - 1))),
    CHECK (((contract ->> 'state') = any (array['approved', 'revoked']))),
    CHECK (((contract ->> 'sourcekind') = any (array['wms', 'lims', 'erp_quality', 'toir']))),
    CHECK ((revision > 0))
);

-- TABLE: integration_loading_bridge  (satrlar: 0 — BO`SH)
CREATE TABLE integration_loading_bridge (
    local_shipment_id uuid NOT NULL,
    local_batch_id uuid NOT NULL,
    site_id uuid NOT NULL,
    revision bigint NOT NULL,
    operation_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    author_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'DRAFT', 'APPROVED', 'REVOKED'
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (local_shipment_id, local_batch_id, site_id, revision),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (author_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (local_batch_id) REFERENCES chemical_quality_batch(id),
    FOREIGN KEY (local_shipment_id) REFERENCES shipment(id),
    FOREIGN KEY (site_id) REFERENCES yard_site(id),
    CHECK ((revision > 0)),
    CHECK (state in ('DRAFT', 'APPROVED', 'REVOKED'))
);

-- TABLE: integration_loading_bridge_current  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
CREATE TABLE integration_loading_bridge_current (
    local_shipment_id uuid,
    local_batch_id uuid,
    site_id uuid,
    revision bigint,
    operation_id uuid,
    branch_id uuid,
    author_id uuid,
    actor_id uuid,
    state text,
    original jsonb,  -- [JSON matn]
    sources jsonb,  -- [JSON matn]
    recorded_at timestamptz
);

-- TABLE: integration_signature_policy  (satrlar: noma'lum)
CREATE TABLE integration_signature_policy (
    id uuid NOT NULL,
    document_type varchar(64) NOT NULL,
    revision bigint NOT NULL,
    operation_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    configuration jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK ((revision > 0))
);

-- TABLE: integration_signer_authority  (satrlar: noma'lum)
CREATE TABLE integration_signer_authority (
    id uuid NOT NULL,
    revision bigint NOT NULL,
    operation_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    configuration jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id, revision),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK ((revision > 0))
);

-- TABLE: integration_toir_hold  (satrlar: 0 — BO`SH)
CREATE TABLE integration_toir_hold (
    source_id text NOT NULL,
    equipment_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    event_id uuid NOT NULL,
    source_revision bigint NOT NULL,
    mapping_revision bigint NOT NULL,
    policy_revision bigint NOT NULL,
    source_status text NOT NULL,
    restriction text NOT NULL,  -- RUXSAT: 'CLEAR', 'IN_REPAIR', 'UNAVAILABLE', 'DECOMMISSIONED'
    reason text NOT NULL,
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (source_id, equipment_id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (event_id) REFERENCES integration_toir_status_inbox(event_id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id),
    CHECK (restriction in ('CLEAR', 'IN_REPAIR', 'UNAVAILABLE', 'DECOMMISSIONED'))
);

-- TABLE: integration_toir_inbox_current  (satrlar: 0 — BO`SH)
-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
CREATE TABLE integration_toir_inbox_current (
    event_id uuid,
    source_id text,
    source_contract_revision bigint,
    branch_id uuid,
    equipment_id uuid,
    submitted_vehicle_id uuid,
    source_revision bigint,
    source_status text,
    schema_version text,
    idempotency_key text,
    original jsonb,  -- [JSON matn]
    payload_hash text,
    initial_status text,
    initial_reason text,
    received_at timestamptz,
    status text,
    reason text,
    mapping_revision bigint,
    policy_revision bigint,
    resolved_at timestamptz
);

-- TABLE: integration_toir_mapping  (satrlar: noma'lum)
CREATE TABLE integration_toir_mapping (
    source_id text NOT NULL,
    equipment_id uuid NOT NULL,
    revision bigint NOT NULL,
    vehicle_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    operation_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    contract jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (source_id, equipment_id, revision),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id),
    CHECK ((revision > 0))
);

-- TABLE: integration_toir_outbox_bridge  (satrlar: noma'lum)
CREATE TABLE integration_toir_outbox_bridge (
    legacy_event_id uuid NOT NULL,
    exchange_event_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (legacy_event_id)
);

-- TABLE: integration_toir_resolution  (satrlar: 0 — BO`SH)
CREATE TABLE integration_toir_resolution (
    operation_id uuid NOT NULL,
    event_id uuid NOT NULL,
    actor_id uuid,
    status text NOT NULL,
    reason text NOT NULL,
    mapping_revision bigint,
    policy_revision bigint,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (event_id) REFERENCES integration_toir_status_inbox(event_id)
);

-- TABLE: integration_toir_snapshot_sequence  (satrlar: noma'lum)
CREATE TABLE integration_toir_snapshot_sequence (
    vehicle_id uuid NOT NULL,
    revision bigint NOT NULL,
    PRIMARY KEY (vehicle_id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id),
    CHECK ((revision > 0))
);

-- TABLE: integration_toir_status_inbox  (satrlar: noma'lum)
CREATE TABLE integration_toir_status_inbox (
    event_id uuid NOT NULL,
    source_id text NOT NULL,
    source_contract_revision bigint NOT NULL,
    branch_id uuid NOT NULL,
    equipment_id uuid NOT NULL,
    submitted_vehicle_id uuid NOT NULL,
    source_revision bigint NOT NULL,
    source_status text NOT NULL,
    schema_version text NOT NULL,
    idempotency_key text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    payload_hash text NOT NULL,
    initial_status text NOT NULL,
    initial_reason text NOT NULL,
    received_at timestamptz NOT NULL,
    PRIMARY KEY (event_id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    CHECK ((payload_hash ~ '^[0-9a-f]{64}$')),
    CHECK ((source_revision >= 0))
);

-- TABLE: integration_toir_status_policy  (satrlar: noma'lum)
CREATE TABLE integration_toir_status_policy (
    source_id text NOT NULL,
    source_status text NOT NULL,
    revision bigint NOT NULL,
    operation_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    contract jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (source_id, source_status, revision),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK ((revision > 0))
);

-- TABLE: inventory_receipt  (satrlar: noma'lum)
CREATE TABLE inventory_receipt (
    id uuid NOT NULL,
    attachment_id uuid NOT NULL,
    counterparty_name varchar(255),
    created_at timestamptz NOT NULL,
    document_date date NOT NULL,
    document_number varchar(64) NOT NULL,
    item_id uuid NOT NULL,
    item_name varchar(256) NOT NULL,
    notes varchar(1024),
    quantity numeric(16,4) NOT NULL,
    received_at timestamptz NOT NULL,
    received_by varchar(255) NOT NULL,
    stock_id uuid NOT NULL,
    total_amount numeric(18,2),
    unit_of_measure varchar(32) NOT NULL,
    unit_price numeric(16,2),
    warehouse_id uuid NOT NULL,
    warehouse_name varchar(256),
    PRIMARY KEY (id)
);

-- TABLE: inventory_stock  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Ombordagi tovar-material qoldiqlari (item, ombor, miqdor, o'lchov birligi).
-- Tovar nomlari product jadvalida.
-- ---------------------------------------------------------------------
CREATE TABLE inventory_stock (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    item_id uuid NOT NULL,
    item_name varchar(256),
    last_updated_at timestamptz NOT NULL,
    quantity numeric(16,4),
    unit_of_measure varchar(32),
    updated_at timestamptz,
    warehouse_id uuid,
    expense_date date,
    group_code varchar(32),
    income_date date,
    item_code varchar(64),
    total_amount numeric(18,2),
    unit_price numeric(16,2),
    vat_rate numeric(6,2),
    warehouse_name varchar(256),
    refurbished boolean NOT NULL,
    source_vehicle_part_id uuid,
    currency varchar(8),
    ledger_opened boolean NOT NULL,
    quarantine_quantity numeric(16,3) NOT NULL,
    version bigint NOT NULL,
    material_group_id uuid,
    measurement_unit_id uuid,
    mxik_id uuid,
    PRIMARY KEY (id),
    FOREIGN KEY (material_group_id) REFERENCES reference_data(id),
    FOREIGN KEY (measurement_unit_id) REFERENCES reference_data(id),
    FOREIGN KEY (mxik_id) REFERENCES reference_data(id)
);

-- TABLE: inventory_warehouse_legacy_mapping  (satrlar: noma'lum)
CREATE TABLE inventory_warehouse_legacy_mapping (
    stock_id uuid NOT NULL,
    warehouse_id uuid,
    warehouse_name text,
    resolution text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (stock_id),
    FOREIGN KEY (stock_id) REFERENCES inventory_stock(id)
);

-- TABLE: maintenance_auto_amendment  (satrlar: 0 — BO`SH)
CREATE TABLE maintenance_auto_amendment (
    operation_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    order_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'RELEASE_LINK', 'AMEND_CARD', 'TRANSFER', 'CARRY_FORWARD'
    card_operation_id uuid,
    release_link_id uuid,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (card_operation_id) REFERENCES maintenance_auto_card(operation_id),
    FOREIGN KEY (order_id) REFERENCES maintenance_auto_order(id),
    FOREIGN KEY (plan_id) REFERENCES maintenance_plan(id),
    FOREIGN KEY (release_link_id) REFERENCES maintenance_auto_repair_link(operation_id),
    CHECK (state in ('RELEASE_LINK', 'AMEND_CARD', 'TRANSFER', 'CARRY_FORWARD'))
);

-- TABLE: maintenance_auto_amendment_closed  (satrlar: noma'lum)
CREATE TABLE maintenance_auto_amendment_closed (
    operation_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    order_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (order_id) REFERENCES maintenance_auto_order(id),
    FOREIGN KEY (plan_id) REFERENCES maintenance_plan(id)
);

-- TABLE: maintenance_auto_amendment_need  (satrlar: noma'lum)
CREATE TABLE maintenance_auto_amendment_need (
    operation_id uuid NOT NULL,
    order_id uuid NOT NULL,
    stock_id uuid NOT NULL,
    item_id uuid NOT NULL,
    unit text NOT NULL,
    quantity numeric(16,3) NOT NULL,
    material_source jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id, stock_id),
    FOREIGN KEY (operation_id) REFERENCES maintenance_auto_amendment(operation_id),
    FOREIGN KEY (order_id) REFERENCES maintenance_auto_order(id),
    FOREIGN KEY (stock_id) REFERENCES inventory_stock(id),
    CHECK ((quantity > (0)))
);

-- TABLE: maintenance_auto_booking  (satrlar: 0 — BO`SH)
CREATE TABLE maintenance_auto_booking (
    operation_id uuid NOT NULL,
    order_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    attempt_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    bay_id uuid NOT NULL,
    person_id uuid NOT NULL,
    bay_window_id uuid NOT NULL,
    person_window_id uuid NOT NULL,
    from_at timestamptz NOT NULL,
    to_at timestamptz NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'HELD', 'RELEASED'
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (order_id) REFERENCES maintenance_auto_order(id),
    FOREIGN KEY (plan_id) REFERENCES maintenance_plan(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id),
    CHECK ((to_at > from_at)),
    CHECK (state in ('HELD', 'RELEASED'))
);

-- TABLE: maintenance_auto_booking_closed  (satrlar: noma'lum)
CREATE TABLE maintenance_auto_booking_closed (
    operation_id uuid NOT NULL,
    order_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (order_id) REFERENCES maintenance_auto_order(id),
    FOREIGN KEY (plan_id) REFERENCES maintenance_plan(id)
);

-- TABLE: maintenance_auto_card  (satrlar: 0 — BO`SH)
CREATE TABLE maintenance_auto_card (
    operation_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'DRAFT', 'APPROVED', 'REVOKED'
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (plan_id) REFERENCES maintenance_plan(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id),
    CHECK (state in ('DRAFT', 'APPROVED', 'REVOKED'))
);

-- TABLE: maintenance_auto_closed  (satrlar: noma'lum)
CREATE TABLE maintenance_auto_closed (
    operation_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (plan_id) REFERENCES maintenance_plan(id)
);

-- TABLE: maintenance_auto_execution  (satrlar: 0 — BO`SH)
CREATE TABLE maintenance_auto_execution (
    operation_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    order_id uuid NOT NULL,
    attempt_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'STARTED', 'WORK_RECORDED', 'AWAITING_ACCEPTANCE', 'REWORK', 'ACCEPTED'
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    baseline jsonb,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (order_id) REFERENCES maintenance_auto_order(id),
    FOREIGN KEY (plan_id) REFERENCES maintenance_plan(id),
    CHECK (state in ('STARTED', 'WORK_RECORDED', 'AWAITING_ACCEPTANCE', 'REWORK', 'ACCEPTED'))
);

-- TABLE: maintenance_auto_execution_closed  (satrlar: noma'lum)
CREATE TABLE maintenance_auto_execution_closed (
    operation_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    order_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (order_id) REFERENCES maintenance_auto_order(id),
    FOREIGN KEY (plan_id) REFERENCES maintenance_plan(id)
);

-- TABLE: maintenance_auto_lifecycle  (satrlar: 0 — BO`SH)
CREATE TABLE maintenance_auto_lifecycle (
    operation_id uuid NOT NULL,
    order_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    attempt_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'OPEN', 'CANCELLED'
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (order_id) REFERENCES maintenance_auto_order(id),
    FOREIGN KEY (plan_id) REFERENCES maintenance_plan(id),
    CHECK (state in ('OPEN', 'CANCELLED'))
);

-- TABLE: maintenance_auto_lifecycle_closed  (satrlar: noma'lum)
CREATE TABLE maintenance_auto_lifecycle_closed (
    operation_id uuid NOT NULL,
    order_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (order_id) REFERENCES maintenance_auto_order(id),
    FOREIGN KEY (plan_id) REFERENCES maintenance_plan(id)
);

-- TABLE: maintenance_auto_material_need  (satrlar: noma'lum)
CREATE TABLE maintenance_auto_material_need (
    order_id uuid NOT NULL,
    stock_id uuid NOT NULL,
    item_id uuid NOT NULL,
    unit text NOT NULL,
    quantity numeric(16,3) NOT NULL,
    material_source jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (order_id, stock_id),
    FOREIGN KEY (order_id) REFERENCES maintenance_auto_order(id),
    FOREIGN KEY (stock_id) REFERENCES inventory_stock(id),
    CHECK ((quantity > (0)))
);

-- TABLE: maintenance_auto_order  (satrlar: 0 — BO`SH)
CREATE TABLE maintenance_auto_order (
    id uuid NOT NULL,
    plan_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    cycle_key text NOT NULL,
    card_operation_id uuid NOT NULL,
    sources jsonb NOT NULL,  -- [JSON matn]
    route_card jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    origin text NOT NULL,  -- RUXSAT: 'USAGE_EVENT', 'CARD_APPROVAL', 'CALENDAR_SCAN'
    created_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (card_operation_id) REFERENCES maintenance_auto_card(operation_id),
    FOREIGN KEY (plan_id) REFERENCES maintenance_plan(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id),
    CHECK (origin in ('USAGE_EVENT', 'CARD_APPROVAL', 'CALENDAR_SCAN'))
);

-- TABLE: maintenance_auto_repair_link  (satrlar: noma'lum)
CREATE TABLE maintenance_auto_repair_link (
    operation_id uuid NOT NULL,
    order_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    attempt_id uuid NOT NULL,
    repair_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (order_id) REFERENCES maintenance_auto_order(id),
    FOREIGN KEY (plan_id) REFERENCES maintenance_plan(id),
    FOREIGN KEY (repair_id) REFERENCES vehicle_repair(id)
);

-- TABLE: maintenance_auto_repair_link_closed  (satrlar: noma'lum)
CREATE TABLE maintenance_auto_repair_link_closed (
    operation_id uuid NOT NULL,
    order_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (order_id) REFERENCES maintenance_auto_order(id),
    FOREIGN KEY (plan_id) REFERENCES maintenance_plan(id)
);

-- TABLE: maintenance_auto_repair_material  (satrlar: noma'lum)
CREATE TABLE maintenance_auto_repair_material (
    order_id uuid NOT NULL,
    stock_id uuid NOT NULL,
    part_request_id uuid NOT NULL,
    link_operation_id uuid NOT NULL,
    PRIMARY KEY (link_operation_id, stock_id),
    FOREIGN KEY (link_operation_id) REFERENCES maintenance_auto_repair_link(operation_id),
    FOREIGN KEY (order_id) REFERENCES maintenance_auto_order(id),
    FOREIGN KEY (part_request_id) REFERENCES repair_order_part_request(id),
    FOREIGN KEY (stock_id) REFERENCES inventory_stock(id)
);

-- TABLE: maintenance_auto_runtime  (satrlar: noma'lum)
CREATE TABLE maintenance_auto_runtime (
    id boolean NOT NULL,
    enabled boolean NOT NULL,
    source_priority jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    CHECK (id),
    CHECK (((jsonb_typeof(source_priority) = 'array') and (jsonb_array_length(source_priority) <= 20)))
);

-- TABLE: maintenance_auto_scan  (satrlar: noma'lum)
CREATE TABLE maintenance_auto_scan (
    plan_id uuid NOT NULL,
    last_scanned_at timestamptz NOT NULL,
    failures integer NOT NULL,
    last_error text,
    PRIMARY KEY (plan_id),
    FOREIGN KEY (plan_id) REFERENCES maintenance_plan(id)
);

-- TABLE: maintenance_deferral  (satrlar: 0 — BO`SH)
CREATE TABLE maintenance_deferral (
    operation_id uuid NOT NULL,
    deferral_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    work_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'REQUESTED', 'APPROVED', 'REVOKED'
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (plan_id) REFERENCES maintenance_plan(id),
    CHECK (state in ('REQUESTED', 'APPROVED', 'REVOKED'))
);

-- TABLE: maintenance_deferral_closed  (satrlar: noma'lum)
CREATE TABLE maintenance_deferral_closed (
    operation_id uuid NOT NULL,
    deferral_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id)
);

-- TABLE: maintenance_deferral_policy  (satrlar: 0 — BO`SH)
CREATE TABLE maintenance_deferral_policy (
    operation_id uuid NOT NULL,
    policy_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'DRAFT', 'APPROVED', 'REVOKED'
    original jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (plan_id) REFERENCES maintenance_plan(id),
    CHECK (state in ('DRAFT', 'APPROVED', 'REVOKED'))
);

-- TABLE: maintenance_deferral_policy_closed  (satrlar: noma'lum)
CREATE TABLE maintenance_deferral_policy_closed (
    operation_id uuid NOT NULL,
    policy_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id)
);

-- TABLE: maintenance_deferral_use  (satrlar: noma'lum)
CREATE TABLE maintenance_deferral_use (
    grant_operation_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    work_id uuid NOT NULL,
    work_snapshot jsonb NOT NULL,  -- [JSON matn]
    evaluated_at timestamptz NOT NULL,
    PRIMARY KEY (grant_operation_id),
    FOREIGN KEY (grant_operation_id) REFERENCES maintenance_deferral(operation_id)
);

-- TABLE: maintenance_plan  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Texnik xizmat rejasi: xizmat turi (moy almashtirish, shina, tormoz, taqsimlash
-- tasmasi, texnik ko'rik), oxirgi xizmat sanasi va probegi, keyingi muddat
-- (next_due_at) va probeg (next_due_at_km).
-- status: ACTIVE, DUE_SOON, OVERDUE, PAUSED.
-- MUDDATI O'TGAN XIZMATLAR status='OVERDUE' bo'yicha olinadi.
-- DIQQAT: maintenance_plan jadvali ham mavjud — u TO_1/TO_2/SEASONAL
-- turidagi rejalashtirilgan TXKlar uchun va reysga chiqishni bloklashi mumkin
-- (blocked_on_overdue).
-- ---------------------------------------------------------------------
CREATE TABLE maintenance_plan (
    id uuid NOT NULL,
    assigned_mechanic varchar(255),
    blocked_on_overdue boolean NOT NULL,
    created_at timestamptz NOT NULL,
    current_engine_hours numeric(14,3),
    current_odometer_km numeric(14,3),
    interval_days integer,
    interval_engine_hours numeric(14,3),
    interval_km numeric(14,3),
    kind varchar(32),  -- RUXSAT: 'OIL_CHANGE', 'TIRE_ROTATION', 'BRAKE_INSPECTION', 'TIMING_BELT', 'TECH_INSPECTION', 'OTHER'
    last_serviced_at date,
    last_serviced_at_km numeric(14,3),
    maintenance_type varchar(32),  -- RUXSAT: 'TO_1', 'TO_2', 'SEASONAL', 'DIAGNOSTIC'
    next_due_at date,
    next_due_at_km numeric(14,3),
    next_due_engine_hours numeric(14,3),
    notes varchar(2000),
    status varchar(16) NOT NULL,  -- RUXSAT: 'PLANNED', 'ACTIVE', 'DUE_SOON', 'DUE', 'UNKNOWN', 'OVERDUE', 'PAUSED', 'COMPLETED'
    updated_at timestamptz NOT NULL,
    vehicle_id uuid NOT NULL,
    version bigint NOT NULL,
    last_serviced_engine_hours numeric(14,3),
    PRIMARY KEY (id),
    CHECK (kind in ('OIL_CHANGE', 'TIRE_ROTATION', 'BRAKE_INSPECTION', 'TIMING_BELT', 'TECH_INSPECTION', 'OTHER')),
    CHECK (maintenance_type in ('TO_1', 'TO_2', 'SEASONAL', 'DIAGNOSTIC')),
    CHECK (status in ('PLANNED', 'ACTIVE', 'DUE_SOON', 'DUE', 'UNKNOWN', 'OVERDUE', 'PAUSED', 'COMPLETED'))
);

-- TABLE: maintenance_release_decision  (satrlar: noma'lum)
CREATE TABLE maintenance_release_decision (
    id uuid NOT NULL,
    actor varchar(255) NOT NULL,
    allowed boolean NOT NULL,
    evaluated_at timestamptz NOT NULL,
    evidence_json text NOT NULL,  -- [JSON matn]
    origin varchar(100) NOT NULL,
    vehicle_id uuid NOT NULL,
    work_id uuid,
    PRIMARY KEY (id)
);

-- TABLE: maintenance_resource_window  (satrlar: 0 — BO`SH)
CREATE TABLE maintenance_resource_window (
    operation_id uuid NOT NULL,
    window_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    resource_kind text NOT NULL,  -- RUXSAT: 'BAY', 'PERSON'
    resource_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'DRAFT', 'APPROVED', 'REVOKED'
    original jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (plan_id) REFERENCES maintenance_plan(id),
    CHECK (resource_kind in ('BAY', 'PERSON')),
    CHECK (state in ('DRAFT', 'APPROVED', 'REVOKED'))
);

-- TABLE: maintenance_resource_window_closed  (satrlar: noma'lum)
CREATE TABLE maintenance_resource_window_closed (
    operation_id uuid NOT NULL,
    window_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (plan_id) REFERENCES maintenance_plan(id)
);

-- TABLE: manual_driver  (satrlar: noma'lum)
CREATE TABLE manual_driver (
    id uuid NOT NULL,
    full_name varchar(256) NOT NULL,
    license_number varchar(64),
    phone varchar(32),
    employee_code varchar(64),
    branch_id uuid,
    driver_entity_id uuid,
    is_active boolean NOT NULL,
    created_by varchar(128),
    created_at timestamptz,
    updated_at timestamptz,
    is_temporary boolean NOT NULL,
    temporary_registered_by varchar(128),
    temporary_registered_at timestamptz,
    PRIMARY KEY (id)
);

-- TABLE: material_demand  (satrlar: noma'lum)
CREATE TABLE material_demand (
    part_request_id uuid NOT NULL,
    available numeric(16,3),
    branch_id uuid,
    own_reserved numeric(16,3),
    reason varchar(100),
    request_version bigint,
    requested_remaining numeric(16,3),
    shortage numeric(16,3),
    stock_id uuid,
    stock_version bigint,
    updated_at timestamptz NOT NULL,
    version bigint,
    PRIMARY KEY (part_request_id),
    FOREIGN KEY (part_request_id) REFERENCES repair_order_part_request(id),
    FOREIGN KEY (stock_id) REFERENCES inventory_stock(id)
);

-- TABLE: material_exchange_attempt  (satrlar: 0 — BO`SH)
CREATE TABLE material_exchange_attempt (
    operation_id uuid NOT NULL,
    attempts integer NOT NULL,
    created_at timestamptz NOT NULL,
    envelope_json text,  -- [JSON matn]
    error_code varchar(100),
    lease_token uuid,  -- [MAXFIY — o'qish taqiqlangan]
    lease_until timestamptz,
    lookup_required boolean NOT NULL,
    mutation_started_at timestamptz,
    next_attempt_at timestamptz,
    owner_epoch bigint NOT NULL,
    payload_hash varchar(64) NOT NULL,
    payload_json text NOT NULL,  -- [JSON matn]
    protocol varchar(100),
    provider varchar(100),
    state varchar(32) NOT NULL,  -- RUXSAT: 'PENDING', 'PROCESSING', 'AWAITING_RECEIPT', 'UNKNOWN', 'CONFIRMED', 'REJECTED'
    updated_at timestamptz NOT NULL,
    version bigint,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (operation_id) REFERENCES material_operation(id),
    CHECK (state in ('PENDING', 'PROCESSING', 'AWAITING_RECEIPT', 'UNKNOWN', 'CONFIRMED', 'REJECTED'))
);

-- TABLE: material_exchange_recovery  (satrlar: noma'lum)
CREATE TABLE material_exchange_recovery (
    id uuid NOT NULL,
    actor varchar(255) NOT NULL,
    attempt_base_version bigint NOT NULL,
    basis varchar(2000) NOT NULL,
    operation_id uuid NOT NULL,
    payload_identity varchar(64) NOT NULL,
    requested_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (operation_id) REFERENCES material_operation(id)
);

-- TABLE: material_expected_supply  (satrlar: 0 — BO`SH)
CREATE TABLE material_expected_supply (
    id uuid NOT NULL,
    accepted_at timestamptz NOT NULL,
    confirmed_at timestamptz NOT NULL,
    document_id varchar(255) NOT NULL,
    expected_at timestamptz NOT NULL,
    line_id varchar(255) NOT NULL,
    owner_epoch bigint NOT NULL,
    payload_identity varchar(64) NOT NULL,
    protocol varchar(100) NOT NULL,
    provider varchar(100) NOT NULL,
    receipt_id varchar(200) NOT NULL,
    remaining_quantity numeric(16,3) NOT NULL,
    source_revision bigint NOT NULL,
    status varchar(32) NOT NULL,
    stock_id uuid NOT NULL,
    unit varchar(32) NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (stock_id) REFERENCES inventory_stock(id)
);

-- TABLE: material_external_receipt  (satrlar: noma'lum)
CREATE TABLE material_external_receipt (
    id uuid NOT NULL,
    accepted_at timestamptz NOT NULL,
    actual_quantity numeric(16,3) NOT NULL,
    confirmed_at timestamptz NOT NULL,
    external_document varchar(255) NOT NULL,
    operation_id uuid NOT NULL,
    outcome varchar(32) NOT NULL,
    owner_epoch bigint NOT NULL,
    payload_hash varchar(64) NOT NULL,
    payload_identity varchar(64) NOT NULL,
    protocol varchar(100) NOT NULL,
    provider varchar(100) NOT NULL,
    receipt_id varchar(200) NOT NULL,
    source_revision bigint NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (operation_id) REFERENCES material_operation(id)
);

-- TABLE: material_item_policy  (satrlar: 0 — BO`SH)
CREATE TABLE material_item_policy (
    item_id uuid NOT NULL,
    base_unit varchar(32),
    basis varchar(2000) NOT NULL,
    recorded_by varchar(255) NOT NULL,
    source varchar(100) NOT NULL,
    tracking varchar(24) NOT NULL,  -- RUXSAT: 'UNCONFIGURED', 'CONSUMABLE', 'SERIALIZED', 'RESOURCE'
    updated_at timestamptz NOT NULL,
    usage_counter varchar(32),  -- RUXSAT: 'ODOMETER_KM', 'ENGINE_HOURS'
    version bigint,
    PRIMARY KEY (item_id),
    CHECK (tracking in ('UNCONFIGURED', 'CONSUMABLE', 'SERIALIZED', 'RESOURCE')),
    CHECK (usage_counter in ('ODOMETER_KM', 'ENGINE_HOURS'))
);

-- TABLE: material_movement  (satrlar: noma'lum)
CREATE TABLE material_movement (
    id uuid NOT NULL,
    item_id uuid NOT NULL,
    leg integer NOT NULL,
    operation_id uuid NOT NULL,
    posted_at timestamptz NOT NULL,
    quarantine_delta numeric(16,3) NOT NULL,
    stock_id uuid NOT NULL,
    unit varchar(32) NOT NULL,
    usable_delta numeric(16,3) NOT NULL,
    warehouse_id uuid,
    PRIMARY KEY (id),
    FOREIGN KEY (operation_id) REFERENCES material_operation(id),
    FOREIGN KEY (stock_id) REFERENCES inventory_stock(id)
);

-- TABLE: material_operation  (satrlar: 0 — BO`SH)
CREATE TABLE material_operation (
    id uuid NOT NULL,
    actor varchar(255) NOT NULL,
    actual_quantity numeric(16,3),
    basis varchar(2000) NOT NULL,
    branch_id uuid,
    created_at timestamptz NOT NULL,
    currency varchar(8),
    disposition varchar(32),
    external_document varchar(255),
    external_receipt_id varchar(200),
    item_id uuid,
    kind varchar(40) NOT NULL,  -- RUXSAT: 'OPENING', 'RECEIPT', 'ISSUE', 'USE', 'REQUEST_RETURN', 'ACCEPT_RETURN', 'ADJUSTMENT', 'TRANSFER'
    owner varchar(20) NOT NULL,
    owner_epoch bigint NOT NULL,
    part_request_id uuid,
    payload_identity varchar(3000) NOT NULL,
    posted_at timestamptz,
    quantity numeric(16,3) NOT NULL,
    quarantine_delta numeric(16,3) NOT NULL,
    repair_order_id uuid,
    status varchar(40) NOT NULL,  -- RUXSAT: 'POSTED', 'PENDING_EXTERNAL', 'UNKNOWN', 'DISCREPANCY', 'REJECTED'
    stock_delta numeric(16,3) NOT NULL,
    stock_id uuid NOT NULL,
    target_owner_epoch bigint,
    target_stock_id uuid,
    target_warehouse_id uuid,
    unit varchar(32) NOT NULL,
    unit_price numeric(16,2),
    vehicle_id uuid,
    version bigint,
    warehouse_id uuid,
    PRIMARY KEY (id),
    FOREIGN KEY (part_request_id) REFERENCES repair_order_part_request(id),
    FOREIGN KEY (repair_order_id) REFERENCES vehicle_repair(id),
    FOREIGN KEY (stock_id) REFERENCES inventory_stock(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id),
    CHECK (kind in ('OPENING', 'RECEIPT', 'ISSUE', 'USE', 'REQUEST_RETURN', 'ACCEPT_RETURN', 'ADJUSTMENT', 'TRANSFER')),
    CHECK (status in ('POSTED', 'PENDING_EXTERNAL', 'UNKNOWN', 'DISCREPANCY', 'REJECTED'))
);

-- TABLE: material_owner_attestation  (satrlar: noma'lum)
CREATE TABLE material_owner_attestation (
    id uuid NOT NULL,
    accepted_at timestamptz NOT NULL,
    confirmed_at timestamptz NOT NULL,
    epoch bigint NOT NULL,
    external_document varchar(255) NOT NULL,
    kind varchar(32) NOT NULL,
    payload_identity varchar(64) NOT NULL,
    protocol varchar(100) NOT NULL,
    provider varchar(100) NOT NULL,
    receipt_id varchar(200) NOT NULL,
    reconciliation_hash varchar(64) NOT NULL,
    source_revision bigint NOT NULL,
    warehouse_id uuid NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (warehouse_id) REFERENCES material_owner_policy(warehouse_id)
);

-- TABLE: material_owner_cutover  (satrlar: 0 — BO`SH)
CREATE TABLE material_owner_cutover (
    id uuid NOT NULL,
    abort_base_version bigint,
    abort_basis varchar(2000),
    aborted_at timestamptz,
    aborted_by varchar(255),
    activated_at timestamptz,
    activation_base_version bigint,
    activation_basis varchar(2000),
    actor varchar(255) NOT NULL,
    basis varchar(2000) NOT NULL,
    from_epoch bigint NOT NULL,
    from_owner varchar(20) NOT NULL,
    payload_identity varchar(64) NOT NULL,
    prepared_at timestamptz NOT NULL,
    reconciliation_hash varchar(64),
    status varchar(20) NOT NULL,
    target_owner varchar(20) NOT NULL,
    warehouse_id uuid NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (warehouse_id) REFERENCES material_owner_policy(warehouse_id)
);

-- TABLE: material_owner_policy  (satrlar: 0 — BO`SH)
CREATE TABLE material_owner_policy (
    warehouse_id uuid NOT NULL,
    actor varchar(255) NOT NULL,
    basis varchar(2000) NOT NULL,
    epoch bigint NOT NULL,
    initialization_id uuid NOT NULL,
    initialization_identity varchar(64) NOT NULL,
    owner varchar(20) NOT NULL,  -- RUXSAT: 'UNCONFIGURED', 'ATIL', 'ERP_WMS'
    pending_cutover_id uuid,
    phase varchar(20) NOT NULL,  -- RUXSAT: 'ACTIVE', 'FROZEN'
    updated_at timestamptz NOT NULL,
    version bigint,
    PRIMARY KEY (warehouse_id),
    CHECK (owner in ('UNCONFIGURED', 'ATIL', 'ERP_WMS')),
    CHECK (phase in ('ACTIVE', 'FROZEN'))
);

-- TABLE: material_procurement_link  (satrlar: noma'lum)
CREATE TABLE material_procurement_link (
    id uuid NOT NULL,
    basis varchar(2000) NOT NULL,
    document_id varchar(255) NOT NULL,
    kind varchar(32) NOT NULL,
    line_id varchar(255) NOT NULL,
    need_id uuid NOT NULL,
    payload_identity varchar(64) NOT NULL,
    provider varchar(100) NOT NULL,
    recorded_at timestamptz NOT NULL,
    recorded_by varchar(255) NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (need_id) REFERENCES material_procurement_need(id)
);

-- TABLE: material_procurement_need  (satrlar: noma'lum)
CREATE TABLE material_procurement_need (
    id uuid NOT NULL,
    basis varchar(2000) NOT NULL,
    branch_id uuid,
    part_request_id uuid NOT NULL,
    payload_identity varchar(64) NOT NULL,
    quantity numeric(16,3) NOT NULL,
    recorded_at timestamptz NOT NULL,
    recorded_by varchar(255) NOT NULL,
    required_by timestamptz NOT NULL,
    snapshot_hash varchar(64) NOT NULL,
    snapshot_json text NOT NULL,  -- [JSON matn]
    stock_id uuid NOT NULL,
    unit varchar(32) NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (part_request_id) REFERENCES repair_order_part_request(id),
    FOREIGN KEY (stock_id) REFERENCES inventory_stock(id)
);

-- TABLE: material_receipt_dispatch_profile  (satrlar: noma'lum)
CREATE TABLE material_receipt_dispatch_profile (
    operation_id uuid NOT NULL,
    provider_id varchar(64) NOT NULL,
    provider_revision bigint NOT NULL,
    protocol varchar(100) NOT NULL,
    profile_contract jsonb NOT NULL,  -- [JSON matn]
    profile_hash varchar(64) NOT NULL,
    owner_epoch bigint NOT NULL,
    payload_hash varchar(64) NOT NULL,
    command_hash varchar(64) NOT NULL,
    envelope_hash varchar(64) NOT NULL,
    envelope_original text NOT NULL,
    scope jsonb NOT NULL,  -- [JSON matn]
    branch_id uuid NOT NULL,
    branch_ids jsonb NOT NULL,  -- [JSON matn]
    operation_version bigint NOT NULL,
    attempt_version bigint NOT NULL,
    attempt_number integer NOT NULL,
    prepared_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (operation_id) REFERENCES material_operation(id),
    CHECK ((attempt_number > 0)),
    CHECK (((jsonb_typeof(branch_ids) = 'array') and (jsonb_array_length(branch_ids) > 0))),
    CHECK ((provider_revision > 0))
);

-- TABLE: material_receipt_machine_witness  (satrlar: noma'lum)
CREATE TABLE material_receipt_machine_witness (
    receipt_evidence_id uuid NOT NULL,
    operation_id uuid NOT NULL,
    machine_id varchar(64) NOT NULL,
    provider_id varchar(64) NOT NULL,
    provider_revision bigint NOT NULL,
    protocol varchar(100) NOT NULL,
    branch_id uuid NOT NULL,
    branch_ids jsonb NOT NULL,  -- [JSON matn]
    owner_epoch bigint NOT NULL,
    payload_hash varchar(64) NOT NULL,
    event_key varchar(36) NOT NULL,
    operation_version bigint NOT NULL,
    attempt_version bigint NOT NULL,
    attempt_number integer NOT NULL,
    source_revision bigint NOT NULL,
    accepted_status varchar(40) NOT NULL,
    typed_identity varchar(64) NOT NULL,
    original_hash varchar(64) NOT NULL,
    raw_original text NOT NULL,
    principal_scope jsonb NOT NULL,  -- [JSON matn]
    canonical_scope jsonb NOT NULL,  -- [JSON matn]
    witnessed_at timestamptz NOT NULL,
    PRIMARY KEY (receipt_evidence_id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (operation_id) REFERENCES material_receipt_dispatch_profile(operation_id),
    FOREIGN KEY (receipt_evidence_id) REFERENCES material_external_receipt(id),
    CHECK (((original_hash) = encode(sha256(convert_to(raw_original, 'utf8'::name)), 'hex')))
);

-- TABLE: material_receipt_readback_witness  (satrlar: noma'lum)
CREATE TABLE material_receipt_readback_witness (
    receipt_evidence_id uuid NOT NULL,
    operation_id uuid NOT NULL,
    provider_id varchar(64) NOT NULL,
    provider_revision bigint NOT NULL,
    protocol varchar(100) NOT NULL,
    branch_id uuid NOT NULL,
    branch_ids jsonb NOT NULL,  -- [JSON matn]
    owner_epoch bigint NOT NULL,
    payload_hash varchar(64) NOT NULL,
    event_key varchar(36) NOT NULL,
    operation_version bigint NOT NULL,
    attempt_version bigint NOT NULL,
    attempt_number integer NOT NULL,
    source_revision bigint NOT NULL,
    accepted_status varchar(40) NOT NULL,
    typed_identity varchar(64) NOT NULL,
    original_hash varchar(64) NOT NULL,
    raw_original text NOT NULL,
    canonical_scope jsonb NOT NULL,  -- [JSON matn]
    request_uri text NOT NULL,
    http_status integer NOT NULL,
    observed_at timestamptz NOT NULL,
    policy_type varchar(64) NOT NULL,
    policy_id uuid NOT NULL,
    policy_version bigint NOT NULL,
    witnessed_at timestamptz NOT NULL,
    PRIMARY KEY (receipt_evidence_id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (operation_id) REFERENCES material_receipt_dispatch_profile(operation_id),
    FOREIGN KEY (policy_id) REFERENCES integration_exchange_provider(operation_id),
    FOREIGN KEY (receipt_evidence_id) REFERENCES material_external_receipt(id),
    CHECK (((original_hash) = encode(sha256(convert_to(raw_original, 'utf8'::name)), 'hex'))),
    CHECK (((http_status >= 200) and (http_status < 300))),
    CHECK (((policy_type) = 'material_readback'))
);

-- TABLE: material_reservation  (satrlar: 0 — BO`SH)
CREATE TABLE material_reservation (
    id uuid NOT NULL,
    actor varchar(255) NOT NULL,
    basis varchar(2000) NOT NULL,
    branch_id uuid,
    created_at timestamptz NOT NULL,
    part_request_id uuid NOT NULL,
    payload_identity varchar(64) NOT NULL,
    quantity numeric(16,3) NOT NULL,
    release_base_version bigint,
    release_basis varchar(2000),
    released_by varchar(255),
    remaining_quantity numeric(16,3) NOT NULL,
    repair_order_id uuid NOT NULL,
    status varchar(24) NOT NULL,  -- RUXSAT: 'ACTIVE', 'CONSUMED', 'RELEASED'
    stock_id uuid NOT NULL,
    unit varchar(32) NOT NULL,
    updated_at timestamptz NOT NULL,
    version bigint,
    PRIMARY KEY (id),
    FOREIGN KEY (part_request_id) REFERENCES repair_order_part_request(id),
    FOREIGN KEY (repair_order_id) REFERENCES vehicle_repair(id),
    FOREIGN KEY (stock_id) REFERENCES inventory_stock(id),
    CHECK (status in ('ACTIVE', 'CONSUMED', 'RELEASED'))
);

-- TABLE: material_reservation_resolution  (satrlar: noma'lum)
CREATE TABLE material_reservation_resolution (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    outcome varchar(32) NOT NULL,
    quantity numeric(16,3) NOT NULL,
    receipt_id uuid NOT NULL,
    use_id uuid NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (receipt_id) REFERENCES material_external_receipt(id),
    FOREIGN KEY (use_id) REFERENCES material_reservation_use(id)
);

-- TABLE: material_reservation_use  (satrlar: noma'lum)
CREATE TABLE material_reservation_use (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    destination varchar(32) NOT NULL,
    operation_id uuid NOT NULL,
    quantity numeric(16,3) NOT NULL,
    reservation_id uuid NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (operation_id) REFERENCES material_operation(id),
    FOREIGN KEY (reservation_id) REFERENCES material_reservation(id)
);

-- TABLE: material_serial_allocation  (satrlar: 0 — BO`SH)
CREATE TABLE material_serial_allocation (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    issue_operation_id uuid NOT NULL,
    last_operation_id uuid,
    part_id uuid NOT NULL,
    part_request_id uuid NOT NULL,
    released_at timestamptz,
    state varchar(32) NOT NULL,  -- RUXSAT: 'ISSUED', 'INSTALLED', 'RETURN_REQUESTED', 'RETURNED_USABLE', 'RETURNED_QUARANTINE', 'RETURNED_QUARANTINE_DISPOSED'
    stock_id uuid NOT NULL,
    version bigint,
    PRIMARY KEY (id),
    FOREIGN KEY (issue_operation_id) REFERENCES material_serial_command(id),
    FOREIGN KEY (part_id) REFERENCES vehicle_part(id),
    FOREIGN KEY (part_request_id) REFERENCES repair_order_part_request(id),
    FOREIGN KEY (stock_id) REFERENCES inventory_stock(id),
    CHECK (((released_at is not null) = ((state) = any ((array['returned_usable', 'returned_quarantine_disposed'])[])))),
    CHECK (state in ('ISSUED', 'INSTALLED', 'RETURN_REQUESTED', 'RETURNED_USABLE', 'RETURNED_QUARANTINE', 'RETURNED_QUARANTINE_DISPOSED')),
    CHECK (state in ('ISSUED', 'INSTALLED', 'RETURN_REQUESTED', 'RETURNED_USABLE', 'RETURNED_QUARANTINE', 'RETURNED_QUARANTINE_DISPOSED'))
);

-- TABLE: material_serial_command  (satrlar: 0 — BO`SH)
CREATE TABLE material_serial_command (
    id uuid NOT NULL,
    actor varchar(255) NOT NULL,
    created_at timestamptz NOT NULL,
    kind varchar(32) NOT NULL,  -- RUXSAT: 'OPENING', 'RECEIPT', 'ISSUE', 'USE', 'REQUEST_RETURN', 'ACCEPT_RETURN', 'ADJUSTMENT', 'TRANSFER'
    part_request_id uuid NOT NULL,
    passport_ids text NOT NULL,
    payload_identity text NOT NULL,
    stock_id uuid NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (part_request_id) REFERENCES repair_order_part_request(id),
    FOREIGN KEY (stock_id) REFERENCES inventory_stock(id),
    CHECK (kind in ('OPENING', 'RECEIPT', 'ISSUE', 'USE', 'REQUEST_RETURN', 'ACCEPT_RETURN', 'ADJUSTMENT', 'TRANSFER'))
);

-- TABLE: material_serial_external_hold  (satrlar: 0 — BO`SH)
CREATE TABLE material_serial_external_hold (
    operation_id uuid NOT NULL,
    part_id uuid NOT NULL,
    part_request_id uuid NOT NULL,
    stock_id uuid NOT NULL,
    kind text NOT NULL,  -- RUXSAT: 'ISSUE', 'ACCEPT_RETURN'
    owner_epoch bigint NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    original_hash text NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'HELD', 'CONFIRMED', 'RELEASED'
    receipt_id text,
    finished_at timestamptz,
    PRIMARY KEY (operation_id, part_id),
    FOREIGN KEY (operation_id) REFERENCES material_serial_command(id),
    FOREIGN KEY (part_id) REFERENCES vehicle_part(id),
    FOREIGN KEY (part_request_id) REFERENCES repair_order_part_request(id),
    FOREIGN KEY (stock_id) REFERENCES inventory_stock(id),
    CHECK (((state = 'held') = ((receipt_id is null) and (finished_at is null)))),
    CHECK (kind in ('ISSUE', 'ACCEPT_RETURN')),
    CHECK ((original_hash ~ '^[a-f0-9]{64}$')),
    CHECK (state in ('HELD', 'CONFIRMED', 'RELEASED'))
);

-- TABLE: material_serial_external_receipt  (satrlar: noma'lum)
CREATE TABLE material_serial_external_receipt (
    receipt_evidence_id uuid NOT NULL,
    operation_id uuid NOT NULL,
    serials jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (receipt_evidence_id),
    FOREIGN KEY (operation_id) REFERENCES material_serial_command(id),
    FOREIGN KEY (receipt_evidence_id) REFERENCES material_external_receipt(id),
    CHECK ((jsonb_typeof(serials) = 'array'))
);

-- TABLE: material_stock_document  (satrlar: 0 — BO`SH)
CREATE TABLE material_stock_document (
    id uuid NOT NULL,
    kind varchar(32) NOT NULL,  -- RUXSAT: 'RECEIPT', 'COUNT', 'TRANSFER'
    payload_identity varchar(64) NOT NULL,
    recorded_at timestamptz NOT NULL,
    source varchar(100) NOT NULL,
    source_document varchar(200) NOT NULL,
    source_line varchar(100) NOT NULL,
    source_revision bigint NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (id) REFERENCES material_operation(id),
    CHECK (kind in ('RECEIPT', 'COUNT', 'TRANSFER'))
);

-- TABLE: material_stock_threshold  (satrlar: noma'lum)
CREATE TABLE material_stock_threshold (
    stock_id uuid NOT NULL,
    basis varchar(2000) NOT NULL,
    critical_quantity numeric(16,3) NOT NULL,
    minimum_quantity numeric(16,3) NOT NULL,
    recorded_by varchar(255) NOT NULL,
    unit varchar(32) NOT NULL,
    updated_at timestamptz NOT NULL,
    version bigint,
    PRIMARY KEY (stock_id),
    FOREIGN KEY (stock_id) REFERENCES inventory_stock(id)
);

-- TABLE: medical_inspection  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Smenaga chiqish oldidan tibbiy ko'rik: qon bosimi, puls, harorat, ko'rik natijasi
-- va amal qilish muddati (to_date). status: FIT (yaroqli), RESTRICTED (cheklangan),
-- UNFIT (yaroqsiz), CANCELLED.
-- HAYDOVCHI BUGUN TIBBIY KO'RIKDAN O'TGANMI SO'RALSA shift_date va status
-- bo'yicha olinadi (status='FIT' bo'lsa o'tgan). driver.medical_cleared_today
-- ni ISHLATMANG: u eskirgan bayroq, yuqoridagi izohga qarang.
-- ---------------------------------------------------------------------
CREATE TABLE medical_inspection (
    id uuid NOT NULL,
    alcohol_promille numeric(5,3),
    assigned_vehicle_id uuid,
    blood_pressure varchar(32),
    created_at timestamptz NOT NULL,
    department_id uuid,
    driver_id uuid NOT NULL,
    driver_name varchar(256) NOT NULL,
    employee_id varchar(64),
    inspected_at timestamptz NOT NULL,
    medic_name varchar(256),
    medic_user_id varchar(128),
    notes varchar(1024),
    pulse_bpm integer,
    shift_date date NOT NULL,
    status varchar(32) NOT NULL,  -- RUXSAT: 'FIT', 'RESTRICTED', 'UNFIT', 'CANCELLED'; BAZADA: 'FIT' 4318, 'CANCELLED' 400, 'UNFIT' 3, 'RESTRICTED' 1
    temperature_c numeric(4,1),
    to_date date NOT NULL,
    updated_at timestamptz NOT NULL,
    branch_id uuid,
    trip_id uuid,
    waybill_id uuid,
    driver_signature text,
    alcohol_prohibited boolean,
    alcohol_reading numeric(14,6),
    alcohol_unit varchar(64),
    applied_regulation_id uuid,
    applied_regulation_json text,  -- [JSON matn]
    applied_regulation_version bigint,
    rule_assessment_reason varchar(128),
    rule_assessment_state varchar(32),
    valid_from timestamptz,
    valid_to timestamptz,
    object_version bigint NOT NULL,
    PRIMARY KEY (id),
    CHECK (status in ('FIT', 'RESTRICTED', 'UNFIT', 'CANCELLED'))
);

-- TABLE: medical_inspection_revision  (satrlar: noma'lum)
CREATE TABLE medical_inspection_revision (
    id uuid NOT NULL,
    action varchar(32) NOT NULL,
    actor_id uuid NOT NULL,
    actor_name varchar(256) NOT NULL,
    after_json text NOT NULL,  -- [JSON matn]
    before_json text,  -- [JSON matn]
    inspection_id uuid NOT NULL,
    occurred_at timestamptz NOT NULL,
    reason varchar(1000) NOT NULL,
    version_after bigint NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (inspection_id) REFERENCES medical_inspection(id)
);

-- TABLE: medical_monthly_alcohol_report  (satrlar: noma'lum)
CREATE TABLE medical_monthly_alcohol_report (
    id uuid NOT NULL,
    branch_id uuid,
    created_at timestamptz NOT NULL,
    medic_name varchar(256),
    medic_user_id uuid,
    report_month integer NOT NULL,
    notes varchar(1024),
    status varchar(32) NOT NULL,  -- RUXSAT: 'DRAFT', 'FINALIZED'; BAZADA: 'FINALIZED' 17, 'DRAFT' 11
    total_count bigint NOT NULL,
    total_meta_count bigint NOT NULL,
    total_mg_negative_count bigint NOT NULL,
    total_mg_positive_count bigint NOT NULL,
    updated_at timestamptz NOT NULL,
    report_year integer NOT NULL,
    PRIMARY KEY (id),
    CHECK (status in ('DRAFT', 'FINALIZED'))
);

-- TABLE: medical_monthly_alcohol_report_row  (satrlar: noma'lum)
CREATE TABLE medical_monthly_alcohol_report_row (
    id uuid NOT NULL,
    display_order integer NOT NULL,
    meta_count bigint NOT NULL,
    mg_negative_count bigint NOT NULL,
    mg_positive_count bigint NOT NULL,
    sex_name varchar(256) NOT NULL,
    sex_number varchar(64) NOT NULL,
    source varchar(32) NOT NULL,  -- RUXSAT: 'AUTO', 'MANUAL'; BAZADA: 'AUTO' 56, 'MANUAL' 45
    total_count bigint NOT NULL,
    report_id uuid NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (report_id) REFERENCES medical_monthly_alcohol_report(id),
    CHECK (source in ('AUTO', 'MANUAL'))
);

-- TABLE: medical_regulation  (satrlar: noma'lum)
CREATE TABLE medical_regulation (
    id uuid NOT NULL,
    alcohol_forbidden_boundary numeric(14,6),
    alcohol_unit varchar(64),
    allow_standalone_for_operational_context boolean,
    branch_id uuid NOT NULL,
    forbid_at_boundary boolean,
    max_examination_age_seconds bigint,
    max_validity_seconds bigint,
    reading_required boolean,
    regulation_reference varchar(512),
    state varchar(32) NOT NULL,
    time_zone varchar(64) NOT NULL,
    updated_at timestamptz NOT NULL,
    updated_by uuid NOT NULL,
    valid_from timestamptz,
    valid_to timestamptz,
    version bigint NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: medical_regulation_revision  (satrlar: noma'lum)
CREATE TABLE medical_regulation_revision (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    actor_name varchar(256) NOT NULL,
    after_json text NOT NULL,  -- [JSON matn]
    before_json text,  -- [JSON matn]
    occurred_at timestamptz NOT NULL,
    reason varchar(1000) NOT NULL,
    regulation_id uuid NOT NULL,
    version_after bigint NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (regulation_id) REFERENCES medical_regulation(id)
);

-- TABLE: medical_release_evidence  (satrlar: noma'lum)
CREATE TABLE medical_release_evidence (
    id uuid NOT NULL,
    action varchar(32) NOT NULL,
    actor_id uuid NOT NULL,
    actor_name varchar(256) NOT NULL,
    occurred_at timestamptz NOT NULL,
    physical_departure_at timestamptz,
    physical_departure_json text,  -- [JSON matn]
    physical_departure_local varchar(64),
    physical_departure_zone varchar(64),
    proof_hash varchar(64) NOT NULL,
    proof_json text NOT NULL,  -- [JSON matn]
    target_id uuid NOT NULL,
    target_type varchar(32) NOT NULL,
    target_version bigint NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: monthly_statement_approval  (satrlar: noma'lum)
CREATE TABLE monthly_statement_approval (
    id uuid NOT NULL,
    approved_at timestamptz NOT NULL,
    approved_by varchar(256) NOT NULL,
    calculation_version integer NOT NULL,
    notes text,
    report_month varchar(7) NOT NULL,
    scope_key varchar(36) NOT NULL,
    snapshot_json text NOT NULL,  -- [JSON matn]
    snapshot_sha256 varchar(64) NOT NULL,
    version bigint,
    PRIMARY KEY (id)
);

-- TABLE: notification  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Foydalanuvchiga yuborilgan bildirishnomalar: yoqilg'i limitiga yaqinlashish,
-- limit oshib ketishi, credential muddati tugashi, noma'lum credential ishlatilishi.
-- severity: INFO, WARNING, CRITICAL. read_at bo'sh bo'lsa — o'qilmagan.
-- reference_id bildirishnoma tegishli obyektni ko'rsatadi.
-- ---------------------------------------------------------------------
CREATE TABLE notification (
    id uuid NOT NULL,
    body text,
    created_at timestamptz NOT NULL,
    driver_id uuid,
    kind varchar(48) NOT NULL,  -- RUXSAT: 'FUEL_RECALL_ACTION_REQUIRED', 'FUEL_RECALL_ESCALATION', 'FUEL_LIMIT_THRESHOLD_APPROACHING', 'FUEL_LIMIT_EXCEEDED', 'CREDENTIAL_EXPIRING_SOON', 'UNKNOWN_CREDENTIAL_USED', 'REPAIR_ORDER_EVENT', 'TRANSPORT_REQUEST_APPROVAL_REQUIRED', 'TRANSPORT_REQUEST_APPROVED', 'TRANSPORT_REQUEST_REJECTED', 'TRANSPORT_REQUEST_ACTION_REQUIRED', 'MEDICAL_INSPECTION_REQUIRED', 'TECHNICAL_INSPECTION_REQUIRED', 'POST_TRIP_INSPECTION_REQUIRED', 'TRIP_READY_TO_START', 'WAYBILL_READY_TO_CLOSE', 'OPERATIONAL_ACTION_REQUIRED', 'OPERATIONAL_SLA_ESCALATION', 'CUSTOMER_CONFIRMATION_REQUIRED', 'CUSTOMER_DISPUTED'; BAZADA: 'TECHNICAL_INSPECTION_REQUIRED' 20314, 'TRIP_READY_TO_START' 11911, 'WAYBILL_READY_TO_CLOSE' 10635, 'MEDICAL_INSPECTION_REQUIRED' 10418, 'TRANSPORT_REQUEST_ACTION_REQUIRED' 7536, 'POST_TRIP_INSPECTION_REQUIRED' 6074, 'TRANSPORT_REQUEST_APPROVED' 756, 'CUSTOMER_CONFIRMATION_REQUIRED' 651, 'REPAIR_ORDER_EVENT' 64, 'TRANSPORT_REQUEST_APPROVAL_REQUIRED' 36; ISHLATILMAGAN: FUEL_RECALL_ACTION_REQUIRED, FUEL_RECALL_ESCALATION, FUEL_LIMIT_THRESHOLD_APPROACHING, FUEL_LIMIT_EXCEEDED, CREDENTIAL_EXPIRING_SOON, UNKNOWN_CREDENTIAL_USED, TRANSPORT_REQUEST_REJECTED, OPERATIONAL_ACTION_REQUIRED, OPERATIONAL_SLA_ESCALATION, CUSTOMER_DISPUTED
    read_at timestamptz,
    reference_id uuid,
    severity varchar(16) NOT NULL,  -- RUXSAT: 'INFO', 'WARNING', 'CRITICAL'; BAZADA: 'WARNING' 37182; ISHLATILMAGAN: INFO, CRITICAL
    title varchar(256) NOT NULL,
    vehicle_id uuid,
    action_type varchar(64),
    action_url varchar(512),
    dedupe_key varchar(256),
    entity_id uuid,
    entity_number varchar(64),
    entity_type varchar(64),
    metadata text,
    recipient_user_id uuid,
    PRIMARY KEY (id),
    CHECK (kind in ('FUEL_RECALL_ACTION_REQUIRED', 'FUEL_RECALL_ESCALATION', 'FUEL_LIMIT_THRESHOLD_APPROACHING', 'FUEL_LIMIT_EXCEEDED', 'CREDENTIAL_EXPIRING_SOON', 'UNKNOWN_CREDENTIAL_USED', 'REPAIR_ORDER_EVENT', 'TRANSPORT_REQUEST_APPROVAL_REQUIRED', 'TRANSPORT_REQUEST_APPROVED', 'TRANSPORT_REQUEST_REJECTED', 'TRANSPORT_REQUEST_ACTION_REQUIRED', 'MEDICAL_INSPECTION_REQUIRED', 'TECHNICAL_INSPECTION_REQUIRED', 'POST_TRIP_INSPECTION_REQUIRED', 'TRIP_READY_TO_START', 'WAYBILL_READY_TO_CLOSE', 'OPERATIONAL_ACTION_REQUIRED', 'OPERATIONAL_SLA_ESCALATION', 'CUSTOMER_CONFIRMATION_REQUIRED', 'CUSTOMER_DISPUTED')),
    CHECK (severity in ('INFO', 'WARNING', 'CRITICAL'))
);

-- TABLE: notification_action_completion  (satrlar: noma'lum)
CREATE TABLE notification_action_completion (
    entity_type varchar(64) NOT NULL,
    entity_id uuid NOT NULL,
    event_version bigint NOT NULL,
    action_type varchar(64) NOT NULL,
    actor_user_id uuid,
    actor_kind varchar(16) NOT NULL,  -- RUXSAT: 'HUMAN', 'MACHINE', 'SYSTEM'
    actor_id varchar(128) NOT NULL,
    source_branch_id uuid,
    source_type varchar(64) NOT NULL,
    source_hash varchar(64),
    enterprise_global_approved boolean NOT NULL,
    evidence_id uuid NOT NULL,
    completed_at timestamptz NOT NULL,
    policy_type varchar(64),
    policy_id uuid,
    policy_version bigint,
    source_id uuid,
    source_action varchar(64),
    source_site_id uuid,
    source_operation_id uuid,
    source_object_version bigint,
    PRIMARY KEY (entity_type, entity_id, event_version, action_type),
    FOREIGN KEY (source_operation_id) REFERENCES material_operation(id),
    FOREIGN KEY (policy_id) REFERENCES integration_exchange_provider(operation_id),
    FOREIGN KEY (source_id) REFERENCES material_external_receipt(id),
    FOREIGN KEY (actor_user_id) REFERENCES app_user(id),
    CHECK (actor_kind in ('HUMAN', 'MACHINE', 'SYSTEM')),
    CHECK (((((actor_kind) = 'human') and (actor_user_id is not null) and ((actor_id) = (actor_user_id)) and ((source_type) = 'human_domain_action') and (source_hash is null) and (source_branch_id is null) and (not enterprise_global_approved)) or (((actor_kind) = 'machine') and (actor_user_id is null) and (source_hash is not null) and ((source_hash) ~ '^[a-f0-9]{64}$') and ((source_branch_id is not null) or (((source_type) = 'snapshot') and enterprise_global_approved))) or (((actor_kind) = 'system') and (actor_user_id is null) and ((entity_type) = 'fleet_material_return') and ((action_type) = 'accept_material_return') and (source_branch_id is not null) and ((source_type) = 'material_business_readback') and (source_hash is not null) and ((source_hash) ~ '^[a-f0-9]{64}$') and (not enterprise_global_approved) and (policy_type is not null) and ((policy_type) = 'material_readback') and (policy_id is not null) and (policy_version is not null) and (policy_version > 0) and (source_id is not null) and (source_action is not null) and ((source_action) = 'material_receipt_readback_accepted') and (source_operation_id is not null) and (source_operation_id = evidence_id) and (source_object_version is not null) and (source_object_version >= 0) and ((actor_id) = ((('system-policy:' || (policy_type)) || ':') || (policy_id)))))),
    CHECK ((((actor_kind) = 'system') or ((policy_type is null) and (policy_id is null) and (policy_version is null) and (source_id is null) and (source_action is null) and (source_site_id is null) and (source_operation_id is null) and (source_object_version is null)))),
    CHECK ((event_version >= 0))
);

-- TABLE: notification_attention  (satrlar: noma'lum)
CREATE TABLE notification_attention (
    id uuid NOT NULL,
    event_key varchar(512) NOT NULL,
    payload_hash varchar(64) NOT NULL,
    event_type varchar(48) NOT NULL,
    entity_type varchar(64) NOT NULL,
    entity_id uuid NOT NULL,
    branch_id uuid,
    event_version bigint NOT NULL,
    action_type varchar(64) NOT NULL,
    severity varchar(16) NOT NULL,  -- RUXSAT: 'INFO', 'WARNING', 'CRITICAL'
    policy_id uuid,
    responsible_user_id uuid,
    reserve_user_id uuid,
    occurred_at timestamptz NOT NULL,
    due_at timestamptz,
    state varchar(32) NOT NULL,  -- RUXSAT: 'OPEN', 'UNCONFIGURED', 'COMPLETED'; BAZADA: 'COMPLETED' 9; ISHLATILMAGAN: OPEN, UNCONFIGURED
    completed_at timestamptz,
    completion_evidence_id uuid,
    escalated_at timestamptz,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (policy_id) REFERENCES notification_sla_policy(id),
    FOREIGN KEY (reserve_user_id) REFERENCES app_user(id),
    FOREIGN KEY (responsible_user_id) REFERENCES app_user(id),
    CHECK (((completed_at is null) = (completion_evidence_id is null))),
    CHECK ((((state) = 'completed') = (completed_at is not null))),
    CHECK ((((state) <> 'open') or ((policy_id is not null) and (responsible_user_id is not null) and (reserve_user_id is not null) and (due_at is not null)))),
    CHECK ((event_version >= 0)),
    CHECK (severity in ('INFO', 'WARNING', 'CRITICAL')),
    CHECK (state in ('OPEN', 'UNCONFIGURED', 'COMPLETED'))
);

-- TABLE: notification_attention_recipient  (satrlar: 0 — BO`SH)
CREATE TABLE notification_attention_recipient (
    attention_id uuid NOT NULL,
    recipient_user_id uuid NOT NULL,
    stage varchar(16) NOT NULL,  -- RUXSAT: 'INITIAL', 'ESCALATION'
    notification_id uuid NOT NULL,
    PRIMARY KEY (attention_id, stage, recipient_user_id),
    FOREIGN KEY (attention_id) REFERENCES notification_attention(id),
    FOREIGN KEY (notification_id) REFERENCES notification(id),
    FOREIGN KEY (recipient_user_id) REFERENCES app_user(id),
    CHECK (stage in ('INITIAL', 'ESCALATION'))
);

-- TABLE: notification_channel_delivery  (satrlar: 0 — BO`SH)
CREATE TABLE notification_channel_delivery (
    id uuid NOT NULL,
    notification_id uuid NOT NULL,
    recipient_user_id uuid NOT NULL,
    channel varchar(16) NOT NULL,  -- RUXSAT: 'EMAIL', 'SMS', 'REALTIME'
    adapter_id varchar(128),
    contract_reference varchar(256),
    state varchar(32) NOT NULL,  -- RUXSAT: 'QUEUED', 'SENDING', 'PROVIDER_ACCEPTED', 'DELIVERED', 'RETRY', 'REJECTED', 'OUTCOME_UNKNOWN', 'SUPPRESSED', 'EXHAUSTED'
    attempts integer NOT NULL,
    next_attempt_at timestamptz NOT NULL,
    accepted_at timestamptz,
    delivered_at timestamptz,
    safe_receipt_code varchar(64),
    claim_token uuid,  -- [MAXFIY — o'qish taqiqlangan]
    created_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (notification_id) REFERENCES notification(id),
    FOREIGN KEY (recipient_user_id) REFERENCES app_user(id),
    CHECK ((attempts >= 0)),
    CHECK (channel in ('EMAIL', 'SMS', 'REALTIME')),
    CHECK ((((channel) = 'realtime') or ((adapter_id is not null) and (contract_reference is not null)))),
    CHECK (state in ('QUEUED', 'SENDING', 'PROVIDER_ACCEPTED', 'DELIVERED', 'RETRY', 'REJECTED', 'OUTCOME_UNKNOWN', 'SUPPRESSED', 'EXHAUSTED'))
);

-- TABLE: notification_governance_operation  (satrlar: 0 — BO`SH)
CREATE TABLE notification_governance_operation (
    operation_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    action varchar(32) NOT NULL,  -- RUXSAT: 'APPROVE_POLICY', 'ROUTE_UNCONFIGURED', 'RETRY_DELIVERY'
    object_id uuid NOT NULL,
    request_hash varchar(64) NOT NULL,
    request_json jsonb NOT NULL,  -- [JSON matn]
    response_json jsonb NOT NULL,  -- [JSON matn]
    state varchar(16) NOT NULL,  -- RUXSAT: 'APPLIED', 'NOT_EXECUTED'
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK (action in ('APPROVE_POLICY', 'ROUTE_UNCONFIGURED', 'RETRY_DELIVERY')),
    CHECK (state in ('APPLIED', 'NOT_EXECUTED'))
);

-- TABLE: notification_sla_policy  (satrlar: 0 — BO`SH)
CREATE TABLE notification_sla_policy (
    id uuid NOT NULL,
    event_type varchar(48) NOT NULL,  -- RUXSAT: 'APPROVAL_REQUIRED', 'ADMISSION_BLOCKED', 'DOCUMENT_EXPIRING', 'INCIDENT_OPENED', 'CAPA_DUE', 'MANDATORY_INTEGRATION_FAILED'
    branch_id uuid,
    revision bigint NOT NULL,
    reaction_minutes integer NOT NULL,
    responsible_user_id uuid NOT NULL,
    reserve_user_id uuid NOT NULL,
    allow_source_responsible boolean NOT NULL,
    web_push_enabled boolean NOT NULL,
    email_adapter_id varchar(128),
    email_contract_reference varchar(256),
    sms_adapter_id varchar(128),
    sms_contract_reference varchar(256),
    approval_reference varchar(256) NOT NULL,
    enabled boolean NOT NULL,
    approved_by uuid NOT NULL,
    approved_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (approved_by) REFERENCES app_user(id),
    FOREIGN KEY (reserve_user_id) REFERENCES app_user(id),
    FOREIGN KEY (responsible_user_id) REFERENCES app_user(id),
    CHECK ((length(trim(both from approval_reference)) > 0)),
    CHECK ((responsible_user_id <> reserve_user_id)),
    CHECK (((email_adapter_id is null) = (email_contract_reference is null))),
    CHECK (((sms_adapter_id is null) = (sms_contract_reference is null))),
    CHECK (event_type in ('APPROVAL_REQUIRED', 'ADMISSION_BLOCKED', 'DOCUMENT_EXPIRING', 'INCIDENT_OPENED', 'CAPA_DUE', 'MANDATORY_INTEGRATION_FAILED')),
    CHECK (((reaction_minutes >= 1) and (reaction_minutes <= 525600))),
    CHECK ((revision > 0))
);

-- TABLE: operational_analytics_snapshot  (satrlar: noma'lum)
CREATE TABLE operational_analytics_snapshot (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    department_id uuid,
    original jsonb NOT NULL,  -- [JSON matn]
    snapshot jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    captured_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: part_condition_evaluation  (satrlar: noma'lum)
CREATE TABLE part_condition_evaluation (
    id uuid NOT NULL,
    evaluated_at timestamptz NOT NULL,
    evaluation jsonb NOT NULL,  -- [JSON matn]
    evidence_identity varchar(64) NOT NULL,
    part_id uuid NOT NULL,
    resource_evidence jsonb,  -- [JSON matn]
    PRIMARY KEY (id),
    FOREIGN KEY (part_id) REFERENCES vehicle_part(id)
);

-- TABLE: part_condition_evaluation_job  (satrlar: 0 — BO`SH)
CREATE TABLE part_condition_evaluation_job (
    id uuid NOT NULL,
    attempts integer NOT NULL,
    completed_at timestamptz,
    created_at timestamptz NOT NULL,
    evaluation_id uuid,
    failure_code varchar(1000),
    next_attempt_at timestamptz,
    part_id uuid NOT NULL,
    source_domain varchar(32) NOT NULL,
    source_id uuid NOT NULL,
    status varchar(16) NOT NULL,
    version bigint,
    PRIMARY KEY (id),
    FOREIGN KEY (evaluation_id) REFERENCES part_condition_evaluation(id),
    FOREIGN KEY (part_id) REFERENCES vehicle_part(id)
);

-- TABLE: part_condition_policy  (satrlar: 0 — BO`SH)
CREATE TABLE part_condition_policy (
    id uuid NOT NULL,
    basis varchar(2000) NOT NULL,
    category varchar(24) NOT NULL,  -- RUXSAT: 'TIRE', 'BATTERY', 'OIL_FILTER', 'AIR_FILTER', 'BRAKE_PAD', 'OTHER'
    effective_at timestamptz NOT NULL,
    item_id uuid NOT NULL,
    payload_identity varchar(64) NOT NULL,
    previous_policy_id uuid,
    recorded_at timestamptz NOT NULL,
    recorded_by varchar(255) NOT NULL,
    recorded_by_id uuid NOT NULL,
    revision bigint NOT NULL,
    source_priority jsonb NOT NULL,  -- [JSON matn]
    thresholds jsonb NOT NULL,  -- [JSON matn]
    usage_source_priority jsonb NOT NULL,  -- [JSON matn]
    restriction_by_state jsonb NOT NULL,  -- [JSON matn]
    PRIMARY KEY (id),
    FOREIGN KEY (item_id) REFERENCES material_item_policy(item_id),
    FOREIGN KEY (previous_policy_id) REFERENCES part_condition_policy(id),
    FOREIGN KEY (recorded_by_id) REFERENCES app_user(id),
    CHECK ((part_condition_operating_mapping_valid(restriction_by_state) is true)),
    CHECK (category in ('TIRE', 'BATTERY', 'OIL_FILTER', 'AIR_FILTER', 'BRAKE_PAD', 'OTHER'))
);

-- TABLE: part_condition_reading  (satrlar: 0 — BO`SH)
CREATE TABLE part_condition_reading (
    id uuid NOT NULL,
    basis varchar(2000) NOT NULL,
    branch_id uuid NOT NULL,
    metric varchar(32) NOT NULL,  -- RUXSAT: 'TREAD_DEPTH_MM', 'CAPACITY_AH', 'VOLTAGE_V', 'CHARGE_PERCENT', 'CYCLE_COUNT', 'RESOURCE_KM', 'RESOURCE_HOURS'
    observed_at timestamptz NOT NULL,
    part_id uuid NOT NULL,
    payload_identity varchar(64) NOT NULL,
    quality varchar(24) NOT NULL,  -- RUXSAT: 'CONFIRMED', 'QUARANTINED'
    recorded_at timestamptz NOT NULL,
    recorded_by varchar(255) NOT NULL,
    recorded_by_id uuid NOT NULL,
    reference_id uuid,
    revision bigint NOT NULL,
    source varchar(32) NOT NULL,
    unit varchar(16) NOT NULL,
    value numeric(20,3) NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (part_id) REFERENCES vehicle_part(id),
    FOREIGN KEY (recorded_by_id) REFERENCES app_user(id),
    FOREIGN KEY (reference_id) REFERENCES part_condition_reading(id),
    CHECK (metric in ('TREAD_DEPTH_MM', 'CAPACITY_AH', 'VOLTAGE_V', 'CHARGE_PERCENT', 'CYCLE_COUNT', 'RESOURCE_KM', 'RESOURCE_HOURS')),
    CHECK (quality in ('CONFIRMED', 'QUARANTINED'))
);

-- TABLE: part_disposal_command  (satrlar: noma'lum)
CREATE TABLE part_disposal_command (
    id uuid NOT NULL,
    act_id uuid NOT NULL,
    branch_id uuid,
    decision_id uuid NOT NULL,
    disposed_at date NOT NULL,
    disposition varchar(16) NOT NULL,
    document_reference varchar(255) NOT NULL,
    part_ids jsonb NOT NULL,  -- [JSON matn]
    payload_identity varchar(64) NOT NULL,
    recipient varchar(255),
    recorded_at timestamptz NOT NULL,
    recorded_by_id uuid NOT NULL,
    recorded_by_name varchar(256) NOT NULL,
    document_file_id uuid,
    document_file_name varchar(255),
    PRIMARY KEY (id),
    FOREIGN KEY (act_id) REFERENCES part_write_off_act(id),
    FOREIGN KEY (decision_id) REFERENCES part_writeoff_decision(id),
    FOREIGN KEY (recorded_by_id) REFERENCES app_user(id)
);

-- TABLE: part_disposal_fact  (satrlar: noma'lum)
CREATE TABLE part_disposal_fact (
    part_id uuid NOT NULL,
    act_id uuid NOT NULL,
    command_id uuid NOT NULL,
    decision_id uuid NOT NULL,
    PRIMARY KEY (part_id),
    FOREIGN KEY (act_id) REFERENCES part_write_off_act(id),
    FOREIGN KEY (command_id) REFERENCES part_disposal_command(id),
    FOREIGN KEY (decision_id) REFERENCES part_writeoff_decision(id),
    FOREIGN KEY (part_id) REFERENCES vehicle_part(id)
);

-- TABLE: part_installation  (satrlar: noma'lum)
CREATE TABLE part_installation (
    id uuid NOT NULL,
    basis varchar(2000) NOT NULL,
    branch_id uuid,
    engine_hours_reading_id uuid,
    engine_hours_removal_reading_id uuid,
    installed_at timestamptz NOT NULL,
    installed_at_hours numeric(20,3),
    installed_at_km numeric(20,3),
    issue_operation_id uuid NOT NULL,
    item_id uuid NOT NULL,
    odometer_reading_id uuid,
    odometer_removal_reading_id uuid,
    origin_kind varchar(32),
    original_material_use_id uuid,
    part_id uuid NOT NULL,
    part_request_id uuid,
    payload_identity varchar(3000) NOT NULL,
    position_id uuid NOT NULL,
    position_layout_id uuid,
    recorded_at timestamptz NOT NULL,
    recorded_by varchar(255) NOT NULL,
    removal_basis varchar(2000),
    removal_defect varchar(2000),
    removal_destination varchar(32),
    removal_operation_id uuid,
    removal_payload_identity varchar(3000),
    removal_reading_id uuid,
    removed_at timestamptz,
    removed_at_hours numeric(20,3),
    removed_at_km numeric(20,3),
    removed_by varchar(255),
    removed_in_repair_id uuid,
    repair_order_id uuid NOT NULL,
    restoration_acceptance_id uuid,
    stock_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    version bigint,
    PRIMARY KEY (id),
    FOREIGN KEY (engine_hours_reading_id) REFERENCES vehicle_usage_reading(id),
    FOREIGN KEY (engine_hours_removal_reading_id) REFERENCES vehicle_usage_reading(id),
    FOREIGN KEY (issue_operation_id) REFERENCES material_operation(id),
    FOREIGN KEY (odometer_reading_id) REFERENCES vehicle_usage_reading(id),
    FOREIGN KEY (odometer_removal_reading_id) REFERENCES vehicle_usage_reading(id),
    FOREIGN KEY (part_id) REFERENCES vehicle_part(id),
    FOREIGN KEY (part_request_id) REFERENCES repair_order_part_request(id),
    FOREIGN KEY (position_id) REFERENCES part_position(id),
    FOREIGN KEY (removal_reading_id) REFERENCES vehicle_usage_reading(id),
    FOREIGN KEY (removed_in_repair_id) REFERENCES vehicle_repair(id),
    FOREIGN KEY (repair_order_id) REFERENCES vehicle_repair(id),
    FOREIGN KEY (stock_id) REFERENCES inventory_stock(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id)
);

-- TABLE: part_position  (satrlar: 0 — BO`SH)
CREATE TABLE part_position (
    id uuid NOT NULL,
    basis varchar(2000) NOT NULL,
    branch_id uuid,
    category varchar(32) NOT NULL,  -- RUXSAT: 'TIRE', 'BATTERY', 'OIL_FILTER', 'AIR_FILTER', 'BRAKE_PAD', 'OTHER'
    code varchar(100) NOT NULL,
    recorded_by varchar(255) NOT NULL,
    updated_at timestamptz NOT NULL,
    vehicle_id uuid NOT NULL,
    version bigint,
    PRIMARY KEY (id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id),
    CHECK (category in ('TIRE', 'BATTERY', 'OIL_FILTER', 'AIR_FILTER', 'BRAKE_PAD', 'OTHER'))
);

-- TABLE: part_position_layout  (satrlar: 0 — BO`SH)
CREATE TABLE part_position_layout (
    id uuid NOT NULL,
    axle_code varchar(100) NOT NULL,
    basis varchar(2000) NOT NULL,
    branch_id uuid,
    effective_at timestamptz NOT NULL,
    payload_identity varchar(64) NOT NULL,
    position_id uuid NOT NULL,
    previous_layout_id uuid,
    recorded_at timestamptz NOT NULL,
    recorded_by varchar(255) NOT NULL,
    recorded_by_id uuid NOT NULL,
    revision bigint NOT NULL,
    slot_code varchar(100) NOT NULL,
    technical_document varchar(2000) NOT NULL,
    vehicle_id uuid NOT NULL,
    wheel_side varchar(16) NOT NULL,  -- RUXSAT: 'LEFT', 'RIGHT', 'CENTER'
    PRIMARY KEY (id),
    FOREIGN KEY (position_id) REFERENCES part_position(id),
    FOREIGN KEY (previous_layout_id) REFERENCES part_position_layout(id),
    FOREIGN KEY (recorded_by_id) REFERENCES app_user(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id),
    CHECK (wheel_side in ('LEFT', 'RIGHT', 'CENTER'))
);

-- TABLE: part_position_layout_head  (satrlar: 0 — BO`SH)
CREATE TABLE part_position_layout_head (
    position_id uuid NOT NULL,
    axle_code varchar(100) NOT NULL,
    branch_id uuid,
    layout_id uuid NOT NULL,
    slot_code varchar(100) NOT NULL,
    vehicle_id uuid NOT NULL,
    version bigint,
    wheel_side varchar(16) NOT NULL,  -- RUXSAT: 'LEFT', 'RIGHT', 'CENTER'
    PRIMARY KEY (position_id),
    FOREIGN KEY (layout_id) REFERENCES part_position_layout(id),
    FOREIGN KEY (position_id) REFERENCES part_position(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id),
    CHECK (wheel_side in ('LEFT', 'RIGHT', 'CENTER'))
);

-- TABLE: part_replacement_need  (satrlar: noma'lum)
CREATE TABLE part_replacement_need (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    initial_evaluation_id uuid NOT NULL,
    part_id uuid NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (initial_evaluation_id) REFERENCES part_condition_evaluation(id),
    FOREIGN KEY (part_id) REFERENCES vehicle_part(id)
);

-- TABLE: part_replacement_resolution  (satrlar: noma'lum)
CREATE TABLE part_replacement_resolution (
    id uuid NOT NULL,
    acceptance_id uuid NOT NULL,
    need_id uuid NOT NULL,
    part_id uuid NOT NULL,
    resolved_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (acceptance_id) REFERENCES part_restoration_acceptance(id),
    FOREIGN KEY (need_id) REFERENCES part_replacement_need(id),
    FOREIGN KEY (part_id) REFERENCES vehicle_part(id)
);

-- TABLE: part_resource_opening  (satrlar: 0 — BO`SH)
CREATE TABLE part_resource_opening (
    id uuid NOT NULL,
    basis varchar(2000) NOT NULL,
    counter varchar(32) NOT NULL,  -- RUXSAT: 'ODOMETER_KM', 'ENGINE_HOURS'
    observed_at timestamptz NOT NULL,
    part_id uuid NOT NULL,
    payload_identity varchar(64) NOT NULL,
    recorded_at timestamptz NOT NULL,
    recorded_by varchar(255) NOT NULL,
    reference_id uuid,
    revision bigint NOT NULL,
    source varchar(100) NOT NULL,
    type varchar(24) NOT NULL,  -- RUXSAT: 'BASELINE', 'CORRECTION'
    value numeric(20,3) NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (part_id) REFERENCES vehicle_part(id),
    FOREIGN KEY (reference_id) REFERENCES part_resource_opening(id),
    CHECK (counter in ('ODOMETER_KM', 'ENGINE_HOURS')),
    CHECK (type in ('BASELINE', 'CORRECTION'))
);

-- TABLE: part_restoration_acceptance  (satrlar: noma'lum)
CREATE TABLE part_restoration_acceptance (
    id uuid NOT NULL,
    accepted_at timestamptz NOT NULL,
    basis varchar(2000) NOT NULL,
    branch_id uuid,
    condition_evaluation_id uuid NOT NULL,
    installation_id uuid NOT NULL,
    part_id uuid NOT NULL,
    payload_identity varchar(64) NOT NULL,
    previous_acceptance_id uuid,
    recorded_at timestamptz NOT NULL,
    recorded_by varchar(255) NOT NULL,
    recorded_by_id uuid NOT NULL,
    removal_operation_id uuid NOT NULL,
    replacement_need_id uuid,
    revision bigint,
    work_document varchar(2000) NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (condition_evaluation_id) REFERENCES part_condition_evaluation(id),
    FOREIGN KEY (installation_id) REFERENCES part_installation(id),
    FOREIGN KEY (part_id) REFERENCES vehicle_part(id),
    FOREIGN KEY (recorded_by_id) REFERENCES app_user(id)
);

-- TABLE: part_service_rule  (satrlar: 0 — BO`SH)
CREATE TABLE part_service_rule (
    id uuid NOT NULL,
    active boolean NOT NULL,
    category varchar(16),  -- RUXSAT: 'TIRE', 'BATTERY', 'OIL_FILTER', 'AIR_FILTER', 'BRAKE_PAD', 'OTHER'
    created_at timestamptz NOT NULL,
    expected_life_days integer,
    expected_life_engine_hours numeric(14,3),
    expected_life_km numeric(14,3),
    expected_life_months integer,
    name varchar(255) NOT NULL,
    replace_at_percent numeric(5,2) NOT NULL,
    updated_at timestamptz NOT NULL,
    version bigint NOT NULL,
    warning_at_percent numeric(5,2) NOT NULL,
    PRIMARY KEY (id),
    CHECK (category in ('TIRE', 'BATTERY', 'OIL_FILTER', 'AIR_FILTER', 'BRAKE_PAD', 'OTHER'))
);

-- TABLE: part_stock_origin  (satrlar: noma'lum)
CREATE TABLE part_stock_origin (
    part_id uuid NOT NULL,
    basis varchar(2000) NOT NULL,
    canonical_serial_key varchar(400) NOT NULL,
    item_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    recorded_by varchar(255) NOT NULL,
    source_operation_id uuid NOT NULL,
    stock_id uuid NOT NULL,
    version bigint,
    PRIMARY KEY (part_id),
    FOREIGN KEY (part_id) REFERENCES vehicle_part(id),
    FOREIGN KEY (source_operation_id) REFERENCES material_operation(id),
    FOREIGN KEY (stock_id) REFERENCES inventory_stock(id)
);

-- TABLE: part_write_off_act  (satrlar: 0 — BO`SH)
CREATE TABLE part_write_off_act (
    id uuid NOT NULL,
    branch_id uuid,
    chair_id uuid NOT NULL,
    chair_name varchar(256) NOT NULL,
    closed_at timestamptz,
    closed_by_id uuid,
    closed_by_name varchar(256),
    closure_reason varchar(2000),
    completed_at timestamptz,
    created_at timestamptz NOT NULL,
    created_by_id uuid NOT NULL,
    created_by_name varchar(256) NOT NULL,
    number varchar(64) NOT NULL,
    reason varchar(2000) NOT NULL,
    signed_at timestamptz,
    status varchar(32) NOT NULL,  -- RUXSAT: 'DRAFT', 'IN_REVIEW', 'AWAITING_CHAIR', 'APPROVED', 'COMPLETED', 'REJECTED', 'CANCELLED'
    submitted_at timestamptz,
    version bigint NOT NULL,
    PRIMARY KEY (id),
    CHECK (status in ('DRAFT', 'IN_REVIEW', 'AWAITING_CHAIR', 'APPROVED', 'COMPLETED', 'REJECTED', 'CANCELLED'))
);

-- TABLE: part_write_off_item  (satrlar: 0 — BO`SH)
CREATE TABLE part_write_off_item (
    act_id uuid NOT NULL,
    conclusion varchar(2000) NOT NULL,
    cost numeric(14,2),
    currency varchar(8),
    defect varchar(2000) NOT NULL,
    disposed_at date,
    disposed_by_id uuid,
    disposed_by_name varchar(256),
    disposition varchar(16),  -- RUXSAT: 'DESTROYED', 'RECYCLED'
    document_reference varchar(255),
    name varchar(255) NOT NULL,
    part_id uuid NOT NULL,
    part_number varchar(128),
    recipient varchar(255),
    recorded_at timestamptz,
    removed_at date,
    removed_at_km numeric(14,3),
    repair_number varchar(64),
    repair_order_id uuid NOT NULL,
    serial_number varchar(128) NOT NULL,
    series varchar(128) NOT NULL,
    vehicle_id uuid NOT NULL,
    vehicle_label varchar(255),
    item_position integer NOT NULL,
    document_file_id uuid,
    document_file_name varchar(255),
    PRIMARY KEY (act_id, item_position),
    FOREIGN KEY (act_id) REFERENCES part_write_off_act(id),
    FOREIGN KEY (part_id) REFERENCES vehicle_part(id),
    CHECK (disposition in ('DESTROYED', 'RECYCLED'))
);

-- TABLE: part_write_off_member  (satrlar: noma'lum)
CREATE TABLE part_write_off_member (
    act_id uuid NOT NULL,
    approved_at timestamptz,
    name varchar(256) NOT NULL,
    user_id uuid NOT NULL,
    member_position integer NOT NULL,
    PRIMARY KEY (act_id, member_position),
    FOREIGN KEY (act_id) REFERENCES part_write_off_act(id)
);

-- TABLE: part_writeoff_accounting_intent  (satrlar: 0 — BO`SH)
CREATE TABLE part_writeoff_accounting_intent (
    id uuid NOT NULL,
    act_id uuid NOT NULL,
    attempts integer NOT NULL,
    branch_id uuid,
    created_at timestamptz NOT NULL,
    decision_id uuid NOT NULL,
    envelope_hash varchar(255),
    envelope_json text,  -- [JSON matn]
    error_code varchar(255),
    lease_token uuid,  -- [MAXFIY — o'qish taqiqlangan]
    lease_until timestamptz,
    lease_was_lookup boolean NOT NULL,
    lookup_latched boolean NOT NULL,
    lookup_required boolean NOT NULL,
    mutation_started_at timestamptz,
    next_attempt_at timestamptz,
    policy_id uuid,
    source_hash varchar(64) NOT NULL,
    source_json text NOT NULL,  -- [JSON matn]
    state varchar(255) NOT NULL,  -- RUXSAT: 'UNCONFIGURED', 'PENDING', 'PROCESSING', 'AWAITING_ACK', 'UNKNOWN', 'CONFIRMED', 'REJECTED'
    version bigint,
    PRIMARY KEY (id),
    FOREIGN KEY (act_id) REFERENCES part_write_off_act(id),
    FOREIGN KEY (decision_id) REFERENCES part_writeoff_decision(id),
    FOREIGN KEY (id) REFERENCES part_disposal_command(id),
    FOREIGN KEY (policy_id) REFERENCES part_writeoff_accounting_policy(id),
    CHECK (state in ('UNCONFIGURED', 'PENDING', 'PROCESSING', 'AWAITING_ACK', 'UNKNOWN', 'CONFIRMED', 'REJECTED'))
);

-- TABLE: part_writeoff_accounting_policy  (satrlar: noma'lum)
CREATE TABLE part_writeoff_accounting_policy (
    id uuid NOT NULL,
    assets jsonb NOT NULL,  -- [JSON matn]
    basis varchar(2000) NOT NULL,
    branch_id uuid NOT NULL,
    document_type varchar(255) NOT NULL,
    epoch bigint NOT NULL,
    external_organization varchar(255) NOT NULL,
    owner varchar(255) NOT NULL,
    previous_epoch bigint NOT NULL,
    protocol varchar(255) NOT NULL,
    provider varchar(255) NOT NULL,
    recorded_at timestamptz NOT NULL,
    recorded_by_id uuid NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: part_writeoff_accounting_receipt  (satrlar: noma'lum)
CREATE TABLE part_writeoff_accounting_receipt (
    id uuid NOT NULL,
    confirmed_at timestamptz NOT NULL,
    document_id varchar(255),
    document_line_id varchar(255),
    intent_id uuid NOT NULL,
    outcome varchar(255) NOT NULL,
    owner varchar(255) NOT NULL,
    owner_epoch bigint NOT NULL,
    payload_hash varchar(64) NOT NULL,
    policy_id uuid NOT NULL,
    protocol varchar(255) NOT NULL,
    provider varchar(255) NOT NULL,
    receipt_json text NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    rejection_code varchar(255),
    PRIMARY KEY (id),
    FOREIGN KEY (intent_id) REFERENCES part_writeoff_accounting_intent(id),
    FOREIGN KEY (policy_id) REFERENCES part_writeoff_accounting_policy(id)
);

-- TABLE: part_writeoff_accounting_recovery  (satrlar: noma'lum)
CREATE TABLE part_writeoff_accounting_recovery (
    id uuid NOT NULL,
    basis varchar(2000) NOT NULL,
    expected_version bigint NOT NULL,
    intent_id uuid NOT NULL,
    payload_hash varchar(64) NOT NULL,
    recorded_at timestamptz NOT NULL,
    recorded_by_id uuid NOT NULL,
    source_hash varchar(64) NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (intent_id) REFERENCES part_writeoff_accounting_intent(id),
    FOREIGN KEY (recorded_by_id) REFERENCES app_user(id)
);

-- TABLE: part_writeoff_correction  (satrlar: noma'lum)
CREATE TABLE part_writeoff_correction (
    id uuid NOT NULL,
    act_id uuid NOT NULL,
    after_json text NOT NULL,  -- [JSON matn]
    basis varchar(2000) NOT NULL,
    before_json text NOT NULL,  -- [JSON matn]
    changes_json text NOT NULL,  -- [JSON matn]
    created_at timestamptz NOT NULL,
    created_by_id uuid NOT NULL,
    created_by_name varchar(256) NOT NULL,
    decision_id uuid NOT NULL,
    document_reference varchar(255) NOT NULL,
    payload_hash varchar(64) NOT NULL,
    payload_json text NOT NULL,  -- [JSON matn]
    previous_correction_id uuid,
    source_hash varchar(64) NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (act_id) REFERENCES part_write_off_act(id),
    FOREIGN KEY (created_by_id) REFERENCES app_user(id),
    FOREIGN KEY (decision_id) REFERENCES part_writeoff_decision(id)
);

-- TABLE: part_writeoff_correction_action  (satrlar: 0 — BO`SH)
CREATE TABLE part_writeoff_correction_action (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    actor_name varchar(256) NOT NULL,
    basis varchar(2000) NOT NULL,
    payload_hash varchar(64) NOT NULL,
    payload_json text NOT NULL,  -- [JSON matn]
    proposal_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    revision bigint NOT NULL,
    type varchar(16) NOT NULL,  -- RUXSAT: 'CREATED', 'SUBMITTED', 'APPROVED', 'SIGNED', 'REJECTED', 'CANCELLED'
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (proposal_id) REFERENCES part_writeoff_correction(id),
    CHECK (type in ('CREATED', 'SUBMITTED', 'APPROVED', 'SIGNED', 'REJECTED', 'CANCELLED'))
);

-- TABLE: part_writeoff_correction_decision  (satrlar: noma'lum)
CREATE TABLE part_writeoff_correction_decision (
    id uuid NOT NULL,
    act_id uuid NOT NULL,
    previous_correction_id uuid,
    proposal_id uuid NOT NULL,
    signed_at timestamptz NOT NULL,
    signed_by_id uuid NOT NULL,
    signed_by_name varchar(256) NOT NULL,
    snapshot_json text NOT NULL,  -- [JSON matn]
    source_hash varchar(64) NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (act_id) REFERENCES part_write_off_act(id),
    FOREIGN KEY (proposal_id) REFERENCES part_writeoff_correction(id),
    FOREIGN KEY (signed_by_id) REFERENCES app_user(id)
);

-- TABLE: part_writeoff_correction_head  (satrlar: noma'lum)
CREATE TABLE part_writeoff_correction_head (
    act_id uuid NOT NULL,
    decision_id uuid NOT NULL,
    version bigint NOT NULL,
    PRIMARY KEY (act_id),
    FOREIGN KEY (act_id) REFERENCES part_write_off_act(id),
    FOREIGN KEY (decision_id) REFERENCES part_writeoff_correction_decision(id)
);

-- TABLE: part_writeoff_decision  (satrlar: noma'lum)
CREATE TABLE part_writeoff_decision (
    id uuid NOT NULL,
    act_id uuid NOT NULL,
    branch_id uuid,
    recorded_at timestamptz NOT NULL,
    signed_at timestamptz NOT NULL,
    signed_by_id uuid NOT NULL,
    signed_by_name varchar(256) NOT NULL,
    snapshot_json text NOT NULL,  -- [JSON matn]
    PRIMARY KEY (id),
    FOREIGN KEY (act_id) REFERENCES part_write_off_act(id),
    FOREIGN KEY (signed_by_id) REFERENCES app_user(id)
);

-- TABLE: payroll_closed_operation  (satrlar: 0 — BO`SH)
CREATE TABLE payroll_closed_operation (
    operation_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    path text NOT NULL,  -- RUXSAT: 'policies', 'work', 'work/reverse', 'statements', 'decisions', 'erp/policies', 'erp/queue', 'erp/retry', 'history/assignment', 'history/rate', 'history/timesheet', 'history/review', 'history/scope', 'history/adapter'
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    CHECK (path in ('policies', 'work', 'work/reverse', 'statements', 'decisions', 'erp/policies', 'erp/queue', 'erp/retry', 'history/assignment', 'history/rate', 'history/timesheet', 'history/review', 'history/scope', 'history/adapter'))
);

-- TABLE: payroll_history_event  (satrlar: 0 — BO`SH)
CREATE TABLE payroll_history_event (
    id uuid NOT NULL,
    branch_id uuid NOT NULL,
    kind text NOT NULL,  -- RUXSAT: 'ASSIGNMENT', 'RATE', 'TIMESHEET', 'REVIEW', 'SCOPE', 'ADAPTER'
    revision bigint NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    snapshot jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    CHECK ((hash ~ '^[0-9a-f]{64}$')),
    CHECK (kind in ('ASSIGNMENT', 'RATE', 'TIMESHEET', 'REVIEW', 'SCOPE', 'ADAPTER')),
    CHECK ((revision > 0))
);

-- TABLE: payroll_hr_business_receipt  (satrlar: noma'lum)
CREATE TABLE payroll_hr_business_receipt (
    provider text NOT NULL,
    receipt_id text NOT NULL,
    event_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    received_at timestamptz NOT NULL,
    PRIMARY KEY (provider, receipt_id),
    FOREIGN KEY (event_id) REFERENCES payroll_hr_outbox(event_id)
);

-- TABLE: payroll_hr_delivery_event  (satrlar: 0 — BO`SH)
CREATE TABLE payroll_hr_delivery_event (
    id uuid NOT NULL,
    event_id uuid NOT NULL,
    revision bigint NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'QUEUED', 'SENDING', 'UNKNOWN', 'RETRY', 'DELIVERED_AWAITING_ACK', 'ACCEPTED', 'REJECTED', 'BLOCKED_REVIEW'
    attempt integer NOT NULL,
    detail text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (event_id) REFERENCES payroll_hr_outbox(event_id),
    CHECK ((attempt >= 0)),
    CHECK ((revision > 0)),
    CHECK (state in ('QUEUED', 'SENDING', 'UNKNOWN', 'RETRY', 'DELIVERED_AWAITING_ACK', 'ACCEPTED', 'REJECTED', 'BLOCKED_REVIEW'))
);

-- TABLE: payroll_hr_message  (satrlar: 0 — BO`SH)
CREATE TABLE payroll_hr_message (
    id uuid NOT NULL,
    operation_id uuid NOT NULL,
    statement_id uuid NOT NULL,
    statement_hash text NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    payload jsonb NOT NULL,  -- [JSON matn]
    payload_hash text NOT NULL,
    status text NOT NULL,
    reason text NOT NULL,
    prepared_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (statement_id) REFERENCES payroll_ledger_event(id),
    CHECK ((payload_hash ~ '^[0-9a-f]{64}$')),
    CHECK ((reason = 'hr_provider_and_employee_mapping_unconfigured')),
    CHECK ((status = 'unconfigured'))
);

-- TABLE: payroll_hr_outbox  (satrlar: noma'lum)
CREATE TABLE payroll_hr_outbox (
    event_id uuid NOT NULL,
    statement_id uuid NOT NULL,
    statement_version bigint NOT NULL,
    statement_hash text NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    provider text NOT NULL,
    policy_version bigint NOT NULL,
    policy_hash text NOT NULL,
    destination_hash text NOT NULL,
    idempotency_key text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    payload jsonb NOT NULL,  -- [JSON matn]
    wire_payload text NOT NULL,
    payload_hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    adapter_id uuid,
    adapter_hash text,
    adapter_snapshot jsonb,  -- [JSON matn]
    PRIMARY KEY (event_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (adapter_id) REFERENCES payroll_history_event(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (statement_id) REFERENCES payroll_ledger_event(id),
    CHECK ((destination_hash ~ '^[0-9a-f]{64}$')),
    CHECK ((payload_hash ~ '^[0-9a-f]{64}$'))
);

-- TABLE: payroll_hr_policy  (satrlar: noma'lum)
CREATE TABLE payroll_hr_policy (
    operation_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    revision bigint NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    CHECK ((hash ~ '^[0-9a-f]{64}$')),
    CHECK ((revision > 0))
);

-- TABLE: payroll_hr_provider_receipt  (satrlar: noma'lum)
CREATE TABLE payroll_hr_provider_receipt (
    provider text NOT NULL,
    receipt_id text NOT NULL,
    event_id uuid NOT NULL,
    adapter_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    canonical jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    received_at timestamptz NOT NULL,
    PRIMARY KEY (provider, receipt_id),
    FOREIGN KEY (adapter_id) REFERENCES payroll_history_event(id),
    FOREIGN KEY (event_id) REFERENCES payroll_hr_outbox(event_id)
);

-- TABLE: payroll_hr_retry_operation  (satrlar: noma'lum)
CREATE TABLE payroll_hr_retry_operation (
    operation_id uuid NOT NULL,
    event_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (event_id) REFERENCES payroll_hr_outbox(event_id)
);

-- TABLE: payroll_ledger_event  (satrlar: 0 — BO`SH)
CREATE TABLE payroll_ledger_event (
    id uuid NOT NULL,
    operation_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    kind text NOT NULL,  -- RUXSAT: 'POLICY', 'WORK', 'REVERSAL', 'STATEMENT', 'DECISION'
    revision bigint NOT NULL,
    actor_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    snapshot jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    CHECK ((id = operation_id)),
    CHECK ((hash ~ '^[0-9a-f]{64}$')),
    CHECK (kind in ('POLICY', 'WORK', 'REVERSAL', 'STATEMENT', 'DECISION')),
    CHECK ((revision > 0))
);

-- TABLE: payroll_rate  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Haydovchi ish haqi tariflari: reys uchun (trip_rate), km uchun (per_km_rate),
-- tungi soat (night_hour_rate), qo'shimcha soat (overtime_hour_rate) va
-- chetlanish uchun jarima koeffitsienti (deviation_penalty_rate).
-- ISH HAQI HISOBI driver_shift VA trip MA'LUMOTLARI BILAN BIRGA QILINADI.
-- (Ilgari `payroll_rate` deb atalardi — sxema ko'chirishda nomi o'zgargan.)
-- ---------------------------------------------------------------------
CREATE TABLE payroll_rate (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    currency varchar(8) NOT NULL,
    deviation_penalty_rate numeric(18,2) NOT NULL,
    night_hour_rate numeric(18,2) NOT NULL,
    overtime_hour_rate numeric(18,2) NOT NULL,
    per_km_rate numeric(18,2) NOT NULL,
    trip_rate numeric(18,2) NOT NULL,
    updated_at timestamptz NOT NULL,
    updated_by varchar(128),
    PRIMARY KEY (id)
);

-- TABLE: position_log  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- GPS qurilmalaridan kelgan xom koordinata yozuvlari (device_id bo'yicha, ATIL
-- obyektlariga bevosita bog'lanmagan). Qurilma qaysi mashinaga tegishliligi
-- vehicle_gps jadvalida (device_id → vehicle_id).
-- MASHINANING JOYLASHUVI SO'RALSA avval vehicle_telemetry_state ga qarash kerak —
-- u tayyor oxirgi holatni beradi.
-- ---------------------------------------------------------------------
CREATE TABLE position_log (
    id bigint NOT NULL,
    altitude float8,
    device_id bigint,
    fix_time timestamptz,
    latitude float8,
    longitude float8,
    saved_at timestamptz,
    speed float8,
    valid boolean NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: product  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Tovar/material nomenklaturasi (nomi, tavsifi, o'lchov birligi).
-- Ombordagi qoldiqlari inventory_stock jadvalida.
-- ---------------------------------------------------------------------
CREATE TABLE product (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    description varchar(255),
    name varchar(255),
    unit varchar(32),
    updated_at timestamptz,
    PRIMARY KEY (id)
);

-- TABLE: production_order  (satrlar: noma'lum)
CREATE TABLE production_order (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    notes varchar(1024),
    order_number varchar(64) NOT NULL,
    planned_end_date timestamptz,
    planned_start_date timestamptz,
    product_id uuid,
    production_line_code varchar(64),
    quantity integer,
    sku varchar(128),
    status varchar(32),  -- BAZADA (eng ko'p uchraydiganlari): 'PLANNED' 1
    target_warehouse_id varchar(64),
    unit varchar(32),
    updated_at timestamptz,
    history_tracked boolean NOT NULL,
    version bigint NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: production_order_authority  (satrlar: noma'lum)
CREATE TABLE production_order_authority (
    order_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    creator_id uuid NOT NULL,
    registered_at timestamptz NOT NULL,
    source_operation_id uuid NOT NULL,
    source_origin varchar(32) NOT NULL,
    PRIMARY KEY (order_id)
);

-- TABLE: production_order_command  (satrlar: noma'lum)
CREATE TABLE production_order_command (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    actor_name varchar(256) NOT NULL,
    kind varchar(16) NOT NULL,
    order_id uuid NOT NULL,
    order_version bigint NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    payload_hash varchar(64) NOT NULL,
    recorded_at timestamptz NOT NULL,
    result_json text NOT NULL,  -- [JSON matn]
    tx_id bigint NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: production_order_history  (satrlar: noma'lum)
CREATE TABLE production_order_history (
    id uuid NOT NULL,
    action varchar(32) NOT NULL,
    actor_id uuid NOT NULL,
    actor_name varchar(256) NOT NULL,
    current_json text NOT NULL,  -- [JSON matn]
    order_id uuid NOT NULL,
    order_version bigint NOT NULL,
    previous_json text,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: production_order_history_context  (satrlar: noma'lum)
CREATE TABLE production_order_history_context (
    order_id uuid NOT NULL,
    order_version bigint NOT NULL,
    tx_id bigint NOT NULL,
    previous_json jsonb,  -- [JSON matn]
    current_json jsonb NOT NULL,  -- [JSON matn]
    PRIMARY KEY (order_id, order_version)
);

-- TABLE: rail_car  (satrlar: 0 — BO`SH)
CREATE TABLE rail_car (
    id uuid NOT NULL,
    capacity_tons integer,
    car_number varchar(64) NOT NULL,
    created_at timestamptz NOT NULL,
    current_station varchar(256),
    kind varchar(32),
    ownership varchar(64),
    status varchar(32),
    updated_at timestamptz,
    PRIMARY KEY (id)
);

-- TABLE: rail_car_hazard_classes  (satrlar: noma'lum)
CREATE TABLE rail_car_hazard_classes (
    rail_car_id uuid NOT NULL,
    hazard_class varchar(32),
    FOREIGN KEY (rail_car_id) REFERENCES rail_car(id)
);

-- TABLE: reference_data  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- UMUMIY KATALOG JADVALI — BARCHA MA'LUMOTNOMALAR SHU JADVALDA SAQLANADI va
-- catalog_type bilan ajratiladi: BRANCHES (filiallar), DEPARTMENTS (bo'limlar),
-- POSITIONS (lavozimlar), LOCATIONS (manzillar), FUEL_TYPES, FUEL_WAREHOUSES
-- (yoqilg'i omborlari), FUEL_SOURCE_TYPES, FUEL_DOCUMENT_TYPES, ORG_STRUCTURE.
-- BO'LIM, FILIAL, MANZIL YOKI LAVOZIM NOMI KERAK BO'LSA SHU JADVALDAN
-- catalog_type BO'YICHA FILTRLAB OLINADI. parent_id ierarxiyani beradi,
-- latitude/longitude — manzil koordinatalari.
-- ---------------------------------------------------------------------
CREATE TABLE reference_data (
    id uuid NOT NULL,
    active boolean NOT NULL,
    address varchar(512),
    branch_id uuid,
    capacity_liters numeric(14,3),
    catalog_type varchar(32) NOT NULL,  -- RUXSAT: 'BRANCHES', 'ORG_STRUCTURE', 'DEPARTMENTS', 'POSITIONS', 'LOCATIONS', 'REPAIR_ZONES', 'MATERIAL_WAREHOUSES', 'MATERIAL_GROUPS', 'MEASUREMENT_UNITS', 'MXIK_CODES', 'FUEL_TYPES', 'FUEL_WAREHOUSES', 'FUEL_SOURCE_TYPES', 'FUEL_DOCUMENT_TYPES'; BAZADA: 'DEPARTMENTS' 102, 'FUEL_TYPES' 8, 'LOCATIONS' 6, 'FUEL_DOCUMENT_TYPES' 6, 'FUEL_SOURCE_TYPES' 4, 'BRANCHES' 4, 'FUEL_WAREHOUSES' 3, 'MATERIAL_WAREHOUSES' 1, 'MEASUREMENT_UNITS' 1; ISHLATILMAGAN: ORG_STRUCTURE, POSITIONS, REPAIR_ZONES, MATERIAL_GROUPS, MXIK_CODES
    code varchar(64),
    created_at timestamptz NOT NULL,
    department_id uuid,
    latitude float8,
    location_id uuid,
    longitude float8,
    name varchar(256) NOT NULL,
    parent_id uuid,
    reference_type varchar(64),
    short_name varchar(128),
    unit varchar(32),
    updated_at timestamptz NOT NULL,
    fuel_storage jsonb,  -- [JSON matn]
    PRIMARY KEY (id),
    FOREIGN KEY (parent_id) REFERENCES reference_data(id),
    CHECK ((((catalog_type) <> 'mxik_codes') or ((code is not null) and ((code) ~ '^[0-9]{17}$') and (btrim((name)) <> '')))),
    CHECK (catalog_type in ('BRANCHES', 'ORG_STRUCTURE', 'DEPARTMENTS', 'POSITIONS', 'LOCATIONS', 'REPAIR_ZONES', 'MATERIAL_WAREHOUSES', 'MATERIAL_GROUPS', 'MEASUREMENT_UNITS', 'MXIK_CODES', 'FUEL_TYPES', 'FUEL_WAREHOUSES', 'FUEL_SOURCE_TYPES', 'FUEL_DOCUMENT_TYPES'))
);

-- TABLE: repair_cost_acceptance  (satrlar: 0 — BO`SH)
CREATE TABLE repair_cost_acceptance (
    id uuid NOT NULL,
    accepted_at timestamptz NOT NULL,
    accepted_by_id uuid NOT NULL,
    accepted_by_name varchar(256) NOT NULL,
    basis varchar(2000) NOT NULL,
    branch_id uuid NOT NULL,
    currency varchar(3),
    description varchar(2000) NOT NULL,
    document_issuer varchar(255) NOT NULL,
    document_reference varchar(255) NOT NULL,
    kind varchar(32) NOT NULL,  -- RUXSAT: 'LABOR', 'CONTRACTOR_SERVICE'
    line_reference varchar(128) NOT NULL,
    money_scale integer,
    operational_amount numeric(24,6),
    owner_epoch bigint NOT NULL,
    payload_identity varchar(64) NOT NULL,
    payload_json text NOT NULL,  -- [JSON matn]
    performed_from timestamptz NOT NULL,
    performed_to timestamptz NOT NULL,
    quantity numeric(20,3) NOT NULL,
    rate_document varchar(255),
    rate_effective_from timestamptz,
    rate_effective_to timestamptz,
    repair_id uuid NOT NULL,
    repair_version bigint NOT NULL,
    source_owner varchar(32) NOT NULL,
    supplier_reference varchar(255),
    unit varchar(32) NOT NULL,
    unit_rate numeric(20,6),
    vehicle_id uuid NOT NULL,
    work_item_id varchar(128),
    worker_id uuid,
    worker_name varchar(256),
    work_source varchar(32),
    completion_operation_id uuid,
    work_evidence varchar(512),
    PRIMARY KEY (id),
    FOREIGN KEY (accepted_by_id) REFERENCES app_user(id),
    FOREIGN KEY (repair_id) REFERENCES vehicle_repair(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id),
    CHECK ((((work_source is null) and (completion_operation_id is null) and (work_evidence is null)) or (((work_source) = 'canonical_done_work') and ((kind) = 'labor') and (completion_operation_id is not null) and (work_evidence is not null)))),
    CHECK (kind in ('LABOR', 'CONTRACTOR_SERVICE'))
);

-- TABLE: repair_cost_adjustment  (satrlar: 0 — BO`SH)
CREATE TABLE repair_cost_adjustment (
    id uuid NOT NULL,
    acted_at timestamptz NOT NULL,
    actor_id uuid NOT NULL,
    actor_name varchar(256) NOT NULL,
    branch_id uuid NOT NULL,
    document_reference varchar(255) NOT NULL,
    kind varchar(16) NOT NULL,  -- RUXSAT: 'CANCEL', 'REPLACE'
    line_reference varchar(128) NOT NULL,
    payload_identity varchar(64) NOT NULL,
    payload_json text NOT NULL,  -- [JSON matn]
    previous_adjustment_id uuid,
    reason varchar(2000) NOT NULL,
    repair_id uuid NOT NULL,
    repair_version bigint NOT NULL,
    replacement_source_id uuid,
    root_source_id uuid NOT NULL,
    source_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    PRIMARY KEY (id),
    CHECK (kind in ('CANCEL', 'REPLACE'))
);

-- TABLE: repair_cost_adjustment_closed  (satrlar: noma'lum)
CREATE TABLE repair_cost_adjustment_closed (
    id uuid NOT NULL,
    repair_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    replacement_command_id uuid,
    original_json text NOT NULL,  -- [JSON matn]
    raw_command text NOT NULL,
    raw_sha varchar(64) NOT NULL,
    payload_sha varchar(64) NOT NULL,
    reason text NOT NULL,
    receipt_json text NOT NULL,  -- [JSON matn]
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (repair_id) REFERENCES vehicle_repair(id),
    CHECK (((replacement_command_id is null) or (replacement_command_id <> id))),
    CHECK (((payload_sha) ~ '^[0-9a-f]{64}$')),
    CHECK (((raw_sha) ~ '^[0-9a-f]{64}$')),
    CHECK (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 2000)))
);

-- TABLE: repair_cost_adjustment_head  (satrlar: noma'lum)
CREATE TABLE repair_cost_adjustment_head (
    root_source_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    current_adjustment_id uuid,
    current_source_id uuid,
    repair_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    version bigint NOT NULL,
    PRIMARY KEY (root_source_id)
);

-- TABLE: repair_cost_canonical_active  (satrlar: noma'lum)
CREATE TABLE repair_cost_canonical_active (
    repair_id uuid NOT NULL,
    work_id text NOT NULL,
    source_id uuid NOT NULL,
    PRIMARY KEY (repair_id, work_id),
    FOREIGN KEY (source_id) REFERENCES repair_cost_acceptance(id)
);

-- TABLE: repair_material_operating_price  (satrlar: noma'lum)
CREATE TABLE repair_material_operating_price (
    id uuid NOT NULL,
    source_id uuid NOT NULL,
    repair_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    source_version bigint NOT NULL,
    owner_epoch bigint NOT NULL,
    quantity numeric(16,3) NOT NULL,
    unit varchar(32) NOT NULL,
    unit_rate numeric(20,6) NOT NULL,
    currency varchar(3) NOT NULL,
    money_scale integer NOT NULL,
    amount numeric(24,6) NOT NULL,
    price_document varchar(255) NOT NULL,
    confirmed_at timestamptz NOT NULL,
    payload_json text NOT NULL,  -- [JSON matn]
    source_json text NOT NULL,  -- [JSON matn]
    fact_json text NOT NULL,  -- [JSON matn]
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (id) REFERENCES repair_material_price_closure(id),
    FOREIGN KEY (repair_id) REFERENCES vehicle_repair(id),
    FOREIGN KEY (source_id) REFERENCES material_operation(id),
    CHECK (((amount = (quantity * unit_rate)) and (trunc(amount, money_scale) = amount))),
    CHECK (((money_scale >= 0) and (money_scale <= 6))),
    CHECK ((owner_epoch >= 0)),
    CHECK ((quantity > (0))),
    CHECK ((source_version >= 0)),
    CHECK ((unit_rate >= (0)))
);

-- TABLE: repair_material_price_closure  (satrlar: 0 — BO`SH)
CREATE TABLE repair_material_price_closure (
    id uuid NOT NULL,
    repair_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    state varchar(16) NOT NULL,  -- RUXSAT: 'RECORDED', 'NOT_EXECUTED'
    payload_json text NOT NULL,  -- [JSON matn]
    reason text,
    receipt_json text NOT NULL,  -- [JSON matn]
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (repair_id) REFERENCES vehicle_repair(id),
    CHECK (((((state) = 'not_executed') and repair_cost_text_ok(reason, 2000, true)) or (((state) = 'recorded') and (reason is null)))),
    CHECK (state in ('RECORDED', 'NOT_EXECUTED'))
);

-- TABLE: repair_order_part_request  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Ta'mirga EHTIYOT QISM so'rovi: qaysi ta'mir buyurtmasiga, qaysi tovar
-- (item_name), qancha so'ralgan/berilgan/ishlatilgan/qaytarilgan,
-- o'lchov birligi, qaysi ombordan. Ta'mirning o'zi vehicle_repair da.
-- ---------------------------------------------------------------------
CREATE TABLE repair_order_part_request (
    id uuid NOT NULL,
    branch_id uuid,
    created_at timestamptz NOT NULL,
    issued_at timestamptz,
    issued_by varchar(255),
    issued_quantity numeric(14,3),
    item_id uuid NOT NULL,
    item_name varchar(256),
    notes varchar(2000),
    rejection_reason varchar(1000),
    repair_order_id uuid NOT NULL,
    requested_at timestamptz NOT NULL,
    requested_by varchar(255) NOT NULL,
    requested_quantity numeric(14,3) NOT NULL,
    return_requested_at timestamptz,
    return_requested_by varchar(255),
    return_requested_quantity numeric(14,3),
    returned_at timestamptz,
    returned_by varchar(255),
    returned_quantity numeric(14,3),
    status varchar(64) NOT NULL,  -- RUXSAT: 'REQUESTED', 'WAITING_PARTS_APPROVAL', 'PARTS_APPROVED', 'ISSUED', 'RETURN_REQUESTED', 'RETURNED', 'USED', 'REJECTED'; BAZADA: 'USED' 9; ISHLATILMAGAN: REQUESTED, WAITING_PARTS_APPROVAL, PARTS_APPROVED, ISSUED, RETURN_REQUESTED, RETURNED, REJECTED
    unit_of_measure varchar(32),
    updated_at timestamptz NOT NULL,
    used_at timestamptz,
    used_by varchar(255),
    used_quantity numeric(14,3),
    vehicle_id uuid NOT NULL,
    warehouse_id uuid,
    approved_at timestamptz,
    approved_by varchar(255),
    stock_id uuid,
    version bigint NOT NULL,
    transport_head_approved_by varchar(255),
    transport_head_approved_at timestamptz,
    pto_approved_by varchar(255),
    pto_approved_at timestamptz,
    arm_installed_by varchar(255),
    arm_installed_at timestamptz,
    pto_installed_by varchar(255),
    pto_installed_at timestamptz,
    installed_location varchar(500),
    disposition_note varchar(500),
    requisition_number varchar(64),
    PRIMARY KEY (id),
    CHECK (status in ('REQUESTED', 'WAITING_PARTS_APPROVAL', 'PARTS_APPROVED', 'ISSUED', 'RETURN_REQUESTED', 'RETURNED', 'USED', 'REJECTED'))
);

-- TABLE: repair_stage_signature  (satrlar: 0 — BO`SH)
CREATE TABLE repair_stage_signature (
    operation_id uuid NOT NULL,
    repair_id uuid NOT NULL,
    repair_version bigint NOT NULL,
    stage varchar(64) NOT NULL,  -- RUXSAT: 'REPAIR_WORK_COMPLETION', 'REPAIR_FINAL_APPROVAL'
    actor_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    payload_sha256 varchar(64) NOT NULL,
    payload text NOT NULL,
    signature_data text NOT NULL,
    certificate_sha256 varchar(64) NOT NULL,
    certificate_serial varchar(128) NOT NULL,
    signer_name varchar(128) NOT NULL,
    signed_at timestamptz NOT NULL,
    certificate_valid_until timestamptz NOT NULL,
    authority_id uuid NOT NULL,
    authority_revision bigint NOT NULL,
    policy_id uuid NOT NULL,
    policy_revision bigint NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (policy_id) REFERENCES integration_signature_policy(id),
    FOREIGN KEY (repair_id) REFERENCES vehicle_repair(id),
    CHECK (((certificate_sha256) ~ '^[a-f0-9]{64}$')),
    CHECK (coalesce(((payload_sha256) = encode(sha256(convert_to(payload, 'utf8'::name)), 'hex')), false)),
    CHECK (coalesce(((((payload)::jsonb ->> 'actorid'))::uuid = actor_id), false)),
    CHECK (coalesce(((((payload)::jsonb #>> '{repair,id}'[]))::uuid = repair_id), false)),
    CHECK (coalesce(((((payload)::jsonb #>> '{repair,branchid}'[]))::uuid = branch_id), false)),
    CHECK (coalesce(((((payload)::jsonb #>> '{repair,version}'[])) = repair_version), false)),
    CHECK (coalesce(((((payload)::jsonb #>> '{command,operationid}'[]))::uuid = operation_id), false)),
    CHECK (coalesce((((payload)::jsonb #>> '{command,stage}'[]) = (stage)), false)),
    CHECK (coalesce((((payload)::jsonb ->> 'contract') = 'atil_repair_stage_signature_v1'), false)),
    CHECK (((payload_sha256) ~ '^[a-f0-9]{64}$')),
    CHECK ((repair_version >= 0)),
    CHECK (((length(signature_data) >= 1) and (length(signature_data) <= 20000))),
    CHECK (stage in ('REPAIR_WORK_COMPLETION', 'REPAIR_FINAL_APPROVAL'))
);

-- TABLE: repair_temporary_acceptance  (satrlar: 0 — BO`SH)
CREATE TABLE repair_temporary_acceptance (
    operation_id uuid NOT NULL,
    repair_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    action text NOT NULL,  -- RUXSAT: 'ACCEPT', 'REVOKE'
    policy_id uuid,
    target_id uuid,
    original jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    source_hash text NOT NULL,
    prior_status text NOT NULL,
    valid_until timestamptz,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (operation_id) REFERENCES fleet_operation(operation_id),
    FOREIGN KEY (policy_id) REFERENCES repair_temporary_policy(operation_id),
    FOREIGN KEY (repair_id) REFERENCES vehicle_repair(id),
    FOREIGN KEY (target_id) REFERENCES repair_temporary_acceptance(operation_id),
    CHECK (action in ('ACCEPT', 'REVOKE')),
    CHECK ((((action = 'accept') and (policy_id is not null) and (target_id is null) and (valid_until is not null)) or ((action = 'revoke') and (target_id is not null))))
);

-- TABLE: repair_temporary_policy  (satrlar: 0 — BO`SH)
CREATE TABLE repair_temporary_policy (
    operation_id uuid NOT NULL,
    repair_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    action text NOT NULL,  -- RUXSAT: 'AUTHOR', 'APPROVE', 'POLICY_REVOKE'
    policy_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    sources jsonb NOT NULL,  -- [JSON matn]
    source_hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (operation_id) REFERENCES fleet_operation(operation_id),
    FOREIGN KEY (policy_id) REFERENCES repair_temporary_policy(operation_id),
    FOREIGN KEY (repair_id) REFERENCES vehicle_repair(id),
    CHECK (action in ('AUTHOR', 'APPROVE', 'POLICY_REVOKE'))
);

-- TABLE: report_export_job  (satrlar: 0 — BO`SH)
CREATE TABLE report_export_job (
    operation_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    kind text NOT NULL,  -- RUXSAT: 'FINANCE_ANALYTICS', 'OPERATIONAL_SNAPSHOT', 'FUEL_MONTHLY'
    source_id uuid NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    original_hash text NOT NULL,
    source_hash text NOT NULL,
    source_version text NOT NULL,
    row_count bigint NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'QUEUED', 'RUNNING', 'READY', 'FAILED'
    attempt bigint NOT NULL,
    lease_token uuid,  -- [MAXFIY — o'qish taqiqlangan]
    lease_until timestamptz,
    reason text,
    artifact bytea,
    artifact_hash text,
    byte_count bigint,
    emitted_rows bigint,
    created_at timestamptz NOT NULL,
    finished_at timestamptz,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    CHECK ((attempt >= 0)),
    CHECK (((state <> 'ready') or (((artifact is not null) and (artifact_hash = encode(sha256(artifact), 'hex')) and (byte_count = octet_length(artifact)) and (emitted_rows = row_count) and (finished_at is not null)) is true))),
    CHECK (kind in ('FINANCE_ANALYTICS', 'OPERATIONAL_SNAPSHOT', 'FUEL_MONTHLY')),
    CHECK ((original_hash ~ '^[a-f0-9]{64}$')),
    CHECK ((reason ~ '^[a-z_]{1,64}$')),
    CHECK ((row_count >= 0)),
    CHECK ((source_hash ~ '^[a-f0-9]{64}$')),
    CHECK (state in ('QUEUED', 'RUNNING', 'READY', 'FAILED'))
);

-- TABLE: retention_document_blob  (satrlar: noma'lum)
CREATE TABLE retention_document_blob (
    version_id uuid NOT NULL,
    storage_key text NOT NULL,
    metadata_hash text NOT NULL,
    content_hash text NOT NULL,
    content bytea NOT NULL,
    captured_at timestamptz NOT NULL,
    PRIMARY KEY (version_id),
    CHECK ((content_hash = encode(sha256(content), 'hex'))),
    CHECK ((octet_length(content) <= 268435456))
);

-- TABLE: retention_record_catalog  (satrlar: noma'lum)
CREATE TABLE retention_record_catalog (
    source_table text NOT NULL,
    event_type text NOT NULL,
    category text NOT NULL,  -- RUXSAT: 'BUSINESS', 'GPS', 'TECHNICAL_LOG'; BAZADA: 'BUSINESS' 35, 'GPS' 1, 'TECHNICAL_LOG' 1
    primary_key_columns text[] NOT NULL,
    time_column text NOT NULL,
    suggested_days integer NOT NULL,
    PRIMARY KEY (source_table),
    CHECK (category in ('BUSINESS', 'GPS', 'TECHNICAL_LOG')),
    CHECK ((event_type = ('record_' || upper(source_table)))),
    CHECK ((cardinality(primary_key_columns) > 0)),
    CHECK ((source_table ~ '^[a-z][a-z0-9_]*$')),
    CHECK ((suggested_days > 0))
);

-- TABLE: retention_record_proof  (satrlar: noma'lum)
CREATE TABLE retention_record_proof (
    archive_id uuid NOT NULL,
    event_id uuid NOT NULL,
    source_table text NOT NULL,
    source_key jsonb NOT NULL,  -- [JSON matn]
    relationship_keys jsonb NOT NULL,  -- [JSON matn]
    payload_hash text NOT NULL,
    PRIMARY KEY (archive_id, event_id)
);

-- TABLE: retention_technical_log  (satrlar: noma'lum)
CREATE TABLE retention_technical_log (
    id uuid NOT NULL,
    occurred_at timestamptz NOT NULL,
    received_at timestamptz NOT NULL,
    level text NOT NULL,
    logger text NOT NULL,
    thread text NOT NULL,
    message text NOT NULL,
    throwable text,
    source_instance uuid NOT NULL,
    source_sequence bigint NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: route  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- MARSHRUTLAR BO'YICHA ASOSIY JADVAL. Marshrut raqami, nomi, rejalashtirilgan
-- davomiylik (planned_duration_minutes) — MASOFA USTUNI BU JADVALDA YO'Q,
-- amaldagi masofa uchun trip.actual_distance_km ishlatiladi;
-- talab qilinadigan transport turi
-- (required_transport_type) va haydovchi toifasi (required_driver_category),
-- biriktirilgan mashina va haydovchi.
-- status: DRAFT, READY_FOR_ASSIGNMENT, DRIVER_ASSIGNED, VEHICLE_ASSIGNED,
-- FULLY_ASSIGNED, TRIP_PLANNED, CANCELLED.
-- assignment_decision_status biriktirish bosqichini ko'rsatadi.
-- Marshrut nuqtalari route_point jadvalida, bog'liq so'rovlar
-- route_transport_request orqali.
-- ---------------------------------------------------------------------
CREATE TABLE route (
    id uuid NOT NULL,
    assigned_driver_id uuid,
    assigned_vehicle_id uuid,
    assignment_decision_status varchar(32) NOT NULL,  -- RUXSAT: 'PENDING', 'VEHICLE_ASSIGNED', 'DRIVER_ASSIGNED', 'FULLY_ASSIGNED', 'TRIP_PLANNED'; BAZADA: 'FULLY_ASSIGNED' 2698, 'TRIP_PLANNED' 1967, 'PENDING' 33, 'VEHICLE_ASSIGNED' 2, 'DRIVER_ASSIGNED' 1
    created_at timestamptz NOT NULL,
    latitude float8,
    longitude float8,
    name varchar(255) NOT NULL,
    planned_arrival_at timestamp,
    planned_departure_at timestamp,
    planned_duration_minutes bigint NOT NULL,
    planned_trip_id uuid,
    planned_trip_number varchar(255),
    required_driver_category varchar(8) NOT NULL,  -- RUXSAT: 'A', 'B', 'BE', 'C', 'CE', 'D', 'DE', 'E'; BAZADA: 'B' 1961, 'C' 1566, 'D' 585, 'CE' 253, 'DE' 120, 'BE' 116, 'A' 78, 'E' 22
    required_transport_type varchar(32) NOT NULL,  -- RUXSAT: 'MOBILE_CRANE', 'AERIAL_PLATFORM', 'TRACTOR', 'WATER_TRUCK', 'EXCAVATOR', 'FRONT_LOADER', 'DUMP_TRUCK', 'LONG_LOAD_TRUCK', 'FLATBED', 'MANIPULATOR', 'PASSENGER_CAR', 'BUS', 'VAN', 'BULLDOZER', 'CONCRETE_PUMP', 'CONCRETE_MIXER', 'FIRE_TRUCK', 'AMBULANCE', 'TRUCK', 'TANKER', 'REFRIGERATED', 'SPECIALIZED', 'MINIBUS', 'PICKUP', 'TRAILER', 'OTHER', 'ELECTRIC_VEHICLE'; BAZADA: 'PASSENGER_CAR' 1896, 'BUS' 747, 'DUMP_TRUCK' 505, 'FLATBED' 308, 'TRACTOR' 227, 'MOBILE_CRANE' 226, 'FRONT_LOADER' 164, 'AERIAL_PLATFORM' 142, 'EXCAVATOR' 131, 'LONG_LOAD_TRUCK' 129, 'VAN' 96, 'MANIPULATOR' 47, 'WATER_TRUCK' 39, 'SPECIALIZED' 26, 'ELECTRIC_VEHICLE' 12, 'CONCRETE_MIXER' 3; ISHLATILMAGAN: BULLDOZER, CONCRETE_PUMP, FIRE_TRUCK, AMBULANCE, TRUCK, TANKER, REFRIGERATED, MINIBUS, PICKUP, TRAILER, OTHER
    route_number varchar(32) NOT NULL,
    sequence_number integer,
    status varchar(32) NOT NULL,  -- RUXSAT: 'DRAFT', 'READY_FOR_ASSIGNMENT', 'DRIVER_ASSIGNED', 'VEHICLE_ASSIGNED', 'FULLY_ASSIGNED', 'TRIP_PLANNED', 'CANCELLED'; BAZADA: 'FULLY_ASSIGNED' 2698, 'TRIP_PLANNED' 1967, 'READY_FOR_ASSIGNMENT' 33, 'VEHICLE_ASSIGNED' 2; ISHLATILMAGAN: DRAFT, DRIVER_ASSIGNED, CANCELLED
    updated_at timestamptz NOT NULL,
    version bigint NOT NULL,
    planning_end_instant timestamptz,
    planning_end_local varchar(64),
    planning_start_instant timestamptz,
    planning_start_local varchar(64),
    planning_time_zone varchar(64),
    requestless_plan_json text,  -- [JSON matn]
    PRIMARY KEY (id),
    CHECK (assignment_decision_status in ('PENDING', 'VEHICLE_ASSIGNED', 'DRIVER_ASSIGNED', 'FULLY_ASSIGNED', 'TRIP_PLANNED')),
    CHECK (required_driver_category in ('A', 'B', 'BE', 'C', 'CE', 'D', 'DE', 'E')),
    CHECK (required_transport_type in ('MOBILE_CRANE', 'AERIAL_PLATFORM', 'TRACTOR', 'WATER_TRUCK', 'EXCAVATOR', 'FRONT_LOADER', 'DUMP_TRUCK', 'LONG_LOAD_TRUCK', 'FLATBED', 'MANIPULATOR', 'PASSENGER_CAR', 'BUS', 'VAN', 'BULLDOZER', 'CONCRETE_PUMP', 'CONCRETE_MIXER', 'FIRE_TRUCK', 'AMBULANCE', 'TRUCK', 'TANKER', 'REFRIGERATED', 'SPECIALIZED', 'MINIBUS', 'PICKUP', 'TRAILER', 'OTHER', 'ELECTRIC_VEHICLE')),
    CHECK (status in ('DRAFT', 'READY_FOR_ASSIGNMENT', 'DRIVER_ASSIGNED', 'VEHICLE_ASSIGNED', 'FULLY_ASSIGNED', 'TRIP_PLANNED', 'CANCELLED'))
);

-- TABLE: route_point  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Marshrut nuqtalari: ketma-ketlik raqami (sequence_number), nuqta turi
-- (ORIGIN, WAYPOINT, LOADING, UNLOADING, DESTINATION), oldingi nuqtadan masofa va
-- yurish vaqti, rejadagi kelish/ketish vaqti, koordinata.
-- MARSHRUT YO'NALISHI SO'RALSA sequence_number BO'YICHA TARTIBLANADI.
-- ---------------------------------------------------------------------
CREATE TABLE route_point (
    id uuid NOT NULL,
    distance_from_previous_km numeric(14,3) NOT NULL,
    drive_duration_from_previous_minutes bigint NOT NULL,
    latitude float8,
    location_id uuid NOT NULL,
    location_name varchar(512),
    longitude float8,
    planned_arrival_at timestamp NOT NULL,
    planned_departure_at timestamp NOT NULL,
    point_type varchar(32) NOT NULL,
    sequence_number integer NOT NULL,
    route_id uuid NOT NULL,
    planning_end_instant timestamptz,
    planning_end_local varchar(64),
    planning_start_instant timestamptz,
    planning_start_local varchar(64),
    planning_time_zone varchar(64),
    PRIMARY KEY (id),
    FOREIGN KEY (route_id) REFERENCES route(id)
);

-- TABLE: route_transport_request  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Marshrut va transport so'rovi o'rtasidagi bog'lovchi jadval. BITTA MARSHRUTGA
-- BIR NECHTA SO'ROV BIRLASHTIRILISHI MUMKIN (konsolidatsiya). So'rov qaysi
-- marshrutga tushganini bilish uchun shu jadval orqali JOIN qilinadi.
-- ---------------------------------------------------------------------
CREATE TABLE route_transport_request (
    route_id uuid NOT NULL,
    transport_request_id uuid NOT NULL,
    FOREIGN KEY (route_id) REFERENCES route(id)
);

-- TABLE: safety_capa_action  (satrlar: 0 — BO`SH)
CREATE TABLE safety_capa_action (
    id uuid NOT NULL,
    incident_id uuid NOT NULL,
    kind varchar(16) NOT NULL,  -- RUXSAT: 'CORRECTIVE', 'PREVENTIVE'
    description text NOT NULL,
    owner_id uuid NOT NULL,
    due_at timestamptz NOT NULL,
    required boolean NOT NULL,
    state varchar(16) NOT NULL,  -- RUXSAT: 'OPEN', 'COMPLETED', 'EFFECTIVE', 'INEFFECTIVE'
    version bigint NOT NULL,
    completion_evidence_id uuid,
    completed_by uuid,
    completed_at timestamptz,
    effectiveness_evidence_id uuid,
    reviewed_by uuid,
    reviewed_at timestamptz,
    review_reason text,
    created_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (completed_by) REFERENCES app_user(id),
    FOREIGN KEY (completion_evidence_id) REFERENCES safety_domain_evidence(id),
    FOREIGN KEY (created_by) REFERENCES app_user(id),
    FOREIGN KEY (effectiveness_evidence_id) REFERENCES safety_domain_evidence(id),
    FOREIGN KEY (incident_id) REFERENCES incident(id),
    FOREIGN KEY (owner_id) REFERENCES app_user(id),
    FOREIGN KEY (reviewed_by) REFERENCES app_user(id),
    CHECK ((((state) = 'open') or (completion_evidence_id is not null))),
    CHECK ((((state) <> all (array[('effective'), ('ineffective')])) or ((effectiveness_evidence_id is not null) and (reviewed_by <> owner_id) and (reviewed_by <> created_by)))),
    CHECK (((length(trim(both from description)) >= 1) and (length(trim(both from description)) <= 4000))),
    CHECK (kind in ('CORRECTIVE', 'PREVENTIVE')),
    CHECK (state in ('OPEN', 'COMPLETED', 'EFFECTIVE', 'INEFFECTIVE'))
);

-- TABLE: safety_domain_evidence  (satrlar: 0 — BO`SH)
CREATE TABLE safety_domain_evidence (
    id uuid NOT NULL,
    aggregate_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    domain varchar(16) NOT NULL,  -- RUXSAT: 'INCIDENT', 'INCIDENT_RETURN', 'FINE'
    kind varchar(32) NOT NULL,  -- RUXSAT: 'PHOTO', 'DOCUMENT', 'PAYMENT', 'EXECUTION', 'EFFECTIVENESS', 'RETURN'
    file_name text,
    content_type text,
    sha256 varchar(64) NOT NULL,
    content_bytes bytea NOT NULL,
    source_reference text NOT NULL,
    occurred_at timestamptz NOT NULL,
    actor_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK (((octet_length(content_bytes) >= 1) and (octet_length(content_bytes) <= 10485760))),
    CHECK (domain in ('INCIDENT', 'INCIDENT_RETURN', 'FINE')),
    CHECK (kind in ('PHOTO', 'DOCUMENT', 'PAYMENT', 'EXECUTION', 'EFFECTIVENESS', 'RETURN')),
    CHECK (((sha256) ~ '^[a-f0-9]{64}$')),
    CHECK ((length(trim(both from source_reference)) > 0))
);

-- TABLE: safety_domain_history  (satrlar: noma'lum)
CREATE TABLE safety_domain_history (
    id uuid NOT NULL,
    aggregate_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    domain varchar(32) NOT NULL,
    aggregate_version bigint NOT NULL,
    transaction_id bigint NOT NULL,
    action varchar(64) NOT NULL,
    actor_id uuid NOT NULL,
    actor_kind varchar(32) NOT NULL,
    reason text NOT NULL,
    before_json jsonb NOT NULL,  -- [JSON matn]
    after_json jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 2000)))
);

-- TABLE: safety_draft_replan_permit  (satrlar: 0 — BO`SH)
CREATE TABLE safety_draft_replan_permit (
    id uuid NOT NULL,
    qualification_permit_id uuid NOT NULL,
    target_type varchar(24) NOT NULL,  -- RUXSAT: 'ROUTE', 'TRIP', 'WAYBILL'
    target_id uuid NOT NULL,
    target_version bigint NOT NULL,
    branch_id uuid NOT NULL,
    route_id uuid NOT NULL,
    load_revision_id uuid NOT NULL,
    load_assessment_hash varchar(64) NOT NULL,
    actor_id uuid NOT NULL,
    state varchar(24) NOT NULL,
    positive_driving_clearance boolean NOT NULL,
    transaction_id bigint NOT NULL,
    proof_json text NOT NULL,  -- [JSON matn]
    proof_hash varchar(64) NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (load_revision_id) REFERENCES transport_load_manifest_revision(id),
    FOREIGN KEY (qualification_permit_id) REFERENCES driver_qualification_permit(id),
    FOREIGN KEY (route_id) REFERENCES route(id),
    CHECK ((not positive_driving_clearance)),
    CHECK (((state) = 'pending_review')),
    CHECK (target_type in ('ROUTE', 'TRIP', 'WAYBILL')),
    CHECK ((target_version > 0))
);

-- TABLE: safety_fine_policy  (satrlar: 0 — BO`SH)
CREATE TABLE safety_fine_policy (
    id uuid NOT NULL,
    branch_id uuid NOT NULL,
    regulation_reference text NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_to timestamptz NOT NULL,
    amount_per_excess_kph numeric(14,2) NOT NULL,
    speed_limit_kph numeric(10,3) NOT NULL,
    currency varchar(3) NOT NULL,
    rounding_mode varchar(16) NOT NULL,  -- RUXSAT: 'HALF_UP', 'HALF_EVEN', 'DOWN', 'UP'
    created_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    approved_by uuid,
    approved_at timestamptz,
    revoked_by uuid,
    revoked_at timestamptz,
    revocation_reason text,
    PRIMARY KEY (id),
    FOREIGN KEY (approved_by) REFERENCES app_user(id),
    FOREIGN KEY (created_by) REFERENCES app_user(id),
    FOREIGN KEY (revoked_by) REFERENCES app_user(id),
    CHECK ((amount_per_excess_kph > (0))),
    CHECK ((valid_to > valid_from)),
    CHECK (((approved_by is null) or (approved_by <> created_by))),
    CHECK (((approved_by is null) = (approved_at is null))),
    CHECK (((currency) ~ '^[a-z]{3}$')),
    CHECK ((length(trim(both from regulation_reference)) > 0)),
    CHECK (rounding_mode in ('HALF_UP', 'HALF_EVEN', 'DOWN', 'UP')),
    CHECK ((speed_limit_kph > (0)))
);

-- TABLE: safety_incident_notification_outbox  (satrlar: noma'lum)
CREATE TABLE safety_incident_notification_outbox (
    id uuid NOT NULL,
    incident_id uuid NOT NULL,
    action_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    recipient_id uuid NOT NULL,
    event_kind varchar(32) NOT NULL,
    due_at timestamptz NOT NULL,
    state varchar(16) NOT NULL,
    attention_id uuid,
    next_attempt_at timestamptz,
    attempts integer NOT NULL,
    last_error varchar(1000),
    created_at timestamptz NOT NULL,
    delivered_at timestamptz,
    action_generation bigint,
    PRIMARY KEY (id),
    FOREIGN KEY (action_id) REFERENCES safety_capa_action(id),
    FOREIGN KEY (incident_id) REFERENCES incident(id),
    FOREIGN KEY (recipient_id) REFERENCES app_user(id)
);

-- TABLE: safety_incident_policy  (satrlar: noma'lum)
CREATE TABLE safety_incident_policy (
    id uuid NOT NULL,
    branch_id uuid NOT NULL,
    regulation_reference text NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_to timestamptz NOT NULL,
    independent_effectiveness_required boolean NOT NULL,
    corrective_action_required boolean NOT NULL,
    preventive_action_required boolean NOT NULL,
    primary_recipient_id uuid,
    backup_recipient_id uuid,
    escalation_hours integer,
    created_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    approved_by uuid,
    approved_at timestamptz,
    revoked_by uuid,
    revoked_at timestamptz,
    revocation_reason text,
    PRIMARY KEY (id),
    FOREIGN KEY (approved_by) REFERENCES app_user(id),
    FOREIGN KEY (backup_recipient_id) REFERENCES app_user(id),
    FOREIGN KEY (created_by) REFERENCES app_user(id),
    FOREIGN KEY (primary_recipient_id) REFERENCES app_user(id),
    FOREIGN KEY (revoked_by) REFERENCES app_user(id),
    CHECK ((valid_to > valid_from)),
    CHECK (((approved_by is null) or (approved_by <> created_by))),
    CHECK (((approved_by is null) = (approved_at is null))),
    CHECK (((primary_recipient_id is distinct from backup_recipient_id) or (primary_recipient_id is null))),
    CHECK (((escalation_hours >= 1) and (escalation_hours <= 8760))),
    CHECK ((length(trim(both from regulation_reference)) > 0))
);

-- TABLE: safety_incident_restriction  (satrlar: noma'lum)
CREATE TABLE safety_incident_restriction (
    id uuid NOT NULL,
    incident_id uuid,
    branch_id uuid,
    resource_kind varchar(16),
    resource_id uuid,
    section_reference text,
    decision varchar(8),
    blocked_decision_id uuid,
    effective_at timestamptz,
    expires_at timestamptz,
    evidence_id uuid,
    actor_id uuid,
    reason text,
    recorded_at timestamptz,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (blocked_decision_id) REFERENCES safety_incident_restriction(id),
    FOREIGN KEY (evidence_id) REFERENCES safety_domain_evidence(id),
    FOREIGN KEY (incident_id) REFERENCES incident(id)
);

-- TABLE: safety_medical_preservation  (satrlar: 0 — BO`SH)
CREATE TABLE safety_medical_preservation (
    id uuid NOT NULL,
    sequence bigint NOT NULL,
    branch_id uuid NOT NULL,
    object_type varchar(32) NOT NULL,  -- RUXSAT: 'MEDICAL_INSPECTION', 'EMERGENCY_CASE', 'CLINICAL_READ_AUDIT'
    object_id uuid NOT NULL,
    revision bigint NOT NULL,
    actor_id uuid NOT NULL,
    operation_id uuid NOT NULL,
    action varchar(32) NOT NULL,  -- RUXSAT: 'HOLD', 'RELEASE_HOLD', 'APPROVE_ARCHIVE_REVIEW'
    recorded_at timestamptz NOT NULL,
    payload jsonb NOT NULL,  -- [JSON matn]
    assessment_snapshot jsonb NOT NULL,  -- [JSON matn]
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    CHECK (action in ('HOLD', 'RELEASE_HOLD', 'APPROVE_ARCHIVE_REVIEW')),
    CHECK (object_type in ('MEDICAL_INSPECTION', 'EMERGENCY_CASE', 'CLINICAL_READ_AUDIT')),
    CHECK ((revision > 0))
);

-- TABLE: safety_medical_privacy_command_closure  (satrlar: 0 — BO`SH)
CREATE TABLE safety_medical_privacy_command_closure (
    operation_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    kind text NOT NULL,  -- RUXSAT: 'POLICY', 'DECISION', 'PRESERVATION'
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK (kind in ('POLICY', 'DECISION', 'PRESERVATION')),
    CHECK (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 2000)))
);

-- TABLE: safety_medical_private_read  (satrlar: noma'lum)
CREATE TABLE safety_medical_private_read (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    object_type varchar(32) NOT NULL,  -- RUXSAT: 'MEDICAL_INSPECTION', 'EMERGENCY_CASE'; BAZADA: 'MEDICAL_INSPECTION' 78196, 'EMERGENCY_CASE' 434
    object_id uuid NOT NULL,
    object_version bigint,
    view varchar(16) NOT NULL,  -- RUXSAT: 'DETAIL', 'SEARCH', 'HISTORY'; BAZADA: 'SEARCH' 78576, 'DETAIL' 29, 'HISTORY' 25
    record_count integer NOT NULL,
    correlation_id varchar(128),
    occurred_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    CHECK (object_type in ('MEDICAL_INSPECTION', 'EMERGENCY_CASE')),
    CHECK ((record_count >= 0)),
    CHECK (view in ('DETAIL', 'SEARCH', 'HISTORY'))
);

-- TABLE: safety_medical_retention_decision  (satrlar: 0 — BO`SH)
CREATE TABLE safety_medical_retention_decision (
    id uuid NOT NULL,
    sequence bigint NOT NULL,
    policy_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    operation_id uuid NOT NULL,
    action varchar(16) NOT NULL,  -- RUXSAT: 'APPROVE', 'REVOKE'
    recorded_at timestamptz NOT NULL,
    payload jsonb NOT NULL,  -- [JSON matn]
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (policy_id) REFERENCES safety_medical_retention_policy(id),
    CHECK (action in ('APPROVE', 'REVOKE'))
);

-- TABLE: safety_medical_retention_policy  (satrlar: 0 — BO`SH)
CREATE TABLE safety_medical_retention_policy (
    id uuid NOT NULL,
    branch_id uuid NOT NULL,
    object_type varchar(32) NOT NULL,  -- RUXSAT: 'MEDICAL_INSPECTION', 'EMERGENCY_CASE', 'CLINICAL_READ_AUDIT'
    version varchar(128) NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_to timestamptz NOT NULL,
    actor_id uuid NOT NULL,
    operation_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    payload jsonb NOT NULL,  -- [JSON matn]
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    CHECK ((valid_to > valid_from)),
    CHECK (object_type in ('MEDICAL_INSPECTION', 'EMERGENCY_CASE', 'CLINICAL_READ_AUDIT'))
);

-- TABLE: safety_operational_permit  (satrlar: noma'lum)
CREATE TABLE safety_operational_permit (
    id uuid NOT NULL,
    qualification_permit_id uuid NOT NULL,
    target_type varchar(24) NOT NULL,
    target_id uuid NOT NULL,
    target_version bigint NOT NULL,
    action varchar(24) NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    proof_json text NOT NULL,  -- [JSON matn]
    proof_hash varchar(64) NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (qualification_permit_id) REFERENCES driver_qualification_permit(id)
);

-- TABLE: safety_technical_inspection_revision  (satrlar: noma'lum)
CREATE TABLE safety_technical_inspection_revision (
    id uuid NOT NULL,
    inspection_id uuid NOT NULL,
    version bigint NOT NULL,
    action text NOT NULL,  -- RUXSAT: 'CREATE', 'CORRECT', 'CANCEL', 'REINSPECT'; BAZADA: 'CREATE' 508; ISHLATILMAGAN: CORRECT, CANCEL, REINSPECT
    vehicle_id uuid NOT NULL,
    trailer_id uuid,
    driver_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    trip_id uuid,
    waybill_id uuid,
    body jsonb NOT NULL,  -- [JSON matn]
    body_hash text NOT NULL,
    actor_id uuid NOT NULL,
    actor_name text NOT NULL,
    recorded_at timestamptz NOT NULL,
    reason text NOT NULL,
    medical_inspection_id uuid,
    medical_inspection_version bigint,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (driver_id) REFERENCES driver(id),
    FOREIGN KEY (medical_inspection_id) REFERENCES medical_inspection(id),
    FOREIGN KEY (trailer_id) REFERENCES trailers(id),
    FOREIGN KEY (trip_id) REFERENCES trip(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id),
    FOREIGN KEY (waybill_id) REFERENCES waybill(id),
    CHECK (action in ('CREATE', 'CORRECT', 'CANCEL', 'REINSPECT')),
    CHECK ((jsonb_typeof(body) = 'object')),
    CHECK ((length(body_hash) = 64)),
    CHECK (((medical_inspection_id is null) = (medical_inspection_version is null))),
    CHECK (((length(btrim(reason)) >= 1) and (length(btrim(reason)) <= 1000))),
    CHECK ((version > 0))
);

-- TABLE: safety_technical_limited_event  (satrlar: 0 — BO`SH)
CREATE TABLE safety_technical_limited_event (
    id uuid NOT NULL,
    inspection_revision_id uuid NOT NULL,
    version bigint NOT NULL,
    action text NOT NULL,  -- RUXSAT: 'APPROVE', 'REVOKE'
    actor_id uuid NOT NULL,
    actor_name text NOT NULL,
    occurred_at timestamptz NOT NULL,
    reason text NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (inspection_revision_id) REFERENCES safety_technical_inspection_revision(id),
    CHECK (action in ('APPROVE', 'REVOKE')),
    CHECK (((length(btrim(reason)) >= 1) and (length(btrim(reason)) <= 1000))),
    CHECK ((version > 0))
);

-- TABLE: safety_technical_operation  (satrlar: noma'lum)
CREATE TABLE safety_technical_operation (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    action text NOT NULL,
    request_json jsonb NOT NULL,  -- [JSON matn]
    result_json jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'APPLIED', 'NOT_EXECUTED'
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK (state in ('APPLIED', 'NOT_EXECUTED'))
);

-- TABLE: safety_technical_photo  (satrlar: noma'lum)
CREATE TABLE safety_technical_photo (
    id uuid NOT NULL,
    branch_id uuid NOT NULL,
    name text NOT NULL,
    content_type text NOT NULL,  -- RUXSAT: 'image/png', 'image/jpeg'; BAZADA: 'image/jpeg' 338, 'image/png' 2
    size_bytes bigint NOT NULL,
    sha256 text NOT NULL,
    authored_by uuid NOT NULL,
    authored_at timestamptz NOT NULL,
    reason text NOT NULL,
    bytes bytea NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (authored_by) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    CHECK ((size_bytes = octet_length(bytes))),
    CHECK ((sha256 = encode(sha256(bytes), 'hex'))),
    CHECK (content_type in ('image/png', 'image/jpeg')),
    CHECK (((length(name) >= 1) and (length(name) <= 256))),
    CHECK (((length(btrim(reason)) >= 1) and (length(btrim(reason)) <= 1000))),
    CHECK ((length(sha256) = 64)),
    CHECK (((size_bytes >= 1) and (size_bytes <= 10485760)))
);

-- TABLE: safety_technical_policy  (satrlar: noma'lum)
CREATE TABLE safety_technical_policy (
    id uuid NOT NULL,
    branch_id uuid NOT NULL,
    version bigint NOT NULL,
    body jsonb NOT NULL,  -- [JSON matn]
    body_hash text NOT NULL,
    authored_by uuid NOT NULL,
    authored_at timestamptz NOT NULL,
    reason text NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (authored_by) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    CHECK ((jsonb_typeof(body) = 'object')),
    CHECK ((length(body_hash) = 64)),
    CHECK (((length(btrim(reason)) >= 1) and (length(btrim(reason)) <= 1000))),
    CHECK ((version > 0))
);

-- TABLE: safety_technical_policy_event  (satrlar: noma'lum)
CREATE TABLE safety_technical_policy_event (
    id uuid NOT NULL,
    policy_id uuid NOT NULL,
    version bigint NOT NULL,
    action text NOT NULL,  -- RUXSAT: 'APPROVE', 'REVOKE'
    actor_id uuid NOT NULL,
    actor_name text NOT NULL,
    occurred_at timestamptz NOT NULL,
    reason text NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (policy_id) REFERENCES safety_technical_policy(id),
    CHECK (action in ('APPROVE', 'REVOKE')),
    CHECK (((length(btrim(reason)) >= 1) and (length(btrim(reason)) <= 1000))),
    CHECK ((version > 0))
);

-- TABLE: safety_work_rest_calculation  (satrlar: noma'lum)
CREATE TABLE safety_work_rest_calculation (
    id uuid NOT NULL,
    supersedes_id uuid,
    branch_id uuid NOT NULL,
    driver_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    calculated_at timestamptz NOT NULL,
    as_of timestamptz NOT NULL,
    context jsonb NOT NULL,  -- [JSON matn]
    result jsonb NOT NULL,  -- [JSON matn]
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (supersedes_id) REFERENCES safety_work_rest_calculation(id)
);

-- TABLE: safety_work_rest_coverage  (satrlar: noma'lum)
CREATE TABLE safety_work_rest_coverage (
    id uuid NOT NULL,
    sequence bigint NOT NULL,
    branch_id uuid NOT NULL,
    driver_id uuid NOT NULL,
    source_id uuid NOT NULL,
    event_id varchar(256) NOT NULL,
    from_at timestamptz NOT NULL,
    to_at timestamptz NOT NULL,
    state varchar(24) NOT NULL,  -- RUXSAT: 'COMPLETE', 'PARTIAL', 'UNAVAILABLE'
    actor_id uuid NOT NULL,
    operation_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    payload jsonb NOT NULL,  -- [JSON matn]
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (driver_id) REFERENCES driver(id),
    CHECK ((to_at > from_at)),
    CHECK (state in ('COMPLETE', 'PARTIAL', 'UNAVAILABLE'))
);

-- TABLE: safety_work_rest_policy  (satrlar: noma'lum)
CREATE TABLE safety_work_rest_policy (
    id uuid NOT NULL,
    branch_id uuid NOT NULL,
    jurisdiction varchar(128) NOT NULL,
    route_id uuid,
    version varchar(128) NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_to timestamptz NOT NULL,
    actor_id uuid NOT NULL,
    operation_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    payload jsonb NOT NULL,  -- [JSON matn]
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK ((valid_to > valid_from))
);

-- TABLE: safety_work_rest_policy_decision  (satrlar: noma'lum)
CREATE TABLE safety_work_rest_policy_decision (
    id uuid NOT NULL,
    sequence bigint NOT NULL,
    policy_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    operation_id uuid NOT NULL,
    state varchar(16) NOT NULL,  -- RUXSAT: 'APPROVED', 'REVOKED'
    recorded_at timestamptz NOT NULL,
    payload jsonb NOT NULL,  -- [JSON matn]
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (policy_id) REFERENCES safety_work_rest_policy(id),
    CHECK (state in ('APPROVED', 'REVOKED'))
);

-- TABLE: safety_work_rest_segment  (satrlar: noma'lum)
CREATE TABLE safety_work_rest_segment (
    id uuid NOT NULL,
    original_id uuid NOT NULL,
    correction_of uuid,
    revision bigint NOT NULL,
    branch_id uuid NOT NULL,
    driver_id uuid NOT NULL,
    vehicle_id uuid,
    source_id uuid NOT NULL,
    event_id varchar(256) NOT NULL,
    started_at timestamptz NOT NULL,
    ended_at timestamptz NOT NULL,
    time_zone varchar(128) NOT NULL,
    mode varchar(24) NOT NULL,  -- RUXSAT: 'DRIVE', 'REST', 'OTHER_WORK', 'AVAILABILITY', 'UNKNOWN'; BAZADA: 'OTHER_WORK' 5; ISHLATILMAGAN: DRIVE, REST, AVAILABILITY, UNKNOWN
    quality varchar(24) NOT NULL,  -- RUXSAT: 'CONFIRMED', 'UNCONFIRMED', 'INVALID', 'VOID'
    actor_id uuid NOT NULL,
    operation_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    payload jsonb NOT NULL,  -- [JSON matn]
    original_command jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (correction_of) REFERENCES safety_work_rest_segment(id),
    FOREIGN KEY (driver_id) REFERENCES driver(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id),
    CHECK ((ended_at > started_at)),
    CHECK (mode in ('DRIVE', 'REST', 'OTHER_WORK', 'AVAILABILITY', 'UNKNOWN')),
    CHECK (quality in ('CONFIRMED', 'UNCONFIRMED', 'INVALID', 'VOID')),
    CHECK ((revision > 0))
);

-- TABLE: safety_work_rest_source  (satrlar: noma'lum)
CREATE TABLE safety_work_rest_source (
    id uuid NOT NULL,
    source_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    revision bigint NOT NULL,
    actor_id uuid NOT NULL,
    operation_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    payload jsonb NOT NULL,  -- [JSON matn]
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK ((revision > 0))
);

-- TABLE: service_contract  (satrlar: 0 — BO`SH)
CREATE TABLE service_contract (
    id uuid NOT NULL,
    branch_id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    currency varchar(3) NOT NULL,
    customer_id uuid NOT NULL,
    department_id uuid,
    number varchar(128) NOT NULL,
    status varchar(16) NOT NULL,  -- RUXSAT: 'DRAFT', 'ACTIVE', 'INACTIVE'
    updated_at timestamptz NOT NULL,
    updated_by uuid NOT NULL,
    valid_from date NOT NULL,
    valid_to date,
    version bigint NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (customer_id) REFERENCES customer(id),
    FOREIGN KEY (department_id) REFERENCES reference_data(id),
    FOREIGN KEY (updated_by) REFERENCES app_user(id),
    CHECK (status in ('DRAFT', 'ACTIVE', 'INACTIVE'))
);

-- TABLE: service_settlement_act  (satrlar: 0 — BO`SH)
CREATE TABLE service_settlement_act (
    id uuid NOT NULL,
    approved_at timestamptz,
    approved_by uuid,
    branch_id uuid NOT NULL,
    cancellation_reason varchar(2000),
    cancelled_at timestamptz,
    cancelled_by uuid,
    contract_id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    created_by uuid NOT NULL,
    customer_id uuid NOT NULL,
    department_id uuid NOT NULL,
    period_from date NOT NULL,
    period_to date NOT NULL,
    snapshot_hash varchar(64) NOT NULL,
    snapshot_json text NOT NULL,  -- [JSON matn]
    status varchar(16) NOT NULL,  -- RUXSAT: 'DRAFT', 'APPROVED', 'CANCELLED'
    tariff_id uuid NOT NULL,
    version bigint NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (approved_by) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (cancelled_by) REFERENCES app_user(id),
    FOREIGN KEY (contract_id) REFERENCES service_contract(id),
    FOREIGN KEY (created_by) REFERENCES app_user(id),
    FOREIGN KEY (customer_id) REFERENCES customer(id),
    FOREIGN KEY (department_id) REFERENCES reference_data(id),
    FOREIGN KEY (tariff_id) REFERENCES tariff(id),
    CHECK (status in ('DRAFT', 'APPROVED', 'CANCELLED'))
);

-- TABLE: service_settlement_act_event  (satrlar: noma'lum)
CREATE TABLE service_settlement_act_event (
    id uuid NOT NULL,
    act_id uuid NOT NULL,
    action varchar(32) NOT NULL,
    actor_id uuid NOT NULL,
    performed_at timestamptz NOT NULL,
    reason varchar(2000),
    snapshot_hash varchar(64) NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (act_id) REFERENCES service_settlement_act(id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id)
);

-- TABLE: service_settlement_claim  (satrlar: noma'lum)
CREATE TABLE service_settlement_claim (
    leg_id uuid NOT NULL,
    accepted_leg_version bigint NOT NULL,
    act_id uuid NOT NULL,
    allocation_version bigint NOT NULL,
    claimed_at timestamptz NOT NULL,
    PRIMARY KEY (leg_id),
    FOREIGN KEY (act_id) REFERENCES service_settlement_act(id),
    FOREIGN KEY (leg_id) REFERENCES transport_execution_leg(id)
);

-- TABLE: service_settlement_operation  (satrlar: 0 — BO`SH)
CREATE TABLE service_settlement_operation (
    id uuid NOT NULL,
    action varchar(32) NOT NULL,  -- RUXSAT: 'ALLOCATE', 'CREATE', 'APPROVE', 'CANCEL', 'CLOSE_CREATE', 'CLOSE_APPROVE', 'CLOSE_CANCEL'
    actor_id uuid NOT NULL,
    payload_hash varchar(64) NOT NULL,
    performed_at timestamptz NOT NULL,
    result_json text NOT NULL,  -- [JSON matn]
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK (action in ('ALLOCATE', 'CREATE', 'APPROVE', 'CANCEL', 'CLOSE_CREATE', 'CLOSE_APPROVE', 'CLOSE_CANCEL'))
);

-- TABLE: service_settlement_trip_claim  (satrlar: noma'lum)
CREATE TABLE service_settlement_trip_claim (
    id varchar(73) NOT NULL,
    act_id uuid NOT NULL,
    contract_id uuid NOT NULL,
    trip_id uuid NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (act_id) REFERENCES service_settlement_act(id),
    FOREIGN KEY (contract_id) REFERENCES service_contract(id)
);

-- TABLE: service_tariff_terms  (satrlar: 0 — BO`SH)
CREATE TABLE service_tariff_terms (
    tariff_id uuid NOT NULL,
    configured_at timestamptz NOT NULL,
    configured_by uuid NOT NULL,
    contract_id uuid NOT NULL,
    money_scale integer NOT NULL,
    rounding_mode varchar(32) NOT NULL,  -- RUXSAT: 'UP', 'DOWN', 'CEILING', 'FLOOR', 'HALF_UP', 'HALF_DOWN', 'HALF_EVEN', 'UNNECESSARY'
    version bigint NOT NULL,
    PRIMARY KEY (tariff_id),
    FOREIGN KEY (configured_by) REFERENCES app_user(id),
    FOREIGN KEY (contract_id) REFERENCES service_contract(id),
    FOREIGN KEY (tariff_id) REFERENCES tariff(id),
    CHECK (rounding_mode in ('UP', 'DOWN', 'CEILING', 'FLOOR', 'HALF_UP', 'HALF_DOWN', 'HALF_EVEN', 'UNNECESSARY'))
);

-- TABLE: shipment  (satrlar: noma'lum)
CREATE TABLE shipment (
    id uuid NOT NULL,
    actual_delivery_at timestamptz,
    actual_pickup_at timestamptz,
    cargo_description varchar(1000),
    cargo_volume_m3 numeric(12,2),
    cargo_weight_kg numeric(12,2),
    created_at timestamptz NOT NULL,
    created_by uuid NOT NULL,
    currency varchar(8),
    customer_name varchar(255),
    destination_address varchar(500),
    destination_location_id varchar(128),
    direction varchar(32),
    hazard_profile_id uuid,
    un_number varchar(255),
    hazard_class varchar(255),
    mode varchar(32),
    notes varchar(1000),
    origin_address varchar(500),
    origin_warehouse_id varchar(128),
    packages_count integer,
    packaging_type varchar(64),
    planned_freight_cost numeric(14,2),
    product_code varchar(128),
    ready_at timestamptz,
    requested_delivery_at timestamptz,
    scheduled_delivery_at timestamptz,
    scheduled_pickup_at timestamptz,
    shipment_number varchar(64) NOT NULL,
    status varchar(20) NOT NULL,  -- RUXSAT: 'PENDING', 'LOADING', 'PICKED_UP', 'IN_TRANSIT', 'DELIVERED', 'CANCELLED', 'RETURNED'
    supplier_name varchar(256),
    updated_at timestamptz,
    updated_by uuid,
    weight_tons numeric(12,3),
    customer_id uuid,
    driver_id uuid,
    trip_id uuid,
    vehicle_id uuid,
    branch_id uuid,
    provenance_known boolean NOT NULL,
    source_origin varchar(16),
    version bigint NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (driver_id) REFERENCES driver(id),
    FOREIGN KEY (trip_id) REFERENCES trip(id),
    FOREIGN KEY (customer_id) REFERENCES customer(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id),
    CHECK (status in ('PENDING', 'LOADING', 'PICKED_UP', 'IN_TRANSIT', 'DELIVERED', 'CANCELLED', 'RETURNED'))
);

-- TABLE: shipment_command  (satrlar: noma'lum)
CREATE TABLE shipment_command (
    operation_id uuid NOT NULL,
    action varchar(16) NOT NULL,
    actor_id uuid NOT NULL,
    payload_json text NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    request_hash varchar(64) NOT NULL,
    result_json text NOT NULL,  -- [JSON matn]
    shipment_id uuid NOT NULL,
    shipment_version bigint NOT NULL,
    PRIMARY KEY (operation_id)
);

-- TABLE: shipment_command_context  (satrlar: noma'lum)
CREATE TABLE shipment_command_context (
    shipment_id uuid NOT NULL,
    tx_id bigint NOT NULL,
    row_snapshot jsonb NOT NULL,  -- [JSON matn]
    response_snapshot jsonb NOT NULL,  -- [JSON matn]
    PRIMARY KEY (shipment_id)
);

-- TABLE: shipment_document_template_review  (satrlar: noma'lum)
CREATE TABLE shipment_document_template_review (
    id uuid NOT NULL,
    operation_id uuid NOT NULL,
    template_id uuid NOT NULL,
    template_version integer NOT NULL,
    actor_id uuid NOT NULL,
    reviewed_at timestamptz NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    PRIMARY KEY (id)
);

-- TABLE: shipment_graph_document  (satrlar: noma'lum)
CREATE TABLE shipment_graph_document (
    id uuid NOT NULL,
    shipment_id uuid NOT NULL,
    leg_id uuid NOT NULL,
    document_id uuid NOT NULL,
    operation_id uuid NOT NULL,
    result_json text NOT NULL,  -- [JSON matn]
    original_json text NOT NULL,  -- [JSON matn]
    actor_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (shipment_id) REFERENCES shipment(id)
);

-- TABLE: shipment_graph_leg_revision  (satrlar: noma'lum)
CREATE TABLE shipment_graph_leg_revision (
    id uuid NOT NULL,
    shipment_id uuid NOT NULL,
    leg_id uuid NOT NULL,
    revision bigint NOT NULL,
    sequence_number integer NOT NULL,
    actor_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    result_json text NOT NULL,  -- [JSON matn]
    PRIMARY KEY (id),
    FOREIGN KEY (shipment_id) REFERENCES shipment(id),
    CHECK ((revision > 0)),
    CHECK ((sequence_number > 0))
);

-- TABLE: shipment_graph_operation  (satrlar: noma'lum)
CREATE TABLE shipment_graph_operation (
    operation_id uuid NOT NULL,
    shipment_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    result_json text NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id)
);

-- TABLE: shipment_graph_trip_link  (satrlar: noma'lum)
CREATE TABLE shipment_graph_trip_link (
    leg_id uuid NOT NULL,
    shipment_id uuid NOT NULL,
    trip_id uuid NOT NULL,
    application_id uuid NOT NULL,
    operation_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (leg_id)
);

-- TABLE: shipment_plan_context  (satrlar: noma'lum)
CREATE TABLE shipment_plan_context (
    revision_id uuid NOT NULL,
    shipment_id uuid NOT NULL,
    tx_id bigint NOT NULL,
    captured_version bigint NOT NULL,
    parent_before jsonb NOT NULL,  -- [JSON matn]
    parent_after jsonb,  -- [JSON matn]
    PRIMARY KEY (revision_id)
);

-- TABLE: shipment_plan_revision  (satrlar: noma'lum)
CREATE TABLE shipment_plan_revision (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    captured_shipment_version bigint NOT NULL,
    content_hash varchar(64) NOT NULL,
    content_json text NOT NULL,  -- [JSON matn]
    operation_id uuid NOT NULL,
    previous_revision_id uuid,
    reason varchar(1000) NOT NULL,
    recorded_at timestamptz NOT NULL,
    revision bigint NOT NULL,
    shipment_id uuid NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: shipment_position_identity  (satrlar: noma'lum)
CREATE TABLE shipment_position_identity (
    position_id uuid NOT NULL,
    shipment_id uuid NOT NULL,
    unit_code varchar(32) NOT NULL,
    first_revision_id uuid NOT NULL,
    PRIMARY KEY (position_id)
);

-- TABLE: shipment_unit_definition  (satrlar: noma'lum)
CREATE TABLE shipment_unit_definition (
    id uuid NOT NULL,
    active boolean NOT NULL,
    actor_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    label varchar(128) NOT NULL,
    operation_id uuid NOT NULL,
    payload_json text NOT NULL,  -- [JSON matn]
    previous_definition_id uuid,
    recorded_at timestamptz NOT NULL,
    request_hash varchar(64) NOT NULL,
    review_reason varchar(1000) NOT NULL,
    revision bigint NOT NULL,
    unit_code varchar(32) NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: shuttle_command  (satrlar: noma'lum)
CREATE TABLE shuttle_command (
    operation_id uuid NOT NULL,
    template_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    payload_hash varchar(64) NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    state varchar(16) NOT NULL,  -- RUXSAT: 'APPLIED', 'NOT_EXECUTED'
    result_json text,  -- [JSON matn]
    closure_reason text,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    CHECK (((payload_hash) = encode(sha256(convert_to(original_json, 'utf8'::name)), 'hex'))),
    CHECK (((((state) = 'applied') and (result_json is not null) and (closure_reason is null)) or (((state) = 'not_executed') and (result_json is null) and (length(btrim(closure_reason)) > 0)))),
    CHECK (state in ('APPLIED', 'NOT_EXECUTED'))
);

-- TABLE: shuttle_day_event  (satrlar: 0 — BO`SH)
CREATE TABLE shuttle_day_event (
    id uuid NOT NULL,
    template_id uuid NOT NULL,
    original_date date NOT NULL,
    revision bigint NOT NULL,
    template_revision_id uuid NOT NULL,
    state varchar(32) NOT NULL,  -- RUXSAT: 'DEMAND_PENDING_REVIEW', 'GENERATED', 'EXCLUDED'
    reason text NOT NULL,
    actor_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (template_revision_id) REFERENCES shuttle_template_revision(id),
    CHECK (state in ('DEMAND_PENDING_REVIEW', 'GENERATED', 'EXCLUDED'))
);

-- TABLE: shuttle_instance  (satrlar: 0 — BO`SH)
CREATE TABLE shuttle_instance (
    id uuid NOT NULL,
    template_id uuid NOT NULL,
    original_date date NOT NULL,
    template_revision_id uuid NOT NULL,
    attempt integer NOT NULL,
    kind varchar(16) NOT NULL,  -- RUXSAT: 'MAIN', 'RESERVE'
    group_operation_id uuid NOT NULL,
    result_json text NOT NULL,  -- [JSON matn]
    allocation_demand_json text NOT NULL,  -- [JSON matn]
    stop_template_json text NOT NULL,  -- [JSON matn]
    allocated_passengers_json text NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (template_revision_id) REFERENCES shuttle_template_revision(id),
    CHECK ((attempt >= 0)),
    CHECK (kind in ('MAIN', 'RESERVE'))
);

-- TABLE: shuttle_instance_mapping  (satrlar: noma'lum)
CREATE TABLE shuttle_instance_mapping (
    id uuid NOT NULL,
    instance_id uuid NOT NULL,
    revision bigint NOT NULL,
    actor_id uuid NOT NULL,
    manifest_ids_json text NOT NULL,  -- [JSON matn]
    allocation_demand_json text NOT NULL,  -- [JSON matn]
    stop_template_json text NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (instance_id) REFERENCES shuttle_instance(id),
    CHECK ((length(btrim(reason)) > 0)),
    CHECK ((revision > 0))
);

-- TABLE: shuttle_template_revision  (satrlar: noma'lum)
CREATE TABLE shuttle_template_revision (
    id uuid NOT NULL,
    template_id uuid NOT NULL,
    revision bigint NOT NULL,
    branch_id uuid NOT NULL,
    department_id uuid NOT NULL,
    state varchar(16) NOT NULL,  -- RUXSAT: 'DRAFT', 'APPROVED', 'REVOKED'
    author_id uuid NOT NULL,
    reviewer_id uuid,
    content_json text NOT NULL,  -- [JSON matn]
    content_hash varchar(64) NOT NULL,
    reason text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    CHECK (((content_hash) = encode(sha256(convert_to(content_json, 'utf8'::name)), 'hex'))),
    CHECK (((((state) = 'draft') and (reviewer_id is null)) or (((state) <> 'draft') and (reviewer_id is not null)))),
    CHECK ((length(btrim(reason)) > 0)),
    CHECK ((revision > 0)),
    CHECK (state in ('DRAFT', 'APPROVED', 'REVOKED'))
);

-- TABLE: speed_violation  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Tezlik oshirish buzilishlari: amaldagi tezlik (speed_kph), ruxsat etilgan chegara
-- (limit_kph) va oshib ketgan qiymat (excess_kph), koordinata, vaqt.
-- telematics_event_id — buzilish qaysi telematika hodisasidan aniqlangani.
-- fine_id to'ldirilgan bo'lsa — buzilish uchun jarima yozilgan.
-- ---------------------------------------------------------------------
CREATE TABLE speed_violation (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    driver_id uuid,
    excess_kph numeric(10,3) NOT NULL,
    fine_id uuid,
    latitude numeric(10,7) NOT NULL,
    limit_kph numeric(10,3) NOT NULL,
    longitude numeric(10,7) NOT NULL,
    occurred_at timestamptz NOT NULL,
    speed_kph numeric(10,3) NOT NULL,
    telematics_event_id uuid NOT NULL,
    trip_id uuid,
    vehicle_id uuid NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: tank  (satrlar: 0 — BO`SH)
CREATE TABLE tank (
    id uuid NOT NULL,
    capacity numeric(12,2),
    created_at timestamptz NOT NULL,
    current_volume numeric(12,2),
    location_id uuid,
    name varchar(128) NOT NULL,
    status varchar(32),
    updated_at timestamptz,
    PRIMARY KEY (id)
);

-- TABLE: tariff  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Tashish tariflari: narx modeli (PER_KM, PER_TON, PER_TON_KM, PER_TRIP, PER_HOUR),
-- summa, minimal to'lov, tungi va xavfli yuk uchun ustama foizlari, amal qilish
-- muddati. status: DRAFT, ACTIVE, ARCHIVED.
-- MIJOZ HISOB-KITOBIDA (customer_settlement_act) shu tarif qo'llanadi.
-- ---------------------------------------------------------------------
CREATE TABLE tariff (
    id uuid NOT NULL,
    amount numeric(14,2) NOT NULL,
    cargo_category varchar(64),
    created_at timestamptz NOT NULL,
    currency varchar(8) NOT NULL,
    department_id uuid,
    hazard_surcharge_percent numeric(6,2),
    minimum_charge numeric(14,2),
    name varchar(255) NOT NULL,
    night_surcharge_percent numeric(6,2),
    notes varchar(2000),
    pricing_model varchar(32) NOT NULL,  -- RUXSAT: 'PER_KM', 'PER_TON', 'PER_TON_KM', 'PER_TRIP', 'PER_HOUR'
    status varchar(16) NOT NULL,  -- RUXSAT: 'DRAFT', 'ACTIVE', 'ARCHIVED'
    updated_at timestamptz NOT NULL,
    valid_from date NOT NULL,
    valid_to date,
    vehicle_category varchar(64),
    version bigint NOT NULL,
    PRIMARY KEY (id),
    CHECK (pricing_model in ('PER_KM', 'PER_TON', 'PER_TON_KM', 'PER_TRIP', 'PER_HOUR')),
    CHECK (status in ('DRAFT', 'ACTIVE', 'ARCHIVED'))
);

-- TABLE: telegram_recipient  (satrlar: noma'lum)
CREATE TABLE telegram_recipient (
    id uuid NOT NULL,
    active boolean NOT NULL,
    chat_id bigint NOT NULL,
    full_name varchar(256),
    linked_at timestamptz NOT NULL,
    phone varchar(32) NOT NULL,
    telegram_username varchar(128),
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: telematics_event  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- TELEMATIKA HODISALARI BO'YICHA ASOSIY JADVAL — GPS VA BORT MA'LUMOTLARI SHU
-- JADVALDAN OLINADI. Koordinata, tezlik (speed_kph), yo'nalish (heading),
-- probeg (odometer_km), yoqilg'i sathi (fuel_level), dvigatel holati (engine_on),
-- qurilma id va hodisa vaqti (timestamp).
-- Bu jadval juda katta bo'ladi — HAR DOIM vehicle_id VA VAQT ORALIG'I BO'YICHA
-- FILTRLANADI. Mashinaning oxirgi holati uchun vehicle_telemetry_state ishlatiladi
-- (bu jadvalni skanerlash shart emas).
-- ---------------------------------------------------------------------
CREATE TABLE telematics_event (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    device_id varchar(128) NOT NULL,
    engine_on boolean NOT NULL,
    fingerprint varchar(64) NOT NULL,
    fuel_level numeric(10,3),
    heading numeric(10,3) NOT NULL,
    latitude numeric(10,7) NOT NULL,
    longitude numeric(10,7) NOT NULL,
    odometer_km numeric(14,3) NOT NULL,
    speed_kph numeric(10,3) NOT NULL,
    timestamp timestamptz NOT NULL,
    vehicle_id uuid NOT NULL,
    binding_id uuid,
    binding_version bigint,
    branch_id uuid,
    recorded_by_id uuid,
    source_state varchar(64),
    PRIMARY KEY (id)
);

-- TABLE: telematics_geozone  (satrlar: 0 — BO`SH)
-- ---------------------------------------------------------------------
-- Geozonalar: depo, obyekt, nazorat nuqtasi, taqiqlangan zona. Markaz koordinatasi
-- va radius (radius_meters) bilan belgilanadi.
-- GEOZONADAN CHIQISH hodisasi incident jadvalida GEOFENCE_VIOLATION sifatida.
-- ---------------------------------------------------------------------
CREATE TABLE telematics_geozone (
    id uuid NOT NULL,
    active boolean NOT NULL,
    created_at timestamptz NOT NULL,
    description varchar(1000),
    latitude numeric(10,7) NOT NULL,
    longitude numeric(10,7) NOT NULL,
    name varchar(255) NOT NULL,
    radius_meters numeric(10,2) NOT NULL,
    type varchar(32) NOT NULL,  -- RUXSAT: 'DEPOT', 'OBJECT', 'CHECKPOINT', 'RESTRICTED'
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    CHECK (type in ('DEPOT', 'OBJECT', 'CHECKPOINT', 'RESTRICTED'))
);

-- TABLE: temporary_paper_backfill_rows  (satrlar: noma'lum)
CREATE TABLE temporary_paper_backfill_rows (
    id uuid NOT NULL,
    application_id uuid,
    branch_id uuid,
    business_date date NOT NULL,
    created_at timestamptz NOT NULL,
    departure_time varchar(16),
    fuel_at_departure_liters numeric(10,2),
    fuel_at_return_liters numeric(10,2),
    fuel_consumed_liters numeric(10,2),
    last_error_code varchar(64),
    last_error_message text,
    manual_driver_override boolean NOT NULL,
    manual_vehicle_override boolean NOT NULL,
    medical_inspection_id uuid,
    odometer_end_km bigint,
    odometer_start_km bigint,
    paper_waybill_number varchar(64),
    processed_at timestamptz,
    processed_by varchar(256),
    resolved_driver_id uuid,
    resolved_vehicle_id uuid,
    return_time varchar(16),
    route_id uuid,
    row_index integer,
    row_key varchar(64) NOT NULL,
    source_driver_name varchar(256),
    source_vehicle_plate varchar(64),
    status varchar(32) NOT NULL,  -- RUXSAT: 'NEW', 'NEEDS_DRIVER', 'NEEDS_VEHICLE', 'NEEDS_MEDICAL', 'NEEDS_TECHNICAL', 'READY', 'COMPLETED', 'FAILED'; BAZADA: 'COMPLETED' 40, 'NEEDS_DRIVER' 31; ISHLATILMAGAN: NEW, NEEDS_VEHICLE, NEEDS_MEDICAL, NEEDS_TECHNICAL, READY, FAILED
    synthetic_medical boolean NOT NULL,
    synthetic_technical boolean NOT NULL,
    technical_inspection_id uuid,
    trip_id uuid,
    updated_at timestamptz NOT NULL,
    version bigint,
    waybill_id uuid,
    PRIMARY KEY (id),
    CHECK (status in ('NEW', 'NEEDS_DRIVER', 'NEEDS_VEHICLE', 'NEEDS_MEDICAL', 'NEEDS_TECHNICAL', 'READY', 'COMPLETED', 'FAILED'))
);

-- TABLE: toir_equipment_status_receipt  (satrlar: 0 — BO`SH)
-- ---------------------------------------------------------------------
-- TOIR (texnik xizmat va ta'mirlash) tizimidan kelgan uskuna holati xabarlari.
-- Mashinaning tashqi tizimdagi holati shu yerga tushadi.
-- ---------------------------------------------------------------------
CREATE TABLE toir_equipment_status_receipt (
    event_id uuid NOT NULL,
    equipment_id uuid NOT NULL,
    received_at timestamptz NOT NULL,
    source_revision bigint NOT NULL,
    source_status varchar(32) NOT NULL,
    status varchar(20) NOT NULL,
    vehicle_id uuid NOT NULL,
    PRIMARY KEY (event_id)
);

-- TABLE: toir_vehicle_outbox  (satrlar: 0 — BO`SH)
-- ---------------------------------------------------------------------
-- Mashina ma'lumotini TOIR tizimiga yuborish navbati (outbox). Ishlash tartibi
-- erp_trip_outbox bilan bir xil.
-- ---------------------------------------------------------------------
CREATE TABLE toir_vehicle_outbox (
    id uuid NOT NULL,
    attempt_count integer NOT NULL,
    created_at timestamptz NOT NULL,
    dispatched_at timestamptz,
    last_error varchar(1000),
    next_attempt_at timestamptz NOT NULL,
    payload_json text NOT NULL,  -- [JSON matn]
    status varchar(16) NOT NULL,
    vehicle_id uuid NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: trailer_combination_norm  (satrlar: noma'lum)
CREATE TABLE trailer_combination_norm (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    fuel_norm_liters numeric(8,2) NOT NULL,
    fuel_type varchar(32),
    notes varchar(255),
    tractor_model_group varchar(64) NOT NULL,
    trailer_model_group varchar(64) NOT NULL,
    updated_at timestamptz NOT NULL,
    updated_by varchar(128),
    PRIMARY KEY (id)
);

-- TABLE: trailers  (satrlar: noma'lum)
CREATE TABLE trailers (
    id uuid NOT NULL,
    plate_number varchar(32) NOT NULL,
    model varchar(64) NOT NULL,
    trailer_type varchar(32) NOT NULL,
    weight_tons numeric(5,2) NOT NULL,
    is_active boolean,
    created_at timestamptz,
    PRIMARY KEY (id)
);

-- TABLE: transport_ai_source_provenance  (satrlar: noma'lum)
CREATE TABLE transport_ai_source_provenance (
    operation_id uuid NOT NULL,
    source_type text NOT NULL,
    source_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    draft_id uuid NOT NULL,
    draft_revision bigint NOT NULL,
    draft_kind text NOT NULL,
    field_hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (draft_id) REFERENCES ai_extraction_draft(draft_id)
);

-- TABLE: transport_assignment_change_outbox  (satrlar: noma'lum)
CREATE TABLE transport_assignment_change_outbox (
    id uuid NOT NULL,
    trip_id uuid NOT NULL,
    event_json jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (id) REFERENCES transport_assignment_event(id)
);

-- TABLE: transport_assignment_command  (satrlar: noma'lum)
CREATE TABLE transport_assignment_command (
    operation_id uuid NOT NULL,
    trip_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    action text NOT NULL,
    payload_hash text NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    outcome text NOT NULL,  -- RUXSAT: 'APPLIED', 'NOT_EXECUTED'; BAZADA: 'APPLIED' 361, 'NOT_EXECUTED' 2
    result_json text,  -- [JSON matn]
    closure_reason text,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (trip_id) REFERENCES trip(id),
    CHECK ((((outcome = 'applied') and (result_json is not null) and (closure_reason is null)) or ((outcome = 'not_executed') and (result_json is null) and ((length(btrim(closure_reason)) >= 1) and (length(btrim(closure_reason)) <= 2000))))),
    CHECK (outcome in ('APPLIED', 'NOT_EXECUTED')),
    CHECK ((payload_hash ~ '^[a-f0-9]{64}$'))
);

-- TABLE: transport_assignment_event  (satrlar: noma'lum)
CREATE TABLE transport_assignment_event (
    id uuid NOT NULL,
    trip_id uuid NOT NULL,
    operation_id uuid,
    action text NOT NULL,
    actor_id uuid,
    effective_at timestamptz NOT NULL,
    previous_version bigint,
    resulting_version bigint NOT NULL,
    before_json jsonb,  -- [JSON matn]
    after_json jsonb NOT NULL,  -- [JSON matn]
    provenance text NOT NULL,  -- RUXSAT: 'CURRENT_COMMAND', 'INITIAL', 'LEGACY_CAPTURE', 'UNSCOPED_MUTATION'; BAZADA: 'LEGACY_CAPTURE' 2561, 'INITIAL' 1534, 'CURRENT_COMMAND' 451, 'UNSCOPED_MUTATION' 287
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (trip_id) REFERENCES trip(id),
    CHECK (provenance in ('CURRENT_COMMAND', 'INITIAL', 'LEGACY_CAPTURE', 'UNSCOPED_MUTATION'))
);

-- TABLE: transport_assignment_graph_event  (satrlar: noma'lum)
CREATE TABLE transport_assignment_graph_event (
    operation_id uuid NOT NULL,
    trip_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    before_json jsonb NOT NULL,  -- [JSON matn]
    after_json jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (trip_id) REFERENCES trip(id)
);

-- TABLE: transport_cost_allocation_command  (satrlar: noma'lum)
CREATE TABLE transport_cost_allocation_command (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    closure_reason varchar(2000),
    original_json text NOT NULL,  -- [JSON matn]
    payload_hash varchar(64) NOT NULL,
    record_id uuid,
    recorded_at timestamptz NOT NULL,
    state varchar(16) NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (record_id) REFERENCES transport_cost_allocation_record(id)
);

-- TABLE: transport_cost_allocation_head  (satrlar: noma'lum)
CREATE TABLE transport_cost_allocation_head (
    id uuid NOT NULL,
    current_record_id uuid,
    revision bigint NOT NULL,
    version bigint NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (current_record_id) REFERENCES transport_cost_allocation_record(id),
    FOREIGN KEY (id) REFERENCES transport_cost_head(id)
);

-- TABLE: transport_cost_allocation_record  (satrlar: noma'lum)
CREATE TABLE transport_cost_allocation_record (
    id uuid NOT NULL,
    basis_hash varchar(64) NOT NULL,
    basis_json text NOT NULL,  -- [JSON matn]
    branch_id uuid NOT NULL,
    cost_head_version bigint NOT NULL,
    entry_id uuid NOT NULL,
    expected_allocation_version bigint NOT NULL,
    head_id uuid NOT NULL,
    operation_id uuid NOT NULL,
    posted_at timestamptz NOT NULL,
    posted_by uuid NOT NULL,
    preview_hash varchar(64) NOT NULL,
    preview_json text NOT NULL,  -- [JSON matn]
    reason varchar(2000) NOT NULL,
    revision bigint NOT NULL,
    rule_head_version bigint NOT NULL,
    rule_id uuid NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (operation_id) REFERENCES transport_cost_allocation_command(id),
    FOREIGN KEY (entry_id) REFERENCES transport_cost_entry(id),
    FOREIGN KEY (head_id) REFERENCES transport_cost_allocation_head(id),
    FOREIGN KEY (rule_id) REFERENCES transport_cost_rule_head(id)
);

-- TABLE: transport_cost_command  (satrlar: noma'lum)
CREATE TABLE transport_cost_command (
    id uuid NOT NULL,
    action varchar(24) NOT NULL,
    actor_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    closure_reason varchar(2000),
    original_json text NOT NULL,  -- [JSON matn]
    payload_hash varchar(64) NOT NULL,
    recorded_at timestamptz NOT NULL,
    result_hash varchar(64),
    result_json text,  -- [JSON matn]
    state varchar(24) NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: transport_cost_entry  (satrlar: 0 — BO`SH)
CREATE TABLE transport_cost_entry (
    id uuid NOT NULL,
    amount numeric(38,6) NOT NULL,
    base_unit varchar(32) NOT NULL,
    branch_id uuid NOT NULL,
    confirmed_at timestamptz NOT NULL,
    correction_reason varchar(2000),
    currency varchar(3) NOT NULL,
    department_id uuid,
    document_id varchar(200) NOT NULL,
    document_line_id varchar(200) NOT NULL,
    document_revision bigint NOT NULL,
    economic_hash varchar(64) NOT NULL,
    entry_type varchar(16) NOT NULL,  -- RUXSAT: 'VALUATION', 'REVERSAL'
    expected_previous_revision bigint NOT NULL,
    head_id uuid NOT NULL,
    interval_end timestamptz NOT NULL,
    interval_start timestamptz NOT NULL,
    money_scale integer NOT NULL,
    occurred_at timestamptz NOT NULL,
    origin_receipt_id uuid NOT NULL,
    owner varchar(16) NOT NULL,  -- RUXSAT: 'UNCONFIGURED', 'SAP', 'ONE_C'
    owner_epoch bigint NOT NULL,
    previous_entry_id uuid,
    provider varchar(64) NOT NULL,
    quantity numeric(24,6) NOT NULL,
    recorded_at timestamptz NOT NULL,
    repair_id uuid,
    reverses_entry_id uuid,
    source_domain varchar(40) NOT NULL,
    source_id uuid NOT NULL,
    source_proof_hash varchar(64) NOT NULL,
    source_proof_json text NOT NULL,  -- [JSON matn]
    source_revision bigint NOT NULL,
    task_id uuid,
    valuation_json text NOT NULL,  -- [JSON matn]
    valuation_revision bigint NOT NULL,
    vehicle_id uuid NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (head_id) REFERENCES transport_cost_head(id),
    FOREIGN KEY (previous_entry_id) REFERENCES transport_cost_entry(id),
    FOREIGN KEY (origin_receipt_id) REFERENCES transport_cost_receipt(id),
    FOREIGN KEY (reverses_entry_id) REFERENCES transport_cost_entry(id),
    CHECK (entry_type in ('VALUATION', 'REVERSAL')),
    CHECK (owner in ('UNCONFIGURED', 'SAP', 'ONE_C'))
);

-- TABLE: transport_cost_head  (satrlar: noma'lum)
CREATE TABLE transport_cost_head (
    id uuid NOT NULL,
    branch_id uuid NOT NULL,
    current_entry_id uuid,
    current_valuation_revision bigint NOT NULL,
    source_domain varchar(40) NOT NULL,
    source_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    version bigint NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (current_entry_id) REFERENCES transport_cost_entry(id)
);

-- TABLE: transport_cost_receipt  (satrlar: 0 — BO`SH)
CREATE TABLE transport_cost_receipt (
    id uuid NOT NULL,
    entry_id uuid NOT NULL,
    owner varchar(16) NOT NULL,  -- RUXSAT: 'UNCONFIGURED', 'SAP', 'ONE_C'
    owner_epoch bigint NOT NULL,
    payload_hash varchar(64) NOT NULL,
    provider varchar(64) NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (entry_id) REFERENCES transport_cost_entry(id),
    CHECK (owner in ('UNCONFIGURED', 'SAP', 'ONE_C'))
);

-- TABLE: transport_cost_rule_approval  (satrlar: noma'lum)
CREATE TABLE transport_cost_rule_approval (
    id uuid NOT NULL,
    approved_at timestamptz NOT NULL,
    approved_by uuid NOT NULL,
    draft_id uuid NOT NULL,
    expected_version bigint NOT NULL,
    operation_id uuid NOT NULL,
    reason varchar(2000) NOT NULL,
    reviewed_hash varchar(64) NOT NULL,
    rule_id uuid NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (draft_id) REFERENCES transport_cost_rule_draft(id),
    FOREIGN KEY (operation_id) REFERENCES transport_cost_command(id),
    FOREIGN KEY (rule_id) REFERENCES transport_cost_rule_head(id)
);

-- TABLE: transport_cost_rule_draft  (satrlar: noma'lum)
CREATE TABLE transport_cost_rule_draft (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    created_by uuid NOT NULL,
    expected_version bigint,
    operation_id uuid NOT NULL,
    reason varchar(2000) NOT NULL,
    revision bigint NOT NULL,
    rule_id uuid NOT NULL,
    snapshot_hash varchar(64) NOT NULL,
    terms_json text NOT NULL,  -- [JSON matn]
    PRIMARY KEY (id),
    FOREIGN KEY (operation_id) REFERENCES transport_cost_command(id),
    FOREIGN KEY (rule_id) REFERENCES transport_cost_rule_head(id)
);

-- TABLE: transport_cost_rule_head  (satrlar: noma'lum)
CREATE TABLE transport_cost_rule_head (
    id uuid NOT NULL,
    branch_id uuid NOT NULL,
    current_approval_id uuid,
    current_draft_id uuid,
    draft_revision bigint NOT NULL,
    version bigint NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (current_approval_id) REFERENCES transport_cost_rule_approval(id),
    FOREIGN KEY (current_draft_id) REFERENCES transport_cost_rule_draft(id)
);

-- TABLE: transport_demand_operation_assignment  (satrlar: noma'lum)
CREATE TABLE transport_demand_operation_assignment (
    id uuid NOT NULL,
    trip_id uuid NOT NULL,
    demand_revision_id uuid NOT NULL,
    revision bigint NOT NULL,
    command_id uuid NOT NULL,
    planning_command_id uuid,
    load_command_id uuid,
    admission_json jsonb NOT NULL,  -- [JSON matn]
    actor_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (demand_revision_id) REFERENCES transport_requirement_operation_revision(id),
    FOREIGN KEY (load_command_id) REFERENCES transport_load_command(operation_id),
    FOREIGN KEY (planning_command_id) REFERENCES transport_planning_operation(id),
    FOREIGN KEY (trip_id) REFERENCES trip(id),
    CHECK (((num_nonnulls(planning_command_id, load_command_id) = 1) and (coalesce(planning_command_id, load_command_id) = command_id))),
    CHECK ((revision > 0))
);

-- TABLE: transport_demand_operation_authority  (satrlar: 0 — BO`SH)
CREATE TABLE transport_demand_operation_authority (
    id uuid NOT NULL,
    command_id uuid NOT NULL,
    subject_id uuid NOT NULL,
    revision bigint NOT NULL,
    kind text NOT NULL,  -- RUXSAT: 'DEFINITION', 'CAPABILITY', 'QUALIFICATION'
    branch_id uuid NOT NULL,
    original_json jsonb NOT NULL,  -- [JSON matn]
    body_hash text NOT NULL,
    author_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (author_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (command_id) REFERENCES transport_demand_operation_command(id),
    CHECK ((body_hash ~ '^[a-f0-9]{64}$')),
    CHECK (kind in ('DEFINITION', 'CAPABILITY', 'QUALIFICATION')),
    CHECK ((revision > 0))
);

-- TABLE: transport_demand_operation_command  (satrlar: 0 — BO`SH)
CREATE TABLE transport_demand_operation_command (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    action text NOT NULL,
    original_json jsonb NOT NULL,  -- [JSON matn]
    payload_hash text NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'APPLIED', 'NOT_EXECUTED'
    result_json jsonb,  -- [JSON matn]
    reason text,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    CHECK ((((state = 'applied') and (result_json is not null)) or ((state = 'not_executed') and (length(btrim(reason)) > 0)))),
    CHECK ((payload_hash ~ '^[a-f0-9]{64}$')),
    CHECK (state in ('APPLIED', 'NOT_EXECUTED'))
);

-- TABLE: transport_demand_operation_decision  (satrlar: 0 — BO`SH)
CREATE TABLE transport_demand_operation_decision (
    id uuid NOT NULL,
    command_id uuid NOT NULL,
    leg_id uuid NOT NULL,
    leg_version bigint NOT NULL,
    source_revision_id uuid NOT NULL,
    source_hash text NOT NULL,
    measured_quantity numeric(18,6) NOT NULL,
    accepted_quantity numeric(18,6) NOT NULL,
    clarification_quantity numeric(18,6) NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'ACCEPTED', 'REVERSED'
    actor_id uuid NOT NULL,
    reason text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (leg_id) REFERENCES transport_demand_operation_leg(leg_id),
    FOREIGN KEY (command_id) REFERENCES transport_execution_command(operation_id),
    FOREIGN KEY (source_revision_id) REFERENCES transport_execution_source_revision(id),
    CHECK ((clarification_quantity >= (0))),
    CHECK ((accepted_quantity >= (0))),
    CHECK (((accepted_quantity + clarification_quantity) = measured_quantity)),
    CHECK ((leg_version >= 0)),
    CHECK ((measured_quantity > (0))),
    CHECK ((source_hash ~ '^[a-f0-9]{64}$')),
    CHECK (state in ('ACCEPTED', 'REVERSED'))
);

-- TABLE: transport_demand_operation_document  (satrlar: 0 — BO`SH)
CREATE TABLE transport_demand_operation_document (
    id uuid NOT NULL,
    command_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    kind text NOT NULL,  -- RUXSAT: 'LOAD_CHART', 'OPERATOR_CERTIFICATE', 'EQUIPMENT_CAPABILITY'
    object_id uuid NOT NULL,
    file_name text NOT NULL,
    content_type text NOT NULL,
    size_bytes bigint NOT NULL,
    storage_key text NOT NULL,
    sha256 text NOT NULL,
    actor_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (command_id) REFERENCES transport_demand_operation_command(id),
    CHECK (kind in ('LOAD_CHART', 'OPERATOR_CERTIFICATE', 'EQUIPMENT_CAPABILITY')),
    CHECK ((sha256 ~ '^[a-f0-9]{64}$')),
    CHECK (((size_bytes > 0) and (size_bytes <= 10485760)))
);

-- TABLE: transport_demand_operation_leg  (satrlar: noma'lum)
CREATE TABLE transport_demand_operation_leg (
    leg_id uuid NOT NULL,
    command_id uuid NOT NULL,
    demand_revision_id uuid NOT NULL,
    source_id uuid NOT NULL,
    waybill_id uuid NOT NULL,
    start_id uuid NOT NULL,
    physical_source_key text NOT NULL,
    actual_quantity numeric(18,6) NOT NULL,
    unit_code text NOT NULL,
    recorded_by uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (leg_id),
    FOREIGN KEY (start_id) REFERENCES transport_demand_operation_start(id),
    FOREIGN KEY (demand_revision_id) REFERENCES transport_requirement_operation_revision(id),
    FOREIGN KEY (leg_id) REFERENCES transport_execution_leg(id),
    FOREIGN KEY (command_id) REFERENCES transport_execution_command(operation_id),
    FOREIGN KEY (recorded_by) REFERENCES app_user(id),
    FOREIGN KEY (waybill_id) REFERENCES waybill(id),
    CHECK ((actual_quantity > (0)))
);

-- TABLE: transport_demand_operation_review  (satrlar: 0 — BO`SH)
CREATE TABLE transport_demand_operation_review (
    id uuid NOT NULL,
    command_id uuid NOT NULL,
    authority_id uuid NOT NULL,
    review_version bigint NOT NULL,
    action text NOT NULL,  -- RUXSAT: 'APPROVE', 'REVOKE'
    actor_id uuid NOT NULL,
    reason text NOT NULL,
    authority_reference text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (authority_id) REFERENCES transport_demand_operation_authority(id),
    FOREIGN KEY (command_id) REFERENCES transport_demand_operation_command(id),
    CHECK (action in ('APPROVE', 'REVOKE')),
    CHECK ((length(btrim(authority_reference)) > 0)),
    CHECK ((length(btrim(reason)) > 0)),
    CHECK ((review_version > 0))
);

-- TABLE: transport_demand_operation_start  (satrlar: noma'lum)
CREATE TABLE transport_demand_operation_start (
    id uuid NOT NULL,
    trip_id uuid NOT NULL,
    permit_id uuid NOT NULL,
    assignment_id uuid NOT NULL,
    manifest_id uuid NOT NULL,
    manifest_revision boolean NOT NULL,
    manifest_hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (assignment_id) REFERENCES transport_demand_operation_assignment(id),
    FOREIGN KEY (permit_id) REFERENCES safety_operational_permit(id),
    FOREIGN KEY (trip_id) REFERENCES trip(id),
    CHECK ((manifest_hash ~ '^[a-f0-9]{64}$'))
);

-- TABLE: transport_document  (satrlar: 0 — BO`SH)
-- ---------------------------------------------------------------------
-- TRANSPORT HUJJATLARI BO'YICHA ASOSIY JADVAL — YO'L VARAQASI, TTN, MARSHRUT
-- VARAQASI, TRANSPORT AKTI VA YETKAZISH TASDIG'I SHU JADVALDAN OLINADI.
-- Hujjat raqami (document_number), turi (document_type), shabloni, holati
-- (GENERATED, UPDATED, CONFIRMED, SIGNING_PENDING, SIGNED, ARCHIVED, CANCELLED),
-- imzo talab qilinishi (signature_required) va imzo ma'lumotlari.
-- Reys, mashina, haydovchi va so'rovga bog'lanadi. Versiyalari document_version,
-- tarixi document_audit jadvalida.
-- ---------------------------------------------------------------------
CREATE TABLE transport_document (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    created_by varchar(128) NOT NULL,
    document_number varchar(64) NOT NULL,
    document_type varchar(64) NOT NULL,  -- RUXSAT: 'WAYBILL', 'TTN', 'ROUTE_SHEET', 'TRANSPORT_ACT', 'DELIVERY_CONFIRMATION', 'WEIGHING_ACT'
    driver_id uuid,
    request_id uuid,
    signature_data varchar(20000),
    signature_document_hash varchar(128),
    signature_required boolean NOT NULL,
    signature_serial_number varchar(128),
    signature_subject varchar(255),
    signed_at timestamptz,
    signed_by varchar(128),
    signing_provider varchar(32),
    status varchar(32) NOT NULL,  -- RUXSAT: 'GENERATED', 'UPDATED', 'CONFIRMED', 'SIGNING_PENDING', 'SIGNED', 'ARCHIVED', 'CANCELLED'
    template_code varchar(64) NOT NULL,
    template_id uuid NOT NULL,
    template_version integer NOT NULL,
    trip_id uuid,
    updated_at timestamptz NOT NULL,
    updated_by varchar(128) NOT NULL,
    vehicle_id uuid,
    PRIMARY KEY (id),
    CHECK (document_type in ('WAYBILL', 'TTN', 'ROUTE_SHEET', 'TRANSPORT_ACT', 'DELIVERY_CONFIRMATION', 'WEIGHING_ACT')),
    CHECK (status in ('GENERATED', 'UPDATED', 'CONFIRMED', 'SIGNING_PENDING', 'SIGNED', 'ARCHIVED', 'CANCELLED'))
);

-- TABLE: transport_execution_command  (satrlar: noma'lum)
CREATE TABLE transport_execution_command (
    operation_id uuid NOT NULL,
    request_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    action varchar(32) NOT NULL,
    leg_id uuid,
    payload_hash varchar(64) NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    outcome varchar(16) NOT NULL,  -- RUXSAT: 'APPLIED', 'NOT_EXECUTED'; BAZADA: 'APPLIED' 6, 'NOT_EXECUTED' 1
    result_json text,  -- [JSON matn]
    reason text,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (request_id) REFERENCES transport_request(id),
    CHECK (((payload_hash) = encode(sha256(convert_to(original_json, 'utf8'::name)), 'hex'))),
    CHECK (((((outcome) = 'applied') and (result_json is not null) and (reason is null)) or (((outcome) = 'not_executed') and (result_json is null) and (length(btrim(reason)) > 0)))),
    CHECK (outcome in ('APPLIED', 'NOT_EXECUTED'))
);

-- TABLE: transport_execution_discrepancy  (satrlar: 0 — BO`SH)
CREATE TABLE transport_execution_discrepancy (
    id uuid NOT NULL,
    request_id uuid NOT NULL,
    trip_id uuid NOT NULL,
    source_revision_id uuid NOT NULL,
    fingerprint varchar(64) NOT NULL,
    decision varchar(64) NOT NULL,  -- RUXSAT: 'EXPLAINED_NON_TASK_DISTANCE', 'MEASUREMENT_REVIEW_REQUIRED', 'LEG_CORRECTION_REQUIRED'
    explanation text NOT NULL,
    document_uri text NOT NULL,
    actor_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (request_id) REFERENCES transport_request(id),
    FOREIGN KEY (source_revision_id) REFERENCES transport_execution_source_revision(id),
    FOREIGN KEY (trip_id) REFERENCES trip(id),
    CHECK (((length(btrim(explanation)) > 0) and (length(btrim(document_uri)) > 0))),
    CHECK (decision in ('EXPLAINED_NON_TASK_DISTANCE', 'MEASUREMENT_REVIEW_REQUIRED', 'LEG_CORRECTION_REQUIRED'))
);

-- TABLE: transport_execution_leg  (satrlar: noma'lum)
CREATE TABLE transport_execution_leg (
    id uuid NOT NULL,
    accepted_distance_km numeric(14,3),
    accepted_engine_hours numeric(14,3),
    accepted_operation_quantity numeric(14,3),
    accepted_weight_tons numeric(14,3),
    assignment_segment_id uuid,
    coverage_branch_id uuid,
    coverage_end timestamp NOT NULL,
    coverage_end_instant timestamptz,
    coverage_end_local varchar(64),
    coverage_policy_id uuid,
    coverage_policy_version bigint,
    coverage_start timestamp NOT NULL,
    coverage_start_instant timestamptz,
    coverage_start_local varchar(64),
    coverage_time_reason varchar(64),
    coverage_time_zone varchar(64),
    decided_at timestamptz,
    decided_by uuid,
    decision_comment varchar(2000),
    destination varchar(255),
    distance_km numeric(14,3),
    engine_hours numeric(14,3),
    idle_hours numeric(14,3),
    measurement_event_at timestamptz,
    measurement_source varchar(1000) NOT NULL,
    operation_quantity numeric(14,3),
    origin varchar(255),
    request_id uuid NOT NULL,
    requirement_id uuid NOT NULL,
    source_hash varchar(64),
    source_revision bigint,
    source_revision_id uuid,
    source_state varchar(32),
    status varchar(16) NOT NULL,  -- RUXSAT: 'SUBMITTED', 'ACCEPTED', 'REJECTED'; BAZADA: 'REJECTED' 1; ISHLATILMAGAN: SUBMITTED, ACCEPTED
    submitted_at timestamptz NOT NULL,
    submitted_by uuid NOT NULL,
    transport_type varchar(32) NOT NULL,  -- RUXSAT: 'MOBILE_CRANE', 'AERIAL_PLATFORM', 'TRACTOR', 'WATER_TRUCK', 'EXCAVATOR', 'FRONT_LOADER', 'DUMP_TRUCK', 'LONG_LOAD_TRUCK', 'FLATBED', 'MANIPULATOR', 'PASSENGER_CAR', 'BUS', 'VAN', 'BULLDOZER', 'CONCRETE_PUMP', 'CONCRETE_MIXER', 'FIRE_TRUCK', 'AMBULANCE', 'TRUCK', 'TANKER', 'REFRIGERATED', 'SPECIALIZED', 'MINIBUS', 'PICKUP', 'TRAILER', 'OTHER', 'ELECTRIC_VEHICLE'
    trip_id uuid NOT NULL,
    unit_code varchar(64),
    vehicle_id uuid NOT NULL,
    version bigint NOT NULL,
    weight_tons numeric(14,3),
    work_hours numeric(14,3),
    work_operation_id uuid,
    worksite_id uuid,
    PRIMARY KEY (id),
    CHECK (status in ('SUBMITTED', 'ACCEPTED', 'REJECTED')),
    CHECK (transport_type in ('MOBILE_CRANE', 'AERIAL_PLATFORM', 'TRACTOR', 'WATER_TRUCK', 'EXCAVATOR', 'FRONT_LOADER', 'DUMP_TRUCK', 'LONG_LOAD_TRUCK', 'FLATBED', 'MANIPULATOR', 'PASSENGER_CAR', 'BUS', 'VAN', 'BULLDOZER', 'CONCRETE_PUMP', 'CONCRETE_MIXER', 'FIRE_TRUCK', 'AMBULANCE', 'TRUCK', 'TANKER', 'REFRIGERATED', 'SPECIALIZED', 'MINIBUS', 'PICKUP', 'TRAILER', 'OTHER', 'ELECTRIC_VEHICLE'))
);

-- TABLE: transport_execution_operation  (satrlar: noma'lum)
CREATE TABLE transport_execution_operation (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    leg_id uuid NOT NULL,
    operation_id uuid NOT NULL,
    payload_hash varchar(64) NOT NULL,
    performed_at timestamptz NOT NULL,
    request_id uuid NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: transport_execution_recalculation  (satrlar: noma'lum)
CREATE TABLE transport_execution_recalculation (
    id uuid NOT NULL,
    request_id uuid NOT NULL,
    leg_id uuid NOT NULL,
    leg_version bigint NOT NULL,
    source_hash varchar(64),
    content_json text NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (leg_id) REFERENCES transport_execution_leg(id),
    FOREIGN KEY (request_id) REFERENCES transport_request(id)
);

-- TABLE: transport_execution_revision  (satrlar: 0 — BO`SH)
CREATE TABLE transport_execution_revision (
    id uuid NOT NULL,
    leg_id uuid NOT NULL,
    request_id uuid NOT NULL,
    previous_version bigint NOT NULL,
    resulting_version bigint NOT NULL,
    action varchar(32) NOT NULL,  -- RUXSAT: 'CORRECT', 'REVERSE', 'SOURCE_INVALIDATED'
    actor_id uuid NOT NULL,
    before_json text NOT NULL,  -- [JSON matn]
    after_json text NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    document_uri text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (leg_id) REFERENCES transport_execution_leg(id),
    FOREIGN KEY (request_id) REFERENCES transport_request(id),
    CHECK (action in ('CORRECT', 'REVERSE', 'SOURCE_INVALIDATED')),
    CHECK ((resulting_version = (previous_version + 1))),
    CHECK (((length(btrim(reason)) > 0) and (length(btrim(document_uri)) > 0)))
);

-- TABLE: transport_execution_source_revision  (satrlar: noma'lum)
CREATE TABLE transport_execution_source_revision (
    id uuid NOT NULL,
    source_id uuid NOT NULL,
    revision bigint NOT NULL,
    request_id uuid NOT NULL,
    trip_id uuid NOT NULL,
    kind varchar(32) NOT NULL,  -- RUXSAT: 'LOCAL_DOCUMENT', 'PRODUCTION_ACCEPTANCE', 'EXTERNAL_PROVIDER'
    state varchar(16) NOT NULL,  -- RUXSAT: 'DRAFT', 'APPROVED', 'REVOKED'; BAZADA: 'DRAFT' 1; ISHLATILMAGAN: APPROVED, REVOKED
    source_hash varchar(64) NOT NULL,
    content_json text NOT NULL,  -- [JSON matn]
    author_id uuid NOT NULL,
    reviewer_id uuid,
    reason text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (author_id) REFERENCES app_user(id),
    FOREIGN KEY (request_id) REFERENCES transport_request(id),
    FOREIGN KEY (reviewer_id) REFERENCES app_user(id),
    FOREIGN KEY (trip_id) REFERENCES trip(id),
    CHECK (((((state) = 'draft') and (reviewer_id is null)) or (((state) <> 'draft') and (reviewer_id is not null)))),
    CHECK (kind in ('LOCAL_DOCUMENT', 'PRODUCTION_ACCEPTANCE', 'EXTERNAL_PROVIDER')),
    CHECK ((revision > 0)),
    CHECK (state in ('DRAFT', 'APPROVED', 'REVOKED'))
);

-- TABLE: transport_governance_closed  (satrlar: noma'lum)
CREATE TABLE transport_governance_closed (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    branch_id uuid,
    action text NOT NULL,
    payload_hash text NOT NULL,
    original_json jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK ((payload_hash ~ '^[a-f0-9]{64}$')),
    CHECK (((length(btrim(reason)) >= 1) and (length(btrim(reason)) <= 2000)))
);

-- TABLE: transport_governance_decision  (satrlar: noma'lum)
CREATE TABLE transport_governance_decision (
    id uuid NOT NULL,
    revision_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    action text NOT NULL,  -- RUXSAT: 'APPROVE', 'REVOKE'
    original_json jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (revision_id) REFERENCES transport_governance_policy(id),
    CHECK (action in ('APPROVE', 'REVOKE'))
);

-- TABLE: transport_governance_policy  (satrlar: noma'lum)
CREATE TABLE transport_governance_policy (
    id uuid NOT NULL,
    branch_id uuid,
    kind text NOT NULL,  -- RUXSAT: 'REQUEST_FIELDS', 'FLEET_RESOURCES', 'ANOMALY_CLOSE'
    version bigint NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    policy_json jsonb NOT NULL,  -- [JSON matn]
    source_hash text NOT NULL,
    author_id uuid NOT NULL,
    original_json jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (author_id) REFERENCES app_user(id),
    CHECK (((branch_id is not null) or (kind = 'request_fields'))),
    CHECK (((valid_until is null) or (valid_until > valid_from))),
    CHECK (kind in ('REQUEST_FIELDS', 'FLEET_RESOURCES', 'ANOMALY_CLOSE')),
    CHECK ((source_hash ~ '^[a-f0-9]{64}$')),
    CHECK ((version > 0))
);

-- TABLE: transport_governance_receipt  (satrlar: noma'lum)
CREATE TABLE transport_governance_receipt (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    branch_id uuid,
    action text NOT NULL,
    payload_hash text NOT NULL,
    original_json jsonb NOT NULL,  -- [JSON matn]
    result_json jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id)
);

-- TABLE: transport_load_allocation_group  (satrlar: noma'lum)
CREATE TABLE transport_load_allocation_group (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    assessment_basis_json text NOT NULL,  -- [JSON matn]
    assessment_hash varchar(64) NOT NULL,
    operation_id uuid NOT NULL,
    proof_json text NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    recorded_at timestamptz NOT NULL,
    routes_json text NOT NULL,  -- [JSON matn]
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id)
);

-- TABLE: transport_load_command  (satrlar: 0 — BO`SH)
CREATE TABLE transport_load_command (
    operation_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    kind text NOT NULL,  -- RUXSAT: 'PREPARE', 'GROUP', 'CANCEL_PREPARED', 'REVISE', 'PREPARE_EXISTING'
    payload_hash text NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    outcome text NOT NULL,  -- RUXSAT: 'APPLIED', 'NOT_EXECUTED'
    result_json text,  -- [JSON matn]
    closure_reason text,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK ((((outcome = 'applied') and (result_json is not null) and (closure_reason is null)) or ((outcome = 'not_executed') and (result_json is null) and ((length(btrim(closure_reason)) >= 1) and (length(btrim(closure_reason)) <= 2000))))),
    CHECK (kind in ('PREPARE', 'GROUP', 'CANCEL_PREPARED', 'REVISE', 'PREPARE_EXISTING')),
    CHECK (outcome in ('APPLIED', 'NOT_EXECUTED')),
    CHECK ((payload_hash ~ '^[a-f0-9]{64}$'))
);

-- TABLE: transport_load_current_claims  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
CREATE TABLE transport_load_current_claims (
    id uuid,
    operation_id uuid,
    route_id uuid,
    vehicle_id uuid,
    actor_id uuid,
    recorded_at timestamptz,
    assessment_basis_json text,  -- [JSON matn]
    assessment_hash varchar(64),
    proof_json text,  -- [JSON matn]
    request_ids uuid[]
);

-- TABLE: transport_load_group_context  (satrlar: noma'lum)
CREATE TABLE transport_load_group_context (
    group_id uuid NOT NULL,
    transaction_id bigint NOT NULL,
    PRIMARY KEY (group_id)
);

-- TABLE: transport_load_group_queue  (satrlar: noma'lum)
CREATE TABLE transport_load_group_queue (
    group_id uuid NOT NULL,
    transaction_id bigint NOT NULL,
    generation bigint NOT NULL,
    validated_generation bigint NOT NULL,
    PRIMARY KEY (group_id)
);

-- TABLE: transport_load_manifest  (satrlar: noma'lum)
CREATE TABLE transport_load_manifest (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    assessment_basis_json text NOT NULL,  -- [JSON matn]
    assessment_hash varchar(64) NOT NULL,
    operation_id uuid NOT NULL,
    proof_json text NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    route_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: transport_load_manifest_audit_context  (satrlar: noma'lum)
CREATE TABLE transport_load_manifest_audit_context (
    audit_id uuid NOT NULL,
    manifest_id uuid NOT NULL,
    request_id uuid NOT NULL,
    transaction_id bigint NOT NULL,
    PRIMARY KEY (audit_id)
);

-- TABLE: transport_load_manifest_insert_context  (satrlar: noma'lum)
CREATE TABLE transport_load_manifest_insert_context (
    kind text NOT NULL,
    id uuid NOT NULL,
    transaction_id bigint NOT NULL,
    PRIMARY KEY (kind, id)
);

-- TABLE: transport_load_manifest_latest  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
CREATE TABLE transport_load_manifest_latest (
    id uuid,
    operation_id uuid,
    route_id uuid,
    vehicle_id uuid,
    actor_id uuid,
    recorded_at timestamptz,
    assessment_basis_json text,  -- [JSON matn]
    assessment_hash varchar(64),
    proof_json text  -- [JSON matn]
);

-- TABLE: transport_load_manifest_request_context  (satrlar: noma'lum)
CREATE TABLE transport_load_manifest_request_context (
    manifest_id uuid NOT NULL,
    request_id uuid NOT NULL,
    captured_version bigint NOT NULL,
    captured_status text NOT NULL,
    transaction_id bigint NOT NULL,
    PRIMARY KEY (manifest_id, request_id)
);

-- TABLE: transport_load_manifest_retirement  (satrlar: noma'lum)
CREATE TABLE transport_load_manifest_retirement (
    operation_id uuid NOT NULL,
    request_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    route_id uuid NOT NULL,
    manifest_head_id uuid NOT NULL,
    preparation_operation_id uuid NOT NULL,
    preparation_actor_id uuid NOT NULL,
    source_id uuid NOT NULL,
    source_revision bigint NOT NULL,
    material_hash text NOT NULL,
    assessment_hash text NOT NULL,
    retained_branch_id uuid NOT NULL,
    before_route_version bigint NOT NULL,
    result_route_version bigint NOT NULL,
    before_request_version bigint NOT NULL,
    result_request_version bigint NOT NULL,
    origin_json jsonb NOT NULL,  -- [JSON matn]
    history_hash text NOT NULL,
    reason text NOT NULL,
    transaction_id bigint NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (preparation_operation_id) REFERENCES transport_load_command(operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (manifest_head_id) REFERENCES transport_load_manifest_revision(id),
    FOREIGN KEY (operation_id) REFERENCES transport_request_revision_intent(operation_id),
    FOREIGN KEY (preparation_actor_id) REFERENCES app_user(id),
    FOREIGN KEY (request_id) REFERENCES transport_request(id),
    FOREIGN KEY (retained_branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (route_id) REFERENCES route(id),
    FOREIGN KEY (source_id) REFERENCES transport_request_load_source(id),
    CHECK ((assessment_hash ~ '^[a-f0-9]{64}$')),
    CHECK ((material_hash ~ '^[a-f0-9]{64}$')),
    CHECK ((source_revision > 0))
);

-- TABLE: transport_load_manifest_revision  (satrlar: noma'lum)
CREATE TABLE transport_load_manifest_revision (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    assessment_basis_json text NOT NULL,  -- [JSON matn]
    assessment_hash varchar(64) NOT NULL,
    captured_route_version bigint NOT NULL,
    operation_id uuid NOT NULL,
    previous_id uuid,
    proof_json text NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    recorded_at timestamptz NOT NULL,
    revision bigint NOT NULL,
    route_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    preparation_before_json jsonb,  -- [JSON matn]
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (route_id) REFERENCES route(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id)
);

-- TABLE: transport_load_manifest_validation_queue  (satrlar: noma'lum)
CREATE TABLE transport_load_manifest_validation_queue (
    manifest_id uuid NOT NULL,
    transaction_id bigint NOT NULL,
    generation bigint NOT NULL,
    validated_generation bigint NOT NULL,
    PRIMARY KEY (manifest_id)
);

-- TABLE: transport_load_revision_context  (satrlar: noma'lum)
CREATE TABLE transport_load_revision_context (
    revision_id uuid NOT NULL,
    route_id uuid NOT NULL,
    transaction_id bigint NOT NULL,
    PRIMARY KEY (revision_id)
);

-- TABLE: transport_load_revision_queue  (satrlar: noma'lum)
CREATE TABLE transport_load_revision_queue (
    revision_id uuid NOT NULL,
    transaction_id bigint NOT NULL,
    generation bigint NOT NULL,
    validated_generation bigint NOT NULL,
    PRIMARY KEY (revision_id)
);

-- TABLE: transport_optimizer_application  (satrlar: 0 — BO`SH)
CREATE TABLE transport_optimizer_application (
    operation_id uuid NOT NULL,
    proposal_id uuid NOT NULL,
    review_revision bigint NOT NULL,
    review_hash text NOT NULL,
    actor_id uuid NOT NULL,
    kind text NOT NULL,  -- RUXSAT: 'PREPARE', 'GROUP'
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK (kind in ('PREPARE', 'GROUP'))
);

-- TABLE: transport_optimizer_proposal  (satrlar: 0 — BO`SH)
CREATE TABLE transport_optimizer_proposal (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    original_hash text NOT NULL,
    baseline_json text NOT NULL,  -- [JSON matn]
    resources_json text NOT NULL,  -- [JSON matn]
    request_json text NOT NULL,  -- [JSON matn]
    state text NOT NULL,  -- RUXSAT: 'PENDING', 'PROPOSED', 'FAILED'
    created_at timestamptz NOT NULL,
    response_at timestamptz,
    response_json text,  -- [JSON matn]
    response_hash text,
    response_version text,
    candidate_json text,  -- [JSON matn]
    reasons_json text,  -- [JSON matn]
    uncovered_json text,  -- [JSON matn]
    comparison_json text,  -- [JSON matn]
    failure text,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK ((((state = 'pending') and (response_at is null) and (response_json is null) and (failure is null)) or ((state = 'proposed') and (response_at is not null) and (response_json is not null) and (response_hash is not null) and (failure is null)) or ((state = 'failed') and (response_at is not null) and (response_json is null) and (failure is not null)))),
    CHECK ((original_hash ~ '^[a-f0-9]{64}$')),
    CHECK (((response_hash is null) or (response_hash ~ '^[a-f0-9]{64}$'))),
    CHECK (state in ('PENDING', 'PROPOSED', 'FAILED'))
);

-- TABLE: transport_optimizer_review  (satrlar: noma'lum)
CREATE TABLE transport_optimizer_review (
    proposal_id uuid NOT NULL,
    revision bigint NOT NULL,
    operation_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    selection_json text NOT NULL,  -- [JSON matn]
    proof_json text NOT NULL,  -- [JSON matn]
    drivers_json text NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    review_hash text NOT NULL,
    basis_json text NOT NULL,  -- [JSON matn]
    reviewed_at timestamptz NOT NULL,
    PRIMARY KEY (proposal_id, revision),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (proposal_id) REFERENCES transport_optimizer_proposal(id),
    CHECK (((length(btrim(reason)) >= 1) and (length(btrim(reason)) <= 2000))),
    CHECK ((review_hash ~ '^[a-f0-9]{64}$')),
    CHECK ((revision > 0))
);

-- TABLE: transport_passport_assignment  (satrlar: noma'lum)
CREATE TABLE transport_passport_assignment (
    id uuid NOT NULL,
    trip_id uuid NOT NULL,
    trip_version bigint NOT NULL,
    vehicle_id uuid NOT NULL,
    trailer_id uuid,
    policy_id uuid NOT NULL,
    policy_version bigint NOT NULL,
    source_hash text NOT NULL,
    snapshot_json jsonb NOT NULL,  -- [JSON matn]
    passport_receipts jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (policy_id) REFERENCES transport_governance_policy(id),
    FOREIGN KEY (trip_id) REFERENCES trip(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id)
);

-- TABLE: transport_planning_closure  (satrlar: noma'lum)
CREATE TABLE transport_planning_closure (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    kind varchar(16) NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    payload_hash varchar(64) NOT NULL,
    performed_at timestamptz NOT NULL,
    reason varchar(2000) NOT NULL,
    request_ids_json text NOT NULL,  -- [JSON matn]
    source_id uuid,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id)
);

-- TABLE: transport_planning_decision_claim  (satrlar: noma'lum)
CREATE TABLE transport_planning_decision_claim (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    payload_hash varchar(64) NOT NULL,
    kind varchar(16) NOT NULL,  -- RUXSAT: 'SINGLE', 'BUNDLE', 'ROUTE', 'DIRECT'; BAZADA: 'SINGLE' 63; ISHLATILMAGAN: BUNDLE, ROUTE, DIRECT
    decision varchar(16) NOT NULL,  -- RUXSAT: 'EXECUTED', 'NOT_EXECUTED'
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK (decision in ('EXECUTED', 'NOT_EXECUTED')),
    CHECK (kind in ('SINGLE', 'BUNDLE', 'ROUTE', 'DIRECT'))
);

-- TABLE: transport_planning_operation  (satrlar: noma'lum)
CREATE TABLE transport_planning_operation (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    kind varchar(16) NOT NULL,  -- RUXSAT: 'SINGLE', 'BUNDLE', 'ROUTE', 'DIRECT'; BAZADA: 'SINGLE' 63; ISHLATILMAGAN: BUNDLE, ROUTE, DIRECT
    payload_hash varchar(64) NOT NULL,
    performed_at timestamptz NOT NULL,
    result_json text NOT NULL,  -- [JSON matn]
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    CHECK (((payload_hash) ~ '^[0-9a-f]{64}$')),
    CHECK (kind in ('SINGLE', 'BUNDLE', 'ROUTE', 'DIRECT')),
    CHECK (coalesce(((jsonb_typeof((result_json)::jsonb) = 'object') and (jsonb_typeof(((result_json)::jsonb -> 'requestids')) = 'array') and (jsonb_array_length(((result_json)::jsonb -> 'requestids')) > 0) and (jsonb_typeof(((result_json)::jsonb -> 'waybillids')) = 'array') and (jsonb_array_length(((result_json)::jsonb -> 'waybillids')) = 1)), false))
);

-- TABLE: transport_production_create_operation  (satrlar: 0 — BO`SH)
CREATE TABLE transport_production_create_operation (
    operation_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    state varchar(16) NOT NULL,  -- RUXSAT: 'APPLIED', 'NOT_EXECUTED'
    result_json text,  -- [JSON matn]
    reason text,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    CHECK (state in ('APPLIED', 'NOT_EXECUTED'))
);

-- TABLE: transport_production_revision  (satrlar: noma'lum)
CREATE TABLE transport_production_revision (
    id uuid NOT NULL,
    order_id uuid NOT NULL,
    revision bigint NOT NULL,
    branch_id uuid NOT NULL,
    base_version bigint NOT NULL,
    policy_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    action varchar(32) NOT NULL,
    reason text NOT NULL,
    content_hash varchar(64) NOT NULL,
    content_json text NOT NULL,  -- [JSON matn]
    result_json text NOT NULL,  -- [JSON matn]
    PRIMARY KEY (id),
    FOREIGN KEY (order_id) REFERENCES production_order(id),
    FOREIGN KEY (policy_id) REFERENCES transport_quantity_policy(id),
    CHECK ((revision > 0))
);

-- TABLE: transport_quantity_operation  (satrlar: 0 — BO`SH)
CREATE TABLE transport_quantity_operation (
    operation_id uuid NOT NULL,
    subject_id uuid NOT NULL,
    domain varchar(16) NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    original_hash varchar(64) NOT NULL,
    state varchar(16) NOT NULL,  -- RUXSAT: 'APPLIED', 'NOT_EXECUTED'
    result_json text,  -- [JSON matn]
    reason text,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    CHECK (((((state) = 'applied') and (result_json is not null) and (reason is null)) or (((state) = 'not_executed') and (result_json is null) and (length(reason) > 0)))),
    CHECK (state in ('APPLIED', 'NOT_EXECUTED'))
);

-- TABLE: transport_quantity_policy  (satrlar: 0 — BO`SH)
CREATE TABLE transport_quantity_policy (
    id uuid NOT NULL,
    branch_id uuid NOT NULL,
    domain varchar(16) NOT NULL,  -- RUXSAT: 'SHIPMENT', 'PRODUCTION'
    operation_id uuid NOT NULL,
    previous_id uuid,
    actor_id uuid NOT NULL,
    reviewed_at timestamptz NOT NULL,
    payload_json text NOT NULL,  -- [JSON matn]
    payload_hash varchar(64) NOT NULL,
    PRIMARY KEY (id),
    CHECK (domain in ('SHIPMENT', 'PRODUCTION'))
);

-- TABLE: transport_request  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- TRANSPORT SO'ROVLARI BO'YICHA ASOSIY JADVAL — BARCHA TRANSPORT BUYURTMALARI SHU
-- JADVALDAN OLINADI. So'rov raqami, tashabbuskor (initiator_name), bo'lim,
-- tasdiqlovchi (approver_name), biriktirilgan logist, jo'natish va yetkazish
-- manzili (origin_location, destination_location) hamda koordinatalari, yuk
-- tavsifi, og'irligi KG DA (cargo_weight_kg) va hajmi m3 da, rejadagi jo'nash va
-- kelish vaqti, ustuvorlik, talab qilinadigan transport turi.
-- status: DRAFT, PENDING_DEPARTMENT_APPROVAL, PENDING_TRANSPORT_APPROVAL, APPROVED,
-- READY_FOR_PLANNING, ASSIGNED, IN_PROGRESS, COMPLETED, CANCELLED,
-- REJECTED_BY_DEPARTMENT, REJECTED_BY_TRANSPORT.
-- TASDIQ KUTAYOTGAN SO'ROVLAR status LIKE 'PENDING%' bo'yicha olinadi, rad etish
-- sababi rejection_reason da. Tarixi transport_request_audit, nuqtalari
-- transport_request_point jadvalida.
-- ---------------------------------------------------------------------
CREATE TABLE transport_request (
    id uuid NOT NULL,
    approver_name varchar(256),
    approver_user_id uuid,
    assigned_logistic_name varchar(256),
    assigned_logistic_user_id uuid,
    cargo_description varchar(1024),
    cargo_places integer,
    cargo_volume_m3 numeric(10,2),
    cargo_weight_kg numeric(10,2),
    comment varchar(1024),
    created_at timestamptz NOT NULL,
    department_id uuid,
    department_name varchar(256),
    destination_latitude numeric(10,6),
    destination_location varchar(512),
    destination_location_id uuid,
    destination_longitude numeric(10,6),
    eimzo_signature text,
    from_branch_id uuid,
    from_branch_name varchar(256),
    from_warehouse_id uuid,
    from_warehouse_name varchar(256),
    initiator_name varchar(256) NOT NULL,
    initiator_user_id uuid NOT NULL,
    origin_latitude numeric(10,6),
    origin_location varchar(512),
    origin_location_id uuid,
    origin_longitude numeric(10,6),
    planned_arrival_at timestamp,
    planned_departure_at timestamp,
    priority varchar(16) NOT NULL,
    purpose varchar(2048),
    rejection_reason varchar(512),
    request_number varchar(64) NOT NULL,
    request_type varchar(64) NOT NULL,
    required_transport_type varchar(32) NOT NULL,
    site_code varchar(120),
    special_requirements varchar(1024),
    status varchar(64) NOT NULL,  -- BAZADA (eng ko'p uchraydiganlari): 'COMPLETED' 1274, 'READY_FOR_PLANNING' 450, 'IN_PROGRESS' 346, 'AWAITING_CUSTOMER_CONFIRMATION' 280, 'ASSIGNED' 252, 'CANCELLED' 245, 'DRAFT' 7, 'ASSIGNED_TO_BRANCH' 6, 'PENDING_DEPARTMENT_APPROVAL' 4, 'SUBMITTED' 3, 'APPROVED' 2, 'PENDING_TRANSPORT_APPROVAL' 1
    submit varchar(255),
    to_branch_id uuid,
    to_branch_name varchar(256),
    to_warehouse_id uuid,
    to_warehouse_name varchar(256),
    updated_at timestamptz NOT NULL,
    version bigint NOT NULL,
    wms_shipment_id uuid,
    binding_driver_id uuid,
    binding_notes varchar(1024),
    binding_route_id uuid,
    binding_vehicle_id uuid,
    bound_at timestamptz,
    bound_by varchar(256),
    waybill_category varchar(32),
    return_location varchar(512),
    cargo_weight_tons numeric(8,2),
    planned_engine_hours numeric(8,2),
    work_site_area varchar(512),
    trailer_id uuid,
    trailer_plate_number varchar(32),
    actual_cargo_weight_tons numeric(10,2),
    actual_ton_km numeric(12,2),
    inbound_km numeric(10,2),
    inbound_tons numeric(10,2),
    outbound_km numeric(10,2),
    outbound_tons numeric(10,2),
    source varchar(32),
    submitted_at timestamptz,
    first_viewed_at timestamptz,
    first_viewed_by varchar(256),
    transport_head_approved_user_id uuid,
    transport_head_approved_by varchar(256),
    transport_head_approved_at timestamptz,
    transport_head_rejected_user_id uuid,
    transport_head_rejected_by varchar(256),
    transport_head_rejected_at timestamptz,
    assigned_branch_id uuid,
    assigned_branch_name varchar(256),
    assigned_by varchar(256),
    assigned_at timestamptz,
    customer_confirmation_status varchar(64),
    is_shift boolean,
    work_mode varchar(64),
    request_mode varchar(32),
    destination_region varchar(128),
    destination_district varchar(128),
    destination_address varchar(512),
    external_organization varchar(256),
    trip_type varchar(64),
    return_not_required boolean,
    passenger_count integer,
    daily_work_start_time varchar(8),
    daily_work_end_time varchar(8),
    exploitation_instruction varchar(2048),
    edo_request_number varchar,
    is_long_term boolean,
    auto_routed boolean,
    auto_routed_at timestamptz,
    auto_routed_branch_id uuid,
    auto_routing_reason varchar(1024),
    fast_track boolean,
    routing_mode varchar(32),
    urgency_reason varchar(1024),
    planning_end_instant timestamptz,
    planning_end_local varchar(64),
    planning_start_instant timestamptz,
    planning_start_local varchar(64),
    planning_time_zone varchar(64),
    correction_operation_id uuid,
    correction_retained_branch_id uuid,
    PRIMARY KEY (id)
);

-- TABLE: transport_request_audit  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Transport so'rovi ustidagi amallar tarixi: amal, oldingi va yangi status, kim
-- bajargani (actor_name), vaqti va izohi.
-- SO'ROV NEGA RAD ETILGANI YOKI QAYSI BOSQICHDA TURGANI SO'RALSA SHU JADVALDAN
-- OLINADI.
-- ---------------------------------------------------------------------
CREATE TABLE transport_request_audit (
    id uuid NOT NULL,
    action varchar(64) NOT NULL,
    actor_id varchar(128),
    actor_name varchar(256),
    comment varchar(512),
    new_status varchar(64),
    performed_at timestamptz NOT NULL,
    previous_status varchar(64),
    request_id uuid NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (request_id) REFERENCES transport_request(id)
);

-- TABLE: transport_request_customer_department  (satrlar: noma'lum)
CREATE TABLE transport_request_customer_department (
    id uuid NOT NULL,
    request_id uuid NOT NULL,
    department_id uuid NOT NULL,
    department_name varchar(256) NOT NULL,
    department_code varchar(64),
    sequence_number integer NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (request_id) REFERENCES transport_request(id),
    FOREIGN KEY (request_id) REFERENCES transport_request(id)
);

-- TABLE: transport_request_endpoint_review  (satrlar: noma'lum)
CREATE TABLE transport_request_endpoint_review (
    operation_id uuid NOT NULL,
    request_id uuid NOT NULL,
    request_version bigint NOT NULL,
    reviewed_json jsonb NOT NULL,  -- [JSON matn]
    point_snapshot jsonb NOT NULL,  -- [JSON matn]
    point_ids uuid[] NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (operation_id) REFERENCES transport_request_revision_command(operation_id),
    FOREIGN KEY (request_id) REFERENCES transport_request(id),
    CHECK ((cardinality(point_ids) = 2))
);

-- TABLE: transport_request_load_approval  (satrlar: noma'lum)
CREATE TABLE transport_request_load_approval (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    approved_at timestamptz NOT NULL,
    approved_request_version bigint NOT NULL,
    audit_id uuid NOT NULL,
    positions_json text,  -- [JSON matn]
    request_id uuid NOT NULL,
    reviewed_material_hash varchar(64),
    reviewed_source_id uuid,
    reviewed_source_revision bigint,
    source_snapshot_json text,  -- [JSON matn]
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (audit_id) REFERENCES transport_request_audit(id),
    FOREIGN KEY (request_id) REFERENCES transport_request(id),
    FOREIGN KEY (reviewed_source_id) REFERENCES transport_request_load_source(id)
);

-- TABLE: transport_request_load_approval_audit_context  (satrlar: noma'lum)
CREATE TABLE transport_request_load_approval_audit_context (
    audit_id uuid NOT NULL,
    request_id uuid NOT NULL,
    transaction_id bigint NOT NULL,
    PRIMARY KEY (audit_id)
);

-- TABLE: transport_request_load_approval_transition  (satrlar: noma'lum)
CREATE TABLE transport_request_load_approval_transition (
    request_id uuid NOT NULL,
    approved_request_version bigint NOT NULL,
    previous_status text NOT NULL,
    transaction_id bigint NOT NULL,
    PRIMARY KEY (request_id, approved_request_version)
);

-- TABLE: transport_request_load_source  (satrlar: noma'lum)
CREATE TABLE transport_request_load_source (
    id uuid NOT NULL,
    actor_id uuid NOT NULL,
    captured_request_version bigint NOT NULL,
    operation_id uuid NOT NULL,
    payload_hash varchar(64) NOT NULL,
    positions_json text NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    request_id uuid NOT NULL,
    revision bigint NOT NULL,
    source_hash varchar(64) NOT NULL,
    source_snapshot_json text NOT NULL,  -- [JSON matn]
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (request_id) REFERENCES transport_request(id)
);

-- TABLE: transport_request_load_source_audit_context  (satrlar: noma'lum)
CREATE TABLE transport_request_load_source_audit_context (
    source_id uuid NOT NULL,
    audit_id uuid NOT NULL,
    transaction_id bigint NOT NULL,
    PRIMARY KEY (source_id)
);

-- TABLE: transport_request_load_source_insert_context  (satrlar: noma'lum)
CREATE TABLE transport_request_load_source_insert_context (
    source_id uuid NOT NULL,
    request_id uuid NOT NULL,
    captured_request_version bigint NOT NULL,
    actor_id uuid NOT NULL,
    branch_id uuid,
    previous_status text NOT NULL,
    transaction_id bigint NOT NULL,
    PRIMARY KEY (source_id)
);

-- TABLE: transport_request_load_source_version_context  (satrlar: noma'lum)
CREATE TABLE transport_request_load_source_version_context (
    source_id uuid NOT NULL,
    request_id uuid NOT NULL,
    previous_version bigint NOT NULL,
    next_version bigint NOT NULL,
    transaction_id bigint NOT NULL,
    PRIMARY KEY (source_id)
);

-- TABLE: transport_request_point  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Transport so'rovidagi yuklash/tushirish nuqtalari: ketma-ketlik, nuqta turi
-- (ORIGIN, WAYPOINT, LOADING, UNLOADING, DESTINATION), manzil, koordinata,
-- oldingi nuqtadan masofa va vaqt.
-- ---------------------------------------------------------------------
CREATE TABLE transport_request_point (
    id uuid NOT NULL,
    address varchar(1024),
    distance_from_previous_km numeric(14,3) NOT NULL,
    drive_duration_from_previous_minutes bigint NOT NULL,
    latitude float8,
    location_id uuid,
    location_name varchar(512),
    longitude float8,
    planned_arrival_at timestamp NOT NULL,
    planned_departure_at timestamp NOT NULL,
    point_type varchar(32) NOT NULL,  -- RUXSAT: 'ORIGIN', 'WAYPOINT', 'LOADING', 'UNLOADING', 'DESTINATION'; BAZADA: 'ORIGIN' 85, 'DESTINATION' 85; ISHLATILMAGAN: WAYPOINT, LOADING, UNLOADING
    sequence_number integer NOT NULL,
    transport_request_id uuid NOT NULL,
    department_id uuid,
    department_name varchar(256),
    planning_start_local varchar(64),
    planning_end_local varchar(64),
    planning_time_zone varchar(64),
    planning_start_instant timestamptz,
    planning_end_instant timestamptz,
    PRIMARY KEY (id),
    FOREIGN KEY (transport_request_id) REFERENCES transport_request(id),
    CHECK (point_type in ('ORIGIN', 'WAYPOINT', 'LOADING', 'UNLOADING', 'DESTINATION'))
);

-- TABLE: transport_request_revision_audit_capture  (satrlar: noma'lum)
CREATE TABLE transport_request_revision_audit_capture (
    operation_id uuid NOT NULL,
    audit_id uuid NOT NULL,
    request_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    audit_json jsonb NOT NULL,  -- [JSON matn]
    transaction_id bigint NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id, audit_id),
    FOREIGN KEY (audit_id) REFERENCES transport_request_audit(id),
    FOREIGN KEY (operation_id) REFERENCES transport_request_revision_intent(operation_id)
);

-- TABLE: transport_request_revision_command  (satrlar: noma'lum)
CREATE TABLE transport_request_revision_command (
    operation_id uuid NOT NULL,
    request_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    action text NOT NULL,  -- RUXSAT: 'CORRECTION', 'CANONICAL_STOPS', 'BRANCH_ASSIGN'; BAZADA: 'CANONICAL_STOPS' 4, 'CORRECTION' 1, 'BRANCH_ASSIGN' 1
    expected_version bigint NOT NULL,
    result_version bigint,
    retained_branch_id uuid,
    original_json text NOT NULL,  -- [JSON matn]
    before_json jsonb NOT NULL,  -- [JSON matn]
    payload_hash text NOT NULL,
    outcome text NOT NULL,  -- RUXSAT: 'APPLIED', 'NOT_EXECUTED'; BAZADA: 'APPLIED' 5, 'NOT_EXECUTED' 1
    result_json text NOT NULL,  -- [JSON matn]
    transaction_id bigint NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (request_id) REFERENCES transport_request(id),
    CHECK (action in ('CORRECTION', 'CANONICAL_STOPS', 'BRANCH_ASSIGN')),
    CHECK ((((outcome = 'applied') and (expected_version < '9223372036854775807') and (result_version = (expected_version + 1))) or ((outcome = 'not_executed') and (result_version is null) and (retained_branch_id is null)))),
    CHECK ((expected_version >= 0)),
    CHECK ((length(original_json) <= 1048576)),
    CHECK (outcome in ('APPLIED', 'NOT_EXECUTED'))
);

-- TABLE: transport_request_revision_intent  (satrlar: noma'lum)
CREATE TABLE transport_request_revision_intent (
    operation_id uuid NOT NULL,
    request_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    action text NOT NULL,  -- RUXSAT: 'CORRECTION', 'CANONICAL_STOPS', 'BRANCH_ASSIGN'; BAZADA: 'CANONICAL_STOPS' 3, 'CORRECTION' 1, 'BRANCH_ASSIGN' 1
    original_json text NOT NULL,  -- [JSON matn]
    before_json jsonb NOT NULL,  -- [JSON matn]
    point_snapshot jsonb NOT NULL,  -- [JSON matn]
    material_snapshot jsonb NOT NULL,  -- [JSON matn]
    audit_snapshot jsonb NOT NULL,  -- [JSON matn]
    route_snapshot jsonb NOT NULL,  -- [JSON matn]
    transaction_id bigint NOT NULL,
    recorded_at timestamptz NOT NULL,
    manifest_retirement_before jsonb,  -- [JSON matn]
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (request_id) REFERENCES transport_request(id),
    CHECK (action in ('CORRECTION', 'CANONICAL_STOPS', 'BRANCH_ASSIGN'))
);

-- TABLE: transport_request_revision_transition  (satrlar: noma'lum)
CREATE TABLE transport_request_revision_transition (
    id uuid NOT NULL,
    request_id uuid NOT NULL,
    previous_version bigint NOT NULL,
    result_version bigint NOT NULL,
    before_json jsonb NOT NULL,  -- [JSON matn]
    after_json jsonb NOT NULL,  -- [JSON matn]
    transaction_id bigint NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: transport_request_service_confirmation  (satrlar: noma'lum)
CREATE TABLE transport_request_service_confirmation (
    id uuid NOT NULL,
    request_id uuid NOT NULL,
    trip_id uuid,
    department_id uuid NOT NULL,
    work_performed varchar(2048),
    arrival_at timestamptz,
    departure_at timestamptz,
    quantity numeric(12,2),
    unit varchar(64),
    result varchar(32),
    comment varchar(2048),
    confirmed_by_user_id uuid,
    confirmed_by_name varchar(256),
    confirmed_at timestamptz,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    status varchar(32),  -- BAZADA (eng ko'p uchraydiganlari): 'PENDING' 349, 'DISPUTED' 1, 'CONFIRMED' 1
    waybill_id uuid,
    vehicle_id uuid,
    driver_id uuid,
    PRIMARY KEY (id),
    FOREIGN KEY (request_id) REFERENCES transport_request(id)
);

-- TABLE: transport_request_transport_requirement  (satrlar: noma'lum)
CREATE TABLE transport_request_transport_requirement (
    id uuid NOT NULL,
    quantity integer NOT NULL,
    sequence_number integer NOT NULL,
    transport_type varchar(32) NOT NULL,
    request_id uuid NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (request_id) REFERENCES transport_request(id),
    FOREIGN KEY (request_id) REFERENCES transport_request(id)
);

-- TABLE: transport_requirement_operation  (satrlar: noma'lum)
CREATE TABLE transport_requirement_operation (
    id uuid NOT NULL,
    request_id uuid NOT NULL,
    requirement_id uuid NOT NULL,
    created_command_id uuid NOT NULL,
    created_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (created_by) REFERENCES app_user(id),
    FOREIGN KEY (created_command_id) REFERENCES transport_demand_operation_command(id),
    FOREIGN KEY (request_id) REFERENCES transport_request(id)
);

-- TABLE: transport_requirement_operation_revision  (satrlar: 0 — BO`SH)
CREATE TABLE transport_requirement_operation_revision (
    id uuid NOT NULL,
    command_id uuid NOT NULL,
    operation_id uuid NOT NULL,
    revision bigint NOT NULL,
    request_version bigint NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'DRAFT', 'CANCELLED'
    body jsonb NOT NULL,  -- [JSON matn]
    material_hash text NOT NULL,
    actor_id uuid NOT NULL,
    reason text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (operation_id) REFERENCES transport_requirement_operation(id),
    FOREIGN KEY (command_id) REFERENCES transport_demand_operation_command(id),
    CHECK ((material_hash ~ '^[a-f0-9]{64}$')),
    CHECK ((length(btrim(reason)) > 0)),
    CHECK ((request_version >= 0)),
    CHECK ((revision > 0)),
    CHECK (state in ('DRAFT', 'CANCELLED'))
);

-- TABLE: transport_route_context_closed  (satrlar: noma'lum)
CREATE TABLE transport_route_context_closed (
    id uuid NOT NULL,
    route_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    action text NOT NULL,  -- RUXSAT: 'SAVE', 'APPROVE', 'REVOKE', 'PERIOD_REPAIR'; BAZADA: 'SAVE' 1; ISHLATILMAGAN: APPROVE, REVOKE, PERIOD_REPAIR
    payload_hash text NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (route_id) REFERENCES route(id),
    CHECK (action in ('SAVE', 'APPROVE', 'REVOKE', 'PERIOD_REPAIR'))
);

-- TABLE: transport_route_context_invalidation  (satrlar: noma'lum)
CREATE TABLE transport_route_context_invalidation (
    id uuid NOT NULL,
    correction_id uuid NOT NULL,
    request_id uuid NOT NULL,
    route_id uuid NOT NULL,
    revision_id uuid,
    actor_id uuid NOT NULL,
    previous_route_version bigint NOT NULL,
    result_route_version bigint NOT NULL,
    basis text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (correction_id) REFERENCES transport_request_revision_command(operation_id),
    FOREIGN KEY (request_id) REFERENCES transport_request(id),
    FOREIGN KEY (revision_id) REFERENCES transport_route_operating_context(id),
    FOREIGN KEY (route_id) REFERENCES route(id),
    CHECK (((previous_route_version >= 0) and (previous_route_version < '9223372036854775807'))),
    CHECK (((length(btrim(basis)) >= 1) and (length(btrim(basis)) <= 2000))),
    CHECK ((result_route_version = (previous_route_version + 1)))
);

-- TABLE: transport_route_context_receipt  (satrlar: noma'lum)
CREATE TABLE transport_route_context_receipt (
    id uuid NOT NULL,
    route_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    action text NOT NULL,
    payload_hash text NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    result_json text NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (route_id) REFERENCES route(id)
);

-- TABLE: transport_route_operating_context  (satrlar: noma'lum)
CREATE TABLE transport_route_operating_context (
    id uuid NOT NULL,
    route_id uuid NOT NULL,
    captured_route_version bigint NOT NULL,
    geometry_hash text NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    context_json text NOT NULL,  -- [JSON matn]
    author_id uuid NOT NULL,
    native_geometry_json jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (author_id) REFERENCES app_user(id),
    FOREIGN KEY (route_id) REFERENCES route(id)
);

-- TABLE: transport_route_operating_decision  (satrlar: noma'lum)
CREATE TABLE transport_route_operating_decision (
    id uuid NOT NULL,
    revision_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    action text NOT NULL,  -- RUXSAT: 'APPROVE', 'REVOKE'
    basis text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (revision_id) REFERENCES transport_route_operating_context(id),
    CHECK (action in ('APPROVE', 'REVOKE'))
);

-- TABLE: transport_route_period_receipt  (satrlar: noma'lum)
CREATE TABLE transport_route_period_receipt (
    id uuid NOT NULL,
    route_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    action text NOT NULL,
    payload_hash text NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    result_json text NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (route_id) REFERENCES route(id),
    CHECK ((action = 'period_repair'))
);

-- TABLE: transport_route_stop_identity  (satrlar: noma'lum)
CREATE TABLE transport_route_stop_identity (
    id uuid NOT NULL,
    route_id uuid NOT NULL,
    amendment_id uuid,
    point_json jsonb,  -- [JSON matn]
    PRIMARY KEY (id),
    FOREIGN KEY (amendment_id) REFERENCES trip_route_amendment(id)
);

-- TABLE: transport_shipment_revision  (satrlar: noma'lum)
CREATE TABLE transport_shipment_revision (
    id uuid NOT NULL,
    shipment_id uuid NOT NULL,
    revision bigint NOT NULL,
    branch_id uuid NOT NULL,
    base_version bigint NOT NULL,
    policy_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    action varchar(32) NOT NULL,
    reason text NOT NULL,
    content_hash varchar(64) NOT NULL,
    content_json text NOT NULL,  -- [JSON matn]
    result_json text NOT NULL,  -- [JSON matn]
    PRIMARY KEY (id),
    FOREIGN KEY (policy_id) REFERENCES transport_quantity_policy(id),
    FOREIGN KEY (shipment_id) REFERENCES shipment(id),
    CHECK ((revision > 0))
);

-- TABLE: transport_source_identity  (satrlar: noma'lum)
CREATE TABLE transport_source_identity (
    domain varchar(16) NOT NULL,
    source_system varchar(128) NOT NULL,
    source_document_id varchar(256) NOT NULL,
    subject_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    registered_by uuid NOT NULL,
    registered_at timestamptz NOT NULL,
    PRIMARY KEY (domain, source_system, source_document_id)
);

-- TABLE: transport_source_revision  (satrlar: noma'lum)
CREATE TABLE transport_source_revision (
    id uuid NOT NULL,
    domain varchar(16) NOT NULL,
    source_system varchar(128) NOT NULL,
    source_document_id varchar(256) NOT NULL,
    source_revision varchar(256) NOT NULL,
    subject_id uuid NOT NULL,
    operation_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    result_json text NOT NULL,  -- [JSON matn]
    PRIMARY KEY (id)
);

-- TABLE: transport_vehicle  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- MASHINALAR (AVTOPARK) BO'YICHA ASOSIY JADVAL — BARCHA TRANSPORT MA'LUMOTLARI SHU
-- JADVALDAN OLINADI. Davlat raqami (plate_number), VIN, garaj raqami, marka va
-- model, yuk ko'tarish qobiliyati KG DA (payload_capacity_kg), hajmi m3,
-- foydalanishga topshirilgan sana, biriktirilgan haydovchi, bo'lim va filial,
-- GPS qurilma id, bugungi texnik ko'rik holati esa alohida vehicle_technical_inspection
-- JURNALIDAN olinadi (transport_vehicle da bunday bayroq ustuni YO'Q).
-- current_status: ACTIVE, RESERVED, IN_OPERATION, IN_MAINTENANCE, BLOCKED,
-- DECOMMISSIONED. transport_type: TRUCK, VAN, FLATBED, TANKER, REFRIGERATED,
-- SPECIALIZED, MINIBUS, PICKUP, TRAILER, OTHER.
-- category: LIGHT, MEDIUM, HEAVY, EXTRA_HEAVY, SPECIAL.
-- ownership_type: OWNED, LEASED, RENTED.
-- BO'SH MASHINA = current_status='ACTIVE' VA OCHIQ REYSI YO'Q.
-- Ikkinchi shart SHART: bu bazada current_status yuritilmaydi va reysdagi
-- mashina ham 'ACTIVE' bo'lib qolaveradi (02.09.2026: 128 mashinadan
-- 125 tasi 'ACTIVE'). Faqat current_status bilan hisoblangan
-- "foydalanish foizi" 95% chiqadi, holbuki reysda 2 ta mashina bor.
-- To'g'ri shakl:
-- WHERE v.current_status='ACTIVE' AND NOT EXISTS (
-- SELECT 1 FROM trip t WHERE t.vehicle_id=v.id
-- AND t.status IN ('PLANNED','ASSIGNED','STARTED',
-- 'ARRIVED_AT_POINT','LOADED','UNLOADED'))
-- ---------------------------------------------------------------------
CREATE TABLE transport_vehicle (
    id uuid NOT NULL,
    assigned_driver_id uuid,
    branch_id uuid,
    brand varchar(64) NOT NULL,
    category varchar(32) NOT NULL,  -- RUXSAT: 'LIGHT', 'MEDIUM', 'HEAVY', 'EXTRA_HEAVY', 'SPECIAL', 'ELECTRIC_VEHICLE', 'ELECTRIC'; BAZADA: 'LIGHT' 50, 'SPECIAL' 47, 'HEAVY' 43, 'MEDIUM' 17; ISHLATILMAGAN: EXTRA_HEAVY, ELECTRIC_VEHICLE, ELECTRIC
    commissioning_date date,
    created_at timestamptz NOT NULL,
    created_by varchar(256) NOT NULL,
    current_status varchar(32) NOT NULL,  -- RUXSAT: 'ACTIVE', 'RESERVED', 'IN_OPERATION', 'IN_MAINTENANCE', 'BLOCKED', 'DECOMMISSIONED'; BAZADA: 'ACTIVE' 162, 'IN_MAINTENANCE' 1; ISHLATILMAGAN: RESERVED, IN_OPERATION, BLOCKED, DECOMMISSIONED
    department_id uuid,
    engine_power numeric(10,2),
    gps_device_id varchar(128),
    model varchar(64) NOT NULL,
    ownership_type varchar(32) NOT NULL,  -- RUXSAT: 'OWNED', 'LEASED', 'RENTED'; BAZADA: 'OWNED' 156; ISHLATILMAGAN: LEASED, RENTED
    payload_capacity_kg numeric(10,2),
    plate_number varchar(32),
    ref_id varchar(16) NOT NULL,
    release_date date,
    seat_count integer,
    tech_passport_date date,
    tech_passport_number varchar(128),
    transport_type varchar(32) NOT NULL,  -- RUXSAT: 'MOBILE_CRANE', 'AERIAL_PLATFORM', 'TRACTOR', 'WATER_TRUCK', 'EXCAVATOR', 'FRONT_LOADER', 'DUMP_TRUCK', 'LONG_LOAD_TRUCK', 'FLATBED', 'MANIPULATOR', 'PASSENGER_CAR', 'BUS', 'VAN', 'BULLDOZER', 'CONCRETE_PUMP', 'CONCRETE_MIXER', 'FIRE_TRUCK', 'AMBULANCE', 'TRUCK', 'TANKER', 'REFRIGERATED', 'SPECIALIZED', 'MINIBUS', 'PICKUP', 'TRAILER', 'OTHER', 'ELECTRIC_VEHICLE'; BAZADA: 'PASSENGER_CAR' 49, 'SPECIALIZED' 18, 'FLATBED' 14, 'BUS' 13, 'DUMP_TRUCK' 13, 'TRACTOR' 9, 'ELECTRIC_VEHICLE' 7, 'MOBILE_CRANE' 7, 'FRONT_LOADER' 7, 'AERIAL_PLATFORM' 7, 'LONG_LOAD_TRUCK' 5, 'WATER_TRUCK' 4, 'EXCAVATOR' 3, 'VAN' 3, 'CONCRETE_MIXER' 2, 'CONCRETE_PUMP' 1, 'BULLDOZER' 1; ISHLATILMAGAN: MANIPULATOR, FIRE_TRUCK, AMBULANCE, TRUCK, TANKER, REFRIGERATED, MINIBUS, PICKUP, TRAILER, OTHER
    updated_at timestamptz NOT NULL,
    updated_by varchar(256) NOT NULL,
    vehicle_color varchar(64),
    vin varchar(64),
    volume_m3 numeric(10,2),
    usage_mode varchar(32) NOT NULL,  -- RUXSAT: 'KM', 'MOTOSOAT', 'KM_AND_MOTOSOAT'; BAZADA: 'KM' 115, 'MOTOSOAT' 38, 'KM_AND_MOTOSOAT' 11
    cargo_capacity_tons numeric,
    cargo_capacity_version bigint NOT NULL,
    passenger_capacity integer,
    PRIMARY KEY (id),
    CHECK (category in ('LIGHT', 'MEDIUM', 'HEAVY', 'EXTRA_HEAVY', 'SPECIAL', 'ELECTRIC_VEHICLE', 'ELECTRIC')),
    CHECK (current_status in ('ACTIVE', 'RESERVED', 'IN_OPERATION', 'IN_MAINTENANCE', 'BLOCKED', 'DECOMMISSIONED')),
    CHECK (ownership_type in ('OWNED', 'LEASED', 'RENTED')),
    CHECK (transport_type in ('MOBILE_CRANE', 'AERIAL_PLATFORM', 'TRACTOR', 'WATER_TRUCK', 'EXCAVATOR', 'FRONT_LOADER', 'DUMP_TRUCK', 'LONG_LOAD_TRUCK', 'FLATBED', 'MANIPULATOR', 'PASSENGER_CAR', 'BUS', 'VAN', 'BULLDOZER', 'CONCRETE_PUMP', 'CONCRETE_MIXER', 'FIRE_TRUCK', 'AMBULANCE', 'TRUCK', 'TANKER', 'REFRIGERATED', 'SPECIALIZED', 'MINIBUS', 'PICKUP', 'TRAILER', 'OTHER', 'ELECTRIC_VEHICLE')),
    CHECK (usage_mode in ('KM', 'MOTOSOAT', 'KM_AND_MOTOSOAT'))
);

-- TABLE: transport_waybill_anomaly_closure  (satrlar: noma'lum)
CREATE TABLE transport_waybill_anomaly_closure (
    id uuid NOT NULL,
    operation_id uuid NOT NULL,
    waybill_id uuid NOT NULL,
    trip_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    inspection_revision_id uuid NOT NULL,
    policy_revision_id uuid NOT NULL,
    original_json jsonb NOT NULL,  -- [JSON matn]
    result_json jsonb NOT NULL,  -- [JSON matn]
    before_json jsonb NOT NULL,  -- [JSON matn]
    after_json jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (inspection_revision_id) REFERENCES safety_technical_inspection_revision(id),
    FOREIGN KEY (policy_revision_id) REFERENCES transport_governance_policy(id),
    FOREIGN KEY (trip_id) REFERENCES trip(id),
    FOREIGN KEY (waybill_id) REFERENCES waybill(id)
);

-- TABLE: transport_waybill_anomaly_operation  (satrlar: 0 — BO`SH)
CREATE TABLE transport_waybill_anomaly_operation (
    operation_id uuid NOT NULL,
    waybill_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'APPLIED', 'NOT_EXECUTED'
    original_json jsonb NOT NULL,  -- [JSON matn]
    result_json jsonb,  -- [JSON matn]
    reason text,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (waybill_id) REFERENCES waybill(id),
    CHECK ((((state = 'applied') and (result_json is not null) and (reason is null)) or ((state = 'not_executed') and (result_json is null) and (length(trim(both from reason)) > 0)))),
    CHECK (state in ('APPLIED', 'NOT_EXECUTED'))
);

-- TABLE: transport_waybill_anomaly_outbox  (satrlar: noma'lum)
CREATE TABLE transport_waybill_anomaly_outbox (
    id uuid NOT NULL,
    closure_id uuid NOT NULL,
    event_type text NOT NULL,
    payload jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (closure_id) REFERENCES transport_waybill_anomaly_closure(id),
    CHECK ((event_type = 'waybill_closed_with_anomaly'))
);

-- TABLE: transport_waybill_passport_snapshot  (satrlar: noma'lum)
CREATE TABLE transport_waybill_passport_snapshot (
    waybill_id uuid NOT NULL,
    waybill_version bigint NOT NULL,
    assignment_snapshot_id uuid NOT NULL,
    source_hash text NOT NULL,
    snapshot_json jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (waybill_id, waybill_version),
    FOREIGN KEY (assignment_snapshot_id) REFERENCES transport_passport_assignment(id),
    FOREIGN KEY (waybill_id) REFERENCES waybill(id)
);

-- TABLE: trip  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- REYSLAR BO'YICHA ASOSIY JADVAL — BARCHA REYS MA'LUMOTLARI SHU JADVALDAN OLINADI.
-- Reys raqami, marshrut, transport so'rovi, mashina va haydovchi; rejadagi va
-- amaldagi jo'nash/kelish vaqti, amaldagi masofa (actual_distance_km) va
-- marshrutdan chetlanish belgisi (deviation_flag).
-- KECHIKISH USTUNI YO'Q — u HISOBLANADI, saqlanmaydi:
-- jo'nab ketmagan  : now() - scheduled_departure_at
-- yo'lda kechikkan : now() - scheduled_arrival_at
-- `delay_minutes` deb ustun IZLAMANG, bunday ustun hech qachon bo'lmagan.
-- status: PLANNED, ASSIGNED, STARTED, ARRIVED_AT_POINT, LOADED, UNLOADED,
-- COMPLETED, CANCELLED, INTERRUPTED.
-- KECHIKAYOTGAN REYSLAR delay_minutes > 0 BO'YICHA OLINADI.
-- FAOL REYSLAR status IN ('STARTED','ARRIVED_AT_POINT','LOADED','UNLOADED').
-- Reys hodisalari trip_event jadvalida.
-- ---------------------------------------------------------------------
CREATE TABLE trip (
    id uuid NOT NULL,
    actual_arrival_at timestamp,
    actual_departure_at timestamp,
    actual_distance_km numeric(14,3) NOT NULL,
    cancellation_reason varchar(1024),
    created_at timestamptz NOT NULL,
    deviation_flag boolean NOT NULL,
    driver_id uuid NOT NULL,
    route_id uuid NOT NULL,
    scheduled_arrival_at timestamp NOT NULL,
    scheduled_departure_at timestamp NOT NULL,
    status varchar(32) NOT NULL,  -- RUXSAT: 'PLANNED', 'ASSIGNED', 'STARTED', 'ARRIVED_AT_POINT', 'LOADED', 'UNLOADED', 'COMPLETED', 'CANCELLED', 'INTERRUPTED'; BAZADA: 'COMPLETED' 3097, 'ASSIGNED' 296, 'STARTED' 284, 'CANCELLED' 264, 'UNLOADED' 153; ISHLATILMAGAN: PLANNED, ARRIVED_AT_POINT, LOADED, INTERRUPTED
    transport_request_id uuid,
    trip_number varchar(32) NOT NULL,
    updated_at timestamptz NOT NULL,
    vehicle_id uuid NOT NULL,
    version bigint NOT NULL,
    actual_engine_hours numeric(14,3),
    trailer_id uuid,
    trailer_plate_number varchar(32),
    trailer_model varchar(64),
    fuel_rate_norm numeric(8,2),
    norm_source varchar(32),
    passenger_count integer,
    work_mode varchar(64),
    is_shift boolean NOT NULL,
    planning_end_instant timestamptz,
    planning_end_local varchar(64),
    planning_start_instant timestamptz,
    planning_start_local varchar(64),
    planning_time_zone varchar(64),
    release_departure_instant timestamptz,
    release_departure_local varchar(64),
    release_departure_zone varchar(64),
    release_return_instant timestamptz,
    release_return_local varchar(64),
    release_return_zone varchar(64),
    PRIMARY KEY (id),
    CHECK (status in ('PLANNED', 'ASSIGNED', 'STARTED', 'ARRIVED_AT_POINT', 'LOADED', 'UNLOADED', 'COMPLETED', 'CANCELLED', 'INTERRUPTED'))
);

-- TABLE: trip_delivery_acceptance  (satrlar: noma'lum)
CREATE TABLE trip_delivery_acceptance (
    id uuid NOT NULL,
    trip_id uuid NOT NULL,
    delivery_event_id uuid NOT NULL,
    allocation_id uuid NOT NULL,
    position_id uuid NOT NULL,
    point_id uuid NOT NULL,
    request_id uuid NOT NULL,
    correction_version bigint NOT NULL,
    quantity numeric(18,6) NOT NULL,
    unit_code text NOT NULL,
    binding_id uuid NOT NULL,
    binding_version bigint NOT NULL,
    recipient_id uuid NOT NULL,
    otp_id uuid NOT NULL,
    operation_id uuid NOT NULL,
    accepted_by uuid NOT NULL,
    accepted_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (accepted_by) REFERENCES app_user(id),
    FOREIGN KEY (binding_id) REFERENCES trip_delivery_recipient_binding(id),
    FOREIGN KEY (delivery_event_id) REFERENCES trip_quantity_event(id),
    FOREIGN KEY (otp_id) REFERENCES trip_delivery_otp_challenge(id),
    FOREIGN KEY (trip_id) REFERENCES trip(id),
    CHECK ((quantity > (0)))
);

-- TABLE: trip_delivery_otp_attempt  (satrlar: noma'lum)
CREATE TABLE trip_delivery_otp_attempt (
    operation_id uuid NOT NULL,
    otp_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    code_hash text NOT NULL,
    outcome text NOT NULL,
    recorded_at timestamptz NOT NULL,
    result_json text,  -- [JSON matn]
    PRIMARY KEY (operation_id),
    FOREIGN KEY (otp_id) REFERENCES trip_delivery_otp_challenge(id)
);

-- TABLE: trip_delivery_otp_challenge  (satrlar: 0 — BO`SH)
CREATE TABLE trip_delivery_otp_challenge (
    id uuid NOT NULL,
    operation_id uuid NOT NULL,
    trip_id uuid NOT NULL,
    delivery_event_id uuid NOT NULL,
    allocation_id uuid NOT NULL,
    position_id uuid NOT NULL,
    point_id uuid NOT NULL,
    request_id uuid NOT NULL,
    correction_version bigint NOT NULL,
    quantity numeric(18,6) NOT NULL,
    unit_code text NOT NULL,
    binding_id uuid NOT NULL,
    binding_version bigint NOT NULL,
    actor_id uuid NOT NULL,
    code_hash text NOT NULL,
    salt uuid NOT NULL,  -- [MAXFIY — o'qish taqiqlangan]
    recipient_id uuid NOT NULL,
    telegram_chat_id bigint NOT NULL,
    expires_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    status text NOT NULL,  -- RUXSAT: 'SENDING', 'SENT', 'SEND_UNKNOWN', 'FAILED', 'VERIFIED', 'EXPIRED'
    attempt_count integer NOT NULL,
    max_attempts integer NOT NULL,
    verified_at timestamptz,
    recipient_contact_json text NOT NULL,  -- [JSON matn]
    PRIMARY KEY (id),
    FOREIGN KEY (binding_id) REFERENCES trip_delivery_recipient_binding(id),
    FOREIGN KEY (delivery_event_id) REFERENCES trip_quantity_event(id),
    FOREIGN KEY (trip_id) REFERENCES trip(id),
    CHECK ((quantity > (0))),
    CHECK (status in ('SENDING', 'SENT', 'SEND_UNKNOWN', 'FAILED', 'VERIFIED', 'EXPIRED'))
);

-- TABLE: trip_delivery_otp_request_closed  (satrlar: noma'lum)
CREATE TABLE trip_delivery_otp_request_closed (
    operation_id uuid NOT NULL,
    trip_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id)
);

-- TABLE: trip_delivery_recipient_binding  (satrlar: noma'lum)
CREATE TABLE trip_delivery_recipient_binding (
    id uuid NOT NULL,
    request_id uuid NOT NULL,
    point_id uuid NOT NULL,
    recipient_id uuid NOT NULL,
    version bigint NOT NULL,
    active boolean NOT NULL,
    previous_id uuid,
    operation_id uuid NOT NULL,
    approved_by uuid NOT NULL,
    approved_at timestamptz NOT NULL,
    approval_reference text NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    recipient_contact_json text NOT NULL,  -- [JSON matn]
    PRIMARY KEY (id),
    FOREIGN KEY (approved_by) REFERENCES app_user(id),
    FOREIGN KEY (recipient_id) REFERENCES telegram_recipient(id),
    FOREIGN KEY (request_id) REFERENCES transport_request(id),
    FOREIGN KEY (point_id) REFERENCES transport_route_stop_identity(id),
    CHECK ((version > 0))
);

-- TABLE: trip_event  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Reys hodisalari: reys yaratildi, boshlandi, nuqtaga yetdi, yuklandi, tushirildi,
-- bekor turish qayd etildi, marshrutdan chetlanish aniqlandi, yakunlandi, bekor
-- qilindi. source — hodisa manbai: DRIVER, DISPATCHER, PLANNING_SERVICE,
-- TELEMATICS_SERVICE, SYSTEM. payload_json da qo'shimcha ma'lumot.
-- REYS YO'LIDA NIMA BO'LGANI SO'RALSA event_time BO'YICHA TARTIBLAB OLINADI.
-- ---------------------------------------------------------------------
CREATE TABLE trip_event (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    event_time timestamp NOT NULL,
    event_type varchar(64) NOT NULL,  -- RUXSAT: 'TRIP_CREATED_FROM_PLANNING', 'TRIP_RESCHEDULED', 'TRIP_STARTED', 'TRIP_ARRIVED_AT_POINT', 'TRIP_LOADED', 'TRIP_UNLOADED', 'TRIP_RETURNED_TO_BASE', 'TRIP_DOWNTIME_RECORDED', 'TRIP_DEVIATION_DETECTED', 'TRIP_RESERVATION_EXPIRED', 'TRIP_COMPLETED', 'TRIP_CANCELLED', 'TRIP_DELIVERY_CONFIRMED', 'TRIP_STOP_ADDED', 'TRIP_DRIVER_REASSIGNED', 'TRIP_VEHICLE_REASSIGNED', 'TRIP_TRAILER_REASSIGNED', 'TRIP_REROUTED', 'TRIP_WAYBILL_ISSUED'; BAZADA: 'TRIP_COMPLETED' 2731, 'TRIP_RETURNED_TO_BASE' 2727, 'TRIP_STARTED' 2604, 'TRIP_CREATED_FROM_PLANNING' 1374, 'TRIP_CANCELLED' 397, 'TRIP_REROUTED' 104, 'TRIP_ARRIVED_AT_POINT' 15, 'TRIP_UNLOADED' 13, 'TRIP_LOADED' 13, 'TRIP_VEHICLE_REASSIGNED' 9, 'TRIP_STOP_ADDED' 7, 'TRIP_DOWNTIME_RECORDED' 5, 'TRIP_DRIVER_REASSIGNED' 4, 'TRIP_WAYBILL_ISSUED' 2, 'TRIP_RESCHEDULED' 1; ISHLATILMAGAN: TRIP_DEVIATION_DETECTED, TRIP_RESERVATION_EXPIRED, TRIP_DELIVERY_CONFIRMED, TRIP_TRAILER_REASSIGNED
    payload_json text,  -- [JSON matn]
    point_id uuid,
    source varchar(32) NOT NULL,  -- RUXSAT: 'DRIVER', 'DISPATCHER', 'PLANNING_SERVICE', 'TELEMATICS_SERVICE', 'SYSTEM'; BAZADA: 'DISPATCHER' 7595, 'PLANNING_SERVICE' 1349, 'SYSTEM' 1055; ISHLATILMAGAN: DRIVER, TELEMATICS_SERVICE
    trip_id uuid NOT NULL,
    occurred_at_utc timestamptz,
    occurrence_zone varchar(64),
    occurrence_offset_seconds integer,
    PRIMARY KEY (id),
    FOREIGN KEY (trip_id) REFERENCES trip(id),
    CHECK (event_type in ('TRIP_CREATED_FROM_PLANNING', 'TRIP_RESCHEDULED', 'TRIP_STARTED', 'TRIP_ARRIVED_AT_POINT', 'TRIP_LOADED', 'TRIP_UNLOADED', 'TRIP_RETURNED_TO_BASE', 'TRIP_DOWNTIME_RECORDED', 'TRIP_DEVIATION_DETECTED', 'TRIP_RESERVATION_EXPIRED', 'TRIP_COMPLETED', 'TRIP_CANCELLED', 'TRIP_DELIVERY_CONFIRMED', 'TRIP_STOP_ADDED', 'TRIP_DRIVER_REASSIGNED', 'TRIP_VEHICLE_REASSIGNED', 'TRIP_TRAILER_REASSIGNED', 'TRIP_REROUTED', 'TRIP_WAYBILL_ISSUED')),
    CHECK ((((occurred_at_utc is null) and (occurrence_zone is null) and (occurrence_offset_seconds is null)) or ((occurred_at_utc is not null) and (occurrence_zone is not null) and (occurrence_offset_seconds is not null) and ((occurrence_offset_seconds >= '-64800') and (occurrence_offset_seconds <= 64800))))),
    CHECK (source in ('DRIVER', 'DISPATCHER', 'PLANNING_SERVICE', 'TELEMATICS_SERVICE', 'SYSTEM'))
);

-- TABLE: trip_legacy_load_baseline  (satrlar: noma'lum)
CREATE TABLE trip_legacy_load_baseline (
    id uuid NOT NULL,
    trip_id uuid NOT NULL,
    route_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    captured_trip_version bigint NOT NULL,
    captured_route_version bigint NOT NULL,
    assessment_basis_json text NOT NULL,  -- [JSON matn]
    assessment_hash text NOT NULL,
    proof_json text NOT NULL,  -- [JSON matn]
    result_json text NOT NULL,  -- [JSON matn]
    reference text NOT NULL,
    reason text NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    payload_hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (route_id) REFERENCES route(id),
    FOREIGN KEY (trip_id) REFERENCES trip(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id),
    CHECK ((captured_route_version >= 0)),
    CHECK ((captured_trip_version >= 0)),
    CHECK ((payload_hash = encode(sha256(convert_to((((trip_id) || ':') || original_json), 'utf8'::name)), 'hex'))),
    CHECK ((payload_hash ~ '^[a-f0-9]{64}$')),
    CHECK (((length(btrim(reason)) >= 1) and (length(btrim(reason)) <= 2000))),
    CHECK (((length(btrim(reference)) >= 1) and (length(btrim(reference)) <= 2000)))
);

-- TABLE: trip_legacy_load_baseline_command  (satrlar: 0 — BO`SH)
CREATE TABLE trip_legacy_load_baseline_command (
    operation_id uuid NOT NULL,
    trip_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    payload_hash text NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    outcome text NOT NULL,  -- RUXSAT: 'APPLIED', 'NOT_EXECUTED'
    result_json text NOT NULL,  -- [JSON matn]
    closure_reason text,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (trip_id) REFERENCES trip(id),
    CHECK ((payload_hash = encode(sha256(convert_to((((trip_id) || ':') || original_json), 'utf8'::name)), 'hex'))),
    CHECK (((outcome = 'not_executed') = (closure_reason is not null))),
    CHECK (((closure_reason is null) or ((length(btrim(closure_reason)) >= 1) and (length(btrim(closure_reason)) <= 2000)))),
    CHECK (outcome in ('APPLIED', 'NOT_EXECUTED'))
);

-- TABLE: trip_pending_reschedule  (satrlar: noma'lum)
CREATE TABLE trip_pending_reschedule (
    id uuid NOT NULL,
    trip_id uuid NOT NULL,
    route_id uuid NOT NULL,
    requested_departure_at timestamp NOT NULL,
    requested_arrival_at timestamp NOT NULL,
    vehicle_id uuid NOT NULL,
    driver_id uuid NOT NULL,
    reason text,
    requested_by uuid NOT NULL,
    context_revision_id uuid NOT NULL,
    trip_version bigint NOT NULL,
    state varchar(16) NOT NULL,
    created_at timestamptz NOT NULL,
    resolved_at timestamptz,
    resolved_by uuid,
    failure text,
    PRIMARY KEY (id)
);

-- TABLE: trip_quantity_command  (satrlar: 0 — BO`SH)
CREATE TABLE trip_quantity_command (
    id uuid NOT NULL,
    trip_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    payload_hash text NOT NULL,
    original_json text NOT NULL,  -- [JSON matn]
    outcome text NOT NULL,  -- RUXSAT: 'APPLIED', 'NOT_EXECUTED'
    closure_reason text,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (trip_id) REFERENCES trip(id),
    CHECK (outcome in ('APPLIED', 'NOT_EXECUTED'))
);

-- TABLE: trip_quantity_event  (satrlar: 0 — BO`SH)
CREATE TABLE trip_quantity_event (
    id uuid NOT NULL,
    trip_id uuid NOT NULL,
    route_id uuid NOT NULL,
    manifest_id uuid NOT NULL,
    allocation_id uuid NOT NULL,
    request_id uuid NOT NULL,
    position_id uuid NOT NULL,
    point_id uuid NOT NULL,
    action text NOT NULL,  -- RUXSAT: 'LOAD', 'DELIVER', 'RETURN'
    quantity_delta numeric(18,6) NOT NULL,
    measurement_quantity numeric(18,6) NOT NULL,
    unit_code text NOT NULL,  -- RUXSAT: 'TONNE', 'PASSENGER'
    occurred_at timestamptz NOT NULL,
    measurement_source_id uuid NOT NULL,
    source_hash text NOT NULL,
    actor_id uuid NOT NULL,
    corrected_event_id uuid,
    correction_version bigint NOT NULL,
    reason text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (corrected_event_id) REFERENCES trip_quantity_event(id),
    FOREIGN KEY (measurement_source_id) REFERENCES transport_execution_source_revision(id),
    FOREIGN KEY (request_id) REFERENCES transport_request(id),
    FOREIGN KEY (route_id) REFERENCES route(id),
    FOREIGN KEY (trip_id) REFERENCES trip(id),
    FOREIGN KEY (point_id) REFERENCES transport_route_stop_identity(id),
    CHECK (action in ('LOAD', 'DELIVER', 'RETURN')),
    CHECK ((correction_version >= 0)),
    CHECK ((measurement_quantity >= (0))),
    CHECK (((length(btrim(reason)) >= 1) and (length(btrim(reason)) <= 2000))),
    CHECK (unit_code in ('TONNE', 'PASSENGER'))
);

-- TABLE: trip_quantity_outbox  (satrlar: noma'lum)
CREATE TABLE trip_quantity_outbox (
    id uuid NOT NULL,
    trip_id uuid NOT NULL,
    event_json jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (id) REFERENCES trip_quantity_event(id)
);

-- TABLE: trip_resource_replacement_proof  (satrlar: noma'lum)
CREATE TABLE trip_resource_replacement_proof (
    id uuid NOT NULL,
    operation_id uuid NOT NULL,
    trip_id uuid NOT NULL,
    route_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    captured_trip_version bigint NOT NULL,
    captured_route_version bigint NOT NULL,
    previous_vehicle_id uuid NOT NULL,
    target_vehicle_id uuid NOT NULL,
    parent_manifest_id uuid NOT NULL,
    parent_assessment_hash text NOT NULL,
    effective_at timestamptz NOT NULL,
    recorded_at timestamptz NOT NULL,
    assessment_basis_json text NOT NULL,  -- [JSON matn]
    assessment_hash text NOT NULL,
    proof_json text NOT NULL,  -- [JSON matn]
    original_json text NOT NULL,  -- [JSON matn]
    command_hash text NOT NULL,
    before_json jsonb NOT NULL,  -- [JSON matn]
    transaction_id bigint NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (operation_id) REFERENCES transport_assignment_command(operation_id),
    FOREIGN KEY (previous_vehicle_id) REFERENCES transport_vehicle(id),
    FOREIGN KEY (route_id) REFERENCES route(id),
    FOREIGN KEY (target_vehicle_id) REFERENCES transport_vehicle(id),
    FOREIGN KEY (trip_id) REFERENCES trip(id),
    CHECK ((assessment_hash ~ '^[a-f0-9]{64}$')),
    CHECK ((captured_route_version >= 0)),
    CHECK ((captured_trip_version >= 0)),
    CHECK ((id = operation_id)),
    CHECK ((previous_vehicle_id <> target_vehicle_id)),
    CHECK ((command_hash ~ '^[a-f0-9]{64}$')),
    CHECK ((parent_assessment_hash ~ '^[a-f0-9]{64}$'))
);

-- TABLE: trip_route_amendment  (satrlar: noma'lum)
CREATE TABLE trip_route_amendment (
    id uuid NOT NULL,
    operation_id uuid NOT NULL,
    trip_id uuid NOT NULL,
    route_id uuid NOT NULL,
    revision bigint NOT NULL,
    previous_id uuid,
    base_manifest_id uuid NOT NULL,
    captured_trip_version bigint NOT NULL,
    captured_route_version bigint NOT NULL,
    effective_at timestamptz NOT NULL,
    actor_id uuid NOT NULL,
    physical_hash text NOT NULL,
    onboard_json jsonb NOT NULL,  -- [JSON matn]
    qualification_json jsonb NOT NULL,  -- [JSON matn]
    assessment_basis_json text NOT NULL,  -- [JSON matn]
    assessment_hash text NOT NULL,
    proof_json text NOT NULL,  -- [JSON matn]
    future_sections_json jsonb NOT NULL,  -- [JSON matn]
    result_json text NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (previous_id) REFERENCES trip_route_amendment(id),
    FOREIGN KEY (route_id) REFERENCES route(id),
    FOREIGN KEY (trip_id) REFERENCES trip(id),
    CHECK ((physical_hash ~ '^[a-f0-9]{64}$')),
    CHECK (((length(btrim(reason)) >= 1) and (length(btrim(reason)) <= 2000))),
    CHECK ((revision > 0))
);

-- TABLE: trip_route_amendment_document  (satrlar: noma'lum)
CREATE TABLE trip_route_amendment_document (
    amendment_id uuid NOT NULL,
    waybill_id uuid NOT NULL,
    captured_version bigint NOT NULL,
    captured_status text NOT NULL,
    PRIMARY KEY (amendment_id, waybill_id),
    FOREIGN KEY (amendment_id) REFERENCES trip_route_amendment(id),
    FOREIGN KEY (waybill_id) REFERENCES waybill(id)
);

-- TABLE: trip_route_amendment_gate  (satrlar: 0 — BO`SH)
CREATE TABLE trip_route_amendment_gate (
    id uuid NOT NULL,
    amendment_id uuid NOT NULL,
    trip_id uuid NOT NULL,
    target_version bigint NOT NULL,
    point_id uuid NOT NULL,
    action text NOT NULL,  -- RUXSAT: 'ARRIVE', 'LOAD', 'UNLOAD', 'RETURN'
    actor_id uuid NOT NULL,
    qualification_json jsonb NOT NULL,  -- [JSON matn]
    safety_json jsonb NOT NULL,  -- [JSON matn]
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (amendment_id) REFERENCES trip_route_amendment(id),
    FOREIGN KEY (trip_id) REFERENCES trip(id),
    CHECK (action in ('ARRIVE', 'LOAD', 'UNLOAD', 'RETURN'))
);

-- TABLE: trip_route_effective_planning_manifest_latest  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
CREATE TABLE trip_route_effective_planning_manifest_latest (
    id uuid,
    operation_id uuid,
    route_id uuid,
    vehicle_id uuid,
    actor_id uuid,
    recorded_at timestamptz,
    assessment_basis_json text,  -- [JSON matn]
    assessment_hash varchar(64),
    proof_json text  -- [JSON matn]
);

-- TABLE: user_department  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Foydalanuvchining qaysi bo'limga (department) biriktirilganini ko'rsatadi.
-- BITTA FOYDALANUVCHIDA BITTA BO'LIM bo'ladi (user_id unique). Bo'lim nomi
-- reference_data jadvalida catalog_type='DEPARTMENTS' bo'yicha turadi.
-- (Ilgari `user_department` deb atalardi — sxema ko'chirishda nomi o'zgargan.)
-- ---------------------------------------------------------------------
CREATE TABLE user_department (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    department_id uuid NOT NULL,
    updated_at timestamptz NOT NULL,
    user_id uuid NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: user_role  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- FOYDALANUVCHI ROLLARI (bog'lovchi jadval): user_id, role.
-- Ilgari `app_user_role` deb atalardi.
-- ---------------------------------------------------------------------
CREATE TABLE user_role (
    user_id uuid NOT NULL,
    role varchar(255),  -- RUXSAT: 'ADMIN', 'LOGISTICIAN', 'DISPATCHER', 'DRIVER', 'REQUEST_INITIATOR', 'FUEL_OPERATOR', 'MEDIC', 'MECHANIC', 'WORKSHOP_MASTER', 'ANALYST', 'HEAD_OF_DEPARTMENT', 'ACCOUNTANT', 'SECURITY_OFFICER', 'WAREHOUSE_OPERATOR', 'HEAD_OF_OPERATIONS', 'EXPLOITATION', 'OPERATIONS', 'FUEL_ATTENDANT', 'TRANSPORT_DEPARTMENT_HEAD', 'PTO'; BAZADA: 'HEAD_OF_DEPARTMENT' 579, 'REQUEST_INITIATOR' 501, 'DRIVER' 247, 'DISPATCHER' 11, 'FUEL_OPERATOR' 11, 'MECHANIC' 10, 'MEDIC' 6, 'HEAD_OF_OPERATIONS' 4, 'WORKSHOP_MASTER' 4, 'WAREHOUSE_OPERATOR' 3, 'TRANSPORT_DEPARTMENT_HEAD' 2, 'EXPLOITATION' 2, 'ADMIN' 2, 'PTO' 2, 'FUEL_ATTENDANT' 2, 'LOGISTICIAN' 1, 'SECURITY_OFFICER' 1, 'ANALYST' 1; ISHLATILMAGAN: ACCOUNTANT, OPERATIONS
    FOREIGN KEY (user_id) REFERENCES app_user(id),
    CHECK (role in ('ADMIN', 'LOGISTICIAN', 'DISPATCHER', 'DRIVER', 'REQUEST_INITIATOR', 'FUEL_OPERATOR', 'MEDIC', 'MECHANIC', 'WORKSHOP_MASTER', 'ANALYST', 'HEAD_OF_DEPARTMENT', 'ACCOUNTANT', 'SECURITY_OFFICER', 'WAREHOUSE_OPERATOR', 'HEAD_OF_OPERATIONS', 'EXPLOITATION', 'OPERATIONS', 'FUEL_ATTENDANT', 'TRANSPORT_DEPARTMENT_HEAD', 'PTO'))
);

-- TABLE: user_warehouse  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Foydalanuvchining qaysi omborga biriktirilganini ko'rsatadi (yoqilg'i operatori,
-- ombor xodimi uchun). Bitta foydalanuvchida bitta ombor.
-- (Ilgari `user_warehouse` deb atalardi — sxema ko'chirishda nomi o'zgargan.)
-- ---------------------------------------------------------------------
CREATE TABLE user_warehouse (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    user_id uuid NOT NULL,
    warehouse_id uuid NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: vehicle_accident  (satrlar: 0 — BO`SH)
-- ---------------------------------------------------------------------
-- Yo'l-transport hodisalari (avariyalar): hodisa raqami, turi (DRIVER_FAULT,
-- NATURAL_CAUSE, THIRD_PARTY_FAULT, OTHER), jiddiyligi (MINOR, MODERATE, SERIOUS,
-- CRITICAL), joyi va vaqti, jarohatlanganlar va halok bo'lganlar soni,
-- taxminiy va amaldagi ta'mirlash summasi, sug'urta da'vosi raqami.
-- TO'LOVNING TAQSIMLANISHI: insurance_paid_amount (sug'urta), driver_paid_amount
-- (haydovchi), factory_paid_amount (korxona).
-- status: REPORTED, UNDER_REVIEW, INSURANCE_PROCESSING, REPAIR_IN_PROGRESS,
-- RESOLVED, CLOSED, CANCELLED. Fayllari vehicle_accident_attachment orqali.
-- ---------------------------------------------------------------------
CREATE TABLE vehicle_accident (
    id uuid NOT NULL,
    accident_number varchar(32) NOT NULL,
    accident_type varchar(32) NOT NULL,  -- RUXSAT: 'DRIVER_FAULT', 'NATURAL_CAUSE', 'THIRD_PARTY_FAULT', 'OTHER'
    actual_repair_amount numeric(18,2),
    created_at timestamptz NOT NULL,
    created_by varchar(128),
    currency varchar(8),
    damage_description varchar(2000),
    description varchar(2000),
    driver_paid_amount numeric(18,2),
    estimated_damage_amount numeric(18,2),
    factory_paid_amount numeric(18,2),
    fatalities_count integer,
    injuries_count integer,
    insurance_claim_number varchar(128),
    insurance_paid_amount numeric(18,2),
    latitude numeric(10,7),
    location_name varchar(512),
    longitude numeric(10,7),
    occurred_at timestamptz NOT NULL,
    police_report_number varchar(128),
    repair_required boolean NOT NULL,
    reported_at timestamptz,
    resolution_notes varchar(2000),
    resolved_at timestamptz,
    severity varchar(32) NOT NULL,  -- RUXSAT: 'MINOR', 'MODERATE', 'SERIOUS', 'CRITICAL'
    status varchar(32) NOT NULL,  -- RUXSAT: 'REPORTED', 'UNDER_REVIEW', 'INSURANCE_PROCESSING', 'REPAIR_IN_PROGRESS', 'RESOLVED', 'CLOSED', 'CANCELLED'
    third_party_involved boolean NOT NULL,
    updated_at timestamptz NOT NULL,
    updated_by varchar(128),
    version bigint NOT NULL,
    driver_id uuid,
    trip_id uuid,
    vehicle_id uuid NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (driver_id) REFERENCES driver(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id),
    FOREIGN KEY (trip_id) REFERENCES trip(id),
    CHECK (accident_type in ('DRIVER_FAULT', 'NATURAL_CAUSE', 'THIRD_PARTY_FAULT', 'OTHER')),
    CHECK (severity in ('MINOR', 'MODERATE', 'SERIOUS', 'CRITICAL')),
    CHECK (status in ('REPORTED', 'UNDER_REVIEW', 'INSURANCE_PROCESSING', 'REPAIR_IN_PROGRESS', 'RESOLVED', 'CLOSED', 'CANCELLED'))
);

-- TABLE: vehicle_accident_attachment  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Avariya va yuklangan fayl (attachment) o'rtasidagi bog'lovchi jadval —
-- avariya rasmlari va hujjatlari.
-- ---------------------------------------------------------------------
CREATE TABLE vehicle_accident_attachment (
    id uuid NOT NULL,
    description varchar(1000),
    accident_id uuid NOT NULL,
    attachment_id uuid NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (attachment_id) REFERENCES attachment(id),
    FOREIGN KEY (accident_id) REFERENCES vehicle_accident(id)
);

-- TABLE: vehicle_assigned_drivers  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- MASHINA-HAYDOVCHI BIRIKTIRUVI (ko'p-ko'pga bog'lovchi jadval).
-- Faqat ikki ustun: vehicle_id, driver_id.
-- Bitta mashinaga bir nechta haydovchi biriktirilishi mumkin.
-- ASOSIY (bitta) haydovchi esa transport_vehicle.assigned_driver_id da.
-- ---------------------------------------------------------------------
CREATE TABLE vehicle_assigned_drivers (
    vehicle_id uuid NOT NULL,
    driver_id uuid,
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id)
);

-- TABLE: vehicle_document  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- MASHINA HUJJATLARI BO'YICHA ASOSIY JADVAL: sug'urta, ro'yxatdan o'tish
-- guvohnomasi, texnik ko'rik, ekologik sertifikat, ruxsatnoma, lizing shartnomasi.
-- Hujjat raqami, bergan organ (issuing_authority), berilgan sana (issued_at) va
-- AMAL QILISH MUDDATI (expiry_date).
-- MUDDATI TUGAYOTGAN HUJJATLAR expiry_date BO'YICHA OLINADI.
-- ---------------------------------------------------------------------
CREATE TABLE vehicle_document (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    created_by varchar(256) NOT NULL,
    document_number varchar(128) NOT NULL,
    document_type varchar(32) NOT NULL,  -- RUXSAT: 'INSURANCE', 'REGISTRATION', 'TECHNICAL_INSPECTION', 'EMISSION_CERTIFICATE', 'PERMIT', 'OTHER', 'REGISTRATION_CERTIFICATE', 'INSURANCE_POLICY', 'TRANSPORT_PERMIT', 'LEASE_CONTRACT'
    expiry_date date,
    issued_at date,
    issuing_authority varchar(256),
    notes varchar(512),
    vehicle_id uuid NOT NULL,
    attachment_id uuid,
    PRIMARY KEY (id),
    FOREIGN KEY (attachment_id) REFERENCES attachment(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id),
    CHECK (document_type in ('INSURANCE', 'REGISTRATION', 'TECHNICAL_INSPECTION', 'EMISSION_CERTIFICATE', 'PERMIT', 'OTHER', 'REGISTRATION_CERTIFICATE', 'INSURANCE_POLICY', 'TRANSPORT_PERMIT', 'LEASE_CONTRACT'))
);

-- TABLE: vehicle_fuel_sensor_installation  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Yoqilg'i sensorining mashinaga o'rnatilish tarixi: o'rnatilgan va olib tashlangan
-- vaqti, o'rnatish joyi, asosiy sensor ekanligi (primary_sensor).
-- removed_at bo'sh bo'lsa — sensor hozir o'rnatilgan holatda.
-- ---------------------------------------------------------------------
CREATE TABLE vehicle_fuel_sensor_installation (
    id uuid NOT NULL,
    installed_at timestamptz NOT NULL,
    installed_by varchar(256) NOT NULL,
    mounting_position varchar(64),
    primary_sensor boolean NOT NULL,
    removed_at timestamptz,
    removed_by varchar(256),
    sensor_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: vehicle_gps  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Mashina va GPS qurilmasi o'rtasidagi bog'lanish (device_id, unique_id).
-- XOM GPS YOZUVLARI (position_log) MASHINAGA SHU JADVAL ORQALI BOG'LANADI —
-- position_log.device_id = vehicle_gps.device_id.
-- ---------------------------------------------------------------------
CREATE TABLE vehicle_gps (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    device_id bigint,
    driver_id uuid,
    unique_id varchar(64) NOT NULL,
    updated_at timestamptz NOT NULL,
    vehicle_id uuid NOT NULL,
    active boolean NOT NULL,
    created_operation_id uuid,
    managed_by_at_il boolean NOT NULL,
    provider_connection varchar(32) NOT NULL,
    version bigint NOT NULL,
    unbound_at timestamptz,
    verified_from timestamptz,
    PRIMARY KEY (id)
);

-- TABLE: vehicle_part  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Mashina ehtiyot qismlari: shina, akkumulyator, moy va havo filtri, tormoz
-- kolodkasi. O'rnatilgan sana va probeg, kutilgan xizmat muddati (expected_life_km,
-- expected_life_days), narxi.
-- status: INSTALLED, IN_STOCK, REPLACED, WORN.
-- ALMASHTIRISH VAQTI KELGAN QISMLAR o'rnatilgan probeg + expected_life_km ni
-- mashinaning hozirgi probegi bilan solishtirib topiladi.
-- ---------------------------------------------------------------------
CREATE TABLE vehicle_part (
    id uuid NOT NULL,
    category varchar(16) NOT NULL,  -- RUXSAT: 'ENGINE', 'TIRE', 'BATTERY', 'OIL_FILTER', 'AIR_FILTER', 'BRAKE_PAD', 'OTHER'; BAZADA: 'TIRE' 634; ISHLATILMAGAN: ENGINE, BATTERY, OIL_FILTER, AIR_FILTER, BRAKE_PAD, OTHER
    cost numeric(14,2),
    created_at timestamptz NOT NULL,
    currency varchar(8),
    current_odometer_km numeric(14,3),
    expected_life_days integer,
    expected_life_km numeric(14,3),
    installed_at date,
    installed_at_km numeric(14,3),
    name varchar(255) NOT NULL,
    notes varchar(2000),
    part_number varchar(128),
    status varchar(16) NOT NULL,  -- RUXSAT: 'INSTALLED', 'IN_STOCK', 'REPLACED', 'WORN', 'IN_REPAIR', 'REPAIRED', 'REFURBISHED', 'REUSED', 'UNREPAIRABLE', 'IN_WRITE_OFF', 'WRITTEN_OFF', 'DESTROYED', 'RECYCLED'; BAZADA: 'INSTALLED' 728; ISHLATILMAGAN: IN_STOCK, REPLACED, WORN, IN_REPAIR, REPAIRED, REFURBISHED, REUSED, UNREPAIRABLE, IN_WRITE_OFF, WRITTEN_OFF, DESTROYED, RECYCLED
    updated_at timestamptz NOT NULL,
    vehicle_id uuid,
    version bigint NOT NULL,
    assessed_at timestamptz,
    assessed_by_id uuid,
    assessed_by_name varchar(256),
    removal_branch_id uuid,
    removal_defect varchar(2000),
    removal_repair_number varchar(64),
    removal_vehicle_label varchar(255),
    removed_at date,
    removed_at_km numeric(14,3),
    removed_by_id uuid,
    removed_by_name varchar(256),
    repair_order_id uuid,
    serial_number varchar(128),
    series varchar(128),
    unrepairable_conclusion varchar(2000),
    write_off_act_id uuid,
    current_engine_hours numeric(14,3),
    expected_life_engine_hours numeric(14,3),
    expected_life_months integer,
    installed_at_engine_hours numeric(14,3),
    primary_battery boolean NOT NULL,
    replace_at_percent numeric(5,2),
    service_rule_id uuid,
    service_rule_name varchar(255),
    tire_size varchar(64),
    tracking_enabled boolean NOT NULL,
    warning_at_percent numeric(5,2),
    accepted_to_warehouse_at timestamptz,
    accepted_to_warehouse_by_id uuid,
    accepted_to_warehouse_by_name varchar(256),
    refurbished_from_part_id uuid,
    refurbished_stock_id uuid,
    repair_completion_notes varchar(2000),
    repaired_at timestamptz,
    repaired_by_id uuid,
    repaired_by_name varchar(256),
    PRIMARY KEY (id),
    CHECK (category in ('ENGINE', 'TIRE', 'BATTERY', 'OIL_FILTER', 'AIR_FILTER', 'BRAKE_PAD', 'OTHER')),
    CHECK (status in ('INSTALLED', 'IN_STOCK', 'REPLACED', 'WORN', 'IN_REPAIR', 'REPAIRED', 'REFURBISHED', 'REUSED', 'UNREPAIRABLE', 'IN_WRITE_OFF', 'WRITTEN_OFF', 'DESTROYED', 'RECYCLED'))
);

-- TABLE: vehicle_photo  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Mashina rasmlari va ular qaysi tomondan olingani (FRONT, REAR, LEFT, RIGHT,
-- CABIN, VIN). Faylning o'zi attachment jadvalida.
-- ---------------------------------------------------------------------
CREATE TABLE vehicle_photo (
    id uuid NOT NULL,
    photo_type varchar(64) NOT NULL,  -- RUXSAT: 'FRONT', 'REAR', 'LEFT', 'RIGHT', 'CABIN', 'VIN'; BAZADA: 'FRONT' 2; ISHLATILMAGAN: REAR, LEFT, RIGHT, CABIN, VIN
    uploaded_at timestamptz NOT NULL,
    attachment_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (attachment_id) REFERENCES attachment(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id),
    CHECK (photo_type in ('FRONT', 'REAR', 'LEFT', 'RIGHT', 'CABIN', 'VIN'))
);

-- TABLE: vehicle_plate_history  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Mashina davlat raqamining o'zgarish tarixi. is_current=true bo'lgan qator —
-- hozirgi raqam (u transport_vehicle.plate_number bilan bir xil bo'lishi kerak).
-- ESKI RAQAM BO'YICHA MASHINA QIDIRILSA SHU JADVALDAN OLINADI.
-- ---------------------------------------------------------------------
CREATE TABLE vehicle_plate_history (
    id uuid NOT NULL,
    assigned_at timestamptz NOT NULL,
    changed_by varchar(256),
    is_current boolean NOT NULL,
    plate_number varchar(32) NOT NULL,
    removed_at timestamptz,
    vehicle_id uuid NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id)
);

-- TABLE: vehicle_reference_data_fuel_type  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Mashina va reference_data katalogidagi yoqilg'i turi o'rtasidagi bog'lovchi
-- jadval (FUEL_TYPES katalogi bo'yicha), 118 yozuv.
-- YOQILG'I TURI NOMI `reference_data` DA:
-- FROM vehicle_reference_data_fuel_type vr
-- JOIN reference_data rd ON rd.id = vr.reference_data__id
-- JOIN transport_vehicle v ON v.id = vr.vehicle_id
-- `fuel_type` JADVALIGA ULANMANG — u BO'SH (0 qator, 02.09.2026).
-- Unga ulangan query nol qator qaytaradi va "ma'lumot yo'q" degan
-- NOTO'G'RI javob beriladi.
-- ---------------------------------------------------------------------
CREATE TABLE vehicle_reference_data_fuel_type (
    vehicle_id uuid NOT NULL,
    reference_data__id uuid NOT NULL,
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id),
    FOREIGN KEY (reference_data__id) REFERENCES reference_data(id)
);

-- TABLE: vehicle_repair  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Ta'mirlash ishlari: qaysi tugun (ENGINE, BRAKES, TIRES, BATTERY, ELECTRICAL,
-- CHASSIS), ustuvorligi, taxminiy narxi, bekor turish soati (downtime_hours).
-- status: OPEN, IN_PROGRESS, WAITING_PARTS, COMPLETED, CANCELLED.
-- blocks_release=true bo'lsa — MASHINA REYSGA CHIQARILMAYDI.
-- ---------------------------------------------------------------------
CREATE TABLE vehicle_repair (
    id uuid NOT NULL,
    blocks_release boolean NOT NULL,
    component_category varchar(64) NOT NULL,  -- RUXSAT: 'ENGINE', 'BRAKES', 'TIRES', 'BATTERY', 'ELECTRICAL', 'CHASSIS', 'OTHER'; BAZADA: 'BRAKES' 8, 'OTHER' 5, 'TIRES' 4; ISHLATILMAGAN: ENGINE, BATTERY, ELECTRICAL, CHASSIS
    created_at timestamptz NOT NULL,
    description varchar(2000),
    downtime_hours numeric(14,3),
    estimated_cost numeric(14,2),
    opened_at timestamptz NOT NULL,
    opened_by varchar(255) NOT NULL,
    priority varchar(64) NOT NULL,  -- RUXSAT: 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'; BAZADA: 'HIGH' 18, 'MEDIUM' 2; ISHLATILMAGAN: LOW, CRITICAL
    status varchar(64) NOT NULL,  -- RUXSAT: 'CREATED', 'PENDING_ARM_APPROVAL', 'APPROVED_BY_ARM', 'ARM_DIAGNOSIS', 'WAITING_PARTS_APPROVAL', 'PARTS_APPROVED', 'PARTS_ISSUED', 'REPAIR_IN_PROGRESS', 'COMPLETED_BY_ARM', 'PENDING_ARM_CLOSURE', 'ARM_CLOSED', 'PENDING_FINAL_MECHANIC_INSPECTION', 'FINAL_INSPECTION_PASSED', 'FINAL_INSPECTION_FAILED', 'CLOSED', 'REJECTED', 'NEW', 'DIAGNOSING', 'WAITING_PARTS', 'REPAIRING', 'REPAIRED', 'NOT_REPAIRED', 'COMPLETED', 'CANCELLED', 'OPEN', 'IN_PROGRESS'; BAZADA: 'CLOSED' 16, 'REPAIR_IN_PROGRESS' 2, 'CANCELLED' 1, 'REJECTED' 1; ISHLATILMAGAN: CREATED, PENDING_ARM_APPROVAL, APPROVED_BY_ARM, ARM_DIAGNOSIS, WAITING_PARTS_APPROVAL, PARTS_APPROVED, PARTS_ISSUED, COMPLETED_BY_ARM, PENDING_ARM_CLOSURE, ARM_CLOSED, PENDING_FINAL_MECHANIC_INSPECTION, FINAL_INSPECTION_PASSED, FINAL_INSPECTION_FAILED, NEW, DIAGNOSING, WAITING_PARTS, REPAIRING, REPAIRED, NOT_REPAIRED, COMPLETED, OPEN, IN_PROGRESS
    title varchar(255) NOT NULL,
    updated_at timestamptz NOT NULL,
    vehicle_id uuid NOT NULL,
    trip_id uuid,
    waybill_id uuid,
    repair_location_id uuid,
    diagnosis varchar(2000),
    required_parts varchar(2000),
    work_performed varchar(2000),
    actual_downtime_hours numeric(14,3),
    decision varchar(32) NOT NULL,  -- RUXSAT: 'UNDECIDED', 'CONTINUE_SAME_WAYBILL', 'REPLACE_VEHICLE', 'NEW_WAYBILL', 'CANCEL_TRIP'
    replacement_vehicle_id uuid,
    dispatcher_comment varchar(2000),
    decision_at timestamptz,
    decision_by varchar(255),
    completed_at timestamptz,
    completed_by varchar(255),
    arm_diagnosed_at timestamptz,
    arm_diagnosed_by varchar(255),
    arm_diagnosis varchar(2000),
    branch_id uuid,
    defect_area varchar(255),
    defect_reason varchar(2000),
    detected_at timestamptz,
    final_conclusion varchar(2000),
    initial_diagnosis varchar(2000),
    inspection_context varchar(64),
    mechanic_comment varchar(2000),
    mechanic_recheck_decision varchar(32),
    mechanic_recheck_notes varchar(2000),
    mechanic_rechecked_at timestamptz,
    mechanic_rechecked_by varchar(255),
    received_by_arm_at timestamptz,
    repair_number varchar(64),
    repaired_at timestamptz,
    repaired_by varchar(255),
    rework_count integer NOT NULL,
    sent_to_arm_at timestamptz,
    technical_inspection_id uuid,
    technical_suspended_at timestamptz,
    unable_to_repair_at timestamptz,
    unable_to_repair_by varchar(255),
    unable_to_repair_reason varchar(2000),
    arm_approved_at timestamptz,
    arm_approved_by_id uuid,
    arm_approved_by_name varchar(255),
    chief_mechanic_completed_at timestamptz,
    chief_mechanic_diagnosed_at timestamptz,
    chief_mechanic_id uuid,
    chief_mechanic_name varchar(255),
    driver_id uuid,
    driver_name varchar(255),
    estimated_completion_time timestamptz,
    estimated_start_time timestamptz,
    final_arm_approved_at timestamptz,
    final_arm_approved_by_id uuid,
    final_arm_approved_by_name varchar(255),
    rejection_reason varchar(2000),
    signature_data varchar(4000),
    signature_id varchar(255),
    signed_at timestamptz,
    signed_by varchar(255),
    version bigint NOT NULL,
    PRIMARY KEY (id),
    CHECK (component_category in ('ENGINE', 'BRAKES', 'TIRES', 'BATTERY', 'ELECTRICAL', 'CHASSIS', 'OTHER')),
    CHECK (decision in ('UNDECIDED', 'CONTINUE_SAME_WAYBILL', 'REPLACE_VEHICLE', 'NEW_WAYBILL', 'CANCEL_TRIP')),
    CHECK (((inspection_context is null) or ((inspection_context) = any (array[('pre_trip'), ('in_trip'), ('post_trip'), ('direct')])))),
    CHECK (((mechanic_recheck_decision is null) or ((mechanic_recheck_decision) = any ((array['passed', 'failed', 'not_performed'])[])))),
    CHECK (priority in ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    CHECK (status in ('CREATED', 'PENDING_ARM_APPROVAL', 'APPROVED_BY_ARM', 'ARM_DIAGNOSIS', 'WAITING_PARTS_APPROVAL', 'PARTS_APPROVED', 'PARTS_ISSUED', 'REPAIR_IN_PROGRESS', 'COMPLETED_BY_ARM', 'PENDING_ARM_CLOSURE', 'ARM_CLOSED', 'PENDING_FINAL_MECHANIC_INSPECTION', 'FINAL_INSPECTION_PASSED', 'FINAL_INSPECTION_FAILED', 'CLOSED', 'REJECTED', 'NEW', 'DIAGNOSING', 'WAITING_PARTS', 'REPAIRING', 'REPAIRED', 'NOT_REPAIRED', 'COMPLETED', 'CANCELLED', 'OPEN', 'IN_PROGRESS'))
);

-- TABLE: vehicle_repair_team_members  (satrlar: noma'lum)
CREATE TABLE vehicle_repair_team_members (
    repair_id uuid NOT NULL,
    assigned_at timestamptz,
    employee_id uuid,
    employee_name varchar(255),
    id varchar(255),
    worker_specialty varchar(255),
    FOREIGN KEY (repair_id) REFERENCES vehicle_repair(id)
);

-- TABLE: vehicle_repair_work_items  (satrlar: noma'lum)
CREATE TABLE vehicle_repair_work_items (
    repair_id uuid NOT NULL,
    category varchar(255),
    completed boolean,
    description varchar(255),
    id varchar(255),
    FOREIGN KEY (repair_id) REFERENCES vehicle_repair(id)
);

-- TABLE: vehicle_status_history  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Mashina holatining o'zgarish tarixi: oldingi va yangi status, kim o'zgartirgani,
-- sababi va vaqti.
-- MASHINA QANCHA VAQT IN_MAINTENANCE YOKI BLOCKED HOLATDA TURGANI SHU JADVALDAN
-- hisoblanadi.
-- ---------------------------------------------------------------------
CREATE TABLE vehicle_status_history (
    id uuid NOT NULL,
    changed_at timestamptz NOT NULL,
    changed_by varchar(256) NOT NULL,
    new_status varchar(32) NOT NULL,  -- RUXSAT: 'ACTIVE', 'RESERVED', 'IN_OPERATION', 'IN_MAINTENANCE', 'BLOCKED', 'DECOMMISSIONED'; BAZADA: 'ACTIVE' 21, 'BLOCKED' 3, 'IN_MAINTENANCE' 1; ISHLATILMAGAN: RESERVED, IN_OPERATION, DECOMMISSIONED
    previous_status varchar(32),  -- RUXSAT: 'ACTIVE', 'RESERVED', 'IN_OPERATION', 'IN_MAINTENANCE', 'BLOCKED', 'DECOMMISSIONED'; BAZADA: 'IN_MAINTENANCE' 2, 'BLOCKED' 2, 'ACTIVE' 1; ISHLATILMAGAN: RESERVED, IN_OPERATION, DECOMMISSIONED
    reason varchar(512),
    vehicle_id uuid NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id),
    CHECK (new_status in ('ACTIVE', 'RESERVED', 'IN_OPERATION', 'IN_MAINTENANCE', 'BLOCKED', 'DECOMMISSIONED')),
    CHECK (previous_status in ('ACTIVE', 'RESERVED', 'IN_OPERATION', 'IN_MAINTENANCE', 'BLOCKED', 'DECOMMISSIONED'))
);

-- TABLE: vehicle_technical_inspection  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Reysdan oldingi (PRE_TRIP) va reysdan keyingi (POST_TRIP) texnik ko'rik.
-- Natija: FIT (yaroqli), LIMITED (cheklangan), BLOCKED (bloklangan). probeg,
-- ko'rikni o'tkazgan shaxs, izohlar. Rasmlar ALOHIDA vehicle_technical_inspection_photo jadvalida.
-- Rasmlari vehicle_technical_inspection_photo jadvalida ham.
-- ---------------------------------------------------------------------
CREATE TABLE vehicle_technical_inspection (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    inspected_at timestamptz NOT NULL,
    inspected_by varchar(255) NOT NULL,
    inspection_type varchar(32) NOT NULL,  -- RUXSAT: 'PRE_TRIP', 'POST_TRIP'; BAZADA: 'PRE_TRIP' 4073, 'POST_TRIP' 3671
    notes varchar(2000),
    probeg bigint,
    status varchar(32) NOT NULL,  -- RUXSAT: 'FIT', 'LIMITED', 'BLOCKED'; BAZADA: 'FIT' 7579; ISHLATILMAGAN: LIMITED, BLOCKED
    to_inspected_at timestamptz,
    trip_id uuid,
    updated_at timestamptz NOT NULL,
    vehicle_id uuid NOT NULL,
    fuel_at_inspection_liters numeric(12,3),
    fuel_consumed_liters numeric(12,3),
    waybill_id uuid,
    moto_hours numeric(14,3),
    calculation_mode varchar(32),
    pre_trip_motohours numeric(10,2),
    post_trip_motohours numeric(10,2),
    motohours_worked numeric(10,2),
    motohours_rate_norm numeric(6,2),
    crane_capacity_tons numeric(5,2),
    recommended_fuel_liters numeric(12,3),
    ev_mileage numeric(14,3),
    hev_mileage numeric(14,3),
    initial_ev_mileage numeric(14,3),
    final_ev_mileage numeric(14,3),
    initial_hev_mileage numeric(14,3),
    final_hev_mileage numeric(14,3),
    PRIMARY KEY (id),
    CHECK (inspection_type in ('PRE_TRIP', 'POST_TRIP')),
    CHECK (status in ('FIT', 'LIMITED', 'BLOCKED'))
);

-- TABLE: vehicle_technical_inspection_correction  (satrlar: noma'lum)
CREATE TABLE vehicle_technical_inspection_correction (
    id uuid NOT NULL,
    inspection_id uuid NOT NULL,
    version bigint NOT NULL,
    actor_id uuid NOT NULL,
    actor_name text NOT NULL,
    recorded_at timestamptz NOT NULL,
    transaction_id bigint NOT NULL,
    reason text NOT NULL,
    before_json jsonb NOT NULL,  -- [JSON matn]
    after_json jsonb NOT NULL,  -- [JSON matn]
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (inspection_id) REFERENCES vehicle_technical_inspection(id),
    CHECK ((version > 0))
);

-- TABLE: vehicle_technical_inspection_photo  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Texnik ko'rik rasmlari: mashina (VEHICLE) yoki taxometr/probeg (TACHOMETER)
-- rasmi. Faylning o'zi attachment jadvalida.
-- ---------------------------------------------------------------------
CREATE TABLE vehicle_technical_inspection_photo (
    id uuid NOT NULL,
    photo_type varchar(32) NOT NULL,  -- RUXSAT: 'VEHICLE', 'TACHOMETER'; BAZADA: 'VEHICLE' 2109, 'TACHOMETER' 116
    uploaded_at timestamptz NOT NULL,
    attachment_id uuid NOT NULL,
    inspection_id uuid NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (attachment_id) REFERENCES attachment(id),
    FOREIGN KEY (inspection_id) REFERENCES vehicle_technical_inspection(id),
    CHECK (photo_type in ('VEHICLE', 'TACHOMETER'))
);

-- TABLE: vehicle_telemetry_state  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- MASHINANING HOZIRGI (OXIRGI) HOLATI — bitta mashinaga bitta qator
-- (vehicle_id birlamchi kalit). Oxirgi koordinata, tezlik, probeg, yoqilg'i sathi,
-- dvigatel holati, bekor turish (idle_time_seconds) va harakat vaqti, hozirgi reys
-- va marshrut, marshrutdan chetlanish (deviation_active) va to'xtash (stop_active)
-- belgilari.
-- MASHINA HOZIR QAYERDA / QANDAY HOLATDA SO'RALSA SHU JADVALDAN OLINADI —
-- katta telematics_event jadvalini skanerlash SHART EMAS.
-- ---------------------------------------------------------------------
CREATE TABLE vehicle_telemetry_state (
    vehicle_id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    current_route_id uuid,
    current_trip_id uuid,
    deviation_active boolean NOT NULL,
    deviation_threshold_meters integer,
    device_id varchar(128),
    idle_time_seconds bigint NOT NULL,
    last_engine_on boolean,
    last_event_at timestamptz,
    last_fuel_level numeric(10,3),
    last_heading numeric(10,3),
    last_latitude numeric(10,7),
    last_longitude numeric(10,7),
    last_odometer_km numeric(14,3),
    last_speed_kph numeric(10,3),
    last_speed_violation_at timestamptz,
    moving_time_seconds bigint NOT NULL,
    route_points_json text,  -- [JSON matn]
    stop_active boolean NOT NULL,
    stop_candidate_since timestamptz,
    trip_actual_distance_km numeric(14,3) NOT NULL,
    updated_at timestamptz NOT NULL,
    version bigint NOT NULL,
    PRIMARY KEY (vehicle_id)
);

-- TABLE: vehicle_tire_norm  (satrlar: noma'lum)
CREATE TABLE vehicle_tire_norm (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    expected_life_days integer,
    expected_life_engine_hours numeric(14,3),
    expected_life_km numeric(14,3),
    expected_life_months integer,
    source varchar(16) NOT NULL,  -- RUXSAT: 'REFERENCE', 'MANUAL'
    tire_size varchar(64) NOT NULL,
    updated_at timestamptz NOT NULL,
    vehicle_id uuid NOT NULL,
    version bigint NOT NULL,
    PRIMARY KEY (id),
    CHECK (source in ('REFERENCE', 'MANUAL'))
);

-- TABLE: vehicle_usage_reading  (satrlar: noma'lum)
CREATE TABLE vehicle_usage_reading (
    id uuid NOT NULL,
    absolute_value numeric(20,3) NOT NULL,
    branch_id uuid,
    counter varchar(32) NOT NULL,  -- RUXSAT: 'ODOMETER_KM', 'ENGINE_HOURS'; BAZADA: 'ODOMETER_KM' 1256, 'ENGINE_HOURS' 70
    counter_offset numeric(20,3) NOT NULL,
    epoch bigint NOT NULL,
    event_id varchar(200) NOT NULL,
    event_type varchar(32) NOT NULL,  -- RUXSAT: 'READING', 'CORRECTION', 'REPLACEMENT'
    lifetime_value numeric(20,3) NOT NULL,
    observed_at timestamptz NOT NULL,
    quality varchar(32) NOT NULL,  -- RUXSAT: 'CONFIRMED', 'QUARANTINED'; BAZADA: 'CONFIRMED' 1260, 'QUARANTINED' 66
    reason varchar(2000),
    received_at timestamptz NOT NULL,
    recorded_by varchar(255) NOT NULL,
    reference_reading_id uuid,
    revision bigint NOT NULL,
    source varchar(100) NOT NULL,
    vehicle_id uuid NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (reference_reading_id) REFERENCES vehicle_usage_reading(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id),
    CHECK (counter in ('ODOMETER_KM', 'ENGINE_HOURS')),
    CHECK (event_type in ('READING', 'CORRECTION', 'REPLACEMENT')),
    CHECK (quality in ('CONFIRMED', 'QUARANTINED'))
);

-- TABLE: waiting_claim  (satrlar: noma'lum)
CREATE TABLE waiting_claim (
    id uuid NOT NULL,
    trip_id uuid NOT NULL,
    contract_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (trip_id) REFERENCES trip(id)
);

-- TABLE: waiting_claim_event  (satrlar: noma'lum)
CREATE TABLE waiting_claim_event (
    operation_id uuid NOT NULL,
    claim_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    action text NOT NULL,
    state text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    snapshot jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (claim_id) REFERENCES waiting_claim(id),
    CHECK ((revision > 0))
);

-- TABLE: waiting_closed_operation  (satrlar: noma'lum)
CREATE TABLE waiting_closed_operation (
    operation_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    claim_id uuid,
    kind text NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    reason text NOT NULL,
    closed_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id)
);

-- TABLE: waiting_contract_policy  (satrlar: noma'lum)
CREATE TABLE waiting_contract_policy (
    operation_id uuid NOT NULL,
    contract_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    carrier_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    revision bigint NOT NULL,
    original jsonb NOT NULL,  -- [JSON matn]
    document jsonb NOT NULL,  -- [JSON matn]
    hash text NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (branch_id) REFERENCES reference_data(id),
    FOREIGN KEY (carrier_id) REFERENCES carrier(id),
    CHECK ((revision > 0))
);

-- TABLE: waybill  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- YO'L VARAQALARI (PUTEVOY LIST) — REYSNING RASMIY HUJJATI VA YOQILG'I HISOBI SHU
-- JADVALDAN OLINADI. Varaqa raqami (waybill_number), berilgan sana, reja va
-- amaldagi jo'nash/qaytish vaqti, spidometr boshi va oxiri (odometer_start_km,
-- odometer_end_km), yuk tavsifi va og'irligi TONNADA.
-- YOQILG'I: berilgan (fuel_issued_liters), jo'nashda bakdagi
-- (fuel_at_departure_liters), qaytishda (fuel_at_return_liters), sarflangan
-- (fuel_consumed_liters) va norma bo'yicha (fuel_norm_liters).
-- NORMADAN ORTIQ SARF fuel_consumed_liters va fuel_norm_liters ni solishtirib
-- topiladi.
-- KO'RIKLAR: reysdan oldin va keyin tibbiy (pre_med_*, post_med_*) va mexanik
-- (pre_mech_*, post_mech_*) ko'rik natijalari — PASSED, FAILED, NOT_PERFORMED.
-- status: DRAFT, ISSUED, IN_USE, RETURNED, CLOSED, CANCELLED.
-- generated_document_id — varaqa asosida yaratilgan transport_document.
-- ---------------------------------------------------------------------
CREATE TABLE waybill (
    id uuid NOT NULL,
    actual_departure_at timestamptz,
    actual_return_at timestamptz,
    attachment_id uuid,
    cancellation_reason varchar(1000),
    cargo_description varchar(1000),
    cargo_weight_tons numeric(12,3),
    closed_at timestamptz,
    closed_by varchar(128),
    comment text,
    created_at timestamptz NOT NULL,
    created_by varchar(128) NOT NULL,
    driver_id uuid NOT NULL,
    driver_talon_number varchar(64),
    emergency_dispatch boolean NOT NULL,
    emergency_reason varchar(1000),
    fuel_at_departure_liters numeric(12,3),
    fuel_at_return_liters numeric(12,3),
    fuel_consumed_liters numeric(12,3),
    fuel_issued_liters numeric(12,3),
    fuel_norm_liters numeric(12,3),
    generated_document_id uuid,
    issue_date date NOT NULL,
    issued_at timestamptz,
    issued_by varchar(128),
    kind varchar(255),
    odometer_end_km numeric(14,3),
    odometer_start_km numeric(14,3),
    planned_departure_at timestamptz NOT NULL,
    planned_return_at timestamptz NOT NULL,
    post_mech_inspection_id uuid,
    post_mech_notes varchar(500),
    post_mech_performed_at timestamptz,
    post_mech_performed_by varchar(128),
    post_mech_result varchar(16),  -- RUXSAT: 'PASSED', 'FAILED', 'NOT_PERFORMED'; BAZADA: 'PASSED' 3288; ISHLATILMAGAN: FAILED, NOT_PERFORMED
    post_med_inspection_id uuid,
    post_med_notes varchar(500),
    post_med_performed_at timestamptz,
    post_med_performed_by varchar(128),
    post_med_result varchar(16),  -- RUXSAT: 'PASSED', 'FAILED', 'NOT_PERFORMED'
    pre_mech_inspection_id uuid,
    pre_mech_notes varchar(500),
    pre_mech_performed_at timestamptz,
    pre_mech_performed_by varchar(128),
    pre_mech_result varchar(16),  -- RUXSAT: 'PASSED', 'FAILED', 'NOT_PERFORMED'; BAZADA: 'PASSED' 3889; ISHLATILMAGAN: FAILED, NOT_PERFORMED
    pre_med_inspection_id uuid,
    pre_med_notes varchar(500),
    pre_med_performed_at timestamptz,
    pre_med_performed_by varchar(128),
    pre_med_result varchar(16),  -- RUXSAT: 'PASSED', 'FAILED', 'NOT_PERFORMED'; BAZADA: 'PASSED' 3765; ISHLATILMAGAN: FAILED, NOT_PERFORMED
    ref_id uuid,
    ref_type varchar(255),
    route_id uuid,
    status varchar(16) NOT NULL,  -- RUXSAT: 'DRAFT', 'ISSUED', 'IN_USE', 'RETURNED', 'CLOSED', 'CANCELLED'; BAZADA: 'CLOSED' 2765, 'RETURNED' 638, 'CANCELLED' 398, 'DRAFT' 326, 'IN_USE' 195, 'ISSUED' 97
    trailer_id uuid,
    transport_request_id uuid,
    trip_id uuid,
    updated_at timestamptz NOT NULL,
    updated_by varchar(128) NOT NULL,
    vehicle_id uuid NOT NULL,
    version bigint NOT NULL,
    waybill_number varchar(64) NOT NULL,
    waybill_type varchar(24) NOT NULL,  -- RUXSAT: 'LOCAL', 'LONG_HAUL', 'CRANE'; BAZADA: 'LOCAL' 4015, 'LONG_HAUL' 256, 'CRANE' 148
    branch_id uuid,
    moto_hours_end numeric(14,3),
    moto_hours_start numeric(14,3),
    attendant_notes varchar(500),
    fuel_attendant_id uuid,
    fuel_attendant_name varchar(128),
    fuel_recommendation varchar(128),
    fuel_type varchar(64),
    fueled_at timestamptz,
    fuel_calculated_by_norm numeric(12,3),
    fuel_rate_norm numeric(12,3),
    taksirovka_calculated_at timestamptz,
    taksirovka_calculated_by varchar(128),
    taksirovka_formula varchar(255),
    outbound_km numeric(10,2),
    outbound_tons numeric(10,2),
    inbound_km numeric(10,2),
    inbound_tons numeric(10,2),
    cargo_ton_km numeric(14,3),
    calculation_mode varchar(32),
    pre_trip_motohours numeric(10,2),
    post_trip_motohours numeric(10,2),
    motohours_worked numeric(10,2),
    motohours_rate_norm numeric(6,2),
    crane_capacity_tons numeric(5,2),
    duty_hours numeric(8,2),
    norm_source varchar(32),
    passenger_count integer,
    customer_department_id uuid,
    customer_department varchar(256),
    fuel_warehouse_id uuid,
    fuel_warehouse_name varchar(256),
    is_shift boolean NOT NULL,
    work_mode varchar(64),
    freight_recorded_at timestamptz,
    ev_mileage_start numeric(14,3),
    ev_mileage_end numeric(14,3),
    hev_mileage_start numeric(14,3),
    hev_mileage_end numeric(14,3),
    initial_ev_mileage numeric(14,3),
    final_ev_mileage numeric(14,3),
    initial_hev_mileage numeric(14,3),
    final_hev_mileage numeric(14,3),
    fuel_norm_rate numeric(10,2),
    fuel_start numeric(12,3),
    fuel_given numeric(12,3),
    fuel_end numeric(12,3),
    actual_fuel numeric(12,3),
    norm_fuel numeric(12,3),
    economy_fuel numeric(12,3),
    excess_fuel numeric(12,3),
    PRIMARY KEY (id),
    CHECK (post_mech_result in ('PASSED', 'FAILED', 'NOT_PERFORMED')),
    CHECK (post_med_result in ('PASSED', 'FAILED', 'NOT_PERFORMED')),
    CHECK (pre_mech_result in ('PASSED', 'FAILED', 'NOT_PERFORMED')),
    CHECK (pre_med_result in ('PASSED', 'FAILED', 'NOT_PERFORMED')),
    CHECK (status in ('DRAFT', 'ISSUED', 'IN_USE', 'RETURNED', 'CLOSED', 'CANCELLED')),
    CHECK (waybill_type in ('LOCAL', 'LONG_HAUL', 'CRANE'))
);

-- TABLE: waybill_companion  (satrlar: noma'lum)
CREATE TABLE waybill_companion (
    waybill_id uuid NOT NULL,
    full_name varchar(256) NOT NULL,
    sequence_number integer NOT NULL,
    user_id uuid,
    department_id uuid,
    department_name varchar(500),
    position varchar(128),
    phone varchar(32),
    FOREIGN KEY (waybill_id) REFERENCES waybill(id),
    CHECK (((user_id is not null) or ((department_id is not null) and (nullif(btrim((department_name)), '') is not null) and (nullif(btrim(("position")), '') is not null) and (nullif(btrim((full_name)), '') is not null))))
);

-- TABLE: waybill_customer_department  (satrlar: noma'lum)
CREATE TABLE waybill_customer_department (
    id uuid NOT NULL,
    department_id uuid,
    department_name varchar(256),
    manager_name varchar(256),
    sequence_number integer NOT NULL,
    waybill_id uuid NOT NULL,
    PRIMARY KEY (id)
);

-- TABLE: waybill_document  (satrlar: noma'lum)
CREATE TABLE waybill_document (
    waybill_id uuid NOT NULL,
    attachment_id uuid,
    comment varchar(1000),
    document_date date,
    document_number varchar(128),
    document_type varchar(32) NOT NULL,  -- RUXSAT: 'WAYBILL', 'TTN', 'TRAVEL_PERMISSION', 'SERVICE_MEMO', 'WAREHOUSE_DOCUMENT', 'INVOICE', 'OTHER'
    FOREIGN KEY (waybill_id) REFERENCES waybill(id),
    CHECK (document_type in ('WAYBILL', 'TTN', 'TRAVEL_PERMISSION', 'SERVICE_MEMO', 'WAREHOUSE_DOCUMENT', 'INVOICE', 'OTHER'))
);

-- TABLE: waybill_fueling  (satrlar: noma'lum)
CREATE TABLE waybill_fueling (
    waybill_id uuid NOT NULL,
    fueling_id uuid NOT NULL,
    occurred_at timestamptz,
    quantity numeric(14,3) NOT NULL,
    fuel_type varchar(64),
    warehouse_id uuid,
    external_station boolean,
    attendant varchar(256),
    attendant_id uuid,
    notes varchar(500),
    recorded_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (waybill_id, fueling_id),
    FOREIGN KEY (waybill_id) REFERENCES waybill(id),
    CHECK (((external_station is distinct from true) or (warehouse_id is null))),
    CHECK ((quantity >= (0)))
);

-- TABLE: waybill_numbering  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- Yo'l varaqasi RAQAMLARINI berish hisoblagichi: varaqa turi bo'yicha
-- oxirgi berilgan va keyingi raqam, boshlang'ich raqam va raqam uzunligi.
-- Bu sozlama jadvali — varaqalarning O'ZI waybill da.
-- ---------------------------------------------------------------------
CREATE TABLE waybill_numbering (
    id uuid NOT NULL,
    business_date date NOT NULL,
    comment varchar(500),
    created_at timestamptz NOT NULL,
    created_by varchar(200) NOT NULL,
    last_issued_number varchar(32),
    next_number bigint NOT NULL,
    number_width integer NOT NULL,
    starting_number bigint NOT NULL,
    updated_at timestamptz NOT NULL,
    version bigint NOT NULL,
    waybill_type varchar(32) NOT NULL,  -- RUXSAT: 'LOCAL', 'LONG_HAUL', 'CRANE'; BAZADA: 'LOCAL' 80, 'CRANE' 44, 'LONG_HAUL' 41
    PRIMARY KEY (id),
    CHECK (waybill_type in ('LOCAL', 'LONG_HAUL', 'CRANE'))
);

-- TABLE: waybill_task  (satrlar: noma'lum)
-- ---------------------------------------------------------------------
-- YO'L VARAQASIDAGI TOPSHIRIQLAR — bitta varaqa ichidagi yuk tashish
-- qatorlari. Yuk nomi va og'irligi (tonna), mijoz, yuklash va tushirish
-- manzili, masofa (distance_km), reyslar soni, ton-km.
-- DIQQAT: bu waybill'ning O'ZI EMAS. "Nechta yo'l varaqasi bor?" ->
-- waybill; "topshiriqlar/yuklar nechta?" -> SHU jadval.
-- ---------------------------------------------------------------------
CREATE TABLE waybill_task (
    waybill_id uuid NOT NULL,
    cargo_name varchar(1000),
    cargo_weight_tons numeric(12,3),
    customer_name varchar(256),
    distance_km numeric(14,3),
    loading_location varchar(512),
    scheduled_at timestamptz,
    sequence_number integer NOT NULL,
    trip_count integer,
    unloading_location varchar(512),
    document_number varchar(128),
    cargo_ton_km numeric(14,3),
    measurement_basis varchar(16),  -- RUXSAT: 'TOTAL', 'PER_RUN'
    FOREIGN KEY (waybill_id) REFERENCES waybill(id),
    CHECK (measurement_basis in ('TOTAL', 'PER_RUN'))
);

-- TABLE: web_push_delivery  (satrlar: noma'lum)
CREATE TABLE web_push_delivery (
    id uuid NOT NULL,
    attempts integer NOT NULL,
    created_at timestamptz NOT NULL,
    next_attempt_at timestamptz NOT NULL,
    notification_id uuid NOT NULL,
    subscription_id uuid NOT NULL,
    accepted_at timestamptz,
    delivered_at timestamptz,
    last_http_status integer,
    state varchar(32) NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (notification_id) REFERENCES notification(id),
    FOREIGN KEY (subscription_id) REFERENCES web_push_subscription(id)
);

-- TABLE: web_push_delivery_history  (satrlar: noma'lum)
CREATE TABLE web_push_delivery_history (
    delivery_id uuid NOT NULL,
    notification_id uuid NOT NULL,
    attempts integer NOT NULL,
    state varchar(32) NOT NULL,
    http_status integer,
    accepted_at timestamptz,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (delivery_id, attempts, state),
    FOREIGN KEY (notification_id) REFERENCES notification(id)
);

-- TABLE: web_push_subscription  (satrlar: noma'lum)
CREATE TABLE web_push_subscription (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    endpoint varchar(2048) NOT NULL,
    endpoint_hash varchar(64) NOT NULL,
    user_id uuid NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (user_id) REFERENCES app_user(id)
);

-- TABLE: weighing  (satrlar: 0 — BO`SH)
CREATE TABLE weighing (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    created_by uuid,
    driver_id uuid,
    gross_weight_kg numeric(12,3),
    net_weight_kg numeric(12,3),
    notes varchar(1000),
    operator_id uuid,
    operator_name varchar(256),
    scale_number varchar(64),
    shipment_id uuid,
    status varchar(16) NOT NULL,  -- RUXSAT: 'DRAFT', 'CONFIRMED', 'CANCELLED'
    tare_weight_kg numeric(12,3),
    trip_id uuid,
    updated_at timestamptz,
    vehicle_id uuid NOT NULL,
    waybill_id uuid,
    weighed_at timestamptz NOT NULL,
    weighing_number varchar(64) NOT NULL,
    PRIMARY KEY (id),
    CHECK (status in ('DRAFT', 'CONFIRMED', 'CANCELLED'))
);

-- TABLE: wms_shipment_projection  (satrlar: noma'lum)
CREATE TABLE wms_shipment_projection (
    shipment_id uuid NOT NULL,
    destination varchar(240) NOT NULL,
    origin varchar(240) NOT NULL,
    ready_for_transport boolean NOT NULL,
    shipment_number varchar(100) NOT NULL,
    source_revision bigint NOT NULL,
    updated_at timestamptz NOT NULL,
    batch_id uuid,
    branch_id uuid,
    event_id uuid,
    order_id uuid,
    product_id uuid,
    quality_requirement varchar(32),
    quality_source_id varchar(128),
    quantity numeric(30,9),
    schema_version varchar(32),
    site_id uuid,
    source_contract_revision bigint,
    source_id varchar(128),
    source_status varchar(64),
    unit varchar(64),
    PRIMARY KEY (shipment_id)
);

-- TABLE: wms_shipment_receipt  (satrlar: 0 — BO`SH)
CREATE TABLE wms_shipment_receipt (
    event_id uuid NOT NULL,
    received_at timestamptz NOT NULL,
    shipment_id uuid NOT NULL,
    source_revision bigint NOT NULL,
    status varchar(20) NOT NULL,
    source_contract_revision bigint,
    original jsonb,  -- [JSON matn]
    source_id varchar(128),
    schema_version varchar(32),
    idempotency_key text,
    payload_hash varchar(64),
    reason text,
    PRIMARY KEY (event_id)
);

-- TABLE: yard_correction_review  (satrlar: 0 — BO`SH)
CREATE TABLE yard_correction_review (
    id uuid NOT NULL,
    measurement_id uuid NOT NULL,
    version bigint NOT NULL,
    action text NOT NULL,  -- RUXSAT: 'APPROVE', 'REJECT', 'REVOKE'
    reference text NOT NULL,
    reason text NOT NULL,
    operation_id text NOT NULL,
    actor_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (measurement_id) REFERENCES yard_measurement(id),
    CHECK (action in ('APPROVE', 'REJECT', 'REVOKE')),
    CHECK ((btrim(reason) <> '')),
    CHECK ((btrim(reference) <> '')),
    CHECK ((version > 0))
);

-- TABLE: yard_device_binding  (satrlar: 0 — BO`SH)
CREATE TABLE yard_device_binding (
    id uuid NOT NULL,
    version bigint NOT NULL,
    scale_id uuid NOT NULL,
    site_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    service_user_id uuid NOT NULL,
    device_reference text NOT NULL,
    unit text NOT NULL,  -- RUXSAT: 'KG', 'TONNE'
    valid_from timestamptz NOT NULL,
    valid_to timestamptz NOT NULL,
    max_delay_seconds bigint NOT NULL,
    regulation_reference text NOT NULL,
    state text NOT NULL,  -- RUXSAT: 'DRAFT', 'APPROVED', 'REVOKED'
    created_by uuid NOT NULL,
    approved_by uuid,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (approved_by) REFERENCES app_user(id),
    FOREIGN KEY (created_by) REFERENCES app_user(id),
    FOREIGN KEY (scale_id) REFERENCES yard_scale(id),
    FOREIGN KEY (service_user_id) REFERENCES app_user(id),
    FOREIGN KEY (site_id) REFERENCES yard_site(id),
    CHECK ((valid_to > valid_from)),
    CHECK (((state <> 'approved') or ((approved_by is not null) and (approved_by <> created_by)))),
    CHECK ((max_delay_seconds > 0)),
    CHECK (state in ('DRAFT', 'APPROVED', 'REVOKED')),
    CHECK (unit in ('KG', 'TONNE'))
);

-- TABLE: yard_device_binding_history  (satrlar: noma'lum)
CREATE TABLE yard_device_binding_history (
    id uuid NOT NULL,
    binding_id uuid NOT NULL,
    action text NOT NULL,
    reason text NOT NULL,
    snapshot_json text NOT NULL,  -- [JSON matn]
    actor_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (binding_id) REFERENCES yard_device_binding(id),
    CHECK ((btrim(reason) <> ''))
);

-- TABLE: yard_device_receipt  (satrlar: noma'lum)
CREATE TABLE yard_device_receipt (
    id uuid NOT NULL,
    binding_id uuid NOT NULL,
    binding_version bigint NOT NULL,
    measurement_id uuid NOT NULL,
    source_measurement_id text NOT NULL,
    request_hash varchar(64) NOT NULL,
    source_payload_hash varchar(64) NOT NULL,
    request_json text NOT NULL,  -- [JSON matn]
    actor_id uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (actor_id) REFERENCES app_user(id),
    FOREIGN KEY (binding_id) REFERENCES yard_device_binding(id),
    FOREIGN KEY (measurement_id) REFERENCES yard_measurement(id)
);

-- TABLE: yard_event  (satrlar: noma'lum)
CREATE TABLE yard_event (
    id uuid NOT NULL,
    action varchar(32) NOT NULL,
    actor_id uuid NOT NULL,
    actor_name varchar(256) NOT NULL,
    occurred_at timestamptz NOT NULL,
    operation_id varchar(128) NOT NULL,
    previous_data_json text,  -- [JSON matn]
    previous_state varchar(32),
    reason varchar(1000),
    release_evidence_json text,  -- [JSON matn]
    release_pair_id uuid,
    release_profile_version bigint,
    release_site_id uuid,
    release_tare_measurement_id uuid,
    request_hash varchar(64) NOT NULL,
    response_json text NOT NULL,  -- [JSON matn]
    result_state varchar(32) NOT NULL,
    target_id uuid NOT NULL,
    target_type varchar(32) NOT NULL,
    version_after bigint NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (release_pair_id) REFERENCES yard_weighing_pair(id),
    FOREIGN KEY (release_site_id) REFERENCES yard_site(id),
    FOREIGN KEY (release_tare_measurement_id) REFERENCES yard_measurement(id)
);

-- TABLE: yard_mass_policy  (satrlar: noma'lum)
CREATE TABLE yard_mass_policy (
    id uuid NOT NULL,
    allow_different_scales boolean NOT NULL,
    branch_id uuid NOT NULL,
    composition_identity varchar(128) NOT NULL,
    max_gross_kg numeric(14,3) NOT NULL,
    max_measurement_age_seconds bigint NOT NULL,
    max_net_kg numeric(14,3) NOT NULL,
    max_pair_gap_seconds bigint NOT NULL,
    order_deviation_kg numeric(14,3) NOT NULL,
    order_weight_source varchar(32) NOT NULL,
    regulation_reference varchar(512) NOT NULL,
    require_current_calibration boolean NOT NULL,
    site_id uuid NOT NULL,
    trailer_id uuid,
    updated_at timestamptz NOT NULL,
    updated_by uuid NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_to timestamptz NOT NULL,
    vehicle_id uuid NOT NULL,
    version bigint NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (site_id) REFERENCES yard_site(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id)
);

-- TABLE: yard_measurement  (satrlar: 0 — BO`SH)
CREATE TABLE yard_measurement (
    id uuid NOT NULL,
    branch_id uuid NOT NULL,
    composition_identity varchar(128) NOT NULL,
    corrects_id uuid,
    driver_id uuid NOT NULL,
    fingerprint varchar(64) NOT NULL,
    kind varchar(16) NOT NULL,  -- RUXSAT: 'TARE', 'GROSS', 'CONTROL'
    manual_reason varchar(1000) NOT NULL,
    mass_kg numeric(14,3) NOT NULL,
    measured_at timestamptz NOT NULL,
    operator_id uuid NOT NULL,
    operator_name varchar(256) NOT NULL,
    recorded_at timestamptz NOT NULL,
    scale_id uuid NOT NULL,
    scale_snapshot_json text NOT NULL,  -- [JSON matn]
    shipment_id uuid,
    site_id uuid NOT NULL,
    source varchar(16) NOT NULL,  -- RUXSAT: 'MANUAL', 'DEVICE'
    source_measurement_id varchar(128) NOT NULL,
    trip_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (corrects_id) REFERENCES yard_measurement(id),
    FOREIGN KEY (driver_id) REFERENCES driver(id),
    FOREIGN KEY (scale_id) REFERENCES yard_scale(id),
    FOREIGN KEY (site_id) REFERENCES yard_site(id),
    FOREIGN KEY (trip_id) REFERENCES trip(id),
    FOREIGN KEY (vehicle_id) REFERENCES transport_vehicle(id),
    CHECK (kind in ('TARE', 'GROSS', 'CONTROL')),
    CHECK ((mass_kg > (0))),
    CHECK ((btrim((manual_reason)) <> '')),
    CHECK (source in ('MANUAL', 'DEVICE'))
);

-- TABLE: yard_scale  (satrlar: noma'lum)
CREATE TABLE yard_scale (
    id uuid NOT NULL,
    branch_id uuid NOT NULL,
    calibration_reference varchar(512),
    calibration_valid_from timestamptz,
    calibration_valid_to timestamptz,
    capacity_kg numeric(14,3),
    manual_input_allowed boolean,
    name varchar(128) NOT NULL,
    regulation_reference varchar(512),
    resolution_kg numeric(14,3),
    site_id uuid NOT NULL,
    state varchar(32) NOT NULL,
    updated_at timestamptz NOT NULL,
    updated_by uuid NOT NULL,
    valid_from timestamptz,
    valid_to timestamptz,
    object_version bigint NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (site_id) REFERENCES yard_site(id)
);

-- TABLE: yard_site  (satrlar: 0 — BO`SH)
CREATE TABLE yard_site (
    id uuid NOT NULL,
    branch_id uuid NOT NULL,
    name varchar(128) NOT NULL,
    profile_json text,  -- [JSON matn]
    profile_state varchar(32) NOT NULL,  -- RUXSAT: 'UNCONFIGURED', 'CONFIGURED'
    profile_valid_from timestamptz,
    profile_valid_to timestamptz,
    regulation_reference varchar(512),
    time_zone varchar(64) NOT NULL,
    updated_at timestamptz NOT NULL,
    updated_by uuid,
    object_version bigint NOT NULL,
    PRIMARY KEY (id),
    CHECK ((((profile_state) <> 'configured') or ((regulation_reference is not null) and (btrim((regulation_reference)) <> '') and (profile_json is not null) and (profile_valid_from is not null) and (profile_valid_to > profile_valid_from)))),
    CHECK (profile_state in ('UNCONFIGURED', 'CONFIGURED'))
);

-- TABLE: yard_weighing_pair  (satrlar: noma'lum)
CREATE TABLE yard_weighing_pair (
    id uuid NOT NULL,
    branch_id uuid NOT NULL,
    composition_identity varchar(128) NOT NULL,
    corrects_id uuid,
    gross_kg numeric(14,3) NOT NULL,
    gross_measurement_id uuid NOT NULL,
    mass_policy_id uuid NOT NULL,
    mass_policy_version bigint NOT NULL,
    net_kg numeric(14,3) NOT NULL,
    operator_id uuid NOT NULL,
    order_fingerprint varchar(64) NOT NULL,
    order_snapshot_json text NOT NULL,  -- [JSON matn]
    policy_snapshot_json text NOT NULL,  -- [JSON matn]
    reason varchar(1000),
    recorded_at timestamptz NOT NULL,
    shipment_id uuid,
    site_id uuid NOT NULL,
    tare_kg numeric(14,3) NOT NULL,
    tare_measurement_id uuid NOT NULL,
    trip_id uuid NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (corrects_id) REFERENCES yard_weighing_pair(id),
    FOREIGN KEY (gross_measurement_id) REFERENCES yard_measurement(id),
    FOREIGN KEY (mass_policy_id) REFERENCES yard_mass_policy(id),
    FOREIGN KEY (site_id) REFERENCES yard_site(id),
    FOREIGN KEY (tare_measurement_id) REFERENCES yard_measurement(id),
    FOREIGN KEY (trip_id) REFERENCES trip(id),
    CHECK (((tare_kg > (0)) and (gross_kg >= tare_kg) and (net_kg = (gross_kg - tare_kg)) and (tare_measurement_id <> gross_measurement_id))),
    CHECK (((corrects_id is null) or ((corrects_id <> id) and (reason is not null) and (btrim((reason)) <> ''))))
);

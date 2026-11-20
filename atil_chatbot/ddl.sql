-- =====================================================================
-- ATIL BAZASI — DDL   (AVTOMATIK HOSIL QILINGAN)
-- =====================================================================
-- Bu fayl haqiqiy bazadan (pg_catalog) hosil qilingan. QO'LDA USTUN
-- QO'SHMANG — baza o'zgarganda fayl qaytadan hosil qilinadi va qo'lda
-- kiritilgan o'zgarish yo'qoladi.
--
-- Chatbot bazani AYNAN shu fayl orqali "ko'radi": model shundan SQL yozadi
-- va `execute_sql` dagi jadval/ustun tekshiruvchisi ham shunga qaraydi.
-- Fayl bazadan orqada qolsa, xato SQL tekshiruvdan o'tib ketadi va faqat
-- bazada yiqiladi — foydalanuvchi esa buni "ma'lumot yo'q" deb tushunadi.
--
-- Faylga FAQAT `read-user-atil` o'qiy oladigan jadvallar kiradi.
--
-- Har jadvalda saqlanadi:
--   * ustunlar va turlari — bazadagidek;
--   * check (...) — status/tur ustunlarining RUXSAT ETILGAN QIYMATLARI;
--   * `-- <ustun> BAZADA:` — o'sha qiymatlardan qaysi biri HAQIQATDA
--     uchrashi va nechtadan. `ISHLATILMAGAN:` dagi qiymatlar bazada YO'Q —
--     ularni WHERE shartida ishlatmang, natija doim bo'sh chiqadi;
--   * foreign key — JOIN yo'llari.
--
-- Jadval USTIDAGI `-- ` izohlari qo'lda yozilgan domen bilimi bo'lib, qayta
-- hosil qilishda saqlanadi. Yangi izohni jadval ustiga yozing.
-- =====================================================================


create table accepted_service_allocation
(
    leg_id                uuid not null,
    accepted_leg_version  bigint not null,
    branch_id             uuid not null,
    confirmed_at          timestamptz not null,
    confirmed_by          uuid not null,
    contract_id           uuid not null,
    customer_id           uuid not null,
    department_id         uuid not null,
    reason                varchar(2000) not null,
    version               bigint not null,
    primary key (leg_id),
    foreign key (branch_id) references reference_data(id),
    foreign key (confirmed_by) references app_user(id),
    foreign key (contract_id) references service_contract(id),
    foreign key (customer_id) references customer(id),
    foreign key (department_id) references reference_data(id),
    foreign key (leg_id) references transport_execution_leg(id)
);

create table accepted_service_allocation_event
(
    id               uuid not null,
    actor_id         uuid not null,
    allocation_json  text not null,
    leg_id           uuid not null,
    performed_at     timestamptz not null,
    reason           varchar(2000) not null,
    primary key (id),
    foreign key (actor_id) references app_user(id),
    foreign key (leg_id) references transport_execution_leg(id)
);

create table ai_extraction_closed
(
    operation_id  uuid not null,
    actor_id      uuid not null,
    reason        text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    check (((length(reason) >= 1) and (length(reason) <= 1000))),
    foreign key (actor_id) references app_user(id)
);

create table ai_extraction_command
(
    operation_id  uuid not null,
    draft_id      uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    revision      bigint not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (draft_id) references ai_extraction_draft(draft_id),
    foreign key (draft_id, revision) references ai_extraction_revision(draft_id, revision)
);

create table ai_extraction_draft
(
    draft_id         uuid not null,
    operation_id     uuid not null,
    actor_id         uuid not null,
    kind             text not null,
    policy_id        uuid not null,
    policy_revision  bigint not null,
    original         jsonb not null,
    sources          jsonb not null,
    state            text not null,
    outcome_reason   text not null,
    fields           jsonb not null,
    revision         bigint not null,
    created_at       timestamptz not null,
    updated_at       timestamptz not null,
    primary key (draft_id),
    check ((jsonb_typeof(fields) = 'array')),
    check (kind in ('DRIVING_LICENSE', 'VEHICLE_PASSPORT', 'VOICE')),
    -- kind BAZADA: jadval bo'sh
    check ((revision >= 0)),
    check (((jsonb_typeof(sources) = 'array') and ((jsonb_array_length(sources) >= 1) and (jsonb_array_length(sources) <= 2)))),
    check (state in ('IN_PROGRESS', 'OUTCOME_UNKNOWN', 'DRAFT', 'REVIEWED_DRAFT', 'REJECTED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (policy_id, policy_revision) references ai_transfer_policy(policy_id, revision)
);

create table ai_extraction_review_closed
(
    operation_id  uuid not null,
    draft_id      uuid not null,
    actor_id      uuid not null,
    reason        text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    check (((length(reason) >= 1) and (length(reason) <= 1000))),
    foreign key (actor_id) references app_user(id),
    foreign key (draft_id) references ai_extraction_draft(draft_id)
);

create table ai_extraction_revision
(
    draft_id     uuid not null,
    revision     bigint not null,
    state        text not null,
    fields       jsonb not null,
    actor_id     uuid not null,
    reason       text not null,
    recorded_at  timestamptz not null,
    primary key (draft_id, revision),
    check (((length(reason) >= 1) and (length(reason) <= 1000))),
    check ((revision > 0)),
    check (state in ('DRAFT', 'REVIEWED_DRAFT', 'REJECTED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (draft_id) references ai_extraction_draft(draft_id)
);

create table ai_provider_session
(
    actor_id         uuid not null,
    provider_origin  text not null,
    session_hash     text not null,
    created_at       timestamptz not null,
    primary key (provider_origin, session_hash),
    check ((length(session_hash) = 64)),
    foreign key (actor_id) references app_user(id)
);

create table ai_transfer_audit
(
    id                 bigint not null,
    operation_id       uuid not null,
    actor_id           uuid not null,
    kind               text not null,
    policy_id          uuid not null,
    policy_revision    bigint not null,
    state              text not null,
    transferred_bytes  bigint not null,
    data_categories    jsonb not null,
    reason             text not null,
    recorded_at        timestamptz not null,
    primary key (id),
    check (kind in ('DRIVING_LICENSE', 'VEHICLE_PASSPORT', 'VOICE', 'CHAT')),
    -- kind BAZADA: jadval bo'sh
    check ((length(reason) <= 100)),
    check (state in ('REQUESTED', 'RESPONSE_RECEIVED', 'OUTCOME_UNKNOWN', 'SESSION_DELETED')),
    -- state BAZADA: jadval bo'sh
    check ((transferred_bytes >= 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (policy_id, policy_revision) references ai_transfer_policy(policy_id, revision)
);

create table ai_transfer_policy
(
    operation_id  uuid not null,
    policy_id     uuid not null,
    revision      bigint not null,
    actor_id      uuid not null,
    state         text not null,
    original      jsonb not null,
    payload       jsonb not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    check ((revision > 0)),
    check (state in ('DRAFT', 'APPROVED', 'REVOKED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id)
);

create table ai_transfer_policy_attempt
(
    operation_id  uuid not null,
    policy_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    check ((jsonb_typeof(original) = 'object')),
    foreign key (actor_id) references app_user(id)
);

create table ai_transfer_policy_closed
(
    operation_id  uuid not null,
    policy_id     uuid not null,
    actor_id      uuid not null,
    reason        text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    check (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 1000))),
    foreign key (actor_id) references app_user(id)
);

-- ---------------------------------------------------------------------
-- Tizim foydalanuvchilari (login, parol hash, email, F.I.Sh., faollik holati).
-- TIZIMGA KIRUVCHI BARCHA FOYDALANUVCHILAR SHU JADVALDA. Rollar alohida
-- user_role jadvalida (bitta foydalanuvchida bir nechta rol bo'lishi mumkin).
-- app_user ishlatiladi.
-- ---------------------------------------------------------------------
create table app_user
(
    id          uuid not null,
    created_at  timestamptz not null,
    email       varchar(128) not null,
    enabled     boolean not null,
    full_name   varchar(256) not null,
    password    varchar(255) not null,
    updated_at  timestamptz not null,
    username    varchar(128) not null,
    branch_id   uuid,
    primary key (id)
);

create table arm_repair_numbering
(
    id             uuid not null,
    business_date  date not null,
    next_sequence  bigint not null,
    updated_at     timestamptz not null,
    primary key (id)
);

create table assignment_decision
(
    id              uuid not null,
    actor_id        uuid not null,
    branch_id       uuid not null,
    decision_json   text not null,
    origin          varchar(64) not null,
    policy_id       uuid,
    policy_version  bigint not null,
    recorded_at     timestamptz not null,
    selection_json  text not null,
    work_id         uuid not null,
    primary key (id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (policy_id) references assignment_policy_revision(id)
);

create table assignment_policy_head
(
    branch_id    uuid not null,
    revision_id  uuid not null,
    version      bigint not null,
    primary key (branch_id),
    foreign key (revision_id) references assignment_policy_revision(id) deferrable initially deferred
);

create table assignment_policy_revision
(
    id             uuid not null,
    basis          varchar(2000) not null,
    branch_id      uuid not null,
    configured     boolean not null,
    payload_hash   varchar(64) not null,
    recorded_at    timestamptz not null,
    recorded_by    uuid not null,
    settings_json  text not null,
    version        bigint not null,
    primary key (id),
    foreign key (recorded_by) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table atil_deploy_migration
(
    id            text not null,
    sha256        text not null,
    installed_at  timestamptz not null,
    primary key (id),
    check ((length(sha256) = 64))
);

create table atil_release_schema_history
(
    release_id  text not null,
    bundle_sha  varchar(64) not null,
    applied_at  timestamptz not null,
    applied_by  name not null,
    primary key (release_id)
);

-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
create table atil_transport_payroll_source
(
    leg_id                 uuid,
    request_id             uuid,
    requirement_id         uuid,
    trip_id                uuid,
    vehicle_id             uuid,
    leg_version            bigint,
    assignment_segment_id  uuid,
    driver_id              uuid,
    allocation_event_id    uuid,
    department_id          uuid,
    branch_id              uuid,
    from_instant           timestamptz,
    to_instant             timestamptz,
    accepted_km            text,
    accepted_engine_hours  text,
    state                  text,
    reason                 text,
    trip_count_claim_id    text,
    source_hash            text
);

create table atil_ui_cycle_release
(
    release_id  text not null,
    bundle_sha  text not null,
    applied_at  timestamptz not null,
    applied_by  text not null,
    primary key (release_id)
);

create table atil_ui_schema_release
(
    bundle_sha256         varchar(64) not null,
    release_commit        varchar(40) not null,
    application_revision  varchar(40) not null,
    applied_by            text not null,
    applied_at            timestamptz not null,
    primary key (bundle_sha256),
    check (((application_revision) ~ '^[a-f0-9]{40}$')),
    check (((bundle_sha256) ~ '^[a-f0-9]{64}$')),
    check (((release_commit) ~ '^[a-f0-9]{40}$'))
);

-- ---------------------------------------------------------------------
-- Yuklangan fayllarning umumiy reyestri (nom, MIME turi, hajmi, URL).
-- FAYLNING O'ZI SHU JADVALDA, LEKIN U QAYSI OBYEKTGA TEGISHLILIGI ALOHIDA
-- BOG'LOVCHI JADVALLARDA: vehicle_photo, vehicle_accident_attachment,
-- vehicle_technical_inspection_photo.
-- ---------------------------------------------------------------------
create table attachment
(
    id             uuid not null,
    content_type   varchar(255),
    created_at     timestamptz,
    created_by     varchar(255),
    file_name      varchar(255),
    original_name  varchar(255),
    size_bytes     bigint,
    url            varchar(255),
    primary key (id)
);

-- ---------------------------------------------------------------------
-- Muhim biznes amallarining audit izi: guvohnoma berish/bekor qilish, yoqilg'i
-- limiti o'zgarishi, yoqilg'i ruxsatnomasi tasdiqlash/rad etish, ish haqi
-- tariflarini o'zgartirish. before_snapshot va after_snapshot da o'zgarishdan
-- oldingi va keyingi holat JSON ko'rinishida turadi.
-- KIM NIMANI QACHON O'ZGARTIRGANI SO'RALSA SHU JADVALDAN OLINADI.
-- ---------------------------------------------------------------------
create table audit_event
(
    id                  uuid not null,
    actor               varchar(128),
    after_snapshot      text,
    before_snapshot     text,
    entity_id           uuid,
    entity_type         varchar(64),
    event_type          varchar(48) not null,
    occurred_at         timestamptz not null,
    subject_driver_id   uuid,
    subject_vehicle_id  uuid,
    summary             varchar(512),
    primary key (id),
    check (event_type in ('CREDENTIAL_ISSUED', 'CREDENTIAL_REVOKED', 'FUEL_LIMIT_CREATED', 'FUEL_LIMIT_UPDATED', 'FUEL_LIMIT_DEACTIVATED', 'FUEL_AUTHORIZATION_APPROVED', 'FUEL_AUTHORIZATION_REJECTED', 'FUEL_AUTHORIZATION_COMPLETED', 'FUEL_AUTHORIZATION_CANCELLED', 'PAYROLL_RATES_UPDATED', 'FUEL_NORM_UPDATED', 'TRAILER_COMBINATION_UPDATED', 'TECHNICAL_INSPECTION_UPDATED', 'WAYBILL_RELEASE_CORRECTED', 'TRIP_ASSIGNMENT_UPDATED', 'TRAILER_CREATED', 'TRAILER_UPDATED', 'TRAILER_DEACTIVATED'))
    -- event_type BAZADA: TECHNICAL_INSPECTION_UPDATED 1350, CREDENTIAL_ISSUED 25, FUEL_NORM_UPDATED 19, TRAILER_CREATED 1, WAYBILL_RELEASE_CORRECTED 1, FUEL_LIMIT_CREATED 1 | ISHLATILMAGAN: CREDENTIAL_REVOKED, FUEL_LIMIT_UPDATED, FUEL_LIMIT_DEACTIVATED, FUEL_AUTHORIZATION_APPROVED, FUEL_AUTHORIZATION_REJECTED, FUEL_AUTHORIZATION_COMPLETED, FUEL_AUTHORIZATION_CANCELLED, PAYROLL_RATES_UPDATED va yana 4 ta
);

create table audit_retention_access
(
    access_id    uuid not null,
    archive_id   uuid not null,
    actor_id     uuid not null,
    access_kind  text not null,
    event_id     uuid,
    reason       text not null,
    recorded_at  timestamptz not null,
    primary key (access_id),
    check (access_kind in ('MANIFEST', 'PROOF', 'EVENT')),
    -- access_kind BAZADA: jadval bo'sh
    check (((length(btrim(reason)) >= 1) and (length(btrim(reason)) <= 2000))),
    foreign key (actor_id) references app_user(id),
    foreign key (archive_id) references audit_retention_manifest(archive_id)
);

create table audit_retention_archive
(
    archive_id    uuid not null,
    event_id      uuid not null,
    payload       jsonb not null,
    payload_hash  text not null,
    primary key (archive_id, event_id),
    foreign key (archive_id, event_id) references audit_retention_proof(archive_id, event_id) deferrable initially deferred
);

create table audit_retention_cleanup
(
    cleanup_id               uuid not null,
    revision                 bigint not null,
    state                    text not null,
    target                   text not null,
    archive_id               uuid not null,
    event_type               text not null,
    policy_revision          bigint not null,
    policy_hash              text not null,
    manifest_hash            text not null,
    actor_id                 uuid not null,
    requester_id             uuid not null,
    operation_id             uuid not null,
    authorization_reference  text not null,
    reason                   text not null,
    event_count              integer not null,
    recorded_at              timestamptz not null,
    primary key (cleanup_id, revision),
    check (((length(btrim(authorization_reference)) >= 1) and (length(btrim(authorization_reference)) <= 2000))),
    check (((state <> 'approved') or (actor_id <> requester_id))),
    check ((event_count > 0)),
    check ((revision > 0)),
    check (state in ('REQUESTED', 'APPROVED', 'EXECUTED', 'CANCELLED')),
    -- state BAZADA: jadval bo'sh
    check (target in ('ONLINE', 'ARCHIVE')),
    -- target BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (archive_id) references audit_retention_manifest(archive_id),
    foreign key (event_type, policy_revision) references audit_retention_policy(event_type, revision),
    foreign key (operation_id) references audit_retention_operation(operation_id) deferrable initially deferred,
    foreign key (requester_id) references app_user(id)
);

create table audit_retention_hold
(
    hold_id          uuid not null,
    revision         bigint not null,
    state            text not null,
    event_type       text not null,
    entity_type      text,
    entity_id        uuid,
    operation_id     uuid not null,
    actor_id         uuid not null,
    author_id        uuid not null,
    legal_reference  text not null,
    reason           text not null,
    recorded_at      timestamptz not null,
    primary key (hold_id, revision),
    check (((entity_id is null) or (entity_type is not null))),
    check (((state <> 'released') or (actor_id <> author_id))),
    check (((length(btrim(legal_reference)) >= 1) and (length(btrim(legal_reference)) <= 2000))),
    check ((revision > 0)),
    check (state in ('ACTIVE', 'RELEASED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (author_id) references app_user(id),
    foreign key (operation_id) references audit_retention_operation(operation_id) deferrable initially deferred
);

create table audit_retention_manifest
(
    archive_id       uuid not null,
    event_type       text not null,
    policy_revision  bigint not null,
    policy_hash      text not null,
    actor_id         uuid not null,
    operation_id     uuid not null,
    event_count      integer not null,
    manifest_hash    text not null,
    archived_at      timestamptz not null,
    reason           text not null,
    primary key (archive_id),
    check ((event_count > 0)),
    check ((manifest_hash ~ '^[a-f0-9]{64}$')),
    foreign key (actor_id) references app_user(id),
    foreign key (event_type, policy_revision) references audit_retention_policy(event_type, revision),
    foreign key (operation_id) references audit_retention_operation(operation_id) deferrable initially deferred
);

create table audit_retention_operation
(
    operation_id  uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    state         text not null,
    result        jsonb,
    reason        text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    check (((state = 'applied') = (result is not null))),
    check (state in ('APPLIED', 'NOT_EXECUTED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id)
);

create table audit_retention_policy
(
    event_type               text not null,
    revision                 bigint not null,
    state                    text not null,
    operation_id             uuid not null,
    actor_id                 uuid not null,
    author_id                uuid not null,
    online_retention_days    integer not null,
    archive_retention_days   integer,
    valid_from               timestamptz not null,
    valid_until              timestamptz not null,
    applicability_reference  text not null,
    approval_reference       text,
    reason                   text not null,
    policy_hash              text not null,
    recorded_at              timestamptz not null,
    primary key (event_type, revision),
    check (((length(btrim(applicability_reference)) >= 1) and (length(btrim(applicability_reference)) <= 2000))),
    check (((archive_retention_days >= 1) and (archive_retention_days <= 365250))),
    check ((valid_until > valid_from)),
    check (((state <> 'approved') or ((actor_id <> author_id) and ((coalesce(length(btrim(approval_reference)), 0) >= 1) and (coalesce(length(btrim(approval_reference)), 0) <= 2000))))),
    check (((online_retention_days >= 1) and (online_retention_days <= 365250))),
    check ((policy_hash ~ '^[a-f0-9]{64}$')),
    check (((length(btrim(reason)) >= 1) and (length(btrim(reason)) <= 2000))),
    check ((revision > 0)),
    check (state in ('DRAFT', 'APPROVED', 'REVOKED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (author_id) references app_user(id),
    foreign key (operation_id) references audit_retention_operation(operation_id) deferrable initially deferred
);

create table audit_retention_proof
(
    archive_id    uuid not null,
    event_id      uuid not null,
    source_table  text not null,
    event_type    text not null,
    entity_type   text,
    entity_id     uuid,
    occurred_at   timestamptz not null,
    payload_hash  text not null,
    primary key (archive_id, event_id),
    check ((payload_hash ~ '^[a-f0-9]{64}$')),
    check (source_table in ('AUDIT_EVENT', 'CRITICAL_AUDIT_EVENT')),
    -- source_table BAZADA: jadval bo'sh
    foreign key (archive_id) references audit_retention_manifest(archive_id) deferrable initially deferred
);

-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
create table audit_retention_source
(
    id            uuid,
    source_table  text,
    event_type    text,
    entity_type   varchar(64),
    entity_id     uuid,
    occurred_at   timestamptz,
    payload       jsonb
);

create table auth_jwt_session
(
    jti                uuid not null,
    user_id            uuid not null,
    session_family     uuid not null,
    token_sha256       text not null,
    credential_sha256  text not null,
    issued_at          timestamptz not null,
    expires_at         timestamptz not null,
    revoked_at         timestamptz,
    revocation_reason  text,
    primary key (jti),
    check ((expires_at > issued_at)),
    check ((((revoked_at is null) and (revocation_reason is null)) or ((revoked_at is not null) and (revocation_reason = any (array['logout', 'credential_change']))))),
    check ((credential_sha256 ~ '^[a-f0-9]{64}$')),
    check ((token_sha256 ~ '^[a-f0-9]{64}$')),
    foreign key (user_id) references app_user(id)
);

create table authorized_recipient
(
    id          uuid not null,
    created_at  timestamptz not null,
    created_by  varchar(128),
    full_name   varchar(256) not null,
    phone       varchar(32) not null,
    primary key (id)
);

create table canonical_inspection_repair_basis
(
    revision_id       uuid not null,
    inspection_id     uuid not null,
    source_version    bigint not null,
    source_hash       text not null,
    vehicle_id        uuid not null,
    branch_id         uuid not null,
    driver_id         uuid not null,
    trailer_id        uuid,
    trip_id           uuid,
    waybill_id        uuid,
    inspection_type   text not null,
    actor_id          uuid not null,
    recorded_at       timestamptz not null,
    inspected_at      timestamptz not null,
    basis_created_at  timestamptz not null,
    primary key (revision_id),
    check (inspection_type in ('PRE_TRIP', 'POST_TRIP')),
    -- inspection_type BAZADA: jadval bo'sh
    check ((source_hash ~ '^[0-9a-f]{64}$')),
    check ((source_version > 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (driver_id) references driver(id),
    foreign key (revision_id) references safety_technical_inspection_revision(id),
    foreign key (trailer_id) references trailers(id),
    foreign key (trip_id) references trip(id),
    foreign key (vehicle_id) references transport_vehicle(id),
    foreign key (waybill_id) references waybill(id)
);

create table canonical_inspection_repair_link
(
    revision_id   uuid not null,
    defect_id     uuid not null,
    repair_id     uuid not null,
    operation_id  uuid not null,
    actor_id      uuid not null,
    recorded_at   timestamptz not null,
    primary key (revision_id),
    foreign key (actor_id) references app_user(id),
    foreign key (defect_id) references fleet_defect(defect_id),
    foreign key (repair_id) references vehicle_repair(id),
    foreign key (revision_id) references canonical_inspection_repair_basis(revision_id)
);

create table carrier
(
    id               uuid not null,
    contact_email    varchar(128),
    contact_person   varchar(128),
    contact_phone    varchar(64),
    created_at       timestamptz not null,
    inn              varchar(32),
    kind             varchar(32),
    name             varchar(256) not null,
    status           varchar(32),
    supports_hazard  boolean,
    updated_at       timestamptz,
    primary key (id)
    -- status BAZADA: INACTIVE 1
);

create table carrier_admission_context
(
    revision_id           uuid not null,
    kind                  varchar(16) not null,
    subject_id            uuid not null,
    branch_id             uuid not null,
    previous_head_id      uuid,
    previous_revision_id  uuid,
    previous_revision     bigint,
    tx_id                 bigint not null,
    primary key (revision_id)
);

create table carrier_admission_head
(
    id                   uuid not null,
    branch_id            uuid not null,
    carrier_id           uuid,
    current_revision_id  uuid not null,
    kind                 varchar(16) not null,
    revision             bigint not null,
    subject_id           uuid not null,
    updated_at           timestamptz not null,
    primary key (id),
    check (kind in ('SOURCE', 'POLICY', 'AGREEMENT'))
    -- kind BAZADA: jadval bo'sh
);

create table carrier_admission_operation
(
    id             uuid not null,
    actor_id       uuid not null,
    branch_id      uuid not null,
    kind           varchar(16) not null,
    original_json  text not null,
    payload_hash   varchar(64) not null,
    recorded_at    timestamptz not null,
    result_json    text not null,
    revision_id    uuid not null,
    subject_id     uuid not null,
    tx_id          bigint not null,
    primary key (id),
    check (kind in ('SOURCE', 'POLICY', 'AGREEMENT'))
    -- kind BAZADA: jadval bo'sh
);

create table carrier_admission_revision
(
    id                    uuid not null,
    actor_id              uuid not null,
    actor_name            varchar(256) not null,
    branch_id             uuid not null,
    carrier_id            uuid,
    data_json             text not null,
    kind                  varchar(16) not null,
    operation_id          uuid not null,
    previous_revision_id  uuid,
    review_reason         varchar(2000) not null,
    review_reference      varchar(256) not null,
    reviewed_at           timestamptz not null,
    revision              bigint not null,
    subject_id            uuid not null,
    primary key (id),
    check (kind in ('SOURCE', 'POLICY', 'AGREEMENT'))
    -- kind BAZADA: jadval bo'sh
);

create table carrier_admission_transition
(
    revision_id  uuid not null,
    head_id      uuid not null,
    tx_id        bigint not null,
    primary key (revision_id)
);

create table carrier_erp_identity_operation
(
    operation_id   uuid not null,
    carrier_id     uuid not null,
    branch_id      uuid not null,
    actor_id       uuid not null,
    state          varchar(16) not null,
    original_json  text not null,
    result_json    text,
    reason         text,
    recorded_at    timestamptz not null,
    primary key (operation_id),
    check (((((state) = 'applied') and (result_json is not null) and (reason is null)) or (((state) = 'not_executed') and (result_json is null) and (length(trim(both from reason)) > 0)))),
    check (state in ('APPLIED', 'NOT_EXECUTED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (carrier_id) references carrier(id)
);

create table carrier_erp_identity_revision
(
    id             uuid not null,
    mapping_id     uuid not null,
    carrier_id     uuid not null,
    branch_id      uuid not null,
    revision       bigint not null,
    state          varchar(16) not null,
    actor_id       uuid not null,
    author_id      uuid not null,
    source_system  varchar(128) not null,
    external_id    varchar(256) not null,
    identity_hash  varchar(64) not null,
    original_json  text not null,
    result_json    text not null,
    recorded_at    timestamptz not null,
    primary key (id),
    check ((revision > 0)),
    check (state in ('ASSERTED', 'APPROVED', 'REVOKED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (author_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (carrier_id) references carrier(id),
    foreign key (source_system, external_id) references carrier_erp_identity_source(source_system, external_id)
);

create table carrier_erp_identity_source
(
    source_system  varchar(128) not null,
    external_id    varchar(256) not null,
    carrier_id     uuid not null,
    primary key (source_system, external_id),
    foreign key (carrier_id) references carrier(id)
);

create table carrier_external_execution_closed
(
    operation_id   uuid not null,
    kind           varchar(16) not null,
    order_id       uuid not null,
    branch_id      uuid not null,
    actor_id       uuid not null,
    original_json  text not null,
    close_reason   text not null,
    closed_at      timestamptz not null,
    result_json    text not null,
    tx_id          bigint not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (order_id) references carrier_order(id)
);

create table carrier_external_execution_record
(
    operation_id   uuid not null,
    kind           varchar(16) not null,
    subject_id     uuid not null,
    order_id       uuid,
    branch_id      uuid not null,
    revision       bigint not null,
    actor_id       uuid not null,
    actor_name     text not null,
    recorded_at    timestamptz not null,
    original_json  text not null,
    payload_json   text not null,
    content_hash   varchar(64) not null,
    tx_id          bigint not null,
    primary key (operation_id),
    check (kind in ('POLICY', 'TARIFF', 'REPORT', 'DECISION', 'REVERSAL')),
    -- kind BAZADA: jadval bo'sh
    check ((revision > 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (order_id) references carrier_order(id)
);

create table carrier_external_qualification
(
    operation_id  uuid not null,
    kind          text not null,
    subject_id    uuid not null,
    order_id      uuid not null,
    branch_id     uuid not null,
    revision      bigint not null,
    actor_id      uuid not null,
    actor_name    text not null,
    recorded_at   timestamptz not null,
    original      jsonb not null,
    payload_json  text not null,
    content_hash  text not null,
    tx_id         bigint not null,
    primary key (operation_id),
    check (kind in ('POLICY', 'PACKAGE', 'DECISION', 'REVOCATION', 'BINDING')),
    -- kind BAZADA: jadval bo'sh
    check ((revision > 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (order_id) references carrier_order(id)
);

create table carrier_external_qualification_closed
(
    operation_id  uuid not null,
    kind          text not null,
    order_id      uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    tx_id         bigint not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (order_id) references carrier_order(id)
);

create table carrier_invoice
(
    id                uuid not null,
    billed_total      numeric(16,2) not null,
    comment           varchar(2000),
    created_at        timestamptz not null,
    currency          varchar(8) not null,
    due_at            date,
    expected_total    numeric(16,2) not null,
    invoice_number    varchar(64) not null,
    issued_at         date not null,
    status            varchar(32) not null,
    updated_at        timestamptz not null,
    variance_percent  numeric(10,4) not null,
    variance_total    numeric(16,2) not null,
    version           bigint not null,
    carrier_id        uuid,
    primary key (id),
    check (status in ('RECEIVED', 'UNDER_REVIEW', 'MATCHED', 'DISCREPANCY', 'APPROVED', 'REJECTED', 'PAID')),
    -- status BAZADA: jadval bo'sh
    foreign key (carrier_id) references carrier(id)
);

create table carrier_invoice_allocation_closed_operation
(
    operation_id  uuid not null,
    invoice_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (invoice_id) references carrier_invoice(id)
);

create table carrier_invoice_approval_closed_operation
(
    kind            text not null,
    operation_id    uuid not null,
    invoice_id      uuid,
    branch_id       uuid not null,
    actor_id        uuid not null,
    original        jsonb not null,
    closure_reason  text not null,
    closed_at       timestamptz not null,
    primary key (kind, operation_id),
    check ((((kind = 'policy') and (invoice_id is null)) or ((kind = 'decision') and (invoice_id is not null)))),
    check (kind in ('POLICY', 'DECISION')),
    -- kind BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (invoice_id) references carrier_invoice(id)
);

create table carrier_invoice_approval_policy
(
    operation_id      uuid not null,
    branch_id         uuid not null,
    actor_id          uuid not null,
    expected_version  bigint not null,
    revision          bigint not null,
    previous_hash     text not null,
    policy_hash       text not null,
    original          jsonb not null,
    recorded_at       timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table carrier_invoice_document_closed_operation
(
    operation_id    uuid not null,
    invoice_id      uuid not null,
    branch_id       uuid not null,
    actor_id        uuid not null,
    original        jsonb not null,
    closure_reason  text not null,
    closed_at       timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (invoice_id) references carrier_invoice(id)
);

create table carrier_invoice_document_revision
(
    operation_id              uuid not null,
    invoice_id                uuid not null,
    carrier_id                uuid not null,
    branch_id                 uuid not null,
    actor_id                  uuid not null,
    expected_version          bigint not null,
    revision                  bigint not null,
    previous_hash             text not null,
    expected_review_revision  bigint not null,
    snapshot                  jsonb not null,
    snapshot_hash             text not null,
    original                  jsonb not null,
    reason                    text not null,
    recorded_at               timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (carrier_id) references carrier(id),
    foreign key (invoice_id) references carrier_invoice(id)
);

create table carrier_invoice_erp_cancellation
(
    operation_id  uuid not null,
    event_id      uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    hash          text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (event_id) references carrier_invoice_erp_outbox(event_id)
);

create table carrier_invoice_erp_closed
(
    operation_id  uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    kind          text not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table carrier_invoice_erp_delivery
(
    event_id     uuid not null,
    revision     bigint not null,
    state        text not null,
    attempt      integer not null,
    detail       text not null,
    recorded_at  timestamptz not null,
    primary key (event_id, revision),
    foreign key (event_id) references carrier_invoice_erp_outbox(event_id)
);

create table carrier_invoice_erp_dispatch
(
    operation_id  uuid not null,
    event_id      uuid not null,
    actor_id      uuid not null,
    attempt       integer not null,
    original      jsonb not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (event_id) references carrier_invoice_erp_outbox(event_id)
);

create table carrier_invoice_erp_outbox
(
    event_id          uuid not null,
    invoice_id        uuid not null,
    invoice_revision  bigint not null,
    branch_id         uuid not null,
    actor_id          uuid not null,
    approval_id       uuid not null,
    policy_id         uuid not null,
    original          jsonb not null,
    payload           jsonb not null,
    wire_payload      text not null,
    payload_hash      text not null,
    idempotency_key   text not null,
    destination_hash  text not null,
    recorded_at       timestamptz not null,
    primary key (event_id),
    foreign key (actor_id) references app_user(id),
    foreign key (approval_id) references carrier_invoice_financial_decision(operation_id),
    foreign key (branch_id) references reference_data(id),
    foreign key (invoice_id) references carrier_invoice(id),
    foreign key (policy_id) references carrier_invoice_erp_policy(operation_id)
);

create table carrier_invoice_erp_policy
(
    operation_id  uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    revision      bigint not null,
    original      jsonb not null,
    hash          text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table carrier_invoice_erp_receipt
(
    event_id     uuid not null,
    provider     text not null,
    receipt_id   text not null,
    original     jsonb not null,
    hash         text not null,
    received_at  timestamptz not null,
    primary key (event_id),
    foreign key (event_id) references carrier_invoice_erp_outbox(event_id)
);

create table carrier_invoice_execution_allocation
(
    operation_id   uuid not null,
    invoice_id     uuid not null,
    branch_id      uuid not null,
    actor_id       uuid not null,
    revision       bigint not null,
    previous_hash  text not null,
    original       jsonb not null,
    snapshot       jsonb not null,
    snapshot_hash  text not null,
    recorded_at    timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (invoice_id) references carrier_invoice(id)
);

create table carrier_invoice_financial_closed_operation
(
    operation_id    uuid not null,
    invoice_id      uuid not null,
    branch_id       uuid not null,
    actor_id        uuid not null,
    original        jsonb not null,
    closure_reason  text not null,
    closed_at       timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (invoice_id) references carrier_invoice(id)
);

create table carrier_invoice_financial_decision
(
    operation_id      uuid not null,
    invoice_id        uuid not null,
    branch_id         uuid not null,
    actor_id          uuid not null,
    expected_version  bigint not null,
    revision          bigint not null,
    previous_hash     text not null,
    decision_hash     text not null,
    original          jsonb not null,
    state             text not null,
    recorded_at       timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (invoice_id) references carrier_invoice(id)
);

create table carrier_invoice_financial_review
(
    operation_id      uuid not null,
    invoice_id        uuid not null,
    carrier_id        uuid not null,
    branch_id         uuid not null,
    actor_id          uuid not null,
    expected_version  bigint not null,
    revision          bigint not null,
    previous_hash     text not null,
    snapshot          jsonb not null,
    snapshot_hash     text not null,
    original          jsonb not null,
    reason            text not null,
    recorded_at       timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (carrier_id) references carrier(id),
    foreign key (invoice_id) references carrier_invoice(id)
);

create table carrier_invoice_line
(
    invoice_id        uuid not null,
    billed_amount     numeric(16,2) not null,
    description       varchar(500) not null,
    expected_amount   numeric(16,2),
    leg_id            uuid,
    matched           boolean not null,
    shipment_id       uuid,
    variance_amount   numeric(16,2) not null,
    variance_percent  numeric(10,4) not null,
    line_index        integer not null,
    primary key (invoice_id, line_index),
    foreign key (invoice_id) references carrier_invoice(id)
);

create table carrier_invoice_review_closed_operation
(
    operation_id    uuid not null,
    invoice_id      uuid not null,
    branch_id       uuid not null,
    actor_id        uuid not null,
    action          text not null,
    original        jsonb not null,
    closure_reason  text not null,
    closed_at       timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (invoice_id) references carrier_invoice(id)
);

create table carrier_invoice_review_event
(
    operation_id      uuid not null,
    invoice_id        uuid not null,
    branch_id         uuid not null,
    actor_id          uuid not null,
    expected_version  bigint not null,
    revision          bigint not null,
    action            text not null,
    state             text not null,
    reason            text not null,
    original          jsonb not null,
    recorded_at       timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (invoice_id) references carrier_invoice(id)
);

create table carrier_order
(
    id             uuid not null,
    agreement_id   uuid not null,
    award_id       uuid not null,
    branch_id      uuid not null,
    carrier_id     uuid not null,
    created_at     timestamptz not null,
    snapshot_hash  varchar(64) not null,
    snapshot_json  text not null,
    state          varchar(32) not null,
    tender_id      uuid not null,
    primary key (id)
);

create table carrier_order_response
(
    operation_id    uuid not null,
    order_id        uuid not null,
    branch_id       uuid not null,
    actor_id        uuid not null,
    policy_id       uuid not null,
    outcome         text not null,
    received_at     timestamptz not null,
    recorded_at     timestamptz not null,
    original_json   text not null,
    result_json     text not null,
    document_bytes  bytea not null,
    document_hash   text not null,
    tx_id           bigint not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (order_id) references carrier_order(id),
    foreign key (policy_id) references carrier_tender_process_policy_revision(id)
);

create table carrier_order_response_closed_operation
(
    operation_id   uuid not null,
    order_id       uuid not null,
    branch_id      uuid not null,
    actor_id       uuid not null,
    original_json  text not null,
    result_json    text not null,
    close_reason   text not null,
    closed_at      timestamptz not null,
    tx_id          bigint not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (order_id) references carrier_order(id)
);

create table carrier_order_response_correction
(
    id                              uuid not null,
    order_id                        uuid not null,
    operation_id                    uuid not null,
    previous_response_operation_id  uuid not null,
    branch_id                       uuid not null,
    actor_id                        uuid not null,
    recorded_at                     timestamptz not null,
    original_json                   text not null,
    result_json                     text not null,
    response_json                   text not null,
    document_bytes                  bytea not null,
    document_hash                   varchar(64) not null,
    primary key (id),
    foreign key (order_id) references carrier_order(id)
);

create table carrier_order_response_correction_closed
(
    operation_id   uuid not null,
    order_id       uuid not null,
    branch_id      uuid not null,
    actor_id       uuid not null,
    original_json  text not null,
    result_json    text not null,
    recorded_at    timestamptz not null,
    primary key (operation_id)
);

create table carrier_tender
(
    id             uuid not null,
    created_at     timestamptz not null,
    description    varchar(1000),
    expires_at     timestamptz,
    shipment_id    uuid not null,
    status         varchar(16) not null,
    tender_number  varchar(64) not null,
    title          varchar(256) not null,
    updated_at     timestamptz,
    version        bigint not null,
    primary key (id),
    check (status in ('OPEN', 'CLOSED', 'CANCELLED'))
    -- status BAZADA: jadval bo'sh
);

create table carrier_tender_award
(
    id                       uuid not null,
    actor_id                 uuid not null,
    agreement_id             uuid not null,
    awarded_at               timestamptz not null,
    bid_id                   uuid not null,
    bid_revision_id          uuid not null,
    branch_id                uuid not null,
    carrier_id               uuid not null,
    previous_tender_version  bigint not null,
    snapshot_hash            varchar(64) not null,
    snapshot_json            text not null,
    tender_id                uuid not null,
    tender_version           bigint not null,
    primary key (id)
);

create table carrier_tender_award_context
(
    award_id      uuid not null,
    tender_id     uuid not null,
    tx_id         bigint not null,
    row_snapshot  jsonb not null,
    primary key (award_id)
);

create table carrier_tender_award_operation
(
    id             uuid not null,
    actor_id       uuid not null,
    award_id       uuid not null,
    branch_id      uuid not null,
    order_id       uuid not null,
    original_json  text not null,
    payload_hash   varchar(64) not null,
    recorded_at    timestamptz not null,
    result_json    text not null,
    tender_id      uuid not null,
    tx_id          bigint not null,
    primary key (id)
);

create table carrier_tender_award_transition
(
    award_id      uuid not null,
    tender_id     uuid not null,
    tx_id         bigint not null,
    row_snapshot  jsonb not null,
    primary key (award_id)
);

create table carrier_tender_bid_context
(
    revision_id           uuid not null,
    bid_id                uuid not null,
    previous_revision_id  uuid,
    previous_revision     bigint,
    tx_id                 bigint not null,
    primary key (revision_id)
);

create table carrier_tender_bid_head
(
    bid_id               uuid not null,
    branch_id            uuid not null,
    carrier_id           uuid not null,
    current_revision_id  uuid not null,
    revision             bigint not null,
    tender_id            uuid not null,
    updated_at           timestamptz not null,
    primary key (bid_id)
);

create table carrier_tender_bid_operation
(
    id             uuid not null,
    actor_id       uuid not null,
    bid_id         uuid not null,
    branch_id      uuid not null,
    original_json  text not null,
    payload_hash   varchar(64) not null,
    recorded_at    timestamptz not null,
    result_json    text not null,
    revision_id    uuid not null,
    tender_id      uuid not null,
    tx_id          bigint not null,
    primary key (id)
);

create table carrier_tender_bid_revision
(
    id                    uuid not null,
    actor_id              uuid not null,
    bid_id                uuid not null,
    branch_id             uuid not null,
    carrier_id            uuid not null,
    operation_id          uuid not null,
    previous_revision_id  uuid,
    revision              bigint not null,
    snapshot_hash         varchar(64) not null,
    snapshot_json         text not null,
    submitted_at          timestamptz not null,
    tender_id             uuid not null,
    primary key (id)
);

create table carrier_tender_bid_transition
(
    revision_id  uuid not null,
    bid_id       uuid not null,
    tx_id        bigint not null,
    primary key (revision_id)
);

create table carrier_tender_creation_context
(
    tender_id     uuid not null,
    tx_id         bigint not null,
    row_snapshot  jsonb not null,
    primary key (tender_id)
);

create table carrier_tender_process_policy_context
(
    revision_id           uuid not null,
    branch_id             uuid not null,
    previous_revision_id  uuid,
    previous_revision     bigint,
    tx_id                 bigint not null,
    primary key (revision_id)
);

create table carrier_tender_process_policy_head
(
    branch_id            uuid not null,
    current_revision_id  uuid not null,
    revision             bigint not null,
    updated_at           timestamptz not null,
    primary key (branch_id)
);

create table carrier_tender_process_policy_operation
(
    id             uuid not null,
    actor_id       uuid not null,
    branch_id      uuid not null,
    original_json  text not null,
    payload_hash   varchar(64) not null,
    recorded_at    timestamptz not null,
    result_json    text not null,
    revision_id    uuid not null,
    tx_id          bigint not null,
    primary key (id)
);

create table carrier_tender_process_policy_revision
(
    id                    uuid not null,
    actor_id              uuid not null,
    actor_name            varchar(256) not null,
    branch_id             uuid not null,
    data_json             text not null,
    operation_id          uuid not null,
    previous_revision_id  uuid,
    review_reason         varchar(2000) not null,
    review_reference      varchar(256) not null,
    reviewed_at           timestamptz not null,
    revision              bigint not null,
    primary key (id)
);

create table carrier_tender_process_policy_transition
(
    revision_id  uuid not null,
    branch_id    uuid not null,
    tx_id        bigint not null,
    primary key (revision_id)
);

create table carrier_tender_source
(
    tender_id                     uuid not null,
    actor_id                      uuid not null,
    branch_id                     uuid not null,
    created_at                    timestamptz not null,
    operation_id                  uuid not null,
    plan_revision_id              uuid not null,
    process_policy_id             uuid not null,
    reason                        varchar(2000) not null,
    shipment_id                   uuid not null,
    shipment_source_operation_id  uuid not null,
    shipment_version              bigint not null,
    snapshot_hash                 varchar(64) not null,
    snapshot_json                 text not null,
    primary key (tender_id)
);

create table carrier_tender_workflow_operation
(
    id             uuid not null,
    actor_id       uuid not null,
    branch_id      uuid not null,
    kind           varchar(32) not null,
    original_json  text not null,
    payload_hash   varchar(64) not null,
    recorded_at    timestamptz not null,
    result_json    text not null,
    tender_id      uuid not null,
    tx_id          bigint not null,
    primary key (id)
);

create table chemical_authority_operation
(
    operation_id    uuid not null,
    actor_id        uuid not null,
    action          text not null,
    source_id       uuid not null,
    branch_id       uuid not null,
    original        jsonb not null,
    payload_hash    text not null,
    state           text not null,
    result          jsonb,
    closure_reason  text,
    recorded_at     timestamptz not null,
    primary key (operation_id),
    check (action in ('WRITE', 'APPROVE', 'REVOKE')),
    -- action BAZADA: jadval bo'sh
    check ((((state = 'applied') and (result is not null) and (jsonb_typeof(result) = 'object') and (closure_reason is null)) or ((state = 'not_executed') and (result is null) and (closure_reason is not null) and ((length(btrim(closure_reason)) >= 1) and (length(btrim(closure_reason)) <= 1000))))),
    check ((jsonb_typeof(original) = 'object')),
    check ((payload_hash ~ '^[a-f0-9]{64}$')),
    check (state in ('APPLIED', 'NOT_EXECUTED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table chemical_quality_batch
(
    id                  uuid not null,
    branch_id           uuid not null,
    product_id          uuid not null,
    reference           text not null,
    external_system     text,
    external_batch_key  text,
    produced_at         timestamptz,
    actor_id            uuid not null,
    reason              text not null,
    created_at          timestamptz not null,
    operation_id        uuid,
    primary key (id),
    check (((external_system is null) = (external_batch_key is null))),
    check (((external_batch_key is null) or ((length(trim(both from external_batch_key)) >= 1) and (length(trim(both from external_batch_key)) <= 512)))),
    check (external_system in ('ERP', 'WMS', 'LIMS')),
    -- external_system BAZADA: jadval bo'sh
    check (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 1000))),
    check (((length(trim(both from reference)) >= 1) and (length(trim(both from reference)) <= 512))),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table chemical_quality_load_binding
(
    target_type       text not null,
    target_id         uuid not null,
    allocation_id     uuid not null,
    version           bigint not null,
    branch_id         uuid not null,
    batch_id          uuid not null,
    release_version   bigint not null,
    passport_id       uuid not null,
    passport_version  bigint not null,
    policy_id         uuid not null,
    policy_version    bigint not null,
    context_id        uuid not null,
    context_version   bigint not null,
    load_ref_kind     text not null,
    load_proof        jsonb not null,
    shipment_id       uuid,
    site_id           uuid,
    work_snapshot     jsonb not null,
    actor_id          uuid not null,
    reason            text not null,
    created_at        timestamptz not null,
    operation_id      uuid,
    primary key (target_type, target_id, allocation_id, version),
    check (load_ref_kind in ('MANIFEST_ALLOCATION', 'REQUEST_POSITION')),
    -- load_ref_kind BAZADA: jadval bo'sh
    check (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 1000))),
    check (target_type in ('ROUTE', 'TRIP', 'WAYBILL')),
    -- target_type BAZADA: jadval bo'sh
    check ((version >= 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (batch_id, release_version) references chemical_quality_release(batch_id, version),
    foreign key (context_id, context_version) references chemical_safety_source(id, version),
    foreign key (passport_id, passport_version) references chemical_quality_passport(id, version),
    foreign key (policy_id, policy_version) references chemical_quality_rule(id, version),
    foreign key (shipment_id) references shipment(id),
    foreign key (site_id) references yard_site(id)
);

-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
create table chemical_quality_load_current
(
    target_type       text,
    target_id         uuid,
    allocation_id     uuid,
    version           bigint,
    branch_id         uuid,
    batch_id          uuid,
    release_version   bigint,
    passport_id       uuid,
    passport_version  bigint,
    policy_id         uuid,
    policy_version    bigint,
    context_id        uuid,
    context_version   bigint,
    load_ref_kind     text,
    load_proof        jsonb,
    shipment_id       uuid,
    site_id           uuid,
    work_snapshot     jsonb,
    actor_id          uuid,
    reason            text,
    created_at        timestamptz,
    operation_id      uuid
);

create table chemical_quality_message
(
    source_system     text not null,
    source_reference  text not null,
    source_version    bigint not null,
    batch_id          uuid not null,
    release_version   bigint not null,
    payload           jsonb not null,
    created_at        timestamptz not null,
    primary key (source_system, source_reference, source_version),
    foreign key (batch_id, release_version) references chemical_quality_release(batch_id, version)
);

create table chemical_quality_notice
(
    id              uuid not null,
    target_type     text not null,
    target_id       uuid not null,
    batch_id        uuid not null,
    source_kind     text not null,
    source_id       uuid not null,
    source_version  bigint not null,
    reason          text not null,
    occurred_at     timestamptz not null,
    primary key (id),
    foreign key (batch_id) references chemical_quality_batch(id)
);

create table chemical_quality_notice_review
(
    notice_id     uuid not null,
    actor_id      uuid not null,
    reason        text not null,
    reviewed_at   timestamptz not null,
    operation_id  uuid,
    primary key (notice_id),
    check (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 1000))),
    foreign key (actor_id) references app_user(id),
    foreign key (notice_id) references chemical_quality_notice(id)
);

create table chemical_quality_notification_delivery
(
    notice_id     uuid not null,
    delivered_at  timestamptz not null,
    primary key (notice_id),
    foreign key (notice_id) references chemical_quality_notice(id)
);

create table chemical_quality_passport
(
    id                    uuid not null,
    version               bigint not null,
    batch_id              uuid not null,
    state                 text not null,
    revision_label        text not null,
    laboratory_reference  text not null,
    measured_at           timestamptz not null,
    measurements          jsonb not null,
    document_id           uuid not null,
    valid_from            timestamptz not null,
    valid_to              timestamptz not null,
    policy_id             uuid not null,
    policy_version        bigint not null,
    author_id             uuid not null,
    actor_id              uuid not null,
    reason                text not null,
    created_at            timestamptz not null,
    operation_id          uuid,
    primary key (id, version),
    check ((valid_from < valid_to)),
    check (((length(trim(both from laboratory_reference)) >= 1) and (length(trim(both from laboratory_reference)) <= 512))),
    check ((jsonb_typeof(measurements) = 'object')),
    check (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 1000))),
    check (((length(trim(both from revision_label)) >= 1) and (length(trim(both from revision_label)) <= 128))),
    check (state in ('DRAFT', 'APPROVED', 'WITHDRAWN')),
    -- state BAZADA: jadval bo'sh
    check ((version >= 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (author_id) references app_user(id),
    foreign key (batch_id) references chemical_quality_batch(id),
    foreign key (document_id) references chemical_safety_document(id),
    foreign key (policy_id, policy_version) references chemical_quality_rule(id, version)
);

-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
create table chemical_quality_passport_current
(
    id                    uuid,
    version               bigint,
    batch_id              uuid,
    state                 text,
    revision_label        text,
    laboratory_reference  text,
    measured_at           timestamptz,
    measurements          jsonb,
    document_id           uuid,
    valid_from            timestamptz,
    valid_to              timestamptz,
    policy_id             uuid,
    policy_version        bigint,
    author_id             uuid,
    actor_id              uuid,
    reason                text,
    created_at            timestamptz,
    operation_id          uuid
);

create table chemical_quality_policy_binding
(
    branch_id       uuid not null,
    product_id      uuid not null,
    version         bigint not null,
    policy_id       uuid not null,
    policy_version  bigint not null,
    actor_id        uuid not null,
    reason          text not null,
    created_at      timestamptz not null,
    operation_id    uuid,
    primary key (branch_id, product_id, version),
    check (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 1000))),
    check ((version >= 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (policy_id, policy_version) references chemical_quality_rule(id, version)
);

create table chemical_quality_release
(
    batch_id          uuid not null,
    version           bigint not null,
    state             text not null,
    disposition       text not null,
    passport_id       uuid not null,
    passport_version  bigint not null,
    policy_id         uuid not null,
    policy_version    bigint not null,
    origin            text not null,
    source_system     text not null,
    source_reference  text not null,
    source_version    bigint not null,
    valid_from        timestamptz not null,
    valid_to          timestamptz not null,
    document_id       uuid not null,
    author_id         uuid not null,
    actor_id          uuid not null,
    reason            text not null,
    created_at        timestamptz not null,
    operation_id      uuid,
    primary key (batch_id, version),
    check ((valid_from < valid_to)),
    check (((origin = 'manual') = (source_system = 'manual'))),
    check (disposition in ('RELEASED', 'HOLD', 'REJECTED', 'REVOKED', 'UNKNOWN')),
    -- disposition BAZADA: jadval bo'sh
    check (origin in ('MANUAL', 'DOCUMENTED_EXTERNAL')),
    -- origin BAZADA: jadval bo'sh
    check (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 1000))),
    check (((length(trim(both from source_reference)) >= 1) and (length(trim(both from source_reference)) <= 512))),
    check (source_system in ('ERP', 'WMS', 'LIMS', 'MANUAL')),
    -- source_system BAZADA: jadval bo'sh
    check ((source_version >= 0)),
    check (state in ('PENDING_REVIEW', 'APPROVED', 'WITHDRAWN')),
    -- state BAZADA: jadval bo'sh
    check ((version >= 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (author_id) references app_user(id),
    foreign key (batch_id) references chemical_quality_batch(id),
    foreign key (document_id) references chemical_safety_document(id),
    foreign key (passport_id, passport_version) references chemical_quality_passport(id, version),
    foreign key (policy_id, policy_version) references chemical_quality_rule(id, version)
);

-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
create table chemical_quality_release_current
(
    batch_id          uuid,
    version           bigint,
    state             text,
    disposition       text,
    passport_id       uuid,
    passport_version  bigint,
    policy_id         uuid,
    policy_version    bigint,
    origin            text,
    source_system     text,
    source_reference  text,
    source_version    bigint,
    valid_from        timestamptz,
    valid_to          timestamptz,
    document_id       uuid,
    author_id         uuid,
    actor_id          uuid,
    reason            text,
    created_at        timestamptz,
    operation_id      uuid
);

create table chemical_quality_rule
(
    id            uuid not null,
    version       bigint not null,
    kind          text not null,
    state         text not null,
    branch_id     uuid not null,
    product_id    uuid not null,
    body          jsonb not null,
    document_id   uuid not null,
    valid_from    timestamptz not null,
    valid_to      timestamptz not null,
    author_id     uuid not null,
    actor_id      uuid not null,
    reason        text not null,
    created_at    timestamptz not null,
    operation_id  uuid,
    primary key (id, version),
    check ((valid_from < valid_to)),
    check (kind in ('POLICY', 'AUTHORITY')),
    -- kind BAZADA: jadval bo'sh
    check (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 1000))),
    check (state in ('DRAFT', 'APPROVED', 'WITHDRAWN')),
    -- state BAZADA: jadval bo'sh
    check ((version >= 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (author_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (document_id) references chemical_safety_document(id)
);

-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
create table chemical_quality_rule_current
(
    id            uuid,
    version       bigint,
    kind          text,
    state         text,
    branch_id     uuid,
    product_id    uuid,
    body          jsonb,
    document_id   uuid,
    valid_from    timestamptz,
    valid_to      timestamptz,
    author_id     uuid,
    actor_id      uuid,
    reason        text,
    created_at    timestamptz,
    operation_id  uuid
);

create table chemical_safety_acknowledgement
(
    id                uuid not null,
    source_id         uuid not null,
    source_version    bigint not null,
    context_id        uuid not null,
    context_version   bigint not null,
    participant_id    uuid not null,
    participant_role  text not null,
    occurred_at       timestamptz not null,
    primary key (id),
    foreign key (context_id, context_version) references chemical_safety_source(id, version),
    foreign key (participant_id) references app_user(id),
    foreign key (source_id, source_version) references chemical_safety_source(id, version)
);

create table chemical_safety_authority
(
    id                uuid not null,
    version           bigint not null,
    state             text not null,
    branch_id         uuid not null,
    participant_id    uuid not null,
    valid_from        timestamptz not null,
    valid_to          timestamptz not null,
    document_id       uuid not null,
    source_reference  text not null,
    body              jsonb not null,
    reason            text not null,
    actor_id          uuid not null,
    created_at        timestamptz not null,
    operation_id      uuid,
    primary key (id, version),
    check ((valid_from < valid_to)),
    check (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 1000))),
    check (((length(trim(both from source_reference)) >= 1) and (length(trim(both from source_reference)) <= 512))),
    check (state in ('DRAFT', 'APPROVED', 'REVOKED')),
    -- state BAZADA: jadval bo'sh
    check ((version >= 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (document_id) references chemical_safety_document(id),
    foreign key (participant_id) references app_user(id)
);

-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
create table chemical_safety_authority_current
(
    id                uuid,
    version           bigint,
    state             text,
    branch_id         uuid,
    participant_id    uuid,
    valid_from        timestamptz,
    valid_to          timestamptz,
    document_id       uuid,
    source_reference  text,
    body              jsonb,
    reason            text,
    actor_id          uuid,
    created_at        timestamptz,
    operation_id      uuid
);

create table chemical_safety_context_binding
(
    target_type     text not null,
    target_id       uuid not null,
    version         bigint not null,
    source_id       uuid not null,
    source_version  bigint not null,
    actor_id        uuid not null,
    reason          text not null,
    created_at      timestamptz not null,
    operation_id    uuid,
    primary key (target_type, target_id, version),
    check (target_type in ('ROUTE', 'TRIP', 'WAYBILL')),
    -- target_type BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (source_id, source_version) references chemical_safety_source(id, version)
);

-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
create table chemical_safety_current
(
    id                uuid,
    version           bigint,
    kind              text,
    state             text,
    branch_id         uuid,
    source_reference  text,
    valid_from        timestamptz,
    valid_to          timestamptz,
    body              jsonb,
    reason            text,
    actor_id          uuid,
    created_at        timestamptz,
    operation_id      uuid
);

create table chemical_safety_document
(
    id           uuid not null,
    branch_id    uuid not null,
    file_name    text not null,
    mime_type    text not null,
    storage_url  text not null,
    size_bytes   bigint not null,
    sha256       text not null,
    actor_id     uuid not null,
    reason       text not null,
    created_at   timestamptz not null,
    primary key (id),
    check (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 1000))),
    check ((sha256 ~ '^[0-9a-f]{64}$')),
    check (((size_bytes > 0) and (size_bytes <= 10485760))),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table chemical_safety_document_content
(
    document_id  uuid not null,
    content      bytea not null,
    primary key (document_id),
    check (((octet_length(content) > 0) and (octet_length(content) <= 10485760))),
    foreign key (document_id) references chemical_safety_document(id)
);

create table chemical_safety_document_read
(
    id              uuid not null,
    document_id     uuid not null,
    participant_id  uuid not null,
    sha256          text not null,
    occurred_at     timestamptz not null,
    primary key (id),
    foreign key (document_id) references chemical_safety_document(id),
    foreign key (participant_id) references app_user(id)
);

create table chemical_safety_manifest_preparation
(
    id                     uuid not null,
    operation_id           uuid not null,
    route_id               uuid not null,
    manifest_id            uuid not null,
    branch_id              uuid not null,
    vehicle_id             uuid not null,
    request_versions       jsonb not null,
    proof_json             text not null,
    assessment_basis_json  text not null,
    assessment_hash        text not null,
    work_snapshot          jsonb not null,
    planning_interval      jsonb not null,
    actor_id               uuid not null,
    reason                 text not null,
    created_at             timestamptz not null,
    primary key (id),
    check ((assessment_hash ~ '^[a-f0-9]{64}$')),
    check (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 1000))),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table chemical_safety_permit
(
    id                       uuid not null,
    qualification_permit_id  uuid not null,
    target_type              text not null,
    target_id                uuid not null,
    target_version           bigint not null,
    action                   text not null,
    proof                    jsonb not null,
    proof_hash               text not null,
    actor_id                 uuid not null,
    occurred_at              timestamptz not null,
    primary key (id),
    check ((proof_hash ~ '^[0-9a-f]{64}$')),
    foreign key (actor_id) references app_user(id),
    foreign key (qualification_permit_id) references driver_qualification_permit(id)
);

create table chemical_safety_policy_binding
(
    branch_id       uuid not null,
    version         bigint not null,
    source_id       uuid not null,
    source_version  bigint not null,
    actor_id        uuid not null,
    reason          text not null,
    created_at      timestamptz not null,
    operation_id    uuid,
    primary key (branch_id, version),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (source_id, source_version) references chemical_safety_source(id, version)
);

create table chemical_safety_reassessment
(
    id              uuid not null,
    target_type     text not null,
    target_id       uuid not null,
    source_id       uuid not null,
    source_version  bigint not null,
    reason          text not null,
    occurred_at     timestamptz not null,
    primary key (id),
    foreign key (source_id, source_version) references chemical_safety_source(id, version)
);

create table chemical_safety_reassessment_publication
(
    reassessment_id  uuid not null,
    context_id       uuid not null,
    context_version  bigint not null,
    published_at     timestamptz not null,
    primary key (reassessment_id),
    foreign key (reassessment_id) references chemical_safety_reassessment(id)
);

create table chemical_safety_review_decision
(
    id               uuid not null,
    context_id       uuid not null,
    context_version  bigint not null,
    proof            jsonb not null,
    proof_hash       text not null,
    actor_id         uuid not null,
    reason           text not null,
    occurred_at      timestamptz not null,
    operation_id     uuid,
    primary key (id),
    check ((proof_hash ~ '^[a-f0-9]{64}$')),
    check (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 1000))),
    foreign key (actor_id) references app_user(id),
    foreign key (context_id, context_version) references chemical_safety_source(id, version)
);

create table chemical_safety_source
(
    id                uuid not null,
    version           bigint not null,
    kind              text not null,
    state             text not null,
    branch_id         uuid not null,
    source_reference  text not null,
    valid_from        timestamptz not null,
    valid_to          timestamptz not null,
    body              jsonb not null,
    reason            text not null,
    actor_id          uuid not null,
    created_at        timestamptz not null,
    operation_id      uuid,
    primary key (id, version),
    check ((valid_from < valid_to)),
    check (kind in ('POLICY', 'PRODUCT', 'CREDENTIAL', 'SDS', 'INSTRUCTIONS', 'TANK', 'COMPATIBILITY', 'CARGO_HISTORY', 'CLEANING', 'CLEANING_EXCEPTION', 'PERMIT', 'INSURANCE', 'CONTEXT')),
    -- kind BAZADA: jadval bo'sh
    check (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 1000))),
    check (((length(trim(both from source_reference)) >= 1) and (length(trim(both from source_reference)) <= 512))),
    check (state in ('DRAFT', 'APPROVED', 'REVOKED')),
    -- state BAZADA: jadval bo'sh
    check ((version >= 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table chemical_safety_yard_permission
(
    id           uuid not null,
    trip_id      uuid not null,
    site_id      uuid not null,
    operation    text not null,
    proof        jsonb not null,
    actor_id     uuid not null,
    occurred_at  timestamptz not null,
    primary key (id),
    check (operation in ('ENTER', 'LOAD', 'UNLOAD')),
    -- operation BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (site_id) references yard_site(id),
    foreign key (trip_id) references trip(id)
);

create table chemical_source_operation_original
(
    operation_id   uuid not null,
    actor_id       uuid not null,
    action         text not null,
    object_id      uuid not null,
    branch_id      uuid not null,
    original       jsonb not null,
    payload_hash   text not null,
    closure_only   boolean not null,
    registered_at  timestamptz not null,
    primary key (operation_id),
    check (action in ('SOURCE_WRITE', 'SOURCE_APPROVE', 'SOURCE_REVOKE', 'POLICY_BIND', 'CONTEXT_BIND_TRIP', 'CONTEXT_BIND_ROUTE', 'CONTEXT_BIND_WAYBILL', 'SOURCE_REASSESS', 'QUALITY_RULE_WRITE', 'QUALITY_RULE_APPROVE', 'QUALITY_RULE_WITHDRAW', 'QUALITY_POLICY_BIND', 'QUALITY_BATCH_REGISTER', 'QUALITY_PASSPORT_WRITE', 'QUALITY_PASSPORT_APPROVE', 'QUALITY_PASSPORT_WITHDRAW', 'QUALITY_RELEASE_RECORD', 'QUALITY_RELEASE_APPROVE', 'QUALITY_RELEASE_WITHDRAW', 'QUALITY_LOAD_BIND_ROUTE', 'QUALITY_LOAD_BIND_TRIP', 'QUALITY_LOAD_BIND_WAYBILL', 'QUALITY_NOTICE_REVIEW')),
    -- action BAZADA: jadval bo'sh
    check ((jsonb_typeof(original) = 'object')),
    check ((payload_hash ~ '^[a-f0-9]{64}$')),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table chemical_source_operation_receipt
(
    operation_id    uuid not null,
    state           text not null,
    result          jsonb,
    closure_reason  text,
    actor_id        uuid not null,
    recorded_at     timestamptz not null,
    primary key (operation_id),
    check ((((state = 'applied') and (result is not null) and (jsonb_typeof(result) = 'object') and (closure_reason is null)) or ((state = 'not_executed') and (result is null) and (closure_reason is not null) and ((length(btrim(closure_reason)) >= 1) and (length(btrim(closure_reason)) <= 1000))))),
    check (state in ('APPLIED', 'NOT_EXECUTED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (operation_id) references chemical_source_operation_original(operation_id)
);

create table critical_action_grant
(
    id                   uuid not null,
    policy_version       bigint not null,
    action               varchar(64) not null,
    role                 varchar(64),
    user_id              uuid,
    branch_id            uuid,
    site_id              uuid,
    all_branches         boolean not null,
    own_object_only      boolean not null,
    valid_from           timestamptz not null,
    valid_until          timestamptz,
    authority_reference  text not null,
    state                varchar(16) not null,
    created_by           uuid not null,
    approved_by          uuid,
    approved_at          timestamptz,
    updated_at           timestamptz not null,
    primary key (id),
    check (((role is null) <> (user_id is null))),
    check ((all_branches or (branch_id is not null))),
    check (((valid_until is null) or (valid_until > valid_from))),
    check ((((state) <> 'approved') or ((approved_by is not null) and (approved_by <> created_by) and (approved_by is distinct from user_id)))),
    check ((policy_version > 0)),
    check (state in ('DRAFT', 'APPROVED', 'REVOKED'))
    -- state BAZADA: jadval bo'sh
);

create table critical_action_grant_revision
(
    id           uuid not null,
    grant_id     uuid not null,
    version      bigint not null,
    action       varchar(64) not null,
    actor_id     uuid not null,
    reason       text not null,
    occurred_at  timestamptz not null,
    snapshot     jsonb not null,
    primary key (id),
    check ((length(trim(both from reason)) > 0)),
    foreign key (grant_id) references critical_action_grant(id)
);

create table critical_audit_event
(
    id                  uuid not null,
    actor_id            varchar(128) not null,
    actor_kind          varchar(16) not null,
    action              varchar(64) not null,
    object_type         varchar(64) not null,
    object_id           uuid,
    object_version      bigint,
    branch_id           uuid,
    site_id             uuid,
    operation_id        uuid,
    correlation_id      varchar(128) not null,
    policy_version      bigint not null,
    outcome             varchar(32) not null,
    reason_code         varchar(128) not null,
    before_json         jsonb not null,
    after_json          jsonb not null,
    rule_versions_json  jsonb not null,
    occurred_at         timestamptz not null,
    primary key (id),
    check (actor_kind in ('HUMAN', 'MACHINE', 'SYSTEM')),
    -- actor_kind BAZADA: HUMAN 5170 | ISHLATILMAGAN: MACHINE, SYSTEM
    check (outcome in ('ALLOWED', 'DENIED', 'HTTP_ACCEPTED', 'HTTP_REJECTED'))
    -- outcome BAZADA: ALLOWED 2338, HTTP_ACCEPTED 2268, HTTP_REJECTED 542, DENIED 22
);

create table critical_authorization_operation
(
    operation_id    uuid not null,
    actor_id        uuid not null,
    grant_id        uuid not null,
    request_hash    varchar(64) not null,
    response_json   jsonb not null,
    recorded_at     timestamptz not null,
    state           varchar(16) not null,
    original_json   jsonb not null,
    closure_reason  text,
    primary key (operation_id),
    check ((((state) <> 'not_executed') or (length(trim(both from closure_reason)) > 0))),
    check (state in ('APPLIED', 'NOT_EXECUTED'))
    -- state BAZADA: jadval bo'sh
);

-- ---------------------------------------------------------------------
-- Mijozlar (buyurtmachilar) ma'lumotlari: nomi, INN, bank hisobi, aloqa shaxsi.
-- kind — mijoz turi: EXTERNAL (tashqi), INTERNAL (ichki bo'lim), B2C, GOV.
-- ---------------------------------------------------------------------
create table customer
(
    id              uuid not null,
    active          boolean not null,
    address         varchar(1000),
    bank_account    varchar(64),
    contact_email   varchar(255),
    contact_person  varchar(255),
    contact_phone   varchar(64),
    created_at      timestamptz not null,
    inn             varchar(32),
    kind            varchar(32) not null,
    name            varchar(255) not null,
    updated_at      timestamptz not null,
    primary key (id),
    check (kind in ('EXTERNAL', 'INTERNAL', 'B2C', 'GOV'))
    -- kind BAZADA: EXTERNAL 2 | ISHLATILMAGAN: INTERNAL, B2C, GOV
);

-- ---------------------------------------------------------------------
-- Mijoz bilan davr uchun hisob-kitob akti: qancha reys, qancha km, qancha tonna,
-- qancha soat va umumiy summa. period_from/period_to davrni, tariff_id qaysi tarif
-- qo'llanganini ko'rsatadi.
-- MIJOZGA QANCHA HISOBLANGANI SO'RALSA SHU JADVALDAN OLINADI.
-- ---------------------------------------------------------------------
create table customer_settlement_act
(
    id                 uuid not null,
    created_at         timestamptz not null,
    created_by         varchar(128),
    currency           varchar(8) not null,
    customer_id        uuid not null,
    payload_json       text,
    period_from        date not null,
    period_to          date not null,
    tariff_id          uuid not null,
    total_amount       numeric(14,2) not null,
    total_hours        numeric(14,3) not null,
    total_km           numeric(14,3) not null,
    total_weight_tons  numeric(14,3) not null,
    trip_count         integer not null,
    primary key (id)
);

create table daily_exploitation_plan
(
    id                     uuid not null,
    branch_id              uuid not null,
    created_at             timestamptz not null,
    created_by             varchar(128),
    notes                  varchar(1024),
    plan_date              date not null,
    sent_by                varchar(128),
    sent_to_dispatcher_at  timestamptz,
    status                 varchar(32) not null,
    total_vehicles         integer,
    updated_at             timestamptz not null,
    updated_by             varchar(128),
    primary key (id),
    check (status in ('DRAFT', 'READY_FOR_DISPATCH', 'FINALIZED'))
    -- status BAZADA: READY_FOR_DISPATCH 1, DRAFT 1 | ISHLATILMAGAN: FINALIZED
);

create table daily_exploitation_plan_item
(
    id                   uuid not null,
    assigned_trip_id     uuid,
    branch_id            uuid not null,
    created_at           timestamptz not null,
    notes                varchar(1024),
    planned_metric_type  varchar(32) not null,
    planned_value        numeric(12,2),
    status               varchar(32) not null,
    updated_at           timestamptz not null,
    vehicle_id           uuid not null,
    workshop_code        varchar(64),
    workshop_name        varchar(128),
    plan_id              uuid not null,
    primary key (id),
    check (planned_metric_type in ('KM', 'MOTOSOAT', 'KM_AND_MOTOSOAT')),
    -- planned_metric_type BAZADA: MOTOSOAT 1 | ISHLATILMAGAN: KM, KM_AND_MOTOSOAT
    check (status in ('READY', 'ASSIGNED_TO_TRIP', 'CANCELLED')),
    -- status BAZADA: READY 1 | ISHLATILMAGAN: ASSIGNED_TO_TRIP, CANCELLED
    foreign key (plan_id) references daily_exploitation_plan(id)
);

create table default_material_warehouse_backfill
(
    entity_type   varchar(32) not null,
    entity_id     uuid not null,
    warehouse_id  uuid not null,
    recorded_at   timestamptz not null,
    recorded_by   text not null,
    primary key (entity_type, entity_id)
);

create table delivery_otp
(
    id                   uuid not null,
    attempt_count        integer not null,
    code_hash            varchar(64) not null,
    created_at           timestamptz not null,
    expires_at           timestamptz not null,
    max_attempts         integer not null,
    recipient_full_name  varchar(256) not null,
    recipient_phone      varchar(32) not null,
    requested_by         varchar(128),
    status               varchar(16) not null,
    telegram_chat_id     bigint not null,
    trip_id              uuid not null,
    verified_at          timestamptz,
    primary key (id),
    check (status in ('PENDING', 'VERIFIED', 'EXPIRED', 'FAILED'))
    -- status BAZADA: jadval bo'sh
);

create table demurrage
(
    id               uuid not null,
    allowance_hours  numeric(10,2),
    amount           numeric(14,2),
    carrier_id       uuid,
    created_at       timestamptz not null,
    currency         varchar(8),
    delay_hours      numeric(10,2),
    ended_at         timestamptz,
    hourly_rate      numeric(14,2),
    kind             varchar(32),
    location_id      uuid,
    reason           varchar(1000),
    shipment_id      uuid,
    started_at       timestamptz,
    status           varchar(16) not null,
    trip_id          uuid not null,
    updated_at       timestamptz,
    vehicle_id       uuid not null,
    primary key (id),
    check (status in ('PENDING', 'APPROVED', 'REJECTED', 'PAID', 'CHARGED'))
    -- status BAZADA: jadval bo'sh
);

create table department_manager
(
    id             uuid not null,
    active         boolean not null,
    created_at     timestamptz not null,
    created_by     varchar(128),
    department_id  uuid not null,
    full_name      varchar(256) not null,
    updated_at     timestamptz not null,
    primary key (id)
);

create table dock
(
    id                          uuid not null,
    created_at                  timestamptz not null,
    location_id                 uuid,
    name                        varchar(128) not null,
    status                      varchar(32),
    updated_at                  timestamptz,
    allowed_operations_json     text,
    allowed_product_codes_json  text,
    branch_id                   uuid,
    calendar_json               text,
    capacity                    integer,
    config_valid_from           timestamptz,
    config_valid_to             timestamptz,
    kind                        varchar(16),
    regulation_reference        varchar(512),
    site_id                     uuid,
    updated_by                  uuid,
    object_version              bigint not null,
    primary key (id)
    -- status BAZADA: jadval bo'sh
);

create table dock_booking
(
    id                    uuid not null,
    actual_end_at         timestamptz,
    actual_start_at       timestamptz,
    arrived_at            timestamptz,
    branch_id             uuid not null,
    carrier_id            uuid,
    composition_identity  varchar(128) not null,
    created_at            timestamptz not null,
    created_by            uuid not null,
    directed_at           timestamptz,
    dock_id               uuid not null,
    end_at                timestamptz not null,
    gate_pass_id          uuid,
    notes                 varchar(1000),
    operation_type        varchar(16),
    shipment_id           uuid,
    site_id               uuid not null,
    start_at              timestamptz not null,
    status                varchar(32) not null,
    trip_id               uuid not null,
    updated_at            timestamptz not null,
    object_version        bigint not null,
    waiting_at            timestamptz,
    primary key (id),
    -- status BAZADA: jadval bo'sh
    foreign key (dock_id) references dock(id),
    foreign key (gate_pass_id) references gate_pass(id),
    foreign key (site_id) references yard_site(id),
    foreign key (trip_id) references trip(id)
);

create table dock_slot
(
    id                  uuid not null,
    created_at          timestamptz not null,
    location_id         uuid,
    name                varchar(128) not null,
    notes               varchar(1000),
    status              varchar(16) not null,
    updated_at          timestamptz,
    current_vehicle_id  uuid,
    primary key (id),
    check (status in ('AVAILABLE', 'OCCUPIED', 'MAINTENANCE')),
    -- status BAZADA: jadval bo'sh
    foreign key (current_vehicle_id) references transport_vehicle(id)
);

-- ---------------------------------------------------------------------
-- HUJJAT AUDITI — hujjat ustidagi amallar tarixi.
-- action (amal), actor (kim bajargan), occurred_at (qachon),
-- details (tafsilot), document_id (qaysi hujjat).
-- DIQQAT: bu YAGONA hujjat audit jadvali. Ilgari `document_audit_entry`
-- degan ikkinchi jadval bor edi — u bazadan o'chirilgan.
-- ---------------------------------------------------------------------
create table document_audit
(
    id           uuid not null,
    action       varchar(64) not null,
    actor        varchar(128) not null,
    details      varchar(2000),
    occurred_at  timestamptz not null,
    document_id  uuid not null,
    primary key (id),
    check (action in ('GENERATED', 'UPDATED', 'DELIVERY_CONFIRMED', 'STATUS_CHANGED', 'SIGNED', 'TEMPLATE_CREATED', 'TEMPLATE_UPDATED', 'WEIGHING_ACT_ACCEPTED')),
    -- action BAZADA: jadval bo'sh
    foreign key (document_id) references transport_document(id)
);

-- ---------------------------------------------------------------------
-- Hujjat shablonlari (yo'l varaqasi, TTN, marshrut varaqasi, transport akti,
-- yetkazish tasdig'i). body_template — shablon matni, template_version — versiya.
-- Faol shablonlar active=true.
-- ---------------------------------------------------------------------
create table document_template
(
    id                uuid not null,
    active            boolean not null,
    body_template     varchar(10000) not null,
    code              varchar(64) not null,
    created_at        timestamptz not null,
    created_by        varchar(128) not null,
    document_type     varchar(64) not null,
    name              varchar(255) not null,
    template_version  integer not null,
    updated_at        timestamptz not null,
    updated_by        varchar(128) not null,
    primary key (id),
    check (document_type in ('WAYBILL', 'TTN', 'ROUTE_SHEET', 'TRANSPORT_ACT', 'DELIVERY_CONFIRMATION', 'WEIGHING_ACT'))
    -- document_type BAZADA: WAYBILL 1 | ISHLATILMAGAN: TTN, ROUTE_SHEET, TRANSPORT_ACT, DELIVERY_CONFIRMATION, WEIGHING_ACT
);

-- ---------------------------------------------------------------------
-- Transport hujjatining har bir versiyasi: fayl nomi, hajmi, SHA-256 checksum,
-- saqlash kaliti (storage_key) va payload JSON. Bitta hujjatda bir nechta versiya
-- bo'lishi mumkin — version_number bo'yicha tartiblanadi.
-- HUJJATNING OXIRGI VERSIYASI KERAK BO'LSA version_number MAX bo'yicha olinadi.
-- ---------------------------------------------------------------------
create table document_version
(
    id                uuid not null,
    checksum_sha256   varchar(128) not null,
    created_at        timestamptz not null,
    created_by        varchar(128) not null,
    file_name         varchar(255) not null,
    file_size_bytes   bigint not null,
    mime_type         varchar(128) not null,
    payload_json      varchar(10000),
    storage_key       varchar(1024) not null,
    version_number    integer not null,
    document_id       uuid not null,
    weighing_pair_id  uuid,
    source_kind       varchar(64),
    source_digest     varchar(64),
    primary key (id),
    check ((((weighing_pair_id is null) and (source_kind is null) and (source_digest is null)) or ((weighing_pair_id is not null) and ((source_kind) = 'yard_weighing_pair_v1') and ((source_digest) ~ '^[a-f0-9]{64}$')))),
    foreign key (weighing_pair_id) references yard_weighing_pair(id),
    foreign key (document_id) references transport_document(id)
);

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
create table driver
(
    id                               uuid not null,
    birth_date                       date,
    created_at                       timestamptz not null,
    department_id                    uuid,
    driver_availability_status       varchar(32) not null,
    driver_license_number            varchar(64) not null,
    employee_id                      varchar(64),
    employment_status                varchar(32) not null,
    erp_employee_id                  uuid,
    full_name                        varchar(256) not null,
    license_given_address            varchar(512),
    license_valid_until              date,
    medical_certificate_valid_until  date,
    medical_cleared_today            boolean not null,
    passport_given_address           varchar(512),
    phone                            varchar(32) not null,
    pinfl                            varchar(32),
    position                         varchar(128) not null,
    table_number                     varchar(64),
    updated_at                       timestamptz not null,
    user_id                          uuid,
    branch_id                        uuid,
    deleted_at                       timestamptz,
    primary key (id),
    check (driver_availability_status in ('AVAILABLE', 'RESERVED_FOR_TRIP', 'ON_TRIP', 'REST_REQUIRED', 'SICK_LEAVE', 'BLOCKED', 'UNAVAILABLE')),
    -- driver_availability_status BAZADA: AVAILABLE 263, BLOCKED 1 | ISHLATILMAGAN: RESERVED_FOR_TRIP, ON_TRIP, REST_REQUIRED, SICK_LEAVE, UNAVAILABLE
    check (employment_status in ('ACTIVE', 'ON_LEAVE', 'SUSPENDED', 'TERMINATED'))
    -- employment_status BAZADA: ACTIVE 264 | ISHLATILMAGAN: ON_LEAVE, SUSPENDED, TERMINATED
);

-- ---------------------------------------------------------------------
-- Haydovchiga biriktirilgan mashinalar ro'yxati (bitta haydovchida bir nechta
-- mashina bo'lishi mumkin). Asosiy mashina driver.transport_vehicle.assigned_driver_id da.
-- ---------------------------------------------------------------------
create table driver_assigned_vehicles
(
    driver_id   uuid not null,
    vehicle_id  uuid,
    foreign key (driver_id) references driver(id)
);

create table driver_command_applied_receipt
(
    operation_id  uuid not null,
    trip_id       uuid not null,
    actor_id      uuid not null,
    command_hash  varchar(64) not null,
    action        varchar(16) not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    check (action in ('START', 'WAIT', 'RESUME', 'EXTEND', 'RETURN', 'COMPLETE', 'ISSUE')),
    -- action BAZADA: RETURN 1, START 1, RESUME 1, WAIT 1, COMPLETE 1 | ISHLATILMAGAN: EXTEND, ISSUE
    check (((command_hash) ~ '^[0-9a-f]{64}$')),
    foreign key (operation_id) references driver_command_operation_key(operation_id)
);

create table driver_command_closure
(
    operation_id      uuid not null,
    trip_id           uuid not null,
    actor_id          uuid not null,
    command_hash      varchar(64) not null,
    action            varchar(16) not null,
    original_version  bigint not null,
    reason            varchar(1024) not null,
    closed_at         timestamptz not null,
    primary key (operation_id),
    check (action in ('START', 'WAIT', 'RESUME', 'EXTEND', 'RETURN', 'COMPLETE', 'ISSUE')),
    -- action BAZADA: jadval bo'sh
    check (((command_hash) ~ '^[0-9a-f]{64}$')),
    check ((original_version >= 0)),
    check ((length(btrim((reason))) > 0)),
    foreign key (operation_id) references driver_command_operation_key(operation_id)
);

create table driver_command_operation_key
(
    operation_id  uuid not null,
    kind          varchar(16) not null,
    primary key (operation_id),
    check (kind in ('EVENT', 'CLOSED'))
    -- kind BAZADA: EVENT 10089 | ISHLATILMAGAN: CLOSED
);

-- ---------------------------------------------------------------------
-- Haydovchi yakunlagan reyslarning qisqa tarixi (reys raqami, mashina, yakunlangan
-- vaqt). HAYDOVCHI QANCHA REYS BAJARGANI SO'RALSA SHU JADVALDAN TEZ OLINADI,
-- to'liq reys ma'lumoti esa trip jadvalida.
-- ---------------------------------------------------------------------
create table driver_completed_trip
(
    id            uuid not null,
    completed_at  timestamptz not null,
    notes         varchar(1024),
    trip_id       uuid not null,
    trip_number   varchar(64) not null,
    vehicle_id    uuid,
    driver_id     uuid not null,
    primary key (id),
    foreign key (driver_id) references driver(id)
);

-- ---------------------------------------------------------------------
-- Haydovchining identifikatsiya vositalari: RFID karta yoki QR kod. Yoqilg'i
-- quyish shoxobchasida haydovchini tanish uchun ishlatiladi. token_hash — kalitning
-- hash'i, active/revoked_at — faollik holati, expires_at — muddati.
-- YOQILG'I RUXSATNOMASI (fuel_authorization) SHU CREDENTIAL ORQALI BERILADI.
-- ---------------------------------------------------------------------
create table driver_credential
(
    id               uuid not null,
    active           boolean not null,
    created_at       timestamptz not null,
    credential_type  varchar(16) not null,
    driver_id        uuid not null,
    expires_at       timestamptz,
    issued_at        timestamptz not null,
    issued_by        varchar(128),
    label            varchar(128),
    revoked_at       timestamptz,
    token_hash       varchar(128) not null,
    updated_at       timestamptz not null,
    primary key (id),
    check (credential_type in ('RFID', 'QR_CODE'))
    -- credential_type BAZADA: jadval bo'sh
);

-- ---------------------------------------------------------------------
-- Haydovchi hujjatlarining skanlari: guvohnoma, passport, tibbiy sertifikat va
-- boshqalar. s3_url — faylning manzili. Hujjat MUDDATLARI bu jadvalda emas,
-- driver jadvalida (license_valid_until, medical_certificate_valid_until).
-- ---------------------------------------------------------------------
create table driver_document
(
    id           uuid not null,
    file_name    varchar(256) not null,
    kind         varchar(32) not null,
    mime_type    varchar(128) not null,
    s3_url       varchar(1024) not null,
    size_bytes   bigint not null,
    uploaded_at  timestamptz not null,
    driver_id    uuid not null,
    primary key (id),
    check (kind in ('DRIVER_LICENSE_SCAN', 'PASSPORT_SCAN', 'MEDICAL_CERTIFICATE_SCAN', 'OTHER')),
    -- kind BAZADA: DRIVER_LICENSE_SCAN 288, MEDICAL_CERTIFICATE_SCAN 285 | ISHLATILMAGAN: PASSPORT_SCAN, OTHER
    foreign key (driver_id) references driver(id)
);

-- ---------------------------------------------------------------------
-- Haydovchining haydovchilik guvohnomasi toifalari: A, B, BE, C, CE, D, DE.
-- BITTA HAYDOVCHIDA BIR NECHTA TOIFA BO'LADI. Marshrut talab qilgan toifa
-- route.required_driver_category da — mos haydovchi tanlashda shu jadval bilan
-- JOIN qilinadi.
-- ---------------------------------------------------------------------
create table driver_license_category
(
    driver_id         uuid not null,
    license_category  varchar(8) not null,
    primary key (driver_id, license_category),
    check (license_category in ('A', 'B', 'BE', 'C', 'CE', 'D', 'DE', 'E')),
    -- license_category BAZADA: B 243, C 238, D 126, CE 87, BE 74, A 69, DE 61, E 43
    foreign key (driver_id) references driver(id)
);

create table driver_qualification_document_event
(
    id                 uuid not null,
    document_id        uuid not null,
    driver_id          uuid not null,
    actor_id           uuid not null,
    occurred_at        timestamptz not null,
    reason             varchar(1000) not null,
    sha256             varchar(64) not null,
    document_snapshot  jsonb not null,
    primary key (id),
    check ((btrim((reason)) <> '')),
    check (((sha256) ~ '^[0-9a-f]{64}$'))
);

create table driver_qualification_permit
(
    id              uuid not null,
    target_type     varchar(24) not null,
    target_id       uuid not null,
    target_version  bigint not null,
    action          varchar(24) not null,
    proof_json      text not null,
    proof_hash      varchar(64) not null,
    actor_id        uuid not null,
    occurred_at     timestamptz not null,
    primary key (id)
);

create table driver_qualification_revision
(
    id             uuid not null,
    source_id      uuid not null,
    version_after  bigint not null,
    action         varchar(24) not null,
    before_json    jsonb,
    after_json     jsonb not null,
    actor_id       uuid not null,
    occurred_at    timestamptz not null,
    reason         varchar(1000) not null,
    primary key (id),
    foreign key (source_id) references driver_qualification_source(id)
);

create table driver_qualification_source
(
    id                    uuid not null,
    kind                  varchar(24) not null,
    driver_id             uuid,
    branch_id             uuid not null,
    vehicle_id            uuid,
    trailer_id            uuid,
    version               bigint not null,
    state                 varchar(24) not null,
    document_id           uuid,
    issuer                varchar(256),
    source_reference      varchar(512),
    valid_from            timestamptz,
    valid_to              timestamptz,
    categories            text[],
    availability          varchar(24),
    updated_by            uuid not null,
    updated_at            timestamptz not null,
    document_snapshot     jsonb,
    composition_snapshot  jsonb,
    primary key (id),
    foreign key (branch_id) references reference_data(id),
    foreign key (driver_id) references driver(id)
);

-- ---------------------------------------------------------------------
-- Haydovchi smenalari: reja va amaldagi boshlanish/tugash vaqti, ishlangan soat,
-- tungi soat (night_hours), qo'shimcha soat (overtime_hours).
-- shift_type: DAY, NIGHT, SPLIT, STANDBY, DAY_OFF, VACATION, SICK_LEAVE.
-- status: PLANNED, CONFIRMED, COMPLETED, CANCELLED.
-- HAYDOVCHI ISH VAQTI VA QO'SHIMCHA SOATLAR SO'RALSA SHU JADVALDAN OLINADI —
-- ish haqi hisobi payroll_rate bilan birga qilinadi.
-- ---------------------------------------------------------------------
create table driver_shift
(
    id                        uuid not null,
    actual_end_at             timestamptz,
    actual_hours              numeric(8,2),
    actual_start_at           timestamptz,
    created_at                timestamptz not null,
    driver_id                 uuid not null,
    driver_name               varchar(256) not null,
    night_hours               numeric(8,2),
    notes                     varchar(1024),
    overtime_hours            numeric(8,2),
    planned_end_at            timestamptz,
    planned_hours             numeric(8,2) not null,
    planned_start_at          timestamptz,
    shift_date                date not null,
    shift_type                varchar(32) not null,
    status                    varchar(32) not null,
    updated_at                timestamptz not null,
    version                   bigint not null,
    actual_start_source_json  text,
    actual_end_source_json    text,
    primary key (id),
    check (shift_type in ('DAY', 'NIGHT', 'SPLIT', 'STANDBY', 'DAY_OFF', 'VACATION', 'SICK_LEAVE')),
    -- shift_type BAZADA: DAY 6 | ISHLATILMAGAN: NIGHT, SPLIT, STANDBY, DAY_OFF, VACATION, SICK_LEAVE
    check (status in ('PLANNED', 'CONFIRMED', 'COMPLETED', 'CANCELLED'))
    -- status BAZADA: CONFIRMED 4, PLANNED 2 | ISHLATILMAGAN: COMPLETED, CANCELLED
);

-- ---------------------------------------------------------------------
-- Elektron raqamli imzo (E-IMZO) sertifikati ma'lumotlari: STIR/PINFL, tashkilot
-- yoki jismoniy shaxs nomi, sertifikat seriya raqami, imzo natijasi (success,
-- error_code). app_user ga bog'langan.
-- HUJJATNI KIM IMZOLAGANI transport_document.signature_* ustunlarida.
-- (Ilgari `eimzo` deb atalardi — sxema ko'chirishda nomi o'zgargan.)
-- ---------------------------------------------------------------------
create table eimzo_signature
(
    id                          uuid not null,
    created_at                  timestamptz not null,
    data                        varchar(20000),
    director_name               varchar(256),
    director_pinfl              varchar(32),
    error_code                  integer,
    error_message               varchar(512),
    is_individual_entrepreneur  boolean not null,
    is_legal                    boolean not null,
    name                        varchar(256),
    pinfl                       varchar(32),
    secret_key                  varchar(32) not null,
    serial_number               varchar(128),
    success                     boolean not null,
    timestamp                   varchar(128),
    tin                         varchar(32),
    tin_pinfl                   varchar(32),
    updated_at                  timestamptz not null,
    user_id                     uuid,
    primary key (id),
    foreign key (user_id) references app_user(id)
);

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
create table emergency_medical_case
(
    id                          uuid not null,
    blocking_ends_at            timestamptz,
    branch_id                   uuid not null,
    cancellation_reason         text,
    created_at                  timestamptz not null,
    created_by                  uuid not null,
    decision_at                 timestamptz,
    decision_comment            text,
    department_id               uuid,
    department_name             varchar(256),
    driver_full_name            varchar(256) not null,
    driver_id                   uuid not null,
    emergency_aid_description   text not null,
    illness_type                varchar(512) not null,
    incident_at                 timestamptz not null,
    medical_inspection_id       uuid,
    observation_started_at      timestamptz not null,
    resolved_at                 timestamptz,
    shift_id                    uuid,
    specialist_referral_note    text,
    status                      varchar(32) not null,
    trip_id                     uuid,
    updated_at                  timestamptz not null,
    updated_by                  uuid,
    vehicle_id                  uuid,
    vehicle_number              varchar(32),
    version                     bigint not null,
    medical_inspection_version  bigint,
    return_proof_json           text,
    primary key (id),
    check (status in ('OBSERVATION_REQUIRED', 'REFERRED_TO_SPECIALIST', 'WORK_SUSPENDED', 'WORK_ALLOWED', 'CANCELLED'))
    -- status BAZADA: WORK_ALLOWED 5, REFERRED_TO_SPECIALIST 1, CANCELLED 1 | ISHLATILMAGAN: OBSERVATION_REQUIRED, WORK_SUSPENDED
);

create table emergency_medical_case_branch_repair
(
    case_id                 uuid not null,
    old_branch_id           uuid not null,
    new_branch_id           uuid not null,
    evidence_inspection_id  uuid not null,
    repaired_at             timestamptz not null,
    repaired_by             text not null,
    reason                  text not null,
    primary key (case_id),
    foreign key (evidence_inspection_id) references medical_inspection(id),
    foreign key (case_id) references emergency_medical_case(id),
    foreign key (new_branch_id) references reference_data(id)
);

-- ---------------------------------------------------------------------
-- Shoshilinch tibbiy holat (emergency_medical_case) holatining
-- O'ZGARISHLAR TARIXI: qaysi holatdan qaysi holatga (from_status ->
-- to_status), qachon va kim o'zgartirgani, izoh bilan.
-- ---------------------------------------------------------------------
create table emergency_medical_status_history
(
    id                         uuid not null,
    changed_at                 timestamptz not null,
    changed_by                 uuid not null,
    changed_by_name            varchar(256) not null,
    comment                    text,
    emergency_medical_case_id  uuid not null,
    from_status                varchar(32),
    to_status                  varchar(32) not null,
    action                     varchar(16),
    after_json                 text,
    before_json                text,
    case_version               bigint,
    recorded_at                timestamptz,
    primary key (id),
    check (from_status in ('OBSERVATION_REQUIRED', 'REFERRED_TO_SPECIALIST', 'WORK_SUSPENDED', 'WORK_ALLOWED', 'CANCELLED')),
    -- from_status BAZADA: OBSERVATION_REQUIRED 7, REFERRED_TO_SPECIALIST 2, WORK_SUSPENDED 1; NULL 1 | ISHLATILMAGAN: WORK_ALLOWED, CANCELLED
    check (to_status in ('OBSERVATION_REQUIRED', 'REFERRED_TO_SPECIALIST', 'WORK_SUSPENDED', 'WORK_ALLOWED', 'CANCELLED'))
    -- to_status BAZADA: OBSERVATION_REQUIRED 7, WORK_ALLOWED 5, REFERRED_TO_SPECIALIST 3, CANCELLED 1, WORK_SUSPENDED 1
);

create table emergency_operational_response
(
    id            uuid not null,
    case_id       uuid not null,
    case_version  bigint not null,
    trip_id       uuid,
    branch_id     uuid not null,
    operation_id  varchar(128) not null,
    actual_at     timestamptz not null,
    reference     text not null,
    reason        text not null,
    actor_id      uuid not null,
    recorded_at   timestamptz not null,
    primary key (id),
    check ((actual_at <= recorded_at)),
    check (((btrim(reference) <> '') and (btrim(reason) <> ''))),
    foreign key (actor_id) references app_user(id),
    foreign key (case_id) references emergency_medical_case(id),
    foreign key (trip_id) references trip(id)
);

-- ---------------------------------------------------------------------
-- Reys ma'lumotini tashqi ERP tizimiga yuborish navbati (outbox pattern).
-- status, attempt_count, last_error, next_attempt_at — yuborish holati.
-- ERP GA REYS KETMAGANI YOKI XATO BERGANI SO'RALSA SHU JADVALDAN OLINADI
-- (status <> yuborilgan yoki last_error to'ldirilgan qatorlar).
-- ---------------------------------------------------------------------
create table erp_trip_outbox
(
    id               uuid not null,
    attempt_count    integer not null,
    created_at       timestamptz not null,
    dispatched_at    timestamptz,
    event_id         varchar(36) not null,
    last_error       varchar(1000),
    next_attempt_at  timestamptz not null,
    payload_json     text not null,
    status           varchar(16) not null,
    trip_id          uuid not null,
    primary key (id)
    -- status BAZADA: jadval bo'sh
);

-- ---------------------------------------------------------------------
-- Mashina ma'lumotini tashqi ERP tizimiga yuborish navbati. Ishlash tartibi
-- erp_trip_outbox bilan bir xil.
-- ---------------------------------------------------------------------
create table erp_vehicle_outbox
(
    id               uuid not null,
    attempt_count    integer not null,
    created_at       timestamptz not null,
    dispatched_at    timestamptz,
    event_id         varchar(36) not null,
    last_error       varchar(1000),
    next_attempt_at  timestamptz not null,
    payload_json     text not null,
    status           varchar(16) not null,
    vehicle_id       uuid not null,
    primary key (id)
    -- status BAZADA: EXCHANGE_QUEUED 59
);

create table exploitation_batch_operation
(
    id            uuid not null,
    actor_id      uuid not null,
    payload_hash  varchar(64) not null,
    performed_at  timestamptz not null,
    result_json   text not null,
    primary key (id),
    foreign key (actor_id) references app_user(id)
);

create table file_document
(
    id                uuid not null,
    original_name     varchar(512) not null,
    display_name      varchar(512) not null,
    storage_key       varchar(512) not null,
    mime_type         varchar(128) not null,
    extension         varchar(32) not null,
    size_bytes        bigint not null,
    category          varchar(64) not null,
    description       varchar(2048),
    access_type       varchar(32) not null,
    uploaded_by_id    uuid not null,
    uploaded_by_name  varchar(256),
    branch_id         uuid,
    branch_name       varchar(256),
    department_id     uuid,
    department_name   varchar(256),
    checksum          varchar(64) not null,
    deleted           boolean not null,
    deleted_at        timestamptz,
    deleted_by_id     uuid,
    deleted_by_name   varchar(256),
    created_at        timestamptz not null,
    updated_at        timestamptz not null,
    primary key (id)
);

create table finance_analytics_closed_operation
(
    operation_id  uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table finance_analytics_report_snapshot
(
    id             uuid not null,
    branch_id      uuid not null,
    department_id  uuid,
    actor_id       uuid not null,
    original       jsonb not null,
    sources        jsonb not null,
    payload        jsonb not null,
    hash           text not null,
    captured_at    timestamptz not null,
    primary key (id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table finance_analytics_revision
(
    operation_id  uuid not null,
    series_id     uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    kind          text not null,
    revision      bigint not null,
    action        text not null,
    state         text not null,
    original      jsonb not null,
    payload       jsonb not null,
    sources       jsonb not null,
    document      jsonb not null,
    hash          text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    check (action in ('SAVE', 'APPROVE', 'REVOKE')),
    -- action BAZADA: SAVE 2 | ISHLATILMAGAN: APPROVE, REVOKE
    check (kind in ('PLAN', 'ENERGY_METHOD', 'ENERGY_FACT', 'FUEL_DEPARTMENT', 'CENSUS', 'EXCEPTION')),
    -- kind BAZADA: ENERGY_METHOD 2 | ISHLATILMAGAN: PLAN, ENERGY_FACT, FUEL_DEPARTMENT, CENSUS, EXCEPTION
    check ((revision > 0)),
    check (state in ('DRAFT', 'APPROVED', 'REVOKED')),
    -- state BAZADA: DRAFT 2 | ISHLATILMAGAN: APPROVED, REVOKED
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table finance_capacity_allocation
(
    id           uuid not null,
    entry_id     uuid not null,
    rule_id      uuid not null,
    branch_id    uuid not null,
    source_json  jsonb not null,
    source_hash  text not null,
    shares       jsonb not null,
    posted_by    uuid not null,
    posted_at    timestamptz not null,
    reason       text not null,
    primary key (id),
    check ((jsonb_typeof(shares) = 'array')),
    foreign key (entry_id) references transport_cost_entry(id),
    foreign key (posted_by) references app_user(id),
    foreign key (rule_id) references transport_cost_rule_head(id)
);

create table finance_capacity_allocation_release
(
    id             uuid not null,
    allocation_id  uuid not null,
    branch_id      uuid not null,
    released_by    uuid not null,
    released_at    timestamptz not null,
    reason         text not null,
    primary key (id),
    foreign key (allocation_id) references finance_capacity_allocation(id),
    foreign key (released_by) references app_user(id)
);

create table finance_cost_accounting_cancellation
(
    id                 uuid not null,
    entry_id           uuid not null,
    branch_id          uuid not null,
    owner              text not null,
    owner_epoch        bigint not null,
    provider           text not null,
    document_id        text not null,
    document_revision  bigint not null,
    document_line_id   text not null,
    confirmed_at       timestamptz not null,
    original_json      text not null,
    payload_hash       text not null,
    recorded_at        timestamptz not null,
    primary key (id),
    check ((payload_hash = encode(sha256(convert_to(original_json, 'utf8'::name)), 'hex'))),
    foreign key (entry_id) references transport_cost_entry(id)
);

create table finance_cost_command
(
    id              uuid not null,
    actor_id        uuid not null,
    branch_id       uuid not null,
    kind            text not null,
    original_json   text not null,
    payload_hash    text not null,
    state           text not null,
    result_json     jsonb,
    closure_reason  text,
    recorded_at     timestamptz not null,
    primary key (id),
    check ((payload_hash = encode(sha256(convert_to(original_json, 'utf8'::name)), 'hex'))),
    check ((((state = 'applied') and (result_json is not null) and (closure_reason is null)) or ((state = 'not_executed') and (result_json is null) and (length(closure_reason) > 0)))),
    foreign key (actor_id) references app_user(id)
);

create table finance_erp_cost_primary_census
(
    id                  uuid not null,
    branch_id           uuid not null,
    owner               text not null,
    owner_epoch         bigint not null,
    provider            text not null,
    from_at             timestamptz not null,
    to_at               timestamptz not null,
    document_reference  text not null,
    original_json       text not null,
    payload_hash        text not null,
    received_at         timestamptz not null,
    primary key (id),
    check ((to_at > from_at)),
    check (((to_at - from_at) <= '366 days'::interval)),
    check ((payload_hash = encode(sha256(convert_to(original_json, 'utf8'::name)), 'hex'))),
    check (owner in ('SAP', 'ONE_C')),
    -- owner BAZADA: jadval bo'sh
    check ((owner_epoch > 0))
);

create table finance_period
(
    id                uuid not null,
    organization_id   uuid not null,
    branch_id         uuid not null,
    month             date not null,
    time_zone         text not null,
    from_at           timestamptz not null,
    to_at             timestamptz not null,
    version           bigint not null,
    state             text not null,
    current_close_id  uuid,
    primary key (id),
    check ((to_at > from_at)),
    check ((month = (date_trunc('month', (month)::timestamp with time zone))::date)),
    check (state in ('OPEN', 'CLOSED')),
    -- state BAZADA: jadval bo'sh
    check ((version >= 0))
);

create table finance_period_close
(
    id                     uuid not null,
    period_id              uuid not null,
    period_version         bigint not null,
    policy_id              uuid not null,
    monthly_snapshot_id    uuid,
    calculation_version    text not null,
    snapshot_json          text not null,
    snapshot_hash          text not null,
    blockers_json          jsonb not null,
    approved_by            uuid not null,
    approved_at            timestamptz not null,
    reason                 text not null,
    analytics_snapshot_id  uuid,
    primary key (id),
    check ((num_nonnulls(monthly_snapshot_id, analytics_snapshot_id) = 1)),
    check ((snapshot_hash = encode(sha256(convert_to(snapshot_json, 'utf8'::name)), 'hex'))),
    foreign key (analytics_snapshot_id) references finance_analytics_report_snapshot(id),
    foreign key (approved_by) references app_user(id),
    foreign key (monthly_snapshot_id) references monthly_statement_approval(id),
    foreign key (period_id) references finance_period(id),
    foreign key (policy_id) references finance_period_policy(id)
);

create table finance_period_command
(
    id              uuid not null,
    actor_id        uuid not null,
    branch_id       uuid not null,
    kind            text not null,
    original_json   text not null,
    payload_hash    text not null,
    state           text not null,
    result_json     text,
    closure_reason  text,
    recorded_at     timestamptz not null,
    primary key (id),
    check ((payload_hash = encode(sha256(convert_to(original_json, 'utf8'::name)), 'hex'))),
    check ((((state = 'applied') and (result_json is not null) and (closure_reason is null)) or ((state = 'not_executed') and (result_json is null) and (length(closure_reason) > 0)))),
    check (state in ('APPLIED', 'NOT_EXECUTED')),
    -- state BAZADA: APPLIED 1 | ISHLATILMAGAN: NOT_EXECUTED
    foreign key (actor_id) references app_user(id)
);

create table finance_period_correction_use
(
    correction_id   uuid not null,
    period_id       uuid not null,
    fact_hash       text not null,
    domain          text not null,
    source          text not null,
    transaction_id  bigint not null,
    used_at         timestamptz not null,
    primary key (correction_id),
    foreign key (correction_id) references finance_period_request(id),
    foreign key (period_id) references finance_period(id)
);

create table finance_period_decision
(
    id                 uuid not null,
    request_id         uuid not null,
    period_id          uuid not null,
    resulting_version  bigint not null,
    decision           text not null,
    approved_by        uuid not null,
    approved_at        timestamptz not null,
    reason             text not null,
    primary key (id),
    check (decision in ('APPROVE', 'REJECT')),
    -- decision BAZADA: jadval bo'sh
    foreign key (approved_by) references app_user(id),
    foreign key (period_id) references finance_period(id),
    foreign key (request_id) references finance_period_request(id)
);

create table finance_period_late_fact
(
    id              uuid not null,
    period_id       uuid not null,
    period_version  bigint not null,
    branch_id       uuid not null,
    occurred_at     timestamptz not null,
    domain          text not null,
    source          text not null,
    fact_json       text not null,
    fact_hash       text not null,
    provider        text not null,
    receipt_key     text not null,
    received_at     timestamptz not null,
    primary key (id),
    check ((fact_hash = encode(sha256(convert_to(fact_json, 'utf8'::name)), 'hex'))),
    foreign key (period_id) references finance_period(id)
);

create table finance_period_late_resolution
(
    id               uuid not null,
    late_fact_id     uuid not null,
    evidence_domain  text not null,
    evidence_id      uuid not null,
    recorded_at      timestamptz not null,
    primary key (id),
    foreign key (late_fact_id) references finance_period_late_fact(id)
);

create table finance_period_policy
(
    id                      uuid not null,
    branch_id               uuid not null,
    organization_id         uuid not null,
    organization_reference  text not null,
    organization_name       text not null,
    time_zone               text not null,
    basis_document          text not null,
    close_roles             text[] not null,
    reopen_roles            text[] not null,
    correction_roles        text[] not null,
    created_by              uuid not null,
    created_at              timestamptz not null,
    primary key (id),
    check (((length(basis_document) >= 1) and (length(basis_document) <= 1000))),
    check ((cardinality(close_roles) > 0)),
    check ((cardinality(correction_roles) > 0)),
    check ((cardinality(reopen_roles) > 0)),
    foreign key (created_by) references app_user(id)
);

create table finance_period_policy_approval
(
    id           uuid not null,
    policy_id    uuid not null,
    approved_by  uuid not null,
    approved_at  timestamptz not null,
    reason       text not null,
    primary key (id),
    foreign key (approved_by) references app_user(id),
    foreign key (policy_id) references finance_period_policy(id)
);

create table finance_period_request
(
    id                  uuid not null,
    period_id           uuid not null,
    period_version      bigint not null,
    kind                text not null,
    domain              text,
    source              text,
    fact_hash           text,
    late_fact_id        uuid,
    document_reference  text not null,
    reason              text not null,
    proposed_by         uuid not null,
    proposed_at         timestamptz not null,
    primary key (id),
    check (((kind = 'reopen') or ((domain is not null) and (source is not null) and (fact_hash ~ '^[0-9a-f]{64}$')))),
    check (kind in ('REOPEN', 'CORRECTION', 'DISMISS')),
    -- kind BAZADA: jadval bo'sh
    foreign key (late_fact_id) references finance_period_late_fact(id),
    foreign key (period_id) references finance_period(id),
    foreign key (proposed_by) references app_user(id)
);

create table finance_repair_accounting_link
(
    id                uuid not null,
    entry_id          uuid not null,
    repair_source_id  uuid not null,
    branch_id         uuid not null,
    nature            text not null,
    basis_document    text not null,
    authored_by       uuid not null,
    authored_at       timestamptz not null,
    reason            text not null,
    primary key (id),
    check (nature in ('WARRANTY_REIMBURSEMENT', 'ACCOUNTING_ADJUSTMENT', 'CONTRACTOR_COST')),
    -- nature BAZADA: jadval bo'sh
    foreign key (authored_by) references app_user(id),
    foreign key (entry_id) references transport_cost_entry(id),
    foreign key (repair_source_id) references repair_cost_acceptance(id)
);

create table finance_repair_accounting_review
(
    id           uuid not null,
    link_id      uuid not null,
    approved_by  uuid not null,
    approved_at  timestamptz not null,
    reason       text not null,
    primary key (id),
    foreign key (approved_by) references app_user(id),
    foreign key (link_id) references finance_repair_accounting_link(id)
);

create table finance_service_evidence
(
    operation_id   uuid not null,
    leg_id         uuid not null,
    tariff_id      uuid not null,
    branch_id      uuid not null,
    actor_id       uuid not null,
    revision       bigint not null,
    action         text not null,
    state          text not null,
    original       jsonb not null,
    snapshot       jsonb not null,
    snapshot_hash  text not null,
    recorded_at    timestamptz not null,
    primary key (operation_id),
    check (action in ('SAVE', 'APPROVE', 'REVOKE')),
    -- action BAZADA: jadval bo'sh
    check ((revision > 0)),
    check ((snapshot_hash ~ '^[0-9a-f]{64}$')),
    check (state in ('DRAFT', 'APPROVED', 'REVOKED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (leg_id) references transport_execution_leg(id),
    foreign key (tariff_id) references tariff(id)
);

create table finance_service_evidence_closed
(
    operation_id  uuid not null,
    leg_id        uuid not null,
    tariff_id     uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    check (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 2000)))
);

create table finance_shipment_cost_link
(
    id                 uuid not null,
    shipment_id        uuid not null,
    graph_leg_id       uuid not null,
    graph_revision_id  uuid not null,
    execution_leg_id   uuid not null,
    allocation_id      uuid not null,
    entry_id           uuid not null,
    branch_id          uuid not null,
    amount             numeric(38,6) not null,
    currency           text not null,
    money_scale        integer not null,
    source_json        jsonb not null,
    source_hash        text not null,
    actor_id           uuid not null,
    recorded_at        timestamptz not null,
    reason             text not null,
    primary key (id),
    check ((amount >= (0))),
    check ((amount = round(amount, money_scale))),
    foreign key (actor_id) references app_user(id),
    foreign key (allocation_id) references transport_cost_allocation_record(id),
    foreign key (entry_id) references transport_cost_entry(id),
    foreign key (execution_leg_id) references transport_execution_leg(id),
    foreign key (graph_revision_id) references shipment_graph_leg_revision(id),
    foreign key (shipment_id) references shipment(id)
);

create table finance_shipment_invoice_closed
(
    operation_id  uuid not null,
    invoice_id    uuid not null,
    shipment_id   uuid not null,
    graph_leg_id  uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (invoice_id) references carrier_invoice(id),
    foreign key (shipment_id) references shipment(id)
);

create table finance_shipment_invoice_link
(
    operation_id  uuid not null,
    invoice_id    uuid not null,
    shipment_id   uuid not null,
    graph_leg_id  uuid not null,
    part_id       uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    source_json   jsonb not null,
    source_hash   text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    check ((source_hash ~ '^[a-f0-9]{64}$')),
    foreign key (actor_id) references app_user(id),
    foreign key (invoice_id) references carrier_invoice(id),
    foreign key (shipment_id) references shipment(id)
);

-- ---------------------------------------------------------------------
-- Jarimalar: tezlik oshirish, marshrutdan chiqish, bekor turish, YHXB jarimasi,
-- yoqilg'idan noto'g'ri foydalanish, zarar. Summasi (amount), holati
-- (OPEN, UNDER_REVIEW, CONFIRMED, DISMISSED, PAID), sodir bo'lgan vaqti.
-- trip, transport_vehicle jadvallariga bog'langan; haydovchi(lar) esa fine_driver
-- bog'lovchi jadvali orqali (bitta jarimada bir nechta haydovchi bo'lishi mumkin).
-- source_violation_id — jarima speed_violation dan avtomatik yaratilgan bo'lsa.
-- ---------------------------------------------------------------------
create table fine
(
    id                   uuid not null,
    amount               numeric(14,2) not null,
    created_at           timestamptz not null,
    currency             varchar(8) not null,
    description          varchar(2000),
    external_reference   varchar(255),
    fine_number          varchar(32) not null,
    kind                 varchar(32) not null,
    occurred_at          timestamptz not null,
    source_violation_id  uuid,
    status               varchar(32) not null,
    status_comment       varchar(2000),
    updated_at           timestamptz not null,
    version              bigint not null,
    trip_id              uuid,
    vehicle_id           uuid not null,
    basis                varchar(2000),
    branch_id            uuid,
    created_actor_kind   varchar(32),
    created_by           uuid,
    payment_evidence_id  uuid,
    policy_id            uuid,
    source_event_key     varchar(512),
    source_kind          varchar(32) not null,
    source_reference     varchar(512),
    primary key (id),
    check (kind in ('SPEEDING', 'ROUTE_DEVIATION', 'IDLE_VIOLATION', 'TRAFFIC_POLICE', 'FUEL_MISUSE', 'DAMAGE', 'OTHER')),
    -- kind BAZADA: jadval bo'sh
    check (status in ('OPEN', 'UNDER_REVIEW', 'CONFIRMED', 'DISMISSED', 'PAID')),
    -- status BAZADA: jadval bo'sh
    foreign key (trip_id) references trip(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

-- ---------------------------------------------------------------------
-- Jarima va haydovchi o'rtasidagi bog'lovchi jadval. HAYDOVCHINING JARIMALARI
-- SO'RALSA fine JADVALI SHU JADVAL ORQALI JOIN QILINADI.
-- ---------------------------------------------------------------------
create table fine_driver
(
    fine_id    uuid not null,
    driver_id  uuid not null,
    foreign key (driver_id) references driver(id),
    foreign key (fine_id) references fine(id)
);

create table fleet_aggregate_negative_closure
(
    id         uuid not null,
    actor_id   uuid not null,
    basis      varchar(2000) not null,
    closed_at  timestamptz not null,
    primary key (id),
    check ((btrim((basis)) <> '')),
    foreign key (actor_id) references app_user(id),
    foreign key (id) references fleet_aggregate_original_command(id)
);

create table fleet_aggregate_original_command
(
    id               uuid not null,
    action           varchar(16) not null,
    part_id          uuid not null,
    payload_json     jsonb not null,
    payload_text     text not null,
    domain_identity  text not null,
    scope_json       jsonb not null,
    actor_id         uuid not null,
    actor            varchar(255) not null,
    retained_at      timestamptz not null,
    primary key (id),
    check (action in ('INSTALL', 'REMOVE', 'ACCEPT', 'REUSE', 'OPENING')),
    -- action BAZADA: jadval bo'sh
    check ((jsonb_typeof(payload_json) = 'object')),
    foreign key (actor_id) references app_user(id),
    foreign key (part_id) references vehicle_part(id)
);

create table fleet_aggregate_passport_revision
(
    id                           uuid not null,
    part_id                      uuid not null,
    previous_revision_id         uuid,
    revision                     bigint not null,
    canonical_serial_key         varchar(400) not null,
    model                        varchar(255) not null,
    manufacturer                 varchar(255) not null,
    criticality                  varchar(32) not null,
    warranty_provider_reference  varchar(255),
    warranty_document            varchar(255),
    warranty_from                timestamptz,
    warranty_to                  timestamptz,
    document                     varchar(255) not null,
    basis                        varchar(2000) not null,
    actor_id                     uuid not null,
    actor                        varchar(255) not null,
    recorded_at                  timestamptz not null,
    payload_identity             varchar(64) not null,
    primary key (id),
    check ((btrim((basis)) <> '')),
    check ((((warranty_provider_reference is null) and (warranty_document is null) and (warranty_from is null) and (warranty_to is null)) or ((btrim((warranty_provider_reference)) <> '') and (btrim((warranty_document)) <> '') and (warranty_from is not null) and (warranty_to > warranty_from)))),
    check (criticality in ('CRITICAL', 'NONCRITICAL', 'UNKNOWN')),
    -- criticality BAZADA: jadval bo'sh
    check ((btrim((document)) <> '')),
    check ((btrim((manufacturer)) <> '')),
    check ((btrim((model)) <> '')),
    check ((revision > 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (part_id) references vehicle_part(id),
    foreign key (previous_revision_id) references fleet_aggregate_passport_revision(id)
);

create table fleet_calendar_closed_operation
(
    operation_id  uuid not null,
    vehicle_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    kind          text not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table fleet_capacity_calendar
(
    id          uuid not null,
    vehicle_id  uuid not null,
    branch_id   uuid not null,
    starts_at   timestamptz not null,
    ends_at     timestamptz not null,
    created_at  timestamptz not null,
    primary key (id),
    check ((ends_at > starts_at)),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table fleet_capacity_revision
(
    operation_id        uuid not null,
    calendar_id         uuid not null,
    version             bigint not null,
    state               text not null,
    actor_id            uuid not null,
    original            jsonb not null,
    intervals           jsonb not null,
    source_snapshot     jsonb not null,
    source_hash         text not null,
    evidence_through    timestamptz not null,
    as_of               timestamptz not null,
    document_reference  text not null,
    reason              text not null,
    primary key (operation_id),
    check (state in ('DRAFT', 'APPROVED', 'REVOKED')),
    -- state BAZADA: jadval bo'sh
    check ((version > 0)),
    foreign key (calendar_id) references fleet_capacity_calendar(id)
);

create table fleet_census
(
    operation_id  uuid not null,
    series_id     uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    revision      bigint not null,
    action        text not null,
    state         text not null,
    original      jsonb not null,
    calendar      jsonb not null,
    sources       jsonb not null,
    document      jsonb not null,
    hash          text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fleet_census_closed_operation
(
    operation_id  uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    kind          text not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fleet_counter_intake_outcome
(
    id           uuid not null,
    raw_id       uuid not null,
    sequence     bigint not null,
    state        varchar(32) not null,
    reason       varchar(120) not null,
    reading_id   uuid,
    mapping_id   uuid,
    binding_id   uuid,
    recorded_at  timestamptz not null,
    primary key (id),
    check (((reason) ~ '^[a-z0-9_]{1,120}$')),
    check (state in ('UNCONFIGURED', 'REJECTED', 'UNKNOWN', 'POSTED', 'QUARANTINED', 'POSTED_REPLAY', 'QUARANTINED_REPLAY')),
    -- state BAZADA: jadval bo'sh
    foreign key (binding_id) references vehicle_gps(id),
    foreign key (mapping_id) references fleet_counter_mapping(id),
    foreign key (raw_id) references fleet_counter_intake_raw(id),
    foreign key (reading_id) references vehicle_usage_reading(id)
);

create table fleet_counter_intake_raw
(
    id            uuid not null,
    machine_id    varchar(255) not null,
    delivery_key  varchar(200) not null,
    raw_body      bytea not null,
    raw_sha       varchar(64) not null,
    received_at   timestamptz not null,
    primary key (id),
    check (((raw_sha) = encode(sha256(raw_body), 'hex'))),
    check ((btrim((delivery_key)) <> '')),
    check (((octet_length(raw_body) >= 1) and (octet_length(raw_body) <= 1000000)))
);

create table fleet_counter_machine_source_witness
(
    raw_id            uuid not null,
    reading_id        uuid not null,
    mapping_id        uuid not null,
    mapping_revision  bigint not null,
    approval_id       uuid not null,
    mapping_hash      varchar(64) not null,
    binding_id        uuid not null,
    binding_version   bigint not null,
    ownership_hash    varchar(64) not null,
    vehicle_id        uuid not null,
    branch_id         uuid not null,
    machine_id        varchar(255) not null,
    source_hash       varchar(64) not null,
    primary key (raw_id),
    foreign key (approval_id) references fleet_counter_mapping_decision(id),
    foreign key (binding_id) references vehicle_gps(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (mapping_id) references fleet_counter_mapping(id),
    foreign key (raw_id) references fleet_counter_intake_raw(id),
    foreign key (reading_id) references vehicle_usage_reading(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table fleet_counter_mapping
(
    id                      uuid not null,
    previous_mapping_id     uuid,
    revision                bigint not null,
    branch_id               uuid not null,
    provider_connection     varchar(32) not null,
    organization_reference  varchar(255) not null,
    machine_id              varchar(255) not null,
    metric_key              varchar(100) not null,
    payload_json            jsonb not null,
    payload_text            text not null,
    payload_identity        varchar(64) not null,
    actor_id                uuid not null,
    actor                   varchar(255) not null,
    recorded_at             timestamptz not null,
    primary key (id),
    check ((revision > 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (previous_mapping_id) references fleet_counter_mapping(id)
);

create table fleet_counter_mapping_decision
(
    id                uuid not null,
    mapping_id        uuid not null,
    action            varchar(16) not null,
    reviewed_hash     varchar(64) not null,
    document          varchar(255) not null,
    basis             varchar(2000) not null,
    actor_id          uuid not null,
    actor             varchar(255) not null,
    recorded_at       timestamptz not null,
    payload_json      jsonb not null,
    payload_text      text not null,
    payload_identity  varchar(64) not null,
    primary key (id),
    check (action in ('APPROVE', 'REVOKE')),
    -- action BAZADA: jadval bo'sh
    check ((btrim((basis)) <> '')),
    check ((btrim((document)) <> '')),
    foreign key (actor_id) references app_user(id),
    foreign key (mapping_id) references fleet_counter_mapping(id)
);

create table fleet_counter_negative_closure
(
    id         uuid not null,
    actor_id   uuid not null,
    basis      varchar(2000) not null,
    closed_at  timestamptz not null,
    primary key (id),
    check ((btrim((basis)) <> '')),
    foreign key (actor_id) references app_user(id),
    foreign key (id) references fleet_counter_original_command(id)
);

create table fleet_counter_original_command
(
    id                uuid not null,
    namespace         varchar(16) not null,
    branch_id         uuid not null,
    payload_json      jsonb not null,
    payload_text      text not null,
    payload_identity  varchar(64) not null,
    actor_id          uuid not null,
    actor             varchar(255) not null,
    retained_at       timestamptz not null,
    primary key (id),
    check (namespace in ('MAPPING', 'DECISION')),
    -- namespace BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fleet_counter_posted_source
(
    id                      uuid not null,
    raw_id                  uuid not null,
    raw_sha                 varchar(64) not null,
    mapping_id              uuid not null,
    binding_id              uuid not null,
    binding_version         bigint not null,
    ownership_hash          varchar(64) not null,
    vehicle_id              uuid not null,
    branch_id               uuid not null,
    provider_connection     varchar(32) not null,
    organization_reference  varchar(255) not null,
    provider_device_id      bigint not null,
    external_event_id       varchar(200) not null,
    metric_key              varchar(100) not null,
    counter                 varchar(32) not null,
    input_value             numeric not null,
    input_unit              varchar(32) not null,
    converted_value         numeric(20,3) not null,
    reading_id              uuid not null,
    recorded_at             timestamptz not null,
    primary key (id),
    check ((converted_value >= (0))),
    check (counter in ('ODOMETER_KM', 'ENGINE_HOURS')),
    -- counter BAZADA: jadval bo'sh
    check ((input_value >= (0))),
    check ((provider_device_id > 0)),
    foreign key (binding_id) references vehicle_gps(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (mapping_id) references fleet_counter_mapping(id),
    foreign key (raw_id) references fleet_counter_intake_raw(id),
    foreign key (reading_id) references vehicle_usage_reading(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table fleet_defect
(
    defect_id         uuid not null,
    object_id         uuid not null,
    branch_id         uuid not null,
    source_type       text not null,
    source_reference  text not null,
    original          jsonb not null,
    repair_id         uuid,
    version           bigint not null,
    state             text not null,
    merged_into       uuid,
    actor_id          uuid not null,
    detected_at       timestamptz not null,
    primary key (defect_id),
    check (state in ('OPEN', 'MERGED', 'CANCELLED', 'RESOLVED')),
    -- state BAZADA: OPEN 2 | ISHLATILMAGAN: MERGED, CANCELLED, RESOLVED
    check ((version >= 1)),
    foreign key (merged_into) references fleet_defect(defect_id),
    foreign key (repair_id) references vehicle_repair(id)
);

create table fleet_defect_event
(
    operation_id  uuid not null,
    defect_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    result        jsonb not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    foreign key (defect_id) references fleet_defect(defect_id)
);

create table fleet_failure_closed_operation
(
    operation_id  uuid not null,
    failure_id    uuid not null,
    vehicle_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    kind          text not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table fleet_failure_event
(
    operation_id          uuid not null,
    failure_id            uuid not null,
    vehicle_id            uuid not null,
    branch_id             uuid not null,
    actor_id              uuid not null,
    revision              bigint not null,
    action                text not null,
    state                 text not null,
    original              jsonb not null,
    failure               jsonb not null,
    failure_document      jsonb not null,
    restoration_document  jsonb,
    hash                  text not null,
    recorded_at           timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table fleet_material_negative_closure
(
    id         uuid not null,
    actor_id   uuid not null,
    basis      varchar(2000) not null,
    closed_at  timestamptz not null,
    primary key (id),
    check ((btrim((basis)) <> '')),
    foreign key (actor_id) references app_user(id),
    foreign key (id) references fleet_material_original_command(id)
);

create table fleet_material_original_command
(
    id                uuid not null,
    namespace         varchar(40) not null,
    target            varchar(500) not null,
    stock_ids         jsonb not null,
    payload_json      jsonb not null,
    payload_text      text not null,
    payload_identity  varchar(64) not null,
    actor_id          uuid not null,
    actor             varchar(255) not null,
    retained_at       timestamptz not null,
    primary key (id),
    check (((jsonb_typeof(stock_ids) = 'array') and (((namespace) = any ((array['warranty', 'condition'])[])) or (jsonb_array_length(stock_ids) > 0)))),
    check (((payload_text)::jsonb = payload_json)),
    check ((jsonb_typeof(payload_json) = 'object')),
    foreign key (actor_id) references app_user(id)
);

create table fleet_material_return_receipt_allocation
(
    receipt_operation_id  uuid not null,
    request_operation_id  uuid not null,
    quantity              numeric(16,3) not null,
    serial_part_ids       text,
    primary key (receipt_operation_id, request_operation_id),
    check ((quantity > (0))),
    foreign key (receipt_operation_id) references material_operation(id),
    foreign key (request_operation_id) references material_operation(id)
);

create table fleet_membership
(
    operation_id  uuid not null,
    series_id     uuid not null,
    vehicle_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    revision      bigint not null,
    action        text not null,
    state         text not null,
    original      jsonb not null,
    calendar      jsonb not null,
    document      jsonb not null,
    hash          text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table fleet_membership_closed_operation
(
    operation_id  uuid not null,
    vehicle_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    kind          text not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table fleet_observation
(
    operation_id  uuid not null,
    series_id     uuid not null,
    vehicle_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    revision      bigint not null,
    action        text not null,
    state         text not null,
    original      jsonb not null,
    calendar      jsonb not null,
    sources       jsonb not null,
    document      jsonb not null,
    hash          text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table fleet_observation_closed_operation
(
    operation_id  uuid not null,
    vehicle_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    kind          text not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table fleet_operation
(
    operation_id    uuid not null,
    object_id       uuid not null,
    branch_id       uuid not null,
    actor_id        uuid not null,
    original        jsonb not null,
    state           text not null,
    result          jsonb,
    closure_reason  text,
    recorded_at     timestamptz not null,
    primary key (operation_id),
    check (state in ('IN_FLIGHT', 'RECORDED', 'NOT_EXECUTED'))
    -- state BAZADA: RECORDED 12, NOT_EXECUTED 3 | ISHLATILMAGAN: IN_FLIGHT
);

create table fleet_passport_admission_fact
(
    admission_id  uuid not null,
    vehicle_id    uuid not null,
    trailer_id    uuid,
    branch_id     uuid not null,
    starts_at     timestamptz not null,
    ends_at       timestamptz not null,
    actor_id      uuid not null,
    proof         jsonb not null,
    created_at    timestamptz not null,
    primary key (admission_id),
    check ((ends_at > starts_at))
);

create table fleet_passport_assignment_mutation
(
    operation_id          uuid not null,
    event_id              uuid not null,
    source_operation_id   uuid not null,
    admission_id          uuid not null,
    object_kind           text not null,
    object_id             uuid not null,
    assignment_type       text not null,
    assignment_reference  text not null,
    trip_id               uuid not null,
    trip_version          bigint not null,
    effective_at          timestamptz not null,
    starts_at             timestamptz not null,
    ends_at               timestamptz not null,
    actor_id              uuid not null,
    original              jsonb not null,
    recorded_at           timestamptz not null,
    primary key (operation_id),
    check (assignment_type in ('TRIP', 'WAYBILL')),
    -- assignment_type BAZADA: jadval bo'sh
    check (((ends_at > starts_at) and (effective_at < ends_at))),
    check (object_kind in ('VEHICLE', 'TRAILER')),
    -- object_kind BAZADA: jadval bo'sh
    check ((trip_version >= 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (admission_id) references fleet_passport_admission_fact(admission_id),
    foreign key (event_id) references transport_assignment_event(id),
    foreign key (operation_id) references fleet_passport_assignment_snapshot(operation_id) deferrable initially deferred,
    foreign key (source_operation_id) references transport_assignment_command(operation_id) deferrable initially deferred,
    foreign key (trip_id) references trip(id)
);

create table fleet_passport_assignment_snapshot
(
    operation_id          uuid not null,
    object_id             uuid not null,
    assignment_type       text not null,
    assignment_reference  text not null,
    starts_at             timestamptz not null,
    ends_at               timestamptz not null,
    snapshot              jsonb not null,
    actor_id              uuid not null,
    recorded_at           timestamptz not null,
    primary key (operation_id),
    check (assignment_type in ('TRIP', 'WAYBILL', 'RESOURCE_REQUEST')),
    -- assignment_type BAZADA: jadval bo'sh
    check ((ends_at > starts_at)),
    foreign key (operation_id) references fleet_passport_command(operation_id) deferrable initially deferred
);

create table fleet_passport_command
(
    operation_id  uuid not null,
    object_id     uuid not null,
    actor_id      uuid not null,
    action        text not null,
    original      jsonb not null,
    result        jsonb not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    foreign key (object_id) references fleet_passport_object(object_id)
);

create table fleet_passport_coupling
(
    operation_id            uuid not null,
    tractor_id              uuid not null,
    trailer_id              uuid not null,
    starts_at               timestamptz not null,
    ends_at                 timestamptz not null,
    snapshot                jsonb not null,
    actor_id                uuid not null,
    cancelled_by            uuid,
    cancellation_reference  text,
    primary key (operation_id),
    check ((ends_at > starts_at)),
    foreign key (operation_id) references fleet_passport_command(operation_id) deferrable initially deferred
);

create table fleet_passport_erp_attempt
(
    operation_id  uuid not null,
    event_id      uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    foreign key (event_id) references fleet_passport_erp_delivery(event_id)
);

create table fleet_passport_erp_delivery
(
    event_id             uuid not null,
    object_id            uuid not null,
    state                text not null,
    attempts             bigint not null,
    erp_asset_reference  text,
    receipt_reference    text,
    last_error           text,
    updated_at           timestamptz not null,
    primary key (event_id),
    check (state in ('PENDING', 'FAILED', 'CONFIRMED')),
    -- state BAZADA: PENDING 4 | ISHLATILMAGAN: FAILED, CONFIRMED
    foreign key (event_id) references fleet_passport_lifecycle(operation_id)
);

create table fleet_passport_lifecycle
(
    operation_id        uuid not null,
    object_id           uuid not null,
    version             bigint not null,
    state               text not null,
    action              text not null,
    effective_at        timestamptz not null,
    branch_id           uuid not null,
    reason              text not null,
    document_reference  text not null,
    actor_id            uuid not null,
    recorded_at         timestamptz not null,
    primary key (operation_id),
    check (state in ('RECEIVED', 'COMMISSIONED', 'CONSERVED', 'WITHDRAWN')),
    -- state BAZADA: COMMISSIONED 2, RECEIVED 2 | ISHLATILMAGAN: CONSERVED, WITHDRAWN
    check ((version > 0)),
    foreign key (object_id) references fleet_passport_object(object_id),
    foreign key (operation_id) references fleet_passport_command(operation_id) deferrable initially deferred
);

create table fleet_passport_object
(
    object_id   uuid not null,
    kind        text not null,
    branch_id   uuid not null,
    created_at  timestamptz not null,
    primary key (object_id),
    check (kind in ('VEHICLE', 'TRAILER'))
    -- kind BAZADA: VEHICLE 2 | ISHLATILMAGAN: TRAILER
);

create table fleet_passport_profile
(
    operation_id    uuid not null,
    object_id       uuid not null,
    version         bigint not null,
    effective_from  timestamptz not null,
    effective_to    timestamptz,
    profile         jsonb not null,
    actor_id        uuid not null,
    recorded_at     timestamptz not null,
    primary key (operation_id),
    check (((effective_to is null) or (effective_to > effective_from))),
    check ((version > 0)),
    foreign key (object_id) references fleet_passport_object(object_id),
    foreign key (operation_id) references fleet_passport_command(operation_id) deferrable initially deferred
);

create table fleet_passport_task
(
    task_id     uuid not null,
    object_id   uuid not null,
    kind        text not null,
    title       text not null,
    due_at      timestamptz,
    blocking    boolean not null,
    state       text not null,
    created_by  uuid not null,
    last_actor  uuid not null,
    version     bigint not null,
    data        jsonb not null,
    primary key (task_id),
    check (kind in ('MAINTENANCE', 'REPAIR', 'EQUIPMENT')),
    -- kind BAZADA: jadval bo'sh
    check (state in ('OPEN', 'WORK_DONE', 'AWAITING_ACCEPTANCE', 'FAILED', 'PASSED', 'CANCELLED'))
    -- state BAZADA: jadval bo'sh
);

create table fleet_passport_usage
(
    operation_id      uuid not null,
    object_id         uuid not null,
    observed_at       timestamptz not null,
    km                numeric,
    hours             numeric,
    source_reference  text not null,
    actor_id          uuid not null,
    primary key (operation_id),
    check (((km is not null) or (hours is not null))),
    check (((hours is null) or (hours >= (0)))),
    check (((km is null) or (km >= (0)))),
    foreign key (operation_id) references fleet_passport_command(operation_id) deferrable initially deferred
);

create table fleet_repair_acceptance
(
    operation_id         uuid not null,
    repair_id            uuid not null,
    actor_id             uuid not null,
    result               text not null,
    accepted_at          timestamptz not null,
    checked_operations   jsonb not null,
    authority_reference  text not null,
    evidence_reference   text not null,
    snapshot             jsonb not null,
    primary key (operation_id),
    check (result in ('PASSED', 'FAILED')),
    -- result BAZADA: jadval bo'sh
    foreign key (repair_id) references vehicle_repair(id)
);

create table fleet_repair_late_original
(
    id             uuid not null,
    domain         text not null,
    repair_id      uuid not null,
    actor_id       uuid not null,
    branch_id      uuid not null,
    original_json  text not null,
    raw_sha        text not null,
    recorded_at    timestamptz not null,
    primary key (id),
    check ((raw_sha = encode(sha256(convert_to(original_json, 'utf8'::name)), 'hex'))),
    check (((((original_json)::jsonb ->> 'repairid') = (repair_id)) and (((original_json)::jsonb ->> 'actorid') = (actor_id)) and (((original_json)::jsonb #>> '{request,commandid}'[]) = (id)))),
    check (domain in ('FLEET_REPAIR', 'FLEET_REPAIR_ADJUSTMENT')),
    -- domain BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (repair_id) references vehicle_repair(id)
);

create table fleet_repair_work
(
    repair_id           uuid not null,
    work_id             text not null,
    title               text not null,
    required            boolean not null,
    state               text not null,
    assigned_user_id    uuid not null,
    performer_id        uuid,
    starts_at           timestamptz,
    ends_at             timestamptz,
    labor_hours         numeric,
    evidence_reference  text,
    waiver_reference    text,
    last_operation_id   uuid not null,
    primary key (repair_id, work_id),
    check (((ends_at is null) or (ends_at > starts_at))),
    check (((labor_hours is null) or (labor_hours >= (0)))),
    check (state in ('ASSIGNED', 'DONE', 'WAIVED')),
    -- state BAZADA: DONE 2 | ISHLATILMAGAN: ASSIGNED, WAIVED
    foreign key (repair_id) references vehicle_repair(id)
);

create table fleet_repair_work_event
(
    operation_id  uuid not null,
    repair_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    result        jsonb not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    foreign key (repair_id) references vehicle_repair(id)
);

create table fleet_resource_calendar
(
    operation_id  uuid not null,
    series_id     uuid not null,
    vehicle_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    revision      bigint not null,
    action        text not null,
    state         text not null,
    original      jsonb not null,
    calendar      jsonb not null,
    document      jsonb not null,
    hash          text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table fleet_serial_command
(
    id                uuid not null,
    action            varchar(32) not null,
    stock_id          uuid not null,
    target_stock_id   uuid,
    document          varchar(255) not null,
    basis             varchar(2000) not null,
    occurred_at       timestamptz not null,
    actor_id          uuid not null,
    actor             varchar(255) not null,
    payload_json      jsonb not null,
    payload_identity  varchar(64) not null,
    recorded_at       timestamptz not null,
    primary key (id),
    check (action in ('TRANSFER_OUT', 'TRANSFER_IN', 'RECEIVE_REMOVED', 'COUNT', 'INVENTORY_FOUND', 'APPLY_QUALITY', 'RETURN_SUPPLIER')),
    -- action BAZADA: jadval bo'sh
    check ((btrim((basis)) <> '')),
    check ((btrim((document)) <> '')),
    foreign key (actor_id) references app_user(id),
    foreign key (stock_id) references inventory_stock(id),
    foreign key (target_stock_id) references inventory_stock(id)
);

create table fleet_serial_event
(
    id                       uuid not null,
    command_id               uuid not null,
    part_id                  uuid not null,
    previous_event_id        uuid,
    revision                 bigint not null,
    stock_id                 uuid not null,
    branch_id                uuid,
    state                    varchar(32) not null,
    disposition              varchar(32) not null,
    stock_accounted          boolean not null,
    removal_installation_id  uuid,
    occurred_at              timestamptz not null,
    actor_id                 uuid not null,
    actor                    varchar(255) not null,
    document                 varchar(255) not null,
    primary key (id),
    check ((stock_accounted or (removal_installation_id is not null))),
    check (disposition in ('USABLE', 'QUARANTINE')),
    -- disposition BAZADA: jadval bo'sh
    check ((revision > 0)),
    check (state in ('USABLE', 'QUARANTINE', 'STORAGE', 'REPAIR', 'IN_TRANSIT', 'LOST', 'SUPPLIER_RETURNED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (command_id) references fleet_serial_command(id),
    foreign key (part_id) references vehicle_part(id),
    foreign key (previous_event_id) references fleet_serial_event(id),
    foreign key (removal_installation_id) references part_installation(id),
    foreign key (stock_id) references inventory_stock(id)
);

create table fleet_serial_quality_approval
(
    id                uuid not null,
    decision_id       uuid not null,
    source_hash       varchar(64) not null,
    document          varchar(255) not null,
    basis             varchar(2000) not null,
    actor_id          uuid not null,
    actor             varchar(255) not null,
    recorded_at       timestamptz not null,
    payload_identity  varchar(64) not null,
    primary key (id),
    check ((btrim((basis)) <> '')),
    check ((btrim((document)) <> '')),
    foreign key (actor_id) references app_user(id),
    foreign key (decision_id) references fleet_serial_quality_decision(id)
);

create table fleet_serial_quality_decision
(
    id                       uuid not null,
    part_id                  uuid not null,
    stock_id                 uuid not null,
    previous_event_id        uuid,
    passport_version         bigint not null,
    condition_evaluation_id  uuid,
    disposition              varchar(32) not null,
    supplier_reference       varchar(255),
    document                 varchar(255) not null,
    basis                    varchar(2000) not null,
    actor_id                 uuid not null,
    actor                    varchar(255) not null,
    recorded_at              timestamptz not null,
    payload_identity         varchar(64) not null,
    source_hash              varchar(64) not null,
    primary key (id),
    check ((btrim((basis)) <> '')),
    check (((((disposition) = 'return_supplier') and (supplier_reference is not null) and (btrim((supplier_reference)) <> '')) or (((disposition) <> 'return_supplier') and (supplier_reference is null)))),
    check (disposition in ('RELEASE_USABLE', 'REPAIR', 'RETURN_SUPPLIER', 'KEEP_QUARANTINE')),
    -- disposition BAZADA: jadval bo'sh
    check ((btrim((document)) <> '')),
    foreign key (actor_id) references app_user(id),
    foreign key (condition_evaluation_id) references part_condition_evaluation(id),
    foreign key (part_id) references vehicle_part(id),
    foreign key (previous_event_id) references fleet_serial_event(id),
    foreign key (stock_id) references inventory_stock(id)
);

create table fleet_serial_warehouse_policy
(
    id                  uuid not null,
    warehouse_id        uuid not null,
    branch_id           uuid not null,
    previous_policy_id  uuid,
    document            varchar(255) not null,
    basis               varchar(2000) not null,
    actor_id            uuid not null,
    actor               varchar(255) not null,
    recorded_at         timestamptz not null,
    payload_identity    varchar(64) not null,
    primary key (id),
    check ((btrim((basis)) <> '')),
    check ((btrim((document)) <> '')),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (previous_policy_id) references fleet_serial_warehouse_policy(id),
    foreign key (warehouse_id) references reference_data(id)
);

create table fleet_usage_policy
(
    operation_id  uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    revision      bigint not null,
    state         text not null,
    original      jsonb not null,
    document      jsonb not null,
    hash          text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    check (state in ('DRAFT', 'APPROVED', 'REVOKED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fleet_usage_policy_closed
(
    operation_id  uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fleet_warranty_claim
(
    id                     uuid not null,
    repair_id              uuid not null,
    vehicle_id             uuid not null,
    branch_id              uuid not null,
    repair_version         bigint not null,
    part_id                uuid not null,
    installation_id        uuid not null,
    aggregate_revision_id  uuid not null,
    incident_at            timestamptz not null,
    supplier_reference     varchar(255) not null,
    contract_reference     varchar(255) not null,
    claim_document         varchar(255) not null,
    description            varchar(2000) not null,
    claimed_amount         numeric(24,6),
    currency               varchar(3),
    basis                  varchar(2000) not null,
    actor_id               uuid not null,
    actor                  varchar(255) not null,
    recorded_at            timestamptz not null,
    payload_json           jsonb not null,
    payload_identity       varchar(64) not null,
    primary key (id),
    check ((btrim((basis)) <> '')),
    check (((claimed_amount is null) = (currency is null))),
    check ((btrim((claim_document)) <> '')),
    check ((claimed_amount >= (0))),
    check ((btrim((contract_reference)) <> '')),
    check (((currency is null) or ((currency) ~ '^[a-z]{3}$'))),
    check ((btrim((description)) <> '')),
    check ((btrim((supplier_reference)) <> '')),
    foreign key (actor_id) references app_user(id),
    foreign key (aggregate_revision_id) references fleet_aggregate_passport_revision(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (installation_id) references part_installation(id),
    foreign key (part_id) references vehicle_part(id),
    foreign key (repair_id) references vehicle_repair(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table fleet_warranty_event
(
    id                  uuid not null,
    claim_id            uuid not null,
    previous_event_id   uuid,
    revision            bigint not null,
    action              varchar(32) not null,
    receipt_event_id    uuid,
    occurred_at         timestamptz not null,
    actual_amount       numeric(24,6),
    currency            varchar(3),
    issuer_reference    varchar(255) not null,
    document_reference  varchar(255) not null,
    line_reference      varchar(128) not null,
    source_hash         varchar(64),
    basis               varchar(2000) not null,
    actor_id            uuid not null,
    actor               varchar(255) not null,
    recorded_at         timestamptz not null,
    payload_json        jsonb not null,
    payload_identity    varchar(64) not null,
    primary key (id),
    check (action in ('SUBMIT', 'ACCEPT_CLAIM', 'REJECT_CLAIM', 'REGISTER_RECEIPT', 'ACCEPT_RECEIPT', 'CANCEL_RECEIPT')),
    -- action BAZADA: jadval bo'sh
    check ((actual_amount > (0))),
    check ((btrim((basis)) <> '')),
    check (action in ('REGISTER_RECEIPT', 'ACCEPT_RECEIPT', 'CANCEL_RECEIPT')),
    -- action BAZADA: jadval bo'sh
    check (action in ('ACCEPT_RECEIPT', 'CANCEL_RECEIPT')),
    -- action BAZADA: jadval bo'sh
    check (((currency is null) or ((currency) ~ '^[a-z]{3}$'))),
    check ((btrim((document_reference)) <> '')),
    check ((btrim((issuer_reference)) <> '')),
    check ((btrim((line_reference)) <> '')),
    check ((revision > 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (claim_id) references fleet_warranty_claim(id),
    foreign key (previous_event_id) references fleet_warranty_event(id),
    foreign key (receipt_event_id) references fleet_warranty_event(id)
);

-- ---------------------------------------------------------------------
-- Yoqilg'i quyishga berilgan ruxsatnoma: so'ralgan (requested_liters), tasdiqlangan
-- (approved_liters) va amalda quyilgan (dispensed_liters) litr.
-- status: APPROVED, REJECTED, COMPLETED, CANCELLED. rejection_reason — rad etish
-- sababi. credential_id — haydovchi qaysi karta/QR bilan tanilgani.
-- RUXSAT BERILGAN LEKIN QUYILMAGAN yoki ORTIQCHA QUYILGAN holatlar
-- approved_liters va dispensed_liters ni solishtirib topiladi.
-- ---------------------------------------------------------------------
create table fuel_authorization
(
    id                uuid not null,
    actor_id          varchar(128),
    amount            numeric(18,2),
    approved_liters   numeric(14,3),
    cancelled_at      timestamptz,
    completed_at      timestamptz,
    created_at        timestamptz not null,
    credential_id     uuid,
    currency          varchar(8),
    dispensed_liters  numeric(14,3),
    driver_id         uuid,
    fuel_record_id    uuid,
    fuel_type         varchar(32) not null,
    rejection_reason  varchar(256),
    requested_liters  numeric(14,3),
    status            varchar(16) not null,
    vehicle_id        uuid not null,
    warehouse_id      uuid,
    primary key (id),
    check (status in ('APPROVED', 'REJECTED', 'COMPLETED', 'CANCELLED'))
    -- status BAZADA: jadval bo'sh
);

-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
create table fuel_card_current_financial_revision
(
    operation_id           uuid,
    row_id                 uuid,
    previous_row_id        uuid,
    hardware_operation_id  uuid,
    physical_fact_id       uuid,
    fuel_record_id         uuid,
    provider               text,
    organization           text,
    transaction_id         text,
    revision               bigint,
    actor_id               uuid,
    branch_id              uuid,
    original               jsonb,
    sources                jsonb,
    source_hash            text,
    document               jsonb,
    financial_amount       numeric,
    currency               text,
    physical_quantity      numeric,
    unit                   text,
    state                  text,
    recorded_at            timestamptz
);

create table fuel_card_financial_correction
(
    operation_id           uuid not null,
    row_id                 uuid not null,
    previous_row_id        uuid not null,
    hardware_operation_id  uuid not null,
    physical_fact_id       uuid not null,
    fuel_record_id         uuid,
    provider               text not null,
    organization           text not null,
    transaction_id         text not null,
    revision               bigint not null,
    actor_id               uuid not null,
    branch_id              uuid not null,
    original               jsonb not null,
    sources                jsonb not null,
    source_hash            text not null,
    document               jsonb not null,
    financial_amount       numeric not null,
    currency               text not null,
    physical_quantity      numeric not null,
    unit                   text not null,
    state                  text not null,
    recorded_at            timestamptz not null,
    primary key (operation_id),
    check ((financial_amount >= (0))),
    check ((physical_quantity > (0))),
    check ((revision > 0)),
    check ((source_hash ~ '^[a-f0-9]{64}$')),
    check (state in ('CORRECTED_FINANCIAL', 'CANCELLED_FINANCIAL')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (fuel_record_id) references fuel_record(id),
    foreign key (hardware_operation_id) references fuel_hardware_operation(id),
    foreign key (physical_fact_id) references fuel_hardware_fact(id),
    foreign key (previous_row_id) references fuel_hardware_card_row(id),
    foreign key (row_id) references fuel_hardware_card_row(id)
);

-- ---------------------------------------------------------------------
-- Yoqilg'i kartasi tranzaksiyalari (tashqi provayderdan import qilinadi): litr,
-- summa, shoxobcha nomi, karta raqami, tashqi tranzaksiya id.
-- CHEK BO'YICHA QUYILGAN YOQILG'I SHU JADVALDA. Sensor ko'rsatkichi bilan
-- solishtirish uchun fuel_sensor_reading ishlatiladi.
-- ---------------------------------------------------------------------
create table fuel_card_transaction
(
    id                       uuid not null,
    amount                   numeric(14,2) not null,
    card_number              varchar(255) not null,
    currency                 varchar(8) not null,
    driver_id                uuid,
    external_transaction_id  varchar(255) not null,
    fuel_type                varchar(32) not null,
    imported_at              timestamptz not null,
    liters                   numeric(12,3) not null,
    merchant_name            varchar(255) not null,
    raw_payload              varchar(4000),
    transacted_at            timestamptz not null,
    trip_id                  uuid,
    vehicle_id               uuid not null,
    primary key (id)
);

create table fuel_consumption_interval
(
    operation_id     uuid not null,
    interval_id      uuid not null,
    account_id       uuid not null,
    vehicle_id       uuid not null,
    branch_id        uuid not null,
    actor_id         uuid not null,
    revision         bigint not null,
    state            text not null,
    original         jsonb not null,
    sources          jsonb not null,
    document         jsonb not null,
    review_document  jsonb,
    hash             text not null,
    recorded_at      timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table fuel_consumption_interval_closed
(
    operation_id  uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_consumption_issue_attribution
(
    operation_id     uuid not null,
    interval_id      uuid not null,
    account_id       uuid not null,
    branch_id        uuid not null,
    actor_id         uuid not null,
    revision         bigint not null,
    state            text not null,
    original         jsonb not null,
    sources          jsonb not null,
    document         jsonb not null,
    review_document  jsonb,
    hash             text not null,
    recorded_at      timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_consumption_issue_attribution_closed
(
    operation_id  uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_consumption_observation
(
    operation_id     uuid not null,
    observation_id   uuid not null,
    account_id       uuid not null,
    vehicle_id       uuid not null,
    branch_id        uuid not null,
    actor_id         uuid not null,
    revision         bigint not null,
    state            text not null,
    original         jsonb not null,
    sources          jsonb not null,
    document         jsonb not null,
    review_document  jsonb,
    hash             text not null,
    recorded_at      timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table fuel_consumption_observation_closed
(
    operation_id  uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_consumption_policy
(
    operation_id  uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    revision      bigint not null,
    state         text not null,
    original      jsonb not null,
    sources       jsonb not null,
    document      jsonb not null,
    hash          text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_consumption_policy_closed
(
    operation_id  uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_forecast_closed
(
    operation_id  uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id)
);

create table fuel_forecast_erp_demand
(
    operation_id       uuid not null,
    forecast_id        uuid not null,
    account_id         uuid not null,
    forecast_revision  bigint not null,
    actor_id           uuid not null,
    state              text not null,
    payload            jsonb not null,
    payload_hash       text not null,
    original           jsonb not null,
    recorded_at        timestamptz not null,
    primary key (operation_id)
);

create table fuel_forecast_erp_exchange
(
    operation_id       uuid not null,
    demand_id          uuid not null,
    account_id         uuid not null,
    actor_id           uuid not null,
    provider_id        text not null,
    provider_revision  bigint not null,
    exchange_id        uuid not null,
    original           jsonb not null,
    recorded_at        timestamptz not null,
    primary key (operation_id),
    foreign key (demand_id) references fuel_forecast_erp_demand(operation_id)
);

create table fuel_forecast_erp_exchange_closed
(
    operation_id  uuid not null,
    account_id    uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id)
);

create table fuel_forecast_revision
(
    operation_id     uuid not null,
    forecast_id      uuid not null,
    account_id       uuid not null,
    branch_id        uuid not null,
    actor_id         uuid not null,
    revision         bigint not null,
    state            text not null,
    original         jsonb not null,
    sources          jsonb not null,
    calculation      jsonb not null,
    document         jsonb not null,
    review_document  jsonb,
    hash             text not null,
    recorded_at      timestamptz not null,
    primary key (operation_id)
);

create table fuel_hardware_aggregate
(
    id           uuid not null,
    vehicle_id   uuid not null,
    branch_id    uuid not null,
    observed_at  timestamptz not null,
    payload      jsonb not null,
    identity     text not null,
    created_at   timestamptz not null,
    primary key (id)
);

create table fuel_hardware_asset
(
    id             uuid not null,
    branch_id      uuid not null,
    account_id     uuid,
    kind           text not null,
    serial_number  text not null,
    tank_id        uuid,
    payload        jsonb not null,
    active         boolean not null,
    created_at     timestamptz not null,
    primary key (id),
    check (kind in ('TANK', 'DISPENSER', 'METER', 'DUT')),
    -- kind BAZADA: TANK 3, DISPENSER 2 | ISHLATILMAGAN: METER, DUT
    foreign key (tank_id) references fuel_hardware_asset(id)
);

create table fuel_hardware_attempt
(
    id            uuid not null,
    operation_id  uuid not null,
    kind          text not null,
    state         text not null,
    request       jsonb not null,
    response      jsonb,
    error         text,
    created_by    uuid not null,
    created_at    timestamptz not null,
    finished_at   timestamptz,
    primary key (id),
    foreign key (operation_id) references fuel_hardware_operation(id)
);

create table fuel_hardware_binding
(
    id          uuid not null,
    sensor_id   uuid not null,
    vehicle_id  uuid not null,
    branch_id   uuid not null,
    valid_from  timestamptz not null,
    valid_to    timestamptz,
    payload     jsonb not null,
    created_by  uuid not null,
    primary key (id),
    check (((valid_to is null) or (valid_to > valid_from))),
    foreign key (sensor_id) references fuel_hardware_asset(id)
);

create table fuel_hardware_calibration
(
    id              uuid not null,
    asset_id        uuid not null,
    valid_from      timestamptz not null,
    valid_to        timestamptz,
    verified_until  timestamptz not null,
    payload         jsonb not null,
    created_by      uuid not null,
    created_at      timestamptz not null,
    primary key (id),
    check (((valid_to is null) or (valid_to > valid_from))),
    foreign key (asset_id) references fuel_hardware_asset(id)
);

create table fuel_hardware_candidate
(
    id          uuid not null,
    vehicle_id  uuid not null,
    branch_id   uuid not null,
    event_key   text not null,
    from_at     timestamptz not null,
    to_at       timestamptz not null,
    payload     jsonb not null,
    state       text not null,
    created_at  timestamptz not null,
    version     bigint not null,
    primary key (id)
);

create table fuel_hardware_candidate_decision
(
    id            uuid not null,
    candidate_id  uuid not null,
    payload       jsonb not null,
    identity      text not null,
    created_by    uuid not null,
    created_at    timestamptz not null,
    primary key (id),
    foreign key (candidate_id) references fuel_hardware_candidate(id)
);

create table fuel_hardware_card_cursor
(
    provider           text not null,
    organization       text not null,
    cursor             text,
    batch_id           uuid not null,
    receipt_reference  text not null,
    primary key (provider, organization)
);

create table fuel_hardware_card_decision
(
    id          uuid not null,
    row_id      uuid not null,
    payload     jsonb not null,
    identity    text not null,
    created_by  uuid not null,
    created_at  timestamptz not null,
    primary key (id),
    foreign key (row_id) references fuel_hardware_card_row(id)
);

create table fuel_hardware_card_row
(
    id               uuid not null,
    batch_id         uuid not null,
    provider         text,
    organization     text,
    transaction_id   text,
    revision         text,
    payload          jsonb not null,
    identity         text not null,
    state            text not null,
    reason           text,
    fact_id          uuid,
    fuel_record_id   uuid,
    previous_row_id  uuid,
    received_at      timestamptz not null,
    version          bigint not null,
    primary key (id),
    foreign key (previous_row_id) references fuel_hardware_card_row(id)
);

create table fuel_hardware_detector_policy
(
    id          uuid not null,
    branch_id   uuid not null,
    valid_from  timestamptz not null,
    valid_to    timestamptz,
    payload     jsonb not null,
    created_by  uuid not null,
    primary key (id),
    check (((valid_to is null) or (valid_to > valid_from)))
);

create table fuel_hardware_fact
(
    id                    uuid not null,
    branch_id             uuid not null,
    operation_id          uuid,
    provider              text not null,
    organization          text not null,
    original_id           text not null,
    vehicle_id            uuid not null,
    driver_id             uuid not null,
    waybill_id            uuid not null,
    fuel_type             text not null,
    unit                  text not null,
    quantity              numeric not null,
    amount                numeric not null,
    quantity_delta        numeric,
    amount_delta          numeric,
    currency              text not null,
    occurred_at           timestamptz not null,
    kind                  text not null,
    related_fact_id       uuid,
    fuel_record_id        uuid,
    stock_issue_event_id  uuid,
    payload               jsonb not null,
    created_by            uuid not null,
    created_at            timestamptz not null,
    primary key (id),
    check ((amount >= (0))),
    check ((quantity >= (0))),
    foreign key (related_fact_id) references fuel_hardware_fact(id)
);

create table fuel_hardware_interval_close
(
    id          uuid not null,
    table_kind  text not null,
    target_id   uuid not null,
    valid_to    timestamptz not null,
    payload     jsonb not null,
    identity    text not null,
    created_by  uuid not null,
    created_at  timestamptz not null,
    primary key (id)
);

create table fuel_hardware_limit
(
    id            uuid not null,
    branch_id     uuid not null,
    subject_type  text not null,
    subject_id    uuid not null,
    fuel_type     text not null,
    unit          text not null,
    valid_from    timestamptz not null,
    valid_to      timestamptz,
    payload       jsonb not null,
    created_by    uuid not null,
    primary key (id),
    check (((valid_to is null) or (valid_to > valid_from))),
    check (subject_type in ('DRIVER', 'VEHICLE'))
    -- subject_type BAZADA: VEHICLE 1 | ISHLATILMAGAN: DRIVER
);

create table fuel_hardware_measurement
(
    id            uuid not null,
    asset_id      uuid not null,
    provider      text not null,
    organization  text not null,
    original_id   text not null,
    observed_at   timestamptz not null,
    received_at   timestamptz not null,
    payload       jsonb not null,
    identity      text not null,
    primary key (id),
    foreign key (asset_id) references fuel_hardware_asset(id)
);

create table fuel_hardware_operation
(
    id                    uuid not null,
    branch_id             uuid not null,
    account_id            uuid not null,
    vehicle_id            uuid not null,
    driver_id             uuid not null,
    waybill_id            uuid not null,
    provider              text not null,
    organization          text not null,
    original_command_id   text not null,
    state                 text not null,
    payload               jsonb not null,
    physical_gate         jsonb not null,
    identity              text not null,
    reservation_event_id  uuid,
    stock_issue_event_id  uuid,
    fact_id               uuid,
    result                jsonb,
    result_identity       text,
    discrepancy           text,
    created_at            timestamptz not null,
    updated_at            timestamptz not null,
    version               bigint not null,
    primary key (id)
);

create table fuel_hardware_outbox
(
    id            uuid not null,
    operation_id  uuid not null,
    account_id    uuid not null,
    owner         text not null,
    payload       jsonb not null,
    state         text not null,
    receipt       jsonb,
    created_at    timestamptz not null,
    primary key (id)
);

create table fuel_hardware_owner_balance
(
    account_id  uuid not null,
    unit        text not null,
    quantity    numeric not null,
    as_of       timestamptz not null,
    receipt_id  uuid not null,
    primary key (account_id),
    check ((quantity >= (0))),
    foreign key (receipt_id) references fuel_hardware_owner_receipt(id)
);

create table fuel_hardware_owner_receipt
(
    id            uuid not null,
    provider      text not null,
    organization  text not null,
    original_id   text not null,
    account_id    uuid not null,
    operation_id  uuid,
    payload       jsonb not null,
    identity      text not null,
    created_at    timestamptz not null,
    primary key (id)
);

create table fuel_hardware_provider
(
    provider                  text not null,
    organization              text not null,
    branch_id                 uuid not null,
    payload                   jsonb not null,
    enabled                   boolean not null,
    last_received_at          timestamptz,
    last_business_receipt_at  timestamptz,
    primary key (provider, organization)
);

create table fuel_hardware_receipt_decision
(
    id                  uuid not null,
    source_document_id  uuid not null,
    tank_id             uuid not null,
    branch_id           uuid not null,
    payload             jsonb not null,
    identity            text not null,
    created_by          uuid not null,
    created_at          timestamptz not null,
    primary key (id)
);

create table fuel_hardware_recovery
(
    id             uuid not null,
    kind           text not null,
    branch_id      uuid not null,
    target_id      uuid,
    actor_id       uuid not null,
    original       jsonb,
    original_hash  text not null,
    state          text not null,
    result         jsonb,
    reason         text,
    registered_at  timestamptz not null,
    finished_at    timestamptz,
    primary key (id),
    check (kind in ('AUTHORIZE', 'CARD_BATCH', 'CARD_MAP', 'DUT_RECONCILE')),
    -- kind BAZADA: AUTHORIZE 3 | ISHLATILMAGAN: CARD_BATCH, CARD_MAP, DUT_RECONCILE
    check ((original_hash ~ '^[a-f0-9]{64}$')),
    check (state in ('REGISTERED', 'RECORDED', 'NOT_EXECUTED')),
    -- state BAZADA: NOT_EXECUTED 2, RECORDED 1 | ISHLATILMAGAN: REGISTERED
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_hardware_recovery_effect
(
    recovery_id  uuid not null,
    row_index    integer not null,
    row_id       uuid not null,
    recorded_at  timestamptz not null,
    primary key (recovery_id, row_index),
    check ((row_index >= 0)),
    foreign key (recovery_id) references fuel_hardware_recovery(id),
    foreign key (row_id) references fuel_hardware_card_row(id)
);

-- ---------------------------------------------------------------------
-- Yoqilg'i ombori hujjatlari: kirim, chiqim, inventarizatsiya.
-- book_balance_liters (kitob bo'yicha qoldiq), actual_balance_liters (amaldagi
-- qoldiq) va delta_liters (tafovut) — INVENTARIZATSIYA TAFOVUTI SHU JADVALDAN
-- OLINADI. status: DRAFT, CONFIRMED, CANCELLED.
-- ---------------------------------------------------------------------
create table fuel_inventory_document
(
    id                         uuid not null,
    actual_balance_liters      numeric(12,3),
    amount                     numeric(14,2),
    book_balance_liters        numeric(12,3),
    counterparty_name          varchar(255),
    created_at                 timestamptz not null,
    created_by                 varchar(255) not null,
    currency                   varchar(8) not null,
    delta_liters               numeric(12,3),
    document_number            varchar(64) not null,
    document_type              varchar(32) not null,
    fuel_type                  varchar(32) not null,
    liters                     numeric(24,6),
    notes                      varchar(1024),
    occurred_at                timestamptz not null,
    reason                     varchar(512),
    status                     varchar(16) not null,
    updated_at                 timestamptz not null,
    confirmed_at               timestamptz,
    confirmed_by               varchar(128),
    warehouse_id               uuid,
    warehouse_name             varchar(256),
    canonical_source_identity  varchar(64),
    counterparty_warehouse_id  uuid,
    evidence_reference         varchar(512),
    related_operation_id       uuid,
    waybill_id                 uuid,
    physical_quantity          numeric(24,6),
    physical_unit              varchar(8),
    primary key (id),
    check (status in ('DRAFT', 'CONFIRMED', 'CANCELLED')),
    -- status BAZADA: CONFIRMED 9, DRAFT 1, CANCELLED 1
    check ( case when (physical_unit is null) then ((physical_quantity is null) and (liters is not null)) when ((physical_unit) = 'kg') then ((physical_quantity is not null) and (liters is null) and (physical_quantity > (0)) and (physical_quantity < ('1000000000000000000')) and ((physical_quantity) <> all (array['nan', 'infinity', '-infinity'])) and ((document_type) = any ((array['quality_release', 'reservation', 'issue', 'release'])[]))) else false end)
);

-- ---------------------------------------------------------------------
-- Yoqilg'i limitlari: haydovchi yoki mashina uchun kunlik/oylik maksimal litr va
-- summa. subject_type — DRIVER yoki VEHICLE, window_type — DAY yoki MONTH.
-- Bitta subyekt + yoqilg'i turi + davr uchun bitta faol limit bo'ladi.
-- LIMIT OSHGANI notification jadvalida FUEL_LIMIT_EXCEEDED sifatida qayd etiladi.
-- ---------------------------------------------------------------------
create table fuel_limit
(
    id            uuid not null,
    active        boolean not null,
    created_at    timestamptz not null,
    currency      varchar(8),
    fuel_type     varchar(32),
    max_amount    numeric(18,2),
    max_liters    numeric(14,3),
    note          varchar(256),
    subject_id    uuid not null,
    subject_type  varchar(16) not null,
    updated_at    timestamptz not null,
    window_type   varchar(16) not null,
    primary key (id),
    check (subject_type in ('DRIVER', 'VEHICLE')),
    -- subject_type BAZADA: VEHICLE 1 | ISHLATILMAGAN: DRIVER
    check (window_type in ('DAY', 'MONTH'))
    -- window_type BAZADA: DAY 1 | ISHLATILMAGAN: MONTH
);

create table fuel_lot_allocation
(
    operation_id  uuid not null,
    account_id    uuid not null,
    event_id      uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    sources       jsonb not null,
    document      jsonb not null,
    hash          text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (event_id) references fuel_stock_event(id)
);

create table fuel_lot_allocation_closed
(
    operation_id  uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
create table fuel_lot_allocation_effective
(
    operation_id  uuid,
    account_id    uuid,
    event_id      uuid,
    branch_id     uuid,
    actor_id      uuid,
    original      jsonb,
    sources       jsonb,
    document      jsonb,
    hash          text,
    recorded_at   timestamptz
);

create table fuel_lot_composition
(
    operation_id  uuid not null,
    account_id    uuid not null,
    event_id      uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    sources       jsonb not null,
    document      jsonb not null,
    hash          text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (event_id) references fuel_stock_event(id)
);

create table fuel_lot_composition_closed
(
    operation_id  uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
create table fuel_lot_composition_effective
(
    operation_id  uuid,
    account_id    uuid,
    event_id      uuid,
    branch_id     uuid,
    actor_id      uuid,
    original      jsonb,
    sources       jsonb,
    document      jsonb,
    hash          text,
    recorded_at   timestamptz
);

create table fuel_lot_correction
(
    operation_id  uuid not null,
    ordinal       bigint not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    revision      bigint not null,
    state         text not null,
    original      jsonb not null,
    sources       jsonb not null,
    document      jsonb not null,
    hash          text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_lot_correction_closed
(
    operation_id  uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_lot_correction_entry
(
    operation_id          uuid not null,
    journal_operation_id  uuid not null,
    kind                  text not null,
    account_id            uuid not null,
    branch_id             uuid not null,
    event_id              uuid not null,
    original              jsonb not null,
    hash                  text not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (event_id) references fuel_stock_event(id),
    foreign key (journal_operation_id) references fuel_lot_correction(operation_id)
);

create table fuel_lot_correction_impact
(
    journal_operation_id  uuid not null,
    account_id            uuid not null,
    lot_id                uuid not null,
    bucket                text not null,
    primary key (journal_operation_id, account_id, lot_id, bucket),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (journal_operation_id) references fuel_lot_correction(operation_id)
);

create table fuel_lot_distribution_part
(
    operation_id  uuid not null,
    account_id    uuid not null,
    event_id      uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    revision      bigint not null,
    state         text not null,
    original      jsonb not null,
    sources       jsonb not null,
    document      jsonb not null,
    hash          text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (event_id) references fuel_stock_event(id)
);

create table fuel_lot_distribution_part_closed
(
    operation_id  uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_mixing
(
    operation_id            uuid not null,
    mixing_id               uuid not null,
    account_id              uuid not null,
    branch_id               uuid not null,
    actor_id                uuid not null,
    revision                bigint not null,
    state                   text not null,
    original                jsonb not null,
    sources                 jsonb not null,
    document                jsonb not null,
    compatibility_document  jsonb not null,
    physical_document       jsonb,
    review_document         jsonb,
    hash                    text not null,
    recorded_at             timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_mixing_closed
(
    operation_id  uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_monthly_closed
(
    operation_id  uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id)
);

create table fuel_monthly_revision
(
    operation_id     uuid not null,
    report_id        uuid not null,
    branch_id        uuid not null,
    month            date not null,
    revision         bigint not null,
    state            text not null,
    actor_id         uuid not null,
    original         jsonb not null,
    sources          jsonb not null,
    calculation      jsonb not null,
    document         jsonb not null,
    review_document  jsonb,
    hash             text not null,
    recorded_at      timestamptz not null,
    primary key (operation_id),
    check ((revision > 0)),
    check (state in ('DRAFT', 'APPROVED', 'REVOKED', 'DISMISSED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

-- ---------------------------------------------------------------------
-- Mashinaning yoqilg'i sarf normasi: 100 km ga qancha litr (liters_per100km) va
-- ruxsat etilgan chetlanish foizi (tolerance_percent). effective_from/effective_to
-- — norma qaysi davrda amal qilgani.
-- NORMA HAR BIR MASHINA UCHUN ALOHIDA belgilanadi (vehicle_id).
-- ---------------------------------------------------------------------
create table fuel_norm
(
    id                      uuid not null,
    created_at              timestamptz not null,
    effective_from          date not null,
    effective_to            date,
    fuel_type               varchar(32) not null,
    liters_per100km         numeric(12,3) not null,
    tolerance_percent       numeric(8,2) not null,
    updated_at              timestamptz not null,
    vehicle_id              uuid not null,
    liters_per_engine_hour  numeric(12,3),
    updated_by              varchar(128),
    primary key (id)
);

create table fuel_norm_calculation_snapshot
(
    id                    uuid not null,
    branch_id             uuid not null,
    norm_revision_id      uuid,
    previous_snapshot_id  uuid,
    recorded_at           timestamptz not null,
    recorded_by_id        uuid not null,
    revision              bigint not null,
    snapshot_identity     varchar(64) not null,
    snapshot_json         text not null,
    source_closed_at      timestamptz not null,
    source_version        bigint not null,
    vehicle_id            uuid not null,
    waybill_id            uuid not null,
    primary key (id)
);

create table fuel_norm_revision
(
    id                    uuid not null,
    approved_at           timestamptz not null,
    approved_by_id        uuid not null,
    approved_by_name      varchar(256) not null,
    basis                 varchar(2000) not null,
    branch_id             uuid not null,
    combination_key       varchar(40) not null,
    document_reference    varchar(255) not null,
    effective_from        date not null,
    fuel_type             varchar(32) not null,
    payload_identity      varchar(64) not null,
    payload_json          text not null,
    previous_revision_id  uuid,
    revision              bigint not null,
    spec_json             text not null,
    trailer_id            uuid,
    vehicle_id            uuid not null,
    primary key (id)
);

-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
create table fuel_owner_current_receipt
(
    account_id    uuid,
    unit          text,
    quantity      numeric,
    as_of         timestamptz,
    receipt_id    uuid,
    provider      text,
    organization  text,
    original_id   text,
    identity      text,
    received_at   timestamptz
);

create table fuel_owner_movement
(
    id                  uuid not null,
    provider            text not null,
    organization        text not null,
    original_key        text not null,
    branch_id           uuid not null,
    actor_id            uuid not null,
    source_document_id  uuid not null,
    request_json        jsonb not null,
    command_json        jsonb not null,
    command_hash        text not null,
    created_at          timestamptz not null,
    primary key (id),
    check ((command_hash ~ '^[a-f0-9]{64}$')),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (source_document_id) references fuel_inventory_document(id)
);

create table fuel_owner_movement_balance
(
    account_id  uuid not null,
    unit        text not null,
    quantity    numeric not null,
    as_of       timestamptz not null,
    receipt_id  uuid not null,
    primary key (account_id),
    check ((quantity >= (0))),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (receipt_id) references fuel_owner_movement_receipt(id)
);

create table fuel_owner_movement_outbox
(
    operation_id  uuid not null,
    state         text not null,
    attempted_at  timestamptz,
    primary key (operation_id),
    check (state in ('PENDING', 'UNKNOWN', 'ACCEPTED', 'REJECTED', 'CANCELLED')),
    -- state BAZADA: jadval bo'sh
    foreign key (operation_id) references fuel_owner_movement(id)
);

create table fuel_owner_movement_receipt
(
    id            uuid not null,
    operation_id  uuid not null,
    provider      text not null,
    organization  text not null,
    original_id   text not null,
    state         text not null,
    payload       jsonb not null,
    identity      text not null,
    recorded_at   timestamptz not null,
    primary key (id),
    check ((identity ~ '^[a-f0-9]{64}$')),
    check (state in ('ACCEPTED', 'REJECTED', 'WAITING', 'UNKNOWN')),
    -- state BAZADA: jadval bo'sh
    foreign key (operation_id) references fuel_owner_movement(id)
);

-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
create table fuel_owner_quality_receipt
(
    account_id     uuid,
    unit           text,
    quantity       numeric,
    as_of          timestamptz,
    receipt_id     uuid,
    provider       text,
    organization   text,
    original_id    text,
    identity       text,
    received_at    timestamptz,
    quality_proof  jsonb
);

create table fuel_owner_source_original
(
    source_document_id  uuid not null,
    account_id          uuid not null,
    actor_id            uuid not null,
    original            jsonb not null,
    identity            text not null,
    primary key (source_document_id),
    check ((identity ~ '^[a-f0-9]{64}$')),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (source_document_id) references fuel_inventory_document(id)
);

create table fuel_physical_correction
(
    operation_id           uuid not null,
    correction_id          uuid not null,
    account_id             uuid not null,
    branch_id              uuid not null,
    actor_id               uuid not null,
    revision               bigint not null,
    state                  text not null,
    original               jsonb not null,
    sources                jsonb not null,
    document               jsonb not null,
    physical_document      jsonb not null,
    counterparty_document  jsonb,
    review_document        jsonb,
    hash                   text not null,
    recorded_at            timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_physical_correction_closed
(
    operation_id  uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_primary_balance_closed
(
    operation_id  uuid not null,
    waybill_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id)
);

create table fuel_primary_balance_revision
(
    operation_id     uuid not null,
    waybill_id       uuid not null,
    branch_id        uuid not null,
    revision         bigint not null,
    state            text not null,
    actor_id         uuid not null,
    original         jsonb not null,
    sources          jsonb not null,
    document         jsonb not null,
    review_document  jsonb,
    hash             text not null,
    recorded_at      timestamptz not null,
    primary key (operation_id),
    check ((revision > 0)),
    check (state in ('DRAFT', 'APPROVED', 'REVOKED', 'DISMISSED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (waybill_id) references waybill(id)
);

create table fuel_quality_admission
(
    event_id     uuid not null,
    account_id   uuid not null,
    evidence     jsonb not null,
    hash         text not null,
    recorded_at  timestamptz not null,
    primary key (event_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (event_id) references fuel_stock_event(id)
);

create table fuel_quality_batch
(
    operation_id          uuid not null,
    batch_id              uuid not null,
    account_id            uuid not null,
    branch_id             uuid not null,
    actor_id              uuid not null,
    receipt_operation_id  uuid not null,
    revision              bigint not null,
    action                text not null,
    state                 text not null,
    original              jsonb not null,
    batch                 jsonb not null,
    sources               jsonb not null,
    proofs                jsonb not null,
    hash                  text not null,
    recorded_at           timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_quality_batch_standard
(
    operation_id           uuid not null,
    account_id             uuid not null,
    standard_operation_id  uuid not null,
    assessment             jsonb not null,
    hash                   text not null,
    recorded_at            timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (operation_id) references fuel_quality_batch(operation_id),
    foreign key (standard_operation_id) references fuel_quality_standard(operation_id)
);

create table fuel_quality_closed_operation
(
    operation_id  uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    kind          text not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_quality_cutover
(
    operation_id  uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    revision      bigint not null,
    state         text not null,
    original      jsonb not null,
    sources       jsonb not null,
    document      jsonb not null,
    hash          text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_quality_cutover_closed
(
    operation_id  uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_quality_decision
(
    operation_id  uuid not null,
    batch_id      uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    revision      bigint not null,
    original      jsonb not null,
    sources       jsonb not null,
    document      jsonb not null,
    hash          text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_quality_decision_closed
(
    operation_id  uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_quality_opening_admission
(
    opening_id   uuid not null,
    account_id   uuid not null,
    evidence     jsonb not null,
    hash         text not null,
    recorded_at  timestamptz not null,
    primary key (opening_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (opening_id) references fuel_stock_opening(id)
);

create table fuel_quality_policy
(
    operation_id  uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    revision      bigint not null,
    state         text not null,
    original      jsonb not null,
    sources       jsonb not null,
    document      jsonb not null,
    hash          text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_quality_policy_closed
(
    operation_id  uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_quality_standard
(
    operation_id  uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    revision      bigint not null,
    state         text not null,
    original      jsonb not null,
    sources       jsonb not null,
    document      jsonb not null,
    hash          text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_quality_standard_closed
(
    operation_id  uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_recall
(
    operation_id  uuid not null,
    recall_id     uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    lot_id        uuid not null,
    bucket        text not null,
    revision      bigint not null,
    state         text not null,
    original      jsonb not null,
    sources       jsonb not null,
    document      jsonb not null,
    hash          text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_recall_attention_delivery
(
    id                    uuid not null,
    event_id              uuid not null,
    observation_revision  bigint not null,
    policy_id             uuid not null,
    target_id             uuid not null,
    target_hash           text not null,
    stage                 text not null,
    state                 text not null,
    notification_id       uuid,
    recorded_at           timestamptz not null,
    primary key (id),
    foreign key (event_id, observation_revision) references fuel_recall_attention_observation(event_id, revision),
    foreign key (event_id) references fuel_recall_attention_event(id),
    foreign key (notification_id) references notification(id),
    foreign key (policy_id) references fuel_recall_attention_policy(operation_id)
);

create table fuel_recall_attention_event
(
    id               uuid not null,
    source_kind      text not null,
    source_id        uuid not null,
    source_revision  bigint not null,
    source_hash      text not null,
    account_id       uuid not null,
    recall_id        uuid not null,
    subject_id       uuid not null,
    actor_id         uuid not null,
    kind             text not null,
    recorded_at      timestamptz not null,
    primary key (id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id)
);

create table fuel_recall_attention_observation
(
    event_id     uuid not null,
    revision     bigint not null,
    proof        jsonb not null,
    hash         text not null,
    recorded_at  timestamptz not null,
    primary key (event_id, revision),
    foreign key (event_id) references fuel_recall_attention_event(id)
);

create table fuel_recall_attention_policy
(
    operation_id  uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    owner_epoch   bigint not null,
    kind          text not null,
    revision      bigint not null,
    original      jsonb not null,
    document      jsonb not null,
    hash          text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_recall_attention_policy_closed
(
    operation_id  uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_recall_attention_scan
(
    event_id         uuid not null,
    last_scanned_at  timestamptz,
    next_scan_at     timestamptz not null,
    failures         integer not null,
    last_error_code  text,
    primary key (event_id),
    check ((failures >= 0)),
    foreign key (event_id) references fuel_recall_attention_event(id)
);

create table fuel_recall_closed
(
    operation_id  uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_recall_completion
(
    operation_id     uuid not null,
    recall_id        uuid not null,
    account_id       uuid not null,
    branch_id        uuid not null,
    actor_id         uuid not null,
    revision         bigint not null,
    state            text not null,
    original         jsonb not null,
    sources          jsonb not null,
    document         jsonb not null,
    review_document  jsonb,
    hash             text not null,
    recorded_at      timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_recall_completion_closed
(
    operation_id  uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_recall_consumed_clearance
(
    operation_id     uuid not null,
    recall_id        uuid not null,
    vehicle_id       uuid not null,
    account_id       uuid not null,
    branch_id        uuid not null,
    actor_id         uuid not null,
    revision         bigint not null,
    state            text not null,
    original         jsonb not null,
    sources          jsonb not null,
    document         jsonb not null,
    review_document  jsonb,
    hash             text not null,
    recorded_at      timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table fuel_recall_consumed_clearance_closed
(
    operation_id  uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_recall_disposal
(
    operation_id     uuid not null,
    disposal_id      uuid not null,
    recall_id        uuid not null,
    account_id       uuid not null,
    branch_id        uuid not null,
    actor_id         uuid not null,
    revision         bigint not null,
    state            text not null,
    original         jsonb not null,
    sources          jsonb not null,
    document         jsonb not null,
    review_document  jsonb,
    hash             text not null,
    recorded_at      timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_recall_disposal_closed
(
    operation_id  uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_recall_hold
(
    operation_id  uuid not null,
    recall_id     uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    sources       jsonb not null,
    document      jsonb not null,
    hash          text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_recall_hold_closed
(
    operation_id  uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_recall_recovery
(
    operation_id  uuid not null,
    recall_id     uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    sources       jsonb not null,
    document      jsonb not null,
    hash          text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_recall_recovery_closed
(
    operation_id  uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_recall_supplier_return
(
    operation_id     uuid not null,
    return_id        uuid not null,
    recall_id        uuid not null,
    account_id       uuid not null,
    branch_id        uuid not null,
    actor_id         uuid not null,
    revision         bigint not null,
    state            text not null,
    original         jsonb not null,
    sources          jsonb not null,
    document         jsonb not null,
    action_document  jsonb,
    hash             text not null,
    recorded_at      timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_recall_supplier_return_closed
(
    operation_id  uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_recall_vehicle_clearance
(
    operation_id     uuid not null,
    recall_id        uuid not null,
    vehicle_id       uuid not null,
    account_id       uuid not null,
    branch_id        uuid not null,
    actor_id         uuid not null,
    revision         bigint not null,
    state            text not null,
    original         jsonb not null,
    sources          jsonb not null,
    document         jsonb not null,
    review_document  jsonb,
    hash             text not null,
    recorded_at      timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table fuel_recall_vehicle_clearance_closed
(
    operation_id  uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

-- ---------------------------------------------------------------------
-- YOQILG'I SARFI BO'YICHA ASOSIY JADVAL — QUYISH VA SARF YOZUVLARI SHU JADVALDAN
-- OLINADI. Litr, summa, amaldagi sarf (actual_consumption_per100km), norma
-- (norm_liters_per100km) va ulardan chetlanish foizi (deviation_percent).
-- severity — chetlanish darajasi: NONE, WARNING, CRITICAL.
-- YOQILG'I ANOMALIYASI SO'RALSA severity <> 'NONE' bo'yicha olinadi, batafsil
-- sabab esa fuel_record_risk_flag jadvalida.
-- ---------------------------------------------------------------------
create table fuel_record
(
    id                           uuid not null,
    actual_consumption_per100km  numeric(12,3),
    actual_distance_km           numeric(12,3),
    amount                       numeric(14,2) not null,
    created_at                   timestamptz not null,
    currency                     varchar(8) not null,
    deviation_percent            numeric(10,2),
    driver_id                    uuid,
    fuel_type                    varchar(32) not null,
    liters                       numeric(24,6),
    norm_liters_per100km         numeric(12,3),
    occurred_at                  timestamptz not null,
    severity                     varchar(16) not null,
    source_reference             varchar(255),
    source_type                  varchar(32) not null,
    trip_id                      uuid,
    updated_at                   timestamptz not null,
    vehicle_id                   uuid not null,
    actual_engine_hours          numeric(12,3),
    expected_fuel_liters         numeric(12,3),
    norm_liters_per_engine_hour  numeric(12,3),
    physical_quantity            numeric(24,6),
    physical_unit                varchar(8),
    primary key (id),
    check (severity in ('NONE', 'WARNING', 'CRITICAL')),
    -- severity BAZADA: NONE 86 | ISHLATILMAGAN: WARNING, CRITICAL
    check ( case when (physical_unit is null) then ((physical_quantity is null) and (liters is not null)) when ((physical_unit) = 'kg') then ((physical_quantity is not null) and (liters is null) and (physical_quantity > (0)) and (physical_quantity < ('1000000000000000000')) and ((physical_quantity) <> all (array['nan', 'infinity', '-infinity'])) and ((source_type) = 'hardware')) else false end)
);

create table fuel_refuel_import_input
(
    external_id     varchar(255) not null,
    transaction_id  uuid not null,
    record_id       uuid,
    actor_id        uuid,
    branch_id       uuid,
    input_text      text,
    input_hash      varchar(64),
    recorded_at     timestamptz not null,
    captured_at     timestamptz,
    source_xid      xid8 not null,
    state           varchar(16) not null,
    primary key (external_id),
    check (((((state) = 'pending') and (actor_id is null) and (branch_id is null) and (input_text is null) and (input_hash is null) and (captured_at is null)) or (((state) = 'captured') and (record_id is not null) and (actor_id is not null) and (branch_id is not null) and (input_text is not null) and (input_hash is not null) and (captured_at is not null)))),
    check (((input_hash) ~ '^[0-9a-f]{64}$')),
    foreign key (actor_id) references app_user(id),
    foreign key (record_id) references fuel_record(id),
    foreign key (transaction_id) references fuel_card_transaction(id)
);

-- ---------------------------------------------------------------------
-- Yoqilg'i sathi sensorlarining reyestri: ishlab chiqaruvchi, model, seriya raqami,
-- sensor kodi, bak hajmi. Mashinaga o'rnatilishi
-- vehicle_fuel_sensor_installation jadvali orqali.
-- ---------------------------------------------------------------------
create table fuel_sensor
(
    id                    uuid not null,
    active                boolean not null,
    created_at            timestamptz not null,
    created_by            varchar(256) not null,
    manufacturer          varchar(128) not null,
    model                 varchar(128) not null,
    notes                 varchar(512),
    sensor_code           varchar(64) not null,
    serial_number         varchar(128),
    tank_capacity_liters  numeric(12,3),
    updated_at            timestamptz not null,
    updated_by            varchar(256) not null,
    primary key (id)
);

-- ---------------------------------------------------------------------
-- Sensor ko'rsatkichlari: bakdagi yoqilg'i litr va foizda, koordinata,
-- harorat, kuchlanish, o'lchov vaqti (recorded_at).
-- CHEK VA SENSOR TAFOVUTINI TOPISH UCHUN fuel_card_transaction BILAN vaqt va
-- mashina bo'yicha solishtiriladi (yoqilg'i o'g'irligini aniqlash).
-- ---------------------------------------------------------------------
create table fuel_sensor_reading
(
    id                   uuid not null,
    created_at           timestamptz not null,
    device_id            varchar(128) not null,
    fuel_level_liters    numeric(12,3) not null,
    fuel_level_percent   numeric(8,3),
    latitude             numeric(10,7),
    longitude            numeric(10,7),
    raw_value            numeric(16,6),
    recorded_at          timestamptz not null,
    sensor_id            uuid not null,
    telematics_event_id  uuid,
    temperature_c        numeric(8,3),
    vehicle_id           uuid not null,
    voltage              numeric(8,3),
    primary key (id)
);

create table fuel_stock_account
(
    id                  uuid not null,
    basis               varchar(2000) not null,
    branch_id           uuid not null,
    configured_at       timestamptz not null,
    configured_by_id    uuid not null,
    document_reference  varchar(255) not null,
    fuel_type           varchar(32) not null,
    owner               varchar(20) not null,
    owner_epoch         bigint not null,
    payload_identity    varchar(64) not null,
    payload_json        text not null,
    unit                varchar(8) not null,
    warehouse_id        uuid not null,
    primary key (id),
    check (owner in ('UNCONFIGURED', 'ATIL', 'ERP_WMS')),
    -- owner BAZADA: ATIL 1 | ISHLATILMAGAN: UNCONFIGURED, ERP_WMS
    check (unit in ('L', 'M3', 'KG', 'KWH'))
    -- unit BAZADA: L 1 | ISHLATILMAGAN: M3, KG, KWH
);

create table fuel_stock_command_cancel
(
    id                uuid not null,
    account_id        uuid not null,
    actor_id          uuid not null,
    payload_json      text not null,
    payload_identity  varchar(64) not null,
    cancelled_at      timestamptz not null,
    primary key (id)
);

create table fuel_stock_event
(
    id                        uuid not null,
    accepted_by_id            uuid not null,
    account_id                uuid not null,
    bucket                    varchar(16) not null,
    counterpart_warehouse_id  uuid,
    document_reference        varchar(255) not null,
    driver_id                 uuid,
    effective_at              timestamptz not null,
    expected_version          bigint not null,
    held_delta                numeric not null,
    kind                      varchar(32) not null,
    owner_epoch               bigint not null,
    payload_identity          varchar(64) not null,
    payload_json              text not null,
    quantity                  numeric not null,
    quarantine_delta          numeric not null,
    recorded_at               timestamptz not null,
    related_operation_id      uuid,
    sequence_number           bigint not null,
    source_document_id        uuid not null,
    source_hash               varchar(64) not null,
    source_json               text not null,
    unit                      varchar(8) not null,
    usable_delta              numeric not null,
    vehicle_id                uuid,
    waybill_id                uuid,
    primary key (id),
    check (bucket in ('USABLE', 'QUARANTINE')),
    -- bucket BAZADA: USABLE 2, QUARANTINE 2
    check (unit in ('L', 'M3', 'KG', 'KWH'))
    -- unit BAZADA: L 4 | ISHLATILMAGAN: M3, KG, KWH
);

create table fuel_stock_opening
(
    id                     uuid not null,
    account_id             uuid not null,
    basis                  varchar(2000) not null,
    document_reference     varchar(255) not null,
    evidence_json          text not null,
    inventory_observed_at  timestamptz not null,
    opened_at              timestamptz not null,
    opened_by_id           uuid not null,
    owner_epoch            bigint not null,
    payload_identity       varchar(64) not null,
    payload_json           text not null,
    preview_hash           varchar(64) not null,
    quarantine_quantity    numeric not null,
    sequence_number        bigint not null,
    unit                   varchar(8) not null,
    usable_quantity        numeric not null,
    primary key (id),
    check (unit in ('L', 'M3', 'KG', 'KWH'))
    -- unit BAZADA: L 1 | ISHLATILMAGAN: M3, KG, KWH
);

create table fuel_stock_projection
(
    account_id           uuid not null,
    held_quantity        numeric not null,
    opening_id           uuid not null,
    owner_epoch          bigint not null,
    quarantine_quantity  numeric not null,
    unit                 varchar(8) not null,
    usable_quantity      numeric not null,
    version              bigint not null,
    primary key (account_id),
    check (unit in ('L', 'M3', 'KG', 'KWH'))
    -- unit BAZADA: L 1 | ISHLATILMAGAN: M3, KG, KWH
);

create table fuel_stock_source_cancel
(
    id                uuid not null,
    account_id        uuid not null,
    actor_id          uuid not null,
    payload_json      text not null,
    payload_identity  varchar(64) not null,
    cancelled_at      timestamptz not null,
    primary key (id)
);

create table fuel_stock_transaction
(
    id                     uuid not null,
    actor                  varchar(128),
    balance_after_liters   numeric(14,3) not null,
    balance_before_liters  numeric(14,3) not null,
    created_at             timestamptz not null,
    fuel_type              varchar(32) not null,
    notes                  varchar(512),
    quantity_liters        numeric(14,3) not null,
    reference_id           uuid,
    reference_number       varchar(64),
    reference_type         varchar(32),
    transaction_type       varchar(32) not null,
    warehouse_id           uuid not null,
    warehouse_name         varchar(256),
    primary key (id)
);

create table fuel_storage_weather
(
    warehouse_id        uuid not null,
    fetched_at          timestamptz,
    forecast_date       date,
    latitude            float8 not null,
    longitude           float8 not null,
    max_temperaturec    float8 not null,
    mean_temperaturec   float8 not null,
    min_temperaturec    float8 not null,
    max_temperature_c   float8,
    mean_temperature_c  float8,
    min_temperature_c   float8,
    primary key (warehouse_id)
);

create table fuel_tank_provenance
(
    operation_id     uuid not null,
    interval_id      uuid not null,
    account_id       uuid not null,
    branch_id        uuid not null,
    actor_id         uuid not null,
    revision         bigint not null,
    state            text not null,
    original         jsonb not null,
    sources          jsonb not null,
    document         jsonb not null,
    review_document  jsonb,
    hash             text not null,
    recorded_at      timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_tank_provenance_closed
(
    operation_id  uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (account_id) references fuel_stock_account(id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

-- ---------------------------------------------------------------------
-- Yoqilg'i turlari katalogi (kod va nomi). Mashina qaysi yoqilg'i bilan
-- ishlashini vehicle_reference_data_fuel_type bog'lovchi jadvali ko'rsatadi.
-- ---------------------------------------------------------------------
create table fuel_type
(
    id        uuid not null,
    code      varchar(32) not null,
    label     varchar(64) not null,
    status    boolean,
    subtitle  varchar(255),
    primary key (id)
    -- status BAZADA: jadval bo'sh
);

create table fuel_unit_consumption_closed
(
    operation_id  uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id)
);

create table fuel_unit_consumption_revision
(
    operation_id     uuid not null,
    interval_id      uuid not null,
    branch_id        uuid not null,
    revision         bigint not null,
    state            text not null,
    actor_id         uuid not null,
    original         jsonb not null,
    sources          jsonb not null,
    calculation      jsonb not null,
    document         jsonb not null,
    review_document  jsonb,
    hash             text not null,
    recorded_at      timestamptz not null,
    primary key (operation_id),
    check ((revision > 0)),
    check (state in ('DRAFT', 'APPROVED', 'REVOKED', 'DISMISSED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table fuel_warehouse_stock
(
    id                      uuid not null,
    capacity_liters         numeric(14,3),
    created_at              timestamptz not null,
    current_balance_liters  numeric(14,3) not null,
    fuel_type               varchar(32) not null,
    updated_at              timestamptz not null,
    warehouse_id            uuid not null,
    warehouse_name          varchar(256),
    primary key (id)
);

create table fuel_work_distribution
(
    operation_id     uuid not null,
    account_id       uuid not null,
    interval_id      uuid not null,
    branch_id        uuid not null,
    actor_id         uuid not null,
    revision         bigint not null,
    state            text not null,
    original         jsonb not null,
    sources          jsonb not null,
    calculation      jsonb not null,
    document         jsonb not null,
    review_document  jsonb,
    hash             text not null,
    recorded_at      timestamptz not null,
    primary key (operation_id)
);

create table fuel_work_distribution_closed
(
    operation_id  uuid not null,
    account_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id)
);

create table gate_pass
(
    id                    uuid not null,
    created_at            timestamptz not null,
    created_by            uuid,
    expires_at            timestamptz,
    issued_at             timestamptz not null,
    notes                 varchar(1000),
    pass_number           varchar(64) not null,
    status                varchar(16) not null,
    updated_at            timestamptz,
    used_at               timestamptz,
    driver_id             uuid,
    trip_id               uuid,
    vehicle_id            uuid,
    branch_id             uuid,
    carrier_id            uuid,
    composition_identity  varchar(128),
    entered_at            timestamptz,
    exited_at             timestamptz,
    kind                  varchar(16),
    shipment_id           uuid,
    site_id               uuid,
    valid_from            timestamptz,
    object_version        bigint not null,
    primary key (id),
    check (status in ('ISSUED', 'USED', 'CANCELLED', 'AT_GATE')),
    -- status BAZADA: jadval bo'sh
    foreign key (vehicle_id) references transport_vehicle(id),
    foreign key (trip_id) references trip(id),
    foreign key (driver_id) references driver(id)
);

create table gps_archive_coverage
(
    binding_id    uuid not null,
    window_from   timestamptz not null,
    window_until  timestamptz not null,
    completed_at  timestamptz not null,
    primary key (binding_id, window_from, window_until),
    check ((window_from < window_until)),
    foreign key (binding_id) references vehicle_gps(id)
);

create table gps_archive_cursor
(
    binding_id    uuid not null,
    lane          varchar(16) not null,
    next_from     timestamptz not null,
    window_from   timestamptz,
    window_until  timestamptz,
    watermark     bigint,
    after_id      bigint not null,
    lease_token   uuid,
    lease_until   timestamptz,
    retry_at      timestamptz,
    error_code    varchar(64),
    updated_at    timestamptz not null,
    primary key (binding_id, lane),
    check ((after_id >= 0)),
    check ((((window_from is null) and (window_until is null) and (watermark is null) and (after_id = 0)) or ((window_from is not null) and (window_until is not null) and (window_from < window_until)))),
    check (((watermark is null) or (watermark >= after_id))),
    check (((lease_token is null) = (lease_until is null))),
    check (lane in ('RECENT', 'BACKFILL')),
    -- lane BAZADA: BACKFILL 70, RECENT 70
    foreign key (binding_id) references vehicle_gps(id)
);

create table gps_archive_point
(
    binding_id          uuid not null,
    vehicle_id          uuid not null,
    provider_device_id  bigint not null,
    provider_point_id   bigint not null,
    fix_time            timestamptz not null,
    received_at         timestamptz not null,
    payload             text not null,
    payload_hash        varchar(64) not null,
    primary key (binding_id, provider_point_id),
    check (((payload_hash) = encode(sha256(convert_to(payload, 'utf8'::name)), 'hex'))),
    check ((jsonb_typeof((payload)::jsonb) = 'object')),
    check ((provider_device_id > 0)),
    check ((provider_point_id > 0)),
    foreign key (binding_id) references vehicle_gps(id)
);

create table gps_configuration
(
    id                 uuid not null,
    actor_id           uuid,
    applied_version    bigint,
    binding_id         uuid,
    binding_version    bigint not null,
    created_at         timestamptz,
    desired_version    bigint not null,
    host               varchar(255),
    model_id           varchar(255),
    payload_encrypted  text,
    port               integer not null,
    state              varchar(255),
    primary key (id),
    foreign key (binding_id) references vehicle_gps(id)
);

create table gps_control_request
(
    id                  uuid not null,
    actor_id            uuid,
    created_at          timestamptz,
    idempotency_key     varchar(255),
    payload_hash        varchar(255),
    response_encrypted  text,
    primary key (id)
);

create table gps_device_credential
(
    id               uuid not null,
    actor_id         uuid,
    binding_id       uuid,
    binding_version  bigint not null,
    created_at       timestamptz,
    generation       bigint not null,
    idempotency_key  varchar(255),
    rate_count       integer not null,
    rate_window      timestamptz,
    revoked_at       timestamptz,
    token_hash       varchar(255),
    primary key (id),
    foreign key (binding_id) references vehicle_gps(id)
);

create table gps_event_command
(
    id             uuid not null,
    actor_id       uuid not null,
    branch_id      uuid not null,
    action         varchar(32) not null,
    request_hash   char(64) not null,
    state          varchar(32) not null,
    response       jsonb not null,
    closure_basis  varchar(2000),
    created_at     timestamptz not null,
    primary key (id),
    check (action in ('SAVE_POLICY', 'SAVE_ZONE', 'DECIDE', 'EVALUATE', 'REVIEW')),
    -- action BAZADA: jadval bo'sh
    check (((((state) = 'not_executed') and (closure_basis is not null) and (length(btrim((closure_basis))) > 0) and (response = 'null'::jsonb)) or (((state) = 'applied') and (closure_basis is null)))),
    check ((request_hash ~ '^[a-f0-9]{64}$')),
    check (state in ('APPLIED', 'NOT_EXECUTED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table gps_event_definition_decision
(
    id             uuid not null,
    branch_id      uuid not null,
    kind           varchar(16) not null,
    definition_id  uuid not null,
    actor_id       uuid not null,
    action         varchar(16) not null,
    basis          varchar(2000) not null,
    created_at     timestamptz not null,
    primary key (id),
    check (action in ('APPROVE', 'REVOKE')),
    -- action BAZADA: jadval bo'sh
    check ((length(btrim((basis))) > 0)),
    check (kind in ('POLICY', 'ZONE')),
    -- kind BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table gps_event_evaluation
(
    id            uuid not null,
    actor_id      uuid not null,
    vehicle_id    uuid not null,
    branch_id     uuid not null,
    trip_id       uuid,
    revision      integer not null,
    previous_id   uuid,
    selection_id  uuid not null,
    policy_id     uuid not null,
    source_hash   char(64) not null,
    from_at       timestamptz not null,
    to_at         timestamptz not null,
    body          jsonb not null,
    source_body   jsonb not null,
    created_at    timestamptz not null,
    primary key (id),
    check ((to_at > from_at)),
    check ((revision > 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (policy_id) references gps_event_policy(id),
    foreign key (previous_id) references gps_event_evaluation(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table gps_event_evidence_review
(
    id             uuid not null,
    evaluation_id  uuid not null,
    actor_id       uuid not null,
    branch_id      uuid not null,
    body           jsonb not null,
    created_at     timestamptz not null,
    primary key (id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (evaluation_id) references gps_event_evaluation(id)
);

create table gps_event_policy
(
    id          uuid not null,
    branch_id   uuid not null,
    author_id   uuid not null,
    valid_from  timestamptz not null,
    valid_to    timestamptz not null,
    body        jsonb not null,
    created_at  timestamptz not null,
    primary key (id),
    check ((valid_to > valid_from)),
    foreign key (author_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table gps_event_zone
(
    id          uuid not null,
    zone_id     uuid not null,
    branch_id   uuid not null,
    author_id   uuid not null,
    valid_from  timestamptz not null,
    valid_to    timestamptz not null,
    body        jsonb not null,
    created_at  timestamptz not null,
    primary key (id),
    check ((valid_to > valid_from)),
    foreign key (author_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table gps_ingest_event
(
    id            uuid not null,
    attempts      integer not null,
    binding_id    uuid,
    created_at    timestamptz,
    device_id     bigint not null,
    error_code    varchar(255),
    event_id      uuid,
    lease_token   uuid,
    lease_until   timestamptz,
    payload       text,
    payload_hash  varchar(255),
    retry_at      timestamptz,
    state         varchar(255),
    unique_id     varchar(255),
    primary key (id),
    foreign key (binding_id) references vehicle_gps(id)
);

create table gps_ingest_receipt
(
    id               uuid not null,
    accepted_count   integer not null,
    created_at       timestamptz,
    credential_id    uuid,
    device_id        bigint not null,
    duplicate_count  integer not null,
    event_ids        text,
    primary key (id),
    foreign key (credential_id) references gps_device_credential(id)
);

create table gps_operation
(
    id                     uuid not null,
    actor_context          varchar(1024) not null,
    actor_id               uuid not null,
    binding_id             uuid,
    created_at             timestamptz not null,
    error_code             varchar(128),
    expected_version       bigint,
    gps_contact_driver_id  uuid,
    idempotency_key        varchar(128) not null,
    kind                   varchar(32) not null,
    lease_token            uuid,
    lease_until            timestamptz,
    mutation_started_at    timestamptz,
    payload_hash           varchar(64) not null,
    provider_device_id     bigint,
    readback_attempts      integer not null,
    retry_at               timestamptz,
    scope_context          varchar(1024),
    state                  varchar(32) not null,
    target_vehicle_id      uuid,
    unique_id              varchar(64),
    updated_at             timestamptz not null,
    vehicle_id             uuid not null,
    version                bigint not null,
    desired_version        bigint,
    ownership_basis        varchar(2000),
    ownership_verified_at  timestamptz,
    primary key (id),
    check (kind in ('CREATE_ATTACH', 'ATTACH', 'UPDATE', 'REBIND', 'DETACH', 'DELETE_PROVIDER', 'VERIFY_OWNERSHIP', 'APPLY_CONFIGURATION', 'VERIFY_CONFIGURATION')),
    -- kind BAZADA: CREATE_ATTACH 13, UPDATE 1 | ISHLATILMAGAN: ATTACH, REBIND, DETACH, DELETE_PROVIDER, VERIFY_OWNERSHIP, APPLY_CONFIGURATION, VERIFY_CONFIGURATION
    check (state in ('PENDING', 'PROCESSING', 'RECONCILING', 'SUCCEEDED', 'FAILED', 'NEEDS_REVIEW'))
    -- state BAZADA: FAILED 9, SUCCEEDED 5 | ISHLATILMAGAN: PENDING, PROCESSING, RECONCILING, NEEDS_REVIEW
);

create table gps_operation_review
(
    id                uuid not null,
    action            varchar(32) not null,
    actor_id          uuid not null,
    basis             varchar(2000) not null,
    expected_version  bigint not null,
    occurred_at       timestamptz not null,
    operation_id      uuid not null,
    payload_hash      varchar(64) not null,
    resulting_state   varchar(32) not null,
    primary key (id),
    check (action in ('RECHECK_PROVIDER', 'ABORT_UNSTARTED')),
    -- action BAZADA: jadval bo'sh
    check (resulting_state in ('PENDING', 'PROCESSING', 'RECONCILING', 'SUCCEEDED', 'FAILED', 'NEEDS_REVIEW')),
    -- resulting_state BAZADA: jadval bo'sh
    foreign key (operation_id) references gps_operation(id)
);

create table gps_provider_diagnostic
(
    id              uuid not null,
    actor_id        uuid not null,
    availability    varchar(32) not null,
    checked_at      timestamptz not null,
    device_count    integer,
    latency_millis  bigint,
    primary key (id),
    check (availability in ('AVAILABLE', 'UNCONFIGURED', 'UNAUTHORIZED', 'NETWORK_ERROR', 'INVALID_RESPONSE', 'PROVIDER_ERROR'))
    -- availability BAZADA: jadval bo'sh
);

create table gps_provider_settings
(
    id                         bigint not null,
    base_url                   varchar(255),
    fmb920_enabled             boolean,
    http_enabled               boolean not null,
    ingress_host               varchar(255),
    integration_key_encrypted  text,
    password_encrypted         text,
    teltonika_port             integer not null,
    username                   varchar(255),
    version                    bigint not null,
    primary key (id)
);

create table hazard_profile
(
    id                     uuid not null,
    created_at             timestamptz not null,
    emergency_code         varchar(64),
    hazard_class           varchar(32),
    notes                  varchar(1000),
    official_name          varchar(256) not null,
    packing_group          varchar(32),
    requires_adr           boolean,
    requires_placards      boolean,
    requires_special_tank  boolean,
    un_number              varchar(32) not null,
    updated_at             timestamptz,
    primary key (id)
);

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
create table incident
(
    id                uuid not null,
    created_at        timestamptz not null,
    description       varchar(1000),
    incident_type     varchar(255) not null,
    latitude          numeric(10,7),
    longitude         numeric(10,7),
    occurred_at       timestamptz not null,
    resolution_notes  varchar(1000),
    resolved_at       timestamptz,
    severity          varchar(255) not null,
    status            varchar(255) not null,
    created_by        uuid not null,
    driver_id         uuid,
    resolved_by       uuid,
    trip_id           uuid,
    vehicle_id        uuid not null,
    assignee_user_id  uuid,
    batch_reference   varchar(512),
    branch_id         uuid,
    location          varchar(512),
    policy_id         uuid,
    root_cause        varchar(4000),
    site_id           uuid,
    updated_at        timestamptz,
    version           bigint not null,
    primary key (id),
    check (incident_type in ('SPEED_VIOLATION', 'FUEL_DEVIATION', 'ROUTE_DEVIATION', 'UNAUTHORIZED_STOP', 'HARD_BRAKING', 'RAPID_ACCELERATION', 'IDLE_EXCESSIVE', 'GEOFENCE_VIOLATION', 'MAINTENANCE_DUE', 'ACCIDENT', 'THEFT', 'OTHER')),
    -- incident_type BAZADA: jadval bo'sh
    check (severity in ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    -- severity BAZADA: jadval bo'sh
    check (status in ('OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED', 'DISMISSED')),
    -- status BAZADA: jadval bo'sh
    foreign key (trip_id) references trip(id),
    foreign key (vehicle_id) references transport_vehicle(id),
    foreign key (driver_id) references driver(id),
    foreign key (created_by) references app_user(id),
    foreign key (resolved_by) references app_user(id)
);

-- ---------------------------------------------------------------------
-- Sug'urta polislari: OSAGO, KASKO, CARGO, LIABILITY, PASSENGER. Polis raqami,
-- sug'urta kompaniyasi, sug'urta summasi, mukofot (premium), amal qilish muddati
-- (valid_from, valid_to).
-- status: ACTIVE, EXPIRING_SOON, EXPIRED, CANCELLED.
-- MUDDATI TUGAYOTGAN SUG'URTALAR valid_to bo'yicha yoki status='EXPIRING_SOON'
-- bilan olinadi.
-- ---------------------------------------------------------------------
create table insurance_policy
(
    id              uuid not null,
    created_at      timestamptz not null,
    currency        varchar(8) not null,
    insured_amount  numeric(16,2) not null,
    insurer_name    varchar(255) not null,
    kind            varchar(16) not null,
    notes           varchar(2000),
    policy_number   varchar(64) not null,
    premium         numeric(14,2) not null,
    status          varchar(16) not null,
    updated_at      timestamptz not null,
    valid_from      date not null,
    valid_to        date not null,
    vehicle_id      uuid,
    version         bigint not null,
    primary key (id),
    check (kind in ('OSAGO', 'KASKO', 'CARGO', 'LIABILITY', 'PASSENGER')),
    -- kind BAZADA: jadval bo'sh
    check (status in ('ACTIVE', 'EXPIRING_SOON', 'EXPIRED', 'CANCELLED'))
    -- status BAZADA: jadval bo'sh
);

create table integration_batch_quality_receipt
(
    event_id                  uuid not null,
    source_id                 text not null,
    source_contract_revision  bigint not null,
    branch_id                 uuid not null,
    site_id                   uuid not null,
    product_id                uuid not null,
    batch_id                  uuid not null,
    decision_id               uuid not null,
    source_revision           bigint not null,
    schema_version            text not null,
    idempotency_key           text not null,
    status                    text not null,
    reason                    text not null,
    original                  jsonb not null,
    payload_hash              text not null,
    received_at               timestamptz not null,
    primary key (event_id),
    check ((payload_hash ~ '^[0-9a-f]{64}$')),
    check ((source_revision >= 0)),
    check (status in ('ACCEPTED', 'STALE', 'SOURCE_NOT_CURRENT')),
    -- status BAZADA: jadval bo'sh
    foreign key (branch_id) references reference_data(id),
    foreign key (site_id) references yard_site(id)
);

create table integration_document_command
(
    operation_id   uuid not null,
    document_id    uuid not null,
    actor_id       uuid not null,
    kind           varchar(32) not null,
    original_json  jsonb not null,
    recorded_at    timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (document_id) references transport_document(id)
);

create table integration_document_intent
(
    operation_id   uuid not null,
    actor_id       uuid not null,
    path           text not null,
    original_json  jsonb not null,
    state          varchar(32) not null,
    reason         text not null,
    recorded_at    timestamptz not null,
    primary key (operation_id),
    check (state in ('APPLIED', 'NOT_EXECUTED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id)
);

create table integration_document_signature
(
    id                       uuid not null,
    document_id              uuid not null,
    version_id               uuid not null,
    version_number           integer not null,
    content_sha256           varchar(128) not null,
    state                    varchar(32) not null,
    certificate_sha256       varchar(64),
    certificate_serial       varchar(128),
    signer_name              varchar(512),
    actor_id                 uuid,
    signed_at                timestamptz,
    certificate_valid_until  timestamptz,
    authority_id             uuid,
    authority_revision       bigint,
    policy_id                uuid,
    policy_revision          bigint,
    provider                 varchar(64),
    signature_data           text,
    primary key (id),
    check ((((state) <> 'verified') or (((certificate_sha256) ~ '^[a-f0-9]{64}$') and (actor_id is not null) and (signed_at is not null) and (authority_id is not null) and (policy_id is not null) and (signature_data is not null)))),
    check (state in ('VERIFIED', 'LEGACY_UNVERIFIED')),
    -- state BAZADA: jadval bo'sh
    foreign key (authority_id, authority_revision) references integration_signer_authority(id, revision),
    foreign key (actor_id) references app_user(id),
    foreign key (document_id) references transport_document(id),
    foreign key (policy_id) references integration_signature_policy(id),
    foreign key (version_id) references document_version(id)
);

create table integration_edo_correction
(
    id                      uuid not null,
    document_id             uuid not null,
    rejected_submission_id  uuid not null,
    prior_version_id        uuid not null,
    new_version_id          uuid not null,
    actor_id                uuid not null,
    reason                  text not null,
    original_json           jsonb not null,
    recorded_at             timestamptz not null,
    primary key (id),
    foreign key (actor_id) references app_user(id),
    foreign key (document_id) references transport_document(id),
    foreign key (new_version_id) references document_version(id),
    foreign key (prior_version_id) references document_version(id),
    foreign key (rejected_submission_id) references integration_edo_submission(id)
);

create table integration_edo_gate_policy
(
    id             uuid not null,
    revision       bigint not null,
    operation_id   uuid not null,
    actor_id       uuid not null,
    site_id        uuid not null,
    operation      varchar(16) not null,
    configuration  jsonb not null,
    recorded_at    timestamptz not null,
    primary key (id, revision),
    check (operation in ('ENTER', 'EXIT', 'LOAD', 'UNLOAD')),
    -- operation BAZADA: jadval bo'sh
    check ((revision > 0)),
    foreign key (actor_id) references app_user(id)
);

create table integration_edo_party
(
    id            uuid not null,
    revision      bigint not null,
    operation_id  uuid not null,
    actor_id      uuid not null,
    card          jsonb not null,
    recorded_at   timestamptz not null,
    primary key (id, revision),
    check ((revision > 0)),
    foreign key (actor_id) references app_user(id)
);

create table integration_edo_protocol
(
    id            uuid not null,
    provider_id   varchar(64) not null,
    revision      bigint not null,
    operation_id  uuid not null,
    actor_id      uuid not null,
    contract      jsonb not null,
    recorded_at   timestamptz not null,
    primary key (id),
    check ((revision > 0)),
    foreign key (actor_id) references app_user(id)
);

create table integration_edo_submission
(
    id                      uuid not null,
    document_id             uuid not null,
    version_id              uuid not null,
    version_number          integer not null,
    evidence_id             uuid not null,
    provider_id             varchar(64) not null,
    exchange_id             uuid not null,
    sender_id               uuid not null,
    sender_revision         bigint not null,
    recipient_id            uuid not null,
    recipient_revision      bigint not null,
    corrects_submission_id  uuid,
    reason                  text not null,
    actor_id                uuid not null,
    original_json           jsonb not null,
    protocol_id             uuid not null,
    protocol_revision       bigint not null,
    recorded_at             timestamptz not null,
    primary key (id),
    foreign key (actor_id) references app_user(id),
    foreign key (corrects_submission_id) references integration_edo_submission(id),
    foreign key (document_id) references transport_document(id),
    foreign key (evidence_id) references integration_document_signature(id),
    foreign key (exchange_id) references integration_exchange_event(id),
    foreign key (protocol_id) references integration_edo_protocol(id),
    foreign key (recipient_id, recipient_revision) references integration_edo_party(id, revision),
    foreign key (sender_id, sender_revision) references integration_edo_party(id, revision),
    foreign key (version_id) references document_version(id)
);

create table integration_exchange_closed_operation
(
    operation_id  uuid not null,
    kind          varchar(32) not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        varchar(2000) not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id)
);

create table integration_exchange_event
(
    id                 uuid not null,
    provider_id        varchar(64) not null,
    channel            varchar(64) not null,
    aggregate_type     varchar(128) not null,
    aggregate_id       uuid not null,
    branch_id          uuid,
    aggregate_version  bigint not null,
    schema_version     varchar(64) not null,
    idempotency_key    varchar(512) not null,
    payload_hash       varchar(64) not null,
    payload            jsonb not null,
    wire_payload       text not null,
    dependency         uuid,
    provider_revision  bigint not null,
    state              varchar(64) not null,
    attempts           integer not null,
    next_attempt_at    timestamptz not null,
    lease_token        uuid,
    lease_until        timestamptz,
    manual_requested   boolean not null,
    detail             varchar(2000) not null,
    created_at         timestamptz not null,
    correlation_id     varchar(128),
    primary key (id),
    check (((correlation_id is null) or (((correlation_id) collate "c") ~ '^[a-za-z0-9._-]{1,128}$'))),
    check ((aggregate_version >= 0)),
    check ((dependency is distinct from id)),
    check (((payload_hash) ~ '^[a-f0-9]{64}$')),
    foreign key (branch_id) references reference_data(id),
    foreign key (dependency) references integration_exchange_event(id)
);

create table integration_exchange_history
(
    sequence     bigint not null,
    event_id     uuid not null,
    state        varchar(64) not null,
    attempt      integer not null,
    detail       varchar(2000) not null,
    actor_id     uuid,
    recorded_at  timestamptz not null,
    primary key (sequence),
    foreign key (actor_id) references app_user(id),
    foreign key (event_id) references integration_exchange_event(id)
);

create table integration_exchange_operation
(
    operation_id  uuid not null,
    kind          varchar(32) not null,
    actor_id      uuid not null,
    original      jsonb not null,
    result        jsonb not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id)
);

create table integration_exchange_provider
(
    provider_id   varchar(64) not null,
    revision      bigint not null,
    operation_id  uuid not null,
    actor_id      uuid not null,
    contract      jsonb not null,
    recorded_at   timestamptz not null,
    primary key (provider_id, revision),
    check ((revision > 0)),
    foreign key (actor_id) references app_user(id)
);

create table integration_exchange_receipt
(
    id                    uuid not null,
    provider_id           varchar(64) not null,
    receipt_id            varchar(256) not null,
    event_id              uuid not null,
    stage                 varchar(64) not null,
    external_document_id  varchar(512),
    reason                varchar(2000) not null,
    confirmed_at          timestamptz not null,
    received_at           timestamptz not null,
    original              jsonb not null,
    primary key (provider_id, receipt_id),
    check (stage in ('VALIDATED', 'BUSINESS_ACCEPTED', 'DELIVERED', 'RECIPIENT_SIGNED', 'BUSINESS_REJECTED')),
    -- stage BAZADA: jadval bo'sh
    foreign key (event_id) references integration_exchange_event(id)
);

create table integration_exchange_receipt_machine_witness
(
    id           uuid not null,
    receipt_id   uuid not null,
    machine_id   varchar(64) not null,
    original     jsonb not null,
    recorded_at  timestamptz not null,
    primary key (id),
    foreign key (receipt_id) references integration_exchange_receipt(id)
);

create table integration_exchange_wire_artifact
(
    event_id             uuid not null,
    provider_revision    bigint not null,
    source_payload_hash  varchar(64) not null,
    wire_sha256          varchar(64) not null,
    wire_payload         text not null,
    prepared_at          timestamptz not null,
    primary key (event_id),
    foreign key (event_id) references integration_exchange_event(id)
);

create table integration_fleet_passport_exchange
(
    source_event_id    uuid not null,
    exchange_event_id  uuid not null,
    captured_at        timestamptz not null,
    primary key (source_event_id),
    foreign key (exchange_event_id) references integration_exchange_event(id),
    foreign key (source_event_id) references fleet_passport_lifecycle(operation_id)
);

create table integration_inbound_control_operation
(
    operation_id  uuid not null,
    actor_id      uuid not null,
    kind          text not null,
    original      jsonb not null,
    state         text not null,
    result        jsonb not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    check (state in ('APPLIED', 'NOT_EXECUTED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id)
);

create table integration_inbound_source
(
    source_id     text not null,
    revision      bigint not null,
    operation_id  uuid not null,
    actor_id      uuid not null,
    contract      jsonb not null,
    recorded_at   timestamptz not null,
    primary key (source_id, revision),
    check (((contract ->> 'sourceid') = source_id)),
    check ((((contract ->> 'expectedrevision')) = (revision - 1))),
    check (((contract ->> 'state') = any (array['approved', 'revoked']))),
    check (((contract ->> 'sourcekind') = any (array['wms', 'lims', 'erp_quality', 'toir']))),
    check ((revision > 0)),
    foreign key (actor_id) references app_user(id)
);

create table integration_loading_bridge
(
    local_shipment_id  uuid not null,
    local_batch_id     uuid not null,
    site_id            uuid not null,
    revision           bigint not null,
    operation_id       uuid not null,
    branch_id          uuid not null,
    author_id          uuid not null,
    actor_id           uuid not null,
    state              text not null,
    original           jsonb not null,
    sources            jsonb not null,
    recorded_at        timestamptz not null,
    primary key (local_shipment_id, local_batch_id, site_id, revision),
    check ((revision > 0)),
    check (state in ('DRAFT', 'APPROVED', 'REVOKED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (author_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (local_batch_id) references chemical_quality_batch(id),
    foreign key (local_shipment_id) references shipment(id),
    foreign key (site_id) references yard_site(id)
);

-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
create table integration_loading_bridge_current
(
    local_shipment_id  uuid,
    local_batch_id     uuid,
    site_id            uuid,
    revision           bigint,
    operation_id       uuid,
    branch_id          uuid,
    author_id          uuid,
    actor_id           uuid,
    state              text,
    original           jsonb,
    sources            jsonb,
    recorded_at        timestamptz
);

create table integration_signature_policy
(
    id             uuid not null,
    document_type  varchar(64) not null,
    revision       bigint not null,
    operation_id   uuid not null,
    actor_id       uuid not null,
    configuration  jsonb not null,
    recorded_at    timestamptz not null,
    primary key (id),
    check ((revision > 0)),
    foreign key (actor_id) references app_user(id)
);

create table integration_signer_authority
(
    id             uuid not null,
    revision       bigint not null,
    operation_id   uuid not null,
    actor_id       uuid not null,
    configuration  jsonb not null,
    recorded_at    timestamptz not null,
    primary key (id, revision),
    check ((revision > 0)),
    foreign key (actor_id) references app_user(id)
);

create table integration_toir_hold
(
    source_id         text not null,
    equipment_id      uuid not null,
    vehicle_id        uuid not null,
    branch_id         uuid not null,
    event_id          uuid not null,
    source_revision   bigint not null,
    mapping_revision  bigint not null,
    policy_revision   bigint not null,
    source_status     text not null,
    restriction       text not null,
    reason            text not null,
    updated_at        timestamptz not null,
    primary key (source_id, equipment_id),
    check (restriction in ('CLEAR', 'IN_REPAIR', 'UNAVAILABLE', 'DECOMMISSIONED')),
    -- restriction BAZADA: jadval bo'sh
    foreign key (branch_id) references reference_data(id),
    foreign key (event_id) references integration_toir_status_inbox(event_id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
create table integration_toir_inbox_current
(
    event_id                  uuid,
    source_id                 text,
    source_contract_revision  bigint,
    branch_id                 uuid,
    equipment_id              uuid,
    submitted_vehicle_id      uuid,
    source_revision           bigint,
    source_status             text,
    schema_version            text,
    idempotency_key           text,
    original                  jsonb,
    payload_hash              text,
    initial_status            text,
    initial_reason            text,
    received_at               timestamptz,
    status                    text,
    reason                    text,
    mapping_revision          bigint,
    policy_revision           bigint,
    resolved_at               timestamptz
    -- status BAZADA: jadval bo'sh
);

create table integration_toir_mapping
(
    source_id     text not null,
    equipment_id  uuid not null,
    revision      bigint not null,
    vehicle_id    uuid not null,
    branch_id     uuid not null,
    operation_id  uuid not null,
    actor_id      uuid not null,
    contract      jsonb not null,
    recorded_at   timestamptz not null,
    primary key (source_id, equipment_id, revision),
    check ((revision > 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table integration_toir_outbox_bridge
(
    legacy_event_id    uuid not null,
    exchange_event_id  uuid not null,
    recorded_at        timestamptz not null,
    primary key (legacy_event_id)
);

create table integration_toir_resolution
(
    operation_id      uuid not null,
    event_id          uuid not null,
    actor_id          uuid,
    status            text not null,
    reason            text not null,
    mapping_revision  bigint,
    policy_revision   bigint,
    recorded_at       timestamptz not null,
    primary key (operation_id),
    -- status BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (event_id) references integration_toir_status_inbox(event_id)
);

create table integration_toir_snapshot_sequence
(
    vehicle_id  uuid not null,
    revision    bigint not null,
    primary key (vehicle_id),
    check ((revision > 0)),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table integration_toir_status_inbox
(
    event_id                  uuid not null,
    source_id                 text not null,
    source_contract_revision  bigint not null,
    branch_id                 uuid not null,
    equipment_id              uuid not null,
    submitted_vehicle_id      uuid not null,
    source_revision           bigint not null,
    source_status             text not null,
    schema_version            text not null,
    idempotency_key           text not null,
    original                  jsonb not null,
    payload_hash              text not null,
    initial_status            text not null,
    initial_reason            text not null,
    received_at               timestamptz not null,
    primary key (event_id),
    check ((payload_hash ~ '^[0-9a-f]{64}$')),
    check ((source_revision >= 0)),
    foreign key (branch_id) references reference_data(id)
);

create table integration_toir_status_policy
(
    source_id      text not null,
    source_status  text not null,
    revision       bigint not null,
    operation_id   uuid not null,
    actor_id       uuid not null,
    contract       jsonb not null,
    recorded_at    timestamptz not null,
    primary key (source_id, source_status, revision),
    check ((revision > 0)),
    foreign key (actor_id) references app_user(id)
);

create table inventory_receipt
(
    id                 uuid not null,
    attachment_id      uuid not null,
    counterparty_name  varchar(255),
    created_at         timestamptz not null,
    document_date      date not null,
    document_number    varchar(64) not null,
    item_id            uuid not null,
    item_name          varchar(256) not null,
    notes              varchar(1024),
    quantity           numeric(16,4) not null,
    received_at        timestamptz not null,
    received_by        varchar(255) not null,
    stock_id           uuid not null,
    total_amount       numeric(18,2),
    unit_of_measure    varchar(32) not null,
    unit_price         numeric(16,2),
    warehouse_id       uuid not null,
    warehouse_name     varchar(256),
    primary key (id)
);

-- ---------------------------------------------------------------------
-- Ombordagi tovar-material qoldiqlari (item, ombor, miqdor, o'lchov birligi).
-- Tovar nomlari product jadvalida.
-- ---------------------------------------------------------------------
create table inventory_stock
(
    id                      uuid not null,
    created_at              timestamptz not null,
    item_id                 uuid not null,
    item_name               varchar(256),
    last_updated_at         timestamptz not null,
    quantity                numeric(16,4),
    unit_of_measure         varchar(32),
    updated_at              timestamptz,
    warehouse_id            uuid,
    expense_date            date,
    group_code              varchar(32),
    income_date             date,
    item_code               varchar(64),
    total_amount            numeric(18,2),
    unit_price              numeric(16,2),
    vat_rate                numeric(6,2),
    warehouse_name          varchar(256),
    refurbished             boolean not null,
    source_vehicle_part_id  uuid,
    currency                varchar(8),
    ledger_opened           boolean not null,
    quarantine_quantity     numeric(16,3) not null,
    version                 bigint not null,
    material_group_id       uuid,
    measurement_unit_id     uuid,
    mxik_id                 uuid,
    primary key (id),
    foreign key (material_group_id) references reference_data(id),
    foreign key (measurement_unit_id) references reference_data(id),
    foreign key (mxik_id) references reference_data(id)
);

create table inventory_warehouse_legacy_mapping
(
    stock_id        uuid not null,
    warehouse_id    uuid,
    warehouse_name  text,
    resolution      text not null,
    recorded_at     timestamptz not null,
    primary key (stock_id),
    foreign key (stock_id) references inventory_stock(id)
);

create table maintenance_auto_amendment
(
    operation_id       uuid not null,
    plan_id            uuid not null,
    order_id           uuid not null,
    branch_id          uuid not null,
    actor_id           uuid not null,
    revision           bigint not null,
    state              text not null,
    card_operation_id  uuid,
    release_link_id    uuid,
    original           jsonb not null,
    sources            jsonb not null,
    document           jsonb not null,
    hash               text not null,
    recorded_at        timestamptz not null,
    primary key (operation_id),
    check (state in ('RELEASE_LINK', 'AMEND_CARD', 'TRANSFER', 'CARRY_FORWARD')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (card_operation_id) references maintenance_auto_card(operation_id),
    foreign key (order_id) references maintenance_auto_order(id),
    foreign key (plan_id) references maintenance_plan(id),
    foreign key (release_link_id) references maintenance_auto_repair_link(operation_id)
);

create table maintenance_auto_amendment_closed
(
    operation_id  uuid not null,
    plan_id       uuid not null,
    order_id      uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (order_id) references maintenance_auto_order(id),
    foreign key (plan_id) references maintenance_plan(id)
);

create table maintenance_auto_amendment_need
(
    operation_id     uuid not null,
    order_id         uuid not null,
    stock_id         uuid not null,
    item_id          uuid not null,
    unit             text not null,
    quantity         numeric(16,3) not null,
    material_source  jsonb not null,
    recorded_at      timestamptz not null,
    primary key (operation_id, stock_id),
    check ((quantity > (0))),
    foreign key (operation_id) references maintenance_auto_amendment(operation_id),
    foreign key (order_id) references maintenance_auto_order(id),
    foreign key (stock_id) references inventory_stock(id)
);

create table maintenance_auto_booking
(
    operation_id      uuid not null,
    order_id          uuid not null,
    plan_id           uuid not null,
    attempt_id        uuid not null,
    vehicle_id        uuid not null,
    branch_id         uuid not null,
    actor_id          uuid not null,
    bay_id            uuid not null,
    person_id         uuid not null,
    bay_window_id     uuid not null,
    person_window_id  uuid not null,
    from_at           timestamptz not null,
    to_at             timestamptz not null,
    revision          bigint not null,
    state             text not null,
    original          jsonb not null,
    sources           jsonb not null,
    document          jsonb not null,
    hash              text not null,
    recorded_at       timestamptz not null,
    primary key (operation_id),
    check ((to_at > from_at)),
    check (state in ('HELD', 'RELEASED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (order_id) references maintenance_auto_order(id),
    foreign key (plan_id) references maintenance_plan(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table maintenance_auto_booking_closed
(
    operation_id  uuid not null,
    order_id      uuid not null,
    plan_id       uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (order_id) references maintenance_auto_order(id),
    foreign key (plan_id) references maintenance_plan(id)
);

create table maintenance_auto_card
(
    operation_id  uuid not null,
    plan_id       uuid not null,
    vehicle_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    revision      bigint not null,
    state         text not null,
    original      jsonb not null,
    sources       jsonb not null,
    document      jsonb not null,
    hash          text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    check (state in ('DRAFT', 'APPROVED', 'REVOKED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (plan_id) references maintenance_plan(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table maintenance_auto_closed
(
    operation_id  uuid not null,
    plan_id       uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (plan_id) references maintenance_plan(id)
);

create table maintenance_auto_execution
(
    operation_id  uuid not null,
    plan_id       uuid not null,
    order_id      uuid not null,
    attempt_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    revision      bigint not null,
    state         text not null,
    original      jsonb not null,
    sources       jsonb not null,
    document      jsonb not null,
    hash          text not null,
    baseline      jsonb,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    check (state in ('STARTED', 'WORK_RECORDED', 'AWAITING_ACCEPTANCE', 'REWORK', 'ACCEPTED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (order_id) references maintenance_auto_order(id),
    foreign key (plan_id) references maintenance_plan(id)
);

create table maintenance_auto_execution_closed
(
    operation_id  uuid not null,
    plan_id       uuid not null,
    order_id      uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (order_id) references maintenance_auto_order(id),
    foreign key (plan_id) references maintenance_plan(id)
);

create table maintenance_auto_lifecycle
(
    operation_id  uuid not null,
    order_id      uuid not null,
    plan_id       uuid not null,
    attempt_id    uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    revision      bigint not null,
    state         text not null,
    original      jsonb not null,
    sources       jsonb not null,
    document      jsonb not null,
    hash          text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    check (state in ('OPEN', 'CANCELLED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (order_id) references maintenance_auto_order(id),
    foreign key (plan_id) references maintenance_plan(id)
);

create table maintenance_auto_lifecycle_closed
(
    operation_id  uuid not null,
    order_id      uuid not null,
    plan_id       uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (order_id) references maintenance_auto_order(id),
    foreign key (plan_id) references maintenance_plan(id)
);

create table maintenance_auto_material_need
(
    order_id         uuid not null,
    stock_id         uuid not null,
    item_id          uuid not null,
    unit             text not null,
    quantity         numeric(16,3) not null,
    material_source  jsonb not null,
    recorded_at      timestamptz not null,
    primary key (order_id, stock_id),
    check ((quantity > (0))),
    foreign key (order_id) references maintenance_auto_order(id),
    foreign key (stock_id) references inventory_stock(id)
);

create table maintenance_auto_order
(
    id                 uuid not null,
    plan_id            uuid not null,
    vehicle_id         uuid not null,
    branch_id          uuid not null,
    cycle_key          text not null,
    card_operation_id  uuid not null,
    sources            jsonb not null,
    route_card         jsonb not null,
    hash               text not null,
    origin             text not null,
    created_at         timestamptz not null,
    primary key (id),
    check (origin in ('USAGE_EVENT', 'CARD_APPROVAL', 'CALENDAR_SCAN')),
    -- origin BAZADA: jadval bo'sh
    foreign key (branch_id) references reference_data(id),
    foreign key (card_operation_id) references maintenance_auto_card(operation_id),
    foreign key (plan_id) references maintenance_plan(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table maintenance_auto_repair_link
(
    operation_id  uuid not null,
    order_id      uuid not null,
    plan_id       uuid not null,
    attempt_id    uuid not null,
    repair_id     uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    sources       jsonb not null,
    document      jsonb not null,
    hash          text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (order_id) references maintenance_auto_order(id),
    foreign key (plan_id) references maintenance_plan(id),
    foreign key (repair_id) references vehicle_repair(id)
);

create table maintenance_auto_repair_link_closed
(
    operation_id  uuid not null,
    order_id      uuid not null,
    plan_id       uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (order_id) references maintenance_auto_order(id),
    foreign key (plan_id) references maintenance_plan(id)
);

create table maintenance_auto_repair_material
(
    order_id           uuid not null,
    stock_id           uuid not null,
    part_request_id    uuid not null,
    link_operation_id  uuid not null,
    primary key (link_operation_id, stock_id),
    foreign key (link_operation_id) references maintenance_auto_repair_link(operation_id),
    foreign key (order_id) references maintenance_auto_order(id),
    foreign key (part_request_id) references repair_order_part_request(id),
    foreign key (stock_id) references inventory_stock(id)
);

create table maintenance_auto_runtime
(
    id               boolean not null,
    enabled          boolean not null,
    source_priority  jsonb not null,
    recorded_at      timestamptz not null,
    primary key (id),
    check (id),
    check (((jsonb_typeof(source_priority) = 'array') and (jsonb_array_length(source_priority) <= 20)))
);

create table maintenance_auto_scan
(
    plan_id          uuid not null,
    last_scanned_at  timestamptz not null,
    failures         integer not null,
    last_error       text,
    primary key (plan_id),
    foreign key (plan_id) references maintenance_plan(id)
);

create table maintenance_deferral
(
    operation_id  uuid not null,
    deferral_id   uuid not null,
    plan_id       uuid not null,
    work_id       uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    revision      bigint not null,
    state         text not null,
    original      jsonb not null,
    sources       jsonb not null,
    document      jsonb not null,
    hash          text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    check (state in ('REQUESTED', 'APPROVED', 'REVOKED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (plan_id) references maintenance_plan(id)
);

create table maintenance_deferral_closed
(
    operation_id  uuid not null,
    deferral_id   uuid not null,
    plan_id       uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id)
);

create table maintenance_deferral_policy
(
    operation_id  uuid not null,
    policy_id     uuid not null,
    plan_id       uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    revision      bigint not null,
    state         text not null,
    original      jsonb not null,
    document      jsonb not null,
    hash          text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    check (state in ('DRAFT', 'APPROVED', 'REVOKED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (plan_id) references maintenance_plan(id)
);

create table maintenance_deferral_policy_closed
(
    operation_id  uuid not null,
    policy_id     uuid not null,
    plan_id       uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id)
);

create table maintenance_deferral_use
(
    grant_operation_id  uuid not null,
    plan_id             uuid not null,
    work_id             uuid not null,
    work_snapshot       jsonb not null,
    evaluated_at        timestamptz not null,
    primary key (grant_operation_id),
    foreign key (grant_operation_id) references maintenance_deferral(operation_id)
);

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
create table maintenance_plan
(
    id                          uuid not null,
    assigned_mechanic           varchar(255),
    blocked_on_overdue          boolean not null,
    created_at                  timestamptz not null,
    current_engine_hours        numeric(14,3),
    current_odometer_km         numeric(14,3),
    interval_days               integer,
    interval_engine_hours       numeric(14,3),
    interval_km                 numeric(14,3),
    kind                        varchar(32),
    last_serviced_at            date,
    last_serviced_at_km         numeric(14,3),
    maintenance_type            varchar(32),
    next_due_at                 date,
    next_due_at_km              numeric(14,3),
    next_due_engine_hours       numeric(14,3),
    notes                       varchar(2000),
    status                      varchar(16) not null,
    updated_at                  timestamptz not null,
    vehicle_id                  uuid not null,
    version                     bigint not null,
    last_serviced_engine_hours  numeric(14,3),
    primary key (id),
    check (kind in ('OIL_CHANGE', 'TIRE_ROTATION', 'BRAKE_INSPECTION', 'TIMING_BELT', 'TECH_INSPECTION', 'OTHER')),
    -- kind BAZADA: OIL_CHANGE 1 | ISHLATILMAGAN: TIRE_ROTATION, BRAKE_INSPECTION, TIMING_BELT, TECH_INSPECTION, OTHER
    check (maintenance_type in ('TO_1', 'TO_2', 'SEASONAL', 'DIAGNOSTIC')),
    -- maintenance_type BAZADA: TO_1 1 | ISHLATILMAGAN: TO_2, SEASONAL, DIAGNOSTIC
    check (status in ('PLANNED', 'ACTIVE', 'DUE_SOON', 'DUE', 'UNKNOWN', 'OVERDUE', 'PAUSED', 'COMPLETED'))
    -- status BAZADA: UNKNOWN 1 | ISHLATILMAGAN: PLANNED, ACTIVE, DUE_SOON, DUE, OVERDUE, PAUSED, COMPLETED
);

create table maintenance_release_decision
(
    id             uuid not null,
    actor          varchar(255) not null,
    allowed        boolean not null,
    evaluated_at   timestamptz not null,
    evidence_json  text not null,
    origin         varchar(100) not null,
    vehicle_id     uuid not null,
    work_id        uuid,
    primary key (id)
);

create table maintenance_resource_window
(
    operation_id   uuid not null,
    window_id      uuid not null,
    plan_id        uuid not null,
    branch_id      uuid not null,
    actor_id       uuid not null,
    resource_kind  text not null,
    resource_id    uuid not null,
    revision       bigint not null,
    state          text not null,
    original       jsonb not null,
    sources        jsonb not null,
    document       jsonb not null,
    hash           text not null,
    recorded_at    timestamptz not null,
    primary key (operation_id),
    check (resource_kind in ('BAY', 'PERSON')),
    -- resource_kind BAZADA: jadval bo'sh
    check (state in ('DRAFT', 'APPROVED', 'REVOKED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (plan_id) references maintenance_plan(id)
);

create table maintenance_resource_window_closed
(
    operation_id  uuid not null,
    window_id     uuid not null,
    plan_id       uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (plan_id) references maintenance_plan(id)
);

create table manual_driver
(
    id                       uuid not null,
    full_name                varchar(256) not null,
    license_number           varchar(64),
    phone                    varchar(32),
    employee_code            varchar(64),
    branch_id                uuid,
    driver_entity_id         uuid,
    is_active                boolean not null,
    created_by               varchar(128),
    created_at               timestamptz,
    updated_at               timestamptz,
    is_temporary             boolean not null,
    temporary_registered_by  varchar(128),
    temporary_registered_at  timestamptz,
    primary key (id)
);

create table material_demand
(
    part_request_id      uuid not null,
    available            numeric(16,3),
    branch_id            uuid,
    own_reserved         numeric(16,3),
    reason               varchar(100),
    request_version      bigint,
    requested_remaining  numeric(16,3),
    shortage             numeric(16,3),
    stock_id             uuid,
    stock_version        bigint,
    updated_at           timestamptz not null,
    version              bigint,
    primary key (part_request_id),
    foreign key (part_request_id) references repair_order_part_request(id),
    foreign key (stock_id) references inventory_stock(id)
);

create table material_exchange_attempt
(
    operation_id         uuid not null,
    attempts             integer not null,
    created_at           timestamptz not null,
    envelope_json        text,
    error_code           varchar(100),
    lease_token          uuid,
    lease_until          timestamptz,
    lookup_required      boolean not null,
    mutation_started_at  timestamptz,
    next_attempt_at      timestamptz,
    owner_epoch          bigint not null,
    payload_hash         varchar(64) not null,
    payload_json         text not null,
    protocol             varchar(100),
    provider             varchar(100),
    state                varchar(32) not null,
    updated_at           timestamptz not null,
    version              bigint,
    primary key (operation_id),
    check (state in ('PENDING', 'PROCESSING', 'AWAITING_RECEIPT', 'UNKNOWN', 'CONFIRMED', 'REJECTED')),
    -- state BAZADA: jadval bo'sh
    foreign key (operation_id) references material_operation(id)
);

create table material_exchange_recovery
(
    id                    uuid not null,
    actor                 varchar(255) not null,
    attempt_base_version  bigint not null,
    basis                 varchar(2000) not null,
    operation_id          uuid not null,
    payload_identity      varchar(64) not null,
    requested_at          timestamptz not null,
    primary key (id),
    foreign key (operation_id) references material_operation(id)
);

create table material_expected_supply
(
    id                  uuid not null,
    accepted_at         timestamptz not null,
    confirmed_at        timestamptz not null,
    document_id         varchar(255) not null,
    expected_at         timestamptz not null,
    line_id             varchar(255) not null,
    owner_epoch         bigint not null,
    payload_identity    varchar(64) not null,
    protocol            varchar(100) not null,
    provider            varchar(100) not null,
    receipt_id          varchar(200) not null,
    remaining_quantity  numeric(16,3) not null,
    source_revision     bigint not null,
    status              varchar(32) not null,
    stock_id            uuid not null,
    unit                varchar(32) not null,
    primary key (id),
    -- status BAZADA: jadval bo'sh
    foreign key (stock_id) references inventory_stock(id)
);

create table material_external_receipt
(
    id                 uuid not null,
    accepted_at        timestamptz not null,
    actual_quantity    numeric(16,3) not null,
    confirmed_at       timestamptz not null,
    external_document  varchar(255) not null,
    operation_id       uuid not null,
    outcome            varchar(32) not null,
    owner_epoch        bigint not null,
    payload_hash       varchar(64) not null,
    payload_identity   varchar(64) not null,
    protocol           varchar(100) not null,
    provider           varchar(100) not null,
    receipt_id         varchar(200) not null,
    source_revision    bigint not null,
    primary key (id),
    foreign key (operation_id) references material_operation(id)
);

create table material_item_policy
(
    item_id        uuid not null,
    base_unit      varchar(32),
    basis          varchar(2000) not null,
    recorded_by    varchar(255) not null,
    source         varchar(100) not null,
    tracking       varchar(24) not null,
    updated_at     timestamptz not null,
    usage_counter  varchar(32),
    version        bigint,
    primary key (item_id),
    check (tracking in ('UNCONFIGURED', 'CONSUMABLE', 'SERIALIZED', 'RESOURCE')),
    -- tracking BAZADA: jadval bo'sh
    check (usage_counter in ('ODOMETER_KM', 'ENGINE_HOURS'))
    -- usage_counter BAZADA: jadval bo'sh
);

create table material_movement
(
    id                uuid not null,
    item_id           uuid not null,
    leg               integer not null,
    operation_id      uuid not null,
    posted_at         timestamptz not null,
    quarantine_delta  numeric(16,3) not null,
    stock_id          uuid not null,
    unit              varchar(32) not null,
    usable_delta      numeric(16,3) not null,
    warehouse_id      uuid,
    primary key (id),
    foreign key (operation_id) references material_operation(id),
    foreign key (stock_id) references inventory_stock(id)
);

create table material_operation
(
    id                   uuid not null,
    actor                varchar(255) not null,
    actual_quantity      numeric(16,3),
    basis                varchar(2000) not null,
    branch_id            uuid,
    created_at           timestamptz not null,
    currency             varchar(8),
    disposition          varchar(32),
    external_document    varchar(255),
    external_receipt_id  varchar(200),
    item_id              uuid,
    kind                 varchar(40) not null,
    owner                varchar(20) not null,
    owner_epoch          bigint not null,
    part_request_id      uuid,
    payload_identity     varchar(3000) not null,
    posted_at            timestamptz,
    quantity             numeric(16,3) not null,
    quarantine_delta     numeric(16,3) not null,
    repair_order_id      uuid,
    status               varchar(40) not null,
    stock_delta          numeric(16,3) not null,
    stock_id             uuid not null,
    target_owner_epoch   bigint,
    target_stock_id      uuid,
    target_warehouse_id  uuid,
    unit                 varchar(32) not null,
    unit_price           numeric(16,2),
    vehicle_id           uuid,
    version              bigint,
    warehouse_id         uuid,
    primary key (id),
    check (kind in ('OPENING', 'RECEIPT', 'ISSUE', 'USE', 'REQUEST_RETURN', 'ACCEPT_RETURN', 'ADJUSTMENT', 'TRANSFER')),
    -- kind BAZADA: jadval bo'sh
    check (status in ('POSTED', 'PENDING_EXTERNAL', 'UNKNOWN', 'DISCREPANCY', 'REJECTED')),
    -- status BAZADA: jadval bo'sh
    foreign key (part_request_id) references repair_order_part_request(id),
    foreign key (repair_order_id) references vehicle_repair(id),
    foreign key (stock_id) references inventory_stock(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table material_owner_attestation
(
    id                   uuid not null,
    accepted_at          timestamptz not null,
    confirmed_at         timestamptz not null,
    epoch                bigint not null,
    external_document    varchar(255) not null,
    kind                 varchar(32) not null,
    payload_identity     varchar(64) not null,
    protocol             varchar(100) not null,
    provider             varchar(100) not null,
    receipt_id           varchar(200) not null,
    reconciliation_hash  varchar(64) not null,
    source_revision      bigint not null,
    warehouse_id         uuid not null,
    primary key (id),
    foreign key (warehouse_id) references material_owner_policy(warehouse_id)
);

create table material_owner_cutover
(
    id                       uuid not null,
    abort_base_version       bigint,
    abort_basis              varchar(2000),
    aborted_at               timestamptz,
    aborted_by               varchar(255),
    activated_at             timestamptz,
    activation_base_version  bigint,
    activation_basis         varchar(2000),
    actor                    varchar(255) not null,
    basis                    varchar(2000) not null,
    from_epoch               bigint not null,
    from_owner               varchar(20) not null,
    payload_identity         varchar(64) not null,
    prepared_at              timestamptz not null,
    reconciliation_hash      varchar(64),
    status                   varchar(20) not null,
    target_owner             varchar(20) not null,
    warehouse_id             uuid not null,
    primary key (id),
    -- status BAZADA: jadval bo'sh
    foreign key (warehouse_id) references material_owner_policy(warehouse_id)
);

create table material_owner_policy
(
    warehouse_id             uuid not null,
    actor                    varchar(255) not null,
    basis                    varchar(2000) not null,
    epoch                    bigint not null,
    initialization_id        uuid not null,
    initialization_identity  varchar(64) not null,
    owner                    varchar(20) not null,
    pending_cutover_id       uuid,
    phase                    varchar(20) not null,
    updated_at               timestamptz not null,
    version                  bigint,
    primary key (warehouse_id),
    check (owner in ('UNCONFIGURED', 'ATIL', 'ERP_WMS')),
    -- owner BAZADA: jadval bo'sh
    check (phase in ('ACTIVE', 'FROZEN'))
    -- phase BAZADA: jadval bo'sh
);

create table material_procurement_link
(
    id                uuid not null,
    basis             varchar(2000) not null,
    document_id       varchar(255) not null,
    kind              varchar(32) not null,
    line_id           varchar(255) not null,
    need_id           uuid not null,
    payload_identity  varchar(64) not null,
    provider          varchar(100) not null,
    recorded_at       timestamptz not null,
    recorded_by       varchar(255) not null,
    primary key (id),
    foreign key (need_id) references material_procurement_need(id)
);

create table material_procurement_need
(
    id                uuid not null,
    basis             varchar(2000) not null,
    branch_id         uuid,
    part_request_id   uuid not null,
    payload_identity  varchar(64) not null,
    quantity          numeric(16,3) not null,
    recorded_at       timestamptz not null,
    recorded_by       varchar(255) not null,
    required_by       timestamptz not null,
    snapshot_hash     varchar(64) not null,
    snapshot_json     text not null,
    stock_id          uuid not null,
    unit              varchar(32) not null,
    primary key (id),
    foreign key (part_request_id) references repair_order_part_request(id),
    foreign key (stock_id) references inventory_stock(id)
);

create table material_receipt_dispatch_profile
(
    operation_id       uuid not null,
    provider_id        varchar(64) not null,
    provider_revision  bigint not null,
    protocol           varchar(100) not null,
    profile_contract   jsonb not null,
    profile_hash       varchar(64) not null,
    owner_epoch        bigint not null,
    payload_hash       varchar(64) not null,
    command_hash       varchar(64) not null,
    envelope_hash      varchar(64) not null,
    envelope_original  text not null,
    scope              jsonb not null,
    branch_id          uuid not null,
    branch_ids         jsonb not null,
    operation_version  bigint not null,
    attempt_version    bigint not null,
    attempt_number     integer not null,
    prepared_at        timestamptz not null,
    primary key (operation_id),
    check ((attempt_number > 0)),
    check (((jsonb_typeof(branch_ids) = 'array') and (jsonb_array_length(branch_ids) > 0))),
    check ((provider_revision > 0)),
    foreign key (provider_id, provider_revision) references integration_exchange_provider(provider_id, revision),
    foreign key (branch_id) references reference_data(id),
    foreign key (operation_id) references material_operation(id)
);

create table material_receipt_machine_witness
(
    receipt_evidence_id  uuid not null,
    operation_id         uuid not null,
    machine_id           varchar(64) not null,
    provider_id          varchar(64) not null,
    provider_revision    bigint not null,
    protocol             varchar(100) not null,
    branch_id            uuid not null,
    branch_ids           jsonb not null,
    owner_epoch          bigint not null,
    payload_hash         varchar(64) not null,
    event_key            varchar(36) not null,
    operation_version    bigint not null,
    attempt_version      bigint not null,
    attempt_number       integer not null,
    source_revision      bigint not null,
    accepted_status      varchar(40) not null,
    typed_identity       varchar(64) not null,
    original_hash        varchar(64) not null,
    raw_original         text not null,
    principal_scope      jsonb not null,
    canonical_scope      jsonb not null,
    witnessed_at         timestamptz not null,
    primary key (receipt_evidence_id),
    check (((original_hash) = encode(sha256(convert_to(raw_original, 'utf8'::name)), 'hex'))),
    foreign key (provider_id, provider_revision) references integration_exchange_provider(provider_id, revision),
    foreign key (branch_id) references reference_data(id),
    foreign key (operation_id) references material_receipt_dispatch_profile(operation_id),
    foreign key (receipt_evidence_id) references material_external_receipt(id)
);

create table material_receipt_readback_witness
(
    receipt_evidence_id  uuid not null,
    operation_id         uuid not null,
    provider_id          varchar(64) not null,
    provider_revision    bigint not null,
    protocol             varchar(100) not null,
    branch_id            uuid not null,
    branch_ids           jsonb not null,
    owner_epoch          bigint not null,
    payload_hash         varchar(64) not null,
    event_key            varchar(36) not null,
    operation_version    bigint not null,
    attempt_version      bigint not null,
    attempt_number       integer not null,
    source_revision      bigint not null,
    accepted_status      varchar(40) not null,
    typed_identity       varchar(64) not null,
    original_hash        varchar(64) not null,
    raw_original         text not null,
    canonical_scope      jsonb not null,
    request_uri          text not null,
    http_status          integer not null,
    observed_at          timestamptz not null,
    policy_type          varchar(64) not null,
    policy_id            uuid not null,
    policy_version       bigint not null,
    witnessed_at         timestamptz not null,
    primary key (receipt_evidence_id),
    check (((original_hash) = encode(sha256(convert_to(raw_original, 'utf8'::name)), 'hex'))),
    check (((http_status >= 200) and (http_status < 300))),
    check (((policy_type) = 'material_readback')),
    foreign key (provider_id, provider_revision) references integration_exchange_provider(provider_id, revision),
    foreign key (branch_id) references reference_data(id),
    foreign key (operation_id) references material_receipt_dispatch_profile(operation_id),
    foreign key (policy_id) references integration_exchange_provider(operation_id),
    foreign key (receipt_evidence_id) references material_external_receipt(id)
);

create table material_reservation
(
    id                    uuid not null,
    actor                 varchar(255) not null,
    basis                 varchar(2000) not null,
    branch_id             uuid,
    created_at            timestamptz not null,
    part_request_id       uuid not null,
    payload_identity      varchar(64) not null,
    quantity              numeric(16,3) not null,
    release_base_version  bigint,
    release_basis         varchar(2000),
    released_by           varchar(255),
    remaining_quantity    numeric(16,3) not null,
    repair_order_id       uuid not null,
    status                varchar(24) not null,
    stock_id              uuid not null,
    unit                  varchar(32) not null,
    updated_at            timestamptz not null,
    version               bigint,
    primary key (id),
    check (status in ('ACTIVE', 'CONSUMED', 'RELEASED')),
    -- status BAZADA: jadval bo'sh
    foreign key (part_request_id) references repair_order_part_request(id),
    foreign key (repair_order_id) references vehicle_repair(id),
    foreign key (stock_id) references inventory_stock(id)
);

create table material_reservation_resolution
(
    id          uuid not null,
    created_at  timestamptz not null,
    outcome     varchar(32) not null,
    quantity    numeric(16,3) not null,
    receipt_id  uuid not null,
    use_id      uuid not null,
    primary key (id),
    foreign key (receipt_id) references material_external_receipt(id),
    foreign key (use_id) references material_reservation_use(id)
);

create table material_reservation_use
(
    id              uuid not null,
    created_at      timestamptz not null,
    destination     varchar(32) not null,
    operation_id    uuid not null,
    quantity        numeric(16,3) not null,
    reservation_id  uuid not null,
    primary key (id),
    foreign key (operation_id) references material_operation(id),
    foreign key (reservation_id) references material_reservation(id)
);

create table material_serial_allocation
(
    id                  uuid not null,
    created_at          timestamptz not null,
    issue_operation_id  uuid not null,
    last_operation_id   uuid,
    part_id             uuid not null,
    part_request_id     uuid not null,
    released_at         timestamptz,
    state               varchar(32) not null,
    stock_id            uuid not null,
    version             bigint,
    primary key (id),
    check (((released_at is not null) = ((state) = any ((array['returned_usable', 'returned_quarantine_disposed'])[])))),
    check (state in ('ISSUED', 'INSTALLED', 'RETURN_REQUESTED', 'RETURNED_USABLE', 'RETURNED_QUARANTINE', 'RETURNED_QUARANTINE_DISPOSED')),
    -- state BAZADA: jadval bo'sh
    check (state in ('ISSUED', 'INSTALLED', 'RETURN_REQUESTED', 'RETURNED_USABLE', 'RETURNED_QUARANTINE', 'RETURNED_QUARANTINE_DISPOSED')),
    -- state BAZADA: jadval bo'sh
    foreign key (issue_operation_id) references material_serial_command(id),
    foreign key (part_id) references vehicle_part(id),
    foreign key (part_request_id) references repair_order_part_request(id),
    foreign key (stock_id) references inventory_stock(id)
);

create table material_serial_command
(
    id                uuid not null,
    actor             varchar(255) not null,
    created_at        timestamptz not null,
    kind              varchar(32) not null,
    part_request_id   uuid not null,
    passport_ids      text not null,
    payload_identity  text not null,
    stock_id          uuid not null,
    primary key (id),
    check (kind in ('OPENING', 'RECEIPT', 'ISSUE', 'USE', 'REQUEST_RETURN', 'ACCEPT_RETURN', 'ADJUSTMENT', 'TRANSFER')),
    -- kind BAZADA: jadval bo'sh
    foreign key (part_request_id) references repair_order_part_request(id),
    foreign key (stock_id) references inventory_stock(id)
);

create table material_serial_external_hold
(
    operation_id     uuid not null,
    part_id          uuid not null,
    part_request_id  uuid not null,
    stock_id         uuid not null,
    kind             text not null,
    owner_epoch      bigint not null,
    original         jsonb not null,
    original_hash    text not null,
    state            text not null,
    receipt_id       text,
    finished_at      timestamptz,
    primary key (operation_id, part_id),
    check (((state = 'held') = ((receipt_id is null) and (finished_at is null)))),
    check (kind in ('ISSUE', 'ACCEPT_RETURN')),
    -- kind BAZADA: jadval bo'sh
    check ((original_hash ~ '^[a-f0-9]{64}$')),
    check (state in ('HELD', 'CONFIRMED', 'RELEASED')),
    -- state BAZADA: jadval bo'sh
    foreign key (operation_id) references material_serial_command(id),
    foreign key (part_id) references vehicle_part(id),
    foreign key (part_request_id) references repair_order_part_request(id),
    foreign key (stock_id) references inventory_stock(id)
);

create table material_serial_external_receipt
(
    receipt_evidence_id  uuid not null,
    operation_id         uuid not null,
    serials              jsonb not null,
    recorded_at          timestamptz not null,
    primary key (receipt_evidence_id),
    check ((jsonb_typeof(serials) = 'array')),
    foreign key (operation_id) references material_serial_command(id),
    foreign key (receipt_evidence_id) references material_external_receipt(id)
);

create table material_stock_document
(
    id                uuid not null,
    kind              varchar(32) not null,
    payload_identity  varchar(64) not null,
    recorded_at       timestamptz not null,
    source            varchar(100) not null,
    source_document   varchar(200) not null,
    source_line       varchar(100) not null,
    source_revision   bigint not null,
    primary key (id),
    check (kind in ('RECEIPT', 'COUNT', 'TRANSFER')),
    -- kind BAZADA: jadval bo'sh
    foreign key (id) references material_operation(id)
);

create table material_stock_threshold
(
    stock_id           uuid not null,
    basis              varchar(2000) not null,
    critical_quantity  numeric(16,3) not null,
    minimum_quantity   numeric(16,3) not null,
    recorded_by        varchar(255) not null,
    unit               varchar(32) not null,
    updated_at         timestamptz not null,
    version            bigint,
    primary key (stock_id),
    foreign key (stock_id) references inventory_stock(id)
);

-- ---------------------------------------------------------------------
-- Smenaga chiqish oldidan tibbiy ko'rik: qon bosimi, puls, harorat, ko'rik natijasi
-- va amal qilish muddati (to_date). status: FIT (yaroqli), RESTRICTED (cheklangan),
-- UNFIT (yaroqsiz), CANCELLED.
-- HAYDOVCHI BUGUN TIBBIY KO'RIKDAN O'TGANMI SO'RALSA shift_date va status
-- bo'yicha olinadi (status='FIT' bo'lsa o'tgan). driver.medical_cleared_today
-- ni ISHLATMANG: u eskirgan bayroq, yuqoridagi izohga qarang.
-- ---------------------------------------------------------------------
create table medical_inspection
(
    id                          uuid not null,
    alcohol_promille            numeric(5,3),
    assigned_vehicle_id         uuid,
    blood_pressure              varchar(32),
    created_at                  timestamptz not null,
    department_id               uuid,
    driver_id                   uuid not null,
    driver_name                 varchar(256) not null,
    employee_id                 varchar(64),
    inspected_at                timestamptz not null,
    medic_name                  varchar(256),
    medic_user_id               varchar(128),
    notes                       varchar(1024),
    pulse_bpm                   integer,
    shift_date                  date not null,
    status                      varchar(32) not null,
    temperature_c               numeric(4,1),
    to_date                     date not null,
    updated_at                  timestamptz not null,
    branch_id                   uuid,
    trip_id                     uuid,
    waybill_id                  uuid,
    driver_signature            text,
    alcohol_prohibited          boolean,
    alcohol_reading             numeric(14,6),
    alcohol_unit                varchar(64),
    applied_regulation_id       uuid,
    applied_regulation_json     text,
    applied_regulation_version  bigint,
    rule_assessment_reason      varchar(128),
    rule_assessment_state       varchar(32),
    valid_from                  timestamptz,
    valid_to                    timestamptz,
    object_version              bigint not null,
    primary key (id),
    check (status in ('FIT', 'RESTRICTED', 'UNFIT', 'CANCELLED'))
    -- status BAZADA: FIT 4318, CANCELLED 400, UNFIT 3, RESTRICTED 1
);

create table medical_inspection_revision
(
    id             uuid not null,
    action         varchar(32) not null,
    actor_id       uuid not null,
    actor_name     varchar(256) not null,
    after_json     text not null,
    before_json    text,
    inspection_id  uuid not null,
    occurred_at    timestamptz not null,
    reason         varchar(1000) not null,
    version_after  bigint not null,
    primary key (id),
    foreign key (inspection_id) references medical_inspection(id)
);

create table medical_monthly_alcohol_report
(
    id                       uuid not null,
    branch_id                uuid,
    created_at               timestamptz not null,
    medic_name               varchar(256),
    medic_user_id            uuid,
    report_month             integer not null,
    notes                    varchar(1024),
    status                   varchar(32) not null,
    total_count              bigint not null,
    total_meta_count         bigint not null,
    total_mg_negative_count  bigint not null,
    total_mg_positive_count  bigint not null,
    updated_at               timestamptz not null,
    report_year              integer not null,
    primary key (id),
    check (status in ('DRAFT', 'FINALIZED'))
    -- status BAZADA: FINALIZED 17, DRAFT 11
);

create table medical_monthly_alcohol_report_row
(
    id                 uuid not null,
    display_order      integer not null,
    meta_count         bigint not null,
    mg_negative_count  bigint not null,
    mg_positive_count  bigint not null,
    sex_name           varchar(256) not null,
    sex_number         varchar(64) not null,
    source             varchar(32) not null,
    total_count        bigint not null,
    report_id          uuid not null,
    primary key (id),
    check (source in ('AUTO', 'MANUAL')),
    -- source BAZADA: AUTO 56, MANUAL 45
    foreign key (report_id) references medical_monthly_alcohol_report(id)
);

create table medical_regulation
(
    id                                        uuid not null,
    alcohol_forbidden_boundary                numeric(14,6),
    alcohol_unit                              varchar(64),
    allow_standalone_for_operational_context  boolean,
    branch_id                                 uuid not null,
    forbid_at_boundary                        boolean,
    max_examination_age_seconds               bigint,
    max_validity_seconds                      bigint,
    reading_required                          boolean,
    regulation_reference                      varchar(512),
    state                                     varchar(32) not null,
    time_zone                                 varchar(64) not null,
    updated_at                                timestamptz not null,
    updated_by                                uuid not null,
    valid_from                                timestamptz,
    valid_to                                  timestamptz,
    version                                   bigint not null,
    primary key (id),
    foreign key (branch_id) references reference_data(id)
);

create table medical_regulation_revision
(
    id             uuid not null,
    actor_id       uuid not null,
    actor_name     varchar(256) not null,
    after_json     text not null,
    before_json    text,
    occurred_at    timestamptz not null,
    reason         varchar(1000) not null,
    regulation_id  uuid not null,
    version_after  bigint not null,
    primary key (id),
    foreign key (regulation_id) references medical_regulation(id)
);

create table medical_release_evidence
(
    id                        uuid not null,
    action                    varchar(32) not null,
    actor_id                  uuid not null,
    actor_name                varchar(256) not null,
    occurred_at               timestamptz not null,
    physical_departure_at     timestamptz,
    physical_departure_json   text,
    physical_departure_local  varchar(64),
    physical_departure_zone   varchar(64),
    proof_hash                varchar(64) not null,
    proof_json                text not null,
    target_id                 uuid not null,
    target_type               varchar(32) not null,
    target_version            bigint not null,
    primary key (id)
);

create table monthly_statement_approval
(
    id                   uuid not null,
    approved_at          timestamptz not null,
    approved_by          varchar(256) not null,
    calculation_version  integer not null,
    notes                text,
    report_month         varchar(7) not null,
    scope_key            varchar(36) not null,
    snapshot_json        text not null,
    snapshot_sha256      varchar(64) not null,
    version              bigint,
    primary key (id)
);

-- ---------------------------------------------------------------------
-- Foydalanuvchiga yuborilgan bildirishnomalar: yoqilg'i limitiga yaqinlashish,
-- limit oshib ketishi, credential muddati tugashi, noma'lum credential ishlatilishi.
-- severity: INFO, WARNING, CRITICAL. read_at bo'sh bo'lsa — o'qilmagan.
-- reference_id bildirishnoma tegishli obyektni ko'rsatadi.
-- ---------------------------------------------------------------------
create table notification
(
    id                 uuid not null,
    body               text,
    created_at         timestamptz not null,
    driver_id          uuid,
    kind               varchar(48) not null,
    read_at            timestamptz,
    reference_id       uuid,
    severity           varchar(16) not null,
    title              varchar(256) not null,
    vehicle_id         uuid,
    action_type        varchar(64),
    action_url         varchar(512),
    dedupe_key         varchar(256),
    entity_id          uuid,
    entity_number      varchar(64),
    entity_type        varchar(64),
    metadata           text,
    recipient_user_id  uuid,
    primary key (id),
    check (kind in ('FUEL_RECALL_ACTION_REQUIRED', 'FUEL_RECALL_ESCALATION', 'FUEL_LIMIT_THRESHOLD_APPROACHING', 'FUEL_LIMIT_EXCEEDED', 'CREDENTIAL_EXPIRING_SOON', 'UNKNOWN_CREDENTIAL_USED', 'REPAIR_ORDER_EVENT', 'TRANSPORT_REQUEST_APPROVAL_REQUIRED', 'TRANSPORT_REQUEST_APPROVED', 'TRANSPORT_REQUEST_REJECTED', 'TRANSPORT_REQUEST_ACTION_REQUIRED', 'MEDICAL_INSPECTION_REQUIRED', 'TECHNICAL_INSPECTION_REQUIRED', 'POST_TRIP_INSPECTION_REQUIRED', 'TRIP_READY_TO_START', 'WAYBILL_READY_TO_CLOSE', 'OPERATIONAL_ACTION_REQUIRED', 'OPERATIONAL_SLA_ESCALATION', 'CUSTOMER_CONFIRMATION_REQUIRED', 'CUSTOMER_DISPUTED')),
    -- kind BAZADA: TECHNICAL_INSPECTION_REQUIRED 20314, TRIP_READY_TO_START 11911, WAYBILL_READY_TO_CLOSE 10635, MEDICAL_INSPECTION_REQUIRED 10418, TRANSPORT_REQUEST_ACTION_REQUIRED 7536, POST_TRIP_INSPECTION_REQUIRED 6074, TRANSPORT_REQUEST_APPROVED 756, CUSTOMER_CONFIRMATION_REQUIRED 651, REPAIR_ORDER_EVENT 64, TRANSPORT_REQUEST_APPROVAL_REQUIRED 36, CUSTOMER_DISPUTED 1 | ISHLATILMAGAN: FUEL_RECALL_ACTION_REQUIRED, FUEL_RECALL_ESCALATION, FUEL_LIMIT_THRESHOLD_APPROACHING, FUEL_LIMIT_EXCEEDED, CREDENTIAL_EXPIRING_SOON, UNKNOWN_CREDENTIAL_USED, TRANSPORT_REQUEST_REJECTED, OPERATIONAL_ACTION_REQUIRED va yana 1 ta
    check (severity in ('INFO', 'WARNING', 'CRITICAL'))
    -- severity BAZADA: WARNING 37182, INFO 31214 | ISHLATILMAGAN: CRITICAL
);

create table notification_action_completion
(
    entity_type                 varchar(64) not null,
    entity_id                   uuid not null,
    event_version               bigint not null,
    action_type                 varchar(64) not null,
    actor_user_id               uuid,
    actor_kind                  varchar(16) not null,
    actor_id                    varchar(128) not null,
    source_branch_id            uuid,
    source_type                 varchar(64) not null,
    source_hash                 varchar(64),
    enterprise_global_approved  boolean not null,
    evidence_id                 uuid not null,
    completed_at                timestamptz not null,
    policy_type                 varchar(64),
    policy_id                   uuid,
    policy_version              bigint,
    source_id                   uuid,
    source_action               varchar(64),
    source_site_id              uuid,
    source_operation_id         uuid,
    source_object_version       bigint,
    primary key (entity_type, entity_id, event_version, action_type),
    check (actor_kind in ('HUMAN', 'MACHINE', 'SYSTEM')),
    -- actor_kind BAZADA: HUMAN 9 | ISHLATILMAGAN: MACHINE, SYSTEM
    check (((((actor_kind) = 'human') and (actor_user_id is not null) and ((actor_id) = (actor_user_id)) and ((source_type) = 'human_domain_action') and (source_hash is null) and (source_branch_id is null) and (not enterprise_global_approved)) or (((actor_kind) = 'machine') and (actor_user_id is null) and (source_hash is not null) and ((source_hash) ~ '^[a-f0-9]{64}$') and ((source_branch_id is not null) or (((source_type) = 'snapshot') and enterprise_global_approved))) or (((actor_kind) = 'system') and (actor_user_id is null) and ((entity_type) = 'fleet_material_return') and ((action_type) = 'accept_material_return') and (source_branch_id is not null) and ((source_type) = 'material_business_readback') and (source_hash is not null) and ((source_hash) ~ '^[a-f0-9]{64}$') and (not enterprise_global_approved) and (policy_type is not null) and ((policy_type) = 'material_readback') and (policy_id is not null) and (policy_version is not null) and (policy_version > 0) and (source_id is not null) and (source_action is not null) and ((source_action) = 'material_receipt_readback_accepted') and (source_operation_id is not null) and (source_operation_id = evidence_id) and (source_object_version is not null) and (source_object_version >= 0) and ((actor_id) = ((('system-policy:' || (policy_type)) || ':') || (policy_id)))))),
    check ((((actor_kind) = 'system') or ((policy_type is null) and (policy_id is null) and (policy_version is null) and (source_id is null) and (source_action is null) and (source_site_id is null) and (source_operation_id is null) and (source_object_version is null)))),
    check ((event_version >= 0)),
    foreign key (source_operation_id) references material_operation(id),
    foreign key (policy_id) references integration_exchange_provider(operation_id),
    foreign key (source_id) references material_external_receipt(id),
    foreign key (actor_user_id) references app_user(id)
);

create table notification_attention
(
    id                      uuid not null,
    event_key               varchar(512) not null,
    payload_hash            varchar(64) not null,
    event_type              varchar(48) not null,
    entity_type             varchar(64) not null,
    entity_id               uuid not null,
    branch_id               uuid,
    event_version           bigint not null,
    action_type             varchar(64) not null,
    severity                varchar(16) not null,
    policy_id               uuid,
    responsible_user_id     uuid,
    reserve_user_id         uuid,
    occurred_at             timestamptz not null,
    due_at                  timestamptz,
    state                   varchar(32) not null,
    completed_at            timestamptz,
    completion_evidence_id  uuid,
    escalated_at            timestamptz,
    created_at              timestamptz not null,
    primary key (id),
    check (((completed_at is null) = (completion_evidence_id is null))),
    check ((((state) = 'completed') = (completed_at is not null))),
    check ((((state) <> 'open') or ((policy_id is not null) and (responsible_user_id is not null) and (reserve_user_id is not null) and (due_at is not null)))),
    check ((event_version >= 0)),
    check (severity in ('INFO', 'WARNING', 'CRITICAL')),
    -- severity BAZADA: WARNING 15 | ISHLATILMAGAN: INFO, CRITICAL
    check (state in ('OPEN', 'UNCONFIGURED', 'COMPLETED')),
    -- state BAZADA: COMPLETED 9, UNCONFIGURED 6 | ISHLATILMAGAN: OPEN
    foreign key (policy_id) references notification_sla_policy(id),
    foreign key (reserve_user_id) references app_user(id),
    foreign key (responsible_user_id) references app_user(id)
);

create table notification_attention_recipient
(
    attention_id       uuid not null,
    recipient_user_id  uuid not null,
    stage              varchar(16) not null,
    notification_id    uuid not null,
    primary key (attention_id, stage, recipient_user_id),
    check (stage in ('INITIAL', 'ESCALATION')),
    -- stage BAZADA: jadval bo'sh
    foreign key (attention_id) references notification_attention(id),
    foreign key (notification_id) references notification(id),
    foreign key (recipient_user_id) references app_user(id)
);

create table notification_channel_delivery
(
    id                  uuid not null,
    notification_id     uuid not null,
    recipient_user_id   uuid not null,
    channel             varchar(16) not null,
    adapter_id          varchar(128),
    contract_reference  varchar(256),
    state               varchar(32) not null,
    attempts            integer not null,
    next_attempt_at     timestamptz not null,
    accepted_at         timestamptz,
    delivered_at        timestamptz,
    safe_receipt_code   varchar(64),
    claim_token         uuid,
    created_at          timestamptz not null,
    primary key (id),
    check ((attempts >= 0)),
    check (channel in ('EMAIL', 'SMS', 'REALTIME')),
    -- channel BAZADA: jadval bo'sh
    check ((((channel) = 'realtime') or ((adapter_id is not null) and (contract_reference is not null)))),
    check (state in ('QUEUED', 'SENDING', 'PROVIDER_ACCEPTED', 'DELIVERED', 'RETRY', 'REJECTED', 'OUTCOME_UNKNOWN', 'SUPPRESSED', 'EXHAUSTED')),
    -- state BAZADA: jadval bo'sh
    foreign key (notification_id) references notification(id),
    foreign key (recipient_user_id) references app_user(id)
);

create table notification_governance_operation
(
    operation_id   uuid not null,
    actor_id       uuid not null,
    action         varchar(32) not null,
    object_id      uuid not null,
    request_hash   varchar(64) not null,
    request_json   jsonb not null,
    response_json  jsonb not null,
    state          varchar(16) not null,
    recorded_at    timestamptz not null,
    primary key (operation_id),
    check (action in ('APPROVE_POLICY', 'ROUTE_UNCONFIGURED', 'RETRY_DELIVERY')),
    -- action BAZADA: jadval bo'sh
    check (state in ('APPLIED', 'NOT_EXECUTED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id)
);

create table notification_sla_policy
(
    id                        uuid not null,
    event_type                varchar(48) not null,
    branch_id                 uuid,
    revision                  bigint not null,
    reaction_minutes          integer not null,
    responsible_user_id       uuid not null,
    reserve_user_id           uuid not null,
    allow_source_responsible  boolean not null,
    web_push_enabled          boolean not null,
    email_adapter_id          varchar(128),
    email_contract_reference  varchar(256),
    sms_adapter_id            varchar(128),
    sms_contract_reference    varchar(256),
    approval_reference        varchar(256) not null,
    enabled                   boolean not null,
    approved_by               uuid not null,
    approved_at               timestamptz not null,
    primary key (id),
    check ((length(trim(both from approval_reference)) > 0)),
    check ((responsible_user_id <> reserve_user_id)),
    check (((email_adapter_id is null) = (email_contract_reference is null))),
    check (((sms_adapter_id is null) = (sms_contract_reference is null))),
    check (event_type in ('APPROVAL_REQUIRED', 'ADMISSION_BLOCKED', 'DOCUMENT_EXPIRING', 'INCIDENT_OPENED', 'CAPA_DUE', 'MANDATORY_INTEGRATION_FAILED')),
    -- event_type BAZADA: jadval bo'sh
    check (((reaction_minutes >= 1) and (reaction_minutes <= 525600))),
    check ((revision > 0)),
    foreign key (approved_by) references app_user(id),
    foreign key (reserve_user_id) references app_user(id),
    foreign key (responsible_user_id) references app_user(id)
);

create table operational_analytics_snapshot
(
    id             uuid not null,
    actor_id       uuid not null,
    branch_id      uuid not null,
    department_id  uuid,
    original       jsonb not null,
    snapshot       jsonb not null,
    hash           text not null,
    captured_at    timestamptz not null,
    primary key (id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table part_condition_evaluation
(
    id                 uuid not null,
    evaluated_at       timestamptz not null,
    evaluation         jsonb not null,
    evidence_identity  varchar(64) not null,
    part_id            uuid not null,
    resource_evidence  jsonb,
    primary key (id),
    foreign key (part_id) references vehicle_part(id)
);

create table part_condition_evaluation_job
(
    id               uuid not null,
    attempts         integer not null,
    completed_at     timestamptz,
    created_at       timestamptz not null,
    evaluation_id    uuid,
    failure_code     varchar(1000),
    next_attempt_at  timestamptz,
    part_id          uuid not null,
    source_domain    varchar(32) not null,
    source_id        uuid not null,
    status           varchar(16) not null,
    version          bigint,
    primary key (id),
    -- status BAZADA: jadval bo'sh
    foreign key (evaluation_id) references part_condition_evaluation(id),
    foreign key (part_id) references vehicle_part(id)
);

create table part_condition_policy
(
    id                     uuid not null,
    basis                  varchar(2000) not null,
    category               varchar(24) not null,
    effective_at           timestamptz not null,
    item_id                uuid not null,
    payload_identity       varchar(64) not null,
    previous_policy_id     uuid,
    recorded_at            timestamptz not null,
    recorded_by            varchar(255) not null,
    recorded_by_id         uuid not null,
    revision               bigint not null,
    source_priority        jsonb not null,
    thresholds             jsonb not null,
    usage_source_priority  jsonb not null,
    restriction_by_state   jsonb not null,
    primary key (id),
    check ((part_condition_operating_mapping_valid(restriction_by_state) is true)),
    check (category in ('TIRE', 'BATTERY', 'OIL_FILTER', 'AIR_FILTER', 'BRAKE_PAD', 'OTHER')),
    -- category BAZADA: jadval bo'sh
    foreign key (item_id) references material_item_policy(item_id),
    foreign key (previous_policy_id) references part_condition_policy(id),
    foreign key (recorded_by_id) references app_user(id)
);

create table part_condition_reading
(
    id                uuid not null,
    basis             varchar(2000) not null,
    branch_id         uuid not null,
    metric            varchar(32) not null,
    observed_at       timestamptz not null,
    part_id           uuid not null,
    payload_identity  varchar(64) not null,
    quality           varchar(24) not null,
    recorded_at       timestamptz not null,
    recorded_by       varchar(255) not null,
    recorded_by_id    uuid not null,
    reference_id      uuid,
    revision          bigint not null,
    source            varchar(32) not null,
    unit              varchar(16) not null,
    value             numeric(20,3) not null,
    primary key (id),
    check (metric in ('TREAD_DEPTH_MM', 'CAPACITY_AH', 'VOLTAGE_V', 'CHARGE_PERCENT', 'CYCLE_COUNT', 'RESOURCE_KM', 'RESOURCE_HOURS')),
    -- metric BAZADA: jadval bo'sh
    check (quality in ('CONFIRMED', 'QUARANTINED')),
    -- quality BAZADA: jadval bo'sh
    foreign key (part_id) references vehicle_part(id),
    foreign key (recorded_by_id) references app_user(id),
    foreign key (reference_id) references part_condition_reading(id)
);

create table part_disposal_command
(
    id                  uuid not null,
    act_id              uuid not null,
    branch_id           uuid,
    decision_id         uuid not null,
    disposed_at         date not null,
    disposition         varchar(16) not null,
    document_reference  varchar(255) not null,
    part_ids            jsonb not null,
    payload_identity    varchar(64) not null,
    recipient           varchar(255),
    recorded_at         timestamptz not null,
    recorded_by_id      uuid not null,
    recorded_by_name    varchar(256) not null,
    document_file_id    uuid,
    document_file_name  varchar(255),
    primary key (id),
    foreign key (act_id) references part_write_off_act(id),
    foreign key (decision_id) references part_writeoff_decision(id),
    foreign key (recorded_by_id) references app_user(id)
);

create table part_disposal_fact
(
    part_id      uuid not null,
    act_id       uuid not null,
    command_id   uuid not null,
    decision_id  uuid not null,
    primary key (part_id),
    foreign key (act_id) references part_write_off_act(id),
    foreign key (command_id) references part_disposal_command(id),
    foreign key (decision_id) references part_writeoff_decision(id),
    foreign key (part_id) references vehicle_part(id)
);

create table part_installation
(
    id                               uuid not null,
    basis                            varchar(2000) not null,
    branch_id                        uuid,
    engine_hours_reading_id          uuid,
    engine_hours_removal_reading_id  uuid,
    installed_at                     timestamptz not null,
    installed_at_hours               numeric(20,3),
    installed_at_km                  numeric(20,3),
    issue_operation_id               uuid not null,
    item_id                          uuid not null,
    odometer_reading_id              uuid,
    odometer_removal_reading_id      uuid,
    origin_kind                      varchar(32),
    original_material_use_id         uuid,
    part_id                          uuid not null,
    part_request_id                  uuid,
    payload_identity                 varchar(3000) not null,
    position_id                      uuid not null,
    position_layout_id               uuid,
    recorded_at                      timestamptz not null,
    recorded_by                      varchar(255) not null,
    removal_basis                    varchar(2000),
    removal_defect                   varchar(2000),
    removal_destination              varchar(32),
    removal_operation_id             uuid,
    removal_payload_identity         varchar(3000),
    removal_reading_id               uuid,
    removed_at                       timestamptz,
    removed_at_hours                 numeric(20,3),
    removed_at_km                    numeric(20,3),
    removed_by                       varchar(255),
    removed_in_repair_id             uuid,
    repair_order_id                  uuid not null,
    restoration_acceptance_id        uuid,
    stock_id                         uuid not null,
    vehicle_id                       uuid not null,
    version                          bigint,
    primary key (id),
    foreign key (engine_hours_reading_id) references vehicle_usage_reading(id),
    foreign key (engine_hours_removal_reading_id) references vehicle_usage_reading(id),
    foreign key (issue_operation_id) references material_operation(id),
    foreign key (odometer_reading_id) references vehicle_usage_reading(id),
    foreign key (odometer_removal_reading_id) references vehicle_usage_reading(id),
    foreign key (part_id) references vehicle_part(id),
    foreign key (part_request_id) references repair_order_part_request(id),
    foreign key (position_id) references part_position(id),
    foreign key (removal_reading_id) references vehicle_usage_reading(id),
    foreign key (removed_in_repair_id) references vehicle_repair(id),
    foreign key (repair_order_id) references vehicle_repair(id),
    foreign key (stock_id) references inventory_stock(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table part_position
(
    id           uuid not null,
    basis        varchar(2000) not null,
    branch_id    uuid,
    category     varchar(32) not null,
    code         varchar(100) not null,
    recorded_by  varchar(255) not null,
    updated_at   timestamptz not null,
    vehicle_id   uuid not null,
    version      bigint,
    primary key (id),
    check (category in ('TIRE', 'BATTERY', 'OIL_FILTER', 'AIR_FILTER', 'BRAKE_PAD', 'OTHER')),
    -- category BAZADA: jadval bo'sh
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table part_position_layout
(
    id                  uuid not null,
    axle_code           varchar(100) not null,
    basis               varchar(2000) not null,
    branch_id           uuid,
    effective_at        timestamptz not null,
    payload_identity    varchar(64) not null,
    position_id         uuid not null,
    previous_layout_id  uuid,
    recorded_at         timestamptz not null,
    recorded_by         varchar(255) not null,
    recorded_by_id      uuid not null,
    revision            bigint not null,
    slot_code           varchar(100) not null,
    technical_document  varchar(2000) not null,
    vehicle_id          uuid not null,
    wheel_side          varchar(16) not null,
    primary key (id),
    check (wheel_side in ('LEFT', 'RIGHT', 'CENTER')),
    -- wheel_side BAZADA: jadval bo'sh
    foreign key (position_id) references part_position(id),
    foreign key (previous_layout_id) references part_position_layout(id),
    foreign key (recorded_by_id) references app_user(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table part_position_layout_head
(
    position_id  uuid not null,
    axle_code    varchar(100) not null,
    branch_id    uuid,
    layout_id    uuid not null,
    slot_code    varchar(100) not null,
    vehicle_id   uuid not null,
    version      bigint,
    wheel_side   varchar(16) not null,
    primary key (position_id),
    check (wheel_side in ('LEFT', 'RIGHT', 'CENTER')),
    -- wheel_side BAZADA: jadval bo'sh
    foreign key (layout_id) references part_position_layout(id),
    foreign key (position_id) references part_position(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table part_replacement_need
(
    id                     uuid not null,
    created_at             timestamptz not null,
    initial_evaluation_id  uuid not null,
    part_id                uuid not null,
    primary key (id),
    foreign key (initial_evaluation_id) references part_condition_evaluation(id),
    foreign key (part_id) references vehicle_part(id)
);

create table part_replacement_resolution
(
    id             uuid not null,
    acceptance_id  uuid not null,
    need_id        uuid not null,
    part_id        uuid not null,
    resolved_at    timestamptz not null,
    primary key (id),
    foreign key (acceptance_id) references part_restoration_acceptance(id),
    foreign key (need_id) references part_replacement_need(id),
    foreign key (part_id) references vehicle_part(id)
);

create table part_resource_opening
(
    id                uuid not null,
    basis             varchar(2000) not null,
    counter           varchar(32) not null,
    observed_at       timestamptz not null,
    part_id           uuid not null,
    payload_identity  varchar(64) not null,
    recorded_at       timestamptz not null,
    recorded_by       varchar(255) not null,
    reference_id      uuid,
    revision          bigint not null,
    source            varchar(100) not null,
    type              varchar(24) not null,
    value             numeric(20,3) not null,
    primary key (id),
    check (counter in ('ODOMETER_KM', 'ENGINE_HOURS')),
    -- counter BAZADA: jadval bo'sh
    check (type in ('BASELINE', 'CORRECTION')),
    -- type BAZADA: jadval bo'sh
    foreign key (part_id) references vehicle_part(id),
    foreign key (reference_id) references part_resource_opening(id)
);

create table part_restoration_acceptance
(
    id                       uuid not null,
    accepted_at              timestamptz not null,
    basis                    varchar(2000) not null,
    branch_id                uuid,
    condition_evaluation_id  uuid not null,
    installation_id          uuid not null,
    part_id                  uuid not null,
    payload_identity         varchar(64) not null,
    previous_acceptance_id   uuid,
    recorded_at              timestamptz not null,
    recorded_by              varchar(255) not null,
    recorded_by_id           uuid not null,
    removal_operation_id     uuid not null,
    replacement_need_id      uuid,
    revision                 bigint,
    work_document            varchar(2000) not null,
    primary key (id),
    foreign key (condition_evaluation_id) references part_condition_evaluation(id),
    foreign key (installation_id) references part_installation(id),
    foreign key (part_id) references vehicle_part(id),
    foreign key (recorded_by_id) references app_user(id)
);

create table part_service_rule
(
    id                          uuid not null,
    active                      boolean not null,
    category                    varchar(16),
    created_at                  timestamptz not null,
    expected_life_days          integer,
    expected_life_engine_hours  numeric(14,3),
    expected_life_km            numeric(14,3),
    expected_life_months        integer,
    name                        varchar(255) not null,
    replace_at_percent          numeric(5,2) not null,
    updated_at                  timestamptz not null,
    version                     bigint not null,
    warning_at_percent          numeric(5,2) not null,
    primary key (id),
    check (category in ('TIRE', 'BATTERY', 'OIL_FILTER', 'AIR_FILTER', 'BRAKE_PAD', 'OTHER'))
    -- category BAZADA: jadval bo'sh
);

create table part_stock_origin
(
    part_id               uuid not null,
    basis                 varchar(2000) not null,
    canonical_serial_key  varchar(400) not null,
    item_id               uuid not null,
    recorded_at           timestamptz not null,
    recorded_by           varchar(255) not null,
    source_operation_id   uuid not null,
    stock_id              uuid not null,
    version               bigint,
    primary key (part_id),
    foreign key (part_id) references vehicle_part(id),
    foreign key (source_operation_id) references material_operation(id),
    foreign key (stock_id) references inventory_stock(id)
);

create table part_write_off_act
(
    id               uuid not null,
    branch_id        uuid,
    chair_id         uuid not null,
    chair_name       varchar(256) not null,
    closed_at        timestamptz,
    closed_by_id     uuid,
    closed_by_name   varchar(256),
    closure_reason   varchar(2000),
    completed_at     timestamptz,
    created_at       timestamptz not null,
    created_by_id    uuid not null,
    created_by_name  varchar(256) not null,
    number           varchar(64) not null,
    reason           varchar(2000) not null,
    signed_at        timestamptz,
    status           varchar(32) not null,
    submitted_at     timestamptz,
    version          bigint not null,
    primary key (id),
    check (status in ('DRAFT', 'IN_REVIEW', 'AWAITING_CHAIR', 'APPROVED', 'COMPLETED', 'REJECTED', 'CANCELLED'))
    -- status BAZADA: jadval bo'sh
);

create table part_write_off_item
(
    act_id              uuid not null,
    conclusion          varchar(2000) not null,
    cost                numeric(14,2),
    currency            varchar(8),
    defect              varchar(2000) not null,
    disposed_at         date,
    disposed_by_id      uuid,
    disposed_by_name    varchar(256),
    disposition         varchar(16),
    document_reference  varchar(255),
    name                varchar(255) not null,
    part_id             uuid not null,
    part_number         varchar(128),
    recipient           varchar(255),
    recorded_at         timestamptz,
    removed_at          date,
    removed_at_km       numeric(14,3),
    repair_number       varchar(64),
    repair_order_id     uuid not null,
    serial_number       varchar(128) not null,
    series              varchar(128) not null,
    vehicle_id          uuid not null,
    vehicle_label       varchar(255),
    item_position       integer not null,
    document_file_id    uuid,
    document_file_name  varchar(255),
    primary key (act_id, item_position),
    check (disposition in ('DESTROYED', 'RECYCLED')),
    -- disposition BAZADA: jadval bo'sh
    foreign key (act_id) references part_write_off_act(id),
    foreign key (part_id) references vehicle_part(id)
);

create table part_write_off_member
(
    act_id           uuid not null,
    approved_at      timestamptz,
    name             varchar(256) not null,
    user_id          uuid not null,
    member_position  integer not null,
    primary key (act_id, member_position),
    foreign key (act_id) references part_write_off_act(id)
);

create table part_writeoff_accounting_intent
(
    id                   uuid not null,
    act_id               uuid not null,
    attempts             integer not null,
    branch_id            uuid,
    created_at           timestamptz not null,
    decision_id          uuid not null,
    envelope_hash        varchar(255),
    envelope_json        text,
    error_code           varchar(255),
    lease_token          uuid,
    lease_until          timestamptz,
    lease_was_lookup     boolean not null,
    lookup_latched       boolean not null,
    lookup_required      boolean not null,
    mutation_started_at  timestamptz,
    next_attempt_at      timestamptz,
    policy_id            uuid,
    source_hash          varchar(64) not null,
    source_json          text not null,
    state                varchar(255) not null,
    version              bigint,
    primary key (id),
    check (state in ('UNCONFIGURED', 'PENDING', 'PROCESSING', 'AWAITING_ACK', 'UNKNOWN', 'CONFIRMED', 'REJECTED')),
    -- state BAZADA: jadval bo'sh
    foreign key (act_id) references part_write_off_act(id),
    foreign key (decision_id) references part_writeoff_decision(id),
    foreign key (id) references part_disposal_command(id),
    foreign key (policy_id) references part_writeoff_accounting_policy(id)
);

create table part_writeoff_accounting_policy
(
    id                     uuid not null,
    assets                 jsonb not null,
    basis                  varchar(2000) not null,
    branch_id              uuid not null,
    document_type          varchar(255) not null,
    epoch                  bigint not null,
    external_organization  varchar(255) not null,
    owner                  varchar(255) not null,
    previous_epoch         bigint not null,
    protocol               varchar(255) not null,
    provider               varchar(255) not null,
    recorded_at            timestamptz not null,
    recorded_by_id         uuid not null,
    primary key (id)
);

create table part_writeoff_accounting_receipt
(
    id                uuid not null,
    confirmed_at      timestamptz not null,
    document_id       varchar(255),
    document_line_id  varchar(255),
    intent_id         uuid not null,
    outcome           varchar(255) not null,
    owner             varchar(255) not null,
    owner_epoch       bigint not null,
    payload_hash      varchar(64) not null,
    policy_id         uuid not null,
    protocol          varchar(255) not null,
    provider          varchar(255) not null,
    receipt_json      text not null,
    recorded_at       timestamptz not null,
    rejection_code    varchar(255),
    primary key (id),
    foreign key (intent_id) references part_writeoff_accounting_intent(id),
    foreign key (policy_id) references part_writeoff_accounting_policy(id)
);

create table part_writeoff_accounting_recovery
(
    id                uuid not null,
    basis             varchar(2000) not null,
    expected_version  bigint not null,
    intent_id         uuid not null,
    payload_hash      varchar(64) not null,
    recorded_at       timestamptz not null,
    recorded_by_id    uuid not null,
    source_hash       varchar(64) not null,
    primary key (id),
    foreign key (intent_id) references part_writeoff_accounting_intent(id),
    foreign key (recorded_by_id) references app_user(id)
);

create table part_writeoff_correction
(
    id                      uuid not null,
    act_id                  uuid not null,
    after_json              text not null,
    basis                   varchar(2000) not null,
    before_json             text not null,
    changes_json            text not null,
    created_at              timestamptz not null,
    created_by_id           uuid not null,
    created_by_name         varchar(256) not null,
    decision_id             uuid not null,
    document_reference      varchar(255) not null,
    payload_hash            varchar(64) not null,
    payload_json            text not null,
    previous_correction_id  uuid,
    source_hash             varchar(64) not null,
    primary key (id),
    foreign key (act_id) references part_write_off_act(id),
    foreign key (created_by_id) references app_user(id),
    foreign key (decision_id) references part_writeoff_decision(id)
);

create table part_writeoff_correction_action
(
    id            uuid not null,
    actor_id      uuid not null,
    actor_name    varchar(256) not null,
    basis         varchar(2000) not null,
    payload_hash  varchar(64) not null,
    payload_json  text not null,
    proposal_id   uuid not null,
    recorded_at   timestamptz not null,
    revision      bigint not null,
    type          varchar(16) not null,
    primary key (id),
    check (type in ('CREATED', 'SUBMITTED', 'APPROVED', 'SIGNED', 'REJECTED', 'CANCELLED')),
    -- type BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (proposal_id) references part_writeoff_correction(id)
);

create table part_writeoff_correction_decision
(
    id                      uuid not null,
    act_id                  uuid not null,
    previous_correction_id  uuid,
    proposal_id             uuid not null,
    signed_at               timestamptz not null,
    signed_by_id            uuid not null,
    signed_by_name          varchar(256) not null,
    snapshot_json           text not null,
    source_hash             varchar(64) not null,
    primary key (id),
    foreign key (act_id) references part_write_off_act(id),
    foreign key (proposal_id) references part_writeoff_correction(id),
    foreign key (signed_by_id) references app_user(id)
);

create table part_writeoff_correction_head
(
    act_id       uuid not null,
    decision_id  uuid not null,
    version      bigint not null,
    primary key (act_id),
    foreign key (act_id) references part_write_off_act(id),
    foreign key (decision_id) references part_writeoff_correction_decision(id)
);

create table part_writeoff_decision
(
    id              uuid not null,
    act_id          uuid not null,
    branch_id       uuid,
    recorded_at     timestamptz not null,
    signed_at       timestamptz not null,
    signed_by_id    uuid not null,
    signed_by_name  varchar(256) not null,
    snapshot_json   text not null,
    primary key (id),
    foreign key (act_id) references part_write_off_act(id),
    foreign key (signed_by_id) references app_user(id)
);

create table payroll_closed_operation
(
    operation_id  uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    path          text not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    check (path in ('policies', 'work', 'work/reverse', 'statements', 'decisions', 'erp/policies', 'erp/queue', 'erp/retry', 'history/assignment', 'history/rate', 'history/timesheet', 'history/review', 'history/scope', 'history/adapter')),
    -- path BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table payroll_history_event
(
    id           uuid not null,
    branch_id    uuid not null,
    kind         text not null,
    revision     bigint not null,
    actor_id     uuid not null,
    original     jsonb not null,
    snapshot     jsonb not null,
    hash         text not null,
    recorded_at  timestamptz not null,
    primary key (id),
    check ((hash ~ '^[0-9a-f]{64}$')),
    check (kind in ('ASSIGNMENT', 'RATE', 'TIMESHEET', 'REVIEW', 'SCOPE', 'ADAPTER')),
    -- kind BAZADA: jadval bo'sh
    check ((revision > 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table payroll_hr_business_receipt
(
    provider     text not null,
    receipt_id   text not null,
    event_id     uuid not null,
    original     jsonb not null,
    hash         text not null,
    received_at  timestamptz not null,
    primary key (provider, receipt_id),
    foreign key (event_id) references payroll_hr_outbox(event_id)
);

create table payroll_hr_delivery_event
(
    id           uuid not null,
    event_id     uuid not null,
    revision     bigint not null,
    state        text not null,
    attempt      integer not null,
    detail       text not null,
    recorded_at  timestamptz not null,
    primary key (id),
    check ((attempt >= 0)),
    check ((revision > 0)),
    check (state in ('QUEUED', 'SENDING', 'UNKNOWN', 'RETRY', 'DELIVERED_AWAITING_ACK', 'ACCEPTED', 'REJECTED', 'BLOCKED_REVIEW')),
    -- state BAZADA: jadval bo'sh
    foreign key (event_id) references payroll_hr_outbox(event_id)
);

create table payroll_hr_message
(
    id              uuid not null,
    operation_id    uuid not null,
    statement_id    uuid not null,
    statement_hash  text not null,
    actor_id        uuid not null,
    original        jsonb not null,
    payload         jsonb not null,
    payload_hash    text not null,
    status          text not null,
    reason          text not null,
    prepared_at     timestamptz not null,
    primary key (id),
    check ((payload_hash ~ '^[0-9a-f]{64}$')),
    check ((reason = 'hr_provider_and_employee_mapping_unconfigured')),
    check ((status = 'unconfigured')),
    -- status BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (statement_id) references payroll_ledger_event(id)
);

create table payroll_hr_outbox
(
    event_id           uuid not null,
    statement_id       uuid not null,
    statement_version  bigint not null,
    statement_hash     text not null,
    branch_id          uuid not null,
    actor_id           uuid not null,
    provider           text not null,
    policy_version     bigint not null,
    policy_hash        text not null,
    destination_hash   text not null,
    idempotency_key    text not null,
    original           jsonb not null,
    payload            jsonb not null,
    wire_payload       text not null,
    payload_hash       text not null,
    recorded_at        timestamptz not null,
    adapter_id         uuid,
    adapter_hash       text,
    adapter_snapshot   jsonb,
    primary key (event_id),
    check ((destination_hash ~ '^[0-9a-f]{64}$')),
    check ((payload_hash ~ '^[0-9a-f]{64}$')),
    foreign key (actor_id) references app_user(id),
    foreign key (adapter_id) references payroll_history_event(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (statement_id) references payroll_ledger_event(id)
);

create table payroll_hr_policy
(
    operation_id  uuid not null,
    branch_id     uuid not null,
    revision      bigint not null,
    actor_id      uuid not null,
    original      jsonb not null,
    hash          text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    check ((hash ~ '^[0-9a-f]{64}$')),
    check ((revision > 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table payroll_hr_provider_receipt
(
    provider     text not null,
    receipt_id   text not null,
    event_id     uuid not null,
    adapter_id   uuid not null,
    original     jsonb not null,
    canonical    jsonb not null,
    hash         text not null,
    received_at  timestamptz not null,
    primary key (provider, receipt_id),
    foreign key (adapter_id) references payroll_history_event(id),
    foreign key (event_id) references payroll_hr_outbox(event_id),
    foreign key (provider, receipt_id) references payroll_hr_business_receipt(provider, receipt_id)
);

create table payroll_hr_retry_operation
(
    operation_id  uuid not null,
    event_id      uuid not null,
    actor_id      uuid not null,
    original      jsonb not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (event_id) references payroll_hr_outbox(event_id)
);

create table payroll_ledger_event
(
    id            uuid not null,
    operation_id  uuid not null,
    branch_id     uuid not null,
    kind          text not null,
    revision      bigint not null,
    actor_id      uuid not null,
    original      jsonb not null,
    snapshot      jsonb not null,
    hash          text not null,
    recorded_at   timestamptz not null,
    primary key (id),
    check ((id = operation_id)),
    check ((hash ~ '^[0-9a-f]{64}$')),
    check (kind in ('POLICY', 'WORK', 'REVERSAL', 'STATEMENT', 'DECISION')),
    -- kind BAZADA: jadval bo'sh
    check ((revision > 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

-- ---------------------------------------------------------------------
-- Haydovchi ish haqi tariflari: reys uchun (trip_rate), km uchun (per_km_rate),
-- tungi soat (night_hour_rate), qo'shimcha soat (overtime_hour_rate) va
-- chetlanish uchun jarima koeffitsienti (deviation_penalty_rate).
-- ISH HAQI HISOBI driver_shift VA trip MA'LUMOTLARI BILAN BIRGA QILINADI.
-- (Ilgari `payroll_rate` deb atalardi — sxema ko'chirishda nomi o'zgargan.)
-- ---------------------------------------------------------------------
create table payroll_rate
(
    id                      uuid not null,
    created_at              timestamptz not null,
    currency                varchar(8) not null,
    deviation_penalty_rate  numeric(18,2) not null,
    night_hour_rate         numeric(18,2) not null,
    overtime_hour_rate      numeric(18,2) not null,
    per_km_rate             numeric(18,2) not null,
    trip_rate               numeric(18,2) not null,
    updated_at              timestamptz not null,
    updated_by              varchar(128),
    primary key (id)
);

-- ---------------------------------------------------------------------
-- GPS qurilmalaridan kelgan xom koordinata yozuvlari (device_id bo'yicha, ATIL
-- obyektlariga bevosita bog'lanmagan). Qurilma qaysi mashinaga tegishliligi
-- vehicle_gps jadvalida (device_id → vehicle_id).
-- MASHINANING JOYLASHUVI SO'RALSA avval vehicle_telemetry_state ga qarash kerak —
-- u tayyor oxirgi holatni beradi.
-- ---------------------------------------------------------------------
create table position_log
(
    id         bigint not null,
    altitude   float8,
    device_id  bigint,
    fix_time   timestamptz,
    latitude   float8,
    longitude  float8,
    saved_at   timestamptz,
    speed      float8,
    valid      boolean not null,
    primary key (id)
);

-- ---------------------------------------------------------------------
-- Tovar/material nomenklaturasi (nomi, tavsifi, o'lchov birligi).
-- Ombordagi qoldiqlari inventory_stock jadvalida.
-- ---------------------------------------------------------------------
create table product
(
    id           uuid not null,
    created_at   timestamptz not null,
    description  varchar(255),
    name         varchar(255),
    unit         varchar(32),
    updated_at   timestamptz,
    primary key (id)
);

create table production_order
(
    id                    uuid not null,
    created_at            timestamptz not null,
    notes                 varchar(1024),
    order_number          varchar(64) not null,
    planned_end_date      timestamptz,
    planned_start_date    timestamptz,
    product_id            uuid,
    production_line_code  varchar(64),
    quantity              integer,
    sku                   varchar(128),
    status                varchar(32),
    target_warehouse_id   varchar(64),
    unit                  varchar(32),
    updated_at            timestamptz,
    history_tracked       boolean not null,
    version               bigint not null,
    primary key (id)
    -- status BAZADA: PLANNED 1
);

create table production_order_authority
(
    order_id             uuid not null,
    branch_id            uuid not null,
    creator_id           uuid not null,
    registered_at        timestamptz not null,
    source_operation_id  uuid not null,
    source_origin        varchar(32) not null,
    primary key (order_id)
);

create table production_order_command
(
    id             uuid not null,
    actor_id       uuid not null,
    actor_name     varchar(256) not null,
    kind           varchar(16) not null,
    order_id       uuid not null,
    order_version  bigint not null,
    original_json  text not null,
    payload_hash   varchar(64) not null,
    recorded_at    timestamptz not null,
    result_json    text not null,
    tx_id          bigint not null,
    primary key (id)
);

create table production_order_history
(
    id             uuid not null,
    action         varchar(32) not null,
    actor_id       uuid not null,
    actor_name     varchar(256) not null,
    current_json   text not null,
    order_id       uuid not null,
    order_version  bigint not null,
    previous_json  text,
    recorded_at    timestamptz not null,
    primary key (id)
);

create table production_order_history_context
(
    order_id       uuid not null,
    order_version  bigint not null,
    tx_id          bigint not null,
    previous_json  jsonb,
    current_json   jsonb not null,
    primary key (order_id, order_version)
);

create table rail_car
(
    id               uuid not null,
    capacity_tons    integer,
    car_number       varchar(64) not null,
    created_at       timestamptz not null,
    current_station  varchar(256),
    kind             varchar(32),
    ownership        varchar(64),
    status           varchar(32),
    updated_at       timestamptz,
    primary key (id)
    -- status BAZADA: jadval bo'sh
);

create table rail_car_hazard_classes
(
    rail_car_id   uuid not null,
    hazard_class  varchar(32),
    foreign key (rail_car_id) references rail_car(id)
);

-- ---------------------------------------------------------------------
-- UMUMIY KATALOG JADVALI — BARCHA MA'LUMOTNOMALAR SHU JADVALDA SAQLANADI va
-- catalog_type bilan ajratiladi: BRANCHES (filiallar), DEPARTMENTS (bo'limlar),
-- POSITIONS (lavozimlar), LOCATIONS (manzillar), FUEL_TYPES, FUEL_WAREHOUSES
-- (yoqilg'i omborlari), FUEL_SOURCE_TYPES, FUEL_DOCUMENT_TYPES, ORG_STRUCTURE.
-- BO'LIM, FILIAL, MANZIL YOKI LAVOZIM NOMI KERAK BO'LSA SHU JADVALDAN
-- catalog_type BO'YICHA FILTRLAB OLINADI. parent_id ierarxiyani beradi,
-- latitude/longitude — manzil koordinatalari.
-- ---------------------------------------------------------------------
create table reference_data
(
    id               uuid not null,
    active           boolean not null,
    address          varchar(512),
    branch_id        uuid,
    capacity_liters  numeric(14,3),
    catalog_type     varchar(32) not null,
    code             varchar(64),
    created_at       timestamptz not null,
    department_id    uuid,
    latitude         float8,
    location_id      uuid,
    longitude        float8,
    name             varchar(256) not null,
    parent_id        uuid,
    reference_type   varchar(64),
    short_name       varchar(128),
    unit             varchar(32),
    updated_at       timestamptz not null,
    fuel_storage     jsonb,
    primary key (id),
    check ((((catalog_type) <> 'mxik_codes') or ((code is not null) and ((code) ~ '^[0-9]{17}$') and (btrim((name)) <> '')))),
    check (catalog_type in ('BRANCHES', 'ORG_STRUCTURE', 'DEPARTMENTS', 'POSITIONS', 'LOCATIONS', 'REPAIR_ZONES', 'MATERIAL_WAREHOUSES', 'MATERIAL_GROUPS', 'MEASUREMENT_UNITS', 'MXIK_CODES', 'FUEL_TYPES', 'FUEL_WAREHOUSES', 'FUEL_SOURCE_TYPES', 'FUEL_DOCUMENT_TYPES')),
    -- catalog_type BAZADA: DEPARTMENTS 102, FUEL_TYPES 8, LOCATIONS 6, FUEL_DOCUMENT_TYPES 6, FUEL_SOURCE_TYPES 4, BRANCHES 4, FUEL_WAREHOUSES 3, MATERIAL_WAREHOUSES 1, MEASUREMENT_UNITS 1, POSITIONS 1 | ISHLATILMAGAN: ORG_STRUCTURE, REPAIR_ZONES, MATERIAL_GROUPS, MXIK_CODES
    foreign key (parent_id) references reference_data(id) not valid
);

create table repair_cost_acceptance
(
    id                       uuid not null,
    accepted_at              timestamptz not null,
    accepted_by_id           uuid not null,
    accepted_by_name         varchar(256) not null,
    basis                    varchar(2000) not null,
    branch_id                uuid not null,
    currency                 varchar(3),
    description              varchar(2000) not null,
    document_issuer          varchar(255) not null,
    document_reference       varchar(255) not null,
    kind                     varchar(32) not null,
    line_reference           varchar(128) not null,
    money_scale              integer,
    operational_amount       numeric(24,6),
    owner_epoch              bigint not null,
    payload_identity         varchar(64) not null,
    payload_json             text not null,
    performed_from           timestamptz not null,
    performed_to             timestamptz not null,
    quantity                 numeric(20,3) not null,
    rate_document            varchar(255),
    rate_effective_from      timestamptz,
    rate_effective_to        timestamptz,
    repair_id                uuid not null,
    repair_version           bigint not null,
    source_owner             varchar(32) not null,
    supplier_reference       varchar(255),
    unit                     varchar(32) not null,
    unit_rate                numeric(20,6),
    vehicle_id               uuid not null,
    work_item_id             varchar(128),
    worker_id                uuid,
    worker_name              varchar(256),
    work_source              varchar(32),
    completion_operation_id  uuid,
    work_evidence            varchar(512),
    primary key (id),
    check ((((work_source is null) and (completion_operation_id is null) and (work_evidence is null)) or (((work_source) = 'canonical_done_work') and ((kind) = 'labor') and (completion_operation_id is not null) and (work_evidence is not null)))),
    check (kind in ('LABOR', 'CONTRACTOR_SERVICE')),
    -- kind BAZADA: jadval bo'sh
    foreign key (accepted_by_id) references app_user(id),
    foreign key (repair_id) references vehicle_repair(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table repair_cost_adjustment
(
    id                      uuid not null,
    acted_at                timestamptz not null,
    actor_id                uuid not null,
    actor_name              varchar(256) not null,
    branch_id               uuid not null,
    document_reference      varchar(255) not null,
    kind                    varchar(16) not null,
    line_reference          varchar(128) not null,
    payload_identity        varchar(64) not null,
    payload_json            text not null,
    previous_adjustment_id  uuid,
    reason                  varchar(2000) not null,
    repair_id               uuid not null,
    repair_version          bigint not null,
    replacement_source_id   uuid,
    root_source_id          uuid not null,
    source_id               uuid not null,
    vehicle_id              uuid not null,
    primary key (id),
    check (kind in ('CANCEL', 'REPLACE'))
    -- kind BAZADA: jadval bo'sh
);

create table repair_cost_adjustment_closed
(
    id                      uuid not null,
    repair_id               uuid not null,
    actor_id                uuid not null,
    branch_id               uuid not null,
    replacement_command_id  uuid,
    original_json           text not null,
    raw_command             text not null,
    raw_sha                 varchar(64) not null,
    payload_sha             varchar(64) not null,
    reason                  text not null,
    receipt_json            text not null,
    closed_at               timestamptz not null,
    primary key (id),
    check (((replacement_command_id is null) or (replacement_command_id <> id))),
    check (((payload_sha) ~ '^[0-9a-f]{64}$')),
    check (((raw_sha) ~ '^[0-9a-f]{64}$')),
    check (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 2000))),
    foreign key (actor_id) references app_user(id),
    foreign key (repair_id) references vehicle_repair(id)
);

create table repair_cost_adjustment_head
(
    root_source_id         uuid not null,
    branch_id              uuid not null,
    current_adjustment_id  uuid,
    current_source_id      uuid,
    repair_id              uuid not null,
    vehicle_id             uuid not null,
    version                bigint not null,
    primary key (root_source_id)
);

create table repair_cost_canonical_active
(
    repair_id  uuid not null,
    work_id    text not null,
    source_id  uuid not null,
    primary key (repair_id, work_id),
    foreign key (repair_id, work_id) references fleet_repair_work(repair_id, work_id),
    foreign key (source_id) references repair_cost_acceptance(id)
);

create table repair_material_operating_price
(
    id              uuid not null,
    source_id       uuid not null,
    repair_id       uuid not null,
    vehicle_id      uuid not null,
    branch_id       uuid not null,
    actor_id        uuid not null,
    source_version  bigint not null,
    owner_epoch     bigint not null,
    quantity        numeric(16,3) not null,
    unit            varchar(32) not null,
    unit_rate       numeric(20,6) not null,
    currency        varchar(3) not null,
    money_scale     integer not null,
    amount          numeric(24,6) not null,
    price_document  varchar(255) not null,
    confirmed_at    timestamptz not null,
    payload_json    text not null,
    source_json     text not null,
    fact_json       text not null,
    primary key (id),
    check (((amount = (quantity * unit_rate)) and (trunc(amount, money_scale) = amount))),
    check (((money_scale >= 0) and (money_scale <= 6))),
    check ((owner_epoch >= 0)),
    check ((quantity > (0))),
    check ((source_version >= 0)),
    check ((unit_rate >= (0))),
    foreign key (actor_id) references app_user(id),
    foreign key (id) references repair_material_price_closure(id) deferrable initially deferred,
    foreign key (repair_id) references vehicle_repair(id),
    foreign key (source_id) references material_operation(id)
);

create table repair_material_price_closure
(
    id            uuid not null,
    repair_id     uuid not null,
    actor_id      uuid not null,
    branch_id     uuid not null,
    state         varchar(16) not null,
    payload_json  text not null,
    reason        text,
    receipt_json  text not null,
    closed_at     timestamptz not null,
    primary key (id),
    check (((((state) = 'not_executed') and repair_cost_text_ok(reason, 2000, true)) or (((state) = 'recorded') and (reason is null)))),
    check (state in ('RECORDED', 'NOT_EXECUTED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (repair_id) references vehicle_repair(id)
);

-- ---------------------------------------------------------------------
-- Ta'mirga EHTIYOT QISM so'rovi: qaysi ta'mir buyurtmasiga, qaysi tovar
-- (item_name), qancha so'ralgan/berilgan/ishlatilgan/qaytarilgan,
-- o'lchov birligi, qaysi ombordan. Ta'mirning o'zi vehicle_repair da.
-- ---------------------------------------------------------------------
create table repair_order_part_request
(
    id                          uuid not null,
    branch_id                   uuid,
    created_at                  timestamptz not null,
    issued_at                   timestamptz,
    issued_by                   varchar(255),
    issued_quantity             numeric(14,3),
    item_id                     uuid not null,
    item_name                   varchar(256),
    notes                       varchar(2000),
    rejection_reason            varchar(1000),
    repair_order_id             uuid not null,
    requested_at                timestamptz not null,
    requested_by                varchar(255) not null,
    requested_quantity          numeric(14,3) not null,
    return_requested_at         timestamptz,
    return_requested_by         varchar(255),
    return_requested_quantity   numeric(14,3),
    returned_at                 timestamptz,
    returned_by                 varchar(255),
    returned_quantity           numeric(14,3),
    status                      varchar(64) not null,
    unit_of_measure             varchar(32),
    updated_at                  timestamptz not null,
    used_at                     timestamptz,
    used_by                     varchar(255),
    used_quantity               numeric(14,3),
    vehicle_id                  uuid not null,
    warehouse_id                uuid,
    approved_at                 timestamptz,
    approved_by                 varchar(255),
    stock_id                    uuid,
    version                     bigint not null,
    transport_head_approved_by  varchar(255),
    transport_head_approved_at  timestamptz,
    pto_approved_by             varchar(255),
    pto_approved_at             timestamptz,
    arm_installed_by            varchar(255),
    arm_installed_at            timestamptz,
    pto_installed_by            varchar(255),
    pto_installed_at            timestamptz,
    installed_location          varchar(500),
    disposition_note            varchar(500),
    requisition_number          varchar(64),
    primary key (id),
    check (status in ('REQUESTED', 'WAITING_PARTS_APPROVAL', 'PARTS_APPROVED', 'ISSUED', 'RETURN_REQUESTED', 'RETURNED', 'USED', 'REJECTED'))
    -- status BAZADA: USED 9, PARTS_APPROVED 2 | ISHLATILMAGAN: REQUESTED, WAITING_PARTS_APPROVAL, ISSUED, RETURN_REQUESTED, RETURNED, REJECTED
);

create table repair_stage_signature
(
    operation_id             uuid not null,
    repair_id                uuid not null,
    repair_version           bigint not null,
    stage                    varchar(64) not null,
    actor_id                 uuid not null,
    branch_id                uuid not null,
    payload_sha256           varchar(64) not null,
    payload                  text not null,
    signature_data           text not null,
    certificate_sha256       varchar(64) not null,
    certificate_serial       varchar(128) not null,
    signer_name              varchar(128) not null,
    signed_at                timestamptz not null,
    certificate_valid_until  timestamptz not null,
    authority_id             uuid not null,
    authority_revision       bigint not null,
    policy_id                uuid not null,
    policy_revision          bigint not null,
    primary key (operation_id),
    check (((certificate_sha256) ~ '^[a-f0-9]{64}$')),
    check (coalesce(((payload_sha256) = encode(sha256(convert_to(payload, 'utf8'::name)), 'hex')), false)),
    check (coalesce(((((payload)::jsonb ->> 'actorid'))::uuid = actor_id), false)),
    check (coalesce(((((payload)::jsonb #>> '{repair,id}'[]))::uuid = repair_id), false)),
    check (coalesce(((((payload)::jsonb #>> '{repair,branchid}'[]))::uuid = branch_id), false)),
    check (coalesce(((((payload)::jsonb #>> '{repair,version}'[])) = repair_version), false)),
    check (coalesce(((((payload)::jsonb #>> '{command,operationid}'[]))::uuid = operation_id), false)),
    check (coalesce((((payload)::jsonb #>> '{command,stage}'[]) = (stage)), false)),
    check (coalesce((((payload)::jsonb ->> 'contract') = 'atil_repair_stage_signature_v1'), false)),
    check (((payload_sha256) ~ '^[a-f0-9]{64}$')),
    check ((repair_version >= 0)),
    check (((length(signature_data) >= 1) and (length(signature_data) <= 20000))),
    check (stage in ('REPAIR_WORK_COMPLETION', 'REPAIR_FINAL_APPROVAL')),
    -- stage BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (authority_id, authority_revision) references integration_signer_authority(id, revision),
    foreign key (policy_id) references integration_signature_policy(id),
    foreign key (repair_id) references vehicle_repair(id)
);

create table repair_temporary_acceptance
(
    operation_id  uuid not null,
    repair_id     uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    action        text not null,
    policy_id     uuid,
    target_id     uuid,
    original      jsonb not null,
    document      jsonb not null,
    sources       jsonb not null,
    source_hash   text not null,
    prior_status  text not null,
    valid_until   timestamptz,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    check (action in ('ACCEPT', 'REVOKE')),
    -- action BAZADA: jadval bo'sh
    check ((((action = 'accept') and (policy_id is not null) and (target_id is null) and (valid_until is not null)) or ((action = 'revoke') and (target_id is not null)))),
    foreign key (actor_id) references app_user(id),
    foreign key (operation_id) references fleet_operation(operation_id) deferrable initially deferred,
    foreign key (policy_id) references repair_temporary_policy(operation_id),
    foreign key (repair_id) references vehicle_repair(id),
    foreign key (target_id) references repair_temporary_acceptance(operation_id)
);

create table repair_temporary_policy
(
    operation_id  uuid not null,
    repair_id     uuid not null,
    branch_id     uuid not null,
    actor_id      uuid not null,
    action        text not null,
    policy_id     uuid not null,
    original      jsonb not null,
    document      jsonb not null,
    sources       jsonb not null,
    source_hash   text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    check (action in ('AUTHOR', 'APPROVE', 'POLICY_REVOKE')),
    -- action BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (operation_id) references fleet_operation(operation_id) deferrable initially deferred,
    foreign key (policy_id) references repair_temporary_policy(operation_id) deferrable initially deferred,
    foreign key (repair_id) references vehicle_repair(id)
);

create table report_export_job
(
    operation_id    uuid not null,
    actor_id        uuid not null,
    branch_id       uuid not null,
    kind            text not null,
    source_id       uuid not null,
    original        jsonb not null,
    original_hash   text not null,
    source_hash     text not null,
    source_version  text not null,
    row_count       bigint not null,
    state           text not null,
    attempt         bigint not null,
    lease_token     uuid,
    lease_until     timestamptz,
    reason          text,
    artifact        bytea,
    artifact_hash   text,
    byte_count      bigint,
    emitted_rows    bigint,
    created_at      timestamptz not null,
    finished_at     timestamptz,
    primary key (operation_id),
    check ((attempt >= 0)),
    check (((state <> 'ready') or (((artifact is not null) and (artifact_hash = encode(sha256(artifact), 'hex')) and (byte_count = octet_length(artifact)) and (emitted_rows = row_count) and (finished_at is not null)) is true))),
    check (kind in ('FINANCE_ANALYTICS', 'OPERATIONAL_SNAPSHOT', 'FUEL_MONTHLY')),
    -- kind BAZADA: jadval bo'sh
    check ((original_hash ~ '^[a-f0-9]{64}$')),
    check ((reason ~ '^[a-z_]{1,64}$')),
    check ((row_count >= 0)),
    check ((source_hash ~ '^[a-f0-9]{64}$')),
    check (state in ('QUEUED', 'RUNNING', 'READY', 'FAILED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table retention_document_blob
(
    version_id     uuid not null,
    storage_key    text not null,
    metadata_hash  text not null,
    content_hash   text not null,
    content        bytea not null,
    captured_at    timestamptz not null,
    primary key (version_id),
    check ((content_hash = encode(sha256(content), 'hex'))),
    check ((octet_length(content) <= 268435456))
);

create table retention_record_catalog
(
    source_table         text not null,
    event_type           text not null,
    category             text not null,
    primary_key_columns  text[] not null,
    time_column          text not null,
    suggested_days       integer not null,
    primary key (source_table),
    check (category in ('BUSINESS', 'GPS', 'TECHNICAL_LOG')),
    -- category BAZADA: BUSINESS 35, GPS 1, TECHNICAL_LOG 1
    check ((event_type = ('record_' || upper(source_table)))),
    check ((cardinality(primary_key_columns) > 0)),
    check ((source_table ~ '^[a-z][a-z0-9_]*$')),
    check ((suggested_days > 0))
);

create table retention_record_proof
(
    archive_id         uuid not null,
    event_id           uuid not null,
    source_table       text not null,
    source_key         jsonb not null,
    relationship_keys  jsonb not null,
    payload_hash       text not null,
    primary key (archive_id, event_id),
    foreign key (archive_id, event_id) references audit_retention_proof(archive_id, event_id) deferrable initially deferred
);

create table retention_technical_log
(
    id               uuid not null,
    occurred_at      timestamptz not null,
    received_at      timestamptz not null,
    level            text not null,
    logger           text not null,
    thread           text not null,
    message          text not null,
    throwable        text,
    source_instance  uuid not null,
    source_sequence  bigint not null,
    primary key (id)
);

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
create table route
(
    id                          uuid not null,
    assigned_driver_id          uuid,
    assigned_vehicle_id         uuid,
    assignment_decision_status  varchar(32) not null,
    created_at                  timestamptz not null,
    latitude                    float8,
    longitude                   float8,
    name                        varchar(255) not null,
    planned_arrival_at          timestamp,
    planned_departure_at        timestamp,
    planned_duration_minutes    bigint not null,
    planned_trip_id             uuid,
    planned_trip_number         varchar(255),
    required_driver_category    varchar(8) not null,
    required_transport_type     varchar(32) not null,
    route_number                varchar(32) not null,
    sequence_number             integer,
    status                      varchar(32) not null,
    updated_at                  timestamptz not null,
    version                     bigint not null,
    planning_end_instant        timestamptz,
    planning_end_local          varchar(64),
    planning_start_instant      timestamptz,
    planning_start_local        varchar(64),
    planning_time_zone          varchar(64),
    requestless_plan_json       text,
    primary key (id),
    check (assignment_decision_status in ('PENDING', 'VEHICLE_ASSIGNED', 'DRIVER_ASSIGNED', 'FULLY_ASSIGNED', 'TRIP_PLANNED')),
    -- assignment_decision_status BAZADA: FULLY_ASSIGNED 2698, TRIP_PLANNED 1967, PENDING 33, VEHICLE_ASSIGNED 2, DRIVER_ASSIGNED 1
    check (required_driver_category in ('A', 'B', 'BE', 'C', 'CE', 'D', 'DE', 'E')),
    -- required_driver_category BAZADA: B 1961, C 1566, D 585, CE 253, DE 120, BE 116, A 78, E 22
    check (required_transport_type in ('MOBILE_CRANE', 'AERIAL_PLATFORM', 'TRACTOR', 'WATER_TRUCK', 'EXCAVATOR', 'FRONT_LOADER', 'DUMP_TRUCK', 'LONG_LOAD_TRUCK', 'FLATBED', 'MANIPULATOR', 'PASSENGER_CAR', 'BUS', 'VAN', 'BULLDOZER', 'CONCRETE_PUMP', 'CONCRETE_MIXER', 'FIRE_TRUCK', 'AMBULANCE', 'TRUCK', 'TANKER', 'REFRIGERATED', 'SPECIALIZED', 'MINIBUS', 'PICKUP', 'TRAILER', 'OTHER', 'ELECTRIC_VEHICLE')),
    -- required_transport_type BAZADA: PASSENGER_CAR 1896, BUS 747, DUMP_TRUCK 505, FLATBED 308, TRACTOR 227, MOBILE_CRANE 226, FRONT_LOADER 164, AERIAL_PLATFORM 142, EXCAVATOR 131, LONG_LOAD_TRUCK 129, VAN 96, MANIPULATOR 47, WATER_TRUCK 39, SPECIALIZED 26, ELECTRIC_VEHICLE 12, CONCRETE_MIXER 3, TRUCK 3 | ISHLATILMAGAN: BULLDOZER, CONCRETE_PUMP, FIRE_TRUCK, AMBULANCE, TANKER, REFRIGERATED, MINIBUS, PICKUP va yana 2 ta
    check (status in ('DRAFT', 'READY_FOR_ASSIGNMENT', 'DRIVER_ASSIGNED', 'VEHICLE_ASSIGNED', 'FULLY_ASSIGNED', 'TRIP_PLANNED', 'CANCELLED'))
    -- status BAZADA: FULLY_ASSIGNED 2698, TRIP_PLANNED 1967, READY_FOR_ASSIGNMENT 33, VEHICLE_ASSIGNED 2, DRIVER_ASSIGNED 1 | ISHLATILMAGAN: DRAFT, CANCELLED
);

-- ---------------------------------------------------------------------
-- Marshrut nuqtalari: ketma-ketlik raqami (sequence_number), nuqta turi
-- (ORIGIN, WAYPOINT, LOADING, UNLOADING, DESTINATION), oldingi nuqtadan masofa va
-- yurish vaqti, rejadagi kelish/ketish vaqti, koordinata.
-- MARSHRUT YO'NALISHI SO'RALSA sequence_number BO'YICHA TARTIBLANADI.
-- ---------------------------------------------------------------------
create table route_point
(
    id                                    uuid not null,
    distance_from_previous_km             numeric(14,3) not null,
    drive_duration_from_previous_minutes  bigint not null,
    latitude                              float8,
    location_id                           uuid not null,
    location_name                         varchar(512),
    longitude                             float8,
    planned_arrival_at                    timestamp not null,
    planned_departure_at                  timestamp not null,
    point_type                            varchar(32) not null,
    sequence_number                       integer not null,
    route_id                              uuid not null,
    planning_end_instant                  timestamptz,
    planning_end_local                    varchar(64),
    planning_start_instant                timestamptz,
    planning_start_local                  varchar(64),
    planning_time_zone                    varchar(64),
    primary key (id),
    foreign key (route_id) references route(id)
);

-- ---------------------------------------------------------------------
-- Marshrut va transport so'rovi o'rtasidagi bog'lovchi jadval. BITTA MARSHRUTGA
-- BIR NECHTA SO'ROV BIRLASHTIRILISHI MUMKIN (konsolidatsiya). So'rov qaysi
-- marshrutga tushganini bilish uchun shu jadval orqali JOIN qilinadi.
-- ---------------------------------------------------------------------
create table route_transport_request
(
    route_id              uuid not null,
    transport_request_id  uuid not null,
    foreign key (route_id) references route(id)
);

create table safety_capa_action
(
    id                         uuid not null,
    incident_id                uuid not null,
    kind                       varchar(16) not null,
    description                text not null,
    owner_id                   uuid not null,
    due_at                     timestamptz not null,
    required                   boolean not null,
    state                      varchar(16) not null,
    version                    bigint not null,
    completion_evidence_id     uuid,
    completed_by               uuid,
    completed_at               timestamptz,
    effectiveness_evidence_id  uuid,
    reviewed_by                uuid,
    reviewed_at                timestamptz,
    review_reason              text,
    created_by                 uuid not null,
    created_at                 timestamptz not null,
    primary key (id),
    check ((((state) = 'open') or (completion_evidence_id is not null))),
    check ((((state) <> all (array[('effective'), ('ineffective')])) or ((effectiveness_evidence_id is not null) and (reviewed_by <> owner_id) and (reviewed_by <> created_by)))),
    check (((length(trim(both from description)) >= 1) and (length(trim(both from description)) <= 4000))),
    check (kind in ('CORRECTIVE', 'PREVENTIVE')),
    -- kind BAZADA: jadval bo'sh
    check (state in ('OPEN', 'COMPLETED', 'EFFECTIVE', 'INEFFECTIVE')),
    -- state BAZADA: jadval bo'sh
    foreign key (completed_by) references app_user(id),
    foreign key (completion_evidence_id) references safety_domain_evidence(id),
    foreign key (created_by) references app_user(id),
    foreign key (effectiveness_evidence_id) references safety_domain_evidence(id),
    foreign key (incident_id) references incident(id),
    foreign key (owner_id) references app_user(id),
    foreign key (reviewed_by) references app_user(id)
);

create table safety_domain_evidence
(
    id                uuid not null,
    aggregate_id      uuid not null,
    branch_id         uuid not null,
    domain            varchar(16) not null,
    kind              varchar(32) not null,
    file_name         text,
    content_type      text,
    sha256            varchar(64) not null,
    content_bytes     bytea not null,
    source_reference  text not null,
    occurred_at       timestamptz not null,
    actor_id          uuid not null,
    recorded_at       timestamptz not null,
    primary key (id),
    check (((octet_length(content_bytes) >= 1) and (octet_length(content_bytes) <= 10485760))),
    check (domain in ('INCIDENT', 'INCIDENT_RETURN', 'FINE')),
    -- domain BAZADA: jadval bo'sh
    check (kind in ('PHOTO', 'DOCUMENT', 'PAYMENT', 'EXECUTION', 'EFFECTIVENESS', 'RETURN')),
    -- kind BAZADA: jadval bo'sh
    check (((sha256) ~ '^[a-f0-9]{64}$')),
    check ((length(trim(both from source_reference)) > 0)),
    foreign key (actor_id) references app_user(id)
);

create table safety_domain_history
(
    id                 uuid not null,
    aggregate_id       uuid not null,
    branch_id          uuid not null,
    domain             varchar(32) not null,
    aggregate_version  bigint not null,
    transaction_id     bigint not null,
    action             varchar(64) not null,
    actor_id           uuid not null,
    actor_kind         varchar(32) not null,
    reason             text not null,
    before_json        jsonb not null,
    after_json         jsonb not null,
    recorded_at        timestamptz not null,
    primary key (id),
    check (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 2000))),
    foreign key (actor_id) references app_user(id)
);

create table safety_draft_replan_permit
(
    id                          uuid not null,
    qualification_permit_id     uuid not null,
    target_type                 varchar(24) not null,
    target_id                   uuid not null,
    target_version              bigint not null,
    branch_id                   uuid not null,
    route_id                    uuid not null,
    load_revision_id            uuid not null,
    load_assessment_hash        varchar(64) not null,
    actor_id                    uuid not null,
    state                       varchar(24) not null,
    positive_driving_clearance  boolean not null,
    transaction_id              bigint not null,
    proof_json                  text not null,
    proof_hash                  varchar(64) not null,
    recorded_at                 timestamptz not null,
    primary key (id),
    check ((not positive_driving_clearance)),
    check (((state) = 'pending_review')),
    check (target_type in ('ROUTE', 'TRIP', 'WAYBILL')),
    -- target_type BAZADA: jadval bo'sh
    check ((target_version > 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (load_revision_id) references transport_load_manifest_revision(id),
    foreign key (qualification_permit_id) references driver_qualification_permit(id),
    foreign key (route_id) references route(id)
);

create table safety_fine_policy
(
    id                     uuid not null,
    branch_id              uuid not null,
    regulation_reference   text not null,
    valid_from             timestamptz not null,
    valid_to               timestamptz not null,
    amount_per_excess_kph  numeric(14,2) not null,
    speed_limit_kph        numeric(10,3) not null,
    currency               varchar(3) not null,
    rounding_mode          varchar(16) not null,
    created_by             uuid not null,
    created_at             timestamptz not null,
    approved_by            uuid,
    approved_at            timestamptz,
    revoked_by             uuid,
    revoked_at             timestamptz,
    revocation_reason      text,
    primary key (id),
    check ((amount_per_excess_kph > (0))),
    check ((valid_to > valid_from)),
    check (((approved_by is null) or (approved_by <> created_by))),
    check (((approved_by is null) = (approved_at is null))),
    check (((currency) ~ '^[a-z]{3}$')),
    check ((length(trim(both from regulation_reference)) > 0)),
    check (rounding_mode in ('HALF_UP', 'HALF_EVEN', 'DOWN', 'UP')),
    -- rounding_mode BAZADA: jadval bo'sh
    check ((speed_limit_kph > (0))),
    foreign key (approved_by) references app_user(id),
    foreign key (created_by) references app_user(id),
    foreign key (revoked_by) references app_user(id)
);

create table safety_incident_notification_outbox
(
    id                 uuid not null,
    incident_id        uuid not null,
    action_id          uuid not null,
    branch_id          uuid not null,
    recipient_id       uuid not null,
    event_kind         varchar(32) not null,
    due_at             timestamptz not null,
    state              varchar(16) not null,
    attention_id       uuid,
    next_attempt_at    timestamptz,
    attempts           integer not null,
    last_error         varchar(1000),
    created_at         timestamptz not null,
    delivered_at       timestamptz,
    action_generation  bigint,
    primary key (id),
    foreign key (action_id) references safety_capa_action(id),
    foreign key (incident_id) references incident(id),
    foreign key (recipient_id) references app_user(id)
);

create table safety_incident_policy
(
    id                                  uuid not null,
    branch_id                           uuid not null,
    regulation_reference                text not null,
    valid_from                          timestamptz not null,
    valid_to                            timestamptz not null,
    independent_effectiveness_required  boolean not null,
    corrective_action_required          boolean not null,
    preventive_action_required          boolean not null,
    primary_recipient_id                uuid,
    backup_recipient_id                 uuid,
    escalation_hours                    integer,
    created_by                          uuid not null,
    created_at                          timestamptz not null,
    approved_by                         uuid,
    approved_at                         timestamptz,
    revoked_by                          uuid,
    revoked_at                          timestamptz,
    revocation_reason                   text,
    primary key (id),
    check ((valid_to > valid_from)),
    check (((approved_by is null) or (approved_by <> created_by))),
    check (((approved_by is null) = (approved_at is null))),
    check (((primary_recipient_id is distinct from backup_recipient_id) or (primary_recipient_id is null))),
    check (((escalation_hours >= 1) and (escalation_hours <= 8760))),
    check ((length(trim(both from regulation_reference)) > 0)),
    foreign key (approved_by) references app_user(id),
    foreign key (backup_recipient_id) references app_user(id),
    foreign key (created_by) references app_user(id),
    foreign key (primary_recipient_id) references app_user(id),
    foreign key (revoked_by) references app_user(id)
);

create table safety_incident_restriction
(
    id                   uuid not null,
    incident_id          uuid,
    branch_id            uuid,
    resource_kind        varchar(16),
    resource_id          uuid,
    section_reference    text,
    decision             varchar(8),
    blocked_decision_id  uuid,
    effective_at         timestamptz,
    expires_at           timestamptz,
    evidence_id          uuid,
    actor_id             uuid,
    reason               text,
    recorded_at          timestamptz,
    primary key (id),
    foreign key (actor_id) references app_user(id),
    foreign key (blocked_decision_id) references safety_incident_restriction(id),
    foreign key (evidence_id) references safety_domain_evidence(id),
    foreign key (incident_id) references incident(id)
);

create table safety_medical_preservation
(
    id                   uuid not null,
    sequence             bigint not null,
    branch_id            uuid not null,
    object_type          varchar(32) not null,
    object_id            uuid not null,
    revision             bigint not null,
    actor_id             uuid not null,
    operation_id         uuid not null,
    action               varchar(32) not null,
    recorded_at          timestamptz not null,
    payload              jsonb not null,
    assessment_snapshot  jsonb not null,
    primary key (id),
    check (action in ('HOLD', 'RELEASE_HOLD', 'APPROVE_ARCHIVE_REVIEW')),
    -- action BAZADA: jadval bo'sh
    check (object_type in ('MEDICAL_INSPECTION', 'EMERGENCY_CASE', 'CLINICAL_READ_AUDIT')),
    -- object_type BAZADA: jadval bo'sh
    check ((revision > 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table safety_medical_privacy_command_closure
(
    operation_id  uuid not null,
    actor_id      uuid not null,
    branch_id     uuid not null,
    kind          text not null,
    original      jsonb not null,
    reason        text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    check (kind in ('POLICY', 'DECISION', 'PRESERVATION')),
    -- kind BAZADA: jadval bo'sh
    check (((length(trim(both from reason)) >= 1) and (length(trim(both from reason)) <= 2000))),
    foreign key (actor_id) references app_user(id)
);

create table safety_medical_private_read
(
    id              uuid not null,
    actor_id        uuid not null,
    branch_id       uuid not null,
    object_type     varchar(32) not null,
    object_id       uuid not null,
    object_version  bigint,
    view            varchar(16) not null,
    record_count    integer not null,
    correlation_id  varchar(128),
    occurred_at     timestamptz not null,
    primary key (id),
    check (object_type in ('MEDICAL_INSPECTION', 'EMERGENCY_CASE')),
    -- object_type BAZADA: MEDICAL_INSPECTION 78196, EMERGENCY_CASE 434
    check ((record_count >= 0)),
    check (view in ('DETAIL', 'SEARCH', 'HISTORY')),
    -- view BAZADA: SEARCH 78576, DETAIL 29, HISTORY 25
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table safety_medical_retention_decision
(
    id            uuid not null,
    sequence      bigint not null,
    policy_id     uuid not null,
    actor_id      uuid not null,
    operation_id  uuid not null,
    action        varchar(16) not null,
    recorded_at   timestamptz not null,
    payload       jsonb not null,
    primary key (id),
    check (action in ('APPROVE', 'REVOKE')),
    -- action BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (policy_id) references safety_medical_retention_policy(id)
);

create table safety_medical_retention_policy
(
    id            uuid not null,
    branch_id     uuid not null,
    object_type   varchar(32) not null,
    version       varchar(128) not null,
    valid_from    timestamptz not null,
    valid_to      timestamptz not null,
    actor_id      uuid not null,
    operation_id  uuid not null,
    recorded_at   timestamptz not null,
    payload       jsonb not null,
    primary key (id),
    check ((valid_to > valid_from)),
    check (object_type in ('MEDICAL_INSPECTION', 'EMERGENCY_CASE', 'CLINICAL_READ_AUDIT')),
    -- object_type BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table safety_operational_permit
(
    id                       uuid not null,
    qualification_permit_id  uuid not null,
    target_type              varchar(24) not null,
    target_id                uuid not null,
    target_version           bigint not null,
    action                   varchar(24) not null,
    branch_id                uuid not null,
    actor_id                 uuid not null,
    proof_json               text not null,
    proof_hash               varchar(64) not null,
    recorded_at              timestamptz not null,
    primary key (id),
    foreign key (qualification_permit_id) references driver_qualification_permit(id)
);

create table safety_technical_inspection_revision
(
    id                          uuid not null,
    inspection_id               uuid not null,
    version                     bigint not null,
    action                      text not null,
    vehicle_id                  uuid not null,
    trailer_id                  uuid,
    driver_id                   uuid not null,
    branch_id                   uuid not null,
    trip_id                     uuid,
    waybill_id                  uuid,
    body                        jsonb not null,
    body_hash                   text not null,
    actor_id                    uuid not null,
    actor_name                  text not null,
    recorded_at                 timestamptz not null,
    reason                      text not null,
    medical_inspection_id       uuid,
    medical_inspection_version  bigint,
    primary key (id),
    check (action in ('CREATE', 'CORRECT', 'CANCEL', 'REINSPECT')),
    -- action BAZADA: CREATE 508, REINSPECT 2 | ISHLATILMAGAN: CORRECT, CANCEL
    check ((jsonb_typeof(body) = 'object')),
    check ((length(body_hash) = 64)),
    check (((medical_inspection_id is null) = (medical_inspection_version is null))),
    check (((length(btrim(reason)) >= 1) and (length(btrim(reason)) <= 1000))),
    check ((version > 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (driver_id) references driver(id),
    foreign key (medical_inspection_id) references medical_inspection(id),
    foreign key (trailer_id) references trailers(id),
    foreign key (trip_id) references trip(id),
    foreign key (vehicle_id) references transport_vehicle(id),
    foreign key (waybill_id) references waybill(id)
);

create table safety_technical_limited_event
(
    id                      uuid not null,
    inspection_revision_id  uuid not null,
    version                 bigint not null,
    action                  text not null,
    actor_id                uuid not null,
    actor_name              text not null,
    occurred_at             timestamptz not null,
    reason                  text not null,
    primary key (id),
    check (action in ('APPROVE', 'REVOKE')),
    -- action BAZADA: jadval bo'sh
    check (((length(btrim(reason)) >= 1) and (length(btrim(reason)) <= 1000))),
    check ((version > 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (inspection_revision_id) references safety_technical_inspection_revision(id)
);

create table safety_technical_operation
(
    id            uuid not null,
    actor_id      uuid not null,
    action        text not null,
    request_json  jsonb not null,
    result_json   jsonb not null,
    recorded_at   timestamptz not null,
    state         text not null,
    primary key (id),
    check (state in ('APPLIED', 'NOT_EXECUTED')),
    -- state BAZADA: APPLIED 506 | ISHLATILMAGAN: NOT_EXECUTED
    foreign key (actor_id) references app_user(id)
);

create table safety_technical_photo
(
    id            uuid not null,
    branch_id     uuid not null,
    name          text not null,
    content_type  text not null,
    size_bytes    bigint not null,
    sha256        text not null,
    authored_by   uuid not null,
    authored_at   timestamptz not null,
    reason        text not null,
    bytes         bytea not null,
    primary key (id),
    check ((size_bytes = octet_length(bytes))),
    check ((sha256 = encode(sha256(bytes), 'hex'))),
    check (content_type in ('image/png', 'image/jpeg')),
    -- content_type BAZADA: image/jpeg 338, image/png 2
    check (((length(name) >= 1) and (length(name) <= 256))),
    check (((length(btrim(reason)) >= 1) and (length(btrim(reason)) <= 1000))),
    check ((length(sha256) = 64)),
    check (((size_bytes >= 1) and (size_bytes <= 10485760))),
    foreign key (authored_by) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table safety_technical_policy
(
    id           uuid not null,
    branch_id    uuid not null,
    version      bigint not null,
    body         jsonb not null,
    body_hash    text not null,
    authored_by  uuid not null,
    authored_at  timestamptz not null,
    reason       text not null,
    primary key (id),
    check ((jsonb_typeof(body) = 'object')),
    check ((length(body_hash) = 64)),
    check (((length(btrim(reason)) >= 1) and (length(btrim(reason)) <= 1000))),
    check ((version > 0)),
    foreign key (authored_by) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table safety_technical_policy_event
(
    id           uuid not null,
    policy_id    uuid not null,
    version      bigint not null,
    action       text not null,
    actor_id     uuid not null,
    actor_name   text not null,
    occurred_at  timestamptz not null,
    reason       text not null,
    primary key (id),
    check (action in ('APPROVE', 'REVOKE')),
    -- action BAZADA: APPROVE 1 | ISHLATILMAGAN: REVOKE
    check (((length(btrim(reason)) >= 1) and (length(btrim(reason)) <= 1000))),
    check ((version > 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (policy_id) references safety_technical_policy(id)
);

create table safety_work_rest_calculation
(
    id             uuid not null,
    supersedes_id  uuid,
    branch_id      uuid not null,
    driver_id      uuid not null,
    actor_id       uuid not null,
    calculated_at  timestamptz not null,
    as_of          timestamptz not null,
    context        jsonb not null,
    result         jsonb not null,
    primary key (id),
    foreign key (actor_id) references app_user(id),
    foreign key (supersedes_id) references safety_work_rest_calculation(id)
);

create table safety_work_rest_coverage
(
    id            uuid not null,
    sequence      bigint not null,
    branch_id     uuid not null,
    driver_id     uuid not null,
    source_id     uuid not null,
    event_id      varchar(256) not null,
    from_at       timestamptz not null,
    to_at         timestamptz not null,
    state         varchar(24) not null,
    actor_id      uuid not null,
    operation_id  uuid not null,
    recorded_at   timestamptz not null,
    payload       jsonb not null,
    primary key (id),
    check ((to_at > from_at)),
    check (state in ('COMPLETE', 'PARTIAL', 'UNAVAILABLE')),
    -- state BAZADA: COMPLETE 5 | ISHLATILMAGAN: PARTIAL, UNAVAILABLE
    foreign key (actor_id) references app_user(id),
    foreign key (driver_id) references driver(id)
);

create table safety_work_rest_policy
(
    id            uuid not null,
    branch_id     uuid not null,
    jurisdiction  varchar(128) not null,
    route_id      uuid,
    version       varchar(128) not null,
    valid_from    timestamptz not null,
    valid_to      timestamptz not null,
    actor_id      uuid not null,
    operation_id  uuid not null,
    recorded_at   timestamptz not null,
    payload       jsonb not null,
    primary key (id),
    check ((valid_to > valid_from)),
    foreign key (actor_id) references app_user(id)
);

create table safety_work_rest_policy_decision
(
    id            uuid not null,
    sequence      bigint not null,
    policy_id     uuid not null,
    actor_id      uuid not null,
    operation_id  uuid not null,
    state         varchar(16) not null,
    recorded_at   timestamptz not null,
    payload       jsonb not null,
    primary key (id),
    check (state in ('APPROVED', 'REVOKED')),
    -- state BAZADA: APPROVED 2 | ISHLATILMAGAN: REVOKED
    foreign key (actor_id) references app_user(id),
    foreign key (policy_id) references safety_work_rest_policy(id)
);

create table safety_work_rest_segment
(
    id                uuid not null,
    original_id       uuid not null,
    correction_of     uuid,
    revision          bigint not null,
    branch_id         uuid not null,
    driver_id         uuid not null,
    vehicle_id        uuid,
    source_id         uuid not null,
    event_id          varchar(256) not null,
    started_at        timestamptz not null,
    ended_at          timestamptz not null,
    time_zone         varchar(128) not null,
    mode              varchar(24) not null,
    quality           varchar(24) not null,
    actor_id          uuid not null,
    operation_id      uuid not null,
    recorded_at       timestamptz not null,
    payload           jsonb not null,
    original_command  jsonb not null,
    reason            text not null,
    primary key (id),
    check ((ended_at > started_at)),
    check (mode in ('DRIVE', 'REST', 'OTHER_WORK', 'AVAILABILITY', 'UNKNOWN')),
    -- mode BAZADA: OTHER_WORK 5, REST 3 | ISHLATILMAGAN: DRIVE, AVAILABILITY, UNKNOWN
    check (quality in ('CONFIRMED', 'UNCONFIRMED', 'INVALID', 'VOID')),
    -- quality BAZADA: CONFIRMED 8 | ISHLATILMAGAN: UNCONFIRMED, INVALID, VOID
    check ((revision > 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (correction_of) references safety_work_rest_segment(id),
    foreign key (driver_id) references driver(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table safety_work_rest_source
(
    id            uuid not null,
    source_id     uuid not null,
    branch_id     uuid not null,
    revision      bigint not null,
    actor_id      uuid not null,
    operation_id  uuid not null,
    recorded_at   timestamptz not null,
    payload       jsonb not null,
    primary key (id),
    check ((revision > 0)),
    foreign key (actor_id) references app_user(id)
);

create table service_contract
(
    id             uuid not null,
    branch_id      uuid not null,
    created_at     timestamptz not null,
    currency       varchar(3) not null,
    customer_id    uuid not null,
    department_id  uuid,
    number         varchar(128) not null,
    status         varchar(16) not null,
    updated_at     timestamptz not null,
    updated_by     uuid not null,
    valid_from     date not null,
    valid_to       date,
    version        bigint not null,
    primary key (id),
    check (status in ('DRAFT', 'ACTIVE', 'INACTIVE')),
    -- status BAZADA: jadval bo'sh
    foreign key (branch_id) references reference_data(id),
    foreign key (customer_id) references customer(id),
    foreign key (department_id) references reference_data(id),
    foreign key (updated_by) references app_user(id)
);

create table service_settlement_act
(
    id                   uuid not null,
    approved_at          timestamptz,
    approved_by          uuid,
    branch_id            uuid not null,
    cancellation_reason  varchar(2000),
    cancelled_at         timestamptz,
    cancelled_by         uuid,
    contract_id          uuid not null,
    created_at           timestamptz not null,
    created_by           uuid not null,
    customer_id          uuid not null,
    department_id        uuid not null,
    period_from          date not null,
    period_to            date not null,
    snapshot_hash        varchar(64) not null,
    snapshot_json        text not null,
    status               varchar(16) not null,
    tariff_id            uuid not null,
    version              bigint not null,
    primary key (id),
    check (status in ('DRAFT', 'APPROVED', 'CANCELLED')),
    -- status BAZADA: jadval bo'sh
    foreign key (approved_by) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (cancelled_by) references app_user(id),
    foreign key (contract_id) references service_contract(id),
    foreign key (created_by) references app_user(id),
    foreign key (customer_id) references customer(id),
    foreign key (department_id) references reference_data(id),
    foreign key (tariff_id) references tariff(id)
);

create table service_settlement_act_event
(
    id             uuid not null,
    act_id         uuid not null,
    action         varchar(32) not null,
    actor_id       uuid not null,
    performed_at   timestamptz not null,
    reason         varchar(2000),
    snapshot_hash  varchar(64) not null,
    primary key (id),
    foreign key (act_id) references service_settlement_act(id),
    foreign key (actor_id) references app_user(id)
);

create table service_settlement_claim
(
    leg_id                uuid not null,
    accepted_leg_version  bigint not null,
    act_id                uuid not null,
    allocation_version    bigint not null,
    claimed_at            timestamptz not null,
    primary key (leg_id),
    foreign key (act_id) references service_settlement_act(id),
    foreign key (leg_id) references transport_execution_leg(id)
);

create table service_settlement_operation
(
    id            uuid not null,
    action        varchar(32) not null,
    actor_id      uuid not null,
    payload_hash  varchar(64) not null,
    performed_at  timestamptz not null,
    result_json   text not null,
    primary key (id),
    check (action in ('ALLOCATE', 'CREATE', 'APPROVE', 'CANCEL', 'CLOSE_CREATE', 'CLOSE_APPROVE', 'CLOSE_CANCEL')),
    -- action BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id)
);

create table service_settlement_trip_claim
(
    id           varchar(73) not null,
    act_id       uuid not null,
    contract_id  uuid not null,
    trip_id      uuid not null,
    primary key (id),
    foreign key (act_id) references service_settlement_act(id),
    foreign key (contract_id) references service_contract(id)
);

create table service_tariff_terms
(
    tariff_id      uuid not null,
    configured_at  timestamptz not null,
    configured_by  uuid not null,
    contract_id    uuid not null,
    money_scale    integer not null,
    rounding_mode  varchar(32) not null,
    version        bigint not null,
    primary key (tariff_id),
    check (rounding_mode in ('UP', 'DOWN', 'CEILING', 'FLOOR', 'HALF_UP', 'HALF_DOWN', 'HALF_EVEN', 'UNNECESSARY')),
    -- rounding_mode BAZADA: jadval bo'sh
    foreign key (configured_by) references app_user(id),
    foreign key (contract_id) references service_contract(id),
    foreign key (tariff_id) references tariff(id)
);

create table shipment
(
    id                       uuid not null,
    actual_delivery_at       timestamptz,
    actual_pickup_at         timestamptz,
    cargo_description        varchar(1000),
    cargo_volume_m3          numeric(12,2),
    cargo_weight_kg          numeric(12,2),
    created_at               timestamptz not null,
    created_by               uuid not null,
    currency                 varchar(8),
    customer_name            varchar(255),
    destination_address      varchar(500),
    destination_location_id  varchar(128),
    direction                varchar(32),
    hazard_profile_id        uuid,
    un_number                varchar(255),
    hazard_class             varchar(255),
    mode                     varchar(32),
    notes                    varchar(1000),
    origin_address           varchar(500),
    origin_warehouse_id      varchar(128),
    packages_count           integer,
    packaging_type           varchar(64),
    planned_freight_cost     numeric(14,2),
    product_code             varchar(128),
    ready_at                 timestamptz,
    requested_delivery_at    timestamptz,
    scheduled_delivery_at    timestamptz,
    scheduled_pickup_at      timestamptz,
    shipment_number          varchar(64) not null,
    status                   varchar(20) not null,
    supplier_name            varchar(256),
    updated_at               timestamptz,
    updated_by               uuid,
    weight_tons              numeric(12,3),
    customer_id              uuid,
    driver_id                uuid,
    trip_id                  uuid,
    vehicle_id               uuid,
    branch_id                uuid,
    provenance_known         boolean not null,
    source_origin            varchar(16),
    version                  bigint not null,
    primary key (id),
    check (status in ('PENDING', 'LOADING', 'PICKED_UP', 'IN_TRANSIT', 'DELIVERED', 'CANCELLED', 'RETURNED')),
    -- status BAZADA: PENDING 1 | ISHLATILMAGAN: LOADING, PICKED_UP, IN_TRANSIT, DELIVERED, CANCELLED, RETURNED
    foreign key (driver_id) references driver(id),
    foreign key (trip_id) references trip(id),
    foreign key (customer_id) references customer(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table shipment_command
(
    operation_id      uuid not null,
    action            varchar(16) not null,
    actor_id          uuid not null,
    payload_json      text not null,
    recorded_at       timestamptz not null,
    request_hash      varchar(64) not null,
    result_json       text not null,
    shipment_id       uuid not null,
    shipment_version  bigint not null,
    primary key (operation_id)
);

create table shipment_command_context
(
    shipment_id        uuid not null,
    tx_id              bigint not null,
    row_snapshot       jsonb not null,
    response_snapshot  jsonb not null,
    primary key (shipment_id)
);

create table shipment_document_template_review
(
    id                uuid not null,
    operation_id      uuid not null,
    template_id       uuid not null,
    template_version  integer not null,
    actor_id          uuid not null,
    reviewed_at       timestamptz not null,
    original_json     text not null,
    primary key (id)
);

create table shipment_graph_document
(
    id             uuid not null,
    shipment_id    uuid not null,
    leg_id         uuid not null,
    document_id    uuid not null,
    operation_id   uuid not null,
    result_json    text not null,
    original_json  text not null,
    actor_id       uuid not null,
    recorded_at    timestamptz not null,
    primary key (id),
    foreign key (shipment_id) references shipment(id)
);

create table shipment_graph_leg_revision
(
    id               uuid not null,
    shipment_id      uuid not null,
    leg_id           uuid not null,
    revision         bigint not null,
    sequence_number  integer not null,
    actor_id         uuid not null,
    recorded_at      timestamptz not null,
    result_json      text not null,
    primary key (id),
    check ((revision > 0)),
    check ((sequence_number > 0)),
    foreign key (shipment_id) references shipment(id)
);

create table shipment_graph_operation
(
    operation_id   uuid not null,
    shipment_id    uuid not null,
    actor_id       uuid not null,
    original_json  text not null,
    result_json    text not null,
    recorded_at    timestamptz not null,
    primary key (operation_id)
);

create table shipment_graph_trip_link
(
    leg_id          uuid not null,
    shipment_id     uuid not null,
    trip_id         uuid not null,
    application_id  uuid not null,
    operation_id    uuid not null,
    recorded_at     timestamptz not null,
    primary key (leg_id)
);

create table shipment_plan_context
(
    revision_id       uuid not null,
    shipment_id       uuid not null,
    tx_id             bigint not null,
    captured_version  bigint not null,
    parent_before     jsonb not null,
    parent_after      jsonb,
    primary key (revision_id)
);

create table shipment_plan_revision
(
    id                         uuid not null,
    actor_id                   uuid not null,
    captured_shipment_version  bigint not null,
    content_hash               varchar(64) not null,
    content_json               text not null,
    operation_id               uuid not null,
    previous_revision_id       uuid,
    reason                     varchar(1000) not null,
    recorded_at                timestamptz not null,
    revision                   bigint not null,
    shipment_id                uuid not null,
    primary key (id)
);

create table shipment_position_identity
(
    position_id        uuid not null,
    shipment_id        uuid not null,
    unit_code          varchar(32) not null,
    first_revision_id  uuid not null,
    primary key (position_id)
);

create table shipment_unit_definition
(
    id                      uuid not null,
    active                  boolean not null,
    actor_id                uuid not null,
    branch_id               uuid not null,
    label                   varchar(128) not null,
    operation_id            uuid not null,
    payload_json            text not null,
    previous_definition_id  uuid,
    recorded_at             timestamptz not null,
    request_hash            varchar(64) not null,
    review_reason           varchar(1000) not null,
    revision                bigint not null,
    unit_code               varchar(32) not null,
    primary key (id)
);

create table shuttle_command
(
    operation_id    uuid not null,
    template_id     uuid not null,
    actor_id        uuid not null,
    payload_hash    varchar(64) not null,
    original_json   text not null,
    state           varchar(16) not null,
    result_json     text,
    closure_reason  text,
    recorded_at     timestamptz not null,
    primary key (operation_id),
    check (((payload_hash) = encode(sha256(convert_to(original_json, 'utf8'::name)), 'hex'))),
    check (((((state) = 'applied') and (result_json is not null) and (closure_reason is null)) or (((state) = 'not_executed') and (result_json is null) and (length(btrim(closure_reason)) > 0)))),
    check (state in ('APPLIED', 'NOT_EXECUTED'))
    -- state BAZADA: APPLIED 2 | ISHLATILMAGAN: NOT_EXECUTED
);

create table shuttle_day_event
(
    id                    uuid not null,
    template_id           uuid not null,
    original_date         date not null,
    revision              bigint not null,
    template_revision_id  uuid not null,
    state                 varchar(32) not null,
    reason                text not null,
    actor_id              uuid not null,
    recorded_at           timestamptz not null,
    primary key (id),
    check (state in ('DEMAND_PENDING_REVIEW', 'GENERATED', 'EXCLUDED')),
    -- state BAZADA: jadval bo'sh
    foreign key (template_revision_id) references shuttle_template_revision(id)
);

create table shuttle_instance
(
    id                         uuid not null,
    template_id                uuid not null,
    original_date              date not null,
    template_revision_id       uuid not null,
    attempt                    integer not null,
    kind                       varchar(16) not null,
    group_operation_id         uuid not null,
    result_json                text not null,
    allocation_demand_json     text not null,
    stop_template_json         text not null,
    allocated_passengers_json  text not null,
    recorded_at                timestamptz not null,
    primary key (id),
    check ((attempt >= 0)),
    check (kind in ('MAIN', 'RESERVE')),
    -- kind BAZADA: jadval bo'sh
    foreign key (template_revision_id) references shuttle_template_revision(id)
);

create table shuttle_instance_mapping
(
    id                      uuid not null,
    instance_id             uuid not null,
    revision                bigint not null,
    actor_id                uuid not null,
    manifest_ids_json       text not null,
    allocation_demand_json  text not null,
    stop_template_json      text not null,
    reason                  text not null,
    recorded_at             timestamptz not null,
    primary key (id),
    check ((length(btrim(reason)) > 0)),
    check ((revision > 0)),
    foreign key (instance_id) references shuttle_instance(id)
);

create table shuttle_template_revision
(
    id             uuid not null,
    template_id    uuid not null,
    revision       bigint not null,
    branch_id      uuid not null,
    department_id  uuid not null,
    state          varchar(16) not null,
    author_id      uuid not null,
    reviewer_id    uuid,
    content_json   text not null,
    content_hash   varchar(64) not null,
    reason         text not null,
    recorded_at    timestamptz not null,
    primary key (id),
    check (((content_hash) = encode(sha256(convert_to(content_json, 'utf8'::name)), 'hex'))),
    check (((((state) = 'draft') and (reviewer_id is null)) or (((state) <> 'draft') and (reviewer_id is not null)))),
    check ((length(btrim(reason)) > 0)),
    check ((revision > 0)),
    check (state in ('DRAFT', 'APPROVED', 'REVOKED'))
    -- state BAZADA: DRAFT 2 | ISHLATILMAGAN: APPROVED, REVOKED
);

-- ---------------------------------------------------------------------
-- Tezlik oshirish buzilishlari: amaldagi tezlik (speed_kph), ruxsat etilgan chegara
-- (limit_kph) va oshib ketgan qiymat (excess_kph), koordinata, vaqt.
-- telematics_event_id — buzilish qaysi telematika hodisasidan aniqlangani.
-- fine_id to'ldirilgan bo'lsa — buzilish uchun jarima yozilgan.
-- ---------------------------------------------------------------------
create table speed_violation
(
    id                   uuid not null,
    created_at           timestamptz not null,
    driver_id            uuid,
    excess_kph           numeric(10,3) not null,
    fine_id              uuid,
    latitude             numeric(10,7) not null,
    limit_kph            numeric(10,3) not null,
    longitude            numeric(10,7) not null,
    occurred_at          timestamptz not null,
    speed_kph            numeric(10,3) not null,
    telematics_event_id  uuid not null,
    trip_id              uuid,
    vehicle_id           uuid not null,
    primary key (id)
);

create table tank
(
    id              uuid not null,
    capacity        numeric(12,2),
    created_at      timestamptz not null,
    current_volume  numeric(12,2),
    location_id     uuid,
    name            varchar(128) not null,
    status          varchar(32),
    updated_at      timestamptz,
    primary key (id)
    -- status BAZADA: jadval bo'sh
);

-- ---------------------------------------------------------------------
-- Tashish tariflari: narx modeli (PER_KM, PER_TON, PER_TON_KM, PER_TRIP, PER_HOUR),
-- summa, minimal to'lov, tungi va xavfli yuk uchun ustama foizlari, amal qilish
-- muddati. status: DRAFT, ACTIVE, ARCHIVED.
-- MIJOZ HISOB-KITOBIDA (customer_settlement_act) shu tarif qo'llanadi.
-- ---------------------------------------------------------------------
create table tariff
(
    id                        uuid not null,
    amount                    numeric(14,2) not null,
    cargo_category            varchar(64),
    created_at                timestamptz not null,
    currency                  varchar(8) not null,
    department_id             uuid,
    hazard_surcharge_percent  numeric(6,2),
    minimum_charge            numeric(14,2),
    name                      varchar(255) not null,
    night_surcharge_percent   numeric(6,2),
    notes                     varchar(2000),
    pricing_model             varchar(32) not null,
    status                    varchar(16) not null,
    updated_at                timestamptz not null,
    valid_from                date not null,
    valid_to                  date,
    vehicle_category          varchar(64),
    version                   bigint not null,
    primary key (id),
    check (pricing_model in ('PER_KM', 'PER_TON', 'PER_TON_KM', 'PER_TRIP', 'PER_HOUR')),
    -- pricing_model BAZADA: PER_TRIP 1 | ISHLATILMAGAN: PER_KM, PER_TON, PER_TON_KM, PER_HOUR
    check (status in ('DRAFT', 'ACTIVE', 'ARCHIVED'))
    -- status BAZADA: ACTIVE 1 | ISHLATILMAGAN: DRAFT, ARCHIVED
);

create table telegram_recipient
(
    id                 uuid not null,
    active             boolean not null,
    chat_id            bigint not null,
    full_name          varchar(256),
    linked_at          timestamptz not null,
    phone              varchar(32) not null,
    telegram_username  varchar(128),
    updated_at         timestamptz not null,
    primary key (id)
);

-- ---------------------------------------------------------------------
-- TELEMATIKA HODISALARI BO'YICHA ASOSIY JADVAL — GPS VA BORT MA'LUMOTLARI SHU
-- JADVALDAN OLINADI. Koordinata, tezlik (speed_kph), yo'nalish (heading),
-- probeg (odometer_km), yoqilg'i sathi (fuel_level), dvigatel holati (engine_on),
-- qurilma id va hodisa vaqti (timestamp).
-- Bu jadval juda katta bo'ladi — HAR DOIM vehicle_id VA VAQT ORALIG'I BO'YICHA
-- FILTRLANADI. Mashinaning oxirgi holati uchun vehicle_telemetry_state ishlatiladi
-- (bu jadvalni skanerlash shart emas).
-- ---------------------------------------------------------------------
create table telematics_event
(
    id               uuid not null,
    created_at       timestamptz not null,
    device_id        varchar(128) not null,
    engine_on        boolean not null,
    fingerprint      varchar(64) not null,
    fuel_level       numeric(10,3),
    heading          numeric(10,3) not null,
    latitude         numeric(10,7) not null,
    longitude        numeric(10,7) not null,
    odometer_km      numeric(14,3) not null,
    speed_kph        numeric(10,3) not null,
    timestamp        timestamptz not null,
    vehicle_id       uuid not null,
    binding_id       uuid,
    binding_version  bigint,
    branch_id        uuid,
    recorded_by_id   uuid,
    source_state     varchar(64),
    primary key (id)
);

-- ---------------------------------------------------------------------
-- Geozonalar: depo, obyekt, nazorat nuqtasi, taqiqlangan zona. Markaz koordinatasi
-- va radius (radius_meters) bilan belgilanadi.
-- GEOZONADAN CHIQISH hodisasi incident jadvalida GEOFENCE_VIOLATION sifatida.
-- ---------------------------------------------------------------------
create table telematics_geozone
(
    id             uuid not null,
    active         boolean not null,
    created_at     timestamptz not null,
    description    varchar(1000),
    latitude       numeric(10,7) not null,
    longitude      numeric(10,7) not null,
    name           varchar(255) not null,
    radius_meters  numeric(10,2) not null,
    type           varchar(32) not null,
    updated_at     timestamptz not null,
    primary key (id),
    check (type in ('DEPOT', 'OBJECT', 'CHECKPOINT', 'RESTRICTED'))
    -- type BAZADA: jadval bo'sh
);

create table temporary_paper_backfill_rows
(
    id                        uuid not null,
    application_id            uuid,
    branch_id                 uuid,
    business_date             date not null,
    created_at                timestamptz not null,
    departure_time            varchar(16),
    fuel_at_departure_liters  numeric(10,2),
    fuel_at_return_liters     numeric(10,2),
    fuel_consumed_liters      numeric(10,2),
    last_error_code           varchar(64),
    last_error_message        text,
    manual_driver_override    boolean not null,
    manual_vehicle_override   boolean not null,
    medical_inspection_id     uuid,
    odometer_end_km           bigint,
    odometer_start_km         bigint,
    paper_waybill_number      varchar(64),
    processed_at              timestamptz,
    processed_by              varchar(256),
    resolved_driver_id        uuid,
    resolved_vehicle_id       uuid,
    return_time               varchar(16),
    route_id                  uuid,
    row_index                 integer,
    row_key                   varchar(64) not null,
    source_driver_name        varchar(256),
    source_vehicle_plate      varchar(64),
    status                    varchar(32) not null,
    synthetic_medical         boolean not null,
    synthetic_technical       boolean not null,
    technical_inspection_id   uuid,
    trip_id                   uuid,
    updated_at                timestamptz not null,
    version                   bigint,
    waybill_id                uuid,
    primary key (id),
    check (status in ('NEW', 'NEEDS_DRIVER', 'NEEDS_VEHICLE', 'NEEDS_MEDICAL', 'NEEDS_TECHNICAL', 'READY', 'COMPLETED', 'FAILED'))
    -- status BAZADA: COMPLETED 40, NEEDS_DRIVER 31, READY 7 | ISHLATILMAGAN: NEW, NEEDS_VEHICLE, NEEDS_MEDICAL, NEEDS_TECHNICAL, FAILED
);

-- ---------------------------------------------------------------------
-- TOIR (texnik xizmat va ta'mirlash) tizimidan kelgan uskuna holati xabarlari.
-- Mashinaning tashqi tizimdagi holati shu yerga tushadi.
-- ---------------------------------------------------------------------
create table toir_equipment_status_receipt
(
    event_id         uuid not null,
    equipment_id     uuid not null,
    received_at      timestamptz not null,
    source_revision  bigint not null,
    source_status    varchar(32) not null,
    status           varchar(20) not null,
    vehicle_id       uuid not null,
    primary key (event_id)
    -- status BAZADA: jadval bo'sh
);

-- ---------------------------------------------------------------------
-- Mashina ma'lumotini TOIR tizimiga yuborish navbati (outbox). Ishlash tartibi
-- erp_trip_outbox bilan bir xil.
-- ---------------------------------------------------------------------
create table toir_vehicle_outbox
(
    id               uuid not null,
    attempt_count    integer not null,
    created_at       timestamptz not null,
    dispatched_at    timestamptz,
    last_error       varchar(1000),
    next_attempt_at  timestamptz not null,
    payload_json     text not null,
    status           varchar(16) not null,
    vehicle_id       uuid not null,
    primary key (id)
    -- status BAZADA: jadval bo'sh
);

create table trailer_combination_norm
(
    id                   uuid not null,
    created_at           timestamptz not null,
    fuel_norm_liters     numeric(8,2) not null,
    fuel_type            varchar(32),
    notes                varchar(255),
    tractor_model_group  varchar(64) not null,
    trailer_model_group  varchar(64) not null,
    updated_at           timestamptz not null,
    updated_by           varchar(128),
    primary key (id)
);

create table trailers
(
    id            uuid not null,
    plate_number  varchar(32) not null,
    model         varchar(64) not null,
    trailer_type  varchar(32) not null,
    weight_tons   numeric(5,2) not null,
    is_active     boolean,
    created_at    timestamptz,
    primary key (id)
);

create table transport_ai_source_provenance
(
    operation_id    uuid not null,
    source_type     text not null,
    source_id       uuid not null,
    actor_id        uuid not null,
    draft_id        uuid not null,
    draft_revision  bigint not null,
    draft_kind      text not null,
    field_hash      text not null,
    recorded_at     timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (draft_id) references ai_extraction_draft(draft_id)
);

create table transport_assignment_change_outbox
(
    id           uuid not null,
    trip_id      uuid not null,
    event_json   jsonb not null,
    recorded_at  timestamptz not null,
    primary key (id),
    foreign key (id) references transport_assignment_event(id)
);

create table transport_assignment_command
(
    operation_id    uuid not null,
    trip_id         uuid not null,
    actor_id        uuid not null,
    action          text not null,
    payload_hash    text not null,
    original_json   text not null,
    outcome         text not null,
    result_json     text,
    closure_reason  text,
    recorded_at     timestamptz not null,
    primary key (operation_id),
    check ((((outcome = 'applied') and (result_json is not null) and (closure_reason is null)) or ((outcome = 'not_executed') and (result_json is null) and ((length(btrim(closure_reason)) >= 1) and (length(btrim(closure_reason)) <= 2000))))),
    check (outcome in ('APPLIED', 'NOT_EXECUTED')),
    -- outcome BAZADA: APPLIED 361, NOT_EXECUTED 2
    check ((payload_hash ~ '^[a-f0-9]{64}$')),
    foreign key (actor_id) references app_user(id),
    foreign key (trip_id) references trip(id)
);

create table transport_assignment_event
(
    id                 uuid not null,
    trip_id            uuid not null,
    operation_id       uuid,
    action             text not null,
    actor_id           uuid,
    effective_at       timestamptz not null,
    previous_version   bigint,
    resulting_version  bigint not null,
    before_json        jsonb,
    after_json         jsonb not null,
    provenance         text not null,
    recorded_at        timestamptz not null,
    primary key (id),
    check (provenance in ('CURRENT_COMMAND', 'INITIAL', 'LEGACY_CAPTURE', 'UNSCOPED_MUTATION')),
    -- provenance BAZADA: LEGACY_CAPTURE 2561, INITIAL 1534, CURRENT_COMMAND 451, UNSCOPED_MUTATION 287
    foreign key (actor_id) references app_user(id),
    foreign key (trip_id) references trip(id)
);

create table transport_assignment_graph_event
(
    operation_id  uuid not null,
    trip_id       uuid not null,
    actor_id      uuid not null,
    before_json   jsonb not null,
    after_json    jsonb not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (trip_id) references trip(id)
);

create table transport_cost_allocation_command
(
    id              uuid not null,
    actor_id        uuid not null,
    branch_id       uuid not null,
    closure_reason  varchar(2000),
    original_json   text not null,
    payload_hash    varchar(64) not null,
    record_id       uuid,
    recorded_at     timestamptz not null,
    state           varchar(16) not null,
    primary key (id),
    foreign key (record_id) references transport_cost_allocation_record(id) deferrable initially deferred
);

create table transport_cost_allocation_head
(
    id                 uuid not null,
    current_record_id  uuid,
    revision           bigint not null,
    version            bigint not null,
    primary key (id),
    foreign key (current_record_id) references transport_cost_allocation_record(id) deferrable initially deferred,
    foreign key (id) references transport_cost_head(id)
);

create table transport_cost_allocation_record
(
    id                           uuid not null,
    basis_hash                   varchar(64) not null,
    basis_json                   text not null,
    branch_id                    uuid not null,
    cost_head_version            bigint not null,
    entry_id                     uuid not null,
    expected_allocation_version  bigint not null,
    head_id                      uuid not null,
    operation_id                 uuid not null,
    posted_at                    timestamptz not null,
    posted_by                    uuid not null,
    preview_hash                 varchar(64) not null,
    preview_json                 text not null,
    reason                       varchar(2000) not null,
    revision                     bigint not null,
    rule_head_version            bigint not null,
    rule_id                      uuid not null,
    primary key (id),
    foreign key (operation_id) references transport_cost_allocation_command(id) deferrable initially deferred,
    foreign key (entry_id) references transport_cost_entry(id),
    foreign key (head_id) references transport_cost_allocation_head(id) deferrable initially deferred,
    foreign key (rule_id) references transport_cost_rule_head(id)
);

create table transport_cost_command
(
    id              uuid not null,
    action          varchar(24) not null,
    actor_id        uuid not null,
    branch_id       uuid not null,
    closure_reason  varchar(2000),
    original_json   text not null,
    payload_hash    varchar(64) not null,
    recorded_at     timestamptz not null,
    result_hash     varchar(64),
    result_json     text,
    state           varchar(24) not null,
    primary key (id)
);

create table transport_cost_entry
(
    id                          uuid not null,
    amount                      numeric(38,6) not null,
    base_unit                   varchar(32) not null,
    branch_id                   uuid not null,
    confirmed_at                timestamptz not null,
    correction_reason           varchar(2000),
    currency                    varchar(3) not null,
    department_id               uuid,
    document_id                 varchar(200) not null,
    document_line_id            varchar(200) not null,
    document_revision           bigint not null,
    economic_hash               varchar(64) not null,
    entry_type                  varchar(16) not null,
    expected_previous_revision  bigint not null,
    head_id                     uuid not null,
    interval_end                timestamptz not null,
    interval_start              timestamptz not null,
    money_scale                 integer not null,
    occurred_at                 timestamptz not null,
    origin_receipt_id           uuid not null,
    owner                       varchar(16) not null,
    owner_epoch                 bigint not null,
    previous_entry_id           uuid,
    provider                    varchar(64) not null,
    quantity                    numeric(24,6) not null,
    recorded_at                 timestamptz not null,
    repair_id                   uuid,
    reverses_entry_id           uuid,
    source_domain               varchar(40) not null,
    source_id                   uuid not null,
    source_proof_hash           varchar(64) not null,
    source_proof_json           text not null,
    source_revision             bigint not null,
    task_id                     uuid,
    valuation_json              text not null,
    valuation_revision          bigint not null,
    vehicle_id                  uuid not null,
    primary key (id),
    check (entry_type in ('VALUATION', 'REVERSAL')),
    -- entry_type BAZADA: jadval bo'sh
    check (owner in ('UNCONFIGURED', 'SAP', 'ONE_C')),
    -- owner BAZADA: jadval bo'sh
    foreign key (head_id) references transport_cost_head(id) deferrable initially deferred,
    foreign key (previous_entry_id) references transport_cost_entry(id) deferrable initially deferred,
    foreign key (origin_receipt_id) references transport_cost_receipt(id) deferrable initially deferred,
    foreign key (reverses_entry_id) references transport_cost_entry(id) deferrable initially deferred
);

create table transport_cost_head
(
    id                          uuid not null,
    branch_id                   uuid not null,
    current_entry_id            uuid,
    current_valuation_revision  bigint not null,
    source_domain               varchar(40) not null,
    source_id                   uuid not null,
    vehicle_id                  uuid not null,
    version                     bigint not null,
    primary key (id),
    foreign key (current_entry_id) references transport_cost_entry(id) deferrable initially deferred
);

create table transport_cost_receipt
(
    id            uuid not null,
    entry_id      uuid not null,
    owner         varchar(16) not null,
    owner_epoch   bigint not null,
    payload_hash  varchar(64) not null,
    provider      varchar(64) not null,
    recorded_at   timestamptz not null,
    primary key (id),
    check (owner in ('UNCONFIGURED', 'SAP', 'ONE_C')),
    -- owner BAZADA: jadval bo'sh
    foreign key (entry_id) references transport_cost_entry(id) deferrable initially deferred
);

create table transport_cost_rule_approval
(
    id                uuid not null,
    approved_at       timestamptz not null,
    approved_by       uuid not null,
    draft_id          uuid not null,
    expected_version  bigint not null,
    operation_id      uuid not null,
    reason            varchar(2000) not null,
    reviewed_hash     varchar(64) not null,
    rule_id           uuid not null,
    primary key (id),
    foreign key (draft_id) references transport_cost_rule_draft(id) deferrable initially deferred,
    foreign key (operation_id) references transport_cost_command(id) deferrable initially deferred,
    foreign key (rule_id) references transport_cost_rule_head(id) deferrable initially deferred
);

create table transport_cost_rule_draft
(
    id                uuid not null,
    created_at        timestamptz not null,
    created_by        uuid not null,
    expected_version  bigint,
    operation_id      uuid not null,
    reason            varchar(2000) not null,
    revision          bigint not null,
    rule_id           uuid not null,
    snapshot_hash     varchar(64) not null,
    terms_json        text not null,
    primary key (id),
    foreign key (operation_id) references transport_cost_command(id) deferrable initially deferred,
    foreign key (rule_id) references transport_cost_rule_head(id) deferrable initially deferred
);

create table transport_cost_rule_head
(
    id                   uuid not null,
    branch_id            uuid not null,
    current_approval_id  uuid,
    current_draft_id     uuid,
    draft_revision       bigint not null,
    version              bigint not null,
    primary key (id),
    foreign key (current_approval_id) references transport_cost_rule_approval(id) deferrable initially deferred,
    foreign key (current_draft_id) references transport_cost_rule_draft(id) deferrable initially deferred
);

create table transport_demand_operation_assignment
(
    id                   uuid not null,
    trip_id              uuid not null,
    demand_revision_id   uuid not null,
    revision             bigint not null,
    command_id           uuid not null,
    planning_command_id  uuid,
    load_command_id      uuid,
    admission_json       jsonb not null,
    actor_id             uuid not null,
    recorded_at          timestamptz not null,
    primary key (id),
    check (((num_nonnulls(planning_command_id, load_command_id) = 1) and (coalesce(planning_command_id, load_command_id) = command_id))),
    check ((revision > 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (demand_revision_id) references transport_requirement_operation_revision(id),
    foreign key (load_command_id) references transport_load_command(operation_id) deferrable initially deferred,
    foreign key (planning_command_id) references transport_planning_operation(id) deferrable initially deferred,
    foreign key (trip_id) references trip(id) deferrable initially deferred
);

create table transport_demand_operation_authority
(
    id             uuid not null,
    command_id     uuid not null,
    subject_id     uuid not null,
    revision       bigint not null,
    kind           text not null,
    branch_id      uuid not null,
    original_json  jsonb not null,
    body_hash      text not null,
    author_id      uuid not null,
    recorded_at    timestamptz not null,
    primary key (id),
    check ((body_hash ~ '^[a-f0-9]{64}$')),
    check (kind in ('DEFINITION', 'CAPABILITY', 'QUALIFICATION')),
    -- kind BAZADA: jadval bo'sh
    check ((revision > 0)),
    foreign key (author_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (command_id) references transport_demand_operation_command(id) deferrable initially deferred
);

create table transport_demand_operation_command
(
    id             uuid not null,
    actor_id       uuid not null,
    branch_id      uuid not null,
    action         text not null,
    original_json  jsonb not null,
    payload_hash   text not null,
    state          text not null,
    result_json    jsonb,
    reason         text,
    recorded_at    timestamptz not null,
    primary key (id),
    check ((((state = 'applied') and (result_json is not null)) or ((state = 'not_executed') and (length(btrim(reason)) > 0)))),
    check ((payload_hash ~ '^[a-f0-9]{64}$')),
    check (state in ('APPLIED', 'NOT_EXECUTED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table transport_demand_operation_decision
(
    id                      uuid not null,
    command_id              uuid not null,
    leg_id                  uuid not null,
    leg_version             bigint not null,
    source_revision_id      uuid not null,
    source_hash             text not null,
    measured_quantity       numeric(18,6) not null,
    accepted_quantity       numeric(18,6) not null,
    clarification_quantity  numeric(18,6) not null,
    state                   text not null,
    actor_id                uuid not null,
    reason                  text not null,
    recorded_at             timestamptz not null,
    primary key (id),
    check ((clarification_quantity >= (0))),
    check ((accepted_quantity >= (0))),
    check (((accepted_quantity + clarification_quantity) = measured_quantity)),
    check ((leg_version >= 0)),
    check ((measured_quantity > (0))),
    check ((source_hash ~ '^[a-f0-9]{64}$')),
    check (state in ('ACCEPTED', 'REVERSED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (leg_id) references transport_demand_operation_leg(leg_id),
    foreign key (command_id) references transport_execution_command(operation_id) deferrable initially deferred,
    foreign key (source_revision_id) references transport_execution_source_revision(id)
);

create table transport_demand_operation_document
(
    id            uuid not null,
    command_id    uuid not null,
    branch_id     uuid not null,
    kind          text not null,
    object_id     uuid not null,
    file_name     text not null,
    content_type  text not null,
    size_bytes    bigint not null,
    storage_key   text not null,
    sha256        text not null,
    actor_id      uuid not null,
    recorded_at   timestamptz not null,
    primary key (id),
    check (kind in ('LOAD_CHART', 'OPERATOR_CERTIFICATE', 'EQUIPMENT_CAPABILITY')),
    -- kind BAZADA: jadval bo'sh
    check ((sha256 ~ '^[a-f0-9]{64}$')),
    check (((size_bytes > 0) and (size_bytes <= 10485760))),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (command_id) references transport_demand_operation_command(id) deferrable initially deferred
);

create table transport_demand_operation_leg
(
    leg_id               uuid not null,
    command_id           uuid not null,
    demand_revision_id   uuid not null,
    source_id            uuid not null,
    waybill_id           uuid not null,
    start_id             uuid not null,
    physical_source_key  text not null,
    actual_quantity      numeric(18,6) not null,
    unit_code            text not null,
    recorded_by          uuid not null,
    recorded_at          timestamptz not null,
    primary key (leg_id),
    check ((actual_quantity > (0))),
    foreign key (start_id) references transport_demand_operation_start(id),
    foreign key (demand_revision_id) references transport_requirement_operation_revision(id),
    foreign key (leg_id) references transport_execution_leg(id) deferrable initially deferred,
    foreign key (command_id) references transport_execution_command(operation_id) deferrable initially deferred,
    foreign key (recorded_by) references app_user(id),
    foreign key (waybill_id) references waybill(id)
);

create table transport_demand_operation_review
(
    id                   uuid not null,
    command_id           uuid not null,
    authority_id         uuid not null,
    review_version       bigint not null,
    action               text not null,
    actor_id             uuid not null,
    reason               text not null,
    authority_reference  text not null,
    recorded_at          timestamptz not null,
    primary key (id),
    check (action in ('APPROVE', 'REVOKE')),
    -- action BAZADA: jadval bo'sh
    check ((length(btrim(authority_reference)) > 0)),
    check ((length(btrim(reason)) > 0)),
    check ((review_version > 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (authority_id) references transport_demand_operation_authority(id),
    foreign key (command_id) references transport_demand_operation_command(id) deferrable initially deferred
);

create table transport_demand_operation_start
(
    id                 uuid not null,
    trip_id            uuid not null,
    permit_id          uuid not null,
    assignment_id      uuid not null,
    manifest_id        uuid not null,
    manifest_revision  boolean not null,
    manifest_hash      text not null,
    recorded_at        timestamptz not null,
    primary key (id),
    check ((manifest_hash ~ '^[a-f0-9]{64}$')),
    foreign key (assignment_id) references transport_demand_operation_assignment(id),
    foreign key (permit_id) references safety_operational_permit(id),
    foreign key (trip_id) references trip(id)
);

-- ---------------------------------------------------------------------
-- TRANSPORT HUJJATLARI BO'YICHA ASOSIY JADVAL — YO'L VARAQASI, TTN, MARSHRUT
-- VARAQASI, TRANSPORT AKTI VA YETKAZISH TASDIG'I SHU JADVALDAN OLINADI.
-- Hujjat raqami (document_number), turi (document_type), shabloni, holati
-- (GENERATED, UPDATED, CONFIRMED, SIGNING_PENDING, SIGNED, ARCHIVED, CANCELLED),
-- imzo talab qilinishi (signature_required) va imzo ma'lumotlari.
-- Reys, mashina, haydovchi va so'rovga bog'lanadi. Versiyalari document_version,
-- tarixi document_audit jadvalida.
-- ---------------------------------------------------------------------
create table transport_document
(
    id                       uuid not null,
    created_at               timestamptz not null,
    created_by               varchar(128) not null,
    document_number          varchar(64) not null,
    document_type            varchar(64) not null,
    driver_id                uuid,
    request_id               uuid,
    signature_data           varchar(20000),
    signature_document_hash  varchar(128),
    signature_required       boolean not null,
    signature_serial_number  varchar(128),
    signature_subject        varchar(255),
    signed_at                timestamptz,
    signed_by                varchar(128),
    signing_provider         varchar(32),
    status                   varchar(32) not null,
    template_code            varchar(64) not null,
    template_id              uuid not null,
    template_version         integer not null,
    trip_id                  uuid,
    updated_at               timestamptz not null,
    updated_by               varchar(128) not null,
    vehicle_id               uuid,
    primary key (id),
    check (document_type in ('WAYBILL', 'TTN', 'ROUTE_SHEET', 'TRANSPORT_ACT', 'DELIVERY_CONFIRMATION', 'WEIGHING_ACT')),
    -- document_type BAZADA: jadval bo'sh
    check (status in ('GENERATED', 'UPDATED', 'CONFIRMED', 'SIGNING_PENDING', 'SIGNED', 'ARCHIVED', 'CANCELLED'))
    -- status BAZADA: jadval bo'sh
);

create table transport_execution_command
(
    operation_id   uuid not null,
    request_id     uuid not null,
    actor_id       uuid not null,
    action         varchar(32) not null,
    leg_id         uuid,
    payload_hash   varchar(64) not null,
    original_json  text not null,
    outcome        varchar(16) not null,
    result_json    text,
    reason         text,
    recorded_at    timestamptz not null,
    primary key (operation_id),
    check (((payload_hash) = encode(sha256(convert_to(original_json, 'utf8'::name)), 'hex'))),
    check (((((outcome) = 'applied') and (result_json is not null) and (reason is null)) or (((outcome) = 'not_executed') and (result_json is null) and (length(btrim(reason)) > 0)))),
    check (outcome in ('APPLIED', 'NOT_EXECUTED')),
    -- outcome BAZADA: APPLIED 6, NOT_EXECUTED 1
    foreign key (actor_id) references app_user(id),
    foreign key (request_id) references transport_request(id)
);

create table transport_execution_discrepancy
(
    id                  uuid not null,
    request_id          uuid not null,
    trip_id             uuid not null,
    source_revision_id  uuid not null,
    fingerprint         varchar(64) not null,
    decision            varchar(64) not null,
    explanation         text not null,
    document_uri        text not null,
    actor_id            uuid not null,
    recorded_at         timestamptz not null,
    primary key (id),
    check (((length(btrim(explanation)) > 0) and (length(btrim(document_uri)) > 0))),
    check (decision in ('EXPLAINED_NON_TASK_DISTANCE', 'MEASUREMENT_REVIEW_REQUIRED', 'LEG_CORRECTION_REQUIRED')),
    -- decision BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (request_id) references transport_request(id),
    foreign key (source_revision_id) references transport_execution_source_revision(id),
    foreign key (trip_id) references trip(id)
);

create table transport_execution_leg
(
    id                           uuid not null,
    accepted_distance_km         numeric(14,3),
    accepted_engine_hours        numeric(14,3),
    accepted_operation_quantity  numeric(14,3),
    accepted_weight_tons         numeric(14,3),
    assignment_segment_id        uuid,
    coverage_branch_id           uuid,
    coverage_end                 timestamp not null,
    coverage_end_instant         timestamptz,
    coverage_end_local           varchar(64),
    coverage_policy_id           uuid,
    coverage_policy_version      bigint,
    coverage_start               timestamp not null,
    coverage_start_instant       timestamptz,
    coverage_start_local         varchar(64),
    coverage_time_reason         varchar(64),
    coverage_time_zone           varchar(64),
    decided_at                   timestamptz,
    decided_by                   uuid,
    decision_comment             varchar(2000),
    destination                  varchar(255),
    distance_km                  numeric(14,3),
    engine_hours                 numeric(14,3),
    idle_hours                   numeric(14,3),
    measurement_event_at         timestamptz,
    measurement_source           varchar(1000) not null,
    operation_quantity           numeric(14,3),
    origin                       varchar(255),
    request_id                   uuid not null,
    requirement_id               uuid not null,
    source_hash                  varchar(64),
    source_revision              bigint,
    source_revision_id           uuid,
    source_state                 varchar(32),
    status                       varchar(16) not null,
    submitted_at                 timestamptz not null,
    submitted_by                 uuid not null,
    transport_type               varchar(32) not null,
    trip_id                      uuid not null,
    unit_code                    varchar(64),
    vehicle_id                   uuid not null,
    version                      bigint not null,
    weight_tons                  numeric(14,3),
    work_hours                   numeric(14,3),
    work_operation_id            uuid,
    worksite_id                  uuid,
    primary key (id),
    check (status in ('SUBMITTED', 'ACCEPTED', 'REJECTED')),
    -- status BAZADA: REJECTED 1, ACCEPTED 1 | ISHLATILMAGAN: SUBMITTED
    check (transport_type in ('MOBILE_CRANE', 'AERIAL_PLATFORM', 'TRACTOR', 'WATER_TRUCK', 'EXCAVATOR', 'FRONT_LOADER', 'DUMP_TRUCK', 'LONG_LOAD_TRUCK', 'FLATBED', 'MANIPULATOR', 'PASSENGER_CAR', 'BUS', 'VAN', 'BULLDOZER', 'CONCRETE_PUMP', 'CONCRETE_MIXER', 'FIRE_TRUCK', 'AMBULANCE', 'TRUCK', 'TANKER', 'REFRIGERATED', 'SPECIALIZED', 'MINIBUS', 'PICKUP', 'TRAILER', 'OTHER', 'ELECTRIC_VEHICLE'))
    -- transport_type BAZADA: PASSENGER_CAR 2 | ISHLATILMAGAN: MOBILE_CRANE, AERIAL_PLATFORM, TRACTOR, WATER_TRUCK, EXCAVATOR, FRONT_LOADER, DUMP_TRUCK, LONG_LOAD_TRUCK va yana 18 ta
);

create table transport_execution_operation
(
    id            uuid not null,
    actor_id      uuid not null,
    leg_id        uuid not null,
    operation_id  uuid not null,
    payload_hash  varchar(64) not null,
    performed_at  timestamptz not null,
    request_id    uuid not null,
    primary key (id)
);

create table transport_execution_recalculation
(
    id            uuid not null,
    request_id    uuid not null,
    leg_id        uuid not null,
    leg_version   bigint not null,
    source_hash   varchar(64),
    content_json  text not null,
    recorded_at   timestamptz not null,
    primary key (id),
    foreign key (leg_id) references transport_execution_leg(id),
    foreign key (request_id) references transport_request(id)
);

create table transport_execution_revision
(
    id                 uuid not null,
    leg_id             uuid not null,
    request_id         uuid not null,
    previous_version   bigint not null,
    resulting_version  bigint not null,
    action             varchar(32) not null,
    actor_id           uuid not null,
    before_json        text not null,
    after_json         text not null,
    reason             text not null,
    document_uri       text not null,
    recorded_at        timestamptz not null,
    primary key (id),
    check (action in ('CORRECT', 'REVERSE', 'SOURCE_INVALIDATED')),
    -- action BAZADA: jadval bo'sh
    check ((resulting_version = (previous_version + 1))),
    check (((length(btrim(reason)) > 0) and (length(btrim(document_uri)) > 0))),
    foreign key (actor_id) references app_user(id),
    foreign key (leg_id) references transport_execution_leg(id),
    foreign key (request_id) references transport_request(id)
);

create table transport_execution_source_revision
(
    id            uuid not null,
    source_id     uuid not null,
    revision      bigint not null,
    request_id    uuid not null,
    trip_id       uuid not null,
    kind          varchar(32) not null,
    state         varchar(16) not null,
    source_hash   varchar(64) not null,
    content_json  text not null,
    author_id     uuid not null,
    reviewer_id   uuid,
    reason        text not null,
    recorded_at   timestamptz not null,
    primary key (id),
    check (((((state) = 'draft') and (reviewer_id is null)) or (((state) <> 'draft') and (reviewer_id is not null)))),
    check (kind in ('LOCAL_DOCUMENT', 'PRODUCTION_ACCEPTANCE', 'EXTERNAL_PROVIDER')),
    -- kind BAZADA: LOCAL_DOCUMENT 2 | ISHLATILMAGAN: PRODUCTION_ACCEPTANCE, EXTERNAL_PROVIDER
    check ((revision > 0)),
    check (state in ('DRAFT', 'APPROVED', 'REVOKED')),
    -- state BAZADA: DRAFT 1, APPROVED 1 | ISHLATILMAGAN: REVOKED
    foreign key (author_id) references app_user(id),
    foreign key (request_id) references transport_request(id),
    foreign key (reviewer_id) references app_user(id),
    foreign key (trip_id) references trip(id)
);

create table transport_governance_closed
(
    id             uuid not null,
    actor_id       uuid not null,
    branch_id      uuid,
    action         text not null,
    payload_hash   text not null,
    original_json  jsonb not null,
    reason         text not null,
    recorded_at    timestamptz not null,
    primary key (id),
    check ((payload_hash ~ '^[a-f0-9]{64}$')),
    check (((length(btrim(reason)) >= 1) and (length(btrim(reason)) <= 2000))),
    foreign key (actor_id) references app_user(id)
);

create table transport_governance_decision
(
    id             uuid not null,
    revision_id    uuid not null,
    actor_id       uuid not null,
    action         text not null,
    original_json  jsonb not null,
    recorded_at    timestamptz not null,
    primary key (id),
    check (action in ('APPROVE', 'REVOKE')),
    -- action BAZADA: APPROVE 1 | ISHLATILMAGAN: REVOKE
    foreign key (actor_id) references app_user(id),
    foreign key (revision_id) references transport_governance_policy(id)
);

create table transport_governance_policy
(
    id             uuid not null,
    branch_id      uuid,
    kind           text not null,
    version        bigint not null,
    valid_from     timestamptz not null,
    valid_until    timestamptz,
    policy_json    jsonb not null,
    source_hash    text not null,
    author_id      uuid not null,
    original_json  jsonb not null,
    recorded_at    timestamptz not null,
    primary key (id),
    check (((branch_id is not null) or (kind = 'request_fields'))),
    check (((valid_until is null) or (valid_until > valid_from))),
    check (kind in ('REQUEST_FIELDS', 'FLEET_RESOURCES', 'ANOMALY_CLOSE')),
    -- kind BAZADA: REQUEST_FIELDS 1 | ISHLATILMAGAN: FLEET_RESOURCES, ANOMALY_CLOSE
    check ((source_hash ~ '^[a-f0-9]{64}$')),
    check ((version > 0)),
    foreign key (author_id) references app_user(id)
);

create table transport_governance_receipt
(
    id             uuid not null,
    actor_id       uuid not null,
    branch_id      uuid,
    action         text not null,
    payload_hash   text not null,
    original_json  jsonb not null,
    result_json    jsonb not null,
    recorded_at    timestamptz not null,
    primary key (id),
    foreign key (actor_id) references app_user(id)
);

create table transport_load_allocation_group
(
    id                     uuid not null,
    actor_id               uuid not null,
    assessment_basis_json  text not null,
    assessment_hash        varchar(64) not null,
    operation_id           uuid not null,
    proof_json             text not null,
    reason                 text not null,
    recorded_at            timestamptz not null,
    routes_json            text not null,
    primary key (id),
    foreign key (actor_id) references app_user(id)
);

create table transport_load_command
(
    operation_id    uuid not null,
    actor_id        uuid not null,
    kind            text not null,
    payload_hash    text not null,
    original_json   text not null,
    outcome         text not null,
    result_json     text,
    closure_reason  text,
    recorded_at     timestamptz not null,
    primary key (operation_id),
    check ((((outcome = 'applied') and (result_json is not null) and (closure_reason is null)) or ((outcome = 'not_executed') and (result_json is null) and ((length(btrim(closure_reason)) >= 1) and (length(btrim(closure_reason)) <= 2000))))),
    check (kind in ('PREPARE', 'GROUP', 'CANCEL_PREPARED', 'REVISE', 'PREPARE_EXISTING')),
    -- kind BAZADA: jadval bo'sh
    check (outcome in ('APPLIED', 'NOT_EXECUTED')),
    -- outcome BAZADA: jadval bo'sh
    check ((payload_hash ~ '^[a-f0-9]{64}$')),
    foreign key (actor_id) references app_user(id)
);

-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
create table transport_load_current_claims
(
    id                     uuid,
    operation_id           uuid,
    route_id               uuid,
    vehicle_id             uuid,
    actor_id               uuid,
    recorded_at            timestamptz,
    assessment_basis_json  text,
    assessment_hash        varchar(64),
    proof_json             text,
    request_ids            uuid[]
);

create table transport_load_group_context
(
    group_id        uuid not null,
    transaction_id  bigint not null,
    primary key (group_id)
);

create table transport_load_group_queue
(
    group_id              uuid not null,
    transaction_id        bigint not null,
    generation            bigint not null,
    validated_generation  bigint not null,
    primary key (group_id)
);

create table transport_load_manifest
(
    id                     uuid not null,
    actor_id               uuid not null,
    assessment_basis_json  text not null,
    assessment_hash        varchar(64) not null,
    operation_id           uuid not null,
    proof_json             text not null,
    recorded_at            timestamptz not null,
    route_id               uuid not null,
    vehicle_id             uuid not null,
    primary key (id)
);

create table transport_load_manifest_audit_context
(
    audit_id        uuid not null,
    manifest_id     uuid not null,
    request_id      uuid not null,
    transaction_id  bigint not null,
    primary key (audit_id)
);

create table transport_load_manifest_insert_context
(
    kind            text not null,
    id              uuid not null,
    transaction_id  bigint not null,
    primary key (kind, id)
);

-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
create table transport_load_manifest_latest
(
    id                     uuid,
    operation_id           uuid,
    route_id               uuid,
    vehicle_id             uuid,
    actor_id               uuid,
    recorded_at            timestamptz,
    assessment_basis_json  text,
    assessment_hash        varchar(64),
    proof_json             text
);

create table transport_load_manifest_request_context
(
    manifest_id       uuid not null,
    request_id        uuid not null,
    captured_version  bigint not null,
    captured_status   text not null,
    transaction_id    bigint not null,
    primary key (manifest_id, request_id)
);

create table transport_load_manifest_retirement
(
    operation_id              uuid not null,
    request_id                uuid not null,
    actor_id                  uuid not null,
    route_id                  uuid not null,
    manifest_head_id          uuid not null,
    preparation_operation_id  uuid not null,
    preparation_actor_id      uuid not null,
    source_id                 uuid not null,
    source_revision           bigint not null,
    material_hash             text not null,
    assessment_hash           text not null,
    retained_branch_id        uuid not null,
    before_route_version      bigint not null,
    result_route_version      bigint not null,
    before_request_version    bigint not null,
    result_request_version    bigint not null,
    origin_json               jsonb not null,
    history_hash              text not null,
    reason                    text not null,
    transaction_id            bigint not null,
    recorded_at               timestamptz not null,
    primary key (operation_id),
    check ((assessment_hash ~ '^[a-f0-9]{64}$')),
    check ((material_hash ~ '^[a-f0-9]{64}$')),
    check ((source_revision > 0)),
    foreign key (preparation_operation_id) references transport_load_command(operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (manifest_head_id) references transport_load_manifest_revision(id),
    foreign key (operation_id) references transport_request_revision_intent(operation_id),
    foreign key (preparation_actor_id) references app_user(id),
    foreign key (request_id) references transport_request(id),
    foreign key (retained_branch_id) references reference_data(id),
    foreign key (route_id) references route(id),
    foreign key (source_id) references transport_request_load_source(id)
);

create table transport_load_manifest_revision
(
    id                       uuid not null,
    actor_id                 uuid not null,
    assessment_basis_json    text not null,
    assessment_hash          varchar(64) not null,
    captured_route_version   bigint not null,
    operation_id             uuid not null,
    previous_id              uuid,
    proof_json               text not null,
    reason                   text not null,
    recorded_at              timestamptz not null,
    revision                 bigint not null,
    route_id                 uuid not null,
    vehicle_id               uuid not null,
    preparation_before_json  jsonb,
    primary key (id),
    foreign key (actor_id) references app_user(id),
    foreign key (route_id) references route(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table transport_load_manifest_validation_queue
(
    manifest_id           uuid not null,
    transaction_id        bigint not null,
    generation            bigint not null,
    validated_generation  bigint not null,
    primary key (manifest_id)
);

create table transport_load_revision_context
(
    revision_id     uuid not null,
    route_id        uuid not null,
    transaction_id  bigint not null,
    primary key (revision_id)
);

create table transport_load_revision_queue
(
    revision_id           uuid not null,
    transaction_id        bigint not null,
    generation            bigint not null,
    validated_generation  bigint not null,
    primary key (revision_id)
);

create table transport_optimizer_application
(
    operation_id     uuid not null,
    proposal_id      uuid not null,
    review_revision  bigint not null,
    review_hash      text not null,
    actor_id         uuid not null,
    kind             text not null,
    recorded_at      timestamptz not null,
    primary key (operation_id),
    check (kind in ('PREPARE', 'GROUP')),
    -- kind BAZADA: jadval bo'sh
    foreign key (proposal_id, review_revision) references transport_optimizer_review(proposal_id, revision),
    foreign key (actor_id) references app_user(id)
);

create table transport_optimizer_proposal
(
    id                uuid not null,
    actor_id          uuid not null,
    original_json     text not null,
    original_hash     text not null,
    baseline_json     text not null,
    resources_json    text not null,
    request_json      text not null,
    state             text not null,
    created_at        timestamptz not null,
    response_at       timestamptz,
    response_json     text,
    response_hash     text,
    response_version  text,
    candidate_json    text,
    reasons_json      text,
    uncovered_json    text,
    comparison_json   text,
    failure           text,
    primary key (id),
    check ((((state = 'pending') and (response_at is null) and (response_json is null) and (failure is null)) or ((state = 'proposed') and (response_at is not null) and (response_json is not null) and (response_hash is not null) and (failure is null)) or ((state = 'failed') and (response_at is not null) and (response_json is null) and (failure is not null)))),
    check ((original_hash ~ '^[a-f0-9]{64}$')),
    check (((response_hash is null) or (response_hash ~ '^[a-f0-9]{64}$'))),
    check (state in ('PENDING', 'PROPOSED', 'FAILED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id)
);

create table transport_optimizer_review
(
    proposal_id     uuid not null,
    revision        bigint not null,
    operation_id    uuid not null,
    actor_id        uuid not null,
    original_json   text not null,
    selection_json  text not null,
    proof_json      text not null,
    drivers_json    text not null,
    reason          text not null,
    review_hash     text not null,
    basis_json      text not null,
    reviewed_at     timestamptz not null,
    primary key (proposal_id, revision),
    check (((length(btrim(reason)) >= 1) and (length(btrim(reason)) <= 2000))),
    check ((review_hash ~ '^[a-f0-9]{64}$')),
    check ((revision > 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (proposal_id) references transport_optimizer_proposal(id)
);

create table transport_passport_assignment
(
    id                 uuid not null,
    trip_id            uuid not null,
    trip_version       bigint not null,
    vehicle_id         uuid not null,
    trailer_id         uuid,
    policy_id          uuid not null,
    policy_version     bigint not null,
    source_hash        text not null,
    snapshot_json      jsonb not null,
    passport_receipts  jsonb not null,
    recorded_at        timestamptz not null,
    primary key (id),
    foreign key (policy_id) references transport_governance_policy(id),
    foreign key (trip_id) references trip(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table transport_planning_closure
(
    id                uuid not null,
    actor_id          uuid not null,
    kind              varchar(16) not null,
    original_json     text not null,
    payload_hash      varchar(64) not null,
    performed_at      timestamptz not null,
    reason            varchar(2000) not null,
    request_ids_json  text not null,
    source_id         uuid,
    primary key (id),
    foreign key (actor_id) references app_user(id)
);

create table transport_planning_decision_claim
(
    id            uuid not null,
    actor_id      uuid not null,
    payload_hash  varchar(64) not null,
    kind          varchar(16) not null,
    decision      varchar(16) not null,
    primary key (id),
    check (decision in ('EXECUTED', 'NOT_EXECUTED')),
    -- decision BAZADA: EXECUTED 65 | ISHLATILMAGAN: NOT_EXECUTED
    check (kind in ('SINGLE', 'BUNDLE', 'ROUTE', 'DIRECT')),
    -- kind BAZADA: SINGLE 63, ROUTE 2 | ISHLATILMAGAN: BUNDLE, DIRECT
    foreign key (actor_id) references app_user(id)
);

create table transport_planning_operation
(
    id            uuid not null,
    actor_id      uuid not null,
    kind          varchar(16) not null,
    payload_hash  varchar(64) not null,
    performed_at  timestamptz not null,
    result_json   text not null,
    primary key (id),
    check (((payload_hash) ~ '^[0-9a-f]{64}$')),
    check (kind in ('SINGLE', 'BUNDLE', 'ROUTE', 'DIRECT')),
    -- kind BAZADA: SINGLE 63, ROUTE 2 | ISHLATILMAGAN: BUNDLE, DIRECT
    check (coalesce(((jsonb_typeof((result_json)::jsonb) = 'object') and (jsonb_typeof(((result_json)::jsonb -> 'requestids')) = 'array') and (jsonb_array_length(((result_json)::jsonb -> 'requestids')) > 0) and (jsonb_typeof(((result_json)::jsonb -> 'waybillids')) = 'array') and (jsonb_array_length(((result_json)::jsonb -> 'waybillids')) = 1)), false)),
    foreign key (actor_id) references app_user(id)
);

create table transport_production_create_operation
(
    operation_id   uuid not null,
    branch_id      uuid not null,
    actor_id       uuid not null,
    original_json  text not null,
    state          varchar(16) not null,
    result_json    text,
    reason         text,
    recorded_at    timestamptz not null,
    primary key (operation_id),
    check (state in ('APPLIED', 'NOT_EXECUTED'))
    -- state BAZADA: jadval bo'sh
);

create table transport_production_revision
(
    id            uuid not null,
    order_id      uuid not null,
    revision      bigint not null,
    branch_id     uuid not null,
    base_version  bigint not null,
    policy_id     uuid not null,
    actor_id      uuid not null,
    recorded_at   timestamptz not null,
    action        varchar(32) not null,
    reason        text not null,
    content_hash  varchar(64) not null,
    content_json  text not null,
    result_json   text not null,
    primary key (id),
    check ((revision > 0)),
    foreign key (order_id) references production_order(id),
    foreign key (policy_id) references transport_quantity_policy(id)
);

create table transport_quantity_operation
(
    operation_id   uuid not null,
    subject_id     uuid not null,
    domain         varchar(16) not null,
    branch_id      uuid not null,
    actor_id       uuid not null,
    original_json  text not null,
    original_hash  varchar(64) not null,
    state          varchar(16) not null,
    result_json    text,
    reason         text,
    recorded_at    timestamptz not null,
    primary key (operation_id),
    check (((((state) = 'applied') and (result_json is not null) and (reason is null)) or (((state) = 'not_executed') and (result_json is null) and (length(reason) > 0)))),
    check (state in ('APPLIED', 'NOT_EXECUTED'))
    -- state BAZADA: jadval bo'sh
);

create table transport_quantity_policy
(
    id            uuid not null,
    branch_id     uuid not null,
    domain        varchar(16) not null,
    operation_id  uuid not null,
    previous_id   uuid,
    actor_id      uuid not null,
    reviewed_at   timestamptz not null,
    payload_json  text not null,
    payload_hash  varchar(64) not null,
    primary key (id),
    check (domain in ('SHIPMENT', 'PRODUCTION'))
    -- domain BAZADA: jadval bo'sh
);

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
create table transport_request
(
    id                               uuid not null,
    approver_name                    varchar(256),
    approver_user_id                 uuid,
    assigned_logistic_name           varchar(256),
    assigned_logistic_user_id        uuid,
    cargo_description                varchar(1024),
    cargo_places                     integer,
    cargo_volume_m3                  numeric(10,2),
    cargo_weight_kg                  numeric(10,2),
    comment                          varchar(1024),
    created_at                       timestamptz not null,
    department_id                    uuid,
    department_name                  varchar(256),
    destination_latitude             numeric(10,6),
    destination_location             varchar(512),
    destination_location_id          uuid,
    destination_longitude            numeric(10,6),
    eimzo_signature                  text,
    from_branch_id                   uuid,
    from_branch_name                 varchar(256),
    from_warehouse_id                uuid,
    from_warehouse_name              varchar(256),
    initiator_name                   varchar(256) not null,
    initiator_user_id                uuid not null,
    origin_latitude                  numeric(10,6),
    origin_location                  varchar(512),
    origin_location_id               uuid,
    origin_longitude                 numeric(10,6),
    planned_arrival_at               timestamp,
    planned_departure_at             timestamp,
    priority                         varchar(16) not null,
    purpose                          varchar(2048),
    rejection_reason                 varchar(512),
    request_number                   varchar(64) not null,
    request_type                     varchar(64) not null,
    required_transport_type          varchar(32) not null,
    site_code                        varchar(120),
    special_requirements             varchar(1024),
    status                           varchar(64) not null,
    submit                           varchar(255),
    to_branch_id                     uuid,
    to_branch_name                   varchar(256),
    to_warehouse_id                  uuid,
    to_warehouse_name                varchar(256),
    updated_at                       timestamptz not null,
    version                          bigint not null,
    wms_shipment_id                  uuid,
    binding_driver_id                uuid,
    binding_notes                    varchar(1024),
    binding_route_id                 uuid,
    binding_vehicle_id               uuid,
    bound_at                         timestamptz,
    bound_by                         varchar(256),
    waybill_category                 varchar(32),
    return_location                  varchar(512),
    cargo_weight_tons                numeric(8,2),
    planned_engine_hours             numeric(8,2),
    work_site_area                   varchar(512),
    trailer_id                       uuid,
    trailer_plate_number             varchar(32),
    actual_cargo_weight_tons         numeric(10,2),
    actual_ton_km                    numeric(12,2),
    inbound_km                       numeric(10,2),
    inbound_tons                     numeric(10,2),
    outbound_km                      numeric(10,2),
    outbound_tons                    numeric(10,2),
    source                           varchar(32),
    submitted_at                     timestamptz,
    first_viewed_at                  timestamptz,
    first_viewed_by                  varchar(256),
    transport_head_approved_user_id  uuid,
    transport_head_approved_by       varchar(256),
    transport_head_approved_at       timestamptz,
    transport_head_rejected_user_id  uuid,
    transport_head_rejected_by       varchar(256),
    transport_head_rejected_at       timestamptz,
    assigned_branch_id               uuid,
    assigned_branch_name             varchar(256),
    assigned_by                      varchar(256),
    assigned_at                      timestamptz,
    customer_confirmation_status     varchar(64),
    is_shift                         boolean,
    work_mode                        varchar(64),
    request_mode                     varchar(32),
    destination_region               varchar(128),
    destination_district             varchar(128),
    destination_address              varchar(512),
    external_organization            varchar(256),
    trip_type                        varchar(64),
    return_not_required              boolean,
    passenger_count                  integer,
    daily_work_start_time            varchar(8),
    daily_work_end_time              varchar(8),
    exploitation_instruction         varchar(2048),
    edo_request_number               varchar,
    is_long_term                     boolean,
    auto_routed                      boolean,
    auto_routed_at                   timestamptz,
    auto_routed_branch_id            uuid,
    auto_routing_reason              varchar(1024),
    fast_track                       boolean,
    routing_mode                     varchar(32),
    urgency_reason                   varchar(1024),
    planning_end_instant             timestamptz,
    planning_end_local               varchar(64),
    planning_start_instant           timestamptz,
    planning_start_local             varchar(64),
    planning_time_zone               varchar(64),
    correction_operation_id          uuid,
    correction_retained_branch_id    uuid,
    primary key (id)
    -- status BAZADA: COMPLETED 1274, READY_FOR_PLANNING 450, IN_PROGRESS 346, AWAITING_CUSTOMER_CONFIRMATION 280, ASSIGNED 252, CANCELLED 245, DRAFT 7, ASSIGNED_TO_BRANCH 6, PENDING_DEPARTMENT_APPROVAL 4, SUBMITTED 3, APPROVED 2, PENDING_TRANSPORT_APPROVAL 1
);

-- ---------------------------------------------------------------------
-- Transport so'rovi ustidagi amallar tarixi: amal, oldingi va yangi status, kim
-- bajargani (actor_name), vaqti va izohi.
-- SO'ROV NEGA RAD ETILGANI YOKI QAYSI BOSQICHDA TURGANI SO'RALSA SHU JADVALDAN
-- OLINADI.
-- ---------------------------------------------------------------------
create table transport_request_audit
(
    id               uuid not null,
    action           varchar(64) not null,
    actor_id         varchar(128),
    actor_name       varchar(256),
    comment          varchar(512),
    new_status       varchar(64),
    performed_at     timestamptz not null,
    previous_status  varchar(64),
    request_id       uuid not null,
    primary key (id),
    foreign key (request_id) references transport_request(id)
);

create table transport_request_customer_department
(
    id               uuid not null,
    request_id       uuid not null,
    department_id    uuid not null,
    department_name  varchar(256) not null,
    department_code  varchar(64),
    sequence_number  integer not null,
    primary key (id),
    foreign key (request_id) references transport_request(id),
    foreign key (request_id) references transport_request(id) on delete cascade
);

create table transport_request_endpoint_review
(
    operation_id     uuid not null,
    request_id       uuid not null,
    request_version  bigint not null,
    reviewed_json    jsonb not null,
    point_snapshot   jsonb not null,
    point_ids        uuid[] not null,
    recorded_at      timestamptz not null,
    primary key (operation_id),
    check ((cardinality(point_ids) = 2)),
    foreign key (operation_id) references transport_request_revision_command(operation_id) deferrable initially deferred,
    foreign key (request_id) references transport_request(id)
);

create table transport_request_load_approval
(
    id                        uuid not null,
    actor_id                  uuid not null,
    approved_at               timestamptz not null,
    approved_request_version  bigint not null,
    audit_id                  uuid not null,
    positions_json            text,
    request_id                uuid not null,
    reviewed_material_hash    varchar(64),
    reviewed_source_id        uuid,
    reviewed_source_revision  bigint,
    source_snapshot_json      text,
    primary key (id),
    foreign key (actor_id) references app_user(id),
    foreign key (audit_id) references transport_request_audit(id),
    foreign key (request_id) references transport_request(id),
    foreign key (reviewed_source_id) references transport_request_load_source(id)
);

create table transport_request_load_approval_audit_context
(
    audit_id        uuid not null,
    request_id      uuid not null,
    transaction_id  bigint not null,
    primary key (audit_id)
);

create table transport_request_load_approval_transition
(
    request_id                uuid not null,
    approved_request_version  bigint not null,
    previous_status           text not null,
    transaction_id            bigint not null,
    primary key (request_id, approved_request_version)
);

create table transport_request_load_source
(
    id                        uuid not null,
    actor_id                  uuid not null,
    captured_request_version  bigint not null,
    operation_id              uuid not null,
    payload_hash              varchar(64) not null,
    positions_json            text not null,
    recorded_at               timestamptz not null,
    request_id                uuid not null,
    revision                  bigint not null,
    source_hash               varchar(64) not null,
    source_snapshot_json      text not null,
    primary key (id),
    foreign key (actor_id) references app_user(id),
    foreign key (request_id) references transport_request(id)
);

create table transport_request_load_source_audit_context
(
    source_id       uuid not null,
    audit_id        uuid not null,
    transaction_id  bigint not null,
    primary key (source_id)
);

create table transport_request_load_source_insert_context
(
    source_id                 uuid not null,
    request_id                uuid not null,
    captured_request_version  bigint not null,
    actor_id                  uuid not null,
    branch_id                 uuid,
    previous_status           text not null,
    transaction_id            bigint not null,
    primary key (source_id)
);

create table transport_request_load_source_version_context
(
    source_id         uuid not null,
    request_id        uuid not null,
    previous_version  bigint not null,
    next_version      bigint not null,
    transaction_id    bigint not null,
    primary key (source_id)
);

-- ---------------------------------------------------------------------
-- Transport so'rovidagi yuklash/tushirish nuqtalari: ketma-ketlik, nuqta turi
-- (ORIGIN, WAYPOINT, LOADING, UNLOADING, DESTINATION), manzil, koordinata,
-- oldingi nuqtadan masofa va vaqt.
-- ---------------------------------------------------------------------
create table transport_request_point
(
    id                                    uuid not null,
    address                               varchar(1024),
    distance_from_previous_km             numeric(14,3) not null,
    drive_duration_from_previous_minutes  bigint not null,
    latitude                              float8,
    location_id                           uuid,
    location_name                         varchar(512),
    longitude                             float8,
    planned_arrival_at                    timestamp not null,
    planned_departure_at                  timestamp not null,
    point_type                            varchar(32) not null,
    sequence_number                       integer not null,
    transport_request_id                  uuid not null,
    department_id                         uuid,
    department_name                       varchar(256),
    planning_start_local                  varchar(64),
    planning_end_local                    varchar(64),
    planning_time_zone                    varchar(64),
    planning_start_instant                timestamptz,
    planning_end_instant                  timestamptz,
    primary key (id),
    check (point_type in ('ORIGIN', 'WAYPOINT', 'LOADING', 'UNLOADING', 'DESTINATION')),
    -- point_type BAZADA: ORIGIN 85, DESTINATION 85, WAYPOINT 22 | ISHLATILMAGAN: LOADING, UNLOADING
    foreign key (transport_request_id) references transport_request(id)
);

create table transport_request_revision_audit_capture
(
    operation_id    uuid not null,
    audit_id        uuid not null,
    request_id      uuid not null,
    actor_id        uuid not null,
    audit_json      jsonb not null,
    transaction_id  bigint not null,
    recorded_at     timestamptz not null,
    primary key (operation_id, audit_id),
    foreign key (audit_id) references transport_request_audit(id),
    foreign key (operation_id) references transport_request_revision_intent(operation_id)
);

create table transport_request_revision_command
(
    operation_id        uuid not null,
    request_id          uuid not null,
    actor_id            uuid not null,
    action              text not null,
    expected_version    bigint not null,
    result_version      bigint,
    retained_branch_id  uuid,
    original_json       text not null,
    before_json         jsonb not null,
    payload_hash        text not null,
    outcome             text not null,
    result_json         text not null,
    transaction_id      bigint not null,
    recorded_at         timestamptz not null,
    primary key (operation_id),
    check (action in ('CORRECTION', 'CANONICAL_STOPS', 'BRANCH_ASSIGN')),
    -- action BAZADA: CANONICAL_STOPS 4, CORRECTION 1, BRANCH_ASSIGN 1
    check ((((outcome = 'applied') and (expected_version < '9223372036854775807') and (result_version = (expected_version + 1))) or ((outcome = 'not_executed') and (result_version is null) and (retained_branch_id is null)))),
    check ((expected_version >= 0)),
    check ((length(original_json) <= 1048576)),
    check (outcome in ('APPLIED', 'NOT_EXECUTED')),
    -- outcome BAZADA: APPLIED 5, NOT_EXECUTED 1
    foreign key (actor_id) references app_user(id),
    foreign key (request_id) references transport_request(id)
);

create table transport_request_revision_intent
(
    operation_id                uuid not null,
    request_id                  uuid not null,
    actor_id                    uuid not null,
    action                      text not null,
    original_json               text not null,
    before_json                 jsonb not null,
    point_snapshot              jsonb not null,
    material_snapshot           jsonb not null,
    audit_snapshot              jsonb not null,
    route_snapshot              jsonb not null,
    transaction_id              bigint not null,
    recorded_at                 timestamptz not null,
    manifest_retirement_before  jsonb,
    primary key (operation_id),
    check (action in ('CORRECTION', 'CANONICAL_STOPS', 'BRANCH_ASSIGN')),
    -- action BAZADA: CANONICAL_STOPS 3, CORRECTION 1, BRANCH_ASSIGN 1
    foreign key (actor_id) references app_user(id),
    foreign key (request_id) references transport_request(id)
);

create table transport_request_revision_transition
(
    id                uuid not null,
    request_id        uuid not null,
    previous_version  bigint not null,
    result_version    bigint not null,
    before_json       jsonb not null,
    after_json        jsonb not null,
    transaction_id    bigint not null,
    recorded_at       timestamptz not null,
    primary key (id)
);

create table transport_request_service_confirmation
(
    id                    uuid not null,
    request_id            uuid not null,
    trip_id               uuid,
    department_id         uuid not null,
    work_performed        varchar(2048),
    arrival_at            timestamptz,
    departure_at          timestamptz,
    quantity              numeric(12,2),
    unit                  varchar(64),
    result                varchar(32),
    comment               varchar(2048),
    confirmed_by_user_id  uuid,
    confirmed_by_name     varchar(256),
    confirmed_at          timestamptz,
    created_at            timestamptz not null,
    updated_at            timestamptz not null,
    status                varchar(32),
    waybill_id            uuid,
    vehicle_id            uuid,
    driver_id             uuid,
    primary key (id),
    -- status BAZADA: PENDING 349, DISPUTED 1, CONFIRMED 1
    foreign key (request_id) references transport_request(id) on delete cascade
);

create table transport_request_transport_requirement
(
    id               uuid not null,
    quantity         integer not null,
    sequence_number  integer not null,
    transport_type   varchar(32) not null,
    request_id       uuid not null,
    primary key (id),
    foreign key (request_id) references transport_request(id),
    foreign key (request_id) references transport_request(id) on delete cascade
);

create table transport_requirement_operation
(
    id                  uuid not null,
    request_id          uuid not null,
    requirement_id      uuid not null,
    created_command_id  uuid not null,
    created_by          uuid not null,
    created_at          timestamptz not null,
    primary key (id),
    foreign key (created_by) references app_user(id),
    foreign key (created_command_id) references transport_demand_operation_command(id) deferrable initially deferred,
    foreign key (request_id) references transport_request(id)
);

create table transport_requirement_operation_revision
(
    id               uuid not null,
    command_id       uuid not null,
    operation_id     uuid not null,
    revision         bigint not null,
    request_version  bigint not null,
    state            text not null,
    body             jsonb not null,
    material_hash    text not null,
    actor_id         uuid not null,
    reason           text not null,
    recorded_at      timestamptz not null,
    primary key (id),
    check ((material_hash ~ '^[a-f0-9]{64}$')),
    check ((length(btrim(reason)) > 0)),
    check ((request_version >= 0)),
    check ((revision > 0)),
    check (state in ('DRAFT', 'CANCELLED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (operation_id) references transport_requirement_operation(id),
    foreign key (command_id) references transport_demand_operation_command(id) deferrable initially deferred
);

create table transport_route_context_closed
(
    id             uuid not null,
    route_id       uuid not null,
    actor_id       uuid not null,
    action         text not null,
    payload_hash   text not null,
    original_json  text not null,
    reason         text not null,
    recorded_at    timestamptz not null,
    primary key (id),
    check (action in ('SAVE', 'APPROVE', 'REVOKE', 'PERIOD_REPAIR')),
    -- action BAZADA: SAVE 1, PERIOD_REPAIR 1 | ISHLATILMAGAN: APPROVE, REVOKE
    foreign key (actor_id) references app_user(id),
    foreign key (route_id) references route(id)
);

create table transport_route_context_invalidation
(
    id                      uuid not null,
    correction_id           uuid not null,
    request_id              uuid not null,
    route_id                uuid not null,
    revision_id             uuid,
    actor_id                uuid not null,
    previous_route_version  bigint not null,
    result_route_version    bigint not null,
    basis                   text not null,
    recorded_at             timestamptz not null,
    primary key (id),
    check (((previous_route_version >= 0) and (previous_route_version < '9223372036854775807'))),
    check (((length(btrim(basis)) >= 1) and (length(btrim(basis)) <= 2000))),
    check ((result_route_version = (previous_route_version + 1))),
    foreign key (actor_id) references app_user(id),
    foreign key (correction_id) references transport_request_revision_command(operation_id) deferrable initially deferred,
    foreign key (request_id) references transport_request(id),
    foreign key (revision_id) references transport_route_operating_context(id),
    foreign key (route_id) references route(id)
);

create table transport_route_context_receipt
(
    id             uuid not null,
    route_id       uuid not null,
    actor_id       uuid not null,
    action         text not null,
    payload_hash   text not null,
    original_json  text not null,
    result_json    text not null,
    recorded_at    timestamptz not null,
    primary key (id),
    foreign key (actor_id) references app_user(id),
    foreign key (route_id) references route(id)
);

create table transport_route_operating_context
(
    id                      uuid not null,
    route_id                uuid not null,
    captured_route_version  bigint not null,
    geometry_hash           text not null,
    original_json           text not null,
    context_json            text not null,
    author_id               uuid not null,
    native_geometry_json    jsonb not null,
    recorded_at             timestamptz not null,
    primary key (id),
    foreign key (author_id) references app_user(id),
    foreign key (route_id) references route(id)
);

create table transport_route_operating_decision
(
    id           uuid not null,
    revision_id  uuid not null,
    actor_id     uuid not null,
    action       text not null,
    basis        text not null,
    recorded_at  timestamptz not null,
    primary key (id),
    check (action in ('APPROVE', 'REVOKE')),
    -- action BAZADA: APPROVE 10 | ISHLATILMAGAN: REVOKE
    foreign key (actor_id) references app_user(id),
    foreign key (revision_id) references transport_route_operating_context(id)
);

create table transport_route_period_receipt
(
    id             uuid not null,
    route_id       uuid not null,
    actor_id       uuid not null,
    action         text not null,
    payload_hash   text not null,
    original_json  text not null,
    result_json    text not null,
    recorded_at    timestamptz not null,
    primary key (id),
    check ((action = 'period_repair')),
    foreign key (actor_id) references app_user(id),
    foreign key (route_id) references route(id)
);

create table transport_route_stop_identity
(
    id            uuid not null,
    route_id      uuid not null,
    amendment_id  uuid,
    point_json    jsonb,
    primary key (id),
    foreign key (amendment_id) references trip_route_amendment(id)
);

create table transport_shipment_revision
(
    id            uuid not null,
    shipment_id   uuid not null,
    revision      bigint not null,
    branch_id     uuid not null,
    base_version  bigint not null,
    policy_id     uuid not null,
    actor_id      uuid not null,
    recorded_at   timestamptz not null,
    action        varchar(32) not null,
    reason        text not null,
    content_hash  varchar(64) not null,
    content_json  text not null,
    result_json   text not null,
    primary key (id),
    check ((revision > 0)),
    foreign key (policy_id) references transport_quantity_policy(id),
    foreign key (shipment_id) references shipment(id)
);

create table transport_source_identity
(
    domain              varchar(16) not null,
    source_system       varchar(128) not null,
    source_document_id  varchar(256) not null,
    subject_id          uuid not null,
    branch_id           uuid not null,
    registered_by       uuid not null,
    registered_at       timestamptz not null,
    primary key (domain, source_system, source_document_id)
);

create table transport_source_revision
(
    id                  uuid not null,
    domain              varchar(16) not null,
    source_system       varchar(128) not null,
    source_document_id  varchar(256) not null,
    source_revision     varchar(256) not null,
    subject_id          uuid not null,
    operation_id        uuid not null,
    actor_id            uuid not null,
    recorded_at         timestamptz not null,
    result_json         text not null,
    primary key (id)
);

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
create table transport_vehicle
(
    id                      uuid not null,
    assigned_driver_id      uuid,
    branch_id               uuid,
    brand                   varchar(64) not null,
    category                varchar(32) not null,
    commissioning_date      date,
    created_at              timestamptz not null,
    created_by              varchar(256) not null,
    current_status          varchar(32) not null,
    department_id           uuid,
    engine_power            numeric(10,2),
    gps_device_id           varchar(128),
    model                   varchar(64) not null,
    ownership_type          varchar(32) not null,
    payload_capacity_kg     numeric(10,2),
    plate_number            varchar(32),
    ref_id                  varchar(16) not null,
    release_date            date,
    seat_count              integer,
    tech_passport_date      date,
    tech_passport_number    varchar(128),
    transport_type          varchar(32) not null,
    updated_at              timestamptz not null,
    updated_by              varchar(256) not null,
    vehicle_color           varchar(64),
    vin                     varchar(64),
    volume_m3               numeric(10,2),
    usage_mode              varchar(32) not null,
    cargo_capacity_tons     numeric,
    cargo_capacity_version  bigint not null,
    passenger_capacity      integer,
    primary key (id),
    check (category in ('LIGHT', 'MEDIUM', 'HEAVY', 'EXTRA_HEAVY', 'SPECIAL', 'ELECTRIC_VEHICLE', 'ELECTRIC')),
    -- category BAZADA: LIGHT 50, SPECIAL 47, HEAVY 43, MEDIUM 17, ELECTRIC_VEHICLE 7 | ISHLATILMAGAN: EXTRA_HEAVY, ELECTRIC
    check (current_status in ('ACTIVE', 'RESERVED', 'IN_OPERATION', 'IN_MAINTENANCE', 'BLOCKED', 'DECOMMISSIONED')),
    -- current_status BAZADA: ACTIVE 162, IN_MAINTENANCE 1, BLOCKED 1 | ISHLATILMAGAN: RESERVED, IN_OPERATION, DECOMMISSIONED
    check (ownership_type in ('OWNED', 'LEASED', 'RENTED')),
    -- ownership_type BAZADA: OWNED 156, RENTED 8 | ISHLATILMAGAN: LEASED
    check (transport_type in ('MOBILE_CRANE', 'AERIAL_PLATFORM', 'TRACTOR', 'WATER_TRUCK', 'EXCAVATOR', 'FRONT_LOADER', 'DUMP_TRUCK', 'LONG_LOAD_TRUCK', 'FLATBED', 'MANIPULATOR', 'PASSENGER_CAR', 'BUS', 'VAN', 'BULLDOZER', 'CONCRETE_PUMP', 'CONCRETE_MIXER', 'FIRE_TRUCK', 'AMBULANCE', 'TRUCK', 'TANKER', 'REFRIGERATED', 'SPECIALIZED', 'MINIBUS', 'PICKUP', 'TRAILER', 'OTHER', 'ELECTRIC_VEHICLE')),
    -- transport_type BAZADA: PASSENGER_CAR 49, SPECIALIZED 18, FLATBED 14, BUS 13, DUMP_TRUCK 13, TRACTOR 9, ELECTRIC_VEHICLE 7, MOBILE_CRANE 7, FRONT_LOADER 7, AERIAL_PLATFORM 7, LONG_LOAD_TRUCK 5, WATER_TRUCK 4, EXCAVATOR 3, VAN 3, CONCRETE_MIXER 2, CONCRETE_PUMP 1, BULLDOZER 1, MANIPULATOR 1 | ISHLATILMAGAN: FIRE_TRUCK, AMBULANCE, TRUCK, TANKER, REFRIGERATED, MINIBUS, PICKUP, TRAILER va yana 1 ta
    check (usage_mode in ('KM', 'MOTOSOAT', 'KM_AND_MOTOSOAT'))
    -- usage_mode BAZADA: KM 115, MOTOSOAT 38, KM_AND_MOTOSOAT 11
);

create table transport_waybill_anomaly_closure
(
    id                      uuid not null,
    operation_id            uuid not null,
    waybill_id              uuid not null,
    trip_id                 uuid not null,
    branch_id               uuid not null,
    actor_id                uuid not null,
    inspection_revision_id  uuid not null,
    policy_revision_id      uuid not null,
    original_json           jsonb not null,
    result_json             jsonb not null,
    before_json             jsonb not null,
    after_json              jsonb not null,
    recorded_at             timestamptz not null,
    primary key (id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (inspection_revision_id) references safety_technical_inspection_revision(id),
    foreign key (policy_revision_id) references transport_governance_policy(id),
    foreign key (trip_id) references trip(id),
    foreign key (waybill_id) references waybill(id)
);

create table transport_waybill_anomaly_operation
(
    operation_id   uuid not null,
    waybill_id     uuid not null,
    branch_id      uuid not null,
    actor_id       uuid not null,
    state          text not null,
    original_json  jsonb not null,
    result_json    jsonb,
    reason         text,
    recorded_at    timestamptz not null,
    primary key (operation_id),
    check ((((state = 'applied') and (result_json is not null) and (reason is null)) or ((state = 'not_executed') and (result_json is null) and (length(trim(both from reason)) > 0)))),
    check (state in ('APPLIED', 'NOT_EXECUTED')),
    -- state BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (waybill_id) references waybill(id)
);

create table transport_waybill_anomaly_outbox
(
    id           uuid not null,
    closure_id   uuid not null,
    event_type   text not null,
    payload      jsonb not null,
    recorded_at  timestamptz not null,
    primary key (id),
    check ((event_type = 'waybill_closed_with_anomaly')),
    foreign key (closure_id) references transport_waybill_anomaly_closure(id)
);

create table transport_waybill_passport_snapshot
(
    waybill_id              uuid not null,
    waybill_version         bigint not null,
    assignment_snapshot_id  uuid not null,
    source_hash             text not null,
    snapshot_json           jsonb not null,
    recorded_at             timestamptz not null,
    primary key (waybill_id, waybill_version),
    foreign key (assignment_snapshot_id) references transport_passport_assignment(id),
    foreign key (waybill_id) references waybill(id)
);

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
create table trip
(
    id                         uuid not null,
    actual_arrival_at          timestamp,
    actual_departure_at        timestamp,
    actual_distance_km         numeric(14,3) not null,
    cancellation_reason        varchar(1024),
    created_at                 timestamptz not null,
    deviation_flag             boolean not null,
    driver_id                  uuid not null,
    route_id                   uuid not null,
    scheduled_arrival_at       timestamp not null,
    scheduled_departure_at     timestamp not null,
    status                     varchar(32) not null,
    transport_request_id       uuid,
    trip_number                varchar(32) not null,
    updated_at                 timestamptz not null,
    vehicle_id                 uuid not null,
    version                    bigint not null,
    actual_engine_hours        numeric(14,3),
    trailer_id                 uuid,
    trailer_plate_number       varchar(32),
    trailer_model              varchar(64),
    fuel_rate_norm             numeric(8,2),
    norm_source                varchar(32),
    passenger_count            integer,
    work_mode                  varchar(64),
    is_shift                   boolean not null,
    planning_end_instant       timestamptz,
    planning_end_local         varchar(64),
    planning_start_instant     timestamptz,
    planning_start_local       varchar(64),
    planning_time_zone         varchar(64),
    release_departure_instant  timestamptz,
    release_departure_local    varchar(64),
    release_departure_zone     varchar(64),
    release_return_instant     timestamptz,
    release_return_local       varchar(64),
    release_return_zone        varchar(64),
    primary key (id),
    check (status in ('PLANNED', 'ASSIGNED', 'STARTED', 'ARRIVED_AT_POINT', 'LOADED', 'UNLOADED', 'COMPLETED', 'CANCELLED', 'INTERRUPTED'))
    -- status BAZADA: COMPLETED 3097, ASSIGNED 296, STARTED 284, CANCELLED 264, UNLOADED 153, INTERRUPTED 1 | ISHLATILMAGAN: PLANNED, ARRIVED_AT_POINT, LOADED
);

create table trip_delivery_acceptance
(
    id                  uuid not null,
    trip_id             uuid not null,
    delivery_event_id   uuid not null,
    allocation_id       uuid not null,
    position_id         uuid not null,
    point_id            uuid not null,
    request_id          uuid not null,
    correction_version  bigint not null,
    quantity            numeric(18,6) not null,
    unit_code           text not null,
    binding_id          uuid not null,
    binding_version     bigint not null,
    recipient_id        uuid not null,
    otp_id              uuid not null,
    operation_id        uuid not null,
    accepted_by         uuid not null,
    accepted_at         timestamptz not null,
    primary key (id),
    check ((quantity > (0))),
    foreign key (accepted_by) references app_user(id),
    foreign key (binding_id) references trip_delivery_recipient_binding(id),
    foreign key (delivery_event_id) references trip_quantity_event(id),
    foreign key (otp_id) references trip_delivery_otp_challenge(id),
    foreign key (trip_id) references trip(id)
);

create table trip_delivery_otp_attempt
(
    operation_id  uuid not null,
    otp_id        uuid not null,
    actor_id      uuid not null,
    code_hash     text not null,
    outcome       text not null,
    recorded_at   timestamptz not null,
    result_json   text,
    primary key (operation_id),
    foreign key (otp_id) references trip_delivery_otp_challenge(id)
);

create table trip_delivery_otp_challenge
(
    id                      uuid not null,
    operation_id            uuid not null,
    trip_id                 uuid not null,
    delivery_event_id       uuid not null,
    allocation_id           uuid not null,
    position_id             uuid not null,
    point_id                uuid not null,
    request_id              uuid not null,
    correction_version      bigint not null,
    quantity                numeric(18,6) not null,
    unit_code               text not null,
    binding_id              uuid not null,
    binding_version         bigint not null,
    actor_id                uuid not null,
    code_hash               text not null,
    salt                    uuid not null,
    recipient_id            uuid not null,
    telegram_chat_id        bigint not null,
    expires_at              timestamptz not null,
    created_at              timestamptz not null,
    original_json           text not null,
    status                  text not null,
    attempt_count           integer not null,
    max_attempts            integer not null,
    verified_at             timestamptz,
    recipient_contact_json  text not null,
    primary key (id),
    check ((quantity > (0))),
    check (status in ('SENDING', 'SENT', 'SEND_UNKNOWN', 'FAILED', 'VERIFIED', 'EXPIRED')),
    -- status BAZADA: jadval bo'sh
    foreign key (binding_id) references trip_delivery_recipient_binding(id),
    foreign key (delivery_event_id) references trip_quantity_event(id),
    foreign key (trip_id) references trip(id)
);

create table trip_delivery_otp_request_closed
(
    operation_id   uuid not null,
    trip_id        uuid not null,
    actor_id       uuid not null,
    original_json  text not null,
    reason         text not null,
    closed_at      timestamptz not null,
    primary key (operation_id)
);

create table trip_delivery_recipient_binding
(
    id                      uuid not null,
    request_id              uuid not null,
    point_id                uuid not null,
    recipient_id            uuid not null,
    version                 bigint not null,
    active                  boolean not null,
    previous_id             uuid,
    operation_id            uuid not null,
    approved_by             uuid not null,
    approved_at             timestamptz not null,
    approval_reference      text not null,
    original_json           text not null,
    recipient_contact_json  text not null,
    primary key (id),
    check ((version > 0)),
    foreign key (approved_by) references app_user(id),
    foreign key (recipient_id) references telegram_recipient(id),
    foreign key (request_id) references transport_request(id),
    foreign key (point_id) references transport_route_stop_identity(id)
);

-- ---------------------------------------------------------------------
-- Reys hodisalari: reys yaratildi, boshlandi, nuqtaga yetdi, yuklandi, tushirildi,
-- bekor turish qayd etildi, marshrutdan chetlanish aniqlandi, yakunlandi, bekor
-- qilindi. source — hodisa manbai: DRIVER, DISPATCHER, PLANNING_SERVICE,
-- TELEMATICS_SERVICE, SYSTEM. payload_json da qo'shimcha ma'lumot.
-- REYS YO'LIDA NIMA BO'LGANI SO'RALSA event_time BO'YICHA TARTIBLAB OLINADI.
-- ---------------------------------------------------------------------
create table trip_event
(
    id                         uuid not null,
    created_at                 timestamptz not null,
    event_time                 timestamp not null,
    event_type                 varchar(64) not null,
    payload_json               text,
    point_id                   uuid,
    source                     varchar(32) not null,
    trip_id                    uuid not null,
    occurred_at_utc            timestamptz,
    occurrence_zone            varchar(64),
    occurrence_offset_seconds  integer,
    primary key (id),
    check (event_type in ('TRIP_CREATED_FROM_PLANNING', 'TRIP_RESCHEDULED', 'TRIP_STARTED', 'TRIP_ARRIVED_AT_POINT', 'TRIP_LOADED', 'TRIP_UNLOADED', 'TRIP_RETURNED_TO_BASE', 'TRIP_DOWNTIME_RECORDED', 'TRIP_DEVIATION_DETECTED', 'TRIP_RESERVATION_EXPIRED', 'TRIP_COMPLETED', 'TRIP_CANCELLED', 'TRIP_DELIVERY_CONFIRMED', 'TRIP_STOP_ADDED', 'TRIP_DRIVER_REASSIGNED', 'TRIP_VEHICLE_REASSIGNED', 'TRIP_TRAILER_REASSIGNED', 'TRIP_REROUTED', 'TRIP_WAYBILL_ISSUED')),
    -- event_type BAZADA: TRIP_COMPLETED 2731, TRIP_RETURNED_TO_BASE 2727, TRIP_STARTED 2604, TRIP_CREATED_FROM_PLANNING 1374, TRIP_CANCELLED 397, TRIP_REROUTED 104, TRIP_ARRIVED_AT_POINT 15, TRIP_UNLOADED 13, TRIP_LOADED 13, TRIP_VEHICLE_REASSIGNED 9, TRIP_STOP_ADDED 7, TRIP_DOWNTIME_RECORDED 5, TRIP_DRIVER_REASSIGNED 4, TRIP_WAYBILL_ISSUED 2, TRIP_RESCHEDULED 1, TRIP_DELIVERY_CONFIRMED 1 | ISHLATILMAGAN: TRIP_DEVIATION_DETECTED, TRIP_RESERVATION_EXPIRED, TRIP_TRAILER_REASSIGNED
    check ((((occurred_at_utc is null) and (occurrence_zone is null) and (occurrence_offset_seconds is null)) or ((occurred_at_utc is not null) and (occurrence_zone is not null) and (occurrence_offset_seconds is not null) and ((occurrence_offset_seconds >= '-64800') and (occurrence_offset_seconds <= 64800))))),
    check (source in ('DRIVER', 'DISPATCHER', 'PLANNING_SERVICE', 'TELEMATICS_SERVICE', 'SYSTEM')),
    -- source BAZADA: DISPATCHER 7595, PLANNING_SERVICE 1349, SYSTEM 1055, DRIVER 8 | ISHLATILMAGAN: TELEMATICS_SERVICE
    foreign key (trip_id) references trip(id)
);

create table trip_legacy_load_baseline
(
    id                      uuid not null,
    trip_id                 uuid not null,
    route_id                uuid not null,
    vehicle_id              uuid not null,
    actor_id                uuid not null,
    captured_trip_version   bigint not null,
    captured_route_version  bigint not null,
    assessment_basis_json   text not null,
    assessment_hash         text not null,
    proof_json              text not null,
    result_json             text not null,
    reference               text not null,
    reason                  text not null,
    original_json           text not null,
    payload_hash            text not null,
    recorded_at             timestamptz not null,
    primary key (id),
    check ((captured_route_version >= 0)),
    check ((captured_trip_version >= 0)),
    check ((payload_hash = encode(sha256(convert_to((((trip_id) || ':') || original_json), 'utf8'::name)), 'hex'))),
    check ((payload_hash ~ '^[a-f0-9]{64}$')),
    check (((length(btrim(reason)) >= 1) and (length(btrim(reason)) <= 2000))),
    check (((length(btrim(reference)) >= 1) and (length(btrim(reference)) <= 2000))),
    foreign key (actor_id) references app_user(id),
    foreign key (route_id) references route(id),
    foreign key (trip_id) references trip(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table trip_legacy_load_baseline_command
(
    operation_id    uuid not null,
    trip_id         uuid not null,
    actor_id        uuid not null,
    payload_hash    text not null,
    original_json   text not null,
    outcome         text not null,
    result_json     text not null,
    closure_reason  text,
    recorded_at     timestamptz not null,
    primary key (operation_id),
    check ((payload_hash = encode(sha256(convert_to((((trip_id) || ':') || original_json), 'utf8'::name)), 'hex'))),
    check (((outcome = 'not_executed') = (closure_reason is not null))),
    check (((closure_reason is null) or ((length(btrim(closure_reason)) >= 1) and (length(btrim(closure_reason)) <= 2000)))),
    check (outcome in ('APPLIED', 'NOT_EXECUTED')),
    -- outcome BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (trip_id) references trip(id)
);

create table trip_pending_reschedule
(
    id                      uuid not null,
    trip_id                 uuid not null,
    route_id                uuid not null,
    requested_departure_at  timestamp not null,
    requested_arrival_at    timestamp not null,
    vehicle_id              uuid not null,
    driver_id               uuid not null,
    reason                  text,
    requested_by            uuid not null,
    context_revision_id     uuid not null,
    trip_version            bigint not null,
    state                   varchar(16) not null,
    created_at              timestamptz not null,
    resolved_at             timestamptz,
    resolved_by             uuid,
    failure                 text,
    primary key (id)
);

create table trip_quantity_command
(
    id              uuid not null,
    trip_id         uuid not null,
    actor_id        uuid not null,
    payload_hash    text not null,
    original_json   text not null,
    outcome         text not null,
    closure_reason  text,
    recorded_at     timestamptz not null,
    primary key (id),
    check (outcome in ('APPLIED', 'NOT_EXECUTED')),
    -- outcome BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (trip_id) references trip(id)
);

create table trip_quantity_event
(
    id                     uuid not null,
    trip_id                uuid not null,
    route_id               uuid not null,
    manifest_id            uuid not null,
    allocation_id          uuid not null,
    request_id             uuid not null,
    position_id            uuid not null,
    point_id               uuid not null,
    action                 text not null,
    quantity_delta         numeric(18,6) not null,
    measurement_quantity   numeric(18,6) not null,
    unit_code              text not null,
    occurred_at            timestamptz not null,
    measurement_source_id  uuid not null,
    source_hash            text not null,
    actor_id               uuid not null,
    corrected_event_id     uuid,
    correction_version     bigint not null,
    reason                 text not null,
    recorded_at            timestamptz not null,
    primary key (id),
    check (action in ('LOAD', 'DELIVER', 'RETURN')),
    -- action BAZADA: jadval bo'sh
    check ((correction_version >= 0)),
    check ((measurement_quantity >= (0))),
    check (((length(btrim(reason)) >= 1) and (length(btrim(reason)) <= 2000))),
    check (unit_code in ('TONNE', 'PASSENGER')),
    -- unit_code BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (corrected_event_id) references trip_quantity_event(id),
    foreign key (measurement_source_id) references transport_execution_source_revision(id),
    foreign key (request_id) references transport_request(id),
    foreign key (route_id) references route(id),
    foreign key (trip_id) references trip(id),
    foreign key (point_id) references transport_route_stop_identity(id)
);

create table trip_quantity_outbox
(
    id           uuid not null,
    trip_id      uuid not null,
    event_json   jsonb not null,
    recorded_at  timestamptz not null,
    primary key (id),
    foreign key (id) references trip_quantity_event(id)
);

create table trip_resource_replacement_proof
(
    id                      uuid not null,
    operation_id            uuid not null,
    trip_id                 uuid not null,
    route_id                uuid not null,
    actor_id                uuid not null,
    captured_trip_version   bigint not null,
    captured_route_version  bigint not null,
    previous_vehicle_id     uuid not null,
    target_vehicle_id       uuid not null,
    parent_manifest_id      uuid not null,
    parent_assessment_hash  text not null,
    effective_at            timestamptz not null,
    recorded_at             timestamptz not null,
    assessment_basis_json   text not null,
    assessment_hash         text not null,
    proof_json              text not null,
    original_json           text not null,
    command_hash            text not null,
    before_json             jsonb not null,
    transaction_id          bigint not null,
    primary key (id),
    check ((assessment_hash ~ '^[a-f0-9]{64}$')),
    check ((captured_route_version >= 0)),
    check ((captured_trip_version >= 0)),
    check ((id = operation_id)),
    check ((previous_vehicle_id <> target_vehicle_id)),
    check ((command_hash ~ '^[a-f0-9]{64}$')),
    check ((parent_assessment_hash ~ '^[a-f0-9]{64}$')),
    foreign key (actor_id) references app_user(id),
    foreign key (operation_id) references transport_assignment_command(operation_id) deferrable initially deferred,
    foreign key (previous_vehicle_id) references transport_vehicle(id),
    foreign key (route_id) references route(id),
    foreign key (target_vehicle_id) references transport_vehicle(id),
    foreign key (trip_id) references trip(id)
);

create table trip_route_amendment
(
    id                      uuid not null,
    operation_id            uuid not null,
    trip_id                 uuid not null,
    route_id                uuid not null,
    revision                bigint not null,
    previous_id             uuid,
    base_manifest_id        uuid not null,
    captured_trip_version   bigint not null,
    captured_route_version  bigint not null,
    effective_at            timestamptz not null,
    actor_id                uuid not null,
    physical_hash           text not null,
    onboard_json            jsonb not null,
    qualification_json      jsonb not null,
    assessment_basis_json   text not null,
    assessment_hash         text not null,
    proof_json              text not null,
    future_sections_json    jsonb not null,
    result_json             text not null,
    reason                  text not null,
    recorded_at             timestamptz not null,
    primary key (id),
    check ((physical_hash ~ '^[a-f0-9]{64}$')),
    check (((length(btrim(reason)) >= 1) and (length(btrim(reason)) <= 2000))),
    check ((revision > 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (previous_id) references trip_route_amendment(id),
    foreign key (route_id) references route(id),
    foreign key (trip_id) references trip(id)
);

create table trip_route_amendment_document
(
    amendment_id      uuid not null,
    waybill_id        uuid not null,
    captured_version  bigint not null,
    captured_status   text not null,
    primary key (amendment_id, waybill_id),
    foreign key (amendment_id) references trip_route_amendment(id),
    foreign key (waybill_id) references waybill(id)
);

create table trip_route_amendment_gate
(
    id                  uuid not null,
    amendment_id        uuid not null,
    trip_id             uuid not null,
    target_version      bigint not null,
    point_id            uuid not null,
    action              text not null,
    actor_id            uuid not null,
    qualification_json  jsonb not null,
    safety_json         jsonb not null,
    recorded_at         timestamptz not null,
    primary key (id),
    check (action in ('ARRIVE', 'LOAD', 'UNLOAD', 'RETURN')),
    -- action BAZADA: jadval bo'sh
    foreign key (actor_id) references app_user(id),
    foreign key (amendment_id) references trip_route_amendment(id),
    foreign key (trip_id) references trip(id)
);

-- ---------------------------------------------------------------------
-- READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.
-- ---------------------------------------------------------------------
create table trip_route_effective_planning_manifest_latest
(
    id                     uuid,
    operation_id           uuid,
    route_id               uuid,
    vehicle_id             uuid,
    actor_id               uuid,
    recorded_at            timestamptz,
    assessment_basis_json  text,
    assessment_hash        varchar(64),
    proof_json             text
);

-- ---------------------------------------------------------------------
-- Foydalanuvchining qaysi bo'limga (department) biriktirilganini ko'rsatadi.
-- BITTA FOYDALANUVCHIDA BITTA BO'LIM bo'ladi (user_id unique). Bo'lim nomi
-- reference_data jadvalida catalog_type='DEPARTMENTS' bo'yicha turadi.
-- (Ilgari `user_department` deb atalardi — sxema ko'chirishda nomi o'zgargan.)
-- ---------------------------------------------------------------------
create table user_department
(
    id             uuid not null,
    created_at     timestamptz not null,
    department_id  uuid not null,
    updated_at     timestamptz not null,
    user_id        uuid not null,
    primary key (id)
);

-- ---------------------------------------------------------------------
-- FOYDALANUVCHI ROLLARI (bog'lovchi jadval): user_id, role.
-- Ilgari `app_user_role` deb atalardi.
-- ---------------------------------------------------------------------
create table user_role
(
    user_id  uuid not null,
    role     varchar(255),
    check (role in ('ADMIN', 'LOGISTICIAN', 'DISPATCHER', 'DRIVER', 'REQUEST_INITIATOR', 'FUEL_OPERATOR', 'MEDIC', 'MECHANIC', 'WORKSHOP_MASTER', 'ANALYST', 'HEAD_OF_DEPARTMENT', 'ACCOUNTANT', 'SECURITY_OFFICER', 'WAREHOUSE_OPERATOR', 'HEAD_OF_OPERATIONS', 'EXPLOITATION', 'OPERATIONS', 'FUEL_ATTENDANT', 'TRANSPORT_DEPARTMENT_HEAD', 'PTO')),
    -- role BAZADA: HEAD_OF_DEPARTMENT 579, REQUEST_INITIATOR 501, DRIVER 247, DISPATCHER 11, FUEL_OPERATOR 11, MECHANIC 10, MEDIC 6, HEAD_OF_OPERATIONS 4, WORKSHOP_MASTER 4, WAREHOUSE_OPERATOR 3, TRANSPORT_DEPARTMENT_HEAD 2, EXPLOITATION 2, ADMIN 2, PTO 2, FUEL_ATTENDANT 2, LOGISTICIAN 1, SECURITY_OFFICER 1, ANALYST 1, ACCOUNTANT 1 | ISHLATILMAGAN: OPERATIONS
    foreign key (user_id) references app_user(id)
);

-- ---------------------------------------------------------------------
-- Foydalanuvchining qaysi omborga biriktirilganini ko'rsatadi (yoqilg'i operatori,
-- ombor xodimi uchun). Bitta foydalanuvchida bitta ombor.
-- (Ilgari `user_warehouse` deb atalardi — sxema ko'chirishda nomi o'zgargan.)
-- ---------------------------------------------------------------------
create table user_warehouse
(
    id            uuid not null,
    created_at    timestamptz not null,
    updated_at    timestamptz not null,
    user_id       uuid not null,
    warehouse_id  uuid not null,
    primary key (id)
);

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
create table vehicle_accident
(
    id                       uuid not null,
    accident_number          varchar(32) not null,
    accident_type            varchar(32) not null,
    actual_repair_amount     numeric(18,2),
    created_at               timestamptz not null,
    created_by               varchar(128),
    currency                 varchar(8),
    damage_description       varchar(2000),
    description              varchar(2000),
    driver_paid_amount       numeric(18,2),
    estimated_damage_amount  numeric(18,2),
    factory_paid_amount      numeric(18,2),
    fatalities_count         integer,
    injuries_count           integer,
    insurance_claim_number   varchar(128),
    insurance_paid_amount    numeric(18,2),
    latitude                 numeric(10,7),
    location_name            varchar(512),
    longitude                numeric(10,7),
    occurred_at              timestamptz not null,
    police_report_number     varchar(128),
    repair_required          boolean not null,
    reported_at              timestamptz,
    resolution_notes         varchar(2000),
    resolved_at              timestamptz,
    severity                 varchar(32) not null,
    status                   varchar(32) not null,
    third_party_involved     boolean not null,
    updated_at               timestamptz not null,
    updated_by               varchar(128),
    version                  bigint not null,
    driver_id                uuid,
    trip_id                  uuid,
    vehicle_id               uuid not null,
    primary key (id),
    check (accident_type in ('DRIVER_FAULT', 'NATURAL_CAUSE', 'THIRD_PARTY_FAULT', 'OTHER')),
    -- accident_type BAZADA: jadval bo'sh
    check (severity in ('MINOR', 'MODERATE', 'SERIOUS', 'CRITICAL')),
    -- severity BAZADA: jadval bo'sh
    check (status in ('REPORTED', 'UNDER_REVIEW', 'INSURANCE_PROCESSING', 'REPAIR_IN_PROGRESS', 'RESOLVED', 'CLOSED', 'CANCELLED')),
    -- status BAZADA: jadval bo'sh
    foreign key (driver_id) references driver(id),
    foreign key (vehicle_id) references transport_vehicle(id),
    foreign key (trip_id) references trip(id)
);

-- ---------------------------------------------------------------------
-- Avariya va yuklangan fayl (attachment) o'rtasidagi bog'lovchi jadval —
-- avariya rasmlari va hujjatlari.
-- ---------------------------------------------------------------------
create table vehicle_accident_attachment
(
    id             uuid not null,
    description    varchar(1000),
    accident_id    uuid not null,
    attachment_id  uuid not null,
    primary key (id),
    foreign key (attachment_id) references attachment(id),
    foreign key (accident_id) references vehicle_accident(id)
);

-- ---------------------------------------------------------------------
-- MASHINA-HAYDOVCHI BIRIKTIRUVI (ko'p-ko'pga bog'lovchi jadval).
-- Faqat ikki ustun: vehicle_id, driver_id.
-- Bitta mashinaga bir nechta haydovchi biriktirilishi mumkin.
-- ASOSIY (bitta) haydovchi esa transport_vehicle.assigned_driver_id da.
-- ---------------------------------------------------------------------
create table vehicle_assigned_drivers
(
    vehicle_id  uuid not null,
    driver_id   uuid,
    foreign key (vehicle_id) references transport_vehicle(id)
);

-- ---------------------------------------------------------------------
-- MASHINA HUJJATLARI BO'YICHA ASOSIY JADVAL: sug'urta, ro'yxatdan o'tish
-- guvohnomasi, texnik ko'rik, ekologik sertifikat, ruxsatnoma, lizing shartnomasi.
-- Hujjat raqami, bergan organ (issuing_authority), berilgan sana (issued_at) va
-- AMAL QILISH MUDDATI (expiry_date).
-- MUDDATI TUGAYOTGAN HUJJATLAR expiry_date BO'YICHA OLINADI.
-- ---------------------------------------------------------------------
create table vehicle_document
(
    id                 uuid not null,
    created_at         timestamptz not null,
    created_by         varchar(256) not null,
    document_number    varchar(128) not null,
    document_type      varchar(32) not null,
    expiry_date        date,
    issued_at          date,
    issuing_authority  varchar(256),
    notes              varchar(512),
    vehicle_id         uuid not null,
    attachment_id      uuid,
    primary key (id),
    check (document_type in ('INSURANCE', 'REGISTRATION', 'TECHNICAL_INSPECTION', 'EMISSION_CERTIFICATE', 'PERMIT', 'OTHER', 'REGISTRATION_CERTIFICATE', 'INSURANCE_POLICY', 'TRANSPORT_PERMIT', 'LEASE_CONTRACT')),
    -- document_type BAZADA: REGISTRATION_CERTIFICATE 1 | ISHLATILMAGAN: INSURANCE, REGISTRATION, TECHNICAL_INSPECTION, EMISSION_CERTIFICATE, PERMIT, OTHER, INSURANCE_POLICY, TRANSPORT_PERMIT va yana 1 ta
    foreign key (attachment_id) references attachment(id) on delete restrict,
    foreign key (vehicle_id) references transport_vehicle(id)
);

-- ---------------------------------------------------------------------
-- Yoqilg'i sensorining mashinaga o'rnatilish tarixi: o'rnatilgan va olib tashlangan
-- vaqti, o'rnatish joyi, asosiy sensor ekanligi (primary_sensor).
-- removed_at bo'sh bo'lsa — sensor hozir o'rnatilgan holatda.
-- ---------------------------------------------------------------------
create table vehicle_fuel_sensor_installation
(
    id                 uuid not null,
    installed_at       timestamptz not null,
    installed_by       varchar(256) not null,
    mounting_position  varchar(64),
    primary_sensor     boolean not null,
    removed_at         timestamptz,
    removed_by         varchar(256),
    sensor_id          uuid not null,
    vehicle_id         uuid not null,
    primary key (id)
);

-- ---------------------------------------------------------------------
-- Mashina va GPS qurilmasi o'rtasidagi bog'lanish (device_id, unique_id).
-- XOM GPS YOZUVLARI (position_log) MASHINAGA SHU JADVAL ORQALI BOG'LANADI —
-- position_log.device_id = vehicle_gps.device_id.
-- ---------------------------------------------------------------------
create table vehicle_gps
(
    id                    uuid not null,
    created_at            timestamptz not null,
    device_id             bigint,
    driver_id             uuid,
    unique_id             varchar(64) not null,
    updated_at            timestamptz not null,
    vehicle_id            uuid not null,
    active                boolean not null,
    created_operation_id  uuid,
    managed_by_at_il      boolean not null,
    provider_connection   varchar(32) not null,
    version               bigint not null,
    unbound_at            timestamptz,
    verified_from         timestamptz,
    primary key (id)
);

-- ---------------------------------------------------------------------
-- Mashina ehtiyot qismlari: shina, akkumulyator, moy va havo filtri, tormoz
-- kolodkasi. O'rnatilgan sana va probeg, kutilgan xizmat muddati (expected_life_km,
-- expected_life_days), narxi.
-- status: INSTALLED, IN_STOCK, REPLACED, WORN.
-- ALMASHTIRISH VAQTI KELGAN QISMLAR o'rnatilgan probeg + expected_life_km ni
-- mashinaning hozirgi probegi bilan solishtirib topiladi.
-- ---------------------------------------------------------------------
create table vehicle_part
(
    id                             uuid not null,
    category                       varchar(16) not null,
    cost                           numeric(14,2),
    created_at                     timestamptz not null,
    currency                       varchar(8),
    current_odometer_km            numeric(14,3),
    expected_life_days             integer,
    expected_life_km               numeric(14,3),
    installed_at                   date,
    installed_at_km                numeric(14,3),
    name                           varchar(255) not null,
    notes                          varchar(2000),
    part_number                    varchar(128),
    status                         varchar(16) not null,
    updated_at                     timestamptz not null,
    vehicle_id                     uuid,
    version                        bigint not null,
    assessed_at                    timestamptz,
    assessed_by_id                 uuid,
    assessed_by_name               varchar(256),
    removal_branch_id              uuid,
    removal_defect                 varchar(2000),
    removal_repair_number          varchar(64),
    removal_vehicle_label          varchar(255),
    removed_at                     date,
    removed_at_km                  numeric(14,3),
    removed_by_id                  uuid,
    removed_by_name                varchar(256),
    repair_order_id                uuid,
    serial_number                  varchar(128),
    series                         varchar(128),
    unrepairable_conclusion        varchar(2000),
    write_off_act_id               uuid,
    current_engine_hours           numeric(14,3),
    expected_life_engine_hours     numeric(14,3),
    expected_life_months           integer,
    installed_at_engine_hours      numeric(14,3),
    primary_battery                boolean not null,
    replace_at_percent             numeric(5,2),
    service_rule_id                uuid,
    service_rule_name              varchar(255),
    tire_size                      varchar(64),
    tracking_enabled               boolean not null,
    warning_at_percent             numeric(5,2),
    accepted_to_warehouse_at       timestamptz,
    accepted_to_warehouse_by_id    uuid,
    accepted_to_warehouse_by_name  varchar(256),
    refurbished_from_part_id       uuid,
    refurbished_stock_id           uuid,
    repair_completion_notes        varchar(2000),
    repaired_at                    timestamptz,
    repaired_by_id                 uuid,
    repaired_by_name               varchar(256),
    primary key (id),
    check (category in ('ENGINE', 'TIRE', 'BATTERY', 'OIL_FILTER', 'AIR_FILTER', 'BRAKE_PAD', 'OTHER')),
    -- category BAZADA: TIRE 634, BATTERY 135 | ISHLATILMAGAN: ENGINE, OIL_FILTER, AIR_FILTER, BRAKE_PAD, OTHER
    check (status in ('INSTALLED', 'IN_STOCK', 'REPLACED', 'WORN', 'IN_REPAIR', 'REPAIRED', 'REFURBISHED', 'REUSED', 'UNREPAIRABLE', 'IN_WRITE_OFF', 'WRITTEN_OFF', 'DESTROYED', 'RECYCLED'))
    -- status BAZADA: INSTALLED 728, WORN 41 | ISHLATILMAGAN: IN_STOCK, REPLACED, IN_REPAIR, REPAIRED, REFURBISHED, REUSED, UNREPAIRABLE, IN_WRITE_OFF va yana 3 ta
);

-- ---------------------------------------------------------------------
-- Mashina rasmlari va ular qaysi tomondan olingani (FRONT, REAR, LEFT, RIGHT,
-- CABIN, VIN). Faylning o'zi attachment jadvalida.
-- ---------------------------------------------------------------------
create table vehicle_photo
(
    id             uuid not null,
    photo_type     varchar(64) not null,
    uploaded_at    timestamptz not null,
    attachment_id  uuid not null,
    vehicle_id     uuid not null,
    primary key (id),
    check (photo_type in ('FRONT', 'REAR', 'LEFT', 'RIGHT', 'CABIN', 'VIN')),
    -- photo_type BAZADA: FRONT 2, REAR 1 | ISHLATILMAGAN: LEFT, RIGHT, CABIN, VIN
    foreign key (attachment_id) references attachment(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

-- ---------------------------------------------------------------------
-- Mashina davlat raqamining o'zgarish tarixi. is_current=true bo'lgan qator —
-- hozirgi raqam (u transport_vehicle.plate_number bilan bir xil bo'lishi kerak).
-- ESKI RAQAM BO'YICHA MASHINA QIDIRILSA SHU JADVALDAN OLINADI.
-- ---------------------------------------------------------------------
create table vehicle_plate_history
(
    id            uuid not null,
    assigned_at   timestamptz not null,
    changed_by    varchar(256),
    is_current    boolean not null,
    plate_number  varchar(32) not null,
    removed_at    timestamptz,
    vehicle_id    uuid not null,
    primary key (id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

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
create table vehicle_reference_data_fuel_type
(
    vehicle_id          uuid not null,
    reference_data__id  uuid not null,
    foreign key (vehicle_id) references transport_vehicle(id),
    foreign key (reference_data__id) references reference_data(id)
);

-- ---------------------------------------------------------------------
-- Ta'mirlash ishlari: qaysi tugun (ENGINE, BRAKES, TIRES, BATTERY, ELECTRICAL,
-- CHASSIS), ustuvorligi, taxminiy narxi, bekor turish soati (downtime_hours).
-- status: OPEN, IN_PROGRESS, WAITING_PARTS, COMPLETED, CANCELLED.
-- blocks_release=true bo'lsa — MASHINA REYSGA CHIQARILMAYDI.
-- ---------------------------------------------------------------------
create table vehicle_repair
(
    id                           uuid not null,
    blocks_release               boolean not null,
    component_category           varchar(64) not null,
    created_at                   timestamptz not null,
    description                  varchar(2000),
    downtime_hours               numeric(14,3),
    estimated_cost               numeric(14,2),
    opened_at                    timestamptz not null,
    opened_by                    varchar(255) not null,
    priority                     varchar(64) not null,
    status                       varchar(64) not null,
    title                        varchar(255) not null,
    updated_at                   timestamptz not null,
    vehicle_id                   uuid not null,
    trip_id                      uuid,
    waybill_id                   uuid,
    repair_location_id           uuid,
    diagnosis                    varchar(2000),
    required_parts               varchar(2000),
    work_performed               varchar(2000),
    actual_downtime_hours        numeric(14,3),
    decision                     varchar(32) not null,
    replacement_vehicle_id       uuid,
    dispatcher_comment           varchar(2000),
    decision_at                  timestamptz,
    decision_by                  varchar(255),
    completed_at                 timestamptz,
    completed_by                 varchar(255),
    arm_diagnosed_at             timestamptz,
    arm_diagnosed_by             varchar(255),
    arm_diagnosis                varchar(2000),
    branch_id                    uuid,
    defect_area                  varchar(255),
    defect_reason                varchar(2000),
    detected_at                  timestamptz,
    final_conclusion             varchar(2000),
    initial_diagnosis            varchar(2000),
    inspection_context           varchar(64),
    mechanic_comment             varchar(2000),
    mechanic_recheck_decision    varchar(32),
    mechanic_recheck_notes       varchar(2000),
    mechanic_rechecked_at        timestamptz,
    mechanic_rechecked_by        varchar(255),
    received_by_arm_at           timestamptz,
    repair_number                varchar(64),
    repaired_at                  timestamptz,
    repaired_by                  varchar(255),
    rework_count                 integer not null,
    sent_to_arm_at               timestamptz,
    technical_inspection_id      uuid,
    technical_suspended_at       timestamptz,
    unable_to_repair_at          timestamptz,
    unable_to_repair_by          varchar(255),
    unable_to_repair_reason      varchar(2000),
    arm_approved_at              timestamptz,
    arm_approved_by_id           uuid,
    arm_approved_by_name         varchar(255),
    chief_mechanic_completed_at  timestamptz,
    chief_mechanic_diagnosed_at  timestamptz,
    chief_mechanic_id            uuid,
    chief_mechanic_name          varchar(255),
    driver_id                    uuid,
    driver_name                  varchar(255),
    estimated_completion_time    timestamptz,
    estimated_start_time         timestamptz,
    final_arm_approved_at        timestamptz,
    final_arm_approved_by_id     uuid,
    final_arm_approved_by_name   varchar(255),
    rejection_reason             varchar(2000),
    signature_data               varchar(4000),
    signature_id                 varchar(255),
    signed_at                    timestamptz,
    signed_by                    varchar(255),
    version                      bigint not null,
    primary key (id),
    check (component_category in ('ENGINE', 'BRAKES', 'TIRES', 'BATTERY', 'ELECTRICAL', 'CHASSIS', 'OTHER')),
    -- component_category BAZADA: BRAKES 8, OTHER 5, TIRES 4, ENGINE 4 | ISHLATILMAGAN: BATTERY, ELECTRICAL, CHASSIS
    check (decision in ('UNDECIDED', 'CONTINUE_SAME_WAYBILL', 'REPLACE_VEHICLE', 'NEW_WAYBILL', 'CANCEL_TRIP')),
    -- decision BAZADA: UNDECIDED 21 | ISHLATILMAGAN: CONTINUE_SAME_WAYBILL, REPLACE_VEHICLE, NEW_WAYBILL, CANCEL_TRIP
    check (((inspection_context is null) or ((inspection_context) = any (array[('pre_trip'), ('in_trip'), ('post_trip'), ('direct')])))),
    check (((mechanic_recheck_decision is null) or ((mechanic_recheck_decision) = any ((array['passed', 'failed', 'not_performed'])[])))),
    check (priority in ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    -- priority BAZADA: HIGH 18, MEDIUM 2, CRITICAL 1 | ISHLATILMAGAN: LOW
    check (status in ('CREATED', 'PENDING_ARM_APPROVAL', 'APPROVED_BY_ARM', 'ARM_DIAGNOSIS', 'WAITING_PARTS_APPROVAL', 'PARTS_APPROVED', 'PARTS_ISSUED', 'REPAIR_IN_PROGRESS', 'COMPLETED_BY_ARM', 'PENDING_ARM_CLOSURE', 'ARM_CLOSED', 'PENDING_FINAL_MECHANIC_INSPECTION', 'FINAL_INSPECTION_PASSED', 'FINAL_INSPECTION_FAILED', 'CLOSED', 'REJECTED', 'NEW', 'DIAGNOSING', 'WAITING_PARTS', 'REPAIRING', 'REPAIRED', 'NOT_REPAIRED', 'COMPLETED', 'CANCELLED', 'OPEN', 'IN_PROGRESS'))
    -- status BAZADA: CLOSED 16, REPAIR_IN_PROGRESS 2, CANCELLED 1, REJECTED 1, PENDING_ARM_APPROVAL 1 | ISHLATILMAGAN: CREATED, APPROVED_BY_ARM, ARM_DIAGNOSIS, WAITING_PARTS_APPROVAL, PARTS_APPROVED, PARTS_ISSUED, COMPLETED_BY_ARM, PENDING_ARM_CLOSURE va yana 13 ta
);

create table vehicle_repair_team_members
(
    repair_id         uuid not null,
    assigned_at       timestamptz,
    employee_id       uuid,
    employee_name     varchar(255),
    id                varchar(255),
    worker_specialty  varchar(255),
    foreign key (repair_id) references vehicle_repair(id)
);

create table vehicle_repair_work_items
(
    repair_id    uuid not null,
    category     varchar(255),
    completed    boolean,
    description  varchar(255),
    id           varchar(255),
    foreign key (repair_id) references vehicle_repair(id)
);

-- ---------------------------------------------------------------------
-- Mashina holatining o'zgarish tarixi: oldingi va yangi status, kim o'zgartirgani,
-- sababi va vaqti.
-- MASHINA QANCHA VAQT IN_MAINTENANCE YOKI BLOCKED HOLATDA TURGANI SHU JADVALDAN
-- hisoblanadi.
-- ---------------------------------------------------------------------
create table vehicle_status_history
(
    id               uuid not null,
    changed_at       timestamptz not null,
    changed_by       varchar(256) not null,
    new_status       varchar(32) not null,
    previous_status  varchar(32),
    reason           varchar(512),
    vehicle_id       uuid not null,
    primary key (id),
    check (new_status in ('ACTIVE', 'RESERVED', 'IN_OPERATION', 'IN_MAINTENANCE', 'BLOCKED', 'DECOMMISSIONED')),
    -- new_status BAZADA: ACTIVE 21, BLOCKED 3, IN_MAINTENANCE 1, DECOMMISSIONED 1 | ISHLATILMAGAN: RESERVED, IN_OPERATION
    check (previous_status in ('ACTIVE', 'RESERVED', 'IN_OPERATION', 'IN_MAINTENANCE', 'BLOCKED', 'DECOMMISSIONED')),
    -- previous_status BAZADA: IN_MAINTENANCE 2, BLOCKED 2, ACTIVE 1, DECOMMISSIONED 1; NULL 1 | ISHLATILMAGAN: RESERVED, IN_OPERATION
    foreign key (vehicle_id) references transport_vehicle(id)
);

-- ---------------------------------------------------------------------
-- Reysdan oldingi (PRE_TRIP) va reysdan keyingi (POST_TRIP) texnik ko'rik.
-- Natija: FIT (yaroqli), LIMITED (cheklangan), BLOCKED (bloklangan). probeg,
-- ko'rikni o'tkazgan shaxs, izohlar. Rasmlar ALOHIDA vehicle_technical_inspection_photo jadvalida.
-- Rasmlari vehicle_technical_inspection_photo jadvalida ham.
-- ---------------------------------------------------------------------
create table vehicle_technical_inspection
(
    id                         uuid not null,
    created_at                 timestamptz not null,
    inspected_at               timestamptz not null,
    inspected_by               varchar(255) not null,
    inspection_type            varchar(32) not null,
    notes                      varchar(2000),
    probeg                     bigint,
    status                     varchar(32) not null,
    to_inspected_at            timestamptz,
    trip_id                    uuid,
    updated_at                 timestamptz not null,
    vehicle_id                 uuid not null,
    fuel_at_inspection_liters  numeric(12,3),
    fuel_consumed_liters       numeric(12,3),
    waybill_id                 uuid,
    moto_hours                 numeric(14,3),
    calculation_mode           varchar(32),
    pre_trip_motohours         numeric(10,2),
    post_trip_motohours        numeric(10,2),
    motohours_worked           numeric(10,2),
    motohours_rate_norm        numeric(6,2),
    crane_capacity_tons        numeric(5,2),
    recommended_fuel_liters    numeric(12,3),
    ev_mileage                 numeric(14,3),
    hev_mileage                numeric(14,3),
    initial_ev_mileage         numeric(14,3),
    final_ev_mileage           numeric(14,3),
    initial_hev_mileage        numeric(14,3),
    final_hev_mileage          numeric(14,3),
    primary key (id),
    check (inspection_type in ('PRE_TRIP', 'POST_TRIP')),
    -- inspection_type BAZADA: PRE_TRIP 4073, POST_TRIP 3671
    check (status in ('FIT', 'LIMITED', 'BLOCKED'))
    -- status BAZADA: FIT 7579, BLOCKED 165 | ISHLATILMAGAN: LIMITED
);

create table vehicle_technical_inspection_correction
(
    id              uuid not null,
    inspection_id   uuid not null,
    version         bigint not null,
    actor_id        uuid not null,
    actor_name      text not null,
    recorded_at     timestamptz not null,
    transaction_id  bigint not null,
    reason          text not null,
    before_json     jsonb not null,
    after_json      jsonb not null,
    primary key (id),
    check ((version > 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (inspection_id) references vehicle_technical_inspection(id)
);

-- ---------------------------------------------------------------------
-- Texnik ko'rik rasmlari: mashina (VEHICLE) yoki taxometr/probeg (TACHOMETER)
-- rasmi. Faylning o'zi attachment jadvalida.
-- ---------------------------------------------------------------------
create table vehicle_technical_inspection_photo
(
    id             uuid not null,
    photo_type     varchar(32) not null,
    uploaded_at    timestamptz not null,
    attachment_id  uuid not null,
    inspection_id  uuid not null,
    primary key (id),
    check (photo_type in ('VEHICLE', 'TACHOMETER')),
    -- photo_type BAZADA: VEHICLE 2109, TACHOMETER 116
    foreign key (attachment_id) references attachment(id),
    foreign key (inspection_id) references vehicle_technical_inspection(id)
);

-- ---------------------------------------------------------------------
-- MASHINANING HOZIRGI (OXIRGI) HOLATI — bitta mashinaga bitta qator
-- (vehicle_id birlamchi kalit). Oxirgi koordinata, tezlik, probeg, yoqilg'i sathi,
-- dvigatel holati, bekor turish (idle_time_seconds) va harakat vaqti, hozirgi reys
-- va marshrut, marshrutdan chetlanish (deviation_active) va to'xtash (stop_active)
-- belgilari.
-- MASHINA HOZIR QAYERDA / QANDAY HOLATDA SO'RALSA SHU JADVALDAN OLINADI —
-- katta telematics_event jadvalini skanerlash SHART EMAS.
-- ---------------------------------------------------------------------
create table vehicle_telemetry_state
(
    vehicle_id                  uuid not null,
    created_at                  timestamptz not null,
    current_route_id            uuid,
    current_trip_id             uuid,
    deviation_active            boolean not null,
    deviation_threshold_meters  integer,
    device_id                   varchar(128),
    idle_time_seconds           bigint not null,
    last_engine_on              boolean,
    last_event_at               timestamptz,
    last_fuel_level             numeric(10,3),
    last_heading                numeric(10,3),
    last_latitude               numeric(10,7),
    last_longitude              numeric(10,7),
    last_odometer_km            numeric(14,3),
    last_speed_kph              numeric(10,3),
    last_speed_violation_at     timestamptz,
    moving_time_seconds         bigint not null,
    route_points_json           text,
    stop_active                 boolean not null,
    stop_candidate_since        timestamptz,
    trip_actual_distance_km     numeric(14,3) not null,
    updated_at                  timestamptz not null,
    version                     bigint not null,
    primary key (vehicle_id)
);

create table vehicle_tire_norm
(
    id                          uuid not null,
    created_at                  timestamptz not null,
    expected_life_days          integer,
    expected_life_engine_hours  numeric(14,3),
    expected_life_km            numeric(14,3),
    expected_life_months        integer,
    source                      varchar(16) not null,
    tire_size                   varchar(64) not null,
    updated_at                  timestamptz not null,
    vehicle_id                  uuid not null,
    version                     bigint not null,
    primary key (id),
    check (source in ('REFERENCE', 'MANUAL'))
    -- source BAZADA: MANUAL 231 | ISHLATILMAGAN: REFERENCE
);

create table vehicle_usage_reading
(
    id                    uuid not null,
    absolute_value        numeric(20,3) not null,
    branch_id             uuid,
    counter               varchar(32) not null,
    counter_offset        numeric(20,3) not null,
    epoch                 bigint not null,
    event_id              varchar(200) not null,
    event_type            varchar(32) not null,
    lifetime_value        numeric(20,3) not null,
    observed_at           timestamptz not null,
    quality               varchar(32) not null,
    reason                varchar(2000),
    received_at           timestamptz not null,
    recorded_by           varchar(255) not null,
    reference_reading_id  uuid,
    revision              bigint not null,
    source                varchar(100) not null,
    vehicle_id            uuid not null,
    primary key (id),
    check (counter in ('ODOMETER_KM', 'ENGINE_HOURS')),
    -- counter BAZADA: ODOMETER_KM 1256, ENGINE_HOURS 70
    check (event_type in ('READING', 'CORRECTION', 'REPLACEMENT')),
    -- event_type BAZADA: READING 1326 | ISHLATILMAGAN: CORRECTION, REPLACEMENT
    check (quality in ('CONFIRMED', 'QUARANTINED')),
    -- quality BAZADA: CONFIRMED 1260, QUARANTINED 66
    foreign key (reference_reading_id) references vehicle_usage_reading(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table waiting_claim
(
    id           uuid not null,
    trip_id      uuid not null,
    contract_id  uuid not null,
    branch_id    uuid not null,
    primary key (id),
    foreign key (branch_id) references reference_data(id),
    foreign key (trip_id) references trip(id)
);

create table waiting_claim_event
(
    operation_id  uuid not null,
    claim_id      uuid not null,
    actor_id      uuid not null,
    revision      bigint not null,
    action        text not null,
    state         text not null,
    original      jsonb not null,
    snapshot      jsonb not null,
    hash          text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    check ((revision > 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (claim_id) references waiting_claim(id)
);

create table waiting_closed_operation
(
    operation_id  uuid not null,
    actor_id      uuid not null,
    branch_id     uuid not null,
    claim_id      uuid,
    kind          text not null,
    original      jsonb not null,
    reason        text not null,
    closed_at     timestamptz not null,
    primary key (operation_id),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id)
);

create table waiting_contract_policy
(
    operation_id  uuid not null,
    contract_id   uuid not null,
    branch_id     uuid not null,
    carrier_id    uuid not null,
    actor_id      uuid not null,
    revision      bigint not null,
    original      jsonb not null,
    document      jsonb not null,
    hash          text not null,
    recorded_at   timestamptz not null,
    primary key (operation_id),
    check ((revision > 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (branch_id) references reference_data(id),
    foreign key (carrier_id) references carrier(id)
);

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
create table waybill
(
    id                        uuid not null,
    actual_departure_at       timestamptz,
    actual_return_at          timestamptz,
    attachment_id             uuid,
    cancellation_reason       varchar(1000),
    cargo_description         varchar(1000),
    cargo_weight_tons         numeric(12,3),
    closed_at                 timestamptz,
    closed_by                 varchar(128),
    comment                   text,
    created_at                timestamptz not null,
    created_by                varchar(128) not null,
    driver_id                 uuid not null,
    driver_talon_number       varchar(64),
    emergency_dispatch        boolean not null,
    emergency_reason          varchar(1000),
    fuel_at_departure_liters  numeric(12,3),
    fuel_at_return_liters     numeric(12,3),
    fuel_consumed_liters      numeric(12,3),
    fuel_issued_liters        numeric(12,3),
    fuel_norm_liters          numeric(12,3),
    generated_document_id     uuid,
    issue_date                date not null,
    issued_at                 timestamptz,
    issued_by                 varchar(128),
    kind                      varchar(255),
    odometer_end_km           numeric(14,3),
    odometer_start_km         numeric(14,3),
    planned_departure_at      timestamptz not null,
    planned_return_at         timestamptz not null,
    post_mech_inspection_id   uuid,
    post_mech_notes           varchar(500),
    post_mech_performed_at    timestamptz,
    post_mech_performed_by    varchar(128),
    post_mech_result          varchar(16),
    post_med_inspection_id    uuid,
    post_med_notes            varchar(500),
    post_med_performed_at     timestamptz,
    post_med_performed_by     varchar(128),
    post_med_result           varchar(16),
    pre_mech_inspection_id    uuid,
    pre_mech_notes            varchar(500),
    pre_mech_performed_at     timestamptz,
    pre_mech_performed_by     varchar(128),
    pre_mech_result           varchar(16),
    pre_med_inspection_id     uuid,
    pre_med_notes             varchar(500),
    pre_med_performed_at      timestamptz,
    pre_med_performed_by      varchar(128),
    pre_med_result            varchar(16),
    ref_id                    uuid,
    ref_type                  varchar(255),
    route_id                  uuid,
    status                    varchar(16) not null,
    trailer_id                uuid,
    transport_request_id      uuid,
    trip_id                   uuid,
    updated_at                timestamptz not null,
    updated_by                varchar(128) not null,
    vehicle_id                uuid not null,
    version                   bigint not null,
    waybill_number            varchar(64) not null,
    waybill_type              varchar(24) not null,
    branch_id                 uuid,
    moto_hours_end            numeric(14,3),
    moto_hours_start          numeric(14,3),
    attendant_notes           varchar(500),
    fuel_attendant_id         uuid,
    fuel_attendant_name       varchar(128),
    fuel_recommendation       varchar(128),
    fuel_type                 varchar(64),
    fueled_at                 timestamptz,
    fuel_calculated_by_norm   numeric(12,3),
    fuel_rate_norm            numeric(12,3),
    taksirovka_calculated_at  timestamptz,
    taksirovka_calculated_by  varchar(128),
    taksirovka_formula        varchar(255),
    outbound_km               numeric(10,2),
    outbound_tons             numeric(10,2),
    inbound_km                numeric(10,2),
    inbound_tons              numeric(10,2),
    cargo_ton_km              numeric(14,3),
    calculation_mode          varchar(32),
    pre_trip_motohours        numeric(10,2),
    post_trip_motohours       numeric(10,2),
    motohours_worked          numeric(10,2),
    motohours_rate_norm       numeric(6,2),
    crane_capacity_tons       numeric(5,2),
    duty_hours                numeric(8,2),
    norm_source               varchar(32),
    passenger_count           integer,
    customer_department_id    uuid,
    customer_department       varchar(256),
    fuel_warehouse_id         uuid,
    fuel_warehouse_name       varchar(256),
    is_shift                  boolean not null,
    work_mode                 varchar(64),
    freight_recorded_at       timestamptz,
    ev_mileage_start          numeric(14,3),
    ev_mileage_end            numeric(14,3),
    hev_mileage_start         numeric(14,3),
    hev_mileage_end           numeric(14,3),
    initial_ev_mileage        numeric(14,3),
    final_ev_mileage          numeric(14,3),
    initial_hev_mileage       numeric(14,3),
    final_hev_mileage         numeric(14,3),
    fuel_norm_rate            numeric(10,2),
    fuel_start                numeric(12,3),
    fuel_given                numeric(12,3),
    fuel_end                  numeric(12,3),
    actual_fuel               numeric(12,3),
    norm_fuel                 numeric(12,3),
    economy_fuel              numeric(12,3),
    excess_fuel               numeric(12,3),
    primary key (id),
    check (post_mech_result in ('PASSED', 'FAILED', 'NOT_PERFORMED')),
    -- post_mech_result BAZADA: PASSED 3288, NOT_PERFORMED 1024; NULL 1 | ISHLATILMAGAN: FAILED
    check (post_med_result in ('PASSED', 'FAILED', 'NOT_PERFORMED')),
    -- post_med_result BAZADA: NOT_PERFORMED 3624; NULL 1 | ISHLATILMAGAN: PASSED, FAILED
    check (pre_mech_result in ('PASSED', 'FAILED', 'NOT_PERFORMED')),
    -- pre_mech_result BAZADA: PASSED 3889, NOT_PERFORMED 530 | ISHLATILMAGAN: FAILED
    check (pre_med_result in ('PASSED', 'FAILED', 'NOT_PERFORMED')),
    -- pre_med_result BAZADA: PASSED 3765, NOT_PERFORMED 654 | ISHLATILMAGAN: FAILED
    check (status in ('DRAFT', 'ISSUED', 'IN_USE', 'RETURNED', 'CLOSED', 'CANCELLED')),
    -- status BAZADA: CLOSED 2765, RETURNED 638, CANCELLED 398, DRAFT 326, IN_USE 195, ISSUED 97
    check (waybill_type in ('LOCAL', 'LONG_HAUL', 'CRANE'))
    -- waybill_type BAZADA: LOCAL 4015, LONG_HAUL 256, CRANE 148
);

create table waybill_companion
(
    waybill_id       uuid not null,
    full_name        varchar(256) not null,
    sequence_number  integer not null,
    user_id          uuid,
    department_id    uuid,
    department_name  varchar(500),
    position         varchar(128),
    phone            varchar(32),
    check (((user_id is not null) or ((department_id is not null) and (nullif(btrim((department_name)), '') is not null) and (nullif(btrim(("position")), '') is not null) and (nullif(btrim((full_name)), '') is not null)))),
    foreign key (waybill_id) references waybill(id)
);

create table waybill_customer_department
(
    id               uuid not null,
    department_id    uuid,
    department_name  varchar(256),
    manager_name     varchar(256),
    sequence_number  integer not null,
    waybill_id       uuid not null,
    primary key (id)
);

create table waybill_document
(
    waybill_id       uuid not null,
    attachment_id    uuid,
    comment          varchar(1000),
    document_date    date,
    document_number  varchar(128),
    document_type    varchar(32) not null,
    check (document_type in ('WAYBILL', 'TTN', 'TRAVEL_PERMISSION', 'SERVICE_MEMO', 'WAREHOUSE_DOCUMENT', 'INVOICE', 'OTHER')),
    -- document_type BAZADA: TTN 1 | ISHLATILMAGAN: WAYBILL, TRAVEL_PERMISSION, SERVICE_MEMO, WAREHOUSE_DOCUMENT, INVOICE, OTHER
    foreign key (waybill_id) references waybill(id)
);

create table waybill_fueling
(
    waybill_id        uuid not null,
    fueling_id        uuid not null,
    occurred_at       timestamptz,
    quantity          numeric(14,3) not null,
    fuel_type         varchar(64),
    warehouse_id      uuid,
    external_station  boolean,
    attendant         varchar(256),
    attendant_id      uuid,
    notes             varchar(500),
    recorded_at       timestamptz not null,
    updated_at        timestamptz not null,
    primary key (waybill_id, fueling_id),
    check (((external_station is distinct from true) or (warehouse_id is null))),
    check ((quantity >= (0))),
    foreign key (waybill_id) references waybill(id)
);

-- ---------------------------------------------------------------------
-- Yo'l varaqasi RAQAMLARINI berish hisoblagichi: varaqa turi bo'yicha
-- oxirgi berilgan va keyingi raqam, boshlang'ich raqam va raqam uzunligi.
-- Bu sozlama jadvali — varaqalarning O'ZI waybill da.
-- ---------------------------------------------------------------------
create table waybill_numbering
(
    id                  uuid not null,
    business_date       date not null,
    comment             varchar(500),
    created_at          timestamptz not null,
    created_by          varchar(200) not null,
    last_issued_number  varchar(32),
    next_number         bigint not null,
    number_width        integer not null,
    starting_number     bigint not null,
    updated_at          timestamptz not null,
    version             bigint not null,
    waybill_type        varchar(32) not null,
    primary key (id),
    check (waybill_type in ('LOCAL', 'LONG_HAUL', 'CRANE'))
    -- waybill_type BAZADA: LOCAL 80, CRANE 44, LONG_HAUL 41
);

-- ---------------------------------------------------------------------
-- YO'L VARAQASIDAGI TOPSHIRIQLAR — bitta varaqa ichidagi yuk tashish
-- qatorlari. Yuk nomi va og'irligi (tonna), mijoz, yuklash va tushirish
-- manzili, masofa (distance_km), reyslar soni, ton-km.
-- DIQQAT: bu waybill'ning O'ZI EMAS. "Nechta yo'l varaqasi bor?" ->
-- waybill; "topshiriqlar/yuklar nechta?" -> SHU jadval.
-- ---------------------------------------------------------------------
create table waybill_task
(
    waybill_id          uuid not null,
    cargo_name          varchar(1000),
    cargo_weight_tons   numeric(12,3),
    customer_name       varchar(256),
    distance_km         numeric(14,3),
    loading_location    varchar(512),
    scheduled_at        timestamptz,
    sequence_number     integer not null,
    trip_count          integer,
    unloading_location  varchar(512),
    document_number     varchar(128),
    cargo_ton_km        numeric(14,3),
    measurement_basis   varchar(16),
    check (measurement_basis in ('TOTAL', 'PER_RUN')),
    -- measurement_basis BAZADA: yo'q; NULL 1 | ISHLATILMAGAN: TOTAL, PER_RUN
    foreign key (waybill_id) references waybill(id)
);

create table web_push_delivery
(
    id                uuid not null,
    attempts          integer not null,
    created_at        timestamptz not null,
    next_attempt_at   timestamptz not null,
    notification_id   uuid not null,
    subscription_id   uuid not null,
    accepted_at       timestamptz,
    delivered_at      timestamptz,
    last_http_status  integer,
    state             varchar(32) not null,
    primary key (id),
    foreign key (notification_id) references notification(id) on delete cascade,
    foreign key (subscription_id) references web_push_subscription(id) on delete cascade
);

create table web_push_delivery_history
(
    delivery_id      uuid not null,
    notification_id  uuid not null,
    attempts         integer not null,
    state            varchar(32) not null,
    http_status      integer,
    accepted_at      timestamptz,
    recorded_at      timestamptz not null,
    primary key (delivery_id, attempts, state),
    foreign key (notification_id) references notification(id)
);

create table web_push_subscription
(
    id             uuid not null,
    created_at     timestamptz not null,
    endpoint       varchar(2048) not null,
    endpoint_hash  varchar(64) not null,
    user_id        uuid not null,
    primary key (id),
    foreign key (user_id) references app_user(id) on delete cascade
);

create table weighing
(
    id               uuid not null,
    created_at       timestamptz not null,
    created_by       uuid,
    driver_id        uuid,
    gross_weight_kg  numeric(12,3),
    net_weight_kg    numeric(12,3),
    notes            varchar(1000),
    operator_id      uuid,
    operator_name    varchar(256),
    scale_number     varchar(64),
    shipment_id      uuid,
    status           varchar(16) not null,
    tare_weight_kg   numeric(12,3),
    trip_id          uuid,
    updated_at       timestamptz,
    vehicle_id       uuid not null,
    waybill_id       uuid,
    weighed_at       timestamptz not null,
    weighing_number  varchar(64) not null,
    primary key (id),
    check (status in ('DRAFT', 'CONFIRMED', 'CANCELLED'))
    -- status BAZADA: jadval bo'sh
);

create table wms_shipment_projection
(
    shipment_id               uuid not null,
    destination               varchar(240) not null,
    origin                    varchar(240) not null,
    ready_for_transport       boolean not null,
    shipment_number           varchar(100) not null,
    source_revision           bigint not null,
    updated_at                timestamptz not null,
    batch_id                  uuid,
    branch_id                 uuid,
    event_id                  uuid,
    order_id                  uuid,
    product_id                uuid,
    quality_requirement       varchar(32),
    quality_source_id         varchar(128),
    quantity                  numeric(30,9),
    schema_version            varchar(32),
    site_id                   uuid,
    source_contract_revision  bigint,
    source_id                 varchar(128),
    source_status             varchar(64),
    unit                      varchar(64),
    primary key (shipment_id)
);

create table wms_shipment_receipt
(
    event_id                  uuid not null,
    received_at               timestamptz not null,
    shipment_id               uuid not null,
    source_revision           bigint not null,
    status                    varchar(20) not null,
    source_contract_revision  bigint,
    original                  jsonb,
    source_id                 varchar(128),
    schema_version            varchar(32),
    idempotency_key           text,
    payload_hash              varchar(64),
    reason                    text,
    primary key (event_id)
    -- status BAZADA: jadval bo'sh
);

create table yard_correction_review
(
    id              uuid not null,
    measurement_id  uuid not null,
    version         bigint not null,
    action          text not null,
    reference       text not null,
    reason          text not null,
    operation_id    text not null,
    actor_id        uuid not null,
    recorded_at     timestamptz not null,
    primary key (id),
    check (action in ('APPROVE', 'REJECT', 'REVOKE')),
    -- action BAZADA: jadval bo'sh
    check ((btrim(reason) <> '')),
    check ((btrim(reference) <> '')),
    check ((version > 0)),
    foreign key (actor_id) references app_user(id),
    foreign key (measurement_id) references yard_measurement(id)
);

create table yard_device_binding
(
    id                    uuid not null,
    version               bigint not null,
    scale_id              uuid not null,
    site_id               uuid not null,
    branch_id             uuid not null,
    service_user_id       uuid not null,
    device_reference      text not null,
    unit                  text not null,
    valid_from            timestamptz not null,
    valid_to              timestamptz not null,
    max_delay_seconds     bigint not null,
    regulation_reference  text not null,
    state                 text not null,
    created_by            uuid not null,
    approved_by           uuid,
    created_at            timestamptz not null,
    primary key (id),
    check ((valid_to > valid_from)),
    check (((state <> 'approved') or ((approved_by is not null) and (approved_by <> created_by)))),
    check ((max_delay_seconds > 0)),
    check (state in ('DRAFT', 'APPROVED', 'REVOKED')),
    -- state BAZADA: jadval bo'sh
    check (unit in ('KG', 'TONNE')),
    -- unit BAZADA: jadval bo'sh
    foreign key (approved_by) references app_user(id),
    foreign key (created_by) references app_user(id),
    foreign key (scale_id) references yard_scale(id),
    foreign key (service_user_id) references app_user(id),
    foreign key (site_id) references yard_site(id)
);

create table yard_device_binding_history
(
    id             uuid not null,
    binding_id     uuid not null,
    action         text not null,
    reason         text not null,
    snapshot_json  text not null,
    actor_id       uuid not null,
    recorded_at    timestamptz not null,
    primary key (id),
    check ((btrim(reason) <> '')),
    foreign key (actor_id) references app_user(id),
    foreign key (binding_id) references yard_device_binding(id)
);

create table yard_device_receipt
(
    id                     uuid not null,
    binding_id             uuid not null,
    binding_version        bigint not null,
    measurement_id         uuid not null,
    source_measurement_id  text not null,
    request_hash           varchar(64) not null,
    source_payload_hash    varchar(64) not null,
    request_json           text not null,
    actor_id               uuid not null,
    recorded_at            timestamptz not null,
    primary key (id),
    foreign key (actor_id) references app_user(id),
    foreign key (binding_id) references yard_device_binding(id),
    foreign key (measurement_id) references yard_measurement(id)
);

create table yard_event
(
    id                           uuid not null,
    action                       varchar(32) not null,
    actor_id                     uuid not null,
    actor_name                   varchar(256) not null,
    occurred_at                  timestamptz not null,
    operation_id                 varchar(128) not null,
    previous_data_json           text,
    previous_state               varchar(32),
    reason                       varchar(1000),
    release_evidence_json        text,
    release_pair_id              uuid,
    release_profile_version      bigint,
    release_site_id              uuid,
    release_tare_measurement_id  uuid,
    request_hash                 varchar(64) not null,
    response_json                text not null,
    result_state                 varchar(32) not null,
    target_id                    uuid not null,
    target_type                  varchar(32) not null,
    version_after                bigint not null,
    primary key (id),
    foreign key (release_pair_id) references yard_weighing_pair(id),
    foreign key (release_site_id) references yard_site(id),
    foreign key (release_tare_measurement_id) references yard_measurement(id)
);

create table yard_mass_policy
(
    id                           uuid not null,
    allow_different_scales       boolean not null,
    branch_id                    uuid not null,
    composition_identity         varchar(128) not null,
    max_gross_kg                 numeric(14,3) not null,
    max_measurement_age_seconds  bigint not null,
    max_net_kg                   numeric(14,3) not null,
    max_pair_gap_seconds         bigint not null,
    order_deviation_kg           numeric(14,3) not null,
    order_weight_source          varchar(32) not null,
    regulation_reference         varchar(512) not null,
    require_current_calibration  boolean not null,
    site_id                      uuid not null,
    trailer_id                   uuid,
    updated_at                   timestamptz not null,
    updated_by                   uuid not null,
    valid_from                   timestamptz not null,
    valid_to                     timestamptz not null,
    vehicle_id                   uuid not null,
    version                      bigint not null,
    primary key (id),
    foreign key (site_id) references yard_site(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table yard_measurement
(
    id                     uuid not null,
    branch_id              uuid not null,
    composition_identity   varchar(128) not null,
    corrects_id            uuid,
    driver_id              uuid not null,
    fingerprint            varchar(64) not null,
    kind                   varchar(16) not null,
    manual_reason          varchar(1000) not null,
    mass_kg                numeric(14,3) not null,
    measured_at            timestamptz not null,
    operator_id            uuid not null,
    operator_name          varchar(256) not null,
    recorded_at            timestamptz not null,
    scale_id               uuid not null,
    scale_snapshot_json    text not null,
    shipment_id            uuid,
    site_id                uuid not null,
    source                 varchar(16) not null,
    source_measurement_id  varchar(128) not null,
    trip_id                uuid not null,
    vehicle_id             uuid not null,
    primary key (id),
    check (kind in ('TARE', 'GROSS', 'CONTROL')),
    -- kind BAZADA: jadval bo'sh
    check ((mass_kg > (0))),
    check ((btrim((manual_reason)) <> '')),
    check (source in ('MANUAL', 'DEVICE')),
    -- source BAZADA: jadval bo'sh
    foreign key (corrects_id) references yard_measurement(id),
    foreign key (driver_id) references driver(id),
    foreign key (scale_id) references yard_scale(id),
    foreign key (site_id) references yard_site(id),
    foreign key (trip_id) references trip(id),
    foreign key (vehicle_id) references transport_vehicle(id)
);

create table yard_scale
(
    id                      uuid not null,
    branch_id               uuid not null,
    calibration_reference   varchar(512),
    calibration_valid_from  timestamptz,
    calibration_valid_to    timestamptz,
    capacity_kg             numeric(14,3),
    manual_input_allowed    boolean,
    name                    varchar(128) not null,
    regulation_reference    varchar(512),
    resolution_kg           numeric(14,3),
    site_id                 uuid not null,
    state                   varchar(32) not null,
    updated_at              timestamptz not null,
    updated_by              uuid not null,
    valid_from              timestamptz,
    valid_to                timestamptz,
    object_version          bigint not null,
    primary key (id),
    foreign key (site_id) references yard_site(id)
);

create table yard_site
(
    id                    uuid not null,
    branch_id             uuid not null,
    name                  varchar(128) not null,
    profile_json          text,
    profile_state         varchar(32) not null,
    profile_valid_from    timestamptz,
    profile_valid_to      timestamptz,
    regulation_reference  varchar(512),
    time_zone             varchar(64) not null,
    updated_at            timestamptz not null,
    updated_by            uuid,
    object_version        bigint not null,
    primary key (id),
    check ((((profile_state) <> 'configured') or ((regulation_reference is not null) and (btrim((regulation_reference)) <> '') and (profile_json is not null) and (profile_valid_from is not null) and (profile_valid_to > profile_valid_from)))),
    check (profile_state in ('UNCONFIGURED', 'CONFIGURED'))
    -- profile_state BAZADA: jadval bo'sh
);

create table yard_weighing_pair
(
    id                    uuid not null,
    branch_id             uuid not null,
    composition_identity  varchar(128) not null,
    corrects_id           uuid,
    gross_kg              numeric(14,3) not null,
    gross_measurement_id  uuid not null,
    mass_policy_id        uuid not null,
    mass_policy_version   bigint not null,
    net_kg                numeric(14,3) not null,
    operator_id           uuid not null,
    order_fingerprint     varchar(64) not null,
    order_snapshot_json   text not null,
    policy_snapshot_json  text not null,
    reason                varchar(1000),
    recorded_at           timestamptz not null,
    shipment_id           uuid,
    site_id               uuid not null,
    tare_kg               numeric(14,3) not null,
    tare_measurement_id   uuid not null,
    trip_id               uuid not null,
    primary key (id),
    check (((tare_kg > (0)) and (gross_kg >= tare_kg) and (net_kg = (gross_kg - tare_kg)) and (tare_measurement_id <> gross_measurement_id))),
    check (((corrects_id is null) or ((corrects_id <> id) and (reason is not null) and (btrim((reason)) <> '')))),
    foreign key (corrects_id) references yard_weighing_pair(id),
    foreign key (gross_measurement_id) references yard_measurement(id),
    foreign key (mass_policy_id) references yard_mass_policy(id),
    foreign key (site_id) references yard_site(id),
    foreign key (tare_measurement_id) references yard_measurement(id),
    foreign key (trip_id) references trip(id)
);

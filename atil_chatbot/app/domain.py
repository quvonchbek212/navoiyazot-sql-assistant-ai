"""ATIL transport domeni. SQL dvigateli LIMS arxitekturasidan ko'chirilgan."""
EXCLUDED_TABLES = {"flyway_schema_history"}
JSON_LARGE_OBJECT_COLUMNS = set()
LOGICAL_FKS = []
MAIN_TABLES = {}
COLUMN_NOTES = {
    "document_template.code": "Shablonning o'z kodi/identifikatori; hujjat turi emas. Hujjat turi bo'yicha guruhlash uchun document_type ishlatiladi.",
    "document_template.document_type": "Hujjat turi kodi (WAYBILL, TTN va boshqalar). Hujjat turi/turi kodi so'ralganda shu ustunni tanlang va guruhlang.",
}

DOMAIN_RULES = """ATIL — transport, avtopark, haydovchilar, reyslar va dispetcherlik bazasi.
Faqat berilgan jonli sxemaga tayan. Mavjud bo'lmagan jadval, ustun yoki statusni o'ylab topma.
Tarixiy namuna qiymatlari cheklov emas; CHECK qiymatlari cheklov. Bo'sh natijani boshqa status bilan almashtirma.
Jadval nomlari birlikda: trip, driver, transport_vehicle, waybill. UUID o'rniga raqam va nomlarni ko'rsat.
Bo'lim, filial va manzil reference_data orqali department_id/branch_id bo'yicha ulanadi; har biriga alohida alias ishlat.
Reys hodisasi trip_event; telematika buzilishi incident. Hujjat fayli driver_document, muddatlar driver da.
Transport yaratgan hujjatlar transport_document; mashina hujjatlari vehicle_document.
Hujjat shablonlari document_template da: document_type — hujjat turi kodi; code — shablonning o'z identifikatori.
«Hujjat turi kodlari bo'yicha» so'ralsa document_template.document_type bilan guruhla; code bilan almashtirma.
Bugungi tibbiy ko'rik jurnali medical_inspection; texnik ko'rik vehicle_technical_inspection.
Hozir yo'lda bo'lgan mashina trip.status IN ('STARTED','ARRIVED_AT_POINT','LOADED','UNLOADED') bilan aniqlanadi.
Mashinalar sonida COUNT(DISTINCT vehicle_id) ishlat; current_status ni reys holati o'rniga ishlatma.
Kechikish hisoblanadi: hali jo'namaganida scheduled_departure_at, jo'naganida va kelmaganida scheduled_arrival_at ni hozirgi vaqt bilan solishtir.
Yakunlangan va bekor qilingan reysni hozir kechikayotgan reyslar qatoriga qo'shma.
transport_vehicle.assigned_driver_id asosiy haydovchiga ulanadi; driver.assigned_vehicle_id mavjud emas.
Ko'p haydovchi bog'lanishi vehicle_assigned_drivers orqali. Haydovchi toifasi driver_license_category.license_category.
Sug'urta insurance_policy va vehicle_document da: umumiy qamrov so'ralsa ikkalasini manbasi bilan UNION ALL qil.
Transport yuk ko'tarishi va ariza yuki kilogrammda, waybill.cargo_weight_tons tonnada. Kerak bo'lsa /1000.0.
Reja masofasi route_point.distance_from_previous_km yig'indisi; trip.delay_minutes/planned_distance_km degan ustunlarni o'ylab topma.
Sana va vaqt Asia/Tashkent. Bugun CURRENT_DATE. Tarix uchun jadvalning ish sanasini ishlat.
Foydalanuvchi boshqa vaqt mintaqasini aniq so'ramasa, kalendar sanalar UTC+05:00 bo'yicha.
timestamptz filtrida mahalliy yarim tunni +00 bilan yozma: +05:00 ishlat yoki sanani vaqt mintaqasisiz yoz (baza Asia/Tashkent).
Kunlar oralig'i ikkala kun bilan so'ralsa: >= birinchi kun 00:00:00+05:00 AND < oxirgi kundan keyingi kun 00:00:00+05:00.
Masalan, 2026-yil 1–6-noyabr: >= TIMESTAMPTZ '2026-11-01 00:00:00+05:00' AND < TIMESTAMPTZ '2026-11-07 00:00:00+05:00'.
<= 23:59:59 ishlatma: oxirgi soniyadagi kasr vaqtlar tushib qoladi. UTCga aylantirsang, Toshkent 00:00 = oldingi kun 19:00 UTC.
Lotin/kirill nomlarni ILIKE bilan ikkala variantda qidir. Savoldagi avtomobil raqami, obyekt va davr shartlarini saqla.
Sxemada javob uchun ma'lumot bo'lmasa SAVOL: orqali aniqlashtir; boshqa mavzu ma'lumotini javob o'rniga bermagin.
"""
GLOSSARY = """reys/рейс/trip → trip; mashina/avtopark/машина/vehicle → transport_vehicle;
haydovchi/водитель/driver → driver; marshrut → route, route_point; ariza/talabnoma/buyurtma → transport_request;
yo'l varaqasi → waybill; varaqa topshirig'i → waybill_task; yoqilg'i quyish → fuel_record;
yoqilg'i normasi → fuel_norm; yoqilg'i turi → vehicle_reference_data_fuel_type, reference_data;
ta'mir/remont → vehicle_repair; texnik xizmat → maintenance_plan; GPS/joylashuv → vehicle_telemetry_state;
tibbiy ko'rik → medical_inspection; texnik ko'rik → vehicle_technical_inspection;
sug'urta → insurance_policy, vehicle_document; bo'lim/filial → reference_data.
hujjat shabloni → document_template.
"""

SYNONYMS = {'akkumulyator': ('vehicle_part', 'transport_vehicle', 'vehicle_repair'),
 'shablon': ('document_template',),
 'template': ('document_template',),
 'шаблон': ('document_template',),
 'akt': ('customer', 'customer_settlement_act', 'tariff'),
 'anomaliya nima uchun': ('fuel_record_risk_flag', 'fuel_record', 'transport_vehicle'),
 'anomaliya sabab': ('fuel_record_risk_flag', 'fuel_record', 'transport_vehicle'),
 'application': ('transport_request',),
 'ariza': ('transport_request', 'transport_request_audit', 'transport_request_point'),
 'arizalar': ('transport_request', 'transport_request_audit', 'transport_request_point'),
 'assigned vehicle': ('driver_assigned_vehicles', 'driver', 'transport_vehicle'),
 'audit': ('audit_event', 'transport_request_audit', 'vehicle_status_history'),
 'audit izi': ('audit_event', 'transport_request_audit', 'vehicle_status_history'),
 'audit jurnal': ('audit_event', 'transport_request_audit', 'vehicle_status_history'),
 'auditida': ('audit_event', 'transport_request_audit', 'vehicle_status_history'),
 'avariya': ('vehicle_accident', 'transport_vehicle', 'driver', 'insurance_policy'),
 'avtomobil': ('transport_vehicle', 'vehicle_document', 'vehicle_telemetry_state'),
 'avtopark': ('transport_vehicle', 'vehicle_document', 'vehicle_telemetry_state'),
 'avtorizatsiya': ('fuel_authorization', 'driver_credential', 'fuel_record'),
 'ayni paytda': ('trip', 'transport_vehicle', 'driver', 'route'),
 'bakdagi': ('fuel_sensor_reading', 'fuel_sensor', 'fuel_card_transaction'),
 'benzin': ('fuel_record', 'fuel_norm', 'fuel_card_transaction', 'transport_vehicle'),
 'bildirishnoma': ('notification', 'fuel_limit'),
 'biriktirilgan avto': ('driver_assigned_vehicles', 'driver', 'transport_vehicle'),
 'biriktirilgan mashina': ('driver_assigned_vehicles', 'driver', 'transport_vehicle'),
 'biriktirilgan transport': ('driver_assigned_vehicles', 'driver', 'transport_vehicle'),
 'bitta marshrutga': ('route_transport_request', 'route', 'transport_request'),
 "bo'lim": ('reference_data', 'user_department'),
 "bo'sh mashina": ('transport_vehicle', 'vehicle_status_history', 'driver'),
 "bo'sh transport": ('transport_vehicle', 'vehicle_status_history', 'driver'),
 'bolim': ('reference_data', 'user_department'),
 'bosh mashina': ('transport_vehicle', 'vehicle_status_history', 'driver'),
 'branch': ('reference_data',),
 'buyurtma': ('transport_request', 'transport_request_audit', 'transport_request_point'),
 'buyurtmachi': ('customer', 'customer_settlement_act', 'tariff'),
 'buzilgan': ('vehicle_repair', 'vehicle_part', 'transport_vehicle'),
 'buzilish': ('incident', 'trip_event', 'transport_vehicle', 'driver'),
 'chetlan': ('incident', 'trip_event', 'transport_vehicle', 'driver'),
 'client': ('customer',),
 'consumption_critical': ('fuel_record_risk_flag', 'fuel_record', 'transport_vehicle'),
 'consumption_warning': ('fuel_record_risk_flag', 'fuel_record', 'transport_vehicle'),
 'credential': ('driver_credential', 'driver'),
 'currently on': ('trip', 'transport_vehicle', 'driver', 'route'),
 'customer': ('customer',),
 'dashboard': ('trip', 'transport_vehicle', 'driver'),
 "datchik o'rnat": ('vehicle_fuel_sensor_installation', 'fuel_sensor', 'transport_vehicle'),
 'datchik ornat': ('vehicle_fuel_sensor_installation', 'fuel_sensor', 'transport_vehicle'),
 'davlat raqami': ('transport_vehicle', 'vehicle_document', 'vehicle_telemetry_state'),
 'davlat raqami almash': ('vehicle_plate_history', 'transport_vehicle'),
 'department': ('reference_data',),
 'device_id': ('vehicle_gps', 'position_log', 'transport_vehicle'),
 'dizel': ('fuel_record', 'fuel_norm', 'fuel_card_transaction', 'transport_vehicle'),
 'driver': ('driver',),
 'ehtiyot qism': ('vehicle_part', 'transport_vehicle', 'vehicle_repair'),
 'erp': ('erp_trip_outbox', 'erp_vehicle_outbox', 'toir_vehicle_outbox'),
 'eski raqam': ('vehicle_plate_history', 'transport_vehicle'),
 'eta': ('trip', 'trip_event', 'transport_vehicle', 'driver'),
 'favqulodda tibbiy': ('emergency_medical_case', 'emergency_medical_status_history', 'driver'),
 'fayl': ('driver_document', 'attachment', 'document_version'),
 'filial': ('reference_data', 'user_department'),
 'filtr': ('vehicle_part', 'transport_vehicle', 'vehicle_repair'),
 'fine': ('fine',),
 'fleet': ('transport_vehicle',),
 'foto': ('vehicle_photo', 'attachment', 'vehicle_technical_inspection_photo'),
 'foydalanuvchi': ('app_user', 'user_role', 'user_department'),
 'foydalanuvchi ombor': ('user_warehouse', 'app_user', 'warehouse'),
 'fuel': ('fuel_record',),
 'fuel norm': ('fuel_norm', 'transport_vehicle'),
 'fuel type': ('fuel_type', 'vehicle_reference_data_fuel_type', 'transport_vehicle'),
 'garaj': ('transport_vehicle', 'vehicle_document', 'vehicle_telemetry_state'),
 'geozona': ('telematics_geozone', 'incident', 'vehicle_telemetry_state'),
 'gps': ('vehicle_telemetry_state', 'telematics_event', 'transport_vehicle'),
 'gps device': ('vehicle_gps', 'position_log', 'transport_vehicle'),
 "gps o'rnatilgan": ('vehicle_gps', 'position_log', 'transport_vehicle'),
 'gps ornatilgan': ('vehicle_gps', 'position_log', 'transport_vehicle'),
 'gps qurilma': ('vehicle_gps', 'position_log', 'transport_vehicle'),
 'gps qurilmasi': ('vehicle_gps', 'position_log', 'transport_vehicle'),
 'gps-qurilma': ('vehicle_gps', 'position_log', 'transport_vehicle'),
 'guvohnoma': ('driver', 'driver_license_category', 'driver_document', 'medical_inspection'),
 'harakatdagi': ('trip', 'transport_vehicle', 'driver', 'route'),
 'haydovchi': ('driver', 'driver_license_category', 'driver_document', 'medical_inspection'),
 'haydovchiga biriktir': ('driver_assigned_vehicles', 'driver', 'transport_vehicle'),
 'haydovchilar': ('driver',),
 'hisob-kitob': ('customer', 'customer_settlement_act', 'tariff'),
 'hodisa': ('incident', 'trip_event', 'transport_vehicle', 'driver'),
 'holat tarixi': ('vehicle_status_history', 'transport_vehicle'),
 "holati o'zgar": ('vehicle_status_history', 'transport_vehicle'),
 "holati qachon o'zgar": ('vehicle_status_history', 'transport_vehicle'),
 'hozir qayerda': ('vehicle_telemetry_state', 'telematics_event', 'transport_vehicle'),
 'hozir reysda': ('trip', 'transport_vehicle', 'driver', 'route'),
 'hujjat': ('vehicle_document', 'transport_vehicle', 'insurance_policy'),
 'hujjat auditi': ('document_audit', 'transport_document'),
 'hujjat fayli': ('driver_document', 'attachment', 'document_version'),
 'hujjat imzo': ('transport_document', 'document_version', 'document_template'),
 'hujjat raqami': ('transport_document', 'document_version', 'document_template'),
 'hujjat tarixi': ('document_audit', 'transport_document'),
 'hujjat ustida': ('document_audit', 'transport_document'),
 'hujjat versiya': ('document_version', 'transport_document'),
 'hujjat yaratil': ('transport_document', 'document_version', 'document_template'),
 'identifikator': ('driver_credential', 'driver'),
 'imzo': ('transport_document', 'document_version', 'document_audit'),
 'in transit': ('trip', 'transport_vehicle', 'driver', 'route'),
 'incident': ('incident',),
 'insurance': ('insurance_policy',),
 'integratsiya': ('erp_trip_outbox', 'erp_vehicle_outbox', 'toir_vehicle_outbox'),
 'inventarizatsiya': ('fuel_inventory_document', 'fuel_record'),
 'inventory': ('inventory_stock',),
 'ish haqi': ('driver_shift', 'driver', 'payroll_rate'),
 'ish soati': ('driver_shift', 'driver', 'payroll_rate'),
 'ish vaqti': ('driver_shift', 'driver', 'payroll_rate'),
 'ishga ruxsat': ('driver', 'medical_inspection', 'driver_license_category'),
 'jarima': ('fine', 'fine_driver', 'speed_violation', 'driver'),
 'joylashuv': ('vehicle_telemetry_state', 'telematics_event', 'transport_vehicle'),
 'jurnal': ('medical_inspection',
            'vehicle_technical_inspection',
            'vehicle_status_history',
            'transport_request_audit'),
 'jurnalida': ('medical_inspection',
               'vehicle_technical_inspection',
               'vehicle_status_history',
               'transport_request_audit'),
 'karta': ('driver_credential', 'driver'),
 "kasal bo'lib qol": ('emergency_medical_case', 'emergency_medical_status_history', 'driver'),
 'kasko': ('insurance_policy', 'vehicle_document', 'transport_vehicle'),
 'katalog': ('reference_data', 'user_department'),
 'kategoriya': ('driver_license_category', 'driver'),
 'kategoriyasi': ('driver_license_category', 'driver'),
 'kechik': ('trip', 'trip_event', 'transport_vehicle', 'driver'),
 'kelishuv': ('transport_request', 'transport_request_audit', 'transport_request_point'),
 'kelishuvdagi': ('transport_request', 'transport_request_audit', 'transport_request_point'),
 'keyingi xizmat': ('maintenance_plan', 'transport_vehicle', 'vehicle_repair'),
 'kim bekor qil': ('audit_event', 'transport_request_audit', 'vehicle_status_history'),
 'kim imzolagan': ('document_audit', 'transport_document'),
 'kim kirgan': ('app_user', 'user_role', 'user_department'),
 "kim o'zgartir": ('audit_event', 'transport_request_audit', 'vehicle_status_history'),
 'kim ozgartir': ('audit_event', 'transport_request_audit', 'vehicle_status_history'),
 'kim qachon': ('audit_event', 'transport_request_audit', 'vehicle_status_history'),
 'kim tasdiqla': ('audit_event', 'transport_request_audit', 'vehicle_status_history'),
 "ko'rib chiqil": ('transport_request', 'transport_request_audit', 'transport_request_point'),
 "ko'rik natija": ('vehicle_technical_inspection', 'transport_vehicle'),
 "ko'rsatkich": ('trip', 'transport_vehicle', 'driver'),
 'konsolidatsiya': ('route_transport_request', 'route', 'transport_request'),
 'konsolidatsiyalangan': ('route_transport_request', 'route', 'transport_request'),
 'koordinata': ('vehicle_telemetry_state', 'telematics_event', 'transport_vehicle'),
 'korib chiqil': ('transport_request', 'transport_request_audit', 'transport_request_point'),
 'korik natija': ('vehicle_technical_inspection', 'transport_vehicle'),
 'kpi': ('trip', 'transport_vehicle', 'driver'),
 'lavozim': ('reference_data', 'user_department'),
 'limit': ('fuel_limit', 'fuel_authorization', 'notification'),
 'limit belgilan': ('fuel_limit', 'notification', 'fuel_record'),
 'limit oshgan': ('fuel_limit', 'notification', 'fuel_record'),
 'limit qoldi': ('fuel_limit', 'notification', 'fuel_record'),
 'liniyada': ('trip', 'transport_vehicle', 'driver', 'route'),
 'liniyadagi': ('trip', 'transport_vehicle', 'driver', 'route'),
 'litr': ('fuel_record', 'fuel_norm', 'fuel_card_transaction', 'transport_vehicle'),
 'login': ('app_user', 'user_role', 'user_department'),
 "ma'lumotnoma": ('reference_data', 'user_department'),
 'maintenance': ('maintenance_plan',),
 'malaka': ('driver', 'driver_license_category', 'driver_document', 'medical_inspection'),
 'manzil': ('reference_data', 'user_department'),
 'marshrut': ('route', 'route_point', 'trip'),
 'marshrut varaqasi': ('transport_document', 'document_version', 'document_template'),
 'marshrutga birlashtir': ('route_transport_request', 'route', 'transport_request'),
 'marshrutlar': ('route',),
 'mashina': ('transport_vehicle', 'vehicle_document', 'vehicle_telemetry_state'),
 'mashina biriktir': ('driver_assigned_vehicles', 'driver', 'transport_vehicle'),
 'mashinalar': ('transport_vehicle',),
 'masofa': ('route', 'route_point', 'trip'),
 'material qoldi': ('inventory_stock', 'product'),
 'mavjud mashina': ('transport_vehicle', 'vehicle_status_history', 'driver'),
 "med ko'rik": ('medical_inspection', 'driver'),
 'medical': ('medical_inspection',),
 "mexanik ko'rik": ('vehicle_technical_inspection', 'transport_vehicle'),
 'mexanik korik': ('vehicle_technical_inspection', 'transport_vehicle'),
 'mijoz': ('customer', 'customer_settlement_act', 'tariff'),
 'moy almashtirish': ('maintenance_plan', 'transport_vehicle', 'vehicle_repair'),
 'muammo belgi': ('fuel_record_risk_flag', 'fuel_record', 'transport_vehicle'),
 'muddati tugay': ('vehicle_document', 'transport_vehicle', 'insurance_policy'),
 'muvofiqlashtir': ('transport_request', 'transport_request_audit', 'transport_request_point'),
 'narx': ('tariff', 'customer_settlement_act'),
 'natijalar': ('medical_inspection',
               'vehicle_technical_inspection',
               'vehicle_status_history',
               'transport_request_audit'),
 'nega anomaliya': ('fuel_record_risk_flag', 'fuel_record', 'transport_vehicle'),
 'no_trip_bound': ('fuel_record_risk_flag', 'fuel_record', 'transport_vehicle'),
 'norma': ('fuel_record', 'fuel_norm', 'fuel_card_transaction', 'transport_vehicle'),
 'norma belgilangan': ('fuel_norm', 'transport_vehicle'),
 'norma qanday': ('fuel_norm', 'transport_vehicle'),
 'nosozlik': ('vehicle_repair', 'vehicle_part', 'transport_vehicle'),
 'nuqson': ('vehicle_technical_inspection', 'transport_vehicle'),
 'nuqta': ('route', 'route_point', 'trip'),
 'nusxa': ('driver_document', 'attachment', 'document_version'),
 "o'g'irlik": ('fuel_sensor_reading', 'fuel_sensor', 'fuel_card_transaction'),
 "o'zgartirdi": ('audit_event', 'transport_request_audit', 'vehicle_status_history'),
 "o'zgartirgan": ('audit_event', 'transport_request_audit', 'vehicle_status_history'),
 "og'ish": ('incident', 'trip_event', 'transport_vehicle', 'driver'),
 'ogirlik': ('fuel_sensor_reading', 'fuel_sensor', 'fuel_card_transaction'),
 'ogish': ('incident', 'trip_event', 'transport_vehicle', 'driver'),
 'ogohlantirish': ('notification', 'fuel_limit'),
 'ogohlantirish belgi': ('fuel_record_risk_flag', 'fuel_record', 'transport_vehicle'),
 'ombor biriktir': ('user_warehouse', 'app_user', 'warehouse'),
 'ombor qoldi': ('inventory_stock', 'product'),
 'ombor qoldig': ('inventory_stock', 'reference_data'),
 'ombor xodimi': ('user_warehouse', 'app_user', 'warehouse'),
 'omborda nechta': ('inventory_stock', 'reference_data'),
 'omborda qancha': ('inventory_stock', 'product'),
 'omborda qoldiq': ('inventory_stock', 'product'),
 'ombordagi tovar': ('inventory_stock', 'reference_data'),
 'on a trip': ('trip', 'transport_vehicle', 'driver', 'route'),
 'on the line': ('trip', 'transport_vehicle', 'driver', 'route'),
 'on the road': ('trip', 'transport_vehicle', 'driver', 'route'),
 'operator ombor': ('user_warehouse', 'app_user', 'warehouse'),
 'osago': ('insurance_policy', 'vehicle_document', 'transport_vehicle'),
 'outbox': ('erp_trip_outbox', 'erp_vehicle_outbox', 'toir_vehicle_outbox'),
 'ozgartirdi': ('audit_event', 'transport_request_audit', 'vehicle_status_history'),
 'ozgartirgan': ('audit_event', 'transport_request_audit', 'vehicle_status_history'),
 'penalty': ('fine',),
 'penya': ('fine', 'fine_driver', 'speed_violation', 'driver'),
 'polis': ('insurance_policy', 'vehicle_document', 'transport_vehicle'),
 'post_trip': ('vehicle_technical_inspection', 'transport_vehicle'),
 'pre_trip': ('vehicle_technical_inspection', 'transport_vehicle'),
 'putevoy': ('waybill', 'transport_vehicle', 'driver', 'trip'),
 'qayerda': ('vehicle_telemetry_state', 'telematics_event', 'transport_vehicle'),
 'qaysi marshrutga tush': ('route_transport_request', 'route', 'transport_request'),
 'qaysi mashinada sensor': ('vehicle_fuel_sensor_installation', 'fuel_sensor', 'transport_vehicle'),
 'qaysi mashinalar biriktir': ('driver_assigned_vehicles', 'driver', 'transport_vehicle'),
 'qaysi omborga biriktir': ('user_warehouse', 'app_user', 'warehouse'),
 'qaysi yoqilg': ('vehicle_reference_data_fuel_type', 'transport_vehicle', 'reference_data'),
 "qo'shimcha soat": ('driver_shift', 'driver', 'payroll_rate'),
 'qoldiq': ('inventory_stock', 'reference_data'),
 'qoldiq bor': ('inventory_stock', 'product'),
 'qr kod': ('driver_credential', 'driver'),
 'qr-kod': ('driver_credential', 'driver'),
 'qurilma biriktir': ('vehicle_gps', 'position_log', 'transport_vehicle'),
 'quyish': ('fuel_record', 'fuel_norm', 'fuel_card_transaction', 'transport_vehicle'),
 'quyishga ruxsat': ('fuel_authorization', 'driver_credential', 'fuel_record'),
 'rad etil': ('transport_request', 'transport_request_audit', 'transport_request_point'),
 'raqam almash': ('vehicle_plate_history', 'transport_vehicle'),
 'raqam tarixi': ('vehicle_plate_history', 'transport_vehicle'),
 'raqami almash': ('vehicle_plate_history', 'transport_vehicle'),
 "raqami o'zgar": ('vehicle_plate_history', 'transport_vehicle'),
 'raqami qachon almash': ('vehicle_plate_history', 'transport_vehicle'),
 "raqami qachon o'zgar": ('vehicle_plate_history', 'transport_vehicle'),
 'rasm': ('vehicle_photo', 'attachment', 'vehicle_technical_inspection_photo'),
 'rasmlari': ('vehicle_photo', 'attachment', 'vehicle_technical_inspection_photo'),
 'razryad': ('driver_license_category', 'driver'),
 'repair': ('vehicle_repair',),
 'request': ('transport_request',),
 'reys': ('trip', 'trip_event', 'transport_vehicle', 'driver', 'route'),
 'reys hodisa': ('trip_event', 'trip', 'transport_vehicle', 'driver'),
 'reys tarixi': ('trip_event', 'trip', 'transport_vehicle', 'driver'),
 "reys yo'lida": ('trip_event', 'trip', 'transport_vehicle', 'driver'),
 'reys yolida': ('trip_event', 'trip', 'transport_vehicle', 'driver'),
 "reysda nima bo'lgan": ('trip_event', 'trip', 'transport_vehicle', 'driver'),
 'reysdagi mashina': ('trip', 'transport_vehicle', 'driver', 'route'),
 'reysdagi transport': ('trip', 'transport_vehicle', 'driver', 'route'),
 'reysdan keyingi': ('vehicle_technical_inspection', 'transport_vehicle'),
 "reysdan keyingi ko'rik": ('vehicle_technical_inspection', 'transport_vehicle'),
 'reysdan oldingi': ('vehicle_technical_inspection', 'transport_vehicle'),
 "reysdan oldingi ko'rik": ('vehicle_technical_inspection', 'transport_vehicle'),
 'reysga chiqa': ('driver', 'medical_inspection', 'driver_license_category'),
 'reysga ruxsat': ('driver', 'medical_inspection', 'driver_license_category'),
 'reyslar': ('trip', 'trip_event', 'transport_vehicle', 'driver', 'route'),
 'rfid': ('driver_credential', 'driver'),
 'risk belgi': ('fuel_record_risk_flag', 'fuel_record', 'transport_vehicle'),
 'risk flag': ('fuel_record_risk_flag', 'fuel_record', 'transport_vehicle'),
 'rol': ('app_user', 'user_role', 'user_department'),
 'route': ('route',),
 'ruxsatnoma': ('vehicle_document', 'transport_vehicle', 'insurance_policy'),
 'ruxsatnoma berilgan': ('fuel_authorization', 'driver_credential', 'fuel_record'),
 "ruxsatsiz to'xtash": ('incident', 'trip_event', 'transport_vehicle', 'driver'),
 'sarf': ('fuel_record', 'fuel_norm', 'fuel_card_transaction', 'transport_vehicle'),
 'sarf normasi': ('fuel_norm', 'transport_vehicle'),
 'sayohat varaq': ('waybill', 'transport_vehicle', 'driver', 'trip'),
 'sensor': ('fuel_sensor_reading', 'fuel_sensor', 'fuel_card_transaction'),
 'sensor montaj': ('vehicle_fuel_sensor_installation', 'fuel_sensor', 'transport_vehicle'),
 "sensor o'rnat": ('vehicle_fuel_sensor_installation', 'fuel_sensor', 'transport_vehicle'),
 'sensor olib tashlan': ('vehicle_fuel_sensor_installation', 'fuel_sensor', 'transport_vehicle'),
 'sensor ornat': ('vehicle_fuel_sensor_installation', 'fuel_sensor', 'transport_vehicle'),
 'sensor qachon': ('vehicle_fuel_sensor_installation', 'fuel_sensor', 'transport_vehicle'),
 'sensor qaysi': ('vehicle_fuel_sensor_installation', 'fuel_sensor', 'transport_vehicle'),
 "sensori o'rnat": ('vehicle_fuel_sensor_installation', 'fuel_sensor', 'transport_vehicle'),
 'sensori olib': ('vehicle_fuel_sensor_installation', 'fuel_sensor', 'transport_vehicle'),
 'sensori ornat': ('vehicle_fuel_sensor_installation', 'fuel_sensor', 'transport_vehicle'),
 'sensori qachon': ('vehicle_fuel_sensor_installation', 'fuel_sensor', 'transport_vehicle'),
 'sensori qaysi': ('vehicle_fuel_sensor_installation', 'fuel_sensor', 'transport_vehicle'),
 'sensorli mashina': ('vehicle_fuel_sensor_installation', 'fuel_sensor', 'transport_vehicle'),
 "sensorni o'rnat": ('vehicle_fuel_sensor_installation', 'fuel_sensor', 'transport_vehicle'),
 'sensorni ornat': ('vehicle_fuel_sensor_installation', 'fuel_sensor', 'transport_vehicle'),
 'servis': ('maintenance_plan', 'transport_vehicle', 'vehicle_repair'),
 'shift': ('driver_shift',),
 'shina': ('vehicle_part', 'transport_vehicle', 'vehicle_repair'),
 'shoshilinch tibbiy': ('emergency_medical_case', 'emergency_medical_status_history', 'driver'),
 'skan': ('driver_document', 'attachment', 'document_version'),
 'skanlar': ('driver_document', 'attachment', 'document_version'),
 'sklad qoldi': ('inventory_stock', 'reference_data'),
 'smena': ('driver_shift', 'driver', 'payroll_rate'),
 "so'rov": ('transport_request', 'transport_request_audit', 'transport_request_point'),
 "so'rov marshruti": ('route_transport_request', 'route', 'transport_request'),
 "sog'lig": ('medical_inspection', 'driver'),
 'sorov': ('transport_request', 'transport_request_audit', 'transport_request_point'),
 'sorov marshruti': ('route_transport_request', 'route', 'transport_request'),
 'spare part': ('vehicle_part',),
 'status tarixi': ('vehicle_status_history', 'transport_vehicle'),
 "sug'urta": ('insurance_policy', 'vehicle_document', 'transport_vehicle'),
 "sug'urta kompaniya": ('insurance_policy', 'vehicle_document', 'transport_vehicle'),
 'sugurta': ('insurance_policy', 'vehicle_document', 'transport_vehicle'),
 'surat': ('vehicle_photo', 'attachment', 'vehicle_technical_inspection_photo'),
 'suratlari': ('vehicle_photo', 'attachment', 'vehicle_technical_inspection_photo'),
 "ta'mir": ('vehicle_repair', 'vehicle_part', 'transport_vehicle'),
 'talabnoma': ('transport_request', 'transport_request_audit', 'transport_request_point'),
 'tamir': ('vehicle_repair', 'vehicle_part', 'transport_vehicle'),
 'tarif': ('tariff', 'customer_settlement_act'),
 'tariff': ('tariff',),
 'tarix': ('audit_event', 'vehicle_status_history', 'transport_request_audit'),
 'tarixi': ('medical_inspection',
            'vehicle_technical_inspection',
            'vehicle_status_history',
            'transport_request_audit'),
 'tasdiq': ('transport_request', 'transport_request_audit', 'transport_request_point'),
 'tashabbuskor': ('transport_request', 'transport_request_audit', 'transport_request_point'),
 'technical inspection': ('vehicle_technical_inspection', 'transport_vehicle'),
 'telematika': ('vehicle_telemetry_state', 'telematics_event', 'transport_vehicle'),
 "texnik ko'rik": ('vehicle_technical_inspection', 'transport_vehicle'),
 "texnik ko'rik natija": ('vehicle_technical_inspection', 'transport_vehicle'),
 'texnik korik': ('vehicle_technical_inspection', 'transport_vehicle'),
 'texnik xizmat': ('maintenance_plan', 'transport_vehicle', 'vehicle_repair'),
 'tez yordam chaqir': ('emergency_medical_case', 'emergency_medical_status_history', 'driver'),
 'tezlik': ('speed_violation', 'fine', 'transport_vehicle', 'driver'),
 'tezlikni osh': ('speed_violation', 'fine', 'transport_vehicle', 'driver'),
 'tibbiy hodisa': ('emergency_medical_case', 'emergency_medical_status_history', 'driver'),
 'tibbiy jurnal': ('medical_inspection', 'driver'),
 "tibbiy ko'rik": ('medical_inspection', 'driver'),
 'tibbiy korik': ('medical_inspection', 'driver'),
 "to'lanmagan jarima": ('fine', 'fine_driver', 'speed_violation', 'driver'),
 "to'lov modeli": ('tariff', 'customer_settlement_act'),
 "to'qnash": ('vehicle_accident', 'transport_vehicle', 'driver', 'insurance_policy'),
 'to-1': ('maintenance_plan', 'transport_vehicle', 'vehicle_repair'),
 'to-2': ('maintenance_plan', 'transport_vehicle', 'vehicle_repair'),
 'toifa': ('driver_license_category', 'driver'),
 'toifasi': ('driver_license_category', 'driver'),
 'toir': ('erp_trip_outbox', 'erp_vehicle_outbox', 'toir_vehicle_outbox'),
 'topshiriq': ('waybill_task', 'waybill'),
 'topshiriqlar': ('waybill_task', 'waybill'),
 'toqnash': ('vehicle_accident', 'transport_vehicle', 'driver', 'insurance_policy'),
 'tovar qoldi': ('inventory_stock', 'product'),
 'transport': ('transport_vehicle', 'vehicle_document', 'vehicle_telemetry_state'),
 'transport akti': ('transport_document', 'document_version', 'document_template'),
 'transport biriktir': ('driver_assigned_vehicles', 'driver', 'transport_vehicle'),
 'transport hujjat': ('transport_document', 'document_version', 'document_template'),
 'travel sheet': ('waybill',),
 'treker': ('vehicle_gps', 'position_log', 'transport_vehicle'),
 'trekker': ('vehicle_gps', 'position_log', 'transport_vehicle'),
 'trip': ('trip', 'trip_event', 'transport_vehicle', 'driver', 'route'),
 'truck': ('transport_vehicle',),
 'ttn': ('transport_document', 'document_version', 'document_template'),
 'tungi soat': ('driver_shift', 'driver', 'payroll_rate'),
 'umumiy statistika': ('trip', 'transport_vehicle', 'driver'),
 'vaqtida yetkaz': ('trip', 'trip_event', 'transport_vehicle', 'driver'),
 'varaqa': ('waybill', 'transport_vehicle', 'driver', 'trip'),
 'varaqa topshiriq': ('waybill_task', 'waybill'),
 'varaqadagi yuk': ('waybill_task', 'waybill'),
 'varaqasi topshiriq': ('waybill_task', 'waybill'),
 'varaqlari': ('waybill', 'transport_vehicle', 'driver', 'trip'),
 'vehicle': ('transport_vehicle',),
 'versiya': ('document_version', 'transport_document'),
 'versiyalari': ('document_version', 'transport_document'),
 'violation': ('incident',),
 'voditel': ('driver', 'driver_license_category', 'driver_document', 'medical_inspection'),
 'waybill': ('waybill',),
 'xizmat muddati': ('maintenance_plan', 'transport_vehicle', 'vehicle_repair'),
 'yetib kel': ('trip', 'trip_event', 'transport_vehicle', 'driver'),
 'yetkazish tasdig': ('transport_document', 'document_version', 'document_audit'),
 "yo'l varaq": ('waybill', 'transport_vehicle', 'driver', 'trip'),
 "yo'lda": ('trip', 'transport_vehicle', 'driver', 'route'),
 "yo'lda kasal": ('emergency_medical_case', 'emergency_medical_status_history', 'driver'),
 "yo'lda nima bo'lgan": ('trip_event', 'trip', 'transport_vehicle', 'driver'),
 "yo'lga chiqa": ('driver', 'medical_inspection', 'driver_license_category'),
 "yo'nalish": ('route', 'route_point', 'trip'),
 'yol varaq': ('waybill', 'transport_vehicle', 'driver', 'trip'),
 'yolda': ('trip', 'transport_vehicle', 'driver', 'route'),
 'yolga chiqa': ('driver', 'medical_inspection', 'driver_license_category'),
 'yonalish': ('route', 'route_point', 'trip'),
 "yonilg'i turi": ('fuel_type', 'vehicle_reference_data_fuel_type', 'transport_vehicle'),
 'yonilgi turi': ('fuel_type', 'vehicle_reference_data_fuel_type', 'transport_vehicle'),
 "yoqilg'i": ('fuel_record', 'fuel_norm', 'fuel_card_transaction', 'transport_vehicle'),
 "yoqilg'i chiqim": ('fuel_inventory_document', 'fuel_record'),
 "yoqilg'i hujjat": ('fuel_inventory_document', 'fuel_record'),
 "yoqilg'i kirim": ('fuel_inventory_document', 'fuel_record'),
 "yoqilg'i limit": ('fuel_limit', 'notification', 'fuel_record'),
 "yoqilg'i norma": ('fuel_norm', 'transport_vehicle'),
 "yoqilg'i ombor": ('fuel_inventory_document', 'fuel_record'),
 "yoqilg'i operatori": ('user_warehouse', 'app_user', 'warehouse'),
 "yoqilg'i ruxsat": ('fuel_authorization', 'driver_credential', 'fuel_record'),
 "yoqilg'i sathi": ('fuel_sensor_reading', 'fuel_sensor', 'fuel_card_transaction'),
 "yoqilg'i turi": ('fuel_type', 'vehicle_reference_data_fuel_type', 'transport_vehicle'),
 "yoqilg'i turlari": ('fuel_type', 'vehicle_reference_data_fuel_type', 'transport_vehicle'),
 'yoqilgi': ('fuel_record', 'fuel_norm', 'fuel_card_transaction', 'transport_vehicle'),
 'yoqilgi limit': ('fuel_limit', 'notification', 'fuel_record'),
 'yoqilgi norma': ('fuel_norm', 'transport_vehicle'),
 'yoqilgi ombor': ('fuel_inventory_document', 'fuel_record'),
 'yoqilgi operatori': ('user_warehouse', 'app_user', 'warehouse'),
 'yoqilgi ruxsat': ('fuel_authorization', 'driver_credential', 'fuel_record'),
 'yoqilgi turi': ('fuel_type', 'vehicle_reference_data_fuel_type', 'transport_vehicle'),
 'yoqilgi turlari': ('fuel_type', 'vehicle_reference_data_fuel_type', 'transport_vehicle'),
 'yozuvlar': ('medical_inspection',
              'vehicle_technical_inspection',
              'vehicle_status_history',
              'transport_request_audit'),
 'yth': ('vehicle_accident', 'transport_vehicle', 'driver', 'insurance_policy'),
 'yuborilmagan': ('erp_trip_outbox', 'erp_vehicle_outbox', 'toir_vehicle_outbox'),
 'yuk qatorlari': ('waybill_task', 'waybill'),
 'yuklangan hujjat': ('driver_document', 'attachment', 'document_version'),
 'zarar': ('vehicle_accident', 'transport_vehicle', 'driver', 'insurance_policy'),
 'zaxira': ('inventory_stock', 'product'),
 'zayavka': ('transport_request', 'transport_request_audit', 'transport_request_point'),
 'zonadan chiq': ('telematics_geozone', 'incident', 'vehicle_telemetry_state'),
 'автомобил': ('transport_vehicle',),
 'автопарк': ('transport_vehicle',),
 'в пути': ('trip', 'transport_vehicle', 'driver', 'route'),
 'в рейсе': ('trip', 'transport_vehicle', 'driver', 'route'),
 'виды топлива': ('fuel_type', 'vehicle_reference_data_fuel_type', 'transport_vehicle'),
 'водител': ('driver',),
 'горюч': ('fuel_record',),
 'заказчик': ('customer',),
 'закреплен': ('driver_assigned_vehicles', 'driver', 'transport_vehicle'),
 'запчаст': ('vehicle_part',),
 'заявк': ('transport_request',),
 'заявок': ('transport_request',),
 'клиент': ('customer',),
 'консолидац': ('route_transport_request', 'route', 'transport_request'),
 'маршрут': ('route',),
 'материальн': ('inventory_stock', 'reference_data'),
 'машин': ('transport_vehicle',),
 'медицинск': ('medical_inspection',),
 'медосмотр': ('medical_inspection',),
 'на линии': ('trip', 'transport_vehicle', 'driver', 'route'),
 'нарушен': ('incident',),
 'нормa расхода': ('fuel_norm', 'transport_vehicle'),
 'остат': ('inventory_stock',),
 'остаток на складе': ('inventory_stock', 'reference_data'),
 'подразделен': ('reference_data',),
 'поездк': ('trip',),
 'пользовател': ('app_user',),
 'происшеств': ('incident',),
 'путев': ('waybill',),
 'путевой лист': ('waybill',),
 'рейс': ('trip',),
 'ремонт': ('vehicle_repair',),
 'сейчас в пути': ('trip', 'transport_vehicle', 'driver', 'route'),
 'склад': ('inventory_stock',),
 'смен': ('driver_shift',),
 'страхов': ('insurance_policy',),
 'тариф': ('tariff',),
 'тех осмотр': ('vehicle_technical_inspection', 'transport_vehicle'),
 'техобслуживан': ('maintenance_plan',),
 'техосмотр': ('vehicle_technical_inspection', 'transport_vehicle'),
 'тип топлива': ('fuel_type', 'vehicle_reference_data_fuel_type', 'transport_vehicle'),
 'топлив': ('fuel_record',),
 'транспорт': ('transport_vehicle',),
 'трекер': ('vehicle_gps', 'position_log', 'transport_vehicle'),
 'установк датчик': ('vehicle_fuel_sensor_installation', 'fuel_sensor', 'transport_vehicle'),
 'филиал': ('reference_data',),
 'шофер': ('driver',),
 'штраф': ('fine',)}

TABLE_NOTES = {'app_user': '---------------------------------------------------------------------\n'
             'Tizim foydalanuvchilari (login, parol hash, email, F.I.Sh., faollik holati).\n'
             'TIZIMGA KIRUVCHI BARCHA FOYDALANUVCHILAR SHU JADVALDA. Rollar alohida\n'
             "user_role jadvalida (bitta foydalanuvchida bir nechta rol bo'lishi mumkin).\n"
             'app_user ishlatiladi.\n'
             '---------------------------------------------------------------------',
 'atil_transport_payroll_source': '---------------------------------------------------------------------\n'
                                  'READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.\n'
                                  '---------------------------------------------------------------------',
 'attachment': '---------------------------------------------------------------------\n'
               'Yuklangan fayllarning umumiy reyestri (nom, MIME turi, hajmi, URL).\n'
               "FAYLNING O'ZI SHU JADVALDA, LEKIN U QAYSI OBYEKTGA TEGISHLILIGI ALOHIDA\n"
               "BOG'LOVCHI JADVALLARDA: vehicle_photo, vehicle_accident_attachment,\n"
               'vehicle_technical_inspection_photo.\n'
               '---------------------------------------------------------------------',
 'audit_event': '---------------------------------------------------------------------\n'
                "Muhim biznes amallarining audit izi: guvohnoma berish/bekor qilish, yoqilg'i\n"
                "limiti o'zgarishi, yoqilg'i ruxsatnomasi tasdiqlash/rad etish, ish haqi\n"
                "tariflarini o'zgartirish. before_snapshot va after_snapshot da o'zgarishdan\n"
                "oldingi va keyingi holat JSON ko'rinishida turadi.\n"
                "KIM NIMANI QACHON O'ZGARTIRGANI SO'RALSA SHU JADVALDAN OLINADI.\n"
                '---------------------------------------------------------------------',
 'audit_retention_source': '---------------------------------------------------------------------\n'
                           'READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.\n'
                           '---------------------------------------------------------------------',
 'chemical_quality_load_current': '---------------------------------------------------------------------\n'
                                  'READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.\n'
                                  '---------------------------------------------------------------------',
 'chemical_quality_passport_current': '---------------------------------------------------------------------\n'
                                      'READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.\n'
                                      '---------------------------------------------------------------------',
 'chemical_quality_release_current': '---------------------------------------------------------------------\n'
                                     'READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.\n'
                                     '---------------------------------------------------------------------',
 'chemical_quality_rule_current': '---------------------------------------------------------------------\n'
                                  'READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.\n'
                                  '---------------------------------------------------------------------',
 'chemical_safety_authority_current': '---------------------------------------------------------------------\n'
                                      'READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.\n'
                                      '---------------------------------------------------------------------',
 'chemical_safety_current': '---------------------------------------------------------------------\n'
                            'READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.\n'
                            '---------------------------------------------------------------------',
 'customer': '---------------------------------------------------------------------\n'
             "Mijozlar (buyurtmachilar) ma'lumotlari: nomi, INN, bank hisobi, aloqa shaxsi.\n"
             "kind — mijoz turi: EXTERNAL (tashqi), INTERNAL (ichki bo'lim), B2C, GOV.\n"
             '---------------------------------------------------------------------',
 'customer_settlement_act': '---------------------------------------------------------------------\n'
                            'Mijoz bilan davr uchun hisob-kitob akti: qancha reys, qancha km, qancha tonna,\n'
                            'qancha soat va umumiy summa. period_from/period_to davrni, tariff_id qaysi '
                            'tarif\n'
                            "qo'llanganini ko'rsatadi.\n"
                            "MIJOZGA QANCHA HISOBLANGANI SO'RALSA SHU JADVALDAN OLINADI.\n"
                            '---------------------------------------------------------------------',
 'document_audit': '---------------------------------------------------------------------\n'
                   'HUJJAT AUDITI — hujjat ustidagi amallar tarixi.\n'
                   'action (amal), actor (kim bajargan), occurred_at (qachon),\n'
                   'details (tafsilot), document_id (qaysi hujjat).\n'
                   'DIQQAT: bu YAGONA hujjat audit jadvali. Ilgari `document_audit_entry`\n'
                   "degan ikkinchi jadval bor edi — u bazadan o'chirilgan.\n"
                   '---------------------------------------------------------------------',
 'document_template': "Hujjat shablonlari: document_type — hujjat turi kodi; code — shablon identifikatori.\n"
                      "Hujjat shablonlari (yo'l varaqasi, TTN, marshrut varaqasi, transport akti,\n"
                      "yetkazish tasdig'i). body_template — shablon matni, template_version — versiya.\n"
                      'Faol shablonlar active=true.\n'
                      '---------------------------------------------------------------------',
 'document_version': '---------------------------------------------------------------------\n'
                     'Transport hujjatining har bir versiyasi: fayl nomi, hajmi, SHA-256 checksum,\n'
                     'saqlash kaliti (storage_key) va payload JSON. Bitta hujjatda bir nechta versiya\n'
                     "bo'lishi mumkin — version_number bo'yicha tartiblanadi.\n"
                     "HUJJATNING OXIRGI VERSIYASI KERAK BO'LSA version_number MAX bo'yicha olinadi.\n"
                     '---------------------------------------------------------------------',
 'driver': '---------------------------------------------------------------------\n'
           "HAYDOVCHILAR BO'YICHA ASOSIY JADVAL — BARCHA HAYDOVCHI MA'LUMOTLARI SHU\n"
           'JADVALDAN OLINADI. F.I.Sh., tabel raqami (employee_id), telefon, lavozim,\n'
           "guvohnoma raqami va muddati (license_valid_until), tibbiy ko'rik muddati\n"
           '(medical_certificate_valid_until), biriktirilgan mashina (transport_vehicle.assigned_driver_id '
           "orqali; ko'p-ko'pga esa vehicle_assigned_drivers jadvali),\n"
           "va bo'lim.\n"
           'DIQQAT: medical_cleared_today ustuni nomiga QARAMANG — u HAR KUNI\n'
           "TOZALANMAYDI. 02.09.2026 o'lchovi: 206 aktiv haydovchidan 128 tasida\n"
           "u `true`, holbuki o'sha kuni ATIGI 1 kishi ko'rikdan o'tgan (qolganlari\n"
           '3 kun oldin). "Bugun ko\'rikdan o\'tganmi" degan savolga BU USTUNDAN\n'
           'javob berilmaydi — medical_inspection dan shift_date + status olinadi.\n'
           'driver_availability_status — bandligi: AVAILABLE, RESERVED_FOR_TRIP, ON_TRIP,\n'
           'REST_REQUIRED, SICK_LEAVE, BLOCKED, UNAVAILABLE.\n'
           'employment_status — mehnat holati: ACTIVE, ON_LEAVE, SUSPENDED, TERMINATED.\n'
           '---------------------------------------------------------------------',
 'driver_assigned_vehicles': '---------------------------------------------------------------------\n'
                             "Haydovchiga biriktirilgan mashinalar ro'yxati (bitta haydovchida bir nechta\n"
                             "mashina bo'lishi mumkin). Asosiy mashina "
                             'driver.transport_vehicle.assigned_driver_id da.\n'
                             '---------------------------------------------------------------------',
 'driver_completed_trip': '---------------------------------------------------------------------\n'
                          'Haydovchi yakunlagan reyslarning qisqa tarixi (reys raqami, mashina, yakunlangan\n'
                          "vaqt). HAYDOVCHI QANCHA REYS BAJARGANI SO'RALSA SHU JADVALDAN TEZ OLINADI,\n"
                          "to'liq reys ma'lumoti esa trip jadvalida.\n"
                          '---------------------------------------------------------------------',
 'driver_credential': '---------------------------------------------------------------------\n'
                      "Haydovchining identifikatsiya vositalari: RFID karta yoki QR kod. Yoqilg'i\n"
                      'quyish shoxobchasida haydovchini tanish uchun ishlatiladi. token_hash — kalitning\n'
                      "hash'i, active/revoked_at — faollik holati, expires_at — muddati.\n"
                      "YOQILG'I RUXSATNOMASI (fuel_authorization) SHU CREDENTIAL ORQALI BERILADI.\n"
                      '---------------------------------------------------------------------',
 'driver_document': '---------------------------------------------------------------------\n'
                    'Haydovchi hujjatlarining skanlari: guvohnoma, passport, tibbiy sertifikat va\n'
                    'boshqalar. s3_url — faylning manzili. Hujjat MUDDATLARI bu jadvalda emas,\n'
                    'driver jadvalida (license_valid_until, medical_certificate_valid_until).\n'
                    '---------------------------------------------------------------------',
 'driver_license_category': '---------------------------------------------------------------------\n'
                            'Haydovchining haydovchilik guvohnomasi toifalari: A, B, BE, C, CE, D, DE.\n'
                            "BITTA HAYDOVCHIDA BIR NECHTA TOIFA BO'LADI. Marshrut talab qilgan toifa\n"
                            'route.required_driver_category da — mos haydovchi tanlashda shu jadval bilan\n'
                            'JOIN qilinadi.\n'
                            '---------------------------------------------------------------------',
 'driver_shift': '---------------------------------------------------------------------\n'
                 'Haydovchi smenalari: reja va amaldagi boshlanish/tugash vaqti, ishlangan soat,\n'
                 "tungi soat (night_hours), qo'shimcha soat (overtime_hours).\n"
                 'shift_type: DAY, NIGHT, SPLIT, STANDBY, DAY_OFF, VACATION, SICK_LEAVE.\n'
                 'status: PLANNED, CONFIRMED, COMPLETED, CANCELLED.\n'
                 "HAYDOVCHI ISH VAQTI VA QO'SHIMCHA SOATLAR SO'RALSA SHU JADVALDAN OLINADI —\n"
                 'ish haqi hisobi payroll_rate bilan birga qilinadi.\n'
                 '---------------------------------------------------------------------',
 'eimzo_signature': '---------------------------------------------------------------------\n'
                    "Elektron raqamli imzo (E-IMZO) sertifikati ma'lumotlari: STIR/PINFL, tashkilot\n"
                    'yoki jismoniy shaxs nomi, sertifikat seriya raqami, imzo natijasi (success,\n'
                    "error_code). app_user ga bog'langan.\n"
                    'HUJJATNI KIM IMZOLAGANI transport_document.signature_* ustunlarida.\n'
                    "(Ilgari `eimzo` deb atalardi — sxema ko'chirishda nomi o'zgargan.)\n"
                    '---------------------------------------------------------------------',
 'emergency_medical_case': '---------------------------------------------------------------------\n'
                           "SMENA DAVOMIDAGI SHOSHILINCH TIBBIY HOLAT (haydovchi yo'lda kasal\n"
                           "bo'lib qolgani). Kasallik turi (illness_type), sodir bo'lgan vaqt\n"
                           "(incident_at), ko'rsatilgan yordam (emergency_aid_description),\n"
                           "mutaxassisga yo'llanma, qaror vaqti va ishga qaytishni to'suvchi\n"
                           "muddat (blocking_ends_at). Haydovchi, mashina va reysga bog'lanadi.\n"
                           '"Shoshilinch tibbiy holat", "haydovchi kasal bo\'ldi" degan savol\n'
                           'SHU JADVALDAN olinadi — waybill.emergency_dispatch dan EMAS, u\n'
                           "butunlay boshqa narsa (shoshilinch jo'natma).\n"
                           '---------------------------------------------------------------------',
 'emergency_medical_status_history': '---------------------------------------------------------------------\n'
                                     'Shoshilinch tibbiy holat (emergency_medical_case) holatining\n'
                                     "O'ZGARISHLAR TARIXI: qaysi holatdan qaysi holatga (from_status ->\n"
                                     "to_status), qachon va kim o'zgartirgani, izoh bilan.\n"
                                     '---------------------------------------------------------------------',
 'erp_trip_outbox': '---------------------------------------------------------------------\n'
                    "Reys ma'lumotini tashqi ERP tizimiga yuborish navbati (outbox pattern).\n"
                    'status, attempt_count, last_error, next_attempt_at — yuborish holati.\n'
                    "ERP GA REYS KETMAGANI YOKI XATO BERGANI SO'RALSA SHU JADVALDAN OLINADI\n"
                    "(status <> yuborilgan yoki last_error to'ldirilgan qatorlar).\n"
                    '---------------------------------------------------------------------',
 'erp_vehicle_outbox': '---------------------------------------------------------------------\n'
                       "Mashina ma'lumotini tashqi ERP tizimiga yuborish navbati. Ishlash tartibi\n"
                       'erp_trip_outbox bilan bir xil.\n'
                       '---------------------------------------------------------------------',
 'fine': '---------------------------------------------------------------------\n'
         'Jarimalar: tezlik oshirish, marshrutdan chiqish, bekor turish, YHXB jarimasi,\n'
         "yoqilg'idan noto'g'ri foydalanish, zarar. Summasi (amount), holati\n"
         "(OPEN, UNDER_REVIEW, CONFIRMED, DISMISSED, PAID), sodir bo'lgan vaqti.\n"
         "trip, transport_vehicle jadvallariga bog'langan; haydovchi(lar) esa fine_driver\n"
         "bog'lovchi jadvali orqali (bitta jarimada bir nechta haydovchi bo'lishi mumkin).\n"
         "source_violation_id — jarima speed_violation dan avtomatik yaratilgan bo'lsa.\n"
         '---------------------------------------------------------------------',
 'fine_driver': '---------------------------------------------------------------------\n'
                "Jarima va haydovchi o'rtasidagi bog'lovchi jadval. HAYDOVCHINING JARIMALARI\n"
                "SO'RALSA fine JADVALI SHU JADVAL ORQALI JOIN QILINADI.\n"
                '---------------------------------------------------------------------',
 'fuel_authorization': '---------------------------------------------------------------------\n'
                       "Yoqilg'i quyishga berilgan ruxsatnoma: so'ralgan (requested_liters), tasdiqlangan\n"
                       '(approved_liters) va amalda quyilgan (dispensed_liters) litr.\n'
                       'status: APPROVED, REJECTED, COMPLETED, CANCELLED. rejection_reason — rad etish\n'
                       'sababi. credential_id — haydovchi qaysi karta/QR bilan tanilgani.\n'
                       'RUXSAT BERILGAN LEKIN QUYILMAGAN yoki ORTIQCHA QUYILGAN holatlar\n'
                       'approved_liters va dispensed_liters ni solishtirib topiladi.\n'
                       '---------------------------------------------------------------------',
 'fuel_card_current_financial_revision': '---------------------------------------------------------------------\n'
                                         'READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida '
                                         'tasvirlangan.\n'
                                         '---------------------------------------------------------------------',
 'fuel_card_transaction': '---------------------------------------------------------------------\n'
                          "Yoqilg'i kartasi tranzaksiyalari (tashqi provayderdan import qilinadi): litr,\n"
                          'summa, shoxobcha nomi, karta raqami, tashqi tranzaksiya id.\n'
                          "CHEK BO'YICHA QUYILGAN YOQILG'I SHU JADVALDA. Sensor ko'rsatkichi bilan\n"
                          'solishtirish uchun fuel_sensor_reading ishlatiladi.\n'
                          '---------------------------------------------------------------------',
 'fuel_inventory_document': '---------------------------------------------------------------------\n'
                            "Yoqilg'i ombori hujjatlari: kirim, chiqim, inventarizatsiya.\n"
                            "book_balance_liters (kitob bo'yicha qoldiq), actual_balance_liters (amaldagi\n"
                            'qoldiq) va delta_liters (tafovut) — INVENTARIZATSIYA TAFOVUTI SHU JADVALDAN\n'
                            'OLINADI. status: DRAFT, CONFIRMED, CANCELLED.\n'
                            '---------------------------------------------------------------------',
 'fuel_limit': '---------------------------------------------------------------------\n'
               "Yoqilg'i limitlari: haydovchi yoki mashina uchun kunlik/oylik maksimal litr va\n"
               'summa. subject_type — DRIVER yoki VEHICLE, window_type — DAY yoki MONTH.\n'
               "Bitta subyekt + yoqilg'i turi + davr uchun bitta faol limit bo'ladi.\n"
               'LIMIT OSHGANI notification jadvalida FUEL_LIMIT_EXCEEDED sifatida qayd etiladi.\n'
               '---------------------------------------------------------------------',
 'fuel_lot_allocation_effective': '---------------------------------------------------------------------\n'
                                  'READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.\n'
                                  '---------------------------------------------------------------------',
 'fuel_lot_composition_effective': '---------------------------------------------------------------------\n'
                                   'READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.\n'
                                   '---------------------------------------------------------------------',
 'fuel_norm': '---------------------------------------------------------------------\n'
              "Mashinaning yoqilg'i sarf normasi: 100 km ga qancha litr (liters_per100km) va\n"
              'ruxsat etilgan chetlanish foizi (tolerance_percent). effective_from/effective_to\n'
              '— norma qaysi davrda amal qilgani.\n'
              'NORMA HAR BIR MASHINA UCHUN ALOHIDA belgilanadi (vehicle_id).\n'
              '---------------------------------------------------------------------',
 'fuel_owner_current_receipt': '---------------------------------------------------------------------\n'
                               'READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.\n'
                               '---------------------------------------------------------------------',
 'fuel_owner_quality_receipt': '---------------------------------------------------------------------\n'
                               'READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.\n'
                               '---------------------------------------------------------------------',
 'fuel_record': '---------------------------------------------------------------------\n'
                "YOQILG'I SARFI BO'YICHA ASOSIY JADVAL — QUYISH VA SARF YOZUVLARI SHU JADVALDAN\n"
                'OLINADI. Litr, summa, amaldagi sarf (actual_consumption_per100km), norma\n'
                '(norm_liters_per100km) va ulardan chetlanish foizi (deviation_percent).\n'
                'severity — chetlanish darajasi: NONE, WARNING, CRITICAL.\n'
                "YOQILG'I ANOMALIYASI SO'RALSA severity <> 'NONE' bo'yicha olinadi, batafsil\n"
                'sabab esa fuel_record_risk_flag jadvalida.\n'
                '---------------------------------------------------------------------',
 'fuel_sensor': '---------------------------------------------------------------------\n'
                "Yoqilg'i sathi sensorlarining reyestri: ishlab chiqaruvchi, model, seriya raqami,\n"
                "sensor kodi, bak hajmi. Mashinaga o'rnatilishi\n"
                'vehicle_fuel_sensor_installation jadvali orqali.\n'
                '---------------------------------------------------------------------',
 'fuel_sensor_reading': '---------------------------------------------------------------------\n'
                        "Sensor ko'rsatkichlari: bakdagi yoqilg'i litr va foizda, koordinata,\n"
                        "harorat, kuchlanish, o'lchov vaqti (recorded_at).\n"
                        'CHEK VA SENSOR TAFOVUTINI TOPISH UCHUN fuel_card_transaction BILAN vaqt va\n'
                        "mashina bo'yicha solishtiriladi (yoqilg'i o'g'irligini aniqlash).\n"
                        '---------------------------------------------------------------------',
 'fuel_type': '---------------------------------------------------------------------\n'
              "Yoqilg'i turlari katalogi (kod va nomi). Mashina qaysi yoqilg'i bilan\n"
              "ishlashini vehicle_reference_data_fuel_type bog'lovchi jadvali ko'rsatadi.\n"
              '---------------------------------------------------------------------',
 'incident': '---------------------------------------------------------------------\n'
             "Hodisalar (telematika va nazorat asosida): tezlik buzilishi, yoqilg'i\n"
             "tafovuti, marshrutdan chiqish, ruxsatsiz to'xtash, qattiq tormozlash, keskin\n"
             'tezlashish, uzoq bekor turish, geozonadan chiqish, texnik xizmat muddati,\n'
             "avariya, o'g'irlik.\n"
             'severity: LOW, MEDIUM, HIGH, CRITICAL. status: OPEN, IN_PROGRESS, RESOLVED,\n'
             'CLOSED, DISMISSED. Kim aniqlagan (created_by) va kim hal qilgan (resolved_by)\n'
             "app_user ga bog'langan.\n"
             "HAL QILINMAGAN HODISALAR status IN ('OPEN','IN_PROGRESS') bo'yicha olinadi.\n"
             '---------------------------------------------------------------------',
 'insurance_policy': '---------------------------------------------------------------------\n'
                     "Sug'urta polislari: OSAGO, KASKO, CARGO, LIABILITY, PASSENGER. Polis raqami,\n"
                     "sug'urta kompaniyasi, sug'urta summasi, mukofot (premium), amal qilish muddati\n"
                     '(valid_from, valid_to).\n'
                     'status: ACTIVE, EXPIRING_SOON, EXPIRED, CANCELLED.\n'
                     "MUDDATI TUGAYOTGAN SUG'URTALAR valid_to bo'yicha yoki status='EXPIRING_SOON'\n"
                     'bilan olinadi.\n'
                     '---------------------------------------------------------------------',
 'integration_loading_bridge_current': '---------------------------------------------------------------------\n'
                                       'READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.\n'
                                       '---------------------------------------------------------------------',
 'integration_toir_inbox_current': '---------------------------------------------------------------------\n'
                                   'READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.\n'
                                   '---------------------------------------------------------------------',
 'inventory_stock': '---------------------------------------------------------------------\n'
                    "Ombordagi tovar-material qoldiqlari (item, ombor, miqdor, o'lchov birligi).\n"
                    'Tovar nomlari product jadvalida.\n'
                    '---------------------------------------------------------------------',
 'maintenance_plan': '---------------------------------------------------------------------\n'
                     'Texnik xizmat rejasi: xizmat turi (moy almashtirish, shina, tormoz, taqsimlash\n'
                     "tasmasi, texnik ko'rik), oxirgi xizmat sanasi va probegi, keyingi muddat\n"
                     '(next_due_at) va probeg (next_due_at_km).\n'
                     'status: ACTIVE, DUE_SOON, OVERDUE, PAUSED.\n'
                     "MUDDATI O'TGAN XIZMATLAR status='OVERDUE' bo'yicha olinadi.\n"
                     'DIQQAT: maintenance_plan jadvali ham mavjud — u TO_1/TO_2/SEASONAL\n'
                     'turidagi rejalashtirilgan TXKlar uchun va reysga chiqishni bloklashi mumkin\n'
                     '(blocked_on_overdue).\n'
                     '---------------------------------------------------------------------',
 'medical_inspection': '---------------------------------------------------------------------\n'
                       "Smenaga chiqish oldidan tibbiy ko'rik: qon bosimi, puls, harorat, ko'rik natijasi\n"
                       'va amal qilish muddati (to_date). status: FIT (yaroqli), RESTRICTED (cheklangan),\n'
                       'UNFIT (yaroqsiz), CANCELLED.\n'
                       "HAYDOVCHI BUGUN TIBBIY KO'RIKDAN O'TGANMI SO'RALSA shift_date va status\n"
                       "bo'yicha olinadi (status='FIT' bo'lsa o'tgan). driver.medical_cleared_today\n"
                       'ni ISHLATMANG: u eskirgan bayroq, yuqoridagi izohga qarang.\n'
                       '---------------------------------------------------------------------',
 'notification': '---------------------------------------------------------------------\n'
                 "Foydalanuvchiga yuborilgan bildirishnomalar: yoqilg'i limitiga yaqinlashish,\n"
                 "limit oshib ketishi, credential muddati tugashi, noma'lum credential ishlatilishi.\n"
                 "severity: INFO, WARNING, CRITICAL. read_at bo'sh bo'lsa — o'qilmagan.\n"
                 "reference_id bildirishnoma tegishli obyektni ko'rsatadi.\n"
                 '---------------------------------------------------------------------',
 'payroll_rate': '---------------------------------------------------------------------\n'
                 'Haydovchi ish haqi tariflari: reys uchun (trip_rate), km uchun (per_km_rate),\n'
                 "tungi soat (night_hour_rate), qo'shimcha soat (overtime_hour_rate) va\n"
                 'chetlanish uchun jarima koeffitsienti (deviation_penalty_rate).\n'
                 "ISH HAQI HISOBI driver_shift VA trip MA'LUMOTLARI BILAN BIRGA QILINADI.\n"
                 "(Ilgari `payroll_rate` deb atalardi — sxema ko'chirishda nomi o'zgargan.)\n"
                 '---------------------------------------------------------------------',
 'position_log': '---------------------------------------------------------------------\n'
                 "GPS qurilmalaridan kelgan xom koordinata yozuvlari (device_id bo'yicha, ATIL\n"
                 "obyektlariga bevosita bog'lanmagan). Qurilma qaysi mashinaga tegishliligi\n"
                 'vehicle_gps jadvalida (device_id → vehicle_id).\n'
                 "MASHINANING JOYLASHUVI SO'RALSA avval vehicle_telemetry_state ga qarash kerak —\n"
                 'u tayyor oxirgi holatni beradi.\n'
                 '---------------------------------------------------------------------',
 'product': '---------------------------------------------------------------------\n'
            "Tovar/material nomenklaturasi (nomi, tavsifi, o'lchov birligi).\n"
            'Ombordagi qoldiqlari inventory_stock jadvalida.\n'
            '---------------------------------------------------------------------',
 'reference_data': '---------------------------------------------------------------------\n'
                   "UMUMIY KATALOG JADVALI — BARCHA MA'LUMOTNOMALAR SHU JADVALDA SAQLANADI va\n"
                   "catalog_type bilan ajratiladi: BRANCHES (filiallar), DEPARTMENTS (bo'limlar),\n"
                   'POSITIONS (lavozimlar), LOCATIONS (manzillar), FUEL_TYPES, FUEL_WAREHOUSES\n'
                   "(yoqilg'i omborlari), FUEL_SOURCE_TYPES, FUEL_DOCUMENT_TYPES, ORG_STRUCTURE.\n"
                   "BO'LIM, FILIAL, MANZIL YOKI LAVOZIM NOMI KERAK BO'LSA SHU JADVALDAN\n"
                   "catalog_type BO'YICHA FILTRLAB OLINADI. parent_id ierarxiyani beradi,\n"
                   'latitude/longitude — manzil koordinatalari.\n'
                   '---------------------------------------------------------------------',
 'repair_order_part_request': '---------------------------------------------------------------------\n'
                              "Ta'mirga EHTIYOT QISM so'rovi: qaysi ta'mir buyurtmasiga, qaysi tovar\n"
                              "(item_name), qancha so'ralgan/berilgan/ishlatilgan/qaytarilgan,\n"
                              "o'lchov birligi, qaysi ombordan. Ta'mirning o'zi vehicle_repair da.\n"
                              '---------------------------------------------------------------------',
 'route': '---------------------------------------------------------------------\n'
          "MARSHRUTLAR BO'YICHA ASOSIY JADVAL. Marshrut raqami, nomi, rejalashtirilgan\n"
          "davomiylik (planned_duration_minutes) — MASOFA USTUNI BU JADVALDA YO'Q,\n"
          'amaldagi masofa uchun trip.actual_distance_km ishlatiladi;\n'
          'talab qilinadigan transport turi\n'
          '(required_transport_type) va haydovchi toifasi (required_driver_category),\n'
          'biriktirilgan mashina va haydovchi.\n'
          'status: DRAFT, READY_FOR_ASSIGNMENT, DRIVER_ASSIGNED, VEHICLE_ASSIGNED,\n'
          'FULLY_ASSIGNED, TRIP_PLANNED, CANCELLED.\n'
          "assignment_decision_status biriktirish bosqichini ko'rsatadi.\n"
          "Marshrut nuqtalari route_point jadvalida, bog'liq so'rovlar\n"
          'route_transport_request orqali.\n'
          '---------------------------------------------------------------------',
 'route_point': '---------------------------------------------------------------------\n'
                'Marshrut nuqtalari: ketma-ketlik raqami (sequence_number), nuqta turi\n'
                '(ORIGIN, WAYPOINT, LOADING, UNLOADING, DESTINATION), oldingi nuqtadan masofa va\n'
                'yurish vaqti, rejadagi kelish/ketish vaqti, koordinata.\n'
                "MARSHRUT YO'NALISHI SO'RALSA sequence_number BO'YICHA TARTIBLANADI.\n"
                '---------------------------------------------------------------------',
 'route_transport_request': '---------------------------------------------------------------------\n'
                            "Marshrut va transport so'rovi o'rtasidagi bog'lovchi jadval. BITTA MARSHRUTGA\n"
                            "BIR NECHTA SO'ROV BIRLASHTIRILISHI MUMKIN (konsolidatsiya). So'rov qaysi\n"
                            'marshrutga tushganini bilish uchun shu jadval orqali JOIN qilinadi.\n'
                            '---------------------------------------------------------------------',
 'speed_violation': '---------------------------------------------------------------------\n'
                    'Tezlik oshirish buzilishlari: amaldagi tezlik (speed_kph), ruxsat etilgan chegara\n'
                    '(limit_kph) va oshib ketgan qiymat (excess_kph), koordinata, vaqt.\n'
                    'telematics_event_id — buzilish qaysi telematika hodisasidan aniqlangani.\n'
                    "fine_id to'ldirilgan bo'lsa — buzilish uchun jarima yozilgan.\n"
                    '---------------------------------------------------------------------',
 'tariff': '---------------------------------------------------------------------\n'
           'Tashish tariflari: narx modeli (PER_KM, PER_TON, PER_TON_KM, PER_TRIP, PER_HOUR),\n'
           "summa, minimal to'lov, tungi va xavfli yuk uchun ustama foizlari, amal qilish\n"
           'muddati. status: DRAFT, ACTIVE, ARCHIVED.\n'
           "MIJOZ HISOB-KITOBIDA (customer_settlement_act) shu tarif qo'llanadi.\n"
           '---------------------------------------------------------------------',
 'telematics_event': '---------------------------------------------------------------------\n'
                     "TELEMATIKA HODISALARI BO'YICHA ASOSIY JADVAL — GPS VA BORT MA'LUMOTLARI SHU\n"
                     "JADVALDAN OLINADI. Koordinata, tezlik (speed_kph), yo'nalish (heading),\n"
                     "probeg (odometer_km), yoqilg'i sathi (fuel_level), dvigatel holati (engine_on),\n"
                     'qurilma id va hodisa vaqti (timestamp).\n'
                     "Bu jadval juda katta bo'ladi — HAR DOIM vehicle_id VA VAQT ORALIG'I BO'YICHA\n"
                     'FILTRLANADI. Mashinaning oxirgi holati uchun vehicle_telemetry_state ishlatiladi\n'
                     '(bu jadvalni skanerlash shart emas).\n'
                     '---------------------------------------------------------------------',
 'telematics_geozone': '---------------------------------------------------------------------\n'
                       'Geozonalar: depo, obyekt, nazorat nuqtasi, taqiqlangan zona. Markaz koordinatasi\n'
                       'va radius (radius_meters) bilan belgilanadi.\n'
                       'GEOZONADAN CHIQISH hodisasi incident jadvalida GEOFENCE_VIOLATION sifatida.\n'
                       '---------------------------------------------------------------------',
 'toir_equipment_status_receipt': '---------------------------------------------------------------------\n'
                                  "TOIR (texnik xizmat va ta'mirlash) tizimidan kelgan uskuna holati "
                                  'xabarlari.\n'
                                  'Mashinaning tashqi tizimdagi holati shu yerga tushadi.\n'
                                  '---------------------------------------------------------------------',
 'toir_vehicle_outbox': '---------------------------------------------------------------------\n'
                        "Mashina ma'lumotini TOIR tizimiga yuborish navbati (outbox). Ishlash tartibi\n"
                        'erp_trip_outbox bilan bir xil.\n'
                        '---------------------------------------------------------------------',
 'transport_document': '---------------------------------------------------------------------\n'
                       "TRANSPORT HUJJATLARI BO'YICHA ASOSIY JADVAL — YO'L VARAQASI, TTN, MARSHRUT\n"
                       "VARAQASI, TRANSPORT AKTI VA YETKAZISH TASDIG'I SHU JADVALDAN OLINADI.\n"
                       'Hujjat raqami (document_number), turi (document_type), shabloni, holati\n'
                       '(GENERATED, UPDATED, CONFIRMED, SIGNING_PENDING, SIGNED, ARCHIVED, CANCELLED),\n'
                       "imzo talab qilinishi (signature_required) va imzo ma'lumotlari.\n"
                       "Reys, mashina, haydovchi va so'rovga bog'lanadi. Versiyalari document_version,\n"
                       'tarixi document_audit jadvalida.\n'
                       '---------------------------------------------------------------------',
 'transport_load_current_claims': '---------------------------------------------------------------------\n'
                                  'READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.\n'
                                  '---------------------------------------------------------------------',
 'transport_load_manifest_latest': '---------------------------------------------------------------------\n'
                                   'READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida tasvirlangan.\n'
                                   '---------------------------------------------------------------------',
 'transport_request': '---------------------------------------------------------------------\n'
                      "TRANSPORT SO'ROVLARI BO'YICHA ASOSIY JADVAL — BARCHA TRANSPORT BUYURTMALARI SHU\n"
                      "JADVALDAN OLINADI. So'rov raqami, tashabbuskor (initiator_name), bo'lim,\n"
                      "tasdiqlovchi (approver_name), biriktirilgan logist, jo'natish va yetkazish\n"
                      'manzili (origin_location, destination_location) hamda koordinatalari, yuk\n'
                      "tavsifi, og'irligi KG DA (cargo_weight_kg) va hajmi m3 da, rejadagi jo'nash va\n"
                      'kelish vaqti, ustuvorlik, talab qilinadigan transport turi.\n'
                      'status: DRAFT, PENDING_DEPARTMENT_APPROVAL, PENDING_TRANSPORT_APPROVAL, APPROVED,\n'
                      'READY_FOR_PLANNING, ASSIGNED, IN_PROGRESS, COMPLETED, CANCELLED,\n'
                      'REJECTED_BY_DEPARTMENT, REJECTED_BY_TRANSPORT.\n'
                      "TASDIQ KUTAYOTGAN SO'ROVLAR status LIKE 'PENDING%' bo'yicha olinadi, rad etish\n"
                      'sababi rejection_reason da. Tarixi transport_request_audit, nuqtalari\n'
                      'transport_request_point jadvalida.\n'
                      '---------------------------------------------------------------------',
 'transport_request_audit': '---------------------------------------------------------------------\n'
                            "Transport so'rovi ustidagi amallar tarixi: amal, oldingi va yangi status, kim\n"
                            'bajargani (actor_name), vaqti va izohi.\n'
                            "SO'ROV NEGA RAD ETILGANI YOKI QAYSI BOSQICHDA TURGANI SO'RALSA SHU JADVALDAN\n"
                            'OLINADI.\n'
                            '---------------------------------------------------------------------',
 'transport_request_point': '---------------------------------------------------------------------\n'
                            "Transport so'rovidagi yuklash/tushirish nuqtalari: ketma-ketlik, nuqta turi\n"
                            '(ORIGIN, WAYPOINT, LOADING, UNLOADING, DESTINATION), manzil, koordinata,\n'
                            'oldingi nuqtadan masofa va vaqt.\n'
                            '---------------------------------------------------------------------',
 'transport_vehicle': '---------------------------------------------------------------------\n'
                      "MASHINALAR (AVTOPARK) BO'YICHA ASOSIY JADVAL — BARCHA TRANSPORT MA'LUMOTLARI SHU\n"
                      'JADVALDAN OLINADI. Davlat raqami (plate_number), VIN, garaj raqami, marka va\n'
                      "model, yuk ko'tarish qobiliyati KG DA (payload_capacity_kg), hajmi m3,\n"
                      "foydalanishga topshirilgan sana, biriktirilgan haydovchi, bo'lim va filial,\n"
                      "GPS qurilma id, bugungi texnik ko'rik holati esa alohida "
                      'vehicle_technical_inspection\n'
                      "JURNALIDAN olinadi (transport_vehicle da bunday bayroq ustuni YO'Q).\n"
                      'current_status: ACTIVE, RESERVED, IN_OPERATION, IN_MAINTENANCE, BLOCKED,\n'
                      'DECOMMISSIONED. transport_type: TRUCK, VAN, FLATBED, TANKER, REFRIGERATED,\n'
                      'SPECIALIZED, MINIBUS, PICKUP, TRAILER, OTHER.\n'
                      'category: LIGHT, MEDIUM, HEAVY, EXTRA_HEAVY, SPECIAL.\n'
                      'ownership_type: OWNED, LEASED, RENTED.\n'
                      "BO'SH MASHINA = current_status='ACTIVE' VA OCHIQ REYSI YO'Q.\n"
                      'Ikkinchi shart SHART: bu bazada current_status yuritilmaydi va reysdagi\n'
                      "mashina ham 'ACTIVE' bo'lib qolaveradi (02.09.2026: 128 mashinadan\n"
                      "125 tasi 'ACTIVE'). Faqat current_status bilan hisoblangan\n"
                      '"foydalanish foizi" 95% chiqadi, holbuki reysda 2 ta mashina bor.\n'
                      "To'g'ri shakl:\n"
                      "WHERE v.current_status='ACTIVE' AND NOT EXISTS (\n"
                      'SELECT 1 FROM trip t WHERE t.vehicle_id=v.id\n'
                      "AND t.status IN ('PLANNED','ASSIGNED','STARTED',\n"
                      "'ARRIVED_AT_POINT','LOADED','UNLOADED'))\n"
                      '---------------------------------------------------------------------',
 'trip': '---------------------------------------------------------------------\n'
         "REYSLAR BO'YICHA ASOSIY JADVAL — BARCHA REYS MA'LUMOTLARI SHU JADVALDAN OLINADI.\n"
         "Reys raqami, marshrut, transport so'rovi, mashina va haydovchi; rejadagi va\n"
         "amaldagi jo'nash/kelish vaqti, amaldagi masofa (actual_distance_km) va\n"
         'marshrutdan chetlanish belgisi (deviation_flag).\n'
         "KECHIKISH USTUNI YO'Q — u HISOBLANADI, saqlanmaydi:\n"
         "jo'nab ketmagan  : now() - scheduled_departure_at\n"
         "yo'lda kechikkan : now() - scheduled_arrival_at\n"
         "`delay_minutes` deb ustun IZLAMANG, bunday ustun hech qachon bo'lmagan.\n"
         'status: PLANNED, ASSIGNED, STARTED, ARRIVED_AT_POINT, LOADED, UNLOADED,\n'
         'COMPLETED, CANCELLED, INTERRUPTED.\n'
         "KECHIKAYOTGAN REYSLAR delay_minutes > 0 BO'YICHA OLINADI.\n"
         "FAOL REYSLAR status IN ('STARTED','ARRIVED_AT_POINT','LOADED','UNLOADED').\n"
         'Reys hodisalari trip_event jadvalida.\n'
         '---------------------------------------------------------------------',
 'trip_event': '---------------------------------------------------------------------\n'
               'Reys hodisalari: reys yaratildi, boshlandi, nuqtaga yetdi, yuklandi, tushirildi,\n'
               'bekor turish qayd etildi, marshrutdan chetlanish aniqlandi, yakunlandi, bekor\n'
               'qilindi. source — hodisa manbai: DRIVER, DISPATCHER, PLANNING_SERVICE,\n'
               "TELEMATICS_SERVICE, SYSTEM. payload_json da qo'shimcha ma'lumot.\n"
               "REYS YO'LIDA NIMA BO'LGANI SO'RALSA event_time BO'YICHA TARTIBLAB OLINADI.\n"
               '---------------------------------------------------------------------',
 'trip_route_effective_planning_manifest_latest': '---------------------------------------------------------------------\n'
                                                  'READ-ONLY VIEW: ustunlar SELECT uchun jadval shaklida '
                                                  'tasvirlangan.\n'
                                                  '---------------------------------------------------------------------',
 'user_department': '---------------------------------------------------------------------\n'
                    "Foydalanuvchining qaysi bo'limga (department) biriktirilganini ko'rsatadi.\n"
                    "BITTA FOYDALANUVCHIDA BITTA BO'LIM bo'ladi (user_id unique). Bo'lim nomi\n"
                    "reference_data jadvalida catalog_type='DEPARTMENTS' bo'yicha turadi.\n"
                    "(Ilgari `user_department` deb atalardi — sxema ko'chirishda nomi o'zgargan.)\n"
                    '---------------------------------------------------------------------',
 'user_role': '---------------------------------------------------------------------\n'
              "FOYDALANUVCHI ROLLARI (bog'lovchi jadval): user_id, role.\n"
              'Ilgari `app_user_role` deb atalardi.\n'
              '---------------------------------------------------------------------',
 'user_warehouse': '---------------------------------------------------------------------\n'
                   "Foydalanuvchining qaysi omborga biriktirilganini ko'rsatadi (yoqilg'i operatori,\n"
                   'ombor xodimi uchun). Bitta foydalanuvchida bitta ombor.\n'
                   "(Ilgari `user_warehouse` deb atalardi — sxema ko'chirishda nomi o'zgargan.)\n"
                   '---------------------------------------------------------------------',
 'vehicle_accident': '---------------------------------------------------------------------\n'
                     "Yo'l-transport hodisalari (avariyalar): hodisa raqami, turi (DRIVER_FAULT,\n"
                     'NATURAL_CAUSE, THIRD_PARTY_FAULT, OTHER), jiddiyligi (MINOR, MODERATE, SERIOUS,\n'
                     "CRITICAL), joyi va vaqti, jarohatlanganlar va halok bo'lganlar soni,\n"
                     "taxminiy va amaldagi ta'mirlash summasi, sug'urta da'vosi raqami.\n"
                     "TO'LOVNING TAQSIMLANISHI: insurance_paid_amount (sug'urta), driver_paid_amount\n"
                     '(haydovchi), factory_paid_amount (korxona).\n'
                     'status: REPORTED, UNDER_REVIEW, INSURANCE_PROCESSING, REPAIR_IN_PROGRESS,\n'
                     'RESOLVED, CLOSED, CANCELLED. Fayllari vehicle_accident_attachment orqali.\n'
                     '---------------------------------------------------------------------',
 'vehicle_accident_attachment': '---------------------------------------------------------------------\n'
                                "Avariya va yuklangan fayl (attachment) o'rtasidagi bog'lovchi jadval —\n"
                                'avariya rasmlari va hujjatlari.\n'
                                '---------------------------------------------------------------------',
 'vehicle_assigned_drivers': '---------------------------------------------------------------------\n'
                             "MASHINA-HAYDOVCHI BIRIKTIRUVI (ko'p-ko'pga bog'lovchi jadval).\n"
                             'Faqat ikki ustun: vehicle_id, driver_id.\n'
                             'Bitta mashinaga bir nechta haydovchi biriktirilishi mumkin.\n'
                             'ASOSIY (bitta) haydovchi esa transport_vehicle.assigned_driver_id da.\n'
                             '---------------------------------------------------------------------',
 'vehicle_document': '---------------------------------------------------------------------\n'
                     "MASHINA HUJJATLARI BO'YICHA ASOSIY JADVAL: sug'urta, ro'yxatdan o'tish\n"
                     "guvohnomasi, texnik ko'rik, ekologik sertifikat, ruxsatnoma, lizing shartnomasi.\n"
                     'Hujjat raqami, bergan organ (issuing_authority), berilgan sana (issued_at) va\n'
                     'AMAL QILISH MUDDATI (expiry_date).\n'
                     "MUDDATI TUGAYOTGAN HUJJATLAR expiry_date BO'YICHA OLINADI.\n"
                     '---------------------------------------------------------------------',
 'vehicle_fuel_sensor_installation': '---------------------------------------------------------------------\n'
                                     "Yoqilg'i sensorining mashinaga o'rnatilish tarixi: o'rnatilgan va olib "
                                     'tashlangan\n'
                                     "vaqti, o'rnatish joyi, asosiy sensor ekanligi (primary_sensor).\n"
                                     "removed_at bo'sh bo'lsa — sensor hozir o'rnatilgan holatda.\n"
                                     '---------------------------------------------------------------------',
 'vehicle_gps': '---------------------------------------------------------------------\n'
                "Mashina va GPS qurilmasi o'rtasidagi bog'lanish (device_id, unique_id).\n"
                "XOM GPS YOZUVLARI (position_log) MASHINAGA SHU JADVAL ORQALI BOG'LANADI —\n"
                'position_log.device_id = vehicle_gps.device_id.\n'
                '---------------------------------------------------------------------',
 'vehicle_part': '---------------------------------------------------------------------\n'
                 'Mashina ehtiyot qismlari: shina, akkumulyator, moy va havo filtri, tormoz\n'
                 "kolodkasi. O'rnatilgan sana va probeg, kutilgan xizmat muddati (expected_life_km,\n"
                 'expected_life_days), narxi.\n'
                 'status: INSTALLED, IN_STOCK, REPLACED, WORN.\n'
                 "ALMASHTIRISH VAQTI KELGAN QISMLAR o'rnatilgan probeg + expected_life_km ni\n"
                 'mashinaning hozirgi probegi bilan solishtirib topiladi.\n'
                 '---------------------------------------------------------------------',
 'vehicle_photo': '---------------------------------------------------------------------\n'
                  'Mashina rasmlari va ular qaysi tomondan olingani (FRONT, REAR, LEFT, RIGHT,\n'
                  "CABIN, VIN). Faylning o'zi attachment jadvalida.\n"
                  '---------------------------------------------------------------------',
 'vehicle_plate_history': '---------------------------------------------------------------------\n'
                          "Mashina davlat raqamining o'zgarish tarixi. is_current=true bo'lgan qator —\n"
                          "hozirgi raqam (u transport_vehicle.plate_number bilan bir xil bo'lishi kerak).\n"
                          "ESKI RAQAM BO'YICHA MASHINA QIDIRILSA SHU JADVALDAN OLINADI.\n"
                          '---------------------------------------------------------------------',
 'vehicle_reference_data_fuel_type': '---------------------------------------------------------------------\n'
                                     "Mashina va reference_data katalogidagi yoqilg'i turi o'rtasidagi "
                                     "bog'lovchi\n"
                                     "jadval (FUEL_TYPES katalogi bo'yicha), 118 yozuv.\n"
                                     "YOQILG'I TURI NOMI `reference_data` DA:\n"
                                     'FROM vehicle_reference_data_fuel_type vr\n'
                                     'JOIN reference_data rd ON rd.id = vr.reference_data__id\n'
                                     'JOIN transport_vehicle v ON v.id = vr.vehicle_id\n'
                                     "`fuel_type` JADVALIGA ULANMANG — u BO'SH (0 qator, 02.09.2026).\n"
                                     'Unga ulangan query nol qator qaytaradi va "ma\'lumot yo\'q" degan\n'
                                     "NOTO'G'RI javob beriladi.\n"
                                     '---------------------------------------------------------------------',
 'vehicle_repair': '---------------------------------------------------------------------\n'
                   "Ta'mirlash ishlari: qaysi tugun (ENGINE, BRAKES, TIRES, BATTERY, ELECTRICAL,\n"
                   'CHASSIS), ustuvorligi, taxminiy narxi, bekor turish soati (downtime_hours).\n'
                   'status: OPEN, IN_PROGRESS, WAITING_PARTS, COMPLETED, CANCELLED.\n'
                   "blocks_release=true bo'lsa — MASHINA REYSGA CHIQARILMAYDI.\n"
                   '---------------------------------------------------------------------',
 'vehicle_status_history': '---------------------------------------------------------------------\n'
                           "Mashina holatining o'zgarish tarixi: oldingi va yangi status, kim "
                           "o'zgartirgani,\n"
                           'sababi va vaqti.\n'
                           'MASHINA QANCHA VAQT IN_MAINTENANCE YOKI BLOCKED HOLATDA TURGANI SHU JADVALDAN\n'
                           'hisoblanadi.\n'
                           '---------------------------------------------------------------------',
 'vehicle_technical_inspection': '---------------------------------------------------------------------\n'
                                 "Reysdan oldingi (PRE_TRIP) va reysdan keyingi (POST_TRIP) texnik ko'rik.\n"
                                 'Natija: FIT (yaroqli), LIMITED (cheklangan), BLOCKED (bloklangan). '
                                 'probeg,\n'
                                 "ko'rikni o'tkazgan shaxs, izohlar. Rasmlar ALOHIDA "
                                 'vehicle_technical_inspection_photo jadvalida.\n'
                                 'Rasmlari vehicle_technical_inspection_photo jadvalida ham.\n'
                                 '---------------------------------------------------------------------',
 'vehicle_technical_inspection_photo': '---------------------------------------------------------------------\n'
                                       "Texnik ko'rik rasmlari: mashina (VEHICLE) yoki taxometr/probeg "
                                       '(TACHOMETER)\n'
                                       "rasmi. Faylning o'zi attachment jadvalida.\n"
                                       '---------------------------------------------------------------------',
 'vehicle_telemetry_state': '---------------------------------------------------------------------\n'
                            'MASHINANING HOZIRGI (OXIRGI) HOLATI — bitta mashinaga bitta qator\n'
                            "(vehicle_id birlamchi kalit). Oxirgi koordinata, tezlik, probeg, yoqilg'i "
                            'sathi,\n'
                            'dvigatel holati, bekor turish (idle_time_seconds) va harakat vaqti, hozirgi '
                            'reys\n'
                            "va marshrut, marshrutdan chetlanish (deviation_active) va to'xtash "
                            '(stop_active)\n'
                            'belgilari.\n'
                            "MASHINA HOZIR QAYERDA / QANDAY HOLATDA SO'RALSA SHU JADVALDAN OLINADI —\n"
                            'katta telematics_event jadvalini skanerlash SHART EMAS.\n'
                            '---------------------------------------------------------------------',
 'waybill': '---------------------------------------------------------------------\n'
            "YO'L VARAQALARI (PUTEVOY LIST) — REYSNING RASMIY HUJJATI VA YOQILG'I HISOBI SHU\n"
            'JADVALDAN OLINADI. Varaqa raqami (waybill_number), berilgan sana, reja va\n'
            "amaldagi jo'nash/qaytish vaqti, spidometr boshi va oxiri (odometer_start_km,\n"
            "odometer_end_km), yuk tavsifi va og'irligi TONNADA.\n"
            "YOQILG'I: berilgan (fuel_issued_liters), jo'nashda bakdagi\n"
            '(fuel_at_departure_liters), qaytishda (fuel_at_return_liters), sarflangan\n'
            "(fuel_consumed_liters) va norma bo'yicha (fuel_norm_liters).\n"
            'NORMADAN ORTIQ SARF fuel_consumed_liters va fuel_norm_liters ni solishtirib\n'
            'topiladi.\n'
            "KO'RIKLAR: reysdan oldin va keyin tibbiy (pre_med_*, post_med_*) va mexanik\n"
            "(pre_mech_*, post_mech_*) ko'rik natijalari — PASSED, FAILED, NOT_PERFORMED.\n"
            'status: DRAFT, ISSUED, IN_USE, RETURNED, CLOSED, CANCELLED.\n'
            'generated_document_id — varaqa asosida yaratilgan transport_document.\n'
            '---------------------------------------------------------------------',
 'waybill_numbering': '---------------------------------------------------------------------\n'
                      "Yo'l varaqasi RAQAMLARINI berish hisoblagichi: varaqa turi bo'yicha\n"
                      "oxirgi berilgan va keyingi raqam, boshlang'ich raqam va raqam uzunligi.\n"
                      "Bu sozlama jadvali — varaqalarning O'ZI waybill da.\n"
                      '---------------------------------------------------------------------',
 'waybill_task': '---------------------------------------------------------------------\n'
                 "YO'L VARAQASIDAGI TOPSHIRIQLAR — bitta varaqa ichidagi yuk tashish\n"
                 "qatorlari. Yuk nomi va og'irligi (tonna), mijoz, yuklash va tushirish\n"
                 'manzili, masofa (distance_km), reyslar soni, ton-km.\n'
                 'DIQQAT: bu waybill\'ning O\'ZI EMAS. "Nechta yo\'l varaqasi bor?" ->\n'
                 'waybill; "topshiriqlar/yuklar nechta?" -> SHU jadval.\n'
                 '---------------------------------------------------------------------'}

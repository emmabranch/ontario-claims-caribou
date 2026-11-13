# Data preparation log

Run: 2026-11-13 14:30

- Active cell claims read: 411,644
  - dropped leased: 4
  - dropped test records: 0
  - kept: 411,640
- Cancelled file rows read: 440,562
  - after keeping latest revision per tenure: 429,894
  - with status 'Cancelled': 303,425
  - dropped test records: 1,150
  - dropped tenures that are active today: 0
  - kept: 302,275
- Active claims with conversion date (2018-04-10): 126,914
- Caribou features: 15 (14 ranges, 1 discontinuous zone)

Writing data/processed/claims_caribou.gpkg (CRS ESRI:102001):
- claims_active: 411,640 features
- claims_cancelled: 302,275 features
- caribou_ranges: 14 features
- caribou_discontinuous: 1 features
- province: 1 features

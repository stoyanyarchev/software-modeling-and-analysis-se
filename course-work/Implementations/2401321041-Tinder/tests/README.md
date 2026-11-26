# Проверки

`database/06_verify.sql` проверява данните, FK и OLTP/DW съответствието. `07_demo.sql` демонстрира бизнес операциите в rollback транзакция.

Допълнителните проверки изискват Python, ODBC Driver 17 и инсталирани бази в LocalDB:

```powershell
python -m pip install -r .\tests\requirements.txt
python .\tests\verify_project.py
```

Проверките за невалидни операции използват rollback. ETL проверката презарежда учебния warehouse и добавя запис в ETL журнала.

Power BI JSON дефинициите се проверяват спрямо публичните Microsoft schemas (необходим е интернет). Ако Microsoft още не е публикувал schema за версия, записана от Desktop, тя се отчита отделно като unavailable, а не като успешно валидирана. PBIX е отворен, зареден, визуално проверен на трите страници и записан в Power BI Desktop; проверено е филтриране по година.

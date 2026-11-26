# Power BI — Tinder Analytics

## Готов отчет

Отворете **Tinder-report.pbix**. Той съдържа импортираните данни и работи без предварителна SQL инсталация за преглед. Трите страници и филтърът по година са проверени в Power BI Desktop. За обновяване на данните е необходим SQL warehouse.

## Редактируем проект и обновяване

1. Инсталирайте базите чрез `database/install.ps1`.
2. Отворете `Tinder.pbip` в актуална версия на Microsoft Power BI Desktop.
3. При нужда разрешете Power BI Project / PBIR preview функции във File → Options → Preview features и рестартирайте Desktop.
4. Изпълнете Refresh. Изберете Windows credentials за `(localdb)\MSSQLLocalDB`.
5. Проверете Model view: 3 fact и 8 dimension таблици; всички връзки са many-to-one и еднопосочни от измерението към факта.
6. След редактиране запишете проекта или използвайте Save As → Power BI report (`.pbix`).

PBIP е редактируемият проектен формат на Power BI, а не преименуван PBIX. Всички report visual definitions са JSON; моделът е TMSL в `Tinder.SemanticModel/model.bim`. Импортът чете директно от SQL Server warehouse. За друга инстанция сменете SQL server във всяка M partition / Power Query data source. Не променяйте имената на таблиците без съответна промяна на визуализациите.

## Страници и визуализации

| Страница | Графики |
|---|---|
| Overview | Swipes по месец; matches по град; приход по месец; типове swipe; 4 KPI |
| Engagement | Swipes по час; match status; matches по месец; съобщения по град на match |
| Revenue | Приход по план; метод на плащане; платежен статус; платили потребители по месец |

Всяка страница има филтри по година и град. Измеренията, които не са приложими към даден факт, не се използват като глобални филтри (например Plan не филтрира swipes).

## Мерки

Мерките вече са включени в семантичния модел. `measures.dax` е четим справочник. `Total Swipes`, `Total Matches`, `Messages Sent` и `Payment Attempts` са суми на адитивни колони. `Net Revenue` е сборът на платените суми, без Failed и Refunded. `Conversation Rate` използва `DIVIDE`, за да избегне деление на нула.

`DimDate[FullDate]` е уникална календарна дата, DimDate е маркирана като Time в модела. `YearMonth` е в сортируем формат YYYY-MM. Имената на дните са сортирани по DayOfWeek. Всички часови стойности са UTC.

## Проверка на числата

При всички филтри изключени:

- Total Swipes: **14 871**
- Total Matches: **537**
- Messages Sent: **4 291**
- Payment Attempts: **533**

Точният приход и conversation rate са записани в `../report/data/report_totals.json`. Те се изчисляват от реалния SQL export и могат да се сравнят с `06_verify.sql`.

## Офлайн версия

`../report/Tinder-analytics.html` е самостоятелен Plotly отчет със същите 12 графики, година/град филтри и същия SQL export. `../report/Tinder-analytics.pdf` е готов печатен отчет. PDF е генериран с ReportLab от същите данни; не е представян като export от Power BI.

## Източници за формата

- https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-overview
- https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-dataset
- https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-report

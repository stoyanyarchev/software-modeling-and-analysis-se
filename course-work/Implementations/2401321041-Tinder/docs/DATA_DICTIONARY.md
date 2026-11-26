# Речник на данните

SQL типовете, ключовете и nullable колоните са извлечени от инсталираните бази. PK = първичен ключ; FK = външен ключ. Бизнес правилата са описани в README и SQL ограниченията.

## OLTP

### Cities

| Колона | SQL тип | Ключ | NULL |
|---|---|---|---|
| CityID | int | PK | Не |
| CityName | nvarchar(80) | — | Не |
| Country | nvarchar(80) | — | Не |
| TimeZone | nvarchar(60) | — | Не |

### Interests

| Колона | SQL тип | Ключ | NULL |
|---|---|---|---|
| InterestID | int | PK | Не |
| InterestName | nvarchar(60) | — | Не |
| Category | nvarchar(40) | — | Не |

### Matches

| Колона | SQL тип | Ключ | NULL |
|---|---|---|---|
| MatchID | int | PK | Не |
| UserLowID | int | FK | Не |
| UserHighID | int | FK | Не |
| MatchedAt | datetime2 | — | Не |
| CityID | int | FK | Не |
| Status | nvarchar(12) | — | Не |
| EndedAt | datetime2 | — | Да |

### MatchStatusLog

| Колона | SQL тип | Ключ | NULL |
|---|---|---|---|
| LogID | int | PK | Не |
| MatchID | int | FK | Не |
| OldStatus | nvarchar(12) | — | Да |
| NewStatus | nvarchar(12) | — | Не |
| ChangedAt | datetime2 | — | Не |
| ChangedBy | sysname | — | Не |

### Messages

| Колона | SQL тип | Ключ | NULL |
|---|---|---|---|
| MessageID | int | PK | Не |
| MatchID | int | FK | Не |
| SenderUserID | int | FK | Не |
| Body | nvarchar(1000) | — | Не |
| SentAt | datetime2 | — | Не |
| ReadAt | datetime2 | — | Да |

### PaymentMethods

| Колона | SQL тип | Ключ | NULL |
|---|---|---|---|
| PaymentMethodID | int | PK | Не |
| MethodName | nvarchar(40) | — | Не |
| Category | nvarchar(20) | — | Не |

### Payments

| Колона | SQL тип | Ключ | NULL |
|---|---|---|---|
| PaymentID | int | PK | Не |
| SubscriptionID | int | FK | Не |
| PaymentMethodID | int | FK | Не |
| CityID | int | FK | Не |
| Amount | decimal(9,2) | — | Не |
| Currency | char(3) | — | Не |
| PaidAt | datetime2 | — | Не |
| Status | nvarchar(10) | — | Не |
| ExternalRef | nvarchar(80) | — | Не |

### Photos

| Колона | SQL тип | Ключ | NULL |
|---|---|---|---|
| PhotoID | int | PK | Не |
| UserID | int | FK | Не |
| PhotoURL | nvarchar(300) | — | Не |
| DisplayOrder | tinyint | — | Не |
| UploadedAt | datetime2 | — | Не |

### Plans

| Колона | SQL тип | Ключ | NULL |
|---|---|---|---|
| PlanID | int | PK | Не |
| PlanName | nvarchar(40) | — | Не |
| MonthlyPrice | decimal(9,2) | — | Не |
| Currency | char(3) | — | Не |
| Description | nvarchar(200) | — | Не |

### Subscriptions

| Колона | SQL тип | Ключ | NULL |
|---|---|---|---|
| SubscriptionID | int | PK | Не |
| UserID | int | FK | Не |
| PlanID | int | FK | Не |
| StartsAt | datetime2 | — | Не |
| EndsAt | datetime2 | — | Не |
| AutoRenew | bit | — | Не |

### Swipes

| Колона | SQL тип | Ключ | NULL |
|---|---|---|---|
| SwipeID | int | PK | Не |
| ActorUserID | int | FK | Не |
| TargetUserID | int | FK | Не |
| SwipeType | nvarchar(10) | — | Не |
| SwipedAt | datetime2 | — | Не |
| CityID | int | FK | Не |

### UserInterests

| Колона | SQL тип | Ключ | NULL |
|---|---|---|---|
| UserID | int | PK / FK | Не |
| InterestID | int | PK / FK | Не |
| AddedAt | datetime2 | — | Не |

### Users

| Колона | SQL тип | Ключ | NULL |
|---|---|---|---|
| UserID | int | PK | Не |
| CityID | int | FK | Не |
| DisplayName | nvarchar(60) | — | Не |
| Email | nvarchar(150) | — | Не |
| BirthDate | date | — | Не |
| Gender | nvarchar(20) | — | Не |
| Bio | nvarchar(500) | — | Да |
| RegisteredAt | datetime2 | — | Не |
| IsActive | bit | — | Не |
| IsVerified | bit | — | Не |

## WAREHOUSE

### DimCity

| Колона | SQL тип | Ключ | NULL |
|---|---|---|---|
| CityKey | int | PK | Не |
| CityID | int | — | Не |
| CityName | nvarchar(80) | — | Не |
| Country | nvarchar(80) | — | Не |

### DimDate

| Колона | SQL тип | Ключ | NULL |
|---|---|---|---|
| DateKey | int | PK | Не |
| FullDate | date | — | Не |
| Year | smallint | — | Не |
| MonthNumber | tinyint | — | Не |
| YearMonth | char(7) | — | Не |
| DayOfWeek | tinyint | — | Не |
| DayName | nvarchar(15) | — | Не |
| IsWeekend | bit | — | Не |

### DimMatchStatus

| Колона | SQL тип | Ключ | NULL |
|---|---|---|---|
| MatchStatusKey | int | PK | Не |
| StatusName | nvarchar(12) | — | Не |

### DimPaymentMethod

| Колона | SQL тип | Ключ | NULL |
|---|---|---|---|
| PaymentMethodKey | int | PK | Не |
| PaymentMethodID | int | — | Не |
| MethodName | nvarchar(40) | — | Не |
| Category | nvarchar(20) | — | Не |

### DimPlan

| Колона | SQL тип | Ключ | NULL |
|---|---|---|---|
| PlanKey | int | PK | Не |
| PlanID | int | — | Не |
| PlanName | nvarchar(40) | — | Не |
| MonthlyPrice | decimal(9,2) | — | Не |
| Currency | char(3) | — | Не |

### DimSwipeType

| Колона | SQL тип | Ключ | NULL |
|---|---|---|---|
| SwipeTypeKey | int | PK | Не |
| SwipeType | nvarchar(10) | — | Не |
| IsPositive | bit | — | Не |

### DimTime

| Колона | SQL тип | Ключ | NULL |
|---|---|---|---|
| TimeKey | tinyint | PK | Не |
| HourLabel | char(5) | — | Не |
| PartOfDay | nvarchar(15) | — | Не |

### DimUser

| Колона | SQL тип | Ключ | NULL |
|---|---|---|---|
| UserKey | int | PK | Не |
| UserID | int | — | Не |
| DisplayName | nvarchar(60) | — | Не |
| Gender | nvarchar(20) | — | Не |
| BirthDate | date | — | Не |
| RegisteredAt | datetime2 | — | Не |
| IsVerified | bit | — | Не |

### EtlLog

| Колона | SQL тип | Ключ | NULL |
|---|---|---|---|
| LoadID | int | PK | Не |
| StartedAt | datetime2 | — | Не |
| FinishedAt | datetime2 | — | Да |
| Status | nvarchar(12) | — | Не |
| SwipesRows | int | — | Да |
| MatchesRows | int | — | Да |
| PaymentsRows | int | — | Да |
| ErrorMessage | nvarchar(2000) | — | Да |

### FactMatches

| Колона | SQL тип | Ключ | NULL |
|---|---|---|---|
| MatchKey | int | PK | Не |
| DateKey | int | FK | Не |
| TimeKey | tinyint | FK | Не |
| UserKey | int | FK | Не |
| OtherUserID | int | — | Не |
| CityKey | int | FK | Не |
| MatchStatusKey | int | FK | Не |
| MatchCount | int | — | Не |
| MessageCount | int | — | Не |
| HasConversation | bit | — | Не |
| MinutesToFirstMessage | int | — | Да |

### FactPayments

| Колона | SQL тип | Ключ | NULL |
|---|---|---|---|
| PaymentKey | int | PK | Не |
| DateKey | int | FK | Не |
| TimeKey | tinyint | FK | Не |
| UserKey | int | FK | Не |
| CityKey | int | FK | Не |
| PlanKey | int | FK | Не |
| PaymentMethodKey | int | FK | Не |
| PaymentStatus | nvarchar(10) | — | Не |
| Amount | decimal(9,2) | — | Не |
| NetRevenue | decimal(9,2) | — | Не |
| PaymentCount | int | — | Не |

### FactSwipes

| Колона | SQL тип | Ключ | NULL |
|---|---|---|---|
| SwipeKey | int | PK | Не |
| DateKey | int | FK | Не |
| TimeKey | tinyint | FK | Не |
| UserKey | int | FK | Не |
| TargetUserID | int | — | Не |
| CityKey | int | FK | Не |
| SwipeTypeKey | int | FK | Не |
| SwipeCount | int | — | Не |
| PositiveSwipeCount | int | — | Не |

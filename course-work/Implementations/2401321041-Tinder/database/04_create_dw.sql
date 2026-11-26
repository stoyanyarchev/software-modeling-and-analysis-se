USE master;
GO
IF DB_ID(N'TinderDW_2401321041') IS NOT NULL THROW 51000,'Warehouse already exists. Refusing to overwrite.',1;
GO
CREATE DATABASE TinderDW_2401321041;
GO
USE TinderDW_2401321041;
GO

CREATE TABLE dbo.DimDate (
 DateKey INT PRIMARY KEY, FullDate DATE NOT NULL UNIQUE, Year SMALLINT NOT NULL,
 MonthNumber TINYINT NOT NULL, YearMonth CHAR(7) NOT NULL, DayOfWeek TINYINT NOT NULL,
 DayName NVARCHAR(15) NOT NULL, IsWeekend BIT NOT NULL
);
CREATE TABLE dbo.DimTime (TimeKey TINYINT PRIMARY KEY, HourLabel CHAR(5) NOT NULL, PartOfDay NVARCHAR(15) NOT NULL);
CREATE TABLE dbo.DimUser (UserKey INT PRIMARY KEY, UserID INT NOT NULL UNIQUE, DisplayName NVARCHAR(60) NOT NULL, Gender NVARCHAR(20) NOT NULL, BirthDate DATE NOT NULL, RegisteredAt DATETIME2(0) NOT NULL, IsVerified BIT NOT NULL);
CREATE TABLE dbo.DimCity (CityKey INT PRIMARY KEY, CityID INT NOT NULL UNIQUE, CityName NVARCHAR(80) NOT NULL, Country NVARCHAR(80) NOT NULL);
CREATE TABLE dbo.DimSwipeType (SwipeTypeKey INT PRIMARY KEY, SwipeType NVARCHAR(10) NOT NULL UNIQUE, IsPositive BIT NOT NULL);
CREATE TABLE dbo.DimPlan (PlanKey INT PRIMARY KEY, PlanID INT NOT NULL UNIQUE, PlanName NVARCHAR(40) NOT NULL, MonthlyPrice DECIMAL(9,2) NOT NULL, Currency CHAR(3) NOT NULL);
CREATE TABLE dbo.DimPaymentMethod (PaymentMethodKey INT PRIMARY KEY, PaymentMethodID INT NOT NULL UNIQUE, MethodName NVARCHAR(40) NOT NULL, Category NVARCHAR(20) NOT NULL);
CREATE TABLE dbo.DimMatchStatus (MatchStatusKey INT PRIMARY KEY, StatusName NVARCHAR(12) NOT NULL UNIQUE);
-- Grain: one immutable directed swipe. UserKey is the actor; TargetUserID is a degenerate identifier.
CREATE TABLE dbo.FactSwipes (
 SwipeKey INT PRIMARY KEY,
 DateKey INT NOT NULL REFERENCES dbo.DimDate(DateKey),
 TimeKey TINYINT NOT NULL REFERENCES dbo.DimTime(TimeKey),
 UserKey INT NOT NULL REFERENCES dbo.DimUser(UserKey),
 TargetUserID INT NOT NULL,
 CityKey INT NOT NULL REFERENCES dbo.DimCity(CityKey),
 SwipeTypeKey INT NOT NULL REFERENCES dbo.DimSwipeType(SwipeTypeKey),
 SwipeCount INT NOT NULL,
 PositiveSwipeCount INT NOT NULL
);
-- Grain: one unordered matched pair, attributed to the second swiper (who completes the match).
CREATE TABLE dbo.FactMatches (
 MatchKey INT PRIMARY KEY,
 DateKey INT NOT NULL REFERENCES dbo.DimDate(DateKey),
 TimeKey TINYINT NOT NULL REFERENCES dbo.DimTime(TimeKey),
 UserKey INT NOT NULL REFERENCES dbo.DimUser(UserKey),
 OtherUserID INT NOT NULL,
 CityKey INT NOT NULL REFERENCES dbo.DimCity(CityKey),
 MatchStatusKey INT NOT NULL REFERENCES dbo.DimMatchStatus(MatchStatusKey),
 MatchCount INT NOT NULL,
 MessageCount INT NOT NULL,
 HasConversation BIT NOT NULL,
 MinutesToFirstMessage INT NULL
);
-- Grain: one payment attempt. Failed/refunded attempts remain visible but earn zero net revenue.
CREATE TABLE dbo.FactPayments (
 PaymentKey INT PRIMARY KEY,
 DateKey INT NOT NULL REFERENCES dbo.DimDate(DateKey),
 TimeKey TINYINT NOT NULL REFERENCES dbo.DimTime(TimeKey),
 UserKey INT NOT NULL REFERENCES dbo.DimUser(UserKey),
 CityKey INT NOT NULL REFERENCES dbo.DimCity(CityKey),
 PlanKey INT NOT NULL REFERENCES dbo.DimPlan(PlanKey),
 PaymentMethodKey INT NOT NULL REFERENCES dbo.DimPaymentMethod(PaymentMethodKey),
 PaymentStatus NVARCHAR(10) NOT NULL,
 Amount DECIMAL(9,2) NOT NULL,
 NetRevenue DECIMAL(9,2) NOT NULL,
 PaymentCount INT NOT NULL
);
CREATE TABLE dbo.EtlLog (LoadID INT IDENTITY PRIMARY KEY, StartedAt DATETIME2(0) NOT NULL, FinishedAt DATETIME2(0) NULL, Status NVARCHAR(12) NOT NULL, SwipesRows INT NULL, MatchesRows INT NULL, PaymentsRows INT NULL, ErrorMessage NVARCHAR(2000) NULL);

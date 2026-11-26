-- Stoyan Yarchev | 2401321041 | Tinder educational model
-- Refuse to overwrite an existing database. See README for clean reinstall.
USE master;
GO
IF DB_ID(N'TinderDB_2401321041') IS NOT NULL THROW 51000, 'Database already exists. Use another instance or explicitly reset your coursework database.', 1;
GO
CREATE DATABASE TinderDB_2401321041;
GO
USE TinderDB_2401321041;
GO

CREATE TABLE dbo.Cities (
 CityID INT IDENTITY PRIMARY KEY,
 CityName NVARCHAR(80) NOT NULL,
 Country NVARCHAR(80) NOT NULL,
 TimeZone NVARCHAR(60) NOT NULL,
 CONSTRAINT UQ_City UNIQUE(CityName,Country)
);
CREATE TABLE dbo.Users (
 UserID INT IDENTITY PRIMARY KEY,
 CityID INT NOT NULL REFERENCES dbo.Cities(CityID),
 DisplayName NVARCHAR(60) NOT NULL,
 Email NVARCHAR(150) NOT NULL UNIQUE,
 BirthDate DATE NOT NULL,
 Gender NVARCHAR(20) NOT NULL,
 Bio NVARCHAR(500) NULL,
 RegisteredAt DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
 IsActive BIT NOT NULL DEFAULT 1,
 IsVerified BIT NOT NULL DEFAULT 0,
 CONSTRAINT CK_User_Adult CHECK(DATEADD(YEAR,18,BirthDate)<=RegisteredAt),
 CONSTRAINT CK_User_Gender CHECK(Gender IN ('Woman','Man','Nonbinary'))
);
CREATE TABLE dbo.Photos (
 PhotoID INT IDENTITY PRIMARY KEY,
 UserID INT NOT NULL REFERENCES dbo.Users(UserID),
 PhotoURL NVARCHAR(300) NOT NULL,
 DisplayOrder TINYINT NOT NULL,
 UploadedAt DATETIME2(0) NOT NULL,
 CONSTRAINT UQ_PhotoOrder UNIQUE(UserID,DisplayOrder),
 CONSTRAINT CK_PhotoOrder CHECK(DisplayOrder BETWEEN 1 AND 9)
);
CREATE TABLE dbo.Interests (
 InterestID INT IDENTITY PRIMARY KEY,
 InterestName NVARCHAR(60) NOT NULL UNIQUE,
 Category NVARCHAR(40) NOT NULL
);
CREATE TABLE dbo.UserInterests (
 UserID INT NOT NULL REFERENCES dbo.Users(UserID),
 InterestID INT NOT NULL REFERENCES dbo.Interests(InterestID),
 AddedAt DATETIME2(0) NOT NULL,
 CONSTRAINT PK_UserInterests PRIMARY KEY(UserID,InterestID)
);
CREATE TABLE dbo.Swipes (
 SwipeID INT IDENTITY PRIMARY KEY,
 ActorUserID INT NOT NULL REFERENCES dbo.Users(UserID),
 TargetUserID INT NOT NULL REFERENCES dbo.Users(UserID),
 SwipeType NVARCHAR(10) NOT NULL,
 SwipedAt DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
 CityID INT NOT NULL REFERENCES dbo.Cities(CityID),
 CONSTRAINT CK_SwipeSelf CHECK(ActorUserID<>TargetUserID),
 CONSTRAINT CK_SwipeType CHECK(SwipeType IN ('Like','Pass','SuperLike')),
 CONSTRAINT UQ_SwipePair UNIQUE(ActorUserID,TargetUserID)
);
CREATE TABLE dbo.Matches (
 MatchID INT IDENTITY PRIMARY KEY,
 UserLowID INT NOT NULL REFERENCES dbo.Users(UserID),
 UserHighID INT NOT NULL REFERENCES dbo.Users(UserID),
 MatchedAt DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
 CityID INT NOT NULL REFERENCES dbo.Cities(CityID),
 Status NVARCHAR(12) NOT NULL DEFAULT 'Active',
 EndedAt DATETIME2(0) NULL,
 CONSTRAINT CK_MatchOrder CHECK(UserLowID<UserHighID),
 CONSTRAINT UQ_MatchPair UNIQUE(UserLowID,UserHighID),
 CONSTRAINT CK_MatchStatus CHECK((Status='Active' AND EndedAt IS NULL) OR (Status='Unmatched' AND EndedAt IS NOT NULL AND EndedAt>=MatchedAt))
);
CREATE TABLE dbo.Messages (
 MessageID INT IDENTITY PRIMARY KEY,
 MatchID INT NOT NULL REFERENCES dbo.Matches(MatchID),
 SenderUserID INT NOT NULL REFERENCES dbo.Users(UserID),
 Body NVARCHAR(1000) NOT NULL,
 SentAt DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
 ReadAt DATETIME2(0) NULL,
 CONSTRAINT CK_MessageRead CHECK(ReadAt>=SentAt),
 CONSTRAINT CK_MessageBody CHECK(LEN(LTRIM(RTRIM(Body)))>0)
);
CREATE TABLE dbo.Plans (
 PlanID INT IDENTITY PRIMARY KEY,
 PlanName NVARCHAR(40) NOT NULL UNIQUE,
 MonthlyPrice DECIMAL(9,2) NOT NULL,
 Currency CHAR(3) NOT NULL DEFAULT 'EUR',
 Description NVARCHAR(200) NOT NULL,
 CONSTRAINT CK_PlanPrice CHECK(MonthlyPrice>=0)
);
CREATE TABLE dbo.Subscriptions (
 SubscriptionID INT IDENTITY PRIMARY KEY,
 UserID INT NOT NULL REFERENCES dbo.Users(UserID),
 PlanID INT NOT NULL REFERENCES dbo.Plans(PlanID),
 StartsAt DATETIME2(0) NOT NULL,
 EndsAt DATETIME2(0) NOT NULL,
 AutoRenew BIT NOT NULL DEFAULT 0,
 CONSTRAINT CK_SubDates CHECK(EndsAt>StartsAt)
);
CREATE TABLE dbo.PaymentMethods (
 PaymentMethodID INT IDENTITY PRIMARY KEY,
 MethodName NVARCHAR(40) NOT NULL UNIQUE,
 Category NVARCHAR(20) NOT NULL
);
CREATE TABLE dbo.Payments (
 PaymentID INT IDENTITY PRIMARY KEY,
 SubscriptionID INT NOT NULL REFERENCES dbo.Subscriptions(SubscriptionID),
 PaymentMethodID INT NOT NULL REFERENCES dbo.PaymentMethods(PaymentMethodID),
 CityID INT NOT NULL REFERENCES dbo.Cities(CityID),
 Amount DECIMAL(9,2) NOT NULL,
 Currency CHAR(3) NOT NULL DEFAULT 'EUR',
 PaidAt DATETIME2(0) NOT NULL,
 Status NVARCHAR(10) NOT NULL,
 ExternalRef NVARCHAR(80) NOT NULL UNIQUE,
 CONSTRAINT CK_PaymentAmount CHECK(Amount>=0),
 CONSTRAINT CK_PaymentStatus CHECK(Status IN ('Paid','Refunded','Failed')),
 CONSTRAINT CK_PaymentCurrency CHECK(Currency='EUR')
);
CREATE TABLE dbo.MatchStatusLog (
 LogID INT IDENTITY PRIMARY KEY,
 MatchID INT NOT NULL REFERENCES dbo.Matches(MatchID),
 OldStatus NVARCHAR(12) NULL,
 NewStatus NVARCHAR(12) NOT NULL,
 ChangedAt DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
 ChangedBy SYSNAME NOT NULL DEFAULT SUSER_SNAME()
);
CREATE INDEX IX_Swipes_Date ON dbo.Swipes(SwipedAt);
CREATE INDEX IX_Messages_Match ON dbo.Messages(MatchID,SentAt);
CREATE INDEX IX_Subscriptions_User ON dbo.Subscriptions(UserID,StartsAt,EndsAt);

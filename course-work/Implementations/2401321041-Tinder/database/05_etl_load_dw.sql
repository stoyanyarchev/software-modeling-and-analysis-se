USE TinderDW_2401321041;
GO
CREATE OR ALTER PROCEDURE dbo.usp_LoadDW
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 DECLARE @LoadID INT,@MinDate DATE,@MaxDate DATE,@lock INT;
 INSERT dbo.EtlLog(StartedAt,Status) VALUES(SYSUTCDATETIME(),'Running');
 SET @LoadID=SCOPE_IDENTITY();
 BEGIN TRY
  BEGIN TRANSACTION;
  EXEC @lock=sys.sp_getapplock @Resource='TinderWarehouseLoad',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
  IF @lock<0 THROW 51020,'Warehouse is already loading.',1;
  DELETE dbo.FactSwipes; DELETE dbo.FactMatches; DELETE dbo.FactPayments;
  DELETE dbo.DimDate; DELETE dbo.DimTime; DELETE dbo.DimUser; DELETE dbo.DimCity;
  DELETE dbo.DimSwipeType; DELETE dbo.DimPlan; DELETE dbo.DimPaymentMethod; DELETE dbo.DimMatchStatus;
  SELECT @MinDate=DATEFROMPARTS(YEAR(MIN(d)),1,1),@MaxDate=DATEFROMPARTS(YEAR(MAX(d)),12,31)
  FROM (SELECT CAST(SwipedAt AS DATE) d FROM TinderDB_2401321041.dbo.Swipes
   UNION ALL SELECT CAST(MatchedAt AS DATE) FROM TinderDB_2401321041.dbo.Matches
   UNION ALL SELECT CAST(PaidAt AS DATE) FROM TinderDB_2401321041.dbo.Payments) q;
  SET @MinDate=COALESCE(@MinDate,'20250101'); SET @MaxDate=COALESCE(@MaxDate,'20261231');
  ;WITH n AS(SELECT TOP(DATEDIFF(DAY,@MinDate,@MaxDate)+1) ROW_NUMBER() OVER(ORDER BY (SELECT NULL))-1 n FROM sys.all_objects a CROSS JOIN sys.all_objects b),
  d AS(SELECT DATEADD(DAY,n,@MinDate) d FROM n),
  x AS(SELECT d,DATEDIFF(DAY,'19000101',d)%7+1 dow FROM d)
  INSERT dbo.DimDate SELECT CONVERT(INT,CONVERT(CHAR(8),d,112)),d,YEAR(d),MONTH(d),CONVERT(CHAR(7),d,126),dow,
   CHOOSE(dow,'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'),CASE WHEN dow>=6 THEN 1 ELSE 0 END FROM x;
  ;WITH h AS(SELECT TOP(24) ROW_NUMBER() OVER(ORDER BY (SELECT NULL))-1 h FROM sys.all_objects)
  INSERT dbo.DimTime SELECT h,RIGHT('0'+CAST(h AS VARCHAR(2)),2)+':00',CASE WHEN h<6 THEN 'Night' WHEN h<12 THEN 'Morning' WHEN h<18 THEN 'Afternoon' ELSE 'Evening' END FROM h;
  INSERT dbo.DimUser SELECT UserID,UserID,DisplayName,Gender,BirthDate,RegisteredAt,IsVerified FROM TinderDB_2401321041.dbo.Users;
  INSERT dbo.DimCity SELECT CityID,CityID,CityName,Country FROM TinderDB_2401321041.dbo.Cities;
  INSERT dbo.DimSwipeType VALUES(1,'Like',1),(2,'Pass',0),(3,'SuperLike',1);
  INSERT dbo.DimPlan SELECT PlanID,PlanID,PlanName,MonthlyPrice,Currency FROM TinderDB_2401321041.dbo.Plans;
  INSERT dbo.DimPaymentMethod SELECT PaymentMethodID,PaymentMethodID,MethodName,Category FROM TinderDB_2401321041.dbo.PaymentMethods;
  INSERT dbo.DimMatchStatus VALUES(1,'Active'),(2,'Unmatched');
  INSERT dbo.FactSwipes
  SELECT s.SwipeID,CONVERT(INT,CONVERT(CHAR(8),s.SwipedAt,112)),DATEPART(HOUR,s.SwipedAt),s.ActorUserID,s.TargetUserID,s.CityID,t.SwipeTypeKey,1,t.IsPositive
  FROM TinderDB_2401321041.dbo.Swipes s JOIN dbo.DimSwipeType t ON s.SwipeType=t.SwipeType;
  INSERT dbo.FactMatches
  SELECT m.MatchID,CONVERT(INT,CONVERT(CHAR(8),m.MatchedAt,112)),DATEPART(HOUR,m.MatchedAt),
   CASE WHEN a.SwipedAt>=b.SwipedAt THEN m.UserLowID ELSE m.UserHighID END,
   CASE WHEN a.SwipedAt>=b.SwipedAt THEN m.UserHighID ELSE m.UserLowID END,
   m.CityID,CASE WHEN m.Status='Active' THEN 1 ELSE 2 END,1,x.MessageCount,CASE WHEN x.MessageCount>0 THEN 1 ELSE 0 END,DATEDIFF(MINUTE,m.MatchedAt,x.FirstMessage)
  FROM TinderDB_2401321041.dbo.Matches m
  JOIN TinderDB_2401321041.dbo.Swipes a ON a.ActorUserID=m.UserLowID AND a.TargetUserID=m.UserHighID
  JOIN TinderDB_2401321041.dbo.Swipes b ON b.ActorUserID=m.UserHighID AND b.TargetUserID=m.UserLowID
  CROSS APPLY(SELECT COUNT(*) MessageCount,MIN(SentAt) FirstMessage FROM TinderDB_2401321041.dbo.Messages x WHERE x.MatchID=m.MatchID) x;
  INSERT dbo.FactPayments
  SELECT p.PaymentID,CONVERT(INT,CONVERT(CHAR(8),p.PaidAt,112)),DATEPART(HOUR,p.PaidAt),s.UserID,p.CityID,s.PlanID,p.PaymentMethodID,p.Status,p.Amount,CASE WHEN p.Status='Paid' THEN p.Amount ELSE 0 END,1
  FROM TinderDB_2401321041.dbo.Payments p JOIN TinderDB_2401321041.dbo.Subscriptions s ON p.SubscriptionID=s.SubscriptionID;
  UPDATE dbo.EtlLog SET FinishedAt=SYSUTCDATETIME(),Status='Succeeded',SwipesRows=(SELECT COUNT(*) FROM dbo.FactSwipes),MatchesRows=(SELECT COUNT(*) FROM dbo.FactMatches),PaymentsRows=(SELECT COUNT(*) FROM dbo.FactPayments) WHERE LoadID=@LoadID;
  COMMIT;
 END TRY
 BEGIN CATCH
  IF @@TRANCOUNT>0 ROLLBACK;
  UPDATE dbo.EtlLog SET FinishedAt=SYSUTCDATETIME(),Status='Failed',ErrorMessage=ERROR_MESSAGE() WHERE LoadID=@LoadID;
  THROW;
 END CATCH
END;
GO
EXEC dbo.usp_LoadDW;
GO

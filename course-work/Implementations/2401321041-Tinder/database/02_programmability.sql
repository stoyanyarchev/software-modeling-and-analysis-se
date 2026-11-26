USE TinderDB_2401321041;
GO
CREATE OR ALTER FUNCTION dbo.fn_CommonInterestCount(@UserA INT,@UserB INT)
RETURNS INT AS
BEGIN
 RETURN (SELECT COUNT(*) FROM dbo.UserInterests a JOIN dbo.UserInterests b ON a.InterestID=b.InterestID WHERE a.UserID=@UserA AND b.UserID=@UserB);
END;
GO
CREATE OR ALTER FUNCTION dbo.fn_UserActivity(@UserID INT)
RETURNS TABLE AS RETURN (
 SELECT u.UserID,u.DisplayName,
 (SELECT COUNT(*) FROM dbo.Swipes s WHERE s.ActorUserID=u.UserID) AS SwipesMade,
 (SELECT COUNT(*) FROM dbo.Matches m WHERE (m.UserLowID=u.UserID OR m.UserHighID=u.UserID) AND m.Status='Active') AS ActiveMatches,
 (SELECT COUNT(*) FROM dbo.Messages x WHERE x.SenderUserID=u.UserID) AS MessagesSent
 FROM dbo.Users u WHERE u.UserID=@UserID
);
GO
-- A canonical pair lock serializes both directions of the same swipe pair.
-- One decision per ordered pair; rewind / repeated swipes are outside this model.
CREATE OR ALTER PROCEDURE dbo.usp_RecordSwipe
 @ActorUserID INT,@TargetUserID INT,@SwipeType NVARCHAR(10)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @ActorUserID IS NULL OR @TargetUserID IS NULL OR @ActorUserID=@TargetUserID THROW 51001,'Choose two different users.',1;
 IF @SwipeType IS NULL OR @SwipeType NOT IN ('Like','Pass','SuperLike') THROW 51002,'Invalid swipe type.',1;
 DECLARE @Lo INT=CASE WHEN @ActorUserID<@TargetUserID THEN @ActorUserID ELSE @TargetUserID END,
 @Hi INT=CASE WHEN @ActorUserID>@TargetUserID THEN @ActorUserID ELSE @TargetUserID END,
 @City INT,@Now DATETIME2(0)=SYSUTCDATETIME(),@Result INT,@Resource NVARCHAR(255);
 SET @Resource=CONCAT('SwipePair:',@Lo,':',@Hi);
 BEGIN TRY
  BEGIN TRANSACTION;
  EXEC @Result=sys.sp_getapplock @Resource=@Resource,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
  IF @Result<0 THROW 51003,'Could not lock user pair. Retry.',1;
  IF (SELECT COUNT(*) FROM dbo.Users WITH(UPDLOCK,HOLDLOCK) WHERE UserID IN(@ActorUserID,@TargetUserID) AND IsActive=1)<>2 THROW 51004,'Both users must exist and be active.',1;
  IF EXISTS(SELECT 1 FROM dbo.Swipes WHERE ActorUserID=@ActorUserID AND TargetUserID=@TargetUserID) THROW 51005,'This user pair already has a swipe in this direction.',1;
  SELECT @City=CityID FROM dbo.Users WHERE UserID=@ActorUserID;
  INSERT dbo.Swipes(ActorUserID,TargetUserID,SwipeType,SwipedAt,CityID) VALUES(@ActorUserID,@TargetUserID,@SwipeType,@Now,@City);
  IF @SwipeType IN ('Like','SuperLike') AND EXISTS(SELECT 1 FROM dbo.Swipes WHERE ActorUserID=@TargetUserID AND TargetUserID=@ActorUserID AND SwipeType IN ('Like','SuperLike'))
   INSERT dbo.Matches(UserLowID,UserHighID,MatchedAt,CityID) VALUES(@Lo,@Hi,@Now,@City);
  COMMIT;
  SELECT MatchID,Status FROM dbo.Matches WHERE UserLowID=@Lo AND UserHighID=@Hi;
 END TRY
 BEGIN CATCH
  IF @@TRANCOUNT>0 ROLLBACK;
  THROW;
 END CATCH
END;
GO
CREATE OR ALTER PROCEDURE dbo.usp_SendMessage @MatchID INT,@SenderUserID INT,@Body NVARCHAR(1000)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 INSERT dbo.Messages(MatchID,SenderUserID,Body) VALUES(@MatchID,@SenderUserID,@Body);
END;
GO
CREATE OR ALTER PROCEDURE dbo.usp_Unmatch @MatchID INT,@UserID INT
AS
BEGIN
 SET NOCOUNT ON;
 UPDATE dbo.Matches SET Status='Unmatched',EndedAt=SYSUTCDATETIME()
 WHERE MatchID=@MatchID AND Status='Active' AND @UserID IN(UserLowID,UserHighID);
 IF @@ROWCOUNT=0 THROW 51006,'Active match not found for this participant.',1;
END;
GO
CREATE OR ALTER PROCEDURE dbo.usp_GetCityStatistics @From DATE,@To DATE
AS
BEGIN
 SET NOCOUNT ON;
 IF @To<@From THROW 51007,'Invalid date range.',1;
 SELECT c.CityName,
 (SELECT COUNT(*) FROM dbo.Swipes s WHERE s.CityID=c.CityID AND s.SwipedAt>=@From AND s.SwipedAt<DATEADD(DAY,1,@To)) AS Swipes,
 (SELECT COUNT(*) FROM dbo.Matches m WHERE m.CityID=c.CityID AND m.MatchedAt>=@From AND m.MatchedAt<DATEADD(DAY,1,@To)) AS Matches,
 (SELECT COALESCE(SUM(p.Amount),0) FROM dbo.Payments p WHERE p.CityID=c.CityID AND p.Status='Paid' AND p.PaidAt>=@From AND p.PaidAt<DATEADD(DAY,1,@To)) AS RevenueEUR
 FROM dbo.Cities c ORDER BY RevenueEUR DESC;
END;
GO
CREATE OR ALTER TRIGGER dbo.trg_Matches_ValidateAndAudit ON dbo.Matches AFTER INSERT,UPDATE
AS
BEGIN
 SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM inserted i WHERE NOT EXISTS(SELECT 1 FROM dbo.Swipes s WHERE s.ActorUserID=i.UserLowID AND s.TargetUserID=i.UserHighID AND s.SwipeType IN('Like','SuperLike') AND s.SwipedAt<=i.MatchedAt)
 OR NOT EXISTS(SELECT 1 FROM dbo.Swipes s WHERE s.ActorUserID=i.UserHighID AND s.TargetUserID=i.UserLowID AND s.SwipeType IN('Like','SuperLike') AND s.SwipedAt<=i.MatchedAt)) THROW 51008,'A match requires two preceding positive swipes.',1;
 IF EXISTS(SELECT 1 FROM inserted i JOIN deleted d ON i.MatchID=d.MatchID WHERE i.UserLowID<>d.UserLowID OR i.UserHighID<>d.UserHighID OR i.MatchedAt<>d.MatchedAt OR i.CityID<>d.CityID OR (d.Status='Unmatched' AND i.Status<>'Unmatched')) THROW 51009,'Match identity is immutable; ended matches cannot reopen.',1;
 INSERT dbo.MatchStatusLog(MatchID,OldStatus,NewStatus)
 SELECT i.MatchID,d.Status,i.Status FROM inserted i LEFT JOIN deleted d ON d.MatchID=i.MatchID WHERE d.MatchID IS NULL OR d.Status<>i.Status;
END;
GO
CREATE OR ALTER TRIGGER dbo.trg_Messages_Validate ON dbo.Messages AFTER INSERT,UPDATE
AS
BEGIN
 SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM inserted i JOIN dbo.Matches m WITH(UPDLOCK,HOLDLOCK) ON i.MatchID=m.MatchID
 WHERE i.SenderUserID NOT IN(m.UserLowID,m.UserHighID) OR i.SentAt<m.MatchedAt OR m.Status<>'Active') THROW 51010,'Only participants in an active match can send messages after matching.',1;
END;
GO
-- Protect historical swipe decisions and the evidence supporting matches.
CREATE OR ALTER TRIGGER dbo.trg_Swipes_Immutable ON dbo.Swipes AFTER UPDATE,DELETE
AS
BEGIN
 IF EXISTS(SELECT 1 FROM deleted) THROW 51011,'Swipe history is immutable in this coursework model.',1;
END;
GO

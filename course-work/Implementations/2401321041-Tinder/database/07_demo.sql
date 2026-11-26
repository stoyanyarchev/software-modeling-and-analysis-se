-- Reversible defense demo. All changes are rolled back.
USE TinderDB_2401321041;
GO
SET NOCOUNT ON;
BEGIN TRANSACTION;
DECLARE @A INT,@B INT,@M INT;
SELECT TOP(1) @A=a.UserID,@B=b.UserID FROM dbo.Users a CROSS JOIN dbo.Users b
WHERE a.UserID<b.UserID AND a.IsActive=1 AND b.IsActive=1
AND NOT EXISTS(SELECT 1 FROM dbo.Swipes s WHERE (s.ActorUserID=a.UserID AND s.TargetUserID=b.UserID) OR (s.ActorUserID=b.UserID AND s.TargetUserID=a.UserID));
EXEC dbo.usp_RecordSwipe @A,@B,'Like';
EXEC dbo.usp_RecordSwipe @B,@A,'SuperLike';
SELECT @M=MatchID FROM dbo.Matches WHERE UserLowID=@A AND UserHighID=@B;
EXEC dbo.usp_SendMessage @M,@A,N'Hello from the coursework demonstration!';
SELECT dbo.fn_CommonInterestCount(@A,@B) AS SharedInterests;
SELECT * FROM dbo.fn_UserActivity(@A);
EXEC dbo.usp_Unmatch @M,@B;
SELECT * FROM dbo.MatchStatusLog WHERE MatchID=@M;
ROLLBACK;
PRINT 'Demo complete; sample data unchanged.';
GO

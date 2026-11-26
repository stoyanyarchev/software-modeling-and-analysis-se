USE TinderDB_2401321041;
GO
SET NOCOUNT ON;
IF (SELECT COUNT(*) FROM sys.tables)<6 THROW 51100,'Too few OLTP tables.',1;
IF (SELECT COUNT(*) FROM sys.columns c JOIN sys.tables t ON c.object_id=t.object_id)<30 THROW 51101,'Too few attributes.',1;
IF EXISTS(SELECT 1 FROM dbo.Swipes s JOIN dbo.Users u ON u.UserID=s.ActorUserID WHERE s.SwipedAt<u.RegisteredAt) THROW 51102,'Swipe before registration.',1;
IF EXISTS(SELECT 1 FROM dbo.Matches m WHERE NOT EXISTS(SELECT 1 FROM dbo.Swipes s WHERE s.ActorUserID=m.UserLowID AND s.TargetUserID=m.UserHighID AND s.SwipeType IN('Like','SuperLike') AND s.SwipedAt<=m.MatchedAt) OR NOT EXISTS(SELECT 1 FROM dbo.Swipes s WHERE s.ActorUserID=m.UserHighID AND s.TargetUserID=m.UserLowID AND s.SwipeType IN('Like','SuperLike') AND s.SwipedAt<=m.MatchedAt)) THROW 51103,'Invalid match.',1;
IF EXISTS(SELECT 1 FROM dbo.Messages x JOIN dbo.Matches m ON m.MatchID=x.MatchID WHERE x.SenderUserID NOT IN(m.UserLowID,m.UserHighID) OR x.SentAt<m.MatchedAt OR x.SentAt>m.EndedAt) THROW 51104,'Invalid message history.',1;
IF EXISTS(SELECT 1 FROM dbo.Subscriptions a JOIN dbo.Subscriptions b ON a.UserID=b.UserID AND a.SubscriptionID<b.SubscriptionID AND a.StartsAt<b.EndsAt AND b.StartsAt<a.EndsAt) THROW 51105,'Overlapping sample subscriptions.',1;
IF (SELECT COUNT(*) FROM dbo.Swipes)<>(SELECT COUNT(*) FROM TinderDW_2401321041.dbo.FactSwipes) THROW 51106,'Swipe ETL row mismatch.',1;
IF (SELECT COUNT(*) FROM dbo.Matches)<>(SELECT COUNT(*) FROM TinderDW_2401321041.dbo.FactMatches) THROW 51107,'Match ETL row mismatch.',1;
IF (SELECT COUNT(*) FROM dbo.Payments)<>(SELECT COUNT(*) FROM TinderDW_2401321041.dbo.FactPayments) THROW 51108,'Payment ETL row mismatch.',1;
IF (SELECT SUM(Amount) FROM dbo.Payments WHERE Status='Paid')<>(SELECT SUM(NetRevenue) FROM TinderDW_2401321041.dbo.FactPayments) THROW 51109,'Revenue reconciliation failed.',1;
IF (SELECT COUNT(*) FROM dbo.Messages)<>(SELECT SUM(MessageCount) FROM TinderDW_2401321041.dbo.FactMatches) THROW 51110,'Message reconciliation failed.',1;
DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS;
SELECT 'Users' Entity,COUNT(*) RowsCount FROM dbo.Users UNION ALL SELECT 'Swipes',COUNT(*) FROM dbo.Swipes UNION ALL SELECT 'Matches',COUNT(*) FROM dbo.Matches UNION ALL SELECT 'Messages',COUNT(*) FROM dbo.Messages UNION ALL SELECT 'Payments',COUNT(*) FROM dbo.Payments;
SELECT COUNT(*) AS OLTP_Tables FROM sys.tables;
SELECT COUNT(*) AS OLTP_Attributes FROM sys.columns c JOIN sys.tables t ON c.object_id=t.object_id;
PRINT 'PASS: constraints, business history, ETL counts and revenue reconciliation.';
GO

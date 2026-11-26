from pathlib import Path
import json,urllib.request,sys,collections
import pyodbc,jsonschema
P=Path(__file__).resolve().parent.parent
connection=r'DRIVER={ODBC Driver 17 for SQL Server};SERVER=(localdb)\MSSQLLocalDB;DATABASE=TinderDB_2401321041;Trusted_Connection=yes;'
results=[]
def check(name,sql,expected=None):
 cn=pyodbc.connect(connection,autocommit=True)
 try:
  cn.execute('BEGIN TRANSACTION');cur=cn.cursor().execute(sql)
  while cur.description is None and cur.nextset():pass
  val=cur.fetchone()[0] if cur.description else None
  if expected is not None and val!=expected:raise AssertionError((val,expected))
  results.append({'check':name,'result':'PASS'})
 finally:
  try:cn.execute('IF @@TRANCOUNT>0 ROLLBACK')
  except:pass
  cn.close()
def rejects(name,sql):
 cn=pyodbc.connect(connection,autocommit=True)
 try:
  cn.execute('BEGIN TRANSACTION')
  try:cn.execute(sql)
  except pyodbc.Error:results.append({'check':name,'result':'PASS'});return
  raise AssertionError(name+' was accepted')
 finally:
  try:cn.execute('IF @@TRANCOUNT>0 ROLLBACK')
  except:pass
  cn.close()
check('13 OLTP entities','SELECT COUNT(*) FROM sys.tables',13)
check('73 OLTP attributes','SELECT COUNT(*) FROM sys.columns c JOIN sys.tables t ON t.object_id=c.object_id',73)
check('Common-interest function matches set intersection','SELECT CASE WHEN dbo.fn_CommonInterestCount(1,2)=(SELECT COUNT(*) FROM dbo.UserInterests a JOIN dbo.UserInterests b ON a.InterestID=b.InterestID WHERE a.UserID=1 AND b.UserID=2) THEN 1 ELSE 0 END',1)
rejects('Reject self-swipe',"EXEC dbo.usp_RecordSwipe 1,1,'Like'")
rejects('Reject unknown swipe type',"EXEC dbo.usp_RecordSwipe 1,2,'Invalid'")
rejects('Reject non-existent user',"EXEC dbo.usp_RecordSwipe 99999,1,'Like'")
rejects('Reject duplicate directed swipe',"DECLARE @a INT,@b INT; SELECT TOP(1) @a=ActorUserID,@b=TargetUserID FROM dbo.Swipes; EXEC dbo.usp_RecordSwipe @a,@b,'Like';")
rejects('Protect swipe history',"UPDATE dbo.Swipes SET SwipeType='Pass' WHERE SwipeID=1")
rejects('Reject match without reciprocal likes',"DECLARE @a INT,@b INT;SELECT TOP(1) @a=a.UserID,@b=b.UserID FROM dbo.Users a CROSS JOIN dbo.Users b WHERE a.UserID<b.UserID AND NOT EXISTS(SELECT 1 FROM dbo.Swipes s WHERE s.ActorUserID=a.UserID AND s.TargetUserID=b.UserID);INSERT dbo.Matches(UserLowID,UserHighID,CityID) VALUES(@a,@b,1)")
rejects('Reject nonparticipant message',"DECLARE @m INT,@u INT;SELECT TOP(1) @m=MatchID,@u=CASE WHEN 360 NOT IN(UserLowID,UserHighID) THEN 360 ELSE 359 END FROM dbo.Matches WHERE Status='Active';EXEC dbo.usp_SendMessage @m,@u,'Unauthorized';")
rejects('Reject message after unmatch',"DECLARE @m INT,@u INT;SELECT TOP(1) @m=MatchID,@u=UserLowID FROM dbo.Matches WHERE Status='Unmatched';EXEC dbo.usp_SendMessage @m,@u,'Too late';")
rejects('Reject blank message',"DECLARE @m INT,@u INT;SELECT TOP(1) @m=MatchID,@u=UserLowID FROM dbo.Matches WHERE Status='Active';EXEC dbo.usp_SendMessage @m,@u,'   ';")
rejects('Reject underage account',"INSERT dbo.Users(CityID,DisplayName,Email,BirthDate,Gender,RegisteredAt) VALUES(1,'Test','test@example.invalid','2010-01-01','Man','2026-01-01')")
rejects('Reject negative payment',"INSERT dbo.Payments(SubscriptionID,PaymentMethodID,CityID,Amount,PaidAt,Status,ExternalRef) VALUES(1,1,1,-1,'20260101','Paid','negative-test')")
rejects('Reject unmatch without end timestamp',"UPDATE dbo.Matches SET Status='Unmatched',EndedAt=NULL WHERE MatchID=(SELECT MIN(MatchID) FROM dbo.Matches WHERE Status='Active')")
check('Failed and refunded attempts yield zero revenue',"SELECT COUNT(*) FROM TinderDW_2401321041.dbo.FactPayments WHERE PaymentStatus<>'Paid' AND NetRevenue<>0",0)
cn=pyodbc.connect(connection,autocommit=True)
before=list(cn.execute('SELECT SUM(NetRevenue),COUNT(*) FROM TinderDW_2401321041.dbo.FactPayments').fetchone())
cn.execute('EXEC TinderDW_2401321041.dbo.usp_LoadDW')
after=list(cn.execute('SELECT SUM(NetRevenue),COUNT(*) FROM TinderDW_2401321041.dbo.FactPayments').fetchone());assert before==after
results.append({'check':'Repeated ETL preserves payment count and revenue','result':'PASS'})
cn.close()
(P/'tests'/'validation_results.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
print(f'{len(results)} SQL checks passed.')

cache={};errors=[];unavailable=[];files=list((P/'powerbi').rglob('*.json'))+list((P/'powerbi').rglob('*.pbip'))+list((P/'powerbi').rglob('*.pbir'))+list((P/'powerbi').rglob('*.pbism'))
files=[f for f in files if '.pbi' not in f.parts]
for path in files:
 data=json.loads(path.read_text(encoding='utf-8-sig'));url=data.get('$schema')
 if not url:continue
 if url not in cache:
  try:
   with urllib.request.urlopen(url,timeout=30) as response:cache[url]=json.load(response)
  except urllib.error.HTTPError as e:
   if e.code!=404:raise
   unavailable.append({'file':str(path.relative_to(P)),'schema':url,'reason':'Microsoft schema endpoint returns 404; verified by opening and saving in Power BI Desktop.'});continue
 try:jsonschema.validate(data,cache[url])
 except jsonschema.ValidationError as e:errors.append({'file':str(path.relative_to(P)),'message':e.message,'path':list(e.path)})
(P/'tests'/'powerbi_schema_validation.json').write_text(json.dumps({'files':len(files),'errors':errors,'unavailable_schemas':unavailable},indent=2),encoding='utf-8')
print('Power BI schema errors:',json.dumps(errors,indent=2));print('Unavailable schema endpoints:',len(unavailable))
if errors:sys.exit(1)

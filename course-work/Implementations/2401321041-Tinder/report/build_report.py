r"""Rebuild the offline analytics report and PDF from SQL Server warehouse data.
Usage: python build_report.py --refresh --server "(localdb)\MSSQLLocalDB"
Without --refresh, renders the included verified SQL export. No cloud account required.
"""
from pathlib import Path
import argparse,json,datetime,decimal,csv,collections
import plotly.graph_objects as go
from plotly.offline import get_plotlyjs
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor,white
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

HERE=Path(__file__).resolve().parent
parser=argparse.ArgumentParser();parser.add_argument('--refresh',action='store_true');parser.add_argument('--server',default=r'(localdb)\MSSQLLocalDB');args=parser.parse_args()
def encode(v):
 if isinstance(v,(datetime.date,datetime.datetime)):return v.isoformat()
 if isinstance(v,decimal.Decimal):return float(v)
 raise TypeError(type(v))
if args.refresh:
 import pyodbc
 cn=pyodbc.connect(f'DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={args.server};DATABASE=TinderDW_2401321041;Trusted_Connection=yes;')
 tables=['DimDate','DimTime','DimUser','DimCity','DimSwipeType','DimPlan','DimPaymentMethod','DimMatchStatus','FactSwipes','FactMatches','FactPayments'];data={}
 for t in tables:
  cur=cn.cursor().execute(f'SELECT * FROM dbo.[{t}]');cols=[x[0] for x in cur.description];rows=[dict(zip(cols,r)) for r in cur.fetchall()];data[t]=rows
  with (HERE/'data'/f'{t}.csv').open('w',encoding='utf-8-sig',newline='') as f:w=csv.DictWriter(f,fieldnames=cols);w.writeheader();w.writerows(rows)
 (HERE/'data'/'warehouse.json').write_text(json.dumps(data,default=encode),encoding='utf-8')
data=json.loads((HERE/'data'/'warehouse.json').read_text(encoding='utf-8'))
S,M,P=(data[k] for k in ['FactSwipes','FactMatches','FactPayments'])
city={r['CityKey']:r['CityName'] for r in data['DimCity']};plan={r['PlanKey']:r['PlanName'] for r in data['DimPlan']};method={r['PaymentMethodKey']:r['MethodName'] for r in data['DimPaymentMethod']}
swtype={r['SwipeTypeKey']:r['SwipeType'] for r in data['DimSwipeType']};status={r['MatchStatusKey']:r['StatusName'] for r in data['DimMatchStatus']}
def group(rows,key,measure):
 out=collections.defaultdict(float)
 for r in rows:out[key(r)]+=r[measure]
 return dict(sorted(out.items()))
month=lambda r:str(r['DateKey'])[:4]+'-'+str(r['DateKey'])[4:6]
summaries={
 'swipes_month':group(S,month,'SwipeCount'),
 'matches_city':group(M,lambda r:city[r['CityKey']],'MatchCount'),
 'revenue_month':group(P,month,'NetRevenue'),
 'decisions':group(S,lambda r:swtype[r['SwipeTypeKey']],'SwipeCount'),
 'swipes_hour':group(S,lambda r:f"{r['TimeKey']:02}:00",'SwipeCount'),
 'match_status':group(M,lambda r:status[r['MatchStatusKey']],'MatchCount'),
 'matches_month':group(M,month,'MatchCount'),
 'messages_city':group(M,lambda r:city[r['CityKey']],'MessageCount'),
 'revenue_plan':group(P,lambda r:plan[r['PlanKey']],'NetRevenue'),
 'payment_method':group(P,lambda r:method[r['PaymentMethodKey']],'NetRevenue'),
 'payment_status':group(P,lambda r:r['PaymentStatus'],'PaymentCount'),
 'paying_users':{}}
for mo in sorted({month(r) for r in P}):summaries['paying_users'][mo]=len({r['UserKey'] for r in P if month(r)==mo and r['PaymentStatus']=='Paid'})
titles=['Swipes by month','Matches by city','Net revenue by month · EUR','Swipe decisions','Swipes by hour · UTC','Match status at refresh','Matches by month','Messages by match city','Net revenue by plan · EUR','Revenue by payment method · EUR','Payment attempt status','Paying users by month']
keys=list(summaries);types=['line','bar','line','donut','bar','donut','line','bar','bar','donut','bar','line']
pink='#EA4565';teal='#168A87';navy='#182437';palette=[pink,teal,'#F5A65B','#6D67B7','#82B0D2','#A4B897']
figs=[];(HERE/'charts').mkdir(exist_ok=True)
for i,(key,typ,title) in enumerate(zip(keys,types,titles)):
 g=summaries[key];labels=list(g);values=list(g.values())
 if typ=='line':trace=go.Scatter(x=labels,y=values,mode='lines+markers',line={'color':pink,'width':3},fill='tozeroy',fillcolor='rgba(234,69,101,.08)')
 elif typ=='donut':trace=go.Pie(labels=labels,values=values,hole=.65,marker={'colors':palette},textinfo='percent',textposition='inside')
 else:trace=go.Bar(x=labels,y=values,marker_color=teal)
 fig=go.Figure(trace);fig.update_layout(title={'text':title,'font':{'size':20,'color':navy}},paper_bgcolor='white',plot_bgcolor='white',font={'family':'Arial','size':13,'color':navy},margin={'l':55,'r':25,'t':65,'b':60},width=760,height=390,showlegend=typ=='donut')
 if typ!='donut':fig.update_xaxes(showgrid=False);fig.update_yaxes(gridcolor='#EDF0F5',rangemode='tozero')
 mf,ax=plt.subplots(figsize=(7.6,3.9),dpi=150);mf.set_facecolor('white');ax.set_title(title,loc='left',fontsize=14,fontweight='bold',color=navy,pad=18)
 if typ=='donut':
  ax.pie(values,labels=labels,autopct='%1.1f%%',colors=palette[:len(values)],wedgeprops={'width':.35,'edgecolor':'white'},textprops={'fontsize':9,'color':navy},pctdistance=.83)
 else:
  if typ=='line':ax.plot(range(len(values)),values,color=pink,linewidth=2.5,marker='o',markersize=3);ax.fill_between(range(len(values)),values,color=pink,alpha=.07)
  else:ax.bar(range(len(values)),values,color=teal,width=.7)
  every=max(1,len(labels)//7);ax.set_xticks(list(range(0,len(labels),every)),[labels[k] for k in range(0,len(labels),every)],rotation=25 if len(labels)>6 else 0,ha='right' if len(labels)>6 else 'center',fontsize=8)
  ax.set_ylim(bottom=0);ax.grid(axis='y',alpha=.2);ax.set_axisbelow(True)
  for side in ['top','right']:ax.spines[side].set_visible(False)
  for side in ['bottom','left']:ax.spines[side].set_color('#DDE3EB')
  ax.tick_params(axis='y',labelsize=9,colors=navy)
 mf.tight_layout();mf.savefig(HERE/'charts'/f'{key}.png',facecolor='white');plt.close(mf);figs.append(fig)
totals={'users':len(data['DimUser']),'swipes':len(S),'matches':len(M),'messages':sum(r['MessageCount'] for r in M),'revenue':round(sum(r['NetRevenue'] for r in P),2),'conversation_rate':sum(r['HasConversation'] for r in M)/len(M),'like_rate':sum(r['PositiveSwipeCount'] for r in S)/len(S),'payment_attempts':len(P)}
(HERE/'data'/'report_totals.json').write_text(json.dumps(totals,indent=2),encoding='utf-8')
html='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Tinder | Data Modeling & Analytics</title>
<style>*{box-sizing:border-box}body{margin:0;background:#F5F7FB;color:#182437;font:15px Arial,sans-serif}header{background:#182437;color:white;padding:38px 5vw}header small{color:#F7A4B4;letter-spacing:2px}h1{font-size:44px;margin:12px 0}header p{color:#D7DFEA;line-height:1.6}main{max-width:1500px;margin:auto;padding:26px}nav{display:flex;gap:18px;align-items:center;flex-wrap:wrap}select{padding:10px;border:1px solid #CDD5DF;border-radius:7px;background:white}.kpis{display:grid;grid-template-columns:repeat(4,1fr);gap:18px;margin:24px 0}.kpi{background:white;padding:22px;border-radius:10px;border-top:4px solid #EA4565}.kpi strong{display:block;font-size:30px;margin-top:10px}.grid{display:grid;grid-template-columns:1fr 1fr;gap:20px}.chart{background:white;border-radius:10px;min-width:0;height:380px}h2{margin:36px 0 18px}footer{line-height:1.7;background:#EAF0F5;padding:24px;margin-top:30px}a{color:#168A87}.note{color:#526279;line-height:1.6}@media(max-width:800px){.grid,.kpis{grid-template-columns:1fr}h1{font-size:32px}}@media print{nav{display:none}.chart{break-inside:avoid}header{padding:20px}main{padding:0}}</style>
<header><small>SOFTWARE MODELING & ANALYSIS / 2401321041</small><h1>Tinder. From a swipe to a connection.</h1><p>Stoyan Yarchev · SQL Server → Data Warehouse → Analytics<br>Fictional educational dataset · January 2025 – October 2026 · All event times are UTC</p></header><main>
<nav><label>Year <select id="year"><option value="all">All years</option><option>2025</option><option>2026</option></select></label><label>City <select id="city"><option value="all">All cities</option>__CITIES__</select></label><button onclick="document.querySelector('#year').value='all';document.querySelector('#city').value='all';render()">Reset filters</button><span class="note">Filters update every chart and KPI.</span></nav>
<div class="kpis"><div class="kpi">Swipes<strong id="ks"></strong></div><div class="kpi">Matches<strong id="km"></strong></div><div class="kpi">Net revenue · EUR<strong id="kr"></strong></div><div class="kpi">Conversation rate<strong id="kc"></strong></div></div>
<h2>01 / Overview</h2><div class="grid">__CHARTS1__</div><h2>02 / Engagement</h2><div class="grid">__CHARTS2__</div><h2>03 / Revenue</h2><div class="grid">__CHARTS3__</div>
<footer><b>How to read this report</b><br>Revenue includes only Paid attempts; Failed and Refunded attempts contribute zero. Prices are illustrative coursework values, not official Tinder prices. A match is counted once per unordered pair. Its city and user attribution follow the second swipe. Message counts and conversation rate belong to the match creation cohort, not the message send month. Match status is the state at warehouse refresh. Filters do not imply a causal relationship.<br><br>Source: TinderDW_2401321041, exported from the tested SQL Server database. This self-contained snapshot works offline; rebuild with <code>python build_report.py --refresh</code> after database changes. <a href="Tinder-analytics.pdf">PDF report</a> · <a href="../README.md">Project README</a></footer></main>
<script>__PLOTLY__</script><script>const DATA=__DATA__; const titles=__TITLES__;const types=__TYPES__;
const cities=Object.fromEntries(DATA.DimCity.map(r=>[r.CityKey,r.CityName]));const plans=Object.fromEntries(DATA.DimPlan.map(r=>[r.PlanKey,r.PlanName]));const methods=Object.fromEntries(DATA.DimPaymentMethod.map(r=>[r.PaymentMethodKey,r.MethodName]));const swipeTypes=Object.fromEntries(DATA.DimSwipeType.map(r=>[r.SwipeTypeKey,r.SwipeType]));const matchStatus=Object.fromEntries(DATA.DimMatchStatus.map(r=>[r.MatchStatusKey,r.StatusName]));
function group(rows,key,value){let o={};for(const r of rows){let k=key(r);o[k]=(o[k]||0)+Number(r[value]);}return Object.fromEntries(Object.entries(o).sort(([a],[b])=>a.localeCompare(b)));}
const month=r=>String(r.DateKey).slice(0,4)+'-'+String(r.DateKey).slice(4,6);const fmt=n=>n.toLocaleString('en-US');
function render(){const y=document.querySelector('#year').value,c=document.querySelector('#city').value;const keep=r=>(y==='all'||String(r.DateKey).startsWith(y))&&(c==='all'||String(r.CityKey)===c);const s=DATA.FactSwipes.filter(keep),m=DATA.FactMatches.filter(keep),p=DATA.FactPayments.filter(keep);document.querySelector('#ks').textContent=fmt(s.length);document.querySelector('#km').textContent=fmt(m.length);document.querySelector('#kr').textContent=fmt(Math.round(p.reduce((a,r)=>a+r.NetRevenue,0)*100)/100);document.querySelector('#kc').textContent=m.length?(100*m.filter(r=>r.HasConversation).length/m.length).toFixed(1)+'%':'—';
let paying={};for(const r of p){if(r.PaymentStatus==='Paid'){(paying[month(r)]??=new Set()).add(r.UserKey)}}paying=Object.fromEntries(Object.entries(paying).sort(([a],[b])=>a.localeCompare(b)).map(([k,v])=>[k,v.size]));
const groups=[group(s,month,'SwipeCount'),group(m,r=>cities[r.CityKey],'MatchCount'),group(p,month,'NetRevenue'),group(s,r=>swipeTypes[r.SwipeTypeKey],'SwipeCount'),group(s,r=>String(r.TimeKey).padStart(2,'0')+':00','SwipeCount'),group(m,r=>matchStatus[r.MatchStatusKey],'MatchCount'),group(m,month,'MatchCount'),group(m,r=>cities[r.CityKey],'MessageCount'),group(p,r=>plans[r.PlanKey],'NetRevenue'),group(p,r=>methods[r.PaymentMethodKey],'NetRevenue'),group(p,r=>r.PaymentStatus,'PaymentCount'),paying];
groups.forEach((g,i)=>{let labels=Object.keys(g),values=Object.values(g),t=types[i],trace=t==='donut'?{type:'pie',labels,values,hole:.65,marker:{colors:['#EA4565','#168A87','#F5A65B','#6D67B7']},textinfo:'percent'}:t==='line'?{type:'scatter',x:labels,y:values,mode:'lines+markers',line:{color:'#EA4565',width:3},fill:'tozeroy',fillcolor:'rgba(234,69,101,.08)'}:{type:'bar',x:labels,y:values,marker:{color:'#168A87'}};Plotly.react('chart'+i,[trace],{title:{text:titles[i],font:{size:18}},margin:{l:60,r:20,t:60,b:65},font:{family:'Arial',color:'#182437'},paper_bgcolor:'white',plot_bgcolor:'white',showlegend:t==='donut',yaxis:{gridcolor:'#EDF0F5',rangemode:'tozero'},xaxis:{type:'category'}},{responsive:true,displaylogo:false});});}
document.querySelector('#year').addEventListener('change',render);document.querySelector('#city').addEventListener('change',render);render();</script></html>'''
html=html.replace('__CITIES__',''.join(f'<option value="{k}">{v}</option>' for k,v in city.items()))
for n in range(3):html=html.replace(f'__CHARTS{n+1}__',''.join(f'<div class="chart" id="chart{i}"></div>' for i in range(n*4,n*4+4)))
html=html.replace('__PLOTLY__',get_plotlyjs()).replace('__DATA__',json.dumps(data)).replace('__TITLES__',json.dumps(titles)).replace('__TYPES__',json.dumps(types))
(HERE/'Tinder-analytics.html').write_text(html,encoding='utf-8')

fontroot=Path('C:/Windows/Fonts')
if (fontroot/'arial.ttf').exists():
 pdfmetrics.registerFont(TTFont('ReportFont',str(fontroot/'arial.ttf')));pdfmetrics.registerFont(TTFont('ReportBold',str(fontroot/'arialbd.ttf')))
else:
 # Standard PDF fonts keep the report portable to other operating systems.
 from reportlab.pdfbase.pdfmetrics import Font
 pdfmetrics.registerFont(Font('ReportFont','Helvetica','WinAnsiEncoding'));pdfmetrics.registerFont(Font('ReportBold','Helvetica-Bold','WinAnsiEncoding'))
c=canvas.Canvas(str(HERE/'Tinder-analytics.pdf'),pagesize=(1200,900));c.setTitle('Tinder | Data Modeling & Analytics');c.setAuthor('Stoyan Yarchev - 2401321041')
for page,title in enumerate(['Overview','Engagement','Revenue']):
 c.setFillColor(HexColor('#F5F7FB'));c.rect(0,0,1200,900,fill=1,stroke=0);c.setFillColor(HexColor(navy));c.rect(0,765,1200,135,fill=1,stroke=0)
 c.setFont('ReportFont',12);c.setFillColor(HexColor('#F7A4B4'));c.drawString(35,865,'SOFTWARE MODELING & ANALYSIS  /  2401321041')
 c.setFillColor(white);c.setFont('ReportBold',32);c.drawString(35,817,f'Tinder / {title}')
 c.setFont('ReportFont',12);c.drawString(35,785,'Stoyan Yarchev | Fictional sample data | Jan 2025 - Oct 2026 | UTC')
 kpis=[('SWIPES',f"{totals['swipes']:,}"),('MATCHES',f"{totals['matches']:,}"),('NET REVENUE',f"EUR {totals['revenue']:,.2f}"),('CONVERSATION RATE',f"{totals['conversation_rate']:.1%}")]
 for i,(label,val) in enumerate(kpis):
  x=35+i*288;c.setFillColor(white);c.roundRect(x,670,267,75,8,fill=1,stroke=0);c.setFillColor(HexColor(navy));c.setFont('ReportFont',10);c.drawString(x+15,724,label);c.setFont('ReportBold',23);c.drawString(x+15,689,val)
 for j in range(4):c.drawImage(str(HERE/'charts'/f'{keys[page*4+j]}.png'),35+(j%2)*575,370-(j//2)*285,width=555,height=280)
 c.setFillColor(HexColor('#526279'));c.setFont('ReportFont',10)
 notes=['Source: SQL Server warehouse. Matches are unordered pairs. Revenue excludes failed/refunded payments.', 'Message metrics use match creation cohorts. Match status is current at refresh. Hours are UTC.', 'All prices are illustrative. Revenue counts Paid attempts only; refunded/failed attempts contribute zero.']
 c.drawString(35,60,notes[page]);c.drawString(35,40,'Offline interactive version: Tinder-analytics.html | Refresh: python build_report.py --refresh');c.drawRightString(1160,25,f'{page+1} / 3');c.showPage()
c.save()
print(json.dumps(totals,indent=2))

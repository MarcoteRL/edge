import sys
TZ = sys.argv[2] if len(sys.argv) > 2 else 'Europe/Madrid'
import sqlite3, pandas as pd, numpy as np, json, math
c=sqlite3.connect('file:'+sys.argv[1]+'?mode=ro',uri=True)
o=pd.read_sql("select rec_ts, hr from decoded_onehz order by rec_ts",c)
o['t']=pd.to_datetime(o.rec_ts,unit='s',utc=True).dt.tz_convert(TZ)
def y(x,f=False): return (0.86*math.exp(1.67*x)) if f else (0.64*math.exp(1.92*x))
def strain(net,C=15.0,M=400.0):
    if net<=0: return 0.0
    u=min(1,net/M); return min(21,21*math.log(1+u*(C-1))/math.log(C))
quiet={}
for day in [r[0] for r in c.execute('select day_id from day_result where rhr is not null and algo_version=(select max(algo_version) from day_result) order by day_id')]:
    p=json.loads(c.execute("select payload_json from day_result where day_id=? and algo_version=(select max(algo_version) from day_result)",(day,)).fetchone()[0])
    sc=p['scalars']; rhr=sc['rhr']; mx=sc['max_hr_used']
    w=p['sleep']['window']['value']; on,off=w['onset_ms']/1000,w['offset_ms']/1000
    d0=pd.Timestamp(day,tz=TZ); d1=d0+pd.Timedelta(days=1)
    seg=o[(o.t>=d0)&(o.t<d1)&~((o.rec_ts>=on)&(o.rec_ts<off))&(o.hr>0)]
    m=seg.set_index('t').hr.resample('1min').mean().dropna()
    x=((m-rhr)/(mx-rhr)).clip(lower=0)
    for fem in (False,True):
        tr=sum(xi*y(xi,fem) for xi in x)
        print(day, 'female' if fem else 'male', 'trimp_rel_err%', round(100*(tr-sc['trimp'])/sc['trimp'],1))
    q=float(np.median(x)); quiet[day]=q
    # guarded net: minutes >=0.4 never offset; others net against Q floor 0
    Q=sc.get('quiet_hrr') or q
    ex=x[x>=0.4]; lv=x[x<0.4]
    netq=sum(xi*y(xi) - Q*y(Q) for xi in lv); netq=max(0,netq)
    net=sum(xi*y(xi) for xi in ex)+netq
    net_pop=sum(xi*y(xi) for xi in ex)+max(0,sum(xi*y(xi)-0.2*y(0.2) for xi in lv))
    print(day,'wake_min',len(x),'min>=40%HRR',len(ex),'own-Q strain',round(strain(net),1),'pop-Q(0.20) strain',round(strain(net_pop),1), 'stored quiet_hrr vs my median diff', None if sc.get('quiet_hrr') is None else round(sc['quiet_hrr']-q,3))

import sys
TZ = sys.argv[2] if len(sys.argv) > 2 else 'Europe/Madrid'
import sqlite3, pandas as pd, numpy as np, json
c=sqlite3.connect('file:'+sys.argv[1]+'?mode=ro',uri=True)
o=pd.read_sql("select rec_ts, hr, band_sleep_state, dyn_accel_g, skin_temp_c from decoded_onehz order by rec_ts",c)
rr=pd.read_sql("select rec_ts, beat_ts_ms, rr_ms from decoded_rr order by beat_ts_ms",c)
res=[]
for day in [r[0] for r in c.execute('select day_id from day_result where rhr is not null and algo_version=(select max(algo_version) from day_result) order by day_id')]:
    p=json.loads(c.execute("select payload_json from day_result where day_id=? and algo_version=(select max(algo_version) from day_result)",(day,)).fetchone()[0])
    w=p['sleep']['window']['value']; on,off=w['onset_ms']/1000,w['offset_ms']/1000
    sc=p['scalars']; acc=p['sleep']['accounting']['value']
    seg=o[(o.rec_ts>=on)&(o.rec_ts<off)]
    hr=seg.hr.dropna(); hr=hr[hr>0]
    # lowest 30-min rolling mean
    r30=hr.rolling(1800,min_periods=1500).mean().min()
    b=rr[(rr.beat_ts_ms/1000>=on)&(rr.beat_ts_ms/1000<off)].copy()
    b['win']=((b.beat_ts_ms/1000-on)//300).astype(int)
    def rmssd(x):
        x=x.values.astype(float); d=np.diff(x)
        # Malik 20% rule
        ok=np.abs(d)/x[:-1] <=0.2
        d=d[ok]
        return np.sqrt(np.mean(d**2)) if len(d)>=20 else np.nan
    wr=b.groupby('win').rr_ms.apply(rmssd).dropna()
    # band sleep state vs our window
    bs=seg.band_sleep_state.value_counts(normalize=True).round(3).to_dict()
    outside=o[((o.rec_ts>=on-6*3600)&(o.rec_ts<on))|((o.rec_ts>=off)&(o.rec_ts<off+3*3600))].band_sleep_state.value_counts(normalize=True).round(3).to_dict()
    # band "sleep" interval: first/last state!=0 within +-6h
    near=o[(o.rec_ts>=on-4*3600)&(o.rec_ts<off+3*3600)]
    bsleep=near[near.band_sleep_state.isin([1,2,3])]
    res.append(dict(day=day, win_h=round((off-on)/3600,2), tst_h=round(acc['tst_sec']/3600,2), eff=acc['efficiency_pct'],
      rhr_rel_err_pct=round(100*(r30-sc['rhr'])/sc['rhr'],2) if sc.get('rhr') else None,
      rhr_noct_vs_rhr=round(sc['rhr_nocturnal']-sc['rhr'],2) if sc.get('rhr_nocturnal') else None,
      rmssd_mean_rel_err_pct=round(100*(wr.mean()-sc['rmssd'])/sc['rmssd'],1), rmssd_median_rel_err_pct=round(100*(wr.median()-sc['rmssd'])/sc['rmssd'],1),
      n_windows=len(wr), rr_cov=round(b.rr_ms.sum()/1000/(off-on),3),
      band_state_in_window=bs, band_state_outside=outside,
      band_onset_delta_min=round((bsleep.rec_ts.min()-on)/60) if len(bsleep) else None, band_offset_delta_min=round((bsleep.rec_ts.max()-off)/60) if len(bsleep) else None,
      sleep_source=p.get('sleep_source'), cycles=p['sleep'].get('cycle_count')))
for r in res: print(r)
# rr coverage by hour of day overall
rr['h']=pd.to_datetime(rr.beat_ts_ms,unit='ms',utc=True).dt.tz_convert(TZ).dt.hour
o['h']=pd.to_datetime(o.rec_ts,unit='s',utc=True).dt.tz_convert(TZ).dt.hour
cov=(rr.groupby('h').rr_ms.sum()/1000)/(o.groupby('h').size())
print('RR coverage by local hour:', cov.round(2).to_dict())
print('rr_ms quantiles', rr.rr_ms.quantile([.001,.01,.5,.99,.999]).to_dict())
d=np.diff(rr.rr_ms.values.astype(float)); print('successive diffs >20%:', np.mean(np.abs(d)/rr.rr_ms.values[:-1]>0.2))
print('rr quantization: distinct mod values', np.unique(rr.rr_ms.values % 4, return_counts=True))

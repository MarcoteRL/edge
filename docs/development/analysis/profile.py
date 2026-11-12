import sys
import sqlite3, json
c=sqlite3.connect('file:'+sys.argv[1]+'?mode=ro',uri=True)
tables=[r[0] for r in c.execute("select name from sqlite_master where type='table' order by name")]
for t in tables:
    n=c.execute(f'select count(*) from "{t}"').fetchone()[0]
    if n==0: continue
    cols=c.execute(f'pragma table_info("{t}")').fetchall()
    print(f'## {t} rows={n}')
    for cid,name,typ,nn,dflt,pk in cols:
        r=c.execute(f'select sum("{name}" is null), min("{name}"), max("{name}"), count(distinct "{name}"), typeof("{name}") from "{t}"').fetchone()
        mn,mx=r[1],r[2]
        if isinstance(mn,(bytes,)) or (isinstance(mn,str) and len(mn)>40): mn=mx='<blob/text>'
        print(f'  {name:24} {typ:8} null%={100*r[0]/n:5.1f} distinct={r[3]:7} type={r[4]} min={mn} max={mx}')

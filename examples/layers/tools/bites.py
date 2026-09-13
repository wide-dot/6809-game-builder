import cv2, numpy as np, sys
path=sys.argv[1]
cap=cv2.VideoCapture(path)
tracks=[]   # each: dict(cx,cy,area,maxarea,low_run,id)
NID=0; BITES=[]; FRAMES=0; COMPS_HIST=[]
while True:
    ok,img=cap.read()
    if not ok: break
    b,g,r=cv2.split(img)
    red=((r>150)&(g<100)&(b<100)).astype(np.uint8)
    n,lab,stats,cent=cv2.connectedComponentsWithStats(red,connectivity=8)
    comps=[(cent[i][0],cent[i][1],stats[i][4]) for i in range(1,n) if stats[i][4]>=40]
    COMPS_HIST.append(len(comps))
    new=[]
    for cx,cy,a in comps:
        BEST=None;BD=1e9
        for t in tracks:
            d=abs(t['cx']-cx)+abs(t['cy']-cy)
            if d<BD and d<24: BD=d;BEST=t
        if BEST is None:
            BEST={'id':NID,'maxarea':a,'low':0}; NID+=1
        else: tracks.remove(BEST)
        BEST.update(cx=cx,cy=cy,area=a)
        BEST['maxarea']=max(BEST['maxarea'],a)
        if a<0.75*BEST['maxarea']: BEST['low']+=1
        else:
            if BEST['low']>=3: BITES.append((FRAMES,BEST['id'],BEST['low'],BEST['maxarea'],int(cx),int(cy)))
            BEST['low']=0
        new.append(BEST)
    tracks=new; FRAMES+=1
for t in tracks:
    if t['low']>=3: BITES.append((FRAMES,t['id'],t['low'],t['maxarea']))
print(path, 'FRAMES',FRAMES,'comps median',int(np.median(COMPS_HIST)),'min',min(COMPS_HIST),'max',max(COMPS_HIST))
print('BITES (end_frame, track, run_len, maxarea):',len(BITES))
for x in BITES[:40]: print(' ',x)

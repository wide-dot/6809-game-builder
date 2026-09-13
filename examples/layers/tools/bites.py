import cv2, numpy as np, sys
path=sys.argv[1]
cap=cv2.VideoCapture(path)
tracks=[]   # each: dict(cx,cy,area,maxarea,low_run,id)
nid=0; bites=[]; frames=0; comps_hist=[]
while True:
    ok,img=cap.read()
    if not ok: break
    b,g,r=cv2.split(img)
    red=((r>150)&(g<100)&(b<100)).astype(np.uint8)
    n,lab,stats,cent=cv2.connectedComponentsWithStats(red,connectivity=8)
    comps=[(cent[i][0],cent[i][1],stats[i][4]) for i in range(1,n) if stats[i][4]>=40]
    comps_hist.append(len(comps))
    new=[]
    for cx,cy,a in comps:
        best=None;bd=1e9
        for t in tracks:
            d=abs(t['cx']-cx)+abs(t['cy']-cy)
            if d<bd and d<24: bd=d;best=t
        if best is None:
            best={'id':nid,'maxarea':a,'low':0}; nid+=1
        else: tracks.remove(best)
        best.update(cx=cx,cy=cy,area=a)
        best['maxarea']=max(best['maxarea'],a)
        if a<0.75*best['maxarea']: best['low']+=1
        else:
            if best['low']>=3: bites.append((frames,best['id'],best['low'],best['maxarea'],int(cx),int(cy)))
            best['low']=0
        new.append(best)
    tracks=new; frames+=1
for t in tracks:
    if t['low']>=3: bites.append((frames,t['id'],t['low'],t['maxarea']))
print(path, 'frames',frames,'comps median',int(np.median(comps_hist)),'min',min(comps_hist),'max',max(comps_hist))
print('bites (end_frame, track, run_len, maxarea):',len(bites))
for x in bites[:40]: print(' ',x)

"""decode les repertoires de dist/to8.fd et compte secteurs / octets par scene"""
import re, struct, glob, os
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
fd=open("dist/to8.fd","rb").read()
SCL=[1,15,13,11,9,7,5,3,8,6,4,2,16,14,12,10]
def off(face,track,secno): return face*80*4096+track*4096+(secno-1)*256
def read_dir(face,track,idx):
    skew=(track*2)&6
    s0=fd[off(face,track,SCL[(skew+idx)&15]):][:256]
    assert s0[:3]==b"IDX", s0[:8]
    n=s0[4]; base=struct.unpack(">H",s0[5:7])[0]
    data=b"".join(fd[off(face,track,SCL[(skew+idx+k)&15]):][:256] for k in range(n))
    p=7; entries={}; fid=base
    while p+8<=len(data):
        sizeu=struct.unpack(">H",data[p:p+2])[0]
        tr,sec,sizea,offa,nsec,sizez=data[p+2:p+8]
        if sizeu==0 and tr==0 and sec==0 and nsec==0 and sizea==0: break
        comp=bool(sizeu&0x8000); link=bool(sizeu&0x4000)
        # nsec compte TOUS les secteurs touches, partiels compris (FdUtil.cwrite : file[4]++ par secteur ecrit)
        full=nsec-(1 if sizea else 0)-(1 if sizez else 0)
        e={"usize":(sizeu&0x3fff)+1,"comp":comp,"link":link,"track":tr>>1,"face":tr&1,
           "sectors":nsec,"bytes":sizea+full*256+sizez,"shared":(1 if sizea else 0)+(1 if sizez else 0),"lsectors":0,"lbytes":0,"lshared":0}
        if sizea==0xff and offa==0: e.update(sectors=0,bytes=0,usize=0)
        p+=8
        if comp: p+=8
        if link:
            la,lofa,lnsec,lz=data[p+4:p+8]
            lfull=lnsec-(1 if la else 0)-(1 if lz else 0)
            e["lsectors"]=lnsec; e["lbytes"]=la+lfull*256+lz; e["lshared"]=(1 if la else 0)+(1 if lz else 0)
            p+=8
        entries[fid]=e; fid+=1+comp+link
    return base,entries
# les emplacements des repertoires, tels que le builder les a ecrits pour le loader
locs=[]
for l in open("gen/directories/locations.asm"):
    m=re.match(r"\s+fcb\s+(\d+),(\d+),(\d+),(\d+)\s+; directory", l)
    if m: locs.append((int(m.group(2)),int(m.group(3)),int(m.group(4))))
allE={}
for d,(face,track,idx) in enumerate(locs):
    base,ent=read_dir(face,track,idx); allE.update(ent)
    if __name__=="__main__": print("repertoire %2d : face %d piste %2d index %2d, %d entrees"%(d,face,track,idx,len(ent)))
names={}
for f in glob.glob("gen/directories/*/entries.asm"):
    for l in open(f):
        m=re.match(r"^(\S+) equ (\d+)\s*$", l)
        if m and not m.group(1).endswith((".page",".dir")): names[m.group(1)]=int(m.group(2))
missing=[n for n,i in names.items() if i not in allE]
print("fichiers nommes", len(names), "entrees decodees", len(allE), "manquants", len(missing), missing[:5])
tot={}
for f in glob.glob("gen/scenes/*.asm"):
    txt=open(f).read()
    for blk in re.finditer(r"; generated scene : (\S+)\n(.*?)fdb\s+0\s+; end marker", txt, re.S):
        sc=blk.group(1); files=[x for x in re.findall(r"fdb\s+([A-Za-z][\w.]*)\s*$", blk.group(2), re.M) if x in names and names[x] in allE]
        E=[allE[names[x]] for x in files]
        tot[sc]=dict(files=len(files),sectors=sum(e["sectors"]+e["lsectors"] for e in E),disk=sum(e["bytes"]+e["lbytes"] for e in E),
                     ram=sum(e["usize"] for e in E),zx0=sum(e["comp"] for e in E),zx0bytes=sum(e["bytes"] for e in E if e["comp"]),
                     link=sum(e["link"] for e in E),lbytes=sum(e["lbytes"] for e in E),
                     shared=sum(e["shared"]+e["lshared"] for e in E))
if __name__=="__main__":
    print("%-22s %4s %5s %5s %8s %8s | %4s %8s | %4s %7s"%("scene","fich","sect","part.","disque o","RAM o","zx0","zx0 o","link","lien o"))
    for sc in sorted(tot, key=lambda s: (not s.startswith("scenes."), s)):
        v=tot[sc]
        if v["files"]: print("%-22s %4d %5d %5d %8d %8d | %4d %8d | %4d %7d"%(sc,v["files"],v["sectors"],v["shared"],v["disk"],v["ram"],v["zx0"],v["zx0bytes"],v["link"],v["lbytes"]))

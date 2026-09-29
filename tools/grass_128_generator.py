from PIL import Image; import numpy as np
N=128; rng=np.random.default_rng(11)
pal=np.array([(58,90,52),(74,110,56),(90,128,60),(100,139,64),(128,158,74)],np.uint8)
def pnoise(scale,seed):
    r=np.random.default_rng(seed).standard_normal((N,N))
    f=np.fft.fft2(r); ky=np.fft.fftfreq(N)[:,None]; kx=np.fft.fftfreq(N)[None]
    f*=np.exp(-((kx**2+ky**2)*scale**2))
    n=np.real(np.fft.ifft2(f)); return (n-n.mean())/n.std()
big=pnoise(12,3)+0.28*pnoise(4,4)
out=np.full((N,N),2)
out[big>0.7]=3          # manchas claras (como las de la tierra)
# sin manchas oscuras grandes: se repetían visiblemente al tilear
spk=rng.random((N,N))
out[(spk<0.010)&(out==2)]=3
out[(spk<0.012)&(out==3)]=2
def wr(y,x,c):
    out[y%N,x%N]=c
TUFTS=[
 # (dy,dx,c): 0 raíz, 1 brizna, 4 punta iluminada
 [(0,0,0),(-1,-1,1),(-1,0,1),(-1,1,1),(-2,-2,1),(-2,0,1),(-2,2,1),(-3,0,4)],
 [(0,0,0),(-1,-1,1),(-1,1,1),(-2,-2,1),(-2,1,1),(-3,1,4)],
 [(0,0,0),(-1,0,1),(-1,1,1),(-2,-1,1),(-2,2,1),(-3,-1,3)],
 [(0,0,1),(-1,-1,1),(-1,1,1),(-2,-1,4)],
]
pts=[];tries=0
while len(pts)<75 and tries<20000:
    tries+=1; p=rng.integers(0,N,2)
    if all(min(abs(p[0]-q[0]),N-abs(p[0]-q[0]))**2+min(abs(p[1]-q[1]),N-abs(p[1]-q[1]))**2>=11**2 for q in pts):
        pts.append(p)
for y,x in pts:
    t=TUFTS[rng.choice(4,p=[.35,.25,.2,.2])]; f=-1 if rng.random()<.5 else 1
    for dy,dx,c in t: wr(y+dy,x+f*dx,c)
# briznas sueltas de 2 px
for _ in range(55):
    y,x=rng.integers(0,N,2)
    if out[y,x]==2 and out[(y-1)%N,x]==2:
        out[y,x]=1; out[(y-1)%N,x]=1 if rng.random()<.5 else 3
img=pal[out]
t=Image.fromarray(img,'RGB').convert('RGBA'); t.save('grass_128.png')
t.resize((1024,1024),Image.NEAREST).save('g_prev.png')
T2=Image.new('RGBA',(256,256))
for a in (0,128):
  for b in (0,128): T2.paste(t,(a,b))
T2.resize((768,768),Image.NEAREST).save('g_tile.png')
print(np.bincount(out.ravel(),minlength=5)/out.size)

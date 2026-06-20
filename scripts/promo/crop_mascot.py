from PIL import Image
BOX = (216, 272, 810, 752)
for plan in ("monthly","yearly"):
    im = Image.open(f"ref-images/promo/pro_{plan}_1024.png").convert("RGB").crop(BOX)
    px = im.load(); W,H = im.size
    # mascot is pure B/W line art -> any saturated (colored) pixel is card-corner
    # contamination; whiten it.
    for y in range(H):
        for x in range(W):
            r,g,b = px[x,y]; mx=max(r,g,b); mn=min(r,g,b)
            sat = (mx-mn)/mx if mx else 0
            if sat > 0.22 and mx > 60:
                px[x,y] = (255,255,255)
    im.save(f"build/promo/mascot_{plan}.png")
print("cleaned crop saved")

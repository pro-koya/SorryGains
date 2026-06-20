import base64, pathlib

OUT = pathlib.Path("build/promo")

# Per-plan visual identity (on-brand: dark base, amber=main accent for yearly,
# calm blue-grey for monthly). Subtle gradients only (DESIGN.md: no garish gradients).
PLANS = {
    "monthly": {
        "bg_top": "#26374F", "bg_bot": "#121A28", "ring": "rgba(142,166,193,0.16)",
        "pill_bg": "#8EA6C1", "pill_fg": "#0E1320", "plan_jp": "月額プラン",
    },
    "yearly": {
        "bg_top": "#6E4A16", "bg_bot": "#1C130A", "ring": "rgba(224,163,58,0.18)",
        "pill_bg": "#E0A33A", "pill_fg": "#1A1206", "plan_jp": "年額プラン",
    },
}

TITLE = "Muscle360 Pro"
BENEFIT = "3アプリのProが、ぜんぶ使える"

def b64(p):
    return base64.b64encode(pathlib.Path(p).read_bytes()).decode()

HTML = """<!doctype html><html><head><meta charset="utf-8"><style>
* {{ margin:0; padding:0; box-sizing:border-box; }}
html,body {{ width:1024px; height:1024px; overflow:hidden; }}
body {{
  font-family:"Hiragino Sans","Hiragino Kaku Gothic ProN",-apple-system,"Helvetica Neue",sans-serif;
  background:linear-gradient(170deg,{bg_top} 0%,{bg_bot} 100%);
  position:relative;
}}
.ring {{
  position:absolute; width:720px; height:720px; border-radius:50%;
  border:100px solid {ring}; top:250px; left:152px;
}}
.wrap {{ position:relative; width:1024px; height:1024px;
  display:flex; flex-direction:column; align-items:center; padding:72px 56px 64px; }}
.title {{ font-size:88px; font-weight:900; color:#fff; letter-spacing:-1px;
  line-height:1.02; text-align:center; white-space:nowrap;
  text-shadow:0 4px 18px rgba(0,0,0,0.30); }}
.benefit {{ margin-top:20px; font-size:47px; font-weight:800; color:#FFFFFF;
  letter-spacing:1px; line-height:1.12; text-align:center; white-space:nowrap;
  text-shadow:0 2px 10px rgba(0,0,0,0.28); }}
.card {{ margin-top:30px; width:604px; height:476px; background:#fff;
  border-radius:40px; box-shadow:0 18px 46px rgba(0,0,0,0.32);
  display:flex; align-items:center; justify-content:center; overflow:hidden; }}
.card img {{ width:560px; height:444px; object-fit:contain; }}
.pill {{ margin-top:38px; background:{pill_bg}; color:{pill_fg};
  font-size:68px; font-weight:900; letter-spacing:4px;
  padding:22px 92px; border-radius:999px; line-height:1;
  box-shadow:0 10px 30px rgba(0,0,0,0.28); }}
</style></head><body>
<div class="ring"></div>
<div class="wrap">
  <div class="title">{title}</div>
  <div class="benefit">{benefit}</div>
  <div class="card"><img src="data:image/png;base64,{mascot}"></div>
  <div class="pill">{plan_jp}</div>
</div>
</body></html>"""

for plan, c in PLANS.items():
    html = HTML.format(title=TITLE, benefit=BENEFIT, mascot=b64(OUT / f"mascot_{plan}.png"),
                       plan_jp=c["plan_jp"], bg_top=c["bg_top"], bg_bot=c["bg_bot"],
                       ring=c["ring"], pill_bg=c["pill_bg"], pill_fg=c["pill_fg"])
    (OUT / f"promo_{plan}.html").write_text(html, encoding="utf-8")
    print("wrote", OUT / f"promo_{plan}.html")

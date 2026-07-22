#!/usr/bin/env python3
"""Mechanical token pass: radii, durations, curves, Colors.white/black.
Run migrate_textstyle.py first, then this, then fix const + imports by hand.
    python3 tool/mech_pass.py <path...>
"""
import pathlib, re, sys
RAD={'32':'brHero','30':'brBanner','28':'brSheet','26':'brSheet','24':'brBanner','22':'brBanner',
     '21':'brPanel','20':'brPanel','18':'brPanel','16':'brCard','15':'brCard','14':'brTile',
     '13':'brTile','12':'brButton','11':'brSm','10':'brSm','9':'brSm','8':'brSm','6':'brXs','999':'brPill'}
DUR={'3000':'ambient','2400':'breathe','2200':'breathe','2000':'breathe','1500':'intro','1400':'shimmer',
     '1200':'verySlow','1100':'verySlow','1000':'verySlow','900':'burst','800':'refreshDwell','700':'refreshDwell',
     '650':'carouselSlide','640':'verySlow','600':'verySlow','520':'page','500':'page','450':'page','420':'page',
     '400':'slow','380':'slow','360':'slow','350':'slow','320':'slow','300':'slow','280':'medium','270':'medium',
     '260':'medium','250':'searchDebounce','240':'medium','220':'base','200':'base','180':'base','160':'searchDebounce',
     '150':'fast','120':'fast','100':'fast','90':'instant'}
CRV={'easeOutCubic':'easeOut','easeInOutCubic':'standard','easeInOut':'easeInOut','easeOut':'easeOut',
     'easeIn':'easeIn','ease':'ease','easeOutBack':'emphasized','elasticOut':'elastic','bounceOut':'bounce',
     'linear':'linear','fastOutSlowIn':'standard','decelerate':'decelerate','easeInCubic':'easeIn'}
def run(paths):
    files=[]
    for a in paths:
        p=pathlib.Path(a); files+=sorted(p.rglob('*.dart')) if p.is_dir() else [p]
    for p in files:
        s=orig=p.read_text(encoding='utf-8')
        s=re.sub(r'\bColors\.white\b','AppColors.onAccent',s)
        s=re.sub(r'\bColors\.black\b','AppColors.scrim',s)
        s=s.replace("BorderRadius.vertical(top: Radius.circular(28))","Radii.brSheetTop")
        s=s.replace("BorderRadius.vertical(top: Radius.circular(24))","Radii.brSheetTop")
        s=re.sub(r'BorderRadius\.circular\((\d+)\)', lambda m: f"Radii.{RAD[m.group(1)]}" if m.group(1) in RAD else m.group(0), s)
        s=re.sub(r'Radius\.circular\((\d+)\)', lambda m: f"Radii.{RAD[m.group(1)].replace('br','r')}" if m.group(1) in RAD else m.group(0), s)
        s=re.sub(r'const Duration\(milliseconds: (\d+)\)', lambda m: f"Motion.{DUR[m.group(1)]}" if m.group(1) in DUR else m.group(0), s)
        s=re.sub(r'\bCurves\.(\w+)', lambda m: f"Motion.{CRV[m.group(1)]}" if m.group(1) in CRV else m.group(0), s)
        if s!=orig: p.write_text(s,encoding='utf-8'); print(' ',p.name)
if __name__=='__main__': run(sys.argv[1:])

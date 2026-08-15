# font 
head > unitsPerEm (1024)
hhea > accent (768)
hhea > decent (-256)
hhea > linegap (0) (not sure if nessicary)

scale = px / unitsPerEm
height=(accent - decent + linegap) * scale

scale = 20 / 1024 = 0.01953125
height = (768 - (-256) + 0) * 0.01953125 = 20

NotoSansSC-Bold
unitsPerEm = 1000
accent = 1160
decent = -288
linegap = 0

scale = px / unitsPerEm
height=(accent - decent + linegap) * scale

height=(accent - decent + linegap) * (px / unitsPerEm)
h=(a-d+l)*(p/u)

px = (height*unitsPerEm)/(accent - decent + linegap)
px = (20*1000)/(1160 - -288 + 0)
px = 13.81215469613260

px = (height*1000)/(1160 - -288 + 0)
px = (height*1000)/1448

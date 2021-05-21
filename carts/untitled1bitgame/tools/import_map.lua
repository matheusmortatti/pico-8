
header = "pico-8 cartridge // http://www.pico-8.com\nversion 29\n__map__\n"

function parsetiled()
 return dofile (arg[1])
end

fexp=io.open(arg[2],"w")
io.output(fexp)
io.write(header)

tiled=parsetiled()
layer,i=tiled.layers[1],1
for y=0,layer.height-1 do
 for x=0,layer.width-1 do
  d=string.format('%02X', layer.data[i]==0 and 0 or layer.data[i]-1)
  io.write(d)
  i=i+1
 end
 io.write("\n")
end

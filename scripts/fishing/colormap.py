import sys
import arcpy

if len(sys.argv) != 2:
    print("Usage: python dump_lyr.py <file.lyr>")
    sys.exit(1)

lyr_file = sys.argv[1]

layer = arcpy.mapping.Layer(lyr_file)

print("Layer:", layer.name)

if layer.supports("DATASOURCE"):
    print("Source:", layer.dataSource)

sym = layer.symbology

print("Symbology type:", sym.symbologyType)

print("\nAvailable properties:")
for name in dir(sym):
    if name.startswith("_"):
        continue

    try:
        value = getattr(sym, name)
        if not callable(value):
            print("%-25s = %r" % (name, value))
    except Exception:
        pass

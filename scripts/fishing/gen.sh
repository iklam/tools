# Usage: bash ../../gen.sh $JAVA SeafloorCharacter_5m_MontereyCanyon.tif 

JAVA=$1
input=$2
tfw=$(basename $input .tif).tfw

echo JAVA=$JAVA
echo input=$input
echo tfw=$tfw
echo ""

if test ! -f "$2"; then
    echo input tiff "$2" does not exist
    exit 1
fi

if test ! -f "$tfw"; then
    echo input tfw "$tfw" does not exist
    exit 1
fi

mkdir -p output

echo ========== Fixing color
$JAVA $(dirname $0)/FixColors.java $2 output/fixed.png


echo ========== Regenerate tif with fixed color
cp -v $tfw output/fixed.tfw
#(cd output; rm -f fixed.tif; ls -l ; gdal_translate -a_srs EPSG:26910 fixed.png fixed.tif)
rm -f output/fixed.tif
ls -l output
gdal_translate -a_srs EPSG:26910 output/fixed.png output/fixed.tif

gdalinfo $input > output/orig.info
gdalinfo output/fixed.tif > output/fixed.tif.info

${IOIGIT}/scripts/scm/tkdiff output/orig.info output/fixed.tif.info

echo ========== Warping

gdalwarp -s_srs EPSG:26910 -t_srs EPSG:3857 -r bilinear output/fixed.tif output/fixed_warped.tif
ls -l output/fixed_warped.tif

echo ========== Add levels
gdaladdo -r average output/fixed_warped.tif 10 11 12 13 14 15 16
ls -l output/fixed_warped.tif

echo ========== Generate mbtiles
gdal_translate -of MBTILES -co TILE_FORMAT=PNG -co ZOOM_LEVEL_STRATEGY=UPPER \
       output/fixed_warped.tif output/final.mbtiles
ls -l output/final.mbtiles 

echo ========== Add levels .. again

gdaladdo -r bilinear output/final.mbtiles 2 4 8 16 32 64
ls -l output/final.mbtiles 

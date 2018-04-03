package Geo::GDAL::FFI;

use v5.10;
use strict;
use warnings;
use Carp;
use Alien::gdal;
use PDL;
use FFI::Platypus;
use FFI::Platypus::Buffer;
require Exporter;
require B;

our $VERSION = 0.01;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw();

use constant Warning => 2;
use constant Failure => 3;
use constant Fatal => 4;

use constant Read => 0;
use constant Write => 1;

our @errors;
our %immutable;
our %parent;

our %capabilities = (
    OPEN => 1,
    CREATE => 2,
    CREATECOPY => 3,
    VIRTUALIO => 4,
    RASTER => 5,
    VECTOR => 6,
    GNM => 7,
    NOTNULL_FIELDS => 8,
    DEFAULT_FIELDS => 9,
    NOTNULL_GEOMFIELDS => 10,
    NONSPATIAL => 11,
    FEATURE_STYLES => 12,
    );

sub capabilities {
    return sort {$capabilities{$a} <=> $capabilities{$b}} keys %capabilities;
}

our %access = (
    ReadOnly => 0,
    Update => 1
    );

sub access {
    return sort {$access{$a} <=> $access{$b}} keys %access;
}

our %open_flags = (
    READONLY => 0x00,
    UPDATE   => 0x01,
    ALL      => 0x00,
    RASTER   => 0x02,
    VECTOR   => 0x04,
    GNM      => 0x08,
    SHARED   => 0x20,
    VERBOSE_ERROR =>  0x40,
    INTERNAL      =>  0x80,
    ARRAY_BLOCK_ACCESS   =>    0x100,
    HASHSET_BLOCK_ACCESS =>    0x200,
    );

sub open_flags {
    return sort {$open_flags{$a} <=> $open_flags{$b}} keys %open_flags;
}

our %datatypes = (
    Unknown => 0,
    Byte => 1,
    UInt16 => 2,
    Int16 => 3,
    UInt32 => 4,
    Int32 => 5,
    Float32 => 6,
    Float64 => 7,
    CInt16 => 8,
    CInt32 => 9,
    CFloat32 => 10,
    CFloat64 => 11
    );
our %datatypes_reverse = reverse %datatypes;

sub datatypes {
    return sort {$datatypes{$a} <=> $datatypes{$b}} keys %datatypes;
}

our %resampling = (
    NearestNeighbour => 0,
    Bilinear => 1,
    Cubic => 2,
    CubicSpline => 3,
    ORA_Lanczos => 4,
    Average => 5,
    Mode => 6,
    Gauss => 7
    );

our %datatype2pdl_datatype = (
    Byte => $PDL::Types::PDL_B,
    Int16 => $PDL::Types::PDL_S,
    UInt16 => $PDL::Types::PDL_US,
    Int32 => $PDL::Types::PDL_L,
    Float32 => $PDL::Types::PDL_F,
    Float64 => $PDL::Types::PDL_D,
    );
our %pdl_datatype2datatype = reverse %datatype2pdl_datatype;

our %field_types = (
    Integer => 0,
    IntegerList => 1,
    Real => 2,
    RealList => 3,
    String => 4,
    StringList => 5,
    #WideString => 6,     # do not use
    #WideStringList => 7, # do not use
    Binary => 8,
    Date => 9,
    Time => 10,
    DateTime => 11,
    Integer64 => 12,
    Integer64List => 13,
    );
our %field_types_reverse = reverse %field_types;

sub field_types {
    return sort {$field_types{$a} <=> $field_types{$b}} keys %field_types;
}

our %field_subtypes = (
    None => 0,
    Boolean => 1,
    Int16 => 2,
    Float32 => 3
    );
our %field_subtypes_reverse = reverse %field_subtypes;

sub field_subtypes {
    return sort {$field_subtypes{$a} <=> $field_subtypes{$b}} keys %field_subtypes;
}

our %justification = (
    Undefined => 0,
    Left => 1,
    Right => 2
    );
our %justification_reverse = reverse %justification;

sub justification {
    return sort {$justification{$a} <=> $justification{$b}} keys %justification;
}

our %color_interpretations = (
    Undefined => 0,
    GrayIndex => 1,
    PaletteIndex => 2,
    RedBand => 3,
    GreenBand => 4,
    BlueBand => 5,
    AlphaBand => 6,
    HueBand => 7,
    SaturationBand => 8,
    LightnessBand => 9,
    CyanBand => 10,
    MagentaBand => 11,
    YellowBand => 12,
    BlackBand => 13,
    YCbCr_YBand => 14,
    YCbCr_CbBand => 15,
    YCbCr_CrBand => 16,
    );
our %color_interpretations_reverse = reverse %color_interpretations;

sub color_interpretations {
    return sort {$color_interpretations{$a} <=> $color_interpretations{$b}} keys %color_interpretations;
}

our %geometry_types = (
    Unknown => 0,
    Point => 1,
    LineString => 2,
    Polygon => 3,
    MultiPoint => 4,
    MultiLineString => 5,
    MultiPolygon => 6,
    GeometryCollection => 7,
    CircularString => 8,
    CompoundCurve => 9,
    CurvePolygon => 10,
    MultiCurve => 11,
    MultiSurface => 12,
    Curve => 13,
    Surface => 14,
    PolyhedralSurface => 15,
    TIN => 16,
    Triangle => 17,
    None => 100,
    LinearRing => 101,
    CircularStringZ => 1008,
    CompoundCurveZ => 1009,
    CurvePolygonZ => 1010,
    MultiCurveZ => 1011,
    MultiSurfaceZ => 1012,
    CurveZ => 1013,
    SurfaceZ => 1014,
    PolyhedralSurfaceZ => 1015,
    TINZ => 1016,
    TriangleZ => 1017,
    PointM => 2001,
    LineStringM => 2002,
    PolygonM => 2003,
    MultiPointM => 2004,
    MultiLineStringM => 2005,
    MultiPolygonM => 2006,
    GeometryCollectionM => 2007,
    CircularStringM => 2008,
    CompoundCurveM => 2009,
    CurvePolygonM => 2010,
    MultiCurveM => 2011,
    MultiSurfaceM => 2012,
    CurveM => 2013,
    SurfaceM => 2014,
    PolyhedralSurfaceM => 2015,
    TINM => 2016,
    TriangleM => 2017,
    PointZM => 3001,
    LineStringZM => 3002,
    PolygonZM => 3003,
    MultiPointZM => 3004,
    MultiLineStringZM => 3005,
    MultiPolygonZM => 3006,
    GeometryCollectionZM => 3007,
    CircularStringZM => 3008,
    CompoundCurveZM => 3009,
    CurvePolygonZM => 3010,
    MultiCurveZM => 3011,
    MultiSurfaceZM => 3012,
    CurveZM => 3013,
    SurfaceZM => 3014,
    PolyhedralSurfaceZM => 3015,
    TINZM => 3016,
    TriangleZM => 3017,
    Point25D => 0x80000001,
    LineString25D => 0x80000002,
    Polygon25D => 0x80000003,
    MultiPoint25D => 0x80000004,
    MultiLineString25D => 0x80000005,
    MultiPolygon25D => 0x80000006,
    GeometryCollection25D => 0x80000007
    );
our %geometry_types_reverse = reverse %geometry_types;

sub geometry_types {
    return sort {$geometry_types{$a} <=> $geometry_types{$b}} keys %geometry_types;
}

our %geometry_formats = (
    WKT => 1,
    );

sub geometry_formats {
    return sort {$geometry_formats{$a} <=> $geometry_formats{$b}} keys %geometry_formats;
}

our %grid_algorithms = (
    InverseDistanceToAPower => 1,
    MovingAverage => 2,
    NearestNeighbor => 3,
    MetricMinimum => 4,
    MetricMaximum => 5,
    MetricRange => 6,
    MetricCount => 7,
    MetricAverageDistance => 8,
    MetricAverageDistancePts => 9,
    Linear => 10,
    InverseDistanceToAPowerNearestNeighbor => 11
    );

sub isint {
    my $value = shift;
    my $b_obj = B::svref_2object(\$value);
    my $flags = $b_obj->FLAGS;
    return 1 if $flags & B::SVp_IOK() && !($flags & B::SVp_NOK()) && !($flags & B::SVp_POK());
}

sub new {
    my $class = shift;
    my $ffi = FFI::Platypus->new;
    $ffi->load_custom_type('::StringPointer' => 'string_pointer');
    $ffi->lib(Alien::gdal->dynamic_libs);

    $ffi->type('(pointer,size_t,size_t,opaque)->size_t' => 'VSIWriteFunction');
    $ffi->type('(int,int,string)->void' => 'CPLErrorHandler');
    $ffi->type('(double,string,pointer)->int' => 'GDALProgressFunc');
    $ffi->type('(pointer,int, pointer,int,int,unsigned int,unsigned int,int,int)->int' => 'GDALDerivedPixelFunc');
    $ffi->type('(pointer,int,int,pointer,pointer,pointer,pointer)->int' => 'GDALTransformerFunc');
    $ffi->type('(double,int,pointer,pointer,pointer)->int' => 'GDALContourWriter');

    # from port/*.h
    $ffi->attach('VSIFOpenL' => [qw/string string/] => 'opaque');
    $ffi->attach('VSIFCloseL' => ['opaque'] => 'int');
    $ffi->attach('VSIFWriteL' => [qw/pointer size_t size_t opaque/] => 'size_t');
    $ffi->attach('VSIStdoutSetRedirection' => ['VSIWriteFunction', 'opaque'] => 'void');
    $ffi->attach('CPLPushErrorHandler' => ['CPLErrorHandler'] => 'void');
    $ffi->attach('CSLDestroy' => ['opaque'] => 'void');
    $ffi->attach('CSLAddString' => ['opaque', 'string'] => 'opaque');
    $ffi->attach('CSLCount' => ['opaque'] => 'int');
    $ffi->attach('CSLGetField' => ['opaque', 'int'] => 'string');

    # from ogr_core.h
    $ffi->attach( 'OGR_GT_Flatten' => ['unsigned int'] => 'unsigned int');

# created with parse_h.pl
# from /home/ajolma/github/gdal/gdal/gcore/gdal.h
eval{$ffi->attach('GDALGetDataTypeSize' => ['unsigned int'] => 'int');};
eval{$ffi->attach('GDALGetDataTypeSizeBits' => ['unsigned int'] => 'int');};
eval{$ffi->attach('GDALGetDataTypeSizeBytes' => ['unsigned int'] => 'int');};
eval{$ffi->attach('GDALDataTypeIsComplex' => ['unsigned int'] => 'int');};
eval{$ffi->attach('GDALDataTypeIsInteger' => ['unsigned int'] => 'int');};
eval{$ffi->attach('GDALDataTypeIsFloating' => ['unsigned int'] => 'int');};
eval{$ffi->attach('GDALDataTypeIsSigned' => ['unsigned int'] => 'int');};
eval{$ffi->attach('GDALGetDataTypeName' => ['unsigned int'] => 'string');};
eval{$ffi->attach('GDALGetDataTypeByName' => [qw/string/] => 'unsigned int');};
eval{$ffi->attach('GDALDataTypeUnion' => ['unsigned int','unsigned int'] => 'unsigned int');};
eval{$ffi->attach('GDALDataTypeUnionWithValue' => ['unsigned int','double','int'] => 'unsigned int');};
eval{$ffi->attach('GDALFindDataType' => [qw/int int int int/] => 'unsigned int');};
eval{$ffi->attach('GDALFindDataTypeForValue' => [qw/double int/] => 'unsigned int');};
eval{$ffi->attach('GDALAdjustValueToDataType' => ['unsigned int','double','int*','int*'] => 'double');};
eval{$ffi->attach('GDALGetNonComplexDataType' => ['unsigned int'] => 'unsigned int');};
eval{$ffi->attach('GDALDataTypeIsConversionLossy' => ['unsigned int','unsigned int'] => 'int');};
eval{$ffi->attach('GDALGetAsyncStatusTypeName' => ['unsigned int'] => 'string');};
eval{$ffi->attach('GDALGetAsyncStatusTypeByName' => [qw/string/] => 'unsigned int');};
eval{$ffi->attach('GDALGetColorInterpretationName' => ['unsigned int'] => 'string');};
eval{$ffi->attach('GDALGetColorInterpretationByName' => [qw/string/] => 'unsigned int');};
eval{$ffi->attach('GDALGetPaletteInterpretationName' => ['unsigned int'] => 'string');};
eval{$ffi->attach('GDALAllRegister' => [] => 'void');};
eval{$ffi->attach('GDALCreate' => ['opaque','string','int','int','int','unsigned int','opaque'] => 'opaque');};
eval{$ffi->attach('GDALCreateCopy' => [qw/opaque string opaque int opaque GDALProgressFunc opaque/] => 'opaque');};
eval{$ffi->attach('GDALIdentifyDriver' => [qw/string opaque/] => 'opaque');};
eval{$ffi->attach('GDALIdentifyDriverEx' => ['string','unsigned int','string_pointer','string_pointer'] => 'opaque');};
eval{$ffi->attach('GDALOpen' => ['string','unsigned int'] => 'opaque');};
eval{$ffi->attach('GDALOpenShared' => ['string','unsigned int'] => 'opaque');};
eval{$ffi->attach('GDALOpenEx' => ['string','unsigned int','opaque','opaque','opaque'] => 'opaque');};
eval{$ffi->attach('GDALDumpOpenDatasets' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALGetDriverByName' => [qw/string/] => 'opaque');};
eval{$ffi->attach('GDALGetDriverCount' => [] => 'int');};
eval{$ffi->attach('GDALGetDriver' => [qw/int/] => 'opaque');};
eval{$ffi->attach('GDALCreateDriver' => [] => 'opaque');};
eval{$ffi->attach('GDALDestroyDriver' => [qw/opaque/] => 'void');};
eval{$ffi->attach('GDALRegisterDriver' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALDeregisterDriver' => [qw/opaque/] => 'void');};
eval{$ffi->attach('GDALDestroyDriverManager' => [] => 'void');};
eval{$ffi->attach('GDALDestroy' => [] => 'void');};
eval{$ffi->attach('GDALDeleteDataset' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('GDALRenameDataset' => [qw/opaque string string/] => 'int');};
eval{$ffi->attach('GDALCopyDatasetFiles' => [qw/opaque string string/] => 'int');};
eval{$ffi->attach('GDALValidateCreationOptions' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('GDALGetDriverShortName' => [qw/opaque/] => 'string');};
eval{$ffi->attach('GDALGetDriverLongName' => [qw/opaque/] => 'string');};
eval{$ffi->attach('GDALGetDriverHelpTopic' => [qw/opaque/] => 'string');};
eval{$ffi->attach('GDALGetDriverCreationOptionList' => [qw/opaque/] => 'string');};
eval{$ffi->attach('GDALInitGCPs' => [qw/int opaque/] => 'void');};
eval{$ffi->attach('GDALDeinitGCPs' => [qw/int opaque/] => 'void');};
eval{$ffi->attach('GDALDuplicateGCPs' => [qw/int opaque/] => 'opaque');};
eval{$ffi->attach('GDALGCPsToGeoTransform' => [qw/int opaque double* int/] => 'int');};
eval{$ffi->attach('GDALInvGeoTransform' => [qw/double* double*/] => 'int');};
eval{$ffi->attach('GDALApplyGeoTransform' => [qw/double* double double double* double*/] => 'void');};
eval{$ffi->attach('GDALComposeGeoTransforms' => [qw/double* double* double*/] => 'void');};
eval{$ffi->attach('GDALGetMetadataDomainList' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('GDALGetMetadata' => [qw/opaque string/] => 'opaque');};
eval{$ffi->attach('GDALSetMetadata' => [qw/opaque opaque string/] => 'int');};
eval{$ffi->attach('GDALGetMetadataItem' => [qw/opaque string string/] => 'string');};
eval{$ffi->attach('GDALSetMetadataItem' => [qw/opaque string string string/] => 'int');};
eval{$ffi->attach('GDALGetDescription' => [qw/opaque/] => 'string');};
eval{$ffi->attach('GDALSetDescription' => [qw/opaque string/] => 'void');};
eval{$ffi->attach('GDALGetDatasetDriver' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('GDALGetFileList' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('GDALClose' => [qw/opaque/] => 'void');};
eval{$ffi->attach('GDALGetRasterXSize' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALGetRasterYSize' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALGetRasterCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALGetRasterBand' => [qw/opaque int/] => 'opaque');};
eval{$ffi->attach('GDALAddBand' => ['opaque','unsigned int','opaque'] => 'int');};
eval{$ffi->attach('GDALBeginAsyncReader' => ['opaque','int','int','int','int','opaque','int','int','unsigned int','int','int*','int','int','int','string_pointer'] => 'opaque');};
eval{$ffi->attach('GDALEndAsyncReader' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('GDALDatasetRasterIO' => ['opaque','unsigned int','int','int','int','int','opaque','int','int','unsigned int','int','int*','int','int','int'] => 'int');};
eval{$ffi->attach('GDALDatasetRasterIOEx' => ['opaque','unsigned int','int','int','int','int','opaque','int','int','unsigned int','int','int*','sint64','sint64','sint64','opaque'] => 'int');};
eval{$ffi->attach('GDALDatasetAdviseRead' => ['opaque','int','int','int','int','int','int','unsigned int','int','int*','string_pointer'] => 'int');};
eval{$ffi->attach('GDALGetProjectionRef' => [qw/opaque/] => 'string');};
eval{$ffi->attach('GDALSetProjection' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('GDALGetGeoTransform' => [qw/opaque double[6]/] => 'int');};
eval{$ffi->attach('GDALSetGeoTransform' => [qw/opaque double[6]/] => 'int');};
eval{$ffi->attach('GDALGetGCPCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALGetGCPProjection' => [qw/opaque/] => 'string');};
eval{$ffi->attach('GDALGetGCPs' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('GDALSetGCPs' => [qw/opaque int opaque string/] => 'int');};
eval{$ffi->attach('GDALGetInternalHandle' => [qw/opaque string/] => 'opaque');};
eval{$ffi->attach('GDALReferenceDataset' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALDereferenceDataset' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALReleaseDataset' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALBuildOverviews' => [qw/opaque string int int* int int* GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('GDALGetOpenDatasets' => [qw/uint64* int*/] => 'void');};
eval{$ffi->attach('GDALGetAccess' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALFlushCache' => [qw/opaque/] => 'void');};
eval{$ffi->attach('GDALCreateDatasetMaskBand' => [qw/opaque int/] => 'int');};
eval{$ffi->attach('GDALDatasetCopyWholeRaster' => [qw/opaque opaque string_pointer GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('GDALRasterBandCopyWholeRaster' => [qw/opaque opaque string_pointer GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('GDALRegenerateOverviews' => [qw/opaque int uint64* string GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('GDALDatasetGetLayerCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALDatasetGetLayer' => [qw/opaque int/] => 'opaque');};
eval{$ffi->attach('GDALDatasetGetLayerByName' => [qw/opaque string/] => 'opaque');};
eval{$ffi->attach('GDALDatasetDeleteLayer' => [qw/opaque int/] => 'int');};
eval{$ffi->attach('GDALDatasetCreateLayer' => ['opaque','string','opaque','unsigned int','opaque'] => 'opaque');};
eval{$ffi->attach('GDALDatasetCopyLayer' => [qw/opaque opaque string opaque/] => 'opaque');};
eval{$ffi->attach('GDALDatasetResetReading' => [qw/opaque/] => 'void');};
eval{$ffi->attach('GDALDatasetGetNextFeature' => [qw/opaque uint64* double* GDALProgressFunc opaque/] => 'opaque');};
eval{$ffi->attach('GDALDatasetTestCapability' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('GDALDatasetExecuteSQL' => [qw/opaque string opaque string/] => 'opaque');};
eval{$ffi->attach('GDALDatasetReleaseResultSet' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('GDALDatasetGetStyleTable' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('GDALDatasetSetStyleTableDirectly' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('GDALDatasetSetStyleTable' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('GDALDatasetStartTransaction' => [qw/opaque int/] => 'int');};
eval{$ffi->attach('GDALDatasetCommitTransaction' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALDatasetRollbackTransaction' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALGetRasterDataType' => [qw/opaque/] => 'unsigned int');};
eval{$ffi->attach('GDALGetBlockSize' => [qw/opaque int* int*/] => 'void');};
eval{$ffi->attach('GDALGetActualBlockSize' => [qw/opaque int int int* int*/] => 'int');};
eval{$ffi->attach('GDALRasterAdviseRead' => ['opaque','int','int','int','int','int','int','unsigned int','string_pointer'] => 'int');};
eval{$ffi->attach('GDALRasterIO' => ['opaque','unsigned int','int','int','int','int','opaque','int','int','unsigned int','int','int'] => 'int');};
eval{$ffi->attach('GDALRasterIOEx' => ['opaque','unsigned int','int','int','int','int','opaque','int','int','unsigned int','sint64','sint64','opaque'] => 'int');};
eval{$ffi->attach('GDALReadBlock' => [qw/opaque int int opaque/] => 'int');};
eval{$ffi->attach('GDALWriteBlock' => [qw/opaque int int opaque/] => 'int');};
eval{$ffi->attach('GDALGetRasterBandXSize' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALGetRasterBandYSize' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALGetRasterAccess' => [qw/opaque/] => 'unsigned int');};
eval{$ffi->attach('GDALGetBandNumber' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALGetBandDataset' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('GDALGetRasterColorInterpretation' => [qw/opaque/] => 'unsigned int');};
eval{$ffi->attach('GDALSetRasterColorInterpretation' => ['opaque','unsigned int'] => 'int');};
eval{$ffi->attach('GDALGetRasterColorTable' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('GDALSetRasterColorTable' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('GDALHasArbitraryOverviews' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALGetOverviewCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALGetOverview' => [qw/opaque int/] => 'opaque');};
eval{$ffi->attach('GDALGetRasterNoDataValue' => [qw/opaque int*/] => 'double');};
eval{$ffi->attach('GDALSetRasterNoDataValue' => [qw/opaque double/] => 'int');};
eval{$ffi->attach('GDALDeleteRasterNoDataValue' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALGetRasterCategoryNames' => [qw/opaque/] => 'string_pointer');};
eval{$ffi->attach('GDALSetRasterCategoryNames' => [qw/opaque string_pointer/] => 'int');};
eval{$ffi->attach('GDALGetRasterMinimum' => [qw/opaque int*/] => 'double');};
eval{$ffi->attach('GDALGetRasterMaximum' => [qw/opaque int*/] => 'double');};
eval{$ffi->attach('GDALGetRasterStatistics' => [qw/opaque int int double* double* double* double*/] => 'int');};
eval{$ffi->attach('GDALComputeRasterStatistics' => [qw/opaque int double* double* double* double* GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('GDALSetRasterStatistics' => [qw/opaque double double double double/] => 'int');};
eval{$ffi->attach('GDALGetRasterUnitType' => [qw/opaque/] => 'string');};
eval{$ffi->attach('GDALSetRasterUnitType' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('GDALGetRasterOffset' => [qw/opaque int*/] => 'double');};
eval{$ffi->attach('GDALSetRasterOffset' => [qw/opaque double/] => 'int');};
eval{$ffi->attach('GDALGetRasterScale' => [qw/opaque int*/] => 'double');};
eval{$ffi->attach('GDALSetRasterScale' => [qw/opaque double/] => 'int');};
eval{$ffi->attach('GDALComputeRasterMinMax' => [qw/opaque int double/] => 'void');};
eval{$ffi->attach('GDALFlushRasterCache' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALGetRasterHistogram' => [qw/opaque double double int int* int int GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('GDALGetRasterHistogramEx' => [qw/opaque double double int uint64* int int GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('GDALGetDefaultHistogram' => [qw/opaque double* double* int* int* int GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('GDALGetDefaultHistogramEx' => [qw/opaque double* double* int* uint64* int GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('GDALSetDefaultHistogram' => [qw/opaque double double int int*/] => 'int');};
eval{$ffi->attach('GDALSetDefaultHistogramEx' => [qw/opaque double double int uint64*/] => 'int');};
eval{$ffi->attach('GDALGetRandomRasterSample' => [qw/opaque int float*/] => 'int');};
eval{$ffi->attach('GDALGetRasterSampleOverview' => [qw/opaque int/] => 'opaque');};
eval{$ffi->attach('GDALGetRasterSampleOverviewEx' => [qw/opaque uint64/] => 'opaque');};
eval{$ffi->attach('GDALFillRaster' => [qw/opaque double double/] => 'int');};
eval{$ffi->attach('GDALComputeBandStats' => [qw/opaque int double* double* GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('GDALOverviewMagnitudeCorrection' => [qw/opaque int uint64* GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('GDALGetDefaultRAT' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('GDALSetDefaultRAT' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('GDALAddDerivedBandPixelFunc' => [qw/string GDALDerivedPixelFunc/] => 'int');};
eval{$ffi->attach('GDALGetMaskBand' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('GDALGetMaskFlags' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALCreateMaskBand' => [qw/opaque int/] => 'int');};
eval{$ffi->attach('GDALGetDataCoverageStatus' => [qw/opaque int int int int int double*/] => 'int');};
eval{$ffi->attach('GDALARGetNextUpdatedRegion' => [qw/opaque double int* int* int* int*/] => 'unsigned int');};
eval{$ffi->attach('GDALARLockBuffer' => [qw/opaque double/] => 'int');};
eval{$ffi->attach('GDALARUnlockBuffer' => [qw/opaque/] => 'void');};
eval{$ffi->attach('GDALGeneralCmdLineProcessor' => [qw/int string_pointer int/] => 'int');};
eval{$ffi->attach('GDALSwapWords' => [qw/opaque int int int/] => 'void');};
eval{$ffi->attach('GDALSwapWordsEx' => [qw/opaque int size_t int/] => 'void');};
eval{$ffi->attach('GDALCopyWords' => ['opaque','unsigned int','int','opaque','unsigned int','int','int'] => 'void');};
eval{$ffi->attach('GDALCopyBits' => [qw/pointer int int pointer int int int int/] => 'void');};
eval{$ffi->attach('GDALLoadWorldFile' => [qw/string double*/] => 'int');};
eval{$ffi->attach('GDALReadWorldFile' => [qw/string string double*/] => 'int');};
eval{$ffi->attach('GDALWriteWorldFile' => [qw/string string double*/] => 'int');};
eval{$ffi->attach('GDALLoadTabFile' => [qw/string double* string_pointer int* opaque/] => 'int');};
eval{$ffi->attach('GDALReadTabFile' => [qw/string double* string_pointer int* opaque/] => 'int');};
eval{$ffi->attach('GDALLoadOziMapFile' => [qw/string double* string_pointer int* opaque/] => 'int');};
eval{$ffi->attach('GDALReadOziMapFile' => [qw/string double* string_pointer int* opaque/] => 'int');};
eval{$ffi->attach('GDALDecToDMS' => [qw/double string int/] => 'string');};
eval{$ffi->attach('GDALPackedDMSToDec' => [qw/double/] => 'double');};
eval{$ffi->attach('GDALDecToPackedDMS' => [qw/double/] => 'double');};
eval{$ffi->attach('GDALVersionInfo' => [qw/string/] => 'string');};
eval{$ffi->attach('GDALCheckVersion' => [qw/int int string/] => 'int');};
eval{$ffi->attach('GDALExtractRPCInfo' => [qw/string_pointer opaque/] => 'int');};
eval{$ffi->attach('GDALCreateColorTable' => ['unsigned int'] => 'opaque');};
eval{$ffi->attach('GDALDestroyColorTable' => [qw/opaque/] => 'void');};
eval{$ffi->attach('GDALCloneColorTable' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('GDALGetPaletteInterpretation' => [qw/opaque/] => 'unsigned int');};
eval{$ffi->attach('GDALGetColorEntryCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALGetColorEntry' => [qw/opaque int/] => 'short[4]');};
eval{$ffi->attach('GDALGetColorEntryAsRGB' => [qw/opaque int short[4]/] => 'int');};
eval{$ffi->attach('GDALSetColorEntry' => [qw/opaque int short[4]/] => 'void');};
eval{$ffi->attach('GDALCreateColorRamp' => [qw/opaque int short[4] int short[4]/] => 'void');};
eval{$ffi->attach('GDALCreateRasterAttributeTable' => [] => 'opaque');};
eval{$ffi->attach('GDALDestroyRasterAttributeTable' => [qw/opaque/] => 'void');};
eval{$ffi->attach('GDALRATGetColumnCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALRATGetNameOfCol' => [qw/opaque int/] => 'string');};
eval{$ffi->attach('GDALRATGetUsageOfCol' => [qw/opaque int/] => 'unsigned int');};
eval{$ffi->attach('GDALRATGetTypeOfCol' => [qw/opaque int/] => 'unsigned int');};
eval{$ffi->attach('GDALRATGetColOfUsage' => ['opaque','unsigned int'] => 'int');};
eval{$ffi->attach('GDALRATGetRowCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALRATGetValueAsString' => [qw/opaque int int/] => 'string');};
eval{$ffi->attach('GDALRATGetValueAsInt' => [qw/opaque int int/] => 'int');};
eval{$ffi->attach('GDALRATGetValueAsDouble' => [qw/opaque int int/] => 'double');};
eval{$ffi->attach('GDALRATSetValueAsString' => [qw/opaque int int string/] => 'void');};
eval{$ffi->attach('GDALRATSetValueAsInt' => [qw/opaque int int int/] => 'void');};
eval{$ffi->attach('GDALRATSetValueAsDouble' => [qw/opaque int int double/] => 'void');};
eval{$ffi->attach('GDALRATChangesAreWrittenToFile' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALRATValuesIOAsDouble' => ['opaque','unsigned int','int','int','int','double*'] => 'int');};
eval{$ffi->attach('GDALRATValuesIOAsInteger' => ['opaque','unsigned int','int','int','int','int*'] => 'int');};
eval{$ffi->attach('GDALRATValuesIOAsString' => ['opaque','unsigned int','int','int','int','string_pointer'] => 'int');};
eval{$ffi->attach('GDALRATSetRowCount' => [qw/opaque int/] => 'void');};
eval{$ffi->attach('GDALRATCreateColumn' => ['opaque','string','unsigned int','unsigned int'] => 'int');};
eval{$ffi->attach('GDALRATSetLinearBinning' => [qw/opaque double double/] => 'int');};
eval{$ffi->attach('GDALRATGetLinearBinning' => [qw/opaque double* double*/] => 'int');};
eval{$ffi->attach('GDALRATInitializeFromColorTable' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('GDALRATTranslateToColorTable' => [qw/opaque int/] => 'opaque');};
eval{$ffi->attach('GDALRATDumpReadable' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('GDALRATClone' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('GDALRATSerializeJSON' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('GDALRATGetRowOfValue' => [qw/opaque double/] => 'int');};
eval{$ffi->attach('GDALSetCacheMax' => [qw/int/] => 'void');};
eval{$ffi->attach('GDALGetCacheMax' => [] => 'int');};
eval{$ffi->attach('GDALGetCacheUsed' => [] => 'int');};
eval{$ffi->attach('GDALSetCacheMax64' => [qw/sint64/] => 'void');};
eval{$ffi->attach('GDALGetCacheMax64' => [] => 'sint64');};
eval{$ffi->attach('GDALGetCacheUsed64' => [] => 'sint64');};
eval{$ffi->attach('GDALFlushCacheBlock' => [] => 'int');};
eval{$ffi->attach('GDALDatasetGetVirtualMem' => ['opaque','unsigned int','int','int','int','int','int','int','unsigned int','int','int*','int','sint64','sint64','size_t','size_t','int','string_pointer'] => 'opaque');};
eval{$ffi->attach('GDALRasterBandGetVirtualMem' => ['opaque','unsigned int','int','int','int','int','int','int','unsigned int','int','sint64','size_t','size_t','int','string_pointer'] => 'opaque');};
eval{$ffi->attach('GDALGetVirtualMemAuto' => ['opaque','unsigned int','int*','sint64*','string_pointer'] => 'opaque');};
eval{$ffi->attach('GDALDatasetGetTiledVirtualMem' => ['opaque','unsigned int','int','int','int','int','int','int','unsigned int','int','int*','unsigned int','size_t','int','string_pointer'] => 'opaque');};
eval{$ffi->attach('GDALRasterBandGetTiledVirtualMem' => ['opaque','unsigned int','int','int','int','int','int','int','unsigned int','size_t','int','string_pointer'] => 'opaque');};
eval{$ffi->attach('GDALCreatePansharpenedVRT' => [qw/string opaque int uint64*/] => 'opaque');};
eval{$ffi->attach('GDALGetJPEG2000Structure' => [qw/string string_pointer/] => 'opaque');};
# from /home/ajolma/github/gdal/gdal/ogr/ogr_api.h
eval{$ffi->attach('OGR_G_CreateFromWkb' => [qw/string opaque uint64* int/] => 'int');};
eval{$ffi->attach('OGR_G_CreateFromWkt' => [qw/string_pointer opaque uint64*/] => 'int');};
eval{$ffi->attach('OGR_G_CreateFromFgf' => [qw/string opaque uint64* int int*/] => 'int');};
eval{$ffi->attach('OGR_G_DestroyGeometry' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_G_CreateGeometry' => ['unsigned int'] => 'opaque');};
eval{$ffi->attach('OGR_G_ApproximateArcAngles' => [qw/double double double double double double double double double/] => 'opaque');};
eval{$ffi->attach('OGR_G_ForceToPolygon' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_ForceToLineString' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_ForceToMultiPolygon' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_ForceToMultiPoint' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_ForceToMultiLineString' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_ForceTo' => ['opaque','unsigned int','string_pointer'] => 'opaque');};
eval{$ffi->attach('OGR_G_GetDimension' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_G_GetCoordinateDimension' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_G_CoordinateDimension' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_G_SetCoordinateDimension' => [qw/opaque int/] => 'void');};
eval{$ffi->attach('OGR_G_Is3D' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_G_IsMeasured' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_G_Set3D' => [qw/opaque int/] => 'void');};
eval{$ffi->attach('OGR_G_SetMeasured' => [qw/opaque int/] => 'void');};
eval{$ffi->attach('OGR_G_Clone' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_GetEnvelope' => [qw/opaque double[4]/] => 'void');};
eval{$ffi->attach('OGR_G_GetEnvelope3D' => [qw/opaque double[6]/] => 'void');};
eval{$ffi->attach('OGR_G_ImportFromWkb' => [qw/opaque string int/] => 'int');};
eval{$ffi->attach('OGR_G_ExportToWkb' => ['opaque','unsigned int','string'] => 'int');};
eval{$ffi->attach('OGR_G_ExportToIsoWkb' => ['opaque','unsigned int','string'] => 'int');};
eval{$ffi->attach('OGR_G_WkbSize' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_G_ImportFromWkt' => [qw/opaque string_pointer/] => 'int');};
eval{$ffi->attach('OGR_G_ExportToWkt' => [qw/opaque string_pointer/] => 'int');};
eval{$ffi->attach('OGR_G_ExportToIsoWkt' => [qw/opaque string_pointer/] => 'int');};
eval{$ffi->attach('OGR_G_GetGeometryType' => [qw/opaque/] => 'unsigned int');};
eval{$ffi->attach('OGR_G_GetGeometryName' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_G_DumpReadable' => [qw/opaque opaque string/] => 'void');};
eval{$ffi->attach('OGR_G_FlattenTo2D' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_G_CloseRings' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_G_CreateFromGML' => [qw/string/] => 'opaque');};
eval{$ffi->attach('OGR_G_ExportToGML' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_G_ExportToGMLEx' => [qw/opaque string_pointer/] => 'string');};
eval{$ffi->attach('OGR_G_CreateFromGMLTree' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_ExportToGMLTree' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_ExportEnvelopeToGMLTree' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_ExportToKML' => [qw/opaque string/] => 'string');};
eval{$ffi->attach('OGR_G_ExportToJson' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_G_ExportToJsonEx' => [qw/opaque string_pointer/] => 'string');};
eval{$ffi->attach('OGR_G_CreateGeometryFromJson' => [qw/string/] => 'opaque');};
eval{$ffi->attach('OGR_G_AssignSpatialReference' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('OGR_G_GetSpatialReference' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_Transform' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_G_TransformTo' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_G_Simplify' => [qw/opaque double/] => 'opaque');};
eval{$ffi->attach('OGR_G_SimplifyPreserveTopology' => [qw/opaque double/] => 'opaque');};
eval{$ffi->attach('OGR_G_DelaunayTriangulation' => [qw/opaque double int/] => 'opaque');};
eval{$ffi->attach('OGR_G_Segmentize' => [qw/opaque double/] => 'void');};
eval{$ffi->attach('OGR_G_Intersects' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_G_Equals' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_G_Disjoint' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_G_Touches' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_G_Crosses' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_G_Within' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_G_Contains' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_G_Overlaps' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_G_Boundary' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_ConvexHull' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_Buffer' => [qw/opaque double int/] => 'opaque');};
eval{$ffi->attach('OGR_G_Intersection' => [qw/opaque opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_Union' => [qw/opaque opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_UnionCascaded' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_PointOnSurface' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_Difference' => [qw/opaque opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_SymDifference' => [qw/opaque opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_Distance' => [qw/opaque opaque/] => 'double');};
eval{$ffi->attach('OGR_G_Distance3D' => [qw/opaque opaque/] => 'double');};
eval{$ffi->attach('OGR_G_Length' => [qw/opaque/] => 'double');};
eval{$ffi->attach('OGR_G_Area' => [qw/opaque/] => 'double');};
eval{$ffi->attach('OGR_G_Centroid' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_G_Value' => [qw/opaque double/] => 'opaque');};
eval{$ffi->attach('OGR_G_Empty' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_G_IsEmpty' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_G_IsValid' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_G_IsSimple' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_G_IsRing' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_G_Polygonize' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_Intersect' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_G_Equal' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_G_SymmetricDifference' => [qw/opaque opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_GetArea' => [qw/opaque/] => 'double');};
eval{$ffi->attach('OGR_G_GetBoundary' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_GetPointCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_G_GetPoints' => [qw/opaque opaque int opaque int opaque int/] => 'int');};
eval{$ffi->attach('OGR_G_GetPointsZM' => [qw/opaque opaque int opaque int opaque int opaque int/] => 'int');};
eval{$ffi->attach('OGR_G_GetX' => [qw/opaque int/] => 'double');};
eval{$ffi->attach('OGR_G_GetY' => [qw/opaque int/] => 'double');};
eval{$ffi->attach('OGR_G_GetZ' => [qw/opaque int/] => 'double');};
eval{$ffi->attach('OGR_G_GetM' => [qw/opaque int/] => 'double');};
eval{$ffi->attach('OGR_G_GetPoint' => [qw/opaque int double* double* double*/] => 'void');};
eval{$ffi->attach('OGR_G_GetPointZM' => [qw/opaque int double* double* double* double*/] => 'void');};
eval{$ffi->attach('OGR_G_SetPointCount' => [qw/opaque int/] => 'void');};
eval{$ffi->attach('OGR_G_SetPoint' => [qw/opaque int double double double/] => 'void');};
eval{$ffi->attach('OGR_G_SetPoint_2D' => [qw/opaque int double double/] => 'void');};
eval{$ffi->attach('OGR_G_SetPointM' => [qw/opaque int double double double/] => 'void');};
eval{$ffi->attach('OGR_G_SetPointZM' => [qw/opaque int double double double double/] => 'void');};
eval{$ffi->attach('OGR_G_AddPoint' => [qw/opaque double double double/] => 'void');};
eval{$ffi->attach('OGR_G_AddPoint_2D' => [qw/opaque double double/] => 'void');};
eval{$ffi->attach('OGR_G_AddPointM' => [qw/opaque double double double/] => 'void');};
eval{$ffi->attach('OGR_G_AddPointZM' => [qw/opaque double double double double/] => 'void');};
eval{$ffi->attach('OGR_G_SetPoints' => [qw/opaque int opaque int opaque int opaque int/] => 'void');};
eval{$ffi->attach('OGR_G_SetPointsZM' => [qw/opaque int opaque int opaque int opaque int opaque int/] => 'void');};
eval{$ffi->attach('OGR_G_SwapXY' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_G_GetGeometryCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_G_GetGeometryRef' => [qw/opaque int/] => 'opaque');};
eval{$ffi->attach('OGR_G_AddGeometry' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_G_AddGeometryDirectly' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_G_RemoveGeometry' => [qw/opaque int int/] => 'int');};
eval{$ffi->attach('OGR_G_HasCurveGeometry' => [qw/opaque int/] => 'int');};
eval{$ffi->attach('OGR_G_GetLinearGeometry' => [qw/opaque double string_pointer/] => 'opaque');};
eval{$ffi->attach('OGR_G_GetCurveGeometry' => [qw/opaque string_pointer/] => 'opaque');};
eval{$ffi->attach('OGRBuildPolygonFromEdges' => [qw/opaque int int double int*/] => 'opaque');};
eval{$ffi->attach('OGRSetGenerate_DB2_V72_BYTE_ORDER' => [qw/int/] => 'int');};
eval{$ffi->attach('OGRGetGenerate_DB2_V72_BYTE_ORDER' => [] => 'int');};
eval{$ffi->attach('OGRSetNonLinearGeometriesEnabledFlag' => [qw/int/] => 'void');};
eval{$ffi->attach('OGRGetNonLinearGeometriesEnabledFlag' => [] => 'int');};
eval{$ffi->attach('OGR_Fld_Create' => ['string','unsigned int'] => 'opaque');};
eval{$ffi->attach('OGR_Fld_Destroy' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_Fld_SetName' => [qw/opaque string/] => 'void');};
eval{$ffi->attach('OGR_Fld_GetNameRef' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_Fld_GetType' => [qw/opaque/] => 'unsigned int');};
eval{$ffi->attach('OGR_Fld_SetType' => ['opaque','unsigned int'] => 'void');};
eval{$ffi->attach('OGR_Fld_GetSubType' => [qw/opaque/] => 'unsigned int');};
eval{$ffi->attach('OGR_Fld_SetSubType' => ['opaque','unsigned int'] => 'void');};
eval{$ffi->attach('OGR_Fld_GetJustify' => [qw/opaque/] => 'unsigned int');};
eval{$ffi->attach('OGR_Fld_SetJustify' => ['opaque','unsigned int'] => 'void');};
eval{$ffi->attach('OGR_Fld_GetWidth' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_Fld_SetWidth' => [qw/opaque int/] => 'void');};
eval{$ffi->attach('OGR_Fld_GetPrecision' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_Fld_SetPrecision' => [qw/opaque int/] => 'void');};
eval{$ffi->attach('OGR_Fld_Set' => ['opaque','string','unsigned int','int','int','unsigned int'] => 'void');};
eval{$ffi->attach('OGR_Fld_IsIgnored' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_Fld_SetIgnored' => [qw/opaque int/] => 'void');};
eval{$ffi->attach('OGR_Fld_IsNullable' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_Fld_SetNullable' => [qw/opaque int/] => 'void');};
eval{$ffi->attach('OGR_Fld_GetDefault' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_Fld_SetDefault' => [qw/opaque string/] => 'void');};
eval{$ffi->attach('OGR_Fld_IsDefaultDriverSpecific' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_GetFieldTypeName' => ['unsigned int'] => 'string');};
eval{$ffi->attach('OGR_GetFieldSubTypeName' => ['unsigned int'] => 'string');};
eval{$ffi->attach('OGR_AreTypeSubTypeCompatible' => ['unsigned int','unsigned int'] => 'int');};
eval{$ffi->attach('OGR_GFld_Create' => ['string','unsigned int'] => 'opaque');};
eval{$ffi->attach('OGR_GFld_Destroy' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_GFld_SetName' => [qw/opaque string/] => 'void');};
eval{$ffi->attach('OGR_GFld_GetNameRef' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_GFld_GetType' => [qw/opaque/] => 'unsigned int');};
eval{$ffi->attach('OGR_GFld_SetType' => ['opaque','unsigned int'] => 'void');};
eval{$ffi->attach('OGR_GFld_GetSpatialRef' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_GFld_SetSpatialRef' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('OGR_GFld_IsNullable' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_GFld_SetNullable' => [qw/opaque int/] => 'void');};
eval{$ffi->attach('OGR_GFld_IsIgnored' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_GFld_SetIgnored' => [qw/opaque int/] => 'void');};
eval{$ffi->attach('OGR_FD_Create' => [qw/string/] => 'opaque');};
eval{$ffi->attach('OGR_FD_Destroy' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_FD_Release' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_FD_GetName' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_FD_GetFieldCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_FD_GetFieldDefn' => [qw/opaque int/] => 'opaque');};
eval{$ffi->attach('OGR_FD_GetFieldIndex' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OGR_FD_AddFieldDefn' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('OGR_FD_DeleteFieldDefn' => [qw/opaque int/] => 'int');};
eval{$ffi->attach('OGR_FD_ReorderFieldDefns' => [qw/opaque int*/] => 'int');};
eval{$ffi->attach('OGR_FD_GetGeomType' => [qw/opaque/] => 'unsigned int');};
eval{$ffi->attach('OGR_FD_SetGeomType' => ['opaque','unsigned int'] => 'void');};
eval{$ffi->attach('OGR_FD_IsGeometryIgnored' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_FD_SetGeometryIgnored' => [qw/opaque int/] => 'void');};
eval{$ffi->attach('OGR_FD_IsStyleIgnored' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_FD_SetStyleIgnored' => [qw/opaque int/] => 'void');};
eval{$ffi->attach('OGR_FD_Reference' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_FD_Dereference' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_FD_GetReferenceCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_FD_GetGeomFieldCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_FD_GetGeomFieldDefn' => [qw/opaque int/] => 'opaque');};
eval{$ffi->attach('OGR_FD_GetGeomFieldIndex' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OGR_FD_AddGeomFieldDefn' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('OGR_FD_DeleteGeomFieldDefn' => [qw/opaque int/] => 'int');};
eval{$ffi->attach('OGR_FD_IsSame' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_F_Create' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_F_Destroy' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_F_GetDefnRef' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_F_SetGeometryDirectly' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_F_SetGeometry' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_F_GetGeometryRef' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_F_StealGeometry' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_F_Clone' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_F_Equal' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_F_GetFieldCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_F_GetFieldDefnRef' => [qw/opaque int/] => 'opaque');};
eval{$ffi->attach('OGR_F_GetFieldIndex' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OGR_F_IsFieldSet' => [qw/opaque int/] => 'int');};
eval{$ffi->attach('OGR_F_UnsetField' => [qw/opaque int/] => 'void');};
eval{$ffi->attach('OGR_F_IsFieldNull' => [qw/opaque int/] => 'int');};
eval{$ffi->attach('OGR_F_IsFieldSetAndNotNull' => [qw/opaque int/] => 'int');};
eval{$ffi->attach('OGR_F_SetFieldNull' => [qw/opaque int/] => 'void');};
eval{$ffi->attach('OGR_F_GetRawFieldRef' => [qw/opaque int/] => 'opaque');};
eval{$ffi->attach('OGR_RawField_IsUnset' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_RawField_IsNull' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_RawField_SetUnset' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_RawField_SetNull' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_F_GetFieldAsInteger' => [qw/opaque int/] => 'int');};
eval{$ffi->attach('OGR_F_GetFieldAsInteger64' => [qw/opaque int/] => 'sint64');};
eval{$ffi->attach('OGR_F_GetFieldAsDouble' => [qw/opaque int/] => 'double');};
eval{$ffi->attach('OGR_F_GetFieldAsString' => [qw/opaque int/] => 'string');};
eval{$ffi->attach('OGR_F_GetFieldAsIntegerList' => [qw/opaque int int*/] => 'pointer');};
eval{$ffi->attach('OGR_F_GetFieldAsInteger64List' => [qw/opaque int int*/] => 'pointer');};
eval{$ffi->attach('OGR_F_GetFieldAsDoubleList' => [qw/opaque int int*/] => 'pointer');};
eval{$ffi->attach('OGR_F_GetFieldAsStringList' => [qw/opaque int/] => 'opaque');};
eval{$ffi->attach('OGR_F_GetFieldAsBinary' => [qw/opaque int int*/] => 'pointer');};
eval{$ffi->attach('OGR_F_GetFieldAsDateTime' => [qw/opaque int int* int* int* int* int* int* int*/] => 'int');};
eval{$ffi->attach('OGR_F_GetFieldAsDateTimeEx' => [qw/opaque int int* int* int* int* int* float* int*/] => 'int');};
eval{$ffi->attach('OGR_F_SetFieldInteger' => [qw/opaque int int/] => 'void');};
eval{$ffi->attach('OGR_F_SetFieldInteger64' => [qw/opaque int sint64/] => 'void');};
eval{$ffi->attach('OGR_F_SetFieldDouble' => [qw/opaque int double/] => 'void');};
eval{$ffi->attach('OGR_F_SetFieldString' => [qw/opaque int string/] => 'void');};
eval{$ffi->attach('OGR_F_SetFieldIntegerList' => [qw/opaque int int int[]/] => 'void');};
eval{$ffi->attach('OGR_F_SetFieldInteger64List' => [qw/opaque int int sint64[]/] => 'void');};
eval{$ffi->attach('OGR_F_SetFieldDoubleList' => [qw/opaque int int double[]/] => 'void');};
eval{$ffi->attach('OGR_F_SetFieldStringList' => [qw/opaque int opaque/] => 'void');};
eval{$ffi->attach('OGR_F_SetFieldRaw' => [qw/opaque int opaque/] => 'void');};
eval{$ffi->attach('OGR_F_SetFieldBinary' => [qw/opaque int int pointer/] => 'void');};
eval{$ffi->attach('OGR_F_SetFieldDateTime' => [qw/opaque int int int int int int int int/] => 'void');};
eval{$ffi->attach('OGR_F_SetFieldDateTimeEx' => [qw/opaque int int int int int int float int/] => 'void');};
eval{$ffi->attach('OGR_F_GetGeomFieldCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_F_GetGeomFieldDefnRef' => [qw/opaque int/] => 'opaque');};
eval{$ffi->attach('OGR_F_GetGeomFieldIndex' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OGR_F_GetGeomFieldRef' => [qw/opaque int/] => 'opaque');};
eval{$ffi->attach('OGR_F_SetGeomFieldDirectly' => [qw/opaque int opaque/] => 'int');};
eval{$ffi->attach('OGR_F_SetGeomField' => [qw/opaque int opaque/] => 'int');};
eval{$ffi->attach('OGR_F_GetFID' => [qw/opaque/] => 'sint64');};
eval{$ffi->attach('OGR_F_SetFID' => [qw/opaque sint64/] => 'int');};
eval{$ffi->attach('OGR_F_DumpReadable' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('OGR_F_SetFrom' => [qw/opaque opaque int/] => 'int');};
eval{$ffi->attach('OGR_F_SetFromWithMap' => [qw/opaque opaque int int*/] => 'int');};
eval{$ffi->attach('OGR_F_GetStyleString' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_F_SetStyleString' => [qw/opaque string/] => 'void');};
eval{$ffi->attach('OGR_F_SetStyleStringDirectly' => [qw/opaque string/] => 'void');};
eval{$ffi->attach('OGR_F_GetStyleTable' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_F_SetStyleTableDirectly' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('OGR_F_SetStyleTable' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('OGR_F_GetNativeData' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_F_SetNativeData' => [qw/opaque string/] => 'void');};
eval{$ffi->attach('OGR_F_GetNativeMediaType' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_F_SetNativeMediaType' => [qw/opaque string/] => 'void');};
eval{$ffi->attach('OGR_F_FillUnsetWithDefault' => [qw/opaque int string_pointer/] => 'void');};
eval{$ffi->attach('OGR_F_Validate' => [qw/opaque int int/] => 'int');};
eval{$ffi->attach('OGR_L_GetName' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_L_GetGeomType' => [qw/opaque/] => 'unsigned int');};
eval{$ffi->attach('OGR_L_GetSpatialFilter' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_L_SetSpatialFilter' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('OGR_L_SetSpatialFilterRect' => [qw/opaque double double double double/] => 'void');};
eval{$ffi->attach('OGR_L_SetSpatialFilterEx' => [qw/opaque int opaque/] => 'void');};
eval{$ffi->attach('OGR_L_SetSpatialFilterRectEx' => [qw/opaque int double double double double/] => 'void');};
eval{$ffi->attach('OGR_L_SetAttributeFilter' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OGR_L_ResetReading' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_L_GetNextFeature' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_L_SetNextByIndex' => [qw/opaque sint64/] => 'int');};
eval{$ffi->attach('OGR_L_GetFeature' => [qw/opaque sint64/] => 'opaque');};
eval{$ffi->attach('OGR_L_SetFeature' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_L_CreateFeature' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_L_DeleteFeature' => [qw/opaque sint64/] => 'int');};
eval{$ffi->attach('OGR_L_GetLayerDefn' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_L_GetSpatialRef' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_L_FindFieldIndex' => [qw/opaque string int/] => 'int');};
eval{$ffi->attach('OGR_L_GetFeatureCount' => [qw/opaque int/] => 'sint64');};
eval{$ffi->attach('OGR_L_GetExtent' => [qw/opaque double[4] int/] => 'int');};
eval{$ffi->attach('OGR_L_GetExtentEx' => [qw/opaque int double[4] int/] => 'int');};
eval{$ffi->attach('OGR_L_TestCapability' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OGR_L_CreateField' => [qw/opaque opaque int/] => 'int');};
eval{$ffi->attach('OGR_L_CreateGeomField' => [qw/opaque opaque int/] => 'int');};
eval{$ffi->attach('OGR_L_DeleteField' => [qw/opaque int/] => 'int');};
eval{$ffi->attach('OGR_L_ReorderFields' => [qw/opaque int*/] => 'int');};
eval{$ffi->attach('OGR_L_ReorderField' => [qw/opaque int int/] => 'int');};
eval{$ffi->attach('OGR_L_AlterFieldDefn' => [qw/opaque int opaque int/] => 'int');};
eval{$ffi->attach('OGR_L_StartTransaction' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_L_CommitTransaction' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_L_RollbackTransaction' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_L_Reference' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_L_Dereference' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_L_GetRefCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_L_SyncToDisk' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_L_GetFeaturesRead' => [qw/opaque/] => 'sint64');};
eval{$ffi->attach('OGR_L_GetFIDColumn' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_L_GetGeometryColumn' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_L_GetStyleTable' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_L_SetStyleTableDirectly' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('OGR_L_SetStyleTable' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('OGR_L_SetIgnoredFields' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OGR_L_Intersection' => [qw/opaque opaque opaque string_pointer GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('OGR_L_Union' => [qw/opaque opaque opaque string_pointer GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('OGR_L_SymDifference' => [qw/opaque opaque opaque string_pointer GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('OGR_L_Identity' => [qw/opaque opaque opaque string_pointer GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('OGR_L_Update' => [qw/opaque opaque opaque string_pointer GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('OGR_L_Clip' => [qw/opaque opaque opaque string_pointer GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('OGR_L_Erase' => [qw/opaque opaque opaque string_pointer GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('OGR_DS_Destroy' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_DS_GetName' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_DS_GetLayerCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_DS_GetLayer' => [qw/opaque int/] => 'opaque');};
eval{$ffi->attach('OGR_DS_GetLayerByName' => [qw/opaque string/] => 'opaque');};
eval{$ffi->attach('OGR_DS_DeleteLayer' => [qw/opaque int/] => 'int');};
eval{$ffi->attach('OGR_DS_GetDriver' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_DS_CreateLayer' => ['opaque','string','opaque','unsigned int','opaque'] => 'opaque');};
eval{$ffi->attach('OGR_DS_CopyLayer' => [qw/opaque opaque string opaque/] => 'opaque');};
eval{$ffi->attach('OGR_DS_TestCapability' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OGR_DS_ExecuteSQL' => [qw/opaque string opaque string/] => 'opaque');};
eval{$ffi->attach('OGR_DS_ReleaseResultSet' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('OGR_DS_Reference' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_DS_Dereference' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_DS_GetRefCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_DS_GetSummaryRefCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_DS_SyncToDisk' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_DS_GetStyleTable' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_DS_SetStyleTableDirectly' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('OGR_DS_SetStyleTable' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('OGR_Dr_GetName' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_Dr_Open' => [qw/opaque string int/] => 'opaque');};
eval{$ffi->attach('OGR_Dr_TestCapability' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OGR_Dr_CreateDataSource' => [qw/opaque string string_pointer/] => 'opaque');};
eval{$ffi->attach('OGR_Dr_CopyDataSource' => [qw/opaque opaque string string_pointer/] => 'opaque');};
eval{$ffi->attach('OGR_Dr_DeleteDataSource' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OGROpen' => [qw/string int uint64*/] => 'opaque');};
eval{$ffi->attach('OGROpenShared' => [qw/string int uint64*/] => 'opaque');};
eval{$ffi->attach('OGRReleaseDataSource' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGRRegisterDriver' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGRDeregisterDriver' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGRGetDriverCount' => [] => 'int');};
eval{$ffi->attach('OGRGetDriver' => [qw/int/] => 'opaque');};
eval{$ffi->attach('OGRGetDriverByName' => [qw/string/] => 'opaque');};
eval{$ffi->attach('OGRGetOpenDSCount' => [] => 'int');};
eval{$ffi->attach('OGRGetOpenDS' => [qw/int/] => 'opaque');};
eval{$ffi->attach('OGRRegisterAll' => [] => 'void');};
eval{$ffi->attach('OGRCleanupAll' => [] => 'void');};
eval{$ffi->attach('OGR_SM_Create' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_SM_Destroy' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_SM_InitFromFeature' => [qw/opaque opaque/] => 'string');};
eval{$ffi->attach('OGR_SM_InitStyleString' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OGR_SM_GetPartCount' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OGR_SM_GetPart' => [qw/opaque int string/] => 'opaque');};
eval{$ffi->attach('OGR_SM_AddPart' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_SM_AddStyle' => [qw/opaque string string/] => 'int');};
eval{$ffi->attach('OGR_ST_Create' => ['unsigned int'] => 'opaque');};
eval{$ffi->attach('OGR_ST_Destroy' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_ST_GetType' => [qw/opaque/] => 'unsigned int');};
eval{$ffi->attach('OGR_ST_GetUnit' => [qw/opaque/] => 'unsigned int');};
eval{$ffi->attach('OGR_ST_SetUnit' => ['opaque','unsigned int','double'] => 'void');};
eval{$ffi->attach('OGR_ST_GetParamStr' => [qw/opaque int int*/] => 'string');};
eval{$ffi->attach('OGR_ST_GetParamNum' => [qw/opaque int int*/] => 'int');};
eval{$ffi->attach('OGR_ST_GetParamDbl' => [qw/opaque int int*/] => 'double');};
eval{$ffi->attach('OGR_ST_SetParamStr' => [qw/opaque int string/] => 'void');};
eval{$ffi->attach('OGR_ST_SetParamNum' => [qw/opaque int int/] => 'void');};
eval{$ffi->attach('OGR_ST_SetParamDbl' => [qw/opaque int double/] => 'void');};
eval{$ffi->attach('OGR_ST_GetStyleString' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_ST_GetRGBFromString' => [qw/opaque string int* int* int* int*/] => 'int');};
eval{$ffi->attach('OGR_STBL_Create' => [] => 'opaque');};
eval{$ffi->attach('OGR_STBL_Destroy' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_STBL_AddStyle' => [qw/opaque string string/] => 'int');};
eval{$ffi->attach('OGR_STBL_SaveStyleTable' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OGR_STBL_LoadStyleTable' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OGR_STBL_Find' => [qw/opaque string/] => 'string');};
eval{$ffi->attach('OGR_STBL_ResetStyleStringReading' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_STBL_GetNextStyle' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_STBL_GetLastStyleName' => [qw/opaque/] => 'string');};
# from /home/ajolma/github/gdal/gdal/ogr/ogr_srs_api.h
eval{$ffi->attach('OSRAxisEnumToName' => ['unsigned int'] => 'string');};
eval{$ffi->attach('OSRNewSpatialReference' => [qw/string/] => 'opaque');};
eval{$ffi->attach('OSRCloneGeogCS' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OSRClone' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OSRDestroySpatialReference' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OSRReference' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRDereference' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRRelease' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OSRValidate' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRFixupOrdering' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRFixup' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRStripCTParms' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRImportFromEPSG' => [qw/opaque int/] => 'int');};
eval{$ffi->attach('OSRImportFromEPSGA' => [qw/opaque int/] => 'int');};
eval{$ffi->attach('OSRImportFromWkt' => [qw/opaque string_pointer/] => 'int');};
eval{$ffi->attach('OSRImportFromProj4' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OSRImportFromESRI' => [qw/opaque string_pointer/] => 'int');};
eval{$ffi->attach('OSRImportFromPCI' => [qw/opaque string string double*/] => 'int');};
eval{$ffi->attach('OSRImportFromUSGS' => [qw/opaque long long double* long/] => 'int');};
eval{$ffi->attach('OSRImportFromXML' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OSRImportFromDict' => [qw/opaque string string/] => 'int');};
eval{$ffi->attach('OSRImportFromPanorama' => [qw/opaque long long long double*/] => 'int');};
eval{$ffi->attach('OSRImportFromOzi' => [qw/opaque string_pointer/] => 'int');};
eval{$ffi->attach('OSRImportFromMICoordSys' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OSRImportFromERM' => [qw/opaque string string string/] => 'int');};
eval{$ffi->attach('OSRImportFromUrl' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OSRExportToWkt' => [qw/opaque string_pointer/] => 'int');};
eval{$ffi->attach('OSRExportToPrettyWkt' => [qw/opaque string_pointer int/] => 'int');};
eval{$ffi->attach('OSRExportToProj4' => [qw/opaque string_pointer/] => 'int');};
eval{$ffi->attach('OSRExportToPCI' => [qw/opaque string_pointer string_pointer double*/] => 'int');};
eval{$ffi->attach('OSRExportToUSGS' => [qw/opaque long* long* double* long*/] => 'int');};
eval{$ffi->attach('OSRExportToXML' => [qw/opaque string_pointer string/] => 'int');};
eval{$ffi->attach('OSRExportToPanorama' => [qw/opaque long* long* long* long* double*/] => 'int');};
eval{$ffi->attach('OSRExportToMICoordSys' => [qw/opaque string_pointer/] => 'int');};
eval{$ffi->attach('OSRExportToERM' => [qw/opaque string string string/] => 'int');};
eval{$ffi->attach('OSRMorphToESRI' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRMorphFromESRI' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRConvertToOtherProjection' => [qw/opaque string string_pointer/] => 'opaque');};
eval{$ffi->attach('OSRSetAttrValue' => [qw/opaque string string/] => 'int');};
eval{$ffi->attach('OSRGetAttrValue' => [qw/opaque string int/] => 'string');};
eval{$ffi->attach('OSRSetAngularUnits' => [qw/opaque string double/] => 'int');};
eval{$ffi->attach('OSRGetAngularUnits' => [qw/opaque string_pointer/] => 'double');};
eval{$ffi->attach('OSRSetLinearUnits' => [qw/opaque string double/] => 'int');};
eval{$ffi->attach('OSRSetTargetLinearUnits' => [qw/opaque string string double/] => 'int');};
eval{$ffi->attach('OSRSetLinearUnitsAndUpdateParameters' => [qw/opaque string double/] => 'int');};
eval{$ffi->attach('OSRGetLinearUnits' => [qw/opaque string_pointer/] => 'double');};
eval{$ffi->attach('OSRGetTargetLinearUnits' => [qw/opaque string string_pointer/] => 'double');};
eval{$ffi->attach('OSRGetPrimeMeridian' => [qw/opaque string_pointer/] => 'double');};
eval{$ffi->attach('OSRIsGeographic' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRIsLocal' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRIsProjected' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRIsCompound' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRIsGeocentric' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRIsVertical' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRIsSameGeogCS' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OSRIsSameVertCS' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OSRIsSame' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OSRSetLocalCS' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OSRSetProjCS' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OSRSetGeocCS' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OSRSetWellKnownGeogCS' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OSRSetFromUserInput' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OSRCopyGeogCSFrom' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OSRSetTOWGS84' => [qw/opaque double double double double double double double/] => 'int');};
eval{$ffi->attach('OSRGetTOWGS84' => [qw/opaque double* int/] => 'int');};
eval{$ffi->attach('OSRSetCompoundCS' => [qw/opaque string opaque opaque/] => 'int');};
eval{$ffi->attach('OSRSetGeogCS' => [qw/opaque string string string double double string double string double/] => 'int');};
eval{$ffi->attach('OSRSetVertCS' => [qw/opaque string string int/] => 'int');};
eval{$ffi->attach('OSRGetSemiMajor' => [qw/opaque int*/] => 'double');};
eval{$ffi->attach('OSRGetSemiMinor' => [qw/opaque int*/] => 'double');};
eval{$ffi->attach('OSRGetInvFlattening' => [qw/opaque int*/] => 'double');};
eval{$ffi->attach('OSRSetAuthority' => [qw/opaque string string int/] => 'int');};
eval{$ffi->attach('OSRGetAuthorityCode' => [qw/opaque string/] => 'string');};
eval{$ffi->attach('OSRGetAuthorityName' => [qw/opaque string/] => 'string');};
eval{$ffi->attach('OSRSetProjection' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OSRSetProjParm' => [qw/opaque string double/] => 'int');};
eval{$ffi->attach('OSRGetProjParm' => [qw/opaque string double int*/] => 'double');};
eval{$ffi->attach('OSRSetNormProjParm' => [qw/opaque string double/] => 'int');};
eval{$ffi->attach('OSRGetNormProjParm' => [qw/opaque string double int*/] => 'double');};
eval{$ffi->attach('OSRSetUTM' => [qw/opaque int int/] => 'int');};
eval{$ffi->attach('OSRGetUTMZone' => [qw/opaque int*/] => 'int');};
eval{$ffi->attach('OSRSetStatePlane' => [qw/opaque int int/] => 'int');};
eval{$ffi->attach('OSRSetStatePlaneWithUnits' => [qw/opaque int int string double/] => 'int');};
eval{$ffi->attach('OSRAutoIdentifyEPSG' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRFindMatches' => [qw/opaque string_pointer int* int*/] => 'uint64*');};
eval{$ffi->attach('OSRFreeSRSArray' => [qw/uint64*/] => 'void');};
eval{$ffi->attach('OSREPSGTreatsAsLatLong' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSREPSGTreatsAsNorthingEasting' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRGetAxis' => ['opaque','string','int','unsigned int'] => 'string');};
eval{$ffi->attach('OSRSetAxes' => ['opaque','string','string','unsigned int','string','unsigned int'] => 'int');};
eval{$ffi->attach('OSRSetACEA' => [qw/opaque double double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetAE' => [qw/opaque double double double double/] => 'int');};
eval{$ffi->attach('OSRSetBonne' => [qw/opaque double double double double/] => 'int');};
eval{$ffi->attach('OSRSetCEA' => [qw/opaque double double double double/] => 'int');};
eval{$ffi->attach('OSRSetCS' => [qw/opaque double double double double/] => 'int');};
eval{$ffi->attach('OSRSetEC' => [qw/opaque double double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetEckert' => [qw/opaque int double double double/] => 'int');};
eval{$ffi->attach('OSRSetEckertIV' => [qw/opaque double double double/] => 'int');};
eval{$ffi->attach('OSRSetEckertVI' => [qw/opaque double double double/] => 'int');};
eval{$ffi->attach('OSRSetEquirectangular' => [qw/opaque double double double double/] => 'int');};
eval{$ffi->attach('OSRSetEquirectangular2' => [qw/opaque double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetGS' => [qw/opaque double double double/] => 'int');};
eval{$ffi->attach('OSRSetGH' => [qw/opaque double double double/] => 'int');};
eval{$ffi->attach('OSRSetIGH' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRSetGEOS' => [qw/opaque double double double double/] => 'int');};
eval{$ffi->attach('OSRSetGaussSchreiberTMercator' => [qw/opaque double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetGnomonic' => [qw/opaque double double double double/] => 'int');};
eval{$ffi->attach('OSRSetHOM' => [qw/opaque double double double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetHOMAC' => [qw/opaque double double double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetHOM2PNO' => [qw/opaque double double double double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetIWMPolyconic' => [qw/opaque double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetKrovak' => [qw/opaque double double double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetLAEA' => [qw/opaque double double double double/] => 'int');};
eval{$ffi->attach('OSRSetLCC' => [qw/opaque double double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetLCC1SP' => [qw/opaque double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetLCCB' => [qw/opaque double double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetMC' => [qw/opaque double double double double/] => 'int');};
eval{$ffi->attach('OSRSetMercator' => [qw/opaque double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetMercator2SP' => [qw/opaque double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetMollweide' => [qw/opaque double double double/] => 'int');};
eval{$ffi->attach('OSRSetNZMG' => [qw/opaque double double double double/] => 'int');};
eval{$ffi->attach('OSRSetOS' => [qw/opaque double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetOrthographic' => [qw/opaque double double double double/] => 'int');};
eval{$ffi->attach('OSRSetPolyconic' => [qw/opaque double double double double/] => 'int');};
eval{$ffi->attach('OSRSetPS' => [qw/opaque double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetRobinson' => [qw/opaque double double double/] => 'int');};
eval{$ffi->attach('OSRSetSinusoidal' => [qw/opaque double double double/] => 'int');};
eval{$ffi->attach('OSRSetStereographic' => [qw/opaque double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetSOC' => [qw/opaque double double double double/] => 'int');};
eval{$ffi->attach('OSRSetTM' => [qw/opaque double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetTMVariant' => [qw/opaque string double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetTMG' => [qw/opaque double double double double/] => 'int');};
eval{$ffi->attach('OSRSetTMSO' => [qw/opaque double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetTPED' => [qw/opaque double double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetVDG' => [qw/opaque double double double/] => 'int');};
eval{$ffi->attach('OSRSetWagner' => [qw/opaque int double double double/] => 'int');};
eval{$ffi->attach('OSRSetQSC' => [qw/opaque double double/] => 'int');};
eval{$ffi->attach('OSRSetSCH' => [qw/opaque double double double double/] => 'int');};
eval{$ffi->attach('OSRCalcInvFlattening' => [qw/double double/] => 'double');};
eval{$ffi->attach('OSRCalcSemiMinorFromInvFlattening' => [qw/double double/] => 'double');};
eval{$ffi->attach('OSRCleanup' => [] => 'void');};
eval{$ffi->attach('OCTNewCoordinateTransformation' => [qw/opaque opaque/] => 'opaque');};
eval{$ffi->attach('OCTDestroyCoordinateTransformation' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OCTTransform' => [qw/opaque int double* double* double*/] => 'int');};
eval{$ffi->attach('OCTTransformEx' => [qw/opaque int double* double* double* int*/] => 'int');};
eval{$ffi->attach('OCTProj4Normalize' => [qw/string/] => 'string');};
eval{$ffi->attach('OCTCleanupProjMutex' => [] => 'void');};
eval{$ffi->attach('OPTGetProjectionMethods' => [] => 'string_pointer');};
eval{$ffi->attach('OPTGetParameterList' => [qw/string string_pointer/] => 'string_pointer');};
eval{$ffi->attach('OPTGetParameterInfo' => [qw/string string string_pointer string_pointer double*/] => 'int');};
# from /home/ajolma/github/gdal/gdal/apps/gdal_utils.h
eval{$ffi->attach('GDALInfoOptionsNew' => [qw/opaque opaque/] => 'opaque');};
eval{$ffi->attach('GDALInfoOptionsFree' => [qw/opaque/] => 'void');};
eval{$ffi->attach('GDALInfo' => [qw/opaque opaque/] => 'string');};
eval{$ffi->attach('GDALTranslateOptionsNew' => [qw/opaque opaque/] => 'opaque');};
eval{$ffi->attach('GDALTranslateOptionsFree' => [qw/opaque/] => 'void');};
eval{$ffi->attach('GDALTranslateOptionsSetProgress' => [qw/opaque GDALProgressFunc opaque/] => 'void');};
eval{$ffi->attach('GDALTranslate' => [qw/string opaque opaque int*/] => 'opaque');};
eval{$ffi->attach('GDALWarpAppOptionsNew' => [qw/opaque opaque/] => 'opaque');};
eval{$ffi->attach('GDALWarpAppOptionsFree' => [qw/opaque/] => 'void');};
eval{$ffi->attach('GDALWarpAppOptionsSetProgress' => [qw/opaque GDALProgressFunc opaque/] => 'void');};
eval{$ffi->attach('GDALWarpAppOptionsSetWarpOption' => [qw/opaque string string/] => 'void');};
eval{$ffi->attach('GDALWarp' => [qw/string opaque int uint64* opaque int*/] => 'opaque');};
eval{$ffi->attach('GDALVectorTranslateOptionsNew' => [qw/opaque opaque/] => 'opaque');};
eval{$ffi->attach('GDALVectorTranslateOptionsFree' => [qw/opaque/] => 'void');};
eval{$ffi->attach('GDALVectorTranslateOptionsSetProgress' => [qw/opaque GDALProgressFunc opaque/] => 'void');};
eval{$ffi->attach('GDALVectorTranslate' => [qw/string opaque int uint64* opaque int*/] => 'opaque');};
eval{$ffi->attach('GDALDEMProcessingOptionsNew' => [qw/opaque opaque/] => 'opaque');};
eval{$ffi->attach('GDALDEMProcessingOptionsFree' => [qw/opaque/] => 'void');};
eval{$ffi->attach('GDALDEMProcessingOptionsSetProgress' => [qw/opaque GDALProgressFunc opaque/] => 'void');};
eval{$ffi->attach('GDALDEMProcessing' => [qw/string opaque string string opaque int*/] => 'opaque');};
eval{$ffi->attach('GDALNearblackOptionsNew' => [qw/opaque opaque/] => 'opaque');};
eval{$ffi->attach('GDALNearblackOptionsFree' => [qw/opaque/] => 'void');};
eval{$ffi->attach('GDALNearblackOptionsSetProgress' => [qw/opaque GDALProgressFunc opaque/] => 'void');};
eval{$ffi->attach('GDALNearblack' => [qw/string opaque opaque opaque int*/] => 'opaque');};
eval{$ffi->attach('GDALGridOptionsNew' => [qw/opaque opaque/] => 'opaque');};
eval{$ffi->attach('GDALGridOptionsFree' => [qw/opaque/] => 'void');};
eval{$ffi->attach('GDALGridOptionsSetProgress' => [qw/opaque GDALProgressFunc opaque/] => 'void');};
eval{$ffi->attach('GDALGrid' => [qw/string opaque opaque int*/] => 'opaque');};
eval{$ffi->attach('GDALRasterizeOptionsNew' => [qw/opaque opaque/] => 'opaque');};
eval{$ffi->attach('GDALRasterizeOptionsFree' => [qw/opaque/] => 'void');};
eval{$ffi->attach('GDALRasterizeOptionsSetProgress' => [qw/opaque GDALProgressFunc opaque/] => 'void');};
eval{$ffi->attach('GDALRasterize' => [qw/string opaque opaque opaque int*/] => 'opaque');};
eval{$ffi->attach('GDALBuildVRTOptionsNew' => [qw/opaque opaque/] => 'opaque');};
eval{$ffi->attach('GDALBuildVRTOptionsFree' => [qw/opaque/] => 'void');};
eval{$ffi->attach('GDALBuildVRTOptionsSetProgress' => [qw/opaque GDALProgressFunc opaque/] => 'void');};
eval{$ffi->attach('GDALBuildVRT' => [qw/string int uint64* opaque opaque int*/] => 'opaque');};


    my $self = {};
    $self->{ffi} = $ffi;
    $self->{CPLErrorHandler} = $ffi->closure(
        sub {
            my ($err, $err_num, $msg) = @_;
            push @errors, $msg;
        });
    CPLPushErrorHandler($self->{CPLErrorHandler});
    GDALAllRegister();
    return bless $self, $class;
}

sub VersionInfo {
    shift;
    return GDALVersionInfo(@_);
}

sub GetDriverCount {
    return GDALGetDriverCount();
}

sub GetDriver {
    my ($self, $i) = @_;
    my $d = GDALGetDriver($i);
    return bless \$d, 'Geo::GDAL::FFI::Driver';
}

sub Drivers {
    my $self = shift;
    my @retval;
    for my $i (0..$self->GetDriverCount-1) {
        push @retval, $self->GetDriver($i);
    }
    return wantarray ? @retval : \@retval;
}

sub GetDriverByName {
    #my $this_subs_name = (caller(0))[3];
    #say STDERR "called $this_subs_name";
    shift;
    my $d = GDALGetDriverByName(@_);
    return bless \$d, 'Geo::GDAL::FFI::Driver';
}
*Driver = *GetDriverByName;

sub Open {
    shift;
    my ($name, $access) = @_;
    $access //= 'ReadOnly';
    my $tmp = $access{$access};
    confess "Unknown constant: $access\n" unless defined $tmp;
    $access = $tmp;
    my $ds = GDALOpen($name, $access);
    if (@errors) {
        my $msg = join("\n", @errors);
        @errors = ();
        confess $msg;
    }
    return bless \$ds, 'Geo::GDAL::FFI::Dataset';
}

sub OpenEx {
    shift;
    my ($name, $args) = @_;
    $args //= {};
    my $flags_array = $args->{open_flags} // [];
    my $drivers = $args->{allowed_drivers} // 0;
    my $options = $args->{open_options} // 0;
    my $files = $args->{sibling_files} // 0;
    my $flags = 0;
    for my $f (@$flags_array) {
        $flags |= $open_flags{$f};
    }
    my $ds = GDALOpenEx($name, $flags, $drivers, $options, $files);
    if (@errors) {
        my $msg = join("\n", @errors);
        @errors = ();
        confess $msg;
    }
    unless ($ds) { # no VERBOSE_ERROR in options and fail
        confess "OpenEx failed for '$name'. Hint: add VERBOSE_ERROR to open_flags.";
    }
    return bless \$ds, 'Geo::GDAL::FFI::Dataset';
}

sub write {
    print STDOUT $_[0];
}

sub close {
}

sub SetVSIStdout {
    my ($self, $writer) = @_;
    $writer = $self unless $writer;
    my $w = $writer->can('write');
    my $c = $writer->can('close');
    confess "$writer must be able to write and close." unless $w && $c;
    #$self->{write} = $w;
    $self->{close} = $c;
    $self->{writer} = $self->{ffi}->closure(sub {
        my ($buf, $size, $count, $stream) = @_;
        $w->(buffer_to_scalar($buf, $size*$count));
    });
    VSIStdoutSetRedirection($self->{writer}, 0);
}

sub UnsetVSIStdout {
    my $self = shift;
    $self->{close}->() if $self->{close};
    $self->SetVSIStdout;
}

sub Importer {
    my ($self, $format) = @_;
    my $importer = $self->can('OSRImportFrom' . $format);
    confess "Spatial reference importer for format '$format' not found!" unless $importer;
    return $importer;
}

sub Exporter {
    my ($self, $format) = @_;
    my $exporter = $self->can('OSRExportTo' . $format);
    confess "Spatial reference exporter for format '$format' not found!" unless $exporter;
    return $exporter;
}

sub Setter {
    my ($self, $proj) = @_;
    my $setter = $self->can('OSRSet' . $proj);
    confess "Parameter setter for projection '$proj' not found!" unless $setter;
    return $setter;
}

package Geo::GDAL::FFI::Object;
use v5.10;
use strict;
use warnings;
use Carp;

sub HasCapability {
    my ($self, $cap) = @_;
    my $tmp = $capabilities{$cap};
    confess "Unknown constant: $cap\n" unless defined $tmp;
    my $md = $self->GetMetadata('');
    return $md->{'DCAP_'.$cap};
}

sub GetMetadataDomainList {
    my ($self) = @_;
    #my $this_subs_name = (caller(0))[3];
    #say STDERR "called $this_subs_name";
    my $csl = Geo::GDAL::FFI::GDALGetMetadataDomainList($$self);
    my @list;
    for my $i (0..Geo::GDAL::FFI::CSLCount($csl)-1) {
        push @list, Geo::GDAL::FFI::CSLGetField($csl, $i);
    }
    Geo::GDAL::FFI::CSLDestroy($csl);
    return wantarray ? @list : \@list;
}

sub GetMetadata {
    my ($self, $domain) = @_;
    my %md;
    unless (defined $domain) {
        for $domain ($self->GetMetadataDomainList) {
            $md{$domain} = $self->GetMetadata($domain);
        }
        return wantarray ? %md : \%md;
    }
    my $csl = Geo::GDAL::FFI::GDALGetMetadata($$self, $domain);
    for my $i (0..Geo::GDAL::FFI::CSLCount($csl)-1) {
        my ($name, $value) = split /=/, Geo::GDAL::FFI::CSLGetField($csl, $i);
        $md{$name} = $value;
    }
    return wantarray ? %md : \%md;
}

sub SetMetadata {
    my ($self, $metadata, $domain) = @_;
    my $csl = 0;
    for my $name (keys %$metadata) {
        $csl = Geo::GDAL::FFI::CSLAddString($csl, "$name=$metadata->{$name}");
    }
    $domain //= "";
    my $err = Geo::GDAL::FFI::GDALSetMetadata($$self, $csl, $domain);
    confess "" if $err == Geo::GDAL::FFI::Failure;
    warn "" if $err == Geo::GDAL::FFI::Warning;
}

sub GetMetadataItem {
    my ($self, $name, $domain) = @_;
    return Geo::GDAL::FFI::GDALGetMetadataItem($$self, $name, $domain);
}

sub SetMetadataItem {
    my ($self, $name, $value, $domain) = @_;
    Geo::GDAL::FFI::GDALSetMetadataItem($$self, $name, $value, $domain);
    if (@errors) {
        my $msg = join("\n", @errors);
        @errors = ();
        confess $msg;
    }
}

package Geo::GDAL::FFI::Driver;
use v5.10;
use strict;
use warnings;
use Carp;
use base 'Geo::GDAL::FFI::Object';

sub GetDescription {
    my $self = shift;
    return Geo::GDAL::FFI::GDALGetDescription($$self);
}
*Name = *GetDescription;

sub CreateDataset {
    my $self = shift;
    my %args = @_ == 1 ? %{$_[0]} : @_;
    my $n = $args{Name} // '';
    my $o = 0;
    for my $key (keys %{$args{Options}}) {
        $o = Geo::GDAL::FFI::CSLAddString($o, "$key=$args{Options}{$key}");
    }
    my $ds;
    if (exists $args{Source}) {
        my $src = ${$args{Source}};
        my $s = $args{Strict} // 0;
        my $p = $args{Progress};
        $ds = Geo::GDAL::FFI::GDALCreateCopy($$self, $n, $$src, $s, $o, $p, $args{ProgressData});
    } elsif (not exists $args{Width}) {
        $ds = Geo::GDAL::FFI::GDALCreate($$self, $n, 0, 0, 0, 0, $o);
    } else {
        my $dt = $args{DataType} // 'Byte';
        my $tmp = $datatypes{$dt};
        confess "Unknown constant: $dt\n" unless defined $tmp;
        $dt = $tmp;
        my $w = $args{Width} // 256;
        my $h = $args{Height} // 256;
        my $b = $args{Bands} // 1;
        $ds = Geo::GDAL::FFI::GDALCreate($$self, $n, $w, $h, $b, $dt, $o);
    }
    if (!$ds || @errors) {
        my $msg;
        if (@errors) {
            $msg = join("\n", @errors);
            @errors = ();
        }
        $msg //= 'CreateDataset failed. (Driver = '.$self->GetDescription.')';
        confess $msg;
    }
    return bless \$ds, 'Geo::GDAL::FFI::Dataset';
}

sub Create {
    #my $this_subs_name = (caller(0))[3];
    #say STDERR "called $this_subs_name";
    my ($self, $name, $width, $height, $bands, $dt, $options) = @_;
    $name //= '';
    $width //= 256;
    $height //= 256;
    $bands //= 1;
    $dt //= 'Byte';
    my $tmp = $datatypes{$dt};
    confess "Unknown constant: $dt\n" unless defined $tmp;
    $dt = $tmp;
    my $o = 0;
    for my $key (keys %$options) {
        $o = Geo::GDAL::FFI::CSLAddString($o, "$key=$options->{$key}");
    }
    my $ds = Geo::GDAL::FFI::GDALCreate($$self, $name, $width, $height, $bands, $dt, $o);
    if (!$ds || @errors) {
        my $msg;
        if (@errors) {
            $msg = join("\n", @errors);
            @errors = ();
        }
        $msg //= 'Create failed. (Driver = '.$self->GetDescription.')';
        confess $msg;
    }
    return bless \$ds, 'Geo::GDAL::FFI::Dataset';
}

sub CreateCopy {
    my ($self, $name, $ds, $strict, $options, $progress, $progress_data) = @_;
    my $o = 0;
    for my $key (keys %$options) {
        $o = Geo::GDAL::FFI::CSLAddString($o, "$key=$options->{$key}");
    }
    my $copy = Geo::GDAL::FFI::GDALCreateCopy($$self, $name, $$ds, $strict, $o, $progress, $progress_data);
    if (!$copy || @errors) {
        my $msg;
        if (@errors) {
            $msg = join("\n", @errors);
            @errors = ();
        }
        $msg //= 'CreateCopy failed. (Driver = '.$self->GetDescription.')';
        confess $msg;
    }
    return bless \$copy, 'Geo::GDAL::FFI::Dataset';
}

package Geo::GDAL::FFI::SpatialReference;
use v5.10;
use strict;
use warnings;
use Carp;

sub new {
    my ($class, $arg, @arg) = @_;
    my $sr;
    if (not defined $arg) {
        $sr = Geo::GDAL::FFI::OSRNewSpatialReference();
    } elsif (not ref $arg) {
        $sr = Geo::GDAL::FFI::OSRNewSpatialReference($arg);
    } else {
        $sr = Geo::GDAL::FFI::OSRNewSpatialReference();
        if ($arg->($sr, @arg) != 0) {
            Geo::GDAL::FFI::OSRDestroySpatialReference($sr);
            $sr = 0;
        }
    }
    return bless \$sr, $class if $sr;
    my $msg = join("\n", @errors);
    @errors = ();
    confess $msg;
}

sub DESTROY {
    my $self = shift;
    Geo::GDAL::FFI::OSRDestroySpatialReference($$self);
}

sub Export {
    my $self = shift;
    my $exporter = shift;
    my $x;
    if ($exporter->($$self, \$x, @_) != 0) {
        my $msg = join("\n", @errors);
        @errors = ();
        confess $msg;
    }
    return $x;
}

sub Set {
    my $self = shift;
    my $setter = shift;
    if ($setter->($$self, @_) != 0) {
        my $msg = join("\n", @errors);
        @errors = ();
        confess $msg;
    }
}

sub Clone {
    my $self = shift;
    my $s = Geo::GDAL::FFI::OSRClone($$self);
    return bless \$s, 'Geo::GDAL::FFI::SpatialReference';
}


package Geo::GDAL::FFI::Dataset;
use v5.10;
use strict;
use warnings;
use Carp;
use base 'Geo::GDAL::FFI::Object';

sub DESTROY {
    my $self = shift;
    $self->FlushCache;
    #say STDERR "DESTROY $self and $$self";
    Geo::GDAL::FFI::GDALClose($$self);
}

sub FlushCache {
    my $self = shift;
    Geo::GDAL::FFI::GDALFlushCache($$self);
}

sub Driver {
    my $self = shift;
    my $dr = Geo::GDAL::FFI::GDALGetDatasetDriver($$self);
    return bless \$dr, 'Geo::GDAL::FFI::Driver';
}

sub Info {
    my $self = shift;
    my $o = 0;
    for my $s (@_) {
        $o = Geo::GDAL::FFI::CSLAddString($o, $s);
    }
    my $io = Geo::GDAL::FFI::GDALInfoOptionsNew($o, 0);
    Geo::GDAL::FFI::CSLDestroy($o);
    my $info = Geo::GDAL::FFI::GDALInfo($$self, $io);
    Geo::GDAL::FFI::GDALInfoOptionsFree($io);
    return $info;
}

sub Translate {
    my $self = shift;
    my $path = shift;
    my $o = 0;
    for my $s (@_) {
        $o = Geo::GDAL::FFI::CSLAddString($o, $s);
    }
    my $io = Geo::GDAL::FFI::GDALTranslateOptionsNew($o, 0);
    Geo::GDAL::FFI::CSLDestroy($o);
    my $e = 0;
    my $ds = Geo::GDAL::FFI::GDALTranslate($path, $$self, $io, \$e);
    Geo::GDAL::FFI::GDALTranslateOptionsFree($io);
    return bless \$ds, 'Geo::GDAL::FFI::Dataset' if $ds && ($e == 0);
    my $msg;
    if (@errors) {
        $msg = join("\n", @errors);
        @errors = ();
    }
    $msg //= 'Translate failed.';
    confess $msg;
}

sub Width {
    my $self = shift;
    return Geo::GDAL::FFI::GDALGetRasterXSize($$self);
}

sub Height {
    my $self = shift;
    return Geo::GDAL::FFI::GDALGetRasterYSize($$self);
}

sub Size {
    my $self = shift;
    return (
        Geo::GDAL::FFI::GDALGetRasterXSize($$self),
        Geo::GDAL::FFI::GDALGetRasterYSize($$self)
        );
}

sub GetProjectionString {
    my ($self) = @_;
    return Geo::GDAL::FFI::GDALGetProjectionRef($$self);
}

sub SetProjectionString {
    my ($self, $proj) = @_;
    my $e = Geo::GDAL::FFI::GDALSetProjection($$self, $proj);
    if ($e != 0) {
        my $msg = join("\n", @errors);
        @errors = ();
        confess $msg;
    }
}

sub GetGeoTransform {
    my ($self) = @_;
    my $t = [0,0,0,0,0,0];
    Geo::GDAL::FFI::GDALGetGeoTransform($$self, $t);
    return wantarray ? @$t : $t;
}

sub SetGeoTransform {
    my $self = shift;
    my $t = @_ > 1 ? [@_] : shift;
    Geo::GDAL::FFI::GDALSetGeoTransform($$self, $t);
}

sub GetBandCount {
    my $self = shift;
    return Geo::GDAL::FFI::GDALGetRasterCount($$self);
}

sub GetBand {
    my ($self, $i) = @_;
    $i //= 1;
    my $b = Geo::GDAL::FFI::GDALGetRasterBand($$self, $i);
    $parent{$b} = $self;
    return bless \$b, 'Geo::GDAL::FFI::Band';
}
*Band = *GetBand;

sub Bands {
    my $self = shift;
    my @bands;
    for my $i (1..Geo::GDAL::FFI::GDALGetRasterCount($$self)) {
        push @bands, $self->Band($i);
    }
    return @bands;
}

sub GetLayer {
    my ($self, $i) = @_;
    $i //= 0;
    my $l = Geo::GDAL::FFI::isint($i) ? Geo::GDAL::FFI::GDALDatasetGetLayer($$self, $i) :
        Geo::GDAL::FFI::GDALDatasetGetLayerByName($$self, $i);
    return bless \$l, 'Geo::GDAL::FFI::Layer';
}

sub CreateLayer {
    my ($self, $args) = @_;
    $args //= {};
    my $name = $args->{Name} // '';
    my ($gt, $sr);
    if (exists $args->{GeometryFields}) {
        $gt = $geometry_types{None};
    } else {
        $gt = $args->{GeometryType} // 'Unknown';
        $gt = $geometry_types{$gt};
        confess "Unknown geometry type: '$args->{GeometryType}'\n" unless defined $gt;
        $sr = Geo::GDAL::FFI::OSRClone(${$args->{SpatialReference}}) if exists $args->{SpatialReference};
    }
    my $o = 0;
    if (exists $args->{Options}) {
        for my $key (keys %{$args->{Options}}) {
            $o = Geo::GDAL::FFI::CSLAddString($o, "$key=$args->{Options}->{$key}");
        }
    }
    my $l = Geo::GDAL::FFI::GDALDatasetCreateLayer($$self, $name, $sr, $gt, $o);
    Geo::GDAL::FFI::OSRRelease($sr) if $sr;
    if (@errors) {
        my $msg = join("\n", @errors);
        @errors = ();
        confess $msg;
    }
    $parent{$l} = $self;
    #say STDERR "parent of $l is $self";
    my $layer = bless \$l, 'Geo::GDAL::FFI::Layer';
    if (exists $args->{Fields}) {
        for my $f (@{$args->{Fields}}) {
            $layer->CreateField($f);
        }
    }
    if (exists $args->{GeometryFields}) {
        for my $f (@{$args->{GeometryFields}}) {
            $layer->CreateGeomField($f);
        }
    }
    return $layer;
}

sub CopyLayer {
    my ($self, $layer, $name, $options) = @_;
    $name //= '';
    my $o = 0;
    for my $key (keys %$options) {
        $o = Geo::GDAL::FFI::CSLAddString($o, "$key=$options->{$key}");
    }
    my $l = Geo::GDAL::FFI::GDALDatasetCopyLayer($$self, $$layer, $name, $o);
    if (@errors) {
        my $msg = join("\n", @errors);
        @errors = ();
        confess $msg;
    }
    $parent{$l} = $self;
    #say STDERR "parent of $l is $self";
    return bless \$l, 'Geo::GDAL::FFI::Layer';
}

package Geo::GDAL::FFI::Band;
use v5.10;
use strict;
use warnings;
use Carp;
use FFI::Platypus::Buffer;

sub DESTROY {
    my $self = shift;
    #say STDERR "delete parent of $$self $parent{$$self}";
    delete $parent{$$self};
}

sub GetDataType {
    my $self = shift;
    return $datatypes_reverse{Geo::GDAL::FFI::GDALGetRasterDataType($$self)};
}
*DataType = *GetDataType;

sub Width {
    my $self = shift;
    Geo::GDAL::FFI::GDALGetRasterBandXSize($$self);
}

sub Height {
    my $self = shift;
    Geo::GDAL::FFI::GDALGetRasterBandYSize($$self);
}

sub Size {
    my $self = shift;
    return (
        Geo::GDAL::FFI::GDALGetRasterBandXSize($$self),
        Geo::GDAL::FFI::GDALGetRasterBandYSize($$self)
        );
}

sub GetNoDataValue {
    my $self = shift;
    my $b = 0;
    my $v = Geo::GDAL::FFI::GDALGetRasterNoDataValue($$self, \$b);
    return unless $b;
    return $v;
}

sub SetNoDataValue {
    my $self = shift;
    unless (@_) {
        Geo::GDAL::FFI::GDALDeleteRasterNoDataValue($$self);
        return;
    }
    my $v = shift;
    my $e = Geo::GDAL::FFI::GDALSetRasterNoDataValue($$self, $v);
    return unless $e;
    confess "SetNoDataValue not supported by the driver." unless @errors;
    my $msg = join("\n", @errors);
    @errors = ();
    confess $msg;
}

sub GetBlockSize {
    my $self = shift;
    my ($w, $h);
    Geo::GDAL::FFI::GDALGetBlockSize($$self, \$w, \$h);
    return ($w, $h);
}
*BlockSize = *GetBlockSize;

sub PackCharacter {
    my $t = shift;
    my $is_big_endian = unpack("h*", pack("s", 1)) =~ /01/; # from Programming Perl
    return ('C', 1) if $t == 1;
    return ($is_big_endian ? ('n', 2) : ('v', 2)) if $t == 2;
    return ('s', 2) if $t == 3;
    return ($is_big_endian ? ('N', 4) : ('V', 4)) if $t == 4;
    return ('l', 4) if $t == 5;
    return ('f', 4) if $t == 6;
    return ('d', 8) if $t == 7;
    # CInt16 => 8,
    # CInt32 => 9,
    # CFloat32 => 10,
    # CFloat64 => 11
}

sub Read {
    my ($self, $xoff, $yoff, $xsize, $ysize, $bufxsize, $bufysize) = @_;
    $xoff //= 0;
    $yoff //= 0;
    my $t = Geo::GDAL::FFI::GDALGetRasterDataType($$self);
    my $buf;
    my ($pc, $bytes_per_cell) = PackCharacter($t);
    my $w;
    $xsize //= Geo::GDAL::FFI::GDALGetRasterBandXSize($$self);
    $ysize //= Geo::GDAL::FFI::GDALGetRasterBandYSize($$self);
    $bufxsize //= $xsize;
    $bufysize //= $ysize;
    $w = $bufxsize * $bytes_per_cell;
    $buf = ' ' x ($bufysize * $w);
    my ($pointer, $size) = scalar_to_buffer $buf;
    Geo::GDAL::FFI::GDALRasterIO($$self, Geo::GDAL::FFI::Read, $xoff, $yoff, $xsize, $ysize, $pointer, $bufxsize, $bufysize, $t, 0, 0);
    my $offset = 0;
    my @data;
    for my $y (0..$bufysize-1) {
        my @d = unpack($pc."[$bufxsize]", substr($buf, $offset, $w));
        push @data, \@d;
        $offset += $w;
    }
    return \@data;
}

sub ReadBlock {
    my ($self, $xoff, $yoff) = @_;
    my ($xsize, $ysize);
    Geo::GDAL::FFI::GDALGetBlockSize($$self, \$xsize, \$ysize);
    my $t = Geo::GDAL::FFI::GDALGetRasterDataType($$self);
    my $buf;
    my ($pc, $bytes_per_cell) = PackCharacter($t);
    my $w = $xsize * $bytes_per_cell;
    $buf = ' ' x ($ysize * $w);
    my ($pointer, $size) = scalar_to_buffer $buf;
    Geo::GDAL::FFI::GDALReadBlock($$self, $xoff, $yoff, $pointer);
    my $offset = 0;
    my @data;
    for my $y (0..$ysize-1) {
        my @d = unpack($pc."[$xsize]", substr($buf, $offset, $w));
        push @data, \@d;
        $offset += $w;
    }
    return \@data;
}

sub Write {
    my ($self, $data, $xoff, $yoff, $xsize, $ysize) = @_;
    $xoff //= 0;
    $yoff //= 0;
    my $bufxsize = @{$data->[0]};
    my $bufysize = @$data;
    $xsize //= $bufxsize;
    $ysize //= $bufysize;
    my $t = Geo::GDAL::FFI::GDALGetRasterDataType($$self);
    my ($pc, $bytes_per_cell) = PackCharacter($t);
    my $buf = '';
    for my $i (0..$bufysize-1) {
        $buf .= pack($pc."[$bufxsize]", @{$data->[$i]});
    }
    my ($pointer, $size) = scalar_to_buffer $buf;
    Geo::GDAL::FFI::GDALRasterIO($$self, Geo::GDAL::FFI::Write, $xoff, $yoff, $xsize, $ysize, $pointer, $bufxsize, $bufysize, $t, 0, 0);
}

sub WriteBlock {
    my ($self, $data, $xoff, $yoff) = @_;
    my ($xsize, $ysize);
    Geo::GDAL::FFI::GDALGetBlockSize($$self, \$xsize, \$ysize);
    my $t = Geo::GDAL::FFI::GDALGetRasterDataType($$self);
    my ($pc, $bytes_per_cell) = PackCharacter($t);
    my $buf = '';
    for my $i (0..$ysize-1) {
        $buf .= pack($pc."[$xsize]", @{$data->[$i]});
    }
    my ($pointer, $size) = scalar_to_buffer $buf;
    Geo::GDAL::FFI::GDALWriteBlock($$self, $xoff, $yoff, $pointer);
}

sub GetColorInterpretation {
    my $self = shift;
    return $color_interpretations_reverse{
        Geo::GDAL::FFI::GDALGetRasterColorInterpretation($$self)
    };
}

sub SetColorInterpretation {
    my ($self, $i) = @_;
    my $tmp = $color_interpretations{$i};
    confess "Unknown constant: $i\n" unless defined $tmp;
    $i = $tmp;
    Geo::GDAL::FFI::GDALSetRasterColorInterpretation($$self, $i);
}

sub GetPaletteInterp {
    my $self = shift;
}

sub GetColorTable {
    my $self = shift;
    my $ct = Geo::GDAL::FFI::GDALGetRasterColorTable($$self);
    return unless $ct;
    # color table is a table of [c1...c4]
    # the interpretation of colors is from next method
    my @table;
    for my $i (0..Geo::GDAL::FFI::GDALGetColorEntryCount($ct)-1) {
        my $c = Geo::GDAL::FFI::GDALGetColorEntry($ct, $i);
        push @table, $c;
    }
    return wantarray ? @table : \@table;
}

sub SetColorTable {
    my ($self, $table) = @_;
    my $ct = Geo::GDAL::FFI::GDALCreateColorTable();
    for my $i (0..$#$table) {
        Geo::GDAL::FFI::GDALSetColorEntry($ct, $i, $table->[$i]);
    }
    Geo::GDAL::FFI::GDALSetRasterColorTable($$self, $ct);
    Geo::GDAL::FFI::GDALDestroyColorTable($ct);
}

sub Piddle {
    my $self = shift;
    my ($w, $h) = $self->Size;
    unless (defined wantarray) {
        my $pdl = shift;
        my $t = $pdl_datatype2datatype{$pdl->get_datatype};
        confess "The Piddle datatype '".$pdl->get_datatype."' is unsuitable.\n" unless defined $t;
        $t = $datatypes{$t};
        my ($xdim, $ydim) = $pdl->dims();
        my ($xoff, $yoff, $xsize, $ysize) = @_;
        $xoff //= 0;
        $yoff //= 0;
        $xsize //= $xdim;
        $ysize //= $ydim;
        if ($xdim > $w - $xoff) {
            warn "Piddle too wide ($xdim) for this raster band (width = $w, offset = $xoff).";
            $xdim = $w - $xoff;
        }
        if ($ydim > $h - $yoff) {
            $ydim = $h - $yoff;
            warn "Piddle too tall ($ydim) for this raster band (height = $h, offset = $yoff).";
        }
        my $data = $pdl->get_dataref();
        my ($pointer, $size) = scalar_to_buffer $$data;
        Geo::GDAL::FFI::GDALRasterIO($$self, Geo::GDAL::FFI::Write, $xoff, $yoff, $xsize, $ysize, $pointer, $xdim, $ydim, $t, 0, 0);
        return;
    }
    my $t = Geo::GDAL::FFI::GDALGetRasterDataType($$self);
    my $pdl_t = $datatype2pdl_datatype{$datatypes_reverse{$t}};
    confess "The Piddle datatype is unsuitable.\n" unless defined $pdl_t;
    my ($xoff, $yoff, $xsize, $ysize, $xdim, $ydim, $alg) = @_;
    $xoff //= 0;
    $yoff //= 0;
    $xsize //= $w - $xoff;
    $ysize //= $h - $yoff;
    $xdim //= $xsize;
    $ydim //= $ysize;
    $alg //= 'NearestNeighbour';
    my $tmp = $resampling{$alg};
    confess "Unknown constant: $alg\n" unless defined $tmp;
    $alg = $tmp;
    my $bufxsize = $xsize;
    my $bufysize = $ysize;
    my ($pc, $bytes_per_cell) = PackCharacter($t);
    my $buf = ' ' x ($bufysize * $bufxsize * $bytes_per_cell);
    my ($pointer, $size) = scalar_to_buffer $buf;
    Geo::GDAL::FFI::GDALRasterIO($$self, Geo::GDAL::FFI::Read, $xoff, $yoff, $xsize, $ysize, $pointer, $bufxsize, $bufysize, $t, 0, 0);
    my $pdl = PDL->new;
    $pdl->set_datatype($pdl_t);
    $pdl->setdims([$xdim, $ydim]);
    my $data = $pdl->get_dataref();
    # FIXME: see http://pdl.perl.org/PDLdocs/API.html how to wrap $buf into a piddle
    $$data = $buf;
    $pdl->upd_data;
    # FIXME: we want approximate equality since no data value can be very large floating point value
    my $bad = GetNoDataValue($self);
    return $pdl->setbadif($pdl == $bad) if defined $bad;
    return $pdl;
}

package Geo::GDAL::FFI::Layer;
use v5.10;
use strict;
use warnings;
use Carp;
use base 'Geo::GDAL::FFI::Object';

sub DESTROY {
    my $self = shift;
    Geo::GDAL::FFI::OGR_L_SyncToDisk($$self);
    #say STDERR "delete parent of $$self $parent{$$self}";
    delete $parent{$$self};
}

sub schema {
    my $self = shift;
    return $self->Defn->schema;
}

sub GetDefn {
    my $self = shift;
    my $d = Geo::GDAL::FFI::OGR_L_GetLayerDefn($$self);
    return bless \$d, 'Geo::GDAL::FFI::FeatureDefn';
}
*Defn = *GetDefn;

sub CreateField {
    my $self = shift;
    my $def = shift;
    unless (ref $def) {
        # name => type calling syntax
        my $name = $def;
        my $type = shift;
        $def = Geo::GDAL::FFI::FieldDefn->new({Name => $name, Type => $type})
    } elsif (ref $def eq 'HASH') {
        $def = Geo::GDAL::FFI::FieldDefn->new($def)
    }
    my $approx_ok = shift // 1;
    my $e = Geo::GDAL::FFI::OGR_L_CreateField($$self, $$def, $approx_ok);
    return unless $e;
    my $msg = join("\n", @errors);
    @errors = ();
    confess $msg;
}

sub CreateGeomField {
    my $self = shift;
    my $def = shift;
    unless (ref $def) {
        # name => type calling syntax
        my $name = $def;
        my $type = shift;
        $def = Geo::GDAL::FFI::GeomFieldDefn->new({Name => $name, Type => $type});
    } elsif (ref $def eq 'HASH') {
        $def = Geo::GDAL::FFI::GeomFieldDefn->new($def)
    }
    my $approx_ok = shift // 1;
    my $e = Geo::GDAL::FFI::OGR_L_CreateGeomField($$self, $$def, $approx_ok);
    return unless $e;
    my $msg = join("\n", @errors);
    @errors = ();
    confess $msg;
}

sub GetSpatialRef {
    my ($self) = @_;
    my $sr = Geo::GDAL::FFI::OGR_L_GetSpatialRef($$self);
    return unless $sr;
    return bless \$sr, 'Geo::GDAL::FFI::SpatialReference';
}

sub ResetReading {
    my $self = shift;
    Geo::GDAL::FFI::OGR_L_ResetReading($$self);
}

sub GetNextFeature {
    my $self = shift;
    my $f = Geo::GDAL::FFI::OGR_L_GetNextFeature($$self);
    return unless $f;
    return bless \$f, 'Geo::GDAL::FFI::Feature';
}

sub GetFeature {
    my ($self, $fid) = @_;
    my $f = Geo::GDAL::FFI::OGR_L_GetFeature($$self, $fid);
    confess unless $f;
    return bless \$f, 'Geo::GDAL::FFI::Feature';
}

sub SetFeature {
    my ($self, $f) = @_;
    Geo::GDAL::FFI::OGR_L_SetFeature($$self, $$f);
}

sub CreateFeature {
    my ($self, $f) = @_;
    my $e = Geo::GDAL::FFI::OGR_L_CreateFeature($$self, $$f);
    return $f unless $e;
}

sub DeleteFeature {
    my ($self, $fid) = @_;
    my $e = Geo::GDAL::FFI::OGR_L_DeleteFeature($$self, $fid);
    return unless $e;
    my $msg = join("\n", @errors);
    @errors = ();
    confess $msg;
}

package Geo::GDAL::FFI::FeatureDefn;
use v5.10;
use strict;
use warnings;
use Carp;

sub new {
    my ($class, $args) = @_;
    $args //= {};
    my $name = $args->{Name} // '';
    my $self = bless \Geo::GDAL::FFI::OGR_FD_Create($name), $class;
    if (exists $args->{Fields}) {
        for my $field (@{$args->{Fields}}) {
            $self->AddField(Geo::GDAL::FFI::FieldDefn->new($field));
        }
    }
    if (exists $args->{GeometryFields}) {
        my $first = 1;
        for my $field (@{$args->{GeometryFields}}) {
            if ($first) {
                my $d = bless \Geo::GDAL::FFI::OGR_FD_GetGeomFieldDefn($$self, 0), 
                'Geo::GDAL::FFI::GeomFieldDefn';
                $d->SetName($field->{Name}) if defined $field->{Name};
                $self->SetGeomType($field->{Type});
                $d->SetSpatialRef($field->{SpatialReference}) if $field->{SpatialReference};
                $d->SetNullable(0) if $field->{NotNullable};
                $first = 0;
            } else {
                $self->AddGeomField(Geo::GDAL::FFI::GeomFieldDefn->new($field));
            }
        }
    } else {
        $self->SetGeomType($args->{GeometryType});
    }
    $self->SetStyleIgnored if $args->{StyleIgnored};
    return $self;
}

sub schema {
    my $self = shift;
    my $schema = {Name => $self->GetName};
    for my $i (0..$self->GetFieldCount-1) {
        push @{$schema->{Fields}}, $self->GetField($i)->schema;
    }
    for my $i (0..$self->GetGeomFieldCount-1) {
        push @{$schema->{GeometryFields}}, $self->GetGeomField($i)->schema;
    }
    $schema->{StyleIgnored} = 1 if $self->IsStyleIgnored;
    return $schema;
}

sub DESTROY {
    my $self = shift;
    #Geo::GDAL::FFI::OGR_FD_Release($$self);
}

sub GetName {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_FD_GetName($$self);
}

sub GetFieldCount {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_FD_GetFieldCount($$self);
}

sub GetGeomFieldCount {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_FD_GetGeomFieldCount($$self);
}

sub GetField {
    my ($self, $i) = @_;
    $i //= 0;
    $i = $self->GetFieldIndex($i) unless Geo::GDAL::FFI::isint($i);
    my $d = Geo::GDAL::FFI::OGR_FD_GetFieldDefn($$self, $i);
    confess "No such field: $i" unless $d;
    ++$immutable{$d};
    return bless \$d, 'Geo::GDAL::FFI::FieldDefn';
}

sub GetGeomField {
    my ($self, $i) = @_;
    $i //= 0;
    $i = $self->GetGeomFieldIndex($i) unless Geo::GDAL::FFI::isint($i);
    my $d = Geo::GDAL::FFI::OGR_FD_GetGeomFieldDefn($$self, $i);
    confess "No such field: $i" unless $d;
    ++$immutable{$d};
    return bless \$d, 'Geo::GDAL::FFI::GeomFieldDefn';
}

sub GetFieldIndex {
    my ($self, $name) = @_;
    return 0 unless defined $name;
    return Geo::GDAL::FFI::OGR_FD_GetFieldIndex($$self, $name);
}

sub GetGeomFieldIndex {
    my ($self, $name) = @_;
    return 0 unless defined $name;
    return Geo::GDAL::FFI::OGR_FD_GetGeomFieldIndex($$self, $name);
}

sub AddField {
    my ($self, $d) = @_;
    Geo::GDAL::FFI::OGR_FD_AddFieldDefn($$self, $$d);
}

sub AddGeomField {
    my ($self, $d) = @_;
    Geo::GDAL::FFI::OGR_FD_AddGeomFieldDefn($$self, $$d);
}

sub DeleteField {
    my ($self, $i) = @_;
    $i //= 0;
    $i = $self->GetFieldIndex($i) unless Geo::GDAL::FFI::isint($i);
    Geo::GDAL::FFI::OGR_FD_DeleteFieldDefn($$self, $i);
}

sub DeleteGeomField {
    my ($self, $i) = @_;
    $i //= 0;
    $i = $self->GetGeomFieldIndex($i) unless Geo::GDAL::FFI::isint($i);
    Geo::GDAL::FFI::OGR_FD_DeleteGeomFieldDefn($$self, $i);
}

sub GetGeomType {
    my ($self) = @_;
    return $geometry_types_reverse{Geo::GDAL::FFI::OGR_FD_GetGeomType($$self)};
}

sub SetGeomType {
    my ($self, $type) = @_;
    $type //= 'Unknown';
    my $tmp = $geometry_types{$type};
    confess "Unknown geometry type: $type\n" unless defined $tmp;
    Geo::GDAL::FFI::OGR_FD_SetGeomType($$self, $tmp);
}

sub IsGeometryIgnored {
    my ($self) = @_;
    Geo::GDAL::FFI::OGR_FD_IsGeometryIgnored($$self);
}

sub SetGeometryIgnored {
    my ($self, $i) = @_;
    $i //= 1;
    Geo::GDAL::FFI::OGR_FD_SetGeometryIgnored($$self, $i);
}

sub IsStyleIgnored {
    my ($self) = @_;
    Geo::GDAL::FFI::OGR_FD_IsStyleIgnored($$self);
}

sub SetStyleIgnored {
    my ($self, $i) = @_;
    $i //= 1;
    Geo::GDAL::FFI::OGR_FD_SetStyleIgnored($$self, $i);
}

package Geo::GDAL::FFI::FieldDefn;
use v5.10;
use strict;
use warnings;
use Carp;

sub new {
    my ($class, $args) = @_;
    my $name = $args->{Name} // 'Unnamed';
    my $type = $args->{Type} // 'String';
    my $tmp = $field_types{$type};
    confess "Unknown field type: '$type'\n" unless defined $tmp;
    my $self = bless \Geo::GDAL::FFI::OGR_Fld_Create($name, $tmp), $class;
    $self->SetDefault($args->{Default}) if defined $args->{Default};
    $self->SetSubtype($args->{Subtype}) if defined $args->{Subtype};
    $self->SetJustify($args->{Justify}) if defined $args->{Justify};
    $self->SetWidth($args->{Width}) if defined $args->{Width};
    $self->SetPrecision($args->{Precision}) if defined $args->{Precision};
    $self->SetNullable(0) if $args->{NotNullable};
    return $self;
}

sub schema {
    my $self = shift;
    my $schema = {
        Name => $self->GetName,
        Type => $self->GetType,
        Subtype => $self->GetSubtype,
        Justify => $self->GetJustify,
        Width => $self->GetWidth,
        Precision => $self->GetPrecision,
    };
    my $default = $self->GetDefault;
    $schema->{Default} = $default if defined $default;
    $schema->{NotNullable} = 1 unless $self->IsNullable;
    return $schema;
}

sub DESTROY {
    my $self = shift;
    #say STDERR "destroy $self => $$self";
    if ($immutable{$$self}) {
        #say STDERR "remove it from immutable";
        $immutable{$$self}--;
        delete $immutable{$$self} if $immutable{$$self} == 0;
    } else {
        #say STDERR "destroy it";
        Geo::GDAL::FFI::OGR_Fld_Destroy($$self);
    }
}

sub SetName {
    my ($self, $name) = @_;
    confess "Can't modify an immutable object." if $immutable{$$self};
    $name //= '';
    Geo::GDAL::FFI::OGR_Fld_SetName($$self, $name);
}

sub GetName {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_Fld_GetNameRef($$self);
}
*Name = *GetName;

sub SetType {
    my ($self, $type) = @_;
    confess "Can't modify an immutable object." if $immutable{$$self};
    $type //= 'String';
    my $tmp = $field_types{$type};
    confess "Unknown constant: $type\n" unless defined $tmp;
    $type = $tmp;
    Geo::GDAL::FFI::OGR_Fld_SetType($$self, $type);
}

sub GetType {
    my ($self) = @_;
    return $field_types_reverse{Geo::GDAL::FFI::OGR_Fld_GetType($$self)};
}
*Type = *GetType;

sub GetDefault {
    my $self = shift;
    return Geo::GDAL::FFI::OGR_Fld_GetDefault($$self)
}

sub SetDefault {
    my ($self, $default) = @_;
    Geo::GDAL::FFI::OGR_Fld_SetDefault($$self, $default);
}

sub IsDefaultDriverSpecific {
    my $self = shift;
    return Geo::GDAL::FFI::OGR_Fld_IsDefaultDriverSpecific($$self);
}

sub SetSubtype {
    my ($self, $subtype) = @_;
    confess "Can't modify an immutable object." if $immutable{$$self};
    $subtype //= 'None';
    my $tmp = $field_subtypes{$subtype};
    confess "Unknown constant: $subtype\n" unless defined $tmp;
    $subtype = $tmp;
    Geo::GDAL::FFI::OGR_Fld_SetSubType($$self, $subtype);
}

sub GetSubtype {
    my ($self) = @_;
    return $field_subtypes_reverse{Geo::GDAL::FFI::OGR_Fld_GetSubType($$self)};
}
*Subtype = *GetSubtype;

sub SetJustify {
    my ($self, $justify) = @_;
    confess "Can't modify an immutable object." if $immutable{$$self};
    $justify //= 'Undefined';
    my $tmp = $justification{$justify};
    confess "Unknown constant: $justify\n" unless defined $tmp;
    $justify = $tmp;
    Geo::GDAL::FFI::OGR_Fld_SetJustify($$self, $justify);
}

sub GetJustify {
    my ($self) = @_;
    return $justification_reverse{Geo::GDAL::FFI::OGR_Fld_GetJustify($$self)};
}
*Justify = *GetJustify;

sub SetWidth {
    my ($self, $width) = @_;
    confess "Can't modify an immutable object." if $immutable{$$self};
    $width //= '';
    Geo::GDAL::FFI::OGR_Fld_SetWidth($$self, $width);
}

sub GetWidth {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_Fld_GetWidth($$self);
}
*Width = *GetWidth;

sub SetPrecision {
    my ($self, $precision) = @_;
    confess "Can't modify an immutable object." if $immutable{$$self};
    $precision //= '';
    Geo::GDAL::FFI::OGR_Fld_SetPrecision($$self, $precision);
}

sub GetPrecision {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_Fld_GetPrecision($$self);
}
*Precision = *GetPrecision;

sub SetIgnored {
    my ($self, $ignored) = @_;
    #confess "Can't modify an immutable object." if $immutable{$$self};
    $ignored //= 1;
    Geo::GDAL::FFI::OGR_Fld_SetIgnored($$self, $ignored);
}

sub IsIgnored {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_Fld_IsIgnored($$self);
}

sub SetNullable {
    my ($self, $nullable) = @_;
    confess "Can't modify an immutable object." if $immutable{$$self};
    $nullable //= 0;
    Geo::GDAL::FFI::OGR_Fld_SetNullable($$self, $nullable);
}

sub IsNullable {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_Fld_IsNullable($$self);
}

package Geo::GDAL::FFI::GeomFieldDefn;
use v5.10;
use strict;
use warnings;
use Carp;

sub new {
    my ($class, $args) = @_;
    $args //= {};
    my $name = $args->{Name} // 'Unnamed';
    my $type = $args->{Type} // 'Point';
    my $tmp = $geometry_types{$type};
    confess "Unknown geometry type: $type\n" unless defined $tmp;
    my $self = bless \Geo::GDAL::FFI::OGR_GFld_Create($name, $tmp), $class;
    $self->SetSpatialRef($args->{SpatialReference}) if $args->{SpatialReference};
    $self->SetNullable(0) if $args->{NotNullable};
    return $self;
}

sub schema {
    my $self = shift;
    my $schema = {
        Name => $self->GetName,
        Type => $self->GetType
    };
    $schema->{SpatialReference} = $self->GetSpatialRef;
    $schema->{NotNullable} = 1 unless $self->IsNullable;
    return $schema;
}

sub DESTROY {
    my $self = shift;
    if ($immutable{$$self}) {
        $immutable{$$self}--;
        delete $immutable{$$self} if $immutable{$$self} == 0;
    } else {
        Geo::GDAL::FFI::OGR_GFld_Destroy($$self);
    }
}

sub SetName {
    my ($self, $name) = @_;
    confess "Can't modify an immutable object." if $immutable{$$self};
    $name //= '';
    Geo::GDAL::FFI::OGR_GFld_SetName($$self, $name);
}

sub GetName {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_GFld_GetNameRef($$self);
}
*Name = *GetName;

sub SetType {
    my ($self, $type) = @_;
    confess "Can't modify an immutable object." if $immutable{$$self};
    $type //= 'Point';
    my $tmp = $geometry_types{$type};
    confess "Unknown geometry type: $type\n" unless defined $tmp;
    $type = $tmp;
    Geo::GDAL::FFI::OGR_GFld_SetType($$self, $type);
}

sub GetType {
    my ($self) = @_;
    return $geometry_types_reverse{Geo::GDAL::FFI::OGR_GFld_GetType($$self)};
}
*Type = *GetType;

sub SetSpatialRef {
    my ($self, $sr) = @_;
    confess "Can't modify an immutable object." if $immutable{$$self};
    Geo::GDAL::FFI::OGR_GFld_SetSpatialRef($$self, $$sr);
}

sub GetSpatialRef {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_GFld_GetSpatialRef($$self);
}
*SpatialRef = *GetSpatialRef;

sub SetIgnored {
    my ($self, $ignored) = @_;
    #confess "Can't modify an immutable object." if $immutable{$$self};
    $ignored //= 1;
    Geo::GDAL::FFI::OGR_GFld_SetIgnored($$self, $ignored);
}

sub IsIgnored {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_GFld_IsIgnored($$self);
}

sub SetNullable {
    my ($self, $nullable) = @_;
    confess "Can't modify an immutable object." if $immutable{$$self};
    $nullable //= 0;
    Geo::GDAL::FFI::OGR_GFld_SetNullable($$self, $nullable);
}

sub IsNullable {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_GFld_IsNullable($$self);
}

package Geo::GDAL::FFI::Feature;
use v5.10;
use strict;
use warnings;
use Carp;
use Encode qw(decode encode);
use FFI::Platypus::Buffer;

sub new {
    my ($class, $defn) = @_;
    my $f = Geo::GDAL::FFI::OGR_F_Create($$defn);
    return bless \$f, $class;
}

sub schema {
    my $self = shift;
    return $self->Defn->schema;
}

sub DESTROY {
    my $self = shift;
    Geo::GDAL::FFI::OGR_F_Destroy($$self);
}

sub GetFID {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_F_GetFID($$self);
}

sub SetFID {
    my ($self, $fid) = @_;
    $fid //= 0;
    Geo::GDAL::FFI::OGR_F_GetFID($$self, $fid);
}

sub GetDefn {
    my ($self) = @_;
    my $d = Geo::GDAL::FFI::OGR_F_GetDefnRef($$self);
    ++$immutable{$d};
    #say STDERR "$d immutable";
    return bless \$d, 'Geo::GDAL::FFI::FeatureDefn';
}
*Defn = *GetDefn;

sub Clone {
    my ($self) = @_;
    my $f = Geo::GDAL::FFI::OGR_F_Clone($$self);
    return bless \$f, 'Geo::GDAL::FFI::Feature';
}

sub Equal {
    my ($self, $f) = @_;
    return Geo::GDAL::FFI::OGR_F_Equal($$self, $$f);
}

sub GetFieldCount {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_F_GetFieldCount($$self);
}

sub SetField {
    my ($self, $fname, $value) = @_;
    $fname //= 0;
    my $i = Geo::GDAL::FFI::isint($fname) ? $fname : $self->GetFieldIndex($fname);
    $self->SetFieldNull($i) unless defined $value;
    my $t = $self->GetFieldDefn($i)->Type;
    $self->SetFieldInteger($i, $value) if $t eq 'Integer';
    $self->SetFieldInteger64($i, $value) if $t eq 'Integer64';
    $self->SetFieldDouble($i, $value) if $t eq 'Real';
    $self->SetFieldString($i, $value) if $t eq 'String';
    # Binary
    if ($t eq 'IntegerList') {
        $self->SetFieldIntegerList($i, $value);
    } elsif ($t eq 'Integer64List') {
        $self->SetFieldInteger64List($i, $value);
    } elsif ($t eq 'RealList') {
        $self->SetFieldRealList($i, $value);
    } elsif ($t eq 'StringList') {
        $self->SetFieldStringList($i, $value);
    } elsif ($t eq 'Date') {
        $self->SetFieldDateTimeEx($i, $value);
    } elsif ($t eq 'Time') {
        my @dt = (0, 0, 0, @$value);
        $self->SetFieldDateTimeEx($i, \@dt);
    } elsif ($t eq 'DateTime') {
        $self->SetFieldDateTimeEx($i, $value);
    }
}

sub GetField {
    my ($self, $fname) = @_;
    $fname //= 0;
    my $i = Geo::GDAL::FFI::isint($fname) ? $fname : $self->GetFieldIndex($fname);
    return unless $self->IsFieldSetAndNotNull($i);
    my $t = $self->GetFieldDefn($i)->Type;
    return $self->GetFieldAsInteger($i) if $t eq 'Integer';
    return $self->GetFieldAsInteger64($i) if $t eq 'Integer64';
    return $self->GetFieldAsDouble($i) if $t eq 'Real';
    return $self->GetFieldAsString($i) if $t eq 'String';
    # Binary
    my $list;
    if ($t eq 'IntegerList') {
        $list = $self->GetFieldAsIntegerList($i);
    } elsif ($t eq 'Integer64List') {
        $list = $self->GetFieldAsInteger64List($i);
    } elsif ($t eq 'RealList') {
        $list = $self->GetFieldAsRealList($i);
    } elsif ($t eq 'StringList') {
        $list = $self->GetFieldAsStringList($i);
    } elsif ($t eq 'Date') {
        $list = $self->GetFieldAsDateTimeEx($i);
        $list = [@$list[0..2]];
    } elsif ($t eq 'Time') {
        $list = $self->GetFieldAsDateTimeEx($i);
        $list = [@$list[3..6]];
    } elsif ($t eq 'DateTime') {
        $list = $self->GetFieldAsDateTimeEx($i);
    }
    return wantarray ? @$list : $list;
}

sub GetFieldDefn {
    my ($self, $i) = @_;
    $i //= 0;
    my $d = Geo::GDAL::FFI::OGR_F_GetFieldDefnRef($$self, $i);
    confess unless $d;
    ++$immutable{$d};
    return bless \$d, 'Geo::GDAL::FFI::FieldDefn';
}

sub GetFieldIndex {
    my ($self, $name) = @_;
    return 0 unless defined $name;
    return Geo::GDAL::FFI::OGR_F_GetFieldIndex($$self, $name);
}

sub IsFieldSet {
    my ($self, $i) = @_;
    $i //= 0;
    return Geo::GDAL::FFI::OGR_F_IsFieldSet($$self, $i);
}

sub UnsetField {
    my ($self, $i) = @_;
    $i //= 0;
    Geo::GDAL::FFI::OGR_F_UnsetField($$self, $i);
}

sub IsFieldNull {
    my ($self, $i) = @_;
    $i //= 0;
    return Geo::GDAL::FFI::OGR_F_IsFieldNull($$self, $i);
}

sub IsFieldSetAndNotNull {
    my ($self, $i) = @_;
    $i //= 0;
    return Geo::GDAL::FFI::OGR_F_IsFieldSetAndNotNull($$self, $i);
}

sub SetFieldNull {
    my ($self, $i) = @_;
    $i //= 0;
    Geo::GDAL::FFI::OGR_F_SetFieldNull($$self, $i);
}

sub GetFieldAsInteger {
    my ($self, $i) = @_;
    $i //= 0;
    return Geo::GDAL::FFI::OGR_F_GetFieldAsInteger($$self, $i);
}

sub GetFieldAsInteger64 {
    my ($self, $i) = @_;
    $i //= 0;
    return Geo::GDAL::FFI::OGR_F_GetFieldAsInteger64($$self, $i);
}

sub GetFieldAsDouble {
    my ($self, $i) = @_;
    $i //= 0;
    return Geo::GDAL::FFI::OGR_F_GetFieldAsDouble($$self, $i);
}

sub GetFieldAsString {
    my ($self, $i, $encoding) = @_;
    $i //= 0;
    my $retval = Geo::GDAL::FFI::OGR_F_GetFieldAsString($$self, $i);
    $retval = decode $encoding => $retval if defined $encoding;
    return $retval;
}

sub GetFieldAsIntegerList {
    my ($self, $i) = @_;
    $i //= 0;
    my (@list, $len);
    my $p = Geo::GDAL::FFI::OGR_F_GetFieldAsIntegerList($$self, $i, \$len);
    @list = unpack("l[$len]", buffer_to_scalar($p, $len*4));
    return wantarray ? @list : \@list;
}

sub GetFieldAsInteger64List {
    my ($self, $i) = @_;
    $i //= 0;
    my (@list, $len);
    my $p = Geo::GDAL::FFI::OGR_F_GetFieldAsInteger64List($$self, $i, \$len);
    @list = unpack("q[$len]", buffer_to_scalar($p, $len*8));
    return wantarray ? @list : \@list;
}

sub GetFieldAsDoubleList {
    my ($self, $i) = @_;
    $i //= 0;
    my (@list, $len);
    my $p = Geo::GDAL::FFI::OGR_F_GetFieldAsDoubleList($$self, $i, \$len);
    @list = unpack("d[$len]", buffer_to_scalar($p, $len*8));
    return wantarray ? @list : \@list;
}

sub GetFieldAsStringList {
    my ($self, $i) = @_;
    $i //= 0;
    my $p = Geo::GDAL::FFI::OGR_F_GetFieldAsStringList($$self, $i);
    my @list;
    for my $i (0..Geo::GDAL::FFI::CSLCount($p)-1) {
        push @list, Geo::GDAL::FFI::CSLGetField($p, $i);
    }
    return wantarray ? @list : \@list;
}

sub GetFieldAsBinary {
    my ($self, $i) = @_;
    $i //= 0;
    return Geo::GDAL::FFI::OGR_F_GetFieldAsBinary($$self, $i);
}

sub GetFieldAsDateTime {
    my ($self, $i) = @_;
    $i //= 0;
    return Geo::GDAL::FFI::OGR_F_GetFieldAsDateTime($$self, $i);
}

sub GetFieldAsDateTimeEx {
    my ($self, $i) = @_;
    $i //= 0;
    my ($y, $m, $d, $h, $min, $s, $tz) = (0, 0, 0, 0, 0, 0.0, 0);
    Geo::GDAL::FFI::OGR_F_GetFieldAsDateTimeEx($$self, $i, \$y, \$m, \$d, \$h, \$min, \$s, \$tz);
    $s = sprintf("%.3f", $s) + 0;
    return wantarray ? ($y, $m, $d, $h, $min, $s, $tz) : [$y, $m, $d, $h, $min, $s, $tz];
}

sub SetFieldInteger {
    my ($self, $i, $value) = @_;
    $i //= 0;
    $value //= 0;
    Geo::GDAL::FFI::OGR_F_SetFieldInteger($$self, $i, $value);
}

sub SetFieldInteger64 {
    my ($self, $i, $value) = @_;
    $i //= 0;
    Geo::GDAL::FFI::OGR_F_SetFieldInteger64($$self, $i, $value);
}

sub SetFieldDouble {
    my ($self, $i, $value) = @_;
    $i //= 0;
    Geo::GDAL::FFI::OGR_F_SetFieldDouble($$self, $i, $value);
}

sub SetFieldString {
    my ($self, $i, $value) = @_;
    $i //= 0;
    Geo::GDAL::FFI::OGR_F_SetFieldString($$self, $i, $value);
}

sub SetFieldIntegerList {
    my ($self, $i, $list) = @_;
    $list //= [];
    $i //= 0;
    Geo::GDAL::FFI::OGR_F_SetFieldIntegerList($$self, $i, scalar @$list, $list);
}

sub SetFieldInteger64List {
    my ($self, $i, $list) = @_;
    $list //= [];
    $i //= 0;
    Geo::GDAL::FFI::OGR_F_SetFieldInteger64List($$self, $i, scalar @$list, $list);
}

sub SetFieldDoubleList {
    my ($self, $i, $list) = @_;
    $list //= [];
    $i //= 0;
    Geo::GDAL::FFI::OGR_F_SetFieldDoubleList($$self, $i, scalar @$list, $list);
}

sub SetFieldStringList {
    my ($self, $i, $list) = @_;
    $list //= [];
    $i //= 0;
    my $csl = 0;
    for my $s (@$list) {
        $csl = Geo::GDAL::FFI::CSLAddString($csl, $s);
    }
    Geo::GDAL::FFI::OGR_F_SetFieldStringList($$self, $i, $csl);
    Geo::GDAL::FFI::CSLDestroy($csl);
}

sub SetFieldDateTime {
    my ($self, $i, $value) = @_;
    $i //= 0;
    Geo::GDAL::FFI::OGR_F_SetFieldDateTime($$self, $i, $value);
}

sub SetFieldDateTimeEx {
    my ($self, $i, $dt) = @_;
    $dt //= [];
    $i //= 0;
    my @dt = @$dt;
    $dt[0] //= 2000; # year
    $dt[0] //= 1; # month 1-12
    $dt[0] //= 1; # day 1-31
    $dt[0] //= 0; # hour 0-23
    $dt[0] //= 0; # minute 0-59
    $dt[0] //= 0.0; # second with millisecond accuracy
    $dt[0] //= 100; # TZ
    Geo::GDAL::FFI::OGR_F_SetFieldDateTimeEx($$self, $i, @dt);
}

sub GetGeomFieldCount {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_F_GetGeomFieldCount($$self);
}

sub GetGeomFieldIndex {
    my ($self, $fname) = @_;
    return 0 unless defined $fname;
    return Geo::GDAL::FFI::OGR_F_GetGeomFieldIndex($$self, $fname);
}

sub GetGeomFieldDefn {
    my ($self, $i) = @_;
    $i //= 0;
}

sub GetGeomField {
    my ($self, $fname) = @_;
    $fname //= 0;
    my $i = Geo::GDAL::FFI::isint($fname) ? $fname : $self->GetGeomFieldIndex($fname);
    my $g = Geo::GDAL::FFI::OGR_F_GetGeomFieldRef($$self, $i);
    confess "No such field: $i" unless $g;
    ++$immutable{$g};
    #say STDERR "$g immutable";
    return bless \$g, 'Geo::GDAL::FFI::Geometry';
}
*GetGeometry = *GetGeomField;

sub SetGeomField {
    my $self = shift;
    my $g = pop;
    my $fname = shift;
    $fname //= 0;
    my $i = Geo::GDAL::FFI::isint($fname) ? $fname : $self->GetGeomFieldIndex($fname);
    if (ref $g eq 'ARRAY') {
        $g = Geo::GDAL::FFI::Geometry->new(@$g);
    }
    ++$immutable{$$g};
    #say STDERR "$$g immutable";
    Geo::GDAL::FFI::OGR_F_SetGeomFieldDirectly($$self, $i, $$g);
}
*SetGeometry = *SetGeomField;

package Geo::GDAL::FFI::Geometry;
use v5.10;
use strict;
use warnings;
use Carp;

sub new {
    my $class = shift;
    my $g = 0;
    if (@_ == 1) {
        my $type = shift // '';
        my $tmp = $geometry_types{$type};
        confess "Empty or unknown geometry type: '$type'\n" unless defined $tmp;
        my $m = $type =~ /M$/;
        my $z = $type =~ /ZM$/ || $type =~ /25D$/;
        $g = Geo::GDAL::FFI::OGR_G_CreateGeometry($tmp);
        confess "OGR_G_CreateGeometry failed." unless $g; # should not happen
        Geo::GDAL::FFI::OGR_G_SetMeasured($g, 1) if $m;
        Geo::GDAL::FFI::OGR_G_Set3D($g, 1) if $z;
        return bless \$g, $class;
    } else {
        my ($format, $string, $sr) = @_;
        my $tmp = $geometry_formats{$format};
        confess "Empty or unknown geometry format: '$format'\n" unless defined $tmp;
        $sr = $$sr if $sr;
        if ($format eq 'WKT') {
            my $e = Geo::GDAL::FFI::OGR_G_CreateFromWkt(\$string, $sr, \$g);
        }
    }
    return bless \$g, $class;
}

sub DESTROY {
    my ($self) = @_;
    if ($immutable{$$self}) {
        #say STDERR "forget $$self $immutable{$$self}";
        $immutable{$$self}--;
        delete $immutable{$$self} if $immutable{$$self} == 0;
    } else {
        #say STDERR "destroy $$self";
        Geo::GDAL::FFI::OGR_G_DestroyGeometry($$self);
    }
}

sub Type {
    my ($self, $mode) = @_;
    $mode //= '';
    my $t = Geo::GDAL::FFI::OGR_G_GetGeometryType($$self);
    Geo::GDAL::FFI::OGR_GT_Flatten($t) if $mode =~ /flatten/i;
    #say STDERR "type is $t";
    return $geometry_types_reverse{$t};
}

sub GetPointCount {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_G_GetPointCount($$self);
}
*PointCount = *GetPointCount;

sub SetPoint {
    my $self = shift;
    confess "Can't modify an immutable object." if $immutable{$$self};
    my ($i, $x, $y, $z, $m);
    $i = shift if
        Geo::GDAL::FFI::OGR_GT_Flatten(
            Geo::GDAL::FFI::OGR_G_GetGeometryType($$self)) != 1; # a point
    if (@_ > 1) {
        ($x, $y, $z, $m) = @_;
    } elsif (@_) {
        ($x, $y, $z, $m) = @{$_[0]};
    }
    $x //= 0;
    $y //= 0;
    my $is3d = Geo::GDAL::FFI::OGR_G_Is3D($$self);
    my $ism = Geo::GDAL::FFI::OGR_G_IsMeasured($$self);
    if ($is3d && $ism) {
        $z //= 0;
        $m //= 0;
        Geo::GDAL::FFI::OGR_G_SetPointZM($$self, $i, $x, $y, $z, $m);
    } elsif ($ism) {
        $m //= 0;
        Geo::GDAL::FFI::OGR_G_SetPointM($$self, $i, $x, $y, $m);
    } elsif ($is3d) {
        $z //= 0;
        Geo::GDAL::FFI::OGR_G_SetPoint($$self, $i, $x, $y, $z);
    } else {
        Geo::GDAL::FFI::OGR_G_SetPoint_2D($$self, $i, $x, $y);
    }
}

sub GetPoint {
    my ($self, $i) = @_;
    $i //= 0;
    my ($x, $y, $z, $m) = (0, 0, 0, 0);
    Geo::GDAL::FFI::OGR_G_GetPointZM($$self, $i, \$x, \$y, \$z, \$m);
    my @point = ($x, $y);
    push @point, $z if Geo::GDAL::FFI::OGR_G_Is3D($$self);
    push @point, $m if Geo::GDAL::FFI::OGR_G_IsMeasured($$self);
    return wantarray ? @point : \@point;
}

sub GetCount {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_G_GetGeometryCount($$self);
}
*GeometryCount = *GetCount;

sub GetGeometry {
    my ($self, $i) = @_;
    my $g = Geo::GDAL::FFI::OGR_G_Clone(Geo::GDAL::FFI::OGR_G_GetGeometryRef($$self, $i));
    return bless \$g, 'Geo::GDAL::FFI::Geometry';
}

sub AddGeometry {
    my ($self, $g) = @_;
    confess "Can't modify an immutable object." if $immutable{$$self};
    my $e = Geo::GDAL::FFI::OGR_G_GetGeometryRef($$self, $$g);
    return unless $e;
    my $msg = join("\n", @errors);
    @errors = ();
    confess $msg;
}

sub RemoveGeometry {
    my ($self, $i) = @_;
    confess "Can't modify an immutable object." if $immutable{$$self};
    my $e = Geo::GDAL::FFI::OGR_G_GetGeometryRef($$self, $i, 1);
    return unless $e;
    my $msg = join("\n", @errors);
    @errors = ();
    confess $msg;
}

sub ImportFromWkt {
    my ($self, $wkt) = @_;
    confess "Can't modify an immutable object." if $immutable{$$self};
    $wkt //= '';
    Geo::GDAL::FFI::OGR_G_ImportFromWkt($$self, \$wkt);
    return $wkt;
}

sub ExportToWkt {
    my ($self) = @_;
    my $wkt = '';
    Geo::GDAL::FFI::OGR_G_ExportToWkt($$self, \$wkt);
    return $wkt;
}

sub ExportToIsoWkt {
    my ($self) = @_;
    my $wkt = '';
    Geo::GDAL::FFI::OGR_G_ExportToIsoWkt($$self, \$wkt);
    return $wkt;
}
*AsWKT = *ExportToIsoWkt;
*AsText = *ExportToIsoWkt;

1;

=pod

=encoding UTF-8

=head1 NAME

Geo::GDAL::FFI - A foreign function interface to GDAL

=head1 SYNOPSIS

    use Geo::GDAL::FFI;
    my $gdal = Geo::GDAL::FFI->new();
    my $ds = $gdal->OpenEx('shapefile.shp');

=head1 DESCRIPTION

This is a foreign function interface to the GDAL geospatial data
access library.

=head2 Methods

'$named_arguments' below means a reference to a hash whose keys are
argument names.

=over 4

=item C<new>

Create a new Geo::GDAL::FFI object.

=item C<capabilities>

Returns the list of capabilities (strings) a Geo::GDAL::FFI::Object can have.

=item C<open_flags>

=item C<datatypes>

=item C<VersionInfo>

=item C<Drivers>

=item C<Driver($name)>

=item C<OpenEx($name, $named_arguments)>

=item C<Importer($format)>

Return a function for importing a SpatialReference object from a
format. The format is one of EPSG, EPSGA, Wkt, Proj4, ESRI, PCI, USGS,
XML, Dict, Panorama, Ozi, MICoordSys, ERM, Url.

=item C<Exporter($format)>

Return a function for exporting a SpatialReference object to a
format. The format is one of Wkt, PrettyWkt, Proj4, PCI, USGS, XML,
Panorama, MICoordSys, ERM.

=item C<Setter($arg)>

Return a function for setting projection parameters in a
SpatialReference object. The arg is one of Axes, ACEA, AE, Bonne, CEA,
CS, EC, Eckert, EckertIV, EckertVI, Equirectangular, Equirectangular2,
GS, GH, IGH, GEOS, GaussSchreiberTMercator, Gnomonic, HOM, HOMAC,
HOM2PNO, IWMPolyconic, Krovak, LAEA, LCC, LCC1SP, LCCB, MC, Mercator,
Mercator2SP, Mollweide, NZMG, OS, Orthographic, Polyconic, PS,
Robinson, Sinusoidal, Stereographic, SOC, TM, TMVariant, TMG, TMSO,
TPED, VDG, Wagner, QSC, SCH

=back

=head1 Geo::GDAL::FFI::Object

The base class for classes Driver, SpatialReference, Dataset, Band,
and Layer.

=head2 Methods

=over 4

=item C<HasCapability($capability)>

=item C<GetMetadataDomainList>

=item C<GetMetadata($domain)>

=item C<SetMetadata($metadata, $domain)>

=item C<GetMetadataItem($item, $domain)>

=item C<SetMetadataItem($item, $value, $domain)>

=back

=head1 Geo::GDAL::FFI::Driver

=head2 Methods

=over 4

=item C<Name>

=item C<CreateDataset($named_arguments)>

Named arguments are Name (string, default = ''), Options (hashref,
default = {}), Source (optional, the dataset to copy), Width and
Height (optional but required to create a raster dataset), Bands
(optional, the number of raster bands in the dataset), DataType
(string, optional, used only when creating a raster dataset, default =
'Byte'), Progress and ProgressData (optional, used only when copying a
dataset), Strict (optional, default is false (0), used only when
copying a dataset).

=back

=head1 Geo::GDAL::FFI::SpatialReference

=head2 Methods

=over 4

=item C<new($arg, @arg)>

Create a new SpatialReference object. If only one argument is given,
it is taken as WKT of a SRS. If there are more than one argument, the
first argument is taken as a format importer and the rest of the
arguments are taken as arguments to the importer. Importers are functions
that are created with the Importer method of Geo::GDAL::FFI object.

=item C<Export($exporter, @arg)>

=item C<Set($setter, @arg)>

=back

=head1 Geo::GDAL::FFI::Dataset

=head2 Methods

=over 4

=item C<Driver>

=item C<Info(@options)>

=item C<Translate(@options)>

=item C<Size>

=item C<>

=item C<>

=item C<>

=item C<>

=item C<Bands>

Returns a list of band objects.

=item C<CreateLayer($named_arguments)>

Create a new vector layer into this dataset.

Named arguments are 

=over 8

=item C<Name> (string, optional, default is ''),

=item C<GeometryType> (optional, default is 'Unknown', the type of the
first geometry field; note: if 'None', the layer schema does not
initially contain any geometry fields),

=item C<SpatialReference> (a SpatialReference object, optional, the
spatial reference for the first geometry field),

=item C<Options> (optional, driver specific options in an anonymous
hash),

=item C<Fields> (optional, a reference to an array of Field objects or
schemas, the fields to create into the layer),

=item C<GeometryFields> (optional, a reference to an array of
GeometryField objects or schemas, the geometry fields to create into
the layer; note that if this argument is defined then the arguments
GeometryType and SpatialReference are ignored).

=back

=item C<GetLayer($n)>

If $n is strictly an integer, then returns the (n-1)th layer in the
dataset, otherwise returns the layer whose name is $n. Without
arguments returns the first layer.

=item C<CopyLayer($layer, $name, $options)>

=back

=head1 Geo::GDAL::FFI::Band

=head2 Methods

=over 4

=item C<DataType>

=item C<Size>

=item C<BlockSize>

=item C<GetNoDataValue>

=item C<SetNoDataValue>

=item C<Read($xoff, $yoff, $xsize, $ysize, $bufxsize, $bufysize)>

=item C<ReadBlock($xoff, $yoff)>

=item C<Write($data, $xoff, $yoff, $xsize, $ysize)>

=item C<WriteBlock($data, $xoff, $yoff)>

=item C<GetColorInterpretation>

=item C<SetColorInterpretation>

=item C<GetColorTable>

=item C<SetColorTable>

=item C<Piddle>

=back

=head1 Geo::GDAL::FFI::Layer

=head2 Methods

=over 4

=item C<Defn>

Get the FeatureDefn object for this layer.

=item C<ResetReading>

=item C<GetNextFeature>

=item C<GetFeature>

=item C<SetFeature>

=item C<CreateFeature>

=item C<DeleteFeature>

=back

=head1 Geo::GDAL::FFI::FeatureDefn

=head2 Methods

=over 4

=item C<new($named_arguments)>

Create a new FeatureDefn object.

The named arguments (optional) are the following.

=over 8

=item C<Name> Optional; the name for this feature class; default is
the empty string.

=item C<Fields> Optional, a reference to an array of FieldDefn objects
or schemas.

=item C<GeometryFields> Optional, a reference to an array of GeomFieldDefn
objects or schemas.

=item C<GeometryType> Optional, the type for the first geometry field;
default is Unknown. Note that this argument is ignored if GeometryFields
is given.

=item C<StyleIgnored>

=back

=item C<schema>

Return the object as a perl data structure.

=item C<GetField($name)>

Get the specified non spatial field. If the argument is explicitly an
integer and not a string, it is taken as the field index.

=item C<GetGeomField($name)>

Get the specified spatial field. If the argument is explicitly an
integer and not a string, it is taken as the field index.

=item C<SetGeometryIgnored($arg)>

Ignore the first geometry field when reading features from a layer. To
not ignore the first geometry field call this method with defined but
false (0) argument.

=item C<IsGeometryIgnored>

Is the first geometry field ignored when reading features from a
layer.

=back

=head1 Geo::GDAL::FFI::FieldDefn

=head2 Schema

The schema of a FieldDefn is (Name, Type, Default, Subtype, Justify,
Width, Precision, NotNullable).

=head2 Methods

=over 4

=item C<SetIgnored($arg)>

Ignore this field when reading features from a layer. To not ignore
this field call this method with defined but false (0) argument.

=item C<IsIgnored>

Is this field ignored when reading features from a layer.

=back

=head1 Geo::GDAL::FFI::GeomFieldDefn

=head2 Schema

The schema of a GeomFieldDefn is (Name, Type, SpatialReference,
NotNullable).

=head2 Methods

=over 4

=item C<SetIgnored($arg)>

Ignore this field when reading features from a layer. To not ignore
this field call this method with defined but false (0) argument.

=item C<IsIgnored>

Is this field ignored when reading features from a layer.

=back

=head1 Geo::GDAL::FFI::Feature

=head2 Methods

=over 4

=item C<new($defn)>

Create a new Feature object. The argument is a FeatureDefn object,
which you can get from a Layer object (Defn method), another Feature
object (Defn method), or by explicitly creating a new FeatureDefn
object.

=item C<Defn>

Return the FeatureDefn object for this Feature.

=item C<GetFID>

=item C<SetFID>

=item C<Clone>

=item C<Equal>

=item C<SetField($fname, $value)>

=item C<GetField($fname)>

=item C<SetGeomField($fname, $geom)>

$fname is optional and by default zero.

=item C<GetGeomField($fname)>

$fname is optional and by default zero.

=back

=head1 Geo::GDAL::FFI::Geometry

=head2 Methods

=over 4

=item C<new($type)>

$type must be one of Geo::GDAL::FFI::geometry_types().

=item C<new($format, $arg, $sr)>

$format must be one of Geo::GDAL::FFI::geometry_formats().

$sr should be SpatialRef object if given.

=item C<Type>

=item C<PointCount>

=item C<SetPoint($i, $x, $y, $z, $m)>

=item C<SetPoint($i, $point)>

$point is [$x, $y, $z, $m]

=item C<GetPoint($i)>

=item C<GeometryCount>

=item C<GetGeometry>

=item C<AddGeometry($geom)>

=item C<RemoveGeometry($i)>

=item C<AsText>

=back

=head1 LICENSE

This software is released under the Artistic License. See
L<perlartistic>.

=head1 AUTHOR

Ari Jolma - Ari.Jolma at gmail.com

=head1 SEE ALSO

L<Alien::gdal>, L<FFI::Platypus>

=cut

__END__;

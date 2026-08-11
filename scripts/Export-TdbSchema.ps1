[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$DatabasePath,
    [Parameter(Mandatory)]
    [string]$TdbAccessDll,
    [Parameter(Mandatory)]
    [string]$OutputPath,
    [string]$MetadataPath,
    [ValidateSet('Plain', 'Xbox360', 'PS3')]
    [string]$ContainerFormat = 'Plain'
)

$ErrorActionPreference = 'Stop'
$dbPath = (Resolve-Path $DatabasePath).Path
$dllPath = (Resolve-Path $TdbAccessDll).Path
$outputFull = [System.IO.Path]::GetFullPath($OutputPath)

if (-not $MetadataPath) {
    $candidateMetadata = Join-Path (Split-Path -Parent $dbPath) 'nhlng-meta.xml'
    if (Test-Path -LiteralPath $candidateMetadata) { $MetadataPath = $candidateMetadata }
}

$metadataTables = @{}
if ($MetadataPath) {
    [xml]$metadata = Get-Content -LiteralPath (Resolve-Path $MetadataPath).Path -Raw
    foreach ($table in $metadata.database.table) {
        $fields = @{}
        foreach ($field in $table.fields.field) { $fields[[string]$field.shortname] = [string]$field.name }
        $metadataTables[[string]$table.shortname] = [pscustomobject]@{ name = [string]$table.name; fields = $fields }
    }
}

$nativeSource = @'
using System;
using System.Runtime.InteropServices;

public static class TdbNative
{
    [StructLayout(LayoutKind.Sequential, Pack = 1, CharSet = CharSet.Unicode)]
    public struct TableProperties
    {
        public IntPtr Name;
        public Int32 FieldCount;
        public Int32 Capacity;
        public Int32 RecordCount;
        public Int32 DeletedCount;
        public Int32 NextDeletedRecord;
        [MarshalAs(UnmanagedType.I1)] public bool Flag0;
        [MarshalAs(UnmanagedType.I1)] public bool Flag1;
        [MarshalAs(UnmanagedType.I1)] public bool Flag2;
        [MarshalAs(UnmanagedType.I1)] public bool Flag3;
        [MarshalAs(UnmanagedType.I1)] public bool NonAllocated;
        [MarshalAs(UnmanagedType.I1)] public bool HasVarchar;
        [MarshalAs(UnmanagedType.I1)] public bool HasCompressedVarchar;
    }

    [StructLayout(LayoutKind.Sequential, Pack = 1, CharSet = CharSet.Unicode)]
    public struct FieldProperties
    {
        public IntPtr Name;
        public Int32 Size;
        public Int32 FieldType;
    }

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool SetDllDirectory(string path);

    [DllImport("tdbaccess.dll", CallingConvention = CallingConvention.StdCall, CharSet = CharSet.Unicode)]
    public static extern Int32 TDBOpen(string fileName);

    [DllImport("tdbaccess.dll", CallingConvention = CallingConvention.StdCall, CharSet = CharSet.Unicode)]
    public static extern Int32 TDBOpenXbox360Save(string fileName);

    [DllImport("tdbaccess.dll", CallingConvention = CallingConvention.StdCall, CharSet = CharSet.Unicode)]
    public static extern Int32 TDBOpenPS3Save(string saveDirectory);

    [DllImport("tdbaccess.dll", CallingConvention = CallingConvention.StdCall)]
    [return: MarshalAs(UnmanagedType.I1)]
    public static extern bool TDBClose(Int32 dbIndex);

    [DllImport("tdbaccess.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern Int32 TDBDatabaseGetTableCount(Int32 dbIndex);

    [DllImport("tdbaccess.dll", CallingConvention = CallingConvention.StdCall)]
    [return: MarshalAs(UnmanagedType.I1)]
    public static extern bool TDBTableGetProperties(Int32 dbIndex, Int32 tableIndex, ref TableProperties properties);

    [DllImport("tdbaccess.dll", CallingConvention = CallingConvention.StdCall, CharSet = CharSet.Unicode)]
    [return: MarshalAs(UnmanagedType.I1)]
    public static extern bool TDBFieldGetProperties(Int32 dbIndex, string tableName, Int32 fieldIndex, ref FieldProperties properties);
}
'@

if (-not ('TdbNative' -as [type])) { Add-Type -TypeDefinition $nativeSource }

$dllDir = Split-Path -Parent $dllPath
if (-not [TdbNative]::SetDllDirectory($dllDir)) { throw "Unable to add TDBAccess DLL directory: $dllDir" }

$fieldTypes = @{
    0 = 'string'
    1 = 'binary'
    2 = 'signed-int'
    3 = 'unsigned-int'
    4 = 'float'
    13 = 'varchar'
    14 = 'long-varchar'
    716 = 'int'
}

$db = switch ($ContainerFormat) {
    'Xbox360' { [TdbNative]::TDBOpenXbox360Save($dbPath) }
    'PS3' { [TdbNative]::TDBOpenPS3Save($dbPath) }
    default { [TdbNative]::TDBOpen($dbPath) }
}
if ($db -lt 0) { throw "TDBAccess could not open $dbPath" }

try {
    $tables = [System.Collections.Generic.List[object]]::new()
    $tableCount = [TdbNative]::TDBDatabaseGetTableCount($db)
    for ($tableIndex = 0; $tableIndex -lt $tableCount; $tableIndex++) {
        $tableNameBuffer = [Runtime.InteropServices.Marshal]::AllocHGlobal(10)
        try {
            $tableProps = [TdbNative+TableProperties]::new()
            $tableProps.Name = $tableNameBuffer
            if (-not [TdbNative]::TDBTableGetProperties($db, $tableIndex, [ref]$tableProps)) {
                throw "Could not read table index $tableIndex"
            }
            $tableName = [Runtime.InteropServices.Marshal]::PtrToStringUni($tableNameBuffer)
            $fields = [System.Collections.Generic.List[object]]::new()
            for ($fieldIndex = 0; $fieldIndex -lt $tableProps.FieldCount; $fieldIndex++) {
                $fieldNameBuffer = [Runtime.InteropServices.Marshal]::AllocHGlobal(10)
                try {
                    $fieldProps = [TdbNative+FieldProperties]::new()
                    $fieldProps.Name = $fieldNameBuffer
                    if (-not [TdbNative]::TDBFieldGetProperties($db, $tableName, $fieldIndex, [ref]$fieldProps)) {
                        throw "Could not read field $fieldIndex from $tableName"
                    }
                    $fieldName = [Runtime.InteropServices.Marshal]::PtrToStringUni($fieldNameBuffer)
                    $logicalFieldName = if ($metadataTables.ContainsKey($tableName) -and $metadataTables[$tableName].fields.ContainsKey($fieldName)) { $metadataTables[$tableName].fields[$fieldName] } else { $fieldName }
                    $typeName = if ($fieldTypes.ContainsKey($fieldProps.FieldType)) { $fieldTypes[$fieldProps.FieldType] } else { "unknown-$($fieldProps.FieldType)" }
                    $fields.Add([ordered]@{ name = $logicalFieldName; short_name = $fieldName; type = $typeName; bits = $fieldProps.Size })
                }
                finally { [Runtime.InteropServices.Marshal]::FreeHGlobal($fieldNameBuffer) }
            }
            $logicalTableName = if ($metadataTables.ContainsKey($tableName)) { $metadataTables[$tableName].name } else { $tableName }
            $tables.Add([ordered]@{
                name = $logicalTableName
                short_name = $tableName
                fields = $fields
                capacity = $tableProps.Capacity
                records = $tableProps.RecordCount
                deleted = $tableProps.DeletedCount
            })
        }
        finally { [Runtime.InteropServices.Marshal]::FreeHGlobal($tableNameBuffer) }
    }

    $result = [ordered]@{
        source_file = [IO.Path]::GetFileName($dbPath)
        container_format = $ContainerFormat
        source_sha256 = (Get-FileHash -LiteralPath $dbPath -Algorithm SHA256).Hash.ToLowerInvariant()
        generated_utc = [DateTime]::UtcNow.ToString('o')
        table_count = $tableCount
        tables = $tables
    }
    $outputDir = Split-Path -Parent $outputFull
    if ($outputDir) { New-Item -ItemType Directory -Force $outputDir | Out-Null }
    $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outputFull -Encoding UTF8
    Write-Host "Exported $tableCount table definitions to $outputFull"
}
finally {
    [void][TdbNative]::TDBClose($db)
}

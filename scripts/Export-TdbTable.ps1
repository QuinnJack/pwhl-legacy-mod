[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$DatabasePath,
    [Parameter(Mandatory)]
    [string]$TdbAccessDll,
    [Parameter(Mandatory)]
    [string]$Table,
    [Parameter(Mandatory)]
    [string]$OutputPath,
    [ValidateSet('Plain', 'Xbox360', 'PS3')]
    [string]$ContainerFormat = 'Plain',
    [string[]]$Fields
)

$ErrorActionPreference = 'Stop'
$dbPath = (Resolve-Path -LiteralPath $DatabasePath).Path
$dllPath = (Resolve-Path -LiteralPath $TdbAccessDll).Path
$outputFull = [IO.Path]::GetFullPath($OutputPath)

$nativeSource = @'
using System;
using System.Runtime.InteropServices;

public static class TdbTableNative
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
    [return: MarshalAs(UnmanagedType.I1)] public static extern bool TDBClose(Int32 dbIndex);
    [DllImport("tdbaccess.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern Int32 TDBDatabaseGetTableCount(Int32 dbIndex);
    [DllImport("tdbaccess.dll", CallingConvention = CallingConvention.StdCall)]
    [return: MarshalAs(UnmanagedType.I1)] public static extern bool TDBTableGetProperties(Int32 dbIndex, Int32 tableIndex, ref TableProperties properties);
    [DllImport("tdbaccess.dll", CallingConvention = CallingConvention.StdCall, CharSet = CharSet.Unicode)]
    [return: MarshalAs(UnmanagedType.I1)] public static extern bool TDBFieldGetProperties(Int32 dbIndex, string tableName, Int32 fieldIndex, ref FieldProperties properties);
    [DllImport("tdbaccess.dll", CallingConvention = CallingConvention.StdCall, CharSet = CharSet.Unicode)]
    [return: MarshalAs(UnmanagedType.I1)] public static extern bool TDBTableRecordDeleted(Int32 dbIndex, string tableName, Int32 recordNumber);
    [DllImport("tdbaccess.dll", CallingConvention = CallingConvention.StdCall, CharSet = CharSet.Unicode)]
    public static extern Int32 TDBFieldGetValueAsInteger(Int32 dbIndex, string tableName, string fieldName, Int32 recordNumber);
    [DllImport("tdbaccess.dll", CallingConvention = CallingConvention.StdCall, CharSet = CharSet.Unicode)]
    public static extern Single TDBFieldGetValueAsFloat(Int32 dbIndex, string tableName, string fieldName, Int32 recordNumber);
    [DllImport("tdbaccess.dll", CallingConvention = CallingConvention.StdCall, CharSet = CharSet.Unicode)]
    [return: MarshalAs(UnmanagedType.I1)] public static extern bool TDBFieldGetValueAsString(Int32 dbIndex, string tableName, string fieldName, Int32 recordNumber, ref IntPtr outputBuffer);
}
'@

if (-not ('TdbTableNative' -as [type])) { Add-Type -TypeDefinition $nativeSource }
if (-not [TdbTableNative]::SetDllDirectory((Split-Path -Parent $dllPath))) {
    throw "Unable to add the TDBAccess DLL directory."
}

$db = switch ($ContainerFormat) {
    'Xbox360' { [TdbTableNative]::TDBOpenXbox360Save($dbPath) }
    'PS3' { [TdbTableNative]::TDBOpenPS3Save($dbPath) }
    default { [TdbTableNative]::TDBOpen($dbPath) }
}
if ($db -lt 0) { throw "TDBAccess could not open $dbPath" }

try {
    $tableProps = $null
    for ($i = 0; $i -lt [TdbTableNative]::TDBDatabaseGetTableCount($db); $i++) {
        $nameBuffer = [Runtime.InteropServices.Marshal]::AllocHGlobal(10)
        try {
            $candidate = [TdbTableNative+TableProperties]::new()
            $candidate.Name = $nameBuffer
            if ([TdbTableNative]::TDBTableGetProperties($db, $i, [ref]$candidate)) {
                $name = [Runtime.InteropServices.Marshal]::PtrToStringUni($nameBuffer)
                if ($name -eq $Table) { $tableProps = $candidate; break }
            }
        }
        finally { [Runtime.InteropServices.Marshal]::FreeHGlobal($nameBuffer) }
    }
    if ($null -eq $tableProps) { throw "Table '$Table' was not found." }

    $fieldDefs = [Collections.Generic.List[object]]::new()
    for ($i = 0; $i -lt $tableProps.FieldCount; $i++) {
        $nameBuffer = [Runtime.InteropServices.Marshal]::AllocHGlobal(10)
        try {
            $field = [TdbTableNative+FieldProperties]::new()
            $field.Name = $nameBuffer
            if (-not [TdbTableNative]::TDBFieldGetProperties($db, $Table, $i, [ref]$field)) {
                throw "Unable to read field $i from $Table."
            }
            $name = [Runtime.InteropServices.Marshal]::PtrToStringUni($nameBuffer)
            if (-not $Fields -or $name -in $Fields) {
                $fieldDefs.Add([pscustomobject]@{ Name = $name; Type = $field.FieldType; Bits = $field.Size })
            }
        }
        finally { [Runtime.InteropServices.Marshal]::FreeHGlobal($nameBuffer) }
    }

    $rows = [Collections.Generic.List[object]]::new()
    for ($record = 0; $record -lt $tableProps.RecordCount; $record++) {
        if ([TdbTableNative]::TDBTableRecordDeleted($db, $Table, $record)) { continue }
        $row = [ordered]@{ record = $record }
        foreach ($field in $fieldDefs) {
            $row[$field.Name] = switch ($field.Type) {
                { $_ -in 0, 13, 14 } {
                    $buffer = [Runtime.InteropServices.Marshal]::AllocHGlobal(([Math]::Max(2, ($field.Bits / 8 + 1)) * 2))
                    try {
                        $bufferPointer = $buffer
                        [void][TdbTableNative]::TDBFieldGetValueAsString($db, $Table, $field.Name, $record, [ref]$bufferPointer)
                        [Runtime.InteropServices.Marshal]::PtrToStringUni($buffer)
                    }
                    finally { [Runtime.InteropServices.Marshal]::FreeHGlobal($buffer) }
                }
                4 { [TdbTableNative]::TDBFieldGetValueAsFloat($db, $Table, $field.Name, $record) }
                default { [TdbTableNative]::TDBFieldGetValueAsInteger($db, $Table, $field.Name, $record) }
            }
        }
        $rows.Add([pscustomobject]$row)
    }

    $outputDir = Split-Path -Parent $outputFull
    if ($outputDir) { New-Item -ItemType Directory -Force -Path $outputDir | Out-Null }
    $rows | Export-Csv -LiteralPath $outputFull -NoTypeInformation -Encoding UTF8
    Write-Host "Exported $($rows.Count) active records from $Table to $outputFull"
}
finally {
    [void][TdbTableNative]::TDBClose($db)
}

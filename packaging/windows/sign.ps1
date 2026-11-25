param(
    [Parameter(Mandatory = $true)]
    [string]$PfxPath,

    [Parameter(Mandatory = $true)]
    [string[]]$Files
)

$ErrorActionPreference = 'Stop'

$pfxPassword = $env:WINDOWS_SIGNING_PFX_PASSWORD
$description = $env:WINDOWS_SIGNING_IDENTITY
# fork 改动：未配置签名证书时跳过签名，不中断构建；产出的安装包无签名，
# 安装时 Windows 会提示未知发布者，需手动选择“仍要运行”。
if ([string]::IsNullOrWhiteSpace($pfxPassword) -or [string]::IsNullOrWhiteSpace($description)) {
    Write-Warning '未配置 Windows 签名证书，跳过签名（安装包将无签名）'
    return
}

$signtool = Get-ChildItem -Path "${env:ProgramFiles(x86)}\Windows Kits\10\bin" -Filter 'signtool.exe' -Recurse |
    Where-Object { $_.FullName -match '\\x64\\signtool\.exe$' } |
    Sort-Object FullName |
    Select-Object -Last 1
if ($null -eq $signtool) {
    throw 'Windows SDK 中未找到 x64 signtool.exe'
}

foreach ($file in $Files) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        throw "待签名文件不存在: $file"
    }

    & $signtool.FullName sign `
        /f $PfxPath `
        /p $pfxPassword `
        /fd SHA256 `
        /tr 'http://timestamp.acs.microsoft.com' `
        /td SHA256 `
        /d $description `
        $file
    if ($LASTEXITCODE -ne 0) {
        throw "signtool 签名失败: $file"
    }

    $signature = Get-AuthenticodeSignature -FilePath $file
    if ($null -eq $signature.SignerCertificate) {
        throw "未找到 Authenticode 签名: $file"
    }
}

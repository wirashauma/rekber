# REKBER Mobile Test Suite - PowerShell runner
$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  REKBER MOBILE TEST SUITE - ANALYZE, TEST, COVERAGE      " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

Write-Host "`n[1/3] Menjalankan flutter analyze..." -ForegroundColor Yellow
flutter analyze
if ($LASTEXITCODE -ne 0) {
    Write-Host "flutter analyze menemukan masalah!" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2/3] Menjalankan flutter test --coverage..." -ForegroundColor Yellow
flutter test --coverage
if ($LASTEXITCODE -ne 0) {
    Write-Host "flutter test gagal!" -ForegroundColor Red
    exit 1
}

Write-Host "`n[3/3] Memeriksa Cakupan Kode (Target >= 70% per kategori)..." -ForegroundColor Yellow
python scripts/check_coverage.py
if ($LASTEXITCODE -ne 0) {
    Write-Host "Pemeriksaan cakupan gagal!" -ForegroundColor Red
    exit 1
}

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "  SEMUA PENGUJIAN & ANALISIS BERHASIL DENGAN SUKSES!      " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green

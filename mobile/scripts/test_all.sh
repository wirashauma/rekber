#!/usr/bin/env bash
set -e

echo "=========================================================="
echo "  REKBER MOBILE TEST SUITE - ANALYZE, TEST, COVERAGE      "
echo "=========================================================="

echo "[1/3] Menjalankan flutter analyze..."
flutter analyze

echo ""
echo "[2/3] Menjalankan flutter test --coverage..."
flutter test --coverage

echo ""
echo "[3/3] Memeriksa Cakupan Kode (Target >= 70% per kategori)..."
if command -v python3 &> /dev/null; then
    python3 scripts/check_coverage.py
else
    python scripts/check_coverage.py
fi

echo ""
echo "=========================================================="
echo "  SEMUA PENGUJIAN & ANALISIS BERHASIL DENGAN SUKSES!      "
echo "=========================================================="

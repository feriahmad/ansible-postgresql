#!/bin/bash

# Script untuk membersihkan data backup PostgreSQL yang bermasalah
# Khususnya untuk menangani JSON yang corrupt

set -e

# Fungsi untuk menampilkan bantuan
show_help() {
    echo "PostgreSQL Backup Data Fixer"
    echo ""
    echo "Usage: $0 [OPTIONS] <input_file> <output_file>"
    echo ""
    echo "Options:"
    echo "  -v, --verbose         Verbose output"
    echo "  -b, --backup         Buat backup dari file asli"
    echo "  -h, --help           Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 backup.sql backup_fixed.sql"
    echo "  $0 -v -b backup.sql backup_fixed.sql"
}

# Default values
VERBOSE=false
BACKUP_ORIGINAL=false
INPUT_FILE=""
OUTPUT_FILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -b|--backup)
            BACKUP_ORIGINAL=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo "Unknown option $1"
            show_help
            exit 1
            ;;
        *)
            if [[ -z "$INPUT_FILE" ]]; then
                INPUT_FILE="$1"
            elif [[ -z "$OUTPUT_FILE" ]]; then
                OUTPUT_FILE="$1"
            else
                echo "Too many arguments"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Validasi input
if [[ -z "$INPUT_FILE" || -z "$OUTPUT_FILE" ]]; then
    echo "Error: Input dan output file harus dispesifikasi"
    show_help
    exit 1
fi

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: File input tidak ditemukan: $INPUT_FILE"
    exit 1
fi

# Backup file asli jika diminta
if [[ "$BACKUP_ORIGINAL" == true ]]; then
    BACKUP_NAME="${INPUT_FILE}.backup.$(date +%s)"
    cp "$INPUT_FILE" "$BACKUP_NAME"
    echo "✅ Backup asli dibuat: $BACKUP_NAME"
fi

echo "🔧 Memulai perbaikan data backup..."
echo "📁 Input: $INPUT_FILE"
echo "📁 Output: $OUTPUT_FILE"

# Deteksi apakah file terkompresi
if [[ "$INPUT_FILE" == *.gz ]]; then
    echo "📦 File terkompresi terdeteksi, mengekstrak..."
    TEMP_INPUT="/tmp/fix_backup_input_$(date +%s).sql"
    gunzip -c "$INPUT_FILE" > "$TEMP_INPUT"
    INPUT_FILE="$TEMP_INPUT"
    CLEANUP_INPUT=true
fi

# Mulai perbaikan
echo "🔍 Mencari dan memperbaiki masalah data..."

# Perbaikan untuk JSON yang corrupt
echo "🔧 Memperbaiki JSON yang corrupt..."

# Buat file output sementara
TEMP_OUTPUT="/tmp/fix_backup_output_$(date +%s).sql"

# Perbaiki masalah JSON dengan sed
sed -E '
    # Perbaiki JSON time format yang corrupt seperti "06:0" menjadi "06:00"
    s/"([0-9]{2}):([0-9])"/"\1:\20"/g
    
    # Perbaiki JSON time format yang corrupt seperti "6:0" menjadi "06:00"  
    s/"([0-9]):([0-9])"/"\10:\20"/g
    
    # Perbaiki JSON boolean yang mungkin corrupt
    s/: true([^,}])/: true\1/g
    s/: false([^,}])/: false\1/g
    
    # Perbaiki trailing comma di JSON
    s/,(\s*[}\]])/\1/g
    
    # Perbaiki quote yang tidak tertutup di JSON
    s/([^"]),(\s*"[^"]*":\s*"[^"]*")([^"])/\1,\2"\3/g
' "$INPUT_FILE" > "$TEMP_OUTPUT"

# Validasi hasil perbaikan
echo "✅ Perbaikan selesai, memvalidasi hasil..."

# Cek apakah masih ada pattern yang bermasalah
ISSUES_FOUND=0

# Cek JSON time format yang masih bermasalah
if grep -q '"[0-9]\{1,2\}:[0-9]"' "$TEMP_OUTPUT"; then
    echo "⚠️  Masih ada time format yang bermasalah"
    if [[ "$VERBOSE" == true ]]; then
        echo "Contoh yang ditemukan:"
        grep -n '"[0-9]\{1,2\}:[0-9]"' "$TEMP_OUTPUT" | head -5
    fi
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# Cek JSON yang tidak valid lainnya
if grep -q '": ".*[^"]$' "$TEMP_OUTPUT"; then
    echo "⚠️  Masih ada JSON string yang tidak tertutup"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# Pindahkan hasil ke output file
mv "$TEMP_OUTPUT" "$OUTPUT_FILE"

# Cleanup
if [[ "$CLEANUP_INPUT" == true ]]; then
    rm -f "$INPUT_FILE"
fi

# Kompres output jika input asli terkompresi
if [[ "$1" == *.gz && "$OUTPUT_FILE" != *.gz ]]; then
    echo "📦 Mengkompres hasil..."
    gzip "$OUTPUT_FILE"
    OUTPUT_FILE="${OUTPUT_FILE}.gz"
fi

echo ""
if [[ $ISSUES_FOUND -eq 0 ]]; then
    echo "✅ Perbaikan berhasil! File siap untuk restore."
else
    echo "⚠️  Perbaikan selesai dengan $ISSUES_FOUND peringatan."
    echo "   File mungkin masih memerlukan perbaikan manual."
fi

echo "📁 File hasil: $OUTPUT_FILE"
echo ""
echo "Langkah selanjutnya:"
echo "1. Coba restore dengan file yang sudah diperbaiki:"
echo "   ./restore_postgresql.sh -f -v $OUTPUT_FILE"
echo ""
echo "2. Jika masih error, cek log detail:"
echo "   tail -f /var/backups/postgresql/restore.log"

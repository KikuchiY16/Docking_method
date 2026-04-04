#!/bin/bash

# --- 設定項目 ---
# leap.in に書かれているパスに合わせて作業ディレクトリを指定します
WORK_DIR="/workspace/andre01/kikuchi/Docking_method/amber/conf_file"
MD_EXE="pmemd.cuda"

# 作業ディレクトリに移動
cd $WORK_DIR
echo "Starting Amber MD Workflow in $WORK_DIR..."

# --- 1. tleap によるシステム構築 ---
echo "Step 1: Running tleap..."
tleap -f leap.in > leap.log

# --- 2. Minimization (構造最適化) ---
# ※ ntr=1 (拘束) があるため、-ref で初期座標 (complex.inpcrd) を参照させます
echo "Step 2: Running Minimization..."
$MD_EXE -O \
  -i min.in \
  -o min.out \
  -p complex.prmtop \
  -c complex.inpcrd \
  -ref complex.inpcrd \
  -r min.rst7

# --- 3. Equilibration (平衡化) ---
echo "Step 3: Running Equilibration..."
$MD_EXE -O \
  -i equil.in \
  -o equil.out \
  -p complex.prmtop \
  -c min.rst7 \
  -r equil.rst7 \
  -x equil.nc

# --- 4. Production (本計算: 100ns) ---
echo "Step 4: Running Production MD..."
$MD_EXE -O \
  -i prod.in \
  -o prod.out \
  -p complex.prmtop \
  -c equil.rst7 \
  -r prod.rst7 \
  -x prod.nc \
  -inf prod.mdinfo

echo "All jobs completed successfully!"
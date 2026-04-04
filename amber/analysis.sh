#!/bin/bash
# --- 設定項目（ご自身の系に合わせて書き換えてください） ---
TOP="/workspace/andre01/kikuchi/Docking_method/amber/conf_file/complex.prmtop"      # トポロジー
TRAJ="/workspace/andre01/kikuchi/Docking_method/amber/conf_file/prod_processed.nc"            # トラジェトリ
PROT_MASK=":1-119"        # 1番から119番がタンパク質
LIG_MASK=":C1"            # リガンド名は C1
COMP_MASK=":1-120"       # 複合体全体（タンパク質＋リガンド）
# --------------------------------------------------

echo "Step 1: Preparing separate topologies for MM-PBSA..."
cpptraj -p $TOP <<EOF
strip !($PROT_MASK)
parmwrite out protein.prmtop
unstrip
strip !($LIG_MASK)
parmwrite out ligand.prmtop
run
quit
EOF

echo "Step 2: Running Comprehensive CPPTRAJ Analysis..."
cpptraj -p $TOP <<EOF
trajin $TRAJ
autoimage

# --- RMSD シリーズ ---
# 1. タンパク質主鎖のRMSD（全体の安定性）
rms first $PROT_MASK@CA,C,N out rmsd_protein_backbone.dat
# 2. タンパク質全重原子のRMSD
rms first $PROT_MASK&!@H* out rmsd_protein_all.dat
# 3. リガンド自体のRMSD（リガンド単体での構造変化）
rms first $LIG_MASK&!@H* out rmsd_ligand_alone.dat
# 4. タンパク質に重ね合わせたリガンドのRMSD（結合位置のズレを確認）
rms first $PROT_MASK@CA,C,N 
rms first $LIG_MASK&!@H* nofit out rmsd_ligand_binding.dat

# --- 柔軟性・形状解析 ---
# 5. 残基ごとの揺らぎ (RMSF)
atomicfluct $PROT_MASK@CA out rmsf_protein.dat byres
# 6. 回転半径 (Radius of Gyration)
radgyr $PROT_MASK out rog_protein.dat
# 7. 溶媒接触表面積 (SASA)
surf $COMP_MASK out sasa_complex.dat

# --- 相互作用 ---
# 8. 水素結合
hbond $COMP_MASK out hbond_count.dat avgout hbond_avg.dat

# --- 出力処理 ---
# 水分子を除いた軽量トラジェトリ（可視化用）
strip :WAT,Cl-,Na+,K+
trajout prod_dry.nc netcdf
run
quit
EOF

echo "Step 3: Running MM-PBSA (Binding Free Energy)..."
cat <<EOF > mmpbsa.in
&general
   startframe=1, endframe=5000, interval=10,
   keep_files=0,
/
&gb
   igb=8, saltcon=0.150,
/
&pb
   istat=1, fillratio=4.0,
/
EOF

MMPBSA.py -O -i mmpbsa.in \
          -o FINAL_RESULTS_MMPBSA.dat \
          -sp $TOP \
          -cp $TOP \
          -rp protein.prmtop \
          -lp ligand.prmtop \
          -y prod.nc

echo "========================================================"
echo " 解析完了！以下のファイルを確認してください："
echo " 1. rmsd_protein_backbone.dat : タンパク質の安定性"
echo " 2. rmsd_ligand_binding.dat   : リガンドの結合安定性"
echo " 3. FINAL_RESULTS_MMPBSA.dat  : 結合自由エネルギー"
echo " 4. prod_dry.nc              : PyMOL/VMD用（水なし）"
echo "========================================================"
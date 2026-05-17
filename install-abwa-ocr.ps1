$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "Gray"
Clear-Host

function p($t, $c="Gray", $n=$true) { if($n){Write-Host $t -f $c}else{Write-Host $t -f $c -NoNewline} }

p ""
p "  ░█████╗░██████╗░██╗    ██╗░█████╗░      ░█████╗░░█████╗░██████╗░" "DarkRed"
p "  ██╔══██╗██╔══██╗██║    ██║██╔══██╗      ██╔══██╗██╔══██╗██╔══██╗" "DarkRed"
p "  ███████║██████╦╝██║ █╗ ██║███████║█████╗██║░░██║██║░░╚═╝██████╔╝" "Red"
p "  ██╔══██║██╔══██╗██║███╗██║██╔══██║╚════╝██║░░██║██║░░██╗██╔══██╗" "Red"
p "  ██║░░██║██████╦╝╚███╔███╔╝██║░░██║      ╚█████╔╝╚█████╔╝██║░░██║" "DarkRed"
p "  ╚═╝░░╚═╝╚═════╝░░╚══╝╚══╝░╚═╝░░╚═╝      ░╚════╝░░╚════╝░╚═╝░░╚═╝" "DarkRed"
p ""
p "                      ocr server installer v1.0" "DarkGray"
p "  ───────────────────────────────────────────────────────────────────" "DarkRed"
p ""

Start-Sleep -Milliseconds 400

function step($t) { p "  >> $t" "Red" }
function ok($t)   { p "  ok  $t" "DarkRed" }
function die($t)  { p "  !! $t" "DarkGray"; exit 1 }

step "checking python..."
Start-Sleep -Milliseconds 200
$pyexe = Get-Command python -ErrorAction SilentlyContinue
if(!$pyexe){die "python not found, install it and add to PATH"}
ok (& python --version 2>&1)

step "looking for gpu..."
Start-Sleep -Milliseconds 300
$gpus = Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name
$vendor = "cpu"
foreach($g in $gpus){
    if($g -match "NVIDIA"){$vendor="nvidia";break}
    if($g -match "AMD|Radeon"){$vendor="amd";break}
}
if($vendor -eq "nvidia"){ok "nvidia found, will use cuda"}
elseif($vendor -eq "amd"){ok "amd found, no rocm on windows, cpu mode"}
else{ok "no gpu, cpu mode"}

$torch = if($vendor -eq "nvidia"){"torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121"}else{"torch torchvision torchaudio"}

step "setting up C:\ocr..."
Start-Sleep -Milliseconds 200
if(!(Test-Path "C:\ocr")){New-Item -ItemType Directory -Path "C:\ocr" | Out-Null}
ok "dir ready"

step "downloading server.py..."
Start-Sleep -Milliseconds 300
try{
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/s1z1-balance/ocr/refs/heads/main/ocr.py" -OutFile "C:\ocr\server.py" -UseBasicParsing
    ok "got it"
}catch{die "download failed: $_"}

step "making venv..."
Start-Sleep -Milliseconds 200
& python -m venv "C:\ocr\venv"
if($LASTEXITCODE -ne 0){die "venv failed"}
ok "venv ready"

step "upgrading pip..."
& "C:\ocr\venv\Scripts\python.exe" -m pip install --upgrade pip -q
ok "done"

step "installing torch ($vendor)..."
Invoke-Expression "C:\ocr\venv\Scripts\pip.exe install $torch -q"
if($LASTEXITCODE -ne 0){die "torch install failed"}
ok "torch ok"

step "installing flask easyocr opencv pillow numpy..."
& "C:\ocr\venv\Scripts\pip.exe" install flask easyocr opencv-python pillow numpy -q
if($LASTEXITCODE -ne 0){die "deps failed"}
ok "all good"

"@echo off`ncall `"C:\ocr\venv\Scripts\activate.bat`"`npython `"C:\ocr\server.py`"" | Set-Content "C:\ocr\start.bat"

p ""
p "  ───────────────────────────────────────────────────────────────────" "DarkRed"
p "  done.  run:  C:\ocr\start.bat" "Red"
p "  endpoint:    http://localhost:8765/ocr" "DarkRed"
p "  ───────────────────────────────────────────────────────────────────" "DarkRed"
p ""
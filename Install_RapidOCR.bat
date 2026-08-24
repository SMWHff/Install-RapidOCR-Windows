@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: ==================== 初始化 ====================
title 一键部署 RapidOCR Web 服务
echo ============================================
echo   一键部署 RapidOCR Web 服务脚本
echo   兼容 Windows 7 / 10 / 11
echo   模型源：HuggingFace + 国内镜像（自动容错）
echo ============================================
echo.

:: 国内加速源（Python、pip）
set "PYTHON_MIRROR=https://mirrors.huaweicloud.com/python"
set "PIP_INDEX=https://pypi.tuna.tsinghua.edu.cn/simple"

:: 模型下载源（主 + 镜像 + 备用）
set "MODEL_BASE_URL=https://hf-mirror.com/SWHL/RapidOCR/resolve/main/PP-OCRv3"
set "MODEL_MIRROR_URL=https://huggingface.co/SWHL/RapidOCR/resolve/main/PP-OCRv3"
set "MODEL_BACKUP_URL=https://www.modelscope.cn/models/RapidAI/RapidOCR/resolve/main/onnx/PP-OCRv3"
set "MIN_MODEL_BYTES=100000"
set "MODEL_CLS_BASE_URL=https://hf-mirror.com/SWHL/RapidOCR/resolve/main/PP-OCRv1"
set "MODEL_CLS_MIRROR_URL=https://huggingface.co/SWHL/RapidOCR/resolve/main/PP-OCRv1"

:: 项目目录
set "BASE_DIR=%~dp0"
set "VENV_DIR=%BASE_DIR%venv"
set "MODEL_DIR=%BASE_DIR%models"
set "APP_FILE=%BASE_DIR%app.py"

:: 模型文件清单（标注是否必需）
set "REQUIRED_MODELS=ch_PP-OCRv3_det_infer.onnx ch_PP-OCRv3_rec_infer.onnx"
set "OPTIONAL_MODELS=ch_ppocr_mobile_v2.0_cls_infer.onnx"
set "ALL_MODELS=%REQUIRED_MODELS% %OPTIONAL_MODELS%"

:: ==================== 启用 TLS 1.2（兼容 Win7） ====================
echo [INFO] 启用 TLS 1.2 支持...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" /v DisabledByDefault /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" /v Enabled /t REG_DWORD /d 1 /f >nul 2>&1

:: ==================== 检测 Python ====================
set "PYTHON_CMD="

where py >nul 2>&1
if not errorlevel 1 (
    py -3.8 -c "import sys; sys.exit(0 if sys.version_info >= (3,8) else 1)" >nul 2>&1
    if not errorlevel 1 (
        for /f "delims=" %%i in ('py -3.8 -c "import sys; print(sys.executable)"') do set "PYTHON_CMD=%%i"
        echo [INFO] 找到 Python 3.8+ ^(py launcher^): !PYTHON_CMD!
    )
)

if not defined PYTHON_CMD (
    where python >nul 2>&1
    if not errorlevel 1 (
        python -c "import sys; sys.exit(0 if sys.version_info >= (3,8) else 1)" >nul 2>&1
        if not errorlevel 1 (
            for /f "delims=" %%i in ('python -c "import sys; print(sys.executable)"') do set "PYTHON_CMD=%%i"
            echo [INFO] 找到 Python ^(>=3.8^): !PYTHON_CMD!
        )
    )
)

if not defined PYTHON_CMD (
    echo [INFO] 未找到合适 Python，开始安装 Python 3.8.10 ...
    call :install_python
    if errorlevel 1 (
        echo [ERROR] Python 安装失败！
        pause
        exit /b 1
    )
)

echo [INFO] 使用 Python: "%PYTHON_CMD%"

:: ==================== 创建虚拟环境 ====================
set "VENV_PYTHON=%VENV_DIR%\Scripts\python.exe"
if exist "%VENV_PYTHON%" (
    echo [INFO] 检测到已存在的虚拟环境，跳过创建。
) else (
    set "USE_UV=0"
    "%PYTHON_CMD%" -m uv --version >nul 2>&1
    if not errorlevel 1 (
        set "USE_UV=1"
    ) else (
        echo [INFO] 尝试通过 pip 安装 uv ...
        "%PYTHON_CMD%" -m pip install --index-url "%PIP_INDEX%" uv >nul 2>&1
        if not errorlevel 1 (
            "%PYTHON_CMD%" -m uv --version >nul 2>&1
            if not errorlevel 1 set "USE_UV=1"
        )
    )

    if "!USE_UV!"=="1" (
        echo [INFO] 使用 uv 创建虚拟环境 ...
        "%PYTHON_CMD%" -m uv venv --python "%PYTHON_CMD%" "%VENV_DIR%"
        if errorlevel 1 (
            echo [WARN] uv 创建虚拟环境失败，回退到 venv。
            set "USE_UV=0"
        ) else (
            echo [INFO] 确保虚拟环境包含 pip ...
            "%VENV_PYTHON%" -m ensurepip --upgrade >nul 2>&1
            if errorlevel 1 (
                echo [WARN] ensurepip 失败，尝试使用 uv 安装 pip...
                "%PYTHON_CMD%" -m uv pip install --python "%VENV_PYTHON%" pip >nul 2>&1
            )
        )
    )
    if "!USE_UV!"=="0" (
        echo [INFO] 使用 venv 创建虚拟环境 ...
        "%PYTHON_CMD%" -m venv "%VENV_DIR%"
        if errorlevel 1 (
            echo [ERROR] venv 创建虚拟环境失败！
            pause
            exit /b 1
        )
    )
)

if not exist "%VENV_PYTHON%" (
    echo [ERROR] 虚拟环境 Python 不存在: "%VENV_PYTHON%"
    pause
    exit /b 1
)

"%VENV_PYTHON%" -m pip --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] 虚拟环境缺少 pip，请手动删除 venv 文件夹后重新运行脚本。
    pause
    exit /b 1
)

:: ==================== 安装依赖 ====================
echo [INFO] 升级 pip ...
"%VENV_PYTHON%" -m pip install --upgrade pip --index-url "%PIP_INDEX%" >nul 2>&1

echo [INFO] 安装基础依赖（兼容 Win7/10/11）...
"%VENV_PYTHON%" -m pip install --index-url "%PIP_INDEX%" ^
    fastapi==0.100.0 uvicorn==0.23.2 python-multipart==0.0.6 ^
    pydantic==1.10.13 ^
    numpy==1.21.6 opencv-python==4.5.5.64 pillow==9.5.0 ^
    pyyaml==6.0.1 shapely==1.8.5 pyclipper==1.3.0.post5 six==1.16.0 tqdm==4.66.1

if errorlevel 1 (
    echo [ERROR] 基础依赖安装失败！
    pause
    exit /b 1
)

:: ==================== GPU 检测 ====================
set "GPU_AVAILABLE=0"
set "CUDA_AVAILABLE=0"

nvidia-smi >nul 2>&1
if not errorlevel 1 (
    echo [INFO] 检测到 NVIDIA GPU。
    where nvcc >nul 2>&1
    if not errorlevel 1 (
        set "CUDA_AVAILABLE=1"
        echo [INFO] 检测到 CUDA Toolkit ^(nvcc^)。
    ) else (
        if defined CUDA_PATH (
            set "CUDA_AVAILABLE=1"
            echo [INFO] 检测到 CUDA_PATH 环境变量。
        )
    )
)

if "!CUDA_AVAILABLE!"=="1" (
    set "GPU_AVAILABLE=1"
    echo [INFO] 安装 onnxruntime-gpu==1.10.0 ...
    "%VENV_PYTHON%" -m pip install --index-url "%PIP_INDEX%" onnxruntime-gpu==1.10.0
) else (
    echo [INFO] 未检测到完整 CUDA 环境，安装 onnxruntime==1.10.0 ^(CPU 版^) ...
    "%VENV_PYTHON%" -m pip install --index-url "%PIP_INDEX%" onnxruntime==1.10.0
)

if errorlevel 1 (
    echo [ERROR] onnxruntime 安装失败！
    pause
    exit /b 1
)

echo [INFO] 安装 rapidocr_onnxruntime（不自动安装依赖）...
"%VENV_PYTHON%" -m pip install --index-url "%PIP_INDEX%" rapidocr_onnxruntime --no-deps
if errorlevel 1 (
    echo [ERROR] rapidocr_onnxruntime 安装失败！
    pause
    exit /b 1
)

:: ==================== 下载模型（智能容错） ====================
echo [INFO] 准备下载 RapidOCR 模型 ...
if not exist "%MODEL_DIR%" mkdir "%MODEL_DIR%"

set "MISSING_REQUIRED=0"
set "MISSING_OPTIONAL=0"

for %%F in (%ALL_MODELS%) do (
    call :download_model "%%F"
    set "result=!errorlevel!"
    if !result! neq 0 (
        :: 检查是否必需
        echo %%F | findstr /C:"ch_ppocr_mobile_v2.0_cls_infer.onnx" >nul
        if errorlevel 1 (
            set "MISSING_REQUIRED=1"
            echo [ERROR] 必需模型 %%F 下载失败！
        ) else (
            set "MISSING_OPTIONAL=1"
            echo [WARN] 可选模型 %%F 下载失败，将跳过加载。
        )
    )
)

if "%MISSING_REQUIRED%"=="1" (
    echo [ERROR] 必需模型缺失，部署失败！请检查网络后重试。
    pause
    exit /b 1
)

if "%MISSING_OPTIONAL%"=="1" (
    echo [WARN] 部分可选模型缺失，OCR 服务仍可运行（方向校正功能将禁用）。
)

echo [INFO] 模型准备完成。
goto :continue

:: ------------------------------------------------------------
:: 子程序：下载单个模型（多源、多工具）
:download_model
set "FILE_NAME=%~1"
set "DEST=%MODEL_DIR%\%FILE_NAME%"

:: 若文件已存在且非空，跳过
if exist "%DEST%" (
    for %%A in ("%DEST%") do if %%~zA geq %MIN_MODEL_BYTES% (
        echo [INFO] 模型文件 %FILE_NAME% 已存在且非空，跳过下载。
        exit /b 0
    ) else (
        del "%DEST%"
    )
)

echo [INFO] 正在下载 %FILE_NAME% ...

:: 分类模型(方向校正)放于 PP-OCRv1 路径，det/rec 放于 PP-OCRv3，按文件名选源
set "CUR_BASE=%MODEL_CLS_BASE_URL%"
set "CUR_MIRROR=%MODEL_CLS_MIRROR_URL%"
echo %FILE_NAME% | findstr /C:"cls_infer" >nul
if errorlevel 1 (
    set "CUR_BASE=%MODEL_BASE_URL%"
    set "CUR_MIRROR=%MODEL_MIRROR_URL%"
)

call :try_download "%CUR_BASE%/%FILE_NAME%" "%DEST%"
if not errorlevel 1 (
    if exist "%DEST%" (
        for %%A in ("%DEST%") do if %%~zA gtr 0 exit /b 0
    )
)

echo [WARN] 主源失败，尝试镜像源...
call :try_download "%CUR_MIRROR%/%FILE_NAME%" "%DEST%"
if not errorlevel 1 (
    if exist "%DEST%" (
        for %%A in ("%DEST%") do if %%~zA gtr 0 exit /b 0
    )
)

echo [WARN] 镜像源失败，尝试备用源（仅限分类模型）...
:: 备用源只对分类模型有效，且路径可能不同，尝试修改文件名
echo %FILE_NAME% | findstr /C:"cls_infer" >nul
if not errorlevel 1 (
    call :try_download "%MODEL_BACKUP_URL%/%FILE_NAME%" "%DEST%"
    if not errorlevel 1 (
        if exist "%DEST%" (
            for %%A in ("%DEST%") do if %%~zA gtr 0 exit /b 0
        )
    )
)

:: 全部失败
if exist "%DEST%" del "%DEST%"
exit /b 1

:: ------------------------------------------------------------
:: 子程序：用多种工具尝试下载
:try_download
set "URL=%~1"
set "DEST=%~2"
set "PART=%DEST%.part"

:: remove a stale partial download from a previous interrupted run
if exist "%PART%" del "%PART%"

:: curl 优先（连接 30 秒、总限 30 分钟、失败自动重试 3 次）
where curl >nul 2>&1
if not errorlevel 1 (
    curl -L --fail --silent --show-error --connect-timeout 30 --max-time 1800 --retry 3 --retry-delay 3 "%URL%" -o "%PART%"
    if not errorlevel 1 (
        for %%A in ("%PART%") do if %%~zA geq %MIN_MODEL_BYTES% ( move /y "%PART%" "%DEST%" >nul 2>&1 && exit /b 0 )
    )
)

:: PowerShell 兜底
powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%URL%' -OutFile '%DEST%' -TimeoutSec 1800" >nul 2>&1
if not errorlevel 1 (
    if exist "%DEST%" (
        for %%A in ("%DEST%") do if %%~zA gtr 0 exit /b 0
    )
)

:: certutil 兜底
certutil -urlcache -split -f "%URL%" "%PART%" >nul 2>&1
if not errorlevel 1 (
    for %%A in ("%PART%") do if %%~zA geq %MIN_MODEL_BYTES% ( move /y "%PART%" "%DEST%" >nul 2>&1 && exit /b 0 )
)
exit /b 1

:: ------------------------------------------------------------
:continue

:: ==================== 创建 Web 服务代码（智能适配缺失模型） ====================
echo [INFO] 创建 Web 服务代码 app.py ...

:: 生成 Web 服务代码（cls 模型已下载，直接引用有效路径）
> "%APP_FILE%" echo import os
>>"%APP_FILE%" echo import numpy as np
>>"%APP_FILE%" echo from fastapi import FastAPI, File, UploadFile
>>"%APP_FILE%" echo from fastapi.responses import JSONResponse, HTMLResponse
>>"%APP_FILE%" echo import uvicorn
>>"%APP_FILE%" echo from rapidocr_onnxruntime import RapidOCR
>>"%APP_FILE%" echo import tempfile
>>"%APP_FILE%" echo.
>>"%APP_FILE%" echo app = FastAPI(title=^"RapidOCR Web Service^")
>>"%APP_FILE%" echo.
>>"%APP_FILE%" echo HTML_PAGE = ^"^"^"
setlocal DisableDelayedExpansion
>>"%APP_FILE%" echo ^<!DOCTYPE html^>
>>"%APP_FILE%" echo ^<html lang=^"zh-CN^"^>
>>"%APP_FILE%" echo ^<head^>
>>"%APP_FILE%" echo ^<meta charset=^"utf-8^"^>
>>"%APP_FILE%" echo ^<meta name=^"viewport^" content=^"width=device-width, initial-scale=1^"^>
>>"%APP_FILE%" echo ^<title^>RapidOCR ^&#x670d;^&#x52a1;^</title^>
>>"%APP_FILE%" echo ^<style^>
>>"%APP_FILE%" echo   :root { --border: #e2e8f0; --slate: #475569; --indigo: #4f46e5; }
>>"%APP_FILE%" echo   * { box-sizing: border-box; }
>>"%APP_FILE%" echo   body { font-family: system-ui, -apple-system, ^"Segoe UI^", ^"Microsoft YaHei^", sans-serif; margin: 0; background: #f8fafc; color: #0f172a; }
>>"%APP_FILE%" echo   header { background: #fff; border-bottom: 1px solid var(--border); padding: 16px 24px; }
>>"%APP_FILE%" echo   header h1 { margin: 0; font-size: 18px; color: var(--indigo); }
>>"%APP_FILE%" echo   main { max-width: 1400px; margin: 24px auto; padding: 0 16px; display: grid; grid-template-columns: 1fr; gap: 24px; }
>>"%APP_FILE%" echo   .card { background: #fff; border: 1px solid var(--border); border-radius: 12px; overflow: hidden; }
>>"%APP_FILE%" echo   .card h2 { margin: 0; padding: 12px 16px; font-size: 14px; background: #f1f5f9; border-bottom: 1px solid var(--border); }
>>"%APP_FILE%" echo   .drop { padding: 24px; text-align: center; border: 2px dashed var(--border); border-radius: 8px; margin: 16px; color: var(--slate); cursor: pointer; }
>>"%APP_FILE%" echo   .drop:hover { border-color: var(--indigo); }
>>"%APP_FILE%" echo   #content { padding: 16px; display: flex; justify-content: center; }
>>"%APP_FILE%" echo   .canvas-wrap { position: relative; display: inline-block; max-width: 100%%; }
>>"%APP_FILE%" echo   #preview { max-width: 100%%; display: block; }
>>"%APP_FILE%" echo   #canvas { position: absolute; inset: 0; width: 100%%; height: 100%%; }
>>"%APP_FILE%" echo   button { background: var(--indigo); color: #fff; border: 0; padding: 10px 20px; border-radius: 8px; font-size: 14px; cursor: pointer; margin: 16px auto; display: block; }
>>"%APP_FILE%" echo   button:disabled { opacity: .6; cursor: not-allowed; }
>>"%APP_FILE%" echo   textarea { display: block; width: calc(100%% - 32px); margin: 0 16px 16px; padding: 10px 12px; border: 1px solid var(--border); border-radius: 8px; font: inherit; font-size: 14px; resize: vertical; box-sizing: border-box; }
>>"%APP_FILE%" echo   table { width: 100%%; border-collapse: collapse; font-size: 13px; }
>>"%APP_FILE%" echo   td, th { padding: 8px 10px; border-bottom: 1px solid var(--border); text-align: left; vertical-align: top; }
>>"%APP_FILE%" echo   th { color: var(--slate); font-weight: 600; white-space: nowrap; }
>>"%APP_FILE%" echo   .score { color: var(--indigo); white-space: nowrap; }
>>"%APP_FILE%" echo   .empty { color: #94a3b8; text-align: center; padding: 24px; }
>>"%APP_FILE%" echo ^</style^>
>>"%APP_FILE%" echo ^</head^>
>>"%APP_FILE%" echo ^<body^>
>>"%APP_FILE%" echo ^<header^>^<h1^>RapidOCR Web ^&#x670d;^&#x52a1;^</h1^>^</header^>
>>"%APP_FILE%" echo ^<main^>
>>"%APP_FILE%" echo   ^<div class=^"card^"^>
>>"%APP_FILE%" echo     ^<h2^>^&#x8bc6;^&#x522b;^&#x7ed3;^&#x679c;^</h2^>
>>"%APP_FILE%" echo     ^<div class=^"drop^" id=^"drop^"^>^&#x70b9;^&#x51fb;^&#x6216;^&#x62d6;^&#x62fd;^&#x56fe;^&#x7247;^&#x5230;^&#x6b64;^&#x5904;^</div^>
>>"%APP_FILE%" echo     ^<input type=^"file^" id=^"file^" accept=^"image/*^" hidden^>
>>"%APP_FILE%" echo     ^<button id=^"run^" disabled^>^&#x5f00;^&#x59cb;^&#x8bc6;^&#x522b;^</button^>
>>"%APP_FILE%" echo     ^<textarea id=^"text^" rows=^"8^" placeholder=^"^&#x8bc6;^&#x522b;^&#x6587;^&#x672c;^"^>^</textarea^>
>>"%APP_FILE%" echo     ^<div id=^"content^"^>^<div class=^"canvas-wrap^"^>^<img id=^"preview^" style=^"display:none^"^>^<canvas id=^"canvas^"^>^</canvas^>^</div^>^</div^>
>>"%APP_FILE%" echo   ^</div^>
>>"%APP_FILE%" echo   ^<div class=^"card^"^>
>>"%APP_FILE%" echo     ^<h2^>^&#x6587;^&#x672c;^&#x5217;^&#x8868;^</h2^>
>>"%APP_FILE%" echo     ^<div id=^"out^"^>^<div class=^"empty^"^>^&#x5c1a;^&#x672a;^&#x8bc6;^&#x522b;^</div^>^</div^>
>>"%APP_FILE%" echo   ^</div^>
>>"%APP_FILE%" echo ^</main^>
>>"%APP_FILE%" echo ^<script^>
>>"%APP_FILE%" echo const $=id=^>document.getElementById(id);
>>"%APP_FILE%" echo let imgEl=$('preview'),canvasEl=$('canvas'),ctx=canvasEl.getContext('2d');
>>"%APP_FILE%" echo let fileUrl=null;
>>"%APP_FILE%" echo function loadFile(f){
>>"%APP_FILE%" echo   if(!f) return;
>>"%APP_FILE%" echo   if(fileUrl) URL.revokeObjectURL(fileUrl);
>>"%APP_FILE%" echo   fileUrl=URL.createObjectURL(f);
>>"%APP_FILE%" echo   imgEl.onload=()=^>{imgEl.style.display='block';canvasEl.width=imgEl.naturalWidth;canvasEl.height=imgEl.naturalHeight;draw([])};
>>"%APP_FILE%" echo   imgEl.src=fileUrl;
>>"%APP_FILE%" echo   $('run').disabled=false;
>>"%APP_FILE%" echo   $('drop').textContent=f.name;
>>"%APP_FILE%" echo }
>>"%APP_FILE%" echo $('drop').onclick=()=^>$('file').click();
>>"%APP_FILE%" echo $('file').onchange=e=^>loadFile(e.target.files[0]);
>>"%APP_FILE%" echo document.addEventListener('dragover',e=^>e.preventDefault());
>>"%APP_FILE%" echo document.addEventListener('drop',e=^>{e.preventDefault();loadFile(e.dataTransfer.files[0])});
>>"%APP_FILE%" echo function draw(boxes){
>>"%APP_FILE%" echo   ctx.clearRect(0,0,canvasEl.width,canvasEl.height);
>>"%APP_FILE%" echo   ctx.strokeStyle='#4f46e5';ctx.lineWidth=3;
>>"%APP_FILE%" echo   for(const b of boxes){
>>"%APP_FILE%" echo     ctx.beginPath();
>>"%APP_FILE%" echo     ctx.moveTo(b[0][0],b[0][1]);
>>"%APP_FILE%" echo     for(let i=1;i^<b.length;i++)ctx.lineTo(b[i][0],b[i][1]);
>>"%APP_FILE%" echo     ctx.closePath();ctx.stroke();
>>"%APP_FILE%" echo   }
>>"%APP_FILE%" echo }
>>"%APP_FILE%" echo function esc(s){return String(s).replace(/[^&^<^>^"']/g,c=^>({'^&':'^&amp;','^<':'^&lt;','^>':'^&gt;','^"':'^&quot;',^"'^":'^&#39;'}[c]))}
>>"%APP_FILE%" echo $('run').onclick=async()=^>{
>>"%APP_FILE%" echo   const f=$('file').files[0]; if(!f)return;
>>"%APP_FILE%" echo   $('run').disabled=true;$('run').textContent='\u8bc6\u522b\u4e2d...';
>>"%APP_FILE%" echo   const fd=new FormData();fd.append('file',f);
>>"%APP_FILE%" echo   try{
>>"%APP_FILE%" echo     const r=await fetch('/ocr',{method:'POST',body:fd});
>>"%APP_FILE%" echo     const d=await r.json();
>>"%APP_FILE%" echo     if(d.error){$('out').innerHTML='^<div class=^"empty^"^>'+esc(d.error)+'^</div^>';$('text').value='';draw([]);return;}
>>"%APP_FILE%" echo     draw(d.result.map(x=^>x[0]));
>>"%APP_FILE%" echo     const rows=d.result.map(x=^>'^<tr^>^<td^>'+esc(x[1])+'^</td^>^<td class=^"score^"^>'+x[2].toFixed(3)+'^</td^>^</tr^>').join('');
>>"%APP_FILE%" echo     $('out').innerHTML='^<table^>^<thead^>^<tr^>^<th^>^&#x6587;^&#x672c;^</th^>^<th^>^&#x7f6e;^&#x4fe1;^&#x5ea6;^</th^>^</tr^>^</thead^>^<tbody^>'+rows+'^</tbody^>^</table^>';
>>"%APP_FILE%" echo     $('text').value=d.result.map(x=^>x[1]).join(String.fromCharCode(10));
>>"%APP_FILE%" echo   }catch(e){$('out').innerHTML='^<div class=^"empty^"^>^&#x8bf7;^&#x6c42;^&#x5931;^&#x8d25;: '+esc(e.message)+'^</div^>';$('text').value='';}
>>"%APP_FILE%" echo   finally{$('run').disabled=false;$('run').textContent='\u5f00\u59cb\u8bc6\u522b';}
>>"%APP_FILE%" echo };
>>"%APP_FILE%" echo ^</script^>
>>"%APP_FILE%" echo ^</body^>
>>"%APP_FILE%" echo ^</html^>
>>"%APP_FILE%" echo.
>>"%APP_FILE%" echo ^"^"^"
endlocal
>>"%APP_FILE%" echo @app.get(^"/^")
>>"%APP_FILE%" echo async def index():
>>"%APP_FILE%" echo     return HTMLResponse(content=HTML_PAGE)
>>"%APP_FILE%" echo.
>>"%APP_FILE%" echo MODEL_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), ^"models^")
>>"%APP_FILE%" echo.
>>"%APP_FILE%" echo # initialize the OCR engine (cls is optional)
>>"%APP_FILE%" echo ocr_engine = RapidOCR(
>>"%APP_FILE%" echo     det_model_path=os.path.join(MODEL_DIR, ^"ch_PP-OCRv3_det_infer.onnx^"),
>>"%APP_FILE%" echo     rec_model_path=os.path.join(MODEL_DIR, ^"ch_PP-OCRv3_rec_infer.onnx^"),
>>"%APP_FILE%" echo     cls_model_path=os.path.join(MODEL_DIR, ^"ch_ppocr_mobile_v2.0_cls_infer.onnx^"),
>>"%APP_FILE%" echo )
>>"%APP_FILE%" echo.
>>"%APP_FILE%" echo def convert_result(result):
>>"%APP_FILE%" echo     if not result:
>>"%APP_FILE%" echo         return result
>>"%APP_FILE%" echo     converted = []
>>"%APP_FILE%" echo     for box, text, score in result:
>>"%APP_FILE%" echo         if isinstance(box, np.ndarray):
>>"%APP_FILE%" echo             box = box.tolist()
>>"%APP_FILE%" echo         converted.append([box, text, float(score)])
>>"%APP_FILE%" echo     return converted
>>"%APP_FILE%" echo.
>>"%APP_FILE%" echo @app.post(^"/ocr^")
>>"%APP_FILE%" echo async def ocr(file: UploadFile = File(...)):
>>"%APP_FILE%" echo     contents = await file.read()
>>"%APP_FILE%" echo     with tempfile.NamedTemporaryFile(delete=False, suffix=^".png^") as tmp:
>>"%APP_FILE%" echo         tmp.write(contents)
>>"%APP_FILE%" echo         tmp_path = tmp.name
>>"%APP_FILE%" echo     try:
>>"%APP_FILE%" echo         result, elapse = ocr_engine(tmp_path)
>>"%APP_FILE%" echo         result = convert_result(result)
>>"%APP_FILE%" echo     finally:
>>"%APP_FILE%" echo         os.unlink(tmp_path)
>>"%APP_FILE%" echo     if result:
>>"%APP_FILE%" echo         return JSONResponse(content={^"result^": result, ^"elapse^": elapse})
>>"%APP_FILE%" echo     else:
>>"%APP_FILE%" echo         return JSONResponse(content={^"error^": ^"OCR failed^"}, status_code=500)
>>"%APP_FILE%" echo.
>>"%APP_FILE%" echo if __name__ == ^"__main__^":
>>"%APP_FILE%" echo     uvicorn.run(app, host=^"0.0.0.0^", port=5000, use_colors=False)
>>"%APP_FILE%" echo.

:: ==================== 启动服务 ====================
echo [INFO] 设置环境变量并启动 Web 服务 ...
set "GPU_AVAILABLE=%GPU_AVAILABLE%"
echo [INFO] 服务地址: http://localhost:5000
echo [INFO] API 文档: http://localhost:5000/docs
echo [INFO] 按 Ctrl+C 停止服务。
"%VENV_PYTHON%" "%APP_FILE%"

pause
exit /b 0

:: ==================== 子程序：安装 Python ====================
:install_python
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    set "PYTHON_INSTALLER_URL=%PYTHON_MIRROR%/3.8.10/python-3.8.10-amd64.exe"
    set "PYTHON_INSTALLER=%TEMP%\python-3.8.10-amd64.exe"
) else (
    set "PYTHON_INSTALLER_URL=%PYTHON_MIRROR%/3.8.10/python-3.8.10.exe"
    set "PYTHON_INSTALLER=%TEMP%\python-3.8.10.exe"
)
echo [INFO] 下载 Python 安装包: !PYTHON_INSTALLER_URL!
certutil -urlcache -split -f "!PYTHON_INSTALLER_URL!" "!PYTHON_INSTALLER!" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python 安装包下载失败！
    exit /b 1
)
if not exist "!PYTHON_INSTALLER!" (
    echo [ERROR] Python 安装包不存在！
    exit /b 1
)
echo [INFO] 静默安装 Python 3.8.10（用户级）...
"!PYTHON_INSTALLER!" /quiet InstallAllUsers=0 PrependPath=1 Include_test=0
if errorlevel 1 (
    echo [ERROR] Python 安装失败！
    del "!PYTHON_INSTALLER!"
    exit /b 1
)
del "!PYTHON_INSTALLER!"

set "PYTHON_CMD=%LOCALAPPDATA%\Programs\Python\Python38\python.exe"
if not exist "!PYTHON_CMD!" (
    set "PYTHON_CMD=%LOCALAPPDATA%\Programs\Python\Python38-32\python.exe"
)
if not exist "!PYTHON_CMD!" (
    echo [ERROR] 未找到安装后的 Python！
    exit /b 1
)
echo [INFO] Python 安装完成: !PYTHON_CMD!
exit /b 0

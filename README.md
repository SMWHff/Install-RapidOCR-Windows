# Install-RapidOCR-Windows

在 Windows 上一键安装并运行 RapidOCR 的中文 OCR Web 服务。

## 功能

- 基于 RapidOCR（PaddleOCR 的 ONNX 运行时版本），无需 GPU 即可运行
- 自带简洁的 Web 页面，支持点击/拖拽上传图片识别
- **模型与虚拟环境已随仓库提供**，clone 后开箱即用
- 也支持一键脚本自动下载模型与安装依赖（多镜像源：hf-mirror、Hugging Face、ModelScope）
- CPU 环境下自动安装 `onnxruntime`，检测到 CUDA 时安装 GPU 版本

## 快速开始

### 方式一：直接使用仓库内 venv（推荐）

仓库已包含完整的 `venv/` 虚拟环境与 `models/` 模型文件：

```bash
# 激活虚拟环境后启动服务
venv/Scripts/activate
uvicorn app:app --host 0.0.0.0 --port 5000
```

### 方式二：一键安装脚本

1. 双击运行 `Install_RapidOCR.bat`
2. 等待脚本完成依赖安装与模型下载（若本地已有 venv/models 会跳过）
3. 脚本启动服务后，浏览器访问 `http://localhost:5000`
4. 拖拽或点击上传图片，点击「开始识别」即可获取识别结果

## 项目结构

```
Install-RapidOCR-Windows/
├── app.py                   # FastAPI 后端 + Web 前端页面
├── Install_RapidOCR.bat     # 一键安装与启动脚本
├── venv/                    # Python 虚拟环境（已随仓库提供）
└── models/                  # OCR 模型文件（已随仓库提供）
```

## API

| 方法 | 路径 | 说明 |
| ---- | ---- | ---- |
| POST | `/api/ocr` | 上传图片，返回识别文本与置信度 |

请求示例：

```bash
curl -X POST http://localhost:5000/api/ocr -F "file=@test.png"
```

## 依赖

- Python 3.x
- FastAPI、uvicorn、numpy、rapidocr_onnxruntime、onnxruntime

# Install-RapidOCR-Windows

在 Windows 上一键安装并运行 RapidOCR 的中文 OCR Web 服务。

## 功能

- 基于 RapidOCR（PaddleOCR 的 ONNX 运行时版本），无需 GPU 即可运行
- 自带简洁的 Web 页面，支持点击/拖拽上传图片识别
- 模型文件自动下载（多镜像源：hf-mirror、Hugging Face、ModelScope）
- CPU 环境下自动安装 `onnxruntime`，检测到 CUDA 时安装 GPU 版本

## 快速开始

1. 双击运行 `Install_RapidOCR.bat`
2. 等待脚本完成依赖安装与模型下载
3. 脚本启动服务后，浏览器访问 `http://localhost:8000`
4. 拖拽或点击上传图片，点击「开始识别」即可获取识别结果

## 项目结构

```
Install-RapidOCR-Windows/
├── app.py                   # FastAPI 后端 + Web 前端页面
├── Install_RapidOCR.bat     # 一键安装与启动脚本
└── models/                  # 模型目录（自动下载，不入库）
```

## API

| 方法 | 路径 | 说明 |
| ---- | ---- | ---- |
| POST | `/api/ocr` | 上传图片，返回识别文本与置信度 |

请求示例：

```bash
curl -X POST http://localhost:8000/api/ocr -F "file=@test.png"
```

## 依赖

- Python 3.x
- FastAPI、uvicorn、numpy、rapidocr_onnxruntime、onnxruntime

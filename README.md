# Install-RapidOCR-Windows

在 Windows 上一键部署并运行 **RapidOCR** 中文 OCR Web 服务。克隆仓库后开箱即用：无需 GPU，无需手动下载模型，即可通过浏览器拖拽图片完成文字识别。

[![Python](https://img.shields.io/badge/Python-3.8%2B-blue)](https://www.python.org/)
[![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey)](#)
[![OCR](https://img.shields.io/badge/OCR-RapidOCR-purple)](https://github.com/RapidAI/RapidOCR)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

## 目录

- [功能特性](#功能特性)
- [技术栈](#技术栈)
- [快速开始](#快速开始)
- [使用说明](#使用说明)
- [API](#api)
- [项目结构](#项目结构)
- [配置](#配置)
- [常见问题](#常见问题-faq)
- [贡献指南](#贡献指南)
- [许可证](#许可证)
- [致谢](#致谢)

## 功能特性

- 🚀 **开箱即用**：完整的 Python 虚拟环境（`venv/`）与 OCR 模型（`models/`）已随仓库提供
- 📦 **一键部署**：双击 `Install_RapidOCR.bat` 自动完成依赖安装、模型下载与服务启动
- 🖼️ **便捷识别**：Web 页面支持点击/拖拽上传图片，实时预览并绘制识别框
- 📋 **结果分组**：同一行文本以 Tab 分隔、不同行换行，多行文本框可直接复制
- 🌐 **多镜像容错**：模型自动从 hf-mirror / Hugging Face / ModelScope 多源下载
- 🎮 **CPU/GPU 自适应**：检测到 CUDA 自动安装 GPU 版 `onnxruntime`，否则安装 CPU 版

## 技术栈

| 类别 | 技术 |
| ---- | ---- |
| Web 框架 | FastAPI、uvicorn |
| OCR 引擎 | rapidocr_onnxruntime（PaddleOCR 的 ONNX 运行时版本） |
| 运行环境 | onnxruntime（CPU/GPU） |
| 图像处理 | opencv-python、Pillow、numpy |
| 其他 | python-multipart、pydantic、pyyaml、shapely、pyclipper、tqdm |

## 快速开始

### 方式一：使用仓库内 venv（推荐）

```bash
# 激活虚拟环境（Git Bash / CMD 均可）
venv/Scripts/activate

# 启动服务
uvicorn app:app --host 0.0.0.0 --port 5000
```

浏览器访问 <http://localhost:5000>。

### 方式二：一键安装脚本

1. 双击运行 `Install_RapidOCR.bat`
2. 脚本自动检测 Python、创建虚拟环境、安装依赖并下载模型（已存在则跳过）
3. 服务启动后，浏览器访问 `http://localhost:5000`

> 提示：脚本会检测 CUDA 环境，自动选择 `onnxruntime-gpu` 或 `onnxruntime`（CPU 版）。

## 使用说明

1. 打开页面后，点击虚线框或拖拽一张图片到页面
2. 点击 **「开始识别」** 按钮
3. 识别完成后：
   - 左侧图片上会绘制出文本检测框
   - **「文本列表」** 表格展示每个识别框的文本与置信度
   - **多行文本框** 汇总全部识别文本：同一行文本以 Tab 分隔、不同行换行，方便复制

## API

| 方法 | 路径 | 说明 |
| ---- | ---- | ---- |
| GET  | `/`       | Web 页面 |
| POST | `/ocr`    | 上传图片，返回识别文本、坐标与置信度 |

请求示例：

```bash
curl -X POST http://localhost:5000/ocr -F "file=@test.png"
```

响应示例：

```json
{
  "result": [
    [[[x, y], [x, y], [x, y], [x, y]], "识别文本", 0.991]
  ],
  "elapse": 1.234
}
```

其中 `result` 每个元素为 `[检测框四点坐标, 文本, 置信度]`。

## 项目结构

```
Install-RapidOCR-Windows/
├── app.py                   # FastAPI 后端 + Web 前端页面
├── Install_RapidOCR.bat     # 一键安装与启动脚本
├── venv/                    # Python 虚拟环境（已随仓库提供）
├── models/                  # OCR 模型文件（已随仓库提供）
├── LICENSE                  # MIT 许可证
└── README.md                # 项目说明
```

## 配置

| 配置项 | 位置 | 说明 |
| ---- | ---- | ---- |
| 服务端口 | `app.py` 中 `uvicorn.run(... port=5000)` | 修改端口后重启服务生效 |
| 模型镜像源 | `Install_RapidOCR.bat` 中 `MODEL_BASE_URL` / `MODEL_MIRROR_URL` / `MODEL_BACKUP_URL` | 按优先级自动容错 |
| 依赖镜像源 | `Install_RapidOCR.bat` 中 `PIP_INDEX` | 默认清华 PyPI 镜像 |
| 模型目录 | `Install_RapidOCR.bat` 中 `MODEL_DIR` | 默认项目根目录下 `models/` |

## 常见问题 (FAQ)

**Q：没有 GPU 能运行吗？**
可以。脚本未检测到 CUDA 时会自动安装 CPU 版 `onnxruntime`，识别速度稍慢但功能完整。

**Q：模型下载很慢或失败？**
脚本内置 hf-mirror、Hugging Face、ModelScope 三个镜像源并自动容错，重试运行即可。也可手动将模型文件放入 `models/` 目录。

**Q：浏览器访问 `localhost:5000` 打不开？**
请确认服务启动日志无报错；Windows 防火墙可能拦截端口，可放行或改用本机访问。

**Q：端口 5000 被占用？**
修改 `app.py` 中的 `port` 参数后重启服务。

## 贡献指南

欢迎贡献！请遵循以下流程：

1. Fork 本仓库
2. 创建功能分支：`git checkout -b feature/xxx`
3. 提交修改：`git commit -am 'Add xxx'`
4. 推送到分支：`git push origin feature/xxx`
5. 发起 Pull Request

提交代码前请确保服务可正常启动运行。

## 许可证

本项目采用 [MIT 许可证](LICENSE)。

```
MIT License

Copyright (c) 2026 SMWHff

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## 致谢

- [RapidOCR](https://github.com/RapidAI/RapidOCR) — 本项目使用的 OCR 引擎
- [PaddleOCR](https://github.com/PaddlePaddle/PaddleOCR) — 模型与算法来源
- [FastAPI](https://github.com/tiangolo/fastapi) / [uvicorn](https://github.com/encode/uvicorn) — Web 服务框架

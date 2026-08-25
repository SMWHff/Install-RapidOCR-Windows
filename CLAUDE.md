# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

Windows 上一键部署并运行 **RapidOCR** 中文 OCR Web 服务：FastAPI 后端 + 内嵌单文件前端，通过 `rapidocr_onnxruntime` 识别图片文字。无需 GPU；模型随仓库提供，虚拟环境由 bat/uv 自动创建。

## 常用命令

### 开发调试（uv 工作流，仅 Win10/11 开发机）

```bash
uv run python app.py          # 启动服务（uv 自动使用 .venv）

# 验证 OCR 接口
curl -X POST http://localhost:5000/ocr -F "file=@test.png"
```

依赖在 `pyproject.toml` 中锁定（Python 3.8、numpy 1.21.6、onnxruntime 1.10.0 等），`uv sync` 同步到 `.venv/`。浏览器访问 `http://localhost:5000`。

### 一键部署（面向终端用户，Win7/10/11）

直接双击 `Install_RapidOCR.bat` 完成依赖安装、模型下载与启动全流程。bat 检测到 uv 时用 `uv run` 启动，无 uv（如 Win7）自动回退 venv+python。

## 架构要点（重要）

### 1. app.py 与 bat 内嵌副本必须同步（最关键）

`Install_RapidOCR.bat` 的 `:continue` 段（约第 327-477 行）会通过 `echo` 逐行**重新生成根目录的 `app.py`**。每次运行 bat，当前的 `app.py` 都会被覆盖为 bat 内嵌的版本。

因此修改 `app.py` 时**必须同步修改 bat 中内嵌的同一份副本**，否则下次运行 bat 后你的修改会丢失。

注意：bat 中 `cls_model_path` 一行是**条件生成**的——若 `models/` 下缺 `ch_ppocr_mobile_v2.0_cls_infer.onnx`，bat 生成的 app.py 会写 `cls_model_path=None`（避免启动失败），否则写完整路径。故 bat 生成的 app.py 可能与仓库版本在 cls 行有差异。

### 2. 单文件全栈结构

`app.py` 同时包含：
- 前端 HTML/CSS/JS，全部内嵌在 `HTML_PAGE` 字符串（`app.py:11-107`），页面样式、拖拽上传、Canvas 绘制检测框、`groupText` 按行分组逻辑都在其中
- 后端 FastAPI 路由：`GET /` 返回页面，`POST /ocr` 处理识别（`app.py:108-145`）

OCR 流程：接收上传 → 写入临时文件 → `ocr_engine(tmp_path)` → numpy 坐标转 JSON 可序列化列表 → 返回 `{result, elapse}`。

### 3. 模型加载

引擎在模块加载时初始化（`app.py:115-119`），指向 `models/` 目录下 3 个固定 ONNX 文件（det / rec / cls）。运行 bat 时缺模型会从 hf-mirror / Hugging Face / ModelScope 多源自动下载，已有且非空则跳过。

## 关键技术约束

- **`Install_RapidOCR.bat` 是 GBK/ANSI 编码**，直接编辑会乱码。必须先转 UTF-8 副本编辑后再转回，禁止直接用编辑工具改原文件。
- **无 `requirements.txt`**：依赖有两处锁定——开发调试用 `pyproject.toml`（uv 管理）；bat 硬编码 `pip install` 指定同一组版本（Python 3.8.10、onnxruntime 1.10.0、fastapi 0.100.0、numpy 1.21.6 等）。新增依赖需同时改 `pyproject.toml` 与 bat 中的安装命令。
- 运行时环境统一为 **`.venv/`**：bat 与 uv 开发工作流都使用它（由 `pyproject.toml` + `uv.lock` 管理，已随仓库提交，Windows 专属）。bat 内置 `USE_UV` 检测：有 uv 用 `uv run` 启动，无 uv（如 Win7）回退 venv+python，该逻辑不得改造成 uv-only。旧 `venv/` 已从 git 跟踪移除（历史遗留，bat 不再使用）。
- 端口 5000 硬编码在 `app.py:148`（`uvicorn.run`），README 与 bat 中的提示文字均与此一致。
- bat 使用 `EnableDelayedExpansion`（`!var!` 语法）与子过程 `call :label`，echo 特殊字符需 `^` 转义。

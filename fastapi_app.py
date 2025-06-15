#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""FastAPI server for the financial analysis system"""

import os
import tempfile
from pathlib import Path

from fastapi import FastAPI, UploadFile, File, Form
from fastapi.responses import HTMLResponse, JSONResponse, FileResponse

from analysis_multi import process_financial_data
from analysis_mal import process_malaysia_financial_data

app = FastAPI()

ALLOWED_EXTENSIONS = {"xlsx", "xls"}


def allowed_file(filename: str) -> bool:
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXTENSIONS


@app.get("/", response_class=HTMLResponse)
async def index():
    """Return the frontend page"""
    try:
        with open("index.html", "r", encoding="utf-8") as f:
            return f.read()
    except FileNotFoundError:
        return HTMLResponse(
            """
            <h1>错误</h1>
            <p>找不到 index.html 文件。请确保前端文件存在。</p>
            """,
            status_code=404,
        )


@app.post("/process")
async def process_files(
    analysis_type: str = Form("indonesia"),
    orders: list[UploadFile] = File(...),
    settlements: list[UploadFile] = File(...),
    consumption: UploadFile = File(...),
):
    """Process uploaded files and run the analysis"""

    all_files = orders + settlements + [consumption]
    for f in all_files:
        if f.filename == "" or not allowed_file(f.filename):
            return JSONResponse({"error": f"文件 {f.filename} 格式不正确，请上传Excel文件"}, status_code=400)

    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)

        order_paths = []
        for i, file in enumerate(orders):
            filename = f"order_{i+1}_{Path(file.filename).name}"
            file_path = temp_path / filename
            with open(file_path, "wb") as out:
                out.write(await file.read())
            order_paths.append(file_path)

        settlement_paths = []
        for i, file in enumerate(settlements):
            filename = f"settlement_{i+1}_{Path(file.filename).name}"
            file_path = temp_path / filename
            with open(file_path, "wb") as out:
                out.write(await file.read())
            settlement_paths.append(file_path)

        consumption_filename = f"consumption_{Path(consumption.filename).name}"
        consumption_path = temp_path / consumption_filename
        with open(consumption_path, "wb") as out:
            out.write(await consumption.read())

        try:
            if analysis_type == "malaysia":
                output_path = process_malaysia_financial_data(
                    order_files=order_paths,
                    settlement_files=settlement_paths,
                    consumption_file=consumption_path,
                    output_dir=temp_path,
                )
                download_name = "马来跨境店财务分析结果.xlsx"
            else:
                output_path = process_financial_data(
                    order_files=order_paths,
                    settlement_files=settlement_paths,
                    consumption_file=consumption_path,
                    output_dir=temp_path,
                )
                download_name = "印尼财务分析结果.xlsx"
        except Exception as e:
            return JSONResponse({"error": f"数据分析失败: {e}"}, status_code=500)

        return FileResponse(
            path=output_path,
            filename=download_name,
            media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        )


if __name__ == "__main__":
    import uvicorn

    port = int(os.environ.get("PORT", 8080))
    print("🚀 启动财务数据分析系统...")
    print(f"📊 访问地址: http://localhost:{port}")
    print("💡 使用 Ctrl+C 停止服务器")

    uvicorn.run(app, host="0.0.0.0", port=port)

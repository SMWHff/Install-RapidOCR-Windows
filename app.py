import os
import numpy as np
from fastapi import FastAPI, File, UploadFile
from fastapi.responses import JSONResponse, HTMLResponse
import uvicorn
from rapidocr_onnxruntime import RapidOCR
import tempfile

app = FastAPI(title="RapidOCR Web Service")

HTML_PAGE = """
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>RapidOCR &#x670d;&#x52a1;</title>
<style>
  :root { --border: #e2e8f0; --slate: #475569; --indigo: #4f46e5; }
  * { box-sizing: border-box; }
  body { font-family: system-ui, -apple-system, "Segoe UI", "Microsoft YaHei", sans-serif; margin: 0; background: #f8fafc; color: #0f172a; }
  header { background: #fff; border-bottom: 1px solid var(--border); padding: 16px 24px; }
  header h1 { margin: 0; font-size: 18px; color: var(--indigo); }
  main { max-width: 1080px; margin: 24px auto; padding: 0 16px; display: grid; grid-template-columns: 1fr 1fr; gap: 24px; }
  @media (max-width: 720px) { main { grid-template-columns: 1fr; } }
  .card { background: #fff; border: 1px solid var(--border); border-radius: 12px; overflow: hidden; }
  .card h2 { margin: 0; padding: 12px 16px; font-size: 14px; background: #f1f5f9; border-bottom: 1px solid var(--border); }
  .drop { padding: 24px; text-align: center; border: 2px dashed var(--border); border-radius: 8px; margin: 16px; color: var(--slate); cursor: pointer; }
  .drop:hover { border-color: var(--indigo); }
  #content { padding: 16px; display: flex; justify-content: center; }
  .canvas-wrap { position: relative; display: inline-block; max-width: 100%; }
  #preview { max-width: 100%; display: block; }
  #canvas { position: absolute; inset: 0; width: 100%; height: 100%; }
  button { background: var(--indigo); color: #fff; border: 0; padding: 10px 20px; border-radius: 8px; font-size: 14px; cursor: pointer; margin: 16px auto; display: block; }
  button:disabled { opacity: .6; cursor: not-allowed; }
  table { width: 100%; border-collapse: collapse; font-size: 13px; }
  td, th { padding: 8px 10px; border-bottom: 1px solid var(--border); text-align: left; vertical-align: top; }
  th { color: var(--slate); font-weight: 600; white-space: nowrap; }
  .score { color: var(--indigo); white-space: nowrap; }
  .empty { color: #94a3b8; text-align: center; padding: 24px; }
</style>
</head>
<body>
<header><h1>RapidOCR Web &#x670d;&#x52a1;</h1></header>
<main>
  <div class="card">
    <h2>&#x8bc6;&#x522b;&#x7ed3;&#x679c;</h2>
    <div class="drop" id="drop">&#x70b9;&#x51fb;&#x6216;&#x62d6;&#x62fd;&#x56fe;&#x7247;&#x5230;&#x6b64;&#x5904;</div>
    <input type="file" id="file" accept="image/*" hidden>
    <button id="run" disabled>&#x5f00;&#x59cb;&#x8bc6;&#x522b;</button>
    <div id="content"><div class="canvas-wrap"><img id="preview" style="display:none"><canvas id="canvas"></canvas></div></div>
  </div>
  <div class="card">
    <h2>&#x6587;&#x672c;&#x5185;&#x5bb9;</h2>
    <div id="out"><div class="empty">&#x5c1a;&#x672a;&#x8bc6;&#x522b;</div></div>
  </div>
</main>
<script>
const $=id=>document.getElementById(id);
let imgEl=$('preview'),canvasEl=$('canvas'),ctx=canvasEl.getContext('2d');
let fileUrl=null;
function loadFile(f){
  if(!f) return;
  if(fileUrl) URL.revokeObjectURL(fileUrl);
  fileUrl=URL.createObjectURL(f);
  imgEl.onload=()=>{imgEl.style.display='block';canvasEl.width=imgEl.naturalWidth;canvasEl.height=imgEl.naturalHeight;draw([])};
  imgEl.src=fileUrl;
  $('run').disabled=false;
  $('drop').textContent=f.name;
}
$('drop').onclick=()=>$('file').click();
$('file').onchange=e=>loadFile(e.target.files[0]);
document.addEventListener('dragover',e=>e.preventDefault());
document.addEventListener('drop',e=>{e.preventDefault();loadFile(e.dataTransfer.files[0])});
function draw(boxes){
  ctx.clearRect(0,0,canvasEl.width,canvasEl.height);
  ctx.strokeStyle='#4f46e5';ctx.lineWidth=3;
  for(const b of boxes){
    ctx.beginPath();
    ctx.moveTo(b[0][0],b[0][1]);
    for(let i=1;i<b.length;i++)ctx.lineTo(b[i][0],b[i][1]);
    ctx.closePath();ctx.stroke();
  }
}
function esc(s){return String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
$('run').onclick=async()=>{
  const f=$('file').files[0]; if(!f)return;
  $('run').disabled=true;$('run').textContent='\u8bc6\u522b\u4e2d...';
  const fd=new FormData();fd.append('file',f);
  try{
    const r=await fetch('/ocr',{method:'POST',body:fd});
    const d=await r.json();
    if(d.error){$('out').innerHTML='<div class="empty">'+esc(d.error)+'</div>';draw([]);return;}
    draw(d.result.map(x=>x[0]));
    const rows=d.result.map(x=>'<tr><td>'+esc(x[1])+'</td><td class="score">'+x[2].toFixed(3)+'</td></tr>').join('');
    $('out').innerHTML='<table><thead><tr><th>&#x6587;&#x672c;</th><th>&#x7f6e;&#x4fe1;&#x5ea6;</th></tr></thead><tbody>'+rows+'</tbody></table>';
  }catch(e){$('out').innerHTML='<div class="empty">&#x8bf7;&#x6c42;&#x5931;&#x8d25;: '+esc(e.message)+'</div>';}
  finally{$('run').disabled=false;$('run').textContent='\u5f00\u59cb\u8bc6\u522b';}
};
</script>
</body>
</html>

"""
@app.get("/")
async def index():
    return HTMLResponse(content=HTML_PAGE)

MODEL_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "models")

# initialize the OCR engine (cls is optional)
ocr_engine = RapidOCR(
    det_model_path=os.path.join(MODEL_DIR, "ch_PP-OCRv3_det_infer.onnx"),
    rec_model_path=os.path.join(MODEL_DIR, "ch_PP-OCRv3_rec_infer.onnx"),
    cls_model_path=os.path.join(MODEL_DIR, "ch_ppocr_mobile_v2.0_cls_infer.onnx"),
)

def convert_result(result):
    if not result:
        return result
    converted = []
    for box, text, score in result:
        if isinstance(box, np.ndarray):
            box = box.tolist()
        converted.append([box, text, float(score)])
    return converted

@app.post("/ocr")
async def ocr(file: UploadFile = File(...)):
    contents = await file.read()
    with tempfile.NamedTemporaryFile(delete=False, suffix=".png") as tmp:
        tmp.write(contents)
        tmp_path = tmp.name
    try:
        result, elapse = ocr_engine(tmp_path)
        result = convert_result(result)
    finally:
        os.unlink(tmp_path)
    if result:
        return JSONResponse(content={"result": result, "elapse": elapse})
    else:
        return JSONResponse(content={"error": "OCR failed"}, status_code=500)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5000, use_colors=False)


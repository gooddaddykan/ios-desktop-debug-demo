import asyncio
import hmac
import json
import os
from pathlib import Path
from aiohttp import web, WSMsgType

TOKEN = os.environ["DESKTOP_SESSION_TOKEN"]
PASSWORD = os.environ["DESKTOP_VNC_PASSWORD"]
ASSETS = Path(os.environ["NOVNC_DIRECTORY"]).resolve()
STOP = Path(os.environ["DESKTOP_STOP_FILE"])

@web.middleware
async def private_session(request, handler):
    parts = request.path.split("/")
    if len(parts) < 3 or not hmac.compare_digest(parts[1], TOKEN):
        raise web.HTTPNotFound()
    response = await handler(request)
    response.headers["Cache-Control"] = "no-store"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["X-Content-Type-Options"] = "nosniff"
    return response

async def index(request):
    html = """<!doctype html><html><head><meta charset="utf-8"><title>iOS Demo — Temporary Mac Desktop</title>
<style>body{margin:0;background:#131722;color:#fff;font:15px system-ui}header{height:52px;display:flex;gap:20px;align-items:center;padding:0 16px}#screen{height:calc(100vh - 52px);background:#000}button{padding:8px 14px;cursor:pointer}</style></head>
<body><header><strong>Public iOS demo</strong><span id="status">Connecting to Mac…</span><button id="finish">End session</button></header><div id="screen"></div>
<script type="module">
import RFB from './assets/core/rfb.js';
const status=document.querySelector('#status');
const url=new URL('./ws',location.href);url.protocol=location.protocol==='https:'?'wss:':'ws:';
const rfb=new RFB(document.querySelector('#screen'),url.href,{credentials:{password:__PASSWORD__}});
rfb.scaleViewport=true;rfb.resizeSession=false;
rfb.addEventListener('connect',()=>{status.textContent='Connected — Mac desktop';});
rfb.addEventListener('disconnect',e=>{status.textContent=e.detail.clean?'Disconnected':'Connection failed or closed';});
rfb.addEventListener('securityfailure',e=>{status.textContent='VNC authentication failed: '+(e.detail.reason||'unknown reason');});
rfb.addEventListener('credentialsrequired',()=>{status.textContent='Mac requires additional authentication';});
document.querySelector('#finish').onclick=async()=>{await fetch('./stop',{method:'POST'});rfb.disconnect();status.textContent='Session ended';};
</script></body></html>""".replace("__PASSWORD__", json.dumps(PASSWORD))
    return web.Response(text=html, content_type="text/html")

async def assets(request):
    path=(ASSETS / request.match_info["path"]).resolve()
    if not path.is_relative_to(ASSETS) or not path.is_file():
        raise web.HTTPNotFound()
    return web.FileResponse(path)

async def websocket(request):
    ws=web.WebSocketResponse(heartbeat=20,max_msg_size=4*1024*1024)
    await ws.prepare(request)
    reader,writer=await asyncio.open_connection("127.0.0.1",5900)
    async def from_vnc():
        while True:
            data=await reader.read(65536)
            if not data: break
            await ws.send_bytes(data)
        await ws.close()
    task=asyncio.create_task(from_vnc())
    try:
        async for message in ws:
            if message.type==WSMsgType.BINARY:
                writer.write(message.data)
                await writer.drain()
            elif message.type in (WSMsgType.ERROR,WSMsgType.CLOSE): break
    finally:
        task.cancel()
        writer.close()
        await writer.wait_closed()
    return ws

async def stop(request):
    STOP.touch()
    return web.Response(text="Session stopped")

app=web.Application(middlewares=[private_session])
app.router.add_get("/{token}/",index)
app.router.add_get("/{token}/assets/{path:.*}",assets)
app.router.add_get("/{token}/ws",websocket)
app.router.add_post("/{token}/stop",stop)
web.run_app(app,host="127.0.0.1",port=6080,access_log=None,print=None)

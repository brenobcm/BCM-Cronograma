import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
import uvicorn
uvicorn.run("gantt_app.app:app", host="0.0.0.0", port=8766, loop="asyncio")

"""Synthetic integration adapter only, not a second production renderer."""
import base64,json,pathlib,sys,tempfile,shutil
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[3]/"tool"))
from resume_print_cdp import Chromium
html=sys.stdin.read()
with tempfile.TemporaryDirectory(prefix="jobix-local-print-") as temporary:
 directory=pathlib.Path(temporary);browser=Chromium(shutil.which("chromium"),directory)
 try:
  target=browser.call("Target.createTarget",{"url":"about:blank"})["targetId"]
  session=browser.call("Target.attachToTarget",{"targetId":target,"flatten":True})["sessionId"]
  browser.call("Page.enable",session=session)
  browser.call("Network.enable",session=session)
  browser.call("Network.setBlockedURLs",{"urls":["http://*","https://*"]},session)
  browser.call("Page.setDocumentContent",{"frameId":browser.call("Page.getFrameTree",session=session)["frameTree"]["frame"]["id"],"html":html},session)
  expected=browser.evaluate("document.body.innerText",session)
  browser.evaluate("document.fonts.ready.then(()=>true)",session)
  pdf=browser.call("Page.printToPDF",{"printBackground":True,"preferCSSPageSize":True},session)
  sys.stdout.write(json.dumps({"pdf":pdf["data"],"text":expected}))
 finally:browser.close()
